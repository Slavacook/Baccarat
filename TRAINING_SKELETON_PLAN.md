# 🏗️ ПЛАН ПОСТРОЕНИЯ СКЕЛЕТА СИСТЕМЫ ОБУЧЕНИЯ

> **Статус**: План для реализации  
> **Дата создания**: 2026-01-28  
> **Цель**: Создать крепкий фундамент (скелет) системы обучения, который легко расширяется

---

## 📋 СОДЕРЖАНИЕ

1. [Архитектурные решения](#архитектурные-решения)
2. [Структура классов](#структура-классов)
3. [Интеграция с существующей системой](#интеграция-с-существующей-системой)
4. [Порядок реализации](#порядок-реализации)
5. [Критические моменты](#критические-моменты)
6. [Чеклист MVP скелета](#чеклист-mvp-скелета)

---

## 🎯 АРХИТЕКТУРНЫЕ РЕШЕНИЯ

### Принципы проектирования скелета

1. **Расширяемость**: Легко добавлять новые этапы без изменения базовой архитектуры
2. **Изоляция**: Обучение не должно влиять на основную игру
3. **Event-Driven**: Коммуникация через EventBus (как в основной игре)
4. **Dependency Injection**: Менеджеры получают зависимости через конструктор
5. **Single Responsibility**: Каждый класс отвечает за одну область
6. **Базовые классы**: Абстрактные классы для этапов (Strategy Pattern)

---

## 🏛️ СТРУКТУРА КЛАССОВ

### 1. Базовые классы (фундамент)

#### `TrainingStageBase` (абстрактный базовый класс)
```gdscript
# scripts/training/stages/TrainingStageBase.gd
# Базовый класс для всех этапов обучения
# Использует Strategy Pattern для легкого добавления новых этапов

class_name TrainingStageBase extends RefCounted

# Идентификатор этапа
var stage_id: String
var stage_name: String
var difficulty_level: int  # 0, 1, 2, 3

# Текст инструкции
var instruction_text: String

# Тип вопроса: "binary", "action_choice", "double_binary"
var question_type: String

# Абстрактные методы (должны быть реализованы в дочерних классах)
func generate_scenario() -> Dictionary:
    """Генерирует сценарий (карты) для этапа
    Returns: {player_hand, banker_hand, expected_answer, ...}
    """
    assert(false, "Must override in child class")
    return {}

func validate_answer(user_answer, scenario: Dictionary) -> bool:
    """Проверяет правильность ответа пользователя
    Args:
        user_answer: Ответ пользователя
        scenario: Сгенерированный сценарий
    Returns: true если правильно, false иначе
    """
    assert(false, "Must override in child class")
    return false

func get_answer_options(scenario: Dictionary) -> Array:
    """Возвращает варианты ответов для UI
    Returns: Array строк с вариантами ответов
    """
    assert(false, "Must override in child class")
    return []

func get_explanation(user_answer, scenario: Dictionary, is_correct: bool) -> String:
    """Генерирует объяснение для пользователя
    Returns: Текст объяснения
    """
    assert(false, "Must override in child class")
    return ""
```

**Критично**: Этот класс - основа для всех этапов. Должен быть максимально гибким.

---

#### `TrainingCardGenerator` (утилита генерации карт)
```gdscript
# scripts/training/TrainingCardGenerator.gd
# Генерация карт для обучения

class_name TrainingCardGenerator

var deck: Deck

func _init(deck_ref: Deck):
    deck = deck_ref

# Генерация руки с заданным значением очков
func generate_hand_with_value(value: int, hand_size: int = 2) -> Array[Card]:
    """Генерирует руку с заданным значением очков
    Args:
        value: Желаемое значение очков (0-9)
        hand_size: Количество карт (обычно 2)
    Returns: Array[Card]
    """
    # Логика генерации карт
    pass

# Генерация натуральной победы (8-9 очков)
func generate_natural_win() -> Dictionary:
    """Генерирует сценарий с натуральной победой
    Returns: {player_hand, banker_hand, expected_answer: "no"}
    """
    pass
```

**Критично**: Должен работать с существующим `Deck`, не создавать новый.

---

### 2. Менеджеры (координация)

#### `TrainingModeManager` (главный менеджер)
```gdscript
# scripts/training/TrainingModeManager.gd
# Главный координатор режима обучения

class_name TrainingModeManager extends Node

# Текущий активный этап
var current_stage: TrainingStageBase = null
var current_stage_index: int = -1

# Все доступные этапы
var stages: Array[TrainingStageBase] = []

# Прогресс по этапам (в памяти на сессию)
var stage_progress: Dictionary = {}  # {stage_id: 0.0-1.0}

# Зависимости (Dependency Injection)
var deck: Deck
var card_manager: CardTextureManager
var ui_manager: UIManager

# Сигналы
signal stage_started(stage_id: String)
signal stage_completed(stage_id: String)
signal progress_changed(stage_id: String, progress: float)
signal training_mode_activated()
signal training_mode_deactivated()

func _init(deck_ref: Deck, card_manager_ref: CardTextureManager, ui_manager_ref: UIManager):
    deck = deck_ref
    card_manager = card_manager_ref
    ui_manager = ui_manager_ref

func activate_training_mode():
    """Активировать режим обучения"""
    training_mode_activated.emit()
    # Скрыть элементы основной игры
    # Показать элементы обучения

func deactivate_training_mode():
    """Деактивировать режим обучения"""
    training_mode_deactivated.emit()
    # Показать элементы основной игры
    # Скрыть элементы обучения

func start_stage(stage_index: int):
    """Начать этап обучения"""
    if stage_index < 0 or stage_index >= stages.size():
        return
    
    current_stage_index = stage_index
    current_stage = stages[stage_index]
    
    # Инициализировать прогресс если нужно
    if not stage_progress.has(current_stage.stage_id):
        stage_progress[current_stage.stage_id] = 0.0
    
    stage_started.emit(current_stage.stage_id)

func process_answer(user_answer) -> Dictionary:
    """Обработать ответ пользователя
    Returns: {is_correct: bool, explanation: String, progress_delta: float}
    """
    if not current_stage:
        return {}
    
    var scenario = current_stage.generate_scenario()
    var is_correct = current_stage.validate_answer(user_answer, scenario)
    var explanation = current_stage.get_explanation(user_answer, scenario, is_correct)
    
    # Обновить прогресс
    var progress_delta = 0.05 if is_correct else -0.20
    var current_progress = stage_progress.get(current_stage.stage_id, 0.0)
    stage_progress[current_stage.stage_id] = clamp(current_progress + progress_delta, 0.0, 1.0)
    
    progress_changed.emit(current_stage.stage_id, stage_progress[current_stage.stage_id])
    
    # Проверить завершение этапа
    if stage_progress[current_stage.stage_id] >= 1.0:
        stage_completed.emit(current_stage.stage_id)
    
    return {
        "is_correct": is_correct,
        "explanation": explanation,
        "progress_delta": progress_delta,
        "current_progress": stage_progress[current_stage.stage_id]
    }
```

**Критично**: Этот менеджер - центральная точка управления. Должен быть изолирован от основной игры.

---

#### `TrainingStageManager` (управление этапами)
```gdscript
# scripts/training/TrainingStageManager.gd
# Регистрация и управление этапами

class_name TrainingStageManager

var registered_stages: Array[TrainingStageBase] = []
var completed_stages: Array[String] = []  # stage_id пройденных этапов

func register_stage(stage: TrainingStageBase):
    """Зарегистрировать этап"""
    registered_stages.append(stage)

func get_stage_by_id(stage_id: String) -> TrainingStageBase:
    """Получить этап по ID"""
    for stage in registered_stages:
        if stage.stage_id == stage_id:
            return stage
    return null

func is_stage_completed(stage_id: String) -> bool:
    """Проверить, пройден ли этап"""
    return stage_id in completed_stages

func get_next_available_stage_index() -> int:
    """Получить индекс следующего доступного этапа
    Returns: -1 если все этапы пройдены
    """
    for i in range(registered_stages.size()):
        if not is_stage_completed(registered_stages[i].stage_id):
            return i
    return -1
```

**Критично**: Должен легко расширяться при добавлении новых этапов.

---

### 3. UI компоненты (базовые)

#### `TrainingProgressBar` (шкала прогресса)
```gdscript
# scripts/training/ui/TrainingProgressBar.gd
# Шкала прогресса с цветными зонами

class_name TrainingProgressBar extends ProgressBar

# Цветные зоны (0-2, 3-6, 7-9)
var green_zone: ColorRect   # 0-2
var purple_zone: ColorRect # 3-6
var red_zone: ColorRect    # 7-9

# Текущая подсвеченная зона
var highlighted_zone: ColorRect = null

func _ready():
    # Инициализация цветных зон
    setup_zones()

func setup_zones():
    """Настроить цветные зоны"""
    # Создать зоны как дочерние элементы
    # 🟢 0-2, 🟣 3-6, 🔴 7-9
    pass

func update_progress(value: float):
    """Обновить прогресс (0.0-1.0)"""
    value = clamp(value, 0.0, 1.0)
    # Анимация плавного заполнения
    var tween = create_tween()
    tween.tween_property(self, "value", value * 100.0, 0.3)

func highlight_zone(zone_type: String):
    """Подсветить зону (green, purple, red)"""
    # Сбросить предыдущую подсветку
    if highlighted_zone:
        highlighted_zone.modulate = Color.WHITE
    
    # Подсветить новую зону
    match zone_type:
        "green":
            highlighted_zone = green_zone
        "purple":
            highlighted_zone = purple_zone
        "red":
            highlighted_zone = red_zone
    
    if highlighted_zone:
        highlighted_zone.modulate = Color(1.2, 1.2, 1.2)  # Ярче
```

**Критично**: Должен быть визуально понятным и легко настраиваемым.

---

#### `TrainingInstructionPopup` (попап инструкции)
```gdscript
# scripts/training/ui/TrainingInstructionPopup.gd
# Попап с инструкцией для этапа

class_name TrainingInstructionPopup extends PopupPanel

var instruction_label: Label
var start_button: Button

signal start_button_pressed()

func setup(instruction_text: String):
    """Настроить попап с текстом инструкции"""
    instruction_label.text = instruction_text

func _on_start_button_pressed():
    start_button_pressed.emit()
    hide()
```

**Критично**: Должен быть переиспользуемым для всех этапов.

---

#### `TrainingQuestionPopup` (попап вопроса)
```gdscript
# scripts/training/ui/TrainingQuestionPopup.gd
# Попап с вопросом и вариантами ответов

class_name TrainingQuestionPopup extends PopupPanel

var question_label: Label
var answer_buttons_container: VBoxContainer
var hint_button: Button

signal answer_selected(answer)
signal hint_requested()

# Типы вопросов
enum QuestionType {
    BINARY,        # Да/Нет
    ACTION_CHOICE, # Выбор действия (3 варианта)
    DOUBLE_BINARY  # Два вопроса Да/Нет
}

func setup(question_text: String, question_type: QuestionType, answer_options: Array):
    """Настроить попап с вопросом"""
    question_label.text = question_text
    
    # Очистить старые кнопки
    for child in answer_buttons_container.get_children():
        child.queue_free()
    
    # Создать кнопки ответов
    match question_type:
        QuestionType.BINARY:
            _create_binary_buttons(answer_options)
        QuestionType.ACTION_CHOICE:
            _create_action_buttons(answer_options)
        QuestionType.DOUBLE_BINARY:
            _create_double_binary_buttons(answer_options)

func _create_binary_buttons(options: Array):
    """Создать кнопки Да/Нет"""
    pass

func _on_answer_button_pressed(answer):
    answer_selected.emit(answer)

func _on_hint_button_pressed():
    hint_requested.emit()
```

**Критично**: Должен поддерживать все типы вопросов (бинарный, выбор действия, двойной бинарный).

---

#### `TrainingStageCompletePopup` (попап завершения)
```gdscript
# scripts/training/ui/TrainingStageCompletePopup.gd
# Попап завершения этапа

class_name TrainingStageCompletePopup extends PopupPanel

var title_label: Label
var progress_label: Label
var repeat_button: Button
var continue_button: Button

signal repeat_pressed()
signal continue_pressed()

func setup(progress: float, is_last_stage: bool = false):
    """Настроить попап завершения"""
    progress_label.text = "Прогресс: %d%%" % (progress * 100)
    
    if is_last_stage:
        continue_button.text = "Завершить обучение"
    else:
        continue_button.text = "Продолжить"

func _on_repeat_pressed():
    repeat_pressed.emit()
    hide()

func _on_continue_pressed():
    continue_pressed.emit()
    hide()
```

**Критично**: Должен корректно обрабатывать последний этап.

---

### 4. Первый этап (MVP - заглушка)

#### `NaturalWinStage` (этап 0 - натуральная победа)
```gdscript
# scripts/training/stages/NaturalWinStage.gd
# Этап 0: Натуральная победа (8-9 очков)

class_name NaturalWinStage extends TrainingStageBase

var card_generator: TrainingCardGenerator

func _init(gen: TrainingCardGenerator):
    card_generator = gen
    stage_id = "natural_win"
    stage_name = "Натуральная победа"
    difficulty_level = 0
    instruction_text = "Если у игрока или банкира 8-9 очков на первых двух картах - это натуральная победа, третья карта никому не нужна"
    question_type = "binary"

func generate_scenario() -> Dictionary:
    """Генерирует сценарий с натуральной победой"""
    var scenario = card_generator.generate_natural_win()
    scenario["expected_answer"] = "no"  # Всегда НЕТ
    return scenario

func validate_answer(user_answer, scenario: Dictionary) -> bool:
    """Проверяет правильность ответа"""
    return user_answer == "no"

func get_answer_options(scenario: Dictionary) -> Array:
    """Возвращает варианты ответов"""
    return ["Да", "Нет"]

func get_explanation(user_answer, scenario: Dictionary, is_correct: bool) -> String:
    """Генерирует объяснение"""
    if is_correct:
        return "Верно! При натуральной победе (8-9 очков) третья карта не нужна."
    else:
        return "Ошибка! Вы выбрали 'Да', но при натуральной победе (8-9 очков) третья карта не нужна."
```

**Критично**: Это первый этап для проверки архитектуры. Должен работать идеально.

---

## 🔗 ИНТЕГРАЦИЯ С СУЩЕСТВУЮЩЕЙ СИСТЕМОЙ

### 1. EventBus (новые сигналы)

Добавить в `scripts/autoload/EventBus.gd`:
```gdscript
# ═══════════════════════════════════════════════════════════════════════════
# 🎓 РЕЖИМ ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

## Режим обучения активирован
@warning_ignore("unused_signal")
signal training_mode_activated()

## Режим обучения деактивирован
@warning_ignore("unused_signal")
signal training_mode_deactivated()

## Этап обучения начат
@warning_ignore("unused_signal")
signal training_stage_started(stage_id: String)

## Этап обучения завершён
@warning_ignore("unused_signal")
signal training_stage_completed(stage_id: String)

## Прогресс этапа изменился
@warning_ignore("unused_signal")
signal training_progress_changed(stage_id: String, progress: float)

## Ответ пользователя обработан
@warning_ignore("unused_signal")
signal training_answer_processed(is_correct: bool, explanation: String, progress: float)

## Запрошена подсказка
@warning_ignore("unused_signal")
signal training_hint_requested()
```

**Критично**: Все события должны быть задокументированы.

---

### 2. GameController (интеграция)

Добавить в `scripts/GameController.gd`:
```gdscript
# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

var training_mode_manager: TrainingModeManager = null
var is_training_mode_active: bool = false

func _ready():
    # ... существующая инициализация ...
    
    # Инициализация режима обучения (если нужно)
    # training_mode_manager = TrainingModeManager.new(deck, card_manager, ui_manager)

func activate_training_mode():
    """Активировать режим обучения"""
    if not training_mode_manager:
        # Инициализировать если нужно
        training_mode_manager = TrainingModeManager.new(deck, card_manager, ui_manager)
        _setup_training_stages()
    
    is_training_mode_active = true
    training_mode_manager.activate_training_mode()
    
    # Скрыть элементы основной игры
    _hide_main_game_elements()
    
    # Показать элементы обучения
    _show_training_elements()

func deactivate_training_mode():
    """Деактивировать режим обучения"""
    if training_mode_manager:
        training_mode_manager.deactivate_training_mode()
    
    is_training_mode_active = false
    
    # Показать элементы основной игры
    _show_main_game_elements()
    
    # Скрыть элементы обучения
    _hide_training_elements()

func _setup_training_stages():
    """Настроить этапы обучения"""
    if not training_mode_manager:
        return
    
    var card_generator = TrainingCardGenerator.new(deck)
    
    # Регистрация этапов (пока только один для MVP)
    var natural_win_stage = NaturalWinStage.new(card_generator)
    training_mode_manager.stages.append(natural_win_stage)

func _hide_main_game_elements():
    """Скрыть элементы основной игры"""
    # Скрыть кнопки, маркеры, etc.
    pass

func _show_main_game_elements():
    """Показать элементы основной игры"""
    # Показать кнопки, маркеры, etc.
    pass

func _show_training_elements():
    """Показать элементы обучения"""
    # Показать шкалу прогресса, попапы, etc.
    pass

func _hide_training_elements():
    """Скрыть элементы обучения"""
    # Скрыть шкалу прогресса, попапы, etc.
    pass
```

**Критично**: Режим обучения должен полностью изолировать основную игру.

---

### 3. SettingsScene (кнопка переключения)

Добавить в `scripts/SettingsScene.gd`:
```gdscript
# === РЕЖИМ ОБУЧЕНИЯ ===
@onready var training_button: Button = find_child("TrainingButton", true, false)

func _ready():
    # ... существующая инициализация ...
    
    if training_button:
        training_button.pressed.connect(_on_training_button_pressed)

func _on_training_button_pressed():
    """Обработка нажатия кнопки 'ОБУЧЕНИЕ'"""
    # Получить GameController
    var game_controller = get_tree().get_first_node_in_group(GameConstants.GROUP_GAME_CONTROLLER)
    if game_controller:
        game_controller.activate_training_mode()
        # Закрыть настройки
        hide()
```

**Критично**: Кнопка должна быть в главном меню настроек.

---

### 4. UI сцены (элементы обучения)

Добавить в `scenes/Game.tscn`:
- `TrainingProgressBar` (вверху экрана, изначально скрыт)
- `TrainingInstructionPopup` (CanvasLayer, изначально скрыт)
- `TrainingQuestionPopup` (CanvasLayer, изначально скрыт)
- `TrainingStageCompletePopup` (CanvasLayer, изначально скрыт)

**Критично**: Все элементы должны быть скрыты по умолчанию и показываться только в режиме обучения.

---

## 📝 ПОРЯДОК РЕАЛИЗАЦИИ

### Фаза 1: Базовые классы (фундамент)

**Шаг 1.1**: Создать `TrainingStageBase`
- [ ] Создать файл `scripts/training/stages/TrainingStageBase.gd`
- [ ] Реализовать базовые свойства (stage_id, stage_name, etc.)
- [ ] Реализовать абстрактные методы (generate_scenario, validate_answer, etc.)
- [ ] Добавить комментарии и документацию

**Шаг 1.2**: Создать `TrainingCardGenerator`
- [ ] Создать файл `scripts/training/TrainingCardGenerator.gd`
- [ ] Реализовать `generate_hand_with_value()`
- [ ] Реализовать `generate_natural_win()`
- [ ] Протестировать генерацию карт

**Шаг 1.3**: Создать `NaturalWinStage` (первый этап)
- [ ] Создать файл `scripts/training/stages/NaturalWinStage.gd`
- [ ] Наследовать от `TrainingStageBase`
- [ ] Реализовать все абстрактные методы
- [ ] Протестировать генерацию сценариев

**Критично**: Базовые классы должны быть идеальными. От них зависит вся система.

---

### Фаза 2: Менеджеры (координация)

**Шаг 2.1**: Создать `TrainingModeManager`
- [ ] Создать файл `scripts/training/TrainingModeManager.gd`
- [ ] Реализовать Dependency Injection (deck, card_manager, ui_manager)
- [ ] Реализовать `activate_training_mode()` / `deactivate_training_mode()`
- [ ] Реализовать `start_stage()` / `process_answer()`
- [ ] Добавить сигналы

**Шаг 2.2**: Создать `TrainingStageManager`
- [ ] Создать файл `scripts/training/TrainingStageManager.gd`
- [ ] Реализовать регистрацию этапов
- [ ] Реализовать проверку пройденных этапов
- [ ] Реализовать получение следующего доступного этапа

**Критично**: Менеджеры должны быть изолированы и не зависеть от UI.

---

### Фаза 3: EventBus (интеграция)

**Шаг 3.1**: Добавить сигналы в EventBus
- [ ] Открыть `scripts/autoload/EventBus.gd`
- [ ] Добавить секцию "РЕЖИМ ОБУЧЕНИЯ"
- [ ] Добавить все сигналы с документацией
- [ ] Проверить синтаксис

**Критично**: Сигналы должны быть задокументированы и следовать существующему стилю.

---

### Фаза 4: UI компоненты (базовые)

**Шаг 4.1**: Создать `TrainingProgressBar`
- [ ] Создать файл `scripts/training/ui/TrainingProgressBar.gd`
- [ ] Создать сцену `scenes/training/TrainingProgressBar.tscn`
- [ ] Реализовать цветные зоны (🟢🟣🔴)
- [ ] Реализовать подсветку зон
- [ ] Реализовать анимацию заполнения

**Шаг 4.2**: Создать `TrainingInstructionPopup`
- [ ] Создать файл `scripts/training/ui/TrainingInstructionPopup.gd`
- [ ] Создать сцену `scenes/training/TrainingInstructionPopup.tscn`
- [ ] Реализовать отображение текста инструкции
- [ ] Реализовать кнопку "Начать"

**Шаг 4.3**: Создать `TrainingQuestionPopup`
- [ ] Создать файл `scripts/training/ui/TrainingQuestionPopup.gd`
- [ ] Создать сцену `scenes/training/TrainingQuestionPopup.tscn`
- [ ] Реализовать поддержку бинарных вопросов (Да/Нет)
- [ ] Реализовать кнопку "Подсказка"
- [ ] Добавить сигналы

**Шаг 4.4**: Создать `TrainingStageCompletePopup`
- [ ] Создать файл `scripts/training/ui/TrainingStageCompletePopup.gd`
- [ ] Создать сцену `scenes/training/TrainingStageCompletePopup.tscn`
- [ ] Реализовать отображение прогресса
- [ ] Реализовать кнопки "Повторить" / "Продолжить"

**Критично**: UI компоненты должны быть переиспользуемыми и легко настраиваемыми.

---

### Фаза 5: Интеграция с GameController

**Шаг 5.1**: Добавить поддержку режима обучения
- [ ] Добавить переменную `training_mode_manager` в `GameController`
- [ ] Добавить переменную `is_training_mode_active`
- [ ] Реализовать `activate_training_mode()` / `deactivate_training_mode()`
- [ ] Реализовать `_setup_training_stages()`
- [ ] Реализовать `_hide_main_game_elements()` / `_show_main_game_elements()`

**Шаг 5.2**: Подключить сигналы
- [ ] Подписаться на сигналы `TrainingModeManager`
- [ ] Обработать события обучения
- [ ] Обновить UI при переключении режимов

**Критично**: Режим обучения должен полностью изолировать основную игру.

---

### Фаза 6: Интеграция с SettingsScene

**Шаг 6.1**: Добавить кнопку в настройки
- [ ] Открыть `scenes/SettingsScene.tscn`
- [ ] Добавить кнопку "ОБУЧЕНИЕ" в главное меню
- [ ] Подключить обработчик в `SettingsScene.gd`
- [ ] Реализовать `_on_training_button_pressed()`

**Критично**: Кнопка должна быть в удобном месте и иметь понятный текст.

---

### Фаза 7: Добавление элементов в Game.tscn

**Шаг 7.1**: Добавить UI элементы обучения
- [ ] Открыть `scenes/Game.tscn`
- [ ] Добавить `TrainingProgressBar` (вверху экрана)
- [ ] Добавить `TrainingInstructionPopup` (CanvasLayer)
- [ ] Добавить `TrainingQuestionPopup` (CanvasLayer)
- [ ] Добавить `TrainingStageCompletePopup` (CanvasLayer)
- [ ] Установить `visible = false` для всех элементов

**Критично**: Все элементы должны быть скрыты по умолчанию.

---

### Фаза 8: Тестирование MVP

**Шаг 8.1**: Протестировать базовый поток
- [ ] Запустить игру
- [ ] Открыть настройки
- [ ] Нажать "ОБУЧЕНИЕ"
- [ ] Проверить активацию режима обучения
- [ ] Проверить отображение попапа инструкции
- [ ] Нажать "Начать"
- [ ] Проверить генерацию карт
- [ ] Проверить отображение вопроса
- [ ] Выбрать ответ
- [ ] Проверить обратную связь
- [ ] Проверить обновление прогресса
- [ ] Проверить завершение этапа

**Критично**: Весь поток должен работать без ошибок.

---

## ⚠️ КРИТИЧЕСКИЕ МОМЕНТЫ

### 1. Изоляция режима обучения

**Проблема**: Обучение не должно влиять на основную игру.

**Решение**:
- Скрывать все элементы основной игры при активации обучения
- Не использовать `GamePhaseManager` в режиме обучения
- Использовать отдельный `Deck` для обучения (или копию)
- Не эмитить события основной игры из обучения

**Проверка**: После деактивации обучения всё должно вернуться в исходное состояние.

---

### 2. Расширяемость базовых классов

**Проблема**: Легко добавлять новые этапы без изменения базовой архитектуры.

**Решение**:
- `TrainingStageBase` должен быть максимально гибким
- Все специфичные для этапа данные в дочерних классах
- Использовать Strategy Pattern для типов вопросов
- Документировать все абстрактные методы

**Проверка**: Добавление нового этапа должно требовать только создания нового класса.

---

### 3. Интеграция с EventBus

**Проблема**: Все события должны быть централизованы.

**Решение**:
- Все события обучения через EventBus
- Не использовать прямые вызовы между компонентами
- Документировать все сигналы
- Следовать существующему стилю EventBus

**Проверка**: Все компоненты должны общаться только через EventBus.

---

### 4. Dependency Injection

**Проблема**: Менеджеры не должны создавать зависимости сами.

**Решение**:
- Все зависимости через конструктор
- `TrainingModeManager` получает deck, card_manager, ui_manager
- `TrainingCardGenerator` получает deck
- `NaturalWinStage` получает card_generator

**Проверка**: Все менеджеры должны получать зависимости извне.

---

### 5. Состояние UI элементов

**Проблема**: UI элементы должны корректно показываться/скрываться.

**Решение**:
- Все элементы обучения скрыты по умолчанию
- Показывать только при активации режима обучения
- Скрывать при деактивации
- Сбрасывать состояние попапов при переключении

**Проверка**: При переключении режимов UI должен корректно обновляться.

---

## ✅ ЧЕКЛИСТ MVP СКЕЛЕТА

### Базовые классы
- [ ] `TrainingStageBase` создан и протестирован
- [ ] `TrainingCardGenerator` создан и протестирован
- [ ] `NaturalWinStage` создан и протестирован

### Менеджеры
- [ ] `TrainingModeManager` создан и протестирован
- [ ] `TrainingStageManager` создан и протестирован

### EventBus
- [ ] Все сигналы обучения добавлены в EventBus
- [ ] Сигналы задокументированы

### UI компоненты
- [ ] `TrainingProgressBar` создан и работает
- [ ] `TrainingInstructionPopup` создан и работает
- [ ] `TrainingQuestionPopup` создан и работает
- [ ] `TrainingStageCompletePopup` создан и работает

### Интеграция
- [ ] `GameController` поддерживает режим обучения
- [ ] `SettingsScene` имеет кнопку переключения
- [ ] `Game.tscn` содержит все UI элементы

### Тестирование
- [ ] Базовый поток работает (активация → инструкция → вопрос → ответ → завершение)
- [ ] Прогресс обновляется корректно
- [ ] Режим обучения изолирован от основной игры
- [ ] Нет ошибок в консоли

---

## 📌 ЗАМЕТКИ

- **Приоритет**: Качество > Скорость. Лучше сделать медленно, но правильно.
- **Тестирование**: После каждого шага проверять работоспособность.
- **Документация**: Все классы должны быть задокументированы.
- **Стиль кода**: Следовать существующему стилю проекта.
- **Расширяемость**: При добавлении новых этапов не должно требоваться изменение базовых классов.

---

## 🔗 СВЯЗАННЫЕ ДОКУМЕНТЫ

- `TRAINING_MODE_DESIGN.md` - полная спецификация системы обучения
- `CLAUDE.md` - общая документация проекта
- `scripts/BaccaratRules.gd` - правила баккара
- `scripts/autoload/EventBus.gd` - система событий

---

**Конец документа**
