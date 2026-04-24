# Детализация: Система достижений

> **Раздел плана:** 7.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Раздел 1-4 (Авторизация, Комнаты, Живая сессия, Асинхронная тренировка), Раздел 6 (Табблица лидеров)

---

## 1. Обзор

Система достижений — это геймификация процесса обучения. Дилеры получают награды за выполнение определённых условий, что мотивирует тренироваться больше и развиваться в разных аспектах игры.

---

## 2. База достижений

### 2.1 Полный список достижений (30 штук)

#### 🎯 Категория: Первые шаги

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `first_step` | Первый шаг | Завершить 1 раунд без ошибок | 🌟 | 20 | `rounds_without_errors >= 1` |
| `first_session` | Первая сессия | Завершить первую тренировочную сессию | 🎮 | 30 | `sessions_completed >= 1` |
| `first_live` | В живую | Участвовать в первой живой сессии | 📡 | 25 | `live_sessions_completed >= 1` |
| `first_10` | Десятка | Сыграть 10 раундов | 🔟 | 50 | `total_rounds >= 10` |

#### 🔥 Категория: Серии без ошибок

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `streak_5` | На огне | 5 раундов подряд без ошибок | 🔥 | 50 | `best_streak >= 5` |
| `streak_10` | Непробиваемый | 10 раундов подряд без ошибок | 💪 | 100 | `best_streak >= 10` |
| `streak_25` | Стальной | 25 раундов подряд без ошибок | ⚡ | 200 | `best_streak >= 25` |
| `streak_50` | Легендарная серия | 50 раундов подряд без ошибок | 👑 | 500 | `best_streak >= 50` |

#### 📊 Категория: Точность

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `accuracy_80` | Крепкий орешек | Точность 80%+ за 50 раундов | 🎯 | 100 | `rounds >= 50 AND accuracy >= 80` |
| `accuracy_90` | Снайпер | Точность 90%+ за 100 раундов | 🏹 | 200 | `rounds >= 100 AND accuracy >= 90` |
| `accuracy_95` | Хирург | Точность 95%+ за 200 раундов | 🔬 | 300 | `rounds >= 200 AND accuracy >= 95` |
| `accuracy_100_session` | Идеальная сессия | 100% точность за сессию (мин. 20 раундов) | 💎 | 150 | `session_accuracy == 100 AND session_rounds >= 20` |

#### ⚡ Категория: Скорость

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `speed_15` | Быстрые руки | Среднее время < 15 сек за 30 раундов | ⚡ | 75 | `rounds >= 30 AND avg_time <= 15` |
| `speed_10` | Молния | Среднее время < 10 сек за 50 раундов | 🌩️ | 150 | `rounds >= 50 AND avg_time <= 10` |
| `speed_5_round` | Пять за минуту | 5 раундов за 60 секунд (каждый < 12 сек) | 💨 | 100 | `five_rounds_under_60_sec >= 1` |

#### 💰 Категория: Выплаты

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `payout_10` | Кассир | 10 правильных выплат подряд | 💰 | 75 | `consecutive_correct_payouts >= 10` |
| `payout_50` | Банкир | 50 правильных выплат подряд | 🏦 | 200 | `consecutive_correct_payouts >= 50` |
| `payout_tie_master` | Мастер ничьих | 10 правильных выплат Ничья подряд | 🤝 | 100 | `consecutive_correct_tie_payouts >= 10` |
| `payout_pair_master` | Мастер пар | 10 правильных выплат Пары подряд | 🎰 | 100 | `consecutive_correct_pair_payouts >= 10` |

#### 🃏 Категория: mastery по правилам

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `player_third_master` | Знаток игрока | 50 правильных решений по 3-й карте игрока (100%) | 📘 | 150 | `player_third_correct == 50 AND player_third_accuracy == 100` |
| `banker_third_master` | Знаток банкира | 50 правильных решений по 3-й карте банкира (100%) | 📗 | 150 | `banker_third_correct == 50 AND banker_third_accuracy == 100` |
| `winner_master` | Верный выбор | 100 правильных выборов победителя подряд | 🏆 | 200 | `consecutive_correct_winners >= 100` |

#### 🏆 Категория: Объем

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `rounds_100` | Сотня | 100 раундов суммарно | 💯 | 100 | `total_rounds >= 100` |
| `rounds_500` | Полтысячи | 500 раундов суммарно | 🎪 | 200 | `total_rounds >= 500` |
| `rounds_1000` | Тысячник | 1,000 раундов суммарно | 🏅 | 500 | `total_rounds >= 1000` |
| `rounds_5000` | Легенда тренировки | 5,000 раундов суммарно | 👑 | 1000 | `total_rounds >= 5000` |

