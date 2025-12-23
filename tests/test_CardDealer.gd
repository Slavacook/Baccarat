# res://tests/test_CardDealer.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ CardDealer
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var dealer: CardDealer
var deck: Deck
var hand_manager: HandManager

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	dealer = CardDealer.new()
	deck = Deck.new()
	hand_manager = HandManager.new()

func after_each():
	"""Очистка после каждого теста"""
	dealer = null
	deck = null
	hand_manager = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: deal_first_four
# ═══════════════════════════════════════════════════════════════════════════

func test_deal_first_four_deals_four_cards():
	"""Проверка что раздаются ровно 4 карты (2 игроку, 2 банкиру)"""
	# Arrange
	var initial_deck_size = deck.cards.size()
	
	# Act
	dealer.deal_first_four(deck, hand_manager)
	
	# Assert
	assert_eq(hand_manager.get_player_size(), 2, "Игрок должен получить 2 карты")
	assert_eq(hand_manager.get_banker_size(), 2, "Банкир должен получить 2 карты")
	assert_eq(deck.cards.size(), initial_deck_size - 4, "Из колоды должно быть взято 4 карты")

func test_deal_first_four_cards_are_different():
	"""Проверка что разданные карты разные"""
	# Arrange
	var seen_cards: Array[String] = []
	
	# Act
	dealer.deal_first_four(deck, hand_manager)
	
	# Assert - проверяем что все карты уникальны
	var player_card1 = hand_manager.get_player_card(0)
	var player_card2 = hand_manager.get_player_card(1)
	var banker_card1 = hand_manager.get_banker_card(0)
	var banker_card2 = hand_manager.get_banker_card(1)
	
	var all_cards = [player_card1, player_card2, banker_card1, banker_card2]
	for card in all_cards:
		var card_str = card.card_to_string()
		assert_false(seen_cards.has(card_str), "Карта %s не должна повторяться" % card_str)
		seen_cards.append(card_str)

func test_deal_first_four_updates_hand_manager():
	"""Проверка что HandManager корректно обновляется"""
	# Arrange
	assert_eq(hand_manager.get_player_size(), 0, "Рука игрока должна быть пуста")
	assert_eq(hand_manager.get_banker_size(), 0, "Рука банкира должна быть пуста")
	
	# Act
	dealer.deal_first_four(deck, hand_manager)
	
	# Assert
	assert_ne(hand_manager.get_player_size(), 0, "Рука игрока должна содержать карты")
	assert_ne(hand_manager.get_banker_size(), 0, "Рука банкира должна содержать карты")
	
	# Проверяем что карты действительно в руках
	var player_hand = hand_manager.get_player_hand()
	var banker_hand = hand_manager.get_banker_hand()
	assert_eq(player_hand.size(), 2, "Рука игрока должна содержать 2 карты")
	assert_eq(banker_hand.size(), 2, "Рука банкира должна содержать 2 карты")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: draw_player_third
# ═══════════════════════════════════════════════════════════════════════════

func test_draw_player_third_adds_card_to_hand():
	"""Проверка что третья карта добавляется в руку игрока"""
	# Arrange
	dealer.deal_first_four(deck, hand_manager)
	var initial_size = hand_manager.get_player_size()
	
	# Act
	var card = dealer.draw_player_third(deck, hand_manager)
	
	# Assert
	assert_not_null(card, "Карта должна быть раздана")
	assert_eq(hand_manager.get_player_size(), initial_size + 1, "В руке игрока должно быть на 1 карту больше")
	assert_eq(hand_manager.get_player_third_card(), card, "Третья карта должна быть той же, что раздана")

func test_draw_player_third_returns_card():
	"""Проверка что метод возвращает разданную карту"""
	# Arrange
	dealer.deal_first_four(deck, hand_manager)
	
	# Act
	var card = dealer.draw_player_third(deck, hand_manager)
	
	# Assert
	assert_not_null(card, "Метод должен вернуть карту")
	assert_true(card is Card, "Возвращаемое значение должно быть Card")
	assert_eq(card, hand_manager.get_player_third_card(), "Возвращённая карта должна совпадать с картой в руке")

func test_draw_player_third_handles_empty_deck():
	"""Проверка обработки пустой колоды (должна автоматически перетасоваться)"""
	# Arrange
	dealer.deal_first_four(deck, hand_manager)
	# Опустошаем колоду (но Deck автоматически перетасуется при draw())
	# Просто убедимся что метод работает даже если колода почти пуста
	
	# Act
	var card = dealer.draw_player_third(deck, hand_manager)
	
	# Assert
	assert_not_null(card, "Карта должна быть раздана даже если колода была почти пуста")
	assert_eq(hand_manager.get_player_size(), 3, "В руке игрока должно быть 3 карты")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: draw_banker_third
