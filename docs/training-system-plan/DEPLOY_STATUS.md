# 🚀 Статус деплоя сервера

> **Дата:** 2026-04-13
> **Сервер:** 147.45.103.38 (Ubuntu 24.04, Docker 29.1.5, Nginx 1.24.0)
> **Домен:** baccarat-trainer.ru (SSL ✅ Let's Encrypt)

---

## ✅ Что сделано

### 1. Файлы деплоя созданы и в Git

| Файл | Описание |
|------|----------|
| `baccarat-server/deploy/docker-compose.prod.yml` | Все сервисы: DB + Redis + API + Nginx |
| `baccarat-server/deploy/nginx/nginx.conf` | Reverse proxy (API на `/api/`, сайт на `/`) |
| `baccarat-server/deploy/.env.prod.example` | Шаблон секретов |
| `baccarat-server/deploy/deploy.sh` | Скрипт запуска |
| `baccarat-server/deploy/README.md` | Инструкция |

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
