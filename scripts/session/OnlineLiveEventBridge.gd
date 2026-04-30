## Мост EventBus → LiveSessionClient: живые события для дашборда тренера (онлайн-сессия).
## Создаётся как дочерний узел GameController при Mode.ONLINE.
class_name OnlineLiveEventBridge
extends Node

## Номер раунда, для которого уже отправили round_completed (без дублей all_bets + heart).
var _last_round_completed_sent: int = -1
## Версия canonical snapshot контракта table_state.
const TABLE_STATE_SCHEMA_VERSION: int = 1
## Монотонный счетчик table_state в рамках дилера+сессии.
var _event_seq: int = 0
## Стабильный идентификатор текущего раунда.
var _current_round_id: String = ""
## Последнее действие дилера (v1, базовый каркас).
var _last_action: Dictionary = {
	"type": "",
	"value": null,
	"expected": null,
	"actual": null,
	"result": "", # "correct", "error"
	"details": {}
}
## Последняя ошибка дилера (v1, базовый каркас).
var _last_error: Dictionary = {
	"active": false,
	"error_type": null,
	"message": null,
	"details": {},
}
## Подавление legacy third-card action_performed после нового решения "карта каждому".
var _suppress_legacy_third_card_actions: bool = false
var _suppressed_legacy_third_card_count: int = 0
var _dealer_player_third_selected: bool = false
var _dealer_banker_third_selected: bool = false
var _suppress_next_payment_correct: bool = false


func _resolve_session_manager() -> Node:
	if Engine.has_singleton("SessionManager"):
		return SessionManager
	return get_node_or_null("/root/SessionManager")


func _resolve_live_session_client() -> Node:
	if Engine.has_singleton("LiveSessionClient"):
		return LiveSessionClient
	return get_node_or_null("/root/LiveSessionClient")


func _ready() -> void:
	var sm: Node = _resolve_session_manager()
	if sm and sm.has_signal("session_started"):
		sm.session_started.connect(_on_session_started)
	print("[OnlineLiveEventBridge] _ready: sm=%s, lsc=%s" % [sm != null, _resolve_live_session_client() != null])
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb == null:
		print("[OnlineLiveEventBridge] _ready: EventBus not found, bridge disabled")
		return
	eb.round_started.connect(_on_round_started)
	eb.cards_dealt.connect(_on_cards_dealt)
	eb.player_third_drawn.connect(_on_player_third_drawn)
	eb.banker_third_drawn.connect(_on_banker_third_drawn)
	eb.action_error.connect(_on_action_error)
	eb.action_correct.connect(_on_action_correct)
	eb.dealer_third_card_toggled.connect(_on_dealer_third_card_toggled)
	eb.dealer_third_card_decision.connect(_on_dealer_third_card_decision)
	eb.dealer_winner_marker_toggled.connect(_on_dealer_winner_marker_toggled)
	eb.payout_correct.connect(_on_payout_correct)
	eb.payout_wrong.connect(_on_payout_wrong)
	eb.all_bets_processed.connect(_on_all_bets_processed)
	eb.heart_bet_round_complete.connect(_on_heart_bet_round_complete)
	eb.collection_correct.connect(_on_collection_correct)
	eb.collection_error.connect(_on_collection_error)
	eb.payment_correct.connect(_on_payment_correct)
	eb.payment_error.connect(_on_payment_error)


func _exit_tree() -> void:
	var sm: Node = _resolve_session_manager()
	if sm and sm.has_signal("session_started"):
		if sm.session_started.is_connected(_on_session_started):
			sm.session_started.disconnect(_on_session_started)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb == null:
		return
	if eb.round_started.is_connected(_on_round_started):
		eb.round_started.disconnect(_on_round_started)
	if eb.cards_dealt.is_connected(_on_cards_dealt):
		eb.cards_dealt.disconnect(_on_cards_dealt)
	if eb.player_third_drawn.is_connected(_on_player_third_drawn):
		eb.player_third_drawn.disconnect(_on_player_third_drawn)
	if eb.banker_third_drawn.is_connected(_on_banker_third_drawn):
		eb.banker_third_drawn.disconnect(_on_banker_third_drawn)
	if eb.action_error.is_connected(_on_action_error):
		eb.action_error.disconnect(_on_action_error)
	if eb.action_correct.is_connected(_on_action_correct):
		eb.action_correct.disconnect(_on_action_correct)
	if eb.dealer_third_card_toggled.is_connected(_on_dealer_third_card_toggled):
		eb.dealer_third_card_toggled.disconnect(_on_dealer_third_card_toggled)
	if eb.dealer_third_card_decision.is_connected(_on_dealer_third_card_decision):
		eb.dealer_third_card_decision.disconnect(_on_dealer_third_card_decision)
	if eb.dealer_winner_marker_toggled.is_connected(_on_dealer_winner_marker_toggled):
		eb.dealer_winner_marker_toggled.disconnect(_on_dealer_winner_marker_toggled)
	if eb.payout_correct.is_connected(_on_payout_correct):
		eb.payout_correct.disconnect(_on_payout_correct)
	if eb.payout_wrong.is_connected(_on_payout_wrong):
		eb.payout_wrong.disconnect(_on_payout_wrong)
	if eb.all_bets_processed.is_connected(_on_all_bets_processed):
		eb.all_bets_processed.disconnect(_on_all_bets_processed)
	if eb.heart_bet_round_complete.is_connected(_on_heart_bet_round_complete):
		eb.heart_bet_round_complete.disconnect(_on_heart_bet_round_complete)
	if eb.collection_correct.is_connected(_on_collection_correct):
		eb.collection_correct.disconnect(_on_collection_correct)
	if eb.collection_error.is_connected(_on_collection_error):
		eb.collection_error.disconnect(_on_collection_error)
	if eb.payment_correct.is_connected(_on_payment_correct):
		eb.payment_correct.disconnect(_on_payment_correct)
	if eb.payment_error.is_connected(_on_payment_error):
		eb.payment_error.disconnect(_on_payment_error)


