# res://tests/manual_test_TieButtonHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЕ ТЕСТИРОВАНИЕ TieButtonHandler
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var handler: TieButtonHandler = null
var hand_manager: HandManager = null
var chance_card_trigger_checker: ChanceCardTriggerChecker = null

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ TieButtonHandler")
	print("════════════════════════════════════════════════════════════")
	
	# Инициализация
	hand_manager = HandManager.new()
	chance_card_trigger_checker = ChanceCardTriggerChecker.new()
	handler = TieButtonHandler.new(hand_manager, chance_card_trigger_checker)
	
	# Запускаем тесты
	run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: get_tie_button_instructions с валидной ничьей
	print("\n📋 Тест 1: get_tie_button_instructions с валидной ничьей")
	# Создаем руки с ничьей (Player: 5+5=10->0, Banker: 5+5=10->0)
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 5))
	hand_manager.add_player_card(Card.new(Card.Suit.SPADES, 5))  # 5+5=10 -> 0
	hand_manager.add_banker_card(Card.new(Card.Suit.DIAMONDS, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 5))  # 5+5=10 -> 0
	var instructions = handler.get_tie_button_instructions(false, false)
	if instructions.get("is_valid", false) and instructions.get("actual_winner", "") == "Tie":
		print("  ✅ PASS: Валидная ничья обработана корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Валидная ничья обработана некорректно")
		print("    is_valid: %s, actual_winner: %s" % [instructions.get("is_valid", false), instructions.get("actual_winner", "")])
		failed += 1
	
	# Тест 2: get_tie_button_instructions с невалидной ничьей (Player выиграл)
	print("\n📋 Тест 2: get_tie_button_instructions с невалидной ничьей (Player выиграл)")
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 8))
	hand_manager.add_player_card(Card.new(Card.Suit.SPADES, 1))  # 8+1=9
	hand_manager.add_banker_card(Card.new(Card.Suit.DIAMONDS, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 3))  # 5+3=8
	instructions = handler.get_tie_button_instructions(false, false)
	if not instructions.get("is_valid", true) and instructions.get("actual_winner", "") == "Player":
		print("  ✅ PASS: Невалидная ничья обработана корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Невалидная ничья обработана некорректно")
		print("    is_valid: %s, actual_winner: %s" % [instructions.get("is_valid", true), instructions.get("actual_winner", "")])
		failed += 1
	
	# Тест 3: get_tie_button_instructions с Heart Bet
	print("\n📋 Тест 3: get_tie_button_instructions с Heart Bet")
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 5))
	hand_manager.add_player_card(Card.new(Card.Suit.SPADES, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.DIAMONDS, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 5))
	instructions = handler.get_tie_button_instructions(true, false)  # has_active_heart_bet=true
	if instructions.get("should_resolve_heart_bet", false) and not instructions.get("should_request_payout", true):
		print("  ✅ PASS: Heart Bet обработан корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Heart Bet обработан некорректно")
		failed += 1
	
	# Тест 4: get_tie_button_instructions с режимом выживания
	print("\n📋 Тест 4: get_tie_button_instructions с режимом выживания")
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 5))
	hand_manager.add_player_card(Card.new(Card.Suit.SPADES, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.DIAMONDS, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 5))
	instructions = handler.get_tie_button_instructions(false, true)  # is_survival_mode=true
	if instructions.get("should_check_chance_cards", false):
		print("  ✅ PASS: Режим выживания обработан корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Режим выживания обработан некорректно")
		failed += 1
	
	# Тест 5: get_tie_button_instructions без hand_manager
	print("\n📋 Тест 5: get_tie_button_instructions без hand_manager")
	var handler_no_manager = TieButtonHandler.new(null, chance_card_trigger_checker)
	instructions = handler_no_manager.get_tie_button_instructions(false, false)
	if not instructions.get("is_valid", true):
		print("  ✅ PASS: Без hand_manager обработано корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Без hand_manager обработано некорректно")
		failed += 1
	
	# Тест 6: get_tie_button_instructions с пустыми руками
	print("\n📋 Тест 6: get_tie_button_instructions с пустыми руками")
	hand_manager.reset()
	instructions = handler.get_tie_button_instructions(false, false)
	if not instructions.get("is_valid", true):
		print("  ✅ PASS: Пустые руки обработаны корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Пустые руки обработаны некорректно")
		failed += 1
	
	# Тест 7: Проверка структуры инструкций
	print("\n📋 Тест 7: Проверка структуры инструкций")
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 5))
	hand_manager.add_player_card(Card.new(Card.Suit.SPADES, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.DIAMONDS, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 5))
	instructions = handler.get_tie_button_instructions(false, false)
	var required_fields = ["is_valid", "actual_winner", "should_resolve_heart_bet", "should_check_chance_cards", "should_show_success", "should_update_ui", "should_request_payout"]
	var all_fields_present = true
	for field in required_fields:
		if not instructions.has(field):
			all_fields_present = false
			break
	if all_fields_present:
		print("  ✅ PASS: Структура инструкций корректна")
		passed += 1
	else:
		print("  ❌ FAIL: Структура инструкций некорректна")
		failed += 1
	
	# Тест 8: get_chance_card_triggers
	print("\n📋 Тест 8: get_chance_card_triggers")
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 5))
	hand_manager.add_player_card(Card.new(Card.Suit.SPADES, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.DIAMONDS, 5))
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 5))
	var triggers = handler.get_chance_card_triggers("Tie")
	if triggers.has("heart_bet_card"):
		print("  ✅ PASS: Триггеры карт шанса получены корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Триггеры карт шанса получены некорректно")
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

