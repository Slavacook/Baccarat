# Детализация: Таблица лидеров комнаты

> **Раздел плана:** 6.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Раздел 1-4 (Авторизация, Комнаты, Живая сессия, Асинхронная тренировка)

---

## 1. Обзор

Таблица лидеров — это система рейтинга дилеров внутри комнаты, основанная на накопленном опыте (XP), точности и количестве раздач. Она мотивирует дилеров тренироваться больше и лучше, создавая здоровую конкуренцию.

---

## 2. Формула расчёта XP

### 2.1 Базовые очки

| Действие | XP | Описание |
|----------|----|----------|
| ✅ Правильное решение (3-я карта) | +10 | Правильно решил, нужна ли третья карта |
| ✅ Правильный выбор победителя | +10 | Правильно выбрал Player/Banker/Tie |
| ✅ Правильная выплата | +15 | Правильно рассчитал и собрал фишки |
| 🎯 Бонус за раунд без ошибок | +5 | Все действия в раунде без ошибок |
| ⚡ Бонус за скорость (< 15 сек) | +3 | Быстрое принятие решений |
| 🔥 Бонус за серию (каждые 5 раундов без ошибок) | +10 | Поощрение стабильности |
| ❌ Ошибка | +0 | Нет XP за раунд с ошибкой |
| 💀 Ошибка в survival mode | -5 | Штраф за ошибку в режиме выживания |

### 2.2 Формула расчёта XP за раунд

```python
def calculate_round_xp(round_result: dict) -> int:
    """Рассчитать XP за один раунд."""
    xp = 0
    
    # Базовые очки за правильные решения
    if round_result.get("player_third_correct"):
        xp += 10
    if round_result.get("banker_third_correct") is not None:
        if round_result["banker_third_correct"]:
            xp += 10
    if round_result.get("winner_correct"):
        xp += 10
    if round_result.get("payout_correct"):
        xp += 15
    
    # Бонус за раунд без ошибок
    if not round_result.get("errors"):
        xp += 5  # no_errors_bonus
    
    # Бонус за скорость
    if round_result.get("time_spent_seconds", 999) < 15:
        xp += 3  # speed_bonus
    
    # Штраф за ошибку в survival mode
    if round_result.get("survival_mode") and round_result.get("errors"):
        xp -= 5  # survival_penalty
    
    # Минимум 0 XP (не может быть отрицательным за раунд)
    return max(0, xp)
```

### 2.3 Бонус за серию

```python
def calculate_streak_bonus(consecutive_clean_rounds: int) -> int:
    """Рассчитать бонус за серию без ошибок."""
    if consecutive_clean_rounds > 0 and consecutive_clean_rounds % 5 == 0:
        return 10  # +10 XP каждые 5 раундов без ошибок
    return 0
```

### 2.4 Примеры расчёта

**Пример 1: Идеальный раунд (быстрый)**
```
✅ 3-я карта Игрока: +10
✅ Выбор победителя: +10
✅ Выплата: +15
🎯 Без ошибок: +5
⚡ Быстрый (12 сек): +3
Итого: 43 XP
```

**Пример 2: Раунд с ошибкой**
```
✅ 3-я карта Игрока: +10
❌ Выбор победителя (неправильно): +0
✅ Выплата: +15
💀 Ошибка в survival: -5
Итого: 20 XP
```

**Пример 3: Раунд без решений (только раздача)**
```
✅ 3-я карта Игрока: +10
✅ 3-я карта Банкира: +10
✅ Выбор победителя: +10
✅ Выплата: +15
🎯 Без ошибок: +5
⚡ Быстрый (10 сек): +3
🔥 Серия 10 раундов (5-й бонус): +10
Итого: 63 XP
```

---

## 3. Система рангов

### 3.1 Таблица рангов

| Ранг | Название | Накопленный XP | Требования | Значок |
|------|----------|----------------|------------|--------|
| 1 | Новичок | 0 | — | 🌱 |
| 2 | Стажёр | 100 | 10 раундов | 📘 |
| 3 | Дилер | 500 | 50 раундов, точность 70%+ | 🃏 |
| 4 | Профессионал | 1,500 | 200 раундов, точность 85%+ | 💼 |
| 5 | Эксперт | 3,000 | 500 раундов, точность 90%+ | 🎓 |
| 6 | Мастер | 6,000 | 1,000 раундов, точность 95%+ | 🏅 |
| 7 | Легенда | 10,000 | 2,000 раундов, точность 98%+ | 👑 |

