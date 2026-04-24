"""API и WebSocket для live-сессий."""

from datetime import datetime, timezone
import hashlib
import json
import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory, get_db
from app.dependencies import get_current_dealer, get_current_trainer
from app.models.dealer import Dealer
from app.models.room import Room, RoomStatus
from app.models.round_result import RoundResult
from app.models.session import Session, SessionParticipant, SessionStatus, SessionType
from app.models.trainer import Trainer
from app.schemas.session import (
    ActiveLiveSessionResponse,
    RoundResultIn,
    SessionCreateRequest,
    SessionCreateResponse,
    SessionEndResponse,
    SessionResultsResponse,
    SessionStartResponse,
)
from app.utils.auth import decode_token
from app.websocket.manager import ws_manager

# Сообщения дилера → ретрансляция всем в live-сессии (тренер + дилеры), см. docs/ONLINE_PROTOCOL.md
_LIVE_MONITOR_TYPES = frozenset(
    {
        "round_started",
        "error_occurred",
        "action_performed",
        "round_completed",
        "table_state",
    },
)
_LIVE_MONITOR_MAX_JSON_BYTES = 12_000


router = APIRouter()
ws_router = APIRouter()
# Последний валидный table_state по ключу session_id + dealer_id (in-memory, процессный).
_LATEST_TABLE_STATE_BY_SESSION: dict[str, dict[str, dict]] = {}


def _is_valid_table_state_payload(data: dict, session_id: str) -> bool:
    """Базовая валидация table_state без падения WS."""
    schema_version = data.get("schema_version")
    if schema_version != 1:
        return False

    event_seq = data.get("event_seq")
    if isinstance(event_seq, bool) or not isinstance(event_seq, int):
        return False

    round_id = data.get("round_id")
    if not isinstance(round_id, str) or not round_id.strip():
        return False

    payload_session_id = data.get("session_id")
    if payload_session_id is not None and str(payload_session_id).strip() != str(session_id).strip():
        return False

    return True


def _cache_table_state_if_newer(session_id: str, dealer_id: str, payload: dict) -> bool:
    """Кэширует table_state только если event_seq строго больше предыдущего.

    Returns:
        True если кэш обновлен, иначе False.
    """
    event_seq = payload.get("event_seq")
    if isinstance(event_seq, bool) or not isinstance(event_seq, int):
        return False

    by_dealer = _LATEST_TABLE_STATE_BY_SESSION.setdefault(session_id, {})
    prev = by_dealer.get(dealer_id)
    if isinstance(prev, dict):
        prev_seq = prev.get("event_seq")
        if isinstance(prev_seq, int) and event_seq <= prev_seq:
            return False

    by_dealer[dealer_id] = payload
    return True


def _get_cached_table_states_for_session(session_id: str) -> list[dict]:
    """Возвращает копии последних table_state для заданной сессии."""
    by_dealer = _LATEST_TABLE_STATE_BY_SESSION.get(session_id, {})
    if not isinstance(by_dealer, dict) or not by_dealer:
        return []
    states: list[dict] = []
    for payload in by_dealer.values():
        if isinstance(payload, dict):
            states.append(dict(payload))
    return states


def _merge_live_payload_with_listener_dealer(data: dict, listener_id: str) -> dict:
    """dealer_id из токена — единственный источник правды."""
    return {**data, "dealer_id": listener_id}


def _new_master_seed() -> str:
    return secrets.token_hex(32)


def _round_seed(master_seed: str, round_number: int) -> str:
    payload = f"{master_seed}:round:{round_number}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


async def _get_room_by_code(db: AsyncSession, room_code: str) -> Room:
    room_res = await db.execute(select(Room).where(Room.room_code == room_code))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


async def _get_active_live_session_for_room(db: AsyncSession, room_id: uuid.UUID) -> Session | None:
    session_res = await db.execute(
        select(Session).where(
            Session.room_id == room_id,
            Session.status.in_([SessionStatus.CREATED, SessionStatus.ACTIVE]),
            Session.type == SessionType.LIVE,
        )
    )
    return session_res.scalar_one_or_none()


