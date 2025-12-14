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
# КОНСТАНТЫ - АЛЬТЕРНАТИВНЫЕ ПОЗИЦИИ ФИШЕК
# Позиции определены относительно игрового поля
# Каждая ставка имеет несколько возможных позиций
# ═══════════════════════════════════════════════════════════════════════════

const ALTERNATIVE_POSITIONS = {
	"Player": [
		Vector2(995, -35),    # Основная позиция (из сцены)✅
		Vector2(700, -38),    # Альтернатива 2✅
		Vector2(1520, 25),     # Альтернатива 1✅
		Vector2(1250, -38),     # Альтернатива 1✅
		Vector2(480, -38),    # Альтернатива 2✅
		Vector2(200, -38),    # Альтернатива 2✅
		Vector2(-150, -35),    # Альтернатива 3✅
		Vector2(-450, 35),    # Альтернатива 3✅
		Vector2(-670, 200),    # Альтернатива 4✅
		Vector2(-800, 380),    # Альтернатива 4✅
		Vector2(1790, 215),    # Альтернатива 5 ✅
		Vector2(1860, 385),    # Альтернатива 6 ✅
	],
	"Banker": [
		Vector2(954, 47),     # Основная позиция (из сцены)✅
		Vector2(654, 47),
		Vector2(-510, 180),     # Альтернатива 1✅
		Vector2(-670, 360),     # Альтернатива 1✅
		Vector2(-20, 45),    # Альтернатива 2✅
		Vector2(-320, 75),    # Альтернатива 2✅
		Vector2(260, 40),    # Альтернатива 3
		Vector2(450, 40),    # Альтернатива 3
		Vector2(1400, 70),    # Альтернатива 4
		Vector2(1650, 200),    # Альтернатива 5 ✅
		Vector2(1750, 350),    # Альтернатива 5 ✅
	],
	"Tie": [
		Vector2(897, 129),    # Основная позиция (из сцены)✅
		Vector2(-480, 260),     # Центр - альтернатива 1✅
		Vector2(-200, 130),    # Центр - альтернатива 2✅
		Vector2(350, 125),    # Центр - альтернатива 3✅
		Vector2(1350, 130),    # Центр - альтернатива 4✅
		Vector2(1550, 250),    # Центр - альтернатива 5✅
	],
	"PairPlayer": [
		Vector2(817, 208),    # Основная позиция (из сцены)✅
		Vector2(-390, 300),    # Альтернатива 1✅
		Vector2(80, 208),    # Альтернатива 2✅
		Vector2(480, 208),    # Альтернатива 3✅
		Vector2(1250, 208),    # Альтернатива 4✅
		Vector2(1565, 440),    # Альтернатива 5✅
	],
	"PairBanker": [
		Vector2(656, 207),    # Основная позиция (из сцены)✅
		Vector2(-480, 440),    # Альтернатива 1✅
		Vector2(-160, 208),    # Альтернатива 2✅
		Vector2(300, 208),    # Альтернатива 3✅
		Vector2(1030, 208),    # Альтернатива 4✅
		Vector2(1455, 285),    # Альтернатива 5✅
	]
}

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Словарь узлов фишек: {"Player": TextureButton, "Banker": TextureButton, ...}
var chip_nodes: Dictionary = {}

# Текущие выбранные текстуры для каждой фишки
var current_textures: Dictionary = {}

# Основные позиции фишек (сохраняются при setup из сцены)
var default_positions: Dictionary = {}

# Режим позиций: DEFAULT, RANDOM, MAX
enum PositionMode { DEFAULT, RANDOM, MAX }
var current_mode: PositionMode = PositionMode.DEFAULT

# Для обратной совместимости
var random_positions_enabled: bool:
	get:
		return current_mode == PositionMode.RANDOM

# Дополнительные фишки для MAX режима (копии)
# {"Player": [TextureButton, TextureButton, ...], ...}
var extra_chips: Dictionary = {}

# Родительский узел для добавления копий фишек
var scene_root: Node = null

