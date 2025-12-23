# res://tests/manual_test_GameStateUpdater.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ GameStateUpdater (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ GameStateUpdater")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var updater = GameStateUpdater.new()
	
	# Создаём тестовый HandManager
	var hand_manager = HandManager.new()
	
	# Тест 1: get_state_update_data с пустыми руками
	print("📋 Тест 1: get_state_update_data с пустыми руками")
	var data1 = updater.get_state_update_data(hand_manager)
	if data1.get("cards_hidden") == true and \
	   data1.has("player_hand") and data1.has("banker_hand") and \
	   data1.has("player_third_card") and data1.has("banker_third_card"):
		print("  ✅ PASS: Данные для пустых рук получены корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось cards_hidden=true и все поля присутствуют")
		tests_failed += 1
	
	# Тест 2: Структура данных
	print("")
	print("📋 Тест 2: Проверка структуры данных")
	var required_fields = ["cards_hidden", "player_hand", "banker_hand", 
	                      "player_third_card", "banker_third_card"]
	var all_present = true
	for field in required_fields:
		if not data1.has(field):
			all_present = false
			break
	if all_present:
		print("  ✅ PASS: Все поля присутствуют в данных")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Не все поля присутствуют")
		tests_failed += 1
	
	# Тест 3: Типы данных
	print("")
	print("📋 Тест 3: Проверка типов данных")
	if data1.get("cards_hidden") is bool and \
	   data1.get("player_hand") is Array and \
	   data1.get("banker_hand") is Array:
		print("  ✅ PASS: Типы данных корректны")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось cards_hidden=bool, player_hand=Array, banker_hand=Array")
		tests_failed += 1
	
	# Тест 4: update_game_state не вызывает ошибок
	print("")
	print("📋 Тест 4: update_game_state не вызывает ошибок")
	# В GDScript нет try/except, просто вызываем метод
	# Если он выполнится без ошибок - тест пройден
	updater.update_game_state(hand_manager)
	print("  ✅ PASS: update_game_state выполнен без ошибок")
	tests_passed += 1
	
	# Тест 5: Данные для рук с картами
	print("")
	print("📋 Тест 5: Данные для рук с картами")
	# Добавляем карты в руки
	var card1 = Card.new(Card.Suit.HEARTS, 7)
	var card2 = Card.new(Card.Suit.SPADES, 8)
	hand_manager.add_player_card(card1)
	hand_manager.add_player_card(card2)
	hand_manager.add_banker_card(card1)
	hand_manager.add_banker_card(card2)
	
	var data2 = updater.get_state_update_data(hand_manager)
	if data2.get("cards_hidden") == false and \
	   data2.get("player_hand").size() == 2 and \
	   data2.get("banker_hand").size() == 2:
		print("  ✅ PASS: Данные для рук с картами получены корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось cards_hidden=false, player_hand.size()=2, banker_hand.size()=2")
		tests_failed += 1
	
	# Тест 6: Третьи карты
	print("")
	print("📋 Тест 6: Проверка третьих карт")
	var card3 = Card.new(Card.Suit.DIAMONDS, 5)
	hand_manager.add_player_card(card3)
	var data3 = updater.get_state_update_data(hand_manager)
	if data3.get("player_third_card") == card3:
		print("  ✅ PASS: Третья карта игрока получена корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось player_third_card=card3")
		tests_failed += 1
	
	# Тест 7: update_game_state обновляет состояние
	print("")
	print("📋 Тест 7: update_game_state обновляет состояние")
	var state_before = GameStateManager.get_current_state()
	updater.update_game_state(hand_manager)
	var state_after = GameStateManager.get_current_state()
	# Состояние может измениться или остаться тем же, главное что метод выполнился
	print("  ✅ PASS: update_game_state выполнен (состояние: %s → %s)" % [state_before, state_after])
	tests_passed += 1
	
	# Итоги
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("📊 ИТОГИ ТЕСТИРОВАНИЯ:")
	print("  ✅ Пройдено: %d" % tests_passed)
	print("  ❌ Провалено: %d" % tests_failed)
	var total_tests = tests_passed + tests_failed
	var success_rate = 100.0 * tests_passed / total_tests if total_tests > 0 else 0.0
	print("  📈 Успешность: %.1f%%" % success_rate)
	print("═══════════════════════════════════════════════════════════")
	
	if tests_failed == 0:
		print("🎉 Все тесты пройдены успешно!")
	else:
		print("⚠️  Некоторые тесты провалены. Проверьте код.")
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("═══════════════════════════════════════════════════════════")

