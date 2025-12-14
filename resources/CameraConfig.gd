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
var cards_zoom: Vector2 = Vector2(1.4, 1.4)
var cards_description: String = "Фокус на зоне раздачи карт"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 3: ЗУМ НА ФИШКИ (Chips View)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ЗУМА НА ФИШКИ
var chips_position: Vector2 = Vector2(850, 115)
# Масштаб камеры для зума на фишки
var chips_zoom: Vector2 = Vector2(1.8, 1.8)
var chips_description: String = "Фокус на зоне ставок (фишки)"

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

func get_chips_settings() -> Dictionary:
	"""Получить настройки для зума на фишки"""
	return {
		"position": chips_position,
		"zoom": chips_zoom,
		"description": chips_description
	}

func get_settings_by_type(zoom_type: String) -> Dictionary:
	"""Получить настройки по типу зума"""
	match zoom_type:
		"general", "out":
			return get_general_settings()
		"cards", "in":
			return get_cards_settings()
		"chips":
			return get_chips_settings()
		_:
			push_error("CameraConfig: неизвестный тип зума '%s'" % zoom_type)
			return get_general_settings()