### 3.2 Проверка повышения ранга

```python
RANKS = [
    {"rank": 1, "name": "Новичок", "xp_required": 0, "min_rounds": 0, "min_accuracy": 0, "icon": "🌱"},
    {"rank": 2, "name": "Стажёр", "xp_required": 100, "min_rounds": 10, "min_accuracy": 0, "icon": "📘"},
    {"rank": 3, "name": "Дилер", "xp_required": 500, "min_rounds": 50, "min_accuracy": 70, "icon": "🃏"},
    {"rank": 4, "name": "Профессионал", "xp_required": 1500, "min_rounds": 200, "min_accuracy": 85, "icon": "💼"},
    {"rank": 5, "name": "Эксперт", "xp_required": 3000, "min_rounds": 500, "min_accuracy": 90, "icon": "🎓"},
    {"rank": 6, "name": "Мастер", "xp_required": 6000, "min_rounds": 1000, "min_accuracy": 95, "icon": "🏅"},
    {"rank": 7, "name": "Легенда", "xp_required": 10000, "min_rounds": 2000, "min_accuracy": 98, "icon": "👑"},
]

def check_rank_up(total_xp: int, total_rounds: int, accuracy: float, current_rank: int) -> dict | None:
    """Проверить, можно ли повысить ранг."""
    for rank in RANKS:
        if rank["rank"] <= current_rank:
            continue  # Уже достигнут или ниже
        
        if (total_xp >= rank["xp_required"] and 
            total_rounds >= rank["min_rounds"] and 
            accuracy >= rank["min_accuracy"]):
            return rank  # Можно повысить
    
    return None  # Нет повышения
```

### 3.3 UI повышения ранга

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  🎉 Поздравляем!                                        │
│                                                         │
│  Ваш ранг повышен!                                      │
│                                                         │
│  📘 Стажёр  →  🃏 Дилер                                 │
│                                                         │
│  Вы набрали 500 XP и сыграли 50 раундов                 │
│  с точностью 78%.                                       │
│                                                         │
│  Продолжайте тренироваться!                             │
│  Следующий ранг: 💼 Профессионал (1,500 XP)             │
│                                                         │
│  [🎮 Продолжить]                                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Формула ранжирования

### 4.1 Как определяется позиция

Ранжирование происходит по **суммарному XP** (основной критерий). При равенстве XP — дополнительные критерии:

| Приоритет | Критерий | Описание |
|-----------|----------|----------|
| 1 | **total_xp DESC** | Чем больше XP, тем выше |
| 2 | **accuracy DESC** | При равенстве XP — выше точность |
| 3 | **avg_time_per_round ASC** | При равенстве XP и точности — быстрее |
| 4 | **last_activity DESC** | При полном равенстве — активнее недавно |

### 4.2 SQL-запрос для таблицы лидеров

```sql
WITH dealer_stats AS (
    SELECT 
        d.id AS dealer_id,
        d.display_name,
        COALESCE(SUM(rr.round_xp), 0) AS total_xp,
        COUNT(rr.id) AS rounds_completed,
        AVG(rr.accuracy) AS avg_accuracy,
        AVG(rr.time_spent_seconds) AS avg_time_per_round,
        MAX(rr.submitted_at) AS last_activity
    FROM dealers d
    LEFT JOIN round_results rr ON rr.dealer_id = d.id
    WHERE d.room_id = :room_id
      AND d.is_active = TRUE
      AND rr.submitted_at >= :period_start  -- фильтр по периоду
    GROUP BY d.id, d.display_name
)
SELECT 
    dealer_id,
    display_name,
    total_xp,
    rounds_completed,
    avg_accuracy,
    avg_time_per_round,
    last_activity,
    RANK() OVER (ORDER BY total_xp DESC, avg_accuracy DESC, avg_time_per_round ASC, last_activity DESC) AS rank
FROM dealer_stats
ORDER BY rank
LIMIT 50;
```

