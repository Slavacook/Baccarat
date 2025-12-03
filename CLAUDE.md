# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

**Баккара 5.9** - тренажёр для обучения правилам игры в баккара, разработанный на Godot 4.5. Проект помогает дилерам и крупье практиковать:
- Знание правил добора третьей карты
- Расчёт выплат с комиссией 5% на банкира
- Расчёт выплат 8:1 на ничью
- Определение победителя
- Режим выживания с 7 жизнями

Игра полностью локализована (русский/английский), работает с джойпадом, имеет систему статистики, настраиваемые лимиты стола и визуальную систему выплат с фишками.

## Команды разработки

**Запуск проекта**:
```bash
# Открыть в редакторе Godot
godot --editor --path .

# Запустить игру напрямую
godot --path . scenes/Game.tscn
```

**Тестирование**:
```bash
# Запуск всех тестов через GUT
godot --path . --headless --script addons/gut/gut_cmdln.gd

# В редакторе: нижняя панель → GUT → Run All
```

**Экспорт**:
```bash
# Экспорт через CLI (после настройки export_presets.cfg)
godot --export-release "macOS" build/Baccarat.app
godot --export-release "Windows Desktop" build/Baccarat.exe
```

## Архитектура проекта

### Общая структура и паттерны проектирования

Проект построен на **многослойной архитектуре** с использованием следующих паттернов:

#### 📐 Основные паттерны:

1. **Manager Pattern** - Каждая область ответственности вынесена в отдельный менеджер
2. **Observer/Event Bus** - Децентрализованная коммуникация через EventBus (pub/sub)
3. **State Machine** - Управление игровыми состояниями через GameStateManager
4. **Object Pooling** - Переиспользование Toast и OverlayNotification узлов
5. **Strategy** - Разные режимы игры (Classic/Super6/EZ) через GameModeManager
6. **Facade** - UIManager скрывает сложность взаимодействия с UI
7. **Singleton (Autoload)** - Глобальные менеджеры как autoload синглтоны

#### 🏗️ Слои архитектуры (снизу вверх):

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER (UI)                                     │
│  ├─ UIManager (фасад для всех UI элементов)                │
│  ├─ PayoutPopup, BetPopup, GameOverPopup                   │
│  ├─ ToastManager, OverlayNotificationManager                │
│  └─ ChipVisualManager, WinnerSelectionManager               │
└─────────────────────────────────────────────────────────────┘
                            ↓ сигналы
┌─────────────────────────────────────────────────────────────┐
│  ORCHESTRATION LAYER (Координация)                          │
│  └─ GameController - главный оркестратор                    │
└─────────────────────────────────────────────────────────────┘
                            ↓ делегирование
┌─────────────────────────────────────────────────────────────┐
│  BUSINESS LOGIC LAYER (Бизнес-логика)                       │
│  ├─ GamePhaseManager (управление фазами игры)              │
│  ├─ GameStateManager (определение состояния)               │
│  ├─ BaccaratRules (правила баккара)                        │
│  ├─ LimitsManager (лимиты стола)                           │
│  ├─ PayoutValidator (валидация выплат)                     │
│  └─ PairBettingManager (логика пар)                        │
└─────────────────────────────────────────────────────────────┘
                            ↓ использует
┌─────────────────────────────────────────────────────────────┐
│  DATA/MODEL LAYER (Данные и модели)                         │
│  ├─ Card (модель карты)                                     │
│  ├─ Deck (колода карт)                                      │
│  ├─ ChipStack, ChipStackManager (модель фишек)             │
│  └─ GameDataManager (состояние раунда)                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  INFRASTRUCTURE LAYER (Инфраструктура)                       │
│  ├─ EventBus (централизованная шина событий)               │
│  ├─ Localization (i18n: ru/en)                             │
│  ├─ SaveManager (persistence)                               │
│  ├─ StatsManager (статистика)                              │
│  └─ GameConfig (конфигурация)                              │
└─────────────────────────────────────────────────────────────┘
```

### Главный контроллер: GameController

`scripts/GameController.gd` - точка входа, координирует все подсистемы:

```gdscript
# Основные компоненты
- deck: Deck - колода карт (52 карты, перемешивается при создании)
- card_manager: CardTextureManager - загрузка текстур карт из assets/cards/
- ui_manager: UIManager - управление UI элементами и сигналами
- phase_manager: GamePhaseManager - управление игровым процессом и валидация действий
- limits_manager: LimitsManager - управление лимитами стола
- camera: Camera2D - камера с зумом и плавными переходами

# Новые менеджеры (v5.9+)
- chip_visual_manager: ChipVisualManager - визуализация фишек на столе
- winner_selection_manager: WinnerSelectionManager - выбор победителя с подсветкой
- payout_queue_manager: PayoutQueueManager - очередь выплат (Main/Pair)
- pair_betting_manager: PairBettingManager - управление ставками на пары
```

**Обязанности GameController**:
- Инициализация всех менеджеров при старте
- Подписка на сигналы UIManager
- Делегирование действий в GamePhaseManager
- Управление камерой (зум при раздаче/выборе победителя)
- Координация режима выживания (жизни, game over)
- Оркестрация выплат через PayoutQueueManager

**Важно**: GameController НЕ содержит игровую логику - он только координирует менеджеры!

### Поток данных и жизненный цикл раунда

#### 📊 Полный цикл одного раунда (детально):

```
1. ИНИЦИАЛИЗАЦИЯ (state: WAITING)
   ┌──────────────────────────────────────────────┐
   │ Пользователь нажимает "Раздать карты"        │
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ UIManager.action_button_pressed → emit()     │
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ GameController._on_action_button()           │
   │ └─ проверяет GameStateManager.current_state  │
   │ └─ вызывает phase_manager.deal_first_four()  │
   └──────────────┬───────────────────────────────┘
                  ↓
2. РАЗДАЧА ПЕРВЫХ 4 КАРТ
   ┌──────────────────────────────────────────────┐
   │ GamePhaseManager.deal_first_four()           │
   │ ├─ deck.draw() x4 → player_hand, banker_hand │
   │ ├─ pair_betting_manager.check_pairs()        │
   │ ├─ ui.show_first_four_cards() → анимация     │
   │ ├─ _update_game_state_manager()              │
   │ └─ EventBus.cards_dealt.emit()               │
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ GameStateManager.determine_state()           │
   │ ├─ вычисляет хэш (player_hand + banker_hand) │
   │ ├─ проверяет кэш                             │
   │ ├─ определяет состояние по очкам:           │
   │ │  • Натуральная 8-9? → CHOOSE_WINNER        │
   │ │  • Банкир 0-2? → CARD_TO_EACH              │
   │ │  • Игрок 6-7? → CARD_TO_BANKER             │
   │ │  • и т.д.                                  │
   │ └─ emit state_changed(old, new)              │
   └──────────────┬───────────────────────────────┘
                  ↓
3. ЗАКАЗ ТРЕТЬИХ КАРТ (если нужно)
   ┌──────────────────────────────────────────────┐
   │ Пользователь кликает на toggle (? ↔ !)       │
   │ UIManager.player_third_toggled.emit(true)    │
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ GamePhaseManager._on_player_third_toggled()  │
   │ └─ устанавливает player_third_selected=true  │
   │ └─ ui.update_player_third_card_ui("!")       │
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ Пользователь нажимает "Карты"                │
   │ GameController._on_action_button()           │
   │ └─ вызывает _validate_and_execute_3rd_cards()│
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ GamePhaseManager._validate_and_execute...()  │
   │ ├─ проверяет GameStateManager.is_action_valid│
   │ ├─ сравнивает с BaccaratRules                │
   │ ├─ ✅ ПРАВИЛЬНО:                             │
   │ │  └─ draw_player_third() → deck.draw()      │
   │ │  └─ EventBus.action_correct.emit()         │
   │ ├─ ❌ НЕПРАВИЛЬНО:                           │
   │ │  └─ EventBus.action_error.emit()           │
   │ │  └─ on_error_occurred() → потеря жизни     │
   │ └─ _update_game_state_manager()              │
   └──────────────┬───────────────────────────────┘
                  ↓
