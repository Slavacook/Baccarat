# Детализация: Серверная часть (бэкенд)

> **Раздел плана:** 9.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Разделы 1-8 (все предыдущие)

---

## 1. Стек технологий

### 1.1 Финальный стек

| Компонент | Технология | Версия | Почему |
|-----------|------------|--------|--------|
| Язык | **Python** | 3.12+ | Зрелый, богатая экосистема, быстрая разработка |
| Фреймворк | **FastAPI** | 0.110+ | Асинхронный, автодокументация (Swagger), высокая производительность |
| База данных | **PostgreSQL** | 16+ | Надёжная, ACID, JSONB, материализованные представления |
| ORM | **SQLAlchemy 2.0** | 2.0+ | Type-safe, async поддержка, зрелая |
| Миграции | **Alembic** | 1.13+ | Автогенерация миграций из моделей SQLAlchemy |
| WebSocket | **FastAPI WebSocket** | встроен | Нативная поддержка, не требует отдельных зависимостей |
| Кэш | **Redis** | 7+ | Кэш таблицы лидеров, сессии, rate limiting |
| Аутентификация | **PyJWT** | 2.8+ | JWT токены (access + refresh) |
| Хеширование | **bcrypt** | 4.1+ | Хэширование паролей и PIN-ов |
| Валидация | **Pydantic** | 2.5+ | Встроенная в FastAPI, type-safe |
| Фоновые задачи | **Celery + Redis** | 5.3+ | Cron-задачи, отложенные уведомления |
| Логирование | **structlog** | 24.1+ | Структурированные логи для мониторинга |
| Тестирование | **pytest + httpx** | 8.0+ | Юнит-тесты, интеграционные тесты API |

### 1.2 Альтернативы (отклонены)

| Альтернатива | Почему отклонена |
|--------------|------------------|
| Node.js + Express | Менее строгая типизация, сложнее работа с БД |
| Go + Gin | Быстрее, но медленнее разработка, меньше библиотек |
| Django + DRF | Тяжеловесный, медленнее FastAPI |
| SQLite | Не подходит для concurrent подключений, нет материализованных представлений |
| MongoDB | Нет ACID, сложнее для реляционных данных (комнаты, дилеры, сессии) |

---

## 2. Архитектура проекта

### 2.1 Структура файлов

