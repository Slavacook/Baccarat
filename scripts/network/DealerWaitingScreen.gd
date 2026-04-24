## Простой экран ожидания дилера: после входа по коду/PIN ждёт старт от тренера и автоматически открывает игру.
extends Control

@onready var room_label: Label = %RoomLabel
@onready var status_label: Label = %StatusLabel
@onready var error_label: Label = %ErrorLabel
@onready var back_btn: Button = %BackBtn

var _api_service: Node = null
var _poll_timer: Timer = null
var _is_check_running: bool = false
var _is_starting_game: bool = false
var _session_id: String = ""


func _ready() -> void:
	_api_service = _find_api_service()
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if error_label:
		error_label.visible = false

	_update_room_label()
	_set_status("Подключаемся к тренировке...")
	_start_polling()


func _start_polling() -> void:
	if _poll_timer == null:
		_poll_timer = Timer.new()
		_poll_timer.wait_time = 2.5
		_poll_timer.one_shot = false
		_poll_timer.name = "DealerWaitPollTimer"
		add_child(_poll_timer)
		_poll_timer.timeout.connect(_on_poll_timeout)
	_poll_timer.start()
	_on_poll_timeout.call_deferred()


func _stop_polling() -> void:
	if _poll_timer and not _poll_timer.is_stopped():
		_poll_timer.stop()


func _on_poll_timeout() -> void:
	if _is_check_running or _is_starting_game:
		return
	_is_check_running = true
	await _check_training_state()
	_is_check_running = false


func _check_training_state() -> void:
	if not (_api_service and _api_service.auth_manager):
		_show_error("Нет данных авторизации. Войдите заново.")
		return

	var user: Dictionary = _api_service.auth_manager.user_data
	var room_code: String = str(user.get("room_code", "")).strip_edges()
	if room_code.is_empty():
		_show_error("Не найден код комнаты.")
		return

	var fetch_res: Dictionary = await _api_service.fetch_active_live_session_async(room_code)
	var code: int = int(fetch_res.get("code", 0))
	var body: Variant = fetch_res.get("body", {})

	if code == 404:
		_hide_error()
		_set_status("Тренер ещё не начал тренировку. Ожидаем...")
		return
	if code != 200 or not (body is Dictionary):
		var detail: String = "Ошибка сервера"
		if body is Dictionary:
			detail = str((body as Dictionary).get("detail", detail))
		_show_error(detail)
		return

	var info: Dictionary = body as Dictionary
	var session_id: String = str(info.get("session_id", "")).strip_edges()
	var state: String = str(info.get("status", "")).strip_edges()
	var round_seed: String = str(info.get("round_seed", "")).strip_edges()
	if session_id.is_empty():
		_show_error("Сервер не вернул id тренировки.")
		return

	var lsc: Node = _get_live_session_client()
	if lsc == null:
		_show_error("LiveSessionClient не найден.")
		return
	if _session_id != session_id:
		_session_id = session_id
		lsc.disconnect_live()

	if not lsc.is_live_connected():
		var token: String = str(_api_service.auth_manager.access_token)
		var err: int = lsc.connect_live(_api_service.api_client.base_url, session_id, token)
		if err != OK:
			_show_error("Нет связи с тренировкой (WS %d)." % err)
			return

	if state == "created":
		_hide_error()
		_set_status("Тренировка подготовлена. Ждём старт от тренера...")
		var sync: Dictionary = await lsc.await_session_started(1.5)
		if sync.is_empty():
			return
		round_seed = str(sync.get("round_seed", round_seed)).strip_edges()
	elif state != "active":
		_hide_error()
		_set_status("Ожидаем запуск тренировки...")
		return

	_start_game(session_id, user, room_code, round_seed)


func _start_game(session_id: String, user: Dictionary, room_code: String, round_seed: String) -> void:
	if _is_starting_game:
		return
	_is_starting_game = true
	_stop_polling()
	_hide_error()
	_set_status("Тренировка началась. Входим в игру...")
	var sm: Node = get_node_or_null("/root/SessionManager")
	if not sm:
		_show_error("SessionManager не найден.")
		_is_starting_game = false
		return
	sm.start_online_session(
		room_code,
		str(user.get("id", "")),
		str(user.get("display_name", "Дилер")),
		session_id
	)
	sm.apply_live_sync({"round_seed": round_seed})
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_back_pressed() -> void:
	_stop_polling()
	if Engine.has_singleton("LiveSessionClient"):
		LiveSessionClient.disconnect_live()
	get_tree().change_scene_to_file("res://scenes/network/MainMenu.tscn")


func _exit_tree() -> void:
	_stop_polling()


func _update_room_label() -> void:
	if not room_label:
		return
	var text: String = "Комната: —"
	if _api_service and _api_service.auth_manager:
		var user: Dictionary = _api_service.auth_manager.user_data
		var room_code: String = str(user.get("room_code", "")).strip_edges()
		if not room_code.is_empty():
			text = "Комната: %s" % room_code
	room_label.text = text


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _show_error(text: String) -> void:
	if error_label:
		error_label.text = text
		error_label.visible = true


func _hide_error() -> void:
	if error_label:
		error_label.visible = false


func _find_api_service() -> Node:
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService") as Node
	var root: Node = get_tree().root
	for child in root.get_children():
		if child.name == "ApiService":
			return child
	return null


func _get_live_session_client() -> Node:
	if Engine.has_singleton("LiveSessionClient"):
		return Engine.get_singleton("LiveSessionClient") as Node
	var existing: Node = get_node_or_null("/root/LiveSessionClient")
	if existing != null:
		return existing
	var script_res: Script = load("res://scripts/network/LiveSessionClient.gd")
	if script_res == null:
		return null
	var node := Node.new()
	node.name = "LiveSessionClient"
	node.set_script(script_res)
	get_tree().root.add_child(node)
	return node
