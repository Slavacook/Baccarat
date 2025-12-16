# res://scripts/providers/PayoutSettingsProvider.gd
# Реализация провайдера настроек выплат (DIP)

class_name PayoutSettingsProvider
extends IPayoutSettingsProvider

func is_payout_enabled(bet_type: String) -> bool:
	return PayoutSettingsManager.is_payout_enabled(bet_type)

func is_realistic_mode_enabled() -> bool:
	return PayoutSettingsManager.is_realistic_mode_enabled()

func get_position_mode() -> int:
	return PayoutSettingsManager.get_position_mode()

func is_player_enabled() -> bool:
	return PayoutSettingsManager.player_payout_enabled

func is_banker_enabled() -> bool:
	return PayoutSettingsManager.banker_payout_enabled

func is_tie_enabled() -> bool:
	return PayoutSettingsManager.tie_payout_enabled

