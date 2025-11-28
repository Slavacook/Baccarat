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
