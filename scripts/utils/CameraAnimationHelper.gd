# res://scripts/utils/CameraAnimationHelper.gd
# ═══════════════════════════════════════════════════════════════════════════
# ПОМОЩНИК АНИМАЦИИ КАМЕРЫ
# 
# Отвечает за:
# - Преобразование типов анимации (transition, ease)
# - Получение человекочитаемых названий зума
# ═══════════════════════════════════════════════════════════════════════════

class_name CameraAnimationHelper
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

static func get_transition_type(type_name: String) -> Tween.TransitionType:
	"""Преобразует строковое название типа анимации в Tween.TransitionType
	
	Args:
		type_name: Название типа (например, "back", "quint", "sine")
		
	Returns:
		Tween.TransitionType соответствующий названию, или TRANS_QUINT по умолчанию
	"""
	match type_name.to_lower():
		"linear":
			return Tween.TRANS_LINEAR
		"sine":
			return Tween.TRANS_SINE
		"quad":
			return Tween.TRANS_QUAD
		"cubic":
			return Tween.TRANS_CUBIC
		"quart":
			return Tween.TRANS_QUART
		"quint":
			return Tween.TRANS_QUINT
		"expo":
			return Tween.TRANS_EXPO
		"circ":
			return Tween.TRANS_CIRC
		"back":
			return Tween.TRANS_BACK
		"elastic":
			return Tween.TRANS_ELASTIC
		"bounce":
			return Tween.TRANS_BOUNCE
		_:
			return Tween.TRANS_QUINT  # По умолчанию

static func get_ease_type(type_name: String) -> Tween.EaseType:
	"""Преобразует строковое название типа плавности в Tween.EaseType
	
	Args:
		type_name: Название типа (например, "in", "out", "in_out")
		
	Returns:
		Tween.EaseType соответствующий названию, или EASE_OUT по умолчанию
	"""
	match type_name.to_lower():
		"in":
			return Tween.EASE_IN
		"out":
			return Tween.EASE_OUT
		"in_out":
			return Tween.EASE_IN_OUT
		"out_in":
			return Tween.EASE_OUT_IN
		_:
			return Tween.EASE_OUT  # По умолчанию

static func get_zoom_name(zoom_type: String) -> String:
	"""Получить человекочитаемое название зума
	
	Args:
		zoom_type: Тип зума (например, "in", "out", "area_1")
		
	Returns:
		Человекочитаемое название зума на русском языке
	"""
	match zoom_type:
		"in", "cards":
			return "Зум на карты"
		"out":
			return "Общий план"
		"area_1":
			return "Область 1"
		"area_2":
			return "Область 2"
		"area_3":
			return "Область 3"
		"area_4":
			return "Область 4"
		"area_5":
			return "Область 5"
		"area_6":
			return "Область 6"
		"up":
			return "Навигация вверх"
		"down":
			return "Навигация вниз"
		_:
			return "Неизвестный зум"