# Сигналы для обработки кликов
signal chip_clicked(bet_type: String)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(player_chip: TextureButton, banker_chip: TextureButton, tie_chip: TextureButton,
		   pair_player_chip: TextureButton = null, pair_banker_chip: TextureButton = null,
		   root_node: Node = null) -> void:
	"""Настройка ссылок на узлы фишек"""
	chip_nodes["Player"] = player_chip
	chip_nodes["Banker"] = banker_chip
	chip_nodes["Tie"] = tie_chip

	if pair_player_chip:
		chip_nodes["PairPlayer"] = pair_player_chip
	if pair_banker_chip:
		chip_nodes["PairBanker"] = pair_banker_chip

	# Сохраняем родительский узел для создания копий в MAX режиме
	if root_node:
		scene_root = root_node
	elif player_chip:
		scene_root = player_chip.get_parent()

	# Сохраняем начальные позиции фишек (из сцены)
	_save_default_positions()
	
	# Инициализируем словарь для дополнительных фишек
	for bet_type in chip_nodes.keys():
		extra_chips[bet_type] = []

	# Скрываем все фишки при старте
	for chip in chip_nodes.values():
		chip.visible = false
		chip.mouse_filter = Control.MOUSE_FILTER_STOP

	print("✅ ChipVisualManager: настроено %d фишек" % chip_nodes.size())


func _save_default_positions() -> void:
	"""Сохранить начальные позиции фишек из сцены"""
	for bet_type in chip_nodes.keys():
		var chip = chip_nodes[bet_type]
		default_positions[bet_type] = Vector2(chip.position.x, chip.position.y)
	print("📍 Сохранены позиции фишек: %s" % default_positions)


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func show_chip(bet_type: String) -> void:
	"""Показать фишку с рандомной текстурой и позицией (зависит от режима)"""
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

	# Применяем позицию в зависимости от режима
	match current_mode:
		PositionMode.DEFAULT:
			_reset_to_default_position(bet_type)
			_remove_extra_chips(bet_type)
		PositionMode.RANDOM:
			_apply_random_position(bet_type)
			_remove_extra_chips(bet_type)
		PositionMode.MAX:
			_reset_to_default_position(bet_type)
			_create_extra_chips(bet_type, texture)

	print("💰 ChipVisualManager: показана фишка %s (%s) mode=%s" % [bet_type, texture_path.get_file(), PositionMode.keys()[current_mode]])


func set_chip_texture(bet_type: String, texture_path: String) -> void:
	"""Установить конкретную текстуру фишки (без рандомизации)"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	if texture_path.is_empty():
		push_warning("ChipVisualManager: пустой путь к текстуре для %s, используем рандомную" % bet_type)
		show_chip(bet_type)
		return

	var chip = chip_nodes[bet_type]
	var texture = load(texture_path)
	if not texture:
		push_error("ChipVisualManager: не удалось загрузить текстуру '%s'" % texture_path)
		return

	chip.texture_normal = texture
	chip.visible = true
	current_textures[bet_type] = texture_path

	print("💰 ChipVisualManager: установлена текстура фишки %s (%s)" % [bet_type, texture_path.get_file()])


func make_chip_visible(bet_type: String) -> void:
	"""Просто показать фишку БЕЗ изменения текстуры"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	chip_nodes[bet_type].visible = true
	print("👁️ ChipVisualManager: фишка %s сделана видимой" % bet_type)


