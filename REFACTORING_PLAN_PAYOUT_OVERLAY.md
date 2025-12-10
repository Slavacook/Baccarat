# 🔄 План рефакторинга: PayoutScene → PayoutOverlay

**Дата:** 2024-12-10
**Цель:** Переделать систему выплат со scene transition на overlay для упрощения кода
**Ожидаемое упрощение:** ~300-400 строк кода, удаление 2-3 менеджеров

---

## 📋 Принципы безопасного рефакторинга

1. ✅ **Небольшие коммиты** - каждая фаза = отдельный commit
2. ✅ **Возможность отката** - можно вернуться на любой этап
3. ✅ **Параллельная работа** - старое и новое работают одновременно (с переключателем)
4. ✅ **Тестирование** - проверка в Godot после каждой фазы
5. ✅ **Backup branch** - создать резервную ветку перед началом

---

## 🎯 Что будет изменено

### **Было (Scene Transition):**
```
GameController → change_scene_to_file("PayoutScene.tscn")
    ↓
Game.tscn 🗑️ УДАЛЁН из памяти
    ↓
PayoutScene.tscn загружен (весь экран)
    ↓
change_scene_to_file("Game.tscn")
    ↓
Game.tscn загружен ЗАНОВО (_ready() вызван снова)
    ↓
Восстановление состояния из TableStateManager
```

### **Станет (Overlay):**
```
GameController → payout_overlay.show()
    ↓
Game.tscn остаётся в памяти ✅
    ↓
PayoutOverlay (CanvasLayer) показан поверх
    ↓
payout_overlay.hide()
    ↓
Game.tscn виден снова (всё на месте)
```

---

## 📂 Файлы, которые будут изменены

### Изменения:
- ✏️ `scenes/Game.tscn` - добавить PayoutOverlay (CanvasLayer)
- ✏️ `scripts/GameController.gd` - интеграция overlay, удаление save/restore
- ✏️ `scripts/scenes/PayoutScene.gd` → `scripts/PayoutOverlay.gd` - адаптация

### Удаления:
- 🗑️ `scenes/PayoutScene.tscn` - больше не нужна
- 🗑️ `scripts/GameDataManager.gd` - удалить если не используется в других местах
- 🗑️ `scripts/autoload/TableStateManager.gd` - логика сохранения не нужна
- 🗑️ `scripts/PayoutContextManager.gd` - контекст возврата не нужен

### Документация:
- ✏️ `CLAUDE.md` - обновить описание архитектуры
- ✏️ `CHANGELOG_PAYOUT_OVERLAY.md` - документация изменений (создать)

---

## 🛠️ Фазы рефакторинга (7 этапов)

---

## Фаза 0: Подготовка 🛡️

**Цель:** Создать точку безопасного возврата

### Шаги:

1. **Создать backup branch**
   ```bash
   git checkout -b backup/before-payout-overlay
   git push origin backup/before-payout-overlay
   git checkout refactoring/phase-2-uimanager
   ```

2. **Создать feature branch**
   ```bash
   git checkout -b feature/payout-overlay
   ```

3. **Протестировать текущую версию**
   - [ ] Запустить игру (F5)
   - [ ] Пройти полный цикл выплаты
   - [ ] Проверить survival mode
   - [ ] Проверить пары (Player Pair, Banker Pair)
   - [ ] Убедиться что всё работает

4. **Анализ зависимостей**
   Проверить где используются менеджеры:
   ```bash
   grep -r "GameDataManager" scripts/
   grep -r "TableStateManager" scripts/
   grep -r "PayoutContextManager" scripts/
   ```

5. **Создать документ**
   ```bash
   # Этот файл уже создан!
   ```

**Commit:**
```bash
git add REFACTORING_PLAN_PAYOUT_OVERLAY.md
git commit -m "docs: план рефакторинга PayoutScene → PayoutOverlay"
```

**Критерий успеха:** ✅ Backup branch создан, текущая версия работает

---

## Фаза 1: Создание PayoutOverlay в Game.tscn 🏗️

**Цель:** Добавить новую структуру без удаления старой

### Шаги:

1. **Открыть Game.tscn в Godot Editor**
   - Правый клик на корневой узел `Game`
   - Add Child Node → `CanvasLayer`
   - Переименовать в `PayoutOverlay`

2. **Настроить CanvasLayer**
   - Layer: 10 (чтобы был поверх всего)
   - Visible: false (по умолчанию скрыт)

