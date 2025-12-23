# res://tests/manual_test_WinnerSelectionStateHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЕ ТЕСТИРОВАНИЕ WinnerSelectionStateHandler
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var handler: WinnerSelectionStateHandler = null
var hand_manager: HandManager = null

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ WinnerSelectionStateHandler")
	print("════════════════════════════════════════════════════════════")
	
	# Инициализация
	hand_manager = HandManager.new()
	handler = WinnerSelectionStateHandler.new(hand_manager)
	
	# Запускаем тесты
	run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: Обработка невалидного выбора (игрок выбрал третью карту)
	print("\n📋 Тест 1: Обработка невалидного выбора (игрок выбрал третью карту)")
	var instructions = handler.get_state_handling_instructions(
		true,  # player_third_selected
		false,  # banker_third_selected
		"start",  # button_state
		true  # can_complete_round
	)
	if instructions.get("action", "") == "handle_invalid_selection":
		print("  ✅ PASS: Невалидный выбор обработан корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Невалидный выбор обработан некорректно")
		print("    Действие: %s" % instructions.get("action", ""))
		failed += 1
	
	# Тест 2: Обработка невалидного выбора (банкир выбрал третью карту)
	print("\n📋 Тест 2: Обработка невалидного выбора (банкир выбрал третью карту)")
	instructions = handler.get_state_handling_instructions(
		false,  # player_third_selected
		true,  # banker_third_selected
		"start",  # button_state
		true  # can_complete_round
	)
	if instructions.get("action", "") == "handle_invalid_selection":
		print("  ✅ PASS: Невалидный выбор банкира обработан корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Невалидный выбор банкира обработан некорректно")
		failed += 1
	
	# Тест 3: Проверка натуральной раздачи
	print("\n📋 Тест 3: Проверка натуральной раздачи")
	# Создаем руки с натуральной раздачей (8 или 9)
	# Player: 8 + 0 (J/Q/K) = 8 (натуральная)
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 8))  # 8 очков
	hand_manager.add_player_card(Card.new(Card.Suit.DIAMONDS, 11))  # J = 0 очков, итого 8 (натуральная)
	hand_manager.add_banker_card(Card.new(Card.Suit.SPADES, 2))
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 3))
	instructions = handler.get_state_handling_instructions(
		true,  # player_third_selected
		false,  # banker_third_selected
		"start",  # button_state
		true  # can_complete_round
	)
	if instructions.get("is_natural", false) and instructions.get("error_message_key", "") == "ERR_NATURAL_NO_DRAW":
		print("  ✅ PASS: Натуральная раздача определена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Натуральная раздача определена некорректно")
		print("    is_natural: %s, error_key: %s" % [instructions.get("is_natural", false), instructions.get("error_message_key", "")])
		failed += 1
	
	# Тест 4: Валидация победителя (первое нажатие)
	print("\n📋 Тест 4: Валидация победителя (первое нажатие)")
	instructions = handler.get_state_handling_instructions(
		false,  # player_third_selected
		false,  # banker_third_selected
		"start",  # button_state (не "complete")
		true  # can_complete_round
	)
	if instructions.get("action", "") == "validate_winner":
		print("  ✅ PASS: Валидация победителя определена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Валидация победителя определена некорректно")
		failed += 1
	
	# Тест 5: Завершение раунда (кнопка "complete" и можно завершить)
	print("\n📋 Тест 5: Завершение раунда (кнопка 'complete' и можно завершить)")
	instructions = handler.get_state_handling_instructions(
		false,  # player_third_selected
		false,  # banker_third_selected
		"complete",  # button_state
		true  # can_complete_round
	)
	if instructions.get("action", "") == "complete_round":
		print("  ✅ PASS: Завершение раунда определено корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Завершение раунда определено некорректно")
		failed += 1
	
	# Тест 6: Блокировка завершения (неоплаченные ставки)
	print("\n📋 Тест 6: Блокировка завершения (неоплаченные ставки)")
	instructions = handler.get_state_handling_instructions(
		false,  # player_third_selected
		false,  # banker_third_selected
		"complete",  # button_state
		false  # can_complete_round
	)
	if instructions.get("action", "") == "none":
		print("  ✅ PASS: Блокировка завершения обработана корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Блокировка завершения обработана некорректно")
		failed += 1
	
	# Тест 7: Проверка структуры инструкций
	print("\n📋 Тест 7: Проверка структуры инструкций")
	instructions = handler.get_state_handling_instructions(
		false,  # player_third_selected
		false,  # banker_third_selected
		"start",  # button_state
		true  # can_complete_round
	)
	if instructions.has("action") and instructions.has("is_natural") and instructions.has("error_message_key"):
		print("  ✅ PASS: Структура инструкций корректна")
		passed += 1
	else:
		print("  ❌ FAIL: Структура инструкций некорректна")
		failed += 1
	
	# Тест 8: Проверка не-натуральной раздачи
	print("\n📋 Тест 8: Проверка не-натуральной раздачи")
	# Создаем руки без натуральной раздачи (обе руки < 8)
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 2))  # 2 очка
	hand_manager.add_player_card(Card.new(Card.Suit.DIAMONDS, 3))  # 3 очка, итого 5 (не натуральная)
	hand_manager.add_banker_card(Card.new(Card.Suit.SPADES, 2))  # 2 очка
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 3))  # 3 очка, итого 5 (не натуральная)
	instructions = handler.get_state_handling_instructions(
		true,  # player_third_selected
		false,  # banker_third_selected
		"start",  # button_state
		true  # can_complete_round
	)
	if not instructions.get("is_natural", true) and instructions.get("error_message_key", "") == "INFO_ALL_OPENED_CHOOSE_WINNER":
		print("  ✅ PASS: Не-натуральная раздача определена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Не-натуральная раздача определена некорректно")
		failed += 1
	
	# Итоги
	print("\n════════════════════════════════════════════════════════════")
	print("📊 ИТОГИ ТЕСТИРОВАНИЯ:")
	print("  ✅ Пройдено: %d" % passed)
	print("  ❌ Провалено: %d" % failed)
	print("  📈 Успешность: %.1f%%" % (100.0 * passed / (passed + failed) if (passed + failed) > 0 else 0.0))
	print("════════════════════════════════════════════════════════════")
	if failed == 0:
		print("🎉 Все тесты пройдены успешно!")
	else:
		print("⚠️ Некоторые тесты провалены")
	print("════════════════════════════════════════════════════════════")
