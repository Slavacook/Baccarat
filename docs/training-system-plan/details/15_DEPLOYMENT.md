# Детализация: Деплой и запуск

> **Раздел плана:** 15.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Разделы 1-14 (все предыдущие)

---

## 1. Инфраструктура сервера

### 1.1 Архитектура продакшена

```
                    ┌─────────────────────────────────────────┐
                    │           INTERNET                      │
                    └──────────────┬──────────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────────┐
                    │           Nginx (Reverse Proxy)          │
                    │  • SSL (Let's Encrypt)                   │
                    │  • HTTP → HTTPS redirect                 │
                    │  • Gzip compression                      │
                    │  • Rate limiting (базовое)               │
                    └──────────────┬──────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
    ┌─────────▼──────┐  ┌────────▼─────────┐  ┌───────▼────────┐
    │   FastAPI App  │  │  FastAPI App     │  │  FastAPI App   │
    │   (worker 1)   │  │  (worker 2)      │  │  (worker 3)    │
    │   Uvicorn      │  │  Uvicorn         │  │  Uvicorn       │
    └─────────┬──────┘  └────────┬─────────┘  └───────┬────────┘
              │                  │                    │
              └──────────────────┼────────────────────┘
                                 │
              ┌──────────────────┼────────────────────┐
              │                  │                    │
    ┌─────────▼──────┐  ┌───────▼────────┐  ┌───────▼────────┐
    │   PostgreSQL   │  │    Redis       │  │   Celery       │
    │   (main DB)    │  │   (cache +     │  │   Worker       │
    │                │  │    queue)       │  │   (tasks)      │
    └────────────────┘  └────────────────┘  └────────────────┘
```

### 1.2 Минимальные требования к серверу

| Компонент | Минимум | Рекомендуемый |
|-----------|---------|---------------|
| CPU | 2 ядра | 4 ядра |
| RAM | 4 GB | 8 GB |
| SSD | 20 GB | 50 GB |
| ОС | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| Домен | baccarat-trainer.com | baccarat-trainer.com + subdomains |

### 1.3 Docker Compose (продакшен)

```yaml
# docker-compose.prod.yml
version: "3.9"

services:
  nginx:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - api
    restart: always

  api:
    build:
      context: .
      dockerfile: Dockerfile.prod
    environment:
      - DATABASE_URL=postgresql+asyncpg://baccarat:${DB_PASSWORD}@db:5432/baccarat_trainer
      - REDIS_URL=redis://redis:6379/0
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
      - APNS_KEY_PATH=/run/secrets/apns_key.p8
      - FCM_SERVER_KEY=${FCM_SERVER_KEY}
      - SENTRY_DSN=${SENTRY_DSN}
    secrets:
      - apns_key
    depends_on:
      - db
      - redis
    deploy:
      replicas: 3
    restart: always

  celery-worker:
    build:
      context: .
      dockerfile: Dockerfile.prod
    command: celery -A app.workers.celery_app worker --loglevel=info --concurrency=4
    environment:
      - DATABASE_URL=postgresql+asyncpg://baccarat:${DB_PASSWORD}@db:5432/baccarat_trainer
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    restart: always

  celery-beat:
    build:
      context: .
      dockerfile: Dockerfile.prod
    command: celery -A app.workers.celery_app beat --loglevel=info
    environment:
      - DATABASE_URL=postgresql+asyncpg://baccarat:${DB_PASSWORD}@db:5432/baccarat_trainer
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - redis
    restart: always

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: baccarat
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: baccarat_trainer
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"  # Только localhost
    restart: always

  redis:
    image: redis:7-alpine
    ports:
      - "127.0.0.1:6379:6379"  # Только localhost
    restart: always

volumes:
  postgres_data:

secrets:
  apns_key:
    file: ./secrets/apns_key.p8
```

### 1.4 Nginx конфигурация

```nginx
# nginx.conf
upstream api_servers {
    server api:8000;
}

server {
    listen 80;
    server_name api.baccarat-trainer.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.baccarat-trainer.com;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # WebSocket поддержка
    location /ws/ {
        proxy_pass http://api_servers;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;  # 24 часа для WebSocket
    }

    # API
    location /api/ {
        proxy_pass http://api_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting
        limit_req zone=api burst=20 nodelay;
    }

    # Swagger документация
    location /docs {
        proxy_pass http://api_servers/docs;
    }

    # Gzip
    gzip on;
    gzip_types text/plain application/json application/javascript text/css;
    gzip_min_length 1000;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
```

---

## 2. Публикация в App Store (iOS)

### 2.1 Требования

| Компонент | Описание |
|-----------|----------|
| Apple Developer аккаунт | $99/год, enrol в Apple Developer Program |
| Bundle Identifier | com.baccarat.trainer |
| App Icon | 1024x1024 PNG (без прозрачности) |
| Скриншоты | 6.7", 5.5", 12.9" (минимум 2 на каждый) |
| Описание | До 4000 символов |
| Keywords | До 100 символов |
| Privacy Policy URL | URL политики конфиденциальности |
| Support URL | URL поддержки |

