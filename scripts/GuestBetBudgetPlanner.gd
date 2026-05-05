# res://scripts/GuestBetBudgetPlanner.gd
# Planner для сборки легального пакета ставок гостей внутри доступного бюджета.
# НЕ создает Bet, НЕ изменяет баланс, НЕ вызывает уход гостя.

class_name GuestBetBudgetPlanner
extends RefCounted

const MIN_BALANCE_TO_CONTINUE: float = 100.0
const SIDE_ONLY_MODERATE_CHANCE: float = 15.0
const SIDE_ONLY_GAMBLER_CHANCE: float = 45.0

func plan_guest_bet_package(
	balance: float,
	character,
	main_choice: String,
	want_tie: bool,
	pair_choice: String,
	desired_main_stake: int,
	desired_tie_stake: int,
	desired_pair_stake: int,
	allowed_bets: Dictionary,
	limits_manager: LimitsManager
) -> Dictionary:
	var package: Array[Dictionary] = []
	var used_balance: int = 0
	var remaining_balance: float = balance

	if balance <= MIN_BALANCE_TO_CONTINUE:
		return {
			"bets": package,
			"should_leave_table": true,
			"used_balance": used_balance,
			"remaining_balance": remaining_balance,
			"reason": "balance_too_low"
		}

	var main_allowed := _is_bet_allowed(allowed_bets, main_choice)
	var main_available := false
	if main_allowed:
		main_available = can_place_main_bet(balance, allowed_bets, limits_manager)

	if main_allowed and main_available:
		remaining_balance = append_bet_if_legal(
			package,
			main_choice,
			desired_main_stake,
			remaining_balance,
			limits_manager
		)
	else:
		if not should_try_side_only(character):
			return {
				"bets": package,
				"should_leave_table": true,
				"used_balance": 0,
				"remaining_balance": balance,
				"reason": "no_legal_bets"
			}
		if not can_place_any_side_bet(balance, allowed_bets, limits_manager):
			return {
				"bets": package,
				"should_leave_table": true,
				"used_balance": 0,
				"remaining_balance": balance,
				"reason": "no_legal_bets"
			}

	if want_tie and _is_bet_allowed(allowed_bets, "Tie"):
		remaining_balance = append_bet_if_legal(
			package,
			"Tie",
			desired_tie_stake,
			remaining_balance,
			limits_manager
		)

	match pair_choice:
		"Both":
			if _is_bet_allowed(allowed_bets, "PairPlayer"):
				remaining_balance = append_bet_if_legal(
					package,
					"PairPlayer",
					desired_pair_stake,
					remaining_balance,
					limits_manager
				)
			if _is_bet_allowed(allowed_bets, "PairBanker"):
				remaining_balance = append_bet_if_legal(
					package,
					"PairBanker",
					desired_pair_stake,
					remaining_balance,
					limits_manager
				)
		"PlayerPair":
			if _is_bet_allowed(allowed_bets, "PairPlayer"):
				remaining_balance = append_bet_if_legal(
					package,
					"PairPlayer",
					desired_pair_stake,
					remaining_balance,
					limits_manager
				)
		"BankerPair":
			if _is_bet_allowed(allowed_bets, "PairBanker"):
				remaining_balance = append_bet_if_legal(
					package,
					"PairBanker",
					desired_pair_stake,
					remaining_balance,
					limits_manager
				)
		"None":
			pass
		_:
			pass

	used_balance = _calculate_used_balance(package)

	if package.is_empty():
		return {
			"bets": package,
			"should_leave_table": true,
			"used_balance": 0,
			"remaining_balance": balance,
			"reason": "no_legal_bets"
		}

	return {
		"bets": package,
		"should_leave_table": false,
		"used_balance": used_balance,
		"remaining_balance": remaining_balance,
		"reason": "ok"
	}

