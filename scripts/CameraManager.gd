# res://scripts/CameraManager.gd
# Менеджер камеры - управление зумом и позицией камеры
# Извлечён из GameController.gd в рамках рефакторинга (Фаза 1)
# Использует CameraConfig для настройки позиций и масштаба

class_name CameraManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal zoom_started(zoom_type: String)
signal zoom_completed(zoom_type: String)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ ПЕРЕМЕННЫЕ (инкапсуляция)
# ═══════════════════════════════════════════════════════════════════════════

var _config_path: String = "res://resources/CameraConfig.gd"
var _config: CameraConfig = null
var _camera: Camera2D = null
var _scene: Node = null  # Родительская сцена для создания tween

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ ПЕРЕМЕННЫЕ (для внутреннего использования)
# ═══════════════════════════════════════════════════════════════════════════

var is_first_deal: bool = true
var current_area: int = -1  # Текущая активная область (-1 = общий план, 0 = карты, 1-3 = область)
var last_zoom_type: String = "out"  # Последний тип зума (для вертикальной навигации)
var current_tween: Tween = null  # Текущий активный tween (для предотвращения конфликтов)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(parent_scene: Node, camera_config_path: String = "") -> void:
	"""Создать и настроить камеру
	
	Args:
		parent_scene: Родительская сцена (Game.tscn) для добавления камеры
		camera_config_path: Путь к файлу конфигурации (опционально)
	"""
	_scene = parent_scene
	
	# Загружаем конфигурацию камеры
	if camera_config_path != "":
		_config_path = camera_config_path
	
	# Загружаем класс и создаём экземпляр
	var config_script = load(_config_path) as GDScript
	if config_script:
		_config = config_script.new() as CameraConfig
	else:
		push_error("❌ CameraManager: не удалось загрузить конфигурацию из %s. Используются значения по умолчанию." % _config_path)
		# Создаём конфигурацию по умолчанию
		_config = CameraConfig.new()
	
	# Создаём камеру
	_camera = Camera2D.new()
	_camera.enabled = true
	parent_scene.add_child(_camera)
	
	# Начинаем с общего плана (из конфигурации)
	var general_settings = _config.get_general_settings()
	_camera.position = general_settings.position
	_camera.zoom = general_settings.zoom
	current_area = -1  # Общий план
	last_zoom_type = "out"
	
	# ═══════════════════════════════════════════════════════════════════
	# ПОДПИСКА НА EVENTBUS - ВСЕ КОМАНДЫ И ЗАПРОСЫ
	# ═══════════════════════════════════════════════════════════════════
	if EventBus:
		# Команды зума
		EventBus.camera_zoom_requested.connect(_on_zoom_requested)
		EventBus.first_deal_completed.connect(_on_first_deal_completed)
		
		# Запросы состояния
		EventBus.camera_current_area_requested.connect(_on_current_area_requested)
		EventBus.camera_target_area_requested.connect(_on_target_area_requested)
		EventBus.camera_target_area_from_requested.connect(_on_target_area_from_requested)
		EventBus.camera_settings_requested.connect(_on_settings_requested)
		EventBus.camera_first_deal_set_requested.connect(_on_first_deal_set_requested)
	
	print("📷 CameraManager: камера создана и полностью инкапсулирована (zoom %.1f, конфиг: %s)" % [general_settings.zoom.x, _config_path])

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ЗУМА
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ ЗУМА (внутренняя логика)
# ═══════════════════════════════════════════════════════════════════════════

func _zoom_in() -> void:
	"""Внутренний метод зума на область карт"""
	current_area = 0
	var settings = _config.get_cards_settings()
	_animate_to(settings.position, settings.zoom, "in")

func _zoom_out() -> void:
	"""Внутренний метод возврата к общему плану"""
	current_area = -1  # Общий план
	var settings = _config.get_general_settings()
	_animate_to(settings.position, settings.zoom, "out")

func _zoom_area(area_index: int) -> void:
	"""Внутренний метод зума на указанную область (1, 2 или 3)"""
	if area_index < 1 or area_index > 3:
		push_error("CameraManager: неверный индекс области %d" % area_index)
		return
	current_area = area_index
	var settings = _config.get_area_settings(area_index)
	_animate_to(settings.position, settings.zoom, "area_%d" % area_index)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ НАВИГАЦИИ (внутренняя логика)
# ═══════════════════════════════════════════════════════════════════════════

