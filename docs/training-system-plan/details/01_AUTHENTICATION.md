# Детализация: Авторизация и роли

> **Раздел плана:** 1.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Нет (первый раздел)

---

## 1. Обзор решения

### Стек технологий для сервера

**Рекомендация:**

| Компонент | Технология | Почему |
|-----------|------------|--------|
| Язык | **Python 3.12+** | Быстрая разработка, богатая экосистема, легко найти разработчиков |
| Фреймворк | **FastAPI** | Современный, асинхронный, автодокументация (Swagger), высокая производительность |
| База данных | **PostgreSQL 16+** | Надёжная, ACID, JSONB для гибких данных, хорошая поддержка Godot |
| ORM | **SQLAlchemy 2.0 + Alembic** | Зрелая миграция, type-safe запросы |
| Аутентификация | **JWT (PyJWT)** | Stateless, легко интегрируется с Godot |
| WebSocket | **FastAPI WebSocket** | Встроенная поддержка, real-time |
| Хеширование паролей | **bcrypt** | Стандарт индустрии |

**Альтернативы (если нужно):**
- Node.js + Express + Prisma — тоже хороший вариант, но Python ближе к Godot-экосистеме
- Go + Gin + GORM — быстрее, но сложнее разработка

### Архитектура авторизации

```
┌─────────────────────────────────────────────────────────────┐
│  GODOT-КЛИЕНТ (iOS/Android)                                 │
│  ┌──────────────────────┐    ┌──────────────────────────┐   │
│  │  Экран входа тренера │    │  Экран входа дилера      │   │
│  │  (email + пароль)    │    │  (код комнаты + PIN)     │   │
│  └──────────┬───────────┘    └────────────┬─────────────┘   │
│             │                              │                 │
│             ▼                              ▼                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              HTTP Client (Godot)                      │   │
│  │  • POST /api/auth/trainer/login                     │   │
│  │  • POST /api/auth/dealer/join                       │   │
│  │  • Хранение JWT в памяти/кэше                       │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         │                                    │
└─────────────────────────┼───────────────────────────────────┘
                          │ HTTPS
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  СЕРВЕР (FastAPI)                                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Auth Router                                            │ │
│  │  • POST /api/auth/trainer/login → JWT                  │ │
│  │  • POST /api/auth/trainer/register → JWT               │ │
│  │  • POST /api/auth/dealer/join → JWT                    │ │
│  │  • POST /api/auth/refresh → новый JWT                  │ │
│  └────────────────────┬───────────────────────────────────┘ │
│                       │                                      │
│  ┌────────────────────▼───────────────────────────────────┐ │
│  │  Auth Middleware                                        │ │
│  │  • Проверка JWT в заголовке Authorization              │ │
│  │  • Извлечение user_id и role из токена                 │ │
│  │  • Возврат 401 при невалидном токене                   │ │
│  └────────────────────┬───────────────────────────────────┘ │
│                       │                                      │
│  ┌────────────────────▼───────────────────────────────────┐ │
│  │  PostgreSQL (таблицы: trainers, dealers, rooms, pins)   │ │
│  │  • bcrypt хэши паролей тренеров                        │ │
│  │  • PIN-коды дилеров (односторонний хэш)                │ │
│  │  • Связь: dealer → room → trainer                      │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Роли пользователей

### 2.1 Тренер (Trainer)

| Атрибут | Описание |
|---------|----------|
| Идентификация | Email + пароль |
| Регистрация | Самостоятельная (через экран регистрации) |
| Права | Создавать комнаты, управлять PIN-ами, видеть дашборд, создавать задания, завершать сессии |
| Токен | JWT с полем `role: "trainer"` |
| Сессия | Долгосрочная (30 дней refresh token) |

### 2.2 Дилер (Dealer)

| Атрибут | Описание |
|---------|----------|
| Идентификация | Код комнаты + PIN-код |
| Регистрация | Автоматическая при первом входе (тренер выдаёт PIN) |
| Права | Входить в комнату, тренироваться, видеть свою статистику и таблицу лидеров |
| Токен | JWT с полем `role: "dealer"` + `room_id` |
| Сессия | Краткосрочная (7 дней refresh token) |

### 2.3 Сравнение прав доступа

| Действие | Тренер | Дилер |
|----------|--------|-------|
| Создать комнату | ✅ | ❌ |
| Войти в комнату (как участник) | ❌ | ✅ |
| Запустить живую сессию | ✅ | ❌ |
| Завершить сессию | ✅ | ❌ |
| Видеть дашборд всех дилеров | ✅ | ❌ |
| Видеть свою статистику | ✅ | ✅ |
| Видеть таблицу лидеров | ✅ | ✅ |
| Создать задание | ✅ | ❌ |
| Выполнить задание | ❌ | ✅ |
| Генерировать PIN-коды | ✅ | ❌ |
| Удалить дилера из комнаты | ✅ | ❌ |
| Архивировать комнату | ✅ | ❌ |

---

## 3. База данных — схема таблиц

### 3.1 Таблица `trainers`

```sql
CREATE TABLE trainers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(255),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    is_active       BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_trainers_email ON trainers(email);
```

**Поля:**
| Поле | Тип | Описание |
|------|-----|----------|
| id | UUID | Уникальный идентификатор тренера |
| email | VARCHAR(255) | Email для входа (уникальный) |
| password_hash | VARCHAR(255) | bcrypt хэш пароля (стоимость 12) |
| full_name | VARCHAR(255) | Отображаемое имя (опционально) |
| created_at | TIMESTAMPTZ | Дата создания аккаунта |
| updated_at | TIMESTAMPTZ | Дата последнего смены данных |
| is_active | BOOLEAN | Флаг активности (soft delete) |

### 3.2 Таблица `rooms`

```sql
CREATE TABLE rooms (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id      UUID NOT NULL REFERENCES trainers(id) ON DELETE CASCADE,
    name            VARCHAR(255) NOT NULL,
    room_code       VARCHAR(20) UNIQUE NOT NULL,
    settings        JSONB NOT NULL DEFAULT '{}',
    status          VARCHAR(20) DEFAULT 'active',  -- active, archived, closed
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    archived_at     TIMESTAMPTZ
);

