# res://scripts/GameDataManager.gd
# Autoload singleton для передачи данных между сценами Game и PayoutScene
extends Node

# Данные для PayoutScene
var payout_winner: String = ""
var payout_stake: float = 0.0
var payout_amount: float = 0.0
var payout_player_score: int = 0
var payout_banker_score: int = 0

# Результат из PayoutScene (для возврата в Game)
var payout_is_correct: bool = false
var payout_collected: float = 0.0
var payout_expected: float = 0.0

# Состояние игры (сохраняется при переходе в PayoutScene)
var survival_rounds: int = 0
var survival_lives: int = 7
var is_survival_active: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ОЧЕРЕДЬ ВЫПЛАТ (для множественных ставок в одном раунде)
# ═══════════════════════════════════════════════════════════════════════════

# Структура данных для выплаты
class PayoutData:
	var bet_type: String  # "Player", "Banker", "Tie", "PairPlayer", "PairBanker"
	var stake: float
	var payout: float
	var player_score: int
	var banker_score: int

	func _init(type: String, stake_amt: float, payout_amt: float, p_score: int = 0, b_score: int = 0):
		bet_type = type
		stake = stake_amt
		payout = payout_amt
		player_score = p_score
		banker_score = b_score

# Очередь выплат (обрабатываются по порядку)
var payout_queue: Array[PayoutData] = []


func set_payout_data(winner: String, stake: float, amount: float, player_score: int = 0, banker_score: int = 0):
	payout_winner = winner
	payout_stake = stake
	payout_amount = amount
	payout_player_score = player_score
	payout_banker_score = banker_score
	print("💰 GameDataManager: Данные выплаты сохранены (%s, stake=%.1f, payout=%.1f, scores=%d vs %d)" % [winner, stake, amount, player_score, banker_score])


func set_payout_result(is_correct: bool, collected: float, expected: float):
	payout_is_correct = is_correct
	payout_collected = collected
	payout_expected = expected
	print("💰 GameDataManager: Результат выплаты сохранён (correct=%s, collected=%.1f, expected=%.1f)" % [is_correct, collected, expected])


func set_game_state(rounds: int, lives: int, is_active: bool):
	survival_rounds = rounds
	survival_lives = lives
	is_survival_active = is_active
	print("💾 GameDataManager: Состояние игры сохранено (rounds=%d, lives=%d, active=%s)" % [rounds, lives, is_active])


func clear():
	payout_winner = ""
	payout_stake = 0.0
	payout_amount = 0.0
	payout_player_score = 0
	payout_banker_score = 0
	payout_is_correct = false
	payout_collected = 0.0
	payout_expected = 0.0
	# НЕ очищаем survival_rounds/lives/is_active - они нужны при возврате!


# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ДЛЯ РАБОТЫ С ОЧЕРЕДЬЮ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

func add_to_payout_queue(bet_type: String, stake: float, payout: float, p_score: int = 0, b_score: int = 0) -> void:
	"""Добавить выплату в очередь"""
	var payout_data = PayoutData.new(bet_type, stake, payout, p_score, b_score)
	payout_queue.append(payout_data)
	print("💰 PayoutQueue: добавлена выплата %s (stake=%.1f, payout=%.1f)" % [bet_type, stake, payout])


func get_next_payout() -> PayoutData:
	"""Получить следующую выплату из очереди (и удалить её)"""
	if payout_queue.is_empty():
		return null

	var next_payout = payout_queue[0]
	payout_queue.remove_at(0)
	print("💰 PayoutQueue: взята выплата %s из очереди (осталось: %d)" % [next_payout.bet_type, payout_queue.size()])
	return next_payout


func has_more_payouts() -> bool:
	"""Проверить, есть ли ещё выплаты в очереди"""
	return not payout_queue.is_empty()


func get_queue_size() -> int:
	"""Получить количество выплат в очереди"""
	return payout_queue.size()


func clear_payout_queue() -> void:
	"""Очистить очередь выплат"""
	var count = payout_queue.size()
	payout_queue.clear()
	if count > 0:
		print("🗑️  PayoutQueue: очищено (%d выплат удалено)" % count)


func print_queue_status() -> void:
	"""Вывести текущий статус очереди"""
	print("═══ PayoutQueue Status ═══")
	print("Выплат в очереди: %d" % payout_queue.size())
	for i in range(payout_queue.size()):
		var p = payout_queue[i]
		print("  [%d] %s: %.1f → %.1f" % [i + 1, p.bet_type, p.stake, p.payout])
	print("═══════════════════════════")
