# res://scripts/TipCalculator.gd
# Калькулятор чаевых с учетом терпения гостей
# Инкапсулирует всю логику расчета чаевых

class_name TipCalculator
extends RefCounted

## Рассчитать сумму чаевых с учетом терпения гостя
##
## Формула:
## 1. Эффективный процент = базовый процент × (1.0 - терпение / 100.0)
## 2. Базовые чаевые = ceil(payout × эффективный процент / 100.0) - округление ДО умножения
## 3. Итоговые чаевые = базовые чаевые × коэффициент ставки
##
## Args:
##   payout: Размер выплаты (выигрыш гостя)
##   bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
##   guest_id: ID гостя (1-6, используется для получения терпения)
##
## Returns:
##   Сумма чаевых (целое число)
static func calculate_tip(payout: float, bet_type: String, guest_id: int) -> int:
	if payout <= 0:
		return 0
	
	if guest_id < 1 or guest_id > 6:
		# Не гостевая ставка - возвращаем 0 (или можно использовать базовый расчет без терпения)
		return 0
	
	# 1. Получаем базовый процент чаевых из настроек
	var base_percentage = SaveManager.instance.load_tip_percentage()  # Например 1.0 для 1%
	
	# 2. Получаем терпение гостя
	var patience = GuestStatsManager.get_guest_patience(guest_id)
	
	# 3. Рассчитываем эффективный процент с учетом терпения
	# Терпение 0% → эффективный = базовый × 1.0 (полный чай)
	# Терпение 50% → эффективный = базовый × 0.5 (половина чая)
	# Терпение 100% → эффективный = базовый × 0.0 (нет чая)
	var effective_percentage = base_percentage * (1.0 - float(patience) / 100.0)
	
	# 4. Рассчитываем базовые чаевые с округлением вверх ДО умножения на коэффициент
	var base_tip = ceil(payout * effective_percentage / 100.0)
	
	# 5. Получаем коэффициент для типа ставки
	var multiplier = get_tip_multiplier(bet_type)
	
	# 6. Умножаем базовые чаевые на коэффициент
	return int(base_tip * multiplier)

## Получить коэффициент для расчета чаевых в зависимости от типа ставки
##
## Args:
##   bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
##
## Returns:
##   Коэффициент: 1 для Player/Banker, 8 для Tie, 11 для Pair
static func get_tip_multiplier(bet_type: String) -> int:
	match bet_type:
		"Player", "Banker":
			return 1
		"Tie":
			return 8
		"PairPlayer", "PairBanker":
			return 11
		_:
			return 1  # По умолчанию коэффициент 1
