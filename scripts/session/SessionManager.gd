## Менеджер тренировочной сессии.
## Хранит контекст: оффлайн или сетевая игра, данные комнаты, раунды.
## (autoload — class_name НЕ нужен)
extends Node

const ONLINE_WATCHDOG_INTERVAL_SEC: float = 4.0
const FORCE_EXIT_SCENE_PATH: String = "res://scenes/network/MyTrainingsScreen.tscn"

# ═══════════════════════════════════════════════════════════════
# РЕЖИМЫ
# ═══════════════════════════════════════════════════════════════

enum Mode {
	OFFLINE,      # Обычная игра без сервера
	ONLINE,       # Игра с отправкой результатов на сервер
	TOURNAMENT    # Турнирный запуск без live/ws
}

var current_mode: Mode = Mode.OFFLINE

# Данные сессии (заполняются при входе дилера)
var room_code: String = ""
var session_id: String = ""
var dealer_id: String = ""
var display_name: String = ""
var tournament_id: String = ""
var tournament_code: String = ""
var tournament_title: String = ""
var tournament_status: String = ""
var tournament_participant_token: String = ""
var tournament_participant_id: String = ""
var tournament_participant_display_name: String = ""
var tournament_max_rounds: int = 0
var tournament_attempt_duration_seconds: int = 0
var tournament_attempt_started_at: float = 0.0
var tournament_rounds_completed: int = 0
var tournament_errors_total: int = 0
var tournament_attempt_finished: bool = false
var tournament_finish_reason: String = ""
var tournament_submit_started: bool = false
var tournament_submit_completed: bool = false
var tournament_submit_succeeded: bool = false
var tournament_last_attempt_payload: Dictionary = {}
var tournament_last_submit_response: Dictionary = {}
var tournament_submit_error_text: String = ""
## Сид текущего раунда с сервера (после применения к колоде совпадает с последней раздачей).
var live_round_seed: String = ""
## Сид следующего раунда из WS `round_sync` (применяется в deal_first_four перед раздачей).
var pending_live_round_seed: String = ""
var _online_watchdog_timer: Timer = null
var _online_watchdog_in_flight: bool = false
var _force_exit_in_progress: bool = false

# Статистика текущей сессии
var rounds_played: int = 0
var correct_answers: int = 0
var total_errors: int = 0
var round_start_time: float = 0.0
var _last_player_cards: Array[String] = []
var _last_banker_cards: Array[String] = []

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal session_started(mode: Mode)
signal session_ended(stats: Dictionary)


# ═══════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	# Подписываемся на события игры
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.round_reset.connect(_on_round_reset)
		eb.action_correct.connect(_on_action_correct)
		eb.payout_correct.connect(_on_payout_correct)
		eb.cards_dealt.connect(_on_cards_dealt)
		eb.player_third_drawn.connect(_on_player_third_drawn)
		eb.banker_third_drawn.connect(_on_banker_third_drawn)
		if eb.has_signal("action_error"):
			eb.action_error.connect(_on_tournament_action_error)
		if eb.has_signal("payout_wrong"):
			eb.payout_wrong.connect(_on_tournament_payout_wrong)
		if eb.has_signal("collection_error"):
			eb.collection_error.connect(_on_tournament_collection_error)
		if eb.has_signal("payment_error"):
			eb.payment_error.connect(_on_tournament_payment_error)
	_ensure_online_watchdog_timer()


# ═══════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════

func start_offline_session() -> void:
	_reset_runtime_context()
	current_mode = Mode.OFFLINE
	_reset_stats()
	session_started.emit(current_mode)


func start_online_session(
	room_code_str: String,
	dealer_id_str: String,
	display_name_str: String,
	live_session_uuid: String = ""
) -> void:
	_reset_runtime_context()
	current_mode = Mode.ONLINE
	room_code = room_code_str
	dealer_id = dealer_id_str
	display_name = display_name_str
	session_id = live_session_uuid
	_reset_stats()
	_start_online_watchdog()
	session_started.emit(current_mode)


