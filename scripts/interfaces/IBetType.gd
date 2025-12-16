# res://scripts/interfaces/IBetType.gd
# Интерфейс для типов ставок (ISP, OCP)
# Позволяет добавлять новые типы ставок без изменения существующего кода

class_name IBetType
extends RefCounted

## Получить название типа ставки
func get_name() -> String:
	push_error("IBetType.get_name() должен быть переопределен")
	return ""

## Получить группу ставки (main/tie/pairs)
func get_group() -> String:
	push_error("IBetType.get_group() должен быть переопределен")
	return ""

## Проверить, выиграла ли ставка при данном победителе
func is_winner(_actual_winner: String, _player_pair_detected: bool, _banker_pair_detected: bool) -> bool:
	push_error("IBetType.is_winner() должен быть переопределен")
	return false

## Вычислить выплату для ставки
func calculate_payout(_stake: float, _commission: float) -> float:
	push_error("IBetType.calculate_payout() должен быть переопределен")
	return 0.0

## Проверить, является ли ставка Tie push
func is_tie_push(_actual_winner: String) -> bool:
	return false

## Получить размер ставки из LimitsManager
func get_stake(_limits_manager: LimitsManager) -> float:
	push_error("IBetType.get_stake() должен быть переопределен")
	return 0.0
