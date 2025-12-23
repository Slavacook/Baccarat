# res://tests/manual_test_WinnerSelectionCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ WinnerSelectionCoordinator (без GUT)
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ WinnerSelectionCoordinator")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	var validator = WinnerSelectionValidator.new()
	var coordinator = WinnerSelectionCoordinator.new(validator)
	
	# Создаём тестовые карты
	var player_card1 = Card.new(Card.Suit.HEARTS, 7)
	var player_card2 = Card.new(Card.Suit.SPADES, 8)
	var banker_card1 = Card.new(Card.Suit.DIAMONDS, 6)
	var banker_card2 = Card.new(Card.Suit.CLUBS, 9)
	
	var player_hand: Array[Card] = [player_card1, player_card2]
	var banker_hand: Array[Card] = [banker_card1, banker_card2]
	
	# Тест 1: get_validation_instructions с пустым выбором
	print("📋 Тест 1: get_validation_instructions с пустым выбором")
	var instructions1 = coordinator.get_validation_instructions(
		"", player_hand, banker_hand, false, false, false
	)
	if instructions1.get("needs_selection") == true:
		print("  ✅ PASS: Пустой выбор обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось needs_selection=true")
		tests_failed += 1
	
	# Тест 2: get_validation_instructions с правильным выбором
	print("")
	print("📋 Тест 2: get_validation_instructions с правильным выбором")
	# Player: 7+8=15 -> 5, Banker: 6+9=15 -> 5, ничья
	var instructions2 = coordinator.get_validation_instructions(
		"Tie", player_hand, banker_hand, false, false, false
	)
	if instructions2.get("needs_selection") == false and \
	   instructions2.get("should_save_winner") == true and \
	   instructions2.has("actual_winner"):
		print("  ✅ PASS: Правильный выбор обработан корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось needs_selection=false, should_save_winner=true")
		tests_failed += 1
	
	# Тест 3: Проверка триггеров Heart Bet в режиме выживания
	print("")
	print("📋 Тест 3: Проверка триггеров Heart Bet в режиме выживания")
	var instructions3 = coordinator.get_validation_instructions(
		"Tie", player_hand, banker_hand, true, false, false
	)
	if instructions3.get("should_check_heart_bet_triggers") == true and \
	   instructions3.has("heart_bet_trigger_data"):
		var trigger_data = instructions3.get("heart_bet_trigger_data", {})
		if trigger_data.has("winner") and trigger_data.has("banker_score") and \
		   trigger_data.has("player_score") and trigger_data.has("is_natural"):
			print("  ✅ PASS: Триггеры Heart Bet должны проверяться в режиме выживания")
			tests_passed += 1
		else:
			print("  ❌ FAIL: Неполные данные для триггеров Heart Bet")
			tests_failed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_check_heart_bet_triggers=true")
		tests_failed += 1
	
	# Тест 4: Проверка триггеров Heart Bet пропускается если был Heart Bet раунд
	print("")
	print("📋 Тест 4: Проверка триггеров Heart Bet пропускается если был Heart Bet раунд")
	var instructions4 = coordinator.get_validation_instructions(
		"Tie", player_hand, banker_hand, true, true, false
	)
	if instructions4.get("should_check_heart_bet_triggers") == false:
		print("  ✅ PASS: Триггеры Heart Bet пропущены после Heart Bet раунда")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_check_heart_bet_triggers=false")
		tests_failed += 1
	
	# Тест 5: Проверка триггеров Heart Bet пропускается если есть активная ставка
	print("")
	print("📋 Тест 5: Проверка триггеров Heart Bet пропускается если есть активная ставка")
	var instructions5 = coordinator.get_validation_instructions(
		"Tie", player_hand, banker_hand, true, false, true
	)
	if instructions5.get("should_check_heart_bet_triggers") == false:
		print("  ✅ PASS: Триггеры Heart Bet пропущены при активной ставке")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_check_heart_bet_triggers=false")
		tests_failed += 1
	
	# Тест 6: Структура инструкций
	print("")
	print("📋 Тест 6: Проверка структуры инструкций")
	var required_fields = ["needs_selection", "validation_result", "actual_winner",
	                      "should_save_winner", "should_check_heart_bet_triggers", "heart_bet_trigger_data"]
	var all_present = true
	for field in required_fields:
		if not instructions2.has(field):
			all_present = false
			break
	if all_present:
		print("  ✅ PASS: Все поля присутствуют в инструкциях")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Не все поля присутствуют")
		tests_failed += 1
	
	# Тест 7: Координатор без валидатора
	print("")
	print("📋 Тест 7: Координатор без валидатора")
	var coordinator_no_validator = WinnerSelectionCoordinator.new(null)
	var instructions7 = coordinator_no_validator.get_validation_instructions(
		"Player", player_hand, banker_hand, false, false, false
	)
	if instructions7.get("needs_selection") == false and \
	   instructions7.get("validation_result").is_empty():
		print("  ✅ PASS: Координатор без валидатора обрабатывает корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось пустой validation_result")
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