3. **Скопировать UI структуру из PayoutScene.tscn**
   - Открыть `scenes/PayoutScene.tscn`
   - Скопировать всю структуру внутри Control (MarginContainer и всё содержимое)
   - Вставить как child в PayoutOverlay

4. **Структура должна быть:**
   ```
   Game (Node2D)
   ├─ Camera2D
   ├─ PlayerZone
   ├─ BankerZone
   ├─ ChipBet
   ├─ SettingsScene (CanvasLayer)
   └─ PayoutOverlay (CanvasLayer) ← NEW!
       └─ ColorRect (затемнение фона - опционально)
           └─ MarginContainer
               └─ VBoxContainer
                   ├─ HeaderHBox
                   │   ├─ ResultLabel
                   │   ├─ StakeLabel
                   │   ├─ AmountPanel
                   │   │   └─ CollectedAmountLabel
                   │   └─ HintButton
                   ├─ FleetPanel
                   │   └─ FleetMargin
                   │       └─ FleetHBox
                   │           ├─ ChipFleetContainer
                   │           └─ PayoutButton
                   ├─ MainPanel
                   │   └─ ChipStacksContainer
                   ├─ ScoreLabel
                   └─ FeedbackContainer
                       └─ FeedbackLabel
   ```

5. **Добавить затемнение фона (опционально)**
   - Add Child к PayoutOverlay → `ColorRect`
   - Anchor Preset: Full Rect
   - Color: `#000000` (чёрный)
   - Modulate Alpha: `0.7` (70% прозрачности)
   - Mouse Filter: Stop (блокирует клики по столу)

6. **Сохранить сцену**
   - Ctrl+S или Scene → Save Scene

**Commit:**
```bash
git add scenes/Game.tscn
git commit -m "feat: добавлен PayoutOverlay (CanvasLayer) в Game.tscn

- Создан CanvasLayer с layer=10
- Скопирована UI структура из PayoutScene.tscn
- Добавлено затемнение фона (ColorRect с alpha 0.7)
- По умолчанию скрыт (visible=false)

Старый PayoutScene.tscn пока НЕ удалён (параллельная работа)"
```

**Критерий успеха:** ✅ PayoutOverlay создан в Game.tscn, игра запускается без ошибок

---

## Фаза 2: Адаптация скрипта PayoutOverlay.gd 📝

**Цель:** Создать новый скрипт без логики scene transition

### Шаги:

1. **Скопировать PayoutScene.gd → PayoutOverlay.gd**
   ```bash
   cp scripts/scenes/PayoutScene.gd scripts/PayoutOverlay.gd
   ```

2. **Изменить комментарий в начале файла**
   ```gdscript
   # res://scripts/PayoutOverlay.gd
   # Overlay для расчёта выплаты с использованием фишек
   # Отображается поверх Game.tscn (CanvasLayer)
   ```

3. **Удалить логику загрузки из GameDataManager**

   **Было:**
   ```gdscript
   func _ready():
       # ...
       # Загружаем данные из GameDataManager
       setup_payout(
           GameDataManager.payout_winner,
           GameDataManager.payout_stake,
           GameDataManager.payout_amount
       )
   ```

   **Стало:**
   ```gdscript
   func _ready():
       # ...
       # Данные передаются напрямую через setup_payout()
       # (вызывается из GameController)
   ```

4. **Изменить метод завершения выплаты**

   **Было (PayoutScene.gd:524):**
   ```gdscript
   func _transition_back_to_game():
       # Сохраняем результат в GameDataManager
       GameDataManager.set_payout_result(is_correct, collected, expected)

       # Переходим обратно на Game.tscn
       get_tree().change_scene_to_file("res://scenes/Game.tscn")
   ```

   **Стало (PayoutOverlay.gd):**
   ```gdscript
   signal payout_completed(is_correct: bool, collected: float, expected: float)

   func _transition_back_to_game():
       # Эмитим сигнал с результатом
       payout_completed.emit(is_correct, collected, expected)

       # Скрываем overlay
       hide()
   ```

5. **Добавить метод show_payout() для внешнего вызова**
   ```gdscript
   func show_payout(winner: String, stake: float, payout: float):
       """Показать overlay с параметрами выплаты

       Вызывается из GameController вместо scene transition
       """
       setup_payout(winner, stake, payout)
       show()  # Показать CanvasLayer

       # Установить фокус на первую кнопку флота
       if chip_fleet_container.get_child_count() > 0:
           var first_chip_button = chip_fleet_container.get_child(0)
           first_chip_button.grab_focus()
   ```

