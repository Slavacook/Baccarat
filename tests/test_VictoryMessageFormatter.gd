# res://tests/test_VictoryMessageFormatter.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ VictoryMessageFormatter
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var formatter: VictoryMessageFormatter

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	formatter = VictoryMessageFormatter.new()

func after_each():
	"""Очистка после каждого теста"""
	formatter = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: format_victory_message
# ═══════════════════════════════════════════════════════════════════════════

func test_format_victory_message_tie():
	"""Проверка: форматирование Tie (игалите)"""
	var message = formatter.format_victory_message("Tie", 8, 8)
	assert_eq(message, "Игалите", "Сообщение для Tie должно быть 'Игалите'")

func test_format_victory_message_player():
	"""Проверка: форматирование победы Player"""
	var message = formatter.format_victory_message("Player", 9, 7)
	assert_true(message.contains("Выиграл"), "Сообщение должно содержать 'Выиграл'")
	assert_true(message.contains("9"), "Сообщение должно содержать очки игрока")
	assert_true(message.contains("7"), "Сообщение должно содержать очки банкира")

func test_format_victory_message_banker():
	"""Проверка: форматирование победы Banker"""
	var message = formatter.format_victory_message("Banker", 5, 8)
	assert_true(message.contains("Выиграл"), "Сообщение должно содержать 'Выиграл'")
	assert_true(message.contains("8"), "Сообщение должно содержать очки банкира")
	assert_true(message.contains("5"), "Сообщение должно содержать очки игрока")

func test_format_victory_message_player_zero():
	"""Проверка: форматирование с нулевыми очками"""
	var message = formatter.format_victory_message("Player", 0, 0)
	assert_true(message.contains("Выиграл"), "Сообщение должно содержать 'Выиграл'")
	assert_true(message.contains("0"), "Сообщение должно содержать нулевые очки")

func test_format_victory_message_banker_natural():
	"""Проверка: форматирование натуральной победы Banker"""
	var message = formatter.format_victory_message("Banker", 3, 9)
	assert_true(message.contains("Выиграл"), "Сообщение должно содержать 'Выиграл'")
	assert_true(message.contains("9"), "Сообщение должно содержать очки банкира (9)")
	assert_true(message.contains("3"), "Сообщение должно содержать очки игрока (3)")

