FROM python:3.12-slim

WORKDIR /code

# Системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
	gcc \
	libpq-dev \
	&& rm -rf /var/lib/apt/lists/*

# Python зависимости
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e ".[dev]"

# Alembic (миграции)
COPY alembic.ini ./
COPY ./alembic /code/alembic

# Код приложения
COPY ./app /code/app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
