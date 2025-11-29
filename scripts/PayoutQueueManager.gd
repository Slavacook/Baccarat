# res://scripts/PayoutQueueManager.gd
# Менеджер очереди выплат (для множественных ставок в одном раунде)

class_name PayoutQueueManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СТРУКТУРА ДАННЫХ ДЛЯ СТАВКИ
# ═══════════════════════════════════════════════════════════════════════════

class BetData:
	var bet_type: String  # "Player", "Banker", "Tie", "PairPlayer", "PairBanker"
	var stake: float
	var payout: float
	var is_paid: bool = false
	var won: bool = false  # Выиграла ли ставка

	func _init(type: String, stake_amount: float, payout_amount: float, did_win: bool = false):
		bet_type = type
		stake = stake_amount
		payout = payout_amount
		won = did_win

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Массив всех ставок текущего раунда
var bets: Array[BetData] = []

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ОЧЕРЕДЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func add_bet(bet_type: String, stake: float, payout: float, won: bool = false) -> void:
	"""Добавить ставку в очередь"""
	var bet = BetData.new(bet_type, stake, payout, won)
	bets.append(bet)
	print("💰 PayoutQueue: добавлена ставка %s (%.2f → %.2f, выиграла=%s)" % [bet_type, stake, payout, won])


func mark_as_paid(bet_type: String) -> bool:
	"""Отметить ставку как оплаченную. Возвращает true если ставка найдена"""
	for bet in bets:
		if bet.bet_type == bet_type and not bet.is_paid:
			bet.is_paid = true
			print("✅ PayoutQueue: ставка %s оплачена" % bet_type)
			return true

	push_warning("PayoutQueue: ставка %s не найдена или уже оплачена" % bet_type)
	return false


func get_unpaid_bets() -> Array[BetData]:
	"""Получить список неоплаченных ставок"""
	var unpaid: Array[BetData] = []
	for bet in bets:
		if not bet.is_paid:
			unpaid.append(bet)
	return unpaid


func get_winning_bets() -> Array[BetData]:
	"""Получить список выигравших ставок"""
	var winning: Array[BetData] = []
	for bet in bets:
		if bet.won:
			winning.append(bet)
	return winning


func get_unpaid_winning_bets() -> Array[BetData]:
	"""Получить список неоплаченных выигравших ставок"""
	var unpaid_winning: Array[BetData] = []
	for bet in bets:
		if bet.won and not bet.is_paid:
			unpaid_winning.append(bet)
	return unpaid_winning


func is_all_paid() -> bool:
	"""Проверить, все ли выигравшие ставки оплачены"""
	for bet in bets:
		if bet.won and not bet.is_paid:
			return false
	return true


func has_unpaid_winning_bets() -> bool:
	"""Есть ли неоплаченные выигравшие ставки"""
	return not is_all_paid()


func get_bet_by_type(bet_type: String) -> BetData:
	"""Получить ставку по типу"""
	for bet in bets:
		if bet.bet_type == bet_type:
			return bet
	return null


func clear() -> void:
	"""Очистить очередь (для нового раунда)"""
	var count = bets.size()
	bets.clear()
	print("🗑️  PayoutQueue: очищено (%d ставок удалено)" % count)


# ═══════════════════════════════════════════════════════════════════════════
# ИНФОРМАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func get_total_bets() -> int:
	"""Общее количество ставок"""
	return bets.size()


func get_total_winning_bets() -> int:
	"""Количество выигравших ставок"""
	return get_winning_bets().size()


func get_total_unpaid_bets() -> int:
	"""Количество неоплаченных ставок"""
	return get_unpaid_bets().size()


func print_status() -> void:
	"""Вывести текущий статус очереди"""
	print("═══ PayoutQueue Status ═══")
	print("Всего ставок: %d" % get_total_bets())
	print("Выигравших: %d" % get_total_winning_bets())
	print("Неоплаченных: %d" % get_total_unpaid_bets())

	for i in range(bets.size()):
		var bet = bets[i]
		var status = "✅" if bet.is_paid else "❌"
		var win_marker = "🏆" if bet.won else "  "
		print("  [%d] %s %s %s: %.2f → %.2f" % [i + 1, status, win_marker, bet.bet_type, bet.stake, bet.payout])
	print("═══════════════════════════")
