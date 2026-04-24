"""Тесты live-сессий (создание, запуск, результаты, завершение)."""

import hashlib
import uuid
from unittest.mock import patch

from httpx import AsyncClient
import pytest
from sqlalchemy import select

from app.api import sessions as sessions_api
from app.models.session import Session as DBSession


def test_live_monitor_ws_types_include_protocol_events():
    """Контракт с docs/ONLINE_PROTOCOL.md: сервер ретранслирует эти типы от дилера."""
    assert "round_started" in sessions_api._LIVE_MONITOR_TYPES
    assert "error_occurred" in sessions_api._LIVE_MONITOR_TYPES
    assert "action_performed" in sessions_api._LIVE_MONITOR_TYPES
    assert "round_completed" in sessions_api._LIVE_MONITOR_TYPES
    assert "table_state" in sessions_api._LIVE_MONITOR_TYPES


def test_table_state_dealer_id_spoof_protection():
    merged = sessions_api._merge_live_payload_with_listener_dealer(
        {"dealer_id": "spoofed", "event_seq": 7},
        "real-dealer-id",
    )
    assert merged["dealer_id"] == "real-dealer-id"
    assert merged["event_seq"] == 7


def test_table_state_cache_seq_rule():
    sessions_api._LATEST_TABLE_STATE_BY_SESSION.clear()
    sid = "s-1"
    did = "d-1"
    assert sessions_api._cache_table_state_if_newer(
        sid, did, {"event_seq": 10, "round_id": "r1", "schema_version": 1}
    )
    assert not sessions_api._cache_table_state_if_newer(
        sid, did, {"event_seq": 10, "round_id": "r1", "schema_version": 1}
    )
    assert not sessions_api._cache_table_state_if_newer(
        sid, did, {"event_seq": 9, "round_id": "r1", "schema_version": 1}
    )
    assert sessions_api._cache_table_state_if_newer(
        sid, did, {"event_seq": 11, "round_id": "r2", "schema_version": 1}
    )


def test_table_state_sync_returns_only_current_session_states():
    sessions_api._LATEST_TABLE_STATE_BY_SESSION.clear()
    sessions_api._cache_table_state_if_newer(
        "s-1", "d-1", {"event_seq": 5, "round_id": "r1", "schema_version": 1}
    )
    sessions_api._cache_table_state_if_newer(
        "s-1", "d-2", {"event_seq": 3, "round_id": "r9", "schema_version": 1}
    )
    sessions_api._cache_table_state_if_newer(
        "s-2", "d-3", {"event_seq": 7, "round_id": "r2", "schema_version": 1}
    )
    states = sessions_api._get_cached_table_states_for_session("s-1")
    assert len(states) == 2
    assert sorted([x["event_seq"] for x in states]) == [3, 5]


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def trainer_tokens(client: AsyncClient):
    resp = await client.post(
        "/api/auth/trainer/register",
        json={"email": "live@trainer.com", "password": "LivePass123", "full_name": "Live Trainer"},
    )
    assert resp.status_code == 201
    return resp.json()


@pytest.fixture
async def room_payload(client: AsyncClient, trainer_tokens):
    resp = await client.post(
        "/api/rooms/",
        json={"name": "Live Room", "max_dealers": 5},
        headers=_auth_headers(trainer_tokens["access_token"]),
    )
    assert resp.status_code == 201
    return resp.json()


@pytest.fixture
async def dealer_tokens(client: AsyncClient, room_payload):
    room_code = room_payload["room"]["room_code"]
    pin = room_payload["pins"][0]["pin"]
    resp = await client.post(
        "/api/rooms/dealer/join",
        json={"room_code": room_code, "pin": pin, "display_name": "Dealer One"},
    )
    assert resp.status_code == 200
    return resp.json()


