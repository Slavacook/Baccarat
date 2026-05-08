# res://scripts/TrainingHintManager.gd
# Read-only адаптер для отладочных обучающих подсказок
# Не вычисляет правила баккары сам, а читает уже готовое состояние игры

class_name TrainingHintManager
extends RefCounted

var phase_resolver: PhaseActionResolver = null
var hand_manager: HandManager = null
var _last_log_signature: String = ""

func _init(phase_resolver_ref: PhaseActionResolver = null, hand_manager_ref: HandManager = null) -> void:
	phase_resolver = phase_resolver_ref
	hand_manager = hand_manager_ref

func build_debug_hint(is_table_prepared: bool) -> Dictionary:
	var current_state: GameStateManager.GameState = GameStateManager.get_current_state()
	var state_name := GameStateManager.get_state_name(current_state)
	var valid_actions_raw: Array = GameStateManager.get_valid_actions(current_state)
	var allowed_actions := _stringify_actions(valid_actions_raw)

	var resolver_action := "unknown"
	var resolver_phase := "unknown"
	var resolver_reason := "Нет данных о следующем шаге"
	if phase_resolver:
		var resolved := phase_resolver.resolve_action(is_table_prepared, current_state)
		resolver_action = str(resolved.get("action", "unknown"))
		resolver_phase = str(resolved.get("phase", "unknown"))
		resolver_reason = str(resolved.get("reason", resolver_reason))

	var expected_action := _map_expected_action(current_state, resolver_action)
	var player_insight := _build_player_insight()
	var banker_insight := _build_banker_insight()
	var inspector := _build_inspector_payload(expected_action, resolver_action, resolver_reason, player_insight, banker_insight)

	return {
		"state": current_state,
		"state_name": state_name,
		"title": str(inspector.get("title", "")),
		"explanation": str(inspector.get("message", "")),
		"expected_action": expected_action,
		"allowed_actions": allowed_actions,
		"phase": resolver_phase,
		"reason_code": resolver_action,
		"resolver_action": resolver_action,
		"resolver_reason": resolver_reason,
		"severity": str(inspector.get("severity", "info")),
		"player": player_insight,
		"banker": banker_insight,
		"inspector": inspector,
		"current_state": state_name,
	}

func log_debug_hint_if_changed(is_table_prepared: bool) -> Dictionary:
	var hint := build_debug_hint(is_table_prepared)
	if not OS.is_debug_build():
		return hint

	var signature := "%s|%s|%s|%s|%s|%s" % [
		str(hint.get("state", "")),
		str(hint.get("expected_action", "")),
		_string_field(hint.get("player", {}), "zone"),
		_string_field(hint.get("banker", {}), "zone"),
		str(hint.get("phase", "")),
		_string_field(hint.get("inspector", {}), "reason_code")
	]
	if signature == _last_log_signature:
		return hint

	_last_log_signature = signature
	print("[TrainingHint] state=%s(%s) valid_actions=%s expected=%s phase=%s reason=%s title=%s explanation=%s" % [
		str(hint.get("state", "")),
		str(hint.get("state_name", "")),
		str(hint.get("allowed_actions", [])),
		str(hint.get("expected_action", "")),
		str(hint.get("phase", "")),
		str(hint.get("resolver_reason", "")),
		str(hint.get("title", "")),
		str(hint.get("explanation", ""))
	])
	print("[TrainingHintInsight] player=%s zone=%s banker=%s zone=%s inspector=\"%s\"" % [
		_int_field(hint.get("player", {}), "decision_score"),
		_string_field(hint.get("player", {}), "zone"),
		_int_field(hint.get("banker", {}), "decision_score"),
		_string_field(hint.get("banker", {}), "zone"),
		_string_field(hint.get("inspector", {}), "message")
	])
	return hint

func _stringify_actions(actions: Array) -> Array[String]:
	var result: Array[String] = []
	for action in actions:
		result.append(GameStateManager.get_action_name(int(action)))
	return result

func _join_allowed_actions(actions: Variant) -> String:
	if actions is Array:
		var parts: Array[String] = []
		for action in actions:
			parts.append(str(action))
		return ",".join(parts)
	return ""

func _build_player_insight() -> Dictionary:
	var score := 0
	var initial_score := 0
	var has_third_card := false
	var card_count := 0
	if hand_manager:
		score = hand_manager.get_player_score()
		initial_score = hand_manager.get_player_initial_score()
		has_third_card = hand_manager.has_player_third_card()
		card_count = hand_manager.get_player_hand_ref().size()

	var is_natural := _is_display_natural(initial_score, has_third_card, card_count)
	var zone := "unknown"
	var zone_title := "Ожидается следующая оценка"
	if card_count < 2:
		zone = "empty"
		zone_title = "Ожидание карт"
	elif is_natural:
		zone = "natural_zone"
		zone_title = "Natural"
	elif has_third_card:
		zone = "final_only"
		zone_title = "Итоговая сумма"
	elif initial_score <= 5:
		zone = "player_draw_zone"
		zone_title = "0–5: берёт карту"
	elif initial_score <= 7:
		zone = "player_stand_zone"
		zone_title = "6–7: стоит"
	elif initial_score <= 9:
		zone = "natural_zone"
		zone_title = "Natural"

	return {
		"score": score,
		"initial_score": initial_score,
		"decision_score": initial_score,
		"label": "Player %d" % score,
		"zone": zone,
		"zone_title": zone_title,
		"scale_position": initial_score,
		"is_natural": is_natural,
		"has_third_card": has_third_card,
		"card_count": card_count
	}

