# res://scripts/utils/ChipPositionManager.gd
# Менеджер позиций фишек
# 
# Отвечает за:
# - Управление позициями фишек (ALTERNATIVE_POSITIONS)
# - Применение случайных позиций
# - Сброс позиций на дефолтные
# - Получение альтернативных позиций

class_name ChipPositionManager

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ - АЛЬТЕРНАТИВНЫЕ ПОЗИЦИИ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

const ALTERNATIVE_POSITIONS = {
	"Player": [
		Vector2(795, -35),    # Гость 4 (сектор 4, основная позиция из сцены)
		Vector2(1450, 5),   # Гость 5 (сектор 5)
		Vector2(480, -38),    # Гость 3 (сектор 3)
		Vector2(-370, 5),    # Гость 2 (сектор 2)
		Vector2(-670, 200),   # Гость 1 (сектор 1)
		Vector2(1715, 150),   # Гость 6 (сектор 6)
	],
	"Banker": [
		Vector2(754, 47),      # Гость 4 (сектор 4, основная позиция из сцены)
		Vector2(-520, 180),   # Гость 1 (сектор 1)
		Vector2(-270, 55),     # Гость 2 (сектор 2)
		Vector2(350, 40),     # Гость 3 (сектор 3)
		Vector2(1500, 105),   # Гость 5 (сектор 5)
		Vector2(1660, 220),   # Гость 6 (сектор 6)
	],
	"Tie": [
		Vector2(897, 129),    # Гость 4 (сектор 4, основная позиция из сцены)
		Vector2(-480, 260),   # Гость 1 (сектор 1)
		Vector2(-200, 130),   # Гость 2 (сектор 2)
		Vector2(350, 125),    # Гость 3 (сектор 3)
		Vector2(1350, 130),   # Гость 5 (сектор 5)
		Vector2(1540, 230),   # Гость 6 (сектор 6)
	],
	"PairPlayer": [
		Vector2(817, 208),    # Гость 4 (сектор 4, основная позиция из сцены)
		Vector2(-390, 300),   # Гость 1 (сектор 1)
		Vector2(80, 208),     # Гость 2 (сектор 2)
		Vector2(480, 208),    # Гость 3 (сектор 3)
		Vector2(1250, 208),   # Гость 5 (сектор 5)
		Vector2(1565, 440),   # Гость 6 (сектор 6)
	],
	"PairBanker": [
		Vector2(656, 207),    # Гость 4 (сектор 4, основная позиция из сцены)
		Vector2(-480, 440),   # Гость 1 (сектор 1)
		Vector2(-160, 208),   # Гость 2 (сектор 2)
		Vector2(300, 208),    # Гость 3 (сектор 3)
		Vector2(1030, 208),   # Гость 5 (сектор 5)
		Vector2(1455, 285),   # Гость 6 (сектор 6)
	]
}

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_alternative_positions(bet_type: String) -> Array:
	"""Получить список альтернативных позиций для типа ставки
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		Массив Vector2 с альтернативными позициями или пустой массив если позиции не найдены
	"""
	if ALTERNATIVE_POSITIONS.has(bet_type):
		return ALTERNATIVE_POSITIONS[bet_type]
	return []

func get_random_position(bet_type: String) -> Vector2:
	"""Получить случайную позицию для типа ставки
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		Случайная позиция Vector2 или Vector2.ZERO если позиции не найдены
	"""
	if not ALTERNATIVE_POSITIONS.has(bet_type):
		push_warning("ChipPositionManager: нет альтернативных позиций для '%s'" % bet_type)
		return Vector2.ZERO
	
	var positions = ALTERNATIVE_POSITIONS[bet_type]
	if positions.is_empty():
		return Vector2.ZERO
	
	var random_index = randi() % positions.size()
	return positions[random_index]

func get_position_at_index(bet_type: String, index: int) -> Vector2:
	"""Получить позицию по индексу
	
	Args:
		bet_type: Тип ставки
		index: Индекс позиции (0-based)
		
	Returns:
		Позиция Vector2 или Vector2.ZERO если индекс невалиден
	"""
	if not ALTERNATIVE_POSITIONS.has(bet_type):
		return Vector2.ZERO
	
	var positions = ALTERNATIVE_POSITIONS[bet_type]
	if index < 0 or index >= positions.size():
		return Vector2.ZERO
	
	return positions[index]

func has_positions(bet_type: String) -> bool:
	"""Проверить, есть ли позиции для типа ставки
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		true если позиции есть, false иначе
	"""
	return ALTERNATIVE_POSITIONS.has(bet_type) and not ALTERNATIVE_POSITIONS[bet_type].is_empty()

func get_positions_count(bet_type: String) -> int:
	"""Получить количество позиций для типа ставки
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		Количество позиций или 0 если позиции не найдены
	"""
	if not ALTERNATIVE_POSITIONS.has(bet_type):
		return 0
	return ALTERNATIVE_POSITIONS[bet_type].size()
