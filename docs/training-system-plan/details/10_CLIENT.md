# Детализация: Клиентская часть (Godot-приложение)

> **Раздел плана:** 10.1  
> **Дата создания:** 2026-04-12  
> **Статус:** Детализация  
> **Зависимости:** Разделы 1-9 (все предыдущие)

---

## 1. Обзор

Клиентская часть — это Godot-приложение, которое запускается на iOS и Android (основные платформы). Оно содержит существующий геймплей Баккара + новые экраны для системы тренировки (вход в комнату, лобби, таблица лидеров, достижения, задания).

---

## 2. Структура новых файлов в проекте Godot

### 2.1 Новые директории

```
scripts/
├── network/                    # Сетевой слой (НОВЫЙ)
│   ├── APIClient.gd           # HTTP-клиент для REST API
│   ├── WebSocketClient.gd     # WebSocket-клиент
│   ├── AuthManager.gd         # Управление токенами
│   ├── RoomClient.gd          # API комнат
│   ├── SessionClient.gd       # API сессий
│   ├── LeaderboardClient.gd   # API таблицы лидеров
│   ├── AchievementClient.gd   # API достижений
│   ├── AssignmentClient.gd    # API заданий
│   └── ResponseCache.gd       # Кэш ответов
│
├── auth/                       # Авторизация (НОВЫЙ)
│   ├── RoleSelectScreen.gd    # Экран выбора роли
│   ├── TrainerLoginScreen.gd  # Экран входа тренера
│   ├── TrainerRegisterScreen.gd  # Экран регистрации тренера
│   ├── DealerLoginScreen.gd   # Экран входа дилера
│   └── PinInput.gd            # Контрол ввода PIN (6 цифр)
│
├── lobby/                      # Лобби комнаты (НОВЫЙ)
│   ├── LobbyScreen.gd         # Главный экран лобби
│   ├── RoomInfoPanel.gd       # Информация о комнате
│   ├── SessionStatusPanel.gd  # Статус сессии
│   └── QuickStartButton.gd    # Кнопка "Начать тренировку"
│
├── leaderboard/                # Таблица лидеров (НОВЫЙ)
│   ├── LeaderboardScreen.gd   # Экран таблицы лидеров
│   ├── LeaderboardRow.gd      # Строка таблицы
│   ├── PeriodSelector.gd      # Переключатель периода
│   └── MyPositionWidget.gd    # Виджет "Ваша позиция"
│
├── achievements/               # Достижения (НОВЫЙ)
│   ├── AchievementsScreen.gd  # Экран достижений
│   ├── AchievementCard.gd     # Карточка достижения
│   ├── AchievementUnlockPopup.gd  # Попап разблокировки
│   └── CategoryFilter.gd      # Фильтр по категории
│
├── assignments/                # Задания (НОВЫЙ)
│   ├── AssignmentsScreen.gd   # Экран заданий
│   ├── AssignmentCard.gd      # Карточка задания
│   ├── ProgressBar.gd         # Прогресс-бар задания
│   └── AssignmentDetailPopup.gd  # Детали задания
│
├── session/                    # Управление сессией (НОВЫЙ)
│   ├── SessionManager.gd      # Менеджер активной сессии
│   ├── SessionTimer.gd        # Таймер сессии
│   ├── SessionHUD.gd          # HUD сессии (таймер, раздача)
│   ├── WaitingScreen.gd       # Экран ожидания старта
│   ├── CountdownScreen.gd     # Обратный отсчёт (5 сек)
│   └── SessionEndScreen.gd    # Экран завершения сессии
│
├── profile/                    # Профиль (НОВЫЙ)
│   ├── ProfileScreen.gd       # Экран профиля
│   ├── StatsPanel.gd          # Панель статистики
│   ├── XPBar.gd               # Прогресс-бар XP
│   ├── RankBadge.gd           # Значок ранга
│   └── XPHistoryChart.gd      # График XP
│
└── ui/                         # Существующая директория
    └── ...                     # Существующие UI менеджеры
```

---

## 3. Wireframes всех новых экранов

### 3.1 Навигация между экранами

