# res://scripts/ThirdCardActionValidator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАТОР ДЕЙСТВИЙ ТРЕТЬИХ КАРТ
# Чистая логика валидации правил баккара для третьих карт
# Не зависит от UI, EventBus и других внешних систем
# ═══════════════════════════════════════════════════════════════════════════

class_name ThirdCardActionValidator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# РЕЗУЛЬТАТ ВАЛИДАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

# Структура результата валидации:
# {
#   "is_valid": bool,                    # Валидна ли комбинация
#   "error_type": String,                # Тип ошибки ("natural_draw", "player_wrong", etc.)
#   "error_message": String,             # Ключ локализации для сообщения
#   "action": String,                    # Действие: "draw_player", "draw_banker", "draw_both", "complete", "wait_banker"
#   "should_reset_player": bool,         # Нужно ли сбросить выбор игрока
#   "should_reset_banker": bool          # Нужно ли сбросить выбор банкира
# }

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНАЯ ВАЛИДАЦИЯ ТРЕТЬИХ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func validate_third_card_action(
	player_score: int,
	banker_score: int,
	player_selected: bool,
	banker_selected: bool,
	has_player_third: bool,
	player_third_card: Card
) -> Dictionary:
	"""Валидация действия с третьими картами
	
	Args:
		player_score: Очки игрока по первым 2 картам
		banker_score: Очки банкира по первым 2 картам
		player_selected: Выбрана ли третья карта игрока
		banker_selected: Выбрана ли третья карта банкира
		has_player_third: Есть ли уже третья карта у игрока
		player_third_card: Третья карта игрока (если есть)
		
	Returns:
		Dictionary с результатом валидации
	"""
	# Проверка натуральных или особых комбинаций (8-9, 6v6, 7v7)
	if BaccaratRules.has_natural_or_no_third(player_score, banker_score):
		return _validate_natural_case(player_selected, banker_selected)
	
	var player_draw: bool = player_score <= 5
	var banker_draw_always: bool = banker_score <= 2
	
	# State 2: Карта каждому (банкир 0-2, игрок 0-5)
	if banker_draw_always and player_draw:
		return _validate_card_to_each(player_selected, banker_selected)
	
	# State 3.1: Карта игроку (банкир 7 стоит)
	if player_draw and banker_score == 7:
		return _validate_card_to_player_with_banker_7(player_score, banker_score, player_selected, banker_selected)
	
	# State 3.2: Карта игроку (банкир 3-6 решает потом)
	if player_draw and banker_score >= 3 and banker_score <= 6:
		return _validate_card_to_player_with_banker_3_6(player_score, player_selected, banker_selected)
	
	# State 4: Карта банкиру (игрок 6-7 стоит)
	var banker_draw: bool = _should_banker_draw(banker_score, has_player_third, player_third_card)
	if not player_draw and banker_draw:
		return _validate_card_to_banker_only(player_score, banker_score, player_selected, banker_selected)
	
	# Fallback: оба стоят
	return _validate_both_stand(player_score, banker_score, player_selected, banker_selected)

# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ БАНКИРА ПОСЛЕ ИГРОКА
# ═══════════════════════════════════════════════════════════════════════════

func validate_banker_after_player(
	banker_score: int,
	banker_selected: bool,
	has_player_third: bool,
	player_third_card: Card
) -> Dictionary:
	"""Валидация третьей карты банкира после того как игрок взял карту
	
	Args:
		banker_score: Очки банкира по первым 2 картам
		banker_selected: Выбрана ли третья карта банкира
		has_player_third: Есть ли третья карта у игрока
		player_third_card: Третья карта игрока
		
	Returns:
		Dictionary с результатом валидации
	"""
	var banker_draw: bool = _should_banker_draw(banker_score, has_player_third, player_third_card)
	
	if banker_draw:
		if not banker_selected:
			return _error_result("banker_wrong", "ERR_BANKER_MUST_DRAW", true, false, "wait_banker")
		return _success_result("draw_banker", false, false)
	else:
		if banker_selected:
			return _error_result("banker_wrong", "ERR_BANKER_NO_DRAW", false, true, "complete")
		return _success_result("complete", false, false)

# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ КОНКРЕТНЫХ СЦЕНАРИЕВ
# ═══════════════════════════════════════════════════════════════════════════

func _validate_natural_case(player_selected: bool, banker_selected: bool) -> Dictionary:
	"""Валидация натуральной комбинации (8-9) или особых (6v6, 7v7)"""
	if player_selected or banker_selected:
		return _error_result("natural_draw", "ERR_NATURAL_NO_DRAW", true, true, "complete")
	return _success_result("complete", false, false)

