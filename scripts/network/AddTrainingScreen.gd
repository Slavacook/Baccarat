## Экран добавления тренировки по персональному access-code.
extends Control

signal go_back
signal training_added(record: Dictionary)

const ACCESS_CODE_ALLOWED_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var access_code_input: LineEdit
var display_name_input: LineEdit
var connect_btn: Button
var back_btn: Button
var error_label: Label
var status_label: Label
var form_scroll: ScrollContainer

var _api_service = null
var _access_store = null


func _ready() -> void:
	form_scroll = find_child("FormScroll", true, false)
	access_code_input = find_child("AccessCodeInput", true, false)
	display_name_input = find_child("DisplayNameInput", true, false)
	connect_btn = find_child("ConnectBtn", true, false)
	back_btn = find_child("BackBtn", true, false)
	error_label = find_child("ErrorLabel", true, false)
	status_label = find_child("StatusLabel", true, false)

	_api_service = _find_api_service()
	_access_store = _find_dealer_access_store()

	if connect_btn and not connect_btn.pressed.is_connected(_on_connect_pressed):
		connect_btn.pressed.connect(_on_connect_pressed)
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if access_code_input and not access_code_input.text_changed.is_connected(_on_access_code_changed):
		access_code_input.text_changed.connect(_on_access_code_changed)
	if access_code_input and not access_code_input.focus_entered.is_connected(_on_input_focus_entered.bind(access_code_input)):
		access_code_input.focus_entered.connect(_on_input_focus_entered.bind(access_code_input))
	if display_name_input and not display_name_input.focus_entered.is_connected(_on_input_focus_entered.bind(display_name_input)):
		display_name_input.focus_entered.connect(_on_input_focus_entered.bind(display_name_input))

	_hide_error()
	_set_status("")


func _on_connect_pressed() -> void:
	var access_code := _normalize_access_code(access_code_input.text if access_code_input else "")
	var display_name := display_name_input.text.strip_edges() if display_name_input else ""

	if access_code == "":
		_show_error("Введите код доступа")
		return
	if display_name == "":
		_show_error("Введите ваше имя")
		return
	if _api_service == null:
		_show_error("ApiService не найден")
		return
	if _access_store == null:
		_show_error("DealerAccessStore не найден")
		return

	_hide_error()
	_set_loading(true)

	var result: Dictionary = await _api_service.activate_dealer_access(access_code, display_name)
	_set_loading(false)

	var code := int(result.get("code", 0))
	var body: Variant = result.get("body", {})
	if code < 200 or code >= 300:
		_show_error(_activation_error_message(code, body))
		return
	if not (body is Dictionary):
		_show_error("Сервер вернул неожиданный ответ")
		return

	var response := body as Dictionary
	var participant_token := str(response.get("participant_token", "")).strip_edges()
	if participant_token == "":
		_show_error("Сервер не вернул participant token")
		return

	var record := _build_access_record(participant_token, response, display_name)
	if not _access_store.add_or_update_access(record):
		_show_error("Не удалось сохранить доступ на устройстве")
		return

	_set_status("Тренировка добавлена")
	training_added.emit(record)
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/network/MyTrainingsScreen.tscn")


func _build_access_record(participant_token: String, response: Dictionary, fallback_display_name: String) -> Dictionary:
	var room := _dictionary_or_empty(response.get("room", {}))
	var dealer := _dictionary_or_empty(response.get("dealer", {}))
	var access := _dictionary_or_empty(response.get("access", {}))

	return {
		"participant_token": participant_token,
		"room_code": str(room.get("room_code", "")),
		"room_title": str(room.get("name", "")),
		"dealer_display_name": str(dealer.get("display_name", fallback_display_name)),
		"availability": "unknown",
		"access_status": str(access.get("status", "unknown")),
		"token_status": "active",
		"cached": {
			"room": room,
			"dealer": dealer,
			"access": access
		}
	}


func _activation_error_message(status_code: int, body: Variant) -> String:
	var code := ""
	var message := "Не удалось добавить тренировку"

	if body is Dictionary:
		var detail: Variant = (body as Dictionary).get("detail", {})
		if detail is Dictionary:
			code = str((detail as Dictionary).get("code", ""))
			message = str((detail as Dictionary).get("message", message))
		else:
			message = str(detail)

	match code:
		"INVALID_ACCESS_CODE":
			return "Код доступа не найден"
		"ACCESS_ALREADY_ACTIVATED":
			return "Этот код уже активирован"
		"ACCESS_REVOKED":
			return "Этот доступ отозван тренером"
		"ACCESS_CLOSED", "ROOM_CLOSED":
			return "Эта тренировка закрыта"
		"DISPLAY_NAME_REQUIRED":
			return "Введите ваше имя"

	if status_code == 0:
		return "Нет связи с сервером"
	return message


func _on_access_code_changed(text: String) -> void:
	var formatted := _format_access_code(text)
	if formatted == text:
		return
	access_code_input.text = formatted
	access_code_input.caret_column = formatted.length()


func _format_access_code(value: String) -> String:
	var cleaned := ""
	for ch in value.to_upper():
		if ACCESS_CODE_ALLOWED_CHARS.contains(ch):
			cleaned += ch
		if cleaned.length() >= 12:
			break

	var parts: Array[String] = []
	for i in range(0, cleaned.length(), 4):
		parts.append(cleaned.substr(i, 4))
	return "-".join(parts)


func _normalize_access_code(value: String) -> String:
	return _format_access_code(value.strip_edges())


func _on_input_focus_entered(target: Control) -> void:
	if form_scroll == null or target == null:
		return
	form_scroll.call_deferred("ensure_control_visible", target)


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _on_back_pressed() -> void:
	go_back.emit()
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/network/MyTrainingsScreen.tscn")


func _find_api_service():
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService")
	return get_node_or_null("/root/ApiService")


func _find_dealer_access_store():
	if Engine.has_singleton("DealerAccessStore"):
		return Engine.get_singleton("DealerAccessStore")
	return get_node_or_null("/root/DealerAccessStore")


func _show_error(text: String) -> void:
	if error_label:
		error_label.text = text
		error_label.visible = true
	_set_status("")


func _hide_error() -> void:
	if error_label:
		error_label.visible = false


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _set_loading(loading: bool) -> void:
	if connect_btn:
		connect_btn.disabled = loading
		connect_btn.text = "Подключение..." if loading else "Подключиться"
	if back_btn:
		back_btn.disabled = loading
	_set_status("Проверяем код..." if loading else "")
