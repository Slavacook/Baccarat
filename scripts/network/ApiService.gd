## Сервис API — единая точка входа для всех HTTP-запросов.
## (autoload — class_name НЕ нужен)
extends Node

var api_client: APIClient
var auth_manager: AuthManager

## Очередной «именованный» HTTP-запрос (чтобы await из лобби не пересёкся с общим разбором).
var _http_op: String = ""

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal trainer_logged_in(user: Dictionary)
signal dealer_joined(user: Dictionary)
signal request_error(status_code: int, detail: String)
signal network_error(message: String)
signal rooms_list_loaded(rooms: Array)
## Результат «именованного» HTTP-запроса для await из лобби (один словарь — стабильный await в GDScript).
signal http_operation_completed(packet: Dictionary)


# ═══════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	auth_manager = AuthManager.new()
	auth_manager.name = "AuthManager"
	add_child(auth_manager)

	api_client = APIClient.new()
	api_client.name = "APIClient_Node"
	add_child(api_client)

	if auth_manager.access_token != "":
		api_client.set_auth_token(auth_manager.access_token)

	api_client.request_completed.connect(_on_request_completed)
	api_client.request_failed.connect(_on_request_failed)
	print("🌐 ApiService готов. URL:", api_client.base_url)


# ═══════════════════════════════════════════════════════════════
# АВТОРИЗАЦИЯ — ТРЕНЕР
# ═══════════════════════════════════════════════════════════════

func trainer_register(email: String, password: String, full_name: String = "") -> void:
	var body: Dictionary = {"email": email, "password": password}
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
	auth_manager.clear_tokens()


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
# ACCESS-ДОСТУПЫ ДИЛЕРА
# ═══════════════════════════════════════════════════════════════

func activate_dealer_access(access_code: String, display_name: String) -> Dictionary:
	_http_op = "activate_dealer_access"
	api_client.post_public("/api/dealer/accesses/activate", {
		"access_code": access_code,
		"display_name": display_name
	})
	var pkt: Dictionary = await http_operation_completed
	return {"code": int(pkt.get("code", 0)), "body": pkt.get("body")}


func activate_dealer_invite(invite_code: String, display_name: String) -> Dictionary:
	_http_op = "activate_dealer_invite"
	api_client.post_public("/api/dealer/invites/activate", {
		"invite_code": invite_code,
		"display_name": display_name
	})
	var pkt: Dictionary = await http_operation_completed
	return {"code": int(pkt.get("code", 0)), "body": pkt.get("body")}


func get_dealer_my_rooms(participant_tokens: Array) -> Dictionary:
	_http_op = "dealer_my_rooms"
	api_client.post_public("/api/dealer/my-rooms", {
		"participant_tokens": participant_tokens
	})
	var pkt: Dictionary = await http_operation_completed
	return {"code": int(pkt.get("code", 0)), "body": pkt.get("body")}


func exchange_participant_token(participant_token: String) -> Dictionary:
	_http_op = "exchange_participant_token"
	api_client.post_public("/api/dealer/tokens/exchange", {
		"participant_token": participant_token
	})
	var pkt: Dictionary = await http_operation_completed
	return {"code": int(pkt.get("code", 0)), "body": pkt.get("body")}


func apply_exchanged_dealer_session(exchange_body: Dictionary, fallback_record: Dictionary = {}) -> Dictionary:
	if not (exchange_body is Dictionary):
		return {"ok": false, "error": "Сервер вернул неверный ответ"}

	var access_token: String = str(exchange_body.get("access_token", "")).strip_edges()
	if access_token.is_empty():
		return {"ok": false, "error": "Сервер не вернул токен входа"}

	var dealer: Dictionary = {}
	if exchange_body.get("dealer", null) is Dictionary:
		dealer = exchange_body.get("dealer", {}) as Dictionary

	var dealer_id: String = str(dealer.get("id", "")).strip_edges()
	var display_name: String = str(dealer.get("display_name", "")).strip_edges()
	var room_id: String = str(dealer.get("room_id", "")).strip_edges()
	var room_code: String = str(dealer.get("room_code", "")).strip_edges()

	if room_code.is_empty():
		room_code = str(fallback_record.get("room_code", "")).strip_edges()

	if dealer_id.is_empty() or display_name.is_empty() or room_code.is_empty():
		return {"ok": false, "error": "Сервер не вернул данные дилера для входа"}

	var user_data: Dictionary = {
		"id": dealer_id,
		"role": "dealer",
		"display_name": display_name,
		"room_id": room_id,
		"room_code": room_code
	}

	api_client.set_auth_token(access_token)
	auth_manager.save_tokens(access_token, "", user_data)
	return {"ok": true, "user": user_data}


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
# LIVE-СЕССИИ (async для лобби)
# ═══════════════════════════════════════════════════════════════

