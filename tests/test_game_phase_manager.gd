# res://tests/test_game_phase_manager.gd
# Тесты для рефакторенных методов GamePhaseManager
# Используем ручные mock-классы для совместимости со строгой типизацией Godot 4
extends GutTest

# ========================================
# MOCK КЛАССЫ (для изоляции от зависимостей)
# ========================================

# Mock для CardTextureManager (пустая реализация)
class MockCardManager extends CardTextureManager:
	func _init():
		pass  # Пустой конструктор (без GameConfig)

# Mock для UIManager (только нужные заглушки с правильными сигнатурами)
class MockUI extends UIManager:
	func _init():
		pass  # Пустой конструктор (без scene, card_manager)

	func update_action_button(text: String):
		pass  # Заглушка для вызова в GamePhaseManager._init()

	func reset_ui():
		pass

	func update_player_third_card_ui(state: String, card: Card = null):
		pass

	func update_banker_third_card_ui(state: String, card: Card = null):
		pass

	func enable_action_button():
		pass

	func show_first_four_cards(player_hand: Array[Card], banker_hand: Array[Card]):
		pass

	func show_player_third_card(card: Card):
		pass

	func show_banker_third_card(card: Card):
		pass

# Mock для PayoutQueueManager
class MockPayoutQueueManager extends PayoutQueueManager:
	func _init():
		pass  # Пустой конструктор

# Mock для ChipVisualManager
class MockChipVisualManager extends ChipVisualManager:
	func _init():
		pass  # Пустой конструктор

# Mock для WinnerSelectionManager
class MockWinnerSelectionManager extends WinnerSelectionManager:
	func _init():
		pass  # Пустой конструктор

# Mock для PairBettingManager
class MockPairBettingManager extends PairBettingManager:
	func _init():
		pass  # Пустой конструктор

# ========================================
# ТЕСТЫ ЛОГИКИ ВАЛИДАЦИИ
# ========================================

var phase_manager: GamePhaseManager
var mock_deck: Deck
var mock_card_manager: MockCardManager
var mock_ui: MockUI
var mock_payout_queue_manager: MockPayoutQueueManager
var mock_chip_visual_manager: MockChipVisualManager
var mock_winner_selection_manager: MockWinnerSelectionManager
var mock_pair_betting_manager: MockPairBettingManager

# ========================================
# SETUP / TEARDOWN
# ========================================

func before_each():
	# Настоящая колода
	mock_deck = Deck.new()

	# Создаём mock объекты (ручные заглушки с правильными типами)
	mock_card_manager = MockCardManager.new()
	mock_ui = MockUI.new()
	mock_payout_queue_manager = MockPayoutQueueManager.new()
	mock_chip_visual_manager = MockChipVisualManager.new()
	mock_winner_selection_manager = MockWinnerSelectionManager.new()
	mock_pair_betting_manager = MockPairBettingManager.new()

	# Инициализируем phase_manager с новыми параметрами (Dependency Injection)
	phase_manager = GamePhaseManager.new(
		mock_deck,
		mock_card_manager,
		mock_ui,
		mock_payout_queue_manager,
		mock_chip_visual_manager,
		mock_winner_selection_manager,
		mock_pair_betting_manager
	)

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
# ТЕСТЫ: _handle_natural_case()
# ========================================

func test_natural_8_no_third_cards():
	# Игрок: 8 очков (натуральная), галочки не выбраны
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 5),
		Card.new(Card.Suit.HEARTS, 3)
	])  # 5+3=8
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 2),
		Card.new(Card.Suit.DIAMONDS, 4)
	])  # 2+4=6
	phase_manager.player_third_selected = false
	phase_manager.banker_third_selected = false

	phase_manager._handle_natural_case()

	# Проверяем что галочки остались неактивны
	assert_false(phase_manager.player_third_selected, "Player third should remain unselected")
	assert_false(phase_manager.banker_third_selected, "Banker third should remain unselected")

func test_natural_9_error_if_player_selected():
	# Игрок: 9 очков (натуральная), но игрок выбрал третью карту → ошибка
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 4),
		Card.new(Card.Suit.HEARTS, 5)
	])  # 4+5=9
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 3),
		Card.new(Card.Suit.DIAMONDS, 3)
	])  # 3+3=6
	phase_manager.player_third_selected = true  # ← Ошибка!
	phase_manager.banker_third_selected = false

	phase_manager._handle_natural_case()

	# Проверяем что ошибка обработана (галочка сброшена)
	assert_false(phase_manager.player_third_selected, "Player third should be reset after error")
	assert_false(phase_manager.banker_third_selected, "Banker third should remain unselected")

