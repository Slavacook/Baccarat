# res://scripts/ui/PayoutOverlayUIBuilder.gd
# Построитель UI элементов для PayoutOverlay
# Инкапсулирует логику создания кнопок фишек, форматирования и обновления UI

extends RefCounted
class_name PayoutOverlayUIBuilder

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var chip_fleet_container: Control  # Контейнер кнопок фишек
var result_label: Label  # Заголовок результата

# ═══════════════════════════════════════════════════════════════════════════
# CALLBACK-ИНТЕРФЕЙС (функции, которые должен предоставить владелец)
# ═══════════════════════════════════════════════════════════════════════════

var on_chip_clicked_callback: Callable  # Вызывается при клике на фишку (denomination: float)
var on_chip_button_input_callback: Callable  # Вызывается при вводе на кнопке фишки (event: InputEvent, denomination: float)

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	chip_fleet_container_ref: Control,
	result_label_ref: Label
):
	"""Инициализация построителя UI
	
	Args:
		chip_fleet_container_ref: Контейнер для кнопок фишек
		result_label_ref: Заголовок результата
	"""
	chip_fleet_container = chip_fleet_container_ref
	result_label = result_label_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - СОЗДАНИЕ UI ЭЛЕМЕНТОВ
# ═══════════════════════════════════════════════════════════════════════════

func create_chip_buttons(chip_denominations: Array) -> void:
	"""Создать кнопки для каждого номинала фишки
	
	Args:
		chip_denominations: Массив номиналов фишек
	"""
	# Очищаем контейнер
	for child in chip_fleet_container.get_children():
		child.queue_free()

	for denomination in chip_denominations:
		var button: TextureButton = TextureButton.new()
		button.custom_minimum_size = GameConstants.CHIP_BUTTON_SIZE
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.focus_mode = Control.FOCUS_NONE  # Не получает фокус (Space не активирует)

		# Загружаем текстуру фишки
		var denom_str: String = str(int(denomination)) if denomination >= 1 else str(denomination)
		var chip_path: String = GameConstants.CHIP_TEXTURE_PATH_TEMPLATE % denom_str
		var texture: Texture2D = load(chip_path)
		if texture:
			button.texture_normal = texture
		else:
			push_warning("PayoutOverlayUIBuilder: текстура не найдена: %s" % chip_path)

		# Подключаем сигналы
		if on_chip_clicked_callback.is_valid():
			button.pressed.connect(on_chip_clicked_callback.bind(denomination))
		if on_chip_button_input_callback.is_valid():
			button.gui_input.connect(on_chip_button_input_callback.bind(denomination))

		chip_fleet_container.add_child(button)

func set_result_header(winner: String) -> void:
	"""Установить заголовок результата с цветом
	
	Args:
		winner: Победитель ("Player"/"Banker"/"Tie"/"PairPlayer"/"PairBanker")
	"""
	match winner:
		"Banker":
			result_label.text = Localization.t("WIN_BANKER")
			result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))  # Красный
		"Player":
			result_label.text = Localization.t("WIN_PLAYER")
			result_label.add_theme_color_override("font_color", Color(0.2, 0.4, 0.9))  # Синий
		"Tie":
			result_label.text = Localization.t("WIN_TIE")
			result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))  # Зелёный
		"PairPlayer":
			result_label.text = Localization.t("PAIR_PLAYER_TITLE")  # "Пара Игрока"
			result_label.add_theme_color_override("font_color", Color(0.2, 0.4, 0.9))  # Синий (как Player)
		"PairBanker":
			result_label.text = Localization.t("PAIR_BANKER_TITLE")  # "Пара Банкира"
			result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))  # Красный (как Banker)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ФОРМАТИРОВАНИЕ
# ═══════════════════════════════════════════════════════════════════════════

static func format_amount(amount: float) -> String:
	"""Форматировать сумму для отображения
	
	Args:
		amount: Сумма для форматирования
		
	Returns:
		Отформатированная строка (без десятичных знаков, если целое число)
	"""
	if amount == floor(amount):
		return str(int(amount))
	else:
		return str(amount)