4. ВЫБОР ПОБЕДИТЕЛЯ (state: CHOOSE_WINNER)
   ┌──────────────────────────────────────────────┐
   │ Все карты открыты                            │
   │ Пользователь кликает PlayerMarker/etc        │
   │ UIManager.winner_selected.emit("Player")     │
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ GameController._on_winner_selected()         │
   │ ├─ BaccaratRules.get_winner() → ожидаемый   │
   │ ├─ сравнение с выбором пользователя         │
   │ ├─ ✅ ПРАВИЛЬНО:                             │
   │ │  └─ EventBus.winner_correct.emit()         │
   │ │  └─ _prepare_payouts() → PayoutQueue       │
   │ ├─ ❌ НЕПРАВИЛЬНО:                           │
   │ │  └─ EventBus.action_error.emit()           │
   │ │  └─ потеря жизни + сброс раунда            │
   └──────────────┬───────────────────────────────┘
                  ↓
5. РАСЧЁТ ВЫПЛАТЫ (PayoutPopup)
   ┌──────────────────────────────────────────────┐
   │ PayoutQueueManager.show_next_payout()        │
   │ ├─ очередь: [Main выплата, Pair выплаты]    │
   │ ├─ показывает PayoutPopup с фишками          │
   │ └─ ждет действий пользователя                │
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ Пользователь собирает фишки                  │
   │ ├─ клик на флот → ChipStack.add_chip()      │
   │ ├─ ChipStackManager.total_changed.emit()    │
   │ └─ автоматическое обновление суммы           │
   └──────────────┬───────────────────────────────┘
                  ↓
   ┌──────────────────────────────────────────────┐
   │ Нажатие "Выплатить"                          │
   │ PayoutPopup._on_payout_button_pressed()      │
   │ ├─ PayoutValidator.validate(collected, exp) │
   │ ├─ ✅ ПРАВИЛЬНО:                             │
   │ │  └─ EventBus.payout_correct.emit()         │
   │ │  └─ OverlayNotificationManager → "Верно!"  │
   │ │  └─ +1 раунд (survival mode)               │
   │ │  └─ сброс и новый раунд                    │
   │ ├─ ❌ НЕПРАВИЛЬНО:                           │
   │ │  └─ EventBus.payout_wrong.emit()           │
   │ │  └─ OverlayNotificationManager → "Ошибка!" │
   │ │  └─ потеря жизни                           │
   │ │  └─ попап остается открытым                │
   └──────────────┬───────────────────────────────┘
                  ↓
6. СБРОС РАУНДА
   ┌──────────────────────────────────────────────┐
   │ GamePhaseManager.reset()                     │
   │ ├─ player_hand.clear()                       │
   │ ├─ banker_hand.clear()                       │
   │ ├─ ui.reset_ui()                             │
   │ ├─ camera.zoom_out() → общий план            │
   │ └─ EventBus.round_reset.emit()               │
   └──────────────┴───────────────────────────────┘
                  ↓ НОВЫЙ РАУНД
```

#### 🔄 Критические точки принятия решений:

**Точка 1: После раздачи 4 карт**
```gdscript
# GameStateManager.determine_state()
if natural_8_or_9:
    return CHOOSE_WINNER  # Сразу к выбору победителя
elif banker_value <= 2 and player_value <= 5:
    return CARD_TO_EACH   # Третья карта обоим
elif banker_value >= 3 and player_value <= 5:
    return CARD_TO_PLAYER # Только игроку
# ... и т.д.
```

**Точка 2: После третьей карты игрока**
```gdscript
# Если игрок получил третью, проверяем нужна ли банкиру
if BaccaratRules.banker_should_draw(banker_hand, true, player_third):
    return CARD_TO_BANKER_AFTER_PLAYER
else:
    return CHOOSE_WINNER
```

**Точка 3: Валидация действия игрока**
```gdscript
# GameStateManager.is_action_valid(action)
match current_state:
    CARD_TO_PLAYER:
        return action == Action.PLAYER_THIRD  # Только третья игроку!
    CARD_TO_BANKER:
        return action == Action.BANKER_THIRD  # Только третья банкиру!
    CARD_TO_EACH:
        return action in [PLAYER_THIRD, BANKER_THIRD] # Обе допустимы
```

### Система управления состояниями

Игровой процесс управляется через **GameStateManager** (autoload singleton) и **GamePhaseManager**.

**GameStateManager** (`scripts/GameStateManager.gd`) - декларативная система состояний:
- Определяет текущее состояние игры на основе карт на столе
- 6 состояний: WAITING, CARD_TO_EACH, CARD_TO_PLAYER, CARD_TO_BANKER, CARD_TO_BANKER_AFTER_PLAYER, CHOOSE_WINNER
- Валидирует допустимые действия: `is_action_valid(action)`
- Выдает сообщения об ошибках: `get_error_message(action)`
- Блокирует изменение настроек во время раздачи: `can_change_settings()`

**GamePhaseManager** (`scripts/GamePhaseManager.gd`) - управление игровым процессом:
- Раздача карт: `deal_first_four()`, `draw_player_third()`, `draw_banker_third()`
- Валидация действий игрока: `_validate_and_execute_third_cards()`, `_validate_banker_after_player()`
- Обновление GameStateManager после каждого действия
- Управление UI toggles и кнопками
- Обработка ошибок и режима выживания

**Состояния игры** (enum GameStateManager.GameState):
1. **WAITING** - карты скрыты, ожидание кнопки "Карты"
2. **CARD_TO_EACH** - банкир 0-2, игрок 0-5 → карта каждому
3. **CARD_TO_PLAYER** - банкир 3-7, игрок 0-5 → карта игроку
4. **CARD_TO_BANKER** - банкир 0-5, игрок 6-7 → карта банкиру
5. **CARD_TO_BANKER_AFTER_PLAYER** - банкир 3-6 после третьей игрока
6. **CHOOSE_WINNER** - все карты открыты, выбор победителя

### Правила баккара: BaccaratRules

`scripts/BaccaratRules.gd` - статический класс с логикой:

**Ключевые методы**:
- `hand_value(hand: Array[Card]) -> int` - сумма очков % 10
- `is_natural(hand) -> bool` - проверка натуральной 8 или 9
- `player_should_draw(player_hand) -> bool` - игрок берёт при ≤5
- `banker_should_draw(banker_hand, player_drew, player_third) -> bool` - сложные правила банкира:
  - 0-2: всегда берёт
  - 7-9: никогда не берёт
  - 3-6: зависит от третьей карты игрока (см. таблицу в методе)
- `get_winner(player_hand, banker_hand) -> String` - возвращает "Player"/"Banker"/"Tie"

### UI система: UIManager

`scripts/UIManager.gd` - управляет всеми UI элементами через сигналы:

**Сигналы**:
- `action_button_pressed()` - кнопка "Раздать карты" / "Открыть"
- `player_third_toggled(selected: bool)` - переключатель третьей карты игрока
- `banker_third_toggled(selected: bool)` - переключатель третьей карты банкира
- `winner_selected(winner: String)` - выбран победитель (Player/Banker/Tie)
- `help_button_pressed()` - кнопка помощи
- `lang_button_pressed()` - переключение языка

**Важно**: UIManager получает ссылку на CardTextureManager для управления текстурами рубашек (?, !, обычная).

### Система выплат с фишками

Визуальная система расчёта выплат с физическими фишками (реализована в v5.9).

**Архитектура** (`scripts/chip_system/`):

1. **ChipStack** (`ChipStack.gd`) - одна стопка фишек:
   - Максимум 20 фишек в стопке (константа MAX_CHIPS)
   - Визуализация через AtlasTexture (показ части стека)
   - Методы: `add_chip()`, `remove_chip()`, `get_total()`, `is_empty()`
   - Сигналы: chip_added, chip_removed, stack_empty, total_changed

2. **ChipStackManager** (`ChipStackManager.gd`) - менеджер всех стопок:
   - Автоматическая сортировка стопок (от крупных к мелким)
   - Динамическое переключение: 6 слотов (Basic) ↔ 10 слотов (Full)
   - Методы: `add_chip(denom)`, `remove_chip(denom)`, `clear_all()`
   - Сигналы: total_changed, slots_changed, stack_added, stack_removed

3. **PayoutValidator** (`PayoutValidator.gd`) - валидация правильности:
   - `validate(collected, expected) -> bool` (погрешность ε=0.01)
   - `get_error_message(collected, expected) -> String`
   - `calculate_hint(amount, denoms) -> Array` - жадный алгоритм для подсказки

4. **PayoutPopup** (`scripts/popups/PayoutPopup.gd`) - UI координатор:
   - Показ информации о ставке, победителе, ожидаемой выплате
   - Флот из 12 номиналов: 100000, 50000, 25000, 10000, 5000, 1000, 500, 100, 25, 5, 1, 0.5
   - Режимы: Basic (6 номиналов) / Full (12 номиналов)
   - Кнопка "Подсказка" → автоматический расчёт
   - Сигналы: payout_confirmed(is_correct, collected, expected), hint_used()

**Логика выплат** (зависит от GameModeManager):
- **Банкир**: stake × 0.95 (комиссия 5%)
  - Classic mode + выигрыш с 6 → stake × 0.5 (Super6)
- **Игрок**: stake × 1.0
- **Ничья**: stake × 8.0 (стандарт)
- **Пары**: stake × 11.0 (Player Pair / Banker Pair)

### Лимиты стола: LimitsManager

`scripts/LimitsManager.gd` - управляет min/max/step для обычных ставок и TIE:

```gdscript
- min_bet, max_bet, step - для Player/Banker
- tie_min, tie_max, tie_step - для Tie (обычно меньше)
```

Методы:
- `generate_bet() -> int` - случайная ставка в пределах лимитов
- `generate_tie_bet() -> int` - случайная ставка для TIE

### Autoload синглтоны

Порядок загрузки из `project.godot` (важен для зависимостей):

1. **SaveManager** (`scripts/SaveManager.gd`) - сохранение/загрузка настроек в `user://save_data.json`

