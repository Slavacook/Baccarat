# res://tests/test_WinnerSelectionValidator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ WinnerSelectionValidator
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var validator: WinnerSelectionValidator
var player_hand: Array[Card]
var banker_hand: Array[Card]

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	validator = WinnerSelectionValidator.new()
	player_hand = []
	banker_hand = []

func after_each():
	"""Очистка после каждого теста"""
	validator = null
	player_hand.clear()
	banker_hand.clear()

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Нет выбора
# ═══════════════════════════════════════════════════════════════════════════

func test_no_selection():
	"""Проверка: победитель не выбран - должен вернуть needs_selection=true"""
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 2)]
	
	var result = validator.validate_winner_selection("", player_hand, banker_hand)
	assert_false(result.get("is_valid", true), "Не должна быть валидна без выбора")
	assert_true(result.get("needs_selection", false), "Должен быть флаг needs_selection")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Правильный выбор
# ═══════════════════════════════════════════════════════════════════════════

func test_correct_selection_player_wins():
	"""Проверка: правильный выбор Player"""
	# Player: 5+3=8, Banker: 7+2=9 → Banker выигрывает
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 2)]
	
	var result = validator.validate_winner_selection("Banker", player_hand, banker_hand)
	assert_true(result.get("is_valid", false), "Должна быть валидна")
	assert_eq(result.get("actual_winner", ""), "Banker", "Фактический победитель должен быть Banker")
	assert_eq(result.get("error_type", ""), "", "Не должно быть ошибки")

func test_correct_selection_banker_wins():
	"""Проверка: правильный выбор Banker"""
	# Player: 7+2=9, Banker: 5+3=8 → Player выигрывает
	player_hand = [Card.new(Card.Suit.HEARTS, 7), Card.new(Card.Suit.DIAMONDS, 2)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 5), Card.new(Card.Suit.SPADES, 3)]
	
	var result = validator.validate_winner_selection("Player", player_hand, banker_hand)
	assert_true(result.get("is_valid", false), "Должна быть валидна")
	assert_eq(result.get("actual_winner", ""), "Player", "Фактический победитель должен быть Player")

func test_correct_selection_tie():
	"""Проверка: правильный выбор Tie"""
	# Player: 5+3=8, Banker: 7+1=8 → Tie
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 1)]
	
	var result = validator.validate_winner_selection("Tie", player_hand, banker_hand)
	assert_true(result.get("is_valid", false), "Должна быть валидна")
	assert_eq(result.get("actual_winner", ""), "Tie", "Фактический победитель должен быть Tie")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Неправильный выбор
# ═══════════════════════════════════════════════════════════════════════════

func test_incorrect_selection_player_instead_of_banker():
	"""Проверка: неправильный выбор Player вместо Banker"""
	# Player: 5+3=8, Banker: 7+2=9 → Banker выигрывает
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 2)]
	
	var result = validator.validate_winner_selection("Player", player_hand, banker_hand)
	assert_false(result.get("is_valid", true), "Не должна быть валидна")
	assert_eq(result.get("error_type", ""), "winner_wrong", "Тип ошибки должен быть winner_wrong")
	assert_eq(result.get("error_message", ""), "ERR_WRONG_WINNER", "Сообщение должно быть ERR_WRONG_WINNER")
	assert_eq(result.get("error_message_params", []), ["Banker"], "Параметры должны содержать Banker")

func test_incorrect_selection_banker_instead_of_player():
	"""Проверка: неправильный выбор Banker вместо Player"""
	# Player: 7+2=9, Banker: 5+3=8 → Player выигрывает
	player_hand = [Card.new(Card.Suit.HEARTS, 7), Card.new(Card.Suit.DIAMONDS, 2)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 5), Card.new(Card.Suit.SPADES, 3)]
	
	var result = validator.validate_winner_selection("Banker", player_hand, banker_hand)
	assert_false(result.get("is_valid", true), "Не должна быть валидна")
	assert_eq(result.get("error_type", ""), "winner_wrong", "Тип ошибки должен быть winner_wrong")
	assert_eq(result.get("actual_winner", ""), "Player", "Фактический победитель должен быть Player")

func test_incorrect_selection_tie_instead_of_player():
	"""Проверка: неправильный выбор Tie вместо Player"""
	# Player: 7+2=9, Banker: 5+3=8 → Player выигрывает
	player_hand = [Card.new(Card.Suit.HEARTS, 7), Card.new(Card.Suit.DIAMONDS, 2)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 5), Card.new(Card.Suit.SPADES, 3)]
	
	var result = validator.validate_winner_selection("Tie", player_hand, banker_hand)
	assert_false(result.get("is_valid", true), "Не должна быть валидна")
	assert_eq(result.get("error_type", ""), "winner_wrong", "Тип ошибки должен быть winner_wrong")

func test_incorrect_selection_player_instead_of_tie():
	"""Проверка: неправильный выбор Player вместо Tie"""
	# Player: 5+3=8, Banker: 7+1=8 → Tie
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 1)]
	
	var result = validator.validate_winner_selection("Player", player_hand, banker_hand)
	assert_false(result.get("is_valid", true), "Не должна быть валидна")
	assert_eq(result.get("actual_winner", ""), "Tie", "Фактический победитель должен быть Tie")
	assert_eq(result.get("error_message", ""), "Ошибка! Неправильный выбор. Игалите", "Сообщение должно быть для Tie")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: С третьими картами
# ═══════════════════════════════════════════════════════════════════════════

func test_correct_selection_with_third_cards():
	"""Проверка: правильный выбор с третьими картами"""
	# Player: 5+3+2=10→0, Banker: 7+2+1=10→0 → Tie
	player_hand = [
		Card.new(Card.Suit.HEARTS, 5),
		Card.new(Card.Suit.DIAMONDS, 3),
		Card.new(Card.Suit.CLUBS, 2)
	]
	banker_hand = [
		Card.new(Card.Suit.CLUBS, 7),
		Card.new(Card.Suit.SPADES, 2),
		Card.new(Card.Suit.HEARTS, 1)
	]
	
	var result = validator.validate_winner_selection("Tie", player_hand, banker_hand)
	assert_true(result.get("is_valid", false), "Должна быть валидна")
	assert_eq(result.get("actual_winner", ""), "Tie", "Фактический победитель должен быть Tie")

func test_incorrect_selection_with_third_cards():
	"""Проверка: неправильный выбор с третьими картами"""
	# Player: 5+3+2=10→0, Banker: 7+2+1=10→0 → Tie
	player_hand = [
		Card.new(Card.Suit.HEARTS, 5),
		Card.new(Card.Suit.DIAMONDS, 3),
		Card.new(Card.Suit.CLUBS, 2)
	]
	banker_hand = [
		Card.new(Card.Suit.CLUBS, 7),
		Card.new(Card.Suit.SPADES, 2),
		Card.new(Card.Suit.HEARTS, 1)
	]
	
	var result = validator.validate_winner_selection("Player", player_hand, banker_hand)
	assert_false(result.get("is_valid", true), "Не должна быть валидна")
	assert_eq(result.get("actual_winner", ""), "Tie", "Фактический победитель должен быть Tie")

