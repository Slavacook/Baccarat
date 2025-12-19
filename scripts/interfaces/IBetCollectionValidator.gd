# res://scripts/interfaces/IBetCollectionValidator.gd
# Интерфейс для валидации операций сбора/оплаты ставок
# Позволяет легко расширять логику валидации через Strategy Pattern

class_name IBetCollectionValidator
extends RefCounted

## Валидация попытки собрать ставку
## Returns: Dictionary с полями can_proceed, error_type, error_message, action
func validate_collect(_bet, _bet_type: String, _position_index: int, _context: Dictionary) -> Dictionary:
	"""Абстрактный метод - должен быть переопределен в наследниках
	
	Args:
		_bet: Данные ставки (не используется в базовой реализации)
		_bet_type: Тип ставки (не используется в базовой реализации)
		_position_index: Индекс позиции (не используется в базовой реализации)
		_context: Контекст валидации (не используется в базовой реализации)
	"""
	push_error("IBetCollectionValidator.validate_collect() должен быть переопределен")
	return {"can_proceed": false, "error_type": "not_implemented", "error_message": "", "action": "none"}

## Валидация попытки оплатить ставку
## Returns: Dictionary с полями can_proceed, error_type, error_message, action
func validate_pay(_bet, _bet_type: String, _position_index: int, _context: Dictionary) -> Dictionary:
	"""Абстрактный метод - должен быть переопределен в наследниках
	
	Args:
		_bet: Данные ставки (не используется в базовой реализации)
		_bet_type: Тип ставки (не используется в базовой реализации)
		_position_index: Индекс позиции (не используется в базовой реализации)
		_context: Контекст валидации (не используется в базовой реализации)
	"""
	push_error("IBetCollectionValidator.validate_pay() должен быть переопределен")
	return {"can_proceed": false, "error_type": "not_implemented", "error_message": "", "action": "none"}
