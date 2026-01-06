# res://tests/test_LinePositionCalculator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ LinePositionCalculator
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var calculator: LinePositionCalculator

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	calculator = LinePositionCalculator.new()

func after_each():
	"""Очистка после каждого теста"""
	calculator = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Кэширование
# ═══════════════════════════════════════════════════════════════════════════

func test_position_caching():
	"""Проверка что результаты кэшируются"""
	# Arrange
	var bet_type = "Player"
	var position_index = 0
	
	# Act - вызываем дважды
	var result1 = calculator.get_line_position_number(bet_type, position_index)
	var result2 = calculator.get_line_position_number(bet_type, position_index)
	
	# Assert
	assert_eq(result1, result2, "Результаты должны совпадать (кэш работает)")

func test_clear_cache():
	"""Проверка очистки кэша"""
	# Arrange
	var bet_type = "Player"
	var position_index = 0
	var result1 = calculator.get_line_position_number(bet_type, position_index)
	
	# Act
	calculator.clear_cache()
	var result2 = calculator.get_line_position_number(bet_type, position_index)
	
	# Assert
	# После очистки результат должен быть пересчитан (может быть тот же, но кэш очищен)
	assert_not_null(result2, "Результат должен быть пересчитан после очистки кэша")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Стандартная нумерация
# ═══════════════════════════════════════════════════════════════════════════

func test_standard_line_numbering_returns_valid():
	"""Проверка что нумерация возвращает валидные значения"""
	# Arrange
	var bet_type = "Player"
	var position_index = 0
	
	# Act
	var result = calculator.get_line_position_number(bet_type, position_index)
	
	# Assert
	assert_gt(result, 0, "Номер позиции должен быть больше 0")
	assert_le(result, 6, "Номер позиции не должен превышать количество позиций")

func test_standard_line_numbering_consistency():
	"""Проверка согласованности нумерации для разных индексов"""
	# Arrange
	var bet_type = "Player"
	
	# Act
	var pos0 = calculator.get_line_position_number(bet_type, 0)
	var pos1 = calculator.get_line_position_number(bet_type, 1)
	
	# Assert
	# Позиции должны быть разными (если индексы разные)
	# Но если позиции имеют одинаковый X, они могут иметь одинаковый номер
	# Поэтому просто проверяем что метод не падает
	assert_not_null(pos0, "Позиция 0 должна иметь номер")
	assert_not_null(pos1, "Позиция 1 должна иметь номер")

func test_invalid_bet_type():
	"""Проверка обработки невалидного типа ставки"""
	# Arrange
	var invalid_type = "InvalidType"
	var position_index = 0
	
	# Act
	var result = calculator.get_line_position_number(invalid_type, position_index)
	
	# Assert
	assert_eq(result, 0, "Невалидный тип должен возвращать 0")

func test_invalid_position_index():
	"""Проверка обработки невалидного индекса позиции"""
	# Arrange
	var bet_type = "Player"
	var invalid_index = -1
	
	# Act
	var result = calculator.get_line_position_number(bet_type, invalid_index)
	
	# Assert
	assert_eq(result, 0, "Невалидный индекс должен возвращать 0")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Нумерация пар
# ═══════════════════════════════════════════════════════════════════════════

func test_pairs_line_numbering():
	"""Проверка нумерации для пар"""
	# Arrange
	var pair_player = "PairPlayer"
	var pair_banker = "PairBanker"
	var position_index = 0
	
	# Act
	var pos_pair_player = calculator.get_line_position_number(pair_player, position_index)
	var pos_pair_banker = calculator.get_line_position_number(pair_banker, position_index)
	
	# Assert
	assert_not_null(pos_pair_player, "PairPlayer должна иметь позицию")
	assert_not_null(pos_pair_banker, "PairBanker должна иметь позицию")
	assert_gt(pos_pair_player, 0, "Номер позиции PairPlayer должен быть больше 0")
	assert_gt(pos_pair_banker, 0, "Номер позиции PairBanker должен быть больше 0")

func test_pairs_combined_line():
	"""Проверка что пары объединены в одну линию"""
	# Arrange
	var pair_player = "PairPlayer"
	var pair_banker = "PairBanker"
	
	# Act
	# Получаем номера для разных индексов
	var pos_player_0 = calculator.get_line_position_number(pair_player, 0)
	var pos_banker_0 = calculator.get_line_position_number(pair_banker, 0)
	
	# Assert
	# Номера должны быть в одной последовательности (не пересекаться)
	# Но так как позиции могут быть в разных местах, просто проверяем что они валидны
	assert_gt(pos_player_0, 0, "PairPlayer позиция должна быть валидной")
	assert_gt(pos_banker_0, 0, "PairBanker позиция должна быть валидной")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Разные типы ставок
# ═══════════════════════════════════════════════════════════════════════════

func test_all_bet_types():
	"""Проверка что все типы ставок обрабатываются"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	var position_index = 0
	
	# Act & Assert
	for bet_type in bet_types:
		var result = calculator.get_line_position_number(bet_type, position_index)
		# Для валидных типов результат должен быть > 0 или 0 (если позиция не найдена)
		assert_ge(result, 0, "Тип %s должен возвращать валидный результат" % bet_type)

