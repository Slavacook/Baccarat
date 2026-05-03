## Экран списка сохраненных онлайн-тренировок дилера.
extends Control

const STATUS_LABELS := {
	"online": "Тренировка идёт",
	"offline": "Тренер ещё не начал",
	"closed": "Комната закрыта",
	"revoked": "Доступ отозван",
	"expired": "Доступ истёк",
	"unknown": "Статус неизвестен"
}

const CARD_STATUS_LABELS := {
	"online": "Идёт",
	"offline": "Не началась",
	"closed": "Закрыта",
	"revoked": "Отозван",
	"expired": "Истёк",
	"unknown": "Неизвестно"
}

var status_label: Label
var error_label: Label
var empty_container: Control
var list_scroll: ScrollContainer
var trainings_list: VBoxContainer
var refresh_button: Button
var add_button: Button
var back_button: Button
var _enter_in_progress: bool = false

var _api_service = null
var _access_store = null


func _ready() -> void:
	status_label = find_child("StatusLabel", true, false)
	error_label = find_child("ErrorLabel", true, false)
	empty_container = find_child("EmptyStateContainer", true, false)
	list_scroll = find_child("TrainingsScroll", true, false)
	trainings_list = find_child("TrainingsList", true, false)
	refresh_button = find_child("RefreshButton", true, false)
	add_button = find_child("AddTrainingButton", true, false)
	back_button = find_child("BackButton", true, false)

	_api_service = _find_api_service()
	_access_store = _find_dealer_access_store()

	if refresh_button and not refresh_button.pressed.is_connected(_on_refresh_pressed):
		refresh_button.pressed.connect(_on_refresh_pressed)
	if add_button and not add_button.pressed.is_connected(_on_add_training_pressed):
		add_button.pressed.connect(_on_add_training_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	_hide_error()
	if empty_container:
		empty_container.visible = false
	if list_scroll:
		list_scroll.visible = false
	await _load_trainings()


func _load_trainings() -> void:
	if _access_store == null:
		_show_error("DealerAccessStore не найден")
		_render_records([])
		return

	_access_store.load_store()
	var local_records: Array[Dictionary] = _access_store.get_all()
	var tokens: Array[String] = _access_store.get_participant_tokens()
	if tokens.is_empty():
		_set_status("")
		_render_records([])
		return

	if _api_service == null:
		_show_error("ApiService не найден")
		_render_records(_build_fallback_records(local_records))
		return

	_hide_error()
	_set_loading(true)
	var result: Dictionary = await _api_service.get_dealer_my_rooms(tokens)
	_set_loading(false)

	var code := int(result.get("code", 0))
	var body: Variant = result.get("body", {})
	if code < 200 or code >= 300:
		_show_error("Не удалось загрузить тренировки. Попробуйте ещё раз.")
		_render_records(_build_fallback_records(local_records))
		return
	if not (body is Dictionary):
		_show_error("Сервер вернул неожиданный ответ")
		_render_records(_build_fallback_records(local_records))
		return

	var records := _merge_server_response(local_records, tokens, body as Dictionary)
	_render_records(records)


func _merge_server_response(local_records: Array[Dictionary], tokens: Array[String], body: Dictionary) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	var rooms: Array = _array_or_empty(body.get("rooms", []))
	var invalid_tokens: Array = _array_or_empty(body.get("invalid_tokens", []))
	var local_by_token := {}
	for record in local_records:
		var token := str(record.get("participant_token", "")).strip_edges()
		if token != "":
			local_by_token[token] = record

	var invalid_by_index := {}
	for invalid_item in invalid_tokens:
		if invalid_item is Dictionary:
			var invalid_dict := invalid_item as Dictionary
			invalid_by_index[int(invalid_dict.get("index", -1))] = str(invalid_dict.get("reason", "not_found"))

	var room_pointer := 0
	for index in range(tokens.size()):
		var token := tokens[index]
		var local_record: Dictionary = local_by_token.get(token, {})
		if invalid_by_index.has(index):
			var reason: String = invalid_by_index[index]
			var invalid_record := _build_invalid_record(local_record, token, reason)
			merged.append(invalid_record)
			_access_store.update_cached_info(token, _build_cache_update(invalid_record))
			continue

		if room_pointer >= rooms.size() or not (rooms[room_pointer] is Dictionary):
			merged.append(_build_fallback_record(local_record, token))
			continue

		var room_item := rooms[room_pointer] as Dictionary
		room_pointer += 1
		var merged_record := _build_room_record(local_record, token, room_item)
		merged.append(merged_record)
		_access_store.update_cached_info(token, _build_cache_update(merged_record))

	return merged


func _build_room_record(local_record: Dictionary, token: String, room_item: Dictionary) -> Dictionary:
	var room := _dictionary_or_empty(room_item.get("room", {}))
	var access := _dictionary_or_empty(room_item.get("access", {}))
	var dealer := _dictionary_or_empty(room_item.get("dealer", {}))
	var availability := str(room_item.get("availability", local_record.get("availability", "unknown")))
	var token_status := str(room_item.get("participant_token_status", local_record.get("token_status", "unknown")))

	return {
		"participant_token": token,
		"room_code": str(room.get("room_code", local_record.get("room_code", ""))),
		"room_title": str(room.get("name", local_record.get("room_title", ""))),
		"dealer_display_name": str(dealer.get("display_name", local_record.get("dealer_display_name", ""))),
		"availability": availability,
		"access_status": str(access.get("status", local_record.get("access_status", "unknown"))),
		"token_status": token_status,
		"action": _action_for_availability(availability),
		"cached": {
			"room": room,
			"access": access,
			"dealer": dealer,
			"active_session": _dictionary_or_empty(room_item.get("active_session", {}))
		}
	}


func _build_invalid_record(local_record: Dictionary, token: String, reason: String) -> Dictionary:
	var availability := "unknown"
	var token_status := reason
	match reason:
		"revoked":
			availability = "revoked"
		"expired":
			availability = "expired"
		_:
			availability = "unknown"

	return {
		"participant_token": token,
		"room_code": str(local_record.get("room_code", "")),
		"room_title": str(local_record.get("room_title", "")),
		"dealer_display_name": str(local_record.get("dealer_display_name", "")),
		"availability": availability,
		"access_status": str(local_record.get("access_status", "unknown")),
		"token_status": token_status,
		"action": "delete",
		"cached": _dictionary_or_empty(local_record.get("cached", {}))
	}


func _build_fallback_records(local_records: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record in local_records:
		records.append(_build_fallback_record(record, str(record.get("participant_token", ""))))
	return records


func _build_fallback_record(local_record: Dictionary, token: String) -> Dictionary:
	return {
		"participant_token": token,
		"room_code": str(local_record.get("room_code", "")),
		"room_title": str(local_record.get("room_title", "")),
		"dealer_display_name": str(local_record.get("dealer_display_name", "")),
		"availability": str(local_record.get("availability", "unknown")),
		"access_status": str(local_record.get("access_status", "unknown")),
		"token_status": str(local_record.get("token_status", "unknown")),
		"action": _action_for_availability(str(local_record.get("availability", "unknown"))),
		"cached": _dictionary_or_empty(local_record.get("cached", {}))
	}


func _build_cache_update(record: Dictionary) -> Dictionary:
	return {
		"room_code": record.get("room_code", ""),
		"room_title": record.get("room_title", ""),
		"dealer_display_name": record.get("dealer_display_name", ""),
		"availability": record.get("availability", "unknown"),
		"access_status": record.get("access_status", "unknown"),
		"token_status": record.get("token_status", "unknown"),
		"cached": _dictionary_or_empty(record.get("cached", {}))
	}


func _render_records(records: Array[Dictionary]) -> void:
	_clear_trainings_list()

	var is_empty := records.is_empty()
	if empty_container:
		empty_container.visible = is_empty
	if list_scroll:
		list_scroll.visible = not is_empty

	for record in records:
		trainings_list.add_child(_create_training_card(record))


func _create_training_card(record: Dictionary) -> Button:
	var action_button := Button.new()
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_button.custom_minimum_size = Vector2(0, 62)
	action_button.add_theme_font_size_override("font_size", 20)
	action_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_training_card_style(action_button)

	var action := str(record.get("action", "refresh"))
	match action:
		"delete":
			action_button.text = "%s · Удалить" % _display_room_title(record)
			action_button.pressed.connect(_on_delete_record.bind(str(record.get("participant_token", ""))))
		"enter":
			action_button.text = "%s · %s" % [
				_display_room_title(record),
				_card_status_text(str(record.get("availability", "unknown")))
			]
			action_button.pressed.connect(_on_enter_training_pressed.bind(record, action_button))
		_:
			action_button.text = "%s · %s" % [
				_display_room_title(record),
				_card_status_text(str(record.get("availability", "unknown")))
			]
			action_button.pressed.connect(_on_refresh_pressed)

	return action_button


func _apply_training_card_style(action_button: Button) -> void:
	if action_button == null:
		return

	var normal_style := StyleBoxFlat.new()
	normal_style.content_margin_left = 18.0
	normal_style.content_margin_top = 12.0
	normal_style.content_margin_right = 18.0
	normal_style.content_margin_bottom = 12.0
	normal_style.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.9, 0.72, 0.42, 0.22)
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.shadow_color = Color(0, 0, 0, 0.22)
	normal_style.shadow_size = 4
	normal_style.shadow_offset = Vector2(0, 2)

	var hover_style := StyleBoxFlat.new()
	hover_style.content_margin_left = 18.0
	hover_style.content_margin_top = 12.0
	hover_style.content_margin_right = 18.0
	hover_style.content_margin_bottom = 12.0
	hover_style.bg_color = Color(0.15, 0.19, 0.25, 0.96)
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.border_color = Color(0.95, 0.75, 0.44, 0.3)
	hover_style.corner_radius_top_left = 10
	hover_style.corner_radius_top_right = 10
	hover_style.corner_radius_bottom_right = 10
	hover_style.corner_radius_bottom_left = 10
	hover_style.shadow_color = Color(0, 0, 0, 0.24)
	hover_style.shadow_size = 5
	hover_style.shadow_offset = Vector2(0, 2)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.content_margin_left = 18.0
	pressed_style.content_margin_top = 12.0
	pressed_style.content_margin_right = 18.0
	pressed_style.content_margin_bottom = 12.0
	pressed_style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	pressed_style.border_width_left = 1
	pressed_style.border_width_top = 1
	pressed_style.border_width_right = 1
	pressed_style.border_width_bottom = 1
	pressed_style.border_color = Color(0.82, 0.66, 0.38, 0.16)
	pressed_style.corner_radius_top_left = 10
	pressed_style.corner_radius_top_right = 10
	pressed_style.corner_radius_bottom_right = 10
	pressed_style.corner_radius_bottom_left = 10
	pressed_style.shadow_color = Color(0, 0, 0, 0.18)
	pressed_style.shadow_size = 2
	pressed_style.shadow_offset = Vector2(0, 1)

	action_button.add_theme_stylebox_override("normal", normal_style)
	action_button.add_theme_stylebox_override("hover", hover_style)
	action_button.add_theme_stylebox_override("pressed", pressed_style)


func _status_text(availability: String) -> String:
	return STATUS_LABELS.get(availability, "Статус неизвестен")


func _card_status_text(availability: String) -> String:
	return CARD_STATUS_LABELS.get(availability, "Неизвестно")


func _action_for_availability(availability: String) -> String:
	match availability:
		"closed", "revoked", "expired":
			return "delete"
		"online":
			return "enter"
		_:
			return "refresh"


func _display_room_title(record: Dictionary) -> String:
	var title := str(record.get("room_title", "")).strip_edges()
	if title != "":
		return title
	return "Тренировка"


func _clear_trainings_list() -> void:
	if trainings_list == null:
		return
	for child in trainings_list.get_children():
		child.queue_free()


func _on_refresh_pressed() -> void:
	await _load_trainings()


func _on_enter_training_pressed(record: Dictionary, action_button: Button) -> void:
	if _enter_in_progress:
		return
	if _api_service == null:
		_show_error("ApiService не найден")
		return

	var participant_token: String = str(record.get("participant_token", "")).strip_edges()
	if participant_token.is_empty():
		_show_error("Доступ недействителен")
		return

	_enter_in_progress = true
	_hide_error()
	_set_loading(true)
	_set_status("Входим в тренировку...")
	var original_text := ""
	if action_button:
		original_text = action_button.text
		action_button.disabled = true
		action_button.text = "Входим..."

	var result: Dictionary = await _api_service.exchange_participant_token(participant_token)
	var code: int = int(result.get("code", 0))
	var body: Variant = result.get("body", {})

	if code >= 200 and code < 300 and body is Dictionary:
		var applied: Dictionary = _api_service.apply_exchanged_dealer_session(body as Dictionary, record)
		if applied.get("ok", false):
			get_tree().change_scene_to_file("res://scenes/network/DealerWaitingScreen.tscn")
			return
		_show_error(str(applied.get("error", "Не удалось войти в тренировку")))
	else:
		_show_error(_exchange_error_text(code, body))

	_enter_in_progress = false
	_set_loading(false)
	if action_button:
		action_button.disabled = false
		action_button.text = original_text


func _on_add_training_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/network/AddTrainingScreen.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/StartScreen.tscn")


func _on_delete_record(participant_token: String) -> void:
	if _access_store:
		_access_store.remove_by_participant_token(participant_token)
	await _load_trainings()


func _show_error(text: String) -> void:
	if error_label:
		error_label.text = text
		error_label.visible = true


func _hide_error() -> void:
	if error_label:
		error_label.visible = false


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _set_loading(loading: bool) -> void:
	if refresh_button:
		refresh_button.disabled = loading
	if add_button:
		add_button.disabled = loading
	if back_button:
		back_button.disabled = loading
	_set_status("Загружаем тренировки..." if loading else "")


func _exchange_error_text(code: int, body: Variant) -> String:
	var detail: Dictionary = _dictionary_or_empty(_dictionary_or_empty(body).get("detail", {}))
	var err_code: String = str(detail.get("code", "")).strip_edges()

	match err_code:
		"PARTICIPANT_TOKEN_REVOKED":
			return "Доступ отозван"
		"PARTICIPANT_TOKEN_EXPIRED":
			return "Доступ истёк"
		"ROOM_CLOSED":
			return "Комната закрыта"
		"INVALID_PARTICIPANT_TOKEN", "ROOM_ACCESS_NOT_ACTIVE", "ROOM_ACCESS_MISMATCH":
			return "Доступ недействителен"
		"DEALER_INACTIVE":
			return "Доступ отозван"

	if code == 0:
		return "Не удалось войти. Проверьте подключение."
	if code == 410:
		return "Комната закрыта"
	if code == 401 or code == 403 or code == 404:
		return "Доступ недействителен"
	return "Не удалось войти в тренировку"


func _find_api_service():
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService")
	return get_node_or_null("/root/ApiService")


func _find_dealer_access_store():
	if Engine.has_singleton("DealerAccessStore"):
		return Engine.get_singleton("DealerAccessStore")
	return get_node_or_null("/root/DealerAccessStore")


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return value
	return []
