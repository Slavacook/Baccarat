# 🚀 Деплой Baccarat Trainer Server

## Быстрый старт

### 1. Подключиться к серверу

```bash
ssh root@147.45.103.38
```

### 2. Склонировать проект

```bash
cd /root
git clone https://github.com/Slavacook/Baccarat.git baccarat-server
cd baccarat-server/baccarat-server/deploy
```

### 3. Создать .env

```bash
cp .env.prod.example .env
```

**Заполни секреты:**

```bash
# Генерация случайных паролей
python3 -c "import secrets; print('DB_PASSWORD=' + secrets.token_urlsafe(48))"
python3 -c "import secrets; print('REDIS_PASSWORD=' + secrets.token_urlsafe(48))"
python3 -c "import secrets; print('JWT_SECRET_KEY=' + secrets.token_urlsafe(64))"
```

Добавь в `.env`:
```
DB_PASSWORD=...
REDIS_PASSWORD=...
JWT_SECRET_KEY=...
```

### 4. Запустить

```bash
bash deploy.sh
```

### 5. Проверить

```bash
curl http://localhost:8000/api/health
# → {"status":"ok","version":"0.1.0"}
```

---

## Структура

```
deploy/
├── docker-compose.prod.yml   # Все сервисы (DB + Redis + API + Nginx)
├── nginx/
│   └── nginx.conf            # Reverse proxy + SSL
├── .env.prod.example         # Шаблон .env
├── deploy.sh                 # Скрипт запуска
└── README.md                 # Этот файл
```

---

## Сервисы

| Сервис | Порт | Описание |
|--------|------|----------|
| **Nginx** | 80, 443 | Reverse proxy + SSL |
| **API** | 8000 (внутри) | FastAPI сервер |
| **PostgreSQL** | 5432 (внутри) | База данных |
| **Redis** | 6379 (внутри) | Кэш + сессии |

---

## Полезные команды

```bash
# Посмотреть логи
docker compose -f docker-compose.prod.yml logs -f api

# Перезапустить API
docker compose -f docker-compose.prod.yml restart api

# Применить миграции вручную
docker compose -f docker-compose.prod.yml exec api python -m alembic upgrade head

# Остановить всё
docker compose -f docker-compose.prod.yml down

# Остановить + удалить данные
docker compose -f docker-compose.prod.yml down -v
```

---

## SSL (Let's Encrypt)

Для SSL нужен **домен**, привязанный к IP сервера.

1. Привяжи домен к `147.45.103.38`
2. В `nginx.conf` замени `server_name _;` на `server_name твой-домен.ru;`
3. В `.env` укажи `DOMAIN=твой-домен.ru`
4. Получи сертификат:

```bash
docker compose -f docker-compose.prod.yml run --rm certbot \
  certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  -d твой-домен.ru \
  --email admin@твой-домен.ru \
  --agree-tos --no-eff-email
```

5. В `nginx.conf` замени пути сертификатов на:
```
ssl_certificate /etc/letsencrypt/live/твой-домен.ru/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/твой-домен.ru/privkey.pem;
```

6. Перезапусти Nginx:
```bash
docker compose -f docker-compose.prod.yml restart nginx
```

---

## Обновление Godot клиента

В `scripts/network/APIClient.gd` измени:

```gdscript
@export var base_url: String = "https://твой-домен.ru"
# или
@export var base_url: String = "http://147.45.103.38"  # без SSL
```

---

## Устранение проблем

### API не запускается
```bash
docker compose -f docker-compose.prod.yml logs api
```

### БД не подключается
```bash
docker compose -f docker-compose.prod.yml logs db
```

### Миграции не применены
```bash
docker compose -f docker-compose.prod.yml exec api python -m alembic upgrade head
```

### Полная очистка
```bash
docker compose -f docker-compose.prod.yml down -v
rm -f .env
bash deploy.sh
```