#### 💀 Категория: Выживание

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `survive_10` | Выживший | 10 раундов в survival mode без потери жизни | ❤️ | 100 | `survival_rounds_without_life_loss >= 10` |
| `survive_25` | Бессмертный | 25 раундов в survival mode без потери жизни | 🛡️ | 200 | `survival_rounds_without_life_loss >= 25` |
| `survive_50` | Неуязвимый | 50 раундов в survival mode без потери жизни | ⭐ | 500 | `survival_rounds_without_life_loss >= 50` |
| `comeback` | Возрождение | Проиграть все жизни, но продолжить тренировку (новая сессия) | 🔄 | 50 | `full_wipe_sessions >= 1` |

#### 🎓 Категория: Ранги

| ID | Название | Описание | Иконка | XP-награда | Условие |
|----|----------|----------|--------|------------|---------|
| `rank_dealer` | Дилер | Достичь ранга «Дилер» | 🃏 | 100 | `rank >= 3` |
| `rank_pro` | Профессионал | Достичь ранга «Профессионал» | 💼 | 200 | `rank >= 4` |
| `rank_expert` | Эксперт | Достичь ранга «Эксперт» | 🎓 | 300 | `rank >= 5` |
| `rank_master` | Мастер | Достичь ранга «Мастер» | 🏅 | 500 | `rank >= 6` |
| `rank_legend` | Легенда | Достичь ранга «Легенда» | 👑 | 1000 | `rank >= 7` |

### 2.2 Структура данных достижения

```python
class Achievement(BaseModel):
    id: str                    # Уникальный ID (snake_case)
    name: str                  # Название на русском
    description: str           # Описание условия
    icon: str                  # Эмодзи-иконка
    category: str              # first_steps, streaks, accuracy, speed, payouts, rules, volume, survival, ranks
    xp_reward: int             # Награда в XP
    condition: dict            # Условие разблокировки
    hidden: bool               # Скрытое достижение (не показывать до разблокировки)
    created_at: datetime
```

---

## 3. Проверка условий достижений

### 3.1 Когда проверяются достижения

| Событие | Какие достижения проверяются |
|---------|------------------------------|
| Завершение раунда | Серии, точность, скорость, выплаты, survival |
| Завершение сессии | Объем, первая сессия, идеальная сессия |
| Повышение ранга | Достижения рангов |
| При загрузке профиля | Все (для восстановления после бага) |

### 3.2 Алгоритм проверки

```python
# server/services/achievement_service.py
class AchievementService:
    
    def check_achievements_on_round_complete(self, dealer_id: UUID, round_result: dict) -> list:
        """Проверить достижения после завершения раунда."""
        unlocked = []
        
        # Получить статистику дилера
        stats = self._get_dealer_stats(dealer_id)
        
        for achievement in self._get_applicable_achievements("round"):
            if self._check_condition(achievement, stats):
                if self._unlock_achievement(dealer_id, achievement):
                    unlocked.append(achievement)
        
        return unlocked
    
    def check_achievements_on_session_complete(self, dealer_id: UUID, session_stats: dict) -> list:
        """Проверить достижения после завершения сессии."""
        unlocked = []
        
        stats = self._get_dealer_stats(dealer_id)
        stats.update(session_stats)  # объединить статистику сессии
        
        for achievement in self._get_applicable_achievements("session"):
            if self._check_condition(achievement, stats):
                if self._unlock_achievement(dealer_id, achievement):
                    unlocked.append(achievement)
        
        return unlocked
    
    def _check_condition(self, achievement: Achievement, stats: dict) -> bool:
        """Проверить условие достижения."""
        condition = achievement.condition
        
        for key, required_value in condition.items():
            actual_value = stats.get(key)
            if actual_value is None:
                return False
            
            # Поддержка операторов
            if isinstance(required_value, dict):
                if "gte" in required_value and actual_value < required_value["gte"]:
                    return False
                if "gt" in required_value and actual_value <= required_value["gt"]:
                    return False
                if "lte" in required_value and actual_value > required_value["lte"]:
                    return False
                if "eq" in required_value and actual_value != required_value["eq"]:
                    return False
            else:
                if actual_value < required_value:
                    return False
        
        return True
    
    def _unlock_achievement(self, dealer_id: UUID, achievement: Achievement) -> bool:
        """Разблокировать достижение (если ещё не разблокировано)."""
        # Проверить, не разблокировано ли уже
        existing = db.query(DealerAchievement).filter_by(
            dealer_id=dealer_id,
            achievement_id=achievement.id
        ).first()
        
        if existing:
            return False  # Уже разблокировано
        
        # Создать запись
        unlocked = DealerAchievement(
            dealer_id=dealer_id,
            achievement_id=achievement.id,
            unlocked_at=datetime.utcnow()
        )
        db.add(unlocked)
        
        # Начислить XP
        self._award_xp(dealer_id, achievement.xp_reward, reason=f"achievement_{achievement.id}")
        
        # Обновить общий прогресс
        dealer = db.query(Dealer).get(dealer_id)
        dealer.total_achievements = db.query(DealerAchievement).filter_by(
            dealer_id=dealer_id
        ).count()
        
        db.commit()
        return True
```

