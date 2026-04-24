## Лобби комнаты — информация о комнате, кнопка «Начать тренировку».
extends Control

signal start_training
signal go_back

@onready var room_name_label: Label = %RoomNameLabel
@onready var room_code_label: Label = %RoomCodeLabel
@onready var status_label: Label = %StatusLabel
@onready var player_count_label: Label = %PlayerCountLabel
@onready var start_btn: Button = %StartBtn
@onready var back_btn: Button = %BackBtn
@onready var error_label: Label = %ErrorLabel
@onready var trainer_mode_container: Control = %TrainerModeContainer
@onready var dealer_mode_container: Control = %DealerModeContainer
@onready var trainer_rooms_list: ItemList = %TrainerRoomsList

var _api_service: Node = null
var _rooms: Array = []
var _is_trainer: bool = false
var _dealer_auto_start_in_progress: bool = false
var _dealer_poll_timer: Timer = null


func _ready() -> void:
	_api_service = _find_api_service()
	if not _api_service:
		_show_error("ApiService не найден")
		return

	_api_service.request_error.connect(_on_request_error)
	_api_service.network_error.connect(_on_network_error)

	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)

	await _determine_role()


func _determine_role() -> void:
	if _api_service and _api_service.auth_manager:
		_is_trainer = _api_service.auth_manager.is_trainer()
	else:
		_is_trainer = false

	if trainer_mode_container:
		trainer_mode_container.visible = _is_trainer
	if dealer_mode_container:
		dealer_mode_container.visible = not _is_trainer

	if _is_trainer:
		if start_btn:
			start_btn.text = "▶️ Подготовить и запустить тренировку"
		await _load_trainer_rooms()
	else:
		if start_btn:
			start_btn.text = "⏳ Ожидание тренера..."
			start_btn.disabled = true
		_load_dealer_info()
		_start_dealer_wait_loop.call_deferred()


# ═══════════════════════════════════════════════════════════════
# ТРЕНЕР
# ═══════════════════════════════════════════════════════════════

func _load_trainer_rooms() -> void:
	if not _api_service:
		return
	_api_service.list_rooms()
	var rooms_arr: Variant = await _api_service.rooms_list_loaded
	_rooms = rooms_arr as Array
	if trainer_rooms_list:
		trainer_rooms_list.clear()
		for room in _rooms:
			if room is Dictionary:
				var d: Dictionary = room as Dictionary
				var display: String = "%s (%s)" % [d.get("name", ""), d.get("room_code", "")]
				trainer_rooms_list.add_item(display)

		if not _rooms.is_empty():
			trainer_rooms_list.select(0)

		if _rooms.is_empty() and status_label:
			status_label.text = "Нет комнат. Создайте комнату в клиенте (экран тренера) или через API."
		elif status_label:
			status_label.text = "Выберите комнату и нажмите «Начать тренировку» для запуска live-сессии"


# ═══════════════════════════════════════════════════════════════
# ДИЛЕР
# ═══════════════════════════════════════════════════════════════

func _load_dealer_info() -> void:
	if _api_service and _api_service.auth_manager:
		var user: Dictionary = _api_service.auth_manager.user_data
		if room_name_label:
			room_name_label.text = "Комната: %s" % user.get("room_code", "—")
		if room_code_label:
			room_code_label.text = "Код: %s" % user.get("room_code", "—")
		if status_label:
			status_label.text = "Проверяем запуск тренировки у тренера..."
		if player_count_label:
			player_count_label.text = "Участников: —"


# ═══════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════

func _ensure_dealer_poll_timer() -> void:
	if _dealer_poll_timer != null:
		return
	_dealer_poll_timer = Timer.new()
	_dealer_poll_timer.name = "DealerPollTimer"
	_dealer_poll_timer.one_shot = false
	_dealer_poll_timer.wait_time = 2.5
	add_child(_dealer_poll_timer)
	_dealer_poll_timer.timeout.connect(_on_dealer_poll_timeout)


func _start_dealer_wait_loop() -> void:
	if _is_trainer:
		return
	_ensure_dealer_poll_timer()
	if _dealer_poll_timer:
		_dealer_poll_timer.start()
	await _on_dealer_poll_timeout()


func _stop_dealer_wait_loop() -> void:
	if _dealer_poll_timer and not _dealer_poll_timer.is_stopped():
		_dealer_poll_timer.stop()


func _on_dealer_poll_timeout() -> void:
	if _dealer_auto_start_in_progress:
		return
	_dealer_auto_start_in_progress = true
	await _start_dealer_training()
	_dealer_auto_start_in_progress = false

func _on_start_pressed() -> void:
	if _is_trainer:
		await _trainer_start_live_session()
	else:
		# Для дилера запуск теперь автоматический при входе в лобби.
		return


