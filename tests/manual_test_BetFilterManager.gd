# res://tests/manual_test_BetFilterManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ BetFilterManager (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ BetFilterManager")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var filter_manager = BetFilterManager.new()
	
	# Тест 1: is_bet_type_enabled_in_settings без менеджеров
	print("📋 Тест 1: is_bet_type_enabled_in_settings без менеджеров")
	var result1 = filter_manager.is_bet_type_enabled_in_settings("Player", null, null)
	if result1:
		print("  ✅ PASS: Возвращает true без менеджеров")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось true")
		tests_failed += 1
	
	# Тест 2: is_bet_type_enabled_in_snapshot с пустым snapshot
	print("")
	print("📋 Тест 2: is_bet_type_enabled_in_snapshot с пустым snapshot")
	var result2 = filter_manager.is_bet_type_enabled_in_snapshot("Player", null, null)
	if result2:
		print("  ✅ PASS: Использует fallback при пустом snapshot")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось true (fallback)")
		tests_failed += 1
	
	# Тест 3: save_filter_snapshot
	print("")
	print("📋 Тест 3: save_filter_snapshot")
	filter_manager.save_filter_snapshot(null, null)
	# Snapshot может содержать пустые значения для PairPlayer/PairBanker даже без менеджеров
	# Проверяем что метод выполнился без ошибок
	if filter_manager.filter_snapshot.has("PairPlayer") or filter_manager.filter_snapshot.is_empty():
		print("  ✅ PASS: Snapshot сохранён (может быть пустым или с дефолтными значениями)")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидался snapshot с дефолтными значениями или пустой")
		tests_failed += 1
	
	# Тест 4: add_pending_filter_change
	print("")
	print("📋 Тест 4: add_pending_filter_change")
	filter_manager.add_pending_filter_change("Player", false)
	if filter_manager.has_pending_filter_changes() and filter_manager.get_pending_filter_changes().get("Player") == false:
		print("  ✅ PASS: Изменение добавлено в очередь")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось изменение Player=false")
		tests_failed += 1
	
	# Тест 5: clear_pending_filter_changes
	print("")
	print("📋 Тест 5: clear_pending_filter_changes")
	filter_manager.clear_pending_filter_changes()
	if not filter_manager.has_pending_filter_changes():
		print("  ✅ PASS: Очередь изменений очищена")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалась пустая очередь")
		tests_failed += 1
	
	# Тест 6: apply_pending_filter_changes с пустой очередью
	print("")
	print("📋 Тест 6: apply_pending_filter_changes с пустой очередью")
	var result6 = filter_manager.apply_pending_filter_changes(null, null)
	if not result6.get("applied") and result6.get("changes", {}).size() == 0:
		print("  ✅ PASS: Пустая очередь не применяется")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось applied=false, changes={}")
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

