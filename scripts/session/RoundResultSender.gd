## Отправляет результаты раундов на сервер.
## Подписывается на EventBus и формирует данные для отправки.
class_name RoundResultSender
extends Node

var _api_service: Node = null
var _session_manager: Node = null

var _pending_results: Array[Dictionary] = []
const SAVE_PATH: String = "user://pending_results.json"


func _ready() -> void:
	_session_manager = _find_session_manager()
	_api_service = _find_api_service()

	_load_pending_results()

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		eb.payout_correct.connect(_on_round_complete)


func _on_round_complete(_collected: float, _expected: float, _bet_type: String, _position_index: int) -> void:
	if not _session_manager or _session_manager.current_mode != SessionManager.Mode.ONLINE:
		return

	var sid: String = str(_session_manager.session_id)
	if sid.is_empty():
		push_warning("[RoundResultSender] Нет session_id — пропуск отправки раунда")
		return

	var stats: Dictionary = _session_manager.get_session_stats()
	var time_spent: float = Time.get_ticks_msec() / 1000.0 - _session_manager.round_start_time

	var acc_raw: float = float(stats.get("accuracy", 0.0))
	var acc_pct: float = acc_raw * 100.0 if acc_raw <= 1.0001 else acc_raw

	var rn: int = int(stats.get("rounds_played", 1))
	if rn < 1:
		rn = 1

	var payload: Dictionary = {
		"round_number": rn,
		"accuracy": acc_pct,
		"errors": [],
		"time_spent_seconds": int(max(3.0, time_spent)),
		"payout_correct": true,
		"round_context": _build_round_context(),
	}

	if _api_service and _api_service.has_method("submit_round_result_async"):
		_send_async.call_deferred(sid, payload)
	else:
		_pending_results.append(payload)
		_save_pending_results()
		print("[RoundResultSender] Нет ApiService — раунд сохранён локально в очередь")


func _build_round_context() -> Dictionary:
	var ctx: Dictionary = {}
	if _session_manager:
		ctx["round_seed"] = str(_session_manager.live_round_seed)
		if _session_manager.has_method("get_round_context_snapshot"):
			var snap: Dictionary = _session_manager.get_round_context_snapshot()
			if snap is Dictionary:
				ctx["player_cards"] = snap.get("player_cards", [])
				ctx["banker_cards"] = snap.get("banker_cards", [])
	var gc: Node = get_tree().current_scene
	if gc == null:
		return ctx
	var hm: Variant = gc.get("hand_manager")
	if hm != null:
		var p_live: Array = []
		var b_live: Array = []
		if hm.has_method("get_player_hand_ref"):
			p_live = hm.get_player_hand_ref()
		if hm.has_method("get_banker_hand_ref"):
			b_live = hm.get_banker_hand_ref()
		var p_live_s: Array[String] = _cards_to_strings(p_live)
		var b_live_s: Array[String] = _cards_to_strings(b_live)
		if not p_live_s.is_empty():
			ctx["player_cards"] = p_live_s
		if not b_live_s.is_empty():
			ctx["banker_cards"] = b_live_s
	var tm: Variant = gc.get("training_mode_manager")
	if tm == null:
		return ctx
	var stage: Variant = tm.get("current_stage")
	if stage != null:
		ctx["stage_id"] = str(stage.get("stage_id"))
	var scenario: Variant = tm.get("current_scenario")
	if scenario is Dictionary:
		var p_cards: Array = ctx.get("player_cards", [])
		var b_cards: Array = ctx.get("banker_cards", [])
		if p_cards.is_empty():
			ctx["player_cards"] = _cards_to_strings(scenario.get("player_hand", []))
		if b_cards.is_empty():
			ctx["banker_cards"] = _cards_to_strings(scenario.get("banker_hand", []))
	return ctx


func _cards_to_strings(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for c in cards:
		if c and c.has_method("card_to_string"):
			out.append(str(c.card_to_string()))
	return out


func _send_async(session_id_str: String, payload: Dictionary) -> void:
	var code: int = await _api_service.submit_round_result_async(session_id_str, payload)
	if code == 201:
		print("[RoundResultSender] Раунд %d отправлен (HTTP %d)" % [payload.get("round_number", 0), code])
	else:
		push_warning("[RoundResultSender] Ошибка отправки раунда: HTTP %d" % code)
		_pending_results.append(payload)
		_save_pending_results()


func flush_results_to_server() -> Error:
	## Отправка накопленного буфера после обрыва связи (TODO: последовательный await без блокировки UI).
	if _pending_results.is_empty():
		return OK
	return ERR_UNAVAILABLE


func _load_pending_results() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json: Variant = JSON.parse_string(file.get_as_text())
		if json is Array:
			_pending_results.clear()
			for x in json:
				if x is Dictionary:
					_pending_results.append(x)
		file.close()


func _save_pending_results() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_pending_results))
		file.close()


func _find_session_manager() -> Node:
	if Engine.has_singleton("SessionManager"):
		return Engine.get_singleton("SessionManager") as Node
	var root: Node = get_tree().root
	for child in root.get_children():
		if child.name == "SessionManager":
			return child
	return null


func _find_api_service() -> Node:
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService") as Node
	var root: Node = get_tree().root
	for child in root.get_children():
		if child.name == "ApiService":
			return child
	return null
