# res://scripts/ChipVisualManager.gd
# Менеджер визуальных фишек на игровом поле

class_name ChipVisualManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ - ТЕКСТУРЫ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

const CHIP_TEXTURES = {
	"Player": [
		"res://assets/chips/chip_500.png",
		"res://assets/chips/chip_1000.png",
		"res://assets/chips/chip_5000.png"
	],
	"Banker": [
		"res://assets/chips/chip_500.png",
		"res://assets/chips/chip_1000.png",
		"res://assets/chips/chip_5000.png"
	],
	"Tie": [
		"res://assets/chips/chip_25.png",
		"res://assets/chips/chip_100.png",
		"res://assets/chips/chip_500.png"
	],
	"PairPlayer": [
		"res://assets/chips/chip_100.png",
		"res://assets/chips/chip_500.png",
		"res://assets/chips/chip_1000.png"
	],
	"PairBanker": [
		"res://assets/chips/chip_100.png",
		"res://assets/chips/chip_500.png",
		"res://assets/chips/chip_1000.png"
	]
}

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Словарь узлов фишек: {"Player": TextureButton, "Banker": TextureButton, ...}
var chip_nodes: Dictionary = {}

# Текущие выбранные текстуры для каждой фишки
var current_textures: Dictionary = {}

# Сигналы для обработки кликов
signal chip_clicked(bet_type: String)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(player_chip: TextureButton, banker_chip: TextureButton, tie_chip: TextureButton,
		   pair_player_chip: TextureButton = null, pair_banker_chip: TextureButton = null) -> void:
	"""Настройка ссылок на узлы фишек"""
	chip_nodes["Player"] = player_chip
	chip_nodes["Banker"] = banker_chip
	chip_nodes["Tie"] = tie_chip

	if pair_player_chip:
		chip_nodes["PairPlayer"] = pair_player_chip
	if pair_banker_chip:
		chip_nodes["PairBanker"] = pair_banker_chip

	# Скрываем все фишки при старте
	for chip in chip_nodes.values():
		chip.visible = false
		chip.mouse_filter = Control.MOUSE_FILTER_STOP

	print("✅ ChipVisualManager: настроено %d фишек" % chip_nodes.size())


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func show_chip(bet_type: String) -> void:
	"""Показать фишку с рандомной текстурой"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	var chip = chip_nodes[bet_type]
	var texture_path = _get_random_texture(bet_type)

	# Загружаем текстуру
	var texture = load(texture_path)
	if not texture:
		push_error("ChipVisualManager: не удалось загрузить текстуру '%s'" % texture_path)
		return

	chip.texture_normal = texture
	chip.visible = true
	current_textures[bet_type] = texture_path

	print("💰 ChipVisualManager: показана фишка %s (%s)" % [bet_type, texture_path.get_file()])


func hide_chip(bet_type: String) -> void:
	"""Скрыть фишку"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	chip_nodes[bet_type].visible = false
	current_textures.erase(bet_type)

	print("🚫 ChipVisualManager: скрыта фишка %s" % bet_type)


func hide_all_chips() -> void:
	"""Скрыть все фишки"""
	for bet_type in chip_nodes.keys():
		hide_chip(bet_type)


func is_chip_visible(bet_type: String) -> bool:
	"""Проверить, видна ли фишка"""
	if not chip_nodes.has(bet_type):
		return false
	return chip_nodes[bet_type].visible


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КЛИКАБЕЛЬНОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func make_chip_clickable(bet_type: String, clickable: bool) -> void:
	"""Сделать фишку кликабельной/некликабельной"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	var chip = chip_nodes[bet_type]
	chip.disabled = not clickable

	if clickable:
		# Подключаем сигнал нажатия
		if not chip.pressed.is_connected(_on_chip_pressed):
			chip.pressed.connect(_on_chip_pressed.bind(bet_type))
	else:
		# Отключаем сигнал
		if chip.pressed.is_connected(_on_chip_pressed):
			chip.pressed.disconnect(_on_chip_pressed)


func make_all_chips_clickable(clickable: bool) -> void:
	"""Сделать все видимые фишки кликабельными/некликабельными"""
	for bet_type in chip_nodes.keys():
		if is_chip_visible(bet_type):
			make_chip_clickable(bet_type, clickable)


func _on_chip_pressed(bet_type: String) -> void:
	"""Обработка нажатия на фишку"""
	print("🖱️  ChipVisualManager: клик на фишку %s" % bet_type)
	chip_clicked.emit(bet_type)


# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _get_random_texture(bet_type: String) -> String:
	"""Получить случайную текстуру для типа ставки"""
	if not CHIP_TEXTURES.has(bet_type):
		push_error("ChipVisualManager: нет текстур для типа '%s'" % bet_type)
		return ""

	var textures = CHIP_TEXTURES[bet_type]
	var random_index = randi() % textures.size()
	return textures[random_index]


func get_current_texture(bet_type: String) -> String:
	"""Получить текущую текстуру фишки"""
	return current_textures.get(bet_type, "")


func get_visible_chips() -> Array:
	"""Получить список видимых фишек"""
	var visible_chips = []
	for bet_type in chip_nodes.keys():
		if is_chip_visible(bet_type):
			visible_chips.append(bet_type)
	return visible_chips


# ═══════════════════════════════════════════════════════════════════════════
# ИНФОРМАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func print_status() -> void:
	"""Вывести текущий статус фишек"""
	print("═══ ChipVisualManager Status ═══")
	for bet_type in chip_nodes.keys():
		var chip = chip_nodes[bet_type]
		var status = "✅ Видна" if chip.visible else "❌ Скрыта"
		var texture = current_textures.get(bet_type, "нет")
		print("  %s: %s | Текстура: %s" % [bet_type, status, texture])
	print("═══════════════════════════════")
