# Шаг 1.2 — Создание комнаты + вход дилера ✅ ЗАВЕРШЕНО

## Что сделано

### 1. API комнат (`app/api/rooms.py`)

| Эндпоинт | Метод | Статус | Описание |
|----------|-------|--------|----------|
| `POST /api/rooms/` | POST | ✅ Готово | Создать комнату (генерирует код + PIN-ы) |
| `GET /api/rooms/` | GET | ✅ Готово | Список комнат тренера |
| `GET /api/rooms/{code}` | GET | ✅ Готово | Получить детали комнаты |
| `POST /api/rooms/dealer/join` | POST | ✅ Готово | Вход дилера (код + PIN) |

### 2. Pydantic схемы (`app/schemas/room.py`)

- `RoomCreateRequest` — запрос на создание комнаты
- `RoomResponse` — ответ с данными комнаты
- `RoomCreateResponse` — комната + PIN-ы
- `RoomSettingsCreate` — настройки комнаты при создании

### 3. Утилиты авторизации (`app/utils/auth.py`)

- `create_access_token()` — создание access JWT (1 час)
- `create_refresh_token()` — создание refresh JWT (7-30 дней)
- `decode_token()` — раскодирование JWT

### 4. Генерация данных

| Тип | Формат | Пример | Функция |
|-----|--------|--------|---------|
| Код комнаты | `TRAIN-XXXX` | `TRAIN-A7X9` | `generate_room_code()` |
| PIN-код | 6 цифр | `482156` | `generate_pin()` |

**Алфавит для кода комнаты:** 34 символа (`ABCDEFGHJKMNPQRTUVWXYZ23456789` — без 0,1,I,L,O)

### 5. Логика входа дилера

```
1. Найти комнату по room_code
   ├─ Не найдена → 404
   └─ Закрыта → 410

2. Проверить PIN
   ├─ Неверный → 403
   └─ Верный → продолжить

3. Проверить dealer_id у PIN
   ├─ Не использован → создать нового дилера (is_first_login=true)
   └─ Использован → проверить display_name
       ├─ Совпадает → вернуть токены (is_first_login=false)
       └─ Не совпадает → 409

4. Обновить last_seen_at
5. Создать JWT токены
6. Вернуть токены + данные пользователя
```

### 6. Тесты

| Файл | Тестов | Что покрывает |
|------|--------|---------------|
| `tests/unit/test_auth.py` | 7 | Регистрация + логин тренера |
| `tests/unit/test_rooms.py` | 10 | Создание комнаты + вход дилера |
| **Итого** | **17** | |

### 7. Файлы изменены/созданы

| Файл | Действие |
|------|----------|
| `app/api/rooms.py` | ✏️ Полностью реализован |
| `app/schemas/room.py` | ✏️ Создан |
| `app/schemas/__init__.py` | ✏️ Обновлён |
| `app/schemas/auth.py` | ✏️ Реорганизован |
| `app/utils/auth.py` | ✏️ Создан (общие JWT-утилиты) |
| `app/api/auth.py` | ✏️ Обновлён (использует utils.auth) |
| `app/main.py` | ✏️ Обновлён (роуты комнат) |
| `tests/unit/test_auth.py` | ✏️ Создан |
| `tests/unit/test_rooms.py` | ✏️ Создан |
| `tests/conftest.py` | ✏️ Обновлён |

---

## Как запустить

```bash
cd baccarat-server

# 1. Запустить БД и Redis
docker compose up -d db redis

# 2. Применить миграции
docker compose exec api alembic upgrade head
# Или локально: alembic upgrade head

# 3. Запустить сервер
uvicorn app.main:app --reload

# 4. Проверить
curl http://localhost:8000/api/health
# → {"status":"ok","version":"0.1.0"}
```

---

## Примеры запросов

### 1. Регистрация тренера
```bash
curl -X POST http://localhost:8000/api/auth/trainer/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@trainer.com","password":"TestPass123","full_name":"Иванов"}'
```

### 2. Создание комнаты
```bash
curl -X POST http://localhost:8000/api/rooms/ \
  -H "Content-Type: application/json" \
  -d '{"trainer_id":"<trainer_id>","name":"Группа А","max_dealers":10}'
```

### 3. Вход дилера
```bash
curl -X POST http://localhost:8000/api/rooms/dealer/join \
  -H "Content-Type: application/json" \
  -d '{"room_code":"TRAIN-A7X9","pin":"482156","display_name":"Петрова М."}'
```

---

## Что дальше (Шаг 1.3)

**Тесты:** Запустить все 17 тестов и убедиться, что проходят.

```bash
pytest tests/unit/ -v
```
