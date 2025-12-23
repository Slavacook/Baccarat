# res://scripts/ValidationErrorFormatter.gd
# ═══════════════════════════════════════════════════════════════════════════
# ФОРМАТТЕР ОШИБОК ВАЛИДАЦИИ
# Форматирует сообщения об ошибках валидации для отображения в UI
# Чистая логика без зависимостей от UI и EventBus
# ═══════════════════════════════════════════════════════════════════════════

class_name ValidationErrorFormatter
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНОЙ МЕТОД
# ═══════════════════════════════════════════════════════════════════════════

func format_third_card_error(
	error_message: String,
	player_score: int = -1,
	banker_score: int = -1
) -> String:
	"""Форматировать сообщение об ошибке валидации третьих карт
	
	Args:
		error_message: Ключ локализации или готовое сообщение
		player_score: Очки игрока (для параметров локализации)
		banker_score: Очки банкира (для параметров локализации)
		
	Returns:
		Отформатированное сообщение об ошибке
	"""
	# Ошибки с параметрами очков игрока
	if error_message == "ERR_PLAYER_NO_DRAW" or error_message == "ERR_PLAYER_MUST_DRAW":
		if player_score >= 0:
			return Localization.t(error_message, [player_score])
		return Localization.t(error_message)
	
	# Ошибки с параметрами очков банкира
	if error_message == "ERR_BANKER_NO_DRAW" or error_message == "ERR_BANKER_MUST_DRAW":
		if banker_score >= 0:
			return Localization.t(error_message, [banker_score])
		return Localization.t(error_message)
	
	# Остальные ошибки - просто локализуем
	return Localization.t(error_message)

func format_winner_selection_error(
	error_message: String,
	error_params: Array = []
) -> String:
	"""Форматировать сообщение об ошибке выбора победителя
	
	Args:
		error_message: Ключ локализации или готовое сообщение
		error_params: Параметры для локализации
		
	Returns:
		Отформатированное сообщение об ошибке
	"""
	# ERR_WRONG_WINNER с параметрами
	if error_message == "ERR_WRONG_WINNER" and not error_params.is_empty():
		return Localization.t(error_message, error_params)
	
	# Готовое сообщение (например, для Tie)
	if not error_message.is_empty() and not error_message.begins_with("ERR_"):
		return error_message
	
	# Остальные ошибки - просто локализуем
	return Localization.t(error_message)

