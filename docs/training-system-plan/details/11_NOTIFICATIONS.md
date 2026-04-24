# Детализация: Система уведомлений

> **Раздел плана:** 11.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Разделы 1-9 (Авторизация — Серверная часть)

---

## 1. Обзор

Система уведомлений включает два канала коммуникации:

| Канал | Когда используется | Примеры |
|-------|-------------------|---------|
| **Push-уведомления** | Приложение закрыто или в фоне | "Новая живая сессия через 15 мин", "Задание просрочено" |
| **Внутриигровые уведомления** | Приложение открыто | "Достижение разблокировано!", "Ранг повышен!" |

---

## 2. Полный список типов уведомлений

### 2.1 Уведомления для дилера

| # | Тип | Канал | Условие | Заголовок | Текст |
|---|-----|-------|---------|-----------|-------|
| 1 | Новая живая сессия | Push | Тренер создал сессию | 🔴 Сессия начинается! | "Группа А — Утро: живая сессия начинается через 15 минут" |
| 2 | Сессия скоро начнётся | Push | Обратный отсчёт 5 мин | ⏰ Через 5 минут | "Живая сессия в группе А начинается через 5 минут!" |
| 3 | Новое задание | Push | Тренер назначил задание | 📝 Новое задание | "3-я карта Банкира: срок до 16 апреля" |
| 4 | Достижение разблокировано | Push + In-game | Достижение выполнено | 🏆 Достижение! | "Разблокировано: Непробиваемый (+100 XP)" |
| 5 | Ранг повышен | Push + In-game | XP достиг порога | 🎉 Новый ранг! | "Вы достигли ранга Профессионал!" |
| 6 | Позиция в таблице | Push | Поднялся на 2+ позиции | 📈 Подъём в рейтинге! | "Вы переместились на #3 в таблице лидеров" |
| 7 | Задание скоро истекает | Push | До срока осталось 24 часа | ⏰ Задание истекает | "3-я карта Банкира: осталось 24 часа" |
| 8 | Задание выполнено | In-game | Прогресс достиг 100% | ✅ Задание выполнено! | "Мастер выплат: +100 XP" |
| 9 | Тренер оставил фидбек | Push | Тренер написал комментарий | 💬 Фидбек от тренера | "Иванов И. оставил комментарий к вашей сессии" |
| 10 | Комната закрыта | Push | Тренер закрыл комнату | ⚠️ Комната закрыта | "Группа А — Утро закрыта. Обратитесь к тренеру" |

### 2.2 Уведомления для тренера

| # | Тип | Канал | Условие | Заголовок | Текст |
|---|-----|-------|---------|-----------|-------|
| 11 | Сессия завершена | Push | Таймер сессии истёк | ✅ Сессия завершена | "Группа А: 187 раундов, средняя точность 84%" |
| 12 | Дилер достиг milestone | Push | Дилер набрал 100/500/1000 раундов | 🎯 Достижение дилера | "Новиков Д. сыграл 500 раундов!" |
| 13 | Точность дилера упала | Push | Точность < 60% за 20 раундов | ⚠️ Внимание | "Морозова О.: точность упала до 55%" |
| 14 | Задание просрочено | Push | Срок задания истёк, не выполнено | ❌ Задание просрочено | "3-я карта Банкира: 5 из 8 дилеров не выполнили" |
| 15 | Новый дилер вошёл | In-game | Дилер впервые вошёл в комнату | 👋 Новый участник | "Лебедева Н. присоединилась к группе" |
| 16 | Дилер не заходил 7 дней | Push | last_seen_at > 7 дней | 💤 Неактивный дилер | "Лебедева Н. не заходила 7 дней" |
| 17 | Дилер выполнил задание | In-game | Задание выполнено | ✅ Задание выполнено | "Новиков Д. выполнил: 3-я карта Банкира" |
| 18 | Группа готова к сессии | Push | Все дилеры подключились | 🟢 Все готовы | "Все 8 участников подключились к сессии" |

### 2.3 Сводная матрица

