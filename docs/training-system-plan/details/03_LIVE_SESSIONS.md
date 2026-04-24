# Детализация: Живая синхронная сессия

> **Раздел плана:** 3.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Раздел 1 (Авторизация), Раздел 2 (Система комнат)

---

## 1. Обзор

Живая синхронная сессия — это групповая тренировка, которую тренер запускает для всех участников комнаты одновременно. Все дилеры получают одинаковые раздачи карт, таймер идёт синхронно, по истечении времени — результаты фиксируются и отправляются на сервер.

### Ключевые принципы

| Принцип | Описание |
|---------|----------|
| **Синхронность** | Таймер одинаковый у всех, старт по команде тренера |
| **Одинаковые раздачи** | Seed-based генерация — все получают одинаковые карты |
| **Независимость решений** | Каждый дилер принимает решения сам, но карты одинаковые |
| **Автоматическая остановка** | По таймеру или по лимиту раундов |
| **Отправка результатов** | Автоматическая после завершения |
| **Устойчивость к обрывам** | Потеря соединения → кэширование локально → синхронизация |

---

## 2. Архитектура синхронизации

### 2.1 Выбор протокола

| Протокол | Плюсы | Минусы | Решение |
|----------|-------|--------|---------|
| **WebSocket** | Real-time, двусторонний, низкая задержка | Нужно держать соединение | ✅ **Основной** |
| HTTP Long Polling | Работает через прокси | Выше задержка, больше трафик | ❌ |
| Server-Sent Events (SSE) | Простой, real-time server→client | Только server→client | ❌ (нужен двусторонний) |
| Periodic polling | Простой | Высокая задержка, лишний трафик | ❌ |

**Решение:** WebSocket — основной протокол для real-time коммуникации.

### 2.2 Архитектура WebSocket

```
┌──────────────────────────────────────────────────────────────┐
│  GODOT-КЛИЕНТ (дилер)                                        │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  WebSocket Client (Godot WebSocketPeer)                │  │
│  │  • Подключение: wss://server/ws/sessions/{session_id}  │  │
│  │  • Отправка: результаты раунда                         │  │
│  │  • Получение: команды от тренера, обновления таймера   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────────┘
                       │ WebSocket (wss://)
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  СЕРВЕР (FastAPI)                                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  WebSocket Manager                                      │  │
│  │  • Хранит активные соединения по session_id            │  │
│  │  • Рассылает сообщения всем участникам сессии          │  │
│  │  • Обрабатывает disconnect                               │  │
│  │  • Синхронизирует таймер                               │  │
│  └────────────────────┬───────────────────────────────────┘  │
│                       │                                       │
│  ┌────────────────────▼───────────────────────────────────┐  │
│  │  Session Controller                                     │  │
│  │  • Создание сессии                                      │  │
│  │  • Генерация seed раздач                                │  │
│  │  • Управление состоянием сессии                        │  │
│  │  • Обработка результатов                                │  │
│  └────────────────────┬───────────────────────────────────┘  │
│                       │                                       │
│  ┌────────────────────▼───────────────────────────────────┐  │
│  │  PostgreSQL                                             │  │
│  │  • Таблица sessions                                     │  │
│  │  • Таблица round_results                                │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 2.3 Состояния сессии

```
┌──────────┐    тренер      ┌──────────┐   таймер/лимит   ┌───────────┐
│ CREATED  │ ────────────→ │  ACTIVE   │ ────────────────→│ COMPLETED │
│          │   "start"      │          │   или "end"       │           │
└──────────┘                └──────────┘                   └───────────┘
                               │
                               │ disconnect всех
                               ▼
                        ┌───────────┐
                        │ ABORTED   │
                        └───────────┘