6. **Обновить метод _update_score_display()**

   **Было:**
   ```gdscript
   func _update_score_display():
       var score = SaveManager.instance.get_score()
       score_label.text = Localization.t("SCORE") + ": %d" % score
   ```

   **Стало (без изменений, но проверить):**
   - SaveManager - autoload, доступен из любой сцены
   - Должно работать без изменений

7. **Протестировать скрипт на ошибки**
   ```bash
   # Открыть Godot, проверить консоль на ошибки парсинга
   ```

**Commit:**
```bash
git add scripts/PayoutOverlay.gd
git commit -m "feat: создан PayoutOverlay.gd для overlay режима

Изменения относительно PayoutScene.gd:
- Удалена загрузка из GameDataManager в _ready()
- Заменён change_scene на hide() + signal payout_completed
- Добавлен метод show_payout() для внешнего вызова
- Данные передаются напрямую через параметры

Старый PayoutScene.gd пока НЕ удалён"
```

**Критерий успеха:** ✅ PayoutOverlay.gd создан, нет ошибок парсинга

---

## Фаза 3: Интеграция в GameController (параллельно) 🔗

**Цель:** Добавить поддержку overlay без удаления scene transition

### Шаги:

1. **Добавить константу-переключатель**
   ```gdscript
   # В начале GameController.gd (после exports)

   # ═══════════════════════════════════════════════════════════════════
   # РЕЖИМ ВЫПЛАТЫ (переключатель для тестирования)
   # ═══════════════════════════════════════════════════════════════════

   const USE_OVERLAY_PAYOUT = false  # true = overlay, false = scene transition
   ```

2. **Добавить ссылку на PayoutOverlay**
   ```gdscript
   # После других @onready переменных
   @onready var payout_overlay: CanvasLayer = $PayoutOverlay
   ```

3. **Подключить скрипт к PayoutOverlay в сцене**
   - Открыть Game.tscn
   - Выбрать узел PayoutOverlay
   - Inspector → Script → Attach Script
   - Выбрать `scripts/PayoutOverlay.gd`
   - Сохранить сцену

4. **Подключить сигнал в _ready()**
   ```gdscript
   func _ready():
       # ... существующий код ...

       # Подключаем PayoutOverlay
       if has_node("PayoutOverlay"):
           payout_overlay = get_node("PayoutOverlay")
           payout_overlay.payout_completed.connect(_on_payout_overlay_completed)
           payout_overlay.hide()  # Убедиться что скрыт
           print("✅ PayoutOverlay подключен к GameController")
       else:
           print("⚠️  PayoutOverlay НЕ НАЙДЕН в Game.tscn")
   ```

5. **Создать новый метод _show_payout_overlay()**
   ```gdscript
   func _show_payout_overlay(winner: String, stake: float, payout: float):
       """Показать PayoutOverlay (новый способ - overlay)"""

       print("💰 Показываю PayoutOverlay: %s, stake=%.1f, payout=%.1f" % [winner, stake, payout])

       # Показываем overlay с параметрами
       payout_overlay.show_payout(winner, stake, payout)
   ```

6. **Создать обработчик завершения**
   ```gdscript
   func _on_payout_overlay_completed(is_correct: bool, collected: float, expected: float):
       """Обработка завершения выплаты в overlay режиме"""

       print("💰 Выплата завершена: correct=%s, collected=%.1f, expected=%.1f" % [is_correct, collected, expected])

       if is_correct:
           # ✅ Правильная выплата
           EventBus.payout_correct.emit(collected, expected)

           # Обновляем очки
           SaveManager.instance.add_score(1)

           # Проверяем следующую выплату в очереди
           if payout_queue_manager.has_next_payout():
               # Есть ещё выплаты (например, пары)
               var next_payout = payout_queue_manager.get_next_payout()
               _show_payout_overlay(
                   next_payout.bet_type,
                   next_payout.stake,
                   next_payout.payout
               )
           else:
               # Все выплаты завершены
               _on_all_payouts_completed()
       else:
           # ❌ Неправильная выплата
           EventBus.payout_wrong.emit(collected, expected)

           if is_survival_mode:
               survival_ui.lose_life()


   func _on_all_payouts_completed():
       """Все выплаты в очереди обработаны"""

       if is_survival_mode:
           survival_rounds_completed += 1
           print("🏆 Раунд выживания завершён: %d" % survival_rounds_completed)

       # Сбрасываем стол для новой раздачи
       phase_manager.reset()
       ui_manager.reset_ui()
       camera_zoom_out()

       # Разблокируем маркеры
       if winner_selection_manager:
           winner_selection_manager.unlock_markers()

       # Эмитим событие подготовки стола
       EventBus.table_prepared_for_new_game.emit()
   ```

