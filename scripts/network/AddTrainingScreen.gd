## Экран добавления тренировки по персональному access-code.
extends Control

signal go_back
signal training_added(record: Dictionary)

const ACCESS_CODE_ALLOWED_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var access_code_input: LineEdit
var display_name_input: LineEdit
var paste_code_btn: Button
var connect_btn: Button
var back_btn: Button
var error_label: Label
var status_label: Label
var form_scroll: ScrollContainer
var keyboard_spacer: Control
var _active_input: Control
var _keyboard_focus_version: int = 0

var _api_service = null
var _access_store = null


func _ready() -> void:
	form_scroll = find_child("FormScroll", true, false)
	access_code_input = find_child("AccessCodeInput", true, false)
	display_name_input = find_child("DisplayNameInput", true, false)
	paste_code_btn = find_child("PasteCodeBtn", true, false)
	connect_btn = find_child("ConnectBtn", true, false)
	back_btn = find_child("BackBtn", true, false)
	error_label = find_child("ErrorLabel", true, false)
	status_label = find_child("StatusLabel", true, false)
	keyboard_spacer = find_child("KeyboardSpacer", true, false)

	_api_service = _find_api_service()
	_access_store = _find_dealer_access_store()

	if connect_btn and not connect_btn.pressed.is_connected(_on_connect_pressed):
		connect_btn.pressed.connect(_on_connect_pressed)
	if paste_code_btn and not paste_code_btn.pressed.is_connected(_on_paste_code_pressed):
		paste_code_btn.pressed.connect(_on_paste_code_pressed)
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if access_code_input and not access_code_input.text_changed.is_connected(_on_access_code_changed):
		access_code_input.text_changed.connect(_on_access_code_changed)
	if access_code_input and not access_code_input.focus_entered.is_connected(_on_input_focus_entered.bind(access_code_input)):
		access_code_input.focus_entered.connect(_on_input_focus_entered.bind(access_code_input))
	if access_code_input and not access_code_input.focus_exited.is_connected(_on_input_focus_exited):
		access_code_input.focus_exited.connect(_on_input_focus_exited)
	if display_name_input and not display_name_input.focus_entered.is_connected(_on_input_focus_entered.bind(display_name_input)):
		display_name_input.focus_entered.connect(_on_input_focus_entered.bind(display_name_input))
	if display_name_input and not display_name_input.focus_exited.is_connected(_on_input_focus_exited):
		display_name_input.focus_exited.connect(_on_input_focus_exited)

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

	var result: Dictionary = await _activate_training_access(access_code, display_name)
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


func _activate_training_access(access_code: String, display_name: String) -> Dictionary:
	var access_result: Dictionary = await _api_service.activate_dealer_access(access_code, display_name)
	var status_code := int(access_result.get("code", 0))
	if status_code >= 200 and status_code < 300:
		return access_result

	var body: Variant = access_result.get("body", {})
	if not _should_try_invite_activation(status_code, body):
		return access_result

	return await _api_service.activate_dealer_invite(access_code, display_name)


func _should_try_invite_activation(status_code: int, body: Variant) -> bool:
	if status_code != 404:
		return false
	if not (body is Dictionary):
		return false

	var detail: Variant = (body as Dictionary).get("detail", {})
	if not (detail is Dictionary):
		return false

	return str((detail as Dictionary).get("code", "")) == "INVALID_ACCESS_CODE"


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
		"INVALID_INVITE_CODE":
			return "Код доступа не найден"
		"ACCESS_ALREADY_ACTIVATED":
			return "Этот код уже активирован"
		"ACCESS_REVOKED":
			return "Этот доступ отозван тренером"
		"INVITE_REVOKED":
			return "Это приглашение отозвано"
		"INVITE_EXPIRED":
			return "Срок действия приглашения истёк"
		"INVITE_NOT_ACTIVE":
			return "Это приглашение недоступно"
		"ROOM_PARTICIPANT_LIMIT_REACHED":
			return "Лимит участников комнаты достигнут"
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


func _on_paste_code_pressed() -> void:
	if access_code_input == null:
		return

	var clipboard_text := str(DisplayServer.clipboard_get()).strip_edges()
	if clipboard_text == "":
		_show_error("Буфер обмена пуст")
		return

	_hide_error()
	var normalized_code := _normalize_access_code(clipboard_text)
	if normalized_code == "":
		_show_error("В буфере обмена нет кода доступа")
		return

	access_code_input.text = normalized_code
	access_code_input.caret_column = normalized_code.length()
	_set_status("Код вставлен из буфера обмена")

	if display_name_input:
		display_name_input.grab_focus()
		_on_input_focus_entered(display_name_input)


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
	_active_input = target
	_keyboard_focus_version += 1
	var focus_version := _keyboard_focus_version
	form_scroll.call_deferred("ensure_control_visible", target)
	_run_keyboard_focus_adjustment(target, focus_version)


func _on_input_focus_exited() -> void:
	_handle_input_focus_exit()


func _input(event: InputEvent) -> void:
	if _active_input == null:
		return
	if not _is_tap_event(event):
		return

	var tap_position := _event_position(event)
	if _is_position_inside_input(access_code_input, tap_position):
		return
	if _is_position_inside_input(display_name_input, tap_position):
		return

	_dismiss_keyboard()


func _run_keyboard_focus_adjustment(target: Control, focus_version: int) -> void:
	if target == null or form_scroll == null:
		return

	var keyboard_height := 0.0
	for _i in range(4):
		if get_tree() == null:
			return
		await get_tree().create_timer(0.08).timeout
		if focus_version != _keyboard_focus_version or target != _active_input:
			return
		keyboard_height = DisplayServer.virtual_keyboard_get_height()
		if keyboard_height > 0.0:
			break

	if focus_version != _keyboard_focus_version or target != _active_input:
		return

	var spacer_height := int(keyboard_height) if keyboard_height > 0.0 else 220
	_set_keyboard_spacer_height(spacer_height)
	form_scroll.call_deferred("ensure_control_visible", target)


func _handle_input_focus_exit() -> void:
	if get_tree() == null:
		return

	await get_tree().create_timer(0.12).timeout
	if _has_input_focus():
		return

	_dismiss_keyboard()


func _has_input_focus() -> bool:
	return (access_code_input != null and access_code_input.has_focus()) \
		or (display_name_input != null and display_name_input.has_focus())


func _dismiss_keyboard() -> void:
	_keyboard_focus_version += 1

	if access_code_input and access_code_input.has_focus():
		access_code_input.release_focus()
	if display_name_input and display_name_input.has_focus():
		display_name_input.release_focus()

	_active_input = null
	_set_keyboard_spacer_height(0)
	DisplayServer.virtual_keyboard_hide()


func _is_tap_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2.ZERO


func _is_position_inside_input(target: Control, position: Vector2) -> bool:
	return target != null and target.get_global_rect().has_point(position)


func _set_keyboard_spacer_height(height: int) -> void:
	if keyboard_spacer == null:
		return
	keyboard_spacer.custom_minimum_size = Vector2(0, max(height, 0))


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
	if paste_code_btn:
		paste_code_btn.disabled = loading
	if back_btn:
		back_btn.disabled = loading
	_set_status("Проверяем код..." if loading else "")