def _active_live_session_to_response(room: Room, session_obj: Session) -> ActiveLiveSessionResponse:
    round_seed: str | None = None
    if session_obj.status == SessionStatus.ACTIVE:
        round_seed = _round_seed(session_obj.master_seed, 1)
    return ActiveLiveSessionResponse(
        session_id=str(session_obj.id),
        room_code=room.room_code,
        status=session_obj.status.value,
        websocket_url=f"/ws/sessions/{session_obj.id}",
        round_seed=round_seed,
        started_at=session_obj.started_at,
        duration_seconds=session_obj.duration_seconds,
    )


async def _get_session_or_404(db: AsyncSession, session_id: str) -> Session:
    try:
        session_uuid = uuid.UUID(session_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Session not found")

    result = await db.execute(select(Session).where(Session.id == session_uuid))
    session_obj = result.scalar_one_or_none()
    if not session_obj:
        raise HTTPException(status_code=404, detail="Session not found")
    return session_obj


def _classify_error_message(msg: str) -> str:
    m = (msg or "").lower()
    if "banker" in m and "third" in m:
        return "third_card_banker"
    if "player" in m and "third" in m:
        return "third_card_player"
    if "winner" in m:
        return "winner_decision"
    if "payout" in m and "pair" in m and "banker" in m:
        return "payout_banker_pair"
    if "payout" in m and "pair" in m and "player" in m:
        return "payout_player_pair"
    if "payout" in m and "tie" in m:
        return "payout_tie"
    if "payout" in m and "banker" in m:
        return "payout_banker"
    if "payout" in m and "player" in m:
        return "payout_player"
    if "chip" in m and "order" in m:
        return "chip_collection_order"
    if "chip" in m:
        return "chip_handling_sequence"
    return "other"


def _normalize_error_entry(err: dict | str) -> dict:
    if isinstance(err, dict):
        msg = str(err.get("message", "")).strip()
        category = str(err.get("category", "")).strip() or _classify_error_message(msg)
        return {
            "category": category or "other",
            "message": msg or "Unknown error",
            "context": err.get("context", {}),
        }
    txt = str(err)
    return {"category": _classify_error_message(txt), "message": txt, "context": {}}


@router.post("/rooms/{room_code}/sessions", response_model=SessionCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_live_session(
    room_code: str,
    body: SessionCreateRequest,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Создать live-сессию для комнаты."""
    room_res = await db.execute(select(Room).where(Room.room_code == room_code))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=403, detail="Not room owner")
    if room.status != RoomStatus.ACTIVE:
        raise HTTPException(status_code=409, detail="Room is not active")

    active_res = await db.execute(
        select(Session).where(
            Session.room_id == room.id,
            Session.status.in_([SessionStatus.CREATED, SessionStatus.ACTIVE]),
            Session.type == SessionType.LIVE,
        )
    )
    if active_res.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Room already has active session")

    duration_seconds = body.duration_minutes * 60
    session_obj = Session(
        room_id=room.id,
        trainer_id=trainer.id,
        status=SessionStatus.CREATED,
        type=SessionType.LIVE,
        master_seed=_new_master_seed(),
        duration_seconds=duration_seconds,
        max_rounds=body.max_rounds,
        end_reason=None,
        created_by=trainer.id,
    )
    db.add(session_obj)
    room.total_sessions += 1
    room.last_session_at = datetime.now(timezone.utc)

    await db.flush()
    await db.refresh(session_obj)

    return SessionCreateResponse(
        session_id=str(session_obj.id),
        room_code=room.room_code,
        status=session_obj.status.value,
        duration_seconds=session_obj.duration_seconds,
        max_rounds=session_obj.max_rounds,
        websocket_url=f"/ws/sessions/{session_obj.id}",
        created_at=session_obj.created_at,
    )


@router.get("/rooms/{room_code}/active-live-session", response_model=ActiveLiveSessionResponse)
async def get_active_live_session_for_dealer(
    room_code: str,
    dealer: Dealer = Depends(get_current_dealer),
    db: AsyncSession = Depends(get_db),
):
    """Текущая live-сессия комнаты (дилер ждёт тренера и подключается к WS по session_id)."""
    room = await _get_room_by_code(db, room_code)
    if dealer.room_id != room.id:
        raise HTTPException(status_code=403, detail="Dealer is not in this room")

    session_obj = await _get_active_live_session_for_room(db, room.id)
    if not session_obj:
        raise HTTPException(status_code=404, detail="No active live session")

    return _active_live_session_to_response(room, session_obj)


@router.get("/rooms/{room_code}/trainer-live-session", response_model=ActiveLiveSessionResponse)
async def get_active_live_session_for_trainer(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Текущая live-сессия комнаты для тренера (веб-дашборд, без WebSocket)."""
    room = await _get_room_by_code(db, room_code)
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=403, detail="Not room owner")

    session_obj = await _get_active_live_session_for_room(db, room.id)
    if not session_obj:
        raise HTTPException(status_code=404, detail="No active live session")

    return _active_live_session_to_response(room, session_obj)


@router.post("/sessions/{session_id}/start", response_model=SessionStartResponse)
async def start_live_session(
    session_id: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Запустить live-сессию."""
    session_obj = await _get_session_or_404(db, session_id)
    if session_obj.trainer_id != trainer.id:
        raise HTTPException(status_code=403, detail="Not session owner")
    if session_obj.status != SessionStatus.CREATED:
        raise HTTPException(status_code=409, detail="Session already started or finished")

    session_obj.status = SessionStatus.ACTIVE
    session_obj.started_at = datetime.now(timezone.utc)

    await ws_manager.broadcast(
        session_id=str(session_obj.id),
        event_type="session_started",
        data={
            "session_id": str(session_obj.id),
            "started_at": session_obj.started_at.isoformat(),
            "duration_seconds": session_obj.duration_seconds,
            "max_rounds": session_obj.max_rounds,
            "round_seed": _round_seed(session_obj.master_seed, 1),
        },
    )

    return SessionStartResponse(
        message="Session started",
        session_id=str(session_obj.id),
        status=session_obj.status.value,
        started_at=session_obj.started_at,
    )


@router.post("/sessions/{session_id}/end", response_model=SessionEndResponse)
async def end_live_session(
    session_id: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Завершить live-сессию вручную."""
    session_obj = await _get_session_or_404(db, session_id)
    if session_obj.trainer_id != trainer.id:
        raise HTTPException(status_code=403, detail="Not session owner")
    if session_obj.status not in [SessionStatus.CREATED, SessionStatus.ACTIVE]:
        raise HTTPException(status_code=409, detail="Session already completed")

    session_obj.status = SessionStatus.COMPLETED
    session_obj.ended_at = datetime.now(timezone.utc)
    session_obj.end_reason = "trainer_end"

    await ws_manager.broadcast(
        session_id=str(session_obj.id),
        event_type="session_ended",
        data={
            "session_id": str(session_obj.id),
            "ended_at": session_obj.ended_at.isoformat(),
            "reason": session_obj.end_reason,
        },
    )

    return SessionEndResponse(
        message="Session ended",
        session_id=str(session_obj.id),
        status=session_obj.status.value,
        ended_at=session_obj.ended_at,
        end_reason=session_obj.end_reason,
    )


@router.post("/sessions/{session_id}/round-results", status_code=status.HTTP_201_CREATED)
async def submit_round_result(
    session_id: str,
    body: RoundResultIn,
    dealer: Dealer = Depends(get_current_dealer),
    db: AsyncSession = Depends(get_db),
):
    """Сохранить результат раунда дилера (детальные ошибки/ставки)."""
    session_obj = await _get_session_or_404(db, session_id)
    if session_obj.status != SessionStatus.ACTIVE:
        raise HTTPException(status_code=409, detail="Session is not active")
    if dealer.room_id != session_obj.room_id:
        raise HTTPException(status_code=403, detail="Dealer does not belong to this room")

    participant_res = await db.execute(
        select(SessionParticipant).where(
            SessionParticipant.session_id == session_obj.id,
            SessionParticipant.dealer_id == dealer.id,
        )
    )
    participant = participant_res.scalar_one_or_none()
    if not participant:
        participant = SessionParticipant(
            session_id=session_obj.id,
            dealer_id=dealer.id,
            status="active",
        )
        db.add(participant)
        await db.flush()

    existing_res = await db.execute(
        select(RoundResult).where(
            RoundResult.session_id == session_obj.id,
            RoundResult.dealer_id == dealer.id,
            RoundResult.round_number == body.round_number,
        )
    )
    if existing_res.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Round result already submitted")

    stored_errors = list(body.errors)
    if body.round_context:
        stored_errors.append(
            {
                "category": "_round_context",
                "message": "round_context",
                "context": body.round_context,
            }
        )

    result = RoundResult(
        session_id=session_obj.id,
        dealer_id=dealer.id,
        round_number=body.round_number,
        accuracy=body.accuracy,
        errors=stored_errors,
        time_spent_seconds=body.time_spent_seconds,
        player_third_card=body.player_third_card,
        banker_third_card=body.banker_third_card,
        winner_chosen=body.winner_chosen,
        winner_correct=body.winner_correct,
        payout_correct=body.payout_correct,
        lives_remaining=body.lives_remaining,
        round_xp=0,
    )
    db.add(result)

    participant.rounds_completed += 1
    dealer.last_seen_at = datetime.now(timezone.utc)

    room_res = await db.execute(select(Room).where(Room.id == session_obj.room_id))
    room = room_res.scalar_one_or_none()
    if room:
        room.total_rounds += 1

    await ws_manager.broadcast(
        session_id=str(session_obj.id),
        event_type="dealer_update",
        data={
            "dealer_id": str(dealer.id),
            "display_name": dealer.display_name,
            "round_number": body.round_number,
            "accuracy": body.accuracy,
            "errors_count": len(body.errors),
        },
    )

    next_rn = body.round_number + 1
    await ws_manager.broadcast(
        session_id=str(session_obj.id),
        event_type="round_sync",
        data={
            "completed_round": body.round_number,
            "next_round_number": next_rn,
            "round_seed": _round_seed(session_obj.master_seed, next_rn),
        },
    )

    return {"message": "Round result saved"}


@router.get("/sessions/{session_id}/results", response_model=SessionResultsResponse)
async def get_session_results(
    session_id: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Получить агрегированные результаты сессии для тренера."""
    session_obj = await _get_session_or_404(db, session_id)
    if session_obj.trainer_id != trainer.id:
        raise HTTPException(status_code=403, detail="Not session owner")

    participants_count_res = await db.execute(
        select(func.count(SessionParticipant.id)).where(SessionParticipant.session_id == session_obj.id)
    )
    total_participants = participants_count_res.scalar() or 0

    results_count_res = await db.execute(
        select(func.count(RoundResult.id)).where(RoundResult.session_id == session_obj.id)
    )
    total_round_results = results_count_res.scalar() or 0

    room_dealers_res = await db.execute(
        select(Dealer.id, Dealer.display_name)
        .where(Dealer.room_id == session_obj.room_id, Dealer.is_active == True)
        .order_by(Dealer.display_name)
    )
    room_dealers = room_dealers_res.all()

    dealers = []
    for dealer_id, display_name in room_dealers:
        rr_res = await db.execute(
            select(RoundResult).where(
                RoundResult.session_id == session_obj.id,
                RoundResult.dealer_id == dealer_id,
            )
        )
        rows = rr_res.scalars().all()
        rounds_count = len(rows)
        avg_accuracy = (
            sum(float(r.accuracy or 0.0) for r in rows) / float(rounds_count)
            if rounds_count > 0
            else 0.0
        )
        cards_errors = 0
        payout_errors = 0
        chips_errors = 0
        errors_total = 0
        for row in rows:
            raw_errors = row.errors or []
            if not isinstance(raw_errors, list):
                raw_errors = [raw_errors]
            for err in raw_errors:
                nerr = _normalize_error_entry(err)
                cat = str(nerr.get("category", ""))
                if cat == "_round_context":
                    continue
                errors_total += 1
                if cat in ("third_card_player", "third_card_banker", "winner_decision", "other"):
                    cards_errors += 1
                elif cat.startswith("payout_"):
                    payout_errors += 1
                elif cat.startswith("chip_"):
                    chips_errors += 1

        part_res = await db.execute(
            select(SessionParticipant).where(
                SessionParticipant.session_id == session_obj.id,
                SessionParticipant.dealer_id == dealer_id,
            )
        )
        participant = part_res.scalar_one_or_none()
        live_seconds = 0
        if participant and participant.joined_at:
            end_ts = participant.left_at or datetime.now(timezone.utc)
            live_seconds = max(0, int((end_ts - participant.joined_at).total_seconds()))
        dealers.append(
            {
                "dealer_id": str(dealer_id),
                "display_name": display_name,
                "rounds_completed": int(rounds_count or 0),
                "avg_accuracy": float(avg_accuracy or 0),
                "errors_total": int(errors_total or 0),
                "cards_errors": int(cards_errors),
                "payout_errors": int(payout_errors),
                "chips_errors": int(chips_errors),
                "live_seconds": int(live_seconds),
            }
        )

    return SessionResultsResponse(
        session_id=str(session_obj.id),
        status=session_obj.status.value,
        total_participants=int(total_participants),
        total_round_results=int(total_round_results),
        dealers=dealers,
    )


@router.get("/sessions/{session_id}/dealers/{dealer_id}/rounds")
async def get_dealer_rounds_for_trainer(
    session_id: str,
    dealer_id: str,
    limit: int = Query(default=100, ge=1, le=300),
    offset: int = Query(default=0, ge=0),
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Детальная история раундов одного дилера в live-сессии (для карточки тренера)."""
    session_obj = await _get_session_or_404(db, session_id)
    if session_obj.trainer_id != trainer.id:
        raise HTTPException(status_code=403, detail="Not session owner")

    try:
        dealer_uuid = uuid.UUID(dealer_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Dealer not found")

    dealer_res = await db.execute(
        select(Dealer).where(Dealer.id == dealer_uuid, Dealer.room_id == session_obj.room_id)
    )
    dealer_obj = dealer_res.scalar_one_or_none()
    if not dealer_obj:
        raise HTTPException(status_code=404, detail="Dealer not found")

    rows_res = await db.execute(
        select(RoundResult)
        .where(RoundResult.session_id == session_obj.id, RoundResult.dealer_id == dealer_uuid)
        .order_by(RoundResult.round_number.desc(), RoundResult.submitted_at.desc())
        .offset(offset)
        .limit(limit)
    )
    rows = rows_res.scalars().all()

    items = []
    for r in rows:
        raw_errors = r.errors or []
        if not isinstance(raw_errors, list):
            raw_errors = [str(raw_errors)]
        normalized_errors = []
        round_context: dict = {}
        for err in raw_errors:
            nerr = _normalize_error_entry(err)
            if nerr["category"] == "_round_context":
                if isinstance(nerr.get("context"), dict):
                    round_context = nerr["context"]
                continue
            normalized_errors.append(nerr)
        items.append(
            {
                "round_number": r.round_number,
                "submitted_at": r.submitted_at,
                "accuracy": float(r.accuracy),
                "time_spent_seconds": int(r.time_spent_seconds),
                "player_third_card": r.player_third_card,
                "banker_third_card": r.banker_third_card,
                "winner_chosen": r.winner_chosen,
                "winner_correct": r.winner_correct,
                "payout_correct": r.payout_correct,
                "round_context": round_context,
                "errors": normalized_errors,
            }
        )

    return {
        "session_id": str(session_obj.id),
        "dealer_id": str(dealer_obj.id),
        "dealer_name": dealer_obj.display_name,
        "limit": limit,
        "offset": offset,
        "rounds": items,
    }


@ws_router.websocket("/ws/sessions/{session_id}")
async def session_ws(
    websocket: WebSocket,
    session_id: str,
    token: str = Query(default=""),
):
    """WebSocket live-сессии: дилеры и владелец-сессии (тренер) получают broadcast-события."""
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            await websocket.close(code=1008, reason="Invalid token type")
            return
        role = payload.get("role")
        if role not in ("dealer", "trainer"):
            await websocket.close(code=1008, reason="Invalid role")
            return
    except Exception:
        await websocket.close(code=1008, reason="Invalid token")
        return

    user_sub = payload.get("sub")
    if not user_sub:
        await websocket.close(code=1008, reason="Invalid token payload")
        return

    try:
        session_uuid = uuid.UUID(session_id)
    except ValueError:
        await websocket.close(code=1008, reason="Invalid session id")
        return

    async with async_session_factory() as db:
        result = await db.execute(select(Session).where(Session.id == session_uuid))
        session_obj = result.scalar_one_or_none()
        if not session_obj:
            await websocket.close(code=1008, reason="Session not found")
            return

        if role == "trainer":
            try:
                trainer_uuid = uuid.UUID(user_sub)
            except ValueError:
                await websocket.close(code=1008, reason="Invalid token payload")
                return
            trainer_res = await db.execute(select(Trainer).where(Trainer.id == trainer_uuid))
            trainer_row = trainer_res.scalar_one_or_none()
            if trainer_row is None or trainer_row.id != session_obj.trainer_id:
                await websocket.close(code=1008, reason="Not session owner")
                return
        else:
            try:
                dealer_uuid = uuid.UUID(user_sub)
            except ValueError:
                await websocket.close(code=1008, reason="Invalid token payload")
                return
            dealer_res = await db.execute(select(Dealer).where(Dealer.id == dealer_uuid))
            dealer_row = dealer_res.scalar_one_or_none()
            if dealer_row is None or dealer_row.room_id != session_obj.room_id:
                await websocket.close(code=1008, reason="Dealer not in session room")
                return

    listener_role: str = role
    listener_id: str = user_sub

    await ws_manager.connect(session_id, websocket)
    if listener_role == "trainer":
        # Безопаснее всегда отправлять sync (даже пустой) как явный hand-shake.
        # Это позволяет клиенту не гадать, есть ли уже состояние в сессии.
        await websocket.send_json(
            {
                "type": "table_state_sync",
                "data": {"states": _get_cached_table_states_for_session(session_id)},
            }
        )
    if listener_role == "dealer":
        await ws_manager.broadcast(
            session_id=session_id,
            event_type="dealer_joined",
            data={"dealer_id": listener_id, "online_count": ws_manager.online_count(session_id)},
        )

    try:
        while True:
            message = await websocket.receive_json()
            message_type = message.get("type")
            if message_type == "heartbeat":
                await websocket.send_json(
                    {
                        "type": "heartbeat_ack",
                        "data": {"server_time": datetime.now(timezone.utc).isoformat()},
                    }
                )
            elif message_type == "ready" and listener_role == "dealer":
                await ws_manager.broadcast(
                    session_id=session_id,
                    event_type="dealer_ready",
                    data={"dealer_id": listener_id},
                )
            elif listener_role == "dealer" and message_type in _LIVE_MONITOR_TYPES:
                raw_data = message.get("data")
                if not isinstance(raw_data, dict):
                    if message_type == "table_state":
                        print(f"[WS] skip invalid table_state data type: session={session_id} dealer={listener_id}")
                        continue
                    data: dict = {}
                else:
                    data = raw_data

                if message_type == "table_state" and not _is_valid_table_state_payload(data, session_id):
                    print(f"[WS] skip invalid table_state payload: session={session_id} dealer={listener_id}")
                    continue

                merged = _merge_live_payload_with_listener_dealer(data, listener_id)
                try:
                    if len(json.dumps(merged, ensure_ascii=False)) > _LIVE_MONITOR_MAX_JSON_BYTES:
                        if message_type == "table_state":
                            print(f"[WS] skip oversized table_state payload: session={session_id} dealer={listener_id}")
                        continue
                except (TypeError, ValueError):
                    if message_type == "table_state":
                        print(f"[WS] skip non-serializable table_state payload: session={session_id} dealer={listener_id}")
                    continue
                if message_type == "table_state":
                    updated = _cache_table_state_if_newer(session_id, listener_id, merged)
                    if not updated:
                        print(f"[WS] skip table_state cache update (old/duplicate seq): session={session_id} dealer={listener_id}")
                await ws_manager.broadcast(
                    session_id=session_id,
                    event_type=message_type,
                    data=merged,
                )
    except WebSocketDisconnect:
        ws_manager.disconnect(session_id, websocket)
        if listener_role == "dealer":
            await ws_manager.broadcast(
                session_id=session_id,
                event_type="dealer_left",
                data={"dealer_id": listener_id, "online_count": ws_manager.online_count(session_id)},
            )