7. **Изменить существующий метод _prepare_payouts() с переключателем**

   Найти метод `_prepare_payouts()` (около строки 350-400) и добавить условие:

   ```gdscript
   func _prepare_payouts(winner: String, stake: float, payout: float):
       """Подготовка очереди выплат и показ первой"""

       # ... существующая логика создания очереди ...

       # Показываем первую выплату
       var first_payout = payout_queue_manager.get_next_payout()

       if USE_OVERLAY_PAYOUT:
           # 🆕 Новый способ - overlay
           _show_payout_overlay(
               first_payout.bet_type,
               first_payout.stake,
               first_payout.payout
           )
       else:
           # 🗑️ Старый способ - scene transition
           _prepare_payout_transition(
               first_payout.bet_type,
               first_payout.stake,
               first_payout.payout
           )
   ```

**Commit:**
```bash
git add scripts/GameController.gd scenes/Game.tscn
git commit -m "feat: интеграция PayoutOverlay в GameController

- Добавлен переключатель USE_OVERLAY_PAYOUT (по умолчанию false)
- Создан метод _show_payout_overlay() для нового способа
- Создан обработчик _on_payout_overlay_completed()
- Подключен сигнал payout_completed
- Существующая логика scene transition сохранена

Можно переключаться между режимами через константу"
```

**Критерий успеха:** ✅ Код компилируется, старый способ всё ещё работает

---

## Фаза 4: Тестирование overlay режима 🧪

**Цель:** Убедиться что новый способ работает правильно

### Шаги:

1. **Включить overlay режим**
   ```gdscript
   const USE_OVERLAY_PAYOUT = true  # Включить новый режим
   ```

2. **Запустить игру (F5)**

3. **Тест 1: Обычная выплата**
   - [ ] Раздать карты
   - [ ] Выбрать правильного победителя
   - [ ] Проверить: PayoutOverlay показался поверх стола
   - [ ] Проверить: карты видны "под" overlay (если фон полупрозрачный)
   - [ ] Собрать фишки правильно
   - [ ] Нажать "Выплатить"
   - [ ] Проверить: overlay скрылся
   - [ ] Проверить: стол готов к новой раздаче
   - [ ] Проверить: маркеры разблокированы

4. **Тест 2: Неправильная выплата**
   - [ ] Раздать карты
   - [ ] Выбрать победителя
   - [ ] Собрать неправильную сумму
   - [ ] Нажать "Выплатить"
   - [ ] Проверить: показался feedback "Ошибка!"
   - [ ] Проверить: overlay НЕ закрылся
   - [ ] Проверить: можно исправить и попробовать снова

5. **Тест 3: Выплата с парами**
   - [ ] Нажать toggles пар (Player Pair, Banker Pair)
   - [ ] Раздать карты с парой
   - [ ] Выбрать победителя
   - [ ] Проверить: показалась ПЕРВАЯ выплата (основная)
   - [ ] Выплатить правильно
   - [ ] Проверить: показалась ВТОРАЯ выплата (пара)
   - [ ] Выплатить правильно
   - [ ] Проверить: overlay закрылся только после ВСЕХ выплат

6. **Тест 4: Survival mode**
   - [ ] Включить survival mode
   - [ ] Сделать ошибку в выплате
   - [ ] Проверить: жизнь потеряна
   - [ ] Проверить: при 0 жизней показался Game Over

7. **Тест 5: Кнопка "Подсказка"**
   - [ ] Нажать "Подсказка"
   - [ ] Проверить: фишки собрались автоматически
   - [ ] Проверить: можно выплатить

8. **Тест 6: Джойпад**
   - [ ] Навигация по кнопкам флота
   - [ ] Выбор фишек
   - [ ] Нажатие "Выплатить"

9. **Проверить консоль на ошибки**
   - [ ] Нет красных ошибок
   - [ ] Нет warnings (кроме известных)