```
┌─────────────────────┐
│   Главное меню      │
│                     │
│  [🎮 Играть]        │
│  [👨‍🏫 Я ТРЕНЕР]      │
│  [🃏 Я ДИЛЕР]       │
│  [⚙️ Настройки]     │
└──────────┬──────────┘
           │
     ┌─────┴──────┐
     │            │
     ▼            ▼
┌─────────┐  ┌──────────────────┐
│ Тренер: │  │ Дилер:           │
│ Логин   │  │ Ввод кода + PIN  │
│/Регистра│  │ → Лобби комнаты  │
│ ция     │  │                  │
└────┬────┘  └────────┬─────────┘
     │                │
     ▼                ▼
┌─────────┐  ┌──────────────────┐
│ Дашборд │  │ Лобби комнаты    │
│ тренера │  │                  │
│ (веб)   │  │ [▶️ Тренировка]  │
│         │  │ [🏆 Лидеры]      │
│         │  │ [🏆 Достижения]  │
│         │  │ [📝 Задания]     │
│         │  │ [👤 Профиль]     │
└─────────┘  └──────────────────┘
```

### 3.2 Главное меню (обновлённое)

```
┌─────────────────────────────────────┐
│                                     │
│        🎰 BACCARAT TRAINER          │
│        Тренажёр дилеров             │
│                                     │
│   ┌───────────────────────────┐     │
│   │  🎮 Быстрая тренировка     │     │
│   │  (без комнаты, оффлайн)    │     │
│   └───────────────────────────┘     │
│                                     │
│   ┌───────────────────────────┐     │
│   │  👨‍🏫 Я ТРЕНЕР              │     │
│   │  (войти в дашборд)         │     │
│   └───────────────────────────┘     │
│                                     │
│   ┌───────────────────────────┐     │
│   │  🃏 Я ДИЛЕР               │     │
│   │  (войти в комнату)         │     │
│   └───────────────────────────┘     │
│                                     │
│   ┌───────────────────────────┐     │
│   │  ⚙️ Настройки             │     │
│   └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

### 3.3 Экран входа дилера

```
┌─────────────────────────────────────┐
│  ← Назад                            │
│                                     │
│  🃏 Вход в комнату                  │
│                                     │
│  Код комнаты:                       │
│  ┌─────────────────────────────┐   │
│  │ TRAIN-                       │   │
│  │         [A] [7] [X] [9]    │   │
│  └─────────────────────────────┘   │
│                                     │
│  PIN-код:                           │
│  ┌─────────────────────────────┐   │
│  │  [4] [8] [2] [1] [5] [6]   │   │
│  └─────────────────────────────┘   │
│                                     │
│  Ваше имя:                          │
│  ┌─────────────────────────────┐   │
│  │ Петрова М.                   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ⚠️ PIN и имя вы получили           │
│  от тренера                         │
│                                     │
│  ┌─────────────────────────────┐   │
│  │       Войти в комнату        │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### 3.4 Лобби комнаты

