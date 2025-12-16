# res://scripts/bet_types/TieBetType.gd
# Реализация ставки на Tie

class_name TieBetType
extends IBetType

func get_name() -> String:
	return "Tie"

func get_group() -> String:
	return "tie"

func is_winner(actual_winner: String, _player_pair_detected: bool, _banker_pair_detected: bool) -> bool:
	return actual_winner == "Tie"

func calculate_payout(stake: float, _commission: float) -> float:
	return stake * 8.0

func get_stake(limits_manager: LimitsManager) -> float:
	return limits_manager.generate_tie_bet()