10. **Если ВСЁ работает:**
    ```bash
    git add scripts/GameController.gd
    git commit -m "test: overlay режим работает корректно

    Протестированы сценарии:
    - Обычная выплата
    - Неправильная выплата с повтором
    - Выплата с парами (очередь)
    - Survival mode с потерей жизни
    - Кнопка подсказки
    - Джойпад навигация

    USE_OVERLAY_PAYOUT = true оставлен включённым"
    ```

11. **Если что-то НЕ работает:**
    ```gdscript
    const USE_OVERLAY_PAYOUT = false  # Вернуть старый способ
    ```

    - Записать что именно не работает
    - Исправить в PayoutOverlay.gd или GameController.gd
    - Повторить тестирование

**Критерий успеха:** ✅ Все 6 тестов пройдены, overlay работает как scene transition

---

## Фаза 5: Удаление старой логики 🗑️

**Цель:** Убрать scene transition код и неиспользуемые менеджеры

**⚠️ ВАЖНО:** Выполнять только после успешного тестирования Фазы 4!

### Шаги:

1. **Удалить переключатель**
   ```gdscript
   // УДАЛИТЬ:
   const USE_OVERLAY_PAYOUT = true
   ```

2. **Удалить метод _prepare_payout_transition() и всё связанное**

   В GameController.gd найти и удалить:
   - `_prepare_payout_transition()` - переход на PayoutScene
   - `_restore_chips_from_table_state()` - восстановление фишек
   - Весь блок с `TableStateManager.save_table_state()`
   - Проверку `var is_payout_return = PayoutContextManager.has_context()`
   - Блок восстановления в `_ready()` при возврате

3. **Упростить _prepare_payouts()**
   ```gdscript
   func _prepare_payouts(winner: String, stake: float, payout: float):
       """Подготовка очереди выплат и показ первой"""

       # Очищаем очередь
       payout_queue_manager.clear_queue()

       # Добавляем основную выплату
       payout_queue_manager.add_payout({
           "bet_type": winner,
           "stake": stake,
           "payout": payout,
           "player_score": BaccaratRules.hand_value(phase_manager.player_hand),
           "banker_score": BaccaratRules.hand_value(phase_manager.banker_hand)
       })

       # Добавляем выплаты за пары (если есть)
       if pair_betting_manager.player_pair_detected:
           var pair_payout = pair_betting_manager.get_player_pair_payout()
           payout_queue_manager.add_payout({
               "bet_type": "PlayerPair",
               "stake": pair_betting_manager.player_pair_stake,
               "payout": pair_payout
           })

       if pair_betting_manager.banker_pair_detected:
           var pair_payout = pair_betting_manager.get_banker_pair_payout()
           payout_queue_manager.add_payout({
               "bet_type": "BankerPair",
               "stake": pair_betting_manager.banker_pair_stake,
               "payout": pair_payout
           })

       # Показываем первую выплату
       var first_payout = payout_queue_manager.get_next_payout()
       _show_payout_overlay(
           first_payout.bet_type,
           first_payout.stake,
           first_payout.payout
       )
   ```

4. **Проверить использование GameDataManager**
   ```bash
   grep -r "GameDataManager" scripts/ --exclude-dir=autoload
   ```

   Если используется ТОЛЬКО для PayoutScene:
   - Удалить `scripts/GameDataManager.gd`
   - Удалить из `project.godot` секции `[autoload]`

5. **Удалить TableStateManager**
   ```bash
   # Проверить использование
   grep -r "TableStateManager" scripts/

   # Если не используется:
   rm scripts/autoload/TableStateManager.gd
   ```

   Удалить из `project.godot`:
   ```
   [autoload]
   TableStateManager="*res://scripts/autoload/TableStateManager.gd"  ← УДАЛИТЬ
   ```

6. **Удалить PayoutContextManager**
   ```bash
   grep -r "PayoutContextManager" scripts/

   # Если не используется:
   rm scripts/PayoutContextManager.gd
   ```

   Удалить из `project.godot`

7. **Удалить PayoutScene.tscn и PayoutScene.gd**
   ```bash
   rm scenes/PayoutScene.tscn
   rm scripts/scenes/PayoutScene.gd
   ```

8. **Проверить проект на ошибки**
   - Открыть Godot
   - Проверить консоль на ошибки загрузки
   - Запустить игру (F5)
   - Проверить что всё работает