CREATE INDEX idx_rooms_trainer_id ON rooms(trainer_id);
CREATE INDEX idx_rooms_code ON rooms(room_code);
CREATE INDEX idx_rooms_status ON rooms(status);
```

**Поля:**
| Поле | Тип | Описание |
|------|-----|----------|
| id | UUID | Уникальный идентификатор комнаты |
| trainer_id | UUID | Владелец комнаты (тренер) |
| name | VARCHAR(255) | Название комнаты |
| room_code | VARCHAR(20) | Уникальный код для входа (например, `TRAIN-A7X9`) |
| settings | JSONB | Настройки комнаты (режим, типы ставок, лимиты, длительность) |
| status | VARCHAR(20) | Статус: active, archived, closed |
| created_at | TIMESTAMPTZ | Дата создания |
| updated_at | TIMESTAMPTZ | Дата последнего обновления |
| archived_at | TIMESTAMPTZ | Дата архивации (если заархивирована) |

### 3.3 Таблица `dealers`

```sql
CREATE TABLE dealers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id         UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    display_name    VARCHAR(255) NOT NULL,
    pin_hash        VARCHAR(255) NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    is_active       BOOLEAN DEFAULT TRUE,
    last_seen_at    TIMESTAMPTZ,
    
    UNIQUE(room_id, display_name)
);

