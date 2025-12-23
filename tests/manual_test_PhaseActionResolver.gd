# res://tests/manual_test_PhaseActionResolver.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ PhaseActionResolver (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ PhaseActionResolver")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var resolver = PhaseActionResolver.new()
	
	# Тест 1: Стол подготовлен
	print("📋 Тест 1: Стол подготовлен")
	var result1 = resolver.resolve_action(true, GameStateManager.GameState.WAITING)
	if result1.get("action") == "deal_first_four" and result1.get("phase") == "table_preparation":
		print("  ✅ PASS: Стол подготовлен → deal_first_four")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось action=deal_first_four, phase=table_preparation")
		tests_failed += 1
	
	# Тест 2: Состояние WAITING
	print("")
	print("📋 Тест 2: Состояние WAITING")
	var result2 = resolver.resolve_action(false, GameStateManager.GameState.WAITING)
	if result2.get("action") == "deal_first_four" and result2.get("phase") == "waiting":
		print("  ✅ PASS: WAITING → deal_first_four")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось action=deal_first_four, phase=waiting")
		tests_failed += 1
	
	# Тест 3: Состояние CARD_TO_BANKER_AFTER_PLAYER
	print("")
	print("📋 Тест 3: Состояние CARD_TO_BANKER_AFTER_PLAYER")
	var result3 = resolver.resolve_action(false, GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER)
	if result3.get("action") == "validate_banker_after_player" and result3.get("phase") == "banker_after_player":
		print("  ✅ PASS: CARD_TO_BANKER_AFTER_PLAYER → validate_banker_after_player")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось action=validate_banker_after_player, phase=banker_after_player")
		tests_failed += 1
	
	# Тест 4: Состояние CHOOSE_WINNER
	print("")
	print("📋 Тест 4: Состояние CHOOSE_WINNER")
	var result4 = resolver.resolve_action(false, GameStateManager.GameState.CHOOSE_WINNER)
	if result4.get("action") == "handle_choose_winner" and result4.get("phase") == "choose_winner":
		print("  ✅ PASS: CHOOSE_WINNER → handle_choose_winner")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось action=handle_choose_winner, phase=choose_winner")
		tests_failed += 1
	
	# Тест 5: Fallback (CARD_TO_EACH)
	print("")
	print("📋 Тест 5: Fallback (CARD_TO_EACH)")
	var result5 = resolver.resolve_action(false, GameStateManager.GameState.CARD_TO_EACH)
	if result5.get("action") == "validate_third_cards" and result5.get("phase") == "third_cards":
		print("  ✅ PASS: CARD_TO_EACH → validate_third_cards (fallback)")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось action=validate_third_cards, phase=third_cards")
		tests_failed += 1
	
	# Тест 6: Приоритет подготовки стола
	print("")
	print("📋 Тест 6: Приоритет подготовки стола над состоянием")
	var result6 = resolver.resolve_action(true, GameStateManager.GameState.CHOOSE_WINNER)
	if result6.get("action") == "deal_first_four":
		print("  ✅ PASS: Подготовка стола имеет приоритет над состоянием")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось action=deal_first_four (приоритет подготовки)")
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

