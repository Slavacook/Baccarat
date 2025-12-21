# res://scripts/popups/TestCardsPopup.gd
# Попап для настройки тестовых карт
# Позволяет задать первые 4 карты для тестирования триггеров

extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

const SUITS = ["♣ Трефы", "♥ Черви", "♠ Пики", "♦ Бубны"]
const VALUES = ["Случайная", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

var background: ColorRect
var panel: PanelContainer
var title_label: Label
var enabled_checkbox: CheckBox

# Карты игрока
var player1_value: OptionButton
var player1_suit: OptionButton
var player2_value: OptionButton
var player2_suit: OptionButton

# Карты банкира
var banker1_value: OptionButton
var banker1_suit: OptionButton
var banker2_value: OptionButton
var banker2_suit: OptionButton

var apply_button: Button
var close_button: Button
var preset_pairs_button: Button  # Быстрая настройка "две пары"

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	layer = 250  # Поверх настроек
	_create_ui()
	_connect_signals()
	_load_current_values()
	hide()

func _create_ui():
	"""Создать UI программно"""
	# Фон (затемнение)
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Панель
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 450)
	panel.offset_left = -250
	panel.offset_top = -225
	panel.offset_right = 250
	panel.offset_bottom = 225
	add_child(panel)
	
	# Основной контейнер
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	panel.add_child(main_vbox)
	
	# Отступ сверху
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	main_vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(content_vbox)
	
	# Заголовок
	title_label = Label.new()
	title_label.text = "🧪 Тестовые карты"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	content_vbox.add_child(title_label)
	
	# Чекбокс включения
	enabled_checkbox = CheckBox.new()
	enabled_checkbox.text = "Включить режим тестовых карт"
	content_vbox.add_child(enabled_checkbox)
	
	# Разделитель
	var sep1 = HSeparator.new()
	content_vbox.add_child(sep1)
	
	# Карты игрока
	var player_label = Label.new()
	player_label.text = "🔴 PLAYER (Игрок)"
	player_label.add_theme_font_size_override("font_size", 18)
	content_vbox.add_child(player_label)
	
	var player_grid = GridContainer.new()
	player_grid.columns = 3
	player_grid.add_theme_constant_override("h_separation", 10)
	player_grid.add_theme_constant_override("v_separation", 8)
	content_vbox.add_child(player_grid)
	
	# Player Card 1
	var p1_label = Label.new()
	p1_label.text = "Карта 1:"
	player_grid.add_child(p1_label)
	player1_value = _create_value_option()
	player_grid.add_child(player1_value)
	player1_suit = _create_suit_option()
	player_grid.add_child(player1_suit)
	
	# Player Card 2
	var p2_label = Label.new()
	p2_label.text = "Карта 2:"
	player_grid.add_child(p2_label)
	player2_value = _create_value_option()
	player_grid.add_child(player2_value)
	player2_suit = _create_suit_option()
	player_grid.add_child(player2_suit)
	
	# Разделитель
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# Карты банкира
	var banker_label = Label.new()
	banker_label.text = "🟡 BANKER (Банкир)"
	banker_label.add_theme_font_size_override("font_size", 18)
	content_vbox.add_child(banker_label)
	
	var banker_grid = GridContainer.new()
	banker_grid.columns = 3
	banker_grid.add_theme_constant_override("h_separation", 10)
	banker_grid.add_theme_constant_override("v_separation", 8)
	content_vbox.add_child(banker_grid)
	
	# Banker Card 1
	var b1_label = Label.new()
	b1_label.text = "Карта 1:"
	banker_grid.add_child(b1_label)
	banker1_value = _create_value_option()
	banker_grid.add_child(banker1_value)
	banker1_suit = _create_suit_option()
	banker_grid.add_child(banker1_suit)
	
	# Banker Card 2
	var b2_label = Label.new()
	b2_label.text = "Карта 2:"
	banker_grid.add_child(b2_label)
	banker2_value = _create_value_option()
	banker_grid.add_child(banker2_value)
	banker2_suit = _create_suit_option()
	banker_grid.add_child(banker2_suit)
	
	# Разделитель
	var sep3 = HSeparator.new()
	content_vbox.add_child(sep3)
	
	# Быстрые настройки
	var presets_hbox = HBoxContainer.new()
	presets_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(presets_hbox)
	
	preset_pairs_button = Button.new()
	preset_pairs_button.text = "🔫 Две пары (5,5 + 10,10)"
	preset_pairs_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	presets_hbox.add_child(preset_pairs_button)
	
	var preset_natural_button = Button.new()
	preset_natural_button.text = "❓ Натуральная (9)"
	preset_natural_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_natural_button.pressed.connect(_on_preset_natural)
	presets_hbox.add_child(preset_natural_button)
	
	# Кнопки управления
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 20)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(buttons_hbox)
	
	apply_button = Button.new()
	apply_button.text = "✅ Применить"
	apply_button.custom_minimum_size = Vector2(150, 40)
	buttons_hbox.add_child(apply_button)
	
	close_button = Button.new()
	close_button.text = "❌ Закрыть"
	close_button.custom_minimum_size = Vector2(150, 40)
	buttons_hbox.add_child(close_button)

