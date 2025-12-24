# res://scripts/bet_types/MainBetType.gd
# Реализация основных ставок (Player/Banker)

class_name MainBetType
extends IBetType

var bet_name: String  # "Player" или "Banker"

func _init(name: String):
	bet_name = name

func get_name() -> String:
	return bet_name

func get_group() -> String:
	return "main"

func is_winner(actual_winner: String, _player_pair_detected: bool, _banker_pair_detected: bool) -> bool:
	return actual_winner == bet_name

func calculate_payout(stake: float, commission: float) -> float:
	if bet_name == "Banker":
		return stake * commission
	else:  # Player
		return stake * 1.0

func is_tie_push(actual_winner: String) -> bool:
	return actual_winner == "Tie" and bet_name in ["Player", "Banker"]

func get_stake(limits_manager: LimitsManager) -> float:
	return limits_manager.generate_bet()