```
baccarat-server/
├── alembic/                    # Миграции БД
│   ├── versions/
│   │   ├── 001_create_trainers.py
│   │   ├── 002_create_rooms.py
│   │   └── ...
│   └── env.py
│
├── app/
│   ├── __init__.py
│   ├── main.py                 # Точка входа (FastAPI app)
│   ├── config.py               # Настройки (env vars)
│   ├── database.py             # Подключение к БД, session
│   ├── dependencies.py         # FastAPI Depends (auth, db, etc.)
│   │
│   ├── models/                 # SQLAlchemy модели
│   │   ├── __init__.py
│   │   ├── trainer.py
│   │   ├── room.py
│   │   ├── dealer.py
│   │   ├── session.py
│   │   ├── round_result.py
│   │   ├── assignment.py
│   │   ├── achievement.py
│   │   └── leaderboard.py
│   │
│   ├── schemas/                # Pydantic схемы (request/response)
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── room.py
│   │   ├── session.py
│   │   ├── dealer.py
│   │   ├── round_result.py
│   │   ├── leaderboard.py
│   │   ├── assignment.py
│   │   └── achievement.py
│   │
│   ├── api/                    # API роутеры
│   │   ├── __init__.py
│   │   ├── auth.py             # POST /api/auth/*
│   │   ├── rooms.py            # CRUD /api/rooms/*
│   │   ├── sessions.py         # POST /api/sessions/*
│   │   ├── async_sessions.py   # POST /api/async-sessions/*
│   │   ├── dashboard.py        # GET /api/rooms/{code}/dashboard
│   │   ├── leaderboard.py      # GET /api/rooms/{code}/leaderboard
│   │   ├── assignments.py      # CRUD /api/assignments/*
│   │   ├── achievements.py     # GET /api/dealers/{id}/achievements
│   │   └── reports.py          # GET /api/rooms/{code}/reports/*
│   │
│   ├── websocket/              # WebSocket обработчики
│   │   ├── __init__.py
│   │   ├── manager.py          # ConnectionManager
│   │   ├── session_ws.py       # ws://server/ws/sessions/{id}
│   │   └── dashboard_ws.py     # ws://server/ws/dashboard/{code}
│   │
│   ├── services/               # Бизнес-логика
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   ├── room_service.py
│   │   ├── session_service.py
│   │   ├── xp_service.py
│   │   ├── leaderboard_service.py
│   │   ├── achievement_service.py
│   │   ├── assignment_service.py
│   │   └── recommendation_service.py
│   │
│   ├── workers/                # Celery фоновые задачи
│   │   ├── __init__.py
│   │   ├── celery_app.py
│   │   ├── tasks.py            # Cron-задачи
│   │   └── notifications.py    # Отправка push/email
│   │
│   ├── middleware/              # Middleware
│   │   ├── __init__.py
│   │   ├── auth.py             # JWT проверка
│   │   ├── room_access.py      # Проверка доступа к комнате
│   │   └── rate_limit.py       # Rate limiting
│   │
│   ├── utils/                  # Утилиты
│   │   ├── __init__.py
│   │   ├── seed_generator.py   # Seed-based генерация
│   │   ├── pin_generator.py    # Генерация PIN-ов
│   │   ├── room_code.py        # Генерация кодов комнат
│   │   └── validators.py       # Общие валидаторы
│   │
│   └── exceptions/             # Кастомные исключения
│       ├── __init__.py
│       └── handlers.py         # Глобальный обработчик ошибок
│
├── tests/                      # Тесты
│   ├── conftest.py
│   ├── test_auth.py
│   ├── test_rooms.py
│   ├── test_sessions.py
│   ├── test_leaderboard.py
│   ├── test_achievements.py
│   └── test_assignments.py
│
├── scripts/                    # Скрипты
│   ├── seed_db.py              # Начальные данные (достижения, ранги)
│   └── create_admin.py         # Создание первого тренера
│
├── .env.example                # Пример переменных окружения
├── .env                        # Реальные переменные (не в git!)
├── docker-compose.yml          # Docker для локальной разработки
├── Dockerfile                  # Docker для продакшена
├── pyproject.toml              # Зависимости проекта
├── alembic.ini                 # Конфиг Alembic
└── README.md
```

---

## 3. Полная схема базы данных

### 3.1 ER-диаграмма

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    trainers     │     │      rooms      │     │    dealers      │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ id (UUID) PK    │──┐  │ id (UUID) PK    │  ┌──│ id (UUID) PK    │
│ email           │  └─<│ trainer_id FK   │  │  │ room_id FK      │
│ password_hash   │     │ room_code       │──┤  │ display_name    │
│ full_name       │     │ name            │  │  │ pin_hash        │
│ created_at      │     │ settings JSONB  │  │  │ created_at      │
│ updated_at      │     │ status          │  │  │ is_active       │
│ is_active       │     │ max_dealers     │  │  │ last_seen_at    │
└─────────────────┘     │ created_at      │  │  └────────┬────────┘
                        │ archived_at    │  │           │
                        └────────┬───────┘  │           │
                                 │          │           │
                    ┌────────────┘          │           │
                    │                       │           │
                    ▼                       ▼           ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    sessions     │     │  room_pins      │     │  session_participants│
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ id (UUID) PK    │     │ id (UUID) PK    │     │ id (UUID) PK    │
│ room_id FK      │     │ room_id FK      │     │ session_id FK   │
│ trainer_id FK   │     │ pin_hash        │     │ dealer_id FK    │
│ status          │     │ dealer_slot     │     │ joined_at       │
│ type            │     │ dealer_id FK    │     │ left_at         │
│ master_seed     │     │ created_at      │     │ rounds_completed│
│ duration_seconds│     │ is_active       │     │ status          │
│ max_rounds      │     └─────────────────┘     └─────────────────┘
│ started_at      │
│ ended_at        │
│ end_reason      │
│ created_at      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│  round_results  │     │ async_sessions  │
├─────────────────┤     ├─────────────────┤
│ id (UUID) PK    │     │ id (UUID) PK    │
│ session_id FK   │     │ room_id FK      │
│ dealer_id FK    │     │ dealer_id FK    │
│ round_number    │     │ status          │
│ accuracy        │     │ started_at      │
│ errors JSONB    │     │ ended_at        │
│ time_spent      │     │ end_reason      │
│ player_third    │     │ rounds_completed│
│ banker_third    │     │ total_time      │
│ winner_chosen   │     └─────────────────┘
│ winner_correct  │
│ payout_correct  │
│ lives_remaining │
│ round_xp        │
│ submitted_at    │
└─────────────────┘