func _on_session_started(_mode: int) -> void:
	_last_round_completed_sent = -1
	_event_seq = 0
	_current_round_id = ""
	_last_action = {
		"type": "",
		"value": null,
		"expected": null,
		"actual": null,
		"result": "",
		"details": {}
	}
	_last_error = {
		"active": false,
		"error_type": null,
		"message": null,
		"details": {},
	}
	_suppress_legacy_third_card_actions = false
	_suppressed_legacy_third_card_count = 0
	_dealer_player_third_selected = false
	_dealer_banker_third_selected = false
	_suppress_next_payment_correct = false
	print("[OnlineLiveEventBridge] session_started: counters reset")


func _should_send() -> bool:
	var sm: Node = _resolve_session_manager()
	if sm == null:
		print("[OnlineLiveEventBridge] _should_send=false: SessionManager not found")
		return false
	if sm.current_mode != sm.Mode.ONLINE:
		print("[OnlineLiveEventBridge] _should_send=false: mode=%s" % str(sm.current_mode))
		return false
	var lsc: Node = _resolve_live_session_client()
	if lsc == null:
		print("[OnlineLiveEventBridge] _should_send=false: LiveSessionClient not found")
		return false
	if not lsc.has_method("is_live_connected"):
		print("[OnlineLiveEventBridge] _should_send=false: lsc has no is_live_connected()")
		return false
	var is_connected: bool = bool(lsc.is_live_connected())
	if not is_connected:
		print("[OnlineLiveEventBridge] _should_send=false: WS not connected")
	return is_connected


func _session_meta() -> Dictionary:
	var sm: Node = _resolve_session_manager()
	if sm == null:
		return {
			"dealer_id": "",
			"display_name": "",
			"round_number": 0,
		}
	return {
		"dealer_id": str(sm.dealer_id),
		"display_name": str(sm.display_name),
		"round_number": int(sm.rounds_played),
	}


func _lives_remaining() -> int:
	var gc: Node = get_parent()
	if gc == null or not gc.get("heart_bar"):
		return -1
	var hb: Variant = gc.heart_bar
	if hb == null:
		return -1
	return int(hb.current_lives)


func _winner_label() -> String:
	var gc: Node = get_parent()
	if gc == null or not gc.get("winner_selection_manager"):
		return ""
	var wsm: Variant = gc.winner_selection_manager
	if wsm == null:
		return ""
	return str(wsm.selected_winner)


func _get_expected_winner() -> String:
	var gc: Node = get_parent()
	if gc == null:
		return ""
	var hm: Variant = gc.get("hand_manager")
	if hm == null:
		return ""
	var p_hand: Array[Card] = []
	var b_hand: Array[Card] = []
	if hm.has_method("get_player_hand_ref"):
		var p_ref = hm.get_player_hand_ref()
		if p_ref is Array:
			p_hand.assign(p_ref)
	if hm.has_method("get_banker_hand_ref"):
		var b_ref = hm.get_banker_hand_ref()
		if b_ref is Array:
			b_hand.assign(b_ref)
	return BaccaratRules.get_winner(p_hand, b_hand)


func _is_game_over_hint() -> bool:
	var gc: Node = get_parent()
	if gc and gc.get("game_state_controller"):
		var gsc: Variant = gc.game_state_controller
		if gsc and gsc.has_method("get_is_game_over"):
			return bool(gsc.get_is_game_over())
	if _lives_remaining() <= 0:
		return true
	return false


