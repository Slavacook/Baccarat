## Экран входа тренера — email + пароль.
extends Control

signal go_back

var email_input: LineEdit
var password_input: LineEdit
var login_btn: Button
var error_label: Label
var status_label: Label

var _api_service: ApiService = null


func _ready() -> void:
	# Ищем узлы через find_child
	email_input = find_child("EmailInput", true, false)
	password_input = find_child("PasswordInput", true, false)
	login_btn = find_child("LoginBtn", true, false)
	var back_btn = find_child("TrainerBackBtn", true, false)
	error_label = find_child("ErrorLabel", true, false)
	status_label = find_child("StatusLabel", true, false)

	# Ищем ApiService
	_api_service = _find_api_service()
	if not _api_service:
		_api_service = ApiService.new()
		_api_service.name = "ApiService"
		get_tree().root.add_child(_api_service)

	_api_service.trainer_logged_in.connect(_on_login_succeeded)
	_api_service.request_error.connect(_on_request_error)
	_api_service.network_error.connect(_on_network_error)

	if login_btn and not login_btn.pressed.is_connected(_on_login_pressed):
		login_btn.pressed.connect(_on_login_pressed)
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)

	if error_label:
		error_label.visible = false


func _find_api_service() -> ApiService:
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService") as ApiService
	var root = get_tree().root
	for child in root.get_children():
		if child.name == "ApiService":
			return child as ApiService
	return null


func _on_login_pressed() -> void:
	print("🔵 Кнопка 'Войти' (Тренер) нажата")
	var email = email_input.text.strip_edges() if email_input else ""
	var password = password_input.text if password_input else ""

	if email.is_empty():
		_show_error("Введите email")
		return
	if password.is_empty():
		_show_error("Введите пароль")
		return
	if not _is_valid_email(email):
		_show_error("Неверный формат email")
		return

	_hide_error()
	_set_loading(true)
	_api_service.trainer_login(email, password)


func _on_login_succeeded(_user: Dictionary) -> void:
	print("🎉 Вход тренера успешен! Переход в лобби...")
	_set_loading(false)
	get_tree().change_scene_to_file("res://scenes/network/LobbyScreen.tscn")


func _on_request_error(status_code: int, detail: String) -> void:
	_set_loading(false)
	if status_code == 401:
		_show_error("Неверный email или пароль")
	elif status_code == 403:
		_show_error("Аккаунт деактивирован")
	elif status_code == 409:
		_show_error("Email уже зарегистрирован")
	else:
		_show_error("Ошибка: " + detail)


func _on_network_error(message: String) -> void:
	_set_loading(false)
	_show_error("Нет связи с сервером: " + message)


func _on_back_pressed() -> void:
	go_back.emit()


func _show_error(text: String) -> void:
	if error_label:
		error_label.text = text
		error_label.visible = true


func _hide_error() -> void:
	if error_label:
		error_label.visible = false


func _set_loading(loading: bool) -> void:
	if login_btn:
		login_btn.disabled = loading
		login_btn.text = "Вход..." if loading else "Войти"
	if status_label:
		status_label.text = "Подключение..." if loading else ""


func _is_valid_email(email: String) -> bool:
	return email.contains("@") and email.contains(".")
