extends GutTest

# Создает типизированный массив карт (для строгой типизации Godot 4)
func _make_hand(cards: Array) -> Array[Card]:
	var hand: Array[Card] = []
	for c in cards:
		hand.append(c)
	return hand

func test_natural():
	var hand = _make_hand([Card.new(0, 5), Card.new(1, 4)])  # 5 + 4 = 9
	assert_eq(BaccaratRules.hand_value(hand), 9)
	assert_true(BaccaratRules.is_natural(hand))

func test_player_draw():
	var hand = _make_hand([Card.new(0,5), Card.new(1,0)])  # 5 + 0 = 5
	assert_true(BaccaratRules.player_should_draw(hand))

func test_banker_draw():
	var banker = _make_hand([Card.new(0,3), Card.new(1,3)])  # 3+3=6
	var player_third = Card.new(2,7)  # 7
	assert_true(BaccaratRules.banker_should_draw(banker, true, player_third))
