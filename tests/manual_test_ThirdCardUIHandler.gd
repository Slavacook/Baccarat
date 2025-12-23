# res://tests/manual_test_ThirdCardUIHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ ThirdCardUIHandler (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ ThirdCardUIHandler")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var handler = ThirdCardUIHandler.new()
	
	# Тест 1: handle_player_third_toggled с false -> true
	print("📋 Тест 1: handle_player_third_toggled с false -> true")
	var instructions1 = handler.handle_player_third_toggled(false)
	if instructions1.get("new_selected") == true and \
	   instructions1.get("ui_text") == "!" and \
	   instructions1.get("should_deselect_winner") == true:
		print("  ✅ PASS: Переключение с false на true корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось new_selected=true, ui_text='!', should_deselect_winner=true")
		tests_failed += 1
	
	# Тест 2: handle_player_third_toggled с true -> false
	print("")
	print("📋 Тест 2: handle_player_third_toggled с true -> false")
	var instructions2 = handler.handle_player_third_toggled(true)
	if instructions2.get("new_selected") == false and \
	   instructions2.get("ui_text") == "?" and \
	   instructions2.get("should_deselect_winner") == true:
		print("  ✅ PASS: Переключение с true на false корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось new_selected=false, ui_text='?', should_deselect_winner=true")
		tests_failed += 1
	
	# Тест 3: handle_banker_third_toggled с false -> true
	print("")
	print("📋 Тест 3: handle_banker_third_toggled с false -> true")
	var instructions3 = handler.handle_banker_third_toggled(false)
	if instructions3.get("new_selected") == true and \
	   instructions3.get("ui_text") == "!" and \
	   instructions3.get("should_deselect_winner") == true:
		print("  ✅ PASS: Переключение банкира с false на true корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось new_selected=true, ui_text='!', should_deselect_winner=true")
		tests_failed += 1
	
	# Тест 4: handle_banker_third_toggled с true -> false
	print("")
	print("📋 Тест 4: handle_banker_third_toggled с true -> false")
	var instructions4 = handler.handle_banker_third_toggled(true)
	if instructions4.get("new_selected") == false and \
	   instructions4.get("ui_text") == "?" and \
	   instructions4.get("should_deselect_winner") == true:
		print("  ✅ PASS: Переключение банкира с true на false корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось new_selected=false, ui_text='?', should_deselect_winner=true")
		tests_failed += 1
	
	# Тест 5: get_cancel_instructions оба выбраны
	print("")
	print("📋 Тест 5: get_cancel_instructions оба выбраны")
	var instructions5 = handler.get_cancel_instructions(true, true)
	if instructions5.get("should_cancel_player") == true and \
	   instructions5.get("should_cancel_banker") == true and \
	   instructions5.get("player_ui_text") == "?" and \
	   instructions5.get("banker_ui_text") == "?":
		print("  ✅ PASS: Отмена обоих заказов корректна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_cancel_player=true, should_cancel_banker=true, оба ui_text='?'")
		tests_failed += 1
	
	# Тест 6: get_cancel_instructions только игрок выбран
	print("")
	print("📋 Тест 6: get_cancel_instructions только игрок выбран")
	var instructions6 = handler.get_cancel_instructions(true, false)
	if instructions6.get("should_cancel_player") == true and \
	   instructions6.get("should_cancel_banker") == false and \
	   instructions6.get("player_ui_text") == "?" and \
	   instructions6.get("banker_ui_text") == "":
		print("  ✅ PASS: Отмена только игрока корректна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_cancel_player=true, should_cancel_banker=false")
		tests_failed += 1
	
	# Тест 7: get_cancel_instructions ни один не выбран
	print("")
	print("📋 Тест 7: get_cancel_instructions ни один не выбран")
	var instructions7 = handler.get_cancel_instructions(false, false)
	if instructions7.get("should_cancel_player") == false and \
	   instructions7.get("should_cancel_banker") == false and \
	   instructions7.get("player_ui_text") == "" and \
	   instructions7.get("banker_ui_text") == "":
		print("  ✅ PASS: Отмена при отсутствии выбора корректна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_cancel_player=false, should_cancel_banker=false")
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

