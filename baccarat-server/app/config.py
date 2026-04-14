from pydantic_settings import BaseSettings
from pydantic import field_validator


class Settings(BaseSettings):
    """Настройки приложения из переменных окружения."""

    # ─── Приложение ───
    APP_NAME: str = "Baccarat Trainer Server"
    APP_ENV: str = "development"
    DEBUG: bool = True
    API_PREFIX: str = "/api"

    # ─── База данных ───
    DATABASE_URL: str = "postgresql+asyncpg://baccarat:baccarat@localhost:5432/baccarat_trainer"

    # ─── Redis ───
    REDIS_URL: str = "redis://localhost:6379/0"

    # ─── JWT ───
    JWT_SECRET_KEY: str = "dev-secret-key-change-in-production-min-32-chars!!"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    JWT_REFRESH_TOKEN_EXPIRE_DAYS_TRAINER: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS_DEALER: int = 7

    @field_validator("JWT_SECRET_KEY")
    @classmethod
    def jwt_secret_length(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("JWT secret должен быть минимум 32 символа")
        return v

    # ─── CORS ───
    CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # ─── SMTP ───
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""

    # ─── Push уведомления ───
    FCM_SERVER_KEY: str = ""
    APNS_KEY_PATH: str = ""
    APNS_KEY_ID: str = ""
    APNS_TEAM_ID: str = ""

    # ─── Sentry ───
    SENTRY_DSN: str = ""

    # ─── Логирование ───
    LOG_LEVEL: str = "DEBUG"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "extra": "ignore"}


settings = Settings()
