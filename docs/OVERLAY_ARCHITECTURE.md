# Архитектура Overlay-уведомлений (устойчивых к сбросам)

## 🎯 Цель

Создать систему overlay-уведомлений, которая работает **независимо от состояния игры** и **не прерывается** при сбросе раунда, смене сцены или других операциях.

## 📋 Требования

1. **Независимость от сброса раунда** - overlay должен показываться полное время, даже если раунд сброшен
2. **Параллельная работа** - overlay работает параллельно игровому процессу, не блокируя его
3. **Перебивание только другими overlay** - только новый overlay может прервать текущий
4. **Автоудаление** - каждый overlay удаляет себя после завершения анимации

## 🏗️ Архитектура

### Компоненты

1. **OverlayNotificationManager** (autoload singleton)

   - Управляет созданием и показом overlay
   - Подписан на EventBus сигналы
   - **НОВАЯ АРХИТЕКТУРА**: создаёт новый overlay для каждого показа
   - Создаёт overlay на уровне `get_tree().root`

2. **OverlayNotification** (CanvasLayer)
   - Визуальный компонент overlay
   - Управляет анимацией появления/исчезновения
   - **НОВАЯ АРХИТЕКТУРА**: удаляет себя после завершения анимации

### Жизненный цикл (НОВАЯ АРХИТЕКТУРА)

```
1. СОЗДАНИЕ (каждый раз заново!)
   EventBus.show_overlay_success.emit(text, duration)
   └─> OverlayNotificationManager._create_and_show_overlay()
   └─> OverlayNotificationScene.instantiate() ← НОВЫЙ overlay!
   └─> get_tree().root.add_child(new_overlay)
   └─> new_overlay.show_message(text, type, duration)
   └─> _is_showing = true
   └─> get_tree().create_tween() (tween на уровне SceneTree!)

2. ПОКАЗ
   Fade in (0.3 сек)
   └─> Пауза (duration секунд) ← НЕ ПРЕРЫВАЕТСЯ!
   └─> Fade out (0.3 сек)

3. ЗАВЕРШЕНИЕ И АВТОУДАЛЕНИЕ
   _on_animation_finished()
   └─> _is_showing = false
   └─> visible = false
   └─> queue_free() ← УДАЛЯЕТ СЕБЯ!
   └─> Overlay больше не существует

4. ЗАВЕРШЕНИЕ
   Overlay скрыт, готов к следующему показу
```

## 🔧 Ключевые решения

### 1. Tween на уровне SceneTree

**Проблема**: `create_tween()` создаёт tween на узле, который может быть удалён при сбросе.

**Решение**: Используем `get_tree().create_tween()` - tween создаётся на уровне SceneTree и не зависит от узлов.

```gdscript
# ❌ ПЛОХО (прерывается при сбросе)
_animation_tween = create_tween()

# ✅ ХОРОШО (устойчив к сбросам)
_animation_tween = get_tree().create_tween()
```

### 2. Overlay на уровне root

**Проблема**: Если overlay в сцене игры, он может быть удалён при сбросе.

**Решение**: Добавляем overlay в `get_tree().root`, а не в сцену игры.

```gdscript
# ❌ ПЛОХО (может быть удалён)
get_tree().current_scene.add_child(_overlay_instance)

# ✅ ХОРОШО (независим от сцены)
get_tree().root.add_child(_overlay_instance)
```

### 3. Автоудаление после завершения

**Проблема**: Переиспользование overlay может накапливать состояние и конфликты.

**Решение**: Каждый overlay создаётся заново и удаляет себя после завершения.

```gdscript
# В OverlayNotification._on_animation_finished()
func _on_animation_finished() -> void:
    _is_showing = false
    visible = false
    queue_free()  # Удаляем себя после завершения
```

**Преимущества**:

- Полная независимость каждого overlay
- Нет накопления состояния
- Автоматическая очистка памяти
- Устойчивость к сбросам (новый overlay не зависит от старого)

### 4. Перебивание только другими overlay

**Механизм**: При показе нового overlay предыдущий tween убивается через `kill()`.

```gdscript
if _animation_tween:
    _animation_tween.kill()  # Только другой overlay может перебить
```

## 📊 Последовательность событий (Heart Bet)

### Сценарий: Выигрыш Heart Bet

