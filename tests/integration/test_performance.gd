# res://tests/integration/test_performance.gd
# Тесты производительности: 100 раундов
extends GutTest

# Создает типизированный массив карт (для строгой типизации Godot 4)
func _make_hand(cards: Array) -> Array[Card]:
	var hand: Array[Card] = []
	for c in cards:
		hand.append(c)
	return hand

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ПРОИЗВОДИТЕЛЬНОСТИ
# ═══════════════════════════════════════════════════════════════════════════

func test_100_rounds_performance():
	var start_time = Time.get_ticks_msec()
	var rounds_completed = 0

	for i in range(100):
		# Создаём новую колоду для каждого раунда
		var round_deck = Deck.new()

		# Раздача первых 4 карт (типизированные массивы)
		var player_hand: Array[Card] = []
		player_hand.append(round_deck.draw())
		player_hand.append(round_deck.draw())
		var banker_hand: Array[Card] = []
		banker_hand.append(round_deck.draw())
		banker_hand.append(round_deck.draw())

		# Определяем состояние
		var state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)

		# Играем раунд до конца
		var player_third = null
		var banker_third = null

		match state:
			GameStateManager.GameState.CHOOSE_WINNER:
				pass  # Сразу выбор победителя
			GameStateManager.GameState.CARD_TO_EACH:
				player_third = round_deck.draw()
				banker_third = round_deck.draw()
				player_hand.append(player_third)
				banker_hand.append(banker_third)
			GameStateManager.GameState.CARD_TO_PLAYER:
				player_third = round_deck.draw()
				player_hand.append(player_third)

				# Проверяем, нужна ли карта банкиру после игрока
				var new_state = GameStateManager.determine_state(false, player_hand, banker_hand, player_third, null)
				if new_state == GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER:
					var banker_should_draw = BaccaratRules.banker_should_draw([banker_hand[0], banker_hand[1]], true, player_third)
					if banker_should_draw:
						banker_third = round_deck.draw()
						banker_hand.append(banker_third)
			GameStateManager.GameState.CARD_TO_BANKER:
				banker_third = round_deck.draw()
				banker_hand.append(banker_third)

		# Определяем победителя
		var _winner = BaccaratRules.get_winner(player_hand, banker_hand)

		rounds_completed += 1

	var end_time = Time.get_ticks_msec()
	var elapsed_time = end_time - start_time

	assert_eq(rounds_completed, 100, "Должно быть сыграно 100 раундов")
	assert_true(elapsed_time < 1000, "100 раундов должны выполниться менее чем за 1 секунду (текущее время: %d мс)" % elapsed_time)

	print("⚡ Performance: 100 раундов завершено за %d мс" % elapsed_time)

func test_gamestate_manager_caching_performance():
	# Тест производительности кэширования GameStateManager
	var player_hand = _make_hand([Card.new(0, 2), Card.new(1, 3)])  # 2♠, 3♥ = 5
	var banker_hand = _make_hand([Card.new(2, 2), Card.new(3, 1)])  # 2♦, A♣ = 3

	var start_time = Time.get_ticks_msec()

	# Вызываем determine_state() 1000 раз с одними и теми же параметрами
	for i in range(1000):
		var _state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)

	var end_time = Time.get_ticks_msec()
	var elapsed_time = end_time - start_time

	# С кэшированием должно быть быстро (<10мс для 1000 вызовов)
	assert_true(elapsed_time < 50, "1000 вызовов determine_state() с кэшем должны быть < 50мс (текущее время: %d мс)" % elapsed_time)

	print("⚡ Кэширование: 1000 вызовов за %d мс (с кэшем)" % elapsed_time)

func test_chip_stack_manager_performance():
	# Тест производительности ChipStackManager
	var mock_container = HBoxContainer.new()
	var manager = ChipStackManager.new(mock_container)

	var start_time = Time.get_ticks_msec()

	# Добавляем 1000 фишек разных номиналов
	for i in range(1000):
		var denomination = [100000.0, 50000.0, 10000.0, 5000.0, 1000.0, 500.0, 100.0, 50.0, 10.0, 5.0][i % 10]
		manager.add_chip(denomination)

	var end_time = Time.get_ticks_msec()
	var elapsed_time = end_time - start_time

	# Проверяем, что все фишки добавились
	var total = manager.get_total()
	assert_true(total > 0, "Общая сумма должна быть > 0")

	# Должно быть быстро (<500мс для 1000 операций)
	assert_true(elapsed_time < 500, "1000 операций add_chip() должны быть < 500мс (текущее время: %d мс)" % elapsed_time)

	print("⚡ ChipStackManager: 1000 операций за %d мс" % elapsed_time)

	# Очистка
	manager.clear_all()
	mock_container.free()