2. **Localization** (`scripts/Localization.gd`) - система локализации ru/en:
   - `t(key: String, args: Array = []) -> String` - перевод с подстановкой аргументов
   - `set_lang(lang: String)`, `get_lang() -> String`

3. **GameModeManager** (`scripts/GameModeManager.gd`) - управление режимами игры:
   - Classic / Super6 / EZ Baccarat
   - Определяет правила выплат для каждого режима

4. **GameStateManager** (`scripts/autoload/GameStateManager.gd`) - декларативная система состояний:
   - 6 состояний: WAITING, CARD_TO_EACH, CARD_TO_PLAYER, CARD_TO_BANKER, CARD_TO_BANKER_AFTER_PLAYER, CHOOSE_WINNER
   - Кэширование для производительности (determine_state())
   - Валидация действий: `is_action_valid(action)`, `get_error_message(action)`
   - Блокировка настроек во время раздачи: `can_change_settings()`

5. **EventBus** (`scripts/autoload/EventBus.gd`) - централизованная event-driven система:
   - **🎮 Игровой процесс**: cards_dealt, player_third_drawn, banker_third_drawn, game_completed, round_reset
   - **✅ Правильные действия**: action_correct, winner_correct
   - **❌ Ошибки**: action_error
   - **💰 Выплаты**: show_payout_popup, payout_correct, payout_wrong, hint_used
   - **📢 Toast**: show_toast_info, show_toast_success, show_toast_error
   - **🎬 Overlay**: show_overlay_success, show_overlay_error, show_overlay_info
   - **⚙️ Настройки**: game_mode_changed, language_changed, survival_mode_changed, table_limits_changed
   - **💔 Режим выживания**: life_lost, game_over, game_restarted
   - **📊 Состояния**: game_state_changed

6. **StatsManager** (`scripts/StatsManager.gd`) - статистика (подписан на EventBus)

7. **ToastManager** (`scripts/ToastManager.gd`) - toast-уведомления:
   - Object pooling (пул из 5 узлов ToastPool)
   - Сигналы: show_toast_info, show_toast_success, show_toast_error

8. **OverlayNotificationManager** (`scripts/OverlayNotificationManager.gd`) - крупные overlay-надписи:
   - "Верно!", "Ошибка!", "Game Over"
   - Анимация появления/исчезновения

9. **FocusManager** (`scripts/FocusManager.gd`) - управление фокусом для джойпада

10. **GameDataManager** (`scripts/GameDataManager.gd`) - хранение текущего состояния раунда

11. **PayoutSettingsManager** (`scripts/autoload/PayoutSettingsManager.gd`) - настройки выплат

12. **BetProfileManager** (`scripts/autoload/BetProfileManager.gd`) - профили ставок

13. **PayoutContextManager** (`scripts/PayoutContextManager.gd`) - контекст текущей выплаты

### Карта зависимостей менеджеров

Понимание зависимостей критично для рефакторинга!

```
GameController (главный оркестратор)
├── deck: Deck
│   └── используется: GamePhaseManager
├── card_manager: CardTextureManager
│   └── используется: UIManager (для текстур рубашек)
├── ui_manager: UIManager
│   ├── зависит от: CardTextureManager
│   ├── сигналы → GameController
│   └── управляет всеми UI узлами сцены
├── phase_manager: GamePhaseManager
│   ├── зависит от: Deck, CardTextureManager, UIManager
│   ├── использует: BaccaratRules (static)
│   ├── обновляет: GameStateManager.determine_state()
│   ├── вызывает: GameController.on_error_occurred()
│   └── эмитит события через EventBus
├── limits_manager: LimitsManager
│   └── генерирует случайные ставки в пределах лимитов
├── camera: Camera2D
│   └── управляется: GameController (zoom in/out)
├── chip_visual_manager: ChipVisualManager
│   └── визуализация фишек на столе
├── winner_selection_manager: WinnerSelectionManager
│   └── подсветка выбранного победителя
├── payout_queue_manager: PayoutQueueManager
│   ├── управляет очередью выплат [Main, Pairs]
│   └── показывает PayoutPopup по очереди
└── pair_betting_manager: PairBettingManager
    ├── проверяет пары при раздаче
    └── хранит результаты: player_pair_detected, banker_pair_detected

Autoload синглтоны (глобальные зависимости):
├── EventBus
│   ├── используется: ВСЕ менеджеры
│   ├── 28+ сигналов для коммуникации
│   └── КРИТИЧНО: центральная точка связи всех компонентов
├── GameStateManager
│   ├── используется: GamePhaseManager, GameController
│   ├── определяет состояние на основе карт
│   └── валидирует действия игрока
├── GameModeManager
│   ├── используется: PayoutCalculator, BetManager
│   └── определяет правила выплат (Classic/Super6/EZ)
├── Localization
│   ├── используется: ВСЕ UI компоненты
│   └── метод t(key) для перевода
├── SaveManager
│   ├── используется: настройки, лимиты
│   └── сохранение в user://save_data.json
├── StatsManager
│   ├── подписан на: EventBus (action_correct/error)
│   └── обновляет UI автоматически
├── ToastManager
│   ├── подписан на: EventBus (show_toast_*)
│   └── использует: ToastPool (object pooling)
├── OverlayNotificationManager
│   ├── подписан на: EventBus (show_overlay_*)
│   └── крупные надписи "Верно!", "Ошибка!"
├── PayoutSettingsManager
│   ├── хранит: какие выплаты активны (Player/Banker/Tie/Pairs)
│   └── используется: PayoutQueueManager
├── BetProfileManager
│   └── профили ставок для разных режимов
└── PayoutContextManager
    └── контекст текущей выплаты (winner, stake, payout)
```

### Детальное описание EventBus (Event-Driven Architecture)

**EventBus** - это сердце архитектуры! Все межкомпонентные коммуникации идут через него.

#### 📡 Категории событий (28 сигналов):

**1. 🎮 Игровой процесс** (5 сигналов):
```gdscript
signal cards_dealt(player_hand: Array[Card], banker_hand: Array[Card])
# Когда: после deal_first_four()
# Кто слушает: StatsManager, анимации

signal player_third_drawn(card: Card)
# Когда: draw_player_third()
# Кто слушает: анимации, логи

signal banker_third_drawn(card: Card)
# Когда: draw_banker_third()

signal game_completed()
# Когда: все карты открыты → CHOOSE_WINNER
# Кто слушает: UI для переключения режима

signal round_reset()
# Когда: начало нового раунда
# Кто слушает: все менеджеры для сброса состояния
```

**2. ✅ Правильные действия** (2 сигнала):
```gdscript
signal action_correct(type: String)
# type: "player_third", "banker_third", "both_third", "winner", "payout"
# Кто слушает: StatsManager (+1 correct), звуки

signal winner_correct(winner: String, player_hand: Array[Card], banker_hand: Array[Card])
# Когда: правильно выбран победитель
# Кто слушает: PayoutQueueManager (подготовка выплат)
```

