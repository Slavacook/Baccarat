# res://scripts/PayoutQueueManager.gd
# Менеджер очереди выплат для ручного режима
# Отслеживает все ставки (выигравшие и проигравшие) и их статус оплаты

class_name PayoutQueueManager
extends RefCounted

# Структура данных для ставки
class BetData:
	var bet_type: String  # "Player", "Banker", "Tie", "PairPlayer", "PairBanker"
	var stake: float
	var payout: float
	var won: bool  # Выиграла ли ставка
	var is_paid: bool  # Оплачена ли выплата (только для выигравших)
	var player_score: int
	var banker_score: int

	func _init(type: String, stake_amt: float, payout_amt: float, did_win: bool, p_score: int = 0, b_score: int = 0):
		bet_type = type
		stake = stake_amt
		payout = payout_amt
		won = did_win
		is_paid = false
		player_score = p_score
		banker_score = b_score

# Список всех ставок в раунде
var bets: Array[BetData] = []

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ СТАВКАМИ
# ═══════════════════════════════════════════════════════════════════════════

func add_bet(bet_type: String, stake: float, payout: float, won: bool, p_score: int = 0, b_score: int = 0) -> void:
	"""Добавить ставку в менеджер"""
	var bet = BetData.new(bet_type, stake, payout, won, p_score, b_score)
	bets.append(bet)
	var status = "✅ ВЫИГРЫШ" if won else "❌ ПРОИГРЫШ"
	print("💰 PayoutQueueManager: добавлена ставка %s (stake=%.1f, payout=%.1f, %s)" % [bet_type, stake, payout, status])


func get_bet_by_type(bet_type: String) -> BetData:
	"""Получить ставку по типу"""
	for bet in bets:
		if bet.bet_type == bet_type:
			return bet
	return null


func mark_as_paid(bet_type: String) -> bool:
	"""Отметить ставку как оплаченную"""
	var bet = get_bet_by_type(bet_type)
	if bet and bet.won and not bet.is_paid:
		bet.is_paid = true
		print("💰 PayoutQueueManager: ставка %s отмечена как оплаченная" % bet_type)
		return true
	return false


func has_any_payouts() -> bool:
	"""Проверить, есть ли хотя бы одна ставка в очереди"""
	return bets.size() > 0


func has_unpaid_winnings() -> bool:
	"""Проверить, есть ли неоплаченные выигравшие ставки"""
	for bet in bets:
		if bet.won and not bet.is_paid:
			return true
	return false


func has_any_winning_bets() -> bool:
	"""Проверить, были ли вообще выигравшие ставки (оплаченные или нет)"""
	for bet in bets:
		if bet.won:
			return true
	return false


func get_unpaid_count() -> int:
	"""Количество неоплаченных выигравших ставок"""
	var count = 0
	for bet in bets:
		if bet.won and not bet.is_paid:
			count += 1
	return count


func get_winning_bets() -> Array[BetData]:
	"""Получить все выигравшие ставки"""
	var winning: Array[BetData] = []
	for bet in bets:
		if bet.won:
			winning.append(bet)
	return winning


func get_all_bets() -> Array[BetData]:
	"""Получить все ставки (выигравшие и проигравшие)"""
	return bets


func clear() -> void:
	"""Очистить все ставки"""
	bets.clear()
	print("🗑️  PayoutQueueManager: очищено")


func print_status() -> void:
	"""Вывести статус всех ставок"""
	print("═══ PayoutQueueManager Status ═══")
	print("Всего ставок: %d" % bets.size())
	for bet in bets:
		var status = ""
		if not bet.won:
			status = "❌ ПРОИГРЫШ"
		elif bet.is_paid:
			status = "✅ ОПЛАЧЕНО"
		else:
			status = "💰 К ОПЛАТЕ"
		print("  %s: %.1f → %.1f (%s)" % [bet.bet_type, bet.stake, bet.payout, status])
	print("Неоплаченных: %d" % get_unpaid_count())
	print("═════════════════════════════════")