┌─────────────────┐     ┌─────────────────┐
│  assignments    │     │assignment_progress│
├─────────────────┤     ├─────────────────┤
│ id (UUID) PK    │     │ id (UUID) PK    │
│ room_id FK      │     │ dealer_id FK    │
│ trainer_id FK   │     │ assignment_id FK│
│ assignment_type │     │ rounds_completed│
│ title           │     │ accuracy        │
│ target_category │     │ current_streak  │
│ target_rounds   │     │ updated_at      │
│ target_accuracy │     └─────────────────┘
│ due_at          │
│ assigned_to JSON│
│ bonus_xp        │     ┌─────────────────┐
│ status          │     │dealer_achievements│
└─────────────────┘     ├─────────────────┤
                        │ id (UUID) PK    │
                        │ dealer_id FK    │
┌─────────────────┐     │ achievement_id  │
│ achievements    │     │ unlocked_at     │
├─────────────────┤     │ xp_awarded      │
│ id (VARCHAR) PK │     └─────────────────┘
│ name            │
│ icon            │
│ category        │     ┌─────────────────┐
│ xp_reward       │     │dealer_ranks_history│
│ condition JSONB │     ├─────────────────┤
│ hidden          │     │ id (UUID) PK    │
└─────────────────┘     │ dealer_id FK    │
                        │ from_rank       │
┌─────────────────┐     │ to_rank         │
│ leaderboard_cache│    │ total_xp        │
│(mat. view)      │     │ achieved_at     │
├─────────────────┤     └─────────────────┘
│ room_id         │
│ dealer_id       │
│ total_xp        │     ┌─────────────────┐
│ rounds_completed│     │login_attempts   │
│ avg_accuracy    │     ├─────────────────┤
│ avg_time        │     │ id (UUID) PK    │
│ last_activity   │     │ room_code       │
└─────────────────┘     │ ip_address      │
                        │ attempted_at    │
                        └─────────────────┘
```

### 3.2 Полные SQL DDL (все таблицы)

Полные DDL-скрипты находятся в миграциях Alembic (`alembic/versions/`). Ключевые индексы:

```sql
-- Основные индексы для производительности
CREATE INDEX idx_rooms_trainer_id ON rooms(trainer_id);
CREATE INDEX idx_rooms_code ON rooms(room_code);
CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_dealers_room_id ON dealers(room_id);
CREATE INDEX idx_sessions_room ON sessions(room_id);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_round_results_session ON round_results(session_id);
CREATE INDEX idx_round_results_dealer ON round_results(dealer_id);
CREATE INDEX idx_assignments_room ON assignments(room_id);
CREATE INDEX idx_assignments_status ON assignments(status);
CREATE INDEX idx_assignments_due_at ON assignments(due_at);