**3. ❌ Ошибки** (1 сигнал):
```gdscript
signal action_error(type: String, message: String)
# type: "player_wrong", "banker_wrong", "natural_draw", "both_wrong",
#       "winner_early", "winner_wrong", "payout_wrong"
# Кто слушает: StatsManager, SurvivalUI (потеря жизни), Toast
```

**4. 💰 Выплаты** (4 сигнала):
```gdscript
signal show_payout_popup(winner: String, stake: float, payout: float)
# Кто слушает: PayoutQueueManager

signal payout_correct(collected: float, expected: float)
# Кто слушает: StatsManager, SurvivalUI (+1 раунд), Overlay

signal payout_wrong(collected: float, expected: float)
# Кто слушает: StatsManager, SurvivalUI (потеря жизни), Overlay

signal hint_used()
# Когда: нажата кнопка "Подсказка" в PayoutPopup
# Кто слушает: StatsManager (опционально: штраф)
```

**5. 📢 Toast уведомления** (3 сигнала):
```gdscript
signal show_toast_info(message: String)
signal show_toast_success(message: String)
signal show_toast_error(message: String)
# Кто слушает: ToastManager → показывает маленькое уведомление
```

**6. 🎬 Overlay уведомления** (3 сигнала):
```gdscript
signal show_overlay_success(message: String, duration: float)
signal show_overlay_error(message: String, duration: float)
signal show_overlay_info(message: String, duration: float)
# Кто слушает: OverlayNotificationManager → крупная надпись на экране
```

**7. ⚙️ Настройки** (4 сигнала):
```gdscript
signal game_mode_changed(new_mode: String)
# new_mode: "Classic", "Super6", "EZ Baccarat"
# Кто слушает: BetManager, PayoutCalculator

signal language_changed(new_lang: String)
# new_lang: "ru", "en"
# Кто слушает: все UI элементы для обновления текстов

signal survival_mode_changed(enabled: bool)
# Кто слушает: SurvivalUI (показать/скрыть), GameController

signal table_limits_changed(min: int, max: int, step: int)
# Кто слушает: LimitsManager, BetPopup
```

**8. 💔 Режим выживания** (3 сигнала):
```gdscript
signal life_lost(remaining_lives: int)
# Когда: любая ошибка в survival mode
# Кто слушает: SurvivalUI (обновление сердечек)

signal game_over(rounds_completed: int)
# Когда: 0 жизней
# Кто слушает: GameOverPopup (показать экран)

signal game_restarted()
# Когда: нажата кнопка Restart
# Кто слушает: GameController (сброс всего)
```

**9. 📊 Состояния** (1 сигнал):
```gdscript
signal game_state_changed(old_state: GameState, new_state: GameState)
# Эмитится: GameStateManager.determine_state()
# Кто слушает: UI (обновление доступности кнопок/toggles)
```

#### 🔌 Паттерн использования EventBus:

**ПРАВИЛЬНО** ✅ (через EventBus):
```gdscript
# В GamePhaseManager при ошибке:
EventBus.action_error.emit("player_wrong", Localization.t("ERROR_PLAYER_THIRD"))
EventBus.show_toast_error.emit(Localization.t("ERROR_PLAYER_THIRD"))

# В SurvivalUI подписка:
func _ready():
    EventBus.action_error.connect(_on_error)
    EventBus.payout_wrong.connect(_on_error)

func _on_error(type = null, message = null):
    lose_life()  # потеря жизни
```

**НЕПРАВИЛЬНО** ❌ (прямой вызов):
```gdscript
# НЕ ДЕЛАЙ ТАК!
get_node("/root/ToastManager").show_error("Ошибка")
game_controller.survival_ui.lose_life()
```

#### 💡 Преимущества EventBus:
1. **Слабая связанность** - компоненты не знают друг о друге
2. **Простота тестирования** - можно мокировать события
3. **Легкость расширения** - добавил подписчика, и он работает
4. **Централизованный контроль** - все события в одном месте
5. **Отладка** - можно логировать все события в EventBus

## Игровой процесс

1. **Старт** → WAITING
   - Показываются рубашки карт
   - Toggles третьих карт **отключены** (mouse_filter = IGNORE, полупрозрачные)
   - Кнопка "Раздать карты" активна
   - Попытка выбрать победителя → toast без штрафа

2. **Раздача** → CARD_TO_PLAYER / CARD_TO_BANKER / CARD_TO_EACH
   - Раздаются 4 карты (2 игроку, 2 банкиру)
   - Toggles **включаются** (можно заказывать третьи карты)
   - GameStateManager определяет состояние на основе очков
   - Проверка натуральных (8-9) → сразу CHOOSE_WINNER

3. **Заказ третьих карт** → валидация в GamePhaseManager
   - Игрок ставит галочки на toggles (? ↔ !)
   - Нажимает кнопку "карты" для подтверждения
   - `_validate_and_execute_third_cards()` проверяет правильность
   - Если **правильно** → раздача карты, toggle скрывается
   - Если **неправильно** → toast с ошибкой, штраф (жизнь/очки), toggle остается

4. **Банкир после игрока** → CARD_TO_BANKER_AFTER_PLAYER
   - После раздачи третьей карты игроку
   - `_handle_banker_after_player()` показывает toast "Решение банкира"
   - Игрок выбирает toggle банкира, нажимает "карты"
   - `_validate_banker_after_player()` валидирует выбор

5. **Выбор победителя** → CHOOSE_WINNER
   - Все карты открыты, кнопка "карты" **отключена**
   - Игрок кликает на маркер (Player/Banker/Tie)
   - Проверка через `GameStateManager.is_action_valid(SELECT_WINNER)`
   - Сравнение с `BaccaratRules.get_winner()`
   - Если **правильно** → PayoutPopup для расчёта выплаты
   - Если **неправильно** → toast с ошибкой, штраф

6. **Расчёт выплаты** (PayoutPopup)
   - Флот фишек разных номиналов (100000, 50000, ..., 0.5)
   - Игрок собирает стопки фишек (max 20 в стопке)
   - Кнопка "Подсказка" → автоматический расчёт (жадный алгоритм)
   - Проверка через `PayoutValidator.validate(collected, expected)`
   - Если **правильно** → сброс раунда, +1 очко
   - Если **неправильно** → toast с ошибкой, штраф

## Конфигурация: GameConfig

`resources/GameConfig.gd` - ресурс с настройками:

```gdscript
@export var card_paths: Dictionary  # Пути к текстурам карт
@export var back_card_path: String  # Обычная рубашка
@export var back_question_path: String  # Рубашка с ?
@export var back_exclamation_path: String  # Рубашка с !
@export var commission_rate: float = 0.95  # Комиссия банкира
@export var table_min_bet, table_max_bet, table_step: int
@export var tie_min_bet, tie_max_bet, tie_step: int
```

## Тестирование

Проект использует **GUT (Godot Unit Testing)** framework (addons/gut/).

**Запуск всех тестов**:
```bash
# CLI (headless режим)
godot --path . --headless --script addons/gut/gut_cmdln.gd

# В редакторе Godot
# Нижняя панель → вкладка GUT → кнопка "Run All"
```

**Запуск конкретного теста**:
```bash
# Только один тест-файл
godot --path . --headless --script addons/gut/gut_cmdln.gd -gtest=tests/test_baccarat_rules.gd

# Только один тест-метод
godot --path . --headless --script addons/gut/gut_cmdln.gd -gtest=tests/test_baccarat_rules.gd -ginner_class=TestBankerRules
```

**Структура тестов**:
- `tests/test_baccarat_rules.gd` - юнит-тесты правил баккара
- `tests/test_*.gd` - другие тесты

**Шаблон теста**:
```gdscript
extends GutTest

func test_something():
    assert_eq(expected, actual, "Optional error message")

func test_with_setup():
    var card = Card.new("hearts", "A")
    assert_eq(card.get_point(), 1, "Ace should be 1 point")
```

**Важные assertion методы**:
- `assert_eq(a, b, msg)` - равенство
- `assert_ne(a, b, msg)` - неравенство
- `assert_true(condition, msg)` - истина
- `assert_false(condition, msg)` - ложь
- `assert_null(value, msg)` - null
- `assert_not_null(value, msg)` - не null

