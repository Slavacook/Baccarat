# res://tests/integration/test_game_cycle.gd
# Интеграционные тесты: полный игровой цикл
extends GutTest

var deck: Deck

func before_each():
	deck = Deck.new()

func after_each():
	deck = null

# Создает типизированный массив карт (для строгой типизации Godot 4)
func _make_hand(cards: Array) -> Array[Card]:
	var hand: Array[Card] = []
	for c in cards:
		hand.append(c)
	return hand

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ПОЛНОГО ИГРОВОГО ЦИКЛА
# ═══════════════════════════════════════════════════════════════════════════

func test_full_round_with_natural():
	# Раздача: Игрок A+8 (9), Банкир 10+K (0)
	var player_hand = _make_hand([Card.new(0, 1), Card.new(1, 8)])  # A♠, 8♥ = 9
	var banker_hand = _make_hand([Card.new(2, 10), Card.new(3, 13)])  # 10♦, K♣ = 0

	# Проверяем, что это натуральная 9
	assert_true(BaccaratRules.is_natural(player_hand), "Должна быть натуральная 9")

	# Определяем состояние игры
	var state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)
	assert_eq(state, GameStateManager.GameState.CHOOSE_WINNER, "Состояние должно быть CHOOSE_WINNER (натуральная)")

	# Проверяем победителя
	var winner = BaccaratRules.get_winner(player_hand, banker_hand)
	assert_eq(winner, "Player", "Победитель должен быть Player (9 vs 0)")

func test_full_round_both_draw_third():
	# Раздача: Игрок 2+3 (5), Банкир A+A (2)
	var player_hand = _make_hand([Card.new(0, 2), Card.new(1, 3)])  # 2♠, 3♥ = 5
	var banker_hand = _make_hand([Card.new(2, 1), Card.new(3, 1)])  # A♦, A♣ = 2

	# Состояние: оба должны брать карту
	var state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)
	assert_eq(state, GameStateManager.GameState.CARD_TO_EACH, "Оба должны брать карту (5 vs 2)")

	# Раздаём третьи карты
	var player_third = deck.draw()
	var banker_third = deck.draw()

	player_hand.append(player_third)
	banker_hand.append(banker_third)

	# Состояние после раздачи: выбор победителя
	state = GameStateManager.determine_state(false, player_hand, banker_hand, player_third, banker_third)
	assert_eq(state, GameStateManager.GameState.CHOOSE_WINNER, "После раздачи обеих карт: выбор победителя")

	# Проверяем победителя
	var winner = BaccaratRules.get_winner(player_hand, banker_hand)
	assert_true(winner in ["Player", "Banker", "Tie"], "Победитель должен быть определён")

func test_full_round_player_only():
	# Раздача: Игрок 2+2 (4), Банкир 6+A (7)
	var player_hand = _make_hand([Card.new(0, 2), Card.new(1, 2)])  # 2♠, 2♥ = 4
	var banker_hand = _make_hand([Card.new(2, 6), Card.new(3, 1)])  # 6♦, A♣ = 7

	# Состояние: только игроку карта
	var state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)
	assert_eq(state, GameStateManager.GameState.CARD_TO_PLAYER, "Только игроку карта (4 vs 7)")

	# Раздаём игроку третью карту
	var player_third = deck.draw()
	player_hand.append(player_third)

	# Состояние после третьей карты игрока
	state = GameStateManager.determine_state(false, player_hand, banker_hand, player_third, null)
	assert_eq(state, GameStateManager.GameState.CHOOSE_WINNER, "После третьей карты игрока: выбор победителя")

	# Проверяем победителя
	var winner = BaccaratRules.get_winner(player_hand, banker_hand)
	assert_true(winner in ["Player", "Banker", "Tie"], "Победитель должен быть определён")

func test_full_round_banker_after_player():
	# Раздача: Игрок 2+2 (4), Банкир 2+2 (4)
	var player_hand = _make_hand([Card.new(0, 2), Card.new(1, 2)])  # 2♠, 2♥ = 4
	var banker_hand = _make_hand([Card.new(2, 2), Card.new(3, 2)])  # 2♦, 2♣ = 4

	# Состояние: игрок берёт карту, банкир ждёт
	var state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)
	assert_eq(state, GameStateManager.GameState.CARD_TO_PLAYER, "Игрок берёт карту (4 vs 4)")

	# Раздаём игроку третью карту (например, 7)
	var player_third = Card.new(0, 7)  # 7♠
	player_hand.append(player_third)

	# Состояние после третьей игрока: банкир решает
	state = GameStateManager.determine_state(false, player_hand, banker_hand, player_third, null)

	# Банкир с 4 должен брать при третьей игрока = 7
	var banker_should_draw = BaccaratRules.banker_should_draw([banker_hand[0], banker_hand[1]], true, player_third)
	assert_false(banker_should_draw, "Банкир с 4 НЕ берёт при третьей игрока = 7")

	assert_eq(state, GameStateManager.GameState.CHOOSE_WINNER, "Банкир не берёт → выбор победителя")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ 10 РАУНДОВ
# ═══════════════════════════════════════════════════════════════════════════

