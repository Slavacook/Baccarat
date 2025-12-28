# res://scripts/GuestSectorMapper.gd
# Статический класс для маппинга секторов стола (1-6) на позиции фишек
# Каждый сектор соответствует одному гостю

class_name GuestSectorMapper

# ═══════════════════════════════════════════════════════════════════════════
# МАППИНГ СЕКТОРОВ НА ПОЗИЦИИ
# ═══════════════════════════════════════════════════════════════════════════
# Сектор 1: левая часть стола (самый левый)
# Сектор 2: левая-центр
# Сектор 3: центр-левая
# Сектор 4: центр (основные позиции)
# Сектор 5: центр-правая
# Сектор 6: правая часть стола (самый правый)
#
# Для каждого сектора используется одна позиция для каждого типа ставки

const SECTOR_POSITIONS = {
	1: {  # Сектор 1 (самый левый)
		"Player": [4],         # Индекс из ALTERNATIVE_POSITIONS["Player"]
		"Banker": [1],         # Индекс из ALTERNATIVE_POSITIONS["Banker"]
		"Tie": [1],            # Индекс из ALTERNATIVE_POSITIONS["Tie"]
		"PairPlayer": [1],     # Индекс из ALTERNATIVE_POSITIONS["PairPlayer"]
		"PairBanker": [1]      # Индекс из ALTERNATIVE_POSITIONS["PairBanker"]
	},
	2: {  # Сектор 2
		"Player": [3],
		"Banker": [2],
		"Tie": [2],
		"PairPlayer": [2],
		"PairBanker": [2]
	},
	3: {  # Сектор 3
		"Player": [2],
		"Banker": [3],
		"Tie": [3],
		"PairPlayer": [3],
		"PairBanker": [3]
	},
	4: {  # Сектор 4 (центр, основные позиции)
		"Player": [0],
		"Banker": [0],
		"Tie": [0],
		"PairPlayer": [0],
		"PairBanker": [0]
	},
	5: {  # Сектор 5
		"Player": [1],
		"Banker": [4],
		"Tie": [4],
		"PairPlayer": [4],
		"PairBanker": [4]
	},
	6: {  # Сектор 6 (самый правый)
		"Player": [5],
		"Banker": [5],
		"Tie": [5],
		"PairPlayer": [5],
		"PairBanker": [5]
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Получить позицию (position_index) для типа ставки в секторе
# Использует первую позицию из пары для Player/Banker
static func get_position_index(sector: int, bet_type: String) -> int:
	"""Получить индекс позиции для типа ставки в секторе
	
	Args:
		sector: Номер сектора (1-6)
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
	
	Returns:
		Индекс позиции из ALTERNATIVE_POSITIONS или -1 если не найдено
	"""
	if sector < 1 or sector > 6:
		push_error("GuestSectorMapper: неверный сектор %d (должен быть 1-6)" % sector)
		return -1
	
	if not SECTOR_POSITIONS.has(sector):
		push_error("GuestSectorMapper: сектор %d не найден" % sector)
		return -1
	
	var sector_data = SECTOR_POSITIONS[sector]
	if not sector_data.has(bet_type):
		push_error("GuestSectorMapper: тип ставки '%s' не найден для сектора %d" % [bet_type, sector])
		return -1
	
	var positions = sector_data[bet_type]
	if positions.is_empty():
		return -1
	
	# Возвращаем первую (и единственную) позицию
	return positions[0]

# ← Получить координаты позиции для типа ставки в секторе
static func get_position_coordinates(sector: int, bet_type: String) -> Vector2:
	"""Получить координаты позиции для типа ставки в секторе
	
	Args:
		sector: Номер сектора (1-6)
		bet_type: Тип ставки
	
	Returns:
		Vector2 координаты или Vector2.ZERO если не найдено
	"""
	var position_index = get_position_index(sector, bet_type)
	if position_index < 0:
		return Vector2.ZERO
	
	if not ChipVisualManager.ALTERNATIVE_POSITIONS.has(bet_type):
		return Vector2.ZERO
	
	var positions = ChipVisualManager.ALTERNATIVE_POSITIONS[bet_type]
	if position_index >= positions.size():
		return Vector2.ZERO
	
	return positions[position_index]

# ← Получить все позиции для сектора (для отладки)
static func get_all_positions_for_sector(sector: int) -> Dictionary:
	"""Получить все позиции для сектора
	
	Returns:
		Dictionary с ключами bet_type и значениями Array[int] индексов
	"""
	if sector < 1 or sector > 6:
		return {}
	
	if not SECTOR_POSITIONS.has(sector):
		return {}
	
	return SECTOR_POSITIONS[sector].duplicate()

# ← Проверить, валиден ли сектор
static func is_valid_sector(sector: int) -> bool:
	return sector >= 1 and sector <= 6

# ← Определить сектор по position_index и bet_type (обратный маппинг)
static func get_sector_from_position(bet_type: String, position_index: int) -> int:
	"""Определить сектор гостя по position_index и типу ставки
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции из ALTERNATIVE_POSITIONS
	
	Returns:
		Номер сектора (1-6) или -1 если не найден
	"""
	# Проверяем все секторы
	for sector in range(1, 7):
		if not SECTOR_POSITIONS.has(sector):
			continue
		
		var sector_data = SECTOR_POSITIONS[sector]
		if not sector_data.has(bet_type):
			continue
		
		var positions = sector_data[bet_type]
		# Проверяем позицию в секторе
		if position_index in positions:
			return sector
	
	return -1