## Ключевые технические детали

### Карты

Класс `Card` (`scripts/Card.gd`):
```gdscript
var suit: String  # "clubs", "hearts", "spades", "diamonds"
var rank: String  # "A", "2"-"10", "J", "Q", "K"

func get_point() -> int:
    # A=1, 2-9=номинал, 10/J/Q/K=0
```

### Колода

`scripts/Deck.gd`:
- 52 карты, перемешивается в конструкторе
- `draw() -> Card` - взять карту
- Нет автоматического перемешивания при исчерпании (для тренажёра это норма)

### Toast система

`scripts/ToastManager.gd` + `scripts/Toast.gd`:
- `show_success(text)` - зелёный toast
- `show_error(text)` - красный toast
- `show_info(text)` - серый toast
- Автоматически исчезают через несколько секунд

### Статистика

`scripts/StatsManager.gd`:
- Хранит счётчики: `correct`, `errors` (словарь по типам)
- `increment_correct()` - +1 правильный ответ
- `increment_error(error_type: String)` - +1 ошибка типа
- Типы ошибок: "player_third_wrong", "banker_third_wrong", "winner_wrong", "commission_wrong", "tie_payout_wrong"
- `update_stats()` - обновляет Label в UI

## Режим выживания

Система жизней с наказанием за ошибки (реализована в v5.9).

**Механика**:
- Игрок начинает с 7 жизнями (отображаются эмодзи-сердечками ❤️)
- Каждая ошибка отнимает 1 жизнь
- Счётчик пройденных раундов (отображается рядом с жизнями)
- При 0 жизней → Game Over экран с результатом

**Точки потери жизни** (12 типов ошибок):
1. Неправильная третья карта игроку
2. Неправильная третья карта банкиру
3. Заказ обеих третьих карт, когда нужна только одна
4. Заказ третьей при натуральной (8-9)
5. Попытка выбрать победителя до завершения раздачи
6. Неправильный выбор победителя
7-12. Ошибки в расчёте выплат (различные случаи)

**UI компоненты**:
- `SurvivalUI` (Control) - панель с жизнями и раундами
- `GameOverPopup` (PopupPanel) - экран Game Over
- Кнопка "Рестарт" для начала новой игры

**События** (через EventBus):
- `life_lost` - потеря жизни
- `game_over` - конец игры (0 жизней)
- `game_restarted` - начало новой игры

## Управление

### Клавиатура / Мышь
- Все кнопки кликабельны
- Переключатели третьей карты - клик по TextureRect
- Фишки в PayoutPopup - клик для добавления/удаления

### Джойпад
Настроены InputMap actions в `project.godot`:
- `CardsButton` - раздать карты (кнопка 9, Start)
- `PlayerThirdCardToggle` - третья карта игрока (кнопка 5, LB)
- `BankerThirdCardToggle` - третья карта банкира (кнопка 3, RB)
- `PlayerMarker` - выбрать игрока (кнопка 4, Y)
- `BankerMarker` - выбрать банкира (кнопка 2, X)
- `TieMarker` - выбрать ничью (кнопка 0, A)
- `ui_focus_accept` - подтвердить (кнопка 1, B)
- WASD / стрелки - навигация по фокусу

## Структура сцены Game.tscn

Главная сцена: `scenes/Game.tscn`

Иерархия узлов:
- **PlayerZone** - зона карт игрока
  - Card1, Card2, Card3 (TextureRect)
  - PlayerThirdCardToggle (TextureRect) - переключатель ?/!
- **BankerZone** - зона карт банкира
  - Card1, Card2, Card3 (TextureRect)
  - BankerThirdCardToggle (TextureRect)
- **CardsButton** - главная кнопка действия
- **PlayerMarker**, **BankerMarker**, **TieMarker** - кнопки выбора победителя
- **BetChip**, **TieChip** - кнопки для показа попапов ставок
- **BetPopup** (PopupPanel) - попап ввода выплаты
- **LimitsPopup** (PopupPanel) - попап настройки лимитов
- **HelpPopup** - попап помощи
- **StatsLabel** - Label со статистикой
- **HelpButton** - кнопка помощи
- **LangButton** - кнопка смены языка
- **LimitsButton** - кнопка настройки лимитов

## Система камеры

`GameController` управляет Camera2D с плавными переходами:

**Константы**:
- `CAMERA_ZOOM_GENERAL = Vector2(1.0, 1.0)` - общий план (весь стол)
- `CAMERA_ZOOM_CARDS = Vector2(1.3, 1.3)` - зум на зону раздачи
- `CAMERA_POS_GENERAL = Vector2(577, 325)` - центр окна (1154x650)
- `CAMERA_POS_CARDS = Vector2(595, 400)` - центр зоны Player/Banker
- `CAMERA_TRANSITION_DURATION = 0.5` - длительность анимации (сек)

**Поведение**:
- При первой раздаче → зум на карты (CAMERA_ZOOM_CARDS)
- При выборе победителя → общий план (CAMERA_ZOOM_GENERAL)
- Все переходы анимированы через Tween

## Детальная структура проекта

### 📁 Организация файлов и директорий

```
Baccarat/
├── assets/                  # Графические ресурсы
│   ├── cards/              # Текстуры карт (52 карты + рубашки)
│   ├── chips/              # Текстуры фишек (12 номиналов)
│   └── ui/                 # UI элементы, иконки
│
├── scenes/                 # Godot сцены (.tscn)
│   ├── Game.tscn          # Главная сцена (корень игры)
│   ├── PayoutScene.tscn   # Сцена с PayoutPopup
│   └── ...
│
├── scripts/                # GDScript код (41 файл)
│   │
│   ├── autoload/          # Autoload синглтоны
│   │   ├── EventBus.gd                # Централизованная шина событий
│   │   ├── GameStateManager.gd        # State Machine для игры
│   │   ├── BetProfileManager.gd       # Профили ставок
│   │   └── PayoutSettingsManager.gd   # Настройки выплат
│   │
│   ├── chip_system/       # Система фишек и выплат
│   │   ├── ChipStack.gd              # Одна стопка фишек (max 20)
│   │   ├── ChipStackManager.gd       # Менеджер всех стопок
│   │   └── PayoutValidator.gd        # Валидация правильности выплаты
│   │
│   ├── popups/            # (пустая - попапы в корне scripts/)
│   │
│   ├── scenes/            # Скрипты для сцен
│   │   └── PayoutScene.gd           # Логика PayoutPopup
│   │
│   ├── Основные менеджеры (корень scripts/):
│   │   ├── GameController.gd         # Главный оркестратор
│   │   ├── GamePhaseManager.gd       # Управление фазами игры
│   │   ├── UIManager.gd              # Фасад для UI
│   │   ├── LimitsManager.gd          # Лимиты стола
│   │   ├── ToastManager.gd           # Toast уведомления
│   │   ├── OverlayNotificationManager.gd  # Крупные надписи
│   │   ├── StatsManager.gd           # Статистика
│   │   ├── GameModeManager.gd        # Режимы игры
│   │   ├── SaveManager.gd            # Сохранение настроек
│   │   ├── Localization.gd           # i18n (ru/en)
│   │   ├── FocusManager.gd           # Фокус для джойпада
│   │   ├── GameDataManager.gd        # Состояние раунда
│   │   └── PayoutContextManager.gd   # Контекст выплаты
│   │
│   ├── Новые менеджеры (v5.9+):
│   │   ├── ChipVisualManager.gd      # Визуализация фишек
│   │   ├── WinnerSelectionManager.gd # Подсветка победителя
│   │   ├── PayoutQueueManager.gd     # Очередь выплат
│   │   └── PairBettingManager.gd     # Логика пар
│   │
│   ├── Модели данных:
│   │   ├── Card.gd                   # Модель карты
│   │   ├── Deck.gd                   # Колода 52 карт
│   │   ├── BaccaratRules.gd          # Статические правила
│   │   └── CardTextureManager.gd     # Загрузка текстур
│   │
│   ├── UI компоненты:
│   │   ├── Toast.gd                  # Один toast узел
│   │   ├── ToastPool.gd              # Object pool для Toast
│   │   ├── OverlayNotification.gd    # Крупная надпись
│   │   ├── BetPopup.gd               # Попап ставок
│   │   ├── TableLimitsPopup.gd       # Настройка лимитов
│   │   ├── SettingsPopup.gd          # Настройки игры
│   │   └── GameOverPopup.gd          # Game Over экран
│   │
│   └── Вспомогательные:
│       └── GameConstants.gd          # Константы (цвета, задержки)
│
├── resources/              # Godot ресурсы
│   └── GameConfig.gd      # Конфигурация (пути к ассетам, коэффициенты)
│
├── tests/                  # GUT тесты
│   ├── test_baccarat_rules.gd       # Тесты правил баккара
│   └── ...
│
├── addons/                 # Godot аддоны
│   └── gut/               # GUT testing framework
│
├── project.godot          # Главный конфиг проекта
├── export_presets.cfg     # Настройки экспорта
├── CLAUDE.md              # Документация для Claude Code
└── README.md              # Общее описание проекта
```

