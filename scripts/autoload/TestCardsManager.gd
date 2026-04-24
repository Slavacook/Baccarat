# res://scripts/autoload/TestCardsManager.gd
# Менеджер ручной раздачи для учебных сценариев
# Autoload синглтон

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

## Названия мастей для UI
const SUIT_NAMES = ["♣ Трефы", "♥ Черви", "♠ Пики", "♦ Бубны"]

## Названия значений для UI
const VALUE_NAMES = ["—", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Включён ли режим ручной раздачи
var enabled: bool = false

## Предустановленные карты (словарь с suit и value, или null = случайная)
var _test_cards: Dictionary = {
	"player1": null,
	"player2": null,
	"banker1": null,
	"banker2": null
}

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func set_enabled(value: bool) -> void:
	"""Включить/выключить режим ручной раздачи"""
	enabled = value

func set_test_card(position: String, suit: int, value: int) -> void:
	"""Установить тестовую карту
	position: "player1", "player2", "banker1", "banker2"
	suit: 0=Clubs, 1=Hearts, 2=Spades, 3=Diamonds
	value: 0=случайная, 1=A, 2-10, 11=J, 12=Q, 13=K
	"""
	if value <= 0:
		_test_cards[position] = null
	else:
		_test_cards[position] = {"suit": suit, "value": value}

func get_test_card(position: String) -> Card:
	"""Получить тестовую карту или null если не задана/отключено"""
	if not enabled:
		return null
	
	var card_data = _test_cards.get(position)
	if card_data == null:
		return null
	
	return Card.new(card_data["suit"], card_data["value"])

func clear_all() -> void:
	"""Сбросить все предустановленные карты"""
	_test_cards = {
		"player1": null,
		"player2": null,
		"banker1": null,
		"banker2": null
	}
	enabled = false

func get_card_data(position: String) -> Dictionary:
	"""Получить данные карты для UI (suit, value)"""
	var data = _test_cards.get(position)
	if data == null:
		return {"suit": 0, "value": 0}
	return data

func is_position_set(position: String) -> bool:
	"""Проверить, задана ли карта для позиции"""
	return _test_cards.get(position) != null

func get_summary() -> String:
	"""Получить текстовое описание настроек"""
	if not enabled:
		return "Ручная раздача отключена"
	
	var parts = []
	for pos in ["player1", "player2", "banker1", "banker2"]:
		var data = _test_cards.get(pos)
		if data:
			var suit_symbol = ["♣", "♥", "♠", "♦"][data["suit"]]
			var value_name = VALUE_NAMES[data["value"]]
			parts.append("%s: %s%s" % [pos, value_name, suit_symbol])
		else:
			parts.append("%s: ?" % pos)
	
	return "\n".join(parts)
