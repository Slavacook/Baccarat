# res://scripts/ThirdCardActionExecutor.gd
# Исполнитель действий для третьих карт
# Определяет какие действия нужно выполнить на основе результатов валидации

class_name ThirdCardActionExecutor
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_action_instructions(validation_result: Dictionary) -> Dictionary:
	"""Получить инструкции для выполнения действий на основе результата валидации
	
	Args:
		validation_result: Результат валидации от ThirdCardActionValidator
		
	Returns:
		Dictionary с полями:
		- should_reset_player: bool - нужно ли сбросить выбор игрока
		- should_reset_banker: bool - нужно ли сбросить выбор банкира
		- should_show_error: bool - нужно ли показать ошибку
		- error_type: String - тип ошибки (если есть)
		- error_message: String - сообщение об ошибке (если есть)
		- action: String - действие для выполнения ("draw_both", "draw_player", "draw_banker", "wait_banker", "complete")
		- needs_banker_decision: bool - нужно ли ждать решения банкира
	"""
	var instructions = {
		"should_reset_player": false,
		"should_reset_banker": false,
		"should_show_error": false,
		"error_type": "",
		"error_message": "",
		"action": "complete",
		"needs_banker_decision": false
	}
	
	# Если валидация не прошла - возвращаем ошибку
	if not validation_result.get("is_valid", false):
		instructions["should_show_error"] = true
		instructions["error_type"] = validation_result.get("error_type", "")
		instructions["error_message"] = validation_result.get("error_message", "")
		instructions["should_reset_player"] = validation_result.get("should_reset_player", false)
		instructions["should_reset_banker"] = validation_result.get("should_reset_banker", false)
		return instructions
	
	# Валидация прошла - определяем действие
	instructions["action"] = validation_result.get("action", "complete")
	instructions["needs_banker_decision"] = validation_result.get("needs_banker_decision", false)
	instructions["should_reset_player"] = validation_result.get("should_reset_player", false)
	instructions["should_reset_banker"] = validation_result.get("should_reset_banker", false)
	
	return instructions

func get_banker_action_instructions(validation_result: Dictionary) -> Dictionary:
	"""Получить инструкции для выполнения действий банкира на основе результата валидации
	
	Args:
		validation_result: Результат валидации от ThirdCardActionValidator
		
	Returns:
		Dictionary с полями:
		- should_reset_banker: bool - нужно ли сбросить выбор банкира
		- should_show_error: bool - нужно ли показать ошибку
		- error_type: String - тип ошибки (если есть)
		- error_message: String - сообщение об ошибке (если есть)
		- action: String - действие для выполнения ("draw_banker", "complete")
	"""
	var instructions = {
		"should_reset_banker": false,
		"should_show_error": false,
		"error_type": "",
		"error_message": "",
		"action": "complete"
	}
	
	# Если валидация не прошла - возвращаем ошибку
	if not validation_result.get("is_valid", false):
		instructions["should_show_error"] = true
		instructions["error_type"] = validation_result.get("error_type", "")
		instructions["error_message"] = validation_result.get("error_message", "")
		instructions["should_reset_banker"] = validation_result.get("should_reset_banker", false)
		return instructions
	
	# Валидация прошла - определяем действие
	instructions["action"] = validation_result.get("action", "complete")
	instructions["should_reset_banker"] = validation_result.get("should_reset_banker", false)
	
	return instructions