### 📚 Детальное описание каждого менеджера

#### 1. GameController.gd (Оркестратор)

**Роль**: Главный координатор, связывает все подсистемы.

**Ключевые методы**:
- `_ready()` - инициализация всех менеджеров, подписка на сигналы
- `_on_action_button()` - обработка главной кнопки "Карты"
- `_on_winner_selected(winner)` - обработка выбора победителя
- `_prepare_payouts()` - формирование очереди выплат
- `camera_zoom_in()` / `camera_zoom_out()` - управление камерой
- `_on_round_completed()` - завершение раунда (+1 в survival mode)

**Не содержит**: Игровой логики, валидации, расчётов.

**Паттерн**: Facade + Mediator.

#### 2. GamePhaseManager.gd (Фазы игры)

**Роль**: Управляет последовательностью фаз раунда.

**Состояние**:
```gdscript
var player_hand: Array[Card]
var banker_hand: Array[Card]
var player_third_selected: bool
var banker_third_selected: bool
```

**Ключевые методы**:
- `deal_first_four()` - раздача 4 карт, проверка пар
- `draw_player_third()` - раздача третьей игроку
- `draw_banker_third()` - раздача третьей банкиру
- `_validate_and_execute_third_cards()` - валидация выбора игрока
- `_validate_banker_after_player()` - валидация банкира после игрока
- `_update_game_state_manager()` - обновление GameStateManager
- `reset()` - сброс к начальному состоянию

**Зависимости**: Deck, UIManager, CardTextureManager, BaccaratRules, GameStateManager.

**Важно**: Все валидации идут через `GameStateManager.is_action_valid()` + `BaccaratRules`.

#### 3. GameStateManager.gd (State Machine)

**Роль**: Декларативное определение состояния игры на основе карт.

**Enum GameState**: 6 состояний (WAITING, CARD_TO_EACH, ..., CHOOSE_WINNER).

**Enum Action**: 4 действия (DEAL_CARDS, PLAYER_THIRD, BANKER_THIRD, SELECT_WINNER).

**Ключевые методы**:
- `determine_state(cards_hidden, player_hand, banker_hand, p3, b3) -> GameState` - **центральный метод**
- `is_action_valid(action: Action) -> bool` - валидация действия
- `get_error_message(action: Action) -> String` - сообщение об ошибке
- `can_change_settings() -> bool` - можно ли менять настройки (только в WAITING)

**Оптимизации**:
- Кэширование результатов `determine_state()` через хэш
- `_hash_params()` - генерация хэша из параметров
- Проверка кэша перед вычислением

**Логика определения состояния** (упрощённо):
```gdscript
if cards_hidden: return WAITING
if natural_8_or_9: return CHOOSE_WINNER
if both_have_3_cards: return CHOOSE_WINNER
# Дальше логика по очкам банкира и игрока
```

#### 4. UIManager.gd (UI Facade)

**Роль**: Единая точка входа для всех UI операций.

**Управляет**:
- Кнопки: action_button, help_button, lang_button
- Карты: player_card1-3, banker_card1-3
- Toggles: player_third_toggle, banker_third_toggle
- Маркеры: player_marker, banker_marker, tie_marker
- Попапы: help_popup, bet_popup
- Статистика: stats_label

**Сигналы** (эмитирует в GameController):
- action_button_pressed()
- player_third_toggled(selected)
- banker_third_toggled(selected)
- winner_selected(winner)
- help_button_pressed()
- lang_button_pressed()

**Ключевые методы**:
- `show_first_four_cards(p_hand, b_hand)` - анимация раздачи 4 карт
- `show_player_third_card(card)` - анимация третьей игрока
- `show_banker_third_card(card)` - анимация третьей банкиру
- `update_player_third_card_ui(mode)` - переключение ? ↔ ! ↔ card
- `reset_ui()` - сброс UI к начальному состоянию
- `enable_action_button()` / `disable_action_button()`

**Паттерн**: Facade.

#### 5. BaccaratRules.gd (Статические правила)

**Роль**: Чистая бизнес-логика правил баккара.

**Статические методы**:
```gdscript
static func hand_value(hand: Array[Card]) -> int
# Сумма очков % 10

static func is_natural(hand: Array[Card]) -> bool
# Проверка 8 или 9

static func player_should_draw(player_hand: Array[Card]) -> bool
# Игрок берёт при ≤5

static func banker_should_draw(
    banker_hand: Array[Card],
    player_drew: bool,
    player_third: Card
) -> bool
# Сложная логика банкира (таблица 3-6 очков)

static func get_winner(player_hand, banker_hand) -> String
# "Player" / "Banker" / "Tie"
```

**Важно**: НЕТ зависимостей, чистая функция - легко тестировать!

#### 6. ChipStack.gd + ChipStackManager.gd (Система фишек)

**ChipStack** - одна стопка фишек:
```gdscript
var denomination: float      # Номинал (100, 50, 10...)
var count: int = 0          # Количество фишек
const MAX_CHIPS = 20        # Максимум в стопке

func add_chip() -> void     # Добавить фишку (+1)
func remove_chip() -> void  # Убрать фишку (-1)
func get_total() -> float   # denomination * count
```

**ChipStackManager** - менеджер всех стопок:
```gdscript
var stacks: Array[ChipStack]
var denominations: Array[float]  # Доступные номиналы

func add_chip(denom: float)     # Найти/создать стопку и добавить
func remove_chip(denom: float)  # Убрать из стопки / удалить стопку
func get_total() -> float       # Сумма всех стопок
func clear_all()                # Очистить всё
```

**Фичи**:
- Автоматическая сортировка (от крупных к мелким)
- Динамическое переключение слотов: 6 (Basic) ↔ 10 (Full)
- Сигналы: total_changed, slots_changed, stack_added, stack_removed

#### 7. PayoutValidator.gd (Валидация выплат)

**Роль**: Проверка правильности собранной выплаты.

**Методы**:
```gdscript
static func validate(collected: float, expected: float) -> bool
# Сравнение с погрешностью ε=0.01

static func get_error_message(collected: float, expected: float) -> String
# Генерация сообщения об ошибке

static func calculate_hint(
    target_amount: float,
    denominations: Array[float]
) -> Array
# Жадный алгоритм для кнопки "Подсказка"
```

**Жадный алгоритм** (для подсказки):
```gdscript
# Начинает с самого крупного номинала
# Берёт максимум фишек этого номинала
# Переходит к следующему меньшему
# Цель: минимизировать количество фишек
```

#### 8. PayoutQueueManager.gd (Очередь выплат)

**Роль**: Управление последовательностью выплат (Main → Pairs).

**Очередь**:
```gdscript
var payout_queue: Array = []
# Например: [
#   {type: "main", winner: "Banker", stake: 200, payout: 190},
#   {type: "pair", pair_type: "player", stake: 50, payout: 550}
# ]
```

**Методы**:
- `add_payout(payout_data)` - добавить в очередь
- `show_next_payout()` - показать PayoutPopup для следующей
- `clear_queue()` - очистить очередь
- `_on_payout_confirmed()` - обработка результата (правильно/нет)

**Логика**: Main выплата всегда первая, потом Pairs (если есть).

#### 9. EventBus.gd (Центральная шина)

См. раздел "Детальное описание EventBus" выше.

#### 10. ToastManager.gd + ToastPool.gd (Уведомления)

**ToastManager** - синглтон, подписан на EventBus:
```gdscript
func _ready():
    EventBus.show_toast_info.connect(_show_info)
    EventBus.show_toast_success.connect(_show_success)
    EventBus.show_toast_error.connect(_show_error)
```

