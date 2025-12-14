# res://scripts/CameraManager.gd
# Менеджер камеры - управление зумом и позицией камеры
# Извлечён из GameController.gd в рамках рефакторинга (Фаза 1)

class_name CameraManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ КАМЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

# Общий план (1:1, показывает весь стол)
const ZOOM_GENERAL = Vector2(1.0, 1.0)
# Зум на карты (1.4:1, фокус на зоне раздачи)
const ZOOM_CARDS = Vector2(1.4, 1.4)
# Зум на фишки (1.9:1, фокус на зоне ставок)
const ZOOM_CHIPS = Vector2(1.8, 1.8)

# Позиция камеры для общего плана (центр окна 1154x650)
const POS_GENERAL = Vector2(577, 325)
# Позиция камеры для зума на карты (центр зоны Player/Banker)
const POS_CARDS = Vector2(595, 400)
# Позиция камеры для зума на фишки (на 200px выше общего плана)
const POS_CHIPS = Vector2(850, 115)

# Длительность плавного перехода камеры (секунды)
const TRANSITION_DURATION = 0.5

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal zoom_started(zoom_type: String)
signal zoom_completed(zoom_type: String)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var camera: Camera2D = null
var scene: Node = null  # Родительская сцена для создания tween
var is_first_deal: bool = true

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(parent_scene: Node) -> void:
	"""Создать и настроить камеру
	
	Args:
		parent_scene: Родительская сцена (Game.tscn) для добавления камеры
	"""
	scene = parent_scene
	
	# Создаём камеру
	camera = Camera2D.new()
	camera.enabled = true
	parent_scene.add_child(camera)
	
	# Начинаем с общего плана
	camera.position = POS_GENERAL
	camera.zoom = ZOOM_GENERAL
	
	# Подписываемся на EventBus
	if EventBus:
		EventBus.camera_zoom_requested.connect(_on_zoom_requested)
		EventBus.first_deal_completed.connect(_on_first_deal_completed)
	
	print("📷 CameraManager: камера создана (zoom %.1f)" % ZOOM_GENERAL.x)

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ЗУМА
# ═══════════════════════════════════════════════════════════════════════════

func zoom_in() -> void:
	"""Плавный зум на область карт"""
	_animate_to(POS_CARDS, ZOOM_CARDS, "in")

func zoom_out() -> void:
	"""Возврат к общему плану"""
	_animate_to(POS_GENERAL, ZOOM_GENERAL, "out")

func zoom_chips() -> void:
	"""Плавный зум на область фишек"""
	_animate_to(POS_CHIPS, ZOOM_CHIPS, "chips")

func zoom_cards() -> void:
	"""Плавный зум на область карт (алиас для zoom_in)"""
	zoom_in()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _animate_to(target_pos: Vector2, target_zoom: Vector2, zoom_type: String) -> void:
	"""Анимировать камеру к заданной позиции и зуму"""
	if not camera or not scene:
		return
	
	zoom_started.emit(zoom_type)
	
	var tween = scene.create_tween()
	tween.set_parallel(true)  # Позиция и зум меняются одновременно
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(camera, "position", target_pos, TRANSITION_DURATION)
	tween.tween_property(camera, "zoom", target_zoom, TRANSITION_DURATION)
	
	# Сигнал завершения после окончания анимации
	tween.finished.connect(func(): zoom_completed.emit(zoom_type))
	
	print("📷 CameraManager: %s (zoom %.1f)" % [_get_zoom_name(zoom_type), target_zoom.x])

func _get_zoom_name(zoom_type: String) -> String:
	"""Получить человекочитаемое название зума"""
	match zoom_type:
		"in", "cards":
			return "Зум на карты"
		"out":
			return "Общий план"
		"chips":
			return "Зум на фишки"
		_:
			return "Неизвестный зум"

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_zoom_requested(zoom_type: String) -> void:
	"""Обработка запроса зума через EventBus"""
	match zoom_type:
		"in":
			zoom_in()
		"out":
			zoom_out()
		"chips":
			zoom_chips()
		"cards":
			zoom_cards()
		_:
			push_error("CameraManager: неизвестный тип зума '%s'" % zoom_type)

func _on_first_deal_completed() -> void:
	"""Обработка завершения первой раздачи"""
	is_first_deal = false
	print("📷 CameraManager: первая раздача завершена")

# ═══════════════════════════════════════════════════════════════════════════
# ГЕТТЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_is_first_deal() -> bool:
	return is_first_deal

func set_is_first_deal(value: bool) -> void:
	is_first_deal = value