func test_payout_validator_hint_performance():
	# Тест производительности расчёта подсказки
	var validator = PayoutValidator.new()
	var denominations = [100000, 50000, 10000, 5000, 1000, 500, 100, 50, 10, 5, 1, 0.5]

	var start_time = Time.get_ticks_msec()

	# Рассчитываем подсказку для 1000 разных сумм
	for i in range(1000):
		var amount = float(i * 1.5 + 100)
		var _hint = validator.calculate_hint(amount, denominations)

	var end_time = Time.get_ticks_msec()
	var elapsed_time = end_time - start_time

	# Жадный алгоритм должен быть быстрым (<100мс для 1000 расчётов)
	assert_true(elapsed_time < 100, "1000 расчётов подсказки должны быть < 100мс (текущее время: %d мс)" % elapsed_time)

	print("⚡ PayoutValidator: 1000 расчётов подсказки за %d мс" % elapsed_time)

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ СТАТИСТИКИ РАУНДОВ
# ═══════════════════════════════════════════════════════════════════════════

func test_100_rounds_statistics():
	# Собираем статистику результатов за 100 раундов
	var stats = {
		"player_wins": 0,
		"banker_wins": 0,
		"ties": 0,
		"naturals": 0,
		"both_draw": 0,
		"player_only": 0,
		"banker_only": 0,
		"no_draw": 0
	}

	for i in range(100):
		var round_deck = Deck.new()

		var player_hand = [round_deck.draw(), round_deck.draw()]
		var banker_hand = [round_deck.draw(), round_deck.draw()]

		var state = GameStateManager.determine_state(false, player_hand, banker_hand, null, null)

		var player_third = null
		var banker_third = null

		# Подсчитываем типы раундов
		match state:
			GameStateManager.GameState.CHOOSE_WINNER:
				stats["naturals"] += 1
			GameStateManager.GameState.CARD_TO_EACH:
				stats["both_draw"] += 1
				player_third = round_deck.draw()
				banker_third = round_deck.draw()
				player_hand.append(player_third)
				banker_hand.append(banker_third)
			GameStateManager.GameState.CARD_TO_PLAYER:
				stats["player_only"] += 1
				player_third = round_deck.draw()
				player_hand.append(player_third)
			GameStateManager.GameState.CARD_TO_BANKER:
				stats["banker_only"] += 1
				banker_third = round_deck.draw()
				banker_hand.append(banker_third)

		# Подсчитываем победителей
		var winner = BaccaratRules.get_winner(player_hand, banker_hand)
		match winner:
			"Player":
				stats["player_wins"] += 1
			"Banker":
				stats["banker_wins"] += 1
			"Tie":
				stats["ties"] += 1

	print("📊 Статистика 100 раундов:")
	print("   Побед Player: %d" % stats["player_wins"])
	print("   Побед Banker: %d" % stats["banker_wins"])
	print("   Ничьих: %d" % stats["ties"])
	print("   Натуральных: %d" % stats["naturals"])
	print("   Оба берут карту: %d" % stats["both_draw"])
	print("   Только игрок: %d" % stats["player_only"])
	print("   Только банкир: %d" % stats["banker_only"])

	# Проверяем, что все раунды завершились
	var total_rounds = stats["player_wins"] + stats["banker_wins"] + stats["ties"]
	assert_eq(total_rounds, 100, "Должно быть 100 завершённых раундов")

	# Проверяем, что хотя бы один раунд каждого типа был (статистически вероятно)
	# Не strict проверка, т.к. случайность может дать любой результат
	assert_true(stats["player_wins"] > 0, "Должна быть хотя бы одна победа Player")
	assert_true(stats["banker_wins"] > 0, "Должна быть хотя бы одна победа Banker")