func test_natural_error_if_banker_selected():
	# Натуральная, но банкир выбрал третью карту → ошибка
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 5),
		Card.new(Card.Suit.HEARTS, 3)
	])  # 5+3=8
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 2),
		Card.new(Card.Suit.DIAMONDS, 4)
	])  # 2+4=6
	phase_manager.player_third_selected = false
	phase_manager.banker_third_selected = true  # ← Ошибка!

	phase_manager._handle_natural_case()

	# Обе галочки должны быть сброшены
	assert_false(phase_manager.player_third_selected, "Player third should remain unselected")
	assert_false(phase_manager.banker_third_selected, "Banker third should be reset after error")

func test_special_combination_6v6():
	# Особая комбинация 6v6 → никто не берет карты
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 3),
		Card.new(Card.Suit.HEARTS, 3)
	])  # 3+3=6
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 4),
		Card.new(Card.Suit.DIAMONDS, 2)
	])  # 4+2=6
	phase_manager.player_third_selected = false
	phase_manager.banker_third_selected = false

	phase_manager._handle_natural_case()

	# Проверяем что complete_game вызван (руки остались 2 карты)
	assert_eq(phase_manager.player_hand.size(), 2, "Player should have 2 cards only")
	assert_eq(phase_manager.banker_hand.size(), 2, "Banker should have 2 cards only")

# ========================================
# ТЕСТЫ: _handle_card_to_each()
# ========================================

func test_card_to_each_success():
	# Банкир 0-2, Игрок 0-5 → оба должны взять карты
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 2),
		Card.new(Card.Suit.HEARTS, 3)
	])  # 2+3=5
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 1),
		Card.new(Card.Suit.DIAMONDS, 1)
	])  # 1+1=2
	phase_manager.player_third_selected = true
	phase_manager.banker_third_selected = true

	phase_manager._handle_card_to_each()

	# Проверяем что обе третьи карты розданы
	assert_eq(phase_manager.player_hand.size(), 3, "Player should have 3 cards")
	assert_eq(phase_manager.banker_hand.size(), 3, "Banker should have 3 cards")
	# Галочки сброшены
	assert_false(phase_manager.player_third_selected, "Player third should be reset")
	assert_false(phase_manager.banker_third_selected, "Banker third should be reset")

func test_card_to_each_error_missing_player():
	# Ошибка: не выбран игрок
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 1),
		Card.new(Card.Suit.HEARTS, 1)
	])  # 1+1=2
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 2),
		Card.new(Card.Suit.DIAMONDS, 0)
	])  # 2+0=2
	phase_manager.player_third_selected = false  # ← Ошибка!
	phase_manager.banker_third_selected = true

	phase_manager._handle_card_to_each()

	# Проверяем что карты НЕ розданы (ошибка)
	assert_eq(phase_manager.player_hand.size(), 2, "Player should still have 2 cards after error")
	assert_eq(phase_manager.banker_hand.size(), 2, "Banker should still have 2 cards after error")

func test_card_to_each_error_missing_both():
	# Ошибка: не выбран ни один
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 2),
		Card.new(Card.Suit.HEARTS, 2)
	])  # 2+2=4
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 1),
		Card.new(Card.Suit.DIAMONDS, 0)
	])  # 1+0=1
	phase_manager.player_third_selected = false  # ← Ошибка!
	phase_manager.banker_third_selected = false  # ← Ошибка!

	phase_manager._handle_card_to_each()

	# Проверяем что карты НЕ розданы
	assert_eq(phase_manager.player_hand.size(), 2, "No cards should be dealt")
	assert_eq(phase_manager.banker_hand.size(), 2, "No cards should be dealt")

# ========================================
# ТЕСТЫ: _handle_card_to_player_with_banker_7()
# ========================================

func test_player_card_with_banker_7_success():
	# Игрок 0-5, Банкир 7 → только игрок берет
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 2),
		Card.new(Card.Suit.HEARTS, 2)
	])  # 2+2=4
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 4),
		Card.new(Card.Suit.DIAMONDS, 3)
	])  # 4+3=7
	phase_manager.player_third_selected = true
	phase_manager.banker_third_selected = false

	phase_manager._handle_card_to_player_with_banker_7(4, 7)

	# Проверяем что только игрок получил карту
	assert_eq(phase_manager.player_hand.size(), 3, "Player should have 3 cards")
	assert_eq(phase_manager.banker_hand.size(), 2, "Banker should still have 2 cards")

func test_player_card_with_banker_7_error_banker_selected():
	# Ошибка: выбран банкир (ему не нужна карта с 7)
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 3),
		Card.new(Card.Suit.HEARTS, 1)
	])  # 3+1=4
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 5),
		Card.new(Card.Suit.DIAMONDS, 2)
	])  # 5+2=7
	phase_manager.player_third_selected = true
	phase_manager.banker_third_selected = true  # ← Ошибка!

	phase_manager._handle_card_to_player_with_banker_7(4, 7)

	# Проверяем что галочка банкира сброшена, карты не розданы
	assert_eq(phase_manager.player_hand.size(), 2, "No cards dealt after error")
	assert_false(phase_manager.banker_third_selected, "Banker third should be reset after error")