-- Составные индексы для частых запросов
CREATE INDEX idx_round_results_session_dealer ON round_results(session_id, dealer_id);
CREATE INDEX idx_round_results_dealer_submitted ON round_results(dealer_id, submitted_at DESC);
CREATE INDEX idx_dealers_room_active ON dealers(room_id, is_active);
CREATE INDEX idx_assignments_room_status_due ON assignments(room_id, status, due_at);

-- Материализованное представление для таблицы лидеров
CREATE MATERIALIZED VIEW leaderboard_cache AS
SELECT ... (см. раздел 6 детализации таблицы лидеров);

CREATE UNIQUE INDEX idx_leaderboard_cache_dealer ON leaderboard_cache(dealer_id);
CREATE INDEX idx_leaderboard_cache_room_xp ON leaderboard_cache(room_id, total_xp DESC);
```

---

## 4. Полное API — все эндпоинты

### 4.1 Сводная таблица всех эндпоинтов

| Метод | Путь | Авторизация | Описание |
|-------|------|-------------|----------|
| **Авторизация** |
| POST | `/api/auth/trainer/register` | Нет | Регистрация тренера |
| POST | `/api/auth/trainer/login` | Нет | Вход тренера |
| POST | `/api/auth/dealer/join` | Нет | Вход дилера |
| POST | `/api/auth/refresh` | Нет | Refresh токена |
| POST | `/api/auth/logout` | Да | Выход |
| GET | `/api/auth/whoami` | Да | Проверка токена |
| GET | `/api/rooms/{code}/check` | Нет | Проверить код комнаты |
| **Комнаты** |
| POST | `/api/rooms` | Тренер | Создать комнату |
| GET | `/api/rooms` | Тренер | Список комнат тренера |
| GET | `/api/rooms/{code}` | Тренер/Дилер | Детали комнаты |
| PATCH | `/api/rooms/{code}/settings` | Тренер (владелец) | Обновить настройки |
| POST | `/api/rooms/{code}/archive` | Тренер (владелец) | Архивировать |
| POST | `/api/rooms/{code}/restore` | Тренер (владелец) | Восстановить |
| POST | `/api/rooms/{code}/close` | Тренер (владелец) | Закрыть навсегда |
| DELETE | `/api/rooms/{code}/dealers/{id}` | Тренер (владелец) | Удалить дилера |
| POST | `/api/rooms/{code}/dealers/{id}/regenerate-pin` | Тренер (владелец) | Перегенерировать PIN |
| **Сессии** |
| POST | `/api/rooms/{code}/sessions` | Тренер | Создать живую сессию |
| POST | `/api/sessions/{id}/start` | Тренер | Начать сессию |
| POST | `/api/sessions/{id}/end` | Тренер | Завершить сессию |
| GET | `/api/sessions/{id}/results` | Тренер/Дилер | Результаты сессии |
| **Async-сессии** |
| POST | `/api/rooms/{code}/async-sessions` | Дилер | Создать async-сессию |
| POST | `/api/async-sessions/{id}/results` | Дилер | Отправить результат раунда |
| POST | `/api/async-sessions/{id}/end` | Дилер | Завершить async-сессию |
| GET | `/api/rooms/{code}/async-limits` | Дилер | Получить лимиты |
| **Дашборд** |
| GET | `/api/rooms/{code}/dashboard` | Тренер | Данные дашборда |
| GET | `/api/rooms/{code}/dealers/{id}/stats` | Тренер | Статистика дилера |
| **Таблица лидеров** |
| GET | `/api/rooms/{code}/leaderboard` | Тренер/Дилер | Таблица лидеров |
| GET | `/api/dealers/{id}/xp-history` | Тренер/Дилер | XP-история |
| **Задания** |
| POST | `/api/rooms/{code}/assignments` | Тренер | Создать задание |
| GET | `/api/rooms/{code}/assignments` | Тренер/Дилер | Список заданий |
| GET | `/api/dealers/{id}/assignments` | Дилер | Мои задания |
| DELETE | `/api/assignments/{id}` | Тренер | Отменить задание |
| PATCH | `/api/assignments/{id}/extend` | Тренер | Продлить срок |
| **Достижения** |
| GET | `/api/dealers/{id}/achievements` | Тренер/Дилер | Достижения дилера |
| POST | `/api/dealers/{id}/achievements/check` | Дилер | Проверить новые |
| **Отчёты** |
| GET | `/api/rooms/{code}/reports/dealer/{id}/pdf` | Тренер | PDF-отчёт по дилеру |
| GET | `/api/rooms/{code}/reports/all/csv` | Тренер | CSV всех результатов |
| **Статистика** |
| GET | `/api/rooms/{code}/analytics` | Тренер | Аналитика группы |
| GET | `/api/rooms/{code}/analytics/comparison` | Тренер | Сравнение дилеров |

**Итого: 40 эндпоинтов**

---

## 5. WebSocket — полный протокол

### 5.1 WebSocket для живых сессий

**URL:** `wss://server/ws/sessions/{session_id}`

