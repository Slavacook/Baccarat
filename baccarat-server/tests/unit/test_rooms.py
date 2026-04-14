"""Тесты на создание комнат и вход дилера."""

import pytest
from httpx import AsyncClient


@pytest.fixture
async def trainer(client: AsyncClient, db_session):
    """Создать тренера."""
    resp = await client.post(
        "/api/auth/trainer/register",
        json={"email": "room@trainer.com", "password": "RoomPass123", "full_name": "Тренер"},
    )
    return resp.json()


def auth_headers(trainer):
    """Получить заголовки авторизации для тренера."""
    return {"Authorization": f"Bearer {trainer['access_token']}"}


class TestCreateRoom:
    """Тесты создания комнаты."""

    async def test_create_room_success(self, client: AsyncClient, db_session, trainer):
        """Создание комнаты → 201, код + PIN-ы."""
        response = await client.post(
            "/api/rooms/",
            json={
                "name": "Тестовая комната",
                "max_dealers": 10,
            },
            headers=auth_headers(trainer),
        )
        assert response.status_code == 201
        data = response.json()
        assert data["room"]["room_code"].startswith("TRAIN-")
        assert len(data["room"]["room_code"]) == 10  # TRAIN-XXXX
        assert len(data["pins"]) == 10
        # Проверить формат PIN-ов
        for pin_data in data["pins"]:
            assert len(pin_data["pin"]) == 6
            assert pin_data["pin"].isdigit()

    async def test_create_room_unauthorized(self, client: AsyncClient):
        """Без токена → 401."""
        response = await client.post(
            "/api/rooms/",
            json={"name": "Тестовая комната", "max_dealers": 10},
        )
        assert response.status_code == 401

    async def test_create_room_invalid_name(self, client: AsyncClient, trainer):
        """Короткое имя → 422."""
        response = await client.post(
            "/api/rooms/",
            json={"name": "AB", "max_dealers": 10},
            headers=auth_headers(trainer),
        )
        assert response.status_code == 422

    @pytest.mark.parametrize("max_dealers", [3, 150])
    async def test_create_room_invalid_dealers(self, client: AsyncClient, trainer, max_dealers: int):
        """< 5 или > 100 дилеров → 422."""
        response = await client.post(
            "/api/rooms/",
            json={"name": "Тест", "max_dealers": max_dealers},
            headers=auth_headers(trainer),
        )
        assert response.status_code == 422


class TestListRooms:
    """Тесты списка комнат."""

    async def test_list_rooms_empty(self, client: AsyncClient, trainer):
        """Пустой список → 200, []."""
        response = await client.get(
            "/api/rooms/",
            headers=auth_headers(trainer),
        )
        assert response.status_code == 200
        assert response.json() == []

    async def test_list_rooms_with_data(self, client: AsyncClient, trainer):
        """Создать комнату → появляется в списке."""
        await client.post(
            "/api/rooms/",
            json={"name": "Комната 1", "max_dealers": 10},
            headers=auth_headers(trainer),
        )
        response = await client.get("/api/rooms/", headers=auth_headers(trainer))
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["name"] == "Комната 1"

    async def test_list_rooms_unauthorized(self, client: AsyncClient):
        """Без токена → 401."""
        response = await client.get("/api/rooms/")
        assert response.status_code == 401


class TestDealerJoin:
    """Тесты входа дилера."""

    @pytest.fixture
    async def room_with_pins(self, client: AsyncClient, trainer):
        """Создать комнату с PIN-ами."""
        resp = await client.post(
            "/api/rooms/",
            json={"name": "Комната для дилера", "max_dealers": 5},
            headers=auth_headers(trainer),
        )
        return resp.json()

    async def test_dealer_join_success(self, client: AsyncClient, db_session, room_with_pins):
        """Верный код + PIN → 200, токены."""
        room = room_with_pins["room"]
        pin = room_with_pins["pins"][0]["pin"]

        response = await client.post(
            "/api/rooms/dealer/join",
            json={
                "room_code": room["room_code"],
                "pin": pin,
                "display_name": "Петрова М.",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["user"]["room_code"] == room["room_code"]
        assert data["user"]["is_first_login"] is True

    async def test_dealer_join_wrong_code(self, client: AsyncClient):
        """Неверный код → 404."""
        response = await client.post(
            "/api/rooms/dealer/join",
            json={"room_code": "TRAIN-XXXX", "pin": "123456", "display_name": "Тест"},
        )
        assert response.status_code == 404

    async def test_dealer_join_wrong_pin(self, client: AsyncClient, room_with_pins):
        """Неверный PIN → 403."""
        room = room_with_pins["room"]
        response = await client.post(
            "/api/rooms/dealer/join",
            json={"room_code": room["room_code"], "pin": "000000", "display_name": "Тест"},
        )
        assert response.status_code == 403

    async def test_dealer_join_invalid_pin_format(self, client: AsyncClient, room_with_pins):
        """PIN не 6 цифр → 422."""
        room = room_with_pins["room"]
        response = await client.post(
            "/api/rooms/dealer/join",
            json={"room_code": room["room_code"], "pin": "12345", "display_name": "Тест"},  # 5 цифр
        )
        assert response.status_code == 422

    async def test_dealer_rejoin_same_pin(self, client: AsyncClient, db_session, room_with_pins):
        """Повторный вход с тем же PIN и именем → 200, is_first_login=False."""
        room = room_with_pins["room"]
        pin = room_with_pins["pins"][0]["pin"]

        # Первый вход
        await client.post(
            "/api/rooms/dealer/join",
            json={"room_code": room["room_code"], "pin": pin, "display_name": "Петрова М."},
        )

        # Второй вход
        response = await client.post(
            "/api/rooms/dealer/join",
            json={"room_code": room["room_code"], "pin": pin, "display_name": "Петрова М."},
        )
        assert response.status_code == 200
        assert response.json()["user"]["is_first_login"] is False

    async def test_dealer_join_name_mismatch(self, client: AsyncClient, db_session, room_with_pins):
        """PIN использован с другим именем → 409."""
        room = room_with_pins["room"]
        pin = room_with_pins["pins"][0]["pin"]

        # Первый вход
        await client.post(
            "/api/rooms/dealer/join",
            json={"room_code": room["room_code"], "pin": pin, "display_name": "Петрова М."},
        )

        # Второй вход с другим именем
        response = await client.post(
            "/api/rooms/dealer/join",
            json={"room_code": room["room_code"], "pin": pin, "display_name": "Другое Имя"},
        )
        assert response.status_code == 409
