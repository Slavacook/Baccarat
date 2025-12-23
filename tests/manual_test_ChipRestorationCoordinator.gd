# res://tests/manual_test_ChipRestorationCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ ChipRestorationCoordinator (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ ChipRestorationCoordinator")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	# Тест 1: Координатор без хранилища гостей
	print("📋 Тест 1: Координатор без хранилища гостей")
	var coordinator1 = ChipRestorationCoordinator.new(null)
	var instructions1 = coordinator1.get_restoration_instructions()
	if not instructions1.get("should_restore_from_table_state") and not instructions1.get("should_show_guest_bets"):
		print("  ✅ PASS: Не восстанавливает без хранилища гостей")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_restore_from_table_state=false, should_show_guest_bets=false")
		tests_failed += 1
	
	# Тест 2: Координатор с пустым хранилищем гостей
	print("")
	print("📋 Тест 2: Координатор с пустым хранилищем гостей")
	var storage2 = GuestBetStorage.new()
	var coordinator2 = ChipRestorationCoordinator.new(storage2)
	# Очищаем состояние TableStateManager для чистого теста
	TableStateManager.clear_state()
	var instructions2 = coordinator2.get_restoration_instructions()
	if not instructions2.get("should_restore_from_table_state") and instructions2.get("reason") != "":
		print("  ✅ PASS: Не восстанавливает без сохраненного состояния")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_restore_from_table_state=false")
		tests_failed += 1
	
	# Тест 3: Координатор с сохраненным состоянием, но без гостей
	print("")
	print("📋 Тест 3: Координатор с сохраненным состоянием, но без гостей")
	# Создаём тестовое состояние в TableStateManager
	# ВАЖНО: has_saved_state() требует непустые руки, поэтому создаём тестовые карты
	var test_card1 = Card.new(Card.Suit.HEARTS, 7)  # 7 черви
	var test_card2 = Card.new(Card.Suit.SPADES, 8)  # 8 пики
	var test_bet = Bet.new("Player", 100.0, 0.0, false, 0, 0, 0, -1, -1, "res://textures/chips/chip_red.png")
	TableStateManager.save_table_state(
		[test_card1, test_card2],  # player_hand (нужны карты для has_saved_state())
		[],  # banker_hand
		"Player",  # winner
		"Player",  # selected_winner
		[test_bet],  # bet_data
		Vector2.ZERO,  # camera_position
		Vector2.ONE,  # camera_zoom
		"normal",  # mode
		0,  # survival_rounds
		7,  # survival_lives
		false,  # survival_active
		false,  # pair_player_pressed
		false,  # pair_banker_pressed
		{"Player": "res://textures/chips/chip_red.png"},  # chip_textures
		"start"  # button_state
	)
	var storage3 = GuestBetStorage.new()
	var coordinator3 = ChipRestorationCoordinator.new(storage3)
	var instructions3 = coordinator3.get_restoration_instructions()
	if not instructions3.get("should_restore_from_table_state") and \
	   instructions3.get("reason").contains("нет гостей"):
		print("  ✅ PASS: Не восстанавливает без гостей (режим GUEST)")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_restore_from_table_state=false с причиной 'нет гостей'")
		print("     Получено: should_restore=%s, reason='%s'" % [instructions3.get("should_restore_from_table_state"), instructions3.get("reason")])
		tests_failed += 1
	
	# Тест 4: Координатор с сохраненным состоянием и с гостями
	print("")
	print("📋 Тест 4: Координатор с сохраненным состоянием и с гостями")
	# Используем то же сохраненное состояние из теста 3, но добавляем гостей
	var storage4 = GuestBetStorage.new()
	var guest_bet = Bet.new("Banker", 50.0, 0.0, false, 0, 0, 0, 1, 1, "")
	storage4.store_guest_bets(1, [guest_bet])
	var coordinator4 = ChipRestorationCoordinator.new(storage4)
	var instructions4 = coordinator4.get_restoration_instructions()
	if instructions4.get("should_restore_from_table_state") and \
	   instructions4.get("should_show_guest_bets") and \
	   instructions4.get("chips_to_restore").size() > 0:
		print("  ✅ PASS: Восстанавливает с сохраненным состоянием и гостями")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_restore_from_table_state=true, should_show_guest_bets=true, chips_to_restore.size() > 0")
		print("     Получено: should_restore=%s, should_show=%s, chips_count=%d" % [
			instructions4.get("should_restore_from_table_state"),
			instructions4.get("should_show_guest_bets"),
			instructions4.get("chips_to_restore").size()
		])
		tests_failed += 1
	
	# Тест 5: Структура инструкций
	print("")
	print("📋 Тест 5: Проверка структуры инструкций")
	var instructions5 = coordinator4.get_restoration_instructions()
	var required_fields = ["should_restore_from_table_state", "should_show_guest_bets", "chips_to_restore", "reason"]
	var all_present = true
	for field in required_fields:
		if not instructions5.has(field):
			all_present = false
			break
	if all_present:
		print("  ✅ PASS: Все поля присутствуют в инструкциях")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Не все поля присутствуют")
		tests_failed += 1
	
	# Тест 6: Структура фишек для восстановления
	print("")
	print("📋 Тест 6: Структура фишек для восстановления")
	var chips = instructions4.get("chips_to_restore", [])
	if chips.size() > 0:
		var chip = chips[0]
		if chip.has("bet_type") and chip.has("chip_texture"):
			print("  ✅ PASS: Структура фишки корректна")
			tests_passed += 1
		else:
			print("  ❌ FAIL: Неполная структура фишки")
			tests_failed += 1
	else:
		print("  ⚠️  SKIP: Нет фишек для проверки структуры")
	
	# Тест 7: should_restore_from_table_state()
	print("")
	print("📋 Тест 7: Метод should_restore_from_table_state()")
	# coordinator1 без хранилища гостей - должен вернуть false (нет гостей)
	var should_restore1 = coordinator1.should_restore_from_table_state()
	# coordinator4 с хранилищем и гостями - должен вернуть true (есть гости и сохраненное состояние)
	var should_restore2 = coordinator4.should_restore_from_table_state()
	if not should_restore1 and should_restore2:
		print("  ✅ PASS: Метод корректно определяет необходимость восстановления")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_restore1=false, should_restore2=true")
		print("     Получено: should_restore1=%s, should_restore2=%s" % [should_restore1, should_restore2])
		tests_failed += 1
	
	# Очищаем состояние после тестов
	TableStateManager.clear_state()
	
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