```

| Статус | Описание | Что могут делать дилеры |
|--------|----------|-------------------------|
| CREATED | Сессия создана, ожидает старта | Видят экран "Ожидание..." |
| ACTIVE | Сессия активна, идёт тренировка | Играют, отправляют результаты |
| COMPLETED | Сессия завершена (по таймеру/лимит) | Видят результаты, не могут играть |
| ABORTED | Сессия прервана (тренер/обрыв) | Видят сообщение об отмене |

---

## 3. Протокол WebSocket-сообщений

### 3.1 Формат сообщений

Все сообщения — JSON с обязательным полем `type`:

```json
{
  "type": "session_start",
  "data": { ... },
  "timestamp": "2026-04-12T14:00:00Z"
}
```

### 3.2 Сервер → Клиент (события от сервера)

| Тип | Когда отправляется | Данные |
|-----|-------------------|--------|
| `session_created` | Тренер создал сессию | `{session_id, room_code, settings, max_rounds}` |
| `session_starting` | Тренер нажал "Старт" (обратный отсчёт 5 сек) | `{start_in_seconds: 5}` |
| `session_started` | Сессия началась | `{session_id, seed, total_rounds_or_time, started_at}` |
| `timer_tick` | Каждые 10 секунд (обновление таймера) | `{remaining_seconds: 1200}` |
| `session_ended` | Сессия завершена (таймер/лимит) | `{reason: "time_limit" \| "round_limit" \| "trainer_end", ended_at}` |
| `session_aborted` | Сессия прервана тренером | `{reason: "trainer_abort"}` |
| `round_seed` | Каждая новая раздача | `{round_number, round_seed, cards_hash}` |
| `dealer_joined` | Новый дилер подключился | `{dealer_id, display_name, total_online}` |
| `dealer_left` | Дилер отключился | `{dealer_id, display_name, total_online}` |
| `ping` | Проверка соединения (каждые 30 сек) | `{server_time: 1713024000}` |
| `error` | Ошибка на сервере | `{code: "...", message: "..."}` |

### 3.3 Клиент → Сервер (события от клиента)

| Тип | Когда отправляется | Данные |
|-----|-------------------|--------|
| `join_session` | Дилер подключился к сессии | `{dealer_id, token}` |
| `ready` | Дилер готов к старту | `{dealer_id}` |
| `round_result` | Раунд завершён | `{round_number, accuracy, errors, time_spent, ...}` |
| `heartbeat` | Каждые 15 секунд (keepalive) | `{dealer_id, client_time}` |
| `reconnect` | Дилер переподключился после обрыва | `{dealer_id, token, last_round_received}` |
| `ping` | Ответ на ping сервера | `{client_time: 1713024000}` |

### 3.4 Примеры сообщений

**Сервер → Дилер: обратный отсчёт до старта**
```json
{
  "type": "session_starting",
  "data": {
    "start_in_seconds": 5,
    "countdown": true
  },
  "timestamp": "2026-04-12T14:00:00Z"
}
```

**Сервер → Дилер: сессия началась**
```json
{
  "type": "session_started",
  "data": {
    "session_id": "uuid",
    "seed": "a1b2c3d4e5f6...",
    "duration_seconds": 1800,
    "max_rounds": null,
    "started_at": "2026-04-12T14:00:05Z"
  },
  "timestamp": "2026-04-12T14:00:05Z"
}
```

**Сервер → Дилер: новая раздача**
```json
{
  "type": "round_seed",
  "data": {
    "round_number": 1,
    "round_seed": "x7k9m2p4...",
    "cards_hash": "sha256:abc123..."
  },
  "timestamp": "2026-04-12T14:00:10Z"
}
```

**Дилер → Сервер: результат раунда**
```json
{
  "type": "round_result",
  "data": {
    "round_number": 1,
    "accuracy": 100.0,
    "errors": [],
    "time_spent_seconds": 18,
    "player_third_card": true,
    "banker_third_card": false,
    "winner_chosen": "Player",
    "winner_correct": true,
    "payout_correct": true,
    "lives_remaining": 7
  },
  "timestamp": "2026-04-12T14:00:28Z"
}
```

---

## 4. Seed-генерация раздач

### 4.1 Принцип

Чтобы все дилеры получили **одинаковые раздачи**, используется seed-based генерация:

```
1. При создании сессии сервер генерирует MASTER_SEED
2. MASTER_SEED сохраняется в БД
3. Для каждого раунда N: ROUND_SEED = hash(MASTER_SEED + str(N))
4. Клиент получает ROUND_SEED и генерирует карты локально
5. Все дилеры с одинаковым ROUND_SEED получат одинаковые карты
```

### 4.2 Алгоритм на сервере

```python
import hashlib
import secrets

