# res://scripts/utils/LinePositionCalculator.gd
# Калькулятор номеров позиций в линиях ставок
# 
# Отвечает за:
# - Вычисление номера позиции в линии (1 = самый правый, N = самый левый)
# - Кэширование результатов для оптимизации
# - Обработка стандартных ставок и пар (PairPlayer/PairBanker)

class_name LinePositionCalculator

# ═══════════════════════════════════════════════════════════════════════════
# КЭШ
# ═══════════════════════════════════════════════════════════════════════════

var _position_cache: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_line_position_number(bet_type: String, position_index: int) -> int:
	"""Получить номер позиции в линии (1 = самый правый, N = самый левый)
	
	Для всех типов ставок нумерация одинаковая: справа налево.
	Исключение: Tie при сборе использует обратный порядок (см. BetCollectionPhaseManager._get_sorted_tie_bets)
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		position_index: Индекс позиции в массиве ALTERNATIVE_POSITIONS
		
	Returns:
		Номер позиции в линии (1 = самый правый, N = самый левый)
	"""
	var key = "%s_%d" % [bet_type, position_index]
	
	# Проверяем кэш
	if _position_cache.has(key):
		return _position_cache[key]
	
	var number = 0
	
	# Для пар: объединяем PairPlayer и PairBanker
	if bet_type in ["PairPlayer", "PairBanker"]:
		number = _get_pairs_line_number(bet_type, position_index)
	else:
		# Для остальных: используем обычную логику
		number = _get_standard_line_number(bet_type, position_index)
	
	# Сохраняем в кэш
	_position_cache[key] = number
	return number

func clear_cache() -> void:
	"""Очистить кэш позиций"""
	_position_cache.clear()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _get_standard_line_number(bet_type: String, position_index: int) -> int:
	"""Получить номер позиции для стандартного типа (не пары)
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie")
		position_index: Индекс позиции
		
	Returns:
		Номер позиции (1 = самый правый)
	"""
	if not ChipVisualManager.ALTERNATIVE_POSITIONS.has(bet_type):
		return 0
	
	var positions = ChipVisualManager.ALTERNATIVE_POSITIONS[bet_type]
	if position_index < 0 or position_index >= positions.size():
		return 0
	
	# Сортируем все позиции по X (справа налево: больший X = меньший номер)
	var sorted_positions = []
	for i in range(positions.size()):
		sorted_positions.append({"index": i, "x": positions[i].x})
	
	sorted_positions.sort_custom(func(a, b): return a.x > b.x)  # Убывание X
	
	# Находим номер нашей позиции (1 = самый правый)
	for i in range(sorted_positions.size()):
		if sorted_positions[i].index == position_index:
			return i + 1  # Нумерация с 1
	
	return 0

func _get_pairs_line_number(bet_type: String, position_index: int) -> int:
	"""Получить номер позиции в объединённой линии пар
	
	Объединяет PairPlayer и PairBanker в одну линию, сортирует по X справа налево.
	
	Args:
		bet_type: "PairPlayer" или "PairBanker"
		position_index: Индекс позиции
		
	Returns:
		Номер позиции в объединённой линии (1 = самый правый)
	"""
	var all_pairs_positions = []
	
	# Собираем все позиции PairPlayer
	if ChipVisualManager.ALTERNATIVE_POSITIONS.has("PairPlayer"):
		var positions = ChipVisualManager.ALTERNATIVE_POSITIONS["PairPlayer"]
		for i in range(positions.size()):
			all_pairs_positions.append({
				"bet_type": "PairPlayer",
				"index": i,
				"x": positions[i].x
			})
	
	# Собираем все позиции PairBanker
	if ChipVisualManager.ALTERNATIVE_POSITIONS.has("PairBanker"):
		var positions = ChipVisualManager.ALTERNATIVE_POSITIONS["PairBanker"]
		for i in range(positions.size()):
			all_pairs_positions.append({
				"bet_type": "PairBanker",
				"index": i,
				"x": positions[i].x
			})
	
	# Сортируем по X (справа налево: больший X = меньший номер)
	all_pairs_positions.sort_custom(func(a, b): return a.x > b.x)
	
	# Находим номер нашей позиции (1 = самый правый)
	for i in range(all_pairs_positions.size()):
		if all_pairs_positions[i].bet_type == bet_type and \
		   all_pairs_positions[i].index == position_index:
			return i + 1  # Нумерация с 1
	
	return 0