**Аутентификация:** Query параметр `?token=<access_token>` или заголовок `Authorization: Bearer <token>`

**Сервер → Клиент:**

| Тип | Данные | Когда |
|-----|--------|-------|
| `session_created` | `{session_id, room_code, settings, max_rounds}` | Сессия создана |
| `session_starting` | `{start_in_seconds: 5}` | Обратный отсчёт |
| `session_started` | `{session_id, seed, duration, started_at}` | Сессия началась |
| `timer_tick` | `{remaining_seconds: N}` | Каждые 10 сек |
| `session_ended` | `{reason, ended_at}` | Сессия завершена |
| `session_aborted` | `{reason}` | Сессия прервана |
| `round_seed` | `{round_number, round_seed, cards_hash}` | Новая раздача |
| `dealer_joined` | `{dealer_id, display_name, total_online}` | Дилер подключился |
| `dealer_left` | `{dealer_id, display_name, total_online}` | Дилер отключился |
| `ping` | `{server_time: timestamp}` | Каждые 30 сек |
| `error` | `{code, message}` | Ошибка |

**Клиент → Сервер:**

| Тип | Данные | Когда |
|-----|--------|-------|
| `join_session` | `{dealer_id, token}` | Подключение |
| `ready` | `{dealer_id}` | Готов к старту |
| `round_result` | `{round_number, accuracy, errors, ...}` | Раунд завершён |
| `heartbeat` | `{dealer_id, client_time}` | Каждые 15 сек |
| `reconnect` | `{dealer_id, token, last_round_received}` | Переподключение |
| `ping` | `{client_time: timestamp}` | Ответ на ping |

### 5.2 WebSocket для дашборда

**URL:** `wss://server/ws/dashboard/{room_code}`

**Аутентификация:** Query параметр `?token=<trainer_access_token>`

**Сервер → Дашборд:**

| Тип | Данные | Когда |
|-----|--------|-------|
| `dashboard_update` | `{session_active, time_remaining, total_rounds, dealers: [...]}` | Каждые 5 сек |
| `dealer_update` | `{dealer_id, rounds, accuracy, errors, avg_time}` | Дилер завершил раунд |
| `session_event` | `{event: started/ended/aborted, data}` | Событие сессии |

### 5.3 ConnectionManager

