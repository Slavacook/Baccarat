# Примеры кода проекта Baccarat

> Готовые примеры использования паттернов и API для быстрого старта

## 📡 EventBus - Примеры использования

### ✅ Правильная отправка события

```gdscript
# Отправка события о правильном действии
EventBus.action_correct.emit("player_third")

# Отправка события об ошибке
EventBus.action_error.emit("player_wrong", Localization.t("ERROR_PLAYER_THIRD"))

# Отправка события о выплате
EventBus.show_payout_popup.emit("Player", 100, 200)

# Отправка события о камере
EventBus.camera_zoom_requested.emit("in", false)
```

### ✅ Правильная подписка на события

```gdscript
# В _ready() или _init()
func _ready():
    EventBus.action_correct.connect(_on_action_correct)
    EventBus.action_error.connect(_on_action_error)
    EventBus.game_completed.connect(_on_game_completed)

# Обработчики событий
func _on_action_correct(action_type: String):
    print("Правильное действие: ", action_type)

func _on_action_error(action_type: String, message: String):
    print("Ошибка: ", action_type, " - ", message)

# Не забудь отписаться при необходимости!
func _exit_tree():
    EventBus.action_correct.disconnect(_on_action_correct)
    EventBus.action_error.disconnect(_on_action_error)
```

### ❌ НЕПРАВИЛЬНО - прямые вызовы

```gdscript
# ❌ НЕ ДЕЛАЙ ТАК!
get_node("/root/ToastManager").show_error("Ошибка")
game_controller.survival_ui.lose_life()

# ✅ ДЕЛАЙ ТАК!
EventBus.show_toast_error.emit("Ошибка")
EventBus.life_loss_requested.emit()
```

## 🏗️ Создание нового менеджера

### Шаблон менеджера с EventBus

```gdscript
# res://scripts/my_system/MyManager.gd
class_name MyManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

var some_dependency: SomeClass

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР
# ═══════════════════════════════════════════════════════════════════════════

func _init(dependency: SomeClass):
    """Инициализация менеджера
    
    Args:
        dependency: Зависимость через DI
    """
    some_dependency = dependency
    _connect_events()

# ═══════════════════════════════════════════════════════════════════════════
# ПОДПИСКА НА СОБЫТИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _connect_events() -> void:
    """Подписка на события EventBus"""
    EventBus.action_correct.connect(_on_action_correct)
    EventBus.round_reset.connect(_on_round_reset)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_action_correct(action_type: String) -> void:
    """Обработка правильного действия"""
    # Логика обработки
    pass

func _on_round_reset() -> void:
    """Сброс состояния при новом раунде"""
    # Логика сброса
    pass

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func do_something() -> void:
    """Публичный метод для выполнения действия"""
    # Валидация
    if not _validate():
        EventBus.action_error.emit("my_action", "Ошибка валидации")
        return
    
    # Выполнение
    _execute()
    
    # Уведомление через EventBus
    EventBus.action_correct.emit("my_action")

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _validate() -> bool:
    """Валидация перед выполнением"""
    return true

func _execute() -> void:
    """Выполнение действия"""
    pass
```

## 🎨 Создание UI менеджера (Phase 2 паттерн)

```gdscript
# res://scripts/ui/MyUIManager.gd
class_name MyUIManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal my_action_triggered(value: String)

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

var my_button: Button
var my_label: Label

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР
# ═══════════════════════════════════════════════════════════════════════════

func _init(scene: Node):
    """Инициализация UI менеджера
    
    Args:
        scene: Корневой узел сцены
    """
    _find_ui_nodes(scene)
    _connect_signals()

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _find_ui_nodes(scene: Node) -> void:
    """Поиск UI узлов в сцене"""
    my_button = scene.get_node("Path/To/MyButton")
    my_label = scene.get_node("Path/To/MyLabel")

func _connect_signals() -> void:
    """Подключение сигналов UI элементов"""
    if my_button:
        my_button.pressed.connect(_on_button_pressed)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ UI
# ═══════════════════════════════════════════════════════════════════════════

func _on_button_pressed() -> void:
    """Обработка нажатия кнопки"""
    my_action_triggered.emit("button_clicked")
    EventBus.action_correct.emit("my_action")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func update_label(text: String) -> void:
    """Обновление текста label"""
    if my_label:
        my_label.text = text

func set_button_enabled(enabled: bool) -> void:
    """Включение/выключение кнопки"""
    if my_button:
        my_button.disabled = not enabled
```

## 🎯 Создание координатора

