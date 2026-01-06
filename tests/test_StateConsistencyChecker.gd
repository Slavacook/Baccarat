# res://tests/test_StateConsistencyChecker.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ StateConsistencyChecker
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var checker: StateConsistencyChecker

# Мок для ставки
class MockBet:
	var _bet_type: String
	var _position_index: int
	var _is_collected: bool = false
	var _is_won: bool = false
	var _is_paid: bool = false
	
	func _init(bet_type: String, position_index: int):
		_bet_type = bet_type
		_position_index = position_index
	
	func get_bet_type() -> String:
		return _bet_type
	
	func get_position_index() -> int:
		return _position_index
	
	func is_collected() -> bool:
		return _is_collected
	
	func set_collected(value: bool):
		_is_collected = value
	
	func is_won() -> bool:
		return _is_won
	
	func set_won(value: bool):
		_is_won = value
	
	func is_paid() -> bool:
		return _is_paid
	
	func set_paid(value: bool):
		_is_paid = value

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	checker = StateConsistencyChecker.new()

func after_each():
	"""Очистка после каждого теста"""
	checker = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Проверка согласованности состояния сбора
# ═══════════════════════════════════════════════════════════════════════════

func test_check_state_consistency_synced():
	"""Проверка согласованного состояния (кэш и bet совпадают)"""
	# Arrange
	var bet = MockBet.new("Player", 0)
	bet.set_collected(true)
	var bet_id = "Player_0"
	var collected_bets_by_id = {bet_id: true}
	
	# Act
	var result = checker.check_state_consistency(bet, bet_id, collected_bets_by_id)
	
	# Assert
	assert_true(result, "Согласованное состояние должно возвращать true")

func test_check_state_consistency_desynced_cache_missing():
	"""Проверка рассинхронизации: bet.is_collected=true, но нет в кэше"""
	# Arrange
	var bet = MockBet.new("Player", 0)
	bet.set_collected(true)
	var bet_id = "Player_0"
	var collected_bets_by_id = {}  # Пустой кэш
	
	# Act
	var result = checker.check_state_consistency(bet, bet_id, collected_bets_by_id)
	
	# Assert
	assert_false(result, "Рассинхронизация должна возвращать false")
	assert_true(collected_bets_by_id.has(bet_id), "Кэш должен быть обновлен")

func test_check_state_consistency_desynced_bet_not_collected():
	"""Проверка рассинхронизации: bet.is_collected=false, но есть в кэше"""
	# Arrange
	var bet = MockBet.new("Player", 0)
	bet.set_collected(false)
	var bet_id = "Player_0"
	var collected_bets_by_id = {bet_id: true}  # Есть в кэше
	
	# Act
	var result = checker.check_state_consistency(bet, bet_id, collected_bets_by_id)
	
	# Assert
	assert_false(result, "Рассинхронизация должна возвращать false")
	assert_false(collected_bets_by_id.has(bet_id), "Кэш должен быть очищен")

func test_check_state_consistency_null_bet():
	"""Проверка обработки null ставки"""
	# Arrange
	var bet = null
	var bet_id = "Player_0"
	var collected_bets_by_id = {}
	
	# Act
	var result = checker.check_state_consistency(bet, bet_id, collected_bets_by_id)
	
	# Assert
	assert_false(result, "Null ставка должна возвращать false")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Проверка согласованности состояния оплаты
# ═══════════════════════════════════════════════════════════════════════════

func test_check_payment_state_consistency_valid():
	"""Проверка валидного состояния оплаты (оплачена и выиграла)"""
	# Arrange
	var bet = MockBet.new("Player", 0)
	bet.set_won(true)
	bet.set_paid(true)
	
	# Act
	var result = checker.check_payment_state_consistency(bet)
	
	# Assert
	assert_true(result, "Валидное состояние оплаты должно возвращать true")

func test_check_payment_state_consistency_invalid_paid_not_won():
	"""Проверка невалидного состояния (оплачена, но не выиграла)"""
	# Arrange
	var bet = MockBet.new("Player", 0)
	bet.set_won(false)
	bet.set_paid(true)  # Оплачена, но не выиграла - ошибка!
	
	# Act - ожидаем ошибку (push_error через DebugLogger), но продолжаем тест
	# GUT будет показывать ошибку как "Unexpected Error", но тест должен пройти
	var result = checker.check_payment_state_consistency(bet)
	
	# Assert
	assert_false(result, "Оплаченная ставка без выигрыша должна возвращать false")
	# Тест проходит, даже если есть push_error в логе

func test_check_payment_state_consistency_not_paid():
	"""Проверка состояния когда ставка не оплачена"""
	# Arrange
	var bet = MockBet.new("Player", 0)
	bet.set_won(true)
	bet.set_paid(false)  # Не оплачена
	
	# Act
	var result = checker.check_payment_state_consistency(bet)
	
	# Assert
	assert_true(result, "Неоплаченная ставка должна возвращать true (нет ошибки)")

func test_check_payment_state_consistency_null_bet():
	"""Проверка обработки null ставки"""
	# Arrange
	var bet = null
	
	# Act
	var result = checker.check_payment_state_consistency(bet)
	
	# Assert
	assert_false(result, "Null ставка должна возвращать false")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Валидация всего состояния
# ═══════════════════════════════════════════════════════════════════════════

func test_validate_all_state_empty():
	"""Проверка валидации при пустом менеджере"""
	# Arrange
	var payout_queue_manager = null
	var collected_bets_by_id = {}
	var is_tie_push_bet = func(bet_type: String) -> bool: return false
	
	# Act
	var result = checker.validate_all_state(payout_queue_manager, collected_bets_by_id, is_tie_push_bet)
	
	# Assert
	assert_false(result.is_consistent, "Пустой менеджер должен быть не согласован")
	assert_gt(result.issues.size(), 0, "Должна быть хотя бы одна проблема")

func test_validate_all_state_consistent():
	"""Проверка валидации согласованного состояния"""
	# Arrange
	# Создаем мок менеджера с методом get_all_bets
	var mock_manager = MockPayoutQueueManager.new()
	var bet1 = MockBet.new("Player", 0)
	bet1.set_collected(true)
	bet1.set_won(true)
	bet1.set_paid(true)
	mock_manager.bets = [bet1]
	
	var collected_bets_by_id = {"Player_0": true}
	var is_tie_push_bet = func(bet_type: String) -> bool: return false
	
	# Act
	var result = checker.validate_all_state(mock_manager, collected_bets_by_id, is_tie_push_bet)
	
	# Assert
	assert_true(result.is_consistent, "Согласованное состояние должно быть валидным")
	assert_eq(result.issues.size(), 0, "Не должно быть проблем")

# Мок для PayoutQueueManager
class MockPayoutQueueManager:
	var bets: Array = []
	
	func get_all_bets() -> Array:
		return bets

