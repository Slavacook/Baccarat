# Детализация: Безопасность и защита от читерства

> **Раздел плана:** 13.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Разделы 1-9 (Авторизация — Серверная часть)

---

## 1. Обзор

Безопасность обеспечивает честность тренировки, защиту данных пользователей и устойчивость системы к злонамеренным действиям. Включает детекцию читерства, валидацию результатов, rate limiting и политику хранения данных.

---

## 2. Детекция читерства

### 2.1 Паттерны читерства

| Паттерн | Описание | Как детектировать | Действие |
|---------|----------|-------------------|----------|
| **Аномально быстрая игра** | Все раунды < 3 сек | `AVG(time_spent) < 3` | Флаг + ручная проверка |
| **Идеальная точность 100% на высокой скорости** | 100% точность при < 5 сек/раунд | `accuracy == 100 AND avg_time < 5` | Флаг + ручная проверка |
| **Одинаковые ответы** | Все решения одинаковые (всегда "да" или всегда "нет") | `STDDEV(decision_variety) < threshold` | Флаг |
| **Аномальный рост XP** | Слишком быстрый набор XP | `xp_per_hour > threshold` | Флаг + временная блокировка |
| **Бот-паттерн** | Решения принимаются через одинаковые интервалы | `STDDEV(time_between_decisions) < threshold` | Флаг |
| **Подделка результатов** | Клиент отправляет неверифицируемые данные | HMAC подпись не совпадает | Отклонить + флаг |
| **Мультиаккаунт** | Один человек с несколькими аккаунтами | Один IP + разные PIN-ы | Ручная проверка |

### 2.2 Алгоритм детекции

```python
# server/services/cheat_detection_service.py
class CheatDetectionService:
    
    # Пороги
    MIN_ROUND_TIME = 3.0  # сек
    SUSPICIOUS_AVG_TIME = 5.0  # сек
    MAX_XP_PER_HOUR = 5000  # XP/час
    MIN_DECISION_VARIETY = 0.3  # 30% разнообразия решений
    
    async def analyze_dealer(self, dealer_id: UUID) -> dict:
        """Проанализировать поведение дилера на признаки читерства."""
        stats = self._get_recent_stats(dealer_id, hours=24)
        flags = []
        
        # Проверка скорости
        if stats["avg_time"] < self.MIN_ROUND_TIME:
            flags.append({
                "type": "impossible_speed",
                "severity": "critical",
                "value": stats["avg_time"],
                "threshold": self.MIN_ROUND_TIME,
                "message": f"Невозможная скорость: {stats['avg_time']}с/раунд (мин: {self.MIN_ROUND_TIME}с)"
            })
        elif stats["avg_time"] < self.SUSPICIOUS_AVG_TIME:
            flags.append({
                "type": "suspicious_speed",
                "severity": "warning",
                "value": stats["avg_time"],
                "threshold": self.SUSPICIOUS_AVG_TIME,
                "message": f"Подозрительная скорость: {stats['avg_time']}с/раунд"
            })
        
        # Проверка 100% точности на высокой скорости
        if stats["accuracy"] == 100 and stats["avg_time"] < self.SUSPICIOUS_AVG_TIME:
            flags.append({
                "type": "perfect_fast",
                "severity": "critical",
                "message": f"100% точность при скорости {stats['avg_time']}с/раунд"
            })
        
        # Проверка разнообразия решений
        if stats["decision_variety"] < self.MIN_DECISION_VARIETY and stats["rounds"] > 20:
            flags.append({
                "type": "no_variety",
                "severity": "warning",
                "value": stats["decision_variety"],
                "message": f"Низкое разнообразие решений: {stats['decision_variety']*100:.0f}%"
            })
        
        # Проверка скорости набора XP
        xp_per_hour = stats["total_xp"] / max(stats["hours_active"], 1)
        if xp_per_hour > self.MAX_XP_PER_HOUR:
            flags.append({
                "type": "xp_spike",
                "severity": "warning",
                "value": xp_per_hour,
                "threshold": self.MAX_XP_PER_HOUR,
                "message": f"Аномальный набор XP: {xp_per_hour:.0f}/час (макс: {self.MAX_XP_PER_HOUR})"
            })
        
        # Проверка бот-паттерна (одинаковые интервалы)
        if stats["time_stddev"] < 0.5 and stats["rounds"] > 30:
            flags.append({
                "type": "bot_pattern",
                "severity": "warning",
                "value": stats["time_stddev"],
                "message": f"Подозрительно равномерные интервалы: σ={stats['time_stddev']:.2f}с"
            })
        
        # Определить общий уровень риска
        critical_count = sum(1 for f in flags if f["severity"] == "critical")
        warning_count = sum(1 for f in flags if f["severity"] == "warning")
        
        if critical_count >= 1:
            risk_level = "high"
        elif warning_count >= 3:
            risk_level = "medium"
        elif warning_count >= 1:
            risk_level = "low"
        else:
            risk_level = "none"
        
        return {
            "dealer_id": dealer_id,
            "risk_level": risk_level,
            "flags": flags,
            "analyzed_at": datetime.utcnow().isoformat()
        }
    
    async def check_result_signature(self, result: dict, session_id: UUID) -> bool:
        """Проверить подпись результата (антиподделка)."""
        session = db.query(Session).get(session_id)
        if not session:
            return False
        
        expected_signature = sign_round_result(result, session.master_seed)
        client_signature = result.get("signature", "")
        
        return hmac.compare_digest(expected_signature, client_signature)
```