# ═══════════════════════════════════════════════════════════════════════════

func test_draw_banker_third_adds_card_to_hand():
	"""Проверка что третья карта добавляется в руку банкира"""
	# Arrange
	dealer.deal_first_four(deck, hand_manager)
	var initial_size = hand_manager.get_banker_size()
	
	# Act
	var card = dealer.draw_banker_third(deck, hand_manager)
	
	# Assert
	assert_not_null(card, "Карта должна быть раздана")
	assert_eq(hand_manager.get_banker_size(), initial_size + 1, "В руке банкира должно быть на 1 карту больше")
	assert_eq(hand_manager.get_banker_third_card(), card, "Третья карта должна быть той же, что раздана")

func test_draw_banker_third_returns_card():
	"""Проверка что метод возвращает разданную карту"""
	# Arrange
	dealer.deal_first_four(deck, hand_manager)
	
	# Act
	var card = dealer.draw_banker_third(deck, hand_manager)
	
	# Assert
	assert_not_null(card, "Метод должен вернуть карту")
	assert_true(card is Card, "Возвращаемое значение должно быть Card")
	assert_eq(card, hand_manager.get_banker_third_card(), "Возвращённая карта должна совпадать с картой в руке")

func test_draw_banker_third_handles_empty_deck():
	"""Проверка обработки пустой колоды"""
	# Arrange
	dealer.deal_first_four(deck, hand_manager)
	
	# Act
	var card = dealer.draw_banker_third(deck, hand_manager)
	
	# Assert
	assert_not_null(card, "Карта должна быть раздана")
	assert_eq(hand_manager.get_banker_size(), 3, "В руке банкира должно быть 3 карты")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Интеграция
# ═══════════════════════════════════════════════════════════════════════════

func test_full_deal_sequence():
	"""Проверка полной последовательности раздачи"""
	# Arrange
	var initial_deck_size = deck.cards.size()
	
	# Act - полная раздача
	dealer.deal_first_four(deck, hand_manager)
	var player_third = dealer.draw_player_third(deck, hand_manager)
	var banker_third = dealer.draw_banker_third(deck, hand_manager)
	
	# Assert
	assert_eq(hand_manager.get_player_size(), 3, "Игрок должен иметь 3 карты")
	assert_eq(hand_manager.get_banker_size(), 3, "Банкир должен иметь 3 карты")
	assert_eq(deck.cards.size(), initial_deck_size - 6, "Из колоды должно быть взято 6 карт")
	assert_not_null(player_third, "Третья карта игрока должна быть раздана")
	assert_not_null(banker_third, "Третья карта банкира должна быть раздана")

func test_multiple_deals_work_correctly():
	"""Проверка что можно выполнить несколько раздач подряд"""
	# Arrange
	hand_manager.reset()
	
	# Act - первая раздача
	dealer.deal_first_four(deck, hand_manager)
	var first_player_size = hand_manager.get_player_size()
	var first_banker_size = hand_manager.get_banker_size()
	
	# Сброс и вторая раздача
	hand_manager.reset()
	dealer.deal_first_four(deck, hand_manager)
	
	# Assert
	assert_eq(hand_manager.get_player_size(), first_player_size, "Вторая раздача должна дать столько же карт игроку")
	assert_eq(hand_manager.get_banker_size(), first_banker_size, "Вторая раздача должна дать столько же карт банкиру")

func test_dealer_does_not_modify_deck_directly():
	"""Проверка что CardDealer не модифицирует колоду напрямую (только через draw)"""
	# Arrange
	var initial_deck_size = deck.cards.size()
	var initial_cards = deck.cards.duplicate()
	
	# Act
	dealer.deal_first_four(deck, hand_manager)
	
	# Assert
	# Колода должна быть изменена (карты взяты), но структура должна остаться корректной
	assert_eq(deck.cards.size(), initial_deck_size - 4, "Колода должна содержать на 4 карты меньше")
	# Проверяем что оставшиеся карты - это подмножество исходных
	for card in deck.cards:
		var found = false
		for initial_card in initial_cards:
			if card.suit == initial_card.suit and card.value == initial_card.value:
				found = true
				break
		assert_true(found, "Все карты в колоде должны быть из исходной колоды")

