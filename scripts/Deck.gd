# res://scripts/Deck.gd
class_name Deck

var cards: Array[Card] = []
var _rng: RandomNumberGenerator


func _init(dedicated_rng: RandomNumberGenerator = null) -> void:
	if dedicated_rng != null:
		_rng = dedicated_rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	shuffle()


func shuffle() -> void:
	cards.clear()
	for i in 8:
		for suit_index in 4:
			for value in range(1, 14):
				cards.append(Card.new(suit_index, value))
	_shuffle_array(cards, _rng)


## Пересобрать колоду с детерминированным RNG из hex-сида сервера (следующий раунд live-сессии).
func reseed_from_hex(seed_hex: String) -> void:
	var h: String = seed_hex.strip_edges()
	if h.is_empty():
		return
	_rng = LiveSeedRng.make_rng(h)
	shuffle()


func draw() -> Card:
	if cards.is_empty():
		shuffle()
	return cards.pop_back()


func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	var n: int = arr.size()
	if n <= 1:
		return
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