**Commit:**
```bash
git add -A
git commit -m "refactor: удалена старая логика scene transition

Удалено:
- Метод _prepare_payout_transition()
- Логика сохранения в TableStateManager
- Логика восстановления из TableStateManager
- GameDataManager.gd (autoload)
- TableStateManager.gd (autoload)
- PayoutContextManager.gd
- scenes/PayoutScene.tscn
- scripts/scenes/PayoutScene.gd

Упрощено:
- _prepare_payouts() - только создание очереди и вызов overlay
- _ready() - убрана проверка is_payout_return

Код стал проще на ~350 строк"
```

**Критерий успеха:** ✅ Проект компилируется, игра работает, старый код удалён

---

## Фаза 6: Cleanup и документация 📚

**Цель:** Финальная очистка и обновление документации

### Шаги:

1. **Переименовать PayoutOverlay.gd → PayoutPopup.gd (опционально)**

   Если хочешь единообразие с другими попапами:
   ```bash
   mv scripts/PayoutOverlay.gd scripts/popups/PayoutPopup.gd
   ```

   Обновить путь к скрипту в Game.tscn

2. **Обновить комментарии в GameController.gd**

   Убрать упоминания о scene transition, добавить описание overlay:
   ```gdscript
   # ═══════════════════════════════════════════════════════════════════
   # СИСТЕМА ВЫПЛАТ
   # ═══════════════════════════════════════════════════════════════════

   # PayoutOverlay - CanvasLayer поверх Game.tscn
   # Показывается после правильного выбора победителя
   # Позволяет игроку собрать фишки для расчёта выплаты
   # После завершения эмитит сигнал payout_completed и скрывается
   ```

3. **Удалить неиспользуемые переменные**

   Проверить GameController.gd на неиспользуемые переменные:
   ```bash
   # Проверить что нет is_payout_return, table_state_snapshot и т.д.
   ```

4. **Обновить CLAUDE.md**

   Изменить раздел "Система выплат":

   ```markdown
   ### Система выплат

   **PayoutOverlay** (`scripts/PayoutOverlay.gd`) - overlay для расчёта выплат:
   - Отображается как CanvasLayer поверх Game.tscn
   - Game.tscn остаётся в памяти (не нужно сохранять/восстанавливать)
   - Использует ChipStack, ChipStackManager, PayoutValidator
   - После завершения эмитит payout_completed и скрывается

   **Жизненный цикл выплаты:**
   ```
   1. Правильный выбор победителя
   2. GameController._prepare_payouts() - создание очереди
   3. payout_overlay.show_payout(winner, stake, payout)
   4. Игрок собирает фишки
   5. Нажатие "Выплатить"
   6. Валидация через PayoutValidator
   7. payout_completed.emit(is_correct, collected, expected)
   8. payout_overlay.hide()
   9. Если есть ещё выплаты → показать следующую
   10. Если все выплаты завершены → сброс стола
   ```

   **Удалено (было в v5.9):**
   - ~~Scene transition на PayoutScene.tscn~~
   - ~~GameDataManager - передача данных между сценами~~
   - ~~TableStateManager - сохранение состояния стола~~
   - ~~PayoutContextManager - контекст возврата~~
   - ~~Логика save/restore в GameController~~
   ```

5. **Создать CHANGELOG_PAYOUT_OVERLAY.md**

   Документировать все изменения (подробный changelog)

6. **Обновить README.md (если есть)**

   Упомянуть упрощение архитектуры

7. **Проверить .gitignore**

   Убедиться что .godot/ не коммитится

**Commit:**
```bash
git add -A
git commit -m "docs: обновлена документация после рефакторинга

- Обновлён CLAUDE.md (раздел 'Система выплат')
- Создан CHANGELOG_PAYOUT_OVERLAY.md
- Улучшены комментарии в GameController.gd
- Удалены упоминания scene transition из комментариев

Рефакторинг завершён полностью"
```

**Критерий успеха:** ✅ Документация актуальна, код чистый

---

## Фаза 7: Финальное тестирование ✅

**Цель:** Полная проверка всех сценариев

### Чеклист тестирования:

#### Базовые сценарии:
- [ ] Запуск игры (F5)
- [ ] Раздача карт
- [ ] Выбор третьих карт (правильно/неправильно)
- [ ] Выбор победителя (Player/Banker/Tie)
- [ ] Выплата с правильной суммой
- [ ] Выплата с неправильной суммой + повтор

