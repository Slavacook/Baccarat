"""Точка входа FastAPI приложения."""

from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import settings
from app.api.auth import router as auth_router
from app.api.rooms import router as rooms_router
from app.api.sessions import router as sessions_router, ws_router as sessions_ws_router


# ─── Sentry ───
if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        traces_sample_rate=0.1,
        environment=settings.APP_ENV,
    )


# ─── Lifespan ───
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Запуск и остановка приложения."""
    # Startup
    print(f"🚀 {settings.APP_NAME} запущен в режиме {settings.APP_ENV}")
    yield
    # Shutdown
    print("👋 Приложение остановлено")


# ─── Приложение ───
app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    docs_url=f"{settings.API_PREFIX}/docs",
    openapi_url=f"{settings.API_PREFIX}/openapi.json",
    lifespan=lifespan,
)

# ─── Rate Limiting ───
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

# ─── CORS ───
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["*"],
)


# ─── Роутеры ───
app.include_router(auth_router, prefix=f"{settings.API_PREFIX}/auth", tags=["Авторизация"])
app.include_router(rooms_router, prefix=settings.API_PREFIX, tags=["Комнаты"])
app.include_router(sessions_router, prefix=settings.API_PREFIX, tags=["Сессии"])
app.include_router(sessions_ws_router, tags=["WebSocket"])


# ─── Health Check ───
@app.get(f"{settings.API_PREFIX}/health")
async def health_check():
    """Проверка работоспособности."""
    return {"status": "ok", "version": "0.1.0"}