### 2.3 Действия при обнаружении

| Уровень риска | Действие | Автоматическое? |
|---------------|----------|-----------------|
| **none** | Ничего | — |
| **low** | Логирование + уведомление тренера | ✅ Да |
| **medium** | Временная блокировка таблицы лидеров (24 часа) | ✅ Да |
| **high** | Блокировка аккаунта + уведомление тренера | ✅ Да, но тренер может разблокировать |

### 2.4 UI флага читерства (дашборд тренера)

```
┌─────────────────────────────────────────────────────────┐
│  ⚠️ Обнаружена подозрительная активность                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Дилер: Морозова О.                                     │
│  Уровень риска: 🔴 Высокий                              │
│                                                         │
│  Обнаруженные аномалии:                                 │
│  ┌───────────────────────────────────────────────────┐ │
│  │ 🔴 100% точность при скорости 4с/раунд            │ │
│  │ ⚠️  Низкое разнообразие решений: 15%              │ │
│  │ ⚠️  Аномальный набор XP: 6,200/час                 │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  [🔓 Разблокировать]  [🚫 Заблокировать]  [📋 Подробнее]│
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Защита от подделки результатов

### 3.1 HMAC-подпись

```python
# server/utils/result_signature.py
import hashlib
import hmac

def sign_round_result(result: dict, master_seed: str) -> str:
    """Создать подпись результата на сервере."""
    # Сериализуем ключевые поля
    payload = ":".join([
        str(result["round_number"]),
        str(result["accuracy"]),
        str(result["time_spent_seconds"]),
        str(result.get("player_third_card", "")),
        str(result.get("banker_third_card", "")),
        str(result.get("winner_chosen", "")),
        master_seed
    ])
    
    return hmac.new(
        master_seed.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()[:16]  # Укороченная подпись

def verify_result(result: dict, master_seed: str, client_signature: str) -> bool:
    """Проверить подпись результата."""
    expected = sign_round_result(result, master_seed)
    return hmac.compare_digest(expected, client_signature)
```

### 3.2 Верификация на сервере

```python
# server/middleware/result_validation.py
class ResultValidationMiddleware:
    
    async def validate_round_result(self, result: dict, session_id: UUID) -> bool:
        """Валидировать результат раунда."""
        
        # 1. Проверка подписи
        session = db.query(Session).get(session_id)
        if not verify_result(result, session.master_seed, result.get("signature", "")):
            return False
        
        # 2. Проверка времени
        if result["time_spent_seconds"] < 3:
            return False
        
        # 3. Проверка последовательности раундов
        last_round = self._get_last_round(session_id, result["dealer_id"])
        if result["round_number"] != (last_round or 0) + 1:
            return False
        
        # 4. Проверка диапазона точности
        if not (0 <= result["accuracy"] <= 100):
            return False
        
        # 5. Проверка timestamp (не в будущем, не старше 24 часов)
        client_time = datetime.fromisoformat(result["client_timestamp"])
        now = datetime.utcnow()
        if client_time > now + timedelta(seconds=30):
            return False
        if client_time < now - timedelta(hours=24):
            return False
        
        return True
```

---

## 4. Rate limiting

### 4.1 Таблица лимитов

| Эндпоинт | Лимит | Окно | Почему |
|----------|-------|------|--------|
| POST /auth/trainer/login | 5 | 5 минут | Защита от брута паролей |
| POST /auth/trainer/register | 3 | 10 минут | Защита от спама регистраций |
| POST /auth/dealer/join | 10 | 5 минут | Защита от перебора PIN |
| POST /auth/refresh | 10 | 1 час | Защита от misuse refresh |
| POST /api/rooms | 5 | 1 час | Лимит создания комнат |
| POST /api/rooms/{code}/settings | 10 | 10 минут | Защита от спама изменений |
| POST /api/async-sessions/{id}/results | 60 | 1 минута | Макс. 1 раунд/сек |
| GET /api/rooms/{code}/leaderboard | 30 | 1 минута | Защита от спама запросов |

### 4.2 Реализация (SlowAPI)

```python
# app/main.py
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request, exc):
    return JSONResponse(
        status_code=429,
        content={
            "error": {
                "code": "RATE_LIMITED",
                "message": "Слишком много запросов. Попробуйте позже.",
                "retry_after": exc.detail.split(":")[0] if ":" in exc.detail else 60
            }
        }
    )