func test_10_rounds_consistency():
	var rounds_completed = 0

	for i in range(10):
		# Создаём новую колоду для каждого раунда
		var round_deck = Deck.new()

		# Раздача первых 4 карт
		var player_hand = [round_deck.draw(), round_deck.draw()]
		var banker_hand = [round_deck.draw(), round_deck.draw()]

		# Определяем состояние
		var state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)

		# Играем раунд до конца
		var player_third = null
		var banker_third = null

		match state:
			GameStateManager.GameState.CHOOSE_WINNER:
				# Натуральная или особая комбинация - сразу выбор
				pass
			GameStateManager.GameState.CARD_TO_EACH:
				# Оба берут карту
				player_third = round_deck.draw()
				banker_third = round_deck.draw()
				player_hand.append(player_third)
				banker_hand.append(banker_third)
			GameStateManager.GameState.CARD_TO_PLAYER:
				# Только игрок берёт
				player_third = round_deck.draw()
				player_hand.append(player_third)
			GameStateManager.GameState.CARD_TO_BANKER:
				# Только банкир берёт
				banker_third = round_deck.draw()
				banker_hand.append(banker_third)

		# Проверяем победителя
		var winner = BaccaratRules.get_winner(player_hand, banker_hand)
		assert_true(winner in ["Player", "Banker", "Tie"], "Раунд %d: победитель определён" % (i + 1))

		rounds_completed += 1

	assert_eq(rounds_completed, 10, "Должно быть сыграно 10 раундов")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ EDGE CASES БАККАРА
# ═══════════════════════════════════════════════════════════════════════════

func test_edge_case_both_naturals():
	# Оба получают натуральную (8 vs 9)
	var player_hand = _make_hand([Card.new(0, 8), Card.new(1, 1)])  # 8♠, A♥ = 9 (натуральная)
	var banker_hand = _make_hand([Card.new(2, 5), Card.new(3, 3)])  # 5♦, 3♣ = 8 (натуральная)

	assert_true(BaccaratRules.is_natural(player_hand), "Player должна быть натуральная 9")
	assert_true(BaccaratRules.is_natural(banker_hand), "Banker должна быть натуральная 8")

	var winner = BaccaratRules.get_winner(player_hand, banker_hand)
	assert_eq(winner, "Player", "Player выигрывает (9 vs 8)")

func test_edge_case_tie():
	# Ничья 5-5
	var player_hand = _make_hand([Card.new(0, 2), Card.new(1, 3)])  # 2♠, 3♥ = 5
	var banker_hand = _make_hand([Card.new(2, 4), Card.new(3, 1)])  # 4♦, A♣ = 5

	var winner = BaccaratRules.get_winner(player_hand, banker_hand)
	assert_eq(winner, "Tie", "Должна быть ничья (5 vs 5)")

func test_edge_case_special_66():
	# Особая комбинация 6-6
	var player_hand = _make_hand([Card.new(0, 6), Card.new(1, 10)])  # 6♠, 10♥ = 6
	var banker_hand = _make_hand([Card.new(2, 3), Card.new(3, 3)]   # 3♦, 3♣ = 6

	var state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)
	assert_eq(state, GameStateManager.GameState.CHOOSE_WINNER, "6-6: особая комбинация, выбор победителя")

func test_edge_case_banker_rule_3_with_8():
	# Банкир с 3 НЕ берёт при третьей игрока = 8
	var player_hand = _make_hand([Card.new(0, 2), Card.new(1, 2)])  # 2♠, 2♥ = 4
	var banker_hand = _make_hand([Card.new(2, 2), Card.new(3, 1)])  # 2♦, A♣ = 3

	var player_third = Card.new(0, 8)  # 8♠
	player_hand.append(player_third)

	var banker_should_draw = BaccaratRules.banker_should_draw([banker_hand[0], banker_hand[1]], true, player_third)
	assert_false(banker_should_draw, "Банкир с 3 НЕ берёт при третьей игрока = 8")

func test_edge_case_banker_rule_6_with_6_or_7():
	# Банкир с 6 берёт только при третьей игрока = 6 или 7
	var banker_hand = _make_hand([Card.new(0, 3), Card.new(1, 3)])  # 3♠, 3♥ = 6

	# Третья игрока = 6 → банкир берёт
	var player_third_6 = Card.new(2, 6)  # 6♦
	var should_draw_6 = BaccaratRules.banker_should_draw([banker_hand[0], banker_hand[1]], true, player_third_6)
	assert_true(should_draw_6, "Банкир с 6 берёт при третьей игрока = 6")

	# Третья игрока = 7 → банкир берёт
	var player_third_7 = Card.new(2, 7)  # 7♦
	var should_draw_7 = BaccaratRules.banker_should_draw([banker_hand[0], banker_hand[1]], true, player_third_7)
	assert_true(should_draw_7, "Банкир с 6 берёт при третьей игрока = 7")

	# Третья игрока = 5 → банкир НЕ берёт
	var player_third_5 = Card.new(2, 5)  # 5♦
	var should_draw_5 = BaccaratRules.banker_should_draw([banker_hand[0], banker_hand[1]], true, player_third_5)
	assert_false(should_draw_5, "Банкир с 6 НЕ берёт при третьей игрока = 5")
