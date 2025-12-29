# res://scripts/ui/PayoutOverlayStyleManager.gd
# Менеджер стилей для PayoutOverlay
# Ответственность: применение стилей ко всем UI элементам окна выплат

class_name PayoutOverlayStyleManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# UI ЭЛЕМЕНТЫ (ссылки на узлы для стилизации)
# ═══════════════════════════════════════════════════════════════════════════

var result_label: Label
var stake_label: Label
var amount_panel: Panel
var collected_amount_label: Label
var payout_button: Button
var hint_button: Button
var main_panel: Panel
var chip_stacks_container: Control
var fleet_panel: Panel
var chip_fleet_container: Control

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	result_label_ref: Label,
	stake_label_ref: Label,
	amount_panel_ref: Panel,
	collected_amount_label_ref: Label,
	payout_button_ref: Button,
	hint_button_ref: Button,
	main_panel_ref: Panel,
	chip_stacks_container_ref: Control,
	fleet_panel_ref: Panel,
	chip_fleet_container_ref: Control
):
	"""Инициализация менеджера стилей
	
	Args:
		result_label_ref: Label для заголовка результата
		stake_label_ref: Label для ставки
		amount_panel_ref: Panel для суммы выплаты
		collected_amount_label_ref: Label для суммы выплаты
		payout_button_ref: Button "Выплатить"
		hint_button_ref: Button подсказки "?"
		main_panel_ref: Panel для стопок фишек
		chip_stacks_container_ref: Контейнер стопок
		fleet_panel_ref: Panel для кнопок фишек
		chip_fleet_container_ref: Контейнер кнопок фишек
	"""
	result_label = result_label_ref
	stake_label = stake_label_ref
	amount_panel = amount_panel_ref
	collected_amount_label = collected_amount_label_ref
	payout_button = payout_button_ref
	hint_button = hint_button_ref
	main_panel = main_panel_ref
	chip_stacks_container = chip_stacks_container_ref
	fleet_panel = fleet_panel_ref
	chip_fleet_container = chip_fleet_container_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func setup_all_styles():
	"""Применить стили ко всем элементам UI"""
	_setup_result_label_style()
	_setup_stake_label_style()
	_setup_amount_panel_style()
	_setup_collected_amount_label_style()
	_setup_payout_button_style()
	_setup_hint_button_style()
	_setup_main_panel_style()
	_setup_chip_stacks_container_style()
	_setup_fleet_panel_style()
	_setup_chip_fleet_container_style()

func update_hint_button_style(purchased: bool):
	"""Обновить стиль кнопки подсказки в зависимости от состояния покупки
	
	Args:
		purchased: true если подсказка куплена (зеленая), false если не куплена (красная)
	"""
	if not hint_button:
		return

	var hint_style_normal: StyleBoxFlat = StyleBoxFlat.new()
	var hint_style_hover: StyleBoxFlat = StyleBoxFlat.new()
	
	if purchased:
		# Зеленая кнопка (куплена)
		hint_style_normal.bg_color = Color(0.2, 0.6, 0.3)  # Зелёный
		hint_style_hover.bg_color = Color(0.3, 0.7, 0.4)   # Светло-зелёный
	else:
		# Красная кнопка (не куплена)
		hint_style_normal.bg_color = Color(0.6, 0.2, 0.2)  # Красный
		hint_style_hover.bg_color = Color(0.7, 0.3, 0.3)   # Светло-красный
	
	# Общие настройки для обоих стилей
	hint_style_normal.border_width_left = 2
	hint_style_normal.border_width_top = 2
	hint_style_normal.border_width_right = 2
	hint_style_normal.border_width_bottom = 2
	hint_style_normal.border_color = Color(0.7, 0.5, 0.2)
	hint_style_normal.corner_radius_top_left = 8
	hint_style_normal.corner_radius_top_right = 8
	hint_style_normal.corner_radius_bottom_left = 8
	hint_style_normal.corner_radius_bottom_right = 8
	
	hint_style_hover.border_width_left = 2
	hint_style_hover.border_width_top = 2
	hint_style_hover.border_width_right = 2
	hint_style_hover.border_width_bottom = 2
	hint_style_hover.border_color = Color(0.8, 0.6, 0.3)
	hint_style_hover.corner_radius_top_left = 8
	hint_style_hover.corner_radius_top_right = 8
	hint_style_hover.corner_radius_bottom_left = 8
	hint_style_hover.corner_radius_bottom_right = 8
	
	hint_button.add_theme_stylebox_override("normal", hint_style_normal)
	hint_button.add_theme_stylebox_override("hover", hint_style_hover)
	hint_button.add_theme_color_override("font_color", Color(1, 1, 1))

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - СТИЛИЗАЦИЯ ЭЛЕМЕНТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _setup_result_label_style():
	"""Стилизация заголовка результата"""
	result_label.add_theme_font_size_override("font_size", GameConstants.FONT_SIZE_RESULT_LABEL)
	result_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	result_label.add_theme_constant_override("outline_size", 3)

func _setup_stake_label_style():
	"""Стилизация метки ставки"""
	stake_label.add_theme_font_size_override("font_size", GameConstants.FONT_SIZE_STAKE_LABEL)
	stake_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))  # Золотистый

