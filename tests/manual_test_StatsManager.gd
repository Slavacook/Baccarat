# res://tests/manual_test_StatsManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ StatsManager (расчет чаевых)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ StatsManager (чаевые)")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	# Получаем экземпляр StatsManager
	var stats_manager = StatsManager.instance
	if not stats_manager:
		print("  ❌ FAIL: StatsManager.instance не найден")
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# ТЕСТЫ: Коэффициенты
	# ═══════════════════════════════════════════════════════════════════
	
	print("📋 Тест 1: Коэффициент для Player")
	var mult1 = stats_manager.get_tip_multiplier("Player")
	if mult1 == 1:
		print("  ✅ PASS: Player = 1")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 1, получено %d" % mult1)
		tests_failed += 1
	
	print("")
	print("📋 Тест 2: Коэффициент для Banker")
	var mult2 = stats_manager.get_tip_multiplier("Banker")
	if mult2 == 1:
		print("  ✅ PASS: Banker = 1")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 1, получено %d" % mult2)
		tests_failed += 1
	
	print("")
	print("📋 Тест 3: Коэффициент для Tie")
	var mult3 = stats_manager.get_tip_multiplier("Tie")
	if mult3 == 8:
		print("  ✅ PASS: Tie = 8")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 8, получено %d" % mult3)
		tests_failed += 1
	
	print("")
	print("📋 Тест 4: Коэффициент для PairPlayer")
	var mult4 = stats_manager.get_tip_multiplier("PairPlayer")
	if mult4 == 11:
		print("  ✅ PASS: PairPlayer = 11")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 11, получено %d" % mult4)
		tests_failed += 1
	
	print("")
	print("📋 Тест 5: Коэффициент для PairBanker")
	var mult5 = stats_manager.get_tip_multiplier("PairBanker")
	if mult5 == 11:
		print("  ✅ PASS: PairBanker = 11")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 11, получено %d" % mult5)
		tests_failed += 1
	
	# ═══════════════════════════════════════════════════════════════════
	# ТЕСТЫ: Расчет чаевых (примеры из описания)
	# ═══════════════════════════════════════════════════════════════════
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("📋 Тесты расчета чаевых")
	print("═══════════════════════════════════════════════════════════")
	
	# Тест 6: Player, 2000 выплата, 0.73% чаевых
	# Базовые = ceil(2000 * 0.73 / 100) = ceil(14.6) = 15
	# Итого = 15 * 1 = 15
	print("")
	print("📋 Тест 6: Player, выплата=2000, чаевые=0.73%")
	var tip6 = stats_manager.calculate_tip_amount(2000.0, 0.73, "Player")
	var expected6 = 15
	if tip6 == expected6:
		print("  ✅ PASS: Чаевые = %d (ожидалось %d)" % [tip6, expected6])
		tests_passed += 1
	else:
		print("  ❌ FAIL: Чаевые = %d (ожидалось %d)" % [tip6, expected6])
		tests_failed += 1
	
	# Тест 7: Player, 1000 выплата, 1% чаевых
	# Базовые = ceil(1000 * 1 / 100) = ceil(10) = 10
	# Итого = 10 * 1 = 10
	print("")
	print("📋 Тест 7: Player, выплата=1000, чаевые=1%")
	var tip7 = stats_manager.calculate_tip_amount(1000.0, 1.0, "Player")
	var expected7 = 10
	if tip7 == expected7:
		print("  ✅ PASS: Чаевые = %d (ожидалось %d)" % [tip7, expected7])
		tests_passed += 1
	else:
		print("  ❌ FAIL: Чаевые = %d (ожидалось %d)" % [tip7, expected7])
		tests_failed += 1
	
	# Тест 8: Tie, 800 выплата, 1% чаевых
	# Базовые = ceil(800 * 1 / 100) = ceil(8) = 8
	# Итого = 8 * 8 = 64
	print("")
	print("📋 Тест 8: Tie, выплата=800, чаевые=1%")
	var tip8 = stats_manager.calculate_tip_amount(800.0, 1.0, "Tie")
	var expected8 = 64
	if tip8 == expected8:
		print("  ✅ PASS: Чаевые = %d (ожидалось %d)" % [tip8, expected8])
		tests_passed += 1
	else:
		print("  ❌ FAIL: Чаевые = %d (ожидалось %d)" % [tip8, expected8])
		tests_failed += 1
	
	# Тест 9: Pair, 1100 выплата, 1% чаевых
	# Базовые = ceil(1100 * 1 / 100) = ceil(11) = 11
	# Итого = 11 * 11 = 121
	print("")
	print("📋 Тест 9: PairPlayer, выплата=1100, чаевые=1%")
	var tip9 = stats_manager.calculate_tip_amount(1100.0, 1.0, "PairPlayer")
	var expected9 = 121
	if tip9 == expected9:
		print("  ✅ PASS: Чаевые = %d (ожидалось %d)" % [tip9, expected9])
		tests_passed += 1
	else:
		print("  ❌ FAIL: Чаевые = %d (ожидалось %d)" % [tip9, expected9])
		tests_failed += 1
	
	# Тест 10: Pair, 100 выплата (ставка), 1% чаевых
	# Выплата = 100 * 11 = 1100
	# Базовые = ceil(1100 * 1 / 100) = ceil(11) = 11
	# Итого = 11 * 11 = 121
	print("")
	print("📋 Тест 10: PairBanker, выплата=1100 (ставка 100 * 11), чаевые=1%")
	var tip10 = stats_manager.calculate_tip_amount(1100.0, 1.0, "PairBanker")
	var expected10 = 121
	if tip10 == expected10:
		print("  ✅ PASS: Чаевые = %d (ожидалось %d)" % [tip10, expected10])
		tests_passed += 1
	else:
		print("  ❌ FAIL: Чаевые = %d (ожидалось %d)" % [tip10, expected10])
		tests_failed += 1
	
	# Тест 11: Tie, 100 выплата (ставка), 1% чаевых
	# Выплата = 100 * 8 = 800
	# Базовые = ceil(800 * 1 / 100) = ceil(8) = 8
	# Итого = 8 * 8 = 64
	print("")
	print("📋 Тест 11: Tie, выплата=800 (ставка 100 * 8), чаевые=1%")
	var tip11 = stats_manager.calculate_tip_amount(800.0, 1.0, "Tie")
	var expected11 = 64
	if tip11 == expected11:
		print("  ✅ PASS: Чаевые = %d (ожидалось %d)" % [tip11, expected11])
		tests_passed += 1
	else:
		print("  ❌ FAIL: Чаевые = %d (ожидалось %d)" % [tip11, expected11])
		tests_failed += 1
	
	# Тест 12: Проверка округления ДО умножения
	# Player, 2000 выплата, 0.5% чаевых
	# Базовые = ceil(2000 * 0.5 / 100) = ceil(10.0) = 10
	# Итого = 10 * 1 = 10
	# Если бы округляли ПОСЛЕ: (2000 * 0.5 / 100) * 1 = 10.0, ceil = 10 (одинаково)
	# Но проверим с дробным процентом:
	# Player, 100 выплата, 1.1% чаевых
	# Базовые = ceil(100 * 1.1 / 100) = ceil(1.1) = 2
	# Итого = 2 * 1 = 2
	print("")
	print("📋 Тест 12: Player, выплата=100, чаевые=1.1% (проверка округления)")
	var tip12 = stats_manager.calculate_tip_amount(100.0, 1.1, "Player")
	var expected12 = 2  # ceil(1.1) = 2
	if tip12 == expected12:
		print("  ✅ PASS: Чаевые = %d (ожидалось %d, округление ДО умножения)" % [tip12, expected12])
		tests_passed += 1
	else:
		print("  ❌ FAIL: Чаевые = %d (ожидалось %d)" % [tip12, expected12])
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
		print("⚠️  Некоторые тесты провалены, требуется проверка.")

