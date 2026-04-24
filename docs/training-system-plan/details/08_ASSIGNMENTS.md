# Детализация: Домашние задания

> **Раздел плана:** 8.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Раздел 1-4 (Авторизация, Комнаты, Живая сессия, Асинхронная тренировка)

---

## 1. Обзор

Домашние задания — это инструмент тренера для направления практики дилеров. Тренер создаёт задание с конкретной целью, сроком и критериями выполнения. Дилеры видят задания в лобби комнаты и могут отслеживать свой прогресс.

---

## 2. Типы заданий

### 2.1 Полный каталог типов заданий

| ID | Название | Категория | Что измеряет | Пример |
|----|----------|-----------|--------------|--------|
| `rounds_count` | Количество раздач | Объем | Сколько раундов сыграть | "Сыграй 50 раздач" |
| `accuracy_target` | Целевая точность | Качество | Точность ≥ N% | "Точность 90%+ за 30 раздач" |
| `category_focus` | Фокус на категорию | Навык | Точность в конкретной категории | "3-я карта Банкира: 20 раздач с точностью 85%+" |
| `speed_challenge` | Скорость | Скорость | Среднее время ≤ N сек | "30 раздач со средним временем < 15 сек" |
| `streak_challenge` | Серия без ошибок | Стабильность | N раундов подряд без ошибок | "15 раундов без ошибок подряд" |
| `payout_accuracy` | Точность выплат | Выплаты | Правильные выплаты подряд | "20 правильных выплат подряд" |
| `survival_challenge` | Выживание | Режим выживания | Раундов в survival без потери жизни | "20 раундов в survival без потери жизни" |
| `tie_payout_focus` | Выплаты ничьих | Выплаты | Правильные выплаты Ничья | "10 правильных выплат Ничья" |
| `pair_payout_focus` | Выплаты пар | Выплаты | Правильные выплаты Пары | "10 правильных выплат Пары" |
| `mixed_challenge` | Смешанное задание | Комбинированное | Несколько условий одновременно | "30 раздач, точность 85%+, среднее время < 20 сек" |

### 2.2 Структура данных задания

```python
class Assignment(BaseModel):
    id: UUID                          # Уникальный ID
    room_id: UUID                     # Комната, в которой создано
    trainer_id: UUID                  # Тренер, который создал
    assignment_type: str              # Тип задания (из каталога)
    title: str                        # Название ("3-я карта Банкира")
    description: str                  # Описание условия
    target_category: str | None       # Категория (если применимо): banker_third_card, payout_tie, etc.
    
    # УСЛОВИЯ ВЫПОЛНЕНИЯ
    target_rounds: int | None         # Целевое количество раундов
    target_accuracy: float | None     # Целевая точность (%)
    target_time: float | None         # Целевое время (сек/раунд)
    target_streak: int | None         # Целевая серия без ошибок
    target_consecutive: int | None    # Целевая серия правильных действий
    
    # СРОКИ
    created_at: datetime              # Когда создано
    start_at: datetime                # Когда начинается (может быть в будущем)
    due_at: datetime                  # Срок выполнения
    is_recurring: bool                # Повторяющееся (еженедельно)
    recurrence_pattern: str | None    # "weekly", "biweekly", "monthly"
    
    # НАЗНАЧЕНИЕ
    assigned_to: str                  # "all" или конкретные dealer_id (JSON)
    
    # НАГРАДА
    bonus_xp: int                     # Бонусный XP за выполнение (0 = без бонуса)
    reward_message: str | None        # Сообщение при выполнении
    
    # СТАТУС
    status: str                       # active, completed, expired, cancelled
    completed_at: datetime | None     # Когда выполнено (последним дилером)
    cancelled_at: datetime | None     # Когда отменено
    cancelled_by: UUID | None         # Кто отменил (trainer_id)
```

### 2.3 Примеры заданий