### 3.3 Формат условий (словарь)

```python
# Примеры условий:
{
    "best_streak": 10,                        # best_streak >= 10
    "total_rounds": {"gte": 100},             # total_rounds >= 100
    "accuracy": {"gte": 90, "rounds_gte": 100},  # accuracy >= 90 AND rounds >= 100
    "avg_time": {"lte": 15, "rounds_gte": 30},   # avg_time <= 15 AND rounds >= 30
    "session_accuracy": {"eq": 100, "session_rounds_gte": 20},  # accuracy == 100 AND rounds >= 20
    "rank": {"gte": 3}                        # rank >= 3
}
```

---

## 4. UI экрана достижений

### 4.1 Экран «Мои достижения» (дилер)

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Назад           🏆 Мои достижения                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Разблокировано: 12 / 30                                        │
│  ██████████████░░░░░░░░░░░░░░ 40%                              │
│                                                                 │
│  Фильтр: [● Все] [🎯 Первые шаги] [🔥 Серии] [📊 Точность]    │
│          [⚡ Скорость] [💰 Выплаты] [🃏 Правила] [🏆 Объем]     │
│          [💀 Выживание] [🎓 Ранги]                              │
│                                                                 │
│  ─── Разблокированные ───                                       │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 🌟 Первый шаг                    ✅ 12.04.2026            │ │
│  │    Завершить 1 раунд без ошибок                           │ │
│  │    +20 XP                                                │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 🔥 На огне                       ✅ 12.04.2026            │ │
│  │    5 раундов подряд без ошибок                            │ │
│  │    +50 XP                                                │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 💪 Непробиваемый                 🔒 8/10 раундов          │ │
│  │    10 раундов подряд без ошибок                           │ │
│  │    ████████████████░░░░░░░░ 80%                           │ │
│  │    +100 XP                                               │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 🎯 Снайпер                       🔒 92/100 раундов       │ │
│  │    Точность 90%+ за 100 раундов                           │ │
│  │    ██████████████████████████░░ 92%                        │ │
│  │    +200 XP                                               │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ─── Скрытые (ещё не открыты) ───                               │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ ❓ ???                                             🔒     │ │
│  │    [Нажмите, чтобы узнать больше...]                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ ❓ ???                                             🔒     │ │
│  │    [Нажмите, чтобы узнать больше...]                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Уведомление о разблокировке

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  🎉 Достижение разблокировано!                          │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │                                                   │ │
│  │                  🔥                               │ │
│  │                                                   │ │
│  │              Н Е П Р О Б И В А Е М Ы Й            │ │
│  │                                                   │ │
│  │     10 раундов подряд без ошибок                  │ │
│  │                                                   │ │
│  │              +100 XP                              │ │
│  │                                                   │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  [🎮 Продолжить]  [🏆 Все достижения]                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 5. База данных

### 5.1 Таблица `achievements` (справочник)

```sql
CREATE TABLE achievements (
    id              VARCHAR(50) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    description     TEXT NOT NULL,
    icon            VARCHAR(10) NOT NULL,
    category        VARCHAR(30) NOT NULL,
    xp_reward       INT NOT NULL DEFAULT 0,
    condition       JSONB NOT NULL,
    hidden          BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Заполнить справочник
INSERT INTO achievements (id, name, description, icon, category, xp_reward, condition, hidden) VALUES
    ('first_step', 'Первый шаг', 'Завершить 1 раунд без ошибок', '🌟', 'first_steps', 20, '{"rounds_without_errors": {"gte": 1}}', false),
    ('streak_5', 'На огне', '5 раундов подряд без ошибок', '🔥', 'streaks', 50, '{"best_streak": 5}', false),
    ('streak_10', 'Непробиваемый', '10 раундов подряд без ошибок', '💪', 'streaks', 100, '{"best_streak": 10}', false),
    -- ... остальные 28 достижений
    ('???', '???', '???', '❓', 'hidden', 0, '{}', true);
```

### 5.2 Таблица `dealer_achievements` (разблокированные)

```sql
CREATE TABLE dealer_achievements (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dealer_id       UUID NOT NULL REFERENCES dealers(id) ON DELETE CASCADE,
    achievement_id  VARCHAR(50) NOT NULL REFERENCES achievements(id),
    unlocked_at     TIMESTAMPTZ DEFAULT NOW(),
    xp_awarded      INT NOT NULL,
    
    UNIQUE(dealer_id, achievement_id)
);

CREATE INDEX idx_dealer_achievements_dealer ON dealer_achievements(dealer_id);
CREATE INDEX idx_dealer_achievements_achievement ON dealer_achievements(achievement_id);
CREATE INDEX idx_dealer_achievements_unlocked_at ON dealer_achievements(unlocked_at);
```