CREATE INDEX idx_dealers_room_id ON dealers(room_id);
```

**Поля:**
| Поле | Тип | Описание |
|------|-----|----------|
| id | UUID | Уникальный идентификатор дилера |
| room_id | UUID | Комната, в которой дилер зарегистрирован |
| display_name | VARCHAR(255) | Отображаемое имя (например, "Петрова М.") |
| pin_hash | VARCHAR(255) | bcrypt хэш PIN-кода |
| created_at | TIMESTAMPTZ | Дата регистрации в комнате |
| is_active | BOOLEAN | Флаг активности (можно "удалить" из комнаты) |
| last_seen_at | TIMESTAMPTZ | Последний вход в систему |

**Важно:** Один и тот же дилер (человек) может быть в нескольких комнатах — в каждой комнате отдельная запись.

### 3.4 Таблица `sessions` (токены авторизации)

```sql
CREATE TABLE sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,  -- trainer_id или dealer_id
    user_type       VARCHAR(10) NOT NULL,  -- 'trainer' или 'dealer'
    refresh_token   VARCHAR(512) UNIQUE NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    is_revoked      BOOLEAN DEFAULT FALSE,
    device_info     JSONB  -- информация об устройстве (опционально)
);

CREATE INDEX idx_sessions_user ON sessions(user_id, user_type);
CREATE INDEX idx_sessions_refresh_token ON sessions(refresh_token);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);
```

**Поля:**
| Поле | Тип | Описание |
|------|-----|----------|
| id | UUID | Уникальный идентификатор сессии |
| user_id | UUID | ID пользователя (тренер или дилер) |
| user_type | VARCHAR(10) | Тип: 'trainer' или 'dealer' |
| refresh_token | VARCHAR(512) | Случайный токен для refresh (храним хэш) |
| expires_at | TIMESTAMPTZ | Когда сессия истекает |
| created_at | TIMESTAMPTZ | Дата создания |
| is_revoked | BOOLEAN | Флаг отзыва (при выходе) |
| device_info | JSONB | infо об устройстве (os, app_version) |

---

## 4. JWT — структура токенов

### 4.1 Access Token (короткоживущий)

```json
{
  "sub": "uuid-пользователя",
  "role": "trainer",
  "room_id": null,
  "exp": 1713024000,
  "iat": 1713020400,
  "type": "access"
}
```

| Поле | Описание |
|------|----------|
| sub | ID пользователя (trainer_id или dealer_id) |
| role | Роль: "trainer" или "dealer" |
| room_id | ID комнаты (только для дилеров, null для тренеров) |
| exp | Время истечения (1 час) |
| iat | Время выдачи |
| type | Тип токена: "access" |

### 4.2 Refresh Token (долгоживущий)

```json
{
  "sub": "uuid-пользователя",
  "role": "trainer",
  "exp": 1715612400,
  "iat": 1713020400,
  "type": "refresh",
  "session_id": "uuid-сессии"
}
```

| Поле | Описание |
|------|----------|
| sub | ID пользователя |
| role | Роль |
| exp | Время истечения (тренер: 30 дней, дилер: 7 дней) |
| iat | Время выдачи |
| type | Тип токена: "refresh" |
| session_id | ID сессии в БД (для отзыва) |

### 4.3 Использование токенов

```
1. Логин → сервер возвращает {access_token, refresh_token}
2. Клиент сохраняет оба токена
3. Каждый запрос к API: заголовок "Authorization: Bearer <access_token>"
4. Когда access_token истекает (через 1 час):
   POST /api/auth/refresh с refresh_token → новый access_token