func create_live_session_async(room_code: String, duration_minutes: int = 30, max_rounds: Variant = null) -> Dictionary:
	_http_op = "create_live"
	var payload: Dictionary = {"duration_minutes": duration_minutes}
	if max_rounds != null:
		payload["max_rounds"] = max_rounds
	api_client.post("/api/rooms/%s/sessions" % room_code, payload)
	var pkt: Dictionary = await http_operation_completed
	return {"code": int(pkt.get("code", 0)), "body": pkt.get("body")}


func start_live_session_async(session_id: String) -> Dictionary:
	_http_op = "start_live"
	api_client.post("/api/sessions/%s/start" % session_id, {})
	var pkt: Dictionary = await http_operation_completed
	return {"code": int(pkt.get("code", 0)), "body": pkt.get("body")}


func fetch_active_live_session_async(room_code: String) -> Dictionary:
	_http_op = "fetch_active_live"
	api_client.get_request("/api/rooms/%s/active-live-session" % room_code)
	var pkt: Dictionary = await http_operation_completed
	return {"code": int(pkt.get("code", 0)), "body": pkt.get("body")}


func submit_round_result_async(session_id: String, payload: Dictionary) -> int:
	_http_op = "round_result"
	api_client.post("/api/sessions/%s/round-results" % session_id, payload)
	var pkt: Dictionary = await http_operation_completed
	return int(pkt.get("code", 0))


# ═══════════════════════════════════════════════════════════════
# ОБРАБОТКА ОТВЕТОВ
# ═══════════════════════════════════════════════════════════════

func _on_request_completed(_request_id: int, response_code: int, body: Variant) -> void:
	print("📥 Ответ от сервера: Код ", response_code)

	if _http_op != "":
		var op: String = _http_op
		_http_op = ""
		http_operation_completed.emit({"operation": op, "code": response_code, "body": body})
		return

	if body is Array and response_code == 200:
		rooms_list_loaded.emit(body as Array)
		return

	if response_code < 200 or response_code >= 300:
		var detail: String = "Ошибка сервера"
		if body is Dictionary:
			detail = str((body as Dictionary).get("detail", detail))
		print("❌ Ошибка сервера: ", detail)
		request_error.emit(response_code, detail)
		return

	if not body is Dictionary:
		print("⚠️ Ответ OK, но неизвестный формат")
		return

	var d: Dictionary = body as Dictionary

	if d.has("access_token") and d.has("user"):
		var at: String = str(d.get("access_token", ""))
		var rt: String = str(d.get("refresh_token", ""))
		var user: Dictionary = d["user"] as Dictionary
		api_client.set_auth_token(at)
		auth_manager.save_tokens(at, rt, user)
		var role: String = str(user.get("role", ""))
		print("✅ Успешный вход! Роль: ", role)
		if role == "trainer":
			trainer_logged_in.emit(user)
		elif role == "dealer":
			dealer_joined.emit(user)
	elif d.has("room") and d.has("pins"):
		print("✅ Комната создана: ", d["room"].get("room_code", ""))
	else:
		print("⚠️ Ответ OK, но неизвестный формат")


func _on_request_failed(_request_id: int, _error_code: int, error_message: String) -> void:
	if _http_op != "":
		var op: String = _http_op
		_http_op = ""
		http_operation_completed.emit({"operation": op, "code": 0, "body": {"detail": error_message}})
		return
	print("🔌 Ошибка сети: ", error_message)
	network_error.emit(error_message)
