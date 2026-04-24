## Главное меню с выбором роли: Тренер / Дилер / Быстрая тренировка.
extends Control

var trainer_login_btn: Button
var dealer_login_btn: Button
var quick_play_btn: Button

var trainer_login_screen: Control
var dealer_login_screen: Control
var main_menu_container: Control


func _ready() -> void:
	# Ищем все узлы через find_child (уникальные имена % не работают в .tscn)
	trainer_login_btn = find_child("TrainerLoginBtn", true, false)
	dealer_login_btn = find_child("DealerLoginBtn", true, false)
	quick_play_btn = find_child("QuickPlayBtn", true, false)
	trainer_login_screen = find_child("TrainerLoginScreen", true, false)
	dealer_login_screen = find_child("DealerLoginScreen", true, false)
	main_menu_container = find_child("MainMenuContainer", true, false)

	if trainer_login_btn:
		trainer_login_btn.pressed.connect(_on_trainer_login_pressed)
	if dealer_login_btn:
		dealer_login_btn.pressed.connect(_on_dealer_login_pressed)
	if quick_play_btn:
		quick_play_btn.pressed.connect(_on_quick_play_pressed)

	# Проверяем, есть ли сохранённая сессия
	if Engine.has_singleton("AuthManager"):
		var am = Engine.get_singleton("AuthManager")
		if am and am.access_token != "":
			_navigate_to_lobby()


func _on_trainer_login_pressed() -> void:
	print("🔵 Тренер → вход")
	if main_menu_container:
		main_menu_container.visible = false
	if trainer_login_screen:
		trainer_login_screen.visible = true


func _on_dealer_login_pressed() -> void:
	print("🟡 Дилер → вход")
	if main_menu_container:
		main_menu_container.visible = false
	if dealer_login_screen:
		dealer_login_screen.visible = true


func _on_quick_play_pressed() -> void:
	print("🟢 Быстрая тренировка")
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _navigate_to_lobby() -> void:
	print("🔵 Навигация в онлайн-сцену")
	if Engine.has_singleton("AuthManager"):
		var am = Engine.get_singleton("AuthManager")
		if am and am.user_data is Dictionary:
			var role: String = str(am.user_data.get("role", ""))
			if role == "dealer":
				get_tree().change_scene_to_file("res://scenes/network/DealerWaitingScreen.tscn")
				return
	get_tree().change_scene_to_file("res://scenes/network/LobbyScreen.tscn")


func go_back() -> void:
	print("⬅️ Назад в меню")
	if trainer_login_screen:
		trainer_login_screen.visible = false
	if dealer_login_screen:
		dealer_login_screen.visible = false
	if main_menu_container:
		main_menu_container.visible = true