func _timestamp_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _set_last_action(action_type: String, action_value: Variant = null, expected: Variant = null, actual: Variant = null, result: String = "", details: Dictionary = {}) -> void:
	_last_action = {
		"type": action_type,
		"value": action_value,
		"expected": expected,
		"actual": actual,
		"result": result,
		"details": details
	}


func _map_third_card_toggle_action(side: String, selected: bool) -> String:
	match side:
		"player":
			return "third_card_player_checked" if selected else "third_card_player_unchecked"
		"banker":
			return "third_card_banker_checked" if selected else "third_card_banker_unchecked"
		_:
			return ""


func _map_third_card_decision_action(decision: String) -> String:
	match decision:
		"player":
			return "third_card_decision_player"
		"banker":
			return "third_card_decision_banker"
		"each":
			return "third_card_decision_each"
		_:
			return ""


func _map_winner_marker_action(winner: String, selected: bool) -> String:
	match winner:
		"Player":
			return "winner_marker_player_selected" if selected else "winner_marker_player_unselected"
		"Banker":
			return "winner_marker_banker_selected" if selected else "winner_marker_banker_unselected"
		"Tie":
			return "winner_marker_tie_selected" if selected else "winner_marker_tie_unselected"
		_:
			return ""


func _emit_dealer_action_event(technical_name: String, reason: String, details: Dictionary = {}) -> void:
	if technical_name.is_empty() or not _should_send():
		return
	_set_last_action("action_performed", technical_name, technical_name, technical_name, "", details)
	_clear_last_error()
	var data: Dictionary = _session_meta()
	data["action_type"] = technical_name
	data["value"] = technical_name
	for key in details.keys():
		data[key] = details[key]
	LiveSessionClient.send_event("action_performed", data)
	send_table_state(reason)


func _set_last_error(error_type: String, message: String, details: Dictionary = {}) -> void:
	_last_error = {
		"active": true,
		"error_type": error_type,
		"message": message,
		"details": details.duplicate(true),
	}


func _resolve_phase_manager() -> Variant:
	var gc: Node = get_parent()
	if gc == null or not gc.get("phase_manager"):
		return null
	return gc.phase_manager


func _sync_third_card_selection_from_phase_manager() -> void:
	var pm: Variant = _resolve_phase_manager()
	if pm == null:
		return
	_dealer_player_third_selected = bool(pm.get("player_third_selected"))
	_dealer_banker_third_selected = bool(pm.get("banker_third_selected"))


func _current_third_card_actual_action() -> String:
	if _dealer_player_third_selected and _dealer_banker_third_selected:
		return "third_card_decision_each"
	if _dealer_player_third_selected:
		return "third_card_decision_player"
	if _dealer_banker_third_selected:
		return "third_card_decision_banker"
	return ""


func _current_third_card_expected_action() -> String:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("get_current_state"):
		return ""
	var state: int = int(gsm.get_current_state())
	match state:
		GameStateManager.GameState.CARD_TO_EACH:
			return "third_card_decision_each"
		GameStateManager.GameState.CARD_TO_PLAYER:
			return "third_card_decision_player"
		GameStateManager.GameState.CARD_TO_BANKER, GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER:
			return "third_card_decision_banker"
		_:
			return ""


func _bet_type_code(bet_type: String) -> String:
	match bet_type:
		"Player":
			return "player"
		"Banker":
			return "banker"
		"Tie":
			return "tie"
		"PlayerPair", "PairPlayer":
			return "player_pair"
		"BankerPair", "PairBanker":
			return "banker_pair"
		_:
			return ""


func _map_collection_event_code(actual_dict: Dictionary) -> String:
	var bet_code: String = _bet_type_code(str(actual_dict.get("bet_type", "")))
	if bet_code.is_empty():
		return ""
	return "take_%s_bet" % bet_code


func _map_collection_error_code(actual_dict: Dictionary, reason: String) -> String:
	if reason != "collect_winning":
		return ""
	var bet_code: String = _bet_type_code(str(actual_dict.get("bet_type", "")))
	if bet_code.is_empty():
		return ""
	return "error_took_winning_%s_bet" % bet_code


func _map_payment_success_code(actual_dict: Dictionary) -> String:
	var bet_code: String = _bet_type_code(str(actual_dict.get("bet_type", "")))
	if bet_code.is_empty():
		return ""
	return "pay_%s_bet_correct" % bet_code


func _map_payment_error_code(actual_dict: Dictionary, reason: String) -> String:
	var bet_code: String = _bet_type_code(str(actual_dict.get("bet_type", "")))
	if bet_code.is_empty():
		return ""
	if reason == "pay_losing":
		return "error_paid_losing_%s_bet" % bet_code
	return ""


