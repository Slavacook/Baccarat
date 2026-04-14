import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.database import Base
# Импорт моделей для Alembic (явно, чтобы избежать конфликтов имён)
from app.models.trainer import Trainer  # noqa: F401
from app.models.room import Room, RoomStatus  # noqa: F401
from app.models.dealer import Dealer  # noqa: F401
from app.models.room_pin import RoomPin  # noqa: F401
from app.models.session import Session, SessionParticipant, SessionStatus, SessionType  # noqa: F401
from app.models.round_result import RoundResult  # noqa: F401
from app.models.async_session import AsyncSession as AsyncSessionModel, AsyncSessionStatus  # noqa: F401
from app.models.achievement import Achievement, DealerAchievement  # noqa: F401
from app.models.assignment import Assignment, AssignmentCompletion, AssignmentProgress  # noqa: F401
from app.models.push_device import PushDevice  # noqa: F401
from app.models.notification_preference import NotificationPreference  # noqa: F401
from app.models.login_attempt import LoginAttempt  # noqa: F401
from app.models.dealer_rank_history import DealerRankHistory  # noqa: F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Миграции без подключения к БД (генерация SQL)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations():
    """Асинхронные миграции."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    """Миграции с подключением к БД."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