---

## 6. API-эндпоинты

### 6.1 Получить достижения дилера

```
GET /api/dealers/{dealer_id}/achievements?category=all

Authorization: Bearer <access_token>

Response 200:
{
    "unlocked": [
        {
            "id": "first_step",
            "name": "Первый шаг",
            "description": "Завершить 1 раунд без ошибок",
            "icon": "🌟",
            "category": "first_steps",
            "xp_reward": 20,
            "unlocked_at": "2026-04-12T10:00:00Z"
        },
        ...
    ],
    "locked": [
        {
            "id": "streak_10",
            "name": "Непробиваемый",
            "description": "10 раундов подряд без ошибок",
            "icon": "💪",
            "category": "streaks",
            "xp_reward": 100,
            "progress": {
                "current": 8,
                "required": 10,
                "percentage": 80.0
            }
        },
        ...
    ],
    "hidden_count": 5,
    "total_achievements": 30,
    "unlocked_count": 12,
    "completion_percentage": 40.0
}
```

### 6.2 Получить новые достижения (после раунда/сессии)

```
POST /api/dealers/{dealer_id}/achievements/check
Authorization: Bearer <dealer_access_token>

Request:
{
    "context": "round_complete",  // или "session_complete"
    "stats": {
        "total_rounds": 89,
        "best_streak": 10,
        "accuracy": 92.0,
        ...
    }
}

Response 200 (если есть новые):
{
    "newly_unlocked": [
        {
            "id": "streak_10",
            "name": "Непробиваемый",
            "icon": "💪",
            "xp_reward": 100
        }
    ],
    "total_xp_earned": 100,
    "new_total_xp": 1640
}

Response 200 (если нет новых):
{
    "newly_unlocked": [],
    "total_xp_earned": 0,
    "new_total_xp": 1540
}
```

---

## 7. Скрытые достижения

### 7.1 Концепция

Некоторые достижения скрыты до их разблокировки. В UI они отображаются как `❓ ???`. При нажатии — показывается подсказка без раскрытия условия.

### 7.2 Примеры скрытых достижений

| ID | Подсказка | Реальное условие |
|----|-----------|------------------|
| `???_natural` | "Натуральная удача" | 5 натуральных (8-9) подряд |
| `???_six_lives` | "Последний шанс" | Выиграть с 1 оставшейся жизнью |
| `???_midnight` | "Полуночник" | Тренироваться после 00:00 |
| `???_marathon` | "Марафонец" | 100 раундов за одну сессию |
| `???_comeback` | "Возрождение" | Начать заново после полной потери жизней |

---

## 8. Тест-кейсы

### 8.1 Разблокировка достижений

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | 1 раунд без ошибок | `first_step` разблокировано |
| 2 | 5 раундов без ошибок | `streak_5` разблокировано |
| 3 | 10 раундов без ошибок | `streak_10` разблокировано |
| 4 | Повторная разблокировка `streak_5` | Не разблокируется повторно |
| 5 | Скрытое достижение | Не видно в списке до разблокировки |
| 6 | Достижение с несколькими условиями | Все условия должны быть выполнены |

### 8.2 Начисление XP

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Разблокировка достижения | XP начислены, total_xp обновлён |
| 2 | XP от достижения повышают ранг | Ранг повышен, уведомление о ранге |
| 3 | Несколько достижений за раз | Все XP начислены |

---

## 9. Связь с другими разделами

| Раздел | Связь |
|--------|-------|
| **6. Таблица лидеров** | Достижения дают бонусный XP, влияют на рейтинг |
| **8. Домашние задания** | Задания могут быть привязаны к достижениям |
| **11. Уведомления** | Push-уведомление при разблокировке достижения |

---

## 10. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Список достижений (30 штук, 10 категорий) | ✅ Завершено |
| 2 | Структура данных достижения | ✅ Завершено |
| 3 | Алгоритм проверки условий | ✅ Завершено |
| 4 | UI экрана достижений | ✅ Завершено (2 экрана) |
| 5 | Хранение на сервере (БД) | ✅ Завершено (2 таблицы) |
| 6 | API-эндпоинты достижений | ✅ Завершено (2 эндпоинта) |
| 7 | Скрытые достижения | ✅ Завершено (5 скрытых) |

**Раздел 7: Система достижений — детализация завершена полностью (7/7 пунктов).**

---

> **Этот документ — финальная детализация раздела 7.1 "Система достижений".**  
> **Следующий шаг:** Приступить к детализации раздела 8 "Домашние задания".
