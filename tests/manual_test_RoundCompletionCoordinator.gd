# res://tests/manual_test_RoundCompletionCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ RoundCompletionCoordinator (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ RoundCompletionCoordinator")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var coordinator = RoundCompletionCoordinator.new()
	
	# Тест 1: can_complete_round без менеджеров
	print("📋 Тест 1: can_complete_round без менеджеров")
	var result1 = coordinator.can_complete_round(null, null)
	if result1.get("can_complete") and result1.get("error_key") == "":
		print("  ✅ PASS: Можно завершить без менеджеров")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось can_complete=true, error_key=''")
		tests_failed += 1
	
	# Тест 2: get_completion_message без менеджера
	print("")
	print("📋 Тест 2: get_completion_message без менеджера")
	var result2 = coordinator.get_completion_message(null)
	if result2.get("message_key") == "NO_ACTIVE_BETS" and not result2.get("has_bets"):
		print("  ✅ PASS: Сообщение NO_ACTIVE_BETS без ставок")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось message_key=NO_ACTIVE_BETS, has_bets=false")
		tests_failed += 1
	
	# Тест 3: get_completion_instructions с Heart Bet
	print("")
	print("📋 Тест 3: get_completion_instructions с Heart Bet")
	var instructions1 = coordinator.get_completion_instructions(true, false)
	if instructions1.get("should_resolve_heart_bet") and not instructions1.get("should_reset_round"):
		print("  ✅ PASS: Инструкции для Heart Bet корректны")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_resolve_heart_bet=true, should_reset_round=false")
		tests_failed += 1
	
	# Тест 4: get_completion_instructions обычный режим
	print("")
	print("📋 Тест 4: get_completion_instructions обычный режим")
	var instructions2 = coordinator.get_completion_instructions(false, false)
	if instructions2.get("should_reset_round") and instructions2.get("should_add_score"):
		print("  ✅ PASS: Инструкции для обычного режима корректны")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_reset_round=true, should_add_score=true")
		tests_failed += 1
	
	# Тест 5: get_completion_instructions режим выживания
	print("")
	print("📋 Тест 5: get_completion_instructions режим выживания")
	var instructions3 = coordinator.get_completion_instructions(false, true)
	if instructions3.get("should_reset_round") and not instructions3.get("should_add_score"):
		print("  ✅ PASS: Инструкции для режима выживания корректны")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_reset_round=true, should_add_score=false")
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

