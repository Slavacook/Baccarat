# Решения текущих проблем проекта

## Проблема 1: UI элементы смещаются (сердечки и кнопка "Начать")

### Анализ проблемы

**SurvivalModeUI (сердечки):**
- Файл: `scenes/Game.tscn`, строки 56-60
- Проблема: Используются фиксированные `offset_top = 600.0` и `offset_bottom = 650.0`
- Элемент находится в TopUI, но с фиксированными координатами

**CardsButton (кнопка "Начать"):**
- Файл: `scenes/Game.tscn`, строки 369-375
- Проблема: Кнопка в корне сцены (parent=".") с фиксированными координатами
- Перемещается программно в GameInitializer, но это может не работать в HTML5

### Решение для SurvivalModeUI

**Текущий код (НЕПРАВИЛЬНО):**
```gdscript
[node name="SurvivalModeUI" parent="TopUI" instance=ExtResource("4_survival")]
visible = true
z_index = 3
offset_top = 600.0      # ❌ Фиксированная позиция
offset_bottom = 650.0
```

**Правильный код:**
```gdscript
[node name="SurvivalModeUI" parent="TopUI" instance=ExtResource("4_survival")]
visible = true
z_index = 3
anchors_preset = 5      # Центр по горизонтали
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 1.0       # Низ экрана
anchor_bottom = 1.0
offset_top = -50.0     # Отступ от низа (50 пикселей)
offset_bottom = 0.0
grow_horizontal = 2
grow_vertical = 0
```

### Решение для CardsButton

**Вариант 1: Переместить в TopUI вручную в .tscn файле**

1. Открыть `scenes/Game.tscn` в Godot редакторе
2. Найти `CardsButton` (строки 369-375)
3. Переместить в `TopUI` через редактор
4. Установить правильные якоря:
   - `anchors_preset = 1` (Top Right) или настроить вручную
   - `anchor_left = 1.0`, `anchor_right = 1.0`
   - `anchor_top = 1.0`, `anchor_bottom = 1.0`
   - Использовать `offset_left` и `offset_top` для позиционирования

**Вариант 2: Исправить программное перемещение**

Убедиться, что в `GameInitializer.gd` правильно устанавливаются якоря после перемещения.

### Важно: window/stretch/aspect="keep"

**КРИТИЧНО:** В `project.godot` должна быть строка:
```ini
window/stretch/mode="2d"
window/stretch/aspect="keep"  # ← ЭТА СТРОКА ОБЯЗАТЕЛЬНА!
```

Без этой строки UI будет "плыть" даже с правильными якорями!

---

## Проблема 2: "memory access out of bounds" на сервере

### Анализ

**Симптомы:**
- Игра работает локально
- На сервере появляется ошибка "memory access out of bounds"
- Игра размером ~120 МБ

### Возможные причины и решения

**1. Недостаточно памяти для WebAssembly**

**Решение:** Проверить настройки памяти в `export_presets.cfg`:
```ini
threads/emscripten_pool_size=8
threads/godot_pool_size=4
```

**2. Проблемы с загрузкой ресурсов**

**Проверка:**
- Открыть консоль браузера (F12)
- Вкладка Network - проверить, все ли файлы загружаются
- Проверить ошибки 404 или другие проблемы загрузки

**3. Неправильные MIME-типы на сервере**

**Проверка nginx конфигурации:**
```nginx
location ~ \.wasm$ {
    add_header Content-Type application/wasm;
}
location ~ \.pck$ {
    add_header Content-Type application/octet-stream;
}
```

**4. Размер ресурсов слишком большой**

**Решения:**
- Оптимизировать текстуры (сжать, уменьшить разрешение)
- Оптимизировать аудио (использовать OGG, уменьшить битрейт)
- Использовать Gzip сжатие (уже настроено)

**5. Проблемы в коде**

**Проверка:**
- Искать обращения к массивам без проверки границ
- Проверить использование `Array`, `Dictionary`, `PackedArray`
- Проверить логику работы с памятью

### Диагностика

**Шаги для диагностики:**
1. Открыть игру на сервере
2. Открыть консоль браузера (F12)
3. Проверить вкладку Console на ошибки
4. Проверить вкладку Network на проблемы загрузки
5. Проверить вкладку Performance на использование памяти

**Полезные команды для проверки:**
```bash
# На сервере - проверить размер файлов
du -sh /var/www/baccarat-trainer.ru/*

# Проверить MIME-типы
curl -I https://baccarat-trainer.ru/game.wasm

# Проверить Gzip
curl -H "Accept-Encoding: gzip" -I https://baccarat-trainer.ru/game.wasm
```

