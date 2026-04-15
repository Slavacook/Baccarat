## Сервис API — единая точка входа для всех HTTP-запросов.
## (autoload — class_name НЕ нужен)
extends Node

var api_client: APIClient

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal trainer_logged_in(user: Dictionary)
signal dealer_joined(user: Dictionary)
signal request_error(status_code: int, detail: String)
signal network_error(message: String)

# ═══════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	api_client = APIClient.new()
	api_client.name = "APIClient_Node"
	add_child(api_client)
	
	# Подключаем сигналы
	api_client.request_completed.connect(_on_request_completed)
	api_client.request_failed.connect(_on_request_failed)
	print("🌐 ApiService готов. URL:", api_client.base_url)

# ═══════════════════════════════════════════════════════════════
# АВТОРИЗАЦИЯ — ТРЕНЕР
# ═══════════════════════════════════════════════════════════════

func trainer_register(email: String, password: String, full_name: String = "") -> void:
	var body = {"email": email, "password": password}
	if full_name != "":
		body["full_name"] = full_name
	print("📡 Регистрация тренера: ", email)
	api_client.post("/api/auth/trainer/register", body)

func trainer_login(email: String, password: String) -> void:
	print("📡 Вход тренера: ", email)
	api_client.post("/api/auth/trainer/login", {"email": email, "password": password})

func trainer_logout() -> void:
	if api_client:
		api_client.post("/api/auth/trainer/logout", {})
		await api_client.request_completed
	api_client.clear_auth_token()

# ═══════════════════════════════════════════════════════════════
# АВТОРИЗАЦИЯ — ДИЛЕР
# ═══════════════════════════════════════════════════════════════

func dealer_join(room_code: String, pin: String, display_name: String) -> void:
	print("📡 Вход дилера: комната=%s, имя=%s" % [room_code, display_name])
	api_client.post("/api/rooms/dealer/join", {
		"room_code": room_code,
		"pin": pin,
		"display_name": display_name
	})

# ═══════════════════════════════════════════════════════════════
# КОМНАТЫ
# ═══════════════════════════════════════════════════════════════

func create_room(room_name: String, max_dealers: int = 10) -> void:
	print("📡 Создание комнаты: ", room_name)
	api_client.post("/api/rooms/", {"name": room_name, "max_dealers": max_dealers})

func list_rooms() -> void:
	api_client.get_request("/api/rooms/")

func get_room(room_code: String) -> void:
	api_client.get_request("/api/rooms/%s" % room_code)

# ═══════════════════════════════════════════════════════════════
# ОБРАБОТКА ОТВЕТОВ
# ═══════════════════════════════════════════════════════════════

func _on_request_completed(_request_id: int, response_code: int, body: Dictionary) -> void:
	print("📥 Ответ от сервера: Код ", response_code)
	
	if response_code == 200 or response_code == 201:
		if body.has("user") and body.has("access_token"):
			var role = body["user"].get("role", "")
			print("✅ Успешный вход! Роль: ", role)
			if role == "trainer":
				trainer_logged_in.emit(body["user"])
			elif role == "dealer":
				dealer_joined.emit(body["user"])
		elif body.has("room") and body.has("pins"):
			print("✅ Комната создана: ", body["room"].get("room_code", ""))
		else:
			print("⚠️ Ответ OK, но неизвестный формат")
	else:
		var detail = str(body.get("detail", "Ошибка сервера"))
		print("❌ Ошибка сервера: ", detail)
		request_error.emit(response_code, detail)

func _on_request_failed(_request_id: int, _error_code: int, error_message: String) -> void:
	print("🔌 Ошибка сети: ", error_message)
	network_error.emit(error_message)