---

## 5. Фильтры периодов

### 5.1 Доступные периоды

| Фильтр | Период | SQL условие |
|--------|--------|-------------|
| Сегодня | 00:00 — сейчас | `submitted_at >= CURRENT_DATE` |
| Неделя | Последние 7 дней | `submitted_at >= NOW() - INTERVAL '7 days'` |
| Месяц | Последние 30 дней | `submitted_at >= NOW() - INTERVAL '30 days'` |
| Всё время | Без ограничений | Без условия |

### 5.2 UI выбора периода

```
┌─────────────────────────────────────────────────────────────────┐
│  🏆 РЕЙТИНГ КОМНАТЫ: TRAIN-A7X9                                │
│                                                                 │
│  Период: [● Сегодня] [○ Неделя] [○ Месяц] [○ Всё время]        │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ #1  🏅 Новиков Д.    ⭐ 2,450 XP  |  95%  |  142 раздачи │  │
│  │     Live: 87 | Async: 55  |  ⚡ 10.2с/раунд             │  │
│  │                                                          │  │
│  │ #2  💼 Иванов А.     ⭐ 2,280 XP  |  92%  |  138 раздач  │  │
│  │     Live: 92 | Async: 46  |  ⚡ 12.1с/раунд             │  │
│  │                                                          │  │
│  │ #3  🃏 Петрова М.    ⭐ 1,540 XP  |  78%  |  89 раздач   │  │
│  │     Live: 45 | Async: 44  |  🐢 28.3с/раунд            │  │
│  │                                                          │  │
│  │ #4  📘 Сидоров К.    ⭐ 1,200 XP  |  85%  |  76 раздач   │  │
│  │     Live: 50 | Async: 26  |  ⏱ 19.5с/раунд            │  │
│  │                                                          │  │
│  │ #5  🌱 Морозова О.   ⭐ 980 XP    |  63%  |  65 раздач   │  │
│  │     Live: 40 | Async: 25  |  🐢 41.2с/раунд            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Ваша позиция: #5 из 8                                   │  │
│  │  До #4 (Сидоров К.): 220 XP                              │  │
│  │  ████████████░░░░░░░░░░░░░░ 64%                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. API-эндпоинты

### 6.1 Получить таблицу лидеров

```
GET /api/rooms/{room_code}/leaderboard?period=today&page=1&per_page=20

Query params:
  period: today | week | month | all  (по умолчанию: all)
  session_type: all | live | async  (по умолчанию: all)
  page: int  (по умолчанию: 1)
  per_page: int  (по умолчанию: 20, макс: 100)

Authorization: Bearer <access_token>  (тренер или дилер этой комнаты)

Response 200:
{
    "leaderboard": [
        {
            "rank": 1,
            "dealer_id": "uuid",
            "display_name": "Новиков Д.",
            "rank_name": "Мастер",
            "rank_icon": "🏅",
            "total_xp": 2450,
            "accuracy": 95.0,
            "rounds_completed": 142,
            "rounds_live": 87,
            "rounds_async": 55,
            "avg_time_per_round": 10.2,
            "best_streak": 28,
            "last_activity": "2026-04-12T14:25:00Z"
        },
        ...
    ],
    "my_position": {
        "rank": 5,
        "total_dealers": 8,
        "next_rank_up": {
            "rank": 4,
            "display_name": "Сидоров К.",
            "xp_gap": 220
        },
        "previous_rank": {
            "rank": 6,
            "display_name": "Козлова Е.",
            "xp_gap_behind": 180
        },
        "progress_to_next": 0.64
    },
    "pagination": {
        "page": 1,
        "per_page": 20,
        "total": 8,
        "total_pages": 1
    }
}
```

### 6.2 Обновить XP дилера (после раунда)

```python
# server/services/xp_service.py
class XPService:
    def award_round_xp(self, dealer_id: UUID, round_result: dict, consecutive_clean_rounds: int) -> dict:
        """Начислить XP за раунд."""
        # Рассчитать базовый XP
        base_xp = calculate_round_xp(round_result)
        
        # Бонус за серию
        streak_bonus = calculate_streak_bonus(consecutive_clean_rounds)
        
        # Итого за раунд
        round_xp = base_xp + streak_bonus
        
        # Обновить в БД
        db.execute(
            """
            INSERT INTO round_results (dealer_id, round_xp, ...)
            VALUES (:dealer_id, :round_xp, ...)
            """,
            {"dealer_id": dealer_id, "round_xp": round_xp, ...}
        )
        
        # Обновить материализованное представление leaderboard
        self._refresh_leaderboard(dealer_id)
        
        # Проверить повышение ранга
        rank_up = self._check_rank_up(dealer_id)
        
        return {
            "round_xp": round_xp,
            "total_xp": self._get_total_xp(dealer_id),
            "rank_up": rank_up
        }
