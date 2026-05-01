"""Dealer-side activation for personal room access codes."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.dealer import Dealer
from app.models.participant_token import ParticipantToken, ParticipantTokenStatus
from app.models.room import Room, RoomStatus
from app.models.room_access import RoomAccess, RoomAccessStatus
from app.models.room_invite import RoomInvite, RoomInviteStatus
from app.models.session import Session, SessionStatus, SessionType
from app.schemas.dealer_access import (
    DealerAccessActivateRequest,
    DealerAccessActivateResponse,
    DealerAccessDealerResponse,
    DealerAccessInfoResponse,
    DealerInviteActivateRequest,
    DealerAccessRoomResponse,
    DealerMyRoomAccessInfo,
    DealerMyRoomActiveSessionInfo,
    DealerMyRoomDealerInfo,
    DealerMyRoomItem,
    DealerMyRoomRoomInfo,
    DealerMyRoomsRequest,
    DealerMyRoomsResponse,
    DealerTokenExchangeAccessInfo,
    DealerTokenExchangeDealerInfo,
    DealerTokenExchangeRequest,
    DealerTokenExchangeResponse,
    InvalidParticipantTokenInfo,
)
from app.utils.access_codes import (
    generate_participant_token,
    hash_participant_token,
    hash_room_access_code,
    hash_room_invite_code,
    normalize_room_access_code,
)
from app.utils.auth import create_access_token

router = APIRouter(prefix="/dealer/accesses")
invite_router = APIRouter(prefix="/dealer/invites")
my_rooms_router = APIRouter(prefix="/dealer")


def activation_error(status_code: int, code: str, message: str) -> HTTPException:
    return HTTPException(status_code=status_code, detail={"code": code, "message": message})


async def generate_unique_participant_token(db: AsyncSession) -> tuple[str, str]:
    """Generate plaintext participant token and unique lookup hash."""
    for _ in range(20):
        token = generate_participant_token()
        token_hash = hash_participant_token(token)
        exists_res = await db.execute(
            select(ParticipantToken.id).where(ParticipantToken.token_hash == token_hash)
        )
        if not exists_res.scalar_one_or_none():
            return token, token_hash

    raise activation_error(
        status.HTTP_500_INTERNAL_SERVER_ERROR,
        "PARTICIPANT_TOKEN_GENERATION_FAILED",
        "Could not generate participant token",
    )


def room_status_value(room: Room) -> str:
    return room.status.value if hasattr(room.status, "value") else str(room.status)


def session_status_value(session_obj: Session) -> str:
    return session_obj.status.value if hasattr(session_obj.status, "value") else str(session_obj.status)


async def get_current_live_session(db: AsyncSession, room_id) -> Session | None:
    session_res = await db.execute(
        select(Session)
        .where(
            Session.room_id == room_id,
            Session.status.in_([SessionStatus.CREATED, SessionStatus.ACTIVE]),
            Session.type == SessionType.LIVE,
        )
        .order_by(Session.created_at.desc())
    )
    return session_res.scalars().first()


def room_is_closed(room: Room) -> bool:
    return room.status == RoomStatus.CLOSED or room_status_value(room) == RoomStatus.CLOSED.value


def sync_room_invite_status(invite: RoomInvite, now: datetime) -> bool:
    if invite.status == RoomInviteStatus.ACTIVE and invite.expires_at <= now:
        invite.status = RoomInviteStatus.EXPIRED
        return True
    return False


def invite_item_availability(
    token_entry: ParticipantToken,
    dealer: Dealer,
    room: Room,
    active_session: Session | None,
) -> str:
    if token_entry.status == ParticipantTokenStatus.REVOKED:
        return "revoked"
    if token_entry.status == ParticipantTokenStatus.EXPIRED:
        return "expired"
    if not dealer.is_active:
        return "revoked"
    if room_is_closed(room):
        return "closed"
    if active_session and active_session.status == SessionStatus.ACTIVE:
        return "online"
    return "offline"


def room_item_availability(
    token_entry: ParticipantToken,
    access: RoomAccess,
    dealer: Dealer,
    room: Room,
    active_session: Session | None,
) -> str:
    if token_entry.status == ParticipantTokenStatus.REVOKED:
        return "revoked"
    if token_entry.status == ParticipantTokenStatus.EXPIRED:
        return "expired"
    if access.status == RoomAccessStatus.REVOKED or not dealer.is_active:
        return "revoked"
    if access.status == RoomAccessStatus.CLOSED or room_is_closed(room):
        return "closed"
    if active_session and active_session.status == SessionStatus.ACTIVE:
        return "online"
    return "offline"


@router.post("/activate", response_model=DealerAccessActivateResponse)
async def activate_dealer_access(
    body: DealerAccessActivateRequest,
    db: AsyncSession = Depends(get_db),
):
    """Activate a one-time room access code and issue a participant token."""
    display_name = body.display_name.strip()
    if not display_name:
        raise activation_error(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "DISPLAY_NAME_REQUIRED",
            "Display name is required",
        )

    normalized_code = normalize_room_access_code(body.access_code)
    if not normalized_code:
        raise activation_error(
            status.HTTP_404_NOT_FOUND,
            "INVALID_ACCESS_CODE",
            "Invalid access code",
        )

    access_code_hash = hash_room_access_code(normalized_code)
    access_res = await db.execute(
        select(RoomAccess)
        .where(RoomAccess.access_code_hash == access_code_hash)
        .with_for_update()
    )
    access = access_res.scalar_one_or_none()

    if not access:
        raise activation_error(
            status.HTTP_404_NOT_FOUND,
            "INVALID_ACCESS_CODE",
            "Invalid access code",
        )

    if access.status == RoomAccessStatus.ACTIVATED:
        raise activation_error(
            status.HTTP_409_CONFLICT,
            "ACCESS_ALREADY_ACTIVATED",
            "This access code has already been activated",
        )
    if access.status == RoomAccessStatus.REVOKED:
        raise activation_error(
            status.HTTP_403_FORBIDDEN,
            "ACCESS_REVOKED",
            "This access has been revoked",
        )
    if access.status == RoomAccessStatus.CLOSED:
        raise activation_error(
            status.HTTP_410_GONE,
            "ACCESS_CLOSED",
            "This access is closed",
        )
    if access.status != RoomAccessStatus.CREATED or access.dealer_id:
        raise activation_error(
            status.HTTP_409_CONFLICT,
            "ACCESS_NOT_ACTIVATABLE",
            "This access cannot be activated",
        )

    room_res = await db.execute(select(Room).where(Room.id == access.room_id))
    room = room_res.scalar_one_or_none()
    if not room:
        raise activation_error(
            status.HTTP_404_NOT_FOUND,
            "ROOM_NOT_FOUND",
            "Room not found",
        )
    if room.status == RoomStatus.CLOSED:
        raise activation_error(
            status.HTTP_410_GONE,
            "ROOM_CLOSED",
            "This room is closed",
        )

    now = datetime.now(timezone.utc)
    dealer = Dealer(
        room_id=room.id,
        display_name=display_name,
        is_active=True,
        last_seen_at=now,
    )
    db.add(dealer)
    await db.flush()

    participant_token, token_hash = await generate_unique_participant_token(db)
    token_entry = ParticipantToken(
        room_access_id=access.id,
        dealer_id=dealer.id,
        token_hash=token_hash,
        status=ParticipantTokenStatus.ACTIVE,
        last_used_at=now,
    )
    db.add(token_entry)

    access.dealer_id = dealer.id
    access.status = RoomAccessStatus.ACTIVATED
    access.activated_at = now
    access.last_used_at = now
    room.total_dealers = int(room.total_dealers or 0) + 1

    await db.commit()
    await db.refresh(dealer)
    await db.refresh(access)
    await db.refresh(room)

    return DealerAccessActivateResponse(
        participant_token=participant_token,
        token_type="Participant",
        room=DealerAccessRoomResponse(
            id=str(room.id),
            room_code=room.room_code,
            name=room.name,
            status=room_status_value(room),
        ),
        dealer=DealerAccessDealerResponse(
            id=str(dealer.id),
            display_name=dealer.display_name,
            role="dealer",
        ),
        access=DealerAccessInfoResponse(
            id=str(access.id),
            slot_number=access.slot_number,
            status=access.status,
            access_code_suffix=access.access_code_suffix,
            trainer_internal_name=access.trainer_internal_name,
            activated_at=access.activated_at,
        ),
    )


@invite_router.post("/activate", response_model=DealerAccessActivateResponse)
async def activate_room_invite(
    body: DealerInviteActivateRequest,
    db: AsyncSession = Depends(get_db),
):
    """Activate a shared room invite code and issue a participant token."""
    display_name = body.display_name.strip()
    if not display_name:
        raise activation_error(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "DISPLAY_NAME_REQUIRED",
            "Display name is required",
        )

    normalized_code = normalize_room_access_code(body.invite_code)
    if not normalized_code:
        raise activation_error(
            status.HTTP_404_NOT_FOUND,
            "INVALID_INVITE_CODE",
            "Invalid invite code",
        )

    invite_code_hash = hash_room_invite_code(normalized_code)
    invite_res = await db.execute(
        select(RoomInvite)
        .where(RoomInvite.invite_code_hash == invite_code_hash)
        .with_for_update()
    )
    invite = invite_res.scalar_one_or_none()

    if not invite:
        raise activation_error(
            status.HTTP_404_NOT_FOUND,
            "INVALID_INVITE_CODE",
            "Invalid invite code",
        )

    now = datetime.now(timezone.utc)
    invite_changed = sync_room_invite_status(invite, now)
    if invite.status == RoomInviteStatus.REVOKED:
        if invite_changed:
            await db.commit()
        raise activation_error(
            status.HTTP_403_FORBIDDEN,
            "INVITE_REVOKED",
            "This invite has been revoked",
        )
    if invite.status == RoomInviteStatus.EXPIRED:
        if invite_changed:
            await db.commit()
        raise activation_error(
            status.HTTP_410_GONE,
            "INVITE_EXPIRED",
            "This invite has expired",
        )
    if invite.status != RoomInviteStatus.ACTIVE:
        if invite_changed:
            await db.commit()
        raise activation_error(
            status.HTTP_409_CONFLICT,
            "INVITE_NOT_ACTIVE",
            "This invite is not active",
        )

    room_res = await db.execute(select(Room).where(Room.id == invite.room_id))
    room = room_res.scalar_one_or_none()
    if not room:
        raise activation_error(
            status.HTTP_404_NOT_FOUND,
            "ROOM_NOT_FOUND",
            "Room not found",
        )
    if room.status == RoomStatus.CLOSED:
        raise activation_error(
            status.HTTP_410_GONE,
            "ROOM_CLOSED",
            "This room is closed",
        )

    dealer = Dealer(
        room_id=room.id,
        display_name=display_name,
        is_active=True,
        last_seen_at=now,
    )
    db.add(dealer)
    await db.flush()

    participant_token, token_hash = await generate_unique_participant_token(db)
    token_entry = ParticipantToken(
        room_access_id=None,
        room_invite_id=invite.id,
        dealer_id=dealer.id,
        token_hash=token_hash,
        status=ParticipantTokenStatus.ACTIVE,
        last_used_at=now,
    )
    db.add(token_entry)

    room.total_dealers = int(room.total_dealers or 0) + 1

    await db.commit()
    await db.refresh(dealer)
    await db.refresh(invite)
    await db.refresh(room)

    return DealerAccessActivateResponse(
        participant_token=participant_token,
        token_type="Participant",
        room=DealerAccessRoomResponse(
            id=str(room.id),
            room_code=room.room_code,
            name=room.name,
            status=room_status_value(room),
        ),
        dealer=DealerAccessDealerResponse(
            id=str(dealer.id),
            display_name=dealer.display_name,
            role="dealer",
        ),
        access=DealerAccessInfoResponse(
            id=str(invite.id),
            kind="room_invite",
            slot_number=None,
            status=invite.status,
            access_code_suffix=invite.invite_code_suffix,
            trainer_internal_name=None,
            activated_at=now,
        ),
    )


@my_rooms_router.post("/my-rooms", response_model=DealerMyRoomsResponse)
async def get_dealer_my_rooms(
    body: DealerMyRoomsRequest,
    db: AsyncSession = Depends(get_db),
):
    """Return rooms available through locally stored participant tokens."""
    rooms: list[DealerMyRoomItem] = []
    invalid_tokens: list[InvalidParticipantTokenInfo] = []
    now = datetime.now(timezone.utc)
    touched_active_token = False

    for index, raw_token in enumerate(body.participant_tokens):
        token = raw_token.strip() if isinstance(raw_token, str) else ""
        if not token or not token.startswith("pt_"):
            invalid_tokens.append(InvalidParticipantTokenInfo(index=index, reason="invalid_format"))
            continue

        token_hash = hash_participant_token(token)
        token_res = await db.execute(
            select(ParticipantToken).where(ParticipantToken.token_hash == token_hash)
        )
        token_entry = token_res.scalar_one_or_none()
        if not token_entry:
            invalid_tokens.append(InvalidParticipantTokenInfo(index=index, reason="not_found"))
            continue

        dealer = await db.get(Dealer, token_entry.dealer_id)
        if not dealer:
            invalid_tokens.append(InvalidParticipantTokenInfo(index=index, reason="not_found"))
            continue

        if token_entry.room_access_id:
            access = await db.get(RoomAccess, token_entry.room_access_id)
            if not access:
                invalid_tokens.append(InvalidParticipantTokenInfo(index=index, reason="not_found"))
                continue

            room = await db.get(Room, access.room_id)
            if not room:
                invalid_tokens.append(InvalidParticipantTokenInfo(index=index, reason="not_found"))
                continue

            active_session = None
            if (
                token_entry.status == ParticipantTokenStatus.ACTIVE
                and access.status == RoomAccessStatus.ACTIVATED
                and dealer.is_active
                and not room_is_closed(room)
            ):
                active_session = await get_current_live_session(db, room.id)
                token_entry.last_used_at = now
                access.last_used_at = now
                touched_active_token = True

            availability = room_item_availability(token_entry, access, dealer, room, active_session)
            rooms.append(
                DealerMyRoomItem(
                    room=DealerMyRoomRoomInfo(
                        id=str(room.id),
                        room_code=room.room_code,
                        name=room.name,
                        status=room_status_value(room),
                    ),
                    access=DealerMyRoomAccessInfo(
                        id=str(access.id),
                        kind="room_access",
                        slot_number=access.slot_number,
                        status=access.status,
                        access_code_suffix=access.access_code_suffix,
                        trainer_internal_name=access.trainer_internal_name,
                    ),
                    dealer=DealerMyRoomDealerInfo(
                        id=str(dealer.id),
                        display_name=dealer.display_name,
                    ),
                    participant_token_status=token_entry.status,
                    availability=availability,
                    active_session=(
                        DealerMyRoomActiveSessionInfo(
                            id=str(active_session.id),
                            status=session_status_value(active_session),
                        )
                        if active_session
                        else None
                    ),
                )
            )
            continue

        if token_entry.room_invite_id:
            invite = await db.get(RoomInvite, token_entry.room_invite_id)
            if not invite:
                invalid_tokens.append(InvalidParticipantTokenInfo(index=index, reason="not_found"))
                continue

            changed = sync_room_invite_status(invite, now)
            room = await db.get(Room, invite.room_id)
            if not room:
                invalid_tokens.append(InvalidParticipantTokenInfo(index=index, reason="not_found"))
                continue

            active_session = None
            if (
                token_entry.status == ParticipantTokenStatus.ACTIVE
                and dealer.is_active
                and not room_is_closed(room)
            ):
                active_session = await get_current_live_session(db, room.id)
                token_entry.last_used_at = now
                touched_active_token = True

            if changed:
                touched_active_token = True

            availability = invite_item_availability(token_entry, dealer, room, active_session)
            rooms.append(
                DealerMyRoomItem(
                    room=DealerMyRoomRoomInfo(
                        id=str(room.id),
                        room_code=room.room_code,
                        name=room.name,
                        status=room_status_value(room),
                    ),
                    access=DealerMyRoomAccessInfo(
                        id=str(invite.id),
                        kind="room_invite",
                        slot_number=None,
                        status=invite.status,
                        access_code_suffix=invite.invite_code_suffix,
                        trainer_internal_name=None,
                    ),
                    dealer=DealerMyRoomDealerInfo(
                        id=str(dealer.id),
                        display_name=dealer.display_name,
                    ),
                    participant_token_status=token_entry.status,
                    availability=availability,
                    active_session=(
                        DealerMyRoomActiveSessionInfo(
                            id=str(active_session.id),
                            status=session_status_value(active_session),
                        )
                        if active_session
                        else None
                    ),
                )
            )
            continue

        invalid_tokens.append(InvalidParticipantTokenInfo(index=index, reason="not_found"))

    if touched_active_token:
        await db.commit()

    return DealerMyRoomsResponse(rooms=rooms, invalid_tokens=invalid_tokens)


@my_rooms_router.post("/tokens/exchange", response_model=DealerTokenExchangeResponse)
async def exchange_participant_token(
    body: DealerTokenExchangeRequest,
    db: AsyncSession = Depends(get_db),
):
    """Exchange a saved participant token for a regular dealer JWT."""
    participant_token = body.participant_token.strip() if isinstance(body.participant_token, str) else ""
    if not participant_token:
        raise activation_error(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "PARTICIPANT_TOKEN_REQUIRED",
            "Participant token is required",
        )
    if not participant_token.startswith("pt_"):
        raise activation_error(
            status.HTTP_401_UNAUTHORIZED,
            "INVALID_PARTICIPANT_TOKEN",
            "Invalid participant token",
        )

    token_hash = hash_participant_token(participant_token)
    token_res = await db.execute(
        select(ParticipantToken).where(ParticipantToken.token_hash == token_hash)
    )
    token_entry = token_res.scalar_one_or_none()
    if not token_entry:
        raise activation_error(
            status.HTTP_401_UNAUTHORIZED,
            "INVALID_PARTICIPANT_TOKEN",
            "Invalid participant token",
        )

    if token_entry.status == ParticipantTokenStatus.REVOKED:
        raise activation_error(
            status.HTTP_403_FORBIDDEN,
            "PARTICIPANT_TOKEN_REVOKED",
            "Participant token has been revoked",
        )
    if token_entry.status == ParticipantTokenStatus.EXPIRED:
        raise activation_error(
            status.HTTP_403_FORBIDDEN,
            "PARTICIPANT_TOKEN_EXPIRED",
            "Participant token has expired",
        )
    if token_entry.status != ParticipantTokenStatus.ACTIVE:
        raise activation_error(
            status.HTTP_403_FORBIDDEN,
            "PARTICIPANT_TOKEN_INACTIVE",
            "Participant token is not active",
        )

    dealer = await db.get(Dealer, token_entry.dealer_id)
    if not dealer:
        raise activation_error(
            status.HTTP_403_FORBIDDEN,
            "ROOM_ACCESS_MISMATCH",
            "Participant token dealer is not valid",
        )
    if not dealer.is_active:
        raise activation_error(
            status.HTTP_403_FORBIDDEN,
            "DEALER_INACTIVE",
            "Dealer is inactive",
        )
    now = datetime.now(timezone.utc)

    if token_entry.room_access_id:
        access = await db.get(RoomAccess, token_entry.room_access_id)
        if not access:
            raise activation_error(
                status.HTTP_401_UNAUTHORIZED,
                "INVALID_PARTICIPANT_TOKEN",
                "Invalid participant token",
            )
        if access.status != RoomAccessStatus.ACTIVATED:
            raise activation_error(
                status.HTTP_403_FORBIDDEN,
                "ROOM_ACCESS_NOT_ACTIVE",
                "Room access is not active",
            )
        if access.dealer_id != token_entry.dealer_id:
            raise activation_error(
                status.HTTP_403_FORBIDDEN,
                "ROOM_ACCESS_MISMATCH",
                "Participant token does not match room access",
            )
        if dealer.room_id != access.room_id:
            raise activation_error(
                status.HTTP_403_FORBIDDEN,
                "ROOM_ACCESS_MISMATCH",
                "Dealer does not match room access",
            )

        room = await db.get(Room, access.room_id)
        if not room:
            raise activation_error(
                status.HTTP_403_FORBIDDEN,
                "ROOM_ACCESS_MISMATCH",
                "Room access room is not valid",
            )
        if room_is_closed(room):
            raise activation_error(
                status.HTTP_410_GONE,
                "ROOM_CLOSED",
                "This room is closed",
            )

        token_entry.last_used_at = now
        access.last_used_at = now
        await db.commit()

        access_token = create_access_token(str(dealer.id), "dealer", str(room.id))
        return DealerTokenExchangeResponse(
            access_token=access_token,
            token_type="Bearer",
            expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            dealer=DealerTokenExchangeDealerInfo(
                id=str(dealer.id),
                display_name=dealer.display_name,
                room_id=str(room.id),
                room_code=room.room_code,
            ),
            access=DealerTokenExchangeAccessInfo(
                id=str(access.id),
                kind="room_access",
                status=access.status,
            ),
        )

    if token_entry.room_invite_id:
        invite = await db.get(RoomInvite, token_entry.room_invite_id)
        if not invite:
            raise activation_error(
                status.HTTP_401_UNAUTHORIZED,
                "INVALID_PARTICIPANT_TOKEN",
                "Invalid participant token",
            )
        sync_room_invite_status(invite, now)

        room = await db.get(Room, invite.room_id)
        if not room:
            raise activation_error(
                status.HTTP_403_FORBIDDEN,
                "ROOM_ACCESS_MISMATCH",
                "Invite room is not valid",
            )
        if dealer.room_id != room.id:
            raise activation_error(
                status.HTTP_403_FORBIDDEN,
                "ROOM_ACCESS_MISMATCH",
                "Dealer does not match invite room",
            )
        if room_is_closed(room):
            raise activation_error(
                status.HTTP_410_GONE,
                "ROOM_CLOSED",
                "This room is closed",
            )

        token_entry.last_used_at = now
        await db.commit()

        access_token = create_access_token(str(dealer.id), "dealer", str(room.id))
        return DealerTokenExchangeResponse(
            access_token=access_token,
            token_type="Bearer",
            expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            dealer=DealerTokenExchangeDealerInfo(
                id=str(dealer.id),
                display_name=dealer.display_name,
                room_id=str(room.id),
                room_code=room.room_code,
            ),
            access=DealerTokenExchangeAccessInfo(
                id=str(invite.id),
                kind="room_invite",
                status=invite.status,
            ),
        )

    raise activation_error(
        status.HTTP_401_UNAUTHORIZED,
        "INVALID_PARTICIPANT_TOKEN",
        "Invalid participant token",
    )
