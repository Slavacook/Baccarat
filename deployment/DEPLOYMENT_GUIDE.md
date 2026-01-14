# Руководство по развёртыванию игры на VPS

## Подготовка

### 1. Экспорт игры из Godot

1. Откройте проект в Godot 4.5.1
2. Перейдите в `Project > Export`
3. Выберите пресет "Web (HTML5)"
4. Укажите путь экспорта: `build/web/index.html`
5. Нажмите "Export Project"

### 2. Проверка экспортированных файлов

После экспорта в папке `build/web/` должны быть:
- `index.html` - главный файл
- `*.wasm` - WebAssembly файл
- `*.pck` - ресурсы игры
- `*.js` - JavaScript файлы
- Другие ресурсы (изображения, звуки и т.д.)

### 3. Локальное тестирование

Откройте `build/web/index.html` в браузере и проверьте:
- ✅ Игра загружается
- ✅ UI адаптивный (измените размер окна)
- ✅ Кнопка Fullscreen работает
- ✅ Нет ошибок в консоли (F12)

## Развёртывание на сервер

### Шаг 1: Создание директории на сервере

```bash
ssh slava@147.45.103.38
sudo mkdir -p /var/www/baccarat-trainer.ru
sudo chown -R slava:slava /var/www/baccarat-trainer.ru
```

### Шаг 2: Загрузка файлов

На локальной машине:

```bash
cd build/web
scp -r * slava@147.45.103.38:/var/www/baccarat-trainer.ru/
```

Или используйте rsync для более эффективной загрузки:

```bash
rsync -avz --progress build/web/ slava@147.45.103.38:/var/www/baccarat-trainer.ru/
```

### Шаг 3: Настройка Nginx

1. Скопируйте конфигурацию на сервер:

```bash
scp deployment/nginx_config.conf slava@147.45.103.38:/tmp/nginx_config.conf
```

2. На сервере:

```bash
ssh slava@147.45.103.38
sudo cp /tmp/nginx_config.conf /etc/nginx/sites-available/baccarat-trainer.ru
sudo ln -s /etc/nginx/sites-available/baccarat-trainer.ru /etc/nginx/sites-enabled/
sudo nginx -t  # Проверка конфигурации
sudo systemctl restart nginx
```

### Шаг 4: Проверка

Откройте в браузере: `http://baccarat-trainer.ru`

Проверьте:
- ✅ Игра загружается
- ✅ Нет ошибок 404
- ✅ Gzip сжатие работает (в DevTools > Network проверьте заголовок `Content-Encoding: gzip`)

## Настройка аналитики

### Google Analytics

1. Зарегистрируйтесь на [Google Analytics](https://analytics.google.com/)
2. Создайте новое свойство для вашего сайта
3. Получите Measurement ID (формат: `G-XXXXXXXXXX`)
4. Откройте `export_presets.cfg` в проекте
5. Найдите строку `html/head_include` и замените `G-XXXXXXXXXX` на ваш ID
6. Переэкспортируйте игру
7. Загрузите обновлённые файлы на сервер

### Яндекс.Метрика (альтернатива)

Если хотите использовать Яндекс.Метрику вместо Google Analytics:

1. Зарегистрируйтесь на [Яндекс.Метрике](https://metrika.yandex.ru/)
2. Получите код счётчика
3. Добавьте его в `html/head_include` в `export_presets.cfg`

## Обновление игры

При обновлении игры:

```bash
# 1. Экспортируйте новую версию в Godot
# 2. Загрузите файлы на сервер
rsync -avz --progress build/web/ slava@147.45.103.38:/var/www/baccarat-trainer.ru/

# 3. Очистите кэш браузера (или дождитесь истечения кэша)
# Или добавьте версионирование в URL: /v2/index.html
```

## Тестирование на разных устройствах

### Разрешения для тестирования:

- **Десктоп:**
  - 1920x1080 (Full HD)
  - 1366x768 (ноутбук)
  - 1280x720 (HD)

- **Мобильные:**
  - 375x667 (iPhone SE)
  - 414x896 (iPhone 11)
  - 360x640 (Android)

- **Планшеты:**
  - 768x1024 (iPad)
  - 1024x768 (iPad landscape)

### Браузеры для тестирования:

- Chrome (десктоп и мобильный)
- Firefox
- Safari (macOS и iOS)
- Edge

## Оптимизация (опционально)

### CDN

Для ускорения загрузки можно использовать CDN:
- [Cloudflare](https://www.cloudflare.com/) - бесплатный план
- [BunnyCDN](https://bunny.net/) - недорогой вариант

### Прогресс-бар загрузки

Для игры размером 120 МБ рекомендуется добавить прогресс-бар загрузки.
Это можно сделать через кастомный HTML шаблон в настройках экспорта.

## Устранение проблем

### Игра не загружается

1. Проверьте консоль браузера (F12) на наличие ошибок
2. Проверьте, что все файлы загружены на сервер
3. Проверьте права доступа: `sudo chmod -R 755 /var/www/baccarat-trainer.ru`

### UI "плывёт" на мобильных

1. Убедитесь, что в `project.godot` установлено:
   - `window/stretch/mode="2d"`
   - `window/stretch/aspect="keep"`
2. Проверьте, что все UI элементы используют якоря (anchors)

### Fullscreen не работает

1. Проверьте, что кнопка Fullscreen видна в TopUI
2. Проверьте консоль браузера на ошибки JavaScript
3. Убедитесь, что используется HTTPS (fullscreen требует безопасного контекста)

### Медленная загрузка

1. Проверьте, что Gzip включён: `curl -H "Accept-Encoding: gzip" -I http://baccarat-trainer.ru`
2. Рассмотрите использование CDN
3. Оптимизируйте размер ресурсов (сжатие текстур, аудио)