#### Пары:
- [ ] Player Pair toggle + выплата
- [ ] Banker Pair toggle + выплата
- [ ] Обе пары одновременно (очередь из 3 выплат)

#### Survival Mode:
- [ ] Включение survival mode
- [ ] Правильная игра → +1 раунд
- [ ] Ошибка в выборе карт → -1 жизнь
- [ ] Ошибка в выплате → -1 жизнь
- [ ] Game Over при 0 жизней
- [ ] Restart после Game Over

#### UI/UX:
- [ ] Кнопка "Подсказка" работает
- [ ] Затемнение фона (если добавили)
- [ ] Карты видны под overlay (если полупрозрачный фон)
- [ ] Маркеры блокируются/разблокируются правильно
- [ ] Камера зум работает
- [ ] Статистика обновляется

#### Джойпад:
- [ ] Навигация по флоту фишек
- [ ] Выбор фишек (A/B)
- [ ] Кнопка "Выплатить" (Start)
- [ ] Кнопка "Подсказка"

#### Настройки:
- [ ] Смена языка (ru ↔ en)
- [ ] Смена режима игры (Junket ↔ Classic)
- [ ] Изменение лимитов стола
- [ ] Включение/выключение survival mode

#### Краевые случаи:
- [ ] Натуральная 8-9 → сразу выбор победителя → выплата
- [ ] Ничья (Tie) с большой выплатой (x8)
- [ ] Банкир с комиссией 5%
- [ ] Быстрые клики (не должно дублироваться)

### Если всё прошло:

**Commit:**
```bash
git commit --allow-empty -m "test: финальное тестирование пройдено

Протестированы:
✅ Все базовые сценарии выплат
✅ Пары (одиночные и множественные)
✅ Survival mode (жизни, game over, restart)
✅ UI/UX (подсказка, затемнение, маркеры)
✅ Джойпад навигация
✅ Настройки игры
✅ Краевые случаи

Рефакторинг PayoutScene → PayoutOverlay ЗАВЕРШЁН"
```

**Merge в основную ветку:**
```bash
git checkout refactoring/phase-2-uimanager
git merge feature/payout-overlay
git push origin refactoring/phase-2-uimanager
```

**Критерий успеха:** ✅ Все тесты пройдены, ветка смержена

---

## 📊 Итоговая статистика

### Ожидаемые улучшения:

| Метрика | До рефакторинга | После рефакторинга | Улучшение |
|---------|-----------------|-------------------|-----------|
| **Строк кода** | ~1800 | ~1450 | -350 строк (-19%) |
| **Файлов** | 10 | 7 | -3 файла |
| **Autoload синглтонов** | 13 | 10 | -3 синглтона |
| **Scene файлов** | 2 | 1 | -1 сцена |
| **Сложность save/restore** | Высокая (15 параметров) | Отсутствует | -100% |
| **Время загрузки выплаты** | ~200ms (scene load) | ~10ms (show overlay) | 20x быстрее |

### Удалённые файлы:
- `scenes/PayoutScene.tscn` (~50 KB)
- `scripts/scenes/PayoutScene.gd` (~600 строк)
- `scripts/GameDataManager.gd` (~130 строк)
- `scripts/autoload/TableStateManager.gd` (~200 строк)
- `scripts/PayoutContextManager.gd` (~50 строк)

### Упрощённые файлы:
- `scripts/GameController.gd` (-~250 строк логики save/restore)

---

## 🚨 Что делать если что-то пошло не так

### Откат на предыдущую фазу:
```bash
git log --oneline  # Найти commit нужной фазы
git reset --hard <commit-hash>
```

### Откат на backup branch:
```bash
git checkout backup/before-payout-overlay
git checkout -b feature/payout-overlay-v2  # Новая попытка
```

### Временное отключение overlay:
```gdscript
const USE_OVERLAY_PAYOUT = false  # Вернуть scene transition (если ещё не удалён)
```

---

## ✅ Критерии успешного завершения

1. ✅ PayoutOverlay работает как полноценная замена PayoutScene
2. ✅ Все тесты пройдены (базовые + краевые случаи)
3. ✅ Старый код удалён полностью
4. ✅ Документация обновлена
5. ✅ Нет ошибок в консоли
6. ✅ Проект стабилен и готов к продакшену

---

**Удачи с рефакторингом! 🚀**

Если на каком-то этапе возникнут вопросы - обращайся, разберём вместе.
