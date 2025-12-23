# res://scripts/WinnerSelectionValidator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАТОР ВЫБОРА ПОБЕДИТЕЛЯ
# Чистая логика валидации выбора победителя
# Не зависит от UI, EventBus и других внешних систем
# ═══════════════════════════════════════════════════════════════════════════

class_name WinnerSelectionValidator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# РЕЗУЛЬТАТ ВАЛИДАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

# Структура результата валидации:
# {
#   "is_valid": bool,                    # Валиден ли выбор
#   "actual_winner": String,             # Фактический победитель ("Player"/"Banker"/"Tie")
#   "error_type": String,                # Тип ошибки ("winner_wrong", "")
#   "error_message": String,             # Ключ локализации для сообщения
#   "error_message_params": Array        # Параметры для локализации (если нужны)
# }

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНАЯ ВАЛИДАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func validate_winner_selection(
	selected_winner: String,
	player_hand: Array,
	banker_hand: Array
) -> Dictionary:
	"""Валидация выбора победителя
	
	Args:
		selected_winner: Выбранный победитель ("Player"/"Banker"/"Tie" или "")
		player_hand: Рука игрока (Array[Card])
		banker_hand: Рука банкира (Array[Card])
		
	Returns:
		Dictionary с результатом валидации
	"""
	# Не выбран ни один маркер?
	if selected_winner.is_empty():
		return _no_selection_result()
	
	# Определяем фактического победителя
	# Создаём типизированные массивы для BaccaratRules.get_winner
	var player_hand_typed: Array[Card] = []
	var banker_hand_typed: Array[Card] = []
	for card in player_hand:
		player_hand_typed.append(card as Card)
	for card in banker_hand:
		banker_hand_typed.append(card as Card)
	var actual_winner = BaccaratRules.get_winner(player_hand_typed, banker_hand_typed)
	
	# Сравниваем выбранного и фактического победителя
	if selected_winner != actual_winner:
		return _incorrect_selection_result(actual_winner)
	
	# Правильный выбор!
	return _correct_selection_result(actual_winner)

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _no_selection_result() -> Dictionary:
	"""Результат когда победитель не выбран"""
	return {
		"is_valid": false,
		"actual_winner": "",
		"error_type": "",
		"error_message": "",
		"error_message_params": [],
		"needs_selection": true  # Флаг что нужно выбрать победителя
	}

func _incorrect_selection_result(actual_winner: String) -> Dictionary:
	"""Результат при неправильном выборе победителя"""
	var error_message = ""
	var error_params: Array = []
	
	if actual_winner == "Tie":
		error_message = "Ошибка! Неправильный выбор. Игалите"
	else:
		error_message = "ERR_WRONG_WINNER"
		error_params = [actual_winner]
	
	return {
		"is_valid": false,
		"actual_winner": actual_winner,
		"error_type": "winner_wrong",
		"error_message": error_message,
		"error_message_params": error_params,
		"needs_selection": false
	}

func _correct_selection_result(actual_winner: String) -> Dictionary:
	"""Результат при правильном выборе победителя"""
	return {
		"is_valid": true,
		"actual_winner": actual_winner,
		"error_type": "",
		"error_message": "",
		"error_message_params": [],
		"needs_selection": false
	}
