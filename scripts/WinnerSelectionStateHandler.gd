# res://scripts/WinnerSelectionStateHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК СОСТОЯНИЯ ВЫБОРА ПОБЕДИТЕЛЯ
# Координирует обработку состояния CHOOSE_WINNER
# ═══════════════════════════════════════════════════════════════════════════

class_name WinnerSelectionStateHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var hand_manager: HandManager = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(hand_manager_ref: HandManager = null):
	hand_manager = hand_manager_ref

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func get_state_handling_instructions(
	player_third_selected: bool,
	banker_third_selected: bool,
	button_state: String,
	can_complete_round: bool
) -> Dictionary:
	"""Получить инструкции для обработки состояния CHOOSE_WINNER
	
	Args:
		player_third_selected: Выбрана ли третья карта игрока
		banker_third_selected: Выбрана ли третья карта банкира
		button_state: Текущее состояние кнопки действия
		can_complete_round: Можно ли завершить раунд
		
	Returns:
		Dictionary с инструкциями:
		{
			"action": String,  # "handle_invalid_selection", "validate_winner", "complete_round", "none"
			"is_natural": bool,  # Для обработки невалидного выбора
			"error_message_key": String  # Ключ локализации ошибки
		}
	"""
	# GUARD 1: Ошибочная попытка заказать карты в финале
	if player_third_selected or banker_third_selected:
		var is_natural = _check_is_natural()
		var error_message_key = "ERR_NATURAL_NO_DRAW" if is_natural else "INFO_ALL_OPENED_CHOOSE_WINNER"
		return {
			"action": "handle_invalid_selection",
			"is_natural": is_natural,
			"error_message_key": error_message_key
		}
	
	# GUARD 2: Первое нажатие - выбор победителя
	if button_state != "complete":
		return {
			"action": "validate_winner",
			"is_natural": false,
			"error_message_key": ""
		}
	
	# GUARD 3: Проверка завершения раунда (неоплаченные ставки)
	if not can_complete_round:
		return {
			"action": "none",  # Сообщение об ошибке показано в _can_complete_round()
			"is_natural": false,
			"error_message_key": ""
		}
	
	# Все проверки пройдены → завершаем раунд
	return {
		"action": "complete_round",
		"is_natural": false,
		"error_message_key": ""
	}

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _check_is_natural() -> bool:
	"""Проверить, является ли раздача натуральной (8 или 9 в первых двух картах)"""
	if not hand_manager:
		return false
	
	var player_first_two = hand_manager.get_player_initial_score()
	var banker_first_two = hand_manager.get_banker_initial_score()
	return player_first_two >= 8 or banker_first_two >= 8