func _map_payout_error_code(expected_dict: Dictionary, reason: String) -> String:
	if reason != "wrong_amount":
		return ""
	var bet_code: String = _bet_type_code(str(expected_dict.get("bet_type", "")))
	if bet_code.is_empty():
		return ""
	return "error_pay_%s_bet_amount" % bet_code


func _build_bet_event_details(event_code: String, expected_dict: Dictionary, actual_dict: Dictionary, reason: String = "", message: String = "") -> Dictionary:
	var details: Dictionary = {
		"event_code": event_code,
		"category": "payment",
		"bet_type": str(actual_dict.get("bet_type", expected_dict.get("bet_type", ""))),
		"position_index": int(actual_dict.get("position_index", expected_dict.get("position_index", -1))),
		"actual_amount": float(actual_dict.get("amount", 0.0)),
		"expected_amount": float(expected_dict.get("amount", 0.0)),
		"stake": float(actual_dict.get("stake", expected_dict.get("stake", 0.0))),
	}
	if not reason.is_empty():
		details["reason"] = reason
	if not message.is_empty():
		details["message"] = message
	return details


func _emit_structured_action_event(event_code: String, reason: String, details: Dictionary = {}) -> void:
	if event_code.is_empty() or not _should_send():
		return
	var safe_details: Dictionary = details.duplicate(true)
	safe_details["event_code"] = event_code
	_set_last_action("action_performed", event_code, event_code, event_code, "correct", safe_details)
	_clear_last_error()
	var data: Dictionary = _session_meta()
	data["action_type"] = event_code
	data["value"] = event_code
	for key in safe_details.keys():
		data[key] = safe_details[key]
	LiveSessionClient.send_event("action_performed", data)
	send_table_state(reason)


func _emit_structured_error_event(event_code: String, reason: String, message: String, details: Dictionary = {}) -> void:
	if not _should_send():
		return
	var safe_details: Dictionary = details.duplicate(true)
	if not event_code.is_empty():
		safe_details["event_code"] = event_code
	_set_last_action("error_occurred", event_code if not event_code.is_empty() else reason, "", "", "error", safe_details)
	_set_last_error(reason if not reason.is_empty() else event_code, message, safe_details)
	var data: Dictionary = _session_meta()
	data["error_type"] = reason if not reason.is_empty() else event_code
	data["message"] = message
	data["lives_remaining"] = _lives_remaining()
	if not event_code.is_empty():
		data["event_code"] = event_code
	for key in safe_details.keys():
		data[key] = safe_details[key]
	LiveSessionClient.send_event("error_occurred", data)
	send_table_state(reason if not reason.is_empty() else "error_occurred")


func _clear_last_error() -> void:
	_last_error = {
		"active": false,
		"error_type": null,
		"message": null,
		"details": {},
	}


func _collection_details(expected_dict: Dictionary, actual_dict: Dictionary, reason: String = "", message: String = "") -> Dictionary:
	var details: Dictionary = _build_bet_event_details("", expected_dict, actual_dict, reason, message)
	details["category"] = "collection"
	return details


func _payment_details(expected_dict: Dictionary, actual_dict: Dictionary, reason: String = "", message: String = "") -> Dictionary:
	var details: Dictionary = _build_bet_event_details("", expected_dict, actual_dict, reason, message)
	details["category"] = "payment"
	return details


func _manual_error_details(category: String, reason: String, message: String) -> Dictionary:
	return {
		"event_code": "",
		"category": category,
		"reason": reason,
		"message": message,
		"bet_type": "",
		"position_index": -1,
		"actual_amount": 0.0,
		"expected_amount": 0.0,
		"stake": 0.0,
	}


func _build_round_id(round_number: int) -> String:
	var sm: Node = _resolve_session_manager()
	if sm == null:
		return "unknown_session:unknown_dealer:%d" % round_number
	var sid: String = str(sm.session_id).strip_edges()
	var did: String = str(sm.dealer_id).strip_edges()
	if sid.is_empty():
		sid = "unknown_session"
	if did.is_empty():
		did = "unknown_dealer"
	return "%s:%s:%d" % [sid, did, round_number]


func _normalize_card_code(raw: String) -> String:
	var t: String = raw.strip_edges().to_upper()
	if t.is_empty():
		return ""
	var m: RegEx = RegEx.new()
	var err: int = m.compile("^(A|[2-9]|10|J|Q|K)([CHSD])$")
	if err != OK:
		return t
	var res: RegExMatch = m.search(t)
	if res == null:
		return ""
	return t


