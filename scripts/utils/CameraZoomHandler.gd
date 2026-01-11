# res://scripts/utils/CameraZoomHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК ЗУМА КАМЕРЫ
# 
# Отвечает за:
# - Выполнение операций зума (in, out, mode2, area)
# - Получение настроек из CameraConfig
# - Вызов анимации через callback
# ═══════════════════════════════════════════════════════════════════════════

class_name CameraZoomHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var config: CameraConfig
var animate_to_callback: Callable  # Callback для вызова _animate_to

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(camera_config: CameraConfig, animate_callback: Callable) -> void:
	"""Инициализировать обработчик зума
	
	Args:
		camera_config: Конфигурация камеры
		animate_callback: Callback для вызова _animate_to(target_pos, target_zoom, target_rotation, zoom_type, is_navigation)
	"""
	config = camera_config
	animate_to_callback = animate_callback

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func zoom_in(is_navigation: bool = false) -> void:
	"""Зум на область карт
	
	Args:
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	var settings = config.get_cards_settings()
	animate_to_callback.call(settings.position, settings.zoom, settings.get("rotation", 0.0), "in", is_navigation)

func zoom_out(is_navigation: bool = false) -> void:
	"""Возврат к общему плану
	
	Args:
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	var settings = config.get_general_settings()
	animate_to_callback.call(settings.position, settings.zoom, settings.get("rotation", 0.0), "out", is_navigation)

func zoom_guest_1_mode2(is_navigation: bool = false) -> void:
	"""Зум на гость 1 режим 2
	
	Args:
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	var settings = config.get_guest_1_mode2_settings()
	animate_to_callback.call(settings.position, settings.zoom, settings.get("rotation", 0.0), "guest_1_mode2", is_navigation)

func zoom_guest_2_mode2(is_navigation: bool = false) -> void:
	"""Зум на гость 2 режим 2
	
	Args:
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	var settings = config.get_guest_2_mode2_settings()
	animate_to_callback.call(settings.position, settings.zoom, settings.get("rotation", 0.0), "guest_2_mode2", is_navigation)

func zoom_guest_3_mode2(is_navigation: bool = false) -> void:
	"""Зум на гость 3 режим 2
	
	Args:
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	var settings = config.get_guest_3_mode2_settings()
	animate_to_callback.call(settings.position, settings.zoom, settings.get("rotation", 0.0), "guest_3_mode2", is_navigation)

func zoom_guest_4_mode2(is_navigation: bool = false) -> void:
	"""Зум на гость 4 режим 2
	
	Args:
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	var settings = config.get_guest_4_mode2_settings()
	animate_to_callback.call(settings.position, settings.zoom, settings.get("rotation", 0.0), "guest_4_mode2", is_navigation)

func zoom_guest_5_mode2(is_navigation: bool = false) -> void:
	"""Зум на гость 5 режим 2
	
	Args:
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	var settings = config.get_guest_5_mode2_settings()
	animate_to_callback.call(settings.position, settings.zoom, settings.get("rotation", 0.0), "guest_5_mode2", is_navigation)

func zoom_guest_6_mode2(is_navigation: bool = false) -> void:
	"""Зум на гость 6 режим 2
	
	Args:
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	var settings = config.get_guest_6_mode2_settings()
	animate_to_callback.call(settings.position, settings.zoom, settings.get("rotation", 0.0), "guest_6_mode2", is_navigation)

func zoom_area(area_index: int, is_navigation: bool = false) -> void:
	"""Зум на указанную область (1-3)
	
	Args:
		area_index: Индекс области (1-3)
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	if area_index < 1 or area_index > 3:
		push_error("CameraZoomHandler: неверный индекс области %d" % area_index)
		return
	var settings = config.get_area_settings(area_index)
	var rotation_value = settings.get("rotation", 0.0)
	print("📷 CameraZoomHandler: zoom_area(%d) - rotation из конфига: %.1f°" % [area_index, rotation_value])
	animate_to_callback.call(settings.position, settings.zoom, rotation_value, "area_%d" % area_index, is_navigation)