**Пример 1: Простое — количество раздач**
```json
{
  "assignment_type": "rounds_count",
  "title": "Практика: 50 раздач",
  "description": "Сыграйте 50 раздач в любом режиме",
  "target_rounds": 50,
  "start_at": "2026-04-12T10:00:00Z",
  "due_at": "2026-04-14T23:59:59Z",
  "assigned_to": "all",
  "bonus_xp": 50
}
```

**Пример 2: Фокус на категорию**
```json
{
  "assignment_type": "category_focus",
  "title": "3-я карта Банкира",
  "description": "Потренируйте правило 3-й карты Банкира",
  "target_category": "banker_third_card",
  "target_rounds": 30,
  "target_accuracy": 90.0,
  "start_at": "2026-04-12T10:00:00Z",
  "due_at": "2026-04-16T23:59:59Z",
  "assigned_to": "all",
  "bonus_xp": 150
}
```

**Пример 3: Скорость + точность**
```json
{
  "assignment_type": "mixed_challenge",
  "title": "Быстро и точно",
  "description": "30 раздач с точностью 85%+ и средним временем < 20 сек",
  "target_rounds": 30,
  "target_accuracy": 85.0,
  "target_time": 20.0,
  "start_at": "2026-04-12T10:00:00Z",
  "due_at": "2026-04-18T23:59:59Z",
  "assigned_to": "all",
  "bonus_xp": 200
}
```

**Пример 4: Индивидуальное задание**
```json
{
  "assignment_type": "category_focus",
  "title": "Выплаты Ничья",
  "description": "Морозова О., потренируйте выплаты Ничья",
  "target_category": "payout_tie",
  "target_rounds": 15,
  "target_accuracy": 80.0,
  "start_at": "2026-04-12T10:00:00Z",
  "due_at": "2026-04-15T23:59:59Z",
  "assigned_to": ["dealer-uuid-morozova"],
  "bonus_xp": 100
}
```

---

## 3. Создание задания (UI тренера)

### 3.1 Экран создания задания

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Назад           📝 Создать задание                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Тип задания:                                                   │
│  [● Фокус на категорию] [○ Количество раздач] [○ Скорость]     │
│  [○ Серия без ошибок] [○ Выплаты] [○ Смешанное]                 │
│                                                                 │
│  ─── Основные настройки ───                                     │
│                                                                 │
│  Название:                                                      │
│  [3-я карта Банкира                           ]                 │
│                                                                 │
│  Описание (необязательно):                                      │
│  [Потренируйте правило 3-й карты Банкира      ]                 │
│  [Обратите внимание на случаи 3-6 очков        ]                │
│                                                                 │
│  ─── Условия выполнения ───                                     │
│                                                                 │
│  Категория:                                                     │
│  [3-я карта Банкира ▼]                                          │
│                                                                 │
│  Количество раундов:                                            │
│  [30]                                                           │
│                                                                 │
│  Целевая точность:                                              │
│  [90]%                                                          │
│                                                                 │
│  ─── Сроки ───                                                  │
│                                                                 │
│  Начать: [Сегодня, 12 апр ▼]  Время: [10:00 ▼]                 │
│  Срок:   [Пятница, 16 апр ▼]  Время: [23:59 ▼]                 │
│                                                                 │
│  Повторяющееся: [○ Нет] [○ Еженедельно] [○ Раз в 2 недели]     │
│                                                                 │
│  ─── Назначение ───                                             │
│                                                                 │
│  Кому: [● Всей группе]  [○ Конкретным дилерам]                 │
│                                                                 │
│  ─── Награда ───                                                │
│                                                                 │
│  Бонусный XP: [150]                                             │
│  Сообщение при выполнении (необязательно):                      │
│  [Отличная работа! Теперь вы знаете правило 3-й карты Банкира]  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              📝 Создать задание                            │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Шаблоны заданий

Тренер может выбрать из готовых шаблонов:

```
┌─────────────────────────────────────────────────────────────────┐
│  📋 Шаблоны заданий                                             │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 📘 3-я карта Банкира (базовый)                            │ │
│  │    30 раздач, точность 85%+                               │ │
│  │    [Использовать]                                          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 💰 Мастер выплат                                           │ │
│  │    20 правильных выплат подряд                             │ │
│  │    [Использовать]                                          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ ⚡ Скорость и точность                                     │ │
│  │    30 раздач, точность 85%+, время < 20 сек               │ │
│  │    [Использовать]                                          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 🔥 Серия без ошибок                                        │ │
│  │    15 раундов подряд без ошибок                           │ │
│  │    [Использовать]                                          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  [+ Создать свой шаблон]                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. UI заданий у дилера

### 4.1 Экран «Мои задания»

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Назад           📝 Мои задания                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Фильтр: [● Активные] [○ Выполненные] [○ Просроченные]         │
│                                                                 │
│  ─── Активные ───                                               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  🎯 3-я карта Банкира                                     │ │
│  │  Потренируйте правило 3-й карты Банкира.                  │ │
│  │  Обратите внимание на случаи 3-6 очков.                   │ │
│  │                                                           │ │
│  │  Цель: 30 раздач с точностью 90%+                         │ │
│  │  Бонус: +150 XP                                           │ │
│  │  Срок: до Пятницы, 16 апр, 23:59                          │ │
│  │  Назначено: Всей группе                                   │ │
│  │                                                           │ │
│  │  Прогресс: 18/30 раздач                                   │ │
│  │  Текущая точность: 87%  (нужно: 90%)                      │ │
│  │  ██████████████░░░░░░░░░░ 60%                             │ │
│  │                                                           │ │
│  │  ⚠️ Нужно ещё 3% точности!                                │ │
│  │                                                           │ │
│  │  [▶️ Продолжить тренировку]  [ℹ️ Подробнее]               │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  💰 Мастер выплат                                         │ │
│  │  20 правильных выплат подряд                              │ │
│  │  Бонус: +100 XP                                           │ │
│  │  Срок: до Воскресенья, 18 апр, 23:59                      │ │
│  │                                                           │ │
│  │  Прогресс: 12/20 выплат                                   │ │
│  │  Текущая серия: 12 ✅                                     │ │
│  │  ████████████░░░░░░░░ 60%                                 │ │
│  │                                                           │ │
│  │  [▶️ Продолжить тренировку]  [ℹ️ Подробнее]               │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Выполненное задание

```
┌───────────────────────────────────────────────────────────┐ │
│  ✅ Серия без ошибок                               ✓       │ │
│  15 раундов подряд без ошибок                             │ │
│  Бонус: +100 XP  ✅ Получено                               │ │
│                                                           │ │
│  Выполнено: 13 апр, 15:30                                 │ │
│  Реальная серия: 18 раундов                               │ │
│  ████████████████████ 100%                                │ │
│                                                           │ │
│  "Отличная работа! Рекордная серия!"                      │ │
│                                                           │ │
│  [📊 Подробнее]                                           │ │
└───────────────────────────────────────────────────────────┘ │
```

### 4.3 Просроченное задание

```
┌───────────────────────────────────────────────────────────┐ │
│  ❌ Скорость и точность                            ⏰      │ │
│  30 раздач, точность 85%+, время < 20 сек                 │ │
│  Срок: 10 апр, 23:59  (истёк 2 дня назад)                 │ │
│                                                           │ │
│  Прогресс: 22/30 раздач                                   │ │
│  ██████████████████░░░░ 73%                               │ │
│                                                           │ │
│  Задание просрочено. Обратитесь к тренеру.                │ │
│                                                           │ │
│  [ℹ️ Подробнее]                                           │ │
└───────────────────────────────────────────────────────────┘ │
```

---

## 5. Отслеживание прогресса

### 5.1 Логика отслеживания

```python
# server/services/assignment_progress_service.py
class AssignmentProgressService:
    
    def update_progress(self, dealer_id: UUID, round_result: dict) -> None:
        """Обновить прогресс заданий дилера после каждого раунда."""
        active_assignments = self._get_active_assignments_for_dealer(dealer_id)
        
        for assignment in active_assignments:
            progress = self._calculate_progress(assignment, dealer_id)
            
            # Обновить в БД
            self._save_progress(dealer_id, assignment.id, progress)
            
            # Проверить выполнение
            if self._is_completed(assignment, progress):
                self._complete_assignment(dealer_id, assignment)
    
    def _calculate_progress(self, assignment: Assignment, dealer_id: UUID) -> dict:
        """Рассчитать прогресс по заданию."""
        stats = self._get_dealer_category_stats(
            dealer_id, 
            assignment.target_category,
            assignment.start_at
        )
        
        progress = {}
        
        if assignment.target_rounds:
            progress["rounds"] = {
                "current": stats["rounds_in_category"],
                "target": assignment.target_rounds,
                "percentage": (stats["rounds_in_category"] / assignment.target_rounds) * 100
            }
        
        if assignment.target_accuracy:
            progress["accuracy"] = {
                "current": stats["accuracy_in_category"],
                "target": assignment.target_accuracy
            }
        
        if assignment.target_time:
            progress["avg_time"] = {
                "current": stats["avg_time_in_category"],
                "target": assignment.target_time
            }
        
        if assignment.target_streak:
            progress["current_streak"] = {
                "current": stats["current_clean_streak"],
                "target": assignment.target_streak
            }
        
        if assignment.target_consecutive:
            progress["consecutive_correct"] = {
                "current": stats["current_consecutive_correct"],
                "target": assignment.target_consecutive
            }
        
        return progress
    
    def _is_completed(self, assignment: Assignment, progress: dict) -> bool:
        """Проверить, выполнено ли задание."""
        if assignment.target_rounds:
            if progress["rounds"]["current"] < progress["rounds"]["target"]:
                return False
        
        if assignment.target_accuracy:
            if progress["accuracy"]["current"] < progress["accuracy"]["target"]:
                return False
        
        if assignment.target_time:
            if progress["avg_time"]["current"] > progress["avg_time"]["target"]:
                return False
        
        if assignment.target_streak:
            if progress["current_streak"]["current"] < progress["current_streak"]["target"]:
                return False
        
        if assignment.target_consecutive:
            if progress["consecutive_correct"]["current"] < progress["consecutive_correct"]["target"]:
                return False
        
        return True
    
    def _complete_assignment(self, dealer_id: UUID, assignment: Assignment) -> None:
        """Отметить задание как выполненное."""
        # Создать запись
        completion = AssignmentCompletion(
            dealer_id=dealer_id,
            assignment_id=assignment.id,
            completed_at=datetime.utcnow(),
            bonus_xp_earned=assignment.bonus_xp
        )
        db.add(completion)
        
        # Начислить бонусный XP
        if assignment.bonus_xp > 0:
            self._award_xp(dealer_id, assignment.bonus_xp, reason=f"assignment_{assignment.id}")
        
        # Обновить статус задания
        assignment.status = "completed"
        
        db.commit()
        
        # Уведомить тренера
        self._notify_trainer(assignment.trainer_id, dealer_id, assignment)