### 2.2 Процесс публикации

```
1. Архивировать в Xcode:
   Product → Archive

2. Загрузить в App Store Connect:
   Distribute App → App Store Connect → Upload

3. Заполнить информацию в App Store Connect:
   - Название: Baccarat Trainer
   - Подзаголовок: Тренажёр для дилеров
   - Описание: (текст о приложении)
   - Keywords: baccarat, dealer, training, casino, cards
   - Категория: Education / Games
   - Возрастной рейтинг: 17+ (казино тематика, но нет реальных ставок)
   - Скриншоты: загрузить для всех размеров

4. Отправить на ревью:
   - Заполнить форму ревью
   - Указать: "Нет реальных ставок, только обучение"
   - Приложить демо-аккаунт (если требуется)

5. Ожидать ревью (1-3 дня)

6. Одобрено → Публикация
   или
   Отклонено → Исправить → Переотправить
```

### 2.3 Ключевые моменты для ревью

| Риск | Решение |
|------|---------|
| Казино тематика | Чётко указать: "Обучающее приложение, нет реальных ставок" |
| Локализация | Поддержка EN + RU |
| Производительность | 60 FPS, < 500MB RAM |
| Privacy | Политика конфиденциальности на сайте |
| Доступность | VoiceOver, Dynamic Type |

### 2.4 Метаданные App Store

```
Название: Baccarat Trainer
Подзаголовок: Casino Dealer Training
Описание:
Baccarat Trainer is an educational app for casino dealers and croupiers. 
Practice third-card rules, payout calculations, and winner determination.

Features:
• Realistic Baccarat gameplay with 8-deck shoe
• Survival mode with 7 lives
• Multiplayer training rooms
• Leaderboards and achievements
• Bilingual: English / Russian

This is an educational app. No real money gambling.

Keywords: baccarat,dealer,training,casino,cards,learn,practice
Категория: Education
Возраст: 17+
```

---

## 3. Публикация в Google Play (Android)

### 3.1 Требования

| Компонент | Описание |
|-----------|----------|
| Google Play Developer аккаунт | $25 (единоразово) |
| Application ID | com.baccarat.trainer |
| App Icon | 512x512 PNG |
| Скриншоты | Минимум 2 (телефон), до 8 |
| Описание | До 4000 символов |
| Privacy Policy URL | URL политики конфиденциальности |
| Content Rating questionnaire | Заполнить в Google Play Console |

### 3.2 Процесс публикации

```
1. Собрать AAB (Android App Bundle):
   godot --path . --export-release "Android" build/baccarat.aab

2. Подписать AAB:
   jarsigner -keystore baccarat.keystore build/baccarat.aab baccarat

3. Загрузить в Google Play Console:
   Create App → Upload AAB

4. Заполнить информацию:
   - Название: Baccarat Trainer
   - Короткое описание: Casino dealer training simulator
   - Полное описание: (как в App Store)
   - Категория: Education
   - Content Rating: заполнить questionnaire
   - Privacy Policy: URL

5. Отправить на ревью

6. Ожидать (1-7 дней для нового аккаунта)

7. Одобрено → Публикация
```

---

## 4. CI/CD пайплайн

### 4.1 GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]
    tags:
      - "v*"

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Install dependencies
        run: pip install -e ".[dev]"
      - name: Run tests
        run: pytest tests/unit/ -v --cov=app --cov-fail-under=80
      - name: Run linting
        run: |
          ruff check app/
          mypy app/

  build-server:
    needs: test
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t baccarat-server:${{ github.ref_name }} .
      - name: Push to registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push baccarat-server:${{ github.ref_name }}

  deploy-server:
    needs: build-server
    runs-on: ubuntu-latest
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/baccarat-trainer
            docker compose pull
            docker compose up -d
            docker system prune -f

  build-ios:
    needs: test
    runs-on: macos-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v4
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.3.0
      - name: Export iOS
        run: godot --path . --export-debug "iOS" build/ios/
      - name: Upload to TestFlight
        run: xcrun altool --upload-app -f build/ios/Baccarat.ipa ...

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v4
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.3.0
      - name: Export Android
        run: godot --path . --export-release "Android" build/android/baccarat.aab
      - name: Upload to Google Play
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SA }}
          packageName: com.baccarat.trainer
          releaseFiles: build/android/baccarat.aab
          track: internal
```

---

## 5. Мониторинг

### 5.1 Компоненты мониторинга

| Компонент | Инструмент | Что мониторим |
|-----------|------------|---------------|
| Ошибки приложения | **Sentry** | Stack traces, context, user info |
| Метрики сервера | **Prometheus + Grafana** | CPU, RAM, response time, error rate |
| Логи | **Loki + Grafana** | Структурированные логи |
| Uptime | **UptimeRobot** | Доступность API и WebSocket |
| Бэкапы БД | **pg_dump + cron** | Ежедневный бэкап |
| Метрики Godot | **Custom** | FPS, memory, crash rate |

### 5.2 Sentry интеграция (сервер)

```python
# app/main.py
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration

