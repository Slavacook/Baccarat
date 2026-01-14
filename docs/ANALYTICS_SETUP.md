# Настройка Google Analytics

## Статус: ✅ Настроено

**Measurement ID:** `G-GT0DJC5JQK`

## Что настроено

### 1. Код Google Analytics в export_presets.cfg

В файле `export_presets.cfg` добавлен код Google Analytics в `html/head_include`:

```ini
html/head_include="<!-- Google Analytics -->
<script async src=\"https://www.googletagmanager.com/gtag/js?id=G-GT0DJC5JQK\"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-GT0DJC5JQK');
</script>"
```

Этот код автоматически добавляется в `<head>` HTML файла при экспорте игры в HTML5.

### 2. AnalyticsHelper.gd

Создан хелпер для отправки событий в аналитику: `scripts/utils/AnalyticsHelper.gd`

**Доступные методы:**

```gdscript
# Отслеживание произвольного события
AnalyticsHelper.track_event("event_name", {"param": "value"})

# Отслеживание начала сессии
AnalyticsHelper.track_session_start()

# Отслеживание времени в игре
AnalyticsHelper.track_game_time(120)  # секунды

# Отслеживание действия пользователя
AnalyticsHelper.track_user_action("button_clicked", {"button": "start"})
```

## Как использовать

### Примеры использования в коде:

```gdscript
# В GameController._ready() или при старте игры
func _ready():
    # ... остальной код ...
    
    # Отслеживаем начало сессии
    if OS.has_feature("HTML5"):
        AnalyticsHelper.track_session_start()

# При нажатии на кнопку
func _on_cards_button_pressed():
    # ... логика кнопки ...
    
    # Отслеживаем действие
    if OS.has_feature("HTML5"):
        AnalyticsHelper.track_user_action("game_started", {
            "mode": GameModeManager.get_current_mode()
        })

# При завершении игры
func _on_game_over():
    var play_time = get_play_time_seconds()
    
    if OS.has_feature("HTML5"):
        AnalyticsHelper.track_game_time(play_time)
        AnalyticsHelper.track_event("game_completed", {
            "rounds": rounds_count,
            "score": final_score
        })
```

## Что отслеживается автоматически

Google Analytics автоматически отслеживает:
- Посещения страницы
- Время на странице
- Устройство пользователя
- Браузер
- Разрешение экрана
- Географию (страна, город)

## Что можно отслеживать дополнительно

Через `AnalyticsHelper` можно отслеживать:
- Начало игры
- Завершение игры
- Время в игре
- Нажатия кнопок
- Выбор режима игры
- Ставки
- Результаты раундов
- Ошибки (если добавить обработку)

## Проверка работы

### После экспорта и загрузки на сервер:

1. Откройте игру в браузере
2. Перейдите в Google Analytics: https://analytics.google.com/
3. Выберите ваше свойство
4. Перейдите в раздел "Отчёты" → "В реальном времени"
5. Должны появиться активные пользователи

### Проверка в консоли браузера:

1. Откройте игру в браузере
2. Нажмите F12 (открыть DevTools)
3. Перейдите на вкладку "Console"
4. Введите: `gtag`
5. Должна появиться функция (не ошибка)

## Важные замечания

1. **Работает только в HTML5 экспорте** - `AnalyticsHelper` проверяет `OS.has_feature("HTML5")`
2. **Не работает в редакторе** - проверяется `Engine.is_editor_hint()`
3. **Нужен экспорт** - код добавляется только при экспорте в HTML5
4. **HTTPS рекомендуется** - Google Analytics лучше работает на HTTPS

## Дополнительные настройки

Если нужно отслеживать больше событий, можно добавить вызовы `AnalyticsHelper` в нужных местах кода:

- При смене режима игры
- При настройке параметров
- При показе подсказок
- При ошибках
- При достижениях

## Полезные ссылки

- [Google Analytics](https://analytics.google.com/)
- [Документация gtag.js](https://developers.google.com/analytics/devguides/collection/gtagjs)
- [События в Google Analytics](https://developers.google.com/analytics/devguides/collection/gtagjs/events)
