# res://resources/CameraConfig.gd
# Конфигурация камеры - настройки позиции и масштаба для всех режимов
# МОЖНО РЕДАКТИРОВАТЬ НАПРЯМУЮ В ЭТОМ ФАЙЛЕ!

extends Resource
class_name CameraConfig

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 1: ОБЩИЙ ПЛАН (General View)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ОБЩЕГО ПЛАНА
var general_position: Vector2 = Vector2(570, 400)
# Масштаб камеры для общего плана
var general_zoom: Vector2 = Vector2(0.4, 0.4)
var general_description: String = "Показывает весь стол"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 2: ЗУМ НА КАРТЫ (Cards View)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ЗУМА НА КАРТЫ
var cards_position: Vector2 = Vector2(595, 400)
# Масштаб камеры для зума на карты
var cards_zoom: Vector2 = Vector2(1.2, 1.2)
var cards_description: String = "Фокус на зоне раздачи карт"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 3: ОБЛАСТЬ 1 - ЛЕВАЯ (Area 1 - Left)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ОБЛАСТИ 1 (левая часть стола)
var area_1_position: Vector2 = Vector2(-300, 220)
# Масштаб камеры для области 1
var area_1_zoom: Vector2 = Vector2(1.0, 1.0)
var area_1_description: String = "Левая область ставок"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 4: ОБЛАСТЬ 2 - ЦЕНТРАЛЬНАЯ (Area 2 - Center)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ОБЛАСТИ 2 (центр стола)
var area_2_position: Vector2 = Vector2(570, 120)
# Масштаб камеры для области 2
var area_2_zoom: Vector2 = Vector2(1.0, 1.0)
var area_2_description: String = "Центральная область ставок"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 5: ОБЛАСТЬ 3 - ПРАВАЯ (Area 3 - Right)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ОБЛАСТИ 3 (правая часть стола)
var area_3_position: Vector2 = Vector2(1450, 220)
# Масштаб камеры для области 3
var area_3_zoom: Vector2 = Vector2(1.0, 1.0)
var area_3_description: String = "Правая область ставок"

# ═══════════════════════════════════════════════════════════════════════════
# ОБЩИЕ НАСТРОЙКИ
# ═══════════════════════════════════════════════════════════════════════════

# Длительность плавного перехода камеры (секунды)
var transition_duration: float = 0.5
# Тип анимации: "linear", "cubic", "elastic", "back", "bounce"
var transition_type: String = "cubic"

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ДЛЯ УДОБНОГО ДОСТУПА
# ═══════════════════════════════════════════════════════════════════════════

func get_general_settings() -> Dictionary:
	"""Получить настройки для общего плана"""
	return {
		"position": general_position,
		"zoom": general_zoom,
		"description": general_description
	}

func get_cards_settings() -> Dictionary:
	"""Получить настройки для зума на карты"""
	return {
		"position": cards_position,
		"zoom": cards_zoom,
		"description": cards_description
	}

func get_area_1_settings() -> Dictionary:
	"""Получить настройки для области 1 (левая)"""
	return {
		"position": area_1_position,
		"zoom": area_1_zoom,
		"description": area_1_description
	}

func get_area_2_settings() -> Dictionary:
	"""Получить настройки для области 2 (центр)"""
	return {
		"position": area_2_position,
		"zoom": area_2_zoom,
		"description": area_2_description
	}

func get_area_3_settings() -> Dictionary:
	"""Получить настройки для области 3 (правая)"""
	return {
		"position": area_3_position,
		"zoom": area_3_zoom,
		"description": area_3_description
	}

func get_area_settings(area_index: int) -> Dictionary:
	"""Получить настройки для области по индексу (1, 2 или 3)"""
	match area_index:
		1:
			return get_area_1_settings()
		2:
			return get_area_2_settings()
		3:
			return get_area_3_settings()
		_:
			push_error("CameraConfig: неизвестный индекс области '%d'" % area_index)
			return get_general_settings()

func get_settings_by_type(zoom_type: String) -> Dictionary:
	"""Получить настройки по типу зума"""
	match zoom_type:
		"general", "out":
			return get_general_settings()
		"cards", "in":
			return get_cards_settings()
		"area_1":
			return get_area_1_settings()
		"area_2":
			return get_area_2_settings()
		"area_3":
			return get_area_3_settings()
		_:
			push_error("CameraConfig: неизвестный тип зума '%s'" % zoom_type)
			return get_general_settings()
