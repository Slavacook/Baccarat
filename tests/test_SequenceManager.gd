# res://tests/test_SequenceManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ SequenceManager
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var sequence_manager: SequenceManager
var bet_sorter: BetSorter
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
	bet_sorter = BetSorter.new(position_calculator)
	sequence_manager = SequenceManager.new(bet_sorter, position_calculator)

func after_each():
	"""Очистка после каждого теста"""
	sequence_manager = null
	bet_sorter = null
	position_calculator = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: initialize_collection_sequence
# ═══════════════════════════════════════════════════════════════════════════

func test_initialize_collection_sequence_player_wins():
	"""Проверка: инициализация последовательности сбора при победе Player"""
	# Arrange
	var bets = [
		MockBet.new("Banker", 0, false),  # Проиграл (собираем)
		MockBet.new("Banker", 1, false),  # Проиграл (собираем)
		MockBet.new("Player", 0, true),   # Выиграл (не собираем)
		MockBet.new("Tie", 0, false),     # Проиграл (собираем)
	]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(pos_idx * 100, 0)
	
	# Act
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	
	# Assert
	assert_eq(sequence_manager.collection_sequence["main"].size(), 2, "Должно быть 2 основные ставки для сбора")
	assert_eq(sequence_manager.collection_sequence["tie"].size(), 1, "Должна быть 1 Tie ставка для сбора")
	assert_eq(sequence_manager.collection_progress["main"], 0, "Прогресс должен быть сброшен")
	assert_eq(sequence_manager.collection_progress["tie"], 0, "Прогресс должен быть сброшен")

func test_initialize_collection_sequence_clears_previous():
	"""Проверка: очистка предыдущих последовательностей"""
	# Arrange
	var bets1 = [MockBet.new("Banker", 0, false)]
	var manager1 = MockPayoutQueueManager.new(bets1)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	# Инициализируем первый раз
	sequence_manager.initialize_collection_sequence(manager1, "Player", get_coords)
	sequence_manager.collection_progress["main"] = 1  # Изменяем прогресс
	
	# Arrange для второго раза
	var bets2 = [MockBet.new("Player", 0, false)]
	var manager2 = MockPayoutQueueManager.new(bets2)
	
	# Act
	sequence_manager.initialize_collection_sequence(manager2, "Banker", get_coords)
	
	# Assert
	assert_eq(sequence_manager.collection_progress["main"], 0, "Прогресс должен быть сброшен")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: initialize_payment_sequence
# ═══════════════════════════════════════════════════════════════════════════

func test_initialize_payment_sequence_banker_wins():
	"""Проверка: инициализация последовательности оплаты при победе Banker"""
	# Arrange
	var bets = [
		MockBet.new("Banker", 0, true),   # Выиграл (оплачиваем)
		MockBet.new("Banker", 1, true),   # Выиграл (оплачиваем)
		MockBet.new("Player", 0, false),  # Проиграл (не оплачиваем)
		MockBet.new("Tie", 0, true),      # Выиграл (оплачиваем)
	]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(pos_idx * 100, 0)
	
	# Act
	sequence_manager.initialize_payment_sequence(manager, "Banker", get_coords)
	
	# Assert
	assert_eq(sequence_manager.payment_sequence["main"].size(), 2, "Должно быть 2 основные ставки для оплаты")
	assert_eq(sequence_manager.payment_sequence["tie"].size(), 1, "Должна быть 1 Tie ставка для оплаты")
	assert_eq(sequence_manager.payment_progress["main"], 0, "Прогресс должен быть сброшен")
	assert_eq(sequence_manager.payment_progress["tie"], 0, "Прогресс должен быть сброшен")

func test_initialize_payment_sequence_clears_previous():
	"""Проверка: очистка предыдущих последовательностей оплаты"""
	# Arrange
	var bets1 = [MockBet.new("Banker", 0, true)]
	var manager1 = MockPayoutQueueManager.new(bets1)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	# Инициализируем первый раз
	sequence_manager.initialize_payment_sequence(manager1, "Banker", get_coords)
	sequence_manager.payment_progress["main"] = 1  # Изменяем прогресс
	
	# Arrange для второго раза
	var bets2 = [MockBet.new("Player", 0, true)]
	var manager2 = MockPayoutQueueManager.new(bets2)
	
	# Act
	sequence_manager.initialize_payment_sequence(manager2, "Player", get_coords)
	
	# Assert
	assert_eq(sequence_manager.payment_progress["main"], 0, "Прогресс должен быть сброшен")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_expected_next_bet
# ═══════════════════════════════════════════════════════════════════════════

func test_get_expected_next_bet_collection():
	"""Проверка: получение следующей ожидаемой ставки для сбора"""
	# Arrange
	var bets = [
		MockBet.new("Banker", 0, false),
		MockBet.new("Banker", 1, false),
	]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	
	# Act
	var first = sequence_manager.get_expected_next_bet("main", true)
	var second = sequence_manager.get_expected_next_bet("main", true)
	
	# Assert
	assert_not_null(first, "Первая ставка должна существовать")
	assert_eq(first.get_bet_type(), "Banker", "Первая ставка должна быть Banker")
	# Вторая должна быть той же (пока не увеличили прогресс)
	assert_eq(second.get_bet_type(), "Banker", "Вторая ставка должна быть той же (прогресс не увеличен)")

