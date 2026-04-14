# Baccarat Trainer Server

Backend API для системы тренировки дилеров Баккара.

## 🚀 Быстрый старт

### 1. Запуск через Docker

```bash
# Скопировать .env
cp .env.example .env

# Запустить
docker compose up -d

# Проверить
curl http://localhost:8000/api/health
```

### 2. Локальная разработка

```bash
# Создать виртуальное окружение
python3.12 -m venv .venv
source .venv/bin/activate

# Установить зависимости
pip install -e ".[dev]"

# Запустить БД и Redis
docker compose up -d db redis

# Применить миграции
alembic upgrade head

# Запустить сервер
uvicorn app.main:app --reload
```

## 📁 Структура

```
app/
├── api/          # API роутеры
├── models/       # SQLAlchemy модели
├── schemas/      # Pydantic схемы
├── services/     # Бизнес-логика
├── websocket/    # WebSocket обработчики
├── workers/      # Celery задачи
├── middleware/   # Middleware
├── utils/        # Утилиты
├── exceptions/   # Исключения
├── config.py     # Настройки
├── database.py   # Подключение к БД
└── main.py       # Точка входа
```

## 📋 API Документация

После запуска: http://localhost:8000/api/docs

## 🧪 Тесты

```bash
pytest tests/ -v
pytest tests/ --cov=app --cov-report=html
```

## 📝 Миграции

```bash
# Создать миграцию
alembic revision --autogenerate -m "description"

# Применить
alembic upgrade head

# Откатить
alembic downgrade -1
```
