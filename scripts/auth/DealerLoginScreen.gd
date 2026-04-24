## Экран входа дилера — код комнаты + PIN-код + имя.
extends Control

signal go_back

var room_code_input: LineEdit
var pin_input: LineEdit
var name_input: LineEdit
var join_btn: Button
var error_label: Label
var status_label: Label

var _api_service: ApiService = null


func _ready() -> void:
	# Ищем узлы через find_child
	room_code_input = find_child("RoomCodeInput", true, false)
	pin_input = find_child("PinInput", true, false)
	name_input = find_child("NameInput", true, false)
	join_btn = find_child("DealerJoinBtn", true, false)
	var back_btn = find_child("DealerBackBtn", true, false)
	error_label = find_child("DealerErrorLabel", true, false)
	status_label = find_child("DealerStatusLabel", true, false)

	# Ищем ApiService
	_api_service = _find_api_service()
	if not _api_service:
		_api_service = ApiService.new()
		_api_service.name = "ApiService"
		get_tree().root.add_child(_api_service)

	_api_service.dealer_joined.connect(_on_join_succeeded)
	_api_service.request_error.connect(_on_request_error)
	_api_service.network_error.connect(_on_network_error)

	if join_btn and not join_btn.pressed.is_connected(_on_join_pressed):
		join_btn.pressed.connect(_on_join_pressed)
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)

	if error_label:
		error_label.visible = false

	if room_code_input:
		room_code_input.text_changed.connect(_on_room_code_changed)
	if pin_input:
		pin_input.text_changed.connect(_on_pin_changed)


func _find_api_service() -> ApiService:
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService") as ApiService
	var root = get_tree().root
	for child in root.get_children():
		if child.name == "ApiService":
			return child as ApiService
	return null


func _on_join_pressed() -> void:
	print("🟡 Кнопка 'Войти' (Дилер) нажата")
	var room_code = room_code_input.text.strip_edges() if room_code_input else ""
	var pin = pin_input.text.strip_edges() if pin_input else ""
	var display_name = name_input.text.strip_edges() if name_input else ""

	if room_code.is_empty():
		_show_error("Введите код комнаты")
		return
	if pin.is_empty():
		_show_error("Введите PIN-код")
		return
	if not pin.is_valid_int() or pin.length() != 6:
		_show_error("PIN должен состоять из 6 цифр")
		return
	if display_name.is_empty():
		_show_error("Введите ваше имя")
		return

	_hide_error()
	_set_loading(true)
	_api_service.dealer_join(room_code, pin, display_name)


func _on_join_succeeded(_user: Dictionary) -> void:
	print("🎉 Вход дилера успешен! Переход в лобби...")
	_set_loading(false)
	get_tree().change_scene_to_file("res://scenes/network/DealerWaitingScreen.tscn")


func _on_request_error(status_code: int, detail: String) -> void:
	_set_loading(false)
	match status_code:
		404:
			_show_error("Комната не найдена")
		403:
			_show_error("Неверный PIN-код")
		409:
			_show_error("Это имя уже привязано к другому PIN")
		410:
			_show_error("Эта комната закрыта")
		_:
			_show_error("Ошибка: " + detail)


func _on_network_error(message: String) -> void:
	_set_loading(false)
	_show_error("Нет связи с сервером: " + message)


func _on_back_pressed() -> void:
	go_back.emit()


func _on_room_code_changed(text: String) -> void:
	room_code_input.text = text.to_upper()


func _on_pin_changed(text: String) -> void:
	# Разрешаем только цифры
	var digits = ""
	for ch in text:
		if ch.is_valid_int():
			digits += ch
	if digits != text:
		pin_input.text = digits
		pin_input.caret_column = digits.length()


func _show_error(text: String) -> void:
	if error_label:
		error_label.text = text
		error_label.visible = true


func _hide_error() -> void:
	if error_label:
		error_label.visible = false


func _set_loading(loading: bool) -> void:
	if join_btn:
		join_btn.disabled = loading
		join_btn.text = "Вход..." if loading else "Войти"
	if status_label:
		status_label.text = "Подключение..." if loading else ""
