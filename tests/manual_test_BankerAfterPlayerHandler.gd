# res://tests/manual_test_BankerAfterPlayerHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ BankerAfterPlayerHandler
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var handler: BankerAfterPlayerHandler = null
var hand_manager: HandManager = null
var third_card_validator: ThirdCardActionValidator = null
var deck: Deck = null
var card_dealer: CardDealer = null

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ BankerAfterPlayerHandler")
	print("════════════════════════════════════════════════════════════")
	
	# Инициализация зависимостей
	hand_manager = HandManager.new()
	third_card_validator = ThirdCardActionValidator.new()
	deck = Deck.new()
	card_dealer = CardDealer.new()
	
	# Создаём handler
	handler = BankerAfterPlayerHandler.new(hand_manager, third_card_validator)
	
	# Запускаем тесты
	_run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func _run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: should_banker_draw возвращает bool
	print("\n📋 Тест 1: should_banker_draw возвращает bool")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	var should_draw = handler.should_banker_draw()
	if should_draw is bool:
		print("  ✅ PASS: Метод возвращает bool")
		passed += 1
	else:
		print("  ❌ FAIL: Метод должен возвращать bool")
		failed += 1
	
	# Тест 2: get_validation_instructions без HandManager
	print("\n📋 Тест 2: get_validation_instructions без HandManager")
	var handler_no_hand = BankerAfterPlayerHandler.new(null, third_card_validator)
	var instructions = handler_no_hand.get_validation_instructions(false)
	if not instructions.get("should_validate", true):
		print("  ✅ PASS: Без HandManager валидация не выполняется")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие валидации без HandManager")
		failed += 1
	
	# Тест 3: get_validation_instructions без ThirdCardActionValidator
	print("\n📋 Тест 3: get_validation_instructions без ThirdCardActionValidator")
	var handler_no_validator = BankerAfterPlayerHandler.new(hand_manager, null)
	instructions = handler_no_validator.get_validation_instructions(false)
	if not instructions.get("should_validate", true):
		print("  ✅ PASS: Без валидатора валидация не выполняется")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось отсутствие валидации без валидатора")
		failed += 1
	
	# Тест 4: get_validation_instructions с валидными данными
	print("\n📋 Тест 4: get_validation_instructions с валидными данными")
	hand_manager.reset()
	card_dealer.deal_first_four(deck, hand_manager)
	instructions = handler.get_validation_instructions(false)
	if instructions.get("should_validate", false):
		print("  ✅ PASS: Валидация выполняется с валидными данными")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась валидация с валидными данными")
		failed += 1
	
	# Тест 5: Проверка структуры инструкций
	print("\n📋 Тест 5: Проверка структуры инструкций")
	instructions = handler.get_validation_instructions(true)
	var has_should_validate = instructions.has("should_validate")
	var has_validation_result = instructions.has("validation_result")
	var has_banker_score = instructions.has("banker_score")
	var has_should_draw = instructions.has("should_draw")
	var has_should_complete = instructions.has("should_complete")
	if has_should_validate and has_validation_result and has_banker_score and \
	   has_should_draw and has_should_complete:
		print("  ✅ PASS: Все поля присутствуют в инструкциях")
		passed += 1
	else:
		print("  ❌ FAIL: Отсутствуют поля в инструкциях")
		failed += 1
	
	# Тест 6: should_banker_draw без HandManager
	print("\n📋 Тест 6: should_banker_draw без HandManager")
	should_draw = handler_no_hand.should_banker_draw()
	if not should_draw:
		print("  ✅ PASS: Без HandManager возвращает false")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалось false без HandManager")
		failed += 1
	
	# Тест 7: Проверка типа данных в инструкциях
	print("\n📋 Тест 7: Проверка типа данных в инструкциях")
	instructions = handler.get_validation_instructions(false)
	var should_validate = instructions.get("should_validate", true)
	var banker_score = instructions.get("banker_score", -1)
	var should_draw_flag = instructions.get("should_draw", true)
	if should_validate is bool and banker_score is int and should_draw_flag is bool:
		print("  ✅ PASS: Типы данных корректны")
		passed += 1
	else:
		print("  ❌ FAIL: Типы данных некорректны")
		failed += 1
	
	# Итоги
	print("\n════════════════════════════════════════════════════════════")
	print("📊 ИТОГИ ТЕСТИРОВАНИЯ:")
	print("  ✅ Пройдено: %d" % passed)
	print("  ❌ Провалено: %d" % failed)
	var success_rate = (float(passed) / float(passed + failed) * 100.0) if (passed + failed) > 0 else 0.0
	print("  📈 Успешность: %.1f%%" % success_rate)
	print("════════════════════════════════════════════════════════════")
	
	if failed == 0:
		print("🎉 Все тесты пройдены успешно!")
	else:
		print("⚠️ Некоторые тесты провалены")
	print("════════════════════════════════════════════════════════════")

