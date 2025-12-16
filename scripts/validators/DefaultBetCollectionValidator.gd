# res://scripts/validators/DefaultBetCollectionValidator.gd
# Реализация валидатора по умолчанию (текущая логика)
# Используется в BetCollectionPhaseManager

class_name DefaultBetCollectionValidator
extends IBetCollectionValidator

var bet_collection_manager: BetCollectionPhaseManager

func _init(manager: BetCollectionPhaseManager):
	bet_collection_manager = manager

func validate_collect(bet: PayoutQueueManager.BetData, bet_type: String, position_index: int, _context: Dictionary) -> Dictionary:
	"""Валидация попытки собрать ставку (делегирует к BetCollectionPhaseManager)
	
	Args:
		bet: Данные ставки
		bet_type: Тип ставки
		position_index: Индекс позиции
		_context: Контекст валидации (не используется в реализации по умолчанию)
	"""
	if not bet_collection_manager:
		return {"can_proceed": false, "error_type": "no_manager", "error_message": "Менеджер не установлен", "action": "none"}
	
	# Используем внутренний метод валидации
	return bet_collection_manager._validate_collect_internal(bet, bet_type, position_index)

func validate_pay(bet: PayoutQueueManager.BetData, bet_type: String, position_index: int, _context: Dictionary) -> Dictionary:
	"""Валидация попытки оплатить ставку (делегирует к BetCollectionPhaseManager)
	
	Args:
		bet: Данные ставки
		bet_type: Тип ставки
		position_index: Индекс позиции
		_context: Контекст валидации (не используется в реализации по умолчанию)
	"""
	if not bet_collection_manager:
		return {"can_proceed": false, "error_type": "no_manager", "error_message": "Менеджер не установлен", "action": "none"}
	
	# Используем внутренний метод валидации
	return bet_collection_manager._validate_pay_internal(bet, bet_type, position_index)
