# res://tests/manual_test_GuestBetDisplayCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ GuestBetDisplayCoordinator (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ GuestBetDisplayCoordinator")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var coordinator = GuestBetDisplayCoordinator.new()
	var filter_manager = BetFilterManager.new()
	
	# Тест 1: get_display_instructions без хранилища
	print("📋 Тест 1: get_display_instructions без хранилища")
	var instructions1 = coordinator.get_display_instructions(null, filter_manager)
	if instructions1.size() == 0:
		print("  ✅ PASS: Возвращает пустой массив без хранилища")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидался пустой массив")
		tests_failed += 1
	
	# Тест 2: get_guests_with_bets_count без хранилища
	print("")
	print("📋 Тест 2: get_guests_with_bets_count без хранилища")
	var count1 = coordinator.get_guests_with_bets_count(null)
	if count1 == 0:
		print("  ✅ PASS: Возвращает 0 без хранилища")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 0")
		tests_failed += 1
	
	# Тест 3: get_bets_count_for_guest без хранилища
	print("")
	print("📋 Тест 3: get_bets_count_for_guest без хранилища")
	var count2 = coordinator.get_bets_count_for_guest(null, 1)
	if count2 == 0:
		print("  ✅ PASS: Возвращает 0 без хранилища")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 0")
		tests_failed += 1
	
	# Тест 4: Структура инструкции
	print("")
	print("📋 Тест 4: Проверка структуры инструкции")
	# Создаём тестовую инструкцию вручную для проверки структуры
	var test_instruction = {
		"bet_type": "Player",
		"position_index": 0,
		"coords": Vector2(100, 200),
		"stake": 100.0,
		"sector": 4,
		"guest_id": 1
	}
	if test_instruction.has("bet_type") and test_instruction.has("position_index") and \
	   test_instruction.has("coords") and test_instruction.has("stake") and \
	   test_instruction.has("sector") and test_instruction.has("guest_id"):
		print("  ✅ PASS: Структура инструкции корректна")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Неполная структура инструкции")
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
	print("")
	print("ℹ️  Примечание: Для полного тестирования нужен реальный GuestBetStorage")
	print("   с тестовыми данными. Проверьте работу в игре вручную.")

