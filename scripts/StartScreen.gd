## Стартовый экран приложения: локальная игра, онлайн и вход в настройки.
extends Control

var play_button: Button
var online_button: Button
var tournament_button: Button
var refresh_status_label: Label

var _refresh_manager = null
var _status_hide_token: int = 0

const REFRESH_IN_PROGRESS_TEXT := "Обновляем данные турниров…"
const REFRESH_SUCCESS_TEXT := "Данные турниров обновлены"
const REFRESH_FAILURE_TEXT := "Не удалось обновить данные турниров"
const STATUS_HIDE_DELAY_SECONDS := 3.5


func _ready() -> void:
	play_button = find_child("PlayButton", true, false)
	online_button = find_child("OnlineButton", true, false)
	tournament_button = find_child("TournamentButton", true, false)
	refresh_status_label = find_child("RefreshStatusLabel", true, false)
	_refresh_manager = _find_refresh_manager()

	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if online_button and not online_button.pressed.is_connected(_on_online_pressed):
		online_button.pressed.connect(_on_online_pressed)
	if tournament_button and not tournament_button.pressed.is_connected(_on_tournament_pressed):
		tournament_button.pressed.connect(_on_tournament_pressed)
	_connect_refresh_manager()
	_sync_refresh_status_on_ready()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_online_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/network/MyTrainingsScreen.tscn")


func _on_tournament_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/network/TournamentEntryScreen.tscn")


func _exit_tree() -> void:
	_disconnect_refresh_manager()
	_status_hide_token += 1


func _find_refresh_manager():
	if Engine.has_singleton("TournamentRefreshManager"):
		return Engine.get_singleton("TournamentRefreshManager")
	return get_node_or_null("/root/TournamentRefreshManager")


func _connect_refresh_manager() -> void:
	if _refresh_manager == null:
		return
	if _refresh_manager.has_signal("refresh_all_started"):
		if not _refresh_manager.refresh_all_started.is_connected(_on_refresh_all_started):
			_refresh_manager.refresh_all_started.connect(_on_refresh_all_started)
	if _refresh_manager.has_signal("refresh_all_completed"):
		if not _refresh_manager.refresh_all_completed.is_connected(_on_refresh_all_completed):
			_refresh_manager.refresh_all_completed.connect(_on_refresh_all_completed)


func _disconnect_refresh_manager() -> void:
	if _refresh_manager == null:
		return
	if _refresh_manager.has_signal("refresh_all_started"):
		if _refresh_manager.refresh_all_started.is_connected(_on_refresh_all_started):
			_refresh_manager.refresh_all_started.disconnect(_on_refresh_all_started)
	if _refresh_manager.has_signal("refresh_all_completed"):
		if _refresh_manager.refresh_all_completed.is_connected(_on_refresh_all_completed):
			_refresh_manager.refresh_all_completed.disconnect(_on_refresh_all_completed)


func _sync_refresh_status_on_ready() -> void:
	if _refresh_manager == null:
		_hide_refresh_status()
		return
	if _refresh_manager.has_method("is_refresh_all_in_progress") and bool(_refresh_manager.call("is_refresh_all_in_progress")):
		_show_refresh_status(REFRESH_IN_PROGRESS_TEXT)
	else:
		_hide_refresh_status()


func _on_refresh_all_started() -> void:
	_show_refresh_status(REFRESH_IN_PROGRESS_TEXT)


func _on_refresh_all_completed(success_count: int, failed_count: int) -> void:
	if success_count > 0:
		_show_refresh_status(REFRESH_SUCCESS_TEXT)
		_schedule_hide_refresh_status()
		return
	if success_count == 0 and failed_count > 0:
		_show_refresh_status(REFRESH_FAILURE_TEXT)
		_schedule_hide_refresh_status()
		return
	_hide_refresh_status()


func _show_refresh_status(text: String) -> void:
	if refresh_status_label == null:
		return
	_status_hide_token += 1
	refresh_status_label.text = text
	refresh_status_label.visible = true


func _hide_refresh_status() -> void:
	if refresh_status_label == null:
		return
	_status_hide_token += 1
	refresh_status_label.visible = false


func _schedule_hide_refresh_status() -> void:
	var hide_token := _status_hide_token
	_hide_refresh_status_after_delay.call_deferred(hide_token)


func _hide_refresh_status_after_delay(hide_token: int) -> void:
	await get_tree().create_timer(STATUS_HIDE_DELAY_SECONDS).timeout
	if not is_inside_tree():
		return
	if hide_token != _status_hide_token:
		return
	if refresh_status_label:
		refresh_status_label.visible = false
