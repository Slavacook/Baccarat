# Индекс классов проекта Baccarat

> Структурированный справочник всех классов для быстрого поиска и понимания архитектуры

**Всего классов**: ~170 GDScript файлов  
**Последнее обновление**: Автоматически генерируется

---

## 📋 Содержание

1. [🎮 Игровой процесс](#-игровой-процесс)
2. [💰 Система выплат](#-система-выплат)
3. [🎨 UI система](#-ui-система)
4. [🃏 Система карт](#-система-карт)
5. [👥 Система гостей](#-система-гостей)
6. [🎯 Система ставок](#-система-ставок)
7. [📷 Камера и навигация](#-камера-и-навигация)
8. [🎲 Карты шанса](#-карты-шанса)
9. [❤️ Heart Bet](#️-heart-bet)
10. [💾 Инфраструктура](#-инфраструктура)
11. [🔧 Утилиты](#-утилиты)
12. [🧪 Тесты](#-тесты)

---

## 🎮 Игровой процесс

### Главные координаторы

| Класс | Файл | Строк | Ответственность | Зависимости |
|-------|------|-------|-----------------|-------------|
| **GameController** | `scripts/GameController.gd` | 1603 | Главный оркестратор всех систем | Все менеджеры |
| **GamePhaseManager** | `scripts/GamePhaseManager.gd` | 604 | Управление фазами игры, валидация | Deck, BaccaratRules, EventBus |
| **GameInitializer** | `scripts/GameInitializer.gd` | ~200 | Инициализация GameController | GameController |
| **GameStateUpdater** | `scripts/GameStateUpdater.gd` | ? | Обновление состояния игры | GameStateManager |
| **GameStateResetCoordinator** | `scripts/GameStateResetCoordinator.gd` | ? | Сброс состояния для нового раунда | EventBus |

### Правила игры

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **BaccaratRules** | `scripts/BaccaratRules.gd` | Статические методы правил баккара |
| **HandManager** | `scripts/HandManager.gd` | Управление руками игрока и банкира |
| **CardDealer** | `scripts/CardDealer.gd` | Логика раздачи карт |

### Координаторы действий

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **FirstFourDealCoordinator** | `scripts/FirstFourDealCoordinator.gd` | Координация раздачи первых 4 карт |
| **ThirdCardDrawingCoordinator** | `scripts/ThirdCardDrawingCoordinator.gd` | Координация раздачи третьей карты |
| **ThirdCardRemovalCoordinator** | `scripts/ThirdCardRemovalCoordinator.gd` | Удаление третьей карты |
| **ThirdCardActionExecutor** | `scripts/ThirdCardActionExecutor.gd` | Выполнение действий с третьей картой |
| **ThirdCardActionValidator** | `scripts/ThirdCardActionValidator.gd` | Валидация действий с третьей картой |
| **ThirdCardUIHandler** | `scripts/ThirdCardUIHandler.gd` | Обработка UI третьей карты |
| **BankerAfterPlayerHandler** | `scripts/BankerAfterPlayerHandler.gd` | Обработка третьей карты банкира после игрока |
| **WinnerSelectionCoordinator** | `scripts/WinnerSelectionCoordinator.gd` | Координация выбора победителя |
| **WinnerSelectionManager** | `scripts/WinnerSelectionManager.gd` | Управление выбором победителя |
| **WinnerSelectionValidator** | `scripts/WinnerSelectionValidator.gd` | Валидация выбора победителя |
| **WinnerSelectionStateHandler** | `scripts/WinnerSelectionStateHandler.gd` | Обработка состояния выбора |
| **WinnerActionExecutor** | `scripts/WinnerActionExecutor.gd` | Выполнение действий после выбора победителя |
| **GameCompletionCoordinator** | `scripts/GameCompletionCoordinator.gd` | Координация завершения игры |
| **RoundCompletionCoordinator** | `scripts/RoundCompletionCoordinator.gd` | Координация завершения раунда |
| **PhaseActionResolver** | `scripts/PhaseActionResolver.gd` | Разрешение действий в фазах |

---

## 💰 Система выплат

### Менеджеры выплат

| Класс | Файл | Ответственность | Зависимости |
|-------|------|-----------------|-------------|
| **PayoutQueueManager** | `scripts/PayoutQueueManager.gd` | Очередь выплат (Main/Pair) | EventBus, PayoutSettingsManager |
| **PayoutManager** | `scripts/payout/PayoutManager.gd` | Главный менеджер выплат | PayoutQueueManager |
| **PayoutQueueHandler** | `scripts/payout/PayoutQueueHandler.gd` | Обработчик очереди выплат | PayoutQueueManager |
| **PayoutOverlayCoordinator** | `scripts/payout/PayoutOverlayCoordinator.gd` | Координация overlay выплат | PayoutOverlay |
| **PayoutCalculator** | `scripts/payout/PayoutCalculator.gd` | Расчёт выплат | BaccaratRules, GameModeManager |
| **PayoutValidator** | `scripts/chip_system/PayoutValidator.gd` | Валидация выплат фишками | ChipStackManager |
| **PayoutHintHandler** | `scripts/payout/PayoutHintHandler.gd` | Подсказки для выплат | PayoutCalculator |
| **PayoutResultHandler** | `scripts/utils/PayoutResultHandler.gd` | Обработка результатов выплат | EventBus |

### UI выплат

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **PayoutOverlay** | `scripts/PayoutOverlay.gd` | Overlay для выплат |
| **PayoutOverlayUIBuilder** | `scripts/ui/PayoutOverlayUIBuilder.gd` | Построение UI выплат |
| **PayoutOverlayStateManager** | `scripts/ui/PayoutOverlayStateManager.gd` | Управление состоянием overlay |
| **PayoutOverlayPaymentHandler** | `scripts/ui/PayoutOverlayPaymentHandler.gd` | Обработка платежей в overlay |
| **PayoutOverlayStyleManager** | `scripts/ui/PayoutOverlayStyleManager.gd` | Стилизация overlay |
| **PayoutKeyboardNavigator** | `scripts/ui/PayoutKeyboardNavigator.gd` | Навигация по клавиатуре |
| **PayoutAnimationController** | `scripts/ui/PayoutAnimationController.gd` | Анимации выплат |
| **PayoutSurvivalInfo** | `scripts/PayoutSurvivalInfo.gd` | Информация о выживании в выплатах |

### Провайдеры и контекст

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **PayoutContextManager** | `scripts/PayoutContextManager.gd` | Контекст выплат (autoload) |
| **PayoutSettingsManager** | `scripts/autoload/PayoutSettingsManager.gd` | Настройки выплат (autoload) |
| **PayoutSettingsProvider** | `scripts/providers/PayoutSettingsProvider.gd` | Провайдер настроек |

---

## 🎨 UI система

### Главный менеджер UI

| Класс | Файл | Строк | Ответственность |
|-------|------|-------|-----------------|
| **UIManager** | `scripts/UIManager.gd` | ~287 | Фасад-агрегатор для всех UI элементов |

### Специализированные UI менеджеры (Phase 2)

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **CardUIManager** | `scripts/ui/CardUIManager.gd` | Управление картами и анимациями |
| **ToggleUIManager** | `scripts/ui/ToggleUIManager.gd` | Управление toggles третьих карт |
| **ButtonUIManager** | `scripts/ui/ButtonUIManager.gd` | Управление кнопками |
| **MarkerUIManager** | `scripts/ui/MarkerUIManager.gd` | Управление маркерами победителя |
| **PayoutToggleManager** | `scripts/ui/PayoutToggleManager.gd` | Управление переключателями выплат |

### Обработчики UI событий

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **WinnerSelectionHandler** | `scripts/ui/WinnerSelectionHandler.gd` | Обработка выбора победителя |
| **SettingsEventHandler** | `scripts/ui/SettingsEventHandler.gd` | Обработка событий настроек |
| **GuestEventHandler** | `scripts/ui/GuestEventHandler.gd` | Обработка событий гостей |
| **FeedbackAnimationManager** | `scripts/ui/FeedbackAnimationManager.gd` | Анимации обратной связи |
| **FocusFrameUI** | `scripts/ui/FocusFrameUI.gd` | Фрейм фокуса для навигации |

### Сцены и попапы

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **SettingsScene** | `scripts/SettingsScene.gd` | Сцена настроек |
| **GameOverScene** | `scripts/GameOverScene.gd` | Сцена окончания игры |
| **GuestMenuScene** | `scripts/GuestMenuScene.gd` | Меню гостей |
| **BetPopup** | `scripts/BetPopup.gd` | Попап ставок |
| **ChanceCardPopup** | `scripts/ChanceCardPopup.gd` | Попап карт шанса |
| **HelpPopup** | `scripts/HelpPopup.gd` | Попап помощи |
| **CribSheetScene** | `scripts/ui/CribSheetScene.gd` | Шпаргалка |

### UI компоненты гостей

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **GuestMenuUIRenderer** | `scripts/ui/GuestMenuUIRenderer.gd` | Рендеринг UI меню гостей |
| **GuestMenuTextUpdater** | `scripts/ui/GuestMenuTextUpdater.gd` | Обновление текста меню |
| **GuestMenuBalanceRenderer** | `scripts/ui/GuestMenuBalanceRenderer.gd` | Рендеринг балансов |
| **GuestMenuKeyboardNavigator** | `scripts/ui/GuestMenuKeyboardNavigator.gd` | Навигация по клавиатуре |
| **GuestBalanceIndicatorManager** | `scripts/ui/GuestBalanceIndicatorManager.gd` | Индикаторы балансов |
| **GuestPatienceIndicatorManager** | `scripts/ui/GuestPatienceIndicatorManager.gd` | Индикаторы терпения |
| **GuestPatienceIndicator** | `scripts/ui/GuestPatienceIndicator.gd` | Индикатор терпения |
| **GuestUIVisualState** | `scripts/ui/GuestUIVisualState.gd` | Визуальное состояние |
| **GuestMenuState** | `scripts/ui/GuestMenuState.gd` | Состояние меню |

---

## 🃏 Система карт

### Модели и менеджеры

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **Card** | `scripts/Card.gd` | Модель карты |
| **Deck** | `scripts/Deck.gd` | Колода карт (8 колод × 52 = 416 карт) |
| **CardTextureManager** | `scripts/CardTextureManager.gd` | Загрузка текстур карт |
| **CardController** | `scripts/utils/CardController.gd` | Контроллер управления картами |
| **FlipCard** | `scripts/FlipCard.gd` | Анимация переворота карты |

---

## 👥 Система гостей

### Фабрики и хранилища

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **GuestBetFactory** | `scripts/GuestBetFactory.gd` | Фабрика генерации ставок гостей |
| **GuestBetStorage** | `scripts/GuestBetStorage.gd` | Хранилище ставок гостей |
| **GuestSectorMapper** | `scripts/GuestSectorMapper.gd` | Маппинг секторов на позиции |

### Координаторы и обработчики

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **GuestBetDisplayCoordinator** | `scripts/GuestBetDisplayCoordinator.gd` | Координация отображения ставок |
| **GuestEventHandler** | `scripts/ui/GuestEventHandler.gd` | Обработка событий гостей |

### Autoload менеджеры

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **GuestSettingsManager** | `scripts/autoload/GuestSettingsManager.gd` | Настройки гостей |
| **GuestStatsManager** | `scripts/autoload/GuestStatsManager.gd` | Статистика гостей |
| **GuestReturnManager** | `scripts/autoload/GuestReturnManager.gd` | Возврат гостей |
| **PatienceTimerManager** | `scripts/autoload/PatienceTimerManager.gd` | Таймеры терпения |

---

## 🎯 Система ставок

### Менеджеры ставок

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **BetCollectionPhaseManager** | `scripts/BetCollectionPhaseManager.gd` | Управление фазой сбора ставок |
| **PairBettingManager** | `scripts/PairBettingManager.gd` | Управление ставками на пары |
| **BetFilterManager** | `scripts/BetFilterManager.gd` | Фильтрация ставок |
| **BetProfileManager** | `scripts/autoload/BetProfileManager.gd` | Профили ставок (autoload) |

### Типы ставок (Strategy pattern)

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **IBetType** | `scripts/interfaces/IBetType.gd` | Интерфейс типа ставки |
| **MainBetType** | `scripts/bet_types/MainBetType.gd` | Основная ставка |
| **TieBetType** | `scripts/bet_types/TieBetType.gd` | Ставка на ничью |
| **PairBetType** | `scripts/bet_types/PairBetType.gd` | Ставка на пару |
| **BetTypeFactory** | `scripts/bet_types/BetTypeFactory.gd` | Фабрика типов ставок |

### Валидаторы

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **DefaultBetCollectionValidator** | `scripts/validators/DefaultBetCollectionValidator.gd` | Валидатор сбора ставок |
| **IBetCollectionValidator** | `scripts/interfaces/IBetCollectionValidator.gd` | Интерфейс валидатора |

---

## 💎 Система фишек

### Менеджеры фишек

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **ChipVisualManager** | `scripts/ChipVisualManager.gd` | Визуализация фишек на столе |
| **ChipStackManager** | `scripts/chip_system/ChipStackManager.gd` | Управление стеками фишек |
| **ChipStack** | `scripts/chip_system/ChipStack.gd` | Модель стека фишек |
| **ChipClickHandler** | `scripts/utils/ChipClickHandler.gd` | Обработка кликов на фишки |
| **ChipRestorationCoordinator** | `scripts/ChipRestorationCoordinator.gd` | Восстановление фишек |
| **ChipNavigationManager** | `scripts/ui/ChipNavigationManager.gd` | Навигация по фишкам |
| **ChipNavigationFrame** | `scripts/ui/ChipNavigationFrame.gd` | Фрейм навигации |

---

## 📷 Камера и навигация

### Камера

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **CameraManager** | `scripts/CameraManager.gd` | Управление камерой (зум, переходы) |
| **CameraInterpolationNode** | `scripts/CameraInterpolationNode.gd` | Интерполяция камеры |
| **CameraConfig** | `resources/CameraConfig.gd` | Конфигурация камеры |

### Навигация

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **KeyboardNavigationController** | `scripts/KeyboardNavigationController.gd` | Навигация по клавиатуре (autoload) |
| **KeyboardFocusController** | `scripts/KeyboardFocusController.gd` | Контроллер фокуса (autoload) |
| **SwipeNavigationController** | `scripts/SwipeNavigationController.gd` | Навигация свайпами (autoload) |
| **InputContextManager** | `scripts/autoload/InputContextManager.gd` | Контекст ввода (autoload) |

### UI навигации

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **AreaButton** | `scripts/ui/AreaButton.gd` | Кнопка области для навигации |

---

## 🎲 Карты шанса

### Менеджеры и хранилища

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **ChanceCardManager** | `scripts/chance_cards/ChanceCardManager.gd` | Менеджер карт шанса (autoload) |
| **ChanceCardStorage** | `scripts/chance_cards/ChanceCardStorage.gd` | Хранилище карт |
| **ChanceCardNavigator** | `scripts/chance_cards/ChanceCardNavigator.gd` | Навигатор карт |
| **ChanceCardTriggerChecker** | `scripts/ChanceCardTriggerChecker.gd` | Проверка триггеров |

### Базовые классы

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **BaseChanceCard** | `scripts/chance_cards/BaseChanceCard.gd` | Базовый класс карты шанса |
| **BaseChanceCardScene** | `scripts/chance_cards/BaseChanceCardScene.gd` | Базовая сцена карты |
| **BaseCardAnimator** | `scripts/chance_cards/animators/BaseCardAnimator.gd` | Базовый аниматор |

### Реализации карт

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **HeartCardChanceCard** | `scripts/chance_cards/implementations/HeartCardChanceCard.gd` | Карта сердца |
| **HeartBetChanceCard** | `scripts/chance_cards/implementations/HeartBetChanceCard.gd` | Карта ставки сердцем |
| **ThirdCardChangeChanceCard** | `scripts/chance_cards/implementations/ThirdCardChangeChanceCard.gd` | Изменение третьей карты |
| **RevolverCardChanceCard** | `scripts/chance_cards/implementations/RevolverCardChanceCard.gd` | Карта револьвера |
| **MysteryCardChanceCard** | `scripts/chance_cards/implementations/MysteryCardChanceCard.gd` | Мистическая карта |

### Аниматоры

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **ScaleFromStorageAnimator** | `scripts/chance_cards/animators/ScaleFromStorageAnimator.gd` | Анимация из хранилища |
| **ScaleFromZeroAnimator** | `scripts/chance_cards/animators/ScaleFromZeroAnimator.gd` | Анимация с нуля |
| **FadeAnimator** | `scripts/chance_cards/animators/FadeAnimator.gd` | Анимация затухания |

### UI карт

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **ChanceCardUI** | `scripts/ChanceCardUI.gd` | UI карты шанса |
| **ChanceCardPopup** | `scripts/ChanceCardPopup.gd` | Попап карты |

---

## ❤️ Heart Bet

### Менеджеры и координаторы

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **HeartBetManager** | `scripts/heart_bet/HeartBetManager.gd` | Менеджер ставки сердцем |
| **HeartBetCoordinator** | `scripts/HeartBetCoordinator.gd` | Координатор ставки |
| **HeartBetController** | `scripts/ui/HeartBetController.gd` | Контроллер UI |
| **HeartBetTriggerSystem** | `scripts/heart_bet/HeartBetTriggerSystem.gd` | Система триггеров |
| **HeartBetUI** | `scenes/heart_bet/HeartBetUI.tscn` | UI ставки |

### Триггеры

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **BaseTrigger** | `scripts/heart_bet/triggers/BaseTrigger.gd` | Базовый триггер |
| **NaturalWinTrigger** | `scripts/heart_bet/triggers/NaturalWinTrigger.gd` | Триггер натуральной победы |
| **BankerSixTrigger** | `scripts/heart_bet/triggers/BankerSixTrigger.gd` | Триггер банкира 6 |

---

## 💚 Система здоровья

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **HeartBar** | `scripts/health_system/HeartBar.gd` | Панель жизней |
| **Heart** | `scripts/health_system/Heart.gd` | Модель сердца |
| **HeartState** | `scripts/health_system/HeartState.gd` | Состояние сердца |
| **IHeartVisual** | `scripts/health_system/IHeartVisual.gd` | Интерфейс визуализации |
| **LabelHeartVisual** | `scripts/health_system/implementations/LabelHeartVisual.gd` | Визуализация через Label |
| **TextureRectHeartVisual** | `scripts/health_system/implementations/TextureRectHeartVisual.gd` | Визуализация через TextureRect |
| **SurvivalModeUI** | `scripts/SurvivalModeUI.gd` | UI режима выживания |
| **SurvivalStateProvider** | `scripts/utils/SurvivalStateProvider.gd` | Провайдер состояния выживания |

---

## 💾 Инфраструктура

### Autoload синглтоны (23 штуки)

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **EventBus** | `scripts/autoload/EventBus.gd` | Централизованная шина событий (38+ сигналов) |
| **GameStateManager** | `scripts/autoload/GameStateManager.gd` | Управление состояниями игры |
| **GameModeManager** | `scripts/GameModeManager.gd` | Управление режимами игры |
| **Localization** | `scripts/Localization.gd` | Локализация (ru/en) |
| **SaveManager** | `scripts/SaveManager.gd` | Сохранение/загрузка |
| **StatsManager** | `scripts/StatsManager.gd` | Статистика |
| **ToastManager** | `scripts/ToastManager.gd` | Управление тостами |
| **ToastPool** | `scripts/ToastPool.gd` | Пул тостов (object pooling) |
| **OverlayNotificationManager** | `scripts/OverlayNotificationManager.gd` | Управление overlay уведомлениями |
| **GameDataManager** | `scripts/GameDataManager.gd` | Данные игры |
| **TableStateManager** | `scripts/autoload/TableStateManager.gd` | Состояние стола |
| **TestCardsManager** | `scripts/autoload/TestCardsManager.gd` | Тестовые карты |

### Конфигурация

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **GameConfig** | `resources/GameConfig.gd` | Конфигурация игры |
| **CameraConfig** | `resources/CameraConfig.gd` | Конфигурация камеры |
| **GameConstants** | `scripts/GameConstants.gd` | Константы игры |

### Менеджеры лимитов

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **LimitsManager** | `scripts/LimitsManager.gd` | Управление лимитами стола |

---

## 🔧 Утилиты

### Обработчики GameController (Phase 8-9)

| Класс | Файл | Строк | Ответственность | Зависимости |
|-------|------|-------|-----------------|-------------|
| **PayoutReturnHandler** | `scripts/utils/PayoutReturnHandler.gd` | ~377 | Обработка возврата из PayoutScene | StateRestorer, PayoutOverlayCoordinator |
| **PayoutPreparationHandler** | `scripts/utils/PayoutPreparationHandler.gd` | ~150 | Подготовка и расчет выплат | HandManager, LimitsManager |
| **UIEventHandler** | `scripts/utils/UIEventHandler.gd` | ~250 | Обработка UI событий | UIManager, PhaseManager |
| **InputHandler** | `scripts/utils/InputHandler.gd` | ~200 | Обработка ввода (клавиатура/геймпад) | ChipNavigationManager, ChanceCardNavigator |
| **CameraNavigationController** | `scripts/utils/CameraNavigationController.gd` | ~285 | Навигация камеры и стрелки | CameraManager, UIManager |
| **ChipNavigationCoordinator** | `scripts/utils/ChipNavigationCoordinator.gd` | ~112 | Координация навигации по ставкам | ChipNavigationManager, BetCollectionPhaseManager |
| **CollectionModeHandler** | `scripts/utils/CollectionModeHandler.gd` | ~79 | Режимы сбора/оплаты ставок | BetCollectionPhaseManager, UIManager |
| **KeyboardFocusHandler** | `scripts/utils/KeyboardFocusHandler.gd` | ~85 | Клавиатурный фокус | GamePhaseManager, WinnerSelectionManager |
| **GamepadMonitor** | `scripts/utils/GamepadMonitor.gd` | ~60 | Мониторинг геймпадов | Input |
| **RoundsCounterUpdater** | `scripts/utils/RoundsCounterUpdater.gd` | ~50 | Обновление счетчика раундов | Label |

### Обработчики GameController (Phase 1-3)

| Класс | Файл | Ответственность | Зависимости |
|-------|------|-----------------|-------------|
| **CardController** | `scripts/utils/CardController.gd` | Управление отображением карт | FlipCard nodes |
| **SurvivalStateProvider** | `scripts/utils/SurvivalStateProvider.gd` | Провайдер состояния выживания | SurvivalModeUI |
| **GameStateController** | `scripts/utils/GameStateController.gd` | Управление состоянием игры | GameOverPopup, EventBus |
| **PayoutResultHandler** | `scripts/utils/PayoutResultHandler.gd` | Обработка результатов выплат | EventBus |
| **ChipClickHandler** | `scripts/utils/ChipClickHandler.gd` | Обработка кликов на фишки | ChipVisualManager, BetCollectionPhaseManager |
| **SettingsEventHandler** | `scripts/ui/SettingsEventHandler.gd` | Обработка событий настроек | SettingsScene, EventBus |

### Утилиты для BetCollectionPhaseManager (Phase 6)

| Класс | Файл | Ответственность | Зависимости |
|-------|------|-----------------|-------------|
| **LinePositionCalculator** | `scripts/utils/LinePositionCalculator.gd` | Расчет позиций фишек на линиях | - |
| **BetSorter** | `scripts/utils/BetSorter.gd` | Сортировка ставок | LinePositionCalculator |
| **SequenceManager** | `scripts/utils/SequenceManager.gd` | Управление последовательностями сбора/оплаты | BetSorter, LinePositionCalculator |
| **StateConsistencyChecker** | `scripts/utils/StateConsistencyChecker.gd` | Проверка согласованности состояния | PayoutQueueManager |

### Утилиты для ChipVisualManager (Phase 6)

| Класс | Файл | Ответственность | Зависимости |
|-------|------|-----------------|-------------|
| **ChipTextureManager** | `scripts/utils/ChipTextureManager.gd` | Управление текстурами фишек | - |
| **ChipPositionManager** | `scripts/utils/ChipPositionManager.gd` | Управление позициями фишек | - |
| **StakeLabelManager** | `scripts/utils/StakeLabelManager.gd` | Управление метками ставок | ChipVisualManager.ChipInstance |
| **RealisticChipGenerator** | `scripts/utils/RealisticChipGenerator.gd` | Генерация реалистичных фишек | ChipPositionManager |

### Утилиты для SettingsScene (Phase 7)

| Класс | Файл | Ответственность | Зависимости |
|-------|------|-----------------|-------------|
| **SettingsKeyboardNavigator** | `scripts/ui/SettingsKeyboardNavigator.gd` | Навигация по настройкам (клавиатура/геймпад) | SettingsScene |

### Форматтеры

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **ValidationErrorFormatter** | `scripts/ValidationErrorFormatter.gd` | Форматирование ошибок валидации |
| **VictoryMessageFormatter** | `scripts/VictoryMessageFormatter.gd` | Форматирование сообщений победы |

### Исполнители

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **TablePreparationExecutor** | `scripts/TablePreparationExecutor.gd` | Подготовка стола |
| **TieButtonHandler** | `scripts/TieButtonHandler.gd` | Обработка кнопки ничьей |

### Калькуляторы

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **TipCalculator** | `scripts/TipCalculator.gd` | Калькулятор чаевых |

### Логирование

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **DebugLogger** | `scripts/DebugLogger.gd` | Логирование отладки |

### Типы обратной связи

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **FeedbackTypes** | `scripts/ui/FeedbackTypes.gd` | Типы обратной связи |

---

## 🧪 Тесты

| Класс | Файл | Ответственность |
|-------|------|-----------------|
| **CardDealer.test** | `scripts/CardDealer.test.gd` | Тесты раздачи карт |

---

## 📊 Статистика

- **Всего классов**: ~190
- **Autoload синглтонов**: 23
- **UI менеджеров**: 5 (Phase 2)
- **Координаторов**: 15+
- **Валидаторов**: 5+
- **Интерфейсов**: 3+
- **Утилит (utils)**: 23 (Phase 1-9)
  - Обработчики GameController: 10 классов
  - Утилиты для BetCollectionPhaseManager: 4 класса
  - Утилиты для ChipVisualManager: 4 класса
  - Утилиты для SettingsScene: 1 класс
  - Другие утилиты: 4 класса

---

## 🔍 Как использовать этот индекс

1. **Поиск класса**: Ctrl+F по названию класса
2. **Поиск по ответственности**: ищите по ключевым словам (например, "выплаты", "карты")
3. **Поиск зависимостей**: смотрите колонку "Зависимости"
4. **Понимание архитектуры**: читайте секции по модулям

---

**Примечание**: Этот индекс создан автоматически. При изменении структуры проекта обновите его вручную.

