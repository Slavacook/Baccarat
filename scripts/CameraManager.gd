# res://scripts/CameraManager.gd
# Менеджер камеры - управление зумом и позицией камеры
# Извлечён из GameController.gd в рамках рефакторинга (Фаза 1)
# Использует CameraConfig для настройки позиций и масштаба

class_name CameraManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ КАМЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

# Путь к файлу конфигурации (можно изменить в коде)
# Используем .gd файл вместо .tres для удобного редактирования
var config_path: String = "res://resources/CameraConfig.gd"
var config: CameraConfig = null

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
var current_area: int = 0  # Текущая активная область (0 = нет, 1-3 = область)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(parent_scene: Node, camera_config_path: String = "") -> void:
	"""Создать и настроить камеру
	
	Args:
		parent_scene: Родительская сцена (Game.tscn) для добавления камеры
		camera_config_path: Путь к файлу конфигурации (опционально)
	"""
	scene = parent_scene
	
	# Загружаем конфигурацию камеры
	if camera_config_path != "":
		config_path = camera_config_path
	
	# Загружаем класс и создаём экземпляр
	var config_script = load(config_path) as GDScript
	if config_script:
		config = config_script.new() as CameraConfig
	else:
		push_error("❌ CameraManager: не удалось загрузить конфигурацию из %s. Используются значения по умолчанию." % config_path)
		# Создаём конфигурацию по умолчанию
		config = CameraConfig.new()
	
	# Создаём камеру
	camera = Camera2D.new()
	camera.enabled = true
	parent_scene.add_child(camera)
	
	# Начинаем с общего плана (из конфигурации)
	var general_settings = config.get_general_settings()
	camera.position = general_settings.position
	camera.zoom = general_settings.zoom
	
	# Подписываемся на EventBus
	if EventBus:
		EventBus.camera_zoom_requested.connect(_on_zoom_requested)
		EventBus.first_deal_completed.connect(_on_first_deal_completed)
	
	print("📷 CameraManager: камера создана (zoom %.1f, конфиг: %s)" % [general_settings.zoom.x, config_path])

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ЗУМА
# ═══════════════════════════════════════════════════════════════════════════

func zoom_in() -> void:
	"""Плавный зум на область карт"""
	current_area = 0
	var settings = config.get_cards_settings()
	_animate_to(settings.position, settings.zoom, "in")

func zoom_out() -> void:
	"""Возврат к общему плану"""
	current_area = 0
	var settings = config.get_general_settings()
	_animate_to(settings.position, settings.zoom, "out")

func zoom_cards() -> void:
	"""Плавный зум на область карт (алиас для zoom_in)"""
	zoom_in()

func zoom_area(area_index: int) -> void:
	"""Плавный зум на указанную область (1, 2 или 3)"""
	if area_index < 1 or area_index > 3:
		push_error("CameraManager: неверный индекс области %d" % area_index)
		return
	current_area = area_index
	var settings = config.get_area_settings(area_index)
	_animate_to(settings.position, settings.zoom, "area_%d" % area_index)

func zoom_next_area() -> void:
	"""Переключиться на следующую область (вправо)"""
	if current_area == 0:
		zoom_area(1)
	elif current_area < 3:
		zoom_area(current_area + 1)
	# Если current_area == 3, остаемся на месте

func zoom_prev_area() -> void:
	"""Переключиться на предыдущую область (влево)"""
	if current_area == 0:
		zoom_area(3)
	elif current_area > 1:
		zoom_area(current_area - 1)
	# Если current_area == 1, остаемся на месте

func get_current_area() -> int:
	"""Получить текущую активную область (0 = нет, 1-3 = область)"""
	return current_area

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _animate_to(target_pos: Vector2, target_zoom: Vector2, zoom_type: String) -> void:
	"""Анимировать камеру к заданной позиции и зуму"""
	if not camera or not scene or not config:
		return
	
	zoom_started.emit(zoom_type)
	
	var tween = scene.create_tween()
	tween.set_parallel(true)  # Позиция и зум меняются одновременно
	
	# Используем тип анимации из конфигурации
	var transition_type = _get_transition_type(config.transition_type)
	tween.set_trans(transition_type)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Используем длительность из конфигурации
	tween.tween_property(camera, "position", target_pos, config.transition_duration)
	tween.tween_property(camera, "zoom", target_zoom, config.transition_duration)
	
	# Сигнал завершения после окончания анимации
	tween.finished.connect(func(): zoom_completed.emit(zoom_type))

	var _settings = config.get_settings_by_type(zoom_type)
	print("📷 CameraManager: %s (zoom %.1f, pos %s)" % [
		_get_zoom_name(zoom_type), 
		target_zoom.x,
		target_pos
	])

func _get_transition_type(type_name: String) -> Tween.TransitionType:
	"""Преобразует строковое название типа анимации в Tween.TransitionType"""
	match type_name.to_lower():
		"linear":
			return Tween.TRANS_LINEAR
		"cubic":
			return Tween.TRANS_CUBIC
		"elastic":
			return Tween.TRANS_ELASTIC
		"back":
			return Tween.TRANS_BACK
		"bounce":
			return Tween.TRANS_BOUNCE
		_:
			return Tween.TRANS_CUBIC  # По умолчанию

func _get_zoom_name(zoom_type: String) -> String:
	"""Получить человекочитаемое название зума"""
	match zoom_type:
		"in", "cards":
			return "Зум на карты"
		"out":
			return "Общий план"
		"area_1":
			return "Область 1 (левая)"
		"area_2":
			return "Область 2 (центр)"
		"area_3":
			return "Область 3 (правая)"
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
		"cards":
			zoom_cards()
		"area_1":
			zoom_area(1)
		"area_2":
			zoom_area(2)
		"area_3":
			zoom_area(3)
		"next_area":
			zoom_next_area()
		"prev_area":
			zoom_prev_area()
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

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ДЛЯ РАБОТЫ С КОНФИГУРАЦИЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func get_config() -> CameraConfig:
	"""Получить текущую конфигурацию камеры"""
	return config

func reload_config() -> void:
	"""Перезагрузить конфигурацию из файла"""
	config = load(config_path) as CameraConfig
	if not config:
		push_error("❌ CameraManager: не удалось перезагрузить конфигурацию из %s" % config_path)
		config = CameraConfig.new()
	print("📷 CameraManager: конфигурация перезагружена из %s" % config_path)

func get_current_settings() -> Dictionary:
	"""Получить текущие настройки камеры (позиция и зум)"""
	if not camera:
		return {}
	return {
		"position": camera.position,
		"zoom": camera.zoom
	}
