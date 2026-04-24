# res://scripts/HandManager.gd
# Менеджер для управления руками игрока и банкира
# Инкапсулирует все операции с картами в руках

class_name HandManager

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ ПОЛЯ (инкапсулированные)
# ═══════════════════════════════════════════════════════════════════════════

var _player_hand: Array[Card] = []
var _banker_hand: Array[Card] = []

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНЫЕ ОПЕРАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func reset() -> void:
	"""Очистить обе руки (начало нового раунда)"""
	_player_hand.clear()
	_banker_hand.clear()


func deal_first_four(deck: Deck) -> void:
	"""Раздать первые 4 карты (2 игроку, 2 банкиру)

	Args:
		deck: Колода для взятия карт
	
	Note:
		Если включён TestCardsManager, используются предустановленные карты
	"""
	# В онлайн-сессии все четыре карты только из колоды — иначе RNG расходится между клиентами.
	var use_test_presets: bool = true
	if Engine.has_singleton("SessionManager"):
		var sm: Node = Engine.get_singleton("SessionManager")
		if sm.current_mode == sm.Mode.ONLINE:
			use_test_presets = false

	var p1: Card = null
	var p2: Card = null
	var b1: Card = null
	var b2: Card = null
	if use_test_presets:
		p1 = TestCardsManager.get_test_card("player1")
		p2 = TestCardsManager.get_test_card("player2")
		b1 = TestCardsManager.get_test_card("banker1")
		b2 = TestCardsManager.get_test_card("banker2")
	
	_player_hand = [
		p1 if p1 else deck.draw(),
		p2 if p2 else deck.draw()
	]
	_banker_hand = [
		b1 if b1 else deck.draw(),
		b2 if b2 else deck.draw()
	]
	
func add_player_card(card: Card) -> void:
	"""Добавить третью карту игроку

	Args:
		card: Карта для добавления
	"""
	_player_hand.append(card)


func add_banker_card(card: Card) -> void:
	"""Добавить третью карту банкиру

	Args:
		card: Карта для добавления
	"""
	_banker_hand.append(card)


func remove_third_cards() -> void:
	"""Убрать третьи карты (для Third Card Change)
	
	Обрезает руки до 2 карт, удаляя третьи карты если они есть.
	"""
	if _player_hand.size() > 2:
		_player_hand.resize(2)
		print("🔄 Третья карта игрока убрана")
	if _banker_hand.size() > 2:
		_banker_hand.resize(2)
		print("🔄 Третья карта банкира убрана")


# ═══════════════════════════════════════════════════════════════════════════
# ПОЛУЧЕНИЕ ДАННЫХ
# ═══════════════════════════════════════════════════════════════════════════

func get_player_hand() -> Array[Card]:
	"""Получить руку игрока (копию)"""
	return _player_hand.duplicate()


func get_banker_hand() -> Array[Card]:
	"""Получить руку банкира (копию)"""
	return _banker_hand.duplicate()


func get_player_hand_ref() -> Array[Card]:
	"""Получить ссылку на руку игрока (для чтения, без копирования)"""
	return _player_hand


func get_banker_hand_ref() -> Array[Card]:
	"""Получить ссылку на руку банкира (для чтения, без копирования)"""
	return _banker_hand


func get_player_size() -> int:
	"""Получить количество карт у игрока"""
	return _player_hand.size()


func get_banker_size() -> int:
	"""Получить количество карт у банкира"""
	return _banker_hand.size()


func get_player_card(index: int) -> Card:
	"""Получить конкретную карту игрока по индексу

	Args:
		index: Индекс карты (0, 1, 2)

	Returns:
		Карта или null если индекс вне диапазона
	"""
	if index < 0 or index >= _player_hand.size():
		return null
	return _player_hand[index]


func get_banker_card(index: int) -> Card:
	"""Получить конкретную карту банкира по индексу

	Args:
		index: Индекс карты (0, 1, 2)

	Returns:
		Карта или null если индекс вне диапазона
	"""
	if index < 0 or index >= _banker_hand.size():
		return null
	return _banker_hand[index]


func get_player_third_card() -> Card:
	"""Получить третью карту игрока (если есть)

	Returns:
		Третья карта или null
	"""
	if _player_hand.size() >= 3:
		return _player_hand[2]
	return null


func get_banker_third_card() -> Card:
	"""Получить третью карту банкира (если есть)

	Returns:
		Третья карта или null
	"""
	if _banker_hand.size() >= 3:
		return _banker_hand[2]
	return null


func has_player_third_card() -> bool:
	"""Проверить наличие третьей карты у игрока"""
	return _player_hand.size() >= 3


func has_banker_third_card() -> bool:
	"""Проверить наличие третьей карты у банкира"""
	return _banker_hand.size() >= 3


# ═══════════════════════════════════════════════════════════════════════════
# ВЫЧИСЛЕНИЕ ОЧКОВ
# ═══════════════════════════════════════════════════════════════════════════

func get_player_score() -> int:
	"""Получить очки игрока через BaccaratRules"""
	return BaccaratRules.hand_value(_player_hand)


func get_banker_score() -> int:
	"""Получить очки банкира через BaccaratRules"""
	return BaccaratRules.hand_value(_banker_hand)


func get_player_initial_score() -> int:
	"""Получить очки игрока по первым 2 картам"""
	if _player_hand.size() < 2:
		return 0
	return BaccaratRules.hand_value([_player_hand[0], _player_hand[1]])


func get_banker_initial_score() -> int:
	"""Получить очки банкира по первым 2 картам"""
	if _banker_hand.size() < 2:
		return 0
	return BaccaratRules.hand_value([_banker_hand[0], _banker_hand[1]])


# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКИ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func are_hands_empty() -> bool:
	"""Проверить пусты ли обе руки"""
	return _player_hand.size() == 0 or _banker_hand.size() == 0


func has_natural() -> bool:
	"""Проверить наличие натуральной (8 или 9) у игрока или банкира"""
	return BaccaratRules.is_natural(_player_hand) or BaccaratRules.is_natural(_banker_hand)


# ═══════════════════════════════════════════════════════════════════════════
# ВОССТАНОВЛЕНИЕ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func restore_from_arrays(p_hand: Array[Card], b_hand: Array[Card]) -> void:
	"""Восстановить руки из массивов (для возврата из PayoutScene)

	Args:
		p_hand: Рука игрока
		b_hand: Рука банкира
	"""
	_player_hand = p_hand.duplicate()
	_banker_hand = b_hand.duplicate()


# ═══════════════════════════════════════════════════════════════════════════
# СЛУЖЕБНОЕ ПРЕДСТАВЛЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════

func _to_string() -> String:
	"""Строковое представление состояния рук"""
	return "HandManager(Player: %d карт [%d очков], Banker: %d карт [%d очков])" % [
		_player_hand.size(),
		get_player_score(),
		_banker_hand.size(),
		get_banker_score()
	]