```

---

## 6. База данных

### 6.1 Таблица `assignments`

```sql
CREATE TABLE assignments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id             UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    trainer_id          UUID NOT NULL REFERENCES trainers(id),
    assignment_type     VARCHAR(30) NOT NULL,
    title               VARCHAR(200) NOT NULL,
    description         TEXT,
    target_category     VARCHAR(50),
    target_rounds       INT,
    target_accuracy     FLOAT,
    target_time         FLOAT,
    target_streak       INT,
    target_consecutive  INT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    start_at            TIMESTAMPTZ NOT NULL,
    due_at              TIMESTAMPTZ NOT NULL,
    is_recurring        BOOLEAN DEFAULT FALSE,
    recurrence_pattern  VARCHAR(20),  -- weekly, biweekly, monthly
    assigned_to         JSONB NOT NULL,  -- "all" или [dealer_id, ...]
    bonus_xp            INT NOT NULL DEFAULT 0,
    reward_message      TEXT,
    status              VARCHAR(20) DEFAULT 'active',  -- active, completed, expired, cancelled
    completed_at        TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    cancelled_by        UUID REFERENCES trainers(id)
);

CREATE INDEX idx_assignments_room ON assignments(room_id);
CREATE INDEX idx_assignments_trainer ON assignments(trainer_id);
CREATE INDEX idx_assignments_status ON assignments(status);
CREATE INDEX idx_assignments_due_at ON assignments(due_at);
```

### 6.2 Таблица `assignment_completions`

```sql
CREATE TABLE assignment_completions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dealer_id           UUID NOT NULL REFERENCES dealers(id) ON DELETE CASCADE,
    assignment_id       UUID NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    completed_at        TIMESTAMPTZ DEFAULT NOW(),
    bonus_xp_earned     INT NOT NULL,
    
    UNIQUE(dealer_id, assignment_id)
);

