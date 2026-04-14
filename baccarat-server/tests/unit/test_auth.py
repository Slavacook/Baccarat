"""Тесты на авторизацию тренера."""

import pytest
from httpx import AsyncClient


class TestTrainerRegister:
    """Тесты регистрации тренера."""

    async def test_register_success(self, client: AsyncClient, db_session):
        """Успешная регистрация → 201, токены."""
        response = await client.post(
            "/api/auth/trainer/register",
            json={"email": "test@trainer.com", "password": "TestPass123", "full_name": "Иванов Иван"},
        )
        assert response.status_code == 201
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["email"] == "test@trainer.com"
        assert data["user"]["role"] == "trainer"

    async def test_register_duplicate_email(self, client: AsyncClient, db_session):
        """Повторный email → 409."""
        body = {"email": "dup@trainer.com", "password": "TestPass123"}
        await client.post("/api/auth/trainer/register", json=body)
        response = await client.post("/api/auth/trainer/register", json=body)
        assert response.status_code == 409

    @pytest.mark.parametrize(
        "password,expected_error",
        [
            ("short", "8 символов"),
            ("nouppercas123", "букву"),  # только строчные
            ("lettersOnly", "цифру"),
        ],
    )
    async def test_register_weak_password(self, client: AsyncClient, password: str, expected_error: str):
        """Слабый пароль → 422."""
        response = await client.post(
            "/api/auth/trainer/register",
            json={"email": "weak@trainer.com", "password": password},
        )
        assert response.status_code == 422

    async def test_register_invalid_email(self, client: AsyncClient):
        """Неверный формат email → 422."""
        response = await client.post(
            "/api/auth/trainer/register",
            json={"email": "not-an-email", "password": "TestPass123"},
        )
        assert response.status_code == 422


class TestTrainerLogin:
    """Тесты входа тренера."""

    @pytest.fixture
    async def registered_trainer(self, client: AsyncClient):
        """Зарегистрировать тренера для тестов."""
        await client.post(
            "/api/auth/trainer/register",
            json={"email": "login@trainer.com", "password": "LoginPass123", "full_name": "Тест"},
        )
        return {"email": "login@trainer.com", "password": "LoginPass123"}

    async def test_login_success(self, client: AsyncClient, registered_trainer):
        """Верные данные → 200, токены."""
        response = await client.post(
            "/api/auth/trainer/login",
            json={"email": registered_trainer["email"], "password": registered_trainer["password"]},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["user"]["email"] == registered_trainer["email"]

    async def test_login_wrong_password(self, client: AsyncClient, registered_trainer):
        """Неверный пароль → 401."""
        response = await client.post(
            "/api/auth/trainer/login",
            json={"email": registered_trainer["email"], "password": "WrongPass123"},
        )
        assert response.status_code == 401

    async def test_login_wrong_email(self, client: AsyncClient):
        """Неверный email → 401."""
        response = await client.post(
            "/api/auth/trainer/login",
            json={"email": "nobody@trainer.com", "password": "TestPass123"},
        )
        assert response.status_code == 401


class TestTrainerRefresh:
    """Тесты обновления токена."""

    @pytest.fixture
    async def registered_trainer(self, client: AsyncClient):
        """Зарегистрировать тренера."""
        resp = await client.post(
            "/api/auth/trainer/register",
            json={"email": "refresh@trainer.com", "password": "RefreshPass123", "full_name": "Тест"},
        )
        return resp.json()

    async def test_refresh_success(self, client: AsyncClient, registered_trainer):
        """Валидный refresh token → 200, новая пара токенов."""
        refresh_token = registered_trainer["refresh_token"]
        response = await client.post(
            "/api/auth/trainer/refresh",
            json={"refresh_token": refresh_token},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["role"] == "trainer"

    async def test_refresh_invalid_token(self, client: AsyncClient):
        """Невалидный токен → 401."""
        response = await client.post(
            "/api/auth/trainer/refresh",
            json={"refresh_token": "invalid.token.here"},
        )
        assert response.status_code == 401

    async def test_refresh_with_access_token(self, client: AsyncClient, registered_trainer):
        """Использовать access token вместо refresh → 401."""
        access_token = registered_trainer["access_token"]
        response = await client.post(
            "/api/auth/trainer/refresh",
            json={"refresh_token": access_token},
        )
        assert response.status_code == 401


class TestTrainerLogout:
    """Тесты выхода тренера."""

    @pytest.fixture
    async def logged_in_trainer(self, client: AsyncClient):
        """Зарегистрировать и получить токены."""
        return (await client.post(
            "/api/auth/trainer/register",
            json={"email": "logout@trainer.com", "password": "LogoutPass123", "full_name": "Тест"},
        )).json()

    async def test_logout_success(self, client: AsyncClient, logged_in_trainer):
        """Успешный logout → 204."""
        response = await client.post(
            "/api/auth/trainer/logout",
            headers={"Authorization": f"Bearer {logged_in_trainer['access_token']}"},
        )
        assert response.status_code == 204

    async def test_logout_unauthorized(self, client: AsyncClient):
        """Без токена → 401."""
        response = await client.post("/api/auth/trainer/logout")
        assert response.status_code == 401


class TestTrainerWhoami:
    """Тесты получения данных тренера."""

    @pytest.fixture
    async def logged_in_trainer(self, client: AsyncClient):
        """Зарегистрировать и получить токены."""
        return (await client.post(
            "/api/auth/trainer/register",
            json={"email": "whoami@trainer.com", "password": "WhoamiPass123", "full_name": "Иванов"},
        )).json()

    async def test_whoami_success(self, client: AsyncClient, logged_in_trainer):
        """Получить данные текущего тренера → 200."""
        response = await client.get(
            "/api/auth/trainer/whoami",
            headers={"Authorization": f"Bearer {logged_in_trainer['access_token']}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["user"]["email"] == "whoami@trainer.com"
        assert data["user"]["full_name"] == "Иванов"
        assert data["user"]["role"] == "trainer"

    async def test_whoami_unauthorized(self, client: AsyncClient):
        """Без токена → 401."""
        response = await client.get("/api/auth/trainer/whoami")
        assert response.status_code == 401

    async def test_whoami_with_dealer_token(self, client: AsyncClient):
        """С токеном дилера → 403."""
        # Создать комнату через тренера
        trainer_resp = await client.post(
            "/api/auth/trainer/register",
            json={"email": "trainer@whoami.com", "password": "Pass123456", "full_name": "Тренер"},
        )
        trainer = trainer_resp.json()

        room_resp = await client.post(
            "/api/rooms/",
            json={"name": "Комната", "max_dealers": 5},
            headers={"Authorization": f"Bearer {trainer['access_token']}"},
        )
        room = room_resp.json()
        pin = room["pins"][0]["pin"]

        # Войти как дилер
        dealer_resp = await client.post(
            "/api/rooms/dealer/join",
            json={"room_code": room["room"]["room_code"], "pin": pin, "display_name": "Дилер"},
        )
        dealer = dealer_resp.json()

        # Попробовать получить whoami тренера с токеном дилера
        response = await client.get(
            "/api/auth/trainer/whoami",
            headers={"Authorization": f"Bearer {dealer['access_token']}"},
        )
        assert response.status_code == 403