sentry_sdk.init(
    dsn=settings.SENTRY_DSN,
    integrations=[FastApiIntegration()],
    traces_sample_rate=0.1,  # 10% запросов для трейсинга
    environment=settings.APP_ENV,
)
```

### 5.3 Sentry интеграция (Godot)

```gdscript
# scripts/utils/CrashReporter.gd
class_name CrashReporter
extends Node

func _ready() -> void:
    # Ловим крэши
    var error_logger = FileAccess.open("user://crash_log.txt", FileAccess.READ_WRITE)
    
    # При старте проверить, есть ли предыдущий крэш-лог
    if FileAccess.file_exists("user://crash_log.txt"):
        var log = FileAccess.get_file_as_string("user://crash_log.txt")
        if log != "":
            _send_crash_report(log)

func _send_crash_report(log: String) -> void:
    if not AuthManager.access_token:
        return
    
    var api = APIClient.new()
    api.set_auth_token(AuthManager.access_token)
    api.post("/api/crash-reports", {
        "log": log,
        "app_version": ProjectSettings.get_setting("application/config/version"),
        "os": OS.get_name(),
        "os_version": OS.get_version()
    })
    
    # Очистить лог
    var file = FileAccess.open("user://crash_log.txt", FileAccess.WRITE)
    file.close()
```

### 5.4 Алёрты

| Событие | Канал | Критичность |
|---------|-------|-------------|
| API недоступен > 5 мин | SMS + Slack | 🔴 Критично |
| Error rate > 5% | Slack | 🟡 Предупреждение |
| CPU > 90% > 10 мин | Slack | 🟡 Предупреждение |
| RAM > 90% > 10 мин | Slack | 🟡 Предупреждение |
| Бэкап не создан | Email | 🟡 Предупреждение |
| Новый крэш-лог | Sentry dashboard | ⚪ Информация |

---

## 6. Бэкапы

### 6.1 Стратегия

| Что | Частота | Хранение | Метод |
|-----|---------|----------|-------|
| PostgreSQL | Ежедневно (3:00 UTC) | 30 дней | pg_dump → S3 |
| Redis | Не бэкапится (кэш) | — | Пересоздаётся |
| Файлы (секреты, конфиги) | При изменении | Бессрочно | Git + S3 |
| Логи | Ежедневно | 90 дней | Loki retention |

### 6.2 Скрипт бэкапа

```bash
#!/bin/bash
# scripts/backup.sh
set -e

BACKUP_DIR="/tmp/backups"
S3_BUCKET="baccarat-trainer-backups"
DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="baccarat_${DATE}.sql.gz"

mkdir -p $BACKUP_DIR

# Бэкап PostgreSQL
pg_dump -U baccarat -h db -d baccarat_trainer | gzip > $BACKUP_DIR/$FILENAME

# Загрузить в S3
aws s3 cp $BACKUP_DIR/$FILENAME s3://$S3_BUCKET/$FILENAME

# Удалить локальные файлы старше 7 дней
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

# Удалить S3 файлы старше 30 дней
aws s3 ls s3://$S3_BUCKET/ | awk '{print $4}' | while read file; do
    FILE_DATE=$(echo $file | grep -o '[0-9]\{8\}')
    if [ -n "$FILE_DATE" ]; then
        DAYS_OLD=$(( ($(date +%s) - $(date -d $FILE_DATE +%s)) / 86400 ))
        if [ $DAYS_OLD -gt 30 ]; then
            aws s3 rm s3://$S3_BUCKET/$file
        fi
    fi
done

echo "Backup completed: $FILENAME"
```

### 6.3 Cron job

```bash
# /etc/crontab
0 3 * * * /opt/baccarat-trainer/scripts/backup.sh >> /var/log/backup.log 2>&1
```

---

## 7. План отката (rollback)

### 7.1 Сервер

```bash
# Откат на предыдущую версию
cd /opt/baccarat-trainer
docker compose down
docker tag baccarat-server:latest baccarat-server:broken
docker tag baccarat-server:previous baccarat-server:latest
docker compose up -d

# Проверить
curl https://api.baccarat-trainer.com/api/health
```

### 7.2 Мобильные приложения

| Платформа | Откат |
|-----------|-------|
| iOS | Нельзя откатить опубликованную версию. Следующая версия с фиксом. |
| Android | Можно откатить в Google Play Console (если < 24 часов) |

---

## 8. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Инфраструктура сервера (хостинг, домен, SSL, firewall) | ✅ Завершено |
| 2 | Процесс публикации в App Store | ✅ Завершено |
| 3 | Процесс публикации в Google Play | ✅ Завершено |
| 4 | CI/CD пайплайн (GitHub Actions) | ✅ Завершено |
| 5 | Система мониторинга (логи, метрики, алерты, дашборд сервера) | ✅ Завершено |
| 6 | Бэкапы и восстановление | ✅ Завершено |
| 7 | План отката (rollback) | ✅ Завершено |

**Раздел 15: Деплой и запуск — детализация завершена полностью (7/7 пунктов).**

---

> **Этот документ — финальная детализация раздела 15.1 "Деплой и запуск".**  
> **Все 15 разделов детализированы!** 🎉