5. При выходе: POST /api/auth/logout → отзыв refresh_token
```

---

## 5. PIN-коды дилеров

### 5.1 Формат

| Параметр | Значение | Почему |
|----------|----------|--------|
| Длина | **6 цифр** | Достаточно комбинаций (1 000 000), легко диктовать |
| Формат | `123456` (только цифры) | Просто вводить на мобильном |
| Генерация | Криптографически случайная | `secrets.token_hex(3)` → 6 цифр |
| Хранение | bcrypt хэш (стоимость 10) | Защита от утечки БД |
| Срок действия | Бессрочный (пока дилер в комнате) | Тренер может отозвать |
| Уникальность | Уникален в пределах комнаты | (room_id, pin_hash) — уникальный |

### 5.2 Генерация PIN-ов

Тренер при создании комнаты получает пакет PIN-кодов:

```json
{
  "room_code": "TRAIN-A7X9",
  "pins": [
    {"pin": "482156", "dealer_slot": 1, "display_name": null},
    {"pin": "739501", "dealer_slot": 2, "display_name": null},
    {"pin": "105678", "dealer_slot": 3, "display_name": null},
    ...
    {"pin": "923847", "dealer_slot": 20, "display_name": null}
  ],
  "max_dealers": 20
}
```

**Параметры:**
- `max_dealers`: настраивается тренером (по умолчанию 20, максимум 100)
- `dealer_slot`: слот в пакете (для удобства раздачи)
- `display_name`: заполняется при первом входе дилера

### 5.3 Поток выдачи PIN-ов

```
1. Тренер создаёт комнату → указывает max_dealers = 20
2. Сервер генерирует 20 случайных PIN-ов
3. Сервер хэширует каждый PIN bcrypt-ом
4. Сервер возвращает тренеру ПЛОСКИЕ PIN-ы (только один раз!)
5. Тренер раздаёт PIN-ы дилерам (лично, в чате, QR-код)
6. Дилер входит: вводит room_code + PIN → сервер создаёт запись в dealers
7. PIN привязывается к display_name дилера
```

---

## 6. Генерация кода комнаты

### 6.1 Формат

| Параметр | Значение | Пример |
|----------|----------|--------|
| Префикс | `TRAIN-` | Константа |
| Код | 4 символа | `A7X9` |
| Символы | Заглавные буквы (A-Z) + цифры (0-9), исключены похожие (0/O, 1/I/L) | `A7X9`, `B3K8` |
| Длина | 10 символов всего | `TRAIN-A7X9` |

### 6.2 Алфавит

```
Допустимые символы: A B C D E F G H J K M N P Q R T U V W X Y Z 2 3 4 5 6 7 8 9
Исключены: 0 (похож на O), 1 (похож на I), I, L, O
Всего: 26 + 8 = 34 символа
```

### 6.3 Пространство комбинаций

```
34^4 = 1 336 336 уникальных кодов
```

При 1000 активных комнат вероятность коллизии ничтожна. При коллизии — перегенерировать.

### 6.4 Алгоритм генерации

```python
import secrets

ALPHABET = "ABCDEFGHJKMNPQRTUVWXYZ23456789"

def generate_room_code() -> str:
    while True:
        code = "TRAIN-" + "".join(secrets.choice(ALPHABET) for _ in range(4))
        if not room_exists(code):  # проверка в БД
            return code
```

---

## 7. API-эндпоинты авторизации

### 7.1 Регистрация тренера

```
POST /api/auth/trainer/register

Request:
{
    "email": "trainer@example.com",
    "password": "secure_password_123",
    "full_name": "Иванов Иван"  // опционально
}

Response 201 (успех):
{
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "token_type": "Bearer",
    "user": {
        "id": "uuid",
        "email": "trainer@example.com",
        "full_name": "Иванов Иван",
        "role": "trainer"
    }
}

Response 409 (email занят):
{
    "error": "Email already registered"
}

Response 422 (валидация):
{
    "error": "Invalid email format"
}
```

**Валидация:**
- Email: валидный формат, уникален
- Пароль: минимум 8 символов, хотя бы 1 буква + 1 цифра

### 7.2 Вход тренера

```
POST /api/auth/trainer/login

Request:
{
    "email": "trainer@example.com",
    "password": "secure_password_123"
}

Response 200 (успех):
{
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "token_type": "Bearer",
    "user": {
        "id": "uuid",
        "email": "trainer@example.com",
        "full_name": "Иванов Иван",
        "role": "trainer"
    }
}