func hide_chip(bet_type: String) -> void:
	"""Скрыть фишку и удалить копии"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	chip_nodes[bet_type].visible = false
	# НЕ стираем current_textures - сохраняем текстуру для восстановления
	
	# Удаляем дополнительные фишки (если были в MAX режиме)
	_remove_extra_chips(bet_type)

	print("🚫 ChipVisualManager: скрыта фишка %s" % bet_type)


func hide_all_chips() -> void:
	"""Скрыть все фишки и удалить все копии"""
	for bet_type in chip_nodes.keys():
		hide_chip(bet_type)
	_remove_all_extra_chips()


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
# УПРАВЛЕНИЕ ПОЗИЦИЯМИ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func set_random_mode(enabled: bool) -> void:
	"""Включить/выключить режим случайных позиций (для обратной совместимости)"""
	set_position_mode(PositionMode.RANDOM if enabled else PositionMode.DEFAULT)


func set_position_mode(mode: PositionMode) -> void:
	"""Установить режим позиций фишек"""
	var old_mode = current_mode
	current_mode = mode
	print("🎲 ChipVisualManager: режим позиций = %s" % PositionMode.keys()[mode])
	
	# Применяем изменения для всех видимых фишек
	for bet_type in chip_nodes.keys():
		if is_chip_visible(bet_type):
			match mode:
				PositionMode.DEFAULT:
					_reset_to_default_position(bet_type)
					_remove_extra_chips(bet_type)
				PositionMode.RANDOM:
					_apply_random_position(bet_type)
					_remove_extra_chips(bet_type)
				PositionMode.MAX:
					_reset_to_default_position(bet_type)
					var texture = chip_nodes[bet_type].texture_normal
					if texture:
						_create_extra_chips(bet_type, texture)


func _apply_random_position(bet_type: String) -> void:
	"""Применить случайную позицию для фишки из списка альтернатив"""
	if not chip_nodes.has(bet_type):
		return
	
	if not ALTERNATIVE_POSITIONS.has(bet_type):
		push_warning("ChipVisualManager: нет альтернативных позиций для '%s'" % bet_type)
		return
	
	var positions = ALTERNATIVE_POSITIONS[bet_type]
	var random_index = randi() % positions.size()
	var new_position = positions[random_index]
	
	chip_nodes[bet_type].position = new_position
	print("📍 Фишка %s перемещена в позицию %d: %s" % [bet_type, random_index, new_position])


func _reset_to_default_position(bet_type: String) -> void:
	"""Вернуть фишку на основную позицию"""
	if not chip_nodes.has(bet_type):
		return
	
	if not default_positions.has(bet_type):
		push_warning("ChipVisualManager: нет сохранённой позиции для '%s'" % bet_type)
		return
	
	chip_nodes[bet_type].position = default_positions[bet_type]


func reset_all_positions() -> void:
	"""Сбросить все фишки на основные позиции"""
	for bet_type in chip_nodes.keys():
		_reset_to_default_position(bet_type)
	print("📍 Все фишки возвращены на основные позиции")


func randomize_all_positions() -> void:
	"""Применить случайные позиции для всех видимых фишек"""
	for bet_type in chip_nodes.keys():
		if is_chip_visible(bet_type):
			_apply_random_position(bet_type)
	print("🎲 Все видимые фишки перемещены в случайные позиции")


func get_alternative_positions(bet_type: String) -> Array:
	"""Получить список альтернативных позиций для типа ставки"""
	if ALTERNATIVE_POSITIONS.has(bet_type):
		return ALTERNATIVE_POSITIONS[bet_type]
	return []


func is_random_mode_enabled() -> bool:
	"""Проверить, включён ли режим случайных позиций"""
	return current_mode == PositionMode.RANDOM


func get_position_mode() -> PositionMode:
	"""Получить текущий режим позиций"""
	return current_mode


# ═══════════════════════════════════════════════════════════════════════════
# MAX РЕЖИМ - СОЗДАНИЕ И УДАЛЕНИЕ КОПИЙ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func _create_extra_chips(bet_type: String, texture: Texture2D) -> void:
	"""Создать дополнительные фишки для всех альтернативных позиций (MAX режим)"""
	if not scene_root:
		push_warning("ChipVisualManager: scene_root не задан, не могу создать копии")
		return
	
	if not ALTERNATIVE_POSITIONS.has(bet_type):
		return
	
	# Сначала удаляем старые копии
	_remove_extra_chips(bet_type)
	
	var positions = ALTERNATIVE_POSITIONS[bet_type]
	var original_chip = chip_nodes[bet_type]
	
	# Создаём копии для всех позиций КРОМЕ первой (основной, где уже стоит оригинал)
	for i in range(1, positions.size()):
		var new_chip = TextureButton.new()
		new_chip.texture_normal = texture
		new_chip.position = positions[i]
		new_chip.scale = original_chip.scale
		new_chip.modulate = original_chip.modulate
		new_chip.mouse_filter = Control.MOUSE_FILTER_STOP
		new_chip.visible = true
		
		# Подключаем сигнал клика
		new_chip.pressed.connect(_on_extra_chip_pressed.bind(bet_type))
		
		scene_root.add_child(new_chip)
		extra_chips[bet_type].append(new_chip)
	
	print("📍 MAX: создано %d копий фишки %s" % [extra_chips[bet_type].size(), bet_type])


func _remove_extra_chips(bet_type: String) -> void:
	"""Удалить дополнительные фишки для типа ставки"""
	if not extra_chips.has(bet_type):
		return
	
	for chip in extra_chips[bet_type]:
		if is_instance_valid(chip):
			chip.queue_free()
	
	extra_chips[bet_type].clear()


func _remove_all_extra_chips() -> void:
	"""Удалить все дополнительные фишки"""
	for bet_type in extra_chips.keys():
		_remove_extra_chips(bet_type)
	print("📍 Все дополнительные фишки удалены")


func _on_extra_chip_pressed(bet_type: String) -> void:
	"""Обработка клика на дополнительную фишку"""
	print("🖱️  ChipVisualManager: клик на копию фишки %s" % bet_type)
	chip_clicked.emit(bet_type)


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