def generate_master_seed() -> str:
    """Генерирует криптографически случайный seed."""
    return secrets.token_hex(32)  # 64 hex-символа

def generate_round_seed(master_seed: str, round_number: int) -> str:
    """Генерирует seed для конкретного раунда."""
    combined = f"{master_seed}:round:{round_number}"
    return hashlib.sha256(combined.encode()).hexdigest()
```

### 4.3 Алгоритм на клиенте (Godot)

```gdscript
# scripts/session/SessionCardGenerator.gd
class_name SessionCardGenerator
extends RefCounted

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func set_seed(round_seed: String) -> void:
    # Конвертируем hex в int для Godot RNG
    var seed_int = int(round_seed.hex_decode())
    rng.seed = seed_int

func generate_deck() -> Array:
    """Генерирует колоду из 8 × 52 = 416 карт."""
    var suits = ["clubs", "hearts", "spades", "diamonds"]
    var ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    var deck = []
    
    for _i in range(8):  # 8 колод
        for suit in suits:
            for rank in ranks:
                deck.append({"suit": suit, "rank": rank})
    
    # Перемешиваем с использованием seeded RNG
    deck.shuffle_custom(rng)
    return deck

func draw_cards(deck: Array, count: int) -> Array:
    """Вытягивает N карт из колоды."""
    return deck.slice(0, count)
```

### 4.4 Верификация честности

```
1. Сервер отправляет round_seed + cards_hash (SHA256 раздач)
2. Клиент генерирует карты локально
3. После сессии сервер раскрывает MASTER_SEED
4. Клиент может проверить, что карты были честными:
   hash(MASTER_SEED + round_number) == round_seed ✓
```

---

## 5. Жизненный цикл живой сессии (пошагово)

### 5.1 Фаза 1: Создание сессии

```
ТРЕНЕР:
1. В дашборде комнаты нажимает "Создать сессию"
2. Настраивает параметры (или использует настройки комнаты по умолчанию)
3. Нажимает "Создать"

СЕРВЕР:
1. Создаёт запись в sessions (status = CREATED)
2. Генерирует MASTER_SEED
3. Открывает WebSocket-канал
4. Рассылает всем подключённым дилерам: session_created

ДИЛЕР:
1. Получает session_created
2. Подключается к WebSocket: wss://server/ws/sessions/{session_id}
3. Отправляет: join_session
4. Видит экран "Ожидание старта сессии..."
```

### 5.2 Фаза 2: Обратный отсчёт

```
ТРЕНЕР:
1. Видит список подключённых дилеров (кто online)
2. Нажимает "Начать сессию"

СЕРВЕР:
1. Отправляет всем: session_starting {start_in_seconds: 5}
2. Запускает обратный отсчёт: 5, 4, 3, 2, 1

ДИЛЕР:
1. Видит обратный отсчёт на экране
2. Готовится к началу
```

### 5.3 Фаза 3: Сессия активна

```
СЕРВЕР:
1. Отправляет: session_started {session_id, seed, duration, started_at}
2. Устанавливает статус сессии: ACTIVE
3. Отправляет: round_seed {round_number: 1, round_seed, cards_hash}
4. Запускает таймер (обратный отсчёт)
5. Каждые 10 сек отправляет: timer_tick {remaining_seconds: N}
6. Каждые 30 сек отправляет: ping

ДИЛЕР:
1. Получает session_started → начинает игру
2. Получает round_seed → генерирует карты локально
3. Играет раунд
4. После раунда отправляет: round_result
5. Получает round_seed для раунда 2 → повторяет
6. Отправляет heartbeat каждые 15 сек
```

### 5.4 Фаза 4: Завершение сессии

```
СЕРВЕР (авто по таймеру):
1. Таймер достиг 0 → статус COMPLETED
2. Отправляет всем: session_ended {reason: "time_limit", ended_at}
3. Закрывает WebSocket-канал
4. Собирает все round_result в БД
5. Рассчитывает итоговую статистику

СЕРВЕР (по лимиту раундов):
1. Последний дилер достиг max_rounds → статус COMPLETED
2. Отправляет: session_ended {reason: "round_limit", ended_at}