Response 401 (неверные данные):
{
    "error": "Invalid email or password"
}
```

**Логика:**
1. Найти тренера по email
2. Проверить пароль через bcrypt
3. Если OK → создать сессию, выдать токены
4. Если нет → вернуть 401 (без уточнения, что именно не так)

### 7.3 Вход дилера

```
POST /api/auth/dealer/join

Request:
{
    "room_code": "TRAIN-A7X9",
    "pin": "482156",
    "display_name": "Петрова М."
}

Response 200 (успех):
{
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "token_type": "Bearer",
    "user": {
        "id": "uuid",
        "display_name": "Петрова М.",
        "room_id": "uuid",
        "room_code": "TRAIN-A7X9",
        "role": "dealer",
        "is_first_login": true
    }
}

Response 404 (комната не найдена):
{
    "error": "Room not found"
}

Response 403 (неверный PIN):
{
    "error": "Invalid PIN"
}

Response 409 (имя уже занято в комнате):
{
    "error": "Display name already taken in this room"
}

Response 410 (комната закрыта):
{
    "error": "Room is closed"
}
```

**Логика:**
1. Найти комнату по `room_code`
2. Проверить статус комнаты (active)
3. Найти PIN в комнате (перебрать все PIN-и, проверить bcrypt)
4. Если PIN не использован → создать запись `dealer` с `display_name`
5. Если PIN использован → проверить, совпадает ли `display_name`
6. Создать сессию, выдать токены

### 7.4 Refresh токена

```
POST /api/auth/refresh

Request:
{
    "refresh_token": "eyJ..."
}

Response 200 (успех):
{
    "access_token": "eyJ...",
    "refresh_token": "eyJ..."  // новый refresh token (rotation)
}

Response 401 (невалидный/отозванный токен):
{
    "error": "Invalid or revoked refresh token"
}
```

**Логика:**
1. Проверить подпись refresh_token
2. Проверить, что сессия не отозвана
3. Проверить, что токен не истёк
4. Создать новый access_token + новый refresh_token (rotation)
5. Отозвать старый refresh_token

### 7.5 Выход

```
POST /api/auth/logout
Authorization: Bearer <access_token>

Request:
{
    "refresh_token": "eyJ..."  // опционально, можно из токена
}

Response 200:
{
    "message": "Logged out successfully"
}
```

**Логика:**
1. Найти сессию по refresh_token
2. Поставить `is_revoked = true`
3. Удалить токен у клиента

### 7.6 Проверка токена (whoami)

```
GET /api/auth/whoami
Authorization: Bearer <access_token>

Response 200:
{
    "user": {
        "id": "uuid",
        "role": "dealer",
        "display_name": "Петрова М.",
        "room_id": "uuid",
        "room_code": "TRAIN-A7X9",
        "last_seen_at": "2026-04-12T18:30:00Z"
    }
}

Response 401:
{
    "error": "Invalid or expired token"
}
```

---

## 8. UI-поток в Godot-клиенте

### 8.1 Экран выбора роли (главное меню)

```
┌─────────────────────────────────────┐
│                                     │
│        🎰 BACCARAT TRAINER          │
│                                     │
│   ┌───────────────────────────┐     │
│   │  👨‍🏫 Я ТРЕНЕР              │     │
│   │  (создать/войти в кабинет) │     │
│   └───────────────────────────┘     │
│                                     │
│   ┌───────────────────────────┐     │
│   │  🃏 Я ДИЛЕР               │     │
│   │  (войти в комнату)         │     │
│   └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

### 8.2 Поток тренера

