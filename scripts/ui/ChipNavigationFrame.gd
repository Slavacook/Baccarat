# res://scripts/ui/ChipNavigationFrame.gd
# Визуальная рамка для выделения выбранной фишки при навигации
# Использует PNG-картинки с независимыми координатами и размерами

extends TextureRect
class_name ChipNavigationFrame

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Настройки текстур для каждой комбинации bet_type + sector
# Каждая текстура имеет свой путь, позицию и масштаб (независимо от позиции фишек)
const FRAME_TEXTURES = {
	"Player": {
		1: {
			"texture": "res://assets/ui/navigation_frames/sector_1/Player_sector_1.png",
			"position": Vector2(-987, 2),
			"scale": 1.75
		},
		2: {
			"texture": "res://assets/ui/navigation_frames/sector_2/Player_sector_2.png",
			"position": Vector2(-608, -125),
			"scale": 1.75
		},
		3: {
			"texture": "res://assets/ui/navigation_frames/sector_3/Player_sector_3.png",
			"position": Vector2(-18, -132),
			"scale": 1.75
		},
		4: {
			"texture": "res://assets/ui/navigation_frames/sector_4/Player_sector_4.png",
			"position": Vector2(501, -108),
			"scale": 1.75
		},
		5: {
			"texture": "res://assets/ui/navigation_frames/sector_5/Player_sector_5.png",
			"position": Vector2(1014, -126),
			"scale": 1.75
		},
		6: {
			"texture": "res://assets/ui/navigation_frames/sector_6/Player_sector_6.png",
			"position": Vector2(1588, 45),
			"scale": 1.75
		},
	},
	"Banker": {
		1: {
			"texture": "res://assets/ui/navigation_frames/sector_1/Banker_sector_1.png",
			"position": Vector2(-805, 90),
			"scale": 1.75
		},
		2: {
			"texture": "res://assets/ui/navigation_frames/sector_2/Banker_sector_2.png",
			"position": Vector2(-526, -56),
			"scale": 1.75
		},
		3: {
			"texture": "res://assets/ui/navigation_frames/sector_3/Banker_sector_3.png",
			"position": Vector2(25, -28),
			"scale": 1.75
		},
		4: {
			"texture": "res://assets/ui/navigation_frames/sector_4/Banker_sector_4.png",
			"position": Vector2(523, -23),
			"scale": 1.75
		},
		5: {
			"texture": "res://assets/ui/navigation_frames/sector_5/Banker_sector_5.png",
			"position": Vector2(970, -45),
			"scale": 1.75
		},
		6: {
			"texture": "res://assets/ui/navigation_frames/sector_6/Banker_sector_6.png",
			"position": Vector2(1475, 83),
			"scale": 1.75
		},
	},
	"Tie": {
		1: {
			"texture": "res://assets/ui/navigation_frames/sector_1/Tie_sector_1.png",
			"position": Vector2(-690, 123),
			"scale": 1.75
		},
		2: {
			"texture": "res://assets/ui/navigation_frames/sector_2/Tie_sector_2.png",
			"position": Vector2(-428, 38),
			"scale": 1.75
		},
		3: {
			"texture": "res://assets/ui/navigation_frames/sector_3/Tie_sector_3.png",
			"position": Vector2(91, 50),
			"scale": 1.75
		},
		4: {
			"texture": "res://assets/ui/navigation_frames/sector_4/Tie_sector_4.png",
			"position": Vector2(524, 40),
			"scale": 1.75
		},
		5: {
			"texture": "res://assets/ui/navigation_frames/sector_5/Tie_sector_5.png",
			"position": Vector2(907, 30),
			"scale": 1.75
		},
		6: {
			"texture": "res://assets/ui/navigation_frames/sector_6/Tie_sector_6.png",
			"position": Vector2(1410, 126),
			"scale": 1.75
		},
	},
	"PairPlayer": {
		1: {
			"texture": "res://assets/ui/navigation_frames/sector_1/PairPlayer_sector_1.png",
			"position": Vector2(-527, 147),
			"scale": 1.75
		},
		2: {
			"texture": "res://assets/ui/navigation_frames/sector_2/PairPlayer_sector_2.png",
			"position": Vector2(-135, 112),
			"scale": 1.75
		},
		3: {
			"texture": "res://assets/ui/navigation_frames/sector_3/PairPlayer_sector_3.png",
			"position": Vector2(344,133),
			"scale": 1.75
		},
		4: {
			"texture": "res://assets/ui/navigation_frames/sector_4/PairPlayer_sector_4.png",
			"position": Vector2(680, 116),
			"scale": 1.75
		},
		5: {
			"texture": "res://assets/ui/navigation_frames/sector_5/PairPlayer_sector_5.png",
			"position": Vector2(1043, 127),
			"scale": 1.75
		},
		6: {
			"texture": "res://assets/ui/navigation_frames/sector_6/PairPlayer_sector_6.png",
			"position": Vector2(1440, 300),
			"scale": 1.75
		},
	},
	"PairBanker": {
		1: {
			"texture": "res://assets/ui/navigation_frames/sector_1/PairBanker_sector_1.png",
			"position": Vector2(-634, 280),
			"scale": 1.75
		},
		2: {
			"texture": "res://assets/ui/navigation_frames/sector_2/PairBanker_sector_2.png",
			"position": Vector2(-363, 81),
			"scale": 1.75
		},
		3: {
			"texture": "res://assets/ui/navigation_frames/sector_3/PairBanker_sector_3.png",
			"position": Vector2(146,121),
			"scale": 1.75
		},
		4: {
			"texture": "res://assets/ui/navigation_frames/sector_4/PairBanker_sector_4.png",
			"position": Vector2(512, 128),
			"scale": 1.75
		},
		5: {
			"texture": "res://assets/ui/navigation_frames/sector_5/PairBanker_sector_5.png",
			"position": Vector2(820, 107),
			"scale": 1.75
		},
		6: {
			"texture": "res://assets/ui/navigation_frames/sector_6/PairBanker_sector_6.png",
			"position": Vector2(1295, 156),
			"scale": 1.75
		},
	},
}

