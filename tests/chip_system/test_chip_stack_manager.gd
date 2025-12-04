# res://tests/chip_system/test_chip_stack_manager.gd
# Unit тесты для ChipStackManager
extends GutTest

var manager: ChipStackManager
var mock_container: HBoxContainer

func before_each():
	# Создаём mock контейнер для слотов
	mock_container = HBoxContainer.new()
	manager = ChipStackManager.new(mock_container)

func after_each():
	# Очищаем все стопки и освобождаем узлы
	if manager:
		manager.clear_all()
	if mock_container:
		mock_container.free()
	manager = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ БАЗОВОЙ ФУНКЦИОНАЛЬНОСТИ
# ═══════════════════════════════════════════════════════════════════════════

func test_initial_state_empty():
	assert_true(manager.is_empty(), "Менеджер должен быть пустым при создании")
	assert_eq(manager.get_total(), 0.0, "Общая сумма должна быть 0")
	assert_eq(manager.get_stack_count(), 0, "Количество стопок должно быть 0")

func test_initial_slot_count():
	assert_eq(manager.slot_count, GameConstants.CHIP_STACK_SLOT_COUNT_SMALL, "Изначально должно быть 9 слотов")
	assert_eq(manager.current_scale, GameConstants.CHIP_STACK_SCALE_SMALL, "Масштаб должен быть 0.75")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДОБАВЛЕНИЯ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func test_add_chip_creates_new_stack():
	var result = manager.add_chip(100.0)
	assert_true(result, "add_chip() должен вернуть true")
	assert_eq(manager.get_stack_count(), 1, "Должна быть создана 1 стопка")
	assert_eq(manager.get_total(), 100.0, "Общая сумма должна быть 100")

func test_add_chip_to_existing_stack():
	manager.add_chip(100.0)
	manager.add_chip(100.0)
	assert_eq(manager.get_stack_count(), 1, "Должна быть только 1 стопка")
	assert_eq(manager.get_total(), 200.0, "Общая сумма должна быть 200")

func test_add_multiple_denominations():
	manager.add_chip(100.0)
	manager.add_chip(50.0)
	manager.add_chip(10.0)

	assert_eq(manager.get_stack_count(), 3, "Должно быть 3 стопки")
	assert_eq(manager.get_total(), 160.0, "Общая сумма должна быть 160")

func test_add_chip_sorts_descending():
	# Добавляем в случайном порядке
	manager.add_chip(10.0)
	manager.add_chip(100.0)
	manager.add_chip(50.0)

	var stacks = manager.get_stacks()
	assert_eq(stacks[0].denomination, 100.0, "Первая стопка: 100")
	assert_eq(stacks[1].denomination, 50.0, "Вторая стопка: 50")
	assert_eq(stacks[2].denomination, 10.0, "Третья стопка: 10")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ УДАЛЕНИЯ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func test_remove_chip_from_stack():
	manager.add_chip(100.0)
	manager.add_chip(100.0)

	var result = manager.remove_chip(100.0)
	assert_true(result, "remove_chip() должен вернуть true")
	assert_eq(manager.get_total(), 100.0, "Должна остаться 1 фишка")

func test_remove_last_chip_deletes_stack():
	manager.add_chip(100.0)
	manager.remove_chip(100.0)

	assert_eq(manager.get_stack_count(), 0, "Стопка должна быть удалена")
	assert_true(manager.is_empty(), "Менеджер должен быть пустым")

func test_remove_from_last_stack_of_denomination():
	# Создаём 2 стопки номинала 100 (по 20 фишек каждая)
	for i in range(ChipStack.MAX_CHIPS):
		manager.add_chip(100.0)
	for i in range(ChipStack.MAX_CHIPS):
		manager.add_chip(100.0)

	assert_eq(manager.get_stack_count(), 2, "Должно быть 2 стопки номинала 100")

	# Удаляем 1 фишку - должна удалиться из ПОСЛЕДНЕЙ (правой) стопки
	manager.remove_chip(100.0)

	var stacks = manager.get_stacks()
	assert_eq(stacks[0].count, ChipStack.MAX_CHIPS, "Первая стопка: полная (20 фишек)")
	assert_eq(stacks[1].count, ChipStack.MAX_CHIPS - 1, "Вторая стопка: 19 фишек")

func test_remove_chip_nonexistent_denomination():
	manager.add_chip(100.0)
	var result = manager.remove_chip(50.0)
	assert_false(result, "remove_chip() должен вернуть false для несуществующего номинала")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ОЧИСТКИ
# ═══════════════════════════════════════════════════════════════════════════

