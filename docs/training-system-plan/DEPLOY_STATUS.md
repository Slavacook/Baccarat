# 🚀 Статус деплоя сервера

> **Сервер:** 147.45.103.38 (Ubuntu 24.04, Docker, Nginx 1.24.0)  
> **Домен:** https://baccarat-trainer.ru (SSL ✅ Let's Encrypt)

---

## Отчёт о деплое — 2026-04-24 (live-мониторинг тренера)

### Что выкатили

| Компонент | Действие |
|-----------|----------|
| **API** | На сервер скопирован `baccarat-server/app/api/sessions.py` (ретрансляция WS-событий `round_started`, `error_occurred`, `action_performed`, `round_completed` от дилера). Контейнер `deploy-api-1` пересобран и перезапущен (`docker compose … build api && up -d api`). |
| **Дашборд тренера** | Файлы `web/trainer-dashboard/` (`app.js`, `index.html`, `styles.css`) → `/var/www/dashboard/` (как в `root` сайта в `/etc/nginx/sites-available/baccarat`). |

Проверка сразу после выката: `curl -sf https://baccarat-trainer.ru/api/health` → `{"status":"ok","version":"0.1.0"}`.

### Что не выкатывалось с сервера

- **Godot-клиент** (в т.ч. `OnlineLiveEventBridge.gd`, правки `GameController.gd`) — это локальный билд/экспорт; без нового билда ученик не начнёт слать live-события. Нужно собрать проект у себя и поставить билд там, где вы тестируете (TestFlight, APK, веб и т.д.).

### Короткий чеклист проверки

1. **API жив**  
   Откройте в браузере или выполните:  
   `curl -s https://baccarat-trainer.ru/api/health`  
   Ожидание: JSON с `"status":"ok"`.

2. **Дашборд обновился**  
   Зайдите на https://baccarat-trainer.ru под тренером → жёсткое обновление страницы (Ctrl+F5 / ⌘⇧R), чтобы сбросить кэш.  
   Ожидание: на экране live-сессии есть блок **«События в реальном времени»** и чекбокс «Только ошибки».

3. **Сессия и WebSocket**  
   Создайте/откройте комнату → «Начать тренировку» → дашборд комнаты.  
   Ожидание: таблица дилеров и строка состояния сессии без ошибок в консоли (F12).

4. **Цепочка live-событий (после обновления клиента Godot)**  
   Ученик входит в онлайн-сессию с **новым** билдом, тренер смотрит дашборд.  
   Ожидание: при раздаче / ошибке / завершении раунда в ленте появляются строки; при ошибке строка дилера в таблице кратко подсвечивается.

5. **Регрессия HTTP**  
   После раунда по-прежнему уходит `POST …/round-results`, в дашборде обновляются агрегаты (раунды, ошибки).  

Если что-то из п.4 не работает при обновлённом сервере — сначала убедитесь, что у ученика именно свежий билд с `OnlineLiveEventBridge`.

---

## История: 2026-04-13 — первичный статус

> **Дата:** 2026-04-13

## ✅ Что сделано (на 2026-04-13)

### 1. Сервер ЗАПУЩЕН и РАБОТАЕТ 🎉

| Компонент         | Статус     | Детали                              |
| ----------------- | ---------- | ----------------------------------- |
| **PostgreSQL**    | ✅ healthy | 17 таблиц с Foreign Keys            |
| **Redis**         | ✅ healthy | Кэш и сессии                        |
| **API (FastAPI)** | ✅ healthy | `{"status":"ok","version":"0.1.0"}` |

**Адрес:** `http://147.45.103.38:8000`

### 2. API эндпоинты протестированы

| Эндпоинт                     | Метод | Результат                                |
| ---------------------------- | ----- | ---------------------------------------- |
| `/api/health`                | GET   | ✅ `{"status":"ok"}`                     |
| `/api/auth/trainer/register` | POST  | ✅ 201 + JWT токен                       |
| `/api/auth/trainer/login`    | POST  | ✅ 200 + токен                           |
| `/api/rooms/`                | POST  | ✅ Создана комната `TRAIN-QR7M` + 10 PIN |

