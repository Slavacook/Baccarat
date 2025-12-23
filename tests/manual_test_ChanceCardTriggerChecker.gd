# res://tests/manual_test_ChanceCardTriggerChecker.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ ChanceCardTriggerChecker (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ ChanceCardTriggerChecker")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var checker = ChanceCardTriggerChecker.new()
	
	# Тест 1: Heart Card триггер
	print("📋 Тест 1: Heart Card триггер (банкир выиграл с 6)")
	var player_hand1 = [Card.new(Card.Suit.HEARTS, 3), Card.new(Card.Suit.DIAMONDS, 2)]
	var banker_hand1 = [Card.new(Card.Suit.CLUBS, 3), Card.new(Card.Suit.SPADES, 3)]  # 6 очков
	var result1 = checker.check_triggers_after_winner("Banker", player_hand1, banker_hand1)
	if result1.get("heart_card"):
		print("  ✅ PASS: Heart Card триггер сработал")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось heart_card=true")
		tests_failed += 1
	
	# Тест 2: Heart Bet Card триггер
	print("")
	print("📋 Тест 2: Heart Bet Card триггер (Tie)")
	var player_hand2 = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 3)]
	var banker_hand2 = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 1)]  # 8 очков = Tie
	var result2 = checker.check_triggers_after_winner("Tie", player_hand2, banker_hand2)
	if result2.get("heart_bet_card"):
		print("  ✅ PASS: Heart Bet Card триггер сработал")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось heart_bet_card=true")
		tests_failed += 1
	
	# Тест 3: Revolver Card триггер
	print("")
	print("📋 Тест 3: Revolver Card триггер (все 6 карт по 0 очков)")
	var player_hand3 = [
		Card.new(Card.Suit.HEARTS, 10),
		Card.new(Card.Suit.DIAMONDS, 11),
		Card.new(Card.Suit.CLUBS, 12)
	]
	var banker_hand3 = [
		Card.new(Card.Suit.SPADES, 13),
		Card.new(Card.Suit.HEARTS, 10),
		Card.new(Card.Suit.DIAMONDS, 11)
	]
	var result3 = checker.check_triggers_after_winner("Player", player_hand3, banker_hand3)
	if result3.get("revolver_card"):
		print("  ✅ PASS: Revolver Card триггер сработал")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось revolver_card=true")
		tests_failed += 1
	
	# Тест 4: Mystery Card триггер
	print("")
	print("📋 Тест 4: Mystery Card триггер (пара тузов)")
	var player_hand4 = [Card.new(Card.Suit.HEARTS, 1), Card.new(Card.Suit.DIAMONDS, 1)]
	var banker_hand4 = [Card.new(Card.Suit.CLUBS, 5), Card.new(Card.Suit.SPADES, 3)]
	var result4 = checker.check_triggers_after_deal(player_hand4, banker_hand4, false, false)
	if result4.get("mystery_card"):
		print("  ✅ PASS: Mystery Card триггер сработал")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось mystery_card=true")
		tests_failed += 1
	
	# Тест 5: Third Card Change триггер
	print("")
	print("📋 Тест 5: Third Card Change триггер (две пары)")
	var player_hand5 = [Card.new(Card.Suit.HEARTS, 5), Card.new(Card.Suit.DIAMONDS, 5)]
	var banker_hand5 = [Card.new(Card.Suit.CLUBS, 7), Card.new(Card.Suit.SPADES, 7)]
	var result5 = checker.check_triggers_after_deal(player_hand5, banker_hand5, true, true)
	if result5.get("third_card_change"):
		print("  ✅ PASS: Third Card Change триггер сработал")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось third_card_change=true")
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