```
┌─────────────────────┐
│ Главное меню        │
│ "Я ТРЕНЕР"          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐     Нет аккаунта?
│ Вход тренера        │────────────────┐
│ Email: [________]   │                │
│ Пароль: [________]  │                ▼
│                     │     ┌─────────────────────┐
│ [Войти] [Забыли?]   │     │ Регистрация тренера │
└──────────┬──────────┘     │ Email: [________]   │
           │                │ Пароль: [________]  │
           │ Успех          │ Повтор: [________]  │
           ▼                │ Имя: [________]     │
┌─────────────────────┐     │ [Зарегистрироваться]│
│ Дашборд тренера     │     └─────────────────────┘
│ (список комнат)     │
│ [+] Создать комнату │
└─────────────────────┘
```

### 8.3 Поток дилера

```
┌─────────────────────┐
│ Главное меню        │
│ "Я ДИЛЕР"           │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Вход дилера         │
│                     │
│ Код комнаты:        │
│ [TRAIN-] [____]     │
│                     │
│ PIN-код:            │
│ [______]            │
│                     │
│ Ваше имя:           │
│ [Петрова М.]        │
│                     │
│ [Войти в комнату]   │
│                     │
│ ⚠️ PIN и имя вы     │
│ получили от тренера │
└──────────┬──────────┘
           │ Успех
           ▼
┌─────────────────────┐
│ Лобби комнаты       │
│ Комната: Группа А   │
│ Участников: 8       │
│                     │
│ [Начать тренировку] │
│ [Таблица лидеров]   │
│ [Мой профиль]       │
└─────────────────────┘
```

### 8.4 Обработка ошибок (UI дилера)

| Ошибка | Сообщение на экране | Действие |
|--------|---------------------|----------|
| Комната не найдена | "Комната с таким кодом не найдена. Проверьте код и попробуйте снова." | Оставить поле кода, фокус на нём |
| Неверный PIN | "Неверный PIN-код. Если проблема повторяется, обратитесь к тренеру." | Оставить поле PIN, очистить, фокус |
| Имя занято | "Это имя уже используется в комнате. Выберите другое (например, добавьте инициал)." | Оставить поле имени, фокус |
| Комната закрыта | "Эта комната закрыта. Обратитесь к тренеру." | Кнопка "Назад" |
| Нет сети | "Нет подключения к интернету. Проверьте соединение." | Кнопка "Повторить" |
| Сервер недоступен | "Сервер временно недоступен. Попробуйте через несколько минут." | Кнопка "Повторить" |

---

## 9. Хранение токенов в Godot-клиенте

### 9.1 iOS

| Хранилище | Что храним | Почему |
|-----------|------------|--------|
| **Keychain** | refresh_token | Безопасное хранилище ОС, переживает переустановку |
| **Память (переменная)** | access_token | Быстрый доступ, теряется при закрытии |

### 9.2 Android

| Хранилище | Что храним | Почему |
|-----------|------------|--------|
| **EncryptedSharedPreferences** | refresh_token | Безопасное хранилище ОС |
| **Память (переменная)** | access_token | Быстрый доступ, теряется при закрытии |

### 9.3 Godot-реализация

```gdscript
# scripts/auth/AuthTokenManager.gd
class_name AuthTokenManager
extends Node

var access_token: String = ""
var refresh_token: String = ""
var user_data: Dictionary = {}

func save_tokens(at: String, rt: String, user: Dictionary) -> void:
    access_token = at
    refresh_token = rt
    user_data = user
    
    # Сохраняем refresh_token в безопасное хранилище ОС
    OS.set_secure_string("refresh_token", rt)
    OS.set_secure_string("user_data", JSON.stringify(user))

func load_tokens() -> bool:
    refresh_token = OS.get_secure_string("refresh_token", "")
    if refresh_token == "":
        return false
    
    user_data = JSON.parse_string(OS.get_secure_string("user_data", "{}"))
    return true

func clear_tokens() -> void:
    access_token = ""
    refresh_token = ""
    user_data = {}
    OS.delete_secure_string("refresh_token")
    OS.delete_secure_string("user_data")

func get_auth_header() -> String:
    return "Bearer " + access_token
```