### 3. Файлы деплоя в Git

| Файл                                             | Описание                                    |
| ------------------------------------------------ | ------------------------------------------- |
| `baccarat-server/deploy/docker-compose.prod.yml` | Все сервисы: DB + Redis + API + Nginx       |
| `baccarat-server/deploy/nginx/nginx.conf`        | Reverse proxy (API на `/api/`, сайт на `/`) |
| `baccarat-server/deploy/.env.prod.example`       | Шаблон секретов                             |
| `baccarat-server/deploy/deploy.sh`               | Скрипт запуска                              |
| `baccarat-server/deploy/README.md`               | Инструкция                                  |

### 2. Сервер проверен

- **OS:** Ubuntu 24.04, диск 6.4ГБ свободно
- **Docker:** 29.1.5 ✅
- **Nginx:** 1.24.0 ✅ (работает сайт baccarat-trainer.ru)
- **SSL:** Let's Encrypt ✅ (до baccarat-trainer.ru)
- **Сайт:** Godot HTML5 билд в `/var/www/html/` — НЕ ТРОГАЕМ
- **Репозиторий:** склонирован в `/root/baccarat_new/`
- **.env:** создан с случайными паролями

### 3. API сервер готов к запуску

- FastAPI приложение: `baccarat-server/app/`
- Миграции: `baccarat-server/alembic/`
- Тесты: 31/31 ✅

---

## ⏸️ Где остановились

### Блокирующая проблема: Docker Hub rate limit

**Что случилось:**
Docker Hub ограничивает бесплатные скачивания (100 раз за 6 часов с одного IP). Сервер скачивал образы слишком много раз — получил блокировку.

**Сообщение об ошибке:**

```
Error response from daemon: error from registry: You have reached your
unauthenticated pull rate limit.
```

**Что нужно для продолжения:**
На сервере (`ssh baccarat`) выполнить:

```bash
docker login
# Логин: vaaceslav
# Пароль: от Docker Hub
```

После логина — запустить:

```bash
cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml up -d --build
```

---

## 📋 План продолжения (после docker login)

1. **Запустить контейнеры** — `docker compose -f docker-compose.prod.yml up -d --build`
2. **Применить миграции** — `docker compose exec api python -m alembic upgrade head`
3. **Проверить API** — `curl http://localhost:8000/api/health`
4. **Настроить Nginx** — добавить `/api/` → API сервер, сохранив существующий сайт
5. **Обновить Godot клиент** — `base_url` в APIClient.gd на `https://baccarat-trainer.ru`

---

## 🗂️ Важно: структура сервера

```
/var/www/html/           ← Существующий сайт (Godot HTML5) — НЕ ТРОГАТЬ
/etc/nginx/sites-enabled/baccarat  ← Конфиг сайта — НЕ ТРОГАТЬ

/root/baccarat_new/baccarat-server/deploy/  ← Наши файлы деплоя
├── .env                                    ← Секреты (уже создан)
├── docker-compose.prod.yml                 ← Запуск всех сервисов
├── nginx/nginx.conf                        ← Наш Nginx конфиг
└── deploy.sh                               ← Скрипт

Порт 80, 443              ← Существующий сайт (работает)
Порт 8000 (планируется)   ← Наш API сервер (ещё не запущен)
```

---

## 📝 Следующий шаг после docker login

Одна команда на сервере:

```bash
cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml up -d --build
docker compose exec api python -m alembic upgrade head
curl http://localhost:8000/api/health
```

---

> **Фиксация:** 2026-04-13
> **Ветка:** refactoring/phase-1-step-1.1-improve-structure
> **Коммит:** f81605b (файлы деплоя)
