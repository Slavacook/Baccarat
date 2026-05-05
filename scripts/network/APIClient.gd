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
var _debug_request_seq: int = 0
var _active_request_trace: Dictionary = {}
var _last_failure_debug_reason: String = ""

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


func get_last_failure_debug_reason() -> String:
	return _last_failure_debug_reason


# ═══════════════════════════════════════════════════════════════
# HTTP МЕТОДЫ
# ═══════════════════════════════════════════════════════════════

func get_request(path: String, query_params: Dictionary = {}) -> int:
	var url = _build_url(path, query_params)
	var headers = _build_headers()
	return _start_request("GET", path, url, headers, HTTPClient.METHOD_GET)


func get_public_request(path: String, query_params: Dictionary = {}) -> int:
	var url = _build_url(path, query_params)
	var headers = _build_headers(false)
	return _start_request("GET", path, url, headers, HTTPClient.METHOD_GET)


func post(path: String, body: Dictionary) -> int:
	var url = _build_url(path)
	var headers = _build_headers()
	var json = JSON.stringify(body)
	return _start_request("POST", path, url, headers, HTTPClient.METHOD_POST, json)


func post_public(path: String, body: Dictionary) -> int:
	var url = _build_url(path)
	var headers = _build_headers(false)
	var json = JSON.stringify(body)
	return _start_request("POST", path, url, headers, HTTPClient.METHOD_POST, json)


func patch(path: String, body: Dictionary) -> int:
	var url = _build_url(path)
	var headers = _build_headers()
	var json = JSON.stringify(body)
	return _start_request("PATCH", path, url, headers, HTTPClient.METHOD_PATCH, json)


func delete_request(path: String) -> int:
	var url = _build_url(path)
	var headers = _build_headers()
	return _start_request("DELETE", path, url, headers, HTTPClient.METHOD_DELETE)


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


func _build_headers(include_auth: bool = true) -> PackedStringArray:
	var headers = PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])
	if include_auth and _auth_token != "":
		headers.append("Authorization: Bearer %s" % _auth_token)
	return headers


func _start_request(
	method_label: String,
	path: String,
	url: String,
	headers: PackedStringArray,
	method: HTTPClient.Method,
	body: String = ""
) -> int:
	_debug_request_seq += 1
	_active_request_trace = {
		"seq": _debug_request_seq,
		"method": method_label,
		"path": path,
		"url": url,
		"started_at_ms": Time.get_ticks_msec()
	}
	_last_failure_debug_reason = ""

	var start_code := _http_request.request(url, headers, method, body)
	print("🧪 APIClient TRACE start seq=%d method=%s path=%s url=%s start_code=%d" % [
		_debug_request_seq,
		method_label,
		path,
		url,
		start_code
	])

	if start_code != OK:
		_last_failure_debug_reason = "request_start_failed"
		print("🧪 APIClient TRACE start_failed seq=%d method=%s path=%s url=%s error_code=%d" % [
			_debug_request_seq,
			method_label,
			path,
			url,
			start_code
		])
		request_failed.emit(0, start_code, "Ошибка запуска HTTPRequest: %d" % start_code)

	return start_code


func _trace_value(source: Dictionary, key: String, fallback: Variant) -> Variant:
	if source.has(key):
		return source[key]
	return fallback


func _body_preview(text: String, max_len: int = 240) -> String:
	var normalized := text.replace("\n", "\\n").replace("\r", "\\r")
	if normalized.length() <= max_len:
		return normalized
	return normalized.substr(0, max_len) + "…"


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var seq := int(_trace_value(_active_request_trace, "seq", 0))
	var method_label := str(_trace_value(_active_request_trace, "method", ""))
	var path := str(_trace_value(_active_request_trace, "path", ""))
	var url := str(_trace_value(_active_request_trace, "url", ""))
	var body_size := body.size()
	print("🧪 APIClient TRACE complete seq=%d method=%s path=%s url=%s result=%d response_code=%d body_size=%d" % [
		seq,
		method_label,
		path,
		url,
		result,
		response_code,
		body_size
	])

	if result != HTTPRequest.RESULT_SUCCESS:
		_last_failure_debug_reason = "network_or_http_request_error"
		request_failed.emit(0, result, "Ошибка сети: %d" % result)
		return

	var response_text = body.get_string_from_utf8()
	if response_text.is_empty():
		print("🧪 APIClient TRACE empty_body seq=%d method=%s path=%s response_code=%d" % [
			seq,
			method_label,
			path,
			response_code
		])
		request_completed.emit(0, response_code, {})
		return

	var json_parse = JSON.new()
	var parse_err = json_parse.parse(response_text)
	if parse_err != OK:
		_last_failure_debug_reason = "parse_or_invalid_response"
		print("🧪 APIClient TRACE parse_failed seq=%d method=%s path=%s response_code=%d parse_err=%d body_preview=%s" % [
			seq,
			method_label,
			path,
			response_code,
			parse_err,
			_body_preview(response_text)
		])
		request_failed.emit(0, response_code, "Неверный JSON от сервера")
		return

	var data: Variant = json_parse.data
	print("🧪 APIClient TRACE parse_ok seq=%d method=%s path=%s response_code=%d body_type=%s" % [
		seq,
		method_label,
		path,
		response_code,
		type_string(typeof(data))
	])
	if data is Dictionary or data is Array:
		request_completed.emit(0, response_code, data)
	else:
		_last_failure_debug_reason = "parse_or_invalid_response"
		print("🧪 APIClient TRACE invalid_body seq=%d method=%s path=%s response_code=%d body_type=%s body_preview=%s" % [
			seq,
			method_label,
			path,
			response_code,
			type_string(typeof(data)),
			_body_preview(response_text)
		])
		request_failed.emit(0, response_code, "Ожидался JSON-объект или массив")