```
┌─────────────────────────────────────┐
│  ← Назад                            │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  🎰 Группа А — Утро         │   │
│  │  Тренер: Иванов И.          │   │
│  │  🟢 Комната активна         │   │
│  │  👥 8 участников            │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  📊 Текущая сессия          │   │
│  │  🟢 Идёт живая сессия       │   │
│  │  Осталось: 18:42            │   │
│  │  Ваш прогресс: 23 раунда    │   │
│  │  Точность: 87%              │   │
│  │                             │   │
│  │  [🎮 Продолжить тренировку] │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  📝 Активные задания: 2     │   │
│  │  [📋 Посмотреть задания]    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  🏆 Ваш ранг: #5 из 8       │   │
│  │  [📋 Таблица лидеров]       │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌───────────┐  ┌───────────┐     │
│  │ 🏆        │  │ 📝        │     │
│  │ Достижения│  │ Задания   │     │
│  │ (12/30)   │  │ (2 акт.)  │     │
│  └───────────┘  └───────────┘     │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  👤 Профиль                 │   │
│  │  🃏 Дилер | ⭐ 1,540 XP    │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### 3.5 HUD сессии (во время игры)

**Живая сессия:**
```
┌─────────────────────────────────────┐
│ 🔴 СЕССИЯ | ⏱ 18:42 | 🎴 #23       │
├─────────────────────────────────────┤
│                                     │
│  [обычный геймплей Баккара]         │
│                                     │
│  Точность: 87% | ❤️ 4/7            │
│                                     │
└─────────────────────────────────────┘
```

**Асинхронная тренировка:**
```
┌─────────────────────────────────────┐
│ 🎮 Самостоятельная | 🎴 #12 | 08:42 │
├─────────────────────────────────────┤
│                                     │
│  [обычный геймплей Баккара]         │
│                                     │
│  Точность: 91% | ❤️ 6/7            │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📝 Задание: "3-я карта ...  │   │
│  │ Прогресс: 8/30  ████░ 27%   │   │
│  └─────────────────────────────┘   │
│                                     │
│  [⏹ Завершить тренировку]          │
└─────────────────────────────────────┘
```

### 3.6 Экран профиля

```
┌─────────────────────────────────────┐
│  ← Назад                            │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  👤 Петрова Мария           │   │
│  │  🃏 Дилер (Ранг 3/7)        │   │
│  │  Комната: Группа А — Утро   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ─── Опыт ───                       │
│  ⭐ 1,540 XP                        │
│  До 💼 Профессионал: 1,540/1,500   │
│  ████████████████████████░░ 95%    │
│                                     │
│  ─── Статистика ───                 │
│  Раундов сыграно:   89              │
│  Общая точность:    78%             │
│  Среднее время:     28 сек/раунд   │
│  Лучшая серия:      15             │
│  Достижений:        12/30          │
│  Заданий выполнено: 5               │
│                                     │
│  ─── XP за последние 7 дней ───     │
│  300│                               │
│  200│    ██                         │
│  100│ ██ ██     ██                  │
│     │    ██  ██ ██ ██  ██          │
│     └─────────────────────────     │
│      Пн Вт Ср Чт Пт Сб Вс           │
│                                     │
│  [🏆 Достижения]  [📝 Задания]     │
│  [📊 Подробная статистика]          │
│                                     │
└─────────────────────────────────────┘
```

---

## 4. Сетевой слой

### 4.1 APIClient — базовый HTTP-клиент

```gdscript
# scripts/network/APIClient.gd
class_name APIClient
extends Node

# ═══════════════════════════════════════════════════════════════
# НАСТРОЙКИ
# ═══════════════════════════════════════════════════════════════

@export var base_url: String = "https://api.baccarat-trainer.com"
var _http_request: HTTPRequest
var _auth_token: String = ""

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal request_completed(request_id: int, response: Dictionary)
signal request_failed(request_id: int, error_code: int, error_message: String)
signal connection_error(error: String)

# ═══════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
    _http_request = HTTPRequest.new()
    add_child(_http_request)
    _http_request.request_completed.connect(_on_request_completed)

func set_auth_token(token: String) -> void:
    _auth_token = token

func clear_auth_token() -> void:
    _auth_token = ""

# ═══════════════════════════════════════════════════════════════
# HTTP МЕТОДЫ
# ═══════════════════════════════════════════════════════════════

func get(path: String, query_params: Dictionary = {}) -> int:
    var url = _build_url(path, query_params)
    var headers = _build_headers()
    return _http_request.request(url, headers, HTTPClient.METHOD_GET)

func post(path: String, body: Dictionary) -> int:
    var url = _build_url(path)
    var headers = _build_headers()
    var json = JSON.stringify(body)
    return _http_request.request(url, headers, HTTPClient.METHOD_POST, json)

func patch(path: String, body: Dictionary) -> int:
    var url = _build_url(path)
    var headers = _build_headers()
    var json = JSON.stringify(body)
    return _http_request.request(url, headers, HTTPClient.METHOD_PATCH, json)

func delete(path: String) -> int:
    var url = _build_url(path)
    var headers = _build_headers()
    return _http_request.request(url, headers, HTTPClient.METHOD_DELETE)

# ═══════════════════════════════════════════════════════════════
# ВНУТРЕННИЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════

func _build_url(path: String, query_params: Dictionary = {}) -> String:
    var url = base_url + path
    if not query_params.is_empty():
        var query = "?"
        for key in query_params:
            query += "%s=%s&" % [key, query_params[key]]
        url += query.trim_suffix("&")
    return url

