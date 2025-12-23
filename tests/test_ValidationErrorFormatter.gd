# res://tests/test_ValidationErrorFormatter.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ ValidationErrorFormatter
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var formatter: ValidationErrorFormatter

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	formatter = ValidationErrorFormatter.new()

func after_each():
	"""Очистка после каждого теста"""
	formatter = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: format_third_card_error
# ═══════════════════════════════════════════════════════════════════════════

func test_format_third_card_error_player_no_draw():
	"""Проверка: форматирование ERR_PLAYER_NO_DRAW с параметрами"""
	var message = formatter.format_third_card_error("ERR_PLAYER_NO_DRAW", 7, -1)
	# Проверяем что сообщение содержит локализацию (может быть разным в зависимости от локализации)
	assert_false(message.is_empty(), "Сообщение не должно быть пустым")

func test_format_third_card_error_banker_must_draw():
	"""Проверка: форматирование ERR_BANKER_MUST_DRAW с параметрами"""
	var message = formatter.format_third_card_error("ERR_BANKER_MUST_DRAW", -1, 5)
	assert_false(message.is_empty(), "Сообщение не должно быть пустым")

func test_format_third_card_error_generic():
	"""Проверка: форматирование общей ошибки"""
	var message = formatter.format_third_card_error("BOTH_CARDS_NEEDED", -1, -1)
	assert_false(message.is_empty(), "Сообщение не должно быть пустым")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: format_winner_selection_error
# ═══════════════════════════════════════════════════════════════════════════

func test_format_winner_selection_error_wrong_winner():
	"""Проверка: форматирование ERR_WRONG_WINNER с параметрами"""
	var message = formatter.format_winner_selection_error("ERR_WRONG_WINNER", ["Banker"])
	assert_false(message.is_empty(), "Сообщение не должно быть пустым")

func test_format_winner_selection_error_ready_message():
	"""Проверка: форматирование готового сообщения (для Tie)"""
	var message = formatter.format_winner_selection_error("Ошибка! Неправильный выбор. Игалите", [])
	assert_eq(message, "Ошибка! Неправильный выбор. Игалите", "Готовое сообщение должно возвращаться как есть")

func test_format_winner_selection_error_generic():
	"""Проверка: форматирование общей ошибки"""
	var message = formatter.format_winner_selection_error("SOME_ERROR", [])
	assert_false(message.is_empty(), "Сообщение не должно быть пустым")