func test_get_expected_next_bet_payment():
	"""Проверка: получение следующей ожидаемой ставки для оплаты"""
	# Arrange
	var bets = [
		MockBet.new("Player", 0, true),
		MockBet.new("Player", 1, true),
	]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_payment_sequence(manager, "Player", get_coords)
	
	# Act
	var first = sequence_manager.get_expected_next_bet("main", false)
	
	# Assert
	assert_not_null(first, "Первая ставка должна существовать")
	assert_eq(first.get_bet_type(), "Player", "Первая ставка должна быть Player")

func test_get_expected_next_bet_after_increment():
	"""Проверка: получение следующей ставки после увеличения прогресса"""
	# Arrange
	var bets = [
		MockBet.new("Banker", 0, false),
		MockBet.new("Banker", 1, false),
	]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	
	# Act
	var first = sequence_manager.get_expected_next_bet("main", true)
	sequence_manager.increment_progress("main", true)
	var second = sequence_manager.get_expected_next_bet("main", true)
	
	# Assert
	assert_not_null(first, "Первая ставка должна существовать")
	assert_not_null(second, "Вторая ставка должна существовать")
	assert_eq(first.get_position_index(), 0, "Первая ставка должна быть с position_index 0")
	assert_eq(second.get_position_index(), 1, "Вторая ставка должна быть с position_index 1")

func test_get_expected_next_bet_empty_sequence():
	"""Проверка: получение следующей ставки из пустой последовательности"""
	# Arrange
	var bets: Array = []
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	
	# Act
	var result = sequence_manager.get_expected_next_bet("main", true)
	
	# Assert
	assert_null(result, "Должен вернуться null для пустой последовательности")

func test_get_expected_next_bet_all_processed():
	"""Проверка: получение следующей ставки когда все обработаны"""
	# Arrange
	var bets = [MockBet.new("Banker", 0, false)]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	sequence_manager.increment_progress("main", true)  # Увеличиваем прогресс
	
	# Act
	var result = sequence_manager.get_expected_next_bet("main", true)
	
	# Assert
	assert_null(result, "Должен вернуться null когда все обработаны")

func test_get_expected_next_bet_invalid_group():
	"""Проверка: получение следующей ставки для несуществующей группы"""
	# Arrange
	var bets = [MockBet.new("Banker", 0, false)]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	
	# Act
	var result = sequence_manager.get_expected_next_bet("invalid_group", true)
	
	# Assert
	assert_null(result, "Должен вернуться null для несуществующей группы")
	
	# Примечание: push_warning не обрабатывается GUT как ошибка, поэтому не нужно помечать его как обработанный

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: increment_progress
# ═══════════════════════════════════════════════════════════════════════════

func test_increment_progress_collection():
	"""Проверка: увеличение прогресса сбора"""
	# Arrange
	var bets = [MockBet.new("Banker", 0, false)]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	
	# Act
	assert_eq(sequence_manager.collection_progress["main"], 0, "Начальный прогресс должен быть 0")
	sequence_manager.increment_progress("main", true)
	
	# Assert
	assert_eq(sequence_manager.collection_progress["main"], 1, "Прогресс должен быть увеличен до 1")

func test_increment_progress_payment():
	"""Проверка: увеличение прогресса оплаты"""
	# Arrange
	var bets = [MockBet.new("Player", 0, true)]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_payment_sequence(manager, "Player", get_coords)
	
	# Act
	assert_eq(sequence_manager.payment_progress["main"], 0, "Начальный прогресс должен быть 0")
	sequence_manager.increment_progress("main", false)
	
	# Assert
	assert_eq(sequence_manager.payment_progress["main"], 1, "Прогресс должен быть увеличен до 1")

func test_increment_progress_multiple_times():
	"""Проверка: многократное увеличение прогресса"""
	# Arrange
	var bets = [
		MockBet.new("Banker", 0, false),
		MockBet.new("Banker", 1, false),
		MockBet.new("Banker", 2, false),
	]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	
	# Act
	sequence_manager.increment_progress("main", true)
	sequence_manager.increment_progress("main", true)
	sequence_manager.increment_progress("main", true)
	
	# Assert
	assert_eq(sequence_manager.collection_progress["main"], 3, "Прогресс должен быть 3")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: reset
# ═══════════════════════════════════════════════════════════════════════════

func test_reset_clears_all():
	"""Проверка: сброс очищает все последовательности и прогресс"""
	# Arrange
	var bets = [MockBet.new("Banker", 0, false)]
	var manager = MockPayoutQueueManager.new(bets)
	var get_coords = func(bet_type: String, pos_idx: int) -> Vector2:
		return Vector2(0, 0)
	
	sequence_manager.initialize_collection_sequence(manager, "Player", get_coords)
	sequence_manager.initialize_payment_sequence(manager, "Player", get_coords)
	sequence_manager.increment_progress("main", true)
	sequence_manager.increment_progress("main", false)
	
	# Act
	sequence_manager.reset()
	
	# Assert
	assert_eq(sequence_manager.collection_sequence.size(), 0, "Последовательности сбора должны быть очищены")
	assert_eq(sequence_manager.payment_sequence.size(), 0, "Последовательности оплаты должны быть очищены")
	assert_eq(sequence_manager.collection_progress["main"], 0, "Прогресс сбора должен быть сброшен")
	assert_eq(sequence_manager.payment_progress["main"], 0, "Прогресс оплаты должен быть сброшен")