# Прозрачность рамки (для видимости фишки под ней)
const FRAME_ALPHA: float = 0.7  # 70% непрозрачности

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var current_bet_type: String = ""
var current_sector: int = -1

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Инициализация рамки"""
	# Настройка TextureRect для работы с заданным размером
	# STRETCH_KEEP_ASPECT_CENTERED - масштабирует текстуру с сохранением пропорций,
	# центрирует в заданном размере (может оставить пустые области, но не обрезает)
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Изначально скрыта
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Базовые настройки
	z_index = 1000
	z_as_relative = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	modulate = Color(1.0, 1.0, 1.0, FRAME_ALPHA)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func show_at_position(_coords: Vector2, bet_type: String, sector: int = -1) -> void:
	"""Показать рамку с PNG-текстурой на независимых координатах
	
	Args:
		_coords: Координаты позиции (игнорируются, используются координаты из FRAME_TEXTURES)
		bet_type: Тип ставки ("Player", "Banker", etc.)
		sector: Номер сектора (1-6)
	"""
	current_bet_type = bet_type
	if sector >= 1 and sector <= 6:
		current_sector = sector
	else:
		current_sector = 1
	
	var config = _get_frame_config(bet_type, current_sector)
	if config.is_empty():
		visible = false
		return
	
	# Устанавливаем текстуру, позицию и размер
	texture = config.texture
	_apply_position(config.position)
	size = config.size
	visible = true
	
	DebugLogger.log("📦 ChipNavigationFrame: показана (bet_type=%s, sector=%d, position=%s, size=%s, scale=%.2f)" % [
		bet_type, current_sector, str(config.position), str(config.size), config.scale
	])

func show_at_chip(chip: ChipVisualManager.ChipInstance) -> void:
	"""Показать рамку у указанной фишки (для обратной совместимости)"""
	if not chip or not chip.node or not is_instance_valid(chip.node):
		hide_frame()
		return
	
	# Пытаемся использовать конфигурацию для этого типа ставки
	current_bet_type = chip.bet_type
	current_sector = 1  # Fallback
	
	var config = _get_frame_config(chip.bet_type, current_sector)
	if not config.is_empty():
		# Используем конфигурацию
		texture = config.texture
		_apply_position(config.position)
		size = config.size
		visible = true
	else:
		# Fallback: используем позицию фишки
		texture = null
		var chip_node = chip.node
		if get_parent() is CanvasLayer:
			_apply_position(chip_node.global_position)
		else:
			_apply_position(chip_node.position)
		size = chip_node.size
		visible = true

func hide_frame() -> void:
	"""Скрыть рамку"""
	visible = false
	texture = null

func update_position() -> void:
	"""Обновить позицию рамки (вызывается при изменении фокуса)"""
	if current_bet_type == "" or current_sector <= 0:
		return
	
	var config = _get_frame_config(current_bet_type, current_sector)
	if not config.is_empty():
		_apply_position(config.position)
		size = config.size

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _apply_position(pos: Vector2) -> void:
	"""Установить позицию рамки с учетом типа родителя
	
	Args:
		pos: Позиция (глобальная для CanvasLayer, локальная для обычного родителя)
	"""
	if get_parent() is CanvasLayer:
		global_position = pos
	else:
		position = pos

func _get_frame_config(bet_type: String, sector: int) -> Dictionary:
	"""Получить конфигурацию для указанного типа ставки и сектора
	
	Returns:
		Dictionary с ключами: "texture" (Texture2D), "position" (Vector2), "size" (Vector2), "scale" (float)
		или пустой Dictionary если конфигурация не найдена
	"""
	if not FRAME_TEXTURES.has(bet_type):
		return {}
	
	var bet_textures = FRAME_TEXTURES[bet_type]
	if not bet_textures.has(sector):
		return {}
	
	var config = bet_textures[sector]
	if not config is Dictionary:
		return {}
	
	var texture_path = config.get("texture", "")
	var frame_position = config.get("position", Vector2.ZERO)
	var frame_scale = config.get("scale", 1.0)
	
	if texture_path.is_empty():
		return {}
	
	var loaded_texture = load(texture_path)
	if not loaded_texture:
		DebugLogger.log_error("❌ ChipNavigationFrame: не удалось загрузить текстуру: %s" % texture_path)
		return {}
	
	# Вычисляем размер на основе оригинального размера текстуры и масштаба
	var original_size = loaded_texture.get_size()
	var final_size = original_size * frame_scale
	
	return {
		"texture": loaded_texture,
		"position": frame_position,
		"size": final_size,
		"scale": frame_scale
	}