```

### 6.3 Получить XP-историю дилера

```
GET /api/dealers/{dealer_id}/xp-history?period=last_30_days

Response 200:
{
    "dealer_id": "uuid",
    "display_name": "Петрова М.",
    "current_total_xp": 1540,
    "current_rank": {"rank": 3, "name": "Дилер", "icon": "🃏"},
    "xp_history": [
        {"date": "2026-04-01", "xp_earned": 120, "cumulative_xp": 1200, "rounds": 8},
        {"date": "2026-04-02", "xp_earned": 85, "cumulative_xp": 1285, "rounds": 6},
        {"date": "2026-04-03", "xp_earned": 0, "cumulative_xp": 1285, "rounds": 0},
        ...
        {"date": "2026-04-12", "xp_earned": 255, "cumulative_xp": 1540, "rounds": 15}
    ],
    "rank_progression": [
        {"date": "2026-04-05", "from_rank": 1, "to_rank": 2, "from_name": "Новичок", "to_name": "Стажёр"},
        {"date": "2026-04-10", "from_rank": 2, "to_rank": 3, "from_name": "Стажёр", "to_name": "Дилер"}
    ]
}
```

---

## 7. Кэширование таблицы лидеров

### 7.1 Стратегия

Пересчитывать таблицу лидеров при каждом запросе — дорого. Используем кэширование:

| Метод | Описание |
|-------|----------|
| **Материализованное представление (PostgreSQL)** | Автообновление после каждой вставки round_results |
| **Redis-кэш** | Кэш на 5 минут, инвалидация при обновлении |
| **Инкрементальное обновление** | При новом результате — пересчитать только позицию этого дилера |

### 7.2 Реализация (материализованное представление)

```sql
-- Материализованное представление для таблицы лидеров
CREATE MATERIALIZED VIEW leaderboard_cache AS
SELECT 
    d.room_id,
    d.id AS dealer_id,
    d.display_name,
    COALESCE(SUM(rr.round_xp), 0) AS total_xp,
    COUNT(rr.id) AS rounds_completed,
    AVG(rr.accuracy) AS avg_accuracy,
    AVG(rr.time_spent_seconds) AS avg_time_per_round,
    MAX(CASE WHEN rr.session_type = 'live' THEN 1 ELSE 0 END) AS rounds_live,
    MAX(CASE WHEN rr.session_type = 'async' THEN 1 ELSE 0 END) AS rounds_async,
    MAX(rr.submitted_at) AS last_activity
FROM dealers d
LEFT JOIN round_results rr ON rr.dealer_id = d.id
WHERE d.is_active = TRUE
GROUP BY d.room_id, d.id, d.display_name;

-- Индекс для быстрого поиска
CREATE UNIQUE INDEX idx_leaderboard_cache_dealer ON leaderboard_cache(dealer_id);
CREATE INDEX idx_leaderboard_cache_room_xp ON leaderboard_cache(room_id, total_xp DESC);

-- Функция для обновления после каждого раунда
CREATE OR REPLACE FUNCTION refresh_leaderboard_cache()
RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер
CREATE TRIGGER trg_refresh_leaderboard
AFTER INSERT ON round_results
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_leaderboard_cache();
```

### 7.3 Инкрементальное обновление (альтернатива)

```python
# server/services/leaderboard_service.py
class LeaderboardService:
    def update_dealer_position(self, dealer_id: UUID) -> None:
        """Обновить позицию одного дилера (не всю таблицу)."""
        # Получить нового total_xp дилера
        new_total = self._calculate_total_xp(dealer_id)
        
        # Посчитать, сколько дилеров имеют больше XP
        higher_count = db.scalar(
            "SELECT COUNT(*) FROM leaderboard_cache WHERE room_id = :room AND total_xp > :xp",
            {"room": dealer.room_id, "xp": new_total}
        )
        
        # Обновить позицию
        new_rank = higher_count + 1
        cache.set(f"dealer_rank:{dealer_id}", new_rank, ttl=300)  # кэш на 5 мин