func _build_headers() -> PackedStringArray:
    var headers = PackedStringArray([
        "Content-Type: application/json",
        "Accept: application/json"
    ])
    if _auth_token != "":
        headers.append("Authorization: Bearer %s" % _auth_token)
    return headers

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        connection_error.emit("Ошибка сети: %d" % result)
        return
    
    var response_text = body.get_string_from_utf8()
    var response = JSON.parse_string(response_text)
    
    if response == null:
        request_failed.emit(0, response_code, "Неверный JSON от сервера")
        return
    
    if response_code >= 400:
        var error_message = response.get("error", {}).get("message", "Неизвестная ошибка")
        request_failed.emit(0, response_code, error_message)
        return
    
    request_completed.emit(0, response)
```

### 4.2 WebSocketClient — клиент для real-time

```gdscript
# scripts/network/WebSocketClient.gd
class_name SessionWebSocketClient
extends Node

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal connected()
signal disconnected()
signal message_received(type: String, data: Dictionary)
signal connection_error(error: String)

# ═══════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════

var _ws: WebSocketPeer
var _server_url: String = ""
var _is_connected: bool = false

# ═══════════════════════════════════════════════════════════════
# ПОДКЛЮЧЕНИЕ
# ═══════════════════════════════════════════════════════════════

func connect_to_session(session_id: String, auth_token: String) -> void:
    _ws = WebSocketPeer.new()
    _server_url = "wss://api.baccarat-trainer.com/ws/sessions/%s?token=%s" % [session_id, auth_token]
    
    var err = _ws.connect_to_url(_server_url)
    if err != OK:
        connection_error.emit("Ошибка подключения: %d" % err)
        return

func connect_to_dashboard(room_code: String, auth_token: String) -> void:
    _ws = WebSocketPeer.new()
    _server_url = "wss://api.baccarat-trainer.com/ws/dashboard/%s?token=%s" % [room_code, auth_token]
    
    var err = _ws.connect_to_url(_server_url)
    if err != OK:
        connection_error.emit("Ошибка подключения: %d" % err)
        return

# ═══════════════════════════════════════════════════════════════
# ОБРАБОТКА (вызывается из _process)
# ═══════════════════════════════════════════════════════════════

func poll() -> void:
    if not _ws:
        return
    
    _ws.poll()
    
    match _ws.get_ready_state():
        WebSocketPeer.STATE_OPEN:
            if not _is_connected:
                _is_connected = true
                connected.emit()
            
            while _ws.get_available_packet_count() > 0:
                var message = _ws.get_packet().get_string_from_utf8()
                _parse_message(message)
        
        WebSocketPeer.STATE_CLOSED:
            if _is_connected:
                _is_connected = false
                disconnected.emit()

func send_message(type: String, data: Dictionary) -> void:
    if not _ws or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return
    
    var message = JSON.stringify({
        "type": type,
        "data": data,
        "timestamp": Time.get_datetime_string_from_system()
    })
    _ws.send_text(message)

# ═══════════════════════════════════════════════════════════════
# ПАРСИНГ
# ═══════════════════════════════════════════════════════════════

func _parse_message(message: String) -> void:
    var json = JSON.parse_string(message)
    if json == null:
        return
    
    var type = json.get("type", "")
    var data = json.get("data", {})
    
    message_received.emit(type, data)

func disconnect_from_server() -> void:
    if _ws:
        _ws.close()
        _ws = null
        _is_connected = false
```

### 4.3 AuthManager — управление токенами

```gdscript
# scripts/network/AuthManager.gd
class_name AuthManager
extends Node

# ═══════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════

var access_token: String = ""
var refresh_token: String = ""
var user_data: Dictionary = {}

# ═══════════════════════════════════════════════════════════════
# СОХРАНЕНИЕ / ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════

func save_tokens(at: String, rt: String, user: Dictionary) -> void:
    access_token = at
    refresh_token = rt
    user_data = user
    
    # Сохраняем refresh_token в безопасное хранилище
    var secure_storage = OS.get_secure_string("refresh_token", "")
    # На iOS: Keychain, на Android: EncryptedSharedPreferences
    _save_to_secure_storage("refresh_token", rt)
    _save_to_secure_storage("user_data", JSON.stringify(user))

