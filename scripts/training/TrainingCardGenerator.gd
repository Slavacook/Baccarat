# res://scripts/training/TrainingCardGenerator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ГЕНЕРАТОР КАРТ ДЛЯ РЕЖИМА ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════
# Создаёт руки с заданным значением очков и сценарии для этапов обучения.
# Работает с переданной колодой (Deck); не создаёт свою.
# ═══════════════════════════════════════════════════════════════════════════

class_name TrainingCardGenerator
extends RefCounted

var deck: Deck

func _init(deck_ref: Deck) -> void:
	deck = deck_ref

# ═══════════════════════════════════════════════════════════════════════════
# ГЕНЕРАЦИЯ РУКИ С ЗАДАННЫМ ЗНАЧЕНИЕМ ОЧКОВ
# ═══════════════════════════════════════════════════════════════════════════

## Генерирует руку из двух карт с заданным значением очков по правилам баккара.
## value — желаемое значение (0–9); hand_size не используется (в баккара считаются первые 2 карты).
## Карты добираются из колоды до тех пор, пока не получится нужная сумма (mod 10).
func generate_hand_with_value(value: int, _hand_size: int = 2) -> Array[Card]:
	value = clampi(value, 0, 9)
	var hand: Array[Card] = []
	var first: Card = deck.draw()
	hand.append(first)
	var need_second_point: int = (value - first.get_point() + 10) % 10
	var second: Card = deck.draw()
	while second.get_point() != need_second_point:
		second = deck.draw()
	hand.append(second)
	return hand

# ═══════════════════════════════════════════════════════════════════════════
# СЦЕНАРИИ ДЛЯ ЭТАПОВ
# ═══════════════════════════════════════════════════════════════════════════

## Генерирует сценарий «натуральная победа»: у игрока или банкира 8 или 9 очков.
## Третья карта никому не нужна (expected_answer: "no").
## Returns: { player_hand: Array[Card], banker_hand: Array[Card], expected_answer: "no" }
func generate_natural_win() -> Dictionary:
	var natural_side: bool = randf() >= 0.5
	var player_hand: Array[Card]
	var banker_hand: Array[Card]

	if natural_side:
		var natural_value: int = 8 if randf() >= 0.5 else 9
		var other_value: int = randi() % 10
		player_hand = generate_hand_with_value(natural_value)
		banker_hand = generate_hand_with_value(other_value)
	else:
		var natural_value: int = 8 if randf() >= 0.5 else 9
		var other_value: int = randi() % 10
		banker_hand = generate_hand_with_value(natural_value)
		player_hand = generate_hand_with_value(other_value)

	return {
		"player_hand": player_hand,
		"banker_hand": banker_hand,
		"expected_answer": "no"
	}
