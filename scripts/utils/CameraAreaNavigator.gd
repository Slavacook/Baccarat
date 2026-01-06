# res://scripts/utils/CameraAreaNavigator.gd
# ═══════════════════════════════════════════════════════════════════════════
# НАВИГАТОР ОБЛАСТЕЙ КАМЕРЫ
# 
# Отвечает за:
# - Навигацию между областями (next, prev, up, down)
# - Определение целевой области по направлению
# - Предсказание целевой области по zoom_type
# ═══════════════════════════════════════════════════════════════════════════

class_name CameraAreaNavigator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

# Callbacks для вызова методов зума
var zoom_area_callback: Callable  # zoom_area(area_index, is_navigation)
var zoom_in_callback: Callable  # zoom_in(is_navigation)
var zoom_out_callback: Callable  # zoom_out(is_navigation)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	zoom_area_cb: Callable,
	zoom_in_cb: Callable,
	zoom_out_cb: Callable
) -> void:
	"""Инициализировать навигатор областей
	
	Args:
		zoom_area_cb: Callback для вызова zoom_area(area_index, is_navigation)
		zoom_in_cb: Callback для вызова zoom_in(is_navigation)
		zoom_out_cb: Callback для вызова zoom_out(is_navigation)
	"""
	zoom_area_callback = zoom_area_cb
	zoom_in_callback = zoom_in_cb
	zoom_out_callback = zoom_out_cb

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - НАВИГАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func zoom_next_area(current_area: int) -> void:
	"""Переключиться на следующую область (вправо)
	
	Использует циклическую навигацию: area_6 → area_1
	
	Args:
		current_area: Текущая область (0 = карты, 1-6 = области ставок, -1 = общий план)
	"""
	var target = get_target_area_by_direction(current_area, "right")
	if target > 0 and target != current_area:
		zoom_area_callback.call(target, false)

func zoom_prev_area(current_area: int) -> void:
	"""Переключиться на предыдущую область (влево)
	
	Использует циклическую навигацию: area_1 → area_6
	
	Args:
		current_area: Текущая область (0 = карты, 1-6 = области ставок, -1 = общий план)
	"""
	var target = get_target_area_by_direction(current_area, "left")
	if target > 0 and target != current_area:
		zoom_area_callback.call(target, false)

func zoom_up(current_area: int) -> void:
	"""Вертикальная навигация вверх
	
	Переходы:
	- С карт → area_4 (центральная область)
	- Из областей → общий план
	
	Args:
		current_area: Текущая область (0 = карты, 1-6 = области ставок, -1 = общий план)
	"""
	var target = get_target_area_by_direction(current_area, "up")
	if target > 0 and target != current_area:
		zoom_area_callback.call(target, false)
	elif target == -1:
		zoom_out_callback.call(false)

func zoom_down(current_area: int) -> void:
	"""Вертикальная навигация вниз
	
	Переходы:
	- Из областей → карты
	- С карт → общий план
	
	Args:
		current_area: Текущая область (0 = карты, 1-6 = области ставок, -1 = общий план)
	"""
	var target = get_target_area_by_direction(current_area, "down")
	if target == 0:
		zoom_in_callback.call(false)
	elif target == -1:
		zoom_out_callback.call(false)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ОПРЕДЕЛЕНИЕ НАПРАВЛЕНИЙ
# ═══════════════════════════════════════════════════════════════════════════

func get_target_area_by_direction(area: int, direction: String) -> int:
	"""Определить целевую область по направлению из указанной области
	
	Единая точка истины для всех переходов камеры.
	
	Args:
		area: Исходная область (0 = карты, 1-6 = области ставок, -1 = общий план)
		direction: "left", "right", "up", "down"
	
	Returns:
		Целевая область (1-6), 0 для карт, -1 для общего плана
	"""
	match direction:
		"left":
			match area:
				-1: return 1  # общий план → area_1 (левая область)
				0: return 1  # карты → area_1
				1: return 6  # area_1 → area_6 (циклически)
				2: return 1  # area_2 → area_1
				3: return 2  # area_3 → area_2
				4: return 3  # area_4 → area_3
				5: return 4  # area_5 → area_4
				6: return 5  # area_6 → area_5
		"right":
			match area:
				-1: return 6  # общий план → area_6 (правая область)
				0: return 6  # карты → area_6
				1: return 2  # area_1 → area_2
				2: return 3  # area_2 → area_3
				3: return 4  # area_3 → area_4
				4: return 5  # area_4 → area_5
				5: return 6  # area_5 → area_6
				6: return 1  # area_6 → area_1 (циклически)
		"up":
			match area:
				-1: return 4  # общий план → area_4 (центральная область)
				0: return 4  # карты → area_4 (центральная)
				1, 2, 3, 4, 5, 6: return -1  # из областей → общий план
		"down":
			match area:
				-1: return 0  # общий план → карты
				0: return -1  # карты → общий план
				1, 2, 3, 4, 5, 6: return 0  # из областей → карты
		_:
			return 0
	return 0

func predict_target_area(zoom_type: String, current_area: int) -> int:
	"""Предсказать целевую область (1-6) по zoom_type, 0 — если карты/общий план
	
	Использует get_target_area_by_direction() для единообразия логики.
	Публичный метод для GameController (используется для подсветки областей).
	
	Args:
		zoom_type: Тип зума (например, "area_1", "next_area", "up", и т.д.)
		current_area: Текущая область (0 = карты, 1-6 = области ставок, -1 = общий план)
		
	Returns:
		Целевая область (1-6), 0 для карт/общего плана, -1 для общего плана
	"""
	match zoom_type:
		"area_1":
			return 1
		"area_2":
			return 2
		"area_3":
			return 3
		"area_4":
			return 4
		"area_5":
			return 5
		"area_6":
			return 6
		"next_area":
			return get_target_area_by_direction(current_area, "right")
		"prev_area":
			return get_target_area_by_direction(current_area, "left")
		"up":
			return get_target_area_by_direction(current_area, "up")
		"down":
			return get_target_area_by_direction(current_area, "down")
		"in", "cards":
			return 0  # карты
		"out":
			return -1  # общий план
		"guest_1_mode2", "guest_2_mode2", "guest_3_mode2", "guest_4_mode2", "guest_5_mode2", "guest_6_mode2":
			return -1  # режимы 2 (обрабатываются как общий план для навигации)
		_:
			return 0