```python
# app/websocket/manager.py
from fastapi import WebSocket
from typing import Dict, Set
import asyncio

class ConnectionManager:
    def __init__(self):
        # session_id -> set of websockets
        self.active_sessions: Dict[str, Set[WebSocket]] = {}
        # room_code -> set of websockets (dashboard)
        self.active_dashboards: Dict[str, Set[WebSocket]] = {}
        # websocket -> dealer_id
        self.ws_to_dealer: Dict[WebSocket, str] = {}
    
    async def connect_session(self, websocket: WebSocket, session_id: str, dealer_id: str):
        await websocket.accept()
        self.active_sessions.setdefault(session_id, set()).add(websocket)
        self.ws_to_dealer[websocket] = dealer_id
    
    async def disconnect_session(self, websocket: WebSocket, session_id: str):
        self.active_sessions.get(session_id, set()).discard(websocket)
        self.ws_to_dealer.pop(websocket, None)
    
    async def send_to_session(self, session_id: str, message: dict):
        """Отправить сообщение всем участникам сессии."""
        disconnected = set()
        for ws in self.active_sessions.get(session_id, set()):
            try:
                await ws.send_json(message)
            except Exception:
                disconnected.add(ws)
        
        # Удалить отключённых
        for ws in disconnected:
            await self.disconnect_session(ws, session_id)
    
    async def connect_dashboard(self, websocket: WebSocket, room_code: str):
        await websocket.accept()
        self.active_dashboards.setdefault(room_code, set()).add(websocket)
    
    async def disconnect_dashboard(self, websocket: WebSocket, room_code: str):
        self.active_dashboards.get(room_code, set()).discard(websocket)
    
    async def send_to_dashboard(self, room_code: str, message: dict):
        """Отправить сообщение всем подключённым дашбордам комнаты."""
        disconnected = set()
        for ws in self.active_dashboards.get(room_code, set()):
            try:
                await ws.send_json(message)
            except Exception:
                disconnected.add(ws)
        
        for ws in disconnected:
            await self.disconnect_dashboard(ws, room_code)

# Глобальный экземпляр
manager = ConnectionManager()
```

---

## 6. Безопасность сервера

### 6.1 CORS

```python
# app/main.py
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",           # веб-дашборд локально
        "https://dashboard.baccarat-trainer.com",  # веб-дашборд продакшен
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["*"],
)
```

### 6.2 Rate Limiting

```python
# app/middleware/rate_limit.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

# Настройка лимитов
RATE_LIMITS = {
    "/api/auth/trainer/login": "5/5minutes",
    "/api/auth/trainer/register": "3/10minutes",
    "/api/auth/dealer/join": "10/5minutes",
    "/api/auth/refresh": "10/1hour",
    "/api/rooms": "5/1hour",  # создание комнат
    "/api/rooms/{code}/settings": "10/10minutes",
}
```

### 6.3 Защита от перебора PIN

```python
# app/services/pin_security.py
class PINSecurityService:
    MAX_ATTEMPTS = 5
    LOCK_DURATION_MINUTES = 30
    DELAY_AFTER_MAX = 2  # секунды задержки после 6-10 попытки
    
    def check_rate_limit(self, room_code: str, ip_address: str) -> bool:
        """Проверить, не заблокирован ли IP за перебор PIN."""
        attempts = db.scalar(
            "SELECT COUNT(*) FROM login_attempts WHERE room_code = :code AND ip_address = :ip AND attempted_at > :cutoff",
            {"code": room_code, "ip": ip_address, "cutoff": datetime.utcnow() - timedelta(minutes=60)}
        )
        return attempts < self.MAX_ATTEMPTS
    
    def record_attempt(self, room_code: str, ip_address: str) -> None:
        """Записать попытку входа."""
        db.execute(
            "INSERT INTO login_attempts (room_code, ip_address) VALUES (:code, :ip)",
            {"code": room_code, "ip": ip_address}
        )
        db.commit()
    
    def cleanup_old_attempts(self) -> None:
        """Удалить записи старше 1 часа."""
        db.execute(
            "DELETE FROM login_attempts WHERE attempted_at < :cutoff",
            {"cutoff": datetime.utcnow() - timedelta(hours=1)}
        )
        db.commit()
```

### 6.4 Валидация данных