---

## Проблема 3: Масштаб меняется, но не на весь экран

### Анализ

**Симптомы:**
- Игра масштабируется при изменении размера окна
- Но не заполняет весь экран
- Остаются чёрные полосы по краям

### Решение

**Настройки в project.godot:**
```ini
window/stretch/mode="2d"        # или "viewport"
window/stretch/aspect="keep"    # Сохраняет пропорции
```

**Если нужно заполнить весь экран:**
```ini
window/stretch/mode="viewport"
window/stretch/aspect="expand"  # Заполняет весь экран (может искажать)
```

**Компромиссное решение:**
- Использовать `"2d"` + `"keep"` для сохранения пропорций
- Добавить чёрные полосы (letterboxing) - это нормально для игр

---

## Пошаговый план исправления

### Шаг 1: Исправить настройки Viewport

1. Открыть `project.godot`
2. Найти секцию `[display]`
3. Убедиться, что есть строка:
   ```ini
   window/stretch/aspect="keep"
   ```
4. Если нет - добавить после `window/stretch/mode="2d"`

### Шаг 2: Исправить SurvivalModeUI

1. Открыть `scenes/Game.tscn` в Godot редакторе
2. Найти `SurvivalModeUI` в TopUI
3. Убрать фиксированные `offset_top` и `offset_bottom`
4. Установить якоря:
   - `anchors_preset = 5` (Center)
   - `anchor_top = 1.0`, `anchor_bottom = 1.0` (низ экрана)
   - `offset_top = -50.0` (отступ от низа)

### Шаг 3: Исправить CardsButton

1. Открыть `scenes/Game.tscn` в Godot редакторе
2. Найти `CardsButton` в корне сцены
3. Переместить в `TopUI` через редактор
4. Установить якоря для позиционирования в правом нижнем углу:
   - `anchors_preset = 3` (Bottom Right)
   - Или настроить вручную: `anchor_left = 1.0`, `anchor_top = 1.0`

### Шаг 4: Переэкспортировать и протестировать

1. Экспортировать игру в HTML5
2. Протестировать локально
3. Проверить на разных разрешениях
4. Загрузить на сервер
5. Протестировать на сервере

---

## Чеклист проверки

### Перед экспортом:
- [ ] `window/stretch/aspect="keep"` в project.godot
- [ ] SurvivalModeUI с правильными якорями
- [ ] CardsButton в TopUI с правильными якорями
- [ ] Все UI элементы используют якоря, а не фиксированные координаты

### После экспорта:
- [ ] Игра загружается локально
- [ ] UI не "плывёт" при изменении размера окна
- [ ] Кнопка Fullscreen работает
- [ ] Нет ошибок в консоли браузера (F12)

### На сервере:
- [ ] Все файлы загружены
- [ ] MIME-типы настроены правильно
- [ ] Gzip сжатие работает
- [ ] Нет ошибок "memory access out of bounds"
- [ ] Игра работает на разных устройствах

---

## Дополнительные советы

### Оптимизация для уменьшения размера

**Текстуры:**
- Использовать формат WebP или сжатые PNG
- Уменьшить разрешение, если возможно
- Использовать texture compression в настройках проекта

**Аудио:**
- Использовать OGG Vorbis (лучшее сжатие)
- Уменьшить битрейт
- Использовать streaming для больших файлов

**Код:**
- Минифицировать GDScript (если возможно)
- Удалить неиспользуемые ресурсы

### Мониторинг производительности

**В браузере (F12):**
- Performance tab - проверить FPS
- Network tab - проверить время загрузки
- Memory tab - проверить использование памяти

**На сервере:**
```bash
# Проверить использование ресурсов
htop

# Проверить логи nginx
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

---

## Полезные команды

### Проверка конфигурации nginx
```bash
sudo nginx -t
```

### Перезапуск nginx
```bash
sudo systemctl restart nginx
```

### Проверка прав доступа
```bash
sudo chown -R slava:slava /var/www/baccarat-trainer.ru
sudo chmod -R 755 /var/www/baccarat-trainer.ru
```

### Загрузка файлов на сервер
```bash
# С локального компьютера
rsync -avz --progress build/web/ slava@147.45.103.38:/var/www/baccarat-trainer.ru/
```

---

## Контакты и помощь

**Если проблемы остаются:**
1. Проверить логи браузера (F12 → Console)
2. Проверить логи nginx на сервере
3. Проверить форум Godot: https://forum.godotengine.org/
4. Проверить документацию: https://docs.godotengine.org/ru/4.5/
