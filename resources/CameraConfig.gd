# res://resources/CameraConfig.gd
# Конфигурация камеры - настройки позиции и масштаба для всех режимов
# МОЖНО РЕДАКТИРОВАТЬ НАПРЯМУЮ В ЭТОМ ФАЙЛЕ!

extends Resource
class_name CameraConfig

func _init() -> void:
	"""Инициализация CameraConfig (требуется для Resource в Godot 4)"""
	pass

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 1: ОБЩИЙ ПЛАН (General View)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ОБЩЕГО ПЛАНА
var general_position: Vector2 = Vector2(570, 150)
# Масштаб камеры для общего плана
var general_zoom: Vector2 = Vector2(0.35, 0.35)
# Поворот камеры для общего плана (в градусах)
var general_rotation: float = 0.0
var general_description: String = "Показывает весь стол"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 2: ЗУМ НА КАРТЫ (Cards View)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ЗУМА НА КАРТЫ
var cards_position: Vector2 = Vector2(595, 400)
# Масштаб камеры для зума на карты
var cards_zoom: Vector2 = Vector2(1.2, 1.2)
# Поворот камеры для зума на карты (в градусах)
var cards_rotation: float = 0.0
var cards_description: String = "Фокус на зоне раздачи карт"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 3: ОБЛАСТЬ 1 - ЛЕВАЯ (Area 1 - Left)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ОБЛАСТИ 1 (левая часть стола)
var area_1_position: Vector2 = Vector2(-380, 150)
# Масштаб камеры для области 1
var area_1_zoom: Vector2 = Vector2(0.8, 0.8)
# Поворот камеры для области 1 (в градусах)
var area_1_rotation: float = -8.0
var area_1_description: String = "Левая область ставок (сектора 1-2)"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 4: ОБЛАСТЬ 2 - ЦЕНТРАЛЬНАЯ (Area 2 - Center, бывшая Area 3)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ОБЛАСТИ 2 (центральная часть стола, сектора 3-4)
var area_2_position: Vector2 = Vector2(590, 30)
# Масштаб камеры для области 2
var area_2_zoom: Vector2 = Vector2(0.8, 0.8)
# Поворот камеры для области 2 (в градусах)
var area_2_rotation: float = 0.0
var area_2_description: String = "Центральная область ставок (сектора 3-4)"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 5: ОБЛАСТЬ 3 - ПРАВАЯ (Area 3 - Right, бывшая Area 6)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ОБЛАСТИ 3 (правая часть стола, сектора 5-6)
var area_3_position: Vector2 = Vector2(1600, 150)
# Масштаб камеры для области 3
var area_3_zoom: Vector2 = Vector2(0.8, 0.8)
# Поворот камеры для области 3 (в градусах)
var area_3_rotation: float = 8.0
var area_3_description: String = "Правая область ставок (сектора 5-6)"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 2 (НЕЗАВИСИМЫЙ): ГОСТЬ 1 РЕЖИМ 2
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ГОСТЬ 1 РЕЖИМ 2
var guest_1_mode2_position: Vector2 = Vector2(170, 120)
# Масштаб камеры для гость 1 режим 2
var guest_1_mode2_zoom: Vector2 = Vector2(0.45, 0.45)
# Поворот камеры для гость 1 режим 2 (в градусах)
var guest_1_mode2_rotation: float = 0.0
var guest_1_mode2_description: String = "Гость 1 режим 2"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 2 (НЕЗАВИСИМЫЙ): ГОСТЬ 2 РЕЖИМ 2
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ГОСТЬ 2 РЕЖИМ 2
var guest_2_mode2_position: Vector2 = Vector2(330, 120)
# Масштаб камеры для гость 2 режим 2
var guest_2_mode2_zoom: Vector2 = Vector2(0.45, 0.45)
# Поворот камеры для гость 2 режим 2 (в градусах)
var guest_2_mode2_rotation: float = 0.0
var guest_2_mode2_description: String = "Гость 2 режим 2"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 2 (НЕЗАВИСИМЫЙ): ГОСТЬ 3 РЕЖИМ 2
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ГОСТЬ 3 РЕЖИМ 2
var guest_3_mode2_position: Vector2 = Vector2(490, 120)
# Масштаб камеры для гость 3 режим 2
var guest_3_mode2_zoom: Vector2 = Vector2(0.45, 0.45)
# Поворот камеры для гость 3 режим 2 (в градусах)
var guest_3_mode2_rotation: float = 0.0
var guest_3_mode2_description: String = "Гость 3 режим 2"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 2 (НЕЗАВИСИМЫЙ): ГОСТЬ 4 РЕЖИМ 2
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ГОСТЬ 4 РЕЖИМ 2
var guest_4_mode2_position: Vector2 = Vector2(650, 120)
# Масштаб камеры для гость 4 режим 2
var guest_4_mode2_zoom: Vector2 = Vector2(0.45, 0.45)
# Поворот камеры для гость 4 режим 2 (в градусах)
var guest_4_mode2_rotation: float = 0.0
var guest_4_mode2_description: String = "Гость 4 режим 2"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 2 (НЕЗАВИСИМЫЙ): ГОСТЬ 5 РЕЖИМ 2
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ГОСТЬ 5 РЕЖИМ 2
var guest_5_mode2_position: Vector2 = Vector2(810, 120)
# Масштаб камеры для гость 5 режим 2
var guest_5_mode2_zoom: Vector2 = Vector2(0.45, 0.45)
# Поворот камеры для гость 5 режим 2 (в градусах)
var guest_5_mode2_rotation: float = 0.0
var guest_5_mode2_description: String = "Гость 5 режим 2"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ 2 (НЕЗАВИСИМЫЙ): ГОСТЬ 6 РЕЖИМ 2
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ГОСТЬ 6 РЕЖИМ 2
var guest_6_mode2_position: Vector2 = Vector2(970, 120)
# Масштаб камеры для гость 6 режим 2
var guest_6_mode2_zoom: Vector2 = Vector2(0.45, 0.45)
# Поворот камеры для гость 6 режим 2 (в градусах)
var guest_6_mode2_rotation: float = 0.0
var guest_6_mode2_description: String = "Гость 6 режим 2"

