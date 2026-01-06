# Граф зависимостей проекта Baccarat

> Визуальное представление зависимостей между модулями и классами

## 📊 Общая архитектура (высокий уровень)

```mermaid
graph TB
    GameController[GameController<br/>Главный координатор]
    
    subgraph "Игровой процесс"
        GamePhaseManager[GamePhaseManager]
        BaccaratRules[BaccaratRules]
        HandManager[HandManager]
        CardDealer[CardDealer]
    end
    
    subgraph "UI система"
        UIManager[UIManager]
        CardUIManager[CardUIManager]
        ButtonUIManager[ButtonUIManager]
        ToggleUIManager[ToggleUIManager]
    end
    
    subgraph "Система выплат"
        PayoutQueueManager[PayoutQueueManager]
        PayoutManager[PayoutManager]
        PayoutCalculator[PayoutCalculator]
        PayoutValidator[PayoutValidator]
    end
    
    subgraph "Система фишек"
        ChipVisualManager[ChipVisualManager]
        ChipStackManager[ChipStackManager]
    end
    
    subgraph "EventBus"
        EventBus[EventBus<br/>38+ сигналов]
    end
    
    subgraph "Утилиты (Phase 8-10)"
        PayoutReturnHandler[PayoutReturnHandler]
        PayoutPreparationHandler[PayoutPreparationHandler]
        UIEventHandler[UIEventHandler]
        InputHandler[InputHandler]
        CameraNavigationController[CameraNavigationController]
        ChipNavigationCoordinator[ChipNavigationCoordinator]
        CollectionModeHandler[CollectionModeHandler]
        KeyboardFocusHandler[KeyboardFocusHandler]
        GamepadMonitor[GamepadMonitor]
        RoundsCounterUpdater[RoundsCounterUpdater]
    end
    
    GameController --> GamePhaseManager
    GameController --> UIManager
    GameController --> PayoutQueueManager
    GameController --> ChipVisualManager
    GameController --> PayoutReturnHandler
    GameController --> PayoutPreparationHandler
    GameController --> UIEventHandler
    GameController --> InputHandler
    GameController --> CameraNavigationController
    
    GamePhaseManager --> BaccaratRules
    GamePhaseManager --> HandManager
    GamePhaseManager --> CardDealer
    GamePhaseManager --> EventBus
    
    UIManager --> CardUIManager
    UIManager --> ButtonUIManager
    UIManager --> ToggleUIManager
    
    PayoutQueueManager --> PayoutManager
    PayoutManager --> PayoutCalculator
    PayoutManager --> PayoutValidator
    
    PayoutValidator --> ChipStackManager
    
    GameController -.-> EventBus
    GamePhaseManager -.-> EventBus
    PayoutQueueManager -.-> EventBus
    ChipVisualManager -.-> EventBus
```

## 🔄 Поток данных в игровом процессе

```mermaid
sequenceDiagram
    participant User as Пользователь
    participant GC as GameController
    participant GPM as GamePhaseManager
    participant BR as BaccaratRules
    participant EB as EventBus
    participant UI as UIManager
    
    User->>GC: Нажал "Раздать"
    GC->>GPM: deal_cards()
    GPM->>BR: hand_value()
    BR-->>GPM: очки
    GPM->>EB: cards_dealt.emit()
    EB->>UI: обновить карты
    GPM-->>GC: результат
    GC->>EB: state_changed.emit()
```

## 🎯 Система выплат (детально)

```mermaid
graph LR
    subgraph "Инициация выплат"
        WinnerSelection[WinnerSelectionManager]
        PayoutQueue[PayoutQueueManager]
    end
    
    subgraph "Расчёт выплат"
        PayoutCalc[PayoutCalculator]
        GameMode[GameModeManager]
        BaccaratRules[BaccaratRules]
    end
    
    subgraph "Валидация"
        PayoutValidator[PayoutValidator]
        ChipStack[ChipStackManager]
    end
    
    subgraph "UI выплат"
        PayoutOverlay[PayoutOverlay]
        PayoutCoordinator[PayoutOverlayCoordinator]
    end
    
    WinnerSelection --> PayoutQueue
    PayoutQueue --> PayoutCalc
    PayoutCalc --> GameMode
    PayoutCalc --> BaccaratRules
    PayoutQueue --> PayoutValidator
    PayoutValidator --> ChipStack
    PayoutQueue --> PayoutCoordinator
    PayoutCoordinator --> PayoutOverlay
```

## 🎨 UI система (Phase 2 рефакторинг)