```gdscript
# res://scripts/MyCoordinator.gd
class_name MyCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var manager_a: ManagerA
var manager_b: ManagerB

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР
# ═══════════════════════════════════════════════════════════════════════════

func _init(mgr_a: ManagerA, mgr_b: ManagerB):
    """Инициализация координатора
    
    Args:
        mgr_a: Первый менеджер
        mgr_b: Второй менеджер
    """
    manager_a = mgr_a
    manager_b = mgr_b

# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func coordinate_action() -> void:
    """Координация действия между менеджерами"""
    # 1. Валидация
    if not _validate():
        EventBus.action_error.emit("coordination", "Ошибка валидации")
        return
    
    # 2. Выполнение через менеджеры
    var result_a = manager_a.do_something()
    var result_b = manager_b.process(result_a)
    
    # 3. Уведомление через EventBus
    EventBus.action_correct.emit("coordination")

func _validate() -> bool:
    """Валидация перед координацией"""
    return manager_a != null and manager_b != null
```

## 💰 Работа с выплатами

```gdscript
# Создание очереди выплат
var payout_queue = PayoutQueueManager.new()
payout_queue.add_payout("Player", 100, 200)
payout_queue.add_payout("Banker", 50, 95)

# Обработка выплаты
func process_payout(payout: Dictionary) -> void:
    var winner = payout.winner
    var stake = payout.stake
    var payout_amount = payout.payout_amount
    
    # Расчёт через калькулятор
    var calculator = PayoutCalculator.new()
    var calculated = calculator.calculate(winner, stake)
    
    # Валидация через валидатор
    var validator = PayoutValidator.new(chip_stack_manager)
    var is_valid = validator.validate(calculated, user_chips)
    
    if is_valid:
        EventBus.payout_correct.emit()
    else:
        EventBus.payout_wrong.emit(validator.get_errors())
```

## 🎲 Работа с картами шанса

```gdscript
# Создание новой карты шанса
# res://scripts/chance_cards/implementations/MyChanceCard.gd
extends BaseChanceCard

func _init():
    super._init()
    card_name = "Моя карта"
    card_description = "Описание карты"

func apply_effect() -> void:
    """Применение эффекта карты"""
    # Логика эффекта
    EventBus.action_correct.emit("chance_card_applied")

# Регистрация в ChanceCardManager
ChanceCardManager.register_card(MyChanceCard.new())
```

## 🎯 Работа с типами ставок (Strategy pattern)

```gdscript
# Создание нового типа ставки
# res://scripts/bet_types/MyBetType.gd
extends IBetType

func get_bet_name() -> String:
    return "Моя ставка"

func calculate_payout(stake: float) -> float:
    """Расчёт выплаты"""
    return stake * 2.0

func is_available() -> bool:
    """Проверка доступности"""
    return true

# Использование через фабрику
var bet_type = BetTypeFactory.create("my_bet")
var payout = bet_type.calculate_payout(100)
```

## 🔧 Работа с валидаторами

```gdscript
# Создание валидатора
# res://scripts/validators/MyValidator.gd
extends IBetCollectionValidator

func validate(bets: Array[Bet]) -> Dictionary:
    """Валидация ставок
    
    Returns:
        Dictionary с ключами:
        - is_valid: bool
        - errors: Array[String]
    """
    var errors: Array[String] = []
    
    # Логика валидации
    for bet in bets:
        if not _validate_bet(bet):
            errors.append("Ошибка в ставке: " + bet.bet_type)
    
    return {
        "is_valid": errors.is_empty(),
        "errors": errors
    }

func _validate_bet(bet: Bet) -> bool:
    """Валидация одной ставки"""
    return bet.stake > 0
```

## 📝 Работа с локализацией

```gdscript
# Добавление нового текста
# В scripts/Localization.gd добавить:
var translations = {
    "ru": {
        "MY_NEW_TEXT": "Мой новый текст",
        "MY_TEXT_WITH_ARGS": "Текст с {arg1} и {arg2}"
    },
    "en": {
        "MY_NEW_TEXT": "My new text",
        "MY_TEXT_WITH_ARGS": "Text with {arg1} and {arg2}"
    }
}

# Использование
var text = Localization.t("MY_NEW_TEXT")
var text_with_args = Localization.t("MY_TEXT_WITH_ARGS", ["value1", "value2"])
```

## 🎮 Работа с состояниями игры

```gdscript
# Проверка текущего состояния
var current_state = GameStateManager.current_state
if current_state == GameStateManager.GameState.CHOOSE_WINNER:
    # Логика для состояния выбора победителя
    pass

# Валидация действия
var is_valid = GameStateManager.is_action_valid(GameStateManager.Action.DEAL_CARDS)
if not is_valid:
    var error = GameStateManager.get_error_message(GameStateManager.Action.DEAL_CARDS)
    EventBus.action_error.emit("deal_cards", error)

# Подписка на изменение состояния
func _ready():
    GameStateManager.state_changed.connect(_on_state_changed)

func _on_state_changed(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState):
    print("Состояние изменилось: ", old_state, " -> ", new_state)
```

## 🧪 Тестирование

```gdscript
# Пример теста
# res://tests/MyTest.gd
extends GutTest

func test_my_function():
    # Arrange
    var manager = MyManager.new()
    
    # Act
    var result = manager.do_something()
    
    # Assert
    assert_true(result, "Должно вернуть true")
```

---

**Примечание**: Все примеры следуют паттернам проекта. Используйте их как основу для новых классов.