СЕРВЕР (тренер завершил вручную):
1. Тренер нажимает "Завершить сессию"
2. Отправляет: session_ended {reason: "trainer_end", ended_at}

ДИЛЕР:
1. Получает session_ended
2. Игра останавливается
3. Видит экран с результатами своей сессии
```

### 5.5 Фаза 5: Результаты

```
СЕРВЕР:
1. Агрегирует результаты всех дилеров
2. Обновляет статистику комнаты
3. Обновляет таблицу лидеров
4. Проверяет достижения
5. Отправляет уведомление тренеру: "Сессия завершена, результаты готовы"

ТРЕНЕР:
1. Получает уведомление
2. Открывает дашборд → видит обновлённые данные

ДИЛЕР:
1. Видит свои результаты сессии
2. Видит обновлённую позицию в таблице лидеров
```

---

## 6. UI-состояния дилера во время сессии

### 6.1 Экран ожидания (CREATED)

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ⏳ Ожидание старта сессии                              │
│                                                         │
│  Комната: Группа А — Утро                               │
│  Тренер: Иванов И.                                      │
│                                                         │
│  Подключились: 7 из 8 участников                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │  🟢 Петрова М.                                  │   │
│  │  🟢 Сидоров К.                                  │   │
│  │  🟢 Новиков Д.                                  │   │
│  │  🟢 Волков И.                                   │   │
│  │  🟢 Козлова Е.                                  │   │
│  │  🟢 Морозова О.                                 │   │
│  │  🟢 Лебедева Н.                                 │   │
│  │  ⚫ Иванов А. (не подключился)                   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Тренируйтесь в своём темпе после старта.               │
│  Удачи! 🍀                                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 6.2 Обратный отсчёт

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│              🚀 Сессия начинается через...               │
│                                                         │
│                    ┌─────┐                              │
│                    │  5  │                              │
│                    └─────┘                              │
│                                                         │
│  Приготовьтесь! Раздачи начнутся автоматически.        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 6.3 Игра (ACTIVE)

```
┌─────────────────────────────────────────────────────────┐
│  СЕССИЯ: TRAIN-A7X9  |  ⏱ 18:42  |  Раздача #23        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [обычный геймплей Баккара — без изменений]             │
│                                                         │
│  Точность: 87%  |  Ошибок: 3  |  ❤️ 4/7               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Отличия от обычной игры:**
- Добавлен таймер в шапку
- Номер раздачи вместо "Раунд"
- Нельзя выйти в главное меню (только завершить сессию)
- Результаты отправляются автоматически

### 6.4 Завершение сессии

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ✅ Сессия завершена!                                   │
│                                                         │
│  ─── Ваши результаты ───                                │
│                                                         │
│  Раздач сыграно:     23                                 │
│  Точность:            87%                               │
│  Ошибок:              3                                 │
│  Среднее время:       22 сек/раунд                     │
│  Жизней осталось:     4/7                               │
│                                                         │
│  ─── Позиция в таблице ───                              │
│                                                         │
│  Текущий ранг: #4 из 7                                  │
│                                                         │
│  [📊 Подробнее]  [🏆 Таблица лидеров]  [🏠 В лобби]    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 7. Обработка обрывов соединения

### 7.1 Стратегия

| Сценарий | Поведение клиента | Поведение сервера |
|----------|-------------------|-------------------|
| Краткий обрыв (< 30 сек) | Пытается переподключиться | Ждёт, не удаляет из сессии |
| Средний обрыв (30 сек - 5 мин) | Пытается переподключиться | Помечает как "disconnected" |
| Долгий обрыв (> 5 мин) | Пытается переподключиться | Считает "left", сохраняет прогресс |
| Сессия завершена во время обрыва | Показывает результаты при подключении | Сохраняет результаты до обрыва |

### 7.2 Механизм переподключения

