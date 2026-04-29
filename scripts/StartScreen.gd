## Стартовый экран приложения: локальная игра, онлайн и вход в настройки.
extends Control

var play_button: Button
var online_button: Button
var settings_button: Button
var hint_label: Label


func _ready() -> void:
	play_button = find_child("PlayButton", true, false)
	online_button = find_child("OnlineButton", true, false)
	settings_button = find_child("SettingsButton", true, false)
	hint_label = find_child("HintLabel", true, false)

	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if online_button and not online_button.pressed.is_connected(_on_online_pressed):
		online_button.pressed.connect(_on_online_pressed)

	if settings_button:
		settings_button.disabled = true
	if hint_label:
		hint_label.text = "Настройки пока доступны внутри игры."


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_online_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/network/MyTrainingsScreen.tscn")
