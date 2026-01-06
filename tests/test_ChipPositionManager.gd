# res://tests/test_ChipPositionManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ ChipPositionManager
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var position_manager: ChipPositionManager

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	position_manager = ChipPositionManager.new()

func after_each():
	"""Очистка после каждого теста"""
	position_manager = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Получение альтернативных позиций
# ═══════════════════════════════════════════════════════════════════════════

func test_get_alternative_positions_valid():
	"""Проверка получения альтернативных позиций для валидного типа"""
	# Arrange
	var bet_type = "Player"
	
	# Act
	var positions = position_manager.get_alternative_positions(bet_type)
	
	# Assert
	assert_not_null(positions, "Должен вернуться массив позиций")
	assert_false(positions.is_empty(), "Массив позиций не должен быть пустым")
	assert_gt(positions.size(), 0, "Должна быть хотя бы одна позиция")

func test_get_alternative_positions_all_types():
	"""Проверка получения позиций для всех типов ставок"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	
	# Act & Assert
	for bet_type in bet_types:
		var positions = position_manager.get_alternative_positions(bet_type)
		assert_false(positions.is_empty(), "Тип %s должен иметь позиции" % bet_type)
		# Проверяем что все позиции - это Vector2
		for pos in positions:
			assert_true(pos is Vector2, "Позиция должна быть Vector2")

func test_get_alternative_positions_invalid():
	"""Проверка обработки невалидного типа ставки"""
	# Arrange
	var invalid_type = "InvalidType"
	
	# Act
	var positions = position_manager.get_alternative_positions(invalid_type)
	
	# Assert
	assert_true(positions.is_empty(), "Невалидный тип должен возвращать пустой массив")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Случайная позиция
# ═══════════════════════════════════════════════════════════════════════════

func test_get_random_position_valid():
	"""Проверка получения случайной позиции для валидного типа"""
	# Arrange
	var bet_type = "Player"
	
	# Act
	var position = position_manager.get_random_position(bet_type)
	
	# Assert
	assert_not_null(position, "Должна вернуться позиция")
	assert_ne(position, Vector2.ZERO, "Позиция не должна быть Vector2.ZERO")

func test_get_random_position_invalid():
	"""Проверка обработки невалидного типа"""
	# Arrange
	var invalid_type = "InvalidType"
	
	# Act - ожидаем предупреждение, но продолжаем тест
	var position = position_manager.get_random_position(invalid_type)
	
	# Assert
	assert_eq(position, Vector2.ZERO, "Невалидный тип должен возвращать Vector2.ZERO")

func test_get_random_position_in_range():
	"""Проверка что случайная позиция находится в списке альтернативных"""
	# Arrange
	var bet_type = "Player"
	var alternative_positions = position_manager.get_alternative_positions(bet_type)
	
	# Act - получаем 10 случайных позиций
	var random_positions: Array[Vector2] = []
	for i in range(10):
		random_positions.append(position_manager.get_random_position(bet_type))
	
	# Assert
	# Все случайные позиции должны быть в списке альтернативных
	for random_pos in random_positions:
		var found = false
		for alt_pos in alternative_positions:
			if random_pos == alt_pos:
				found = true
				break
		assert_true(found, "Случайная позиция должна быть в списке альтернативных")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Позиция по индексу
# ═══════════════════════════════════════════════════════════════════════════

func test_get_position_at_index_valid():
	"""Проверка получения позиции по валидному индексу"""
	# Arrange
	var bet_type = "Player"
	var index = 0
	
	# Act
	var position = position_manager.get_position_at_index(bet_type, index)
	
	# Assert
	assert_not_null(position, "Должна вернуться позиция")
	assert_ne(position, Vector2.ZERO, "Позиция не должна быть Vector2.ZERO")

func test_get_position_at_index_invalid_index():
	"""Проверка обработки невалидного индекса"""
	# Arrange
	var bet_type = "Player"
	var invalid_index = -1
	
	# Act
	var position = position_manager.get_position_at_index(bet_type, invalid_index)
	
	# Assert
	assert_eq(position, Vector2.ZERO, "Невалидный индекс должен возвращать Vector2.ZERO")

func test_get_position_at_index_out_of_range():
	"""Проверка обработки индекса вне диапазона"""
	# Arrange
	var bet_type = "Player"
	var positions_count = position_manager.get_positions_count(bet_type)
	var out_of_range_index = positions_count + 10
	
	# Act
	var position = position_manager.get_position_at_index(bet_type, out_of_range_index)
	
	# Assert
	assert_eq(position, Vector2.ZERO, "Индекс вне диапазона должен возвращать Vector2.ZERO")

func test_get_position_at_index_consistency():
	"""Проверка согласованности позиций по индексу"""
	# Arrange
	var bet_type = "Player"
	var alternative_positions = position_manager.get_alternative_positions(bet_type)
	
	# Act & Assert
	for i in range(alternative_positions.size()):
		var pos_by_index = position_manager.get_position_at_index(bet_type, i)
		var pos_from_array = alternative_positions[i]
		assert_eq(pos_by_index, pos_from_array, "Позиция по индексу %d должна совпадать с позицией из массива" % i)

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Проверка наличия позиций
# ═══════════════════════════════════════════════════════════════════════════

func test_has_positions_valid():
	"""Проверка наличия позиций для валидных типов"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	
	# Act & Assert
	for bet_type in bet_types:
		var has = position_manager.has_positions(bet_type)
		assert_true(has, "Тип %s должен иметь позиции" % bet_type)

func test_has_positions_invalid():
	"""Проверка наличия позиций для невалидного типа"""
	# Arrange
	var invalid_type = "InvalidType"
	
	# Act
	var has = position_manager.has_positions(invalid_type)
	
	# Assert
	assert_false(has, "Невалидный тип не должен иметь позиций")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Количество позиций
# ═══════════════════════════════════════════════════════════════════════════

func test_get_positions_count_valid():
	"""Проверка получения количества позиций для валидного типа"""
	# Arrange
	var bet_type = "Player"
	
	# Act
	var count = position_manager.get_positions_count(bet_type)
	
	# Assert
	assert_gt(count, 0, "Количество позиций должно быть больше 0")
	assert_eq(count, position_manager.get_alternative_positions(bet_type).size(), "Количество должно совпадать с размером массива")

func test_get_positions_count_invalid():
	"""Проверка получения количества позиций для невалидного типа"""
	# Arrange
	var invalid_type = "InvalidType"
	
	# Act
	var count = position_manager.get_positions_count(invalid_type)
	
	# Assert
	assert_eq(count, 0, "Невалидный тип должен возвращать 0")

