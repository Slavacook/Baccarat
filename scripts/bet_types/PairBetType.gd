# res://scripts/bet_types/PairBetType.gd
# Реализация ставок на пары

class_name PairBetType
extends IBetType

var pair_name: String  # "PairPlayer" или "PairBanker"

func _init(name: String):
	pair_name = name

func get_name() -> String:
	return pair_name

func get_group() -> String:
	return "pairs"

func is_winner(_actual_winner: String, player_pair_detected: bool, banker_pair_detected: bool) -> bool:
	if pair_name == "PairPlayer":
		return player_pair_detected
	elif pair_name == "PairBanker":
		return banker_pair_detected
	return false

func calculate_payout(stake: float, _commission: float) -> float:
	# Выплата для пар рассчитывается через PairBettingManager
	# Это значение будет переопределено при использовании
	return stake * 11.0  # Стандартный коэффициент для пар

func get_stake(limits_manager: LimitsManager) -> float:
	return limits_manager.generate_pair_bet()

