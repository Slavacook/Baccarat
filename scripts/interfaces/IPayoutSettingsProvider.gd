# res://scripts/interfaces/IPayoutSettingsProvider.gd
# Интерфейс для провайдера настроек выплат (DIP)

class_name IPayoutSettingsProvider
extends RefCounted

## Проверить, включена ли выплата для типа ставки
func is_payout_enabled(_bet_type: String) -> bool:
	push_error("IPayoutSettingsProvider.is_payout_enabled() должен быть переопределен")
	return false

## Проверить, включен ли realistic режим
func is_realistic_mode_enabled() -> bool:
	push_error("IPayoutSettingsProvider.is_realistic_mode_enabled() должен быть переопределен")
	return false

## Получить режим позиций
func get_position_mode() -> int:
	push_error("IPayoutSettingsProvider.get_position_mode() должен быть переопределен")
	return 0

## Проверить, включена ли ставка Player
func is_player_enabled() -> bool:
	return is_payout_enabled("Player")

## Проверить, включена ли ставка Banker
func is_banker_enabled() -> bool:
	return is_payout_enabled("Banker")

## Проверить, включена ли ставка Tie
func is_tie_enabled() -> bool:
	return is_payout_enabled("Tie")
