# res://scripts/PayoutQueueManager.gd
# Менеджер очереди выплат для ручного режима
# Отслеживает все ставки (выигравшие и проигравшие) и их статус оплаты

class_name PayoutQueueManager
extends RefCounted

# Список всех ставок в раунде (использует единый класс Bet)
var bets: Array[Bet] = []

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ СТАВКАМИ
# ═══════════════════════════════════════════════════════════════════════════

func add_bet(bet_type: String, stake: float, payout: float, won: bool, p_score: int = 0, b_score: int = 0, position_index: int = 0) -> void:
	"""Добавить ставку в менеджер"""
	var bet = Bet.new(bet_type, stake, payout, won, position_index, p_score, b_score)
	bets.append(bet)
	var status = "✅ ВЫИГРЫШ" if won else "❌ ПРОИГРЫШ"
	DebugLogger.log("💰 PayoutQueueManager: добавлена ставка %s[%d] (stake=%.1f, payout=%.1f, %s)" % [bet_type, position_index, stake, payout, status])


func get_bet_by_type(bet_type: String) -> Bet:
	"""Получить первую ставку по типу (для обратной совместимости)"""
	for bet in bets:
		if bet.get_bet_type() == bet_type:
			return bet
	return null


func get_bet_by_id(bet_type: String, position_index: int) -> Bet:
	"""Получить ставку по типу и индексу позиции"""
	for bet in bets:
		if bet.get_bet_type() == bet_type and bet.get_position_index() == position_index:
			return bet
	return null


func get_bets_by_type(bet_type: String) -> Array[Bet]:
	"""Получить все ставки определённого типа"""
	var result: Array[Bet] = []
	for bet in bets:
		if bet.get_bet_type() == bet_type:
			result.append(bet)
	return result


func mark_as_paid(bet_type: String, position_index: int = -1) -> bool:
	"""Отметить ставку как оплаченную"""
	var bet: Bet
	if position_index < 0:
		# Для обратной совместимости - ищем первую
		bet = get_bet_by_type(bet_type)
	else:
		bet = get_bet_by_id(bet_type, position_index)
	
	if bet and bet.is_won() and not bet.is_paid():
		bet.mark_as_paid()
		DebugLogger.log("💰 PayoutQueueManager: ставка %s[%d] отмечена как оплаченная" % [bet_type, bet.get_position_index()])
		return true
	return false


func mark_as_collected(bet_type: String, position_index: int = -1) -> bool:
	"""Отметить проигрышную ставку как собранную"""
	var bet: Bet
	if position_index < 0:
		bet = get_bet_by_type(bet_type)
	else:
		bet = get_bet_by_id(bet_type, position_index)
	
	if bet and not bet.is_won() and not bet.is_collected():
		bet.mark_as_collected()
		DebugLogger.log("💰 PayoutQueueManager: ставка %s[%d] отмечена как собранная" % [bet_type, bet.get_position_index()])
		return true
	return false


func has_any_payouts() -> bool:
	"""Проверить, есть ли хотя бы одна ставка в очереди"""
	return bets.size() > 0


func has_unpaid_winnings() -> bool:
	"""Проверить, есть ли неоплаченные выигравшие ставки"""
	for bet in bets:
		if bet.is_won() and not bet.is_paid():
			return true
	return false


func has_any_winning_bets() -> bool:
	"""Проверить, были ли вообще выигравшие ставки (оплаченные или нет)"""
	for bet in bets:
		if bet.is_won():
			return true
	return false


func has_uncollected_losing() -> bool:
	"""Проверить, есть ли несобранные проигравшие ставки"""
	for bet in bets:
		if not bet.is_won() and not bet.is_collected():
			return true
	return false


func get_unpaid_count() -> int:
	"""Количество неоплаченных выигравших ставок"""
	var count = 0
	for bet in bets:
		if bet.is_won() and not bet.is_paid():
			count += 1
	return count


func get_uncollected_count() -> int:
	"""Количество несобранных проигравших ставок"""
	var count = 0
	for bet in bets:
		if not bet.is_won() and not bet.is_collected():
			count += 1
	return count


func get_winning_bets() -> Array[Bet]:
	"""Получить все выигравшие ставки"""
	var winning: Array[Bet] = []
	for bet in bets:
		if bet.is_won():
			winning.append(bet)
	return winning


func get_losing_bets() -> Array[Bet]:
	"""Получить все проигравшие ставки"""
	var losing: Array[Bet] = []
	for bet in bets:
		if not bet.is_won():
			losing.append(bet)
	return losing


func get_unpaid_winning_bets() -> Array[Bet]:
	"""Получить неоплаченные выигравшие ставки"""
	var result: Array[Bet] = []
	for bet in bets:
		if bet.is_won() and not bet.is_paid():
			result.append(bet)
	return result


func get_uncollected_losing_bets() -> Array[Bet]:
	"""Получить несобранные проигравшие ставки"""
	var result: Array[Bet] = []
	for bet in bets:
		if not bet.is_won() and not bet.is_collected():
			result.append(bet)
	return result


func get_all_bets() -> Array[Bet]:
	"""Получить все ставки (выигравшие и проигравшие)"""
	return bets


func clear() -> void:
	"""Очистить все ставки"""
	bets.clear()
	DebugLogger.log("🗑️  PayoutQueueManager: очищено")


func print_status() -> void:
	"""Вывести статус всех ставок"""
	DebugLogger.log("═══ PayoutQueueManager Status ═══")
	DebugLogger.log("Всего ставок: %d" % bets.size())
	for bet in bets:
		var status = ""
		if not bet.is_won():
			if bet.is_collected():
				status = "🗑️ СОБРАНО"
			else:
				status = "❌ ПРОИГРЫШ"
		elif bet.is_paid():
			status = "✅ ОПЛАЧЕНО"
		else:
			status = "💰 К ОПЛАТЕ"
		DebugLogger.log("  %s[%d]: %.1f → %.1f (%s)" % [bet.get_bet_type(), bet.get_position_index(), bet.get_stake(), bet.get_payout(), status])
	DebugLogger.log("Неоплаченных выигрышей: %d" % get_unpaid_count())
	DebugLogger.log("Несобранных проигрышей: %d" % get_uncollected_count())
	DebugLogger.log("═════════════════════════════════")