class TestLiveSessions:
    async def test_create_start_submit_end_live_session(
        self,
        client: AsyncClient,
        trainer_tokens,
        room_payload,
        dealer_tokens,
    ):
        room_code = room_payload["room"]["room_code"]
        trainer_headers = _auth_headers(trainer_tokens["access_token"])
        dealer_headers = _auth_headers(dealer_tokens["access_token"])

        # create
        create_resp = await client.post(
            f"/api/rooms/{room_code}/sessions",
            json={"duration_minutes": 15, "max_rounds": 50},
            headers=trainer_headers,
        )
        assert create_resp.status_code == 201
        session_id = create_resp.json()["session_id"]

        # start
        start_resp = await client.post(f"/api/sessions/{session_id}/start", headers=trainer_headers)
        assert start_resp.status_code == 200
        assert start_resp.json()["status"] == "active"

        # submit round result
        round_resp = await client.post(
            f"/api/sessions/{session_id}/round-results",
            json={
                "round_number": 1,
                "accuracy": 100.0,
                "errors": [],
                "time_spent_seconds": 12,
                "player_third_card": True,
                "banker_third_card": False,
                "winner_chosen": "Player",
                "winner_correct": True,
                "payout_correct": True,
                "lives_remaining": 7,
            },
            headers=dealer_headers,
        )
        assert round_resp.status_code == 201

        # fetch results
        results_resp = await client.get(f"/api/sessions/{session_id}/results", headers=trainer_headers)
        assert results_resp.status_code == 200
        body = results_resp.json()
        assert body["total_round_results"] == 1
        assert len(body["dealers"]) == 1
        assert body["dealers"][0]["display_name"] == "Dealer One"

        # end
        end_resp = await client.post(f"/api/sessions/{session_id}/end", headers=trainer_headers)
        assert end_resp.status_code == 200
        assert end_resp.json()["status"] == "completed"

    async def test_cannot_create_second_active_session(self, client: AsyncClient, trainer_tokens, room_payload):
        room_code = room_payload["room"]["room_code"]
        trainer_headers = _auth_headers(trainer_tokens["access_token"])

        first = await client.post(
            f"/api/rooms/{room_code}/sessions",
            json={"duration_minutes": 30},
            headers=trainer_headers,
        )
        assert first.status_code == 201

        second = await client.post(
            f"/api/rooms/{room_code}/sessions",
            json={"duration_minutes": 30},
            headers=trainer_headers,
        )
        assert second.status_code == 409

    async def test_dealer_active_live_session_endpoint(
        self,
        client: AsyncClient,
        trainer_tokens,
        room_payload,
        dealer_tokens,
    ):
        """Дилер получает активную live-сессию после создания тренером."""
        room_code = room_payload["room"]["room_code"]
        trainer_headers = _auth_headers(trainer_tokens["access_token"])
        dealer_headers = _auth_headers(dealer_tokens["access_token"])

        no_sess = await client.get(
            f"/api/rooms/{room_code}/active-live-session",
            headers=dealer_headers,
        )
        assert no_sess.status_code == 404

        create_resp = await client.post(
            f"/api/rooms/{room_code}/sessions",
            json={"duration_minutes": 10},
            headers=trainer_headers,
        )
        assert create_resp.status_code == 201
        session_id = create_resp.json()["session_id"]

        created_info = await client.get(
            f"/api/rooms/{room_code}/active-live-session",
            headers=dealer_headers,
        )
        assert created_info.status_code == 200
        body_created = created_info.json()
        assert body_created["session_id"] == session_id
        assert body_created["status"] == "created"
        assert body_created["round_seed"] is None

        start_resp = await client.post(f"/api/sessions/{session_id}/start", headers=trainer_headers)
        assert start_resp.status_code == 200

        active_info = await client.get(
            f"/api/rooms/{room_code}/active-live-session",
            headers=dealer_headers,
        )
        assert active_info.status_code == 200
        body_active = active_info.json()
        assert body_active["status"] == "active"
        assert body_active["round_seed"] is not None

    async def test_trainer_live_session_endpoint(
        self,
        client: AsyncClient,
        trainer_tokens,
        room_payload,
    ):
        """Тренер видит ту же активную сессию по отдельному URL."""
        room_code = room_payload["room"]["room_code"]
        trainer_headers = _auth_headers(trainer_tokens["access_token"])

        t404 = await client.get(
            f"/api/rooms/{room_code}/trainer-live-session",
            headers=trainer_headers,
        )
        assert t404.status_code == 404

        create_resp = await client.post(
            f"/api/rooms/{room_code}/sessions",
            json={"duration_minutes": 5},
            headers=trainer_headers,
        )
        assert create_resp.status_code == 201
        session_id = create_resp.json()["session_id"]

        t200 = await client.get(
            f"/api/rooms/{room_code}/trainer-live-session",
            headers=trainer_headers,
        )
        assert t200.status_code == 200
        assert t200.json()["session_id"] == session_id

        await client.post(f"/api/sessions/{session_id}/start", headers=trainer_headers)
        t_active = await client.get(
            f"/api/rooms/{room_code}/trainer-live-session",
            headers=trainer_headers,
        )
        assert t_active.status_code == 200
        assert t_active.json()["status"] == "active"

    async def test_submit_round_broadcasts_round_sync(
        self,
        client: AsyncClient,
        trainer_tokens,
        room_payload,
        dealer_tokens,
        db_session,
    ):
        """После сохранения раунда сервер шлёт WS `round_sync` с сидом следующего раунда."""
        room_code = room_payload["room"]["room_code"]
        trainer_headers = _auth_headers(trainer_tokens["access_token"])
        dealer_headers = _auth_headers(dealer_tokens["access_token"])

        create_resp = await client.post(
            f"/api/rooms/{room_code}/sessions",
            json={"duration_minutes": 10, "max_rounds": 20},
            headers=trainer_headers,
        )
        assert create_resp.status_code == 201
        session_id = create_resp.json()["session_id"]
        await client.post(f"/api/sessions/{session_id}/start", headers=trainer_headers)

        res = await db_session.execute(select(DBSession).where(DBSession.id == uuid.UUID(session_id)))
        sess_row = res.scalar_one()
        expected_next = hashlib.sha256(
            f"{sess_row.master_seed}:round:2".encode("utf-8"),
        ).hexdigest()

        ws_events: list[tuple[str, dict]] = []

        async def capture_broadcast(*, session_id: str, event_type: str, data: dict) -> None:
            ws_events.append((event_type, data))

        with patch.object(sessions_api.ws_manager, "broadcast", side_effect=capture_broadcast):
            round_resp = await client.post(
                f"/api/sessions/{session_id}/round-results",
                json={
                    "round_number": 1,
                    "accuracy": 100.0,
                    "errors": [],
                    "time_spent_seconds": 12,
                    "player_third_card": True,
                    "banker_third_card": False,
                    "winner_chosen": "Player",
                    "winner_correct": True,
                    "payout_correct": True,
                    "lives_remaining": 7,
                },
                headers=dealer_headers,
            )
        assert round_resp.status_code == 201

        sync_msgs = [d for typ, d in ws_events if typ == "round_sync"]
        assert len(sync_msgs) == 1
        payload = sync_msgs[0]
        assert payload["completed_round"] == 1
        assert payload["next_round_number"] == 2
        assert payload["round_seed"] == expected_next

        dealer_msgs = [d for typ, d in ws_events if typ == "dealer_update"]
        assert len(dealer_msgs) == 1

    async def test_trainer_can_fetch_dealer_round_history(
        self,
        client: AsyncClient,
        trainer_tokens,
        room_payload,
        dealer_tokens,
    ):
        room_code = room_payload["room"]["room_code"]
        trainer_headers = _auth_headers(trainer_tokens["access_token"])
        dealer_headers = _auth_headers(dealer_tokens["access_token"])

        create_resp = await client.post(
            f"/api/rooms/{room_code}/sessions",
            json={"duration_minutes": 10},
            headers=trainer_headers,
        )
        assert create_resp.status_code == 201
        session_id = create_resp.json()["session_id"]
        await client.post(f"/api/sessions/{session_id}/start", headers=trainer_headers)

        submit_resp = await client.post(
            f"/api/sessions/{session_id}/round-results",
            json={
                "round_number": 1,
                "accuracy": 75.0,
                "errors": ["Banker third card decision was wrong"],
                "time_spent_seconds": 10,
                "player_third_card": False,
                "banker_third_card": True,
                "winner_chosen": "Banker",
                "winner_correct": False,
                "payout_correct": True,
                "lives_remaining": 6,
                "round_context": {"player_cards": ["8H", "AC"], "banker_cards": ["7D", "2S"]},
            },
            headers=dealer_headers,
        )
        assert submit_resp.status_code == 201

        dealer_id = dealer_tokens["user"]["id"]
        details_resp = await client.get(
            f"/api/sessions/{session_id}/dealers/{dealer_id}/rounds",
            headers=trainer_headers,
        )
        assert details_resp.status_code == 200
        body = details_resp.json()
        assert body["dealer_id"] == dealer_id
        assert len(body["rounds"]) == 1
        item = body["rounds"][0]
        assert item["round_number"] == 1
        assert item["errors"][0]["category"] == "third_card_banker"
        assert item["round_context"]["player_cards"] == ["8H", "AC"]
