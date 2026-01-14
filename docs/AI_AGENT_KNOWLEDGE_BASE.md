# База знаний для AI-агента: Godot HTML5 развёртывание

## 📚 Оглавление

1. [Godot Engine - основы](#godot-engine---основы)
2. [Адаптивный UI в Godot](#адаптивный-ui-в-godot)
3. [Экспорт в HTML5](#экспорт-в-html5)
4. [Проблемы и решения](#проблемы-и-решения)
5. [Настройка Nginx](#настройка-nginx)
6. [Веб-технологии](#веб-технологии)
7. [Отладка и тестирование](#отладка-и-тестирование)
8. [Полезные ресурсы](#полезные-ресурсы)

---

## Godot Engine - основы

### Архитектура Godot

**Ключевые концепции:**
- **Сцены (Scenes)** - основные единицы организации проекта
- **Узлы (Nodes)** - базовые элементы сцены
- **Сигналы (Signals)** - система событий для связи узлов
- **CanvasLayer** - слои для UI элементов
- **Viewport** - область отрисовки

**Важные файлы:**
- `project.godot` - настройки проекта
- `export_presets.cfg` - настройки экспорта
- `.tscn` файлы - сцены игры

### GDScript основы

**Синтаксис:**
```gdscript
extends Node2D
class_name MyClass

signal my_signal(value: int)

var my_var: int = 0

func _ready() -> void:
    pass
```

**Работа с узлами:**
```gdscript
var node = get_node("Path/To/Node")
var node_or_null = get_node_or_null("Path/To/Node")
```

**Сигналы:**
```gdscript
signal_name.connect(_on_signal_name)
signal_name.emit(value)
```

### Официальная документация

- **Главная документация:** https://docs.godotengine.org/ru/4.5/
- **Введение в Godot:** https://docs.godotengine.org/ru/4.5/getting_started/introduction/introduction_to_godot.html
- **GDScript:** https://docs.godotengine.org/ru/4.5/tutorials/scripting/gdscript/
- **UI система:** https://docs.godotengine.org/ru/4.5/tutorials/ui/

---

## Адаптивный UI в Godot

### Проблема: UI элементы "плывут" на разных экранах

**Причины:**
1. Неправильные настройки Viewport
2. Фиксированные координаты вместо якорей
3. Элементы не в CanvasLayer
4. Неправильный Stretch Mode

### Решение 1: Настройки Viewport в project.godot

**ПРАВИЛЬНЫЕ настройки:**
```ini
[display]
window/size/viewport_width=1154
window/size/viewport_height=650
window/stretch/mode="2d"          # или "viewport"
window/stretch/aspect="keep"      # ВАЖНО! Сохраняет пропорции
```

**НЕПРАВИЛЬНЫЕ настройки (вызывают проблемы):**
```ini
window/stretch/mode="canvas_items"  # ❌ Растягивает без сохранения пропорций
window/stretch/aspect="expand"      # ❌ Растягивает на весь экран
```

**Разница между режимами:**
- `"2d"` - масштабирует 2D элементы, сохраняя пропорции
- `"viewport"` - масштабирует весь viewport
- `"canvas_items"` - растягивает canvas_items без сохранения пропорций

**Разница между aspect:**
- `"keep"` - сохраняет пропорции (рекомендуется)
- `"expand"` - растягивает на весь экран (может искажать)
- `"ignore"` - игнорирует соотношение сторон

### Решение 2: Использование якорей (Anchors)

**Якоря привязывают элементы к краям экрана:**

```gdscript
# В .tscn файле или через код:
anchors_preset = 15  # PRESET_FULL_RECT - на весь экран
# или
anchor_left = 0.5   # Центр по горизонтали
anchor_right = 0.5
anchor_top = 1.0    # Низ экрана
anchor_bottom = 1.0
```

**Presets якорей:**
- `0` - Top Left
- `1` - Top Right
- `2` - Bottom Left
- `3` - Bottom Right
- `4` - Center Left
- `5` - Center (центр экрана)
- `6` - Center Right
- `7` - Bottom Wide
- `8` - Center Wide
- `15` - Full Rect (весь экран)

### Решение 3: Контейнеры для автоматического размещения

**Типы контейнеров:**
- `MarginContainer` - добавляет отступы
- `VBoxContainer` - вертикальное размещение
- `HBoxContainer` - горизонтальное размещение
- `GridContainer` - сетка
- `CenterContainer` - центрирование

**Пример правильной структуры:**
```
Control (anchors_preset = 15)
└── MarginContainer (anchors_preset = 15)
    └── VBoxContainer
        ├── Label
        ├── Button
        └── HBoxContainer
            ├── Button1
            └── Button2
```

### Решение 4: CanvasLayer для фиксированных UI элементов

**Проблема:** Элементы в корне сцены масштабируются с камерой

**Решение:** Переместить в CanvasLayer (TopUI)

**В Game.tscn:**
```gdscript
[node name="TopUI" type="CanvasLayer" parent="."]
layer = 128  # Высокий слой - поверх всего

[node name="MyButton" type="Button" parent="TopUI"]
anchors_preset = 1  # Правый верхний угол
anchor_left = 1.0
anchor_top = 0.0
```

**Программное перемещение (GameInitializer.gd):**
```gdscript
static func _setup_fixed_ui(controller: Node2D) -> void:
    var top_ui: Node = controller.get_node("TopUI")
    var button = controller.get_node("CardsButton")
    var global_pos: Vector2 = button.global_position
    controller.remove_child(button)
    top_ui.add_child(button)
    button.global_position = global_pos
```

### Проблема: SurvivalModeUI (сердечки) смещаются

**Текущая проблема в Game.tscn:**
```gdscript
[node name="SurvivalModeUI" parent="TopUI" instance=ExtResource("4_survival")]
offset_top = 600.0      # ❌ Фиксированная позиция!
offset_bottom = 650.0
```

**Решение:** Убрать фиксированные offset и использовать якоря

**Правильная настройка:**
```gdscript
[node name="SurvivalModeUI" parent="TopUI" instance=ExtResource("4_survival")]
anchors_preset = 5     # Центр по горизонтали
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 1.0      # Низ экрана
anchor_bottom = 1.0
offset_top = -50.0    # Отступ от низа
```

### Проблема: CardsButton (кнопка "Начать") смещается

**Текущая проблема:**
- Кнопка в корне сцены (parent=".")
- Фиксированные координаты без якорей
- Перемещается программно, но это может не работать в HTML5

**Решение:** Переместить в TopUI с правильными якорями

**Полезные ресурсы:**
- **Адаптивный UI в Godot:** https://habr.com/ru/articles/865684/
- **Размеры и якоря:** https://docs.godotengine.org/ru/4.5/tutorials/ui/size_and_anchors.html
- **Контейнеры:** https://docs.godotengine.org/ru/4.5/tutorials/ui/gui_containers.html
- **Множественные разрешения:** https://docs.godotengine.org/ru/4.5/tutorials/rendering/multiple_resolutions.html

---

## Экспорт в HTML5

### Настройки экспорта в export_presets.cfg

**Ключевые параметры:**
```ini
[preset.3.options]
variant/thread_support=false              # Многопоточность (нужен coi-serviceworker.js если true)
html/canvas_resize_policy=2               # 2 = Adaptive (рекомендуется)
html/focus_canvas_on_start=true
html/head_include="..."                   # Код для аналитики, мета-теги
```

**Canvas Resize Policy:**
- `0` - None (не адаптируется)
- `1` - Project (использует настройки проекта)
- `2` = **Adaptive** (рекомендуется для адаптивности)

### WebAssembly vs JavaScript

**WebAssembly (рекомендуется):**
- ✅ Лучшая производительность
- ✅ Поддержка многопоточности (с настройками)
- ❌ Больший размер файлов
- ❌ Требует специальные заголовки на сервере

**JavaScript:**
- ✅ Меньший размер
- ✅ Проще настройка
- ❌ Медленнее
- ❌ Нет многопоточности

**Выбор:** Используйте WebAssembly для лучшей производительности

### Настройка памяти для WebAssembly

**Проблема:** "memory access out of bounds" ошибка

**Возможные решения:**
1. Увеличить heap size в настройках экспорта
2. Проверить использование памяти в коде
3. Оптимизировать ресурсы

**Настройки в export_presets.cfg:**
```ini
threads/emscripten_pool_size=8
threads/godot_pool_size=4
```

**Полезные ресурсы:**
- **Экспорт в Web:** https://docs.godotengine.org/ru/4.5/tutorials/export/exporting_for_web.html
- **Компиляция для веб-браузера:** https://docs.godotengine.org/ru/4.5/engine_details/development/compiling/compiling_for_web.html
- **Кастомизация HTML:** https://docs.godotengine.org/ru/4.5/tutorials/platform/web/customizing_html5_shell.html

---

## Проблемы и решения

### Проблема 1: UI элементы "плывут" на разных экранах

**Симптомы:**
- Кнопки смещаются при изменении размера окна
- Элементы не на своих местах на мобильных
- Масштаб меняется, но не на весь экран

**Решения:**
1. ✅ Установить `window/stretch/aspect="keep"` в project.godot
2. ✅ Использовать якоря вместо фиксированных координат
3. ✅ Переместить UI элементы в CanvasLayer (TopUI)
4. ✅ Использовать контейнеры для автоматического размещения

### Проблема 2: "memory access out of bounds" на сервере

**Симптомы:**
- Игра работает локально, но падает на сервере
- Ошибка появляется при загрузке или во время игры

**Возможные причины:**
1. Недостаточно памяти для WebAssembly
2. Проблемы с загрузкой ресурсов
3. Ошибки в коде при работе с массивами
4. Проблемы с настройками экспорта

**Решения:**
1. Проверить размер ресурсов (120 МБ - большой размер)
2. Оптимизировать текстуры и аудио
3. Проверить логи браузера (F12)
4. Увеличить лимиты памяти в настройках экспорта
5. Проверить правильность MIME-типов на сервере

### Проблема 3: Fullscreen не работает

**Симптомы:**
- Кнопка fullscreen не переключает режим
- Ошибки в консоли браузера

**Решения:**
1. Проверить, что используется HTTPS (fullscreen требует безопасного контекста)
2. Проверить код FullscreenManager
3. Проверить поддержку браузером Fullscreen API

**Код для HTML5:**
```gdscript
func _toggle_fullscreen_html5() -> void:
    var script = """
    (function() {
        if (document.fullscreenElement) {
            document.exitFullscreen().catch(function(err) {
                console.log('Fullscreen exit error:', err);
            });
        } else {
            document.documentElement.requestFullscreen().catch(function(err) {
                console.log('Fullscreen request error:', err);
            });
        }
    })();
    """
    JavaScript.eval(script)
```

### Проблема 4: Медленная загрузка (120 МБ)

**Решения:**
1. ✅ Включить Gzip сжатие в nginx
2. ✅ Настроить кэширование
3. ✅ Использовать CDN
4. ✅ Оптимизировать ресурсы (сжать текстуры, аудио)
5. ✅ Добавить прогресс-бар загрузки

**Полезные ресурсы:**
- **Форум Godot:** https://forum.godotengine.org/
- **Godot 4.0 and HTML5 export:** https://forum.godotengine.org/t/godot-4-0-and-html5-export/1202

---

## Настройка Nginx

### Базовая конфигурация для Godot HTML5

```nginx
server {
    listen 80;
    server_name baccarat-trainer.ru;

    root /var/www/baccarat-trainer.ru;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # MIME-типы для Godot файлов
    location ~ \.wasm$ {
        add_header Content-Type application/wasm;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location ~ \.pck$ {
        add_header Content-Type application/octet-stream;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    # Gzip сжатие
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/wasm
        application/octet-stream;

    # Кэширование статических файлов
    location ~* \.(?:ico|css|js|gif|jpe?g|png|woff2?|eot|ttf|svg|otf|wasm|pck)$ {
        expires 6M;
        access_log off;
        add_header Cache-Control "public, immutable";
    }
}
```

### Важные MIME-типы

- `.wasm` → `application/wasm`
- `.pck` → `application/octet-stream`
- `.js` → `application/javascript`
- `.html` → `text/html`

### Gzip сжатие

**Настройки:**
- `gzip_comp_level 6` - баланс между сжатием и CPU
- `gzip_min_length 1000` - сжимать файлы > 1KB
- `gzip_types` - типы файлов для сжатия

**Эффективность:** Уменьшает размер в 2-3 раза (для 120 МБ это критично!)

### Кэширование

**Настройки:**
- `expires 6M` - кэш на 6 месяцев
- `Cache-Control "public, immutable"` - файлы не изменяются

**Полезные ресурсы:**
- **Nginx документация:** https://nginx.org/ru/docs/
- **Nginx для фронтенд-разработчика:** https://skillbox.ru/course/nginx/
- **Харденинг Nginx:** https://habr.com/ru/companies/bizone/articles/960586/

---

## Веб-технологии

### HTML5 для игр

**Ключевые технологии:**
- **Canvas** - область отрисовки игры
- **WebAssembly (WASM)** - скомпилированный код
- **WebGL** - графика
- **JavaScript API** - взаимодействие с браузером

### JavaScript интеграция в Godot

**Использование JavaScript.eval():**
```gdscript
func call_javascript():
    var script = "console.log('Hello from Godot!');"
    JavaScript.eval(script)
```

**Получение результата:**
```gdscript
var result = JavaScript.eval("document.fullscreenElement != null")
```

**Ограничения:**
- Работает только в HTML5 экспорте
- Асинхронные операции требуют обработки

### Fullscreen API

**JavaScript код:**
```javascript
// Войти в fullscreen
document.documentElement.requestFullscreen().catch(err => {
    console.log('Fullscreen error:', err);
});

// Выйти из fullscreen
document.exitFullscreen();
```

**Проверка состояния:**
```javascript
document.fullscreenElement != null
```

### Google Analytics интеграция

**Код для head_include в export_presets.cfg:**
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

**Отправка событий из Godot:**
```gdscript
static func track_event(event_name: String, parameters: Dictionary = {}) -> void:
    if OS.has_feature("HTML5"):
        var script = """
        (function() {
            if (typeof gtag !== 'undefined') {
                gtag('event', '%s', %s);
            }
        })();
        """ % [event_name, JSON.stringify(parameters)]
        JavaScript.eval(script)
```

**Полезные ресурсы:**
- **MDN Web Docs:** https://developer.mozilla.org/
- **WebAssembly:** https://webassembly.org/
- **Fullscreen API:** https://developer.mozilla.org/en-US/docs/Web/API/Fullscreen_API

---

## Отладка и тестирование

### Инструменты отладки

**В браузере:**
- **Chrome DevTools** (F12)
  - Console - ошибки и логи
  - Network - загрузка файлов
  - Performance - производительность
  - Application - кэш, localStorage

**В Godot:**
- Output панель - логи игры
- Remote Inspector - отладка на удалённом устройстве
- Profiler - анализ производительности

### Чеклист тестирования

**Десктоп:**
- [ ] Chrome
- [ ] Firefox
- [ ] Safari
- [ ] Edge

**Мобильные:**
- [ ] Android Chrome
- [ ] iOS Safari
- [ ] Разные разрешения экранов

**Разрешения для тестирования:**
- 1920x1080 (Full HD)
- 1366x768 (ноутбук)
- 1280x720 (HD)
- 375x667 (iPhone SE)
- 414x896 (iPhone 11)
- 360x640 (Android)

### Типичные ошибки и решения

**Ошибка: "Failed to load resource"**
- Проверить пути к файлам
- Проверить MIME-типы на сервере
- Проверить права доступа

**Ошибка: "CORS policy"**
- Добавить заголовки CORS в nginx
- Проверить настройки сервера

**Ошибка: "memory access out of bounds"**
- Проверить размер ресурсов
- Увеличить лимиты памяти
- Оптимизировать код

**Полезные ресурсы:**
- **Godot Forum:** https://forum.godotengine.org/
- **Godot Reddit:** https://www.reddit.com/r/godot/

---

## Полезные ресурсы

### Официальная документация

**Godot:**
- Главная: https://docs.godotengine.org/ru/4.5/
- UI система: https://docs.godotengine.org/ru/4.5/tutorials/ui/
- Экспорт в Web: https://docs.godotengine.org/ru/4.5/tutorials/export/exporting_for_web.html
- Множественные разрешения: https://docs.godotengine.org/ru/4.5/tutorials/rendering/multiple_resolutions.html

**Nginx:**
- Документация: https://nginx.org/ru/docs/

**Веб-технологии:**
- MDN Web Docs: https://developer.mozilla.org/
- WebAssembly: https://webassembly.org/

### Статьи и туториалы

**Адаптивный UI:**
- Адаптивный UI в Godot: https://habr.com/ru/articles/865684/
- Making Responsive UI in Godot: https://www.kodeco.com/45869762-making-responsive-ui-in-godot

**Экспорт и развёртывание:**
- Export Godot to HTML5: https://alexduggan1.github.io/Guides/ExportGodotToHTML5/
- Godot 4.0 and HTML5 export: https://forum.godotengine.org/t/godot-4-0-and-html5-export/1202

**Оптимизация:**
- Введение в оптимизацию Godot: https://habr.com/ru/articles/878784/
- Общая оптимизация: https://docs.godotengine.org/ru/4.5/tutorials/performance/general_optimization.html

### Курсы и обучение

**Godot:**
- Godot для новичков: https://career.habr.com/courses/skills/godot-engine
- Godot Engine для начинающих: https://itproger.com/course/godot

**Nginx:**
- Nginx для фронтенд-разработчика: https://skillbox.ru/course/nginx/

### Сообщества

- **Godot Forum:** https://forum.godotengine.org/
- **Godot Reddit:** https://www.reddit.com/r/godot/
- **Godot Discord:** (официальный сервер)

---

## Чеклист для решения проблем

### UI "плывёт"

- [ ] Проверить `window/stretch/aspect="keep"` в project.godot
- [ ] Проверить использование якорей вместо фиксированных координат
- [ ] Проверить, что UI элементы в CanvasLayer (TopUI)
- [ ] Проверить использование контейнеров
- [ ] Протестировать на разных разрешениях

### Ошибки памяти

- [ ] Проверить размер ресурсов
- [ ] Проверить настройки памяти в export_presets.cfg
- [ ] Проверить логи браузера (F12)
- [ ] Оптимизировать текстуры и аудио
- [ ] Проверить код на утечки памяти

### Проблемы с экспортом

- [ ] Проверить настройки экспорта
- [ ] Проверить версию экспортных шаблонов
- [ ] Протестировать локально перед загрузкой на сервер
- [ ] Проверить консоль браузера на ошибки

### Проблемы с сервером

- [ ] Проверить MIME-типы в nginx
- [ ] Проверить Gzip сжатие
- [ ] Проверить права доступа к файлам
- [ ] Проверить логи nginx
- [ ] Проверить SSL сертификат (если используется HTTPS)

---

## Быстрые ссылки

### Настройки проекта
- `project.godot` - настройки Viewport, растяжения
- `export_presets.cfg` - настройки экспорта

### Ключевые файлы проекта
- `scenes/Game.tscn` - главная сцена
- `scenes/SurvivalModeUI.tscn` - UI сердечек
- `scripts/ui/FullscreenManager.gd` - менеджер fullscreen
- `scripts/utils/AnalyticsHelper.gd` - хелпер аналитики

### Конфигурация сервера
- `deployment/nginx_config.conf` - конфигурация nginx
- `deployment/DEPLOYMENT_GUIDE.md` - руководство по развёртыванию

---

## Примечания

**Последнее обновление:** 2024
**Версия Godot:** 4.5.1
**Проект:** Baccarat Trainer

**Важно:**
- Всегда тестируйте локально перед загрузкой на сервер
- Проверяйте консоль браузера (F12) на ошибки
- Документируйте изменения
- Делайте резервные копии перед большими изменениями
