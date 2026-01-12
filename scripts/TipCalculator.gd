# res://scripts/TipCalculator.gd
# Калькулятор чаевых с учетом терпения гостей
# Инкапсулирует всю логику расчета чаевых

class_name TipCalculator
extends RefCounted

## Рассчитать сумму чаевых с учетом терпения гостя
static func calculate_tip(payout: float, _bet_type: String, guest_id: int) -> int:
	if payout <= 0:
		return 0
	
	if guest_id < 1 or guest_id > 6:
		return 0
	
	var base_percentage = SaveManager.instance.load_tip_percentage()
	var patience = GuestStatsManager.get_guest_patience(guest_id)
	var effective_percentage = base_percentage * (float(patience) / 100.0)
	var base_tip = ceil(payout * effective_percentage / 100.0)
	return int(base_tip)
