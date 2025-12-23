# res://tests/manual_test_ThirdCardDrawingCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ ThirdCardDrawingCoordinator
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var coordinator: ThirdCardDrawingCoordinator = null
var card_dealer: CardDealer = null
var hand_manager: HandManager = null
var deck: Deck = null

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ ThirdCardDrawingCoordinator")
	print("════════════════════════════════════════════════════════════")
	
	# Инициализация зависимостей
	card_dealer = CardDealer.new()
	hand_manager = HandManager.new()
	deck = Deck.new()
	
	# Создаём координатор
	coordinator = ThirdCardDrawingCoordinator.new(card_dealer, hand_manager)
	
	# Запускаем тесты
	_run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func _run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: draw_player_third успешная раздача
	print("\n📋 Тест 1: draw_player_third успешная раздача")
	hand_manager.reset()
	var initial_player_size = hand_manager.get_player_size()
	var result = coordinator.draw_player_third(deck)
	if result.get("success", false) and result.get("card", null) != null:
		if hand_manager.get_player_size() == initial_player_size + 1:
			print("  ✅ PASS: Третья карта игрока раздана корректно")
			passed += 1
		else:
			print("  ❌ FAIL: Карта не добавлена в руку игрока")
			failed += 1
	else:
		print("  ❌ FAIL: Ожидалась успешная раздача")
		failed += 1
	
	# Тест 2: draw_banker_third успешная раздача
	print("\n📋 Тест 2: draw_banker_third успешная раздача")
	hand_manager.reset()
	var initial_banker_size = hand_manager.get_banker_size()
	result = coordinator.draw_banker_third(deck)
	if result.get("success", false) and result.get("card", null) != null:
		if hand_manager.get_banker_size() == initial_banker_size + 1:
			print("  ✅ PASS: Третья карта банкира раздана корректно")
			passed += 1
		else:
			print("  ❌ FAIL: Карта не добавлена в руку банкира")
			failed += 1
	else:
		print("  ❌ FAIL: Ожидалась успешная раздача")
		failed += 1
	
	# Тест 3: draw_player_third без CardDealer
	print("\n📋 Тест 3: draw_player_third без CardDealer")
	var coordinator_no_dealer = ThirdCardDrawingCoordinator.new(null, hand_manager)
	result = coordinator_no_dealer.draw_player_third(deck)
	if not result.get("success", true) and result.get("error", "") != "":
		print("  ✅ PASS: Ошибка обработана корректно без CardDealer")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась ошибка без CardDealer")
		failed += 1
	
	# Тест 4: draw_banker_third без CardDealer
	print("\n📋 Тест 4: draw_banker_third без CardDealer")
	result = coordinator_no_dealer.draw_banker_third(deck)
	if not result.get("success", true) and result.get("error", "") != "":
		print("  ✅ PASS: Ошибка обработана корректно без CardDealer")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась ошибка без CardDealer")
		failed += 1
	
	# Тест 5: draw_player_third без HandManager
	print("\n📋 Тест 5: draw_player_third без HandManager")
	var coordinator_no_hand = ThirdCardDrawingCoordinator.new(card_dealer, null)
	result = coordinator_no_hand.draw_player_third(deck)
	if not result.get("success", true) and result.get("error", "") != "":
		print("  ✅ PASS: Ошибка обработана корректно без HandManager")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась ошибка без HandManager")
		failed += 1
	
	# Тест 6: draw_banker_third без HandManager
	print("\n📋 Тест 6: draw_banker_third без HandManager")
	result = coordinator_no_hand.draw_banker_third(deck)
	if not result.get("success", true) and result.get("error", "") != "":
		print("  ✅ PASS: Ошибка обработана корректно без HandManager")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидалась ошибка без HandManager")
		failed += 1
	
	# Тест 7: Проверка структуры результата для успешной раздачи
	print("\n📋 Тест 7: Проверка структуры результата для успешной раздачи")
	hand_manager.reset()
	result = coordinator.draw_player_third(deck)
	var has_success = result.has("success")
	var has_card = result.has("card")
	var has_error = result.has("error")
	if has_success and has_card and has_error:
		print("  ✅ PASS: Все поля присутствуют в результате")
		passed += 1
	else:
		print("  ❌ FAIL: Отсутствуют поля: success=%s, card=%s, error=%s" % [has_success, has_card, has_error])
		failed += 1
	
	# Тест 8: Проверка структуры результата для ошибки
	print("\n📋 Тест 8: Проверка структуры результата для ошибки")
	result = coordinator_no_dealer.draw_player_third(deck)
	has_success = result.has("success")
	has_card = result.has("card")
	has_error = result.has("error")
	if has_success and has_card and has_error:
		print("  ✅ PASS: Все поля присутствуют в результате ошибки")
		passed += 1
	else:
		print("  ❌ FAIL: Отсутствуют поля в результате ошибки")
		failed += 1
	
	# Тест 9: Проверка типа карты в результате
	print("\n📋 Тест 9: Проверка типа карты в результате")
	hand_manager.reset()
	result = coordinator.draw_player_third(deck)
	var card = result.get("card", null)
	if card != null and card is Card:
		print("  ✅ PASS: Карта имеет правильный тип")
		passed += 1
	else:
		print("  ❌ FAIL: Карта имеет неправильный тип или отсутствует")
		failed += 1
	
	# Тест 10: Проверка что карты разные при последовательных раздачах
	print("\n📋 Тест 10: Проверка что карты разные при последовательных раздачах")
	hand_manager.reset()
	var result1 = coordinator.draw_player_third(deck)
	var result2 = coordinator.draw_player_third(deck)
	var card1 = result1.get("card", null)
	var card2 = result2.get("card", null)
	if card1 != null and card2 != null and card1 != card2:
		print("  ✅ PASS: Карты разные при последовательных раздачах")
		passed += 1
	else:
		print("  ❌ FAIL: Карты одинаковые или отсутствуют")
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