```
T=0.0s: HeartBetManager._handle_win()
  └─> EventBus.show_overlay_success.emit("Поздравляем!", 4.0)
  └─> OverlayNotificationManager._create_and_show_overlay()
  └─> OverlayNotificationScene.instantiate() ← СОЗДАЁТСЯ НОВЫЙ!
  └─> get_tree().root.add_child(new_overlay)
  └─> new_overlay.show_message() ← НАЧАЛО ПОКАЗА
  └─> _is_showing = true
  └─> get_tree().create_tween() ← Tween на уровне SceneTree!
  └─> Fade in (0.3 сек)

T=0.3s: Fade in завершён
  └─> Пауза 4.0 секунд ← НАЧИНАЕТСЯ ПАУЗА

T=0.3s: HeartBetManager._handle_win() продолжается
  └─> EventBus.heart_bet_round_complete.emit()

T=0.3s: GameController._on_heart_bet_round_complete()
  └─> await get_tree().create_timer(1.5).timeout ← ЗАДЕРЖКА 1.5 СЕК

T=1.8s: Задержка завершена
  └─> phase_manager.reset() ← СБРОС РАУНДА
  └─> Overlay ВСЁ ЕЩЁ ПОКАЗЫВАЕТСЯ! (независим, новый экземпляр)

T=4.3s: Пауза overlay завершена (0.3 + 4.0)
  └─> Fade out (0.3 сек)

T=4.6s: Fade out завершён
  └─> _on_animation_finished()
  └─> _is_showing = false
  └─> visible = false
  └─> queue_free() ← OVERLAY УДАЛЯЕТ СЕБЯ!
```

**Результат**: Overlay показался полные 4.6 секунд, несмотря на сброс раунда в 1.8 секунд!
**Преимущество**: Новый overlay каждый раз = полная независимость, нет конфликтов состояния!

## 🛡️ Защита от различных сценариев

### Сценарий 1: Сброс раунда во время показа

**Что происходит**:

- Overlay показывает сообщение (4 секунды)
- Через 1.5 секунды происходит `phase_manager.reset()`
- Overlay продолжает показываться, т.к. tween на уровне SceneTree

**Защита**: ✅ Работает

### Сценарий 2: Принудительный вызов hide()

**Что происходит**:

- Overlay активно показывается (`_is_showing = true`)
- Кто-то вызывает `overlay.hide()`
- Overlay игнорирует вызов

**Защита**: ✅ Работает

### Сценарий 3: Новый overlay во время показа старого

**Что происходит**:

- Overlay показывает "Поздравляем!" (4 секунды)
- Через 2 секунды показывается новый overlay "Ошибка!"
- Старый overlay убивается через `kill()`, новый показывается

**Защита**: ✅ Работает (перебивание разрешено)

### Сценарий 4: Смена сцены

**Что происходит**:

- Overlay показывает сообщение
- Происходит `get_tree().change_scene_to_file(...)`
- Overlay остаётся, т.к. он на уровне root

**Защита**: ✅ Работает

## 🔍 Отладка

### Логи для отслеживания

```gdscript
# В OverlayNotification.show_message()
print("🎬 OverlayNotification.show_message: '%s', duration=%.1f" % [text, duration])
print("🎬 Оверлей: пауза %.1f секунд (устойчив к сбросам)" % duration)

# В OverlayNotification.hide()
print("🎬 Overlay защищён от скрытия (активно показывается)")

# В OverlayNotification._on_animation_finished()
print("🎬 Overlay скрыт после завершения анимации")
```

### Проверка состояния

```gdscript
# Проверить, показывается ли overlay
if OverlayNotificationManager._overlay_instance:
    var is_showing = OverlayNotificationManager._overlay_instance._is_showing
    print("Overlay активно показывается: %s" % is_showing)
```

## 📝 Использование

### Показать overlay

```gdscript
# Через EventBus (рекомендуется)
EventBus.show_overlay_success.emit("Поздравляем!", 4.0)
EventBus.show_overlay_error.emit("Ошибка!", 4.0)
EventBus.show_overlay_info.emit("Информация", 4.0)

# Напрямую через менеджер
OverlayNotificationManager.show_success("Поздравляем!", 4.0)
```

### Принудительное скрытие (только для экстренных случаев)

```gdscript
# Только если действительно нужно (Game Over, смена сцены)
if OverlayNotificationManager._overlay_instance:
    OverlayNotificationManager._overlay_instance.force_hide()
```

## ✅ Преимущества

1. **Независимость** - overlay не зависит от состояния игры
2. **Надёжность** - гарантированное время показа
3. **Параллельность** - не блокирует игровой процесс
4. **Защита** - не прерывается случайными вызовами
5. **Гибкость** - можно перебить другим overlay

## ⚠️ Важные замечания

1. **Не используйте `force_hide()`** в обычной игре - только для экстренных случаев
2. **Длительность должна быть достаточной** - учитывайте, что overlay показывается полное время
3. **Перебивание разрешено** - новый overlay может прервать старый (это нормально)
4. **Overlay на уровне root** - он не удаляется при смене сцены (нужно учитывать при тестировании)

## 🔄 Сравнение: До и После

### ❌ До (проблемы)

- Overlay прерывался при сбросе раунда
- Tween создавался на узле (мог быть удалён)
- Переиспользование overlay накапливало состояние
- Непредсказуемое время показа

### ✅ После (решение - НОВАЯ АРХИТЕКТУРА)

- Overlay устойчив к сбросам (новый overlay каждый раз)
- Tween на уровне SceneTree (не удаляется)
- Автоудаление после завершения (нет накопления состояния)
- Гарантированное время показа
- Полная независимость каждого overlay
