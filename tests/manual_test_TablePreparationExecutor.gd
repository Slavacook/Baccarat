# res://tests/manual_test_TablePreparationExecutor.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЕ ТЕСТИРОВАНИЕ TablePreparationExecutor
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var executor: TablePreparationExecutor = null
var round_completion_coordinator: RoundCompletionCoordinator = null
var payout_queue_manager: PayoutQueueManager = null
var bet_filter_manager: BetFilterManager = null
var guest_bet_factory: GuestBetFactory = null
var chip_restoration_coordinator: ChipRestorationCoordinator = null

var test_resolve_heart_bet_called: bool = false
var test_resolve_heart_bet_winner: String = ""
var test_reset_round_called: bool = false
var test_reset_round_update_state: bool = true
var test_restore_chips_called: bool = false
var test_apply_filters_called: bool = false

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ TablePreparationExecutor")
	print("════════════════════════════════════════════════════════════")
	
	# Инициализация
	round_completion_coordinator = RoundCompletionCoordinator.new()
	bet_filter_manager = BetFilterManager.new()
	chip_restoration_coordinator = ChipRestorationCoordinator.new()
	
	# Создаем исполнитель
	executor = TablePreparationExecutor.new(
		round_completion_coordinator,
		payout_queue_manager,
		bet_filter_manager,
		guest_bet_factory,
		chip_restoration_coordinator
	)
	
	# Запускаем тесты
	run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: Выполнение с разрешением Heart Bet
	print("\n📋 Тест 1: Выполнение с разрешением Heart Bet")
	reset_test_flags()
	var instructions_heart_bet = {
		"should_resolve_heart_bet": true,
		"should_show_message": false,
		"should_reset_round": false,
		"should_restore_chips": false,
		"should_apply_filters": false,
		"should_generate_guest_bets": false,
		"should_add_score": false,
		"should_set_waiting_state": false
	}
	TableStateManager.set_actual_winner("Player")
	var result = executor.execute_preparation_actions(
		instructions_heart_bet,
		_resolve_heart_bet_callback,
		_reset_round_callback,
		_restore_chips_callback,
		_apply_filters_callback
	)
	if result.get("should_continue", true) == false and test_resolve_heart_bet_called and test_resolve_heart_bet_winner == "Player":
		print("  ✅ PASS: Heart Bet разрешен корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Heart Bet не разрешен корректно")
		failed += 1
	
	# Тест 2: Выполнение обычной подготовки
	print("\n📋 Тест 2: Выполнение обычной подготовки")
	reset_test_flags()
	var instructions_normal = {
		"should_resolve_heart_bet": false,
		"should_show_message": true,
		"should_reset_round": true,
		"should_restore_chips": true,
		"should_apply_filters": true,
		"should_generate_guest_bets": true,
		"should_add_score": true,
		"should_set_waiting_state": true
	}
	result = executor.execute_preparation_actions(
		instructions_normal,
		_resolve_heart_bet_callback,
		_reset_round_callback,
		_restore_chips_callback,
		_apply_filters_callback
	)
	var actions = result.get("actions_executed", [])
	var expected_actions = ["show_message", "camera_zoom", "add_score", "reset_round", "set_waiting_state", "apply_filters", "generate_guest_bets", "restore_chips"]
	var all_actions_present = true
	for action in expected_actions:
		if not action in actions:
			all_actions_present = false
			break
	if result.get("should_continue", false) == true and all_actions_present and test_reset_round_called and test_restore_chips_called and test_apply_filters_called:
		print("  ✅ PASS: Обычная подготовка выполнена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Обычная подготовка выполнена некорректно")
		print("    Действия: %s" % str(actions))
		failed += 1
	
	# Тест 3: Выполнение без некоторых действий
	print("\n📋 Тест 3: Выполнение без некоторых действий")
	reset_test_flags()
	var instructions_partial = {
		"should_resolve_heart_bet": false,
		"should_show_message": false,
		"should_reset_round": true,
		"should_restore_chips": false,
		"should_apply_filters": false,
		"should_generate_guest_bets": false,
		"should_add_score": false,
		"should_set_waiting_state": true
	}
	result = executor.execute_preparation_actions(
		instructions_partial,
		_resolve_heart_bet_callback,
		_reset_round_callback,
		_restore_chips_callback,
		_apply_filters_callback
	)
	actions = result.get("actions_executed", [])
	if "camera_zoom" in actions and "reset_round" in actions and "set_waiting_state" in actions and \
	   not "show_message" in actions and not "add_score" in actions and not "restore_chips" in actions:
		print("  ✅ PASS: Частичная подготовка выполнена корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Частичная подготовка выполнена некорректно")
		print("    Действия: %s" % str(actions))
		failed += 1
	
	# Тест 4: Проверка структуры результата
	print("\n📋 Тест 4: Проверка структуры результата")
	reset_test_flags()
	result = executor.execute_preparation_actions(
		instructions_normal,
		_resolve_heart_bet_callback,
		_reset_round_callback,
		_restore_chips_callback,
		_apply_filters_callback
	)
	if result.has("should_continue") and result.has("actions_executed"):
		print("  ✅ PASS: Структура результата корректна")
		passed += 1
	else:
		print("  ❌ FAIL: Структура результата некорректна")
		failed += 1
	
	# Тест 5: Выполнение с невалидными коллбэками
	print("\n📋 Тест 5: Выполнение с невалидными коллбэками")
	reset_test_flags()
	var invalid_callback = Callable()
	result = executor.execute_preparation_actions(
		instructions_normal,
		invalid_callback,
		invalid_callback,
		invalid_callback,
		invalid_callback
	)
	# Должны выполниться действия, которые не требуют коллбэков (camera_zoom, add_score, set_waiting_state)
	actions = result.get("actions_executed", [])
	if "camera_zoom" in actions and not test_reset_round_called and not test_restore_chips_called:
		print("  ✅ PASS: Невалидные коллбэки обработаны корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Невалидные коллбэки обработаны некорректно")
		failed += 1
	
	# Тест 6: Проверка параметров коллбэков
	print("\n📋 Тест 6: Проверка параметров коллбэков")
	reset_test_flags()
	TableStateManager.set_actual_winner("Banker")
	result = executor.execute_preparation_actions(
		instructions_heart_bet,
		_resolve_heart_bet_callback,
		_reset_round_callback,
		_restore_chips_callback,
		_apply_filters_callback
	)
	if test_resolve_heart_bet_winner == "Banker":
		print("  ✅ PASS: Параметры коллбэков переданы корректно")
		passed += 1
	else:
		print("  ❌ FAIL: Параметры коллбэков переданы некорректно")
		failed += 1
	
	# Тест 7: Проверка reset_round с update_state=false
	print("\n📋 Тест 7: Проверка reset_round с update_state=false")
	reset_test_flags()
	result = executor.execute_preparation_actions(
		instructions_normal,
		_resolve_heart_bet_callback,
		_reset_round_callback,
		_restore_chips_callback,
		_apply_filters_callback
	)
	if test_reset_round_called and test_reset_round_update_state == false:
		print("  ✅ PASS: reset_round вызван с update_state=false")
		passed += 1
	else:
		print("  ❌ FAIL: reset_round вызван некорректно")
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

func reset_test_flags():
	test_resolve_heart_bet_called = false
	test_resolve_heart_bet_winner = ""
	test_reset_round_called = false
	test_reset_round_update_state = true
	test_restore_chips_called = false
	test_apply_filters_called = false

func _resolve_heart_bet_callback(actual_winner: String):
	test_resolve_heart_bet_called = true
	test_resolve_heart_bet_winner = actual_winner

func _reset_round_callback(update_state: bool):
	test_reset_round_called = true
	test_reset_round_update_state = update_state

func _restore_chips_callback():
	test_restore_chips_called = true

func _apply_filters_callback():
	test_apply_filters_called = true

