# План рефакторинга ФАЗА 8: Дальнейшее уменьшение GameController

**Цель**: Уменьшить `GameController` с 2196 строк до < 1500 строк  
**Текущий размер**: 2196 строк  
**Целевой размер**: < 1500 строк  
**Нужно убрать**: ~700 строк

---

## 📊 Анализ текущего состояния

### Уже извлечено ✅
- `GameInitializer` - инициализация (~200 строк)
- `PayoutManager` - подготовка выплат
- `StateRestorer` - восстановление состояния
- `CardController` - управление картами
- `PayoutResultHandler` - обработка результатов выплат
- `ChipClickHandler` - обработка кликов на фишки
- `GameStateController` - управление состоянием игры
- `SettingsEventHandler` - обработка событий настроек
- `GuestEventHandler` - обработка событий гостей
- `HeartBetController` - логика Heart Bet
- `WinnerSelectionHandler` - обработка выбора победителя
- `PayoutQueueHandler` - обработка очереди выплат
- `PayoutOverlayCoordinator` - координация PayoutOverlay

---

## 🎯 Кандидаты для извлечения

### 1. CameraNavigationController (~200 строк) 🔴 Высокий приоритет

**Методы для извлечения:**
- `camera_zoom_in()` - увеличение масштаба камеры
- `camera_zoom_out()` - уменьшение масштаба камеры
- `camera_zoom_cards()` - масштабирование на карты
- `camera_zoom_area(area_index)` - масштабирование на область
- `_on_left_arrow_pressed()` - обработка стрелки влево
- `_on_right_arrow_pressed()` - обработка стрелки вправо
- `_on_up_arrow_pressed()` - обработка стрелки вверх
- `_on_down_arrow_pressed()` - обработка стрелки вниз
- `_request_camera_target_area(direction)` - запрос области камеры
- `_on_arrows_visibility_changed(should_show)` - изменение видимости стрелок
- `_update_arrows_state(target_area)` - обновление состояния стрелок
- `_update_arrows_for_area(current_area)` - обновление стрелок для области
- `_apply_arrows_state(...)` - применение состояния стрелок
- `_on_camera_zoom_completed(zoom_type)` - завершение масштабирования
- `_on_camera_zoom_requested(zoom_type, is_navigation)` - запрос масштабирования

**Зависимости:**
- `camera_manager: CameraManager`
- `ui_manager: UIManager` (для стрелок)

**Оценка**: ~200 строк, средний риск ⚠️

---

### 2. ChipNavigationCoordinator (~100 строк) 🟡 Средний приоритет

**Методы для извлечения:**
- `_on_chip_navigation_activation_requested(camera_linked)` - активация навигации
- `_activate_chip_navigation_deferred(camera_linked)` - отложенная активация
- `_has_bets_to_process()` - проверка наличия ставок
- `_on_auto_switch_to_pay_mode_requested()` - автоматическое переключение режима

**Зависимости:**
- `chip_navigation_manager: ChipNavigationManager`
- `bet_collection_manager: BetCollectionPhaseManager`
- `ui_manager: UIManager`

**Оценка**: ~100 строк, низкий риск ✅

---

### 3. CollectionModeHandler (~50 строк) 🟢 Низкий приоритет

**Методы для извлечения:**
- `_on_collect_mode_toggled(enabled)` - обработка toggle сбора
- `_on_pay_mode_toggled(enabled)` - обработка toggle оплаты

**Зависимости:**
- `bet_collection_manager: BetCollectionPhaseManager`
- `ui_manager: UIManager`

**Оценка**: ~50 строк, низкий риск ✅

---

### 4. KeyboardFocusHandler (~50 строк) 🟢 Низкий приоритет

**Методы для извлечения:**
- `_on_focus_activated(target)` - обработка активации фокуса

**Зависимости:**
- `phase_manager: GamePhaseManager`
- `winner_selection_manager: WinnerSelectionManager`

**Оценка**: ~50 строк, низкий риск ✅

---

### 5. GamepadMonitor (~50 строк) 🟢 Низкий приоритет

**Методы для извлечения:**
- `_check_gamepad_connection()` - проверка подключения геймпадов
- `_process(delta)` - периодическая проверка геймпадов

**Зависимости:**
- Нет (использует только Input)

**Оценка**: ~50 строк, низкий риск ✅

---

### 6. RoundsCounterUpdater (~30 строк) 🟢 Низкий приоритет

**Методы для извлечения:**
- `_on_round_started()` - обработка начала раунда
- `_update_rounds_counter()` - обновление счетчика

**Зависимости:**
- `rounds_counter_label: Label`
- `survival_rounds_completed: int`

**Оценка**: ~30 строк, низкий риск ✅

---

## 📈 Ожидаемые результаты

### После извлечения всех классов:
- **GameController**: ~1500 строк (было 2196) ✅ **-32%**
- **CameraNavigationController**: ~200 строк (новый)
- **ChipNavigationCoordinator**: ~100 строк (новый)
- **CollectionModeHandler**: ~50 строк (новый)
- **KeyboardFocusHandler**: ~50 строк (новый)
- **GamepadMonitor**: ~50 строк (новый)
- **RoundsCounterUpdater**: ~30 строк (новый)

**Всего извлечено**: ~480 строк

---

## 🎯 План выполнения

### Шаг 1: Извлечь CameraNavigationController
- Создать класс `CameraNavigationController`
- Извлечь все методы управления камерой
- Обновить `GameController` для использования нового класса

### Шаг 2: Извлечь ChipNavigationCoordinator
- Создать класс `ChipNavigationCoordinator`
- Извлечь методы активации навигации
- Обновить `GameController`

### Шаг 3: Извлечь CollectionModeHandler
- Создать класс `CollectionModeHandler`
- Извлечь методы переключения режимов
- Обновить `GameController`

### Шаг 4: Извлечь KeyboardFocusHandler
- Создать класс `KeyboardFocusHandler`
- Извлечь метод обработки фокуса
- Обновить `GameController`

### Шаг 5: Извлечь GamepadMonitor
- Создать класс `GamepadMonitor`
- Извлечь методы проверки геймпадов
- Обновить `GameController`

### Шаг 6: Извлечь RoundsCounterUpdater
- Создать класс `RoundsCounterUpdater`
- Извлечь методы обновления счетчика
- Обновить `GameController`

---

## ⚠️ Важные замечания

1. **GameController - это координатор**, поэтому некоторый размер оправдан
2. **Не стоит разбивать слишком мелко** - может стать сложнее понимать поток
3. **Приоритет:** сначала крупные методы, потом повторяющийся код
4. **Осторожно с зависимостями** - GameController имеет много связей

---

## ✅ Критерии успеха

- [ ] GameController < 1500 строк
- [ ] Все тесты проходят
- [ ] Игра работает как раньше
- [ ] Нет ошибок компиляции
- [ ] Сохранена обратная совместимость