func test_clear_all():
	manager.add_chip(100.0)
	manager.add_chip(50.0)
	manager.add_chip(10.0)

	manager.clear_all()

	assert_true(manager.is_empty(), "Менеджер должен быть пустым после clear_all()")
	assert_eq(manager.get_total(), 0.0, "Общая сумма должна быть 0")
	assert_eq(manager.get_stack_count(), 0, "Количество стопок должно быть 0")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ АВТОМАТИЧЕСКОГО ПЕРЕКЛЮЧЕНИЯ СЛОТОВ (6↔10)
# ═══════════════════════════════════════════════════════════════════════════

func test_rescale_to_10_slots_when_7th_stack():
	# Добавляем 7 разных номиналов (7 стопок)
	var denominations = [100000, 50000, 10000, 5000, 1000, 500, 100]

	for denom in denominations:
		manager.add_chip(denom)

	assert_eq(manager.slot_count, GameConstants.CHIP_STACK_SLOT_COUNT_LARGE, "Должно быть 13 слотов")
	assert_eq(manager.current_scale, GameConstants.CHIP_STACK_SCALE_LARGE, "Масштаб должен быть 0.6")

func test_rescale_back_to_6_slots_when_removing():
	# Добавляем 7 номиналов (переключится на 10 слотов)
	var denominations = [100000, 50000, 10000, 5000, 1000, 500, 100]
	for denom in denominations:
		manager.add_chip(denom)

	# Удаляем 1 фишку (осталось 6 стопок)
	manager.remove_chip(100)

	assert_eq(manager.slot_count, GameConstants.CHIP_STACK_SLOT_COUNT_SMALL, "Должно вернуться к 9 слотам")
	assert_eq(manager.current_scale, GameConstants.CHIP_STACK_SCALE_SMALL, "Масштаб должен быть 0.75")

func test_max_10_stacks_limit():
	# Пытаемся добавить 11 разных номиналов
	var denominations = [100000, 50000, 10000, 5000, 1000, 500, 100, 50, 10, 5, 1]

	for i in range(10):
		var result = manager.add_chip(denominations[i])
		assert_true(result, "Первые 10 стопок должны добавляться")

	# 11-я стопка не должна добавиться
	var result = manager.add_chip(denominations[10])
	assert_false(result, "11-я стопка не должна добавиться (лимит 10 слотов)")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ СИГНАЛОВ
# ═══════════════════════════════════════════════════════════════════════════

func test_total_changed_signal_on_add():
	watch_signals(manager)
	manager.add_chip(100.0)
	assert_signal_emitted(manager, "total_changed", "Сигнал total_changed должен быть эмитирован")

func test_total_changed_signal_on_remove():
	manager.add_chip(100.0)
	watch_signals(manager)
	manager.remove_chip(100.0)
	assert_signal_emitted(manager, "total_changed", "Сигнал total_changed должен быть эмитирован")

func test_slots_changed_signal_on_rescale():
	watch_signals(manager)

	# Добавляем 7 стопок (должно переключиться на 10 слотов)
	for i in range(7):
		manager.add_chip(float(i + 1))

	assert_signal_emitted(manager, "slots_changed", "Сигнал slots_changed должен быть эмитирован")

func test_stack_added_signal():
	watch_signals(manager)
	manager.add_chip(100.0)
	assert_signal_emitted(manager, "stack_added", "Сигнал stack_added должен быть эмитирован")

func test_stack_removed_signal():
	manager.add_chip(100.0)
	watch_signals(manager)
	manager.remove_chip(100.0)
	assert_signal_emitted(manager, "stack_removed", "Сигнал stack_removed должен быть эмитирован")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ГРАНИЧНЫХ СЛУЧАЕВ
# ═══════════════════════════════════════════════════════════════════════════

func test_add_fractional_denominations():
	manager.add_chip(0.5)
	manager.add_chip(0.5)
	assert_eq(manager.get_total(), 1.0, "Сумма дробных номиналов должна быть 1.0")

func test_large_number_of_chips():
	# Добавляем 100 фишек по 10
	for i in range(100):
		manager.add_chip(10.0)

	assert_eq(manager.get_total(), 1000.0, "Общая сумма должна быть 1000")
	# 100 фишек / 20 max = 5 стопок
	assert_eq(manager.get_stack_count(), 5, "Должно быть 5 полных стопок")

func test_mixed_operations():
	# Добавляем фишки
	manager.add_chip(100.0)
	manager.add_chip(50.0)
	manager.add_chip(100.0)

	# Удаляем
	manager.remove_chip(50.0)

	# Добавляем ещё
	manager.add_chip(10.0)

	assert_eq(manager.get_stack_count(), 2, "Должно быть 2 стопки (100 и 10)")
	assert_eq(manager.get_total(), 210.0, "Общая сумма должна быть 210")
