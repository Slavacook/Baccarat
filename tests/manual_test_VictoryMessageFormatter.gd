# res://tests/manual_test_VictoryMessageFormatter.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ VictoryMessageFormatter (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ VictoryMessageFormatter")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var formatter = VictoryMessageFormatter.new()
	
	# Тест 1: Tie (игалите)
	print("📋 Тест 1: Форматирование Tie")
	var message1 = formatter.format_victory_message("Tie", 8, 8)
	if message1 == "Игалите":
		print("  ✅ PASS: Сообщение для Tie корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 'Игалите', получено: %s" % message1)
		tests_failed += 1
	
	# Тест 2: Player победа
	print("")
	print("📋 Тест 2: Форматирование победы Player")
	var message2 = formatter.format_victory_message("Player", 9, 7)
	if message2.contains("Выиграл") and message2.contains("9") and message2.contains("7"):
		print("  ✅ PASS: Сообщение для Player корректно: %s" % message2)
		tests_passed += 1
	else:
		print("  ❌ FAIL: Сообщение некорректно: %s" % message2)
		tests_failed += 1
	
	# Тест 3: Banker победа
	print("")
	print("📋 Тест 3: Форматирование победы Banker")
	var message3 = formatter.format_victory_message("Banker", 5, 8)
	if message3.contains("Выиграл") and message3.contains("8") and message3.contains("5"):
		print("  ✅ PASS: Сообщение для Banker корректно: %s" % message3)
		tests_passed += 1
	else:
		print("  ❌ FAIL: Сообщение некорректно: %s" % message3)
		tests_failed += 1
	
	# Тест 4: Нулевые очки
	print("")
	print("📋 Тест 4: Форматирование с нулевыми очками")
	var message4 = formatter.format_victory_message("Player", 0, 0)
	if message4.contains("Выиграл") and message4.contains("0"):
		print("  ✅ PASS: Сообщение с нулевыми очками корректно: %s" % message4)
		tests_passed += 1
	else:
		print("  ❌ FAIL: Сообщение некорректно: %s" % message4)
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