---

## 10. Безопасность

### 10.1 Пароли тренеров

| Параметр | Значение |
|----------|----------|
| Алгоритм | bcrypt |
| Стоимость | 12 (баланс безопасности/производительности) |
| Соль | Автоматическая (bcrypt генерирует) |
| Минимальная длина | 8 символов |
| Требования | Минимум 1 буква + 1 цифра |

### 10.2 PIN-коды дилеров

| Параметр | Значение |
|----------|----------|
| Алгоритм | bcrypt |
| Стоимость | 10 (PIN короче, можно меньше) |
| Соль | Автоматическая |
| Лимит попыток | 5 неверных попыток → временная блокировка PIN |

### 10.3 Rate limiting

| Эндпоинт | Лимит | Окно |
|----------|-------|------|
| /auth/trainer/login | 5 запросов | 5 минут |
| /auth/trainer/register | 3 запроса | 10 минут |
| /auth/dealer/join | 10 запросов | 5 минут |
| /auth/refresh | 10 запросов | 1 час |

**При превышении:** HTTP 429 "Too Many Requests", заголовок `Retry-After: 300`

### 10.4 Защита от перебора PIN-ов

```
Попытка 1-5: обычный ответ "Invalid PIN"
Попытка 6-10: ответ через 2 секунды (delay)
Попытка 11+: блокировка PIN на 30 минут, ответ "PIN temporarily locked"
```

**Отслеживание:**
```sql
CREATE TABLE login_attempts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code   VARCHAR(20) NOT NULL,
    ip_address  VARCHAR(45) NOT NULL,
    attempted_at TIMESTAMPTZ DEFAULT NOW()
);

-- Удалить записи старше 1 часа
DELETE FROM login_attempts WHERE attempted_at < NOW() - INTERVAL '1 hour';
```

### 10.5 CORS

```python
# FastAPI CORS настройки
allow_origins = [
    "http://localhost:3000",  # веб-дашборд (локально)
    "https://dashboard.baccarat-trainer.com",  # веб-дашборд (прод)
]
allow_credentials = True
allow_methods = ["*"]
allow_headers = ["*"]
```

Для Godot-клиента CORS не нужен (это не браузер), но сервер должен принимать заголовок `Authorization`.

### 10.6 HTTPS

