# res://tests/test_ChanceCardTriggerChecker.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ ChanceCardTriggerChecker
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var checker: ChanceCardTriggerChecker
var player_hand: Array[Card]
var banker_hand: Array[Card]

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	checker = ChanceCardTriggerChecker.new()
	player_hand = []
	banker_hand = []

func after_each():
	"""Очистка после каждого теста"""
	checker = null
	player_hand.clear()
	banker_hand.clear()

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: check_triggers_after_winner
# ═══════════════════════════════════════════════════════════════════════════

func test_check_triggers_after_winner_empty_hands():
	"""Проверка: пустые руки - не должно быть триггеров"""
	var result = checker.check_triggers_after_winner("Player", [], [])
	assert_false(result.get("heart_card", true), "Не должно быть триггера Heart Card")
	assert_false(result.get("heart_bet_card", true), "Не должно быть триггера Heart Bet Card")
	assert_false(result.get("revolver_card", true), "Не должно быть триггера Revolver Card")

func test_check_triggers_heart_card():
	"""Проверка: триггер Heart Card (банкир выиграл с 6)"""
	player_hand = [Card.new(Card.Suit.HEARTS, 3), Card.new(Card.Suit.DIAMONDS, 2)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 3), Card.new(Card.Suit.SPADES, 3)]  # 6 очков
	var result = checker.check_triggers_after_winner("Banker", player_hand, banker_hand)
	assert_true(result.get("heart_card", false), "Должен быть триггер Heart Card")
	assert_false(result.get("heart_bet_card", true), "Не должно быть триггера Heart Bet Card")

func test_check_triggers_heart_bet_card():
	"""Проверка: триггер Heart Bet Card (Tie)"""
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 1)]  # 8 очков = Tie
	var result = checker.check_triggers_after_winner("Tie", player_hand, banker_hand)
	assert_true(result.get("heart_bet_card", false), "Должен быть триггер Heart Bet Card")
	assert_false(result.get("heart_card", true), "Не должно быть триггера Heart Card")

func test_check_triggers_revolver_card():
	"""Проверка: триггер Revolver Card (все 6 карт по 0 очков)"""
	# Все карты 10, J, Q, K (дают 0 очков)
	player_hand = [
		Card.new(Card.Suit.HEARTS, 10),
		Card.new(Card.Suit.DIAMONDS, 11),
		Card.new(Card.Suit.CLUBS, 12)
	]
	banker_hand = [
		Card.new(Card.Suit.SPADES, 13),
		Card.new(Card.Suit.HEARTS, 10),
		Card.new(Card.Suit.DIAMONDS, 11)
	]
	var result = checker.check_triggers_after_winner("Player", player_hand, banker_hand)
	assert_true(result.get("revolver_card", false), "Должен быть триггер Revolver Card")

func test_check_triggers_no_triggers():
	"""Проверка: нет триггеров при обычной игре"""
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 2)]
	var result = checker.check_triggers_after_winner("Player", player_hand, banker_hand)
	assert_false(result.get("heart_card", true), "Не должно быть триггера Heart Card")
	assert_false(result.get("heart_bet_card", true), "Не должно быть триггера Heart Bet Card")
	assert_false(result.get("revolver_card", true), "Не должно быть триггера Revolver Card")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: check_triggers_after_deal
# ═══════════════════════════════════════════════════════════════════════════

func test_check_triggers_mystery_card():
	"""Проверка: триггер Mystery Card (пара тузов)"""
	player_hand = [Card.new(Card.Suit.HEARTS, 1), Card.new(Card.Suit.DIAMONDS, 1)]  # Пара тузов
	banker_hand = [Card.new(Card.Suit.CLUBS, 5), Card.new(Card.Suit.SPADES, 3)]
	var result = checker.check_triggers_after_deal(player_hand, banker_hand, false, false)
	assert_true(result.get("mystery_card", false), "Должен быть триггер Mystery Card")

func test_check_triggers_third_card_change():
	"""Проверка: триггер Third Card Change (две пары)"""
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 5)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 7)]
	var result = checker.check_triggers_after_deal(player_hand, banker_hand, true, true)
	assert_true(result.get("third_card_change", false), "Должен быть триггер Third Card Change")

func test_check_triggers_no_deal_triggers():
	"""Проверка: нет триггеров при обычной раздаче"""
	player_hand = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	banker_hand = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 2)]
	var result = checker.check_triggers_after_deal(player_hand, banker_hand, false, false)
	assert_false(result.get("mystery_card", true), "Не должно быть триггера Mystery Card")
	assert_false(result.get("third_card_change", true), "Не должно быть триггера Third Card Change")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Вспомогательные методы
# ═══════════════════════════════════════════════════════════════════════════

func test_check_aces_pair():
	"""Проверка: пара тузов определяется корректно"""
	var hand = [Card.new(Card.Suit.HEARTS, 1), Card.new(Card.Suit.DIAMONDS, 1)]
	# Используем внутренний метод через проверку триггеров
	var result = checker.check_triggers_after_deal(hand, [], false, false)
	assert_true(result.get("mystery_card", false), "Должна быть пара тузов")

func test_check_all_zero_cards():
	"""Проверка: все 6 карт по 0 очков определяется корректно"""
	player_hand = [
		Card.new(Card.Suit.HEARTS, 10),
		Card.new(Card.Suit.DIAMONDS, 11),
		Card.new(Card.Suit.CLUBS, 12)
	]
	banker_hand = [
		Card.new(Card.Suit.SPADES, 13),
		Card.new(Card.Suit.HEARTS, 10),
		Card.new(Card.Suit.DIAMONDS, 11)
	]
	var result = checker.check_triggers_after_winner("Player", player_hand, banker_hand)
	assert_true(result.get("revolver_card", false), "Должны быть все 6 карт по 0 очков")