func _zoom_next_area() -> void:
	"""Переключиться на следующую область (вправо)"""
	var target = _get_target_area_by_direction("right")
	if target > 0 and target != current_area:
		_zoom_area(target)

func _zoom_prev_area() -> void:
	"""Переключиться на предыдущую область (влево)"""
	var target = _get_target_area_by_direction("left")
	if target > 0 and target != current_area:
		_zoom_area(target)

func _zoom_up() -> void:
	"""Вертикальная навигация вверх: с карт → area_2, из областей → общий план"""
	var target = _get_target_area_by_direction("up")
	if target > 0 and target != current_area:
		_zoom_area(target)
	elif target == -1:
		_zoom_out()

func _zoom_down() -> void:
	"""Вертикальная навигация вниз: из областей → карты, с карт → общий план"""
	var target = _get_target_area_by_direction("down")
	if target == 0:
		_zoom_in()
	elif target == -1:
		_zoom_out()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ ОПРЕДЕЛЕНИЯ НАПРАВЛЕНИЙ (внутренняя логика)
# ═══════════════════════════════════════════════════════════════════════════

func _get_target_area_by_direction(direction: String) -> int:
	"""Определить целевую область по направлению из текущего состояния
	
	Единая точка истины для всех переходов камеры.
	
	Args:
		direction: "left", "right", "up", "down"
	
	Returns:
		Целевая область (1-3), 0 для карт, -1 для общего плана
	"""
	match direction:
		"left":
			match current_area:
				0: return 1  # карты → area_1
				1: return 1  # area_1 → остаётся (нет перехода)
				2: return 1  # area_2 → area_1
				3: return 2  # area_3 → area_2
		"right":
			match current_area:
				0: return 3  # карты → area_3
				1: return 2  # area_1 → area_2
				2: return 3  # area_2 → area_3
				3: return 3  # area_3 → остаётся (нет перехода)
		"up":
			match current_area:
				0: return 2  # карты → area_2
				1, 2, 3: return -1  # из областей → общий план
		"down":
			match current_area:
				-1: return 0  # общий план → карты
				0: return -1  # карты → общий план
				1, 2, 3: return 0  # из областей → карты
		_:
			return 0
	return 0

func _get_target_area_by_direction_from(area: int, direction: String) -> int:
	"""Определить целевую область по направлению из указанной области
	
	Аналогично get_target_area_by_direction(), но принимает область как параметр.
	Используется для предсказания состояния стрелок на основе целевой области.
	
	Args:
		area: Исходная область (0 = карты, 1-3 = области ставок, -1 = общий план)
		direction: "left", "right", "up", "down"
	
	Returns:
		Целевая область (1-3), 0 для карт, -1 для общего плана
	"""
	match direction:
		"left":
			match area:
				0: return 1  # карты → area_1
				1: return 1  # area_1 → остаётся (нет перехода)
				2: return 1  # area_2 → area_1
				3: return 2  # area_3 → area_2
		"right":
			match area:
				0: return 3  # карты → area_3
				1: return 2  # area_1 → area_2
				2: return 3  # area_2 → area_3
				3: return 3  # area_3 → остаётся (нет перехода)
		"up":
			match area:
				0: return 2  # карты → area_2
				1, 2, 3: return -1  # из областей → общий план
		"down":
			match area:
				-1: return 0  # общий план → карты
				0: return -1  # карты → общий план
				1, 2, 3: return 0  # из областей → карты
		_:
			return 0
	return 0

func predict_target_area(zoom_type: String) -> int:
	"""Предсказать целевую область (1-3) по zoom_type, 0 — если карты/общий план
	
	Использует _get_target_area_by_direction() для единообразия логики.
	Публичный метод для GameController (используется для подсветки областей).
	"""
	match zoom_type:
		"area_1":
			return 1
		"area_2":
			return 2
		"area_3":
			return 3
		"next_area":
			return _get_target_area_by_direction("right")
		"prev_area":
			return _get_target_area_by_direction("left")
		"up":
			return _get_target_area_by_direction("up")
		"down":
			return _get_target_area_by_direction("down")
		_:
			return 0  # любые in/out/cards — без подсветки

func is_on_cards() -> bool:
	"""Проверка, находится ли камера на картах"""
	return last_zoom_type == "in" or last_zoom_type == "cards"

func is_on_area() -> bool:
	"""Проверка, находится ли камера на области ставок"""
	return current_area >= 1 and current_area <= 3