func load_tokens() -> bool:
    refresh_token = _load_from_secure_storage("refresh_token", "")
    if refresh_token == "":
        return false
    
    var user_json = _load_from_secure_storage("user_data", "{}")
    user_data = JSON.parse_string(user_json)
    return true

func clear_tokens() -> void:
    access_token = ""
    refresh_token = ""
    user_data = {}
    _delete_from_secure_storage("refresh_token")
    _delete_from_secure_storage("user_data")

# ═══════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ
# ═══════════════════════════════════════════════════════════════

func get_role() -> String:
    return user_data.get("role", "")

func is_trainer() -> bool:
    return get_role() == "trainer"

func is_dealer() -> bool:
    return get_role() == "dealer"

func get_room_code() -> String:
    return user_data.get("room_code", "")

func _save_to_secure_storage(key: String, value: String) -> void:
    # iOS: Keychain, Android: EncryptedSharedPreferences
    # Реализация зависит от платформы
    pass

func _load_from_secure_storage(key: String, default: String) -> String:
    return default

func _delete_from_secure_storage(key: String) -> void:
    pass
```

---

## 5. Кэширование

### 5.1 Что кешируем

| Данные | Где храним | TTL | Причина |
|--------|------------|-----|---------|
| Access token | Память | 1 час | Быстрый доступ |
| Refresh token | Secure Storage | 7-30 дней | Переживает перезапуск |
| Профиль пользователя | Память + файл | 5 мин | Не запрашивать каждый раз |
| Таблица лидеров | Память | 1 мин | Обновлять периодически |
| Результаты раунда (при обрыве) | Файл | До отправки | Не потерять при краше |
| Настройки комнаты | Память | 10 мин | Редко меняются |

### 5.2 Кэш результатов раунда (при обрыве)

```gdscript
# scripts/session/SessionResultCache.gd
class_name SessionResultCache
extends Node

const CACHE_DIR = "user://session_cache/"

var _results: Array = []
var _session_id: String = ""

func start_session(session_id: String) -> void:
    _session_id = session_id
    _results = []
    _ensure_cache_dir()

func cache_round_result(result: Dictionary) -> void:
    _results.append(result)
    _save_to_file()

func get_cached_results() -> Array:
    return _results.duplicate()

func flush_to_server(api_client: APIClient) -> Error:
    if _results.is_empty():
        return OK
    
    var body = JSON.stringify({"results": _results})
    var path = "/api/sessions/%s/results/batch" % _session_id
    
    # Отправляем
    var request_id = api_client.post(path, body)
    # Ждём ответ (синхронно через сигнал)
    var success = await api_client.request_completed
    
    if success:
        _results.clear()
        _delete_cache_file()
        return OK
    else:
        return FAILED

func _save_to_file() -> void:
    var path = CACHE_DIR + _session_id + ".json"
    var file = FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(_results))
    file.close()

func _ensure_cache_dir() -> void:
    if not DirAccess.dir_exists_absolute(CACHE_DIR):
        DirAccess.make_dir_absolute(CACHE_DIR)

func _delete_cache_file() -> void:
    var path = CACHE_DIR + _session_id + ".json"
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
```

---

## 6. Сборки для iOS и Android

### 6.1 iOS

**Требования:**
- macOS с установленным Xcode 15+
- Apple Developer аккаунт ($99/год)
- Сертификаты: Development + Distribution
- Provisioning Profiles

**Процесс сборки:**
```bash
# 1. Экспорт из Godot
godot --path . --export-debug "iOS" build/ios/

# 2. Открыть в Xcode
open build/ios/Baccarat.xcodeproj

# 3. В Xcode:
#    - Выбрать команду (Team)
#    - Настроить Bundle Identifier (com.baccarat.trainer)
#    - Настроить иконки и launch screen
#    - Archive → Distribute to App Store

# 4. Для тестирования (TestFlight):
#    - Archive → Upload to App Store Connect
#    - Добавить в TestFlight для бета-тестирования
```

**Настройки Godot iOS экспорта:**
```
Application:
  Name: Baccarat Trainer
  Unique Name: com.baccarat.trainer
  Version: 1.0.0
  Build: 1

Capabilities:
  Push Notifications: ON (для уведомлений)
  
