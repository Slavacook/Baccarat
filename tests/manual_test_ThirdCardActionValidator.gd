# res://tests/manual_test_ThirdCardActionValidator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ ThirdCardActionValidator (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ ThirdCardActionValidator")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var validator = ThirdCardActionValidator.new()
	
	# Тест 1: Натуральная комбинация
	print("📋 Тест 1: Натуральная комбинация (8-7)")
	var result1 = validator.validate_third_card_action(8, 7, false, false, false, null)
	if result1.get("is_valid") and result1.get("action") == "complete":
		print("  ✅ PASS: Натуральная комбинация валидна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, action=complete")
		tests_failed += 1
	
	# Тест 2: Карта каждому
	print("")
	print("📋 Тест 2: Карта каждому (5-2, оба выбрали)")
	var result2 = validator.validate_third_card_action(5, 2, true, true, false, null)
	if result2.get("is_valid") and result2.get("action") == "draw_both":
		print("  ✅ PASS: Карта каждому валидна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, action=draw_both")
		tests_failed += 1
	
	# Тест 3: Карта игроку (банкир 7)
	print("")
	print("📋 Тест 3: Карта игроку (5-7, игрок выбрал)")
	var result3 = validator.validate_third_card_action(5, 7, true, false, false, null)
	if result3.get("is_valid") and result3.get("action") == "draw_player":
		print("  ✅ PASS: Карта игроку валидна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, action=draw_player")
		tests_failed += 1
	
	# Тест 4: Карта игроку (банкир 3-6)
	print("")
	print("📋 Тест 4: Карта игроку (5-4, игрок выбрал, банкир решает потом)")
	var result4 = validator.validate_third_card_action(5, 4, true, false, false, null)
	if result4.get("is_valid") and result4.get("action") == "draw_player" and result4.get("needs_banker_decision"):
		print("  ✅ PASS: Карта игроку с needs_banker_decision валидна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, action=draw_player, needs_banker_decision=true")
		tests_failed += 1
	
	# Тест 5: Карта банкиру
	print("")
	print("📋 Тест 5: Карта банкиру (7-3, банкир выбрал)")
	var result5 = validator.validate_third_card_action(7, 3, false, true, false, null)
	if result5.get("is_valid") and result5.get("action") == "draw_banker":
		print("  ✅ PASS: Карта банкиру валидна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, action=draw_banker")
		tests_failed += 1
	
	# Тест 6: Валидация банкира после игрока
	print("")
	print("📋 Тест 6: Валидация банкира после игрока (банкир 3, выбрал, игрок взял 5)")
	var player_card = Card.new(Card.Suit.HEARTS, 5)
	var result6 = validator.validate_banker_after_player(3, true, true, player_card)
	if result6.get("is_valid") and result6.get("action") == "draw_banker":
		print("  ✅ PASS: Банкир должен взять карту")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось is_valid=true, action=draw_banker")
		tests_failed += 1
	
	# Итоги
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("📊 ИТОГИ ТЕСТИРОВАНИЯ:")
	print("  ✅ Пройдено: %d" % tests_passed)
	print("  ❌ Провалено: %d" % tests_failed)
	print("  📈 Успешность: %.1f%%" % (100.0 * tests_passed / (tests_passed + tests_failed) if (tests_passed + tests_failed) > 0 else 0))
	print("═══════════════════════════════════════════════════════════")
	
	if tests_failed == 0:
		print("🎉 Все тесты пройдены успешно!")
	else:
		print("⚠️  Некоторые тесты провалены. Проверьте код.")
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("═══════════════════════════════════════════════════════════")