| Событие | Дилер | Тренер |
|---------|-------|--------|
| Новая живая сессия | ✅ Push | — |
| Сессия завершена | In-game | ✅ Push |
| Новое задание | ✅ Push | — |
| Задание выполнено | In-game | In-game |
| Задание просрочено | — | ✅ Push |
| Достижение | ✅ Push + In-game | — |
| Ранг повышен | ✅ Push + In-game | — |
| Точность упала | — | ✅ Push |
| Неактивный дилер | — | ✅ Push |
| Фидбек тренера | ✅ Push | — |

---

## 3. Интеграция с APNs (iOS)

### 3.1 Требования

| Компонент | Описание |
|-----------|----------|
| Apple Developer аккаунт | Обязательно ($99/год) |
| APNs Key | Создаётся в Apple Developer Portal |
| Key ID | Идентификатор ключа |
| Team ID | Идентификатор команды |
| Bundle Identifier | com.baccarat.trainer |
| Push Notifications capability | Включить в Xcode |

### 3.2 Получение device token (Godot → iOS)

```gdscript
# scripts/notifications/PushNotificationManager.gd
class_name PushNotificationManager
extends Node

var device_token: String = ""
var apns_topic: String = "com.baccarat.trainer"

func _ready() -> void:
    if OS.get_name() == "iOS":
        _register_for_push_notifications()

func _register_for_push_notifications() -> void:
    # На iOS это делается через нативный плагин
    # Godot 4.x: используем iOS plugin
    var ios_plugin = Engine.get_singleton("iOSPushNotifications")
    if ios_plugin:
        ios_plugin.register_for_remote_notifications()
        ios_plugin.device_token_received.connect(_on_device_token_received)
        ios_plugin.notification_received.connect(_on_notification_received)

func _on_device_token_received(token: String) -> void:
    device_token = token
    # Отправить токен на сервер
    _send_token_to_server()

func _send_token_to_server() -> void:
    if device_token == "" or not AuthManager.access_token:
        return
    
    var api = APIClient.new()
    api.set_auth_token(AuthManager.access_token)
    api.post("/api/notifications/register-device", {
        "device_token": device_token,
        "platform": "ios",
        "app_version": ProjectSettings.get_setting("application/config/version")
    })
```

### 3.3 Отправка push через APNs (сервер)

```python
# server/services/push_service.py
import httpx
import jwt
import time
from typing import List

class APNsService:
    def __init__(self):
        self.key_id = settings.APNS_KEY_ID
        self.team_id = settings.APNS_TEAM_ID
        self.topic = "com.baccarat.trainer"
        self._private_key = self._load_private_key()
        self._token_cache = {"token": None, "expires_at": 0}
    
    def _load_private_key(self) -> str:
        """Загрузить .p8 файл ключа APNs."""
        with open(settings.APNS_KEY_PATH, "r") as f:
            return f.read()
    
    def _get_auth_token(self) -> str:
        """Получить JWT токен для APNs (кешируется на 30 мин)."""
        now = time.time()
        if self._token_cache["token"] and now < self._token_cache["expires_at"]:
            return self._token_cache["token"]
        
        token = jwt.encode(
            {"iss": self.team_id, "iat": now},
            self._private_key,
            algorithm="ES256",
            headers={"kid": self.key_id}
        )
        
        self._token_cache["token"] = token
        self._token_cache["expires_at"] = now + 1800  # 30 мин
        return token
    
    async def send_push(
        self,
        device_token: str,
        title: str,
        body: str,
        data: dict = None,
        sound: str = "default"
    ) -> bool:
        """Отправить push-уведомление через APNs."""
        auth_token = self._get_auth_token()
        
        payload = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body
                },
                "sound": sound,
                "badge": 1  # Обновить badge на иконке
            }
        }
        
        if data:
            payload["aps"]["data"] = data
        
        headers = {
            "apns-topic": self.topic,
            "apns-push-type": "alert",
            "apns-priority": "10",  # 10 = immediate, 5 = background
            "authorization": f"bearer {auth_token}"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.push.apple.com/3/device/" + device_token,
                json=payload,
                headers=headers
            )
        
        if response.status_code == 200:
            return True
        else:
            # Логировать ошибку
            logger.error(f"APNs error: {response.status_code} - {response.text}")
            return False
    
    async def send_to_multiple(self, device_tokens: List[str], title: str, body: str, data: dict = None) -> dict:
        """Отправить push нескольким устройствам."""
        results = {"sent": 0, "failed": 0, "errors": []}
        
        for token in device_tokens:
            success = await self.send_push(token, title, body, data)
            if success:
                results["sent"] += 1
            else:
                results["failed"] += 1
                results["errors"].append(token)
        
        return results
```

