# res://scripts/chip_system/ChipStackManager.gd
# Менеджер для управления коллекцией стопок фишек
# Ответственность: добавление/удаление стопок, сортировка, переключение режимов слотов

class_name ChipStackManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal total_changed(new_total: float)         # Общая сумма изменилась
signal slots_changed(new_slot_count: int)      # Количество слотов изменилось (6↔10)
signal stack_added(stack: ChipStack, index: int)   # Стопка добавлена
signal stack_removed(stack: ChipStack, index: int) # Стопка удалена

# ═══════════════════════════════════════════════════════════════════════════
# (Константы перенесены в GameConstants)
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var chip_stacks: Array[ChipStack] = []  # Массив стопок (сортировка: от крупных к мелким)
var stack_slots: Array[Control] = []    # UI слоты для стопок (VBoxContainer)
var chip_stacks_container: Control      # Родительский контейнер слотов (HBoxContainer)

var slot_count: int = GameConstants.CHIP_STACK_SLOT_COUNT_SMALL  # Текущее количество слотов (6 или 10)
var current_scale: float = GameConstants.CHIP_STACK_SCALE_SMALL  # Текущий масштаб стопок

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(container: Control):
	chip_stacks_container = container
	_initialize_slots(GameConstants.CHIP_STACK_SLOT_COUNT_SMALL)

# ← Создание фиксированных слотов для стеков
func _initialize_slots(count: int):
	# Очищаем старые слоты
	for slot in stack_slots:
		chip_stacks_container.remove_child(slot)
		slot.queue_free()
	stack_slots.clear()

	slot_count = count
	current_scale = GameConstants.CHIP_STACK_SCALE_SMALL if count == GameConstants.CHIP_STACK_SLOT_COUNT_SMALL else GameConstants.CHIP_STACK_SCALE_LARGE

	# Создаём пустые слоты
	for i in range(count):
		var slot = VBoxContainer.new()
		slot.custom_minimum_size = Vector2(96 * current_scale, GameConstants.CHIP_STACK_SLOT_HEIGHT)  # ВЫСОТА ФИКСИРОВАНА!
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.alignment = BoxContainer.ALIGNMENT_END  # Выравнивание СНИЗУ!
		chip_stacks_container.add_child(slot)
		stack_slots.append(slot)

	print("ChipStackManager: Инициализировано %d слотов (масштаб %.1f)" % [count, current_scale])
	slots_changed.emit(count)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ДОБАВЛЕНИЕ/УДАЛЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════

# ← Добавить фишку с указанным номиналом
func add_chip(denomination: float) -> bool:
	# Ищем ПОСЛЕДНИЙ (правый) стек данного номинала с свободным местом
	var target_stack: ChipStack = null
	var target_index: int = -1

	for i in range(chip_stacks.size() - 1, -1, -1):  # С конца!
		var stack = chip_stacks[i]
		if stack.denomination == denomination and stack.count < GameConstants.CHIP_STACK_MAX_CHIPS:
			target_stack = stack
			target_index = i
			break

	# Если нет подходящей стопки, создаём новую
	if target_stack == null:
		# Проверяем, есть ли свободный слот
		if chip_stacks.size() >= slot_count:
			# Нужно переключиться на 10 слотов
			if slot_count == GameConstants.CHIP_STACK_SLOT_COUNT_SMALL:
				_rescale_to_large()
			else:
				push_warning("ChipStackManager: Все слоты заняты! Максимум 10 стеков.")
				return false

		# Создаём новый стек с текущим масштабом
		target_stack = ChipStack.new(denomination, current_scale)

		# Находим правильную позицию (сортировка от крупного к мелкому)
		target_index = _find_sorted_position(denomination)

		# Вставляем стек
		chip_stacks.insert(target_index, target_stack)

		# Пересобираем все стеки в слотах
		_rebuild_slots()

		stack_added.emit(target_stack, target_index)

	# Добавляем фишку в стопку
	if target_stack.add_chip():
		_update_total()
		print("ChipStackManager: Добавлена фишка %s, всего в стопке: %d (слот %d)" % [denomination, target_stack.count, target_index])
		return true
	else:
		push_warning("ChipStackManager: Стопка полна! (макс %d фишек)" % GameConstants.CHIP_STACK_MAX_CHIPS)
		return false

# ← Удалить фишку с указанным номиналом (из ПОСЛЕДНЕГО стека)
func remove_chip(denomination: float) -> bool:
	# Ищем ПОСЛЕДНИЙ (правый) стек данного номинала
	var target_stack: ChipStack = null
	var target_index: int = -1

	for i in range(chip_stacks.size() - 1, -1, -1):  # С конца!
		var stack = chip_stacks[i]
		if stack.denomination == denomination:
			target_stack = stack
			target_index = i
			break

	if target_stack == null:
		push_warning("ChipStackManager: Нет стека номинала %s для удаления" % denomination)
		return false

	# Удаляем одну фишку
	if target_stack.remove_chip():
		print("ChipStackManager: Удалена фишка %s, осталось: %d (слот %d)" % [denomination, target_stack.count, target_index])

		# Если стопка опустела, удаляем её
		if target_stack.is_empty():
			var slot = stack_slots[target_index]
			if target_stack.container.get_parent():
				slot.remove_child(target_stack.container)

			if is_instance_valid(target_stack.container):
				target_stack.container.queue_free()

			chip_stacks.erase(target_stack)
			stack_removed.emit(target_stack, target_index)

			print("ChipStackManager: Стопка номинала %s удалена (пуста, слот %d)" % [denomination, target_index])

			# Пересобираем слоты (сдвигаем влево)
			_compact_stacks()

		_update_total()
		return true
	else:
		return false