func _get_cards_from_session_snapshot(sm: Node) -> Dictionary:
	var out: Dictionary = {
		"player": [],
		"banker": [],
	}
	if sm == null or not sm.has_method("get_round_context_snapshot"):
		return out
	var snap: Variant = sm.get_round_context_snapshot()
	if snap is Dictionary:
		var p_raw: Variant = snap.get("player_cards", [])
		var b_raw: Variant = snap.get("banker_cards", [])
		if p_raw is Array:
			for x in p_raw:
				var code: String = _normalize_card_code(str(x))
				if not code.is_empty():
					out["player"].append(code)
		if b_raw is Array:
			for x in b_raw:
				var code_b: String = _normalize_card_code(str(x))
				if not code_b.is_empty():
					out["banker"].append(code_b)
	return out


func _get_cards_from_live_hand_manager() -> Dictionary:
	var out: Dictionary = {
		"player": [],
		"banker": [],
	}
	var gc: Node = get_parent()
	if gc == null:
		return out
	var hm: Variant = gc.get("hand_manager")
	if hm == null:
		return out
	if hm.has_method("get_player_hand_ref"):
		var p_live: Variant = hm.get_player_hand_ref()
		if p_live is Array:
			for c in p_live:
				if c and c.has_method("card_to_string"):
					var code: String = _normalize_card_code(str(c.card_to_string()))
					if not code.is_empty():
						out["player"].append(code)
	if hm.has_method("get_banker_hand_ref"):
		var b_live: Variant = hm.get_banker_hand_ref()
		if b_live is Array:
			for c_b in b_live:
				if c_b and c_b.has_method("card_to_string"):
					var code_b: String = _normalize_card_code(str(c_b.card_to_string()))
					if not code_b.is_empty():
						out["banker"].append(code_b)
	return out


func _merge_cards(preferred: Array, fallback: Array) -> Array[String]:
	var src: Array = preferred
	if src.is_empty():
		src = fallback
	var merged: Array[String] = []
	for x in src:
		var code: String = _normalize_card_code(str(x))
		if not code.is_empty():
			merged.append(code)
	return merged


func _to_card_slots(codes: Array[String]) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in range(3):
		var code: Variant = null
		var visible: bool = false
		if i < codes.size():
			code = codes[i]
			visible = true
		slots.append({
			"slot": i,
			"code": code,
			"visible": visible,
		})
	return slots


func _rank_points(rank: String) -> int:
	match rank:
		"A":
			return 1
		"2", "3", "4", "5", "6", "7", "8", "9":
			return int(rank)
		_:
			return 0


func _calc_baccarat_score(codes: Array[String]) -> Variant:
	if codes.is_empty():
		return null
	var total: int = 0
	for code in codes:
		var c: String = _normalize_card_code(code)
		if c.is_empty():
			continue
		var suit: String = c.right(1)
		var rank: String = c.left(c.length() - suit.length())
		total += _rank_points(rank)
	return total % 10


func _map_phase() -> String:
	if _last_action.get("type", "") == "round_completed":
		return "round_completed"
	if str(_last_action.get("type", "")).begins_with("payout"):
		return "payout"
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("get_current_state"):
		return "waiting"
	var st: int = int(gsm.get_current_state())
	if st == 1:
		return "waiting"
	if st == 2:
		return "dealing_initial"
	if st == 3:
		return "third_card_player"
	if st == 4 or st == 5:
		return "third_card_banker"
	if st == 6:
		return "winner_selection"
	return "waiting"


func build_table_state() -> Dictionary:
	## Commit 2: сбор реальных карт/счета/фазы с null-safe fallback.
	var sm: Node = _resolve_session_manager()
	var round_number: int = 0
	if sm != null:
		round_number = int(sm.rounds_played)
		_current_round_id = _build_round_id(round_number)
	else:
		_current_round_id = "unknown_session:unknown_dealer:0"
	var snap_cards: Dictionary = _get_cards_from_session_snapshot(sm)
	var live_cards: Dictionary = _get_cards_from_live_hand_manager()
	var player_codes: Array[String] = _merge_cards(snap_cards.get("player", []), live_cards.get("player", []))
	var banker_codes: Array[String] = _merge_cards(snap_cards.get("banker", []), live_cards.get("banker", []))
	var player_slots: Array[Dictionary] = _to_card_slots(player_codes)
	var banker_slots: Array[Dictionary] = _to_card_slots(banker_codes)

	return {
		"schema_version": TABLE_STATE_SCHEMA_VERSION,
		"dealer_id": str(sm.dealer_id) if sm != null else "",
		"display_name": str(sm.display_name) if sm != null else "",
		"session_id": str(sm.session_id) if sm != null else "",
		"round_number": round_number,
		"round_id": _current_round_id,
		"event_seq": _event_seq,
		"timestamp": _timestamp_ms(),
		"phase": _map_phase(),
		"player": {
			"cards": player_slots,
			"score": _calc_baccarat_score(player_codes),
		},
		"banker": {
			"cards": banker_slots,
			"score": _calc_baccarat_score(banker_codes),
		},
		"last_action": _last_action.duplicate(true),
		"error": _last_error.duplicate(true),
		"lives_remaining": _lives_remaining(),
		"is_game_over": _is_game_over_hint(),
	}