func _trainer_start_live_session() -> void:
	_hide_error()
	if not _api_service:
		return
	if trainer_rooms_list == null or _rooms.is_empty():
		_show_error("Нет комнат. Сначала создайте комнату.")
		return
	var sel: PackedInt32Array = trainer_rooms_list.get_selected_items()
	if sel.is_empty():
		_show_error("Выберите комнату в списке")
		return
	var idx: int = int(sel[0])
	if idx < 0 or idx >= _rooms.size():
		_show_error("Некорректный выбор комнаты")
		return
	var room: Dictionary = _rooms[idx] as Dictionary
	var code_str: String = str(room.get("room_code", ""))
	if code_str.is_empty():
		_show_error("У комнаты нет кода")
		return
	if status_label:
		status_label.text = "Создаём live-сессию..."
	var created: Dictionary = await _api_service.create_live_session_async(code_str, 30, null)
	var c1: int = int(created.get("code", 0))
	var b1: Variant = created.get("body", {})
	if c1 != 201 or not b1 is Dictionary:
		_show_error("Не удалось создать сессию (код %s)" % str(c1))
		return
	var body1: Dictionary = b1 as Dictionary
	var session_id: String = str(body1.get("session_id", ""))
	if session_id.is_empty():
		_show_error("Сервер не вернул session_id")
		return
	if status_label:
		status_label.text = "Запускаем live-сессию..."
	var started: Dictionary = await _api_service.start_live_session_async(session_id)
	var c2: int = int(started.get("code", 0))
	if c2 != 200:
		_show_error("Не удалось запустить сессию (код %s)" % str(c2))
		return
	if status_label:
		status_label.text = "Live-сессия запущена. Дилеры могут нажать «Начать тренировку»."


func _start_dealer_training() -> void:
	_hide_error()
	var sm: Node = get_node_or_null("/root/SessionManager")
	if not (_api_service and _api_service.auth_manager and sm):
		_show_error("Нет данных авторизации")
		return
	var user: Dictionary = _api_service.auth_manager.user_data
	var room_code: String = str(user.get("room_code", ""))
	if room_code.is_empty():
		_show_error("Нет кода комнаты")
		return
	if status_label:
		status_label.text = "Проверяем live-сессию..."
	var fetch_res: Dictionary = await _api_service.fetch_active_live_session_async(room_code)
	var fcode: int = int(fetch_res.get("code", 0))
	var fbody: Variant = fetch_res.get("body", {})
	if fcode == 404:
		_hide_error()
		if status_label:
			status_label.text = "Тренер ещё не подготовил тренировку. Ожидайте."
		return
	if fcode != 200 or not fbody is Dictionary:
		var detail: String = "ошибка"
		if fbody is Dictionary:
			detail = str((fbody as Dictionary).get("detail", str(fcode)))
		_show_error("Ошибка: %s" % detail)
		return

	var info: Dictionary = fbody as Dictionary
	var session_id: String = str(info.get("session_id", ""))
	var st: String = str(info.get("status", ""))
	var round_seed: String = str(info.get("round_seed", ""))
	if session_id.is_empty():
		_show_error("Нет session_id от сервера")
		return

	var token: String = _api_service.auth_manager.access_token
	if not Engine.has_singleton("LiveSessionClient"):
		_show_error("LiveSessionClient не найден (autoload)")
		return
	var lsc: Node = LiveSessionClient
	var err: int = lsc.connect_live(_api_service.api_client.base_url, session_id, token)
	if err != OK:
		_show_error("Не удалось открыть WebSocket (код %d)" % err)
		return

	if st == "created":
		if status_label:
			status_label.text = "Тренер подготовил тренировку. Ждём кнопки «Запустить»..."
		var sync: Dictionary = await lsc.await_session_started(6.0)
		if sync.is_empty():
			lsc.disconnect_live()
			_hide_error()
			if status_label:
				status_label.text = "Ждём запуска тренером... проверяем автоматически."
			return
		round_seed = str(sync.get("round_seed", round_seed))

	sm.start_online_session(
		room_code,
		str(user.get("id", "")),
		str(user.get("display_name", "Дилер")),
		session_id
	)
	sm.apply_live_sync({"round_seed": round_seed})
	_stop_dealer_wait_loop()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_back_pressed() -> void:
	_stop_dealer_wait_loop()
	if Engine.has_singleton("LiveSessionClient"):
		LiveSessionClient.disconnect_live()
	go_back.emit()
	get_tree().change_scene_to_file("res://scenes/network/MainMenu.tscn")


func _exit_tree() -> void:
	_stop_dealer_wait_loop()


func _on_request_error(status_code: int, detail: String) -> void:
	_show_error("Ошибка: %s" % detail)


func _on_network_error(message: String) -> void:
	_show_error("Нет соединения: %s" % message)


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
	push_warning("ApiService не найден! Сетевые функции не будут работать.")
	return null