```mermaid
graph TB
    UIManager[UIManager<br/>Фасад]
    
    CardUI[CardUIManager<br/>Карты]
    ToggleUI[ToggleUIManager<br/>Toggles]
    ButtonUI[ButtonUIManager<br/>Кнопки]
    MarkerUI[MarkerUIManager<br/>Маркеры]
    PayoutToggleUI[PayoutToggleManager<br/>Переключатели выплат]
    
    UIManager --> CardUI
    UIManager --> ToggleUI
    UIManager --> ButtonUI
    UIManager --> MarkerUI
    UIManager --> PayoutToggleUI
    
    CardUI -.-> EventBus
    ToggleUI -.-> EventBus
    ButtonUI -.-> EventBus
```

## 👥 Система гостей

```mermaid
graph TB
    subgraph "Генерация ставок"
        GuestFactory[GuestBetFactory]
        GuestStorage[GuestBetStorage]
        SectorMapper[GuestSectorMapper]
    end
    
    subgraph "Управление"
        GuestSettings[GuestSettingsManager<br/>autoload]
        GuestStats[GuestStatsManager<br/>autoload]
        PatienceTimer[PatienceTimerManager<br/>autoload]
    end
    
    subgraph "UI"
        GuestMenu[GuestMenuScene]
        GuestEventHandler[GuestEventHandler]
        GuestUIRenderer[GuestMenuUIRenderer]
    end
    
    GuestFactory --> GuestStorage
    GuestFactory --> SectorMapper
    GuestFactory --> GuestSettings
    GuestStorage --> GuestStats
    GuestEventHandler --> GuestUIRenderer
    GuestEventHandler --> GuestMenu
    PatienceTimer --> GuestEventHandler
```

## 🎲 Карты шанса

```mermaid
graph TB
    ChanceCardManager[ChanceCardManager<br/>autoload]
    
    subgraph "Хранилище"
        ChanceStorage[ChanceCardStorage]
        BaseCard[BaseChanceCard]
    end
    
    subgraph "Реализации"
        HeartCard[HeartCardChanceCard]
        HeartBetCard[HeartBetChanceCard]
        ThirdCardChange[ThirdCardChangeChanceCard]
        RevolverCard[RevolverCardChanceCard]
        MysteryCard[MysteryCardChanceCard]
    end
    
    subgraph "Анимации"
        BaseAnimator[BaseCardAnimator]
        ScaleAnimator[ScaleFromStorageAnimator]
        FadeAnimator[FadeAnimator]
    end
    
    ChanceCardManager --> ChanceStorage
    ChanceStorage --> BaseCard
    BaseCard --> HeartCard
    BaseCard --> HeartBetCard
    BaseCard --> ThirdCardChange
    BaseCard --> RevolverCard
    BaseCard --> MysteryCard
    
    HeartCard --> BaseAnimator
    ScaleAnimator --> BaseAnimator
    FadeAnimator --> BaseAnimator
```

## 📷 Камера и навигация

```mermaid
graph TB
    subgraph "Камера"
        CameraManager[CameraManager]
        CameraConfig[CameraConfig]
        CameraInterpolation[CameraInterpolationNode]
    end
    
    subgraph "Навигация"
        KeyboardNav[KeyboardNavigationController<br/>autoload]
        KeyboardFocus[KeyboardFocusController<br/>autoload]
        SwipeNav[SwipeNavigationController<br/>autoload]
        ChipNav[ChipNavigationManager]
    end
    
    subgraph "Ввод"
        InputContext[InputContextManager<br/>autoload]
    end
    
    CameraManager --> CameraConfig
    CameraManager --> CameraInterpolation
    KeyboardNav --> CameraManager
    SwipeNav --> CameraManager
    ChipNav --> CameraManager
    KeyboardNav --> InputContext
    KeyboardFocus --> InputContext
```

## 💎 Система фишек

```mermaid
graph TB
    ChipVisualManager[ChipVisualManager]
    
    subgraph "Модели"
        ChipStack[ChipStack]
        ChipStackManager[ChipStackManager]
    end
    
    subgraph "Обработка"
        ChipClickHandler[ChipClickHandler]
        ChipRestoration[ChipRestorationCoordinator]
    end
    
    subgraph "Навигация"
        ChipNavigation[ChipNavigationManager]
        ChipNavigationFrame[ChipNavigationFrame]
    end
    
    ChipVisualManager --> ChipStackManager
    ChipStackManager --> ChipStack
    ChipClickHandler --> ChipVisualManager
    ChipRestoration --> ChipStackManager
    ChipNavigation --> ChipVisualManager
    ChipNavigation --> ChipNavigationFrame
```