```

---

## 8. UI таблицы лидеров (Godot-клиент)

### 8.1 Экран таблицы лидеров

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Назад           🏆 Рейтинг: Группа А — Утро                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Период: [● Сегодня] [○ Неделя] [○ Месяц] [○ Всё время]        │
│  Тип:    [● Все] [○ Live] [○ Async]                            │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ #1 🏅 Новиков Д.    ⭐ 2,450  |  95%  |  142 раздач      │ │
│  │                                                           │ │
│  │ #2 💼 Иванов А.     ⭐ 2,280  |  92%  |  138 раздач      │ │
│  │                                                           │ │
│  │ #3 🃏 Волков И.     ⭐ 1,950  |  88%  |  120 раздач      │ │
│  │                                                           │ │
│  │ #4 🃏 Сидоров К.    ⭐ 1,720  |  85%  |  98 раздач       │ │
│  │                                                           │ │
│  │ #5 🃏 Петрова М. ← Вы  ⭐ 1,540  |  78%  |  89 раздач   │ │
│  │    До #4: 180 XP  ████████████░░░░░░░░░░ 75%             │ │
│  │                                                           │ │
│  │ #6 📘 Козлова Е.    ⭐ 1,200  |  71%  |  76 раздач       │ │
│  │                                                           │ │
│  │ #7 🌱 Морозова О.   ⭐ 980    |  63%  |  65 раздач       │ │
│  │                                                           │ │
│  │ #8 🌱 Лебедева Н.   ⭐ 450    |  55%  |  30 раздач       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ─── Ваш прогресс ───                                           │
│  Ранг: 🃏 Дилер (3/7)                                           │
│  До 💼 Профессионал: 1,540 / 1,500 XP ✅ Скоро!                 │
│  ████████████████████████░░░░ 95%                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 API для Godot-клиента

```gdscript
# scripts/leaderboard/LeaderboardClient.gd
class_name LeaderboardClient
extends Node

const BASE_URL = "https://server/api"

var http: HTTPRequest
var auth_token: String

func get_leaderboard(room_code: String, period: String = "all", 
                   session_type: String = "all", page: int = 1) -> Dictionary:
    """Получить таблицу лидеров."""
    var url = "%s/rooms/%s/leaderboard?period=%s&session_type=%s&page=%d" % [
        BASE_URL, room_code, period, session_type, page
    ]
    
    http.request(url, [
        "Content-Type: application/json",
        "Authorization: Bearer %s" % auth_token
    ], HTTPClient.METHOD_GET)
    
    # Ждём ответ
    var result = await http.request_completed
    return JSON.parse_string(result[3].get_string_from_utf8())

func get_xp_history(dealer_id: String, period: String = "last_30_days") -> Dictionary:
    """Получить XP-историю."""
    var url = "%s/dealers/%s/xp-history?period=%s" % [BASE_URL, dealer_id, period]
    
    http.request(url, [
        "Content-Type: application/json",
        "Authorization: Bearer %s" % auth_token
    ], HTTPClient.METHOD_GET)
    
    var result = await http.request_completed
    return JSON.parse_string(result[3].get_string_from_utf8())
```

---

## 9. База данных — дополнительные таблицы

### 9.1 Таблица `rank_definitions` (справочник рангов)

```sql
CREATE TABLE rank_definitions (
    id              INT PRIMARY KEY,
    rank_number     INT NOT NULL UNIQUE,
    name            VARCHAR(50) NOT NULL,
    icon            VARCHAR(10) NOT NULL,
    xp_required     INT NOT NULL,
    min_rounds      INT NOT NULL DEFAULT 0,
    min_accuracy    FLOAT NOT NULL DEFAULT 0.0,
    description     TEXT
);

