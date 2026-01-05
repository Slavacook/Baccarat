# Troubleshooting - Решение частых проблем

> Руководство по решению типичных проблем при разработке

## 🔴 Критические проблемы

### Проблема: "Сигнал не работает" / "EventBus не срабатывает"

**Симптомы:**
- Событие отправляется, но никто не реагирует
- Подписчик не получает событие

**Причины и решения:**

1. **Подписка после отправки события**
```gdscript
# ❌ НЕПРАВИЛЬНО
EventBus.action_correct.emit("test")  # Событие отправлено
EventBus.action_correct.connect(_on_action)  # Подписка после отправки

# ✅ ПРАВИЛЬНО
EventBus.action_correct.connect(_on_action)  # Сначала подписка
EventBus.action_correct.emit("test")  # Потом отправка
```

2. **Неправильное имя сигнала**
```gdscript
# ❌ НЕПРАВИЛЬНО
EventBus.action_correct.connect(_on_action)  # Опечатка в имени

# ✅ ПРАВИЛЬНО
EventBus.action_correct.connect(_on_action_correct)  # Правильное имя
```

3. **Объект уничтожен до получения события**
```gdscript
# ✅ ПРАВИЛЬНО - отписка при уничтожении
func _exit_tree():
    EventBus.action_correct.disconnect(_on_action_correct)
```

4. **Проверка существования сигнала**
```gdscript
# Проверь, что сигнал существует в scripts/autoload/EventBus.gd
# Все сигналы должны быть объявлены там
```

### Проблема: "Циклические зависимости"

**Симптомы:**
- Ошибка при компиляции
- Класс A зависит от B, B зависит от A

**Решение:**
```gdscript
# ❌ НЕПРАВИЛЬНО - прямая зависимость
class ManagerA:
    var manager_b: ManagerB  # Прямая зависимость

class ManagerB:
    var manager_a: ManagerA  # Цикл!

# ✅ ПРАВИЛЬНО - через EventBus
class ManagerA:
    func do_something():
        EventBus.something_happened.emit()  # Через EventBus

class ManagerB:
    func _ready():
        EventBus.something_happened.connect(_on_something)  # Подписка
```

### Проблема: "GameController слишком большой" (2024 строки)

**Симптомы:**
- Сложно найти нужный метод
- Много ответственностей в одном классе

**Решение:**
1. Используй паттерн Extract Class
2. Выноси логику в отдельные менеджеры/координаторы
3. См. `REFACTORING_ANALYSIS_GameController.md`

```gdscript
# ❌ НЕПРАВИЛЬНО - всё в GameController
class GameController:
    func handle_chips(): pass
    func handle_payouts(): pass
    func handle_cards(): pass

# ✅ ПРАВИЛЬНО - разделение ответственности
class GameController:
    var chip_handler: ChipClickHandler
    var payout_handler: PayoutResultHandler
    var card_controller: CardController
```

## 🟡 Частые проблемы

### Проблема: "UI не обновляется"

**Причины:**
1. **Использование прямых ссылок вместо EventBus**
```gdscript
# ❌ НЕПРАВИЛЬНО
game_controller.ui_manager.update_label("text")

# ✅ ПРАВИЛЬНО
EventBus.ui_update_requested.emit("label", "text")
```

2. **Обновление UI до инициализации**
```gdscript
# ✅ ПРАВИЛЬНО - проверка готовности
func update_ui():
    if not is_node_ready():
        await ready
    # Обновление UI
```

### Проблема: "Состояние игры не обновляется"

**Решение:**
```gdscript
# ✅ ПРАВИЛЬНО - через GameStateManager
var state = GameStateManager.determine_state()
GameStateManager.current_state = state

# Или подписка на изменения
func _ready():
    GameStateManager.state_changed.connect(_on_state_changed)
```

### Проблема: "Локализация не работает"

**Причины:**
1. **Ключ не существует**
```gdscript
# Проверь, что ключ есть в scripts/Localization.gd
# И для ru, и для en
```

2. **Неправильное использование**
```gdscript
# ❌ НЕПРАВИЛЬНО
var text = Localization.translate("KEY")

# ✅ ПРАВИЛЬНО
var text = Localization.t("KEY")
```

3. **Язык не установлен**
```gdscript
# ✅ Установка языка
Localization.set_lang("ru")
```

### Проблема: "Выплаты не рассчитываются правильно"

**Решение:**
1. **Проверь режим игры**
```gdscript
var mode = GameModeManager.get_current_mode()
# "junket" или "classic" - разные правила
```

2. **Используй PayoutCalculator**
```gdscript
var calculator = PayoutCalculator.new()
var payout = calculator.calculate(winner, stake)
```

3. **Проверь комиссию банкира**
```gdscript
# В режиме "junket" комиссия 5%
var commission = GameModeManager.get_banker_commission()
```

## 🟢 Мелкие проблемы

### Проблема: "Типы не указаны"

**Решение:**
```gdscript
# ❌ НЕПРАВИЛЬНО
func process(data):
    return data

# ✅ ПРАВИЛЬНО
func process(data: Dictionary) -> bool:
    return data.has("key")
```

### Проблема: "Комментарии на английском"

**Решение:**
```gdscript
# ✅ ПРАВИЛЬНО - комментарии на русском
func process_bet(bet: Bet) -> bool:
    """Обрабатывает ставку и возвращает успешность"""
    pass
```

### Проблема: "Дублирование кода"

**Решение:**
1. Вынеси в отдельный метод
2. Создай утилитный класс
3. Используй наследование

```gdscript
# ❌ НЕПРАВИЛЬНО - дублирование
func method1():
    var result = validate() and process()

func method2():
    var result = validate() and process()

# ✅ ПРАВИЛЬНО - общий метод
func _common_logic() -> bool:
    return validate() and process()

func method1():
    var result = _common_logic()

func method2():
    var result = _common_logic()
```

## 🔍 Отладка

### Как проверить, что EventBus работает

```gdscript
# Добавь временный подписчик для отладки
func _ready():
    EventBus.action_correct.connect(_debug_event)
    EventBus.action_error.connect(_debug_event)

func _debug_event(*args):
    print("EventBus event: ", args)
```

### Как найти, кто отправляет событие

```gdscript
# В scripts/autoload/EventBus.gd добавь отладку
signal action_correct(action_type: String)

func _ready():
    action_correct.connect(_debug_action_correct)

func _debug_action_correct(action_type: String):
    print("action_correct emitted: ", action_type)
    print_stack()  # Покажет стек вызовов
```

### Как проверить зависимости

```gdscript
# Используй граф зависимостей из DEPENDENCY_GRAPH.md
# Или создай скрипт для анализа:
# tools/analyze_dependencies.sh
```

## 📚 Полезные ресурсы

1. **EventBus сигналы**: `scripts/autoload/EventBus.gd`
2. **Состояния игры**: `scripts/autoload/GameStateManager.gd`
3. **Правила баккара**: `scripts/BaccaratRules.gd`
4. **Примеры кода**: `CODE_EXAMPLES.md`
5. **Архитектура**: `CLAUDE.md`

## 🆘 Если ничего не помогает

1. **Проверь логи Godot**: View → Output → Debug
2. **Проверь документацию**: `CLAUDE.md`, `AI_CONTEXT.md`
3. **Используй поиск**: `grep -r "название_метода" scripts/`
4. **Спроси AI**: используй контекст из `.cursorrules`

---

**Совет**: Большинство проблем решается использованием EventBus вместо прямых вызовов!