# Применение к эндпоинтам
@app.post("/api/auth/trainer/login")
@limiter.limit("5/5minutes")
async def trainer_login(request: Request, ...):
    ...
```

---

## 5. Валидация данных

### 5.1 На уровне API (Pydantic)

```python
# app/schemas/round_result.py
from pydantic import BaseModel, field_validator

class RoundResultRequest(BaseModel):
    round_number: int
    accuracy: float
    errors: list = []
    time_spent_seconds: float
    player_third_card: bool | None = None
    banker_third_card: bool | None = None
    winner_chosen: str | None = None
    winner_correct: bool
    payout_correct: bool
    lives_remaining: int | None = None
    client_timestamp: str
    
    @field_validator("accuracy")
    def accuracy_range(cls, v):
        if not (0 <= v <= 100):
            raise ValueError("Accuracy must be between 0 and 100")
        return v
    
    @field_validator("time_spent_seconds")
    def min_time(cls, v):
        if v < 3:
            raise ValueError("Minimum round time is 3 seconds")
        return v
    
    @field_validator("winner_chosen")
    def winner_value(cls, v):
        if v is not None and v not in ["Player", "Banker", "Tie"]:
            raise ValueError("Winner must be Player, Banker, or Tie")
        return v
    
    @field_validator("client_timestamp")
    def timestamp_not_future(cls, v):
        client_time = datetime.fromisoformat(v)
        if client_time > datetime.utcnow() + timedelta(seconds=30):
            raise ValueError("Timestamp cannot be in the future")
        return v
```

### 5.2 На уровне бизнес-логики

```python
# server/validators/round_result.py
class RoundResultValidator:
    
    def validate(self, result: dict, session: Session, dealer: Dealer) -> list:
        """Валидировать результат раунда на уровне бизнес-логики."""
        errors = []
        
        # Проверить, что сессия активна
        if session.status != "active":
            errors.append("Session is not active")
        
        # Проверить, что дилер в этой сессии
        participant = db.query(SessionParticipant).filter_by(
            session_id=session.id,
            dealer_id=dealer.id
        ).first()
        if not participant:
            errors.append("Dealer is not participant of this session")
        
        # Проверить лимит раундов сессии
        if session.max_rounds and participant.rounds_completed >= session.max_rounds:
            errors.append("Session round limit reached")
        
        # Проверить дневной лимит дилера
        daily_rounds = self._get_daily_rounds(dealer.id)
        if daily_rounds >= 500:
            errors.append("Daily round limit reached")
        
        return errors
```

---

## 6. Шифрование

### 6.1 HTTPS (обязательно)

| Компонент | Настройка |
|-----------|-----------|
| Сервер | Nginx с SSL-сертификатом (Let's Encrypt) |
| Godot-клиент | HTTPS по умолчанию, проверка сертификата |
| WebSocket | WSS (WebSocket Secure) |
| API | Только HTTPS, редирект с HTTP |

### 6.2 Хранение чувствительных данных

| Данные | Метод защиты |
|--------|--------------|
| Пароли тренеров | bcrypt (стоимость 12) |
| PIN-коды дилеров | bcrypt (стоимость 10) |
| JWT секреты | Environment variables, не в коде |
| Device tokens | Хранятся в БД, без шифрования (не чувствительные) |
| Логи | Без персональных данных (email, PIN) |

### 6.3 Защита JWT

```python
# app/config.py
class Settings(BaseSettings):
    JWT_SECRET_KEY: str  # Минимум 32 символа, случайный
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    JWT_REFRESH_TOKEN_EXPIRE_DAYS_TRAINER: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS_DEALER: int = 7
    
    @validator("JWT_SECRET_KEY")
    def jwt_secret_length(cls, v):
        if len(v) < 32:
            raise ValueError("JWT secret must be at least 32 characters")
        return v