CREATE INDEX idx_assignment_completions_dealer ON assignment_completions(dealer_id);
CREATE INDEX idx_assignment_completions_assignment ON assignment_completions(assignment_id);
```

### 6.3 Таблица `assignment_progress` (кэш прогресса)

```sql
CREATE TABLE assignment_progress (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dealer_id           UUID NOT NULL REFERENCES dealers(id) ON DELETE CASCADE,
    assignment_id       UUID NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    rounds_completed    INT DEFAULT 0,
    accuracy            FLOAT,
    avg_time            FLOAT,
    current_streak      INT DEFAULT 0,
    consecutive_correct INT DEFAULT 0,
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(dealer_id, assignment_id)
);

CREATE INDEX idx_assignment_progress_dealer ON assignment_progress(dealer_id);
```

---

## 7. API-эндпоинты

### 7.1 Создать задание

```
POST /api/rooms/{room_code}/assignments
Authorization: Bearer <trainer_access_token>

Request:
{
    "assignment_type": "category_focus",
    "title": "3-я карта Банкира",
    "description": "Потренируйте правило 3-й карты Банкира",
    "target_category": "banker_third_card",
    "target_rounds": 30,
    "target_accuracy": 90.0,
    "start_at": "2026-04-12T10:00:00Z",
    "due_at": "2026-04-16T23:59:59Z",
    "assigned_to": "all",
    "bonus_xp": 150,
    "reward_message": "Отличная работа!"
}

Response 201:
{
    "assignment": {
        "id": "uuid",
        "assignment_type": "category_focus",
        "title": "3-я карта Банкира",
        "status": "active",
        "assigned_count": 8
    }
}
```

### 7.2 Получить задания комнаты

```
GET /api/rooms/{room_code}/assignments?status=active

Authorization: Bearer <trainer_access_token>  (или dealer token)

Response 200 (тренер):
{
    "assignments": [
        {
            "id": "uuid",
            "assignment_type": "category_focus",
            "title": "3-я карта Банкира",
            "target_rounds": 30,
            "target_accuracy": 90.0,
            "due_at": "2026-04-16T23:59:59Z",
            "assigned_to": "all",
            "bonus_xp": 150,
            "status": "active",
            "progress": {
                "completed": 3,
                "in_progress": 5,
                "not_started": 0,
                "total_assigned": 8
            }
        },
        ...
    ]
}

Response 200 (дилер):
{
    "assignments": [
        {
            "id": "uuid",
            "assignment_type": "category_focus",
            "title": "3-я карта Банкира",
            "target_rounds": 30,
            "target_accuracy": 90.0,
            "due_at": "2026-04-16T23:59:59Z",
            "bonus_xp": 150,
            "status": "active",
            "my_progress": {
                "rounds": {"current": 18, "target": 30, "percentage": 60.0},
                "accuracy": {"current": 87.0, "target": 90.0}
            },
            "is_completed": false
        },
        ...
    ]
}
```

### 7.3 Отменить задание

```
DELETE /api/assignments/{assignment_id}
Authorization: Bearer <trainer_access_token>