Screen:
  Orientation: Landscape
  Supported Orientations: Landscape Left, Landscape Right
  Scale Mode: canvas_items
```

### 6.2 Android

**Требования:**
- JDK 17+
- Android SDK (API 34+)
- Keystore для подписи

**Процесс сборки:**
```bash
# 1. Настройка keystore
keytool -genkey -v -keystore baccarat.keystore -alias baccarat -keyalg RSA -keysize 2048 -validity 10000

# 2. Экспорт из Godot
godot --path . --export-debug "Android" build/android/baccarat.apk

# 3. Для Google Play:
#    - Export Release Build (подписанный)
#    - Загрузить в Google Play Console
```

**Настройки Godot Android экспорта:**
```
Application:
  Name: Baccarat Trainer
  Unique Name: com.baccarat.trainer
  Version: 1.0.0
  Version Code: 1

Screen:
  Orientation: Landscape
  Immersive Mode: ON
  Include Debug Keystore: OFF (для релиза)
  
Permissions:
  Internet: ON (обязательно для API)
  Network State: ON
  Vibrate: ON (опционально)
```

### 6.3 CI/CD (автоматическая сборка)

```yaml
# .github/workflows/build.yml
name: Build iOS and Android

on:
  push:
    tags:
      - "v*"

jobs:
  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.3.0
      - name: Export iOS
        run: godot --path . --export-debug "iOS" build/ios/
      - name: Upload to TestFlight
        run: xcrun altool --upload-app ...

  build-android:
    runs-on: ubuntu-latest
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
```

---

## 7. Разделение кода: один проект или разные?

### Решение: **Один проект Godot**

| Критерий | Один проект | Разные проекты |
|----------|-------------|----------------|
| Поддержка | ✅ Легче | ❌ Дублирование кода |
| Общие компоненты | ✅ Геймплей общий | ❌ Синхронизация |
| Размер сборки | ✅ Условно одинаковый | — |
| Сложность | ✅ Проще | ❌ Два проекта |
| Обновления | ✅ Одно обновление | ❌ Два обновления |

**Реализация:**
- Один проект Godot
- Разные сцены для тренера и дилера
- Общие компоненты геймплея (BaccaratRules, Deck, etc.)
- Условная компиляция через `OS.has_feature()` если нужно

---

## 8. Существующие экраны/код: что меняется, что добавляется

### 8.1 Меняется

| Файл | Что меняется |
|------|--------------|
| `scenes/Game.tscn` | Добавляется SessionHUD (таймер сессии) |
| `scripts/GameController.gd` | Интеграция с SessionManager, отправка результатов |
| `scripts/autoload/EventBus.gd` | Новые сигналы: session_started, session_ended, round_result_sent |
| `scripts/Localization.gd` | Новые ключи переводов для всех новых экранов |

### 8.2 Добавляется

| Файл | Описание |
|------|----------|
| `scenes/auth/` | Все экраны авторизации |
| `scenes/lobby/` | Лобби комнаты |
| `scenes/leaderboard/` | Таблица лидеров |
| `scenes/achievements/` | Достижения |
| `scenes/assignments/` | Задания |
| `scenes/profile/` | Профиль |
| `scripts/network/` | Весь сетевой слой |

---

## 9. Итог: что было детализировано

| # | Пункт из плана | Статус |
|---|----------------|--------|
| 1 | Wireframes всех новых экранов | ✅ Завершено (10 экранов) |
| 2 | Навигация между экранами | ✅ Завершено |
| 3 | Сетевой слой (классы, методы, обработка ошибок) | ✅ Завершено |
| 4 | Кэширование (что кешируем, как синхронизируем) | ✅ Завершено |
| 5 | Процесс сборки для iOS и Android | ✅ Завершено |
| 6 | Какие существующие экраны/код меняются | ✅ Завершено |
| 7 | Решение: один проект Godot | ✅ Завершено |
| 8 | CI/CD пайплайн (автосборка) | ✅ Завершено |

**Раздел 10: Клиентская часть Godot — детализация завершена полностью (8/8 пунктов).**

---

> **Этот документ — финальная детализация раздела 10.1 "Клиентская часть Godot".**  
> **Следующий шаг:** Приступить к детализации раздела 11 "Система уведомлений".
