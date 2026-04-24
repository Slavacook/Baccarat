# Детализация: Тестирование

> **Раздел плана:** 14.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Разделы 1-13 (все предыдущие)

---

## 1. Обзор

Стратегия тестирования покрывает все уровни: юнит-тесты серверной логики, интеграционные тесты API, E2E-сценарии полного цикла, нагрузочные тесты и тестирование мобильных сборок.

---

## 2. Юнит-тесты сервера

### 2.1 Инструменты

| Компонент | Инструмент | Почему |
|-----------|------------|--------|
| Фреймворк | **pytest** | Стандарт для Python, фикстуры, параметризация |
| Моки БД | **pytest-mock** | Легко мокать SQLAlchemy сессии |
| Тестирование API | **httpx** (async) | Асинхронные HTTP-тесты для FastAPI |
| Фабрики данных | **factory_boy** | Генерация тестовых данных |
| Покрытие | **pytest-cov** | Отчёт покрытия кода |

### 2.2 Список юнит-тестов

#### Авторизация (test_auth.py)

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `test_trainer_register_success` | Регистрация тренера → 201, токены |
| 2 | `test_trainer_register_duplicate_email` | Повторный email → 409 |
| 3 | `test_trainer_register_weak_password` | Слабый пароль → 422 |
| 4 | `test_trainer_login_success` | Верные данные → 200, токены |
| 5 | `test_trainer_login_wrong_password` | Неверный пароль → 401 |
| 6 | `test_trainer_login_wrong_email` | Неверный email → 401 |
| 7 | `test_dealer_join_success` | Верный код + PIN → 200 |
| 8 | `test_dealer_join_wrong_code` | Неверный код → 404 |
| 9 | `test_dealer_join_wrong_pin` | Неверный PIN → 403 |
| 10 | `test_dealer_join_duplicate_name` | Имя занято → 409 |
| 11 | `test_dealer_join_closed_room` | Закрытая комната → 410 |
| 12 | `test_pin_bruteforce_lockout` | 6 неверных попыток → блокировка |
| 13 | `test_token_refresh` | Refresh → новый access token |
| 14 | `test_expired_token_rejected` | Истёкший токен → 401 |
| 15 | `test_revoked_token_rejected` | Отозванный токен → 401 |

#### Комнаты (test_rooms.py)

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `test_create_room_success` | Создание → 201, код, PIN-ы |
| 2 | `test_create_room_invalid_name` | Короткое имя → 422 |
| 3 | `test_create_room_invalid_dealers` | < 5 дилеров → 422 |
| 4 | `test_create_room_limit_reached` | 51-я комната → 429 |
| 5 | `test_get_rooms_list` | Список комнат тренера |
| 6 | `test_get_room_details_owner` | Полный доступ владельца |
| 7 | `test_get_room_details_dealer` | Ограниченный доступ дилера |
| 8 | `test_get_room_details_unauthorized` | 401 без токена |
| 9 | `test_update_room_settings_success` | Обновление настроек |
| 10 | `test_update_room_settings_active_session` | Ошибка при активной сессии |
| 11 | `test_archive_room_success` | Архивация → статус changed |
| 12 | `test_archive_room_active_session` | Ошибка при активной сессии |
| 13 | `test_close_room_success` | Закрытие → статус changed |
| 14 | `test_delete_dealer_success` | Удаление дилера |
| 15 | `test_regenerate_pin_success` | Новый PIN, старый не работает |

#### Сессии (test_sessions.py)

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `test_create_session_success` | Создание сессии → 201 |
| 2 | `test_start_session_success` | Запуск → status = active |
| 3 | `test_end_session_by_trainer` | Завершение тренером |
| 4 | `test_end_session_by_timer` | Автозавершение по таймеру |
| 5 | `test_end_session_by_round_limit` | Автозавершение по лимиту раундов |
| 6 | `test_abort_session` | Прерывание сессии |
| 7 | `test_seed_generation` | MASTER_SEED генерируется |
| 8 | `test_round_seed_deterministic` | Одинаковый seed → одинаковые карты |
| 9 | `test_reconnect_after_disconnect` | Переподключение дилера |
| 10 | `test_session_results_saved` | Результаты сохранены после завершения |