- **Обязателен** для всех запросов
- Сервер: SSL-сертификат (Let's Encrypt)
- Клиент: проверка SSL-сертификата (Godot по умолчанию проверяет)

---

## 11. Ошибки и их коды

### 11.1 Глобальный формат ошибки

```json
{
    "error": {
        "code": "INVALID_CREDENTIALS",
        "message": "Неверный email или пароль",
        "details": {}  // опционально, дополнительные данные
    }
}
```

### 11.2 Коды ошибок авторизации

| Код | HTTP | Описание | Для кого |
|-----|------|----------|----------|
| `INVALID_CREDENTIALS` | 401 | Неверный email или пароль | Тренер |
| `EMAIL_ALREADY_REGISTERED` | 409 | Email уже зарегистрирован | Тренер |
| `INVALID_EMAIL_FORMAT` | 422 | Неверный формат email | Тренер |
| `WEAK_PASSWORD` | 422 | Пароль слишком слабый | Тренер |
| `ROOM_NOT_FOUND` | 404 | Комната с таким кодом не найдена | Дилер |
| `INVALID_PIN` | 403 | Неверный PIN-код | Дилер |
| `PIN_LOCKED` | 403 | PIN заблокирован (слишком много попыток) | Дилер |
| `DISPLAY_NAME_TAKEN` | 409 | Имя уже занято в этой комнате | Дилер |
| `ROOM_CLOSED` | 410 | Комната закрыта или заархивирована | Дилер |
| `INVALID_TOKEN` | 401 | Токен невалиден или истёк | Все |
| `TOKEN_REVOKED` | 401 | Токен отозван (вы вышли из системы) | Все |
| `INSUFFICIENT_PERMISSIONS` | 403 | У вас нет прав для этого действия | Все |
| `RATE_LIMITED` | 429 | Слишком много запросов | Все |

---

## 12. Тест-кейсы для авторизации

### 12.1 Регистрация тренера

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Валидный email + пароль → регистрация | 201, токены выданы |
| 2 | Повторный email → регистрация | 409, "Email already registered" |
| 3 | Пароль < 8 символов | 422, "Weak password" |
| 4 | Пароль без цифр | 422, "Weak password" |
| 5 | Неверный формат email | 422, "Invalid email format" |
| 6 | Пустой email | 422, validation error |
| 7 | Пустой пароль | 422, validation error |

### 12.2 Вход тренера

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Верный email + пароль | 200, токены выданы |
| 2 | Неверный пароль | 401, "Invalid credentials" |
| 3 | Неверный email | 401, "Invalid credentials" |
| 4 | Неактивный аккаунт (is_active=false) | 403, "Account deactivated" |

### 12.3 Вход дилера

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Верный код + PIN + уникальное имя | 200, токены, is_first_login=true |
| 2 | Неверный код комнаты | 404, "Room not found" |
| 3 | Неверный PIN | 403, "Invalid PIN" |
| 4 | Верный PIN, но имя занято | 409, "Display name already taken" |
| 5 | Закрытая комната | 410, "Room is closed" |
| 6 | 6-я неверная попытка PIN | 403, "PIN temporarily locked" |
| 7 | Повторный вход (тот же PIN + имя) | 200, is_first_login=false |

### 12.4 Refresh токена

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Валидный refresh_token | 200, новые access + refresh |
| 2 | Истёкший refresh_token | 401, "Invalid or expired token" |
| 3 | Отозванный refresh_token | 401, "Token revoked" |
| 4 | Поддельный refresh_token | 401, "Invalid token" |

---

## 13. Зависимости и следующие шаги

### Что нужно перед реализацией

- [ ] Утвердить стек технологий (Python + FastAPI + PostgreSQL)
- [ ] Настроить сервер (если ещё не настроен)
- [ ] Создать репозиторий для серверного кода (или моно-репо)

### Следующий раздел для детализации

После завершения работы с авторизацией → **раздел 2.1 "Система комнат"** (детализация структуры данных комнаты, API, UI).

---

## 14. Заметки и открытые вопросы

### Вопросы для обсуждения

1. **Нужен ли тренеру PIN для входа в свою комнату?** — Сейчас: нет, тренер входит по email/паролю и видит все свои комнаты.
2. **Может ли дилер быть в нескольких комнатах одновременно?** — Сейчас: да, отдельные записи для каждой комнаты.
3. **Может ли дилер сменить имя после входа?** — Сейчас: нет, но можно добавить позже.
4. **Нужна ли верификация email тренера?** — Сейчас: нет (MVP), но можно добавить позже.
5. **Что если тренер забудет пароль?** — Добавить "Забыли пароль?" с email-сбросом (позже, не для MVP).

### Решения

| Вопрос | Решение | Обоснование |
|--------|---------|-------------|
| PIN для тренера? | Нет | Тренер входит по email/паролю, PIN только для дилеров |
| Дилер в нескольких комнатах? | Да | Отдельные записи, независимые друг от друга |
| Смена имени дилера? | Нет (MVP) | Упростить, добавить позже если нужно |
| Верификация email? | Нет (MVP) | Ускорить запуск, добавить позже |
| Восстановление пароля? | Нет (MVP) | Упростить, добавить позже |

---

> **Этот документ — финальная детализация раздела 1.1 "Авторизация и роли".**  
> **Следующий шаг:** Приступить к реализации серверной части авторизации (FastAPI + PostgreSQL).
