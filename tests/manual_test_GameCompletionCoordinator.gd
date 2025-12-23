# res://tests/manual_test_GameCompletionCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ GameCompletionCoordinator
# ═══════════════════════════════════════════════════════════════════════════

extends Node

var coordinator: GameCompletionCoordinator = null

func _ready():
	print("════════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ GameCompletionCoordinator")
	print("════════════════════════════════════════════════════════════")
	
	# Создаём координатор
	coordinator = GameCompletionCoordinator.new()
	
	# Запускаем тесты
	_run_tests()
	
	print("════════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("════════════════════════════════════════════════════════════")

func _run_tests():
	var passed = 0
	var failed = 0
	
	# Тест 1: get_completion_instructions возвращает инструкции
	print("\n📋 Тест 1: get_completion_instructions возвращает инструкции")
	var instructions = coordinator.get_completion_instructions()
	if instructions is Dictionary and not instructions.is_empty():
		print("  ✅ PASS: Инструкции получены")
		passed += 1
	else:
		print("  ❌ FAIL: Ожидались инструкции")
		failed += 1
	
	# Тест 2: Проверка структуры инструкций
	print("\n📋 Тест 2: Проверка структуры инструкций")
	instructions = coordinator.get_completion_instructions()
	var has_reset_player = instructions.has("should_reset_player_third_ui")
	var has_reset_banker = instructions.has("should_reset_banker_third_ui")
	var has_update_button = instructions.has("should_update_action_button")
	var has_button_text = instructions.has("action_button_text")
	if has_reset_player and has_reset_banker and has_update_button and has_button_text:
		print("  ✅ PASS: Все поля присутствуют в инструкциях")
		passed += 1
	else:
		print("  ❌ FAIL: Отсутствуют поля в инструкциях")
		failed += 1
	
	# Тест 3: Проверка значений инструкций
	print("\n📋 Тест 3: Проверка значений инструкций")
	instructions = coordinator.get_completion_instructions()
	if instructions.get("should_reset_player_third_ui", false) and \
	   instructions.get("should_reset_banker_third_ui", false) and \
	   instructions.get("should_update_action_button", false):
		print("  ✅ PASS: Значения инструкций корректны")
		passed += 1
	else:
		print("  ❌ FAIL: Значения инструкций некорректны")
		failed += 1
	
	# Тест 4: Проверка типа данных action_button_text
	print("\n📋 Тест 4: Проверка типа данных action_button_text")
	instructions = coordinator.get_completion_instructions()
	var button_text = instructions.get("action_button_text", "")
	if button_text is String and not button_text.is_empty():
		print("  ✅ PASS: action_button_text имеет правильный тип и не пустой")
		passed += 1
	else:
		print("  ❌ FAIL: action_button_text имеет неправильный тип или пустой")
		failed += 1
	
	# Тест 5: Проверка типов данных в инструкциях
	print("\n📋 Тест 5: Проверка типов данных в инструкциях")
	instructions = coordinator.get_completion_instructions()
	var reset_player = instructions.get("should_reset_player_third_ui", true)
	var reset_banker = instructions.get("should_reset_banker_third_ui", true)
	var update_button = instructions.get("should_update_action_button", true)
	if reset_player is bool and reset_banker is bool and update_button is bool:
		print("  ✅ PASS: Типы данных корректны")
		passed += 1
	else:
		print("  ❌ FAIL: Типы данных некорректны")
		failed += 1
	
	# Тест 6: Повторный вызов возвращает те же инструкции
	print("\n📋 Тест 6: Повторный вызов возвращает те же инструкции")
	var instructions1 = coordinator.get_completion_instructions()
	var instructions2 = coordinator.get_completion_instructions()
	if instructions1.get("should_reset_player_third_ui") == instructions2.get("should_reset_player_third_ui") and \
	   instructions1.get("should_reset_banker_third_ui") == instructions2.get("should_reset_banker_third_ui"):
		print("  ✅ PASS: Повторный вызов возвращает те же инструкции")
		passed += 1
	else:
		print("  ❌ FAIL: Повторный вызов возвращает разные инструкции")
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