**ToastPool** - object pooling:
```gdscript
const POOL_SIZE = 5
var pool: Array[Toast] = []

func get_toast() -> Toast  # Взять из пула или создать
func return_toast(toast)   # Вернуть в пул
```

**Оптимизация**: Переиспользование узлов вместо create/queue_free().

#### 11. StatsManager.gd (Статистика)

**Роль**: Сбор и отображение статистики.

**Состояние**:
```gdscript
var correct: int = 0
var errors: Dictionary = {
    "player_third_wrong": 0,
    "banker_third_wrong": 0,
    "winner_wrong": 0,
    # ...
}
```

**Подписки**:
```gdscript
EventBus.action_correct.connect(_on_correct)
EventBus.action_error.connect(_on_error)
EventBus.payout_correct.connect(_on_payout_correct)
EventBus.payout_wrong.connect(_on_payout_wrong)
```

**Автоматическое обновление**: Каждое событие → обновление UI.

#### 12. Localization.gd (i18n)

**Словарь переводов**:
```gdscript
var translations = {
    "ACTION_BUTTON_CARDS": {
        "ru": "Карты",
        "en": "Cards"
    },
    "ERROR_PLAYER_THIRD": {
        "ru": "Игрок не должен брать третью карту",
        "en": "Player shouldn't draw third card"
    },
    # ... 50+ ключей
}
```

**Метод**:
```gdscript
func t(key: String, args: Array = []) -> String
# Возвращает перевод с подстановкой args
# Пример: t("PAYOUT_STAKE", [200]) → "Ставка: 200"
```

## Планы развития

Из `redme.txt`:

1. ✅ **Интерфейс выплаты с фишками** - реализовано в v5.9
2. **Подсказка с подсветкой зон** - визуальная помощь новичкам
3. **Улучшенные комментарии в тостах** - более информативные сообщения
4. ✅ **Камера** - реализована динамическая камера с зумом
5. **Анимация карт** - плавное появление карт при раздаче
6. **Звуки** - звуковое сопровождение действий

## Рекомендации при разработке

### Event-Driven архитектура
**ВАЖНО**: Проект использует EventBus для связи между компонентами.

**Правило**: Вместо прямых вызовов методов используй события:
```gdscript
# ❌ Плохо - прямой вызов
toast_manager.show_error("Ошибка!")

# ✅ Хорошо - через EventBus
EventBus.show_toast_error.emit("Ошибка!")
```

**Подписка на события**:
```gdscript
func _ready():
    EventBus.action_correct.connect(_on_action_correct)
    EventBus.payout_wrong.connect(_on_payout_wrong)
```

### При добавлении нового функционала:
1. Определить, в какой менеджер относится функционал
2. Если нужен новый autoload - добавить в `project.godot` в правильном порядке (учитывай зависимости!)
3. Добавить переводы в `Localization.gd` (ru + en) через ключи
4. Обновить `GameConfig.gd` если нужны глобальные настройки
5. Написать тесты в `tests/` (обязательно для игровой логики)
6. Добавить события в EventBus если нужна связь между менеджерами

### При изменении игровой логики:
1. **Всегда** обновлять тесты в `tests/test_baccarat_rules.gd`
2. Проверять соответствие официальным правилам баккара
3. Тестировать все edge cases (натуральные, равенство, пары, etc.)
4. Запускать тесты перед коммитом: `godot --path . --headless --script addons/gut/gut_cmdln.gd`

### При работе с UI:
1. Все UI элементы управляются через UIManager или специализированные менеджеры
2. **Используй сигналы**, не прямые вызовы методов
3. Обновляй локализацию через `Localization.t(key)` при смене языка
4. **Всегда проверяй работу с джойпадом** через FocusManager
5. Для toast используй EventBus: `show_toast_success/error/info`
6. Для крупных надписей используй OverlayNotificationManager через EventBus

### Работа с состояниями:
1. Текущее состояние всегда определяется GameStateManager
2. Не хардкодь логику состояний - используй `is_action_valid(action)`
3. Обновляй состояние через `determine_state()` после каждого изменения карт
4. Проверяй блокировку настроек: `can_change_settings()`

### Стиль кода:
- **Типизация обязательна**: `var hand: Array[Card]`, `func get_point() -> int`
- Комментарии на русском в коде (для пояснения логики)
- Имена переменных/методов/классов на английском
- Используй `# ←` для важных комментариев-маркеров
- Группируй связанные методы вместе, разделяй секции через комментарии:
  ```gdscript
  # ═══════════════════════════════════════════════════════════════════
  # СЕКЦИЯ НАЗВАНИЯ
  # ═══════════════════════════════════════════════════════════════════
  ```

### Отладка:
- `print()` для логов (будут в Output консоли Godot)
- EventBus события для toast/overlay уведомлений
- GUT тесты для проверки игровой логики
- **Всегда проверяй console на ошибки/warnings** после каждого изменения
- Используй `@warning_ignore("unused_signal")` для сигналов EventBus

### Производительность:
- ToastManager использует object pooling - не создавай Toast напрямую
- GameStateManager кэширует состояния - используй `determine_state()` осторожно
- AtlasTexture в ChipStack для оптимизации отрисовки стеков фишек
- Tween для анимаций камеры (переиспользуй существующий Tween)

## Гайд по глубокому рефакторингу

### 🔄 Текущие архитектурные решения и их обоснование

#### ✅ Что сделано правильно и должно сохраниться:

1. **Event-Driven Architecture через EventBus**
   - Все компоненты слабо связаны
   - Легко добавлять новых подписчиков
   - Простота отладки (все события в одном месте)
   - **Не трогать** при рефакторинге!

2. **Декларативная State Machine (GameStateManager)**
   - Состояние определяется из данных (карты), а не из флагов
   - Кэширование для производительности
   - Централизованная валидация действий
   - **Сохранить** эту логику

3. **Разделение ответственностей (Single Responsibility)**
   - Каждый менеджер отвечает за одну область
   - GameController - только координация, НЕ логика
   - BaccaratRules - чистые функции без состояния
   - **Продолжать** этот паттерн

4. **Object Pooling для UI**
   - ToastPool переиспользует узлы
   - Избегание create/queue_free
   - **Расширить** на другие часто создаваемые узлы

#### ⚠️ Потенциальные проблемы и точки улучшения:

1. **GamePhaseManager - слишком много обязанностей**
   ```
   ПРОБЛЕМА:
   - Управление фазами
   - Валидация действий
   - Взаимодействие с UI
   - Управление руками (player_hand, banker_hand)

   РЕШЕНИЕ:
   Разбить на:
   - HandManager (управление руками)
   - PhaseCoordinator (координация фаз)
   - ActionValidator (валидация через GameStateManager)
   ```

2. **UIManager - God Object**
   ```
   ПРОБЛЕМА:
   - Управляет всеми UI элементами (30+ ссылок)
   - Знает о деталях анимаций
   - Сигналы смешаны с логикой

   РЕШЕНИЕ:
   Разбить на специализированные менеджеры:
   - CardUIManager (только карты)
   - ToggleUIManager (toggles третьих карт)
   - MarkerUIManager (маркеры победителя)
   - ButtonUIManager (кнопки)
   ```

3. **Зависимость от scene tree**
   ```
   ПРОБЛЕМА:
   UIManager получает узлы через get_node() в конструкторе
   Жёсткая привязка к структуре сцены

   РЕШЕНИЕ:
   Dependency Injection через конструктор:
   func _init(action_btn: Button, player_cards: Array[TextureRect], ...)
   ```

4. **Прямые вызовы вместо EventBus**
   ```
   ПРОБЛЕМА:
   GamePhaseManager.on_error_occurred() вызывает:
   game_controller.survival_ui.lose_life()

   РЕШЕНИЕ:
   EventBus.life_lost.emit(remaining_lives)
   ```

5. **Отсутствие интерфейсов/абстракций**
   ```
   ПРОБЛЕМА:
   Сложно подменить реализацию для тестов

   РЕШЕНИЕ:
   Создать абстрактные базовые классы:
   - IValidator (для PayoutValidator, ActionValidator)
   - IDeckProvider (для Deck, MockDeck)
   - IStateManager (для GameStateManager)
   ```

### 🛠️ Пошаговый план рефакторинга (если потребуется)