func fit_stake_to_budget(
	desired_stake: int,
	bet_type: String,
	remaining_balance: float,
	limits_manager: LimitsManager
) -> int:
	if limits_manager == null:
		return 0
	if remaining_balance <= 0.0:
		return 0

	var min_stake := _get_min_stake(bet_type, limits_manager)
	var max_stake := _get_max_stake(bet_type, limits_manager)
	var step_stake := _get_step_stake(bet_type, limits_manager)

	if min_stake <= 0 or max_stake <= 0 or step_stake <= 0:
		return 0

	var budget_cap := int(floor(remaining_balance))
	if budget_cap < min_stake:
		return 0

	var capped_max = mini(max_stake, budget_cap)
	if capped_max < min_stake:
		return 0

	var desired = desired_stake
	if desired < min_stake:
		desired = min_stake
	if desired > capped_max:
		desired = capped_max

	var aligned = _align_down_to_step(desired, min_stake, step_stake)
	if aligned < min_stake:
		return 0
	if aligned > capped_max:
		aligned = _align_down_to_step(capped_max, min_stake, step_stake)

	if aligned < min_stake or aligned > capped_max:
		return 0

	return aligned

func can_place_main_bet(
	balance: float,
	allowed_bets: Dictionary,
	limits_manager: LimitsManager
) -> bool:
	if limits_manager == null:
		return false

	var has_allowed_main := false
	if _is_bet_allowed(allowed_bets, "Player"):
		has_allowed_main = true
	if _is_bet_allowed(allowed_bets, "Banker"):
		has_allowed_main = true
	if not has_allowed_main:
		return false

	return balance >= limits_manager.min_bet

func can_place_any_side_bet(
	balance: float,
	allowed_bets: Dictionary,
	limits_manager: LimitsManager
) -> bool:
	if limits_manager == null:
		return false

	if _is_bet_allowed(allowed_bets, "Tie") and balance >= limits_manager.tie_min:
		return true
	if _is_bet_allowed(allowed_bets, "PairPlayer") and balance >= limits_manager.pairs_min:
		return true
	if _is_bet_allowed(allowed_bets, "PairBanker") and balance >= limits_manager.pairs_min:
		return true

	return false

func append_bet_if_legal(
	package: Array[Dictionary],
	bet_type: String,
	desired_stake: int,
	remaining_balance: float,
	limits_manager: LimitsManager
) -> float:
	var fitted_stake = fit_stake_to_budget(
		desired_stake,
		bet_type,
		remaining_balance,
		limits_manager
	)
	if fitted_stake <= 0:
		return remaining_balance

	package.append({
		"bet_type": bet_type,
		"stake": fitted_stake
	})

	return remaining_balance - float(fitted_stake)

func should_try_side_only(character) -> bool:
	if character == GuestSettingsManager.GuestCharacter.CAUTIOUS:
		return false
	if character == GuestSettingsManager.GuestCharacter.MODERATE:
		return randf() * 100.0 < SIDE_ONLY_MODERATE_CHANCE
	if character == GuestSettingsManager.GuestCharacter.GAMBLER:
		return randf() * 100.0 < SIDE_ONLY_GAMBLER_CHANCE
	return false

func _is_bet_allowed(allowed_bets: Dictionary, bet_type: String) -> bool:
	if not allowed_bets.has(bet_type):
		return false
	if not (allowed_bets[bet_type] is bool):
		return false
	return allowed_bets[bet_type]

func _get_min_stake(bet_type: String, limits_manager: LimitsManager) -> int:
	match bet_type:
		"Player", "Banker":
			return limits_manager.min_bet
		"Tie":
			return limits_manager.tie_min
		"PairPlayer", "PairBanker":
			return limits_manager.pairs_min
		_:
			return 0

func _get_max_stake(bet_type: String, limits_manager: LimitsManager) -> int:
	match bet_type:
		"Player", "Banker":
			return limits_manager.max_bet
		"Tie":
			return limits_manager.tie_max
		"PairPlayer", "PairBanker":
			return limits_manager.pairs_max
		_:
			return 0

func _get_step_stake(bet_type: String, limits_manager: LimitsManager) -> int:
	match bet_type:
		"Player", "Banker":
			return limits_manager.step
		"Tie":
			return limits_manager.tie_step
		"PairPlayer", "PairBanker":
			return limits_manager.pairs_step
		_:
			return 0

func _align_down_to_step(value: int, min_stake: int, step_stake: int) -> int:
	if step_stake <= 0:
		return 0
	if value < min_stake:
		return 0

	var offset = value - min_stake
	var steps = int(floor(float(offset) / float(step_stake)))
	return min_stake + (steps * step_stake)

func _calculate_used_balance(package: Array[Dictionary]) -> int:
	var total := 0
	for item in package:
		if not (item is Dictionary):
			continue
		if not item.has("stake"):
			continue
		var stake_value = item["stake"]
		if stake_value is int:
			total += stake_value
	return total
