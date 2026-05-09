## Глобальный визуальный статус фонового обновления турниров.
extends CanvasLayer

const REFRESH_IN_PROGRESS_TEXT := "Обновляем данные турниров…"
const REFRESH_SUCCESS_TEXT := "Данные турниров обновлены"
const REFRESH_FAILURE_TEXT := "Не удалось обновить данные турниров"
const STATUS_HIDE_DELAY_SECONDS := 3.5
const SPINNER_FRAME_SECONDS := 0.12
const SPINNER_FRAMES := ["|", "/", "-", "\\"]
const FADE_IN_DURATION := 0.22
const FADE_OUT_DURATION := 0.3

var refresh_card: Control
var spinner_label: Label
var status_label: Label

var _refresh_manager = null
var _visibility_token: int = 0
var _spinner_active: bool = false
var _spinner_index: int = 0
var _spinner_elapsed: float = 0.0
var _fade_tween: Tween = null


func _ready() -> void:
	refresh_card = find_child("RefreshCard", true, false)
	spinner_label = find_child("SpinnerLabel", true, false)
	status_label = find_child("StatusLabel", true, false)
	_refresh_manager = _find_refresh_manager()

	set_process(false)
	_connect_refresh_manager()
	_sync_refresh_status_on_ready()


func _exit_tree() -> void:
	_disconnect_refresh_manager()
	_visibility_token += 1
	_spinner_active = false
	_kill_fade_tween()
	set_process(false)


func _process(delta: float) -> void:
	if not _spinner_active or spinner_label == null:
		return

	_spinner_elapsed += delta
	if _spinner_elapsed < SPINNER_FRAME_SECONDS:
		return

	_spinner_elapsed = 0.0
	_spinner_index = (_spinner_index + 1) % SPINNER_FRAMES.size()
	spinner_label.text = SPINNER_FRAMES[_spinner_index]


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
		_hide_card_immediately()
		return
	if _refresh_manager.has_method("is_refresh_all_in_progress") and bool(_refresh_manager.call("is_refresh_all_in_progress")):
		_show_refresh_started()
		return
	_hide_card_immediately()


func _on_refresh_all_started() -> void:
	_show_refresh_started()


func _on_refresh_all_completed(success_count: int, failed_count: int) -> void:
	if success_count > 0:
		_show_result_and_hide_later(REFRESH_SUCCESS_TEXT)
		return
	if success_count == 0 and failed_count > 0:
		_show_result_and_hide_later(REFRESH_FAILURE_TEXT)
		return
	_hide_card_immediately()


func _show_refresh_started() -> void:
	_visibility_token += 1
	_show_card(REFRESH_IN_PROGRESS_TEXT, true, true)


func _show_result_and_hide_later(text: String) -> void:
	_visibility_token += 1
	var current_token := _visibility_token
	_show_card(text, false, false)
	_hide_after_delay.call_deferred(current_token)


func _show_card(text: String, show_spinner: bool, animate_fade_in: bool) -> void:
	if refresh_card == null:
		return

	_kill_fade_tween()
	refresh_card.visible = true
	if status_label:
		status_label.text = text
	_set_spinner_active(show_spinner)

	if animate_fade_in:
		refresh_card.modulate.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(refresh_card, "modulate:a", 1.0, FADE_IN_DURATION)
	else:
		refresh_card.modulate.a = 1.0


func _hide_card_immediately() -> void:
	_visibility_token += 1
	_kill_fade_tween()
	if refresh_card:
		refresh_card.visible = false
		refresh_card.modulate.a = 1.0
	_set_spinner_active(false)


func _set_spinner_active(active: bool) -> void:
	_spinner_active = active
	_spinner_elapsed = 0.0
	_spinner_index = 0
	set_process(active)

	if spinner_label == null:
		return

	spinner_label.visible = active
	spinner_label.text = SPINNER_FRAMES[0] if active else ""


func _hide_after_delay(token: int) -> void:
	var deadline_ms := Time.get_ticks_msec() + int(STATUS_HIDE_DELAY_SECONDS * 1000.0)
	while is_inside_tree() and Time.get_ticks_msec() < deadline_ms:
		await get_tree().process_frame

	if not is_inside_tree():
		return
	if token != _visibility_token:
		return
	_start_fade_out(token)


func _start_fade_out(token: int) -> void:
	if refresh_card == null:
		return
	if token != _visibility_token:
		return

	_kill_fade_tween()
	refresh_card.visible = true
	refresh_card.modulate.a = 1.0
	var fade_tween := create_tween()
	_fade_tween = fade_tween
	fade_tween.tween_property(refresh_card, "modulate:a", 0.0, FADE_OUT_DURATION)
	while is_inside_tree() and token == _visibility_token and _fade_tween == fade_tween and fade_tween.is_running():
		await get_tree().process_frame

	if not is_inside_tree():
		return
	if token != _visibility_token:
		return
	if _fade_tween != fade_tween:
		return
	refresh_card.visible = false
	refresh_card.modulate.a = 1.0
	_fade_tween = null
	_set_spinner_active(false)


func _kill_fade_tween() -> void:
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null
