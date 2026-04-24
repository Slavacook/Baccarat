## HTTP-клиент для взаимодействия с сервером Baccarat Trainer.
## Оборачивает HTTPRequest и предоставляет удобные методы для REST API.
class_name APIClient
extends Node

# ═══════════════════════════════════════════════════════════════
# НАСТРОЙКИ
# ═══════════════════════════════════════════════════════════════

@export var base_url: String = "https://baccarat-trainer.ru"

var _http_request: HTTPRequest
var _auth_token: String = ""

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal request_completed(request_id: int, response_code: int, body: Variant)
signal request_failed(request_id: int, error_code: int, error_message: String)

# ═══════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 10.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)


func set_auth_token(token: String) -> void:
	_auth_token = token


func clear_auth_token() -> void:
	_auth_token = ""


# ═══════════════════════════════════════════════════════════════
# HTTP МЕТОДЫ
# ═══════════════════════════════════════════════════════════════

func get_request(path: String, query_params: Dictionary = {}) -> int:
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


func delete_request(path: String) -> int:
	var url = _build_url(path)
	var headers = _build_headers()
	return _http_request.request(url, headers, HTTPClient.METHOD_DELETE)


# ═══════════════════════════════════════════════════════════════
# ВНУТРЕННИЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════

func _build_url(path: String, query_params: Dictionary = {}) -> String:
	var url = base_url + path
	if not query_params.is_empty():
		var parts: PackedStringArray = []
		for key in query_params:
			parts.append("%s=%s" % [key, query_params[key]])
		url += "?" + "&".join(parts)
	return url


func _build_headers() -> PackedStringArray:
	var headers = PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])
	if _auth_token != "":
		headers.append("Authorization: Bearer %s" % _auth_token)
	return headers


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit(0, result, "Ошибка сети: %d" % result)
		return

	var response_text = body.get_string_from_utf8()
	if response_text.is_empty():
		request_completed.emit(0, response_code, {})
		return

	var json_parse = JSON.new()
	var parse_err = json_parse.parse(response_text)
	if parse_err != OK:
		request_failed.emit(0, response_code, "Неверный JSON от сервера")
		return

	var data: Variant = json_parse.data
	if data is Dictionary or data is Array:
		request_completed.emit(0, response_code, data)
	else:
		request_failed.emit(0, response_code, "Ожидался JSON-объект или массив")
