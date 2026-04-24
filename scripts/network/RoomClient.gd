## Клиент для API комнат — обёртка над APIClient.
class_name RoomClient
extends Node

var _api: APIClient

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal room_created(response: Dictionary)
signal room_create_failed(error: String)
signal rooms_loaded(rooms: Array)
signal rooms_load_failed(error: String)
signal room_loaded(room: Dictionary)
signal dealer_joined(response: Dictionary)
signal dealer_join_failed(error: String)


# ═══════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	# Ищем APIClient в дереве сцены
	_api = _find_api_client()
	if _api:
		_api.request_completed.connect(_on_request_completed)
		_api.request_failed.connect(_on_request_failed)


func _find_api_client() -> APIClient:
	# Ищем в родителях или autoload
	if Engine.has_singleton("APIClient"):
		return Engine.get_singleton("APIClient") as APIClient
	# Ищем в дереве
	var node = get_tree().root.find_child("APIClient", true, false)
	if node:
		return node as APIClient
	return null


func set_api_client(api: APIClient) -> void:
	if _api:
		_api.request_completed.disconnect(_on_request_completed)
		_api.request_failed.disconnect(_on_request_failed)
	_api = api
	_api.request_completed.connect(_on_request_completed)
	_api.request_failed.connect(_on_request_failed)


# ═══════════════════════════════════════════════════════════════
# API МЕТОДЫ
# ═══════════════════════════════════════════════════════════════

func create_room(name: String, max_dealers: int = 10) -> void:
	if not _api:
		room_create_failed.emit("APIClient не настроен")
		return
	_api.post("/api/rooms/", {"name": name, "max_dealers": max_dealers})


func list_rooms() -> void:
	if not _api:
		rooms_load_failed.emit("APIClient не настроен")
		return
	_api.get_request("/api/rooms/")


func get_room(room_code: String) -> void:
	if not _api:
		room_create_failed.emit("APIClient не настроен")
		return
	_api.get_request("/api/rooms/%s" % room_code)


func join_room(room_code: String, pin: String, display_name: String) -> void:
	if not _api:
		dealer_join_failed.emit("APIClient не настроен")
		return
	_api.post("/api/rooms/dealer/join", {
		"room_code": room_code,
		"pin": pin,
		"display_name": display_name
	})


# ═══════════════════════════════════════════════════════════════
# ОБРАБОТКА ОТВЕТОВ
# ═══════════════════════════════════════════════════════════════

func _on_request_completed(_request_id: int, response_code: int, body: Variant) -> void:
	# Определяем какой запрос был по последнему вызову
	# В простой реализации обрабатываем по контексту
	match response_code:
		201:
			# Room created
			room_created.emit(body)
		200:
			# Could be rooms list, room details, or dealer join
			if typeof(body) == TYPE_DICTIONARY:
				var d: Dictionary = body as Dictionary
				if d.has("room") and d.has("pins"):
					room_created.emit(d)
				elif d.has("user") and d.has("access_token"):
					dealer_joined.emit(d)
				else:
					room_loaded.emit(d)
			elif body is Array:
				rooms_loaded.emit(body)
		_:
			if typeof(body) == TYPE_DICTIONARY:
				var d2: Dictionary = body as Dictionary
				if d2.has("detail"):
					var error = d2["detail"] if typeof(d2["detail"]) == TYPE_STRING else str(d2["detail"])
					room_create_failed.emit(error)


func _on_request_failed(_request_id: int, error_code: int, error_message: String) -> void:
	room_create_failed.emit("Ошибка сети: %s" % error_message)