func get_last_zoom_type() -> String:
	"""Получить последний тип зума"""
	return last_zoom_type

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _animate_to(target_pos: Vector2, target_zoom: Vector2, zoom_type: String) -> void:
	"""Анимировать камеру к заданной позиции и зуму"""
	if not _camera or not _scene or not _config:
		return
	
	# Останавливаем предыдущую анимацию если она ещё идёт (защита от быстрых нажатий)
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	last_zoom_type = zoom_type
	zoom_started.emit(zoom_type)
	
	var tween = _scene.create_tween()
	current_tween = tween  # Сохраняем ссылку для возможности остановки
	tween.set_parallel(true)  # Позиция и зум меняются одновременно
	
	# Используем тип анимации из конфигурации
	var transition_type = _get_transition_type(_config.transition_type)
	tween.set_trans(transition_type)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Используем длительность из конфигурации
	tween.tween_property(_camera, "position", target_pos, _config.transition_duration)
	tween.tween_property(_camera, "zoom", target_zoom, _config.transition_duration)
	
	# Сигнал завершения после окончания анимации
	tween.finished.connect(func(): 
		current_tween = null  # Очищаем ссылку после завершения
		zoom_completed.emit(zoom_type)
	)

	var _settings = _config.get_settings_by_type(zoom_type)
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
		"up":
			return "Навигация вверх"
		"down":
			return "Навигация вниз"
		_:
			return "Неизвестный зум"

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ EVENTBUS - КОМАНДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _on_zoom_requested(zoom_type: String) -> void:
	"""Обработка запроса зума через EventBus"""
	match zoom_type:
		"in":
			_zoom_in()
		"out":
			_zoom_out()
		"cards":
			_zoom_in()
		"area_1":
			_zoom_area(1)
		"area_2":
			_zoom_area(2)
		"area_3":
			_zoom_area(3)
		"next_area":
			_zoom_next_area()
		"prev_area":
			_zoom_prev_area()
		"up":
			_zoom_up()
		"down":
			_zoom_down()
		_:
			push_error("CameraManager: неизвестный тип зума '%s'" % zoom_type)

func _on_first_deal_set_requested(value: bool) -> void:
	"""Обработка запроса установки is_first_deal"""
	is_first_deal = value

func _on_first_deal_completed() -> void:
	"""Обработка завершения первой раздачи"""
	is_first_deal = false
	print("📷 CameraManager: первая раздача завершена")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ EVENTBUS - ЗАПРОСЫ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _on_current_area_requested() -> void:
	"""Обработка запроса текущей области"""
	if EventBus:
		EventBus.camera_current_area_received.emit(current_area)

func _on_target_area_requested(direction: String) -> void:
	"""Обработка запроса целевой области по направлению"""
	var target = _get_target_area_by_direction(direction)
	if EventBus:
		EventBus.camera_target_area_received.emit(direction, target)

func _on_target_area_from_requested(area: int, direction: String) -> void:
	"""Обработка запроса целевой области из указанной"""
	var target = _get_target_area_by_direction_from(area, direction)
	if EventBus:
		EventBus.camera_target_area_from_received.emit(area, direction, target)

func _on_settings_requested() -> void:
	"""Обработка запроса настроек камеры"""
	if _camera and EventBus:
		EventBus.camera_settings_received.emit(_camera.position, _camera.zoom)

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

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЙ API (для специальных случаев, например StateRestorer)
# ═══════════════════════════════════════════════════════════════════════════

func restore_to_general() -> void:
	"""Восстановить камеру к общему плану (для StateRestorer)
	
	Публичный метод для восстановления состояния камеры без анимации.
	Используется только в StateRestorer для восстановления состояния стола.
	"""
	if _camera and _config:
		var general_settings = _config.get_general_settings()
		_camera.position = general_settings.position
		_camera.zoom = general_settings.zoom
		is_first_deal = false
		current_area = -1  # Общий план
		last_zoom_type = "out"
		print("📷 CameraManager: камера восстановлена к общему плану")

func reload_config() -> void:
	"""Перезагрузить конфигурацию из файла (для отладки)"""
	var config_script = load(_config_path) as GDScript
	if config_script:
		_config = config_script.new() as CameraConfig
	else:
		push_error("❌ CameraManager: не удалось перезагрузить конфигурацию из %s" % _config_path)
		_config = CameraConfig.new()
	print("📷 CameraManager: конфигурация перезагружена из %s" % _config_path)
