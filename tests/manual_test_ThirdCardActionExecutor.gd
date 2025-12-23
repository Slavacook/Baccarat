# res://tests/manual_test_ThirdCardActionExecutor.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ ThirdCardActionExecutor (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ ThirdCardActionExecutor")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var executor = ThirdCardActionExecutor.new()
	
	# Тест 1: get_action_instructions с невалидным результатом
	print("📋 Тест 1: get_action_instructions с невалидным результатом")
	var invalid_result = {
		"is_valid": false,
		"error_type": "player_wrong",
		"error_message": "ERR_PLAYER_MUST_DRAW",
		"should_reset_player": true,
		"should_reset_banker": false
	}
	var instructions1 = executor.get_action_instructions(invalid_result)
	if instructions1.get("should_show_error") == true and \
	   instructions1.get("error_type") == "player_wrong" and \
	   instructions1.get("should_reset_player") == true:
		print("  ✅ PASS: Невалидный результат обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_show_error=true, error_type='player_wrong'")
		tests_failed += 1
	
	# Тест 2: get_action_instructions с валидным результатом "draw_both"
	print("")
	print("📋 Тест 2: get_action_instructions с валидным результатом 'draw_both'")
	var valid_result1 = {
		"is_valid": true,
		"action": "draw_both",
		"needs_banker_decision": false
	}
	var instructions2 = executor.get_action_instructions(valid_result1)
	if instructions2.get("should_show_error") == false and \
	   instructions2.get("action") == "draw_both" and \
	   instructions2.get("needs_banker_decision") == false:
		print("  ✅ PASS: Действие 'draw_both' определено корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_show_error=false, action='draw_both'")
		tests_failed += 1
	
	# Тест 3: get_action_instructions с валидным результатом "draw_player" с needs_banker_decision
	print("")
	print("📋 Тест 3: get_action_instructions с 'draw_player' и needs_banker_decision=true")
	var valid_result2 = {
		"is_valid": true,
		"action": "draw_player",
		"needs_banker_decision": true
	}
	var instructions3 = executor.get_action_instructions(valid_result2)
	if instructions3.get("should_show_error") == false and \
	   instructions3.get("action") == "draw_player" and \
	   instructions3.get("needs_banker_decision") == true:
		print("  ✅ PASS: Действие 'draw_player' с needs_banker_decision определено корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось action='draw_player', needs_banker_decision=true")
		tests_failed += 1
	
	# Тест 4: get_banker_action_instructions с невалидным результатом
	print("")
	print("📋 Тест 4: get_banker_action_instructions с невалидным результатом")
	var invalid_banker_result = {
		"is_valid": false,
		"error_type": "banker_wrong",
		"error_message": "ERR_BANKER_MUST_DRAW",
		"should_reset_banker": true
	}
	var instructions4 = executor.get_banker_action_instructions(invalid_banker_result)
	if instructions4.get("should_show_error") == true and \
	   instructions4.get("error_type") == "banker_wrong" and \
	   instructions4.get("should_reset_banker") == true:
		print("  ✅ PASS: Невалидный результат банкира обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_show_error=true, error_type='banker_wrong'")
		tests_failed += 1
	
	# Тест 5: get_banker_action_instructions с валидным результатом "draw_banker"
	print("")
	print("📋 Тест 5: get_banker_action_instructions с валидным результатом 'draw_banker'")
	var valid_banker_result = {
		"is_valid": true,
		"action": "draw_banker"
	}
	var instructions5 = executor.get_banker_action_instructions(valid_banker_result)
	if instructions5.get("should_show_error") == false and \
	   instructions5.get("action") == "draw_banker":
		print("  ✅ PASS: Действие банкира 'draw_banker' определено корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_show_error=false, action='draw_banker'")
		tests_failed += 1
	
	# Тест 6: get_banker_action_instructions с валидным результатом "complete"
	print("")
	print("📋 Тест 6: get_banker_action_instructions с валидным результатом 'complete'")
	var complete_result = {
		"is_valid": true,
		"action": "complete"
	}
	var instructions6 = executor.get_banker_action_instructions(complete_result)
	if instructions6.get("should_show_error") == false and \
	   instructions6.get("action") == "complete":
		print("  ✅ PASS: Действие банкира 'complete' определено корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_show_error=false, action='complete'")
		tests_failed += 1
	
	# Тест 7: Структура инструкций
	print("")
	print("📋 Тест 7: Проверка структуры инструкций")
	var instructions7 = executor.get_action_instructions(valid_result1)
	var required_fields = ["should_reset_player", "should_reset_banker", "should_show_error", 
	                      "error_type", "error_message", "action", "needs_banker_decision"]
	var all_present = true
	for field in required_fields:
		if not instructions7.has(field):
			all_present = false
			break
	if all_present:
		print("  ✅ PASS: Все поля присутствуют в инструкциях")
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

