# res://scripts/CardTextureManager.gd
class_name CardTextureManager

const SUIT_TO_FOLDER = {
	Card.Suit.CLUBS:    "clubs",
	Card.Suit.HEARTS:   "hearts",
	Card.Suit.SPADES:   "spades",
	Card.Suit.DIAMONDS: "diamonds"
}

const VALUE_TO_NAME = {
	1:  "ace", 2: "2", 3: "3", 4: "4", 5: "5",
	6: "6", 7: "7", 8: "8", 9: "9", 10: "10",
	11: "jack", 12: "queen", 13: "king"
}

var _texture_cache = {}
var config: GameConfig

func _init(conf: GameConfig):
	config = conf

func get_card_texture(suit: int, value: int) -> Texture2D:
	var suit_name = SUIT_TO_FOLDER.get(suit, "")
	var value_name = VALUE_TO_NAME.get(value, "")
	if suit_name == "" or value_name == "":
		push_error("Invalid suit or value: %d, %d" % [suit, value])
		return null

	# Формируем путь к файлу карты
	var path = "res://assets/cards/%s_%s.png" % [value_name, suit_name]
	print("Card path: ", path) # Для отладки

	# Кэширование
	if _texture_cache.has(path):
		return _texture_cache[path]

	# Загружаем ресурс
	var texture = load(path)
	if texture:
		_texture_cache[path] = texture
	else:
		push_error("Card texture not loaded: %s" % path)
	return texture

func get_back_texture() -> Texture2D:
	# Загружаем выбранный стиль рубашки из настроек
	var style = SaveManager.instance.load_card_back_style()
	var path = "res://assets/cards/back/card_back.png"  # По умолчанию Tiger

	if style == "leopard":
		path = "res://assets/cards/back/card_back_2.png"

	return _load_cached(path)

func get_back_question_texture() -> Texture2D:
	return _load_cached(config.back_question_path)

func get_back_exclamation_texture() -> Texture2D:
	return _load_cached(config.back_exclamation_path)

func _load_cached(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex = load(path)
	if tex:
		_texture_cache[path] = tex
	else:
		push_error("Back texture not loaded: %s" % path)
	return tex
