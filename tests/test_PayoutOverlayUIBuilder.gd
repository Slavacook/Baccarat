# res://tests/test_PayoutOverlayUIBuilder.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ PayoutOverlayUIBuilder
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var ui_builder: PayoutOverlayUIBuilder
var mock_chip_fleet_container: Control
var mock_result_label: Label

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	mock_chip_fleet_container = Control.new()
	mock_result_label = Label.new()
	ui_builder = PayoutOverlayUIBuilder.new(mock_chip_fleet_container, mock_result_label)

func after_each():
	"""Очистка после каждого теста"""
	if ui_builder:
		ui_builder = null
	if mock_chip_fleet_container:
		mock_chip_fleet_container.queue_free()
	if mock_result_label:
		mock_result_label.queue_free()

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: format_amount (статический метод)
# ═══════════════════════════════════════════════════════════════════════════

func test_format_amount_integer():
	"""Проверка: форматирование целого числа"""
	var result = PayoutOverlayUIBuilder.format_amount(100.0)
	assert_eq(result, "100", "Целое число должно форматироваться без десятичных знаков")

func test_format_amount_zero():
	"""Проверка: форматирование нуля"""
	var result = PayoutOverlayUIBuilder.format_amount(0.0)
	assert_eq(result, "0", "Ноль должен форматироваться как '0'")

func test_format_amount_decimal():
	"""Проверка: форматирование дробного числа"""
	var result = PayoutOverlayUIBuilder.format_amount(50.5)
	assert_eq(result, "50.5", "Дробное число должно сохранять десятичные знаки")

func test_format_amount_small_decimal():
	"""Проверка: форматирование маленького дробного числа"""
	var result = PayoutOverlayUIBuilder.format_amount(0.5)
	assert_eq(result, "0.5", "Маленькое дробное число должно сохранять десятичные знаки")

func test_format_amount_large_integer():
	"""Проверка: форматирование большого целого числа"""
	var result = PayoutOverlayUIBuilder.format_amount(1000000.0)
	assert_eq(result, "1000000", "Большое целое число должно форматироваться без десятичных знаков")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: set_result_header
# ═══════════════════════════════════════════════════════════════════════════

func test_set_result_header_player():
	"""Проверка: установка заголовка для Player"""
	ui_builder.set_result_header("Player")
	# Проверяем что текст установлен (может быть локализован)
	assert_false(mock_result_label.text.is_empty(), "Текст заголовка должен быть установлен")
	# Проверяем что цвет установлен (синий)
	var color = mock_result_label.get_theme_color("font_color")
	assert_not_null(color, "Цвет должен быть установлен")

func test_set_result_header_banker():
	"""Проверка: установка заголовка для Banker"""
	ui_builder.set_result_header("Banker")
	assert_false(mock_result_label.text.is_empty(), "Текст заголовка должен быть установлен")

func test_set_result_header_tie():
	"""Проверка: установка заголовка для Tie"""
	ui_builder.set_result_header("Tie")
	assert_false(mock_result_label.text.is_empty(), "Текст заголовка должен быть установлен")

func test_set_result_header_pair_player():
	"""Проверка: установка заголовка для PairPlayer"""
	ui_builder.set_result_header("PairPlayer")
	assert_false(mock_result_label.text.is_empty(), "Текст заголовка должен быть установлен")

func test_set_result_header_pair_banker():
	"""Проверка: установка заголовка для PairBanker"""
	ui_builder.set_result_header("PairBanker")
	assert_false(mock_result_label.text.is_empty(), "Текст заголовка должен быть установлен")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: create_chip_buttons
# ═══════════════════════════════════════════════════════════════════════════

func test_create_chip_buttons_empty():
	"""Проверка: создание кнопок с пустым массивом номиналов"""
	ui_builder.create_chip_buttons([])
	assert_eq(mock_chip_fleet_container.get_child_count(), 0, "Не должно быть кнопок при пустом массиве")

func test_create_chip_buttons_single():
	"""Проверка: создание одной кнопки"""
	var denominations = [100.0]
	ui_builder.create_chip_buttons(denominations)
	assert_eq(mock_chip_fleet_container.get_child_count(), 1, "Должна быть создана одна кнопка")

func test_create_chip_buttons_multiple():
	"""Проверка: создание нескольких кнопок"""
	var denominations = [1.0, 5.0, 25.0, 100.0]
	ui_builder.create_chip_buttons(denominations)
	assert_eq(mock_chip_fleet_container.get_child_count(), 4, "Должны быть созданы 4 кнопки")

func test_create_chip_buttons_clears_existing():
	"""Проверка: очистка существующих кнопок перед созданием новых"""
	# Создаём первую партию
	ui_builder.create_chip_buttons([100.0])
	assert_eq(mock_chip_fleet_container.get_child_count(), 1, "Первая партия: 1 кнопка")
	
	# Создаём вторую партию
	ui_builder.create_chip_buttons([1.0, 5.0])
	# Ждём освобождения старых кнопок
	await get_tree().process_frame
	assert_eq(mock_chip_fleet_container.get_child_count(), 2, "Вторая партия: должно быть 2 кнопки (старые удалены)")

