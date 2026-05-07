# res://scripts/TrainingHintManager.gd
# Read-only адаптер для отладочных обучающих подсказок
# Не вычисляет правила баккары сам, а читает уже готовое состояние игры

class_name TrainingHintManager
extends RefCounted

var phase_resolver: PhaseActionResolver = null
var _last_log_signature: String = ""

func _init(phase_resolver_ref: PhaseActionResolver = null) -> void:
	phase_resolver = phase_resolver_ref

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
	var title := _build_title(expected_action)
	var explanation := _build_explanation(expected_action, resolver_reason)

	return {
		"state": current_state,
		"state_name": state_name,
		"title": title,
		"explanation": explanation,
		"expected_action": expected_action,
		"allowed_actions": allowed_actions,
		"phase": resolver_phase,
		"reason_code": resolver_action,
		"resolver_action": resolver_action,
		"resolver_reason": resolver_reason,
		"severity": "info",
	}

func log_debug_hint_if_changed(is_table_prepared: bool) -> void:
	if not OS.is_debug_build():
		return

	var hint := build_debug_hint(is_table_prepared)
	var signature := "%s|%s|%s|%s|%s" % [
		str(hint.get("state", "")),
		str(hint.get("expected_action", "")),
		str(hint.get("phase", "")),
		str(hint.get("reason_code", "")),
		_join_allowed_actions(hint.get("allowed_actions", []))
	]
	if signature == _last_log_signature:
		return

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

func _build_explanation(expected_action: String, resolver_reason: String) -> String:
	match expected_action:
		"deal_cards":
			return "Игра ждёт следующую раздачу. %s" % resolver_reason
		"player_third":
			return "Текущая фаза ожидает решение по третьей карте Player. %s" % resolver_reason
		"banker_third":
			return "Текущая фаза ожидает решение по третьей карте Banker. %s" % resolver_reason
		"both_third":
			return "Текущая фаза ещё не завершена: нужны решения по обеим сторонам. %s" % resolver_reason
		"choose_winner":
			return "Раздача завершена, дальше нужно определить победителя. %s" % resolver_reason
		_:
			return "Используется текущее состояние игры без пересчёта правил. %s" % resolver_reason
