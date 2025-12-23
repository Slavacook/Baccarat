# res://tests/manual_test_ValidationErrorFormatter.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ ValidationErrorFormatter (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ ValidationErrorFormatter")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var formatter = ValidationErrorFormatter.new()
	
	# Тест 1: format_third_card_error для игрока
	print("📋 Тест 1: format_third_card_error для игрока")
	var message1 = formatter.format_third_card_error("ERR_PLAYER_NO_DRAW", 7, -1)
	if not message1.is_empty():
		print("  ✅ PASS: Сообщение отформатировано: %s" % message1)
		tests_passed += 1
	else:
		print("  ❌ FAIL: Сообщение пустое")
		tests_failed += 1
	
	# Тест 2: format_third_card_error для банкира
	print("")
	print("📋 Тест 2: format_third_card_error для банкира")
	var message2 = formatter.format_third_card_error("ERR_BANKER_MUST_DRAW", -1, 5)
	if not message2.is_empty():
		print("  ✅ PASS: Сообщение отформатировано: %s" % message2)
		tests_passed += 1
	else:
		print("  ❌ FAIL: Сообщение пустое")
		tests_failed += 1
	
	# Тест 3: format_winner_selection_error с параметрами
	print("")
	print("📋 Тест 3: format_winner_selection_error с параметрами")
	var message3 = formatter.format_winner_selection_error("ERR_WRONG_WINNER", ["Banker"])
	if not message3.is_empty():
		print("  ✅ PASS: Сообщение отформатировано: %s" % message3)
		tests_passed += 1
	else:
		print("  ❌ FAIL: Сообщение пустое")
		tests_failed += 1
	
	# Тест 4: format_winner_selection_error готовое сообщение
	print("")
	print("📋 Тест 4: format_winner_selection_error готовое сообщение")
	var message4 = formatter.format_winner_selection_error("Ошибка! Неправильный выбор. Игалите", [])
	if message4 == "Ошибка! Неправильный выбор. Игалите":
		print("  ✅ PASS: Готовое сообщение возвращается как есть")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось готовое сообщение, получено: %s" % message4)
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