# ═══════════════════════════════════════════════════════════════════════════
# ПОЗИЦИИ КАМЕРЫ ДЛЯ ГОСТЕЙ (автоматический переход при приходе нового гостя)
# ═══════════════════════════════════════════════════════════════════════════

# Позиция камеры для ГОСТЬ 1
var guest_1_position: Vector2 = Vector2(-720, -180)
var guest_1_zoom: Vector2 = Vector2(0.6, 0.6)
var guest_1_rotation: float = -8.0
var guest_1_description: String = "Гость 1"

# Позиция камеры для ГОСТЬ 2
var guest_2_position: Vector2 = Vector2(-420, -480)
var guest_2_zoom: Vector2 = Vector2(0.6, 0.6)
var guest_2_rotation: float = -4.0
var guest_2_description: String = "Гость 2"

# Позиция камеры для ГОСТЬ 3
var guest_3_position: Vector2 = Vector2(150, -540)
var guest_3_zoom: Vector2 = Vector2(0.6, 0.6)
var guest_3_rotation: float = 0.0
var guest_3_description: String = "Гость 3"

# Позиция камеры для ГОСТЬ 4
var guest_4_position: Vector2 = Vector2(900, -540)
var guest_4_zoom: Vector2 = Vector2(0.6, 0.6)
var guest_4_rotation: float = 0.0
var guest_4_description: String = "Гость 4"

# Позиция камеры для ГОСТЬ 5
var guest_5_position: Vector2 = Vector2(1600, -480)
var guest_5_zoom: Vector2 = Vector2(0.6, 0.6)
var guest_5_rotation: float = 0.4
var guest_5_description: String = "Гость 5"

# Позиция камеры для ГОСТЬ 6
var guest_6_position: Vector2 = Vector2(2000, -180)
var guest_6_zoom: Vector2 = Vector2(0.6, 0.6)
var guest_6_rotation: float = 8.0
var guest_6_description: String = "Гость 6"

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ АНИМАЦИИ КАМЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ОБЩИЕ НАСТРОЙКИ АНИМАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

# Использовать экспоненциальное сглаживание с адаптивной скоростью
# Чем дальше камера от цели, тем быстрее движение
# Чем ближе к цели, тем медленнее движение
var use_adaptive_interpolation: bool = true

# Использовать встроенное сглаживание Camera2D вместо Tween
# Встроенное сглаживание не поддерживает плавный старт/финиш (ease in/out)
# Для плавного старта и финиша используйте Tween (use_camera_smoothing = false)
var use_camera_smoothing: bool = false

# Длительность плавного перехода камеры (секунды)
# Используется только для Tween анимаций (если use_camera_smoothing = false)
var transition_duration: float = 2.2

# Скорость встроенного сглаживания камеры (единиц в секунду)
# Используется только если use_camera_smoothing = true
var position_smoothing_speed: float = 8.0
var rotation_smoothing_speed: float = 3.0