func _build_banker_insight() -> Dictionary:
	var score := 0
	var initial_score := 0
	var has_third_card := false
	var card_count := 0
	if hand_manager:
		score = hand_manager.get_banker_score()
		initial_score = hand_manager.get_banker_initial_score()
		has_third_card = hand_manager.has_banker_third_card()
		card_count = hand_manager.get_banker_hand_ref().size()

	var is_natural := _is_display_natural(initial_score, has_third_card, card_count)
	var zone := "unknown"
	var zone_title := "Ожидается следующая оценка"
	if card_count < 2:
		zone = "empty"
		zone_title = "Ожидание карт"
	elif is_natural:
		zone = "natural_zone"
		zone_title = "Natural"
	elif has_third_card:
		zone = "final_only"
		zone_title = "Итоговая сумма"
	elif initial_score <= 2:
		zone = "banker_draw_0_2"
		zone_title = "0–2: точно берёт"
	elif initial_score <= 6:
		zone = "banker_complex_3_6"
		zone_title = "3–6: зависит от Player"
	elif initial_score == 7:
		zone = "banker_stand_7"
		zone_title = "7: точно стоит"
	elif initial_score <= 9:
		zone = "natural_zone"
		zone_title = "Natural"

	return {
		"score": score,
		"initial_score": initial_score,
		"decision_score": initial_score,
		"label": "Banker %d" % score,
		"zone": zone,
		"zone_title": zone_title,
		"scale_position": initial_score,
		"is_natural": is_natural,
		"has_third_card": has_third_card,
		"card_count": card_count
	}

func _is_display_natural(initial_score: int, has_third_card: bool, card_count: int) -> bool:
	if has_third_card:
		return false
	if card_count < 2:
		return false
	return initial_score >= 8 and initial_score <= 9

func _build_inspector_payload(
	expected_action: String,
	resolver_action: String,
	resolver_reason: String,
	player_insight: Dictionary,
	banker_insight: Dictionary
) -> Dictionary:
	var title := _build_title(expected_action)
	var message := "Используется текущее состояние игры."

	if bool(player_insight.get("is_natural", false)) or bool(banker_insight.get("is_natural", false)):
		title = "Natural 8/9"
		message = "Natural 8 или 9 завершает раздачу. Третья карта никому не даётся."
	elif expected_action == "player_third":
		message = "Natural нет. Сначала смотри Player: 0–5 берёт карту, 6–7 стоит."
	elif expected_action == "banker_third":
		message = "Теперь смотри Banker. 0–2 берёт, 7 стоит, 3–6 зависит от третьей карты Player."
	elif expected_action == "choose_winner":
		message = "Раздача завершена. Сравни итоговые очки и выбери победителя."
	else:
		message = "Используется текущее состояние игры. %s" % resolver_reason

	return {
		"title": title,
		"message": message,
		"severity": "info",
		"reason_code": resolver_action
	}

func _string_field(source: Variant, key: String) -> String:
	if source is Dictionary:
		return str(source.get(key, ""))
	return ""

func _int_field(source: Variant, key: String) -> int:
	if source is Dictionary:
		return int(source.get(key, 0))
	return 0

func _map_expected_action(current_state: GameStateManager.GameState, resolver_action: String) -> String:
	match current_state:
		GameStateManager.GameState.WAITING:
			return "deal_cards"
		GameStateManager.GameState.CARD_TO_EACH:
			return "both_third"
		GameStateManager.GameState.CARD_TO_PLAYER:
			return "player_third"
		GameStateManager.GameState.CARD_TO_BANKER, GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER:
			return "banker_third"
		GameStateManager.GameState.CHOOSE_WINNER:
			return "choose_winner"
		_:
			pass

	match resolver_action:
		"deal_first_four":
			return "deal_cards"
		"validate_banker_after_player":
			return "banker_third"
		"handle_choose_winner":
			return "choose_winner"
		_:
			return "unknown"

func _build_title(expected_action: String) -> String:
	match expected_action:
		"deal_cards":
			return "Продолжите раздачу"
		"player_third":
			return "Дайте третью карту Player"
		"banker_third":
			return "Дайте третью карту Banker"
		"both_third":
			return "Дайте третьи карты обеим сторонам"
		"choose_winner":
			return "Выберите победителя"
		_:
			return "Ожидается следующее действие"