# ========================================
# ТЕСТЫ: _handle_card_to_banker_only()
# ========================================

func test_banker_card_only_success():
	# Игрок 6-7, Банкир 0-5 → только банкир берет
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 3),
		Card.new(Card.Suit.HEARTS, 3)
	])  # 3+3=6
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 2),
		Card.new(Card.Suit.DIAMONDS, 3)
	])  # 2+3=5
	phase_manager.player_third_selected = false
	phase_manager.banker_third_selected = true

	phase_manager._handle_card_to_banker_only(6, 5)

	# Проверяем что только банкир получил карту
	assert_eq(phase_manager.player_hand.size(), 2, "Player should still have 2 cards")
	assert_eq(phase_manager.banker_hand.size(), 3, "Banker should have 3 cards")

func test_banker_card_only_error_player_selected():
	# Ошибка: выбран игрок (ему не нужна карта с 6-7)
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 3),
		Card.new(Card.Suit.HEARTS, 4)
	])  # 3+4=7
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 1),
		Card.new(Card.Suit.DIAMONDS, 3)
	])  # 1+3=4
	phase_manager.player_third_selected = true  # ← Ошибка!
	phase_manager.banker_third_selected = true

	phase_manager._handle_card_to_banker_only(7, 4)

	# Проверяем что галочка игрока сброшена
	assert_eq(phase_manager.banker_hand.size(), 2, "No cards dealt after error")
	assert_false(phase_manager.player_third_selected, "Player third should be reset after error")

# ========================================
# ИНТЕГРАЦИОННЫЕ ТЕСТЫ
# ========================================

func test_full_validation_natural():
	# Полный цикл: натуральная → сразу выбор победителя
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 5),
		Card.new(Card.Suit.HEARTS, 4)
	])  # 5+4=9
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 3),
		Card.new(Card.Suit.DIAMONDS, 3)
	])  # 3+3=6
	phase_manager.player_third_selected = false
	phase_manager.banker_third_selected = false

	phase_manager._validate_and_execute_third_cards()

	# Проверяем что complete_game вызван (третьих карт нет)
	assert_eq(phase_manager.player_hand.size(), 2, "No third cards for natural")
	assert_eq(phase_manager.banker_hand.size(), 2, "No third cards for natural")

func test_full_validation_card_to_each():
	# Полный цикл: карта каждому
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 2),
		Card.new(Card.Suit.HEARTS, 3)
	])  # 2+3=5
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 1),
		Card.new(Card.Suit.DIAMONDS, 1)
	])  # 1+1=2
	phase_manager.player_third_selected = true
	phase_manager.banker_third_selected = true

	phase_manager._validate_and_execute_third_cards()

	# Проверяем что оба получили третьи карты
	assert_eq(phase_manager.player_hand.size(), 3, "Both should get third cards")
	assert_eq(phase_manager.banker_hand.size(), 3, "Both should get third cards")

func test_full_validation_player_only_banker_7():
	# Полный цикл: только игрок (банкир 7)
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 2),
		Card.new(Card.Suit.HEARTS, 2)
	])  # 2+2=4
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 4),
		Card.new(Card.Suit.DIAMONDS, 3)
	])  # 4+3=7
	phase_manager.player_third_selected = true
	phase_manager.banker_third_selected = false

	phase_manager._validate_and_execute_third_cards()

	# Проверяем что только игрок получил третью карту
	assert_eq(phase_manager.player_hand.size(), 3, "Player gets third card")
	assert_eq(phase_manager.banker_hand.size(), 2, "Banker stands with 7")

func test_full_validation_banker_only():
	# Полный цикл: только банкир (игрок 6-7)
	phase_manager.player_hand = _make_hand([
		Card.new(Card.Suit.CLUBS, 3),
		Card.new(Card.Suit.HEARTS, 3)
	])  # 3+3=6
	phase_manager.banker_hand = _make_hand([
		Card.new(Card.Suit.SPADES, 2),
		Card.new(Card.Suit.DIAMONDS, 2)
	])  # 2+2=4
	phase_manager.player_third_selected = false
	phase_manager.banker_third_selected = true

	phase_manager._validate_and_execute_third_cards()

	# Проверяем что только банкир получил третью карту
	assert_eq(phase_manager.player_hand.size(), 2, "Player stands with 6")
	assert_eq(phase_manager.banker_hand.size(), 3, "Banker gets third card")