```gdscript
# scripts/session/SessionWebSocket.gd
class_name SessionWebSocket
extends Node

const MAX_RECONNECT_ATTEMPTS = 10
const RECONNECT_DELAY_BASE = 1.0  # секунды

var ws: WebSocketPeer
var session_id: String
var dealer_id: String
var auth_token: String
var reconnect_attempts: int = 0
var last_round_received: int = 0

func _process(delta: float) -> void:
    if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
        if reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
            var delay = RECONNECT_DELAY_BASE * pow(2, reconnect_attempts)
            await get_tree().create_timer(delay).timeout
            _reconnect()

func _reconnect() -> void:
    reconnect_attempts += 1
    ws = WebSocketPeer.new()
    var url = "wss://server/ws/sessions/%s" % session_id
    ws.connect_to_url(url)
    
    # Ждём подключения
    while ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
        ws.poll()
        await get_tree().process_frame
    
    if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        # Отправляем reconnect с последним полученным раундом
        var msg = JSON.stringify({
            "type": "reconnect",
            "data": {
                "dealer_id": dealer_id,
                "token": auth_token,
                "last_round_received": last_round_received
            }
        })
        ws.send_text(msg)
        reconnect_attempts = 0

func _on_round_completed(round_number: int) -> void:
    last_round_received = round_number
```

### 7.3 Локальное кэширование результатов

```gdscript
# scripts/session/SessionResultCache.gd
class_name SessionResultCache
extends Node

const CACHE_FILE = "user://session_cache_%s.json"

var _results: Array = []
var _session_id: String = ""

func start_session(session_id: String) -> void:
    _session_id = session_id
    _results = []

func cache_round_result(result: Dictionary) -> void:
    _results.append(result)
    # Сохраняем на диск на случай крэша
    var file = FileAccess.open(CACHE_FILE % _session_id, FileAccess.WRITE)
    file.store_string(JSON.stringify(_results))
    file.close()

func get_cached_results() -> Array:
    return _results.duplicate()

func flush_to_server(http_client: HTTPRequest) -> void:
    """Отправляет все закэшированные результаты на сервер."""
    if _results.is_empty():
        return
    
    var body = JSON.stringify({"results": _results})
    http_client.request(
        "https://server/api/sessions/%s/results/batch" % _session_id,
        ["Content-Type: application/json", "Authorization: Bearer %s" % auth_token],
        HTTPClient.METHOD_POST,
        body
    )
    
    # Ждём подтверждения
    # ... (обработка ответа)
    
    # Очищаем кэш после успешной отправки
    _results.clear()
    var dir = DirAccess.open("user://")
    dir.remove(CACHE_FILE % _session_id)

func load_from_cache() -> bool:
    """Загружает кэшированные результаты при переподключении."""
    var path = CACHE_FILE % _session_id
    if not FileAccess.file_exists(path):
        return false
    
    var file = FileAccess.open(path, FileAccess.READ)
    _results = JSON.parse_string(file.get_as_text())
    file.close()
    return true
```

---

## 8. База данных — таблицы сессий

### 8.1 Таблица `sessions`

```sql
CREATE TABLE sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id             UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    trainer_id          UUID NOT NULL REFERENCES trainers(id),
    status              VARCHAR(20) DEFAULT 'created',  -- created, active, completed, aborted
    type                VARCHAR(10) DEFAULT 'live',     -- live, async
    master_seed         VARCHAR(255) NOT NULL,
    duration_seconds    INT NOT NULL,                   -- из настроек комнаты
    max_rounds          INT,                            -- NULL = без лимита
    started_at          TIMESTAMPTZ,
    ended_at            TIMESTAMPTZ,
    end_reason          VARCHAR(30),  -- time_limit, round_limit, trainer_end, trainer_abort
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    created_by          UUID NOT NULL REFERENCES trainers(id)
);

CREATE INDEX idx_sessions_room ON sessions(room_id);
CREATE INDEX idx_sessions_trainer ON sessions(trainer_id);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_started_at ON sessions(started_at);
```

### 8.2 Таблица `round_results`

