# res://tests/manual_test_GameStateResetCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ GameStateResetCoordinator (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ GameStateResetCoordinator")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var coordinator = GameStateResetCoordinator.new()
	
	# Тест 1: Инструкции по умолчанию
	print("📋 Тест 1: Инструкции по умолчанию")
	var instructions1 = coordinator.get_reset_instructions()
	if instructions1.get("should_reset_hands") and instructions1.get("should_clear_chips") and instructions1.get("should_update_state"):
		print("  ✅ PASS: Инструкции по умолчанию корректны")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидались все флаги true")
		tests_failed += 1
	
	# Тест 2: Инструкции с keep_guest_bets=true
	print("")
	print("📋 Тест 2: Инструкции с keep_guest_bets=true")
	var instructions2 = coordinator.get_reset_instructions(true, true)
	if not instructions2.get("should_clear_chips") and not instructions2.get("should_clear_guest_bets"):
		print("  ✅ PASS: Фишки и ставки гостей не очищаются при keep_guest_bets=true")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_clear_chips=false, should_clear_guest_bets=false")
		tests_failed += 1
	
	# Тест 3: Инструкции с update_state=false
	print("")
	print("📋 Тест 3: Инструкции с update_state=false")
	var instructions3 = coordinator.get_reset_instructions(false, false)
	if not instructions3.get("should_update_state") and instructions3.get("should_invalidate_cache"):
		print("  ✅ PASS: Состояние не обновляется, но кэш инвалидируется")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_update_state=false, should_invalidate_cache=true")
		tests_failed += 1
	
	# Тест 4: Все поля присутствуют
	print("")
	print("📋 Тест 4: Все поля присутствуют в инструкциях")
	var instructions4 = coordinator.get_reset_instructions()
	var required_fields = ["should_reset_hands", "should_reset_ui", "should_clear_chips", 
	                      "should_clear_guest_bets", "should_update_state", "should_invalidate_cache",
	                      "should_reset_managers", "should_hide_ui_elements"]
	var all_present = true
	for field in required_fields:
		if not instructions4.has(field):
			all_present = false
			break
	if all_present:
		print("  ✅ PASS: Все поля присутствуют")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Не все поля присутствуют")
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