func _create_value_option() -> OptionButton:
	"""Создать OptionButton для выбора значения карты"""
	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(120, 30)
	for i in range(VALUES.size()):
		option.add_item(VALUES[i], i)
	return option

func _create_suit_option() -> OptionButton:
	"""Создать OptionButton для выбора масти"""
	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(120, 30)
	for i in range(SUITS.size()):
		option.add_item(SUITS[i], i)
	return option

func _connect_signals():
	"""Подключить сигналы"""
	background.gui_input.connect(_on_background_input)
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)
	preset_pairs_button.pressed.connect(_on_preset_pairs)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func open_popup():
	"""Открыть попап"""
	_load_current_values()
	show()
	print("🧪 Попап тестовых карт открыт")

func close_popup():
	"""Закрыть попап"""
	hide()
	print("🧪 Попап тестовых карт закрыт")

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _load_current_values():
	"""Загрузить текущие значения из TestCardsManager"""
	enabled_checkbox.button_pressed = TestCardsManager.enabled
	
	_load_card_option("player1", player1_value, player1_suit)
	_load_card_option("player2", player2_value, player2_suit)
	_load_card_option("banker1", banker1_value, banker1_suit)
	_load_card_option("banker2", banker2_value, banker2_suit)

func _load_card_option(position: String, value_opt: OptionButton, suit_opt: OptionButton):
	"""Загрузить значения для одной карты"""
	var data = TestCardsManager.get_card_data(position)
	value_opt.selected = data["value"]
	suit_opt.selected = data["suit"]

func _apply_values():
	"""Применить выбранные значения"""
	TestCardsManager.set_enabled(enabled_checkbox.button_pressed)
	
	_apply_card("player1", player1_value, player1_suit)
	_apply_card("player2", player2_value, player2_suit)
	_apply_card("banker1", banker1_value, banker1_suit)
	_apply_card("banker2", banker2_value, banker2_suit)
	
	print("🧪 Тестовые карты применены")

func _apply_card(position: String, value_opt: OptionButton, suit_opt: OptionButton):
	"""Применить значения для одной карты"""
	var value = value_opt.selected  # 0 = случайная, 1-13 = A-K
	var suit = suit_opt.selected    # 0-3 = масти
	TestCardsManager.set_test_card(position, suit, value)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_background_input(event: InputEvent):
	"""Клик по фону закрывает попап"""
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _on_apply_pressed():
	"""Применить и закрыть"""
	_apply_values()
	close_popup()

func _on_close_pressed():
	"""Закрыть без применения"""
	close_popup()

func _on_preset_pairs():
	"""Быстрая настройка: две пары (для тестирования Revolver Card)"""
	enabled_checkbox.button_pressed = true
	
	# Player: 5♠, 5♦
	player1_value.selected = 5   # 5
	player1_suit.selected = 2    # Spades
	player2_value.selected = 5   # 5
	player2_suit.selected = 3    # Diamonds
	
	# Banker: 10♥, 10♦
	banker1_value.selected = 10  # 10
	banker1_suit.selected = 1    # Hearts
	banker2_value.selected = 10  # 10
	banker2_suit.selected = 3    # Diamonds
	
	print("🧪 Пресет 'Две пары' установлен")

func _on_preset_natural():
	"""Быстрая настройка: натуральная победа (для тестирования Mystery Card)"""
	enabled_checkbox.button_pressed = true
	
	# Player: 9♠, K♦ = 9 (натуральная)
	player1_value.selected = 9   # 9
	player1_suit.selected = 2    # Spades
	player2_value.selected = 13  # K
	player2_suit.selected = 3    # Diamonds
	
	# Banker: 3♥, 4♦ = 7
	banker1_value.selected = 3   # 3
	banker1_suit.selected = 1    # Hearts
	banker2_value.selected = 4   # 4
	banker2_suit.selected = 3    # Diamonds
	
	print("🧪 Пресет 'Натуральная победа' установлен")

