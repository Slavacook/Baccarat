# 🔍 Анализ зависимостей перед рефакторингом PayoutScene → PayoutOverlay

**Дата:** 2024-12-10
**Цель:** Определить какие менеджеры можно безопасно удалить после рефакторинга

---

## 📊 Статистика использования

| Менеджер | Упоминаний | Файлов | Можно удалить? |
|----------|------------|--------|----------------|
| GameDataManager | 62 | 3 | ✅ ДА |
| TableStateManager | 43 | 3 | ⚠️ ПРОВЕРИТЬ |
| PayoutContextManager | 11 | 2 | ✅ ДА |

---

## 1. GameDataManager

**Файл:** `scripts/GameDataManager.gd` (autoload)

**Используется в:**
1. `scripts/GameDataManager.gd` - сам файл (определение)
2. `scripts/scenes/PayoutScene.gd` - загрузка данных выплаты
3. `scripts/GameController.gd` - сохранение данных перед переходом

**Назначение:**
Передача данных между сценами Game.tscn и PayoutScene.tscn при scene transition:
- `payout_winner` - "Player", "Banker", "Tie"
- `payout_stake` - размер ставки
- `payout_amount` - ожидаемая выплата
- `payout_player_score` - очки игрока
- `payout_banker_score` - очки банкира

**Вердикт:** ✅ **УДАЛИТЬ ПОЛНОСТЬЮ**

После рефакторинга данные будут передаваться напрямую через метод:
```gdscript
payout_overlay.show_payout(winner, stake, payout)
```

---

## 2. TableStateManager

**Файл:** `scripts/autoload/TableStateManager.gd` (autoload)

**Используется в:**
1. `scripts/autoload/TableStateManager.gd` - сам файл (определение)
2. `scripts/GameController.gd` - save/restore логика (основное использование)
3. `scripts/GamePhaseManager.gd` - ??? (нужно проверить)

**Назначение:**
Сохранение полного состояния стола перед переходом на PayoutScene:
- `player_hand` / `banker_hand` - карты на столе
- `actual_winner` / `selected_winner` - победитель
- `bets` - все ставки (основная + пары)
- `camera_position` / `camera_zoom` - состояние камеры
- `game_mode` - режим игры
- `survival_rounds` / `survival_lives` - survival mode
- `pair_player_toggle_pressed` / `pair_banker_toggle_pressed` - состояние toggles
- `action_button_state` - состояние кнопки действия

**Проверка использования в GamePhaseManager:**
```bash
grep -n "TableStateManager" scripts/GamePhaseManager.gd
```

**Вердикт:** ⚠️ **ПРОВЕРИТЬ GamePhaseManager, затем УДАЛИТЬ**

Если TableStateManager используется только для save/restore при scene transition - удалить.
Если есть другое использование в GamePhaseManager - рефакторить.

---

## 3. PayoutContextManager

**Файл:** `scripts/PayoutContextManager.gd` (autoload)

**Используется в:**
1. `scripts/PayoutContextManager.gd` - сам файл (определение)
2. `scripts/GameController.gd` - проверка возврата из PayoutScene

**Назначение:**
Определение, возвращаемся ли мы из PayoutScene (для пропуска reset):
```gdscript
var is_payout_return = PayoutContextManager.has_context()
if not is_payout_return:
    phase_manager.reset()  # Только если НЕ возвращаемся
```

**Вердикт:** ✅ **УДАЛИТЬ ПОЛНОСТЬЮ**

После рефакторинга Game.tscn остаётся в памяти, reset не нужен.

---

## 📋 План удаления (Фаза 5)

### Шаг 1: Удалить GameDataManager
```bash
# Удалить файл
rm scripts/GameDataManager.gd

# Удалить из project.godot [autoload]
# Найти строку: GameDataManager="*res://scripts/GameDataManager.gd"
# Удалить её
```

**Заменить в коде:**
```gdscript
// БЫЛО:
GameDataManager.set_payout_data(winner, stake, payout)
get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")

// СТАЛО:
payout_overlay.show_payout(winner, stake, payout)
```

---

### Шаг 2: Проверить и удалить TableStateManager
```bash
# Проверить использование в GamePhaseManager
grep -A 3 -B 3 "TableStateManager" scripts/GamePhaseManager.gd

# Если не критично:
rm scripts/autoload/TableStateManager.gd

# Удалить из project.godot [autoload]
```

**Удалить в GameController.gd:**
- Метод save_table_state() (вызов перед scene transition)
- Метод _restore_chips_from_table_state() (восстановление после возврата)
- Проверку is_payout_return в _ready()
- Блок восстановления карт, камеры, toggles

---

### Шаг 3: Удалить PayoutContextManager
```bash
rm scripts/PayoutContextManager.gd

# Удалить из project.godot [autoload]
```

**Удалить в GameController.gd:**
```gdscript
// БЫЛО:
var is_payout_return = PayoutContextManager.has_context()
if not is_payout_return:
    phase_manager.reset()

// СТАЛО:
// Ничего - reset не нужен, Game.tscn в памяти
```

---

## 📊 Ожидаемое упрощение

### Файлы:
- ❌ `scripts/GameDataManager.gd` (~130 строк)
- ❌ `scripts/autoload/TableStateManager.gd` (~200 строк)
- ❌ `scripts/PayoutContextManager.gd` (~50 строк)
- **Итого:** -380 строк, -3 файла

### Код в GameController.gd:
- ❌ `_prepare_payout_transition()` (~50 строк)
- ❌ `TableStateManager.save_table_state()` вызов (~20 строк)
- ❌ `_restore_chips_from_table_state()` (~80 строк)
- ❌ Блок восстановления в `_ready()` (~60 строк)
- ❌ Проверка `is_payout_return` и условия (~20 строк)
- **Итого:** -230 строк в GameController

### Autoload синглтоны:
- Было: 13 autoload
- Станет: 10 autoload
- **Итого:** -3 синглтона

---

## ✅ Критерии безопасного удаления

Перед удалением убедиться:

1. ✅ PayoutOverlay полностью работает (Фаза 4 пройдена)
2. ✅ Все тесты пройдены
3. ✅ Старый PayoutScene.tscn удалён
4. ✅ `USE_OVERLAY_PAYOUT = true` и работает стабильно
5. ✅ Проверено использование в GamePhaseManager

---

## 🔍 Проверка GamePhaseManager

**TODO:** Проверить зачем TableStateManager используется в GamePhaseManager

```bash
grep -n "TableStateManager" scripts/GamePhaseManager.gd
```

**Возможные варианты:**
- Сохранение руки игрока/банкира
- Сохранение состояния toggles
- Другая логика

**Если критично:** Рефакторить использование в GamePhaseManager
**Если не критично:** Удалить вместе со всем TableStateManager

---

**Анализ завершён.** Готово к началу Фазы 1.
