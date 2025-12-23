# res://tests/manual_test_FirstFourDealCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ FirstFourDealCoordinator
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var coordinator: FirstFourDealCoordinator = null
var pair_betting_manager: PairBettingManager = null
var chance_card_trigger_checker: ChanceCardTriggerChecker = null

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ FirstFourDealCoordinator")
	print("════════════════════════════════════════════════════════════")
	
	# Инициализация зависимостей
	pair_betting_manager = PairBettingManager.new()
	chance_card_trigger_checker = ChanceCardTriggerChecker.new()
	
	# Создаём координатор
	coordinator = FirstFourDealCoordinator.new(pair_betting_manager, chance_card_trigger_checker)
	
	# Запускаем тесты
	_run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func _run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: has_any_bets без ставок
	print("\n📋 Тест 1: has_any_bets без ставок")
	PayoutSettingsManager.toggle_player(false)
	PayoutSettingsManager.toggle_banker(false)
	PayoutSettingsManager.toggle_tie(false)
	pair_betting_manager.toggle_pair_player_bet(false)
	pair_betting_manager.toggle_pair_banker_bet(false)
	
	var bets_info = coordinator.has_any_bets()
	if not bets_info.get("has_any", true):
		print("  ✅ PASS: Нет ставок определено корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие ставок")
		failed += 1
	
	# Тест 2: has_any_bets с основной ставкой
	print("\n📋 Тест 2: has_any_bets с основной ставкой")
	PayoutSettingsManager.toggle_player(true)
	bets_info = coordinator.has_any_bets()
	if bets_info.get("has_any", false) and bets_info.get("has_main_bets", false):
		print("  ✅ PASS: Основная ставка определена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась основная ставка")
		failed += 1
	
	# Тест 3: has_any_bets с парной ставкой
	print("\n📋 Тест 3: has_any_bets с парной ставкой")
	PayoutSettingsManager.toggle_player(false)
	pair_betting_manager.toggle_pair_player_bet(true)
	bets_info = coordinator.has_any_bets()
	if bets_info.get("has_any", false) and bets_info.get("has_pair_bets", false):
		print("  ✅ PASS: Парная ставка определена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась парная ставка")
		failed += 1
	
	# Тест 4: check_pairs с парой у игрока
	print("\n📋 Тест 4: check_pairs с парой у игрока")
	var card1 = Card.new(Card.Suit.HEARTS, 1)  # A
	var card2 = Card.new(Card.Suit.HEARTS, 1)  # A
	var card3 = Card.new(Card.Suit.SPADES, 13)  # K
	var card4 = Card.new(Card.Suit.SPADES, 12)  # Q
	
	var pairs_info = coordinator.check_pairs(card1, card2, card3, card4)
	if pairs_info.get("has_player_pair", false) and not pairs_info.get("has_banker_pair", false):
		print("  ✅ PASS: Пара игрока определена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась пара у игрока")
		failed += 1
	
	# Тест 5: check_pairs с парой у банкира
	print("\n📋 Тест 5: check_pairs с парой у банкира")
	card1 = Card.new(Card.Suit.HEARTS, 13)  # K
	card2 = Card.new(Card.Suit.SPADES, 12)  # Q
	card3 = Card.new(Card.Suit.DIAMONDS, 10)  # 10
	card4 = Card.new(Card.Suit.CLUBS, 10)  # 10
	
	pairs_info = coordinator.check_pairs(card1, card2, card3, card4)
	if not pairs_info.get("has_player_pair", false) and pairs_info.get("has_banker_pair", false):
		print("  ✅ PASS: Пара банкира определена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась пара у банкира")
		failed += 1
	
	# Тест 6: check_pairs с двумя парами
	print("\n📋 Тест 6: check_pairs с двумя парами")
	card1 = Card.new(Card.Suit.HEARTS, 1)  # A
	card2 = Card.new(Card.Suit.SPADES, 1)  # A
	card3 = Card.new(Card.Suit.DIAMONDS, 13)  # K
	card4 = Card.new(Card.Suit.CLUBS, 13)  # K
	
	pairs_info = coordinator.check_pairs(card1, card2, card3, card4)
	if pairs_info.get("has_both_pairs", false):
		print("  ✅ PASS: Две пары определены корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидались две пары")
		failed += 1
	
	# Тест 7: check_pairs без пар
	print("\n📋 Тест 7: check_pairs без пар")
	card1 = Card.new(Card.Suit.HEARTS, 1)  # A
	card2 = Card.new(Card.Suit.SPADES, 13)  # K
	card3 = Card.new(Card.Suit.DIAMONDS, 12)  # Q
	card4 = Card.new(Card.Suit.CLUBS, 11)  # J
	
	pairs_info = coordinator.check_pairs(card1, card2, card3, card4)
	if not pairs_info.get("has_player_pair", false) and not pairs_info.get("has_banker_pair", false):
		print("  ✅ PASS: Отсутствие пар определено корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие пар")
		failed += 1
	
	# Тест 8: get_triggers_after_deal с двумя парами (Third Card Change)
	print("\n📋 Тест 8: get_triggers_after_deal с двумя парами")
	var player_hand: Array[Card] = [Card.new(Card.Suit.HEARTS, 1), Card.new(Card.Suit.SPADES, 1)]  # A, A
	var banker_hand: Array[Card] = [Card.new(Card.Suit.DIAMONDS, 13), Card.new(Card.Suit.CLUBS, 13)]  # K, K
	
	var triggers = coordinator.get_triggers_after_deal(
		player_hand, banker_hand,
		true, true,  # Обе пары
		false  # Не режим выживания
	)
	if triggers.get("third_card_change", false):
		print("  ✅ PASS: Триггер Third Card Change определен корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидался триггер Third Card Change")
		failed += 1
	
	# Тест 9: get_triggers_after_deal с парой тузов (Mystery Card, режим выживания)
	print("\n📋 Тест 9: get_triggers_after_deal с парой тузов (Mystery Card)")
	var player_hand_mystery: Array[Card] = [Card.new(Card.Suit.HEARTS, 1), Card.new(Card.Suit.SPADES, 1)]  # A, A
	var banker_hand_mystery: Array[Card] = [Card.new(Card.Suit.DIAMONDS, 13), Card.new(Card.Suit.CLUBS, 12)]  # K, Q
	
	triggers = coordinator.get_triggers_after_deal(
		player_hand_mystery, banker_hand_mystery,
		false, false,  # Пары не нужны для Mystery Card
		true  # Режим выживания
	)
	if triggers.get("mystery_card", false):
		print("  ✅ PASS: Триггер Mystery Card определен корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидался триггер Mystery Card")
		failed += 1
	
	# Тест 10: get_triggers_after_deal без режима выживания (Mystery Card не должен сработать)
	print("\n📋 Тест 10: get_triggers_after_deal без режима выживания")
	triggers = coordinator.get_triggers_after_deal(
		player_hand_mystery, banker_hand_mystery,
		false, false,
		false  # Не режим выживания
	)
	if not triggers.get("mystery_card", true):
		print("  ✅ PASS: Mystery Card не срабатывает без режима выживания")
		passed += 1
	else:
		print("  ❌ FAIL: Mystery Card не должен срабатывать без режима выживания")
		failed += 1
	
	# Тест 11: check_pairs без pair_betting_manager
	print("\n📋 Тест 11: check_pairs без pair_betting_manager")
	var coordinator_no_pair = FirstFourDealCoordinator.new(null, chance_card_trigger_checker)
	pairs_info = coordinator_no_pair.check_pairs(card1, card2, card3, card4)
	if not pairs_info.get("has_player_pair", true) and not pairs_info.get("has_banker_pair", true):
		print("  ✅ PASS: Без pair_betting_manager обработано корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие пар без менеджера")
		failed += 1
	
	# Тест 12: get_triggers_after_deal без chance_card_trigger_checker
	print("\n📋 Тест 12: get_triggers_after_deal без chance_card_trigger_checker")
	var coordinator_no_trigger = FirstFourDealCoordinator.new(pair_betting_manager, null)
	triggers = coordinator_no_trigger.get_triggers_after_deal(
		player_hand, banker_hand,
		true, true,
		false
	)
	if not triggers.get("third_card_change", true) and not triggers.get("mystery_card", true):
		print("  ✅ PASS: Без chance_card_trigger_checker обработано корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие триггеров без checker")
		failed += 1
	
	# Итоги
	print("\n════════════════════════════════════════════════════════════")
	print("📊 ИТОГИ ТЕСТИРОВАНИЯ:")
	print("  ✅ Пройдено: %d" % passed)
	print("  ❌ Провалено: %d" % failed)
	var success_rate = (float(passed) / float(passed + failed) * 100.0) if (passed + failed) > 0 else 0.0
	print("  📈 Успешность: %.1f%%" % success_rate)
	print("════════════════════════════════════════════════════════════")
	
	if failed == 0:
		print("🎉 Все тесты пройдены успешно!")
	else:
		print("⚠️ Некоторые тесты провалены")
	print("════════════════════════════════════════════════════════════")
