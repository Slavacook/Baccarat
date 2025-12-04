# 📊 ФАЗА 1: Анализ зависимостей GamePhaseManager

Дата: 2025-12-04
Вариант: Б (Полный рефакторинг)

---

## 🔍 Найденные зависимости (48 строк)

### Категория 1: Менеджеры (через game_controller)

| Менеджер | Использование | Строки | Решение |
|----------|---------------|--------|---------|
| `payout_queue_manager` | Очередь выплат | 59, 204-205 | DI через конструктор |
| `chip_visual_manager` | Визуализация фишек | 60-61, 232, 457, 460, 492, 495 | DI через конструктор |
| `winner_selection_manager` | Выбор победителя | 62-63, 541, 545 | DI через конструктор |
| `pair_betting_manager` | Ставки на пары | 74-76, 109-110, 115-116, 481-482, 484, 511-512, 516 | DI через конструктор |
| `camera` | Камера (зум) | 89, 220-221, 577 | EventBus события |

**Всего менеджеров**: 5

### Категория 2: Прямые вызовы методов

| Метод | Строка | Что делает | Решение |
|-------|--------|------------|---------|
| `survival_ui.lose_life()` | 30 | Потеря жизни | EventBus.request_life_loss.emit() |
| `camera_zoom_in()` | 89 | Зум на карты | EventBus.camera_zoom_requested.emit("in") |
| `camera_zoom_out()` | 221 | Общий план | EventBus.camera_zoom_requested.emit("out") |
| `camera_zoom_chips()` | 577 | Зум на фишки | EventBus.camera_zoom_requested.emit("chips") |
| `_prepare_payouts_manual()` | 581 | Подготовка выплат | EventBus.manual_payout_requested.emit(winner) |

**Всего методов**: 5

### Категория 3: Флаги состояния

| Флаг | Использование | Строки | Решение |
|------|---------------|--------|---------|
| `is_first_deal` | Проверка первой раздачи | 84, 87, 90 | Передать через параметр или событие |
| `is_table_prepared_for_new_game` | Готовность стола | 82, 93, 161, 164, 238-239 | Передать через параметр или событие |

**Всего флагов**: 2

---

## 🎯 План рефакторинга

### Шаг 1: Изменить конструктор GamePhaseManager

**Было**:
```gdscript
func _init(deck_ref: Deck, card_manager_ref: CardTextureManager, ui_ref: UIManager):
    deck = deck_ref
    card_manager = card_manager_ref
    ui = ui_ref
```

**Станет**:
```gdscript
func _init(
    deck_ref: Deck,
    card_manager_ref: CardTextureManager,
    ui_ref: UIManager,
    payout_queue_mgr: PayoutQueueManager,
    chip_visual_mgr: ChipVisualManager,
    winner_selection_mgr: WinnerSelectionManager,
    pair_betting_mgr: PairBettingManager
):
    deck = deck_ref
    card_manager = card_manager_ref
    ui = ui_ref
    payout_queue_manager = payout_queue_mgr
    chip_visual_manager = chip_visual_mgr
    winner_selection_manager = winner_selection_mgr
    pair_betting_manager = pair_betting_mgr
```

### Шаг 2: Добавить поля в GamePhaseManager

```gdscript
# Новые поля (вместо game_controller)
var payout_queue_manager: PayoutQueueManager
var chip_visual_manager: ChipVisualManager
var winner_selection_manager: WinnerSelectionManager
var pair_betting_manager: PairBettingManager
```

### Шаг 3: Создать события в EventBus

```gdscript
# В EventBus.gd добавить:

# Камера
signal camera_zoom_requested(zoom_type: String)  # "in", "out", "chips"

# Survival mode (уже есть life_lost, но нужен request)
signal life_loss_requested()  # Запрос на потерю жизни

# Выплаты
signal manual_payout_requested(winner: String)  # Подготовка выплат вручную

# Флаги (опционально)
signal first_deal_completed()  # Первая раздача завершена
signal table_prepared_for_new_game()  # Стол готов к новой игре
```

### Шаг 4: Замены в GamePhaseManager

#### 4.1 Прямые вызовы методов → EventBus

```gdscript
# Строка 30
# ❌ Было:
game_controller.survival_ui.lose_life()
# ✅ Станет:
EventBus.life_loss_requested.emit()

# Строка 89
# ❌ Было:
game_controller.camera_zoom_in()
# ✅ Станет:
EventBus.camera_zoom_requested.emit("in")

# Строка 221
# ❌ Было:
game_controller.camera_zoom_out()
# ✅ Станет:
EventBus.camera_zoom_requested.emit("out")

# Строка 577
# ❌ Было:
game_controller.camera_zoom_chips()
# ✅ Станет:
EventBus.camera_zoom_requested.emit("chips")

# Строка 581
# ❌ Было:
game_controller._prepare_payouts_manual(actual_winner)
# ✅ Станет:
EventBus.manual_payout_requested.emit(actual_winner)
```

#### 4.2 Доступ к менеджерам → прямое использование

```gdscript
# Строка 59
# ❌ Было:
game_controller.payout_queue_manager = null
# ✅ Станет:
payout_queue_manager = null  # Уже есть поле!

# Строка 60-61
# ❌ Было:
if game_controller.chip_visual_manager:
    game_controller.chip_visual_manager.hide_all_chips()
# ✅ Станет:
if chip_visual_manager:
    chip_visual_manager.hide_all_chips()

# Строка 62-63
# ❌ Было:
if game_controller.winner_selection_manager:
    game_controller.winner_selection_manager.reset()
# ✅ Станет:
if winner_selection_manager:
    winner_selection_manager.reset()

# И так далее для всех менеджеров...
```