#### Фаза 1: Разделение UIManager (низкий риск)

1. Создать `scripts/ui/` директорию
2. Вынести компоненты:
   ```
   CardUIManager.gd      - управление картами и анимациями
   ToggleUIManager.gd    - toggles третьих карт
   MarkerUIManager.gd    - маркеры победителя
   ButtonUIManager.gd    - кнопки действий
   ```
3. UIManager становится фасадом-агрегатором
4. Каждый компонент эмитит события → UIManager собирает их

**Тесты**: Проверить что все сигналы работают, анимации корректны.

#### Фаза 2: Декомпозиция GamePhaseManager (средний риск)

1. Создать `scripts/game_logic/` директорию
2. Выделить компоненты:
   ```
   HandManager.gd          - player_hand, banker_hand, третьи карты
   PhaseCoordinator.gd     - последовательность фаз
   ActionValidator.gd      - делегирует GameStateManager + BaccaratRules
   ```
3. GamePhaseManager остаётся тонким слоем-координатором

**Тесты**: Полный прогон GUT тестов, ручное тестирование всех сценариев.

#### Фаза 3: Введение Dependency Injection (высокий риск)

1. Создать `GameContext.gd` - контейнер зависимостей:
   ```gdscript
   class_name GameContext

   var deck: IDeckProvider
   var state_manager: IStateManager
   var event_bus: EventBus
   var localization: ILocalization

   func _init():
       # Регистрация зависимостей
       deck = Deck.new()
       state_manager = GameStateManager
       event_bus = EventBus
       # ...
   ```

2. Все менеджеры получают зависимости через конструктор
3. Убрать прямые обращения к autoload (кроме EventBus)

**Тесты**: Создать MockContext для юнит-тестов.

#### Фаза 4: Абстрактные интерфейсы (низкий риск)

1. Создать `scripts/interfaces/` директорию
2. Базовые классы:
   ```gdscript
   # IDeckProvider.gd
   class_name IDeckProvider
   func draw() -> Card:
       assert(false, "Must override")

   # IValidator.gd
   class_name IValidator
   func validate(data) -> bool:
       assert(false, "Must override")
   ```

3. Реализации наследуют интерфейсы
4. Тесты используют моки

**Тесты**: Покрытие всех критичных компонентов моками.

### 📋 Чеклист перед добавлением новой фичи

#### 1. Определение места в архитектуре

- [ ] К какому слою относится фича? (Presentation/Business/Data/Infrastructure)
- [ ] Какой менеджер отвечает за эту область?
- [ ] Нужен ли новый менеджер или можно расширить существующий?

#### 2. Зависимости

- [ ] Какие autoload синглтоны нужны?
- [ ] Порядок инициализации в project.godot корректен?
- [ ] Все зависимости через EventBus или DI?

#### 3. События

- [ ] Какие новые события нужны в EventBus?
- [ ] Кто будет эмитить события?
- [ ] Кто будет слушать события?
- [ ] Документировать события в CLAUDE.md

#### 4. Локализация

- [ ] Добавлены ключи переводов в Localization.gd (ru + en)?
- [ ] Все UI тексты через `Localization.t(key)`?

#### 5. Состояния

- [ ] Нужны ли новые состояния в GameStateManager?
- [ ] Нужны ли новые действия (Action)?
- [ ] Обновлена валидация `is_action_valid()`?

#### 6. Тестирование

- [ ] Написаны GUT тесты для бизнес-логики?
- [ ] Проверены все edge cases?
- [ ] Ручное тестирование с джойпадом?
- [ ] Тестирование в survival mode?

#### 7. Производительность

- [ ] Используется object pooling где нужно?
- [ ] Нет утечек памяти (connect/disconnect)?
- [ ] Кэширование дорогих операций?

#### 8. Документация

- [ ] Обновлён CLAUDE.md (новые менеджеры, зависимости)?
- [ ] Комментарии в коде (на русском)?
- [ ] Обновлён раздел "Планы развития"?

### 🎯 Антипаттерны, которых нужно избегать

#### ❌ 1. Прямые вызовы через scene tree
```gdscript
# ПЛОХО
get_node("/root/ToastManager").show_error("Ошибка")
game_controller.survival_ui.lose_life()

# ХОРОШО
EventBus.show_toast_error.emit("Ошибка")
EventBus.life_lost.emit(remaining_lives)
```

#### ❌ 2. Бизнес-логика в UI
```gdscript
# ПЛОХО (в UIManager)
func _on_button_pressed():
    var winner = BaccaratRules.get_winner(player_hand, banker_hand)
    if winner == "Player":
        show_player_win()

# ХОРОШО
func _on_button_pressed():
    button_pressed.emit()  # Просто эмитим событие
```

#### ❌ 3. Хардкод вместо конфигурации
```gdscript
# ПЛОХО
const COMMISSION_RATE = 0.95

# ХОРОШО
var commission_rate = GameConfig.commission_rate
```

#### ❌ 4. Глобальное состояние вместо параметров
```gdscript
# ПЛОХО
var current_winner: String  # глобальная переменная
func calculate_payout():
    return stake * get_multiplier(current_winner)

# ХОРОШО
func calculate_payout(winner: String, stake: float) -> float:
    return stake * get_multiplier(winner)
```

#### ❌ 5. Множественная ответственность
```gdscript
# ПЛОХО
class GameManager:
    func deal_cards(): pass
    func calculate_payout(): pass
    func save_settings(): pass
    func show_toast(): pass

# ХОРОШО - разбить на специализированные менеджеры
```

### 💡 Примеры успешных паттернов в проекте

#### ✅ 1. Event-Driven коммуникация
```gdscript
# В GamePhaseManager
EventBus.action_error.emit("player_wrong", error_msg)

# В StatsManager
func _ready():
    EventBus.action_error.connect(_on_error)

# Результат: слабая связанность, легко добавить новых слушателей
```

#### ✅ 2. Декларативная State Machine
```gdscript
# Состояние определяется из данных
var state = GameStateManager.determine_state(
    cards_hidden, player_hand, banker_hand, p3, b3
)

# А не из флагов:
# var is_dealing = true
# var is_third_card_phase = false  # ← антипаттерн
```

#### ✅ 3. Object Pooling
```gdscript
# ToastPool переиспользует узлы
var toast = toast_pool.get_toast()
toast.show_message("Успех!")
# После анимации → toast_pool.return_toast(toast)
```

#### ✅ 4. Чистые функции без состояния
```gdscript
# BaccaratRules - чистые static методы
static func hand_value(hand: Array[Card]) -> int:
    var total = 0
    for card in hand:
        total += card.get_point()
    return total % 10

# Легко тестировать, нет side effects
```

### 🚀 Советы для масштабирования проекта

1. **Если добавляешь новый режим игры** (например, Dragon Tiger):
   - Создай новый GameModeManager.GameMode enum
   - Расширь BaccaratRules или создай DragonTigerRules
   - Используй Strategy pattern через GameModeManager

2. **Если добавляешь новый тип ставки** (например, Lucky 6):
   - Расширь PayoutQueueManager.add_payout()
   - Добавь новый тип в PayoutValidator
   - Обнови Localization с новыми ключами

3. **Если добавляешь мультиплеер**:
   - Создай NetworkManager (autoload)
   - События через EventBus остаются локальными
   - Синхронизация состояния через GameDataManager

4. **Если добавляешь достижения/прогресс**:
   - Создай AchievementManager (подписан на EventBus)
   - Слушай события: action_correct, payout_correct, round_completed
   - Сохранение через SaveManager

### 📊 Метрики качества кода

Текущее состояние проекта (v5.9):
- ✅ **Модульность**: 9/10 (менеджеры хорошо разделены)
- ⚠️ **Связанность**: 7/10 (GamePhaseManager, UIManager - God Objects)
- ✅ **Тестируемость**: 8/10 (BaccaratRules легко тестируется)
- ✅ **Расширяемость**: 9/10 (EventBus позволяет легко добавлять фичи)
- ✅ **Читаемость**: 9/10 (хорошие комментарии, названия)
- ✅ **Производительность**: 8/10 (кэширование, pooling)

**Цели для будущего**:
- Разбить God Objects (UIManager → специализированные менеджеры)
- Ввести Dependency Injection для тестируемости
- Покрытие тестами 80%+ критичной логики
