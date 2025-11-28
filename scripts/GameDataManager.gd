# res://scripts/GameDataManager.gd
# Autoload singleton для передачи данных между сценами Game и PayoutScene
extends Node

# Данные для PayoutScene
var payout_winner: String = ""
var payout_stake: float = 0.0
var payout_amount: float = 0.0

# Результат из PayoutScene (для возврата в Game)
var payout_is_correct: bool = false
var payout_collected: float = 0.0
var payout_expected: float = 0.0


func set_payout_data(winner: String, stake: float, amount: float):
	payout_winner = winner
	payout_stake = stake
	payout_amount = amount
	print("💰 GameDataManager: Данные выплаты сохранены (%s, stake=%.1f, payout=%.1f)" % [winner, stake, amount])


func set_payout_result(is_correct: bool, collected: float, expected: float):
	payout_is_correct = is_correct
	payout_collected = collected
	payout_expected = expected
	print("💰 GameDataManager: Результат выплаты сохранён (correct=%s, collected=%.1f, expected=%.1f)" % [is_correct, collected, expected])


func clear():
	payout_winner = ""
	payout_stake = 0.0
	payout_amount = 0.0
	payout_is_correct = false
	payout_collected = 0.0
	payout_expected = 0.0
