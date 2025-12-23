# res://tests/manual_test_WinnerSelectionValidator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ WinnerSelectionValidator (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ WinnerSelectionValidator")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var validator = WinnerSelectionValidator.new()
	
	# Тест 1: Нет выбора
	print("📋 Тест 1: Нет выбора победителя")
	var player_hand1 = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	var banker_hand1 = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 2)]
	var result1 = validator.validate_winner_selection("", player_hand1, banker_hand1)
	if not result1.get("is_valid") and result1.get("needs_selection"):
		print("  ✅ PASS: Нет выбора обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=false, needs_selection=true")
		tests_failed += 1
	
	# Тест 2: Правильный выбор Player
	print("")
	print("📋 Тест 2: Правильный выбор Player")
	var player_hand2 = [Card.new(Card.Suit.HEARTS, 7), Card.new(Card.Suit.DIAMONDS, 2)]
	var banker_hand2 = [Card.new(Card.Suit.CLUBS, 5), Card.new(Card.Suit.SPADES, 3)]
	var result2 = validator.validate_winner_selection("Player", player_hand2, banker_hand2)
	if result2.get("is_valid") and result2.get("actual_winner") == "Player":
		print("  ✅ PASS: Правильный выбор Player валиден")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, actual_winner=Player")
		tests_failed += 1
	
	# Тест 3: Правильный выбор Banker
	print("")
	print("📋 Тест 3: Правильный выбор Banker")
	var player_hand3 = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	var banker_hand3 = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 2)]
	var result3 = validator.validate_winner_selection("Banker", player_hand3, banker_hand3)
	if result3.get("is_valid") and result3.get("actual_winner") == "Banker":
		print("  ✅ PASS: Правильный выбор Banker валиден")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, actual_winner=Banker")
		tests_failed += 1
	
	# Тест 4: Правильный выбор Tie
	print("")
	print("📋 Тест 4: Правильный выбор Tie")
	var player_hand4 = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	var banker_hand4 = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 1)]
	var result4 = validator.validate_winner_selection("Tie", player_hand4, banker_hand4)
	if result4.get("is_valid") and result4.get("actual_winner") == "Tie":
		print("  ✅ PASS: Правильный выбор Tie валиден")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, actual_winner=Tie")
		tests_failed += 1
	
	# Тест 5: Неправильный выбор Player вместо Banker
	print("")
	print("📋 Тест 5: Неправильный выбор Player вместо Banker")
	var player_hand5 = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	var banker_hand5 = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 2)]
	var result5 = validator.validate_winner_selection("Player", player_hand5, banker_hand5)
	if not result5.get("is_valid") and result5.get("error_type") == "winner_wrong" and result5.get("actual_winner") == "Banker":
		print("  ✅ PASS: Неправильный выбор обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=false, error_type=winner_wrong, actual_winner=Banker")
		tests_failed += 1
	
	# Тест 6: Неправильный выбор вместо Tie
	print("")
	print("📋 Тест 6: Неправильный выбор Player вместо Tie")
	var player_hand6 = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	var banker_hand6 = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 1)]
	var result6 = validator.validate_winner_selection("Player", player_hand6, banker_hand6)
	if not result6.get("is_valid") and result6.get("actual_winner") == "Tie" and result6.get("error_message") == "Ошибка! Неправильный выбор. Игалите":
		print("  ✅ PASS: Неправильный выбор вместо Tie обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=false, actual_winner=Tie, специальное сообщение для Tie")
		tests_failed += 1
	
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
