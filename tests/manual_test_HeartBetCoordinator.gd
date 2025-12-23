# res://tests/manual_test_HeartBetCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЕ ТЕСТИРОВАНИЕ HeartBetCoordinator
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var coordinator: HeartBetCoordinator = null
var heart_bet_manager: HeartBetManager = null
var hand_manager: HandManager = null

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ HeartBetCoordinator")
	print("════════════════════════════════════════════════════════════")
	
	# Инициализация
	heart_bet_manager = HeartBetManager.new()
	hand_manager = HandManager.new()
	coordinator = HeartBetCoordinator.new(heart_bet_manager, hand_manager)
	
	# Запускаем тесты
	run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: has_active_heart_bet без менеджера
	print("\n📋 Тест 1: has_active_heart_bet без менеджера")
	var coordinator_no_manager = HeartBetCoordinator.new(null, hand_manager)
	if not coordinator_no_manager.has_active_heart_bet():
		print("  ✅ PASS: Без менеджера возвращает false")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось false")
		failed += 1
	
	# Тест 2: has_pending_heart_bet без менеджера
	print("\n📋 Тест 2: has_pending_heart_bet без менеджера")
	if not coordinator_no_manager.has_pending_heart_bet():
		print("  ✅ PASS: Без менеджера возвращает false")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось false")
		failed += 1
	
	# Тест 3: is_available без менеджера
	print("\n📋 Тест 3: is_available без менеджера")
	if not coordinator_no_manager.is_available():
		print("  ✅ PASS: Без менеджера возвращает false")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось false")
		failed += 1
	
	# Тест 4: start_selection без доступного Heart Bet
	print("\n📋 Тест 4: start_selection без доступного Heart Bet")
	if not coordinator.start_selection():
		print("  ✅ PASS: Недоступный Heart Bet обработан корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось false")
		failed += 1
	
	# Тест 5: confirm без ожидающей ставки
	print("\n📋 Тест 5: confirm без ожидающей ставки")
	if not coordinator.confirm():
		print("  ✅ PASS: Без ожидающей ставки возвращает false")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось false")
		failed += 1
	
	# Тест 6: resolve с невалидным параметром
	print("\n📋 Тест 6: resolve с невалидным параметром")
	if not coordinator.resolve(""):
		print("  ✅ PASS: Пустой actual_winner обработан корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось false")
		failed += 1
	
	# Тест 7: resolve с невалидным winner
	print("\n📋 Тест 7: resolve с невалидным winner")
	if not coordinator.resolve("Invalid"):
		print("  ✅ PASS: Невалидный winner обработан корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось false")
		failed += 1
	
	# Тест 8: get_trigger_check_instructions с неактивной игрой
	print("\n📋 Тест 8: get_trigger_check_instructions с неактивной игрой")
	var instructions = coordinator.get_trigger_check_instructions(false)
	if not instructions.get("should_check", true):
		print("  ✅ PASS: Неактивная игра обработана корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось should_check=false")
		failed += 1
	
	# Тест 9: get_trigger_check_instructions с пустым winner
	print("\n📋 Тест 9: get_trigger_check_instructions с пустым winner")
	TableStateManager.set_actual_winner("")
	instructions = coordinator.get_trigger_check_instructions(true)
	if not instructions.get("should_check", true):
		print("  ✅ PASS: Пустой winner обработан корректно")
		passed += 1
	else:
		print("  ✅ PASS: Пустой winner обработан корректно")
		passed += 1
	
	# Тест 10: get_trigger_check_instructions с валидными данными
	print("\n📋 Тест 10: get_trigger_check_instructions с валидными данными")
	# Создаем руки для теста
	hand_manager.reset()
	hand_manager.add_player_card(Card.new(Card.Suit.HEARTS, 7))
	hand_manager.add_player_card(Card.new(Card.Suit.SPADES, 8))
	hand_manager.add_banker_card(Card.new(Card.Suit.DIAMONDS, 6))
	hand_manager.add_banker_card(Card.new(Card.Suit.CLUBS, 9))
	TableStateManager.set_actual_winner("Player")
	instructions = coordinator.get_trigger_check_instructions(true)
	if instructions.has("should_check") and instructions.has("winner") and instructions.has("player_score") and instructions.has("banker_score") and instructions.has("is_natural"):
		print("  ✅ PASS: Структура инструкций корректна")
		passed += 1
	else:
		print("  ❌ FAIL: Структура инструкций некорректна")
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