```

---

## 7. Политика хранения данных (GDPR)

### 7.1 Сроки хранения

| Тип данных | Срок | Действие после |
|------------|------|----------------|
| Аккаунт тренера | Бессрочно (пока активен) | Удаление по запросу |
| PIN-коды | Пока комната active | Удаление при закрытии комнаты |
| Результаты раундов | 2 года | Анонимизация |
| Закрытые комнаты | 90 дней | Полное удаление |
| Логи попыток входа | 1 час | Автоудаление (cron) |
| Device tokens | Бессрочно (пока активен) | Удаление при отзыве |
| Уведомления | 30 дней | Удаление |

### 7.2 Право на удаление

```python
# server/services/data_deletion_service.py
class DataDeletionService:
    
    async def delete_trainer_account(self, trainer_id: UUID) -> dict:
        """Удалить аккаунт тренера и все связанные данные."""
        result = {"deleted": {"rooms": 0, "dealers": 0, "sessions": 0, "results": 0}}
        
        # Удалить комнаты (каскад)
        rooms = db.query(Room).filter_by(trainer_id=trainer_id).all()
        result["deleted"]["rooms"] = len(rooms)
        
        for room in rooms:
            result["deleted"]["dealers"] += db.query(Dealer).filter_by(room_id=room.id).count()
            result["deleted"]["sessions"] += db.query(Session).filter_by(room_id=room.id).count()
        
        # Удалить тренера
        db.query(Trainer).filter_by(id=trainer_id).delete()
        
        db.commit()
        
        return result
    
    async def delete_dealer(self, dealer_id: UUID) -> dict:
        """Удалить дилера (но сохранить анонимизированные результаты)."""
        # Анонимизировать результаты
        db.execute(
            """
            UPDATE round_results 
            SET dealer_id = NULL 
            WHERE dealer_id = :id
            """,
            {"id": dealer_id}
        )
        
        # Удалить дилера
        db.query(Dealer).filter_by(id=dealer_id).delete()
        
        db.commit()
        
        return {"deleted": True, "results_anonymized": True}
```

---

## 8. Аудит безопасности

### 8.1 Чеклист перед запуском

| Проверка | Статус | Ответственный |
|----------|--------|---------------|
| HTTPS включён на всех эндпоинтах | ⏳ | DevOps |
| JWT секреты ротированы | ⏳ | Dev |
| Пароли хэшированы bcrypt | ⏳ | Dev |
| Rate limiting настроен | ⏳ | Dev |
| SQL-инъекции исключены (parameterized queries) | ⏳ | Dev |
| XSS исключён (валидация ввода) | ⏳ | Dev |
| CORS настроен правильно | ⏳ | Dev |
| Логи не содержат чувствительных данных | ⏳ | Dev |
| Бэкапы БД настроены | ⏳ | DevOps |
| Мониторинг ошибок (Sentry) | ⏳ | DevOps |
| Детекция читерства работает | ⏳ | Dev |
| GDPR: право на удаление реализовано | ⏳ | Dev |

### 8.2 Пентест-сценарии

| Сценарий | Ожидаемый результат |
|----------|---------------------|
| Подбор PIN дилера | Блокировка после 5 попыток |
| brute-force пароль тренера | Rate limiting, блокировка IP |
| SQL-инъекция через параметр | Ошибка 422, запрос отклонён |
| Подделка JWT | 401, запрос отклонён |
| XSS через display_name | Валидация, экранирование |
| CSRF через веб-дашборд | CSRF token required |
| Перебор room_code | Rate limiting |

---

## 9. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Алгоритм детекции читерства (паттерны, пороги, действия) | ✅ Завершено |
| 2 | Механизм подписи результатов (HMAC) | ✅ Завершено |
| 3 | Правила rate limiting (запросы/минуту, бан) | ✅ Завершено |
| 4 | Политика хранения данных (GDPR) | ✅ Завершено |
| 5 | Аудит безопасности (чеклист, пентест) | ✅ Завершено |
| 6 | Валидация данных (Pydantic + бизнес-логика) | ✅ Завершено |
| 7 | Шифрование (HTTPS, bcrypt, JWT) | ✅ Завершено |

**Раздел 13: Безопасность — детализация завершена полностью (7/7 пунктов).**

---

> **Этот документ — финальная детализация раздела 13.1 "Безопасность".**  
> **Следующий шаг:** Приступить к детализации раздела 14 "Тестирование".