#### XP и лидерборд (test_leaderboard.py)

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `test_xp_calculation_perfect_round` | 43 XP за идеальный раунд |
| 2 | `test_xp_calculation_with_error` | 20 XP за раунд с ошибкой |
| 3 | `test_xp_streak_bonus` | +10 XP за каждые 5 раундов без ошибок |
| 4 | `test_xp_survival_penalty` | -5 XP за ошибку в survival |
| 5 | `test_leaderboard_ranking_order` | Сортировка по XP |
| 6 | `test_leaderboard_tiebreaker_accuracy` | Tiebreaker по точности |
| 7 | `test_leaderboard_tiebreaker_speed` | Tiebreaker по скорости |
| 8 | `test_leaderboard_filter_period` | Фильтр по периоду |
| 9 | `test_leaderboard_filter_session_type` | Фильтр live/async |
| 10 | `test_rank_up_conditions_met` | Повышение ранга при выполнении условий |
| 11 | `test_rank_up_conditions_not_met` | Нет повышения без условий |

#### Достижения (test_achievements.py)

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `test_achievement_unlock_first_step` | 1 раунд без ошибок → first_step |
| 2 | `test_achievement_unlock_streak_5` | 5 без ошибок → streak_5 |
| 3 | `test_achievement_no_duplicate` | Не разблокируется повторно |
| 4 | `test_achievement_hidden_not_visible` | Скрытые не видны до разблокировки |
| 5 | `test_achievement_xp_awarded` | XP начислены при разблокировке |
| 6 | `test_achievement_multi_condition` | Все условия должны быть выполнены |

#### Задания (test_assignments.py)

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `test_create_assignment_success` | Создание задания |
| 2 | `test_create_assignment_invalid_dates` | due_at < start_at → 422 |
| 3 | `test_assignment_progress_update` | Прогресс обновляется |
| 4 | `test_assignment_completion` | Выполнение → статус changed, XP начислены |
| 5 | `test_assignment_expiration` | Просрочка → статус = expired |
| 6 | `test_assignment_cancellation` | Отмена тренером |
| 7 | `test_recurring_assignment_creation` | Создание нового экземпляра |

#### Безопасность (test_security.py)

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `test_result_signature_valid` | HMAC подпись совпадает |
| 2 | `test_result_signature_invalid` | Подделка → отклонено |
| 3 | `test_rate_limit_login` | 6-й логин → 429 |
| 4 | `test_rate_limit_pin` | 11-й PIN → 429 |
| 5 | `test_sql_injection_prevention` | SQL-инъекция отклонена |
| 6 | `test_cheat_detection_speed` | Аномальная скорость → флаг |
| 7 | `test_cheat_detection_perfect_fast` | 100% + быстро → флаг |
| 8 | `test_cheat_detection_bot_pattern` | Одинаковые интервалы → флаг |

### 2.3 Команды запуска

```bash
# Все юнит-тесты
pytest tests/unit/ -v --cov=app --cov-report=html

# Конкретный файл
pytest tests/unit/test_auth.py -v

# Конкретный тест
pytest tests/unit/test_auth.py::test_trainer_login_success -v

# С отчётом покрытия
pytest tests/unit/ --cov=app --cov-report=term-missing --cov-fail-under=80
```

---

## 3. Интеграционные тесты

### 3.1 Список интеграционных тестов

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `test_full_auth_flow` | Регистрация → логин → refresh → logout |
| 2 | `test_room_lifecycle` | Создание → настройки → архив → восстановление → закрытие |
| 3 | `test_session_flow` | Создание → запуск → результаты → завершение |
| 4 | `test_async_session_flow` | Создание → результаты → завершение |
| 5 | `test_leaderboard_update` | Раунд → XP обновлён → позиция обновлена |
| 6 | `test_assignment_completion_flow` | Создание → прогресс → выполнение → XP |
| 7 | `test_achievement_unlock_flow` | Раунды → условие выполнено → достижение разблокировано |
| 8 | `test_trainer_dashboard_data` | Данные дашборда корректны |
| 9 | `test_pdf_report_generation` | PDF генерируется без ошибок |
| 10 | `test_csv_export` | CSV экспортируется с правильным форматом |
| 11 | `test_websocket_connection` | WebSocket подключается, сообщения отправляются/принимаются |
| 12 | `test_push_notification_registration` | Device token зарегистрирован |

