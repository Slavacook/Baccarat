# res://tests/test_game_phase_manager_simple.gd
# Упрощенная версия тестов (без моков UI)
extends GutTest

# ========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ========================================

# Создает типизированный массив карт (для строгой типизации Godot 4)
func _make_hand(cards: Array) -> Array[Card]:
	var hand: Array[Card] = []
	for c in cards:
		hand.append(c)
	return hand

# ========================================
# ПРОСТЫЕ ТЕСТЫ БЕЗ СЛОЖНЫХ ЗАВИСИМОСТЕЙ
# ========================================

# Тест 1: Проверка что BaccaratRules работает
func test_baccarat_rules_natural():
	var hand = _make_hand([Card.new(0, 5), Card.new(1, 4)])  # 5+4=9
	var value = BaccaratRules.hand_value(hand)
	assert_eq(value, 9, "Hand value should be 9")
	assert_true(BaccaratRules.is_natural(hand), "Should be natural with 9")

# Тест 2: Проверка создания карт
func test_card_creation():
	var card = Card.new(0, 5)  # 5 треф
	assert_not_null(card, "Card should be created")
	assert_eq(card.get_point(), 5, "Card point should be 5")

# Тест 3: Проверка колоды
func test_deck_creation():
	var deck = Deck.new()
	assert_not_null(deck, "Deck should be created")

	var card1 = deck.draw()
	var card2 = deck.draw()
	assert_not_null(card1, "First card should exist")
	assert_not_null(card2, "Second card should exist")

# Тест 4: Проверка правила "игрок берет при ≤5"
func test_player_draw_rule():
	var hand_5 = _make_hand([Card.new(0, 2), Card.new(1, 3)])  # 2+3=5
	var hand_6 = _make_hand([Card.new(0, 3), Card.new(1, 3)])  # 3+3=6

	assert_true(BaccaratRules.player_should_draw(hand_5), "Player should draw with 5")
	assert_false(BaccaratRules.player_should_draw(hand_6), "Player should NOT draw with 6")

# Тест 5: Проверка победителя
func test_get_winner():
	var player_9 = _make_hand([Card.new(0, 5), Card.new(1, 4)])  # 5+4=9
	var banker_6 = _make_hand([Card.new(2, 3), Card.new(3, 3)])  # 3+3=6

	var winner = BaccaratRules.get_winner(player_9, banker_6)
	assert_eq(winner, "Player", "Player should win with 9 vs 6")

# Тест 6: Проверка ничьи
func test_get_winner_tie():
	var player_7 = _make_hand([Card.new(0, 4), Card.new(1, 3)])  # 4+3=7
	var banker_7 = _make_hand([Card.new(2, 5), Card.new(3, 2)])  # 5+2=7

	var winner = BaccaratRules.get_winner(player_7, banker_7)
	assert_eq(winner, "Tie", "Should be tie with 7 vs 7")

# Тест 7: Проверка особой комбинации has_natural_or_no_third
func test_has_natural_or_no_third_with_8():
	var has = BaccaratRules.has_natural_or_no_third(8, 5)
	assert_true(has, "Should detect natural 8")

func test_has_natural_or_no_third_with_9():
	var has = BaccaratRules.has_natural_or_no_third(3, 9)
	assert_true(has, "Should detect natural 9")

func test_has_natural_or_no_third_6v6():
	var has = BaccaratRules.has_natural_or_no_third(6, 6)
	assert_true(has, "Should detect special case 6v6")

func test_has_natural_or_no_third_7v7():
	var has = BaccaratRules.has_natural_or_no_third(7, 7)
	assert_true(has, "Should detect special case 7v7")

func test_has_natural_or_no_third_normal_case():
	var has = BaccaratRules.has_natural_or_no_third(5, 3)
	assert_false(has, "Should NOT detect natural for 5 vs 3")
