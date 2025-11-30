# res://scripts/chip_system/PayoutValidator.gd
# Валидатор выплат для PayoutPopup
# Ответственность: проверка правильности выплаты, расчёт подсказки, сообщения об ошибках

class_name PayoutValidator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Погрешность для сравнения float чисел в валюте
# 0.01 = 1 копейка (минимальная единица валюты, ниже которой различие игнорируется)
const FLOAT_EPSILON = 0.01

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Проверить правильность выплаты
# Параметры:
#   - collected: float - собранная сумма фишками
#   - expected: float - ожидаемая выплата
# Возвращает: true если выплата правильная (с учётом погрешности float)
func validate(collected: float, expected: float) -> bool:
	return abs(collected - expected) < FLOAT_EPSILON

# ← Получить сообщение об ошибке
# Параметры:
#   - collected: float - собранная сумма
#   - expected: float - ожидаемая выплата
# Возвращает: String с описанием ошибки
func get_error_message(collected: float, expected: float) -> String:
	if collected < expected:
		var diff = expected - collected
		return "Недостаточно! Не хватает: %s" % _format_amount(diff)
	elif collected > expected:
		var diff = collected - expected
		return "Слишком много! Лишнее: %s" % _format_amount(diff)
	else:
		return "Ошибка валидации"

# ← Рассчитать подсказку (оптимальное распределение фишек)
# Параметры:
#   - expected: float - ожидаемая выплата
#   - denominations: Array - доступные номиналы фишек (например [100, 50, 10, 5, 1, 0.5])
# Возвращает: Array[Dictionary] - массив {denomination: float, count: int}
# Использует жадный алгоритм: берём максимально крупные номиналы
func calculate_hint(expected: float, denominations: Array) -> Array:
	var result: Array = []
	var remaining = expected

	# Сортируем номиналы от большего к меньшему
	var sorted_denoms = denominations.duplicate()
	sorted_denoms.sort()
	sorted_denoms.reverse()

	# Жадный алгоритм: берём максимально крупные номиналы
	for denom in sorted_denoms:
		var count = 0

		while remaining >= denom - FLOAT_EPSILON:
			count += 1
			remaining -= denom

			if remaining < FLOAT_EPSILON:  # Учитываем погрешность float
				break

		if count > 0:
			result.append({
				"denomination": denom,
				"count": count
			})

		if remaining < FLOAT_EPSILON:
			break

	# Проверка: если остался остаток, значит невозможно составить точную сумму
	# Примечание: не используем push_warning() чтобы не ломать unit тесты
	if remaining >= FLOAT_EPSILON:
		print("PayoutValidator: Невозможно составить точную сумму %.2f из доступных номиналов" % expected)

	return result

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Форматирование числа: "2345" для целых, "2345.5" для дробных
func _format_amount(amount: float) -> String:
	if amount == floor(amount):
		return str(int(amount))
	else:
		return str(amount)