### 3.4 Фикстуры для интеграционных тестов

```python
# tests/conftest.py
import pytest
from httpx import AsyncClient
from app.main import app
from app.database import get_db, engine
from app.models import Base

@pytest.fixture(scope="function")
async def db_session():
    """Создать тестовую БД."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    async with AsyncSession(engine) as session:
        yield session
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest.fixture
async def client(db_session):
    """Тестовый HTTP-клиент."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.fixture
async def trainer_token(client):
    """Токен авторизованного тренера."""
    response = await client.post("/api/auth/trainer/register", json={
        "email": "test@trainer.com",
        "password": "TestPass123"
    })
    return response.json()["access_token"]

@pytest.fixture
async def room_with_dealers(client, trainer_token):
    """Комната с 5 дилерами."""
    response = await client.post("/api/rooms", json={
        "name": "Test Room",
        "max_dealers": 10
    }, headers={"Authorization": f"Bearer {trainer_token}"})
    room = response.json()["room"]
    pins = response.json()["pins"]
    return {"room": room, "pins": pins}
```

---

## 4. E2E-сценарии

### 4.1 Полный цикл: живая сессия

```
Сценарий: Тренер создаёт комнату, запускает сессию, дилеры играют, результаты на дашборде

Шаги:
1. Тренер регистрируется → получает токен
2. Тренер создаёт комнату → получает код + PIN-ы
3. Дилер 1 входит (код + PIN) → получает токен
4. Дилер 2 входит (код + PIN) → получает токен
5. Тренер создаёт сессию → session_id
6. Тренер запускает сессию → обратный отсчёт
7. Дилер 1 играет 5 раундов → отправляет результаты
8. Дилер 2 играет 5 раундов → отправляет результаты
9. Тренер завершает сессию
10. Проверяем: результаты сохранены, лидерборд обновлён, дашборд показывает данные

Ассерты:
- Оба дилера имеют результаты
- Лидерборд показывает правильного лидера
- Дашборд показывает правильную статистику
```

### 4.2 E2E-сценарии (полный список)

| # | Сценарий | Описание |
|---|----------|----------|
| 1 | Полная живая сессия | Создание → игра → результаты → дашборд |
| 2 | Асинхронная тренировка | Дилер играет один → результаты → лидерборд |
| 3 | Задание от тренера | Создание → прогресс → выполнение → XP |
| 4 | Достижения | Игра → разблокировка → push-уведомление |
| 5 | Обрыв и переподключение | Дилер отключился → reconnect → результаты сохранены |
| 6 | Повышение ранга | Накопление XP → ранг повышен → уведомление |
| 7 | Детекция читерства | Аномальная скорость → флаг → блокировка |
| 8 | Экспорт отчёта | PDF и CSV генерируются корректно |

---

## 5. Нагрузочные тесты

### 5.1 Инструменты

| Инструмент | Для чего | Почему |
|------------|----------|--------|
| **Locust** | Нагрузочное тестирование API | Python-based, реалистичные сценарии |
| **WebSocket King** | Тестирование WebSocket | Concurrent подключения |

### 5.2 Сценарии нагрузки

| Сценарий | Нагрузка | Ожидаемый результат |
|----------|----------|---------------------|
| 100 дилеров одновременно отправляют результаты | 100 concurrent POST /async-sessions/{id}/results | Response time < 500ms, 0 ошибок |
| 50 живых сессий параллельно | 50 WebSocket подключений | Все подключены, сообщения < 100ms |
| 10 тренеров обновляют дашборд | 10 WebSocket dashboard подключений | Обновления < 5 сек |
| 1000 запросов лидерборда за минуту | 1000 GET /leaderboard | Response time < 200ms (кэш) |

### 5.3 Locust-файл