func send_table_state(reason: String) -> void:
	print("[OnlineLiveEventBridge] DEBUG send_table_state called: reason=%s" % str(reason))
	## Commit 1: метод добавлен, массовая отправка по событиям будет на следующих шагах.
	if not _should_send():
		print("[OnlineLiveEventBridge] table_state skipped: reason=%s" % reason)
		return
	_event_seq += 1
	var payload: Dictionary = build_table_state()
	payload["reason"] = reason
	var lsc: Node = _resolve_live_session_client()
	if lsc == null or not lsc.has_method("send_event"):
		print("[OnlineLiveEventBridge] table_state skipped: lsc/send_event missing, reason=%s" % reason)
		return
	lsc.send_event("table_state", payload)
	print("[OnlineLiveEventBridge] table_state sent: reason=%s seq=%d round_id=%s phase=%s" % [
		reason,
		_event_seq,
		str(payload.get("round_id", "")),
		str(payload.get("phase", "")),
	])


func _on_round_started() -> void:
	if not _should_send():
		return
	_dealer_player_third_selected = false
	_dealer_banker_third_selected = false
	var should_preserve_last_action = _last_action.get("type", "") in ["action_correct", "action_error"]
	if not should_preserve_last_action:
		_set_last_action("round_started", null)
	_clear_last_error()
	var data: Dictionary = _session_meta()
	data["timestamp"] = int(Time.get_unix_time_from_system())
	LiveSessionClient.send_event("round_started", data)
	send_table_state("round_started")


func _on_cards_dealt(_player_hand: Array[Card], _banker_hand: Array[Card]) -> void:
	_set_last_action("cards_dealt", null)
	send_table_state("cards_dealt")


func _on_player_third_drawn(_card: Card) -> void:
	_set_last_action("action_correct", "player_third", "player_third", "player_third", "correct", {})
	send_table_state("player_third_drawn")


func _on_banker_third_drawn(_card: Card) -> void:
	_set_last_action("action_correct", "banker_third", "banker_third", "banker_third", "correct", {})
	send_table_state("banker_third_drawn")


func _on_dealer_third_card_toggled(side: String, selected: bool) -> void:
	if side == "player":
		_dealer_player_third_selected = selected
	elif side == "banker":
		_dealer_banker_third_selected = selected
	var technical_name: String = _map_third_card_toggle_action(side, selected)
	_emit_dealer_action_event(technical_name, technical_name, {
		"side": side,
		"selected": selected,
	})


func _on_dealer_third_card_decision(decision: String) -> void:
	var technical_name: String = _map_third_card_decision_action(decision)
	if decision == "each":
		_suppress_legacy_third_card_actions = true
		_suppressed_legacy_third_card_count = 0
	_emit_dealer_action_event(technical_name, technical_name, {
		"decision": decision,
	})


func _on_dealer_winner_marker_toggled(winner: String, selected: bool) -> void:
	var technical_name: String = _map_winner_marker_action(winner, selected)
	_emit_dealer_action_event(technical_name, technical_name, {
		"winner": winner,
		"selected": selected,
	})


func _on_action_error(err_type: String, message: String) -> void:
	if not _should_send():
		return
	
	var effective_err_type = str(err_type)
	if err_type == "incomplete_bets":
		if message == "ERR_COMPLETE_BEFORE_COLLECT":
			var collect_details: Dictionary = _manual_error_details("collection", "complete_before_collect", message)
			_emit_structured_error_event("", "incomplete_bets", message, collect_details)
			return
		if message == "ERR_COMPLETE_BEFORE_PAY":
			var pay_details: Dictionary = _manual_error_details("payment", "complete_before_pay", message)
			_emit_structured_error_event("", "incomplete_bets", message, pay_details)
			return
	if err_type == "winner_wrong" or err_type == "tie_wrong":
		var actual = _winner_label()
		var expected = _get_expected_winner()
		if actual == "Tie" and expected != "Tie":
			effective_err_type = "tie_wrong"
		_set_last_action("action_error", effective_err_type, expected, actual, "error", {})
	elif err_type in ["player_wrong", "banker_wrong", "both_wrong"]:
		var actual_action = _current_third_card_actual_action()
		var expected_action = _current_third_card_expected_action()
		_set_last_action("action_error", effective_err_type, expected_action, actual_action, "error", {})
	elif err_type == "natural_draw":
		_set_last_action("action_error", effective_err_type, "natural_draw", "natural_draw", "error", {})
	else:
		_set_last_action("action_error", effective_err_type)
	
	_set_last_error(effective_err_type, str(message))
	var data: Dictionary = _session_meta()
	data["error_type"] = effective_err_type
	data["message"] = str(message)
	data["lives_remaining"] = _lives_remaining()
	if err_type in ["player_wrong", "banker_wrong", "both_wrong"]:
		var actual_action = _current_third_card_actual_action()
		var expected_action = _current_third_card_expected_action()
		if not actual_action.is_empty():
			data["actual_action"] = actual_action
		if not expected_action.is_empty():
			data["expected_action"] = expected_action
	LiveSessionClient.send_event("error_occurred", data)
	send_table_state("action_error")
	_sync_third_card_selection_from_phase_manager()


