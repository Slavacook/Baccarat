# res://scripts/utils/RealisticChipGenerator.gd
# Генератор реалистичных фишек для REALISTIC режима
# 
# Отвечает за:
# - Генерацию случайного количества фишек с весовым распределением
# - Выбор случайных позиций для фишек
# - Управление вероятностями и диапазонами

class_name RealisticChipGenerator

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ - ВЕРОЯТНОСТИ ДЛЯ REALISTIC РЕЖИМА
# ═══════════════════════════════════════════════════════════════════════════

# Веса вероятностей (сумма = 100%)
const PROBABILITY_WEIGHTS = [70.0, 20.2, 7.0, 2.0, 0.6, 0.2]

# Диапазоны количества для типов с 6 позициями (Player, Banker, Tie, Pairs)
const RANGES_6 = [[0, 0], [1, 1], [2, 2], [3, 3], [4, 5], [6, 6]]

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_ranges_for_bet_type(_bet_type: String) -> Array:
	"""Получить диапазоны количества для типа ставки
	
	Args:
		_bet_type: Тип ставки (не используется, все типы имеют 6 позиций)
		
	Returns:
		Массив диапазонов [[min, max], ...]
	"""
	# Все типы ставок теперь имеют 6 позиций
	return RANGES_6


func generate_random_count(bet_type: String, position_manager: ChipPositionManager) -> int:
	"""Генерировать случайное количество ставок с весовым распределением
	
	Args:
		bet_type: Тип ставки
		position_manager: Менеджер позиций для получения количества позиций
		
	Returns:
		Случайное количество ставок (0-6)
	"""
	var ranges = get_ranges_for_bet_type(bet_type)
	
	# Выбираем диапазон по весам
	var roll = randf() * 100.0  # 0-100
	var cumulative = 0.0
	var selected_range_idx = 0
	
	for i in range(PROBABILITY_WEIGHTS.size()):
		cumulative += PROBABILITY_WEIGHTS[i]
		if roll < cumulative:
			selected_range_idx = i
			break
	
	# Получаем диапазон
	var selected_range = ranges[selected_range_idx]
	var min_count = selected_range[0]
	var max_count = selected_range[1]
	
	# Ограничиваем максимальным количеством позиций
	var positions_count = position_manager.get_positions_count(bet_type)
	max_count = mini(max_count, positions_count)
	min_count = mini(min_count, max_count)
	
	# Случайное число в диапазоне
	if min_count == max_count:
		return min_count
	return randi_range(min_count, max_count)


func select_random_positions(bet_type: String, count: int, position_manager: ChipPositionManager) -> Array[int]:
	"""Выбрать случайные позиции для ставок
	
	Args:
		bet_type: Тип ставки
		count: Количество позиций для выбора
		position_manager: Менеджер позиций для получения списка позиций
		
	Returns:
		Массив индексов выбранных позиций
	"""
	var positions = position_manager.get_alternative_positions(bet_type)
	if count <= 0 or positions.size() == 0:
		return []
	
	# Создаём список всех индексов и перемешиваем
	var indices: Array[int] = []
	for i in range(positions.size()):
		indices.append(i)
	indices.shuffle()
	
	# Берём первые count индексов
	var selected: Array[int] = []
	for i in range(mini(count, indices.size())):
		selected.append(indices[i])
	
	return selected