### 3.4 Формат payload APNs

```json
{
  "aps": {
    "alert": {
      "title": "🏆 Достижение!",
      "body": "Разблокировано: Непробиваемый (+100 XP)"
    },
    "sound": "default",
    "badge": 1,
    "data": {
      "type": "achievement_unlocked",
      "achievement_id": "streak_10",
      "xp_reward": 100
    }
  }
}
```

---

## 4. Интеграция с FCM (Android)

### 4.1 Требования

| Компонент | Описание |
|-----------|----------|
| Firebase проект | Создаётся в Firebase Console |
| google-services.json | Скачивается из Firebase Console |
| FCM Server Key | Из настроек проекта Firebase |
| Internet permission | В манифесте Android |

### 4.2 Получение FCM token (Godot → Android)

```gdscript
# scripts/notifications/PushNotificationManager.gd (продолжение)

func _register_for_push_notifications() -> void:
    if OS.get_name() == "Android":
        # На Android через Godot Firebase плагин или нативный
        var android_plugin = Engine.get_singleton("AndroidPushNotifications")
        if android_plugin:
            android_plugin.register_for_fcm()
            android_plugin.fcm_token_received.connect(_on_fcm_token_received)
            android_plugin.notification_received.connect(_on_notification_received)

func _on_fcm_token_received(token: String) -> void:
    device_token = token
    _send_token_to_server()
```

### 4.3 Отправка push через FCM (сервер)

```python
# server/services/fcm_service.py
import httpx

class FCMService:
    def __init__(self):
        self.server_key = settings.FCM_SERVER_KEY
        self.fcm_url = "https://fcm.googleapis.com/fcm/send"
    
    async def send_push(
        self,
        device_token: str,
        title: str,
        body: str,
        data: dict = None,
        sound: str = "default"
    ) -> bool:
        """Отправить push-уведомление через FCM."""
        payload = {
            "to": device_token,
            "notification": {
                "title": title,
                "body": body,
                "sound": sound
            },
            "data": data or {},
            "priority": "high"
        }
        
        headers = {
            "Authorization": f"key={self.server_key}",
            "Content-Type": "application/json"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.fcm_url,
                json=payload,
                headers=headers
            )
        
        result = response.json()
        
        if response.status_code == 200 and result.get("success", 0) > 0:
            return True
        else:
            logger.error(f"FCM error: {result}")
            return False
```

### 4.4 Формат payload FCM

```json
{
  "to": "device_fcm_token",
  "notification": {
    "title": "📝 Новое задание",
    "body": "3-я карта Банкира: срок до 16 апреля",
    "sound": "default"
  },
  "data": {
    "type": "new_assignment",
    "assignment_id": "uuid",
    "room_code": "TRAIN-A7X9"
  },
  "priority": "high"
}
```

---

## 5. Универсальный сервис уведомлений (сервер)