## 🎯 Система ставок

```mermaid
graph TB
    subgraph "Типы ставок"
        IBetType[IBetType<br/>Интерфейс]
        MainBet[MainBetType]
        TieBet[TieBetType]
        PairBet[PairBetType]
        BetTypeFactory[BetTypeFactory]
    end
    
    subgraph "Менеджеры"
        BetCollection[BetCollectionPhaseManager]
        PairBetting[PairBettingManager]
        BetFilter[BetFilterManager]
    end
    
    subgraph "Валидация"
        IBetValidator[IBetCollectionValidator]
        DefaultValidator[DefaultBetCollectionValidator]
    end
    
    MainBet --> IBetType
    TieBet --> IBetType
    PairBet --> IBetType
    BetTypeFactory --> IBetType
    
    BetCollection --> BetTypeFactory
    BetCollection --> DefaultValidator
    DefaultValidator --> IBetValidator
    PairBetting --> PairBet
```

## 🔗 Autoload синглтоны (23 штуки)

```mermaid
graph TB
    subgraph "Ядро"
        EventBus[EventBus<br/>38+ сигналов]
        GameStateManager[GameStateManager]
        GameModeManager[GameModeManager]
    end
    
    subgraph "Инфраструктура"
        SaveManager[SaveManager]
        Localization[Localization]
        StatsManager[StatsManager]
    end
    
    subgraph "UI инфраструктура"
        ToastManager[ToastManager]
        OverlayNotificationManager[OverlayNotificationManager]
        FeedbackAnimationManager[FeedbackAnimationManager]
    end
    
    subgraph "Гости"
        GuestSettingsManager[GuestSettingsManager]
        GuestStatsManager[GuestStatsManager]
        GuestReturnManager[GuestReturnManager]
        PatienceTimerManager[PatienceTimerManager]
    end
    
    subgraph "Настройки"
        PayoutSettingsManager[PayoutSettingsManager]
        BetProfileManager[BetProfileManager]
        TableStateManager[TableStateManager]
    end
    
    subgraph "Навигация"
        KeyboardNavigationController[KeyboardNavigationController]
        KeyboardFocusController[KeyboardFocusController]
        SwipeNavigationController[SwipeNavigationController]
        InputContextManager[InputContextManager]
    end
    
    subgraph "Специальные"
        ChanceCardManager[ChanceCardManager]
        GameDataManager[GameDataManager]
        PayoutContextManager[PayoutContextManager]
        TestCardsManager[TestCardsManager]
    end
    
    EventBus -.-> GameStateManager
    EventBus -.-> ToastManager
    EventBus -.-> OverlayNotificationManager
```

## ⚠️ Критические зависимости

### EventBus - центральная точка связи

```mermaid
graph LR
    EventBus[EventBus<br/>Центральная шина]
    
    GameController[GameController]
    GamePhaseManager[GamePhaseManager]
    PayoutQueueManager[PayoutQueueManager]
    ChipVisualManager[ChipVisualManager]
    UIManager[UIManager]
    CameraManager[CameraManager]
    
    EventBus --> GameController
    EventBus --> GamePhaseManager
    EventBus --> PayoutQueueManager
    EventBus --> ChipVisualManager
    EventBus --> UIManager
    EventBus --> CameraManager
```

**Важно**: Все менеджеры общаются через EventBus, НЕ напрямую!

## 🔄 Циклы зависимостей (избегать!)

```mermaid
graph LR
    A[Класс A] --> B[Класс B]
    B --> C[Класс C]
    C --> A
    
    style A fill:#ff6b6b
    style B fill:#ff6b6b
    style C fill:#ff6b6b
```

**Решение**: Использовать EventBus для разрыва циклов

## 📈 Метрики зависимостей

| Класс | Количество зависимостей | Уровень сложности |
|-------|------------------------|-------------------|
| GameController | 20+ | 🔴 Высокий |
| GamePhaseManager | 10+ | 🟡 Средний |
| UIManager | 5 | 🟢 Низкий |
| BaccaratRules | 0 | 🟢 Низкий |

## 💡 Рекомендации

1. **Избегайте прямых зависимостей** - используйте EventBus
2. **Следуйте Dependency Inversion Principle** - зависеть от абстракций
3. **Разрывайте циклы** через EventBus или интерфейсы
4. **Минимизируйте зависимости** - чем меньше, тем лучше

---

**Примечание**: Этот граф создан на основе анализа кода. При изменении архитектуры обновите его вручную.

