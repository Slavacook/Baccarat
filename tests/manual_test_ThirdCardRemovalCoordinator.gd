# res://tests/manual_test_ThirdCardRemovalCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ ThirdCardRemovalCoordinator
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var coordinator: ThirdCardRemovalCoordinator = null
var hand_manager: HandManager = null
var deck: Deck = null
var card_dealer: CardDealer = null

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ ThirdCardRemovalCoordinator")
	print("════════════════════════════════════════════════════════════")
	
	# Инициализация зависимостей
	hand_manager = HandManager.new()
	deck = Deck.new()
	card_dealer = CardDealer.new()
	
	# Создаём координатор
	coordinator = ThirdCardRemovalCoordinator.new(hand_manager)
	
	# Запускаем тесты
	_run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func _run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: get_removal_instructions без третьих карт
	print("\n📋 Тест 1: get_removal_instructions без третьих карт")
	hand_manager.reset()
	var instructions = coordinator.get_removal_instructions()
	if not instructions.get("should_remove_cards", true) and \
	   not instructions.get("has_player_third", true) and \
	   not instructions.get("has_banker_third", true):
		print("  ✅ PASS: Инструкции корректны для пустых рук")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие третьих карт")
		failed += 1
	
	# Тест 2: get_removal_instructions с третьей картой игрока
	print("\n📋 Тест 2: get_removal_instructions с третьей картой игрока")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	card_dealer.draw_player_third(deck, hand_manager)
	instructions = coordinator.get_removal_instructions()
	if instructions.get("should_remove_cards", false) and \
	   instructions.get("has_player_third", false) and \
	   instructions.get("should_reset_flags", false):
		print("  ✅ PASS: Инструкции корректны для третьей карты игрока")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась третья карта игрока")
		failed += 1
	
	# Тест 3: get_removal_instructions с третьей картой банкира
	print("\n📋 Тест 3: get_removal_instructions с третьей картой банкира")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	card_dealer.draw_banker_third(deck, hand_manager)
	instructions = coordinator.get_removal_instructions()
	if instructions.get("should_remove_cards", false) and \
	   instructions.get("has_banker_third", false) and \
	   instructions.get("should_reset_flags", false):
		print("  ✅ PASS: Инструкции корректны для третьей карты банкира")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась третья карта банкира")
		failed += 1
	
	# Тест 4: get_removal_instructions с обеими третьими картами
	print("\n📋 Тест 4: get_removal_instructions с обеими третьими картами")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	card_dealer.draw_player_third(deck, hand_manager)
	card_dealer.draw_banker_third(deck, hand_manager)
	instructions = coordinator.get_removal_instructions()
	if instructions.get("should_remove_cards", false) and \
	   instructions.get("has_player_third", false) and \
	   instructions.get("has_banker_third", false):
		print("  ✅ PASS: Инструкции корректны для обеих третьих карт")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидались обе третьи карты")
		failed += 1
	
	# Тест 5: remove_third_cards без третьих карт
	print("\n📋 Тест 5: remove_third_cards без третьих карт")
	hand_manager.reset()
	var removed = coordinator.remove_third_cards()
	if not removed:
		print("  ✅ PASS: Карты не удалены (нечего удалять)")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие удаления")
		failed += 1
	
	# Тест 6: remove_third_cards с третьей картой игрока
	print("\n📋 Тест 6: remove_third_cards с третьей картой игрока")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	card_dealer.draw_player_third(deck, hand_manager)
	var player_size_before = hand_manager.get_player_size()
	removed = coordinator.remove_third_cards()
	var player_size_after = hand_manager.get_player_size()
	if removed and player_size_after == player_size_before - 1:
		print("  ✅ PASS: Третья карта игрока удалена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось удаление третьей карты игрока")
		failed += 1
	
	# Тест 7: remove_third_cards с третьей картой банкира
	print("\n📋 Тест 7: remove_third_cards с третьей картой банкира")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	card_dealer.draw_banker_third(deck, hand_manager)
	var banker_size_before = hand_manager.get_banker_size()
	removed = coordinator.remove_third_cards()
	var banker_size_after = hand_manager.get_banker_size()
	if removed and banker_size_after == banker_size_before - 1:
		print("  ✅ PASS: Третья карта банкира удалена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось удаление третьей карты банкира")
		failed += 1
	
	# Тест 8: remove_third_cards с обеими третьими картами
	print("\n📋 Тест 8: remove_third_cards с обеими третьими картами")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	card_dealer.draw_player_third(deck, hand_manager)
	card_dealer.draw_banker_third(deck, hand_manager)
	var player_size_before_both = hand_manager.get_player_size()
	var banker_size_before_both = hand_manager.get_banker_size()
	removed = coordinator.remove_third_cards()
	var player_size_after_both = hand_manager.get_player_size()
	var banker_size_after_both = hand_manager.get_banker_size()
	if removed and \
	   player_size_after_both == player_size_before_both - 1 and \
	   banker_size_after_both == banker_size_before_both - 1:
		print("  ✅ PASS: Обе третьи карты удалены корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось удаление обеих третьих карт")
		failed += 1
	
	# Тест 9: get_removal_instructions без HandManager
	print("\n📋 Тест 9: get_removal_instructions без HandManager")
	var coordinator_no_hand = ThirdCardRemovalCoordinator.new(null)
	instructions = coordinator_no_hand.get_removal_instructions()
	if not instructions.get("should_remove_cards", true) and \
	   not instructions.get("has_player_third", true) and \
	   not instructions.get("has_banker_third", true):
		print("  ✅ PASS: Без HandManager обработано корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие действий без HandManager")
		failed += 1
	
	# Тест 10: remove_third_cards без HandManager
	print("\n📋 Тест 10: remove_third_cards без HandManager")
	removed = coordinator_no_hand.remove_third_cards()
	if not removed:
		print("  ✅ PASS: Без HandManager удаление не выполнено")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие удаления без HandManager")
		failed += 1
	
	# Тест 11: Проверка структуры инструкций
	print("\n📋 Тест 11: Проверка структуры инструкций")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	card_dealer.draw_player_third(deck, hand_manager)
	instructions = coordinator.get_removal_instructions()
	var has_should_remove = instructions.has("should_remove_cards")
	var has_player_third = instructions.has("has_player_third")
	var has_banker_third = instructions.has("has_banker_third")
	var has_reset_flags = instructions.has("should_reset_flags")
	var has_update_ui = instructions.has("should_update_ui")
	var has_recalculate = instructions.has("should_recalculate_state")
	if has_should_remove and has_player_third and has_banker_third and \
	   has_reset_flags and has_update_ui and has_recalculate:
		print("  ✅ PASS: Все поля присутствуют в инструкциях")
		passed += 1
	else:
		print("  ❌ FAIL: Отсутствуют поля в инструкциях")
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