```python
# server/services/notification_service.py
from app.services.push_service import APNsService
from app.services.fcm_service import FCMService

class NotificationService:
    def __init__(self):
        self.apns = APNsService()
        self.fcm = FCMService()
    
    async def notify_dealer(
        self,
        dealer_id: UUID,
        title: str,
        body: str,
        notification_type: str,
        data: dict = None
    ) -> bool:
        """Отправить push-уведомление дилеру."""
        # Получить device tokens дилера
        devices = db.execute(
            "SELECT device_token, platform FROM push_devices WHERE dealer_id = :id AND is_active = true",
            {"id": dealer_id}
        ).fetchall()
        
        if not devices:
            return False
        
        success_count = 0
        for device in devices:
            if device["platform"] == "ios":
                success = await self.apns.send_push(
                    device["device_token"], title, body, data
                )
            else:  # android
                success = await self.fcm.send_push(
                    device["device_token"], title, body, data
                )
            
            if success:
                success_count += 1
        
        return success_count > 0
    
    async def notify_trainer(
        self,
        trainer_id: UUID,
        title: str,
        body: str,
        notification_type: str,
        data: dict = None
    ) -> bool:
        """Отправить push-уведомление тренеру."""
        devices = db.execute(
            "SELECT device_token, platform FROM push_devices WHERE trainer_id = :id AND is_active = true",
            {"id": trainer_id}
        ).fetchall()
        
        if not devices:
            return False
        
        success_count = 0
        for device in devices:
            if device["platform"] == "ios":
                success = await self.apns.send_push(
                    device["device_token"], title, body, data
                )
            else:
                success = await self.fcm.send_push(
                    device["device_token"], title, body, data
                )
            
            if success:
                success_count += 1
        
        return success_count > 0
    
    async def notify_room_dealers(
        self,
        room_code: str,
        title: str,
        body: str,
        notification_type: str,
        data: dict = None
    ) -> dict:
        """Отправить push всем дилерам комнаты."""
        room = db.execute("SELECT id FROM rooms WHERE room_code = :code", {"code": room_code}).fetchone()
        if not room:
            return {"sent": 0, "failed": 0}
        
        dealers = db.execute(
            "SELECT id FROM dealers WHERE room_id = :room_id AND is_active = true",
            {"room_id": room["id"]}
        ).fetchall()
        
        results = {"sent": 0, "failed": 0}
        for dealer in dealers:
            success = await self.notify_dealer(
                dealer["id"], title, body, notification_type, data
            )
            if success:
                results["sent"] += 1
            else:
                results["failed"] += 1
        
        return results
```

---

## 6. Внутриигровые уведомления

### 6.1 Система внутриигровых уведомлений (Godot)

```gdscript
# scripts/ui/InGameNotificationManager.gd
class_name InGameNotificationManager
extends Node

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ (подписка на события)
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
    # Подписка на EventBus
    EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
    EventBus.rank_increased.connect(_on_rank_increased)
    EventBus.assignment_completed.connect(_on_assignment_completed)
    EventBus.session_started.connect(_on_session_started)
    EventBus.session_ended.connect(_on_session_ended)
    EventBus.leaderboard_position_changed.connect(_on_leaderboard_changed)

# ═══════════════════════════════════════════════════════════════
# ТИПЫ УВЕДОМЛЕНИЙ
# ═══════════════════════════════════════════════════════════════

enum NotificationType {
    SUCCESS,    # Зелёный, позитивное
    INFO,       # Синий, информационное
    WARNING,    # Жёлтый, предупреждение
    ERROR       # Красный, ошибка
}

# ═══════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════

func _on_achievement_unlocked(achievement: Dictionary) -> void:
    show_notification(
        "🏆 Достижение разблокировано!",
        "%s (+%d XP)" % [achievement.name, achievement.xp_reward],
        NotificationType.SUCCESS,
        4.0
    )

func _on_rank_increased(rank: Dictionary) -> void:
    show_notification(
        "🎉 Новый ранг!",
        "Вы достигли ранга %s %s" % [rank.icon, rank.name],
        NotificationType.SUCCESS,
        5.0
    )

func _on_assignment_completed(assignment: Dictionary) -> void:
    show_notification(
        "✅ Задание выполнено!",
        "%s (+%d XP)" % [assignment.title, assignment.bonus_xp],
        NotificationType.SUCCESS,
        4.0
    )

func _on_session_started(session: Dictionary) -> void:
    show_notification(
        "🔴 Сессия началась!",
        "Осталось: %d мин" % (session.duration_seconds / 60),
        NotificationType.INFO,
        3.0
    )

func _on_session_ended(session: Dictionary) -> void:
    show_notification(
        "✅ Сессия завершена",
        "Раундов: %d, Точность: %.0f%%" % [session.rounds, session.accuracy],
        NotificationType.SUCCESS,
        5.0
    )

func _on_leaderboard_changed(position: Dictionary) -> void:
    if position.jump >= 2:  # Поднялся на 2+ позиции
        show_notification(
            "📈 Подъём в рейтинге!",
            "Вы переместились на #%d" % position.new_rank,
            NotificationType.SUCCESS,
            3.0
        )

# ═══════════════════════════════════════════════════════════════
# ОТОБРАЖЕНИЕ
# ═══════════════════════════════════════════════════════════════

var notification_queue: Array = []
var is_showing: bool = false

func show_notification(title: String, body: String, type: NotificationType, duration: float = 3.0) -> void:
    notification_queue.append({"title": title, "body": body, "type": type, "duration": duration})
    
    if not is_showing:
        _show_next()

func _show_next() -> void:
    if notification_queue.is_empty():
        is_showing = false
        return
    
    is_showing = true
    var notification = notification_queue.pop_front()
    
    # Показать попап
    var popup = preload("res://scenes/ui/NotificationPopup.tscn").instantiate()
    popup.set_notification(notification.title, notification.body, notification.type)
    get_tree().root.add_child(popup)
    
    # Автоматически скры через duration
    await get_tree().create_timer(notification.duration).timeout
    popup.queue_free()
    
    # Показать следующее
    _show_next()
```

