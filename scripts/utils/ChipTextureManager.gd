# res://scripts/utils/ChipTextureManager.gd
# Менеджер текстур фишек
# 
# Отвечает за:
# - Управление текстурами фишек (CHIP_TEXTURES)
# - Получение случайных текстур
# - Хранение текущих текстур

class_name ChipTextureManager

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
# СОСТОЯНИЕ
# ═══════════════════════════════════════════════════════════════════════════

# Текущие текстуры для каждого типа ставки
var current_textures: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_random_texture(bet_type: String) -> String:
	"""Получить случайную текстуру для типа ставки
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		
	Returns:
		Путь к случайной текстуре или пустая строка если текстуры не найдены
	"""
	if not CHIP_TEXTURES.has(bet_type):
		push_error("ChipTextureManager: нет текстур для типа '%s'" % bet_type)
		return ""
	
	var textures = CHIP_TEXTURES[bet_type]
	if textures.is_empty():
		push_error("ChipTextureManager: пустой массив текстур для типа '%s'" % bet_type)
		return ""
	
	var random_index = randi() % textures.size()
	return textures[random_index]

func get_current_texture(bet_type: String) -> String:
	"""Получить текущую текстуру фишки
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		Путь к текущей текстуре или пустая строка если текстура не установлена
	"""
	return current_textures.get(bet_type, "")

func set_current_texture(bet_type: String, texture_path: String) -> void:
	"""Установить текущую текстуру фишки (без применения к узлу)
	
	Сохраняет путь к текстуре, но не применяет её к узлу фишки.
	
	Args:
		bet_type: Тип ставки
		texture_path: Путь к текстуре
	"""
	current_textures[bet_type] = texture_path

func clear_current_texture(bet_type: String) -> void:
	"""Очистить текущую текстуру для типа ставки
	
	Args:
		bet_type: Тип ставки
	"""
	current_textures.erase(bet_type)

func clear_all_textures() -> void:
	"""Очистить все текущие текстуры"""
	current_textures.clear()

func has_textures(bet_type: String) -> bool:
	"""Проверить, есть ли текстуры для типа ставки
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		true если текстуры есть, false иначе
	"""
	return CHIP_TEXTURES.has(bet_type) and not CHIP_TEXTURES[bet_type].is_empty()