func _on_action_correct(action_type: String) -> void:
	print("[OnlineLiveEventBridge] DEBUG _on_action_correct called: action_type=%s" % str(action_type))
	if not _should_send():
		print("[OnlineLiveEventBridge] DEBUG _on_action_correct blocked by _should_send")
		return

	if _suppress_legacy_third_card_actions and action_type in ["player_third", "banker_third"]:
		_suppressed_legacy_third_card_count += 1
		if _suppressed_legacy_third_card_count >= 2:
			_suppress_legacy_third_card_actions = false
			_suppressed_legacy_third_card_count = 0
		_sync_third_card_selection_from_phase_manager()
		send_table_state("action_correct_suppressed")
		return
	
	if action_type == "winner":
		var actual = _winner_label()
		var expected = _get_expected_winner()
		_set_last_action("action_correct", actual, expected, actual, "correct", {})
	elif action_type in ["player_third", "banker_third", "both_third", "banker_third_after_player", "no_third"]:
		_set_last_action("action_correct", str(action_type), str(action_type), str(action_type), "correct", {})
	else:
		_set_last_action("action_correct", str(action_type))
	
	_clear_last_error()
	var data: Dictionary = _session_meta()
	data["is_correct"] = true
	if action_type == "winner":
		data["action_type"] = "winner_selection"
		data["value"] = _winner_label()
	elif action_type in ["player_third", "banker_third", "both_third", "banker_third_after_player", "no_third"]:
		data["action_type"] = str(action_type)
		data["value"] = str(action_type)
	else:
		data["action_type"] = str(action_type)
		data["value"] = ""
	LiveSessionClient.send_event("action_performed", data)
	send_table_state("action_correct")
	_sync_third_card_selection_from_phase_manager()

	if _suppress_legacy_third_card_actions:
		_suppress_legacy_third_card_actions = false
		_suppressed_legacy_third_card_count = 0


func _on_payout_correct(payload: Dictionary) -> void:
	var expected_dict: Dictionary = _payload_expected(payload)
	var actual_dict: Dictionary = _payload_actual(payload)
	var event_code: String = _map_payment_success_code(actual_dict)
	if not event_code.is_empty():
		_suppress_next_payment_correct = true
		var details: Dictionary = _payment_details(expected_dict, actual_dict)
		details["event_code"] = event_code
		_emit_structured_action_event(event_code, "payout_correct", details)
		return
	_set_last_action("payout_correct", actual_dict, expected_dict, actual_dict, "correct", payload)
	_clear_last_error()
	send_table_state("payout_correct")


func _on_payout_wrong(payload: Dictionary) -> void:
	if not _should_send():
		return
	var expected_dict: Dictionary = _payload_expected(payload)
	var actual_dict: Dictionary = _payload_actual(payload)
	var reason: String = _payload_reason(payload, "wrong_amount")
	var message: String = _payload_message(payload, "Неверная выплата")
	var event_code: String = _map_payout_error_code(expected_dict, reason)
	if not event_code.is_empty():
		var details: Dictionary = _payment_details(expected_dict, actual_dict, reason, message)
		details["event_code"] = event_code
		_emit_structured_error_event(event_code, "payout_wrong", message, details)
		return
	_set_last_action("payout_wrong", reason, expected_dict, actual_dict, "error", payload)
	_set_last_error("payout_wrong", message)
	var data: Dictionary = _session_meta()
	data["error_type"] = "payout_wrong"
	data["message"] = message
	data["lives_remaining"] = _lives_remaining()
	data["bet_type"] = str(expected_dict.get("bet_type", ""))
	data["collected"] = float(actual_dict.get("amount", 0.0))
	data["expected"] = float(expected_dict.get("amount", 0.0))
	data["position_index"] = int(expected_dict.get("position_index", -1))
	LiveSessionClient.send_event("error_occurred", data)
	send_table_state("payout_wrong")