```python
# tests/load/locustfile.py
from locust import HttpUser, task, between

class DealerUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        # Войти как дилер
        self.client.post("/api/auth/dealer/join", json={
            "room_code": "TRAIN-TEST",
            "pin": "123456",
            "display_name": "LoadTest Dealer"
        })
        self.token = self.last_response.json()["access_token"]
        self.headers = {"Authorization": f"Bearer {self.token}"}
    
    @task(3)
    def submit_round_result(self):
        self.client.post("/api/async-sessions/test-session/results", json={
            "round_number": 1,
            "accuracy": 90.0,
            "errors": [],
            "time_spent_seconds": 15,
            "winner_correct": True,
            "payout_correct": True
        }, headers=self.headers)
    
    @task(1)
    def get_leaderboard(self):
        self.client.get("/api/rooms/TRAIN-TEST/leaderboard", headers=self.headers)
    
    @task(1)
    def get_assignments(self):
        self.client.get("/api/rooms/TRAIN-TEST/assignments", headers=self.headers)

class TrainerUser(HttpUser):
    wait_time = between(2, 5)
    
    @task(1)
    def get_dashboard(self):
        self.client.get("/api/rooms/TRAIN-TEST/dashboard", headers=self.headers)
```

### 5.4 Метрики

| Метрика | Цель | Как измерить |
|---------|------|--------------|
| Response time (p50) | < 200ms | Locust stats |
| Response time (p99) | < 1000ms | Locust stats |
| Error rate | < 0.1% | Locust stats |
| Concurrent connections | 500 WebSocket | Серверные метрики |
| CPU usage | < 80% | Docker stats |
| Memory usage | < 2GB | Docker stats |
| DB query time | < 50ms | PostgreSQL slow query log |

---

## 6. Тестирование мобильных сборок

### 6.1 Устройства для тестирования

#### iOS

| Устройство | iOS версия | Почему |
|------------|------------|--------|
| iPhone 15 Pro | 17.x | Последняя модель |
| iPhone 13 | 16.x | Популярная модель |
| iPhone SE (3rd gen) | 16.x | Минимальная поддержка |
| iPad Air | 17.x | Планшет (landscape) |

#### Android

| Устройство | Android версия | Почему |
|------------|----------------|--------|
| Pixel 8 | 14 | Референсное устройство |
| Samsung Galaxy S23 | 14 | Популярный OEM |
| Xiaomi Redmi Note 12 | 13 | Бюджетный сегмент |

### 6.2 Чеклист мобильного тестирования

| Проверка | iOS | Android |
|----------|-----|---------|
| Приложение запускается | ⏳ | ⏳ |
| Авторизация работает | ⏳ | ⏳ |
| Вход в комнату (код + PIN) | ⏳ | ⏳ |
| Геймплей Баккара | ⏳ | ⏳ |
| Таймер сессии отображается | ⏳ | ⏳ |
| Таблица лидеров загружается | ⏳ | ⏳ |
| Достижения отображаются | ⏳ | ⏳ |
| Задания отображаются | ⏳ | ⏳ |
| Push-уведомления приходят | ⏳ | ⏳ |
| Ориентация экрана (landscape) | ⏳ | ⏳ |
| Работа при потере сети | ⏳ | ⏳ |
| Восстановление после краша | ⏳ | ⏳ |
| Хранение токенов (Keychain/EncryptedSharedPreferences) | ⏳ | ⏳ |
| Производительность (60 FPS) | ⏳ | ⏳ |
| Потребление памяти < 500MB | ⏳ | ⏳ |

---

## 7. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Список юнит-тестов для сервера | ✅ Завершено (60+ тестов) |
| 2 | Список интеграционных тестов | ✅ Завершено (12 тестов) |
| 3 | Список E2E-сценариев | ✅ Завершено (8 сценариев) |
| 4 | Стратегия нагрузочного тестирования | ✅ Завершено (Locust, метрики) |
| 5 | Тестирование мобильных сборок | ✅ Завершено (чеклист, устройства) |
| 6 | Фикстуры и инфраструктура тестов | ✅ Завершено |

**Раздел 14: Тестирование — детализация завершена полностью (6/6 пунктов).**

---

> **Этот документ — финальная детализация раздела 14.1 "Тестирование".**  
> **Следующий шаг:** Приступить к детализации раздела 15 "Деплой и запуск".