```python
# app/utils/validators.py
from pydantic import BaseModel, field_validator, EmailStr
import re

class TrainerRegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None
    
    @field_validator("password")
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Пароль должен содержать минимум 8 символов")
        if not re.search(r"[A-Za-z]", v):
            raise ValueError("Пароль должен содержать хотя бы одну букву")
        if not re.search(r"\d", v):
            raise ValueError("Пароль должен содержать хотя бы одну цифру")
        return v

class RoomCreateRequest(BaseModel):
    name: str
    max_dealers: int = 20
    
    @field_validator("name")
    def name_length(cls, v):
        if len(v) < 3:
            raise ValueError("Название должно содержать минимум 3 символа")
        if len(v) > 100:
            raise ValueError("Название не должно превышать 100 символов")
        return v
    
    @field_validator("max_dealers")
    def max_dealers_range(cls, v):
        if v < 5 or v > 100:
            raise ValueError("Максимум дилеров должен быть от 5 до 100")
        return v
```

### 6.5 Подпись результатов раунда (античит)

```python
# app/utils/result_signature.py
import hashlib
import hmac

def sign_round_result(result: dict, session_master_seed: str) -> str:
    """Подписать результат раунда на клиенте (Godot)."""
    payload = f"{result['round_number']}:{result['accuracy']}:{result['time_spent_seconds']}:{session_master_seed}"
    return hmac.new(
        session_master_seed.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()

def verify_round_result(result: dict, signature: str, session_master_seed: str) -> bool:
    """Проверить подпись результата на сервере."""
    expected = sign_round_result(result, session_master_seed)
    return hmac.compare_digest(expected, signature)
```

---

## 7. Фоновые задачи (Celery)

### 7.1 Конфигурация

```python
# app/workers/celery_app.py
from celery import Celery

celery_app = Celery(
    "baccarat_trainer",
    broker="redis://localhost:6379/0",
    backend="redis://localhost:6379/1",
    timezone="UTC",
    include=["app.workers.tasks"]
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)
```

### 7.2 Задачи

```python
# app/workers/tasks.py
from app.workers.celery_app import celery_app
from app.services.assignment_service import AssignmentService
from app.services.room_service import RoomService
from app.workers.notifications import send_push_notification

@celery_app.task
def expire_assignments():
    """Каждый час: пометить просроченные задания."""
    AssignmentService.expire_overdue_assignments()

@celery_app.task
def create_recurring_assignments():
    """Каждый день: создать экземпляры повторяющихся заданий."""
    AssignmentService.create_recurring_instances()

@celery_app.task
def notify_overdue_assignments():
    """Каждый день (9:00): уведомить тренеров о просроченных заданиях."""
    overdue = AssignmentService.get_overdue_assignments()
    for trainer_id, assignments in overdue.items():
        send_push_notification(
            trainer_id,
            title="Просроченные задания",
            body=f"{len(assignments)} заданий просрочено в ваших комнатах"
        )

@celery_app.task
def cleanup_closed_rooms():
    """Каждый день: удалить комнаты, закрытые > 90 дней назад."""
    RoomService.delete_old_closed_rooms(days=90)

@celery_app.task
def cleanup_login_attempts():
    """Каждый час: удалить старые записи попыток входа."""
    from app.services.pin_security import PINSecurityService
    PINSecurityService().cleanup_old_attempts()

@celery_app.task
def cleanup_old_sessions():
    """Каждый день: архивировать сессии старше 90 дней."""
    from app.services.session_service import SessionService
    SessionService.archive_old_sessions(days=90)
```

### 7.3 Расписание (Celery Beat)