func _send_round_completed() -> void:
	if not _should_send():
		return
	var sm: Node = SessionManager
	var rn: int = int(sm.rounds_played)
	if rn == _last_round_completed_sent:
		return
	_last_round_completed_sent = rn
	var stats: Dictionary = sm.get_session_stats()
	var acc: float = float(stats.get("accuracy", 0.0))
	if acc > 1.0001:
		acc = acc / 100.0
	var t0: float = float(sm.round_start_time)
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	var spent: int = int(max(0.0, now_sec - t0))
	var data: Dictionary = _session_meta()
	data["accuracy"] = acc
	data["time_spent"] = spent
	data["is_game_over"] = _is_game_over_hint()
	_set_last_action("round_completed", null)
	LiveSessionClient.send_event("round_completed", data)
	send_table_state("round_completed")


func _on_all_bets_processed() -> void:
	_send_round_completed()


func _on_heart_bet_round_complete() -> void:
	send_table_state("heart_bet_round_complete")
	_send_round_completed()


func _on_collection_correct(payload: Dictionary) -> void:
	var expected = _payload_expected(payload)
	var actual = _payload_actual(payload)
	var event_code: String = _map_collection_event_code(actual)
	if not event_code.is_empty():
		var details: Dictionary = _collection_details(expected, actual)
		details["event_code"] = event_code
		if _should_send():
			_set_last_action("action_performed", event_code, event_code, event_code, "correct", details)
			_clear_last_error()
			var data: Dictionary = _session_meta()
			data["action_type"] = event_code
			data["value"] = event_code
			for key in details.keys():
				data[key] = details[key]
			LiveSessionClient.send_event("action_performed", data)
			send_table_state("collection_correct")
			return
		_set_last_action("collection_correct", actual, expected, actual, "correct", payload)
		_clear_last_error()
		send_table_state("collection_correct")
		return
	_set_last_action("collection_correct", actual, expected, actual, "correct", payload)
	_clear_last_error()
	send_table_state("collection_correct")


func _on_collection_error(payload: Dictionary) -> void:
	var expected = _payload_expected(payload)
	var actual = _payload_actual(payload)
	var reason = _payload_reason(payload, "collection_error")
	var message = _payload_message(payload, "Ошибка сбора ставок")
	var event_code: String = _map_collection_error_code(actual, reason)
	var details: Dictionary = _collection_details(expected, actual, reason, message)
	var should_emit_live_error: bool = (not event_code.is_empty()) or reason == "wrong_order" or reason == "pay_before_collect"
	if should_emit_live_error and _should_send():
		if not event_code.is_empty():
			details["event_code"] = event_code
		_set_last_action("error_occurred", event_code if not event_code.is_empty() else "collection_error", "", "", "error", details)
		_set_last_error("collection_error", message, details)
		var data: Dictionary = _session_meta()
		data["error_type"] = "collection_error"
		data["message"] = message
		data["lives_remaining"] = _lives_remaining()
		for key in details.keys():
			data[key] = details[key]
		LiveSessionClient.send_event("error_occurred", data)
		send_table_state("collection_error")
		return
	_set_last_action("collection_error", reason, expected, actual, "error", payload)
	_set_last_error("collection_error", message)
	send_table_state("collection_error")


func _on_payment_correct(payload: Dictionary) -> void:
	var expected = _payload_expected(payload)
	var actual = _payload_actual(payload)
	if _suppress_next_payment_correct:
		_suppress_next_payment_correct = false
		send_table_state("payment_correct_suppressed")
		return
	var event_code: String = _map_payment_success_code(actual)
	if not event_code.is_empty():
		var details: Dictionary = _payment_details(expected, actual)
		details["event_code"] = event_code
		_emit_structured_action_event(event_code, "payment_correct", details)
		return
	_set_last_action("payment_correct", actual, expected, actual, "correct", payload)
	_clear_last_error()
	send_table_state("payment_correct")


func _on_payment_error(payload: Dictionary) -> void:
	var expected = _payload_expected(payload)
	var actual = _payload_actual(payload)
	var reason = _payload_reason(payload, "payment_error")
	var message = _payload_message(payload, "Ошибка оплаты ставок")
	var event_code: String = _map_payment_error_code(actual, reason)
	var details: Dictionary = _payment_details(expected, actual, reason, message)
	if not event_code.is_empty():
		details["event_code"] = event_code
		_emit_structured_error_event(event_code, "payment_error", message, details)
		return
	if reason == "wrong_order":
		_emit_structured_error_event("", "payment_error", message, details)
		return
	_set_last_action("payment_error", reason, expected, actual, "error", payload)
	_set_last_error("payment_error", message)
	send_table_state("payment_error")


# === Helper functions for payload access ===
func _payload_expected(payload: Dictionary) -> Dictionary:
	return payload.get("expected", {})

func _payload_actual(payload: Dictionary) -> Dictionary:
	return payload.get("actual", {})

func _payload_reason(payload: Dictionary, fallback: String) -> String:
	return payload.get("reason", fallback)

func _payload_message(payload: Dictionary, fallback: String) -> String:
	return payload.get("message", fallback)