# ═══════════════════════════════════════════════════════════════════════════
# 🔵 БЫСТРАЯ АНИМАЦИЯ (обычные переходы)
# ═══════════════════════════════════════════════════════════════════════════
# 
# Используется для ВСЕХ переходов, КРОМЕ переходов между режимами 2
# 
# Примеры переходов с быстрой анимацией:
#   - карты → область ставок
#   - общий план → карты
#   - область → общий план
#   - любая область → другая область
#   - общий план → режим 2 (гость)
#   - режим 2 (гость) → карты
# 
# Исключение (медленная анимация):
#   - переходы МЕЖДУ режимами 2 (guest_1_mode2 ↔ guest_2_mode2 ↔ ... ↔ guest_6_mode2)
# 
# ═══════════════════════════════════════════════════════════════════════════

# Параметры экспоненциального сглаживания для БЫСТРОЙ анимации
# (используется только если use_adaptive_interpolation = true)
var min_interpolation_speed: float = 0.08  # Минимальная скорость (когда близко к цели) - чем меньше, тем медленнее
var max_interpolation_speed: float = 0.22  # Максимальная скорость (когда далеко от цели) - чем больше, тем быстрее
var distance_threshold: float = 2.0  # Расстояние для финального плавного подхода (пиксели)
var rotation_threshold: float = 0.3  # Порог для поворота (градусы)

# ═══════════════════════════════════════════════════════════════════════════
# 🟢 МЕДЛЕННАЯ АНИМАЦИЯ (навигация между режимами 2)
# ═══════════════════════════════════════════════════════════════════════════
# 
# Используется ТОЛЬКО при переходах между режимами 2 (гости 1-6)
# 
# Режимы 2 (все используют медленную анимацию):
#   - guest_1_mode2 (Гость 1 режим 2)
#   - guest_2_mode2 (Гость 2 режим 2)
#   - guest_3_mode2 (Гость 3 режим 2)
#   - guest_4_mode2 (Гость 4 режим 2)
#   - guest_5_mode2 (Гость 5 режим 2)
#   - guest_6_mode2 (Гость 6 режим 2)
# 
# Примеры переходов с медленной анимацией:
#   - guest_1_mode2 → guest_2_mode2
#   - guest_2_mode2 → guest_3_mode2
#   - guest_6_mode2 → guest_1_mode2 (циклически)
#   - любые переходы между guest_X_mode2
# 
# ═══════════════════════════════════════════════════════════════════════════

# Параметры экспоненциального сглаживания для МЕДЛЕННОЙ анимации
# (используется только если use_adaptive_interpolation = true)
# Эти значения значительно меньше, чем для быстрой анимации
var navigation_min_interpolation_speed: float = 0.003  # Минимальная скорость (очень медленно)
var navigation_max_interpolation_speed: float = 0.04  # Максимальная скорость (медленно)
var navigation_distance_threshold: float = 2.5  # Порог расстояния (более строгий)
var navigation_rotation_threshold: float = 0.3  # Порог поворота (более строгий)

# Тип кривой анимации (TRANS):
# "linear" - линейная (равномерная скорость)
# "sine" - синусоидальная (очень плавная)
# "quad" - квадратичная (плавная)
# "cubic" - кубическая (более плавная)
# "quart" - 4-я степень (очень плавная)
# "quint" - 5-я степень (максимально плавная)
# "expo" - экспоненциальная (резкое начало/конец)
# "circ" - круговая (очень плавная)
# "back" - с отскоком назад
# "elastic" - упругая
# "bounce" - с подпрыгиванием
var transition_type: String = "quart"

# Тип плавности (EASE):
# "in" - плавное начало, быстрое завершение
# "out" - быстрое начало, плавное завершение
# "in_out" - плавное начало и завершение (симметрично) - рекомендуется для плавного старта и финиша
# "out_in" - быстрое начало и завершение, плавная середина
var ease_type: String = "in_out"

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ДЛЯ УДОБНОГО ДОСТУПА
# ═══════════════════════════════════════════════════════════════════════════

func get_general_settings() -> Dictionary:
	"""Получить настройки для общего плана"""
	return {
		"position": general_position,
		"zoom": general_zoom,
		"rotation": general_rotation,
		"description": general_description
	}

func get_cards_settings() -> Dictionary:
	"""Получить настройки для зума на карты"""
	return {
		"position": cards_position,
		"zoom": cards_zoom,
		"rotation": cards_rotation,
		"description": cards_description
	}

func get_area_1_settings() -> Dictionary:
	"""Получить настройки для области 1 (левая)"""
	return {
		"position": area_1_position,
		"zoom": area_1_zoom,
		"rotation": area_1_rotation,
		"description": area_1_description
	}

func get_area_2_settings() -> Dictionary:
	"""Получить настройки для области 2 (центральная, бывшая Area 3)"""
	return {
		"position": area_2_position,
		"zoom": area_2_zoom,
		"rotation": area_2_rotation,
		"description": area_2_description
	}