func _validate_card_to_each(player_selected: bool, banker_selected: bool) -> Dictionary:
	"""Валидация: карта каждому (банкир 0-2, игрок 0-5)"""
	if not player_selected or not banker_selected:
		return _error_result("both_wrong", "BOTH_CARDS_NEEDED", true, true, "wait_both")
	return _success_result("draw_both", false, false)

func _validate_card_to_player_with_banker_7(
	player_score: int,
	banker_score: int,
	player_selected: bool,
	banker_selected: bool
) -> Dictionary:
	"""Валидация: карта только игроку (банкир 7 стоит)"""
	# Проверка: игрок должен взять карту
	if not player_selected:
		return _error_result("player_wrong", "ERR_PLAYER_MUST_DRAW", false, false, "wait_player")
	
	# Проверка: банкир НЕ должен брать карту
	if banker_selected:
		return _error_result("banker_wrong", "ERR_BANKER_NO_DRAW", false, true, "wait_player")
	
	return _success_result("draw_player", false, false)

func _validate_card_to_player_with_banker_3_6(
	player_score: int,
	player_selected: bool,
	banker_selected: bool
) -> Dictionary:
	"""Валидация: карта игроку, банкир решает потом (банкир 3-6)"""
	# Проверка: игрок должен взять карту
	if not player_selected:
		return _error_result("player_wrong", "ERR_PLAYER_MUST_DRAW", false, false, "wait_player")
	
	# Проверка: банкир пока НЕ должен брать (решение потом)
	if banker_selected:
		return _error_result("banker_wrong", "BANKER_NO_CARD_YET", false, true, "wait_player")
	
	# Возвращаем успех с флагом что нужно ждать решения банкира
	var result = _success_result("draw_player", false, false)
	result["needs_banker_decision"] = true  # После раздачи игроку нужно ждать решения банкира
	return result

func _validate_card_to_banker_only(
	player_score: int,
	banker_score: int,
	player_selected: bool,
	banker_selected: bool
) -> Dictionary:
	"""Валидация: карта только банкиру (игрок 6-7 стоит)"""
	# Проверка: банкир должен взять карту
	if not banker_selected:
		return _error_result("banker_wrong", "ERR_BANKER_MUST_DRAW", false, false, "wait_banker")
	
	# Проверка: игрок НЕ должен брать карту
	if player_selected:
		return _error_result("player_wrong", "ERR_PLAYER_NO_DRAW", true, false, "wait_banker")
	
	return _success_result("draw_banker", false, false)

func _validate_both_stand(
	player_score: int,
	banker_score: int,
	player_selected: bool,
	banker_selected: bool
) -> Dictionary:
	"""Валидация: оба стоят (не должны брать карты)"""
	if player_selected or banker_selected:
		# Ошибка: пытаются заказать карты когда оба должны стоять
		var should_reset_player = player_selected
		var should_reset_banker = banker_selected
		var error_type = "player_wrong" if player_selected else "banker_wrong"
		var error_message = "ERR_PLAYER_NO_DRAW" if player_selected else "ERR_BANKER_NO_DRAW"
		var score = player_score if player_selected else banker_score
		return _error_result(error_type, error_message, should_reset_player, should_reset_banker, "complete")
	
	return _success_result("complete", false, false)

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _should_banker_draw(banker_score: int, has_player_third: bool, player_third_card: Card) -> bool:
	"""Проверить, должен ли банкир взять третью карту
	
	Args:
		banker_score: Очки банкира по первым 2 картам
		has_player_third: Есть ли третья карта у игрока
		player_third_card: Третья карта игрока (если есть)
		
	Returns:
		true если банкир должен взять карту
	"""
	if banker_score <= 2:
		return true
	if banker_score >= 7:
		return false
	if not has_player_third:
		return banker_score <= 5
	
	var p3_val = player_third_card.get_point()
	match banker_score:
		3: return p3_val != 8
		4: return p3_val in [2, 3, 4, 5, 6, 7]
		5: return p3_val in [4, 5, 6, 7]
		6: return p3_val in [6, 7]
	return false

func _success_result(action: String, reset_player: bool, reset_banker: bool) -> Dictionary:
	"""Создать успешный результат валидации"""
	return {
		"is_valid": true,
		"error_type": "",
		"error_message": "",
		"action": action,
		"should_reset_player": reset_player,
		"should_reset_banker": reset_banker
	}

func _error_result(error_type: String, error_message: String, reset_player: bool, reset_banker: bool, action: String) -> Dictionary:
	"""Создать результат с ошибкой"""
	return {
		"is_valid": false,
		"error_type": error_type,
		"error_message": error_message,
		"action": action,
		"should_reset_player": reset_player,
		"should_reset_banker": reset_banker
	}

