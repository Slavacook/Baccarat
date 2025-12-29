# res://tests/test_PayoutOverlayStyleManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ PayoutOverlayStyleManager
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var style_manager: PayoutOverlayStyleManager
var mock_result_label: Label
var mock_stake_label: Label
var mock_amount_panel: Panel
var mock_collected_amount_label: Label
var mock_payout_button: Button
var mock_hint_button: Button
var mock_main_panel: Panel
var mock_chip_stacks_container: Control
var mock_fleet_panel: Panel
var mock_chip_fleet_container: Control

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	mock_result_label = Label.new()
	mock_stake_label = Label.new()
	mock_amount_panel = Panel.new()
	mock_collected_amount_label = Label.new()
	mock_payout_button = Button.new()
	mock_hint_button = Button.new()
	mock_main_panel = Panel.new()
	mock_chip_stacks_container = Control.new()
	mock_fleet_panel = Panel.new()
	mock_chip_fleet_container = Control.new()
	
	style_manager = PayoutOverlayStyleManager.new(
		mock_result_label,
		mock_stake_label,
		mock_amount_panel,
		mock_collected_amount_label,
		mock_payout_button,
		mock_hint_button,
		mock_main_panel,
		mock_chip_stacks_container,
		mock_fleet_panel,
		mock_chip_fleet_container
	)

func after_each():
	"""Очистка после каждого теста"""
	if style_manager:
		style_manager = null
	# Освобождаем моки
	mock_result_label.queue_free()
	mock_stake_label.queue_free()
	mock_amount_panel.queue_free()
	mock_collected_amount_label.queue_free()
	mock_payout_button.queue_free()
	mock_hint_button.queue_free()
	mock_main_panel.queue_free()
	mock_chip_stacks_container.queue_free()
	mock_fleet_panel.queue_free()
	mock_chip_fleet_container.queue_free()

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: setup_all_styles
# ═══════════════════════════════════════════════════════════════════════════

func test_setup_all_styles():
	"""Проверка: установка всех стилей"""
	# Метод должен выполниться без ошибок
	style_manager.setup_all_styles()
	# Если нет ошибок - тест пройден
	# Проверяем что стили применены (например, размер шрифта)
	assert_gt(mock_result_label.get_theme_font_size("font_size"), 0, "Размер шрифта должен быть установлен")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: update_hint_button_style
# ═══════════════════════════════════════════════════════════════════════════

func test_update_hint_button_style_not_purchased():
	"""Проверка: обновление стиля кнопки подсказки (не куплена)"""
	style_manager.update_hint_button_style(false)
	# Проверяем что стиль применён (например, цвет фона)
	var style_box = mock_hint_button.get_theme_stylebox("normal")
	assert_not_null(style_box, "Стиль должен быть применён")

func test_update_hint_button_style_purchased():
	"""Проверка: обновление стиля кнопки подсказки (куплена)"""
	style_manager.update_hint_button_style(true)
	# Проверяем что стиль применён
	var style_box = mock_hint_button.get_theme_stylebox("normal")
	assert_not_null(style_box, "Стиль должен быть применён")

