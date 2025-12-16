# res://scripts/payout/PayoutCalculator.gd
# Калькулятор выплат (SRP - единственная ответственность: расчет выплат)

class_name PayoutCalculator
extends RefCounted

var rules_provider: BaccaratRulesProvider
var commission_provider: CommissionProvider

func _init(rules: BaccaratRulesProvider = null, commission: CommissionProvider = null):
	rules_provider = rules if rules else DefaultBaccaratRulesProvider.new()
	commission_provider = commission if commission else DefaultCommissionProvider.new()

## Рассчитать выплату для ставки
func calculate(bet_type: IBetType, stake: float, actual_winner: String, 
			   player_pair_detected: bool, banker_pair_detected: bool,
			   banker_hand_value: int = 0) -> float:
	if not bet_type.is_winner(actual_winner, player_pair_detected, banker_pair_detected):
		return 0.0
	
	var commission = commission_provider.get_commission(bet_type.get_name(), banker_hand_value)
	return bet_type.calculate_payout(stake, commission)

## Рассчитать выплату для пары (специальная логика)
func calculate_pair_payout(bet_type: IBetType, stake: float, pair_betting_manager: PairBettingManager) -> float:
	if bet_type.get_name() == "PairPlayer" or bet_type.get_name() == "PairBanker":
		return pair_betting_manager.calculate_pair_payout(stake, bet_type.get_name())
	return 0.0

# ═══════════════════════════════════════════════════════════════════════════
# Провайдеры для Dependency Injection
# ═══════════════════════════════════════════════════════════════════════════

class BaccaratRulesProvider:
	func hand_value(_hand: Array) -> int:
		push_error("BaccaratRulesProvider.hand_value() должен быть переопределен")
		return 0

class DefaultBaccaratRulesProvider extends BaccaratRulesProvider:
	func hand_value(hand: Array) -> int:
		return BaccaratRules.hand_value(hand)

class CommissionProvider:
	func get_commission(_bet_type: String, _banker_hand_value: int) -> float:
		push_error("CommissionProvider.get_commission() должен быть переопределен")
		return 1.0

class DefaultCommissionProvider extends CommissionProvider:
	func get_commission(bet_type: String, banker_hand_value: int) -> float:
		if bet_type != "Banker":
			return 1.0
		
		var commission = GameModeManager.get_banker_commission()
		if GameModeManager.get_mode_string() == "classic" and banker_hand_value == 6:
			commission = 0.5
		return commission