Response 200:
{
    "message": "Задание отменено",
    "assignment": {
        "id": "uuid",
        "status": "cancelled",
        "cancelled_at": "2026-04-12T16:00:00Z"
    }
}
```

### 7.4 Продлить срок задания

```
PATCH /api/assignments/{assignment_id}/extend
Authorization: Bearer <trainer_access_token>

Request:
{
    "new_due_at": "2026-04-20T23:59:59Z"
}

Response 200:
{
    "message": "Срок задания продлён",
    "assignment": {
        "id": "uuid",
        "due_at": "2026-04-20T23:59:59Z"
    }
}
```

---

## 8. Автоматические действия сервера

### 8.1 Cron-задачи

| Задача | Частота | Что делает |
|--------|---------|------------|
| `expire_assignments` | Каждый час | Меняет статус `active` → `expired` для заданий с `due_at < NOW()` |
| `create_recurring_assignments` | Каждый день | Создаёт новые экземпляры повторяющихся заданий |
| `notify_overdue` | Каждый день (9:00) | Уведомляет тренера о просроченных заданиях |
| `cleanup_old_assignments` | Раз в неделю | Архивирует задания старше 90 дней |

### 8.2 Уведомления при событиях

| Событие | Кому | Тип |
|---------|------|-----|
| Новое задание назначено | Дилеры | Push + внутриигровое |
| Задание выполнено | Тренер | Внутриигровое (дашборд) |
| Задание просрочено | Тренер | Email/SMS |
| 50% прогресса задания | Дилер | Внутриигровое |
| 90% прогресса задания | Дилер | Внутриигровое + push |

---

## 9. Тест-кейсы

### 9.1 Создание заданий

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Валидное задание → создание | 201, задание создано, assigned_count = N |
| 2 | Задание в прошлом → создание | 422, "start_at must be in the future or now" |
| 3 | due_at < start_at | 422, "due_at must be after start_at" |
| 4 | Пустой title | 422, "Title is required" |
| 5 | assigned_to = пустой список | 422, "Must assign to at least one dealer" |

### 9.2 Отслеживание прогресса

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Дилер играет → раунд в нужной категории | Прогресс обновлён |
| 2 | Прогресс достиг цели | Задание выполнено, XP начислены |
| 3 | Задание истекло до выполнения | Статус = expired, XP не начислены |
| 4 | Тренер отменил задание | Статус = cancelled, прогресс сброшен |
| 5 | Повторяющееся задание | Создан новый экземпляр с новым сроком |

---

## 10. Связь с другими разделами

| Раздел | Связь |
|--------|-------|
| **4. Асинхронная тренировка** | Задания выполняются в async-режиме |
| **5. Дашборд тренера** | Дашборд показывает прогресс заданий |
| **7. Система достижений** | Задания могут быть привязаны к достижениям |
| **11. Уведомления** | Push-уведомления о новых/просроченных заданиях |

---

## 11. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Структура данных задания (все поля) | ✅ Завершено |
| 2 | API для создания/получения/обновления заданий | ✅ Завершено (4 эндпоинта) |
| 3 | UI создания задания (экран тренера) | ✅ Завершено |
| 4 | UI отображения задания у дилера | ✅ Завершено (3 экрана) |
| 5 | Система уведомлений о выполнении/просрочке | ✅ Завершено |
| 6 | Рекуррентные задания (еженедельно) | ✅ Завершено |
| 7 | Шаблоны заданий | ✅ Завершено |
| 8 | Автоматические cron-задачи сервера | ✅ Завершено |

**Раздел 8: Домашние задания — детализация завершена полностью (8/8 пунктов).**

---

> **Этот документ — финальная детализация раздела 8.1 "Домашние задания".**  
> **Следующий шаг:** Приступить к детализации раздела 9 "Серверная часть".
