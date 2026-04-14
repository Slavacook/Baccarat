"""Фикстуры для тестов — PostgreSQL."""

import os
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.database import Base, get_db
from app.main import app

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://baccarat:baccarat@localhost:5432/baccarat_trainer",
)


@pytest.fixture(scope="session")
def event_loop():
    import asyncio
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def setup_db():
    """Создать таблицы один раз в начале сессии."""
    eng = create_async_engine(TEST_DATABASE_URL, echo=False)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await eng.dispose()
    yield
    # Удалить таблицы в конце
    eng = create_async_engine(TEST_DATABASE_URL, echo=False)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await eng.dispose()


@pytest.fixture
async def db_session(setup_db):
    """
    Каждый тест получает собственный движок и сессию.
    Полная изоляция — никаких конкурентных операций.
    """
    # Уникальный движок для каждого теста
    eng = create_async_engine(TEST_DATABASE_URL, echo=False, pool_size=1, max_overflow=0)

    # Чистим данные
    async with eng.begin() as conn:
        await conn.execute(text("SET session_replication_role = 'replica';"))
        for table in reversed(Base.metadata.sorted_tables):
            try:
                await conn.execute(table.delete())
            except Exception:
                pass
        await conn.execute(text("SET session_replication_role = 'origin';"))

    SessionLocal = async_sessionmaker(eng, class_=AsyncSession, expire_on_commit=False)

    async with SessionLocal() as session:
        async def override_get_db():
            yield session

        app.dependency_overrides[get_db] = override_get_db

        try:
            yield session
        finally:
            await session.close()
            app.dependency_overrides.clear()
            await eng.dispose()


@pytest.fixture
async def client(db_session):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
