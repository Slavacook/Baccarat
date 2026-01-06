# res://tests/test_BetSorter.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ BetSorter
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var sorter: BetSorter
var position_calculator: LinePositionCalculator

# Мок для ставки
class MockBet:
	var _bet_type: String
	var _position_index: int
	var _is_won: bool = false
	
	func _init(bet_type: String, position_index: int, is_won: bool = false):
		_bet_type = bet_type
		_position_index = position_index
		_is_won = is_won
	
	func get_bet_type() -> String:
		return _bet_type
	
	func get_position_index() -> int:
		return _position_index
	
	func is_won() -> bool:
		return _is_won

# Мок для PayoutQueueManager
class MockPayoutQueueManager:
	var bets: Array = []
	
	func _init(bets_array: Array):
		bets = bets_array

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	position_calculator = LinePositionCalculator.new()
	sorter = BetSorter.new(position_calculator)

func after_each():
	"""Очистка после каждого теста"""
	sorter = null
	position_calculator = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_sorted_main_bets
# ═══════════════════════════════════════════════════════════════════════════

func test_get_sorted_main_bets_player_wins_collect_banker():
	"""Проверка: Player выиграл, собираем проигрышные Banker ставки"""
	# Arrange
	var bets = [
		MockBet.new("Banker", 0, false),  # Проиграл
		MockBet.new("Banker", 1, false),  # Проиграл
		MockBet.new("Player", 0, true),   # Выиграл (не собираем)
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var result = sorter.get_sorted_main_bets(manager, "Player", false)
	
	# Assert
	assert_eq(result.size(), 2, "Должно быть 2 проигрышные Banker ставки")
	assert_eq(result[0].get_bet_type(), "Banker", "Первая ставка должна быть Banker")
	assert_eq(result[1].get_bet_type(), "Banker", "Вторая ставка должна быть Banker")
	# Проверяем сортировку справа налево (меньший position_index = правее)
	assert_true(result[0].get_position_index() <= result[1].get_position_index(), "Сортировка справа налево")

func test_get_sorted_main_bets_banker_wins_pay_banker():
	"""Проверка: Banker выиграл, оплачиваем выигрышные Banker ставки"""
	# Arrange
	var bets = [
		MockBet.new("Banker", 0, true),   # Выиграл
		MockBet.new("Banker", 1, true),   # Выиграл
		MockBet.new("Player", 0, false),   # Проиграл (не оплачиваем)
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var result = sorter.get_sorted_main_bets(manager, "Banker", true)
	
	# Assert
	assert_eq(result.size(), 2, "Должно быть 2 выигрышные Banker ставки")
	assert_eq(result[0].get_bet_type(), "Banker", "Первая ставка должна быть Banker")
	assert_eq(result[1].get_bet_type(), "Banker", "Вторая ставка должна быть Banker")

func test_get_sorted_main_bets_tie_no_main_bets():
	"""Проверка: Tie - основные ставки не собираются и не оплачиваются"""
	# Arrange
	var bets = [
		MockBet.new("Player", 0, false),
		MockBet.new("Banker", 0, false),
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var collect_result = sorter.get_sorted_main_bets(manager, "Tie", false)
	var pay_result = sorter.get_sorted_main_bets(manager, "Tie", true)
	
	# Assert
	assert_eq(collect_result.size(), 0, "При Tie не должно быть ставок для сбора")
	assert_eq(pay_result.size(), 0, "При Tie не должно быть ставок для оплаты")

func test_get_sorted_main_bets_null_manager():
	"""Проверка: null менеджер возвращает пустой массив"""
	# Act
	var result = sorter.get_sorted_main_bets(null, "Player", false)
	
	# Assert
	assert_eq(result.size(), 0, "Должен вернуться пустой массив")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_sorted_tie_bets
# ═══════════════════════════════════════════════════════════════════════════

func test_get_sorted_tie_bets_collect_left_to_right():
	"""Проверка: сбор Tie ставок слева направо (обратный порядок)"""
	# Arrange
	var bets = [
		MockBet.new("Tie", 0, false),  # position_index 0
		MockBet.new("Tie", 1, false),  # position_index 1
		MockBet.new("Tie", 2, false),  # position_index 2
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var result = sorter.get_sorted_tie_bets(manager, false)
	
	# Assert
	assert_eq(result.size(), 3, "Должно быть 3 Tie ставки")
	# При сборе: слева направо (больший номер позиции = левее = идёт первым)
	var num0 = position_calculator.get_line_position_number(result[0].get_bet_type(), result[0].get_position_index())
	var num1 = position_calculator.get_line_position_number(result[1].get_bet_type(), result[1].get_position_index())
	var num2 = position_calculator.get_line_position_number(result[2].get_bet_type(), result[2].get_position_index())
	assert_true(num0 >= num1, "Сортировка слева направо при сборе (номер позиции)")
	assert_true(num1 >= num2, "Сортировка слева направо при сборе (номер позиции)")

func test_get_sorted_tie_bets_pay_right_to_left():
	"""Проверка: оплата Tie ставок справа налево (прямой порядок)"""
	# Arrange
	var bets = [
		MockBet.new("Tie", 0, true),  # position_index 0
		MockBet.new("Tie", 1, true),  # position_index 1
		MockBet.new("Tie", 2, true),  # position_index 2
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var result = sorter.get_sorted_tie_bets(manager, true)
	
	# Assert
	assert_eq(result.size(), 3, "Должно быть 3 Tie ставки")
	# При оплате: справа налево (меньший номер позиции = правее = идёт первым)
	var num0 = position_calculator.get_line_position_number(result[0].get_bet_type(), result[0].get_position_index())
	var num1 = position_calculator.get_line_position_number(result[1].get_bet_type(), result[1].get_position_index())
	var num2 = position_calculator.get_line_position_number(result[2].get_bet_type(), result[2].get_position_index())
	assert_true(num0 <= num1, "Сортировка справа налево при оплате (номер позиции)")
	assert_true(num1 <= num2, "Сортировка справа налево при оплате (номер позиции)")

func test_get_sorted_tie_bets_filters_by_won():
	"""Проверка: фильтрация по is_won"""
	# Arrange
	var bets = [
		MockBet.new("Tie", 0, true),   # Выиграл
		MockBet.new("Tie", 1, false),  # Проиграл
		MockBet.new("Tie", 2, true),   # Выиграл
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var winning_result = sorter.get_sorted_tie_bets(manager, true)
	var losing_result = sorter.get_sorted_tie_bets(manager, false)
	
	# Assert
	assert_eq(winning_result.size(), 2, "Должно быть 2 выигрышные Tie ставки")
	assert_eq(losing_result.size(), 1, "Должно быть 1 проигрышная Tie ставка")

func test_get_sorted_tie_bets_null_manager():
	"""Проверка: null менеджер возвращает пустой массив"""
	# Act
	var result = sorter.get_sorted_tie_bets(null, false)
	
	# Assert
	assert_eq(result.size(), 0, "Должен вернуться пустой массив")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_sorted_pair_bets
# ═══════════════════════════════════════════════════════════════════════════

func test_get_sorted_pair_bets_both_types():
	"""Проверка: сортировка PairPlayer и PairBanker вместе"""
	# Arrange
	var bets = [
		MockBet.new("PairPlayer", 0, false),
		MockBet.new("PairBanker", 0, false),
		MockBet.new("PairPlayer", 1, false),
		MockBet.new("PairBanker", 1, false),
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var result = sorter.get_sorted_pair_bets(manager, false)
	
	# Assert
	assert_eq(result.size(), 4, "Должно быть 4 пары ставки")
	# Проверяем что все ставки - пары
	for bet in result:
		var bet_type = bet.get_bet_type()
		assert_true(bet_type == "PairPlayer" or bet_type == "PairBanker", "Все ставки должны быть парами")

func test_get_sorted_pair_bets_right_to_left():
	"""Проверка: сортировка пар справа налево"""
	# Arrange
	var bets = [
		MockBet.new("PairPlayer", 2, false),  # position_index 2
		MockBet.new("PairPlayer", 0, false),  # position_index 0
		MockBet.new("PairPlayer", 1, false),  # position_index 1
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var result = sorter.get_sorted_pair_bets(manager, false)
	
	# Assert
	assert_eq(result.size(), 3, "Должно быть 3 пары ставки")
	# Сортировка справа налево (меньший номер позиции = правее = идёт первым)
	var num0 = position_calculator.get_line_position_number(result[0].get_bet_type(), result[0].get_position_index())
	var num1 = position_calculator.get_line_position_number(result[1].get_bet_type(), result[1].get_position_index())
	var num2 = position_calculator.get_line_position_number(result[2].get_bet_type(), result[2].get_position_index())
	assert_true(num0 <= num1, "Сортировка справа налево (номер позиции)")
	assert_true(num1 <= num2, "Сортировка справа налево (номер позиции)")

func test_get_sorted_pair_bets_filters_by_won():
	"""Проверка: фильтрация пар по is_won"""
	# Arrange
	var bets = [
		MockBet.new("PairPlayer", 0, true),   # Выиграл
		MockBet.new("PairBanker", 0, false),  # Проиграл
		MockBet.new("PairPlayer", 1, true),   # Выиграл
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var winning_result = sorter.get_sorted_pair_bets(manager, true)
	var losing_result = sorter.get_sorted_pair_bets(manager, false)
	
	# Assert
	assert_eq(winning_result.size(), 2, "Должно быть 2 выигрышные пары")
	assert_eq(losing_result.size(), 1, "Должно быть 1 проигрышная пара")

func test_get_sorted_pair_bets_excludes_non_pairs():
	"""Проверка: исключение не-пар из результата"""
	# Arrange
	var bets = [
		MockBet.new("PairPlayer", 0, false),
		MockBet.new("Player", 0, false),     # Не пара
		MockBet.new("PairBanker", 0, false),
		MockBet.new("Banker", 0, false),     # Не пара
	]
	var manager = MockPayoutQueueManager.new(bets)
	
	# Act
	var result = sorter.get_sorted_pair_bets(manager, false)
	
	# Assert
	assert_eq(result.size(), 2, "Должно быть только 2 пары ставки")
	for bet in result:
		var bet_type = bet.get_bet_type()
		assert_true(bet_type == "PairPlayer" or bet_type == "PairBanker", "Все ставки должны быть парами")

func test_get_sorted_pair_bets_null_manager():
	"""Проверка: null менеджер возвращает пустой массив"""
	# Act
	var result = sorter.get_sorted_pair_bets(null, false)
	
	# Assert
	assert_eq(result.size(), 0, "Должен вернуться пустой массив")