### 6.2 UI попапа уведомления

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  🏆 Достижение разблокировано!                      │
│  Непробиваемый (+100 XP)                            │
│                                                     │
└─────────────────────────────────────────────────────┘

Цвет фона:
- SUCCESS: Зелёный (#4CAF50)
- INFO: Синий (#2196F3)
- WARNING: Жёлтый (#FFC107)
- ERROR: Красный (#F44336)

Анимация:
- Появление: slide down from top (0.3s)
- Исчезновение: fade out (0.3s)
- Максимум 1 уведомление одновременно (остальные в очереди)
```

---

## 7. Настройки уведомлений

### 7.1 UI настроек

```
┌─────────────────────────────────────────────────────────┐
│  ← Назад           🔔 Уведомления                       │
├─────────────────────────────────────────────────────────┤
│                                                                 │
│  ─── Push-уведомления ───                                       │
│                                                                 │
│  [x] Включить push-уведомления                                 │
│                                                                 │
│  ─── Дилер ───                                                  │
│                                                                 │
│  [x] Новая живая сессия                                         │
│  [x] Сессия скоро начнётся (за 5 мин)                          │
│  [x] Новое задание от тренера                                   │
│  [x] Достижение разблокировано                                  │
│  [x] Ранг повышен                                               │
│  [x] Подъём в рейтинге                                          │
│  [x] Задание скоро истекает (за 24 часа)                       │
│  [x] Фидбек от тренера                                          │
│                                                                 │
│  ─── Тренер ───                                                 │
│                                                                 │
│  [x] Сессия завершена                                           │
│  [x] Достижение дилера                                          │
│  [x] Точность дилера упала                                      │
│  [x] Задание просрочено                                         │
│  [x] Неактивный дилер (7 дней)                                 │
│                                                                 │
│  ─── Звук ───                                                   │
│                                                                 │
│  [x] Звук уведомлений                                          │
│  Громкость: ████████░░░░ 80%                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 API для настроек

```
POST /api/notifications/preferences
Authorization: Bearer <access_token>

Request:
{
    "push_enabled": true,
    "preferences": {
        "new_session": true,
        "session_starting": true,
        "new_assignment": true,
        "achievement_unlocked": true,
        "rank_increased": true,
        "leaderboard_position": false,
        "assignment_expiring": true,
        "trainer_feedback": true
    }
}

Response 200:
{
    "message": "Настройки уведомлений обновлены"
}
```

### 7.3 База данных — таблица настроек

```sql
CREATE TABLE notification_preferences (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,  -- dealer_id или trainer_id
    user_type       VARCHAR(10) NOT NULL,  -- 'dealer' или 'trainer'
    push_enabled    BOOLEAN DEFAULT TRUE,
    preferences     JSONB NOT NULL DEFAULT '{}',
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, user_type)
);
```

---

## 8. Fallback: если push не дошёл

### 8.1 Стратегия

| Сценарий | Действие |
|----------|----------|
| Push не дошёл (ошибка APNs/FCM) | Сохранить в БД как "pending" |
| Push доставлен, но пользователь не открыл | Показать при следующем входе |
| Приложение было в фоне при push | Показать как in-game уведомление |
| Устройство оффлайн > 24 часа | Уведомление теряется (не критичное) |

### 8.2 Таблица "недоставленных" уведомлений

```sql
CREATE TABLE pending_notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    user_type       VARCHAR(10) NOT NULL,
    title           VARCHAR(200) NOT NULL,
    body            TEXT NOT NULL,
    notification_type VARCHAR(30) NOT NULL,
    data            JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    delivered_at    TIMESTAMPTZ,
    is_delivered    BOOLEAN DEFAULT FALSE,
    expires_at      TIMESTAMPTZ  -- NULL = не истекает
);

CREATE INDEX idx_pending_notifications_user ON pending_notifications(user_id, user_type, is_delivered);
```

### 8.3 Получение недоставленных при входе

```gdscript
# scripts/notifications/PushNotificationManager.gd

func _on_login_success() -> void:
    # Проверить недоставленные push-уведомления
    _fetch_pending_notifications()

func _fetch_pending_notifications() -> void:
    var api = APIClient.new()
    api.set_auth_token(AuthManager.access_token)
    
    var response = await api.get("/api/notifications/pending")
    
    for notification in response.get("notifications", []):
        # Показать как in-game уведомление
        InGameNotificationManager.show_notification(
            notification.title,
            notification.body,
            _map_type(notification.notification_type),
            5.0
        )
    
    # Отметить как доставленные
    if not response.get("notifications", []).is_empty():
        api.post("/api/notifications/mark-delivered", {
            "ids": response.notifications.map(func(n): return n.id)
        })
```

---

## 9. База данных — таблица устройств

```sql
CREATE TABLE push_devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dealer_id       UUID REFERENCES dealers(id) ON DELETE CASCADE,
    trainer_id      UUID REFERENCES trainers(id) ON DELETE CASCADE,
    device_token    VARCHAR(255) NOT NULL,
    platform        VARCHAR(10) NOT NULL,  -- 'ios' или 'android'
    app_version     VARCHAR(20),
    is_active       BOOLEAN DEFAULT TRUE,
    last_seen_at    TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(device_token, platform)
);

CREATE INDEX idx_push_devices_dealer ON push_devices(dealer_id);
CREATE INDEX idx_push_devices_trainer ON push_devices(trainer_id);
CREATE INDEX idx_push_devices_active ON push_devices(is_active);
```

---

## 10. API-эндпоинты уведомлений

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/notifications/register-device` | Зарегистрировать device token |
| GET | `/api/notifications/pending` | Получить недоставленные |
| POST | `/api/notifications/mark-delivered` | Отметить доставленными |
| POST | `/api/notifications/preferences` | Обновить настройки |
| GET | `/api/notifications/preferences` | Получить настройки |

---

## 11. Тест-кейсы

### 11.1 Push-уведомления

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Тренер создал сессию → дилеры получили push | Push доставлен в течение 5 сек |
| 2 | Достижение разблокировано → push | Push доставлен |
| 3 | Устройство оффлайн → уведомление потеряно | OK (не критичное) |
| 4 | Неверный device token | Ошибка залогирована, token помечен неактивным |
| 5 | Пользователь отключил push в настройках | Push не отправляется |

### 11.2 Внутриигровые уведомления

| # | Сценарий | Ожидаемый результат |
|---|----------|---------------------|
| 1 | Достижение разблокировано во время игры | In-game уведомление показано |
| 2 | Несколько уведомлений одновременно | Показываются по очереди |
| 3 | Пришёл push, приложение в фоне | In-game при открытии приложения |
| 4 | Недоставленные push при входе | Показаны при первом экране после логина |

---

## 12. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Полный список типов уведомлений (18 типов) | ✅ Завершено |
| 2 | Интеграция с APNs (iOS) — сертификаты, payload | ✅ Завершено |
| 3 | Интеграция с FCM (Android) — ключи, payload | ✅ Завершено |
| 4 | UI настроек уведомлений | ✅ Завершено |
| 5 | Fallback (если push не дошёл) | ✅ Завершено |
| 6 | Внутриигровые уведомления | ✅ Завершено |
| 7 | База данных устройств и настроек | ✅ Завершено |
| 8 | API-эндпоинты уведомлений | ✅ Завершено (5 эндпоинтов) |

**Раздел 11: Система уведомлений — детализация завершена полностью (8/8 пунктов).**

---

> **Этот документ — финальная детализация раздела 11.1 "Система уведомлений".**  
> **Следующий шаг:** Приступить к детализации раздела 12 "Аналитика и отчёты".
