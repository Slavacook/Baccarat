# res://scripts/WinnerActionExecutor.gd
# Исполнитель действий для выбора победителя
# Определяет какие действия нужно выполнить на основе результатов валидации

class_name WinnerActionExecutor
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_action_instructions(validation_result: Dictionary, actual_winner: String) -> Dictionary:
	"""Получить инструкции для выполнения действий на основе результата валидации выбора победителя
	
	Args:
		validation_result: Результат валидации от WinnerSelectionValidator
		actual_winner: Фактический победитель (уже определён)
		
	Returns:
		Dictionary с полями:
		- should_show_error: bool - нужно ли показать ошибку
		- error_type: String - тип ошибки (если есть)
		- error_message: String - сообщение об ошибке (если есть)
		- error_params: Array - параметры для сообщения об ошибке (если есть)
		- should_reset_winner_selection: bool - нужно ли сбросить выбор маркера
		- should_emit_correct: bool - нужно ли эмитировать action_correct
		- should_check_heart_bet_triggers: bool - нужно ли проверить триггеры Heart Bet
		- should_check_chance_card_triggers: bool - нужно ли проверить триггеры карт шанса
		- should_skip_payouts: bool - нужно ли пропустить выплаты (для Heart Bet)
		- should_update_button_state: bool - нужно ли обновить состояние кнопки
		- button_state: String - новое состояние кнопки (если нужно обновить)
	"""
	var instructions = {
		"should_show_error": false,
		"error_type": "",
		"error_message": "",
		"error_params": [],
		"should_reset_winner_selection": false,
		"should_emit_correct": false,
		"should_check_heart_bet_triggers": false,
		"should_check_chance_card_triggers": false,
		"should_skip_payouts": false,
		"should_update_button_state": false,
		"button_state": ""
	}
	
	# Если валидация не прошла - возвращаем ошибку
	if not validation_result.get("is_valid", false):
		instructions["should_show_error"] = true
		instructions["error_type"] = validation_result.get("error_type", "")
		instructions["error_message"] = validation_result.get("error_message", "")
		instructions["error_params"] = validation_result.get("error_message_params", [])
		instructions["should_reset_winner_selection"] = true
		return instructions
	
	# Валидация прошла - определяем действия
	instructions["should_emit_correct"] = true
	instructions["should_update_button_state"] = true
	instructions["button_state"] = "complete"
	
	# Проверка триггеров определяется в GamePhaseManager на основе режима игры
	# Здесь мы только указываем, что нужно проверить
	instructions["should_check_heart_bet_triggers"] = true
	instructions["should_check_chance_card_triggers"] = true
	
	return instructions

