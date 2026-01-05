# res://scripts/utils/StateConsistencyChecker.gd
# Проверка согласованности состояния ставок
# 
# Отвечает за:
# - Проверку согласованности состояния собранных ставок
# - Проверку согласованности состояния оплаченных ставок
# - Валидацию всего состояния (для отладки)

class_name StateConsistencyChecker

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func check_state_consistency(bet, bet_id: String, collected_bets_by_id: Dictionary) -> bool:
	"""Проверить согласованность состояния для собранной ставки
	
	Args:
		bet: Объект ставки
		bet_id: Идентификатор ставки (для кэша)
		collected_bets_by_id: Словарь собранных ставок (для обновления)
	
	Returns:
		true если состояние согласовано, false если есть рассинхронизация
	"""
	if not bet:
		return false
	
	var in_cache = collected_bets_by_id.has(bet_id)
	var in_bet = bet.is_collected()
	
	if in_cache != in_bet:
		# Рассинхронизация обнаружена
		DebugLogger.log_warning("Рассинхронизация для %s: кэш=%s, bet.is_collected=%s" % [bet_id, in_cache, in_bet])
		# Автоматическое исправление
		if in_bet:
			collected_bets_by_id[bet_id] = true
		else:
			collected_bets_by_id.erase(bet_id)
		return false
	
	return true

func check_payment_state_consistency(bet) -> bool:
	"""Проверить согласованность состояния для оплаченной ставки
	
	Args:
		bet: Объект ставки
	
	Returns:
		true если состояние согласовано
	"""
	if not bet:
		return false
	
	# Для оплаченных ставок проверяем что они действительно выиграли
	if bet.is_paid() and not bet.is_won():
		DebugLogger.log_error("КРИТИЧЕСКАЯ ОШИБКА: Ставка %s[%d] помечена как оплаченная, но не выиграла!" % [bet.get_bet_type(), bet.get_position_index()])
		return false
	
	return true

func validate_all_state(payout_queue_manager, collected_bets_by_id: Dictionary, is_tie_push_bet: Callable) -> Dictionary:
	"""Проверить согласованность всего состояния (для отладки)
	
	Args:
		payout_queue_manager: Менеджер очереди выплат с информацией о ставках
		collected_bets_by_id: Словарь собранных ставок
		is_tie_push_bet: Функция для проверки Tie push ставок
	
	Returns:
		Dictionary с результатами проверки:
		- is_consistent: bool - согласовано ли состояние
		- issues: Array[String] - список проблем
	"""
	var issues: Array[String] = []
	
	if not payout_queue_manager:
		issues.append("payout_queue_manager не инициализирован")
		return {"is_consistent": false, "issues": issues}
	
	# Проверяем каждую ставку
	for bet in payout_queue_manager.bets:
		var bet_id = "%s_%d" % [bet.get_bet_type(), bet.get_position_index()]
		var in_cache = collected_bets_by_id.has(bet_id)
		var in_bet = bet.is_collected()
		
		# Проверка собранных ставок
		if in_cache != in_bet:
			issues.append("Рассинхронизация для %s: кэш=%s, bet.is_collected=%s" % [bet_id, in_cache, in_bet])
		
		# Проверка оплаченных ставок
		if bet.is_paid() and not bet.is_won():
			issues.append("Ставка %s помечена как оплаченная, но не выиграла" % bet_id)
		
		# Проверка Tie push ставок
		if bet.is_paid() and is_tie_push_bet.call(bet.get_bet_type()):
			issues.append("Tie push ставка %s помечена как оплаченная" % bet_id)
	
	return {
		"is_consistent": issues.is_empty(),
		"issues": issues
	}