#### 4.3 Флаги состояния → локальные поля

```gdscript
# В GamePhaseManager добавить поля:
var is_first_deal: bool = true
var is_table_prepared: bool = false

# Строка 84
# ❌ Было:
print("  → is_first_deal: %s" % (game_controller.is_first_deal if game_controller else "N/A"))
# ✅ Станет:
print("  → is_first_deal: %s" % is_first_deal)

# Строка 87-90
# ❌ Было:
if game_controller and (game_controller.is_first_deal or is_prepared_table):
    game_controller.camera_zoom_in()
    game_controller.is_first_deal = false
# ✅ Станет:
if is_first_deal or is_table_prepared:
    EventBus.camera_zoom_requested.emit("in")
    is_first_deal = false
    EventBus.first_deal_completed.emit()
```

### Шаг 5: Обновить GameController

```gdscript
# В GameController._ready()

# ❌ Было:
phase_manager = GamePhaseManager.new(deck, card_manager, ui_manager)
phase_manager.set_game_controller(self)

# ✅ Станет:
phase_manager = GamePhaseManager.new(
    deck,
    card_manager,
    ui_manager,
    payout_queue_manager,
    chip_visual_manager,
    winner_selection_manager,
    pair_betting_manager
)

# Подписаться на новые события:
EventBus.camera_zoom_requested.connect(_on_camera_zoom_requested)
EventBus.life_loss_requested.connect(_on_life_loss_requested)
EventBus.manual_payout_requested.connect(_on_manual_payout_requested)
```

### Шаг 6: Удалить из GamePhaseManager

```gdscript
# ❌ Удалить:
var game_controller = null
func set_game_controller(controller) -> void:
    game_controller = controller
func on_error_occurred() -> void:  # Не нужен, используется только для survival
```

---

## 📝 Детальный список изменений

### EventBus.gd (+10 строк)
```gdscript
# Камера (3 новых события)
signal camera_zoom_requested(zoom_type: String)  # "in", "out", "chips"

# Survival mode
signal life_loss_requested()  # Запрос потери жизни

# Выплаты
signal manual_payout_requested(winner: String)

# Флаги (опционально)
signal first_deal_completed()
signal table_prepared_for_new_game()
```

### GamePhaseManager.gd

**Удалить (3 строки)**:
```gdscript
var game_controller = null  # Строка 7
func set_game_controller(controller) -> void:  # Строки 25-26
func on_error_occurred() -> void:  # Строки 28-30
```

**Добавить новые поля (+6 строк)**:
```gdscript
var payout_queue_manager: PayoutQueueManager
var chip_visual_manager: ChipVisualManager
var winner_selection_manager: WinnerSelectionManager
var pair_betting_manager: PairBettingManager
var is_first_deal: bool = true
var is_table_prepared: bool = false
```

**Изменить конструктор (+4 параметра)**:
```gdscript
func _init(
    deck_ref: Deck,
    card_manager_ref: CardTextureManager,
    ui_ref: UIManager,
    payout_queue_mgr: PayoutQueueManager,
    chip_visual_mgr: ChipVisualManager,
    winner_selection_mgr: WinnerSelectionManager,
    pair_betting_mgr: PairBettingManager
):
```

**Заменить все 48 вызовов** game_controller на:
- Прямое использование менеджеров (35 мест)
- EventBus события (5 мест)
- Локальные флаги (8 мест)

### GameController.gd

**Изменить создание phase_manager (+4 параметра)**:
```gdscript
phase_manager = GamePhaseManager.new(
    deck,
    card_manager,
    ui_manager,
    payout_queue_manager,
    chip_visual_manager,
    winner_selection_manager,
    pair_betting_manager
)
```

**Удалить**:
```gdscript
phase_manager.set_game_controller(self)
```

**Добавить подписки на события (+10 строк)**:
```gdscript
EventBus.camera_zoom_requested.connect(_on_camera_zoom_requested)
EventBus.life_loss_requested.connect(_on_life_loss_requested)
EventBus.manual_payout_requested.connect(_on_manual_payout_requested)
EventBus.first_deal_completed.connect(_on_first_deal_completed)
EventBus.table_prepared_for_new_game.connect(_on_table_prepared)

func _on_camera_zoom_requested(zoom_type: String):
    match zoom_type:
        "in": camera_zoom_in()
        "out": camera_zoom_out()
        "chips": camera_zoom_chips()

func _on_life_loss_requested():
    if is_survival_mode and survival_ui:
        survival_ui.lose_life()

func _on_manual_payout_requested(winner: String):
    _prepare_payouts_manual(winner)

func _on_first_deal_completed():
    is_first_deal = false

func _on_table_prepared():
    is_table_prepared_for_new_game = true
```

---

## 🎯 Итоговые изменения

| Файл | Добавлено | Удалено | Изменено |
|------|-----------|---------|----------|
| EventBus.gd | 10 строк | 0 | 0 |
| GamePhaseManager.gd | 10 строк | 3 строки | 48 замен |
| GameController.gd | 35 строк | 1 строка | 1 изменение |

**Всего**: ~95 строк изменений

---

## ⏱️ Оценка времени

- Шаг 1-2: Изменение конструктора и полей - 30 мин
- Шаг 3: Добавление событий в EventBus - 30 мин
- Шаг 4: Замена всех 48 вызовов - 3 часа
- Шаг 5: Обновление GameController - 1 час
- Шаг 6: Удаление game_controller - 15 мин
- Тестирование - 1.5 часа
- Исправление багов - 30 мин

**Итого**: 6-7 часов

---

Создано: 2025-12-04
Версия: 1.0