INSERT INTO rank_definitions VALUES 
    (1, 'Новичок', '🌱', 0, 0, 0, 'Начало пути'),
    (2, 'Стажёр', '📘', 100, 10, 0, 'Первые шаги'),
    (3, 'Дилер', '🃏', 500, 50, 70, 'Базовые навыки освоены'),
    (4, 'Профессионал', '💼', 1500, 200, 85, 'Уверенная игра'),
    (5, 'Эксперт', '🎓', 3000, 500, 90, 'Высокая точность'),
    (6, 'Мастер', '🏅', 6000, 1000, 95, 'Почти без ошибок'),
    (7, 'Легенда', '👑', 10000, 2000, 98, 'Совершенство');
```

### 9.2 Таблица `dealer_ranks_history` (история повышений)

```sql
CREATE TABLE dealer_ranks_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dealer_id       UUID NOT NULL REFERENCES dealers(id),
    from_rank       INT NOT NULL,
    to_rank         INT NOT NULL,
    total_xp        INT NOT NULL,
    total_rounds    INT NOT NULL,
    accuracy        FLOAT NOT NULL,
    achieved_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dealer_ranks_history_dealer ON dealer_ranks_history(dealer_id);
```

---

## 10. Тест-кейсы

### 10.1 Расчёт XP

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Идеальный раунд (все правильно, быстро) | 43 XP |
| 2 | Раунд с 1 ошибкой (survival mode) | 20 XP |
| 3 | Раунд без решений (только раздача) | 0 XP (если нет действий) |
| 4 | Серия 5 раундов без ошибок | +10 бонус к 5-му раунду |
| 5 | Серия 10 раундов без ошибок | +10 бонус к 10-му раунду |
| 6 | Ошибка в survival mode | -5 XP (минимум 0 за раунд) |

### 10.2 Ранжирование

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Дилер A: 1000 XP, Б: 500 XP | A = #1, Б = #2 |
| 2 | Дилер A: 1000 XP/90%, Б: 1000 XP/95% | Б = #1 (точность выше) |
| 3 | Дилер A: 1000 XP/90%/15с, Б: 1000 XP/90%/20с | A = #1 (быстрее) |
| 4 | Дилер A: 1000 XP/90%/15с/сегодня, Б: 1000 XP/90%/15с/неделю назад | A = #1 (активнее) |

### 10.3 Повышение ранга

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | 500 XP, 50 раундов, 78% точность | Ранг 3 (Дилер) ✅ |
| 2 | 500 XP, 40 раундов, 78% точность | Ранг 2 (Стажёр) ❌ (нужно 50 раундов) |
| 3 | 500 XP, 50 раундов, 65% точность | Ранг 2 (Стажёр) ❌ (нужно 70% точности) |
| 4 | 499 XP, 50 раундов, 78% точность | Ранг 2 (Стажёр) ❌ (нужно 500 XP) |

---

## 11. Связь с другими разделами

| Раздел | Связь |
|--------|-------|
| **3. Живая сессия** | Результаты сессии обновляют таблицу лидеров |
| **4. Асинхронная тренировка** | Async-результаты попадают в общую таблицу с фильтром |
| **5. Дашборд тренера** | Дашборд показывает позицию каждого дилера из таблицы |
| **7. Система достижений** | Достижения могут давать бонусный XP |
| **12. Аналитика** | Аналитика использует данные таблицы лидеров |

---

## 12. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Формула расчёта XP (все коэффициенты, бонусы, штрафы) | ✅ Завершено |
| 2 | Система рангов (названия, пороги XP, требования) | ✅ Завершено (7 рангов) |
| 3 | API для получения таблицы лидеров | ✅ Завершено (3 эндпоинта) |
| 4 | Кэширование таблицы (материализованное представление) | ✅ Завершено |
| 5 | UI таблицы лидеров (Godot-экран) | ✅ Завершено |

**Раздел 6: Таблица лидеров — детализация завершена полностью (5/5 пунктов).**

---

> **Этот документ — финальная детализация раздела 6.1 "Таблица лидеров".**  
> **Следующий шаг:** Приступить к детализации раздела 7 "Система достижений".
