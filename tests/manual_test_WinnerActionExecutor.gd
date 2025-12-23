# res://tests/manual_test_WinnerActionExecutor.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ WinnerActionExecutor (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ WinnerActionExecutor")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var executor = WinnerActionExecutor.new()
	
	# Тест 1: get_action_instructions с невалидным результатом
	print("📋 Тест 1: get_action_instructions с невалидным результатом")
	var invalid_result = {
		"is_valid": false,
		"error_type": "winner_wrong",
		"error_message": "ERR_WRONG_WINNER",
		"error_message_params": ["Player"]
	}
	var instructions1 = executor.get_action_instructions(invalid_result, "Banker")
	if instructions1.get("should_show_error") == true and \
	   instructions1.get("error_type") == "winner_wrong" and \
	   instructions1.get("should_reset_winner_selection") == true:
		print("  ✅ PASS: Невалидный результат обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_show_error=true, error_type='winner_wrong'")
		tests_failed += 1
	
	# Тест 2: get_action_instructions с валидным результатом
	print("")
	print("📋 Тест 2: get_action_instructions с валидным результатом")
	var valid_result = {
		"is_valid": true
	}
	var instructions2 = executor.get_action_instructions(valid_result, "Player")
	if instructions2.get("should_show_error") == false and \
	   instructions2.get("should_emit_correct") == true and \
	   instructions2.get("should_update_button_state") == true and \
	   instructions2.get("button_state") == "complete":
		print("  ✅ PASS: Валидный результат обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_show_error=false, should_emit_correct=true")
		tests_failed += 1
	
	# Тест 3: Проверка триггеров в валидном результате
	print("")
	print("📋 Тест 3: Проверка триггеров в валидном результате")
	var instructions3 = executor.get_action_instructions(valid_result, "Banker")
	if instructions3.get("should_check_heart_bet_triggers") == true and \
	   instructions3.get("should_check_chance_card_triggers") == true:
		print("  ✅ PASS: Триггеры должны проверяться")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_check_heart_bet_triggers=true, should_check_chance_card_triggers=true")
		tests_failed += 1
	
	# Тест 4: Структура инструкций для невалидного результата
	print("")
	print("📋 Тест 4: Структура инструкций для невалидного результата")
	var required_fields_error = ["should_show_error", "error_type", "error_message", 
	                            "error_params", "should_reset_winner_selection"]
	var all_present_error = true
	for field in required_fields_error:
		if not instructions1.has(field):
			all_present_error = false
			break
	if all_present_error:
		print("  ✅ PASS: Все поля присутствуют в инструкциях для ошибки")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Не все поля присутствуют")
		tests_failed += 1
	
	# Тест 5: Структура инструкций для валидного результата
	print("")
	print("📋 Тест 5: Структура инструкций для валидного результата")
	var required_fields_valid = ["should_show_error", "should_emit_correct", 
	                            "should_check_heart_bet_triggers", "should_check_chance_card_triggers",
	                            "should_update_button_state", "button_state"]
	var all_present_valid = true
	for field in required_fields_valid:
		if not instructions2.has(field):
			all_present_valid = false
			break
	if all_present_valid:
		print("  ✅ PASS: Все поля присутствуют в инструкциях для валидного результата")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Не все поля присутствуют")
		tests_failed += 1
	
	# Тест 6: Параметры ошибки передаются корректно
	print("")
	print("📋 Тест 6: Параметры ошибки передаются корректно")
	var error_params = instructions1.get("error_params", [])
	if error_params.size() == 1 and error_params[0] == "Player":
		print("  ✅ PASS: Параметры ошибки переданы корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось error_params=['Player']")
		tests_failed += 1
	
	# Тест 7: Состояние кнопки устанавливается корректно
	print("")
	print("📋 Тест 7: Состояние кнопки устанавливается корректно")
	if instructions2.get("button_state") == "complete":
		print("  ✅ PASS: Состояние кнопки установлено в 'complete'")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось button_state='complete'")
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