```sql
CREATE TABLE round_results (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    dealer_id           UUID NOT NULL REFERENCES dealers(id),
    round_number        INT NOT NULL,
    
    -- РЕЗУЛЬТАТЫ
    accuracy            FLOAT NOT NULL,  -- 0.0 - 100.0
    errors              JSONB NOT NULL DEFAULT '[]',  -- [{type, message, timestamp}]
    time_spent_seconds  INT NOT NULL,
    
    -- РЕШЕНИЯ ДИЛЕРА
    player_third_card   BOOLEAN,  -- заказал ли третью карту игроку
    banker_third_card   BOOLEAN,  -- заказал ли третью карту банкиру
    player_third_correct BOOLEAN, -- правильно ли решил про 3-ю карту игрока
    banker_third_correct BOOLEAN, -- правильно ли решил про 3-ю карту банкира
    winner_chosen       VARCHAR(10),  -- Player, Banker, Tie
    winner_correct      BOOLEAN,
    payout_correct      BOOLEAN,
    
    -- СОСТОЯНИЕ
    lives_remaining     INT,  -- если survival_mode
    hearts_pledged      INT,  -- сколько жизней в залоге
    
    -- ВРЕМЯ
    started_at          TIMESTAMPTZ DEFAULT NOW(),
    submitted_at        TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(session_id, dealer_id, round_number)
);

CREATE INDEX idx_round_results_session ON round_results(session_id);
CREATE INDEX idx_round_results_dealer ON round_results(dealer_id);
CREATE INDEX idx_round_results_round ON round_results(session_id, round_number);
```

### 8.3 Таблица `session_participants` (кто участвовал)

```sql
CREATE TABLE session_participants (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    dealer_id           UUID NOT NULL REFERENCES dealers(id),
    joined_at           TIMESTAMPTZ DEFAULT NOW(),
    left_at             TIMESTAMPTZ,
    rounds_completed    INT DEFAULT 0,
    status              VARCHAR(20) DEFAULT 'joined',  -- joined, active, disconnected, completed, left
    
    UNIQUE(session_id, dealer_id)
);

CREATE INDEX idx_session_participants_session ON session_participants(session_id);
```

---

## 9. Опоздавшие дилеры

### 9.1 Сценарий

```
14:00 — Тренер запустил сессию (30 мин)
14:05 — Дилер Петрова вошла в комнату (опоздала на 5 мин)
14:05 — Сервер проверяет: сессия ACTIVE → подключает
14:05 — Дилер видит: "Сессия уже идёт. Осталось: 25:00"
14:05 — Дилер начинает играть с текущей раздачи
```

### 9.2 Логика

| Параметр | Поведение |
|----------|----------|
| Таймер | Идёт с общего старта (не с момента входа дилера) |
| Раздачи | Дилер получает текущую раздачу (не с начала) |
| Результаты | Считаются только раунды, которые дилер сыграл |
| Таблица лидеров | Учитывает только сыгранные раунды (accuracy, не total) |

### 9.3 UI для опоздавшего

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ⚠️ Сессия уже идёт                                     │
│                                                         │
│  Начата: 14:00                                          │
│  Осталось: 24:52                                        │
│  Текущая раздача: #5                                    │
│                                                         │
│  Вы можете присоединиться сейчас.                       │
│  Результаты будут считаться с момента вашего входа.     │
│                                                         │
│  [🎮 Присоединиться]  [❌ Отмена]                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 10. API-эндпоинты для сессий

### 10.1 Создать сессию

```
POST /api/rooms/{room_code}/sessions
Authorization: Bearer <trainer_access_token>

Request (опционально, можно без тела → настройки комнаты по умолчанию):
{
    "duration_minutes": 30,  // переопределение
    "max_rounds": 50,         // переопределение
    "settings_overrides": {
        "survival_mode": false
    }
}

Response 201:
{
    "session": {
        "id": "uuid",
        "room_code": "TRAIN-A7X9",
        "status": "created",
        "type": "live",
        "duration_seconds": 1800,
        "max_rounds": null,
        "created_at": "2026-04-12T13:55:00Z"
    },
    "websocket_url": "wss://server/ws/sessions/{session_id}"
}
```

### 10.2 Начать сессию

```
POST /api/sessions/{session_id}/start
Authorization: Bearer <trainer_access_token>

Response 200:
{
    "message": "Сессия запущена",
    "session": {
        "id": "uuid",
        "status": "active",
        "started_at": "2026-04-12T14:00:05Z",
        "ends_at": "2026-04-12T14:30:05Z"
    }
}
```

### 10.3 Завершить сессию (тренер)

```
POST /api/sessions/{session_id}/end
Authorization: Bearer <trainer_access_token>

Request:
{
    "reason": "trainer_end"
}

Response 200:
{
    "message": "Сессия завершена",
    "session": {
        "id": "uuid",
        "status": "completed",
        "ended_at": "2026-04-12T14:25:00Z",
        "end_reason": "trainer_end"
    }
}
```