func get_area_3_settings() -> Dictionary:
	"""Получить настройки для области 3 (правая, бывшая Area 6)"""
	return {
		"position": area_3_position,
		"zoom": area_3_zoom,
		"rotation": area_3_rotation,
		"description": area_3_description
	}

func get_guest_1_mode2_settings() -> Dictionary:
	"""Получить настройки для гость 1 режим 2"""
	return {
		"position": guest_1_mode2_position,
		"zoom": guest_1_mode2_zoom,
		"rotation": guest_1_mode2_rotation,
		"description": guest_1_mode2_description
	}

func get_guest_2_mode2_settings() -> Dictionary:
	"""Получить настройки для гость 2 режим 2"""
	return {
		"position": guest_2_mode2_position,
		"zoom": guest_2_mode2_zoom,
		"rotation": guest_2_mode2_rotation,
		"description": guest_2_mode2_description
	}

func get_guest_3_mode2_settings() -> Dictionary:
	"""Получить настройки для гость 3 режим 2"""
	return {
		"position": guest_3_mode2_position,
		"zoom": guest_3_mode2_zoom,
		"rotation": guest_3_mode2_rotation,
		"description": guest_3_mode2_description
	}

func get_guest_4_mode2_settings() -> Dictionary:
	"""Получить настройки для гость 4 режим 2"""
	return {
		"position": guest_4_mode2_position,
		"zoom": guest_4_mode2_zoom,
		"rotation": guest_4_mode2_rotation,
		"description": guest_4_mode2_description
	}

func get_guest_5_mode2_settings() -> Dictionary:
	"""Получить настройки для гость 5 режим 2"""
	return {
		"position": guest_5_mode2_position,
		"zoom": guest_5_mode2_zoom,
		"rotation": guest_5_mode2_rotation,
		"description": guest_5_mode2_description
	}

func get_guest_6_mode2_settings() -> Dictionary:
	"""Получить настройки для гость 6 режим 2"""
	return {
		"position": guest_6_mode2_position,
		"zoom": guest_6_mode2_zoom,
		"rotation": guest_6_mode2_rotation,
		"description": guest_6_mode2_description
	}

func get_guest_1_settings() -> Dictionary:
	"""Получить настройки для гость 1"""
	return {
		"position": guest_1_position,
		"zoom": guest_1_zoom,
		"rotation": guest_1_rotation,
		"description": guest_1_description
	}

func get_guest_2_settings() -> Dictionary:
	"""Получить настройки для гость 2"""
	return {
		"position": guest_2_position,
		"zoom": guest_2_zoom,
		"rotation": guest_2_rotation,
		"description": guest_2_description
	}

func get_guest_3_settings() -> Dictionary:
	"""Получить настройки для гость 3"""
	return {
		"position": guest_3_position,
		"zoom": guest_3_zoom,
		"rotation": guest_3_rotation,
		"description": guest_3_description
	}

func get_guest_4_settings() -> Dictionary:
	"""Получить настройки для гость 4"""
	return {
		"position": guest_4_position,
		"zoom": guest_4_zoom,
		"rotation": guest_4_rotation,
		"description": guest_4_description
	}

func get_guest_5_settings() -> Dictionary:
	"""Получить настройки для гость 5"""
	return {
		"position": guest_5_position,
		"zoom": guest_5_zoom,
		"rotation": guest_5_rotation,
		"description": guest_5_description
	}

func get_guest_6_settings() -> Dictionary:
	"""Получить настройки для гость 6"""
	return {
		"position": guest_6_position,
		"zoom": guest_6_zoom,
		"rotation": guest_6_rotation,
		"description": guest_6_description
	}

func get_area_settings(area_index: int) -> Dictionary:
	"""Получить настройки для области по индексу (1-3)"""
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
		"guest_1_mode2":
			return get_guest_1_mode2_settings()
		"guest_2_mode2":
			return get_guest_2_mode2_settings()
		"guest_3_mode2":
			return get_guest_3_mode2_settings()
		"guest_4_mode2":
			return get_guest_4_mode2_settings()
		"guest_5_mode2":
			return get_guest_5_mode2_settings()
		"guest_6_mode2":
			return get_guest_6_mode2_settings()
		"guest_1":
			return get_guest_1_settings()
		"guest_2":
			return get_guest_2_settings()
		"guest_3":
			return get_guest_3_settings()
		"guest_4":
			return get_guest_4_settings()
		"guest_5":
			return get_guest_5_settings()
		"guest_6":
			return get_guest_6_settings()
		_:
			push_error("CameraConfig: неизвестный тип зума '%s'" % zoom_type)
			return get_general_settings()
