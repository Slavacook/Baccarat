# res://scripts/HandManager.gd
# Менеджер для управления руками игрока и банкира
# Инкапсулирует все операции с картами в руках

class_name HandManager

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ
# ═══════════════════════════════════════════════════════════════════════════

var player_hand: Array[Card] = []
var banker_hand: Array[Card] = []

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНЫЕ ОПЕРАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func reset() -> void:
	"""Очистить обе руки (начало нового раунда)"""
	player_hand.clear()
	banker_hand.clear()


func deal_first_four(deck: Deck) -> void:
	"""Раздать первые 4 карты (2 игроку, 2 банкиру)

	Args:
		deck: Колода для взятия карт
	"""
	player_hand = [deck.draw(), deck.draw()]
	banker_hand = [deck.draw(), deck.draw()]


func add_player_card(card: Card) -> void:
	"""Добавить третью карту игроку

	Args:
		card: Карта для добавления
	"""
	player_hand.append(card)


func add_banker_card(card: Card) -> void:
	"""Добавить третью карту банкиру

	Args:
		card: Карта для добавления
	"""
	banker_hand.append(card)


# ═══════════════════════════════════════════════════════════════════════════
# ПОЛУЧЕНИЕ ДАННЫХ
# ═══════════════════════════════════════════════════════════════════════════

func get_player_hand() -> Array[Card]:
	"""Получить руку игрока (копию)"""
	return player_hand.duplicate()


func get_banker_hand() -> Array[Card]:
	"""Получить руку банкира (копию)"""
	return banker_hand.duplicate()


func get_player_hand_ref() -> Array[Card]:
	"""Получить ссылку на руку игрока (для чтения, без копирования)"""
	return player_hand


func get_banker_hand_ref() -> Array[Card]:
	"""Получить ссылку на руку банкира (для чтения, без копирования)"""
	return banker_hand


func get_player_size() -> int:
	"""Получить количество карт у игрока"""
	return player_hand.size()


func get_banker_size() -> int:
	"""Получить количество карт у банкира"""
	return banker_hand.size()


func get_player_card(index: int) -> Card:
	"""Получить конкретную карту игрока по индексу

	Args:
		index: Индекс карты (0, 1, 2)

	Returns:
		Карта или null если индекс вне диапазона
	"""
	if index < 0 or index >= player_hand.size():
		return null
	return player_hand[index]


func get_banker_card(index: int) -> Card:
	"""Получить конкретную карту банкира по индексу

	Args:
		index: Индекс карты (0, 1, 2)

	Returns:
		Карта или null если индекс вне диапазона
	"""
	if index < 0 or index >= banker_hand.size():
		return null
	return banker_hand[index]


func get_player_third_card() -> Card:
	"""Получить третью карту игрока (если есть)

	Returns:
		Третья карта или null
	"""
	if player_hand.size() >= 3:
		return player_hand[2]
	return null


func get_banker_third_card() -> Card:
	"""Получить третью карту банкира (если есть)

	Returns:
		Третья карта или null
	"""
	if banker_hand.size() >= 3:
		return banker_hand[2]
	return null


func has_player_third_card() -> bool:
	"""Проверить наличие третьей карты у игрока"""
	return player_hand.size() >= 3


func has_banker_third_card() -> bool:
	"""Проверить наличие третьей карты у банкира"""
	return banker_hand.size() >= 3


# ═══════════════════════════════════════════════════════════════════════════
# ВЫЧИСЛЕНИЕ ОЧКОВ
# ═══════════════════════════════════════════════════════════════════════════

func get_player_score() -> int:
	"""Получить очки игрока через BaccaratRules"""
	return BaccaratRules.hand_value(player_hand)


func get_banker_score() -> int:
	"""Получить очки банкира через BaccaratRules"""
	return BaccaratRules.hand_value(banker_hand)


func get_player_initial_score() -> int:
	"""Получить очки игрока по первым 2 картам"""
	if player_hand.size() < 2:
		return 0
	return BaccaratRules.hand_value([player_hand[0], player_hand[1]])


func get_banker_initial_score() -> int:
	"""Получить очки банкира по первым 2 картам"""
	if banker_hand.size() < 2:
		return 0
	return BaccaratRules.hand_value([banker_hand[0], banker_hand[1]])


# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКИ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func are_hands_empty() -> bool:
	"""Проверить пусты ли обе руки"""
	return player_hand.size() == 0 or banker_hand.size() == 0


func has_natural() -> bool:
	"""Проверить наличие натуральной (8 или 9) у игрока или банкира"""
	return BaccaratRules.is_natural(player_hand) or BaccaratRules.is_natural(banker_hand)


# ═══════════════════════════════════════════════════════════════════════════
# ВОССТАНОВЛЕНИЕ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func restore_from_arrays(p_hand: Array[Card], b_hand: Array[Card]) -> void:
	"""Восстановить руки из массивов (для возврата из PayoutScene)

	Args:
		p_hand: Рука игрока
		b_hand: Рука банкира
	"""
	player_hand = p_hand.duplicate()
	banker_hand = b_hand.duplicate()


# ═══════════════════════════════════════════════════════════════════════════
# DEBUG
# ═══════════════════════════════════════════════════════════════════════════

func _to_string() -> String:
	"""Строковое представление для отладки"""
	return "HandManager(Player: %d карт [%d очков], Banker: %d карт [%d очков])" % [
		player_hand.size(),
		get_player_score(),
		banker_hand.size(),
		get_banker_score()
	]