func start_tournament_session(access_record: Dictionary) -> void:
	_reset_runtime_context()
	current_mode = Mode.TOURNAMENT

	var tournament: Dictionary = _dictionary_or_empty(_dict_value(access_record, "tournament", {}))
	var participant: Dictionary = _dictionary_or_empty(_dict_value(access_record, "participant", {}))

	tournament_id = str(_dict_value(tournament, "id", "")).strip_edges()
	tournament_code = str(_dict_value(tournament, "code", "")).strip_edges()
	tournament_title = str(_dict_value(tournament, "title", "")).strip_edges()
	tournament_status = str(_dict_value(tournament, "status", "")).strip_edges()
	tournament_participant_token = str(_dict_value(access_record, "participant_token", "")).strip_edges()
	tournament_participant_id = str(_dict_value(participant, "id", "")).strip_edges()
	tournament_participant_display_name = str(_dict_value(participant, "display_name", "")).strip_edges()
	tournament_max_rounds = int(_dict_value(tournament, "max_rounds", 0))
	tournament_attempt_duration_seconds = int(_dict_value(tournament, "attempt_duration_seconds", 0))
	tournament_attempt_started_at = Time.get_ticks_msec() / 1000.0
	display_name = tournament_participant_display_name

	_reset_stats()
	session_started.emit(current_mode)


func apply_live_sync(data: Dictionary) -> void:
	if data.has("round_seed"):
		var rs: String = str(data["round_seed"])
		if rs != "":
			live_round_seed = rs


func apply_server_round_sync(data: Dictionary) -> void:
	if not data.has("round_seed"):
		return
	var rs: String = str(data["round_seed"]).strip_edges()
	if rs != "":
		pending_live_round_seed = rs


func apply_pending_live_deck_seed_to(deck: Deck) -> void:
	if current_mode != Mode.ONLINE:
		return
	if deck == null:
		return
	var pending: String = pending_live_round_seed.strip_edges()
	if pending.is_empty():
		return
	deck.reseed_from_hex(pending)
	live_round_seed = pending
	pending_live_round_seed = ""


func end_session() -> Dictionary:
	var stats = get_session_stats()
	session_ended.emit(stats)
	_reset_runtime_context()
	_reset_stats()
	current_mode = Mode.OFFLINE
	return stats


func force_exit_online_session(reason_code: String, message: String) -> void:
	if current_mode != Mode.ONLINE:
		return
	if _force_exit_in_progress:
		return

	_force_exit_in_progress = true
	_stop_online_watchdog()

	var final_message: String = message.strip_edges()
	if final_message.is_empty():
		final_message = _force_exit_message(reason_code)

	end_session()
	_clear_runtime_dealer_auth()

	var tree := get_tree()
	if tree == null:
		return
	if tree.current_scene == null or tree.current_scene.scene_file_path != FORCE_EXIT_SCENE_PATH:
		tree.change_scene_to_file(FORCE_EXIT_SCENE_PATH)
	if not final_message.is_empty():
		_emit_force_exit_toast.call_deferred(final_message)


func get_session_stats() -> Dictionary:
	return {
		"mode": current_mode,
		"room_code": room_code,
		"session_id": session_id,
		"dealer_id": dealer_id,
		"display_name": display_name,
		"tournament_id": tournament_id,
		"tournament_code": tournament_code,
		"tournament_title": tournament_title,
		"tournament_status": tournament_status,
		"tournament_participant_token": tournament_participant_token,
		"tournament_participant_id": tournament_participant_id,
		"tournament_participant_display_name": tournament_participant_display_name,
		"tournament_max_rounds": tournament_max_rounds,
		"tournament_attempt_duration_seconds": tournament_attempt_duration_seconds,
		"tournament_attempt_started_at": tournament_attempt_started_at,
		"tournament_rounds_completed": tournament_rounds_completed,
		"tournament_errors_total": tournament_errors_total,
		"tournament_attempt_finished": tournament_attempt_finished,
		"tournament_finish_reason": tournament_finish_reason,
		"tournament_submit_started": tournament_submit_started,
		"tournament_submit_completed": tournament_submit_completed,
		"tournament_submit_succeeded": tournament_submit_succeeded,
		"tournament_last_attempt_payload": tournament_last_attempt_payload.duplicate(true),
		"tournament_last_submit_response": tournament_last_submit_response.duplicate(true),
		"tournament_submit_error_text": tournament_submit_error_text,
		"rounds_played": rounds_played,
		"correct_answers": correct_answers,
		"total_errors": total_errors,
		"accuracy": _calc_accuracy()
	}