func _setup_amount_panel_style():
	"""Стилизация панели суммы"""
	var amount_style: StyleBoxFlat = StyleBoxFlat.new()
	amount_style.bg_color = GameConstants.AMOUNT_PANEL_BG_COLOR
	amount_style.border_width_left = 2
	amount_style.border_width_top = 2
	amount_style.border_width_right = 2
	amount_style.border_width_bottom = 2
	amount_style.border_color = GameConstants.AMOUNT_PANEL_BORDER_COLOR
	amount_style.corner_radius_top_left = 6
	amount_style.corner_radius_top_right = 6
	amount_style.corner_radius_bottom_left = 6
	amount_style.corner_radius_bottom_right = 6
	amount_panel.add_theme_stylebox_override("panel", amount_style)

func _setup_collected_amount_label_style():
	"""Стилизация метки собранной суммы"""
	collected_amount_label.add_theme_font_size_override("font_size", 36)
	collected_amount_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

func _setup_payout_button_style():
	"""Стилизация кнопки выплаты"""
	payout_button.text = "Выплатить"
	payout_button.add_theme_font_size_override("font_size", GameConstants.FONT_SIZE_PAYOUT_BUTTON)

	var payout_style_normal: StyleBoxFlat = StyleBoxFlat.new()
	payout_style_normal.bg_color = Color(0.15, 0.6, 0.3)  # Зелёная
	payout_style_normal.border_width_left = 3
	payout_style_normal.border_width_top = 3
	payout_style_normal.border_width_right = 3
	payout_style_normal.border_width_bottom = 3
	payout_style_normal.border_color = Color(0.7, 0.5, 0.2)  # Золотистая рамка
	payout_style_normal.corner_radius_top_left = 8
	payout_style_normal.corner_radius_top_right = 8
	payout_style_normal.corner_radius_bottom_left = 8
	payout_style_normal.corner_radius_bottom_right = 8
	payout_button.add_theme_stylebox_override("normal", payout_style_normal)

	var payout_style_hover: StyleBoxFlat = StyleBoxFlat.new()
	payout_style_hover.bg_color = Color(0.2, 0.7, 0.4)
	payout_style_hover.border_width_left = 3
	payout_style_hover.border_width_top = 3
	payout_style_hover.border_width_right = 3
	payout_style_hover.border_width_bottom = 3
	payout_style_hover.border_color = Color(0.8, 0.6, 0.3)
	payout_style_hover.corner_radius_top_left = 8
	payout_style_hover.corner_radius_top_right = 8
	payout_style_hover.corner_radius_bottom_left = 8
	payout_style_hover.corner_radius_bottom_right = 8
	payout_button.add_theme_stylebox_override("hover", payout_style_hover)

	payout_button.add_theme_color_override("font_color", Color(1, 1, 1))

func _setup_hint_button_style():
	"""Стилизация кнопки подсказки (начальный стиль - красная)"""
	hint_button.text = "?"
	hint_button.add_theme_font_size_override("font_size", 28)
	update_hint_button_style(false)  # Красная кнопка (не куплена)

func _setup_main_panel_style():
	"""Стилизация главной панели (стопки фишек)"""
	var main_style: StyleBoxFlat = StyleBoxFlat.new()
	main_style.bg_color = GameConstants.MAIN_PANEL_BG_COLOR
	main_style.border_width_left = 2
	main_style.border_width_top = 2
	main_style.border_width_right = 2
	main_style.border_width_bottom = 2
	main_style.border_color = GameConstants.MAIN_PANEL_BORDER_COLOR
	main_style.corner_radius_top_left = 8
	main_style.corner_radius_top_right = 8
	main_style.corner_radius_bottom_left = 8
	main_style.corner_radius_bottom_right = 8
	main_panel.add_theme_stylebox_override("panel", main_style)

func _setup_chip_stacks_container_style():
	"""Стилизация контейнера стопок"""
	chip_stacks_container.custom_minimum_size = Vector2(0, 240)  # ← Уменьшили высоту с 280 до 240
	chip_stacks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_stacks_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # ← Выравнивание по верху
	chip_stacks_container.add_theme_constant_override("separation", 5)  # ← Уменьшили с 10 до 5

func _setup_fleet_panel_style():
	"""Стилизация панели флота (кнопки фишек)"""
	var fleet_style: StyleBoxFlat = StyleBoxFlat.new()
	fleet_style.bg_color = GameConstants.FLEET_PANEL_BG_COLOR
	fleet_style.border_width_left = 2
	fleet_style.border_width_top = 2
	fleet_style.border_width_right = 2
	fleet_style.border_width_bottom = 2
	fleet_style.border_color = GameConstants.FLEET_PANEL_BORDER_COLOR
	fleet_style.corner_radius_top_left = 8
	fleet_style.corner_radius_top_right = 8
	fleet_style.corner_radius_bottom_left = 8
	fleet_style.corner_radius_bottom_right = 8
	fleet_panel.add_theme_stylebox_override("panel", fleet_style)

func _setup_chip_fleet_container_style():
	"""Стилизация контейнера кнопок фишек"""
	chip_fleet_container.add_theme_constant_override("separation", 10)

