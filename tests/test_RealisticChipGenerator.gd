# res://tests/test_RealisticChipGenerator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ RealisticChipGenerator
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var generator: RealisticChipGenerator
var position_manager: ChipPositionManager

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	generator = RealisticChipGenerator.new()
	position_manager = ChipPositionManager.new()

func after_each():
	"""Очистка после каждого теста"""
	generator = null
	position_manager = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Получение диапазонов
# ═══════════════════════════════════════════════════════════════════════════

func test_get_ranges_for_bet_type():
	"""Проверка получения диапазонов для типа ставки"""
	# Arrange
	var bet_type = "Player"
	
	# Act
	var ranges = generator.get_ranges_for_bet_type(bet_type)
	
	# Assert
	assert_not_null(ranges, "Должен вернуться массив диапазонов")
	assert_false(ranges.is_empty(), "Массив диапазонов не должен быть пустым")
	assert_eq(ranges.size(), 6, "Должно быть 6 диапазонов")

func test_get_ranges_for_bet_type_all_types():
	"""Проверка что все типы ставок возвращают одинаковые диапазоны"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	
	# Act
	var first_ranges = generator.get_ranges_for_bet_type(bet_types[0])
	
	# Assert
	for bet_type in bet_types:
		var ranges = generator.get_ranges_for_bet_type(bet_type)
		assert_eq(ranges.size(), first_ranges.size(), "Все типы должны иметь одинаковое количество диапазонов")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Генерация случайного количества
# ═══════════════════════════════════════════════════════════════════════════

func test_generate_random_count_valid():
	"""Проверка генерации случайного количества для валидного типа"""
	# Arrange
	var bet_type = "Player"
	
	# Act
	var count = generator.generate_random_count(bet_type, position_manager)
	
	# Assert
	assert_ge(count, 0, "Количество должно быть >= 0")
	assert_le(count, 6, "Количество не должно превышать количество позиций")

func test_generate_random_count_all_types():
	"""Проверка генерации для всех типов ставок"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	
	# Act & Assert
	for bet_type in bet_types:
		var count = generator.generate_random_count(bet_type, position_manager)
		assert_ge(count, 0, "Тип %s должен генерировать валидное количество" % bet_type)
		assert_le(count, 6, "Тип %s не должен превышать количество позиций" % bet_type)

func test_generate_random_count_in_range():
	"""Проверка что сгенерированное количество находится в допустимом диапазоне"""
	# Arrange
	var bet_type = "Player"
	var ranges = generator.get_ranges_for_bet_type(bet_type)
	
	# Act - генерируем 100 раз
	var counts: Array[int] = []
	for i in range(100):
		counts.append(generator.generate_random_count(bet_type, position_manager))
	
	# Assert
	# Находим минимальный и максимальный диапазоны
	var min_range = ranges[0][0]
	var max_range = ranges[ranges.size() - 1][1]
	
	for count in counts:
		assert_ge(count, min_range, "Количество должно быть >= минимального диапазона")
		assert_le(count, max_range, "Количество должно быть <= максимального диапазона")

func test_generate_random_count_respects_positions_limit():
	"""Проверка что количество не превышает количество позиций"""
	# Arrange
	var bet_type = "Player"
	var positions_count = position_manager.get_positions_count(bet_type)
	
	# Act - генерируем 50 раз
	for i in range(50):
		var count = generator.generate_random_count(bet_type, position_manager)
		# Assert
		assert_le(count, positions_count, "Количество не должно превышать количество позиций")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Выбор случайных позиций
# ═══════════════════════════════════════════════════════════════════════════

func test_select_random_positions_valid():
	"""Проверка выбора случайных позиций для валидного типа"""
	# Arrange
	var bet_type = "Player"
	var count = 3
	
	# Act
	var positions = generator.select_random_positions(bet_type, count, position_manager)
	
	# Assert
	assert_not_null(positions, "Должен вернуться массив позиций")
	assert_eq(positions.size(), count, "Количество выбранных позиций должно совпадать с запрошенным")

func test_select_random_positions_zero_count():
	"""Проверка обработки нулевого количества"""
	# Arrange
	var bet_type = "Player"
	var count = 0
	
	# Act
	var positions = generator.select_random_positions(bet_type, count, position_manager)
	
	# Assert
	assert_true(positions.is_empty(), "Нулевое количество должно возвращать пустой массив")

func test_select_random_positions_negative_count():
	"""Проверка обработки отрицательного количества"""
	# Arrange
	var bet_type = "Player"
	var count = -1
	
	# Act
	var positions = generator.select_random_positions(bet_type, count, position_manager)
	
	# Assert
	assert_true(positions.is_empty(), "Отрицательное количество должно возвращать пустой массив")

func test_select_random_positions_unique():
	"""Проверка что выбранные позиции уникальны"""
	# Arrange
	var bet_type = "Player"
	var count = 3
	
	# Act
	var positions = generator.select_random_positions(bet_type, count, position_manager)
	
	# Assert
	# Проверяем что все индексы уникальны
	var unique_positions: Array[int] = []
	for pos in positions:
		assert_false(unique_positions.has(pos), "Позиция %d не должна повторяться" % pos)
		unique_positions.append(pos)

func test_select_random_positions_in_range():
	"""Проверка что выбранные позиции находятся в допустимом диапазоне"""
	# Arrange
	var bet_type = "Player"
	var positions_count = position_manager.get_positions_count(bet_type)
	var count = 3
	
	# Act
	var positions = generator.select_random_positions(bet_type, count, position_manager)
	
	# Assert
	for pos in positions:
		assert_ge(pos, 0, "Индекс позиции должен быть >= 0")
		assert_lt(pos, positions_count, "Индекс позиции должен быть < количества позиций")

func test_select_random_positions_max_count():
	"""Проверка выбора максимального количества позиций"""
	# Arrange
	var bet_type = "Player"
	var positions_count = position_manager.get_positions_count(bet_type)
	var count = positions_count + 10  # Больше чем доступно
	
	# Act
	var positions = generator.select_random_positions(bet_type, count, position_manager)
	
	# Assert
	assert_le(positions.size(), positions_count, "Количество выбранных позиций не должно превышать доступное")

func test_select_random_positions_all_types():
	"""Проверка выбора позиций для всех типов ставок"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	var count = 2
	
	# Act & Assert
	for bet_type in bet_types:
		var positions = generator.select_random_positions(bet_type, count, position_manager)
		assert_eq(positions.size(), count, "Тип %s должен вернуть запрошенное количество позиций" % bet_type)