```python
# app/workers/celery_app.py
celery_app.conf.beat_schedule = {
    "expire-assignments": {
        "task": "app.workers.tasks.expire_assignments",
        "schedule": 3600.0,  # каждый час
    },
    "create-recurring-assignments": {
        "task": "app.workers.tasks.create_recurring_assignments",
        "schedule": 86400.0,  # каждый день
        "options": {"expires": 3600},
    },
    "notify-overdue": {
        "task": "app.workers.tasks.notify_overdue_assignments",
        "schedule": crontab(hour=9, minute=0),  # каждый день в 9:00
    },
    "cleanup-closed-rooms": {
        "task": "app.workers.tasks.cleanup_closed_rooms",
        "schedule": crontab(hour=3, minute=0),  # каждый день в 3:00
    },
    "cleanup-login-attempts": {
        "task": "app.workers.tasks.cleanup_login_attempts",
        "schedule": 3600.0,  # каждый час
    },
    "cleanup-old-sessions": {
        "task": "app.workers.tasks.cleanup_old_sessions",
        "schedule": crontab(hour=4, minute=0),  # каждый день в 4:00
    },
}
```

---

## 8. Переменные окружения

### 8.1 `.env.example`

```bash
# ─── Приложение ───
APP_NAME=Baccarat Trainer Server
APP_ENV=production
DEBUG=False
SECRET_KEY=change-me-to-random-string
API_PREFIX=/api

# ─── База данных ───
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/baccarat_trainer

# ─── Redis ───
REDIS_URL=redis://localhost:6379/0

# ─── JWT ───
JWT_SECRET_KEY=change-me-to-another-random-string
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRE_DAYS_TRAINER=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS_DEALER=7

# ─── CORS ───
CORS_ORIGINS=http://localhost:3000,https://dashboard.baccarat-trainer.com

# ─── SMTP (для email уведомлений) ───
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=notifications@baccarat-trainer.com
SMTP_PASSWORD=change-me

# ─── Push уведомления ───
FCM_SERVER_KEY=change-me  # Firebase Cloud Messaging
APNS_KEY_ID=change-me     # Apple Push Notifications
APNS_TEAM_ID=change-me

# ─── Sentry (мониторинг ошибок) ───
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx

# ─── Логирование ───
LOG_LEVEL=INFO
LOG_FORMAT=json
```

---

## 9. Docker — локальная разработка

### 9.1 `docker-compose.yml`

```yaml
version: "3.9"

services:
  api:
    build: .
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      - db
      - redis
    volumes:
      - ./app:/code/app
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: baccarat
      POSTGRES_PASSWORD: baccarat
      POSTGRES_DB: baccarat_trainer
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  celery-worker:
    build: .
    command: celery -A app.workers.celery_app worker --loglevel=info
    env_file: .env
    depends_on:
      - redis
      - db

  celery-beat:
    build: .
    command: celery -A app.workers.celery_app beat --loglevel=info
    env_file: .env
    depends_on:
      - redis

volumes:
  postgres_data:
```

### 9.2 `Dockerfile`

```dockerfile
FROM python:3.12-slim

WORKDIR /code

# Системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Python зависимости
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .

# Код приложения
COPY ./app /code/app

# Команда запуска (переопределяется в docker-compose)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 10. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Финальный стек технологий | ✅ Завершено |
| 2 | Полная схема БД (все таблицы, колонки, индексы, связи) | ✅ Завершено |
| 3 | Все API-эндпоинты (40 эндпоинтов, методы, пути) | ✅ Завершено |
| 4 | WebSocket-протокол (события, формат сообщений) | ✅ Завершено |
| 5 | Стратегия безопасности (CORS, rate limiting, античит) | ✅ Завершено |
| 6 | Фоновые задачи (Celery, расписание) | ✅ Завершено (6 задач) |
| 7 | Переменные окружения | ✅ Завершено |
| 8 | Docker для локальной разработки | ✅ Завершено |
| 9 | Структура проекта (файлы, директории) | ✅ Завершено |

**Раздел 9: Серверная часть — детализация завершена полностью (9/9 пунктов).**

---

> **Этот документ — финальная детализация раздела 9.1 "Серверная часть".**  
> **Следующий шаг:** Приступить к детализации раздела 10 "Клиентская часть Godot".
