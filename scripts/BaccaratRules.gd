# res://scripts/BaccaratRules.gd
class_name BaccaratRules

static func hand_value(hand: Array[Card]) -> int:
	var total = 0
	for card in hand:
		total += card.get_point()
	return total % 10

static func is_natural(hand: Array[Card]) -> bool:
	# Натуральная - это 8 или 9 очков на ПЕРВЫХ ДВУХ картах!
	if hand.size() < 2:
		return false
	# Считаем только первые 2 карты
	var first_two_value = (hand[0].get_point() + hand[1].get_point()) % 10
	return first_two_value >= 8

static func player_should_draw(player_hand: Array[Card]) -> bool:
	return hand_value(player_hand) <= 5

static func banker_should_draw(
	banker_hand: Array[Card],
	player_drew: bool,
	player_third: Card
) -> bool:
	var b_score = hand_value(banker_hand)
	if b_score <= 2:
		return true
	if b_score >= 7:
		return false
	if not player_drew:
		return b_score <= 5

	var p3_val = player_third.get_point()
	match b_score:
		3: return p3_val != 8
		4: return p3_val in [2,3,4,5,6,7]
		5: return p3_val in [4,5,6,7]
		6: return p3_val in [6,7]
	return false

static func get_winner(player_hand: Array[Card], banker_hand: Array[Card]) -> String:
	var p = hand_value(player_hand)
	var b = hand_value(banker_hand)
	if p > b: return "Player"
	if b > p: return "Banker"
	return "Tie"

# ← Проверка натурала или исключений (6-7 комбинации)
static func has_natural_or_no_third(player_value: int, banker_value: int) -> bool:
	var natural = player_value >= 8 or banker_value >= 8
	var no_third = (player_value == 6 and banker_value == 6) or \
	               (player_value == 7 and banker_value == 7) or \
	               (player_value == 6 and banker_value == 7) or \
	               (player_value == 7 and banker_value == 6)
	return natural or no_third