func get_round_context_snapshot() -> Dictionary:
	return {
		"player_cards": _last_player_cards.duplicate(),
		"banker_cards": _last_banker_cards.duplicate(),
	}


func _reset_stats() -> void:
	rounds_played = 0
	correct_answers = 0
	total_errors = 0
	round_start_time = 0.0
	_last_player_cards.clear()
	_last_banker_cards.clear()


func _reset_runtime_context() -> void:
	if Engine.has_singleton("LiveSessionClient"):
		LiveSessionClient.disconnect_live()
	_stop_online_watchdog()
	session_id = ""
	room_code = ""
	dealer_id = ""
	display_name = ""
	tournament_id = ""
	tournament_code = ""
	tournament_title = ""
	tournament_status = ""
	tournament_participant_token = ""
	tournament_participant_id = ""
	tournament_participant_display_name = ""
	tournament_max_rounds = 0
	tournament_attempt_duration_seconds = 0
	tournament_attempt_started_at = 0.0
	tournament_rounds_completed = 0
	tournament_errors_total = 0
	tournament_attempt_finished = false
	tournament_finish_reason = ""
	tournament_submit_started = false
	tournament_submit_completed = false
	tournament_submit_succeeded = false
	tournament_last_attempt_payload.clear()
	tournament_last_submit_response.clear()
	tournament_submit_error_text = ""
	live_round_seed = ""
	pending_live_round_seed = ""
	_force_exit_in_progress = false


func mark_tournament_round_completed() -> void:
	if current_mode != Mode.TOURNAMENT:
		return
	if tournament_attempt_finished:
		return
	tournament_rounds_completed += 1


func mark_tournament_error() -> void:
	if current_mode != Mode.TOURNAMENT:
		return
	if tournament_attempt_finished:
		return
	tournament_errors_total += 1


func finish_tournament_attempt(reason: String) -> void:
	if current_mode != Mode.TOURNAMENT:
		return
	if tournament_attempt_finished:
		return
	tournament_attempt_finished = true
	tournament_finish_reason = reason


func start_tournament_submit() -> bool:
	if current_mode != Mode.TOURNAMENT:
		return false
	if tournament_submit_started or tournament_submit_completed:
		return false
	tournament_submit_started = true
	return true


func complete_tournament_submit(success: bool) -> void:
	if current_mode != Mode.TOURNAMENT:
		return
	tournament_submit_completed = true
	tournament_submit_succeeded = success


func save_tournament_attempt_payload(payload: Dictionary) -> void:
	if current_mode != Mode.TOURNAMENT:
		return
	tournament_last_attempt_payload = payload.duplicate(true)


func get_tournament_attempt_payload() -> Dictionary:
	return tournament_last_attempt_payload.duplicate(true)


func save_tournament_submit_response(response: Dictionary) -> void:
	if current_mode != Mode.TOURNAMENT:
		return
	tournament_last_submit_response = response.duplicate(true)
	tournament_submit_error_text = ""


func set_tournament_submit_error(text: String) -> void:
	if current_mode != Mode.TOURNAMENT:
		return
	tournament_submit_error_text = text


func reset_tournament_submit_state_for_retry() -> bool:
	if current_mode != Mode.TOURNAMENT:
		return false
	if not tournament_submit_completed or tournament_submit_succeeded:
		return false
	tournament_submit_started = false
	tournament_submit_completed = false
	tournament_submit_succeeded = false
	tournament_submit_error_text = ""
	return true


func _calc_accuracy() -> float:
	if rounds_played == 0:
		return 0.0
	return float(correct_answers) / float(rounds_played)


# ═══════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════

func _on_round_reset() -> void:
	# Новый раунд начался
	rounds_played += 1
	round_start_time = Time.get_ticks_msec() / 1000.0
	_last_player_cards.clear()
	_last_banker_cards.clear()


func _on_action_correct(_type: String) -> void:
	correct_answers += 1


func _on_payout_correct(_payload: Dictionary) -> void:
	correct_answers += 1