### 10.4 Получить результаты сессии

```
GET /api/sessions/{session_id}/results
Authorization: Bearer <trainer_access_token>  (или dealer token этой сессии)

Response 200 (тренер — все результаты):
{
    "session": {
        "id": "uuid",
        "status": "completed",
        "duration_seconds": 1800,
        "total_rounds_all_dealers": 187,
        "started_at": "2026-04-12T14:00:05Z",
        "ended_at": "2026-04-12T14:30:05Z"
    },
    "dealers": [
        {
            "dealer_id": "uuid",
            "display_name": "Петрова М.",
            "rounds_completed": 23,
            "accuracy": 87.0,
            "total_errors": 3,
            "avg_time_per_round": 22.5
        },
        ...
    ]
}

Response 200 (дилер — только свои):
{
    "session": { ... },
    "my_results": {
        "rounds_completed": 23,
        "accuracy": 87.0,
        "total_errors": 3,
        "error_breakdown": {
            "banker_third_card": 2,
            "payout_tie": 1
        },
        "rounds": [
            {
                "round_number": 1,
                "accuracy": 100.0,
                "errors": [],
                "time_spent_seconds": 18
            },
            ...
        ]
    }
}
```

---

## 11. Тест-кейсы

### 11.1 Создание и запуск

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Тренер создаёт сессию | 201, session_id, websocket_url |
| 2 | Дилер подключается к CREATED сессии | WebSocket open, session_created |
| 3 | Тренер запускает сессию | 200, все получают session_starting → session_started |
| 4 | Дилер не подключился к старту | Может подключиться позже (опоздавший) |

### 11.2 Во время сессии

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Дилер играет → round_result | Сервер сохраняет, точность считается |
| 2 | Дилер отключился на 10 сек | Переподключился, продолжает с того же места |
| 3 | Дилер отключился на 10 мин | Сервер пометил "disconnected", дилер reconnect → продолжает |
| 4 | Дилер отключился на 1 час | Сервер пометил "left", результаты до обрыва сохранены |
| 5 | Опоздавший дилер входит | Видит оставшееся время, играет с текущей раздачи |

### 11.3 Завершение

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Таймер истёк | session_ended всем, результаты сохранены |
| 2 | Лимит раундов достигнут | session_ended всем, результаты сохранены |
| 3 | Тренер завершил вручную | session_ended всем, результаты сохранены |
| 4 | Тренер прервал (abort) | session_aborted всем, результаты до прерывания сохранены |
| 5 | Дилер получил session_ended | Игра остановлена, показаны результаты |

---

## 12. Связь с другими разделами

| Раздел | Связь |
|--------|-------|
| **2. Система комнат** | Сессия создаётся внутри комнаты; настройки комнаты влияют на сессию |
| **4. Асинхронная тренировка** | Асинхронная = сессия типа "async", без таймера и синхронизации |
| **5. Дашборд тренера** | Дашборд показывает real-time данные активной сессии |
| **6. Таблица лидеров** | Результаты сессии обновляют таблицу лидеров |
| **9. Серверная часть** | WebSocket-менеджер, Session Controller, БД |
| **10. Клиентская часть** | Godot WebSocket клиент, кэширование, UI |

---

## 13. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Протокол синхронизации (WebSocket) | ✅ Завершено |
| 2 | Механизм seed-генерации раздач | ✅ Завершено |
| 3 | Формат данных результата раунда | ✅ Завершено |
| 4 | Поведение при потере соединения | ✅ Завершено |
| 5 | UI-состояния дилера во время сессии | ✅ Завершено (4 экрана) |
| 6 | UI тренера во время сессии (мониторинг) | ✅ Описано (см. раздел 5 — дашборд) |
| 7 | Процесс завершения сессии | ✅ Завершено |

**Раздел 3: Живая синхронная сессия — детализация завершена полностью (7/7 пунктов).**

---

> **Этот документ — финальная детализация раздела 3.1 "Живая синхронная сессия".**  
> **Следующий шаг:** Приступить к детализации раздела 4 "Асинхронная тренировка".