# ← Очистить все стопки
func clear_all():
	for stack in chip_stacks:
		if stack.container.get_parent():
			stack.container.get_parent().remove_child(stack.container)

		if is_instance_valid(stack.container):
			stack.container.queue_free()

	chip_stacks.clear()
	_update_total()

	print("ChipStackManager: Все стопки очищены")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ПОЛУЧЕНИЕ ИНФОРМАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

# ← Получить общую сумму всех стопок
func get_total() -> float:
	var total: float = 0.0
	for stack in chip_stacks:
		total += stack.get_total()
	return total

# ← Получить массив стопок
func get_stacks() -> Array[ChipStack]:
	return chip_stacks

# ← Получить количество стопок
func get_stack_count() -> int:
	return chip_stacks.size()

# ← Проверка, пусты ли все стопки
func is_empty() -> bool:
	return chip_stacks.is_empty()

# ← Проверить, есть ли стек с указанным номиналом
func has_stack(denomination: float) -> bool:
	for stack in chip_stacks:
		if stack.denomination == denomination:
			return true
	return false

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - УПРАВЛЕНИЕ СЛОТАМИ
# ═══════════════════════════════════════════════════════════════════════════

# ← Переключение на 10 слотов с масштабированием
func _rescale_to_large():
	print("ChipStackManager: Переключение на 10 слотов...")

	# Сохраняем текущие стеки
	var saved_stacks = chip_stacks.duplicate()

	# Удаляем стеки из старых слотов
	for i in range(saved_stacks.size()):
		var stack = saved_stacks[i]
		var old_slot = stack_slots[i]
		if stack.container.get_parent():
			old_slot.remove_child(stack.container)

	# Пересоздаём слоты (10 штук)
	_initialize_slots(GameConstants.CHIP_STACK_SLOT_COUNT_LARGE)

	# Обновляем масштаб всех стеков
	for stack in saved_stacks:
		stack.update_scale(current_scale)  # current_scale = 0.6

	# Возвращаем стеки в новые слоты
	chip_stacks.clear()
	for i in range(saved_stacks.size()):
		var stack = saved_stacks[i]
		chip_stacks.append(stack)
		var new_slot = stack_slots[i]
		new_slot.add_child(stack.container)

	print("ChipStackManager: Переключено на 10 слотов (масштаб %.1f)" % current_scale)

# ← Переключение обратно на 6 слотов
func _rescale_to_small():
	print("ChipStackManager: Возвращение к 6 слотам...")

	var saved_stacks = chip_stacks.duplicate()

	# Удаляем стеки из текущих слотов
	for stack in saved_stacks:
		if stack.container.get_parent():
			stack.container.get_parent().remove_child(stack.container)

	# Пересоздаём 6 слотов
	_initialize_slots(GameConstants.CHIP_STACK_SLOT_COUNT_SMALL)

	# Обновляем масштаб обратно на 1.0
	for stack in saved_stacks:
		stack.update_scale(current_scale)  # current_scale = 1.0

	# Возвращаем стеки
	chip_stacks.clear()
	for i in range(saved_stacks.size()):
		var stack = saved_stacks[i]
		chip_stacks.append(stack)
		var slot = stack_slots[i]
		slot.add_child(stack.container)

	print("ChipStackManager: Возвращено к 6 слотам (масштаб %.1f)" % current_scale)

# ← Найти позицию для вставки стека (сортировка от крупного к мелкому)
func _find_sorted_position(denomination: float) -> int:
	for i in range(chip_stacks.size()):
		if chip_stacks[i].denomination < denomination:
			return i
	return chip_stacks.size()

# ← Пересборка стеков в слотах (после вставки)
func _rebuild_slots():
	# Удаляем все стеки из слотов
	for i in range(chip_stacks.size()):
		var stack = chip_stacks[i]
		if stack.container.get_parent():
			stack.container.get_parent().remove_child(stack.container)

	# Добавляем стеки обратно в правильном порядке
	for i in range(chip_stacks.size()):
		var stack = chip_stacks[i]
		var slot = stack_slots[i]
		slot.add_child(stack.container)

# ← Сжатие стеков (сдвиг влево после удаления)
func _compact_stacks():
	# Удаляем все стеки из слотов
	for i in range(chip_stacks.size()):
		var stack = chip_stacks[i]
		if stack.container.get_parent():
			stack.container.get_parent().remove_child(stack.container)

	# Добавляем стеки обратно по порядку
	for i in range(chip_stacks.size()):
		var stack = chip_stacks[i]
		var slot = stack_slots[i]
		slot.add_child(stack.container)

	# Если стеков <= 6 и текущий режим 10 слотов, возвращаемся к 6
	if chip_stacks.size() <= GameConstants.CHIP_STACK_SLOT_COUNT_SMALL and slot_count == GameConstants.CHIP_STACK_SLOT_COUNT_LARGE:
		_rescale_to_small()

# ← Обновить общую сумму
func _update_total():
	total_changed.emit(get_total())