func _on_cards_dealt(player_hand: Array[Card], banker_hand: Array[Card]) -> void:
	_last_player_cards = _cards_to_strings(player_hand)
	_last_banker_cards = _cards_to_strings(banker_hand)


func _on_player_third_drawn(card: Card) -> void:
	if card and card.has_method("card_to_string"):
		_last_player_cards.append(str(card.card_to_string()))


func _on_banker_third_drawn(card: Card) -> void:
	if card and card.has_method("card_to_string"):
		_last_banker_cards.append(str(card.card_to_string()))


func _on_tournament_action_error(_error_type: Variant = null, _message: Variant = null) -> void:
	mark_tournament_error()


func _on_tournament_payout_wrong(_payload: Variant = null) -> void:
	mark_tournament_error()


func _on_tournament_collection_error(_payload: Variant = null) -> void:
	mark_tournament_error()


func _on_tournament_payment_error(_payload: Variant = null) -> void:
	mark_tournament_error()


func _cards_to_strings(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for c in cards:
		if c and c.has_method("card_to_string"):
			out.append(str(c.card_to_string()))
	return out


func _ensure_online_watchdog_timer() -> void:
	if _online_watchdog_timer != null:
		return
	_online_watchdog_timer = Timer.new()
	_online_watchdog_timer.name = "OnlineSessionWatchdogTimer"
	_online_watchdog_timer.one_shot = false
	_online_watchdog_timer.wait_time = ONLINE_WATCHDOG_INTERVAL_SEC
	add_child(_online_watchdog_timer)
	_online_watchdog_timer.timeout.connect(_on_online_watchdog_timeout)


func _start_online_watchdog() -> void:
	if current_mode != Mode.ONLINE:
		return
	_ensure_online_watchdog_timer()
	if _online_watchdog_timer == null:
		return
	if _online_watchdog_timer.is_stopped():
		_online_watchdog_timer.start()
	_on_online_watchdog_timeout.call_deferred()


func _stop_online_watchdog() -> void:
	if _online_watchdog_timer and not _online_watchdog_timer.is_stopped():
		_online_watchdog_timer.stop()
	_online_watchdog_in_flight = false


func _on_online_watchdog_timeout() -> void:
	if current_mode != Mode.ONLINE:
		return
	if _force_exit_in_progress or _online_watchdog_in_flight:
		return
	_online_watchdog_in_flight = true
	await _run_online_watchdog_check()
	_online_watchdog_in_flight = false


func _run_online_watchdog_check() -> void:
	if current_mode != Mode.ONLINE or _force_exit_in_progress:
		return

	var api_service := _find_api_service()
	if api_service == null or not api_service.has_method("fetch_active_live_session_async"):
		return

	var normalized_room_code := room_code.strip_edges()
	if normalized_room_code.is_empty():
		return

	var result: Dictionary = await api_service.fetch_active_live_session_async(normalized_room_code)
	if current_mode != Mode.ONLINE or _force_exit_in_progress:
		return

	var code: int = int(_dict_value(result, "code", 0))
	match code:
		200:
			return
		404:
			force_exit_online_session("session_finished", "Тренировка завершена")
		401, 403:
			force_exit_online_session("access_revoked", "Доступ к тренировке отозван")
		410:
			force_exit_online_session("room_closed", "Комната закрыта")
		0:
			return
		_:
			if code >= 500:
				return


func _clear_runtime_dealer_auth() -> void:
	var api_service := _find_api_service()
	if api_service == null:
		return
	if api_service.get("api_client") != null and api_service.api_client.has_method("clear_auth_token"):
		api_service.api_client.clear_auth_token()


func _emit_force_exit_toast(message: String) -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb == null:
		return
	if eb.has_signal("show_toast_error"):
		eb.show_toast_error.emit(message)


func _force_exit_message(reason_code: String) -> String:
	match reason_code:
		"session_finished":
			return "Тренировка завершена"
		"room_closed":
			return "Комната закрыта"
		"access_revoked":
			return "Доступ к тренировке отозван"
		_:
			return "Доступ к тренировке потерян"


func _find_api_service() -> Node:
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService") as Node
	return get_node_or_null("/root/ApiService")


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _dict_value(source: Dictionary, key: String, fallback: Variant) -> Variant:
	if source.has(key):
		return source[key]
	return fallback
