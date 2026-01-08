# res://scripts/CameraManager.gd
# Менеджер камеры - управление зумом и позицией камеры
# Извлечён из GameController.gd в рамках рефакторинга (Фаза 1)
# Использует CameraConfig для настройки позиций и масштаба

class_name CameraManager
extends RefCounted

# Предзагрузка классов для статических методов и типов
# Используем прямые вызовы class_name классов (не нужен preload для статических методов)
# const CameraAnimationHelper = preload("res://scripts/utils/CameraAnimationHelper.gd")  # Не нужен - класс уже глобальный
const CameraConfigClass = preload("res://resources/CameraConfig.gd")
# Preload для новых классов (нужны для типизации переменных)
const CameraZoomHandlerClass = preload("res://scripts/utils/CameraZoomHandler.gd")
const CameraAreaNavigatorClass = preload("res://scripts/utils/CameraAreaNavigator.gd")
const CameraInterpolationHandlerClass = preload("res://scripts/utils/CameraInterpolationHandler.gd")

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
var _process_node: Node = null  # Node для обработки _process (экспоненциальное сглаживание)
var _zoom_handler: RefCounted = null  # Обработчик зума (Extract Class) - CameraZoomHandler
var _area_navigator: RefCounted = null  # Навигатор областей (Extract Class) - CameraAreaNavigator
var _interpolation_handler: RefCounted = null  # Обработчик интерполяции (Extract Class) - CameraInterpolationHandler
var _target_area: int = -1  # Целевая область во время анимации (обновляется только после завершения)
var _is_animating: bool = false  # Флаг активной анимации

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ ПЕРЕМЕННЫЕ (для внутреннего использования)
# ═══════════════════════════════════════════════════════════════════════════

var is_first_deal: bool = true
var current_area: int = -1  # Текущая активная область (-1 = общий план, 0 = карты, 1-3 = область)
var last_zoom_type: String = "out"  # Последний тип зума (для вертикальной навигации)
var current_tween: Tween = null  # Текущий активный tween (для предотвращения конфликтов)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ И ОЧИСТКА
# ═══════════════════════════════════════════════════════════════════════════

func cleanup() -> void:
	"""Очистить ресурсы и отписаться от EventBus
	
	КРИТИЧЕСКИ ВАЖНО: Вызвать перед созданием нового CameraManager или при удалении!
	Без этого старый экземпляр продолжит получать события из EventBus.
	"""
	print("📷 CameraManager: cleanup - отписка от EventBus")
	
	# Отписываемся от всех сигналов EventBus
	if EventBus:
		if EventBus.camera_zoom_requested.is_connected(_on_zoom_requested):
			EventBus.camera_zoom_requested.disconnect(_on_zoom_requested)
		if EventBus.first_deal_completed.is_connected(_on_first_deal_completed):
			EventBus.first_deal_completed.disconnect(_on_first_deal_completed)
		if EventBus.camera_current_area_requested.is_connected(_on_current_area_requested):
			EventBus.camera_current_area_requested.disconnect(_on_current_area_requested)
		if EventBus.camera_target_area_requested.is_connected(_on_target_area_requested):
			EventBus.camera_target_area_requested.disconnect(_on_target_area_requested)
		if EventBus.camera_target_area_from_requested.is_connected(_on_target_area_from_requested):
			EventBus.camera_target_area_from_requested.disconnect(_on_target_area_from_requested)
		if EventBus.camera_settings_requested.is_connected(_on_settings_requested):
			EventBus.camera_settings_requested.disconnect(_on_settings_requested)
		if EventBus.camera_first_deal_set_requested.is_connected(_on_first_deal_set_requested):
			EventBus.camera_first_deal_set_requested.disconnect(_on_first_deal_set_requested)
		if EventBus.game_restarted.is_connected(_on_game_restarted):
			EventBus.game_restarted.disconnect(_on_game_restarted)
	
	# Останавливаем анимации
	if _interpolation_handler:
		_interpolation_handler.stop_interpolation()
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	# Удаляем созданные ноды
	if _camera and is_instance_valid(_camera):
		_camera.queue_free()
		_camera = null
	if _process_node and is_instance_valid(_process_node):
		_process_node.queue_free()
		_process_node = null
	
	print("📷 CameraManager: cleanup завершён")

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
		if _config == null:
			# Если приведение типа не сработало, создаём напрямую
			_config = CameraConfigClass.new() as CameraConfig
	else:
		push_error("❌ CameraManager: не удалось загрузить конфигурацию из %s. Используются значения по умолчанию." % _config_path)
		# Создаём конфигурацию по умолчанию
		_config = CameraConfigClass.new() as CameraConfig
	
	# Создаём камеру
	_camera = Camera2D.new()
	_camera.enabled = true
	_camera.ignore_rotation = false  # Разрешаем поворот камеры
	
	# Настраиваем встроенное сглаживание если включено
	if _config.use_camera_smoothing:
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = _config.position_smoothing_speed
		_camera.rotation_smoothing_enabled = true
		_camera.rotation_smoothing_speed = _config.rotation_smoothing_speed
		print("📷 CameraManager: встроенное сглаживание включено (position_speed=%.1f, rotation_speed=%.1f)" % [_config.position_smoothing_speed, _config.rotation_smoothing_speed])
	else:
		_camera.position_smoothing_enabled = false
		_camera.rotation_smoothing_enabled = false
		print("📷 CameraManager: встроенное сглаживание отключено (используется Tween)")
	
	parent_scene.add_child(_camera)
	
	# Создаём Node для обработки _process (экспоненциальное сглаживание)
	_process_node = Node.new()
	_process_node.name = "CameraInterpolationNode"
	
	# Загружаем скрипт для обработки _process
	var script_path = "res://scripts/CameraInterpolationNode.gd"
	var script = load(script_path) as GDScript
	if script:
		_process_node.set_script(script)
	
	parent_scene.add_child(_process_node)
	
	# Настраиваем node через setup если метод доступен
	if _process_node.has_method("setup"):
		_process_node.setup(self)
	else:
		# Если скрипт не загружен, устанавливаем process вручную
		_process_node.set_process(false)  # Начинаем с выключенным, включается при старте интерполяции
	
	# Начинаем с общего плана (из конфигурации)
	var general_settings = _config.get_general_settings()
	_camera.position = general_settings.position
	_camera.zoom = general_settings.zoom
	_camera.rotation_degrees = general_settings.get("rotation", 0.0)
	current_area = -1  # Общий план
	last_zoom_type = "out"
	
	# Инициализируем обработчик интерполяции
	var on_interpolation_completed = func(zoom_type: String) -> void:
		# Обновляем current_area только после завершения анимации
		current_area = _target_area
		_is_animating = false
		zoom_completed.emit(zoom_type)
	_interpolation_handler = CameraInterpolationHandlerClass.new(
		_config, 
		_camera, 
		_scene, 
		_process_node,
		on_interpolation_completed
	)
	
	# Обновляем CameraInterpolationNode для использования обработчика интерполяции
	if _process_node.has_method("setup_interpolation_handler"):
		_process_node.setup_interpolation_handler(_interpolation_handler)
	
	# Инициализируем обработчик зума
	var animate_callback = func(target_pos: Vector2, target_zoom: Vector2, target_rotation: float, zoom_type: String, is_nav: bool) -> void:
		_animate_to(target_pos, target_zoom, target_rotation, zoom_type, is_nav)
	_zoom_handler = CameraZoomHandlerClass.new(_config, animate_callback)
	
	# Инициализируем навигатор областей
	var zoom_area_cb = func(area_index: int, is_nav: bool) -> void:
		_zoom_handler.zoom_area(area_index, is_nav)
	var zoom_in_cb = func(is_nav: bool) -> void:
		_zoom_handler.zoom_in(is_nav)
	var zoom_out_cb = func(is_nav: bool) -> void:
		_zoom_handler.zoom_out(is_nav)
	_area_navigator = CameraAreaNavigatorClass.new(zoom_area_cb, zoom_in_cb, zoom_out_cb)
	
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
		
		# События игры
		EventBus.game_restarted.connect(_on_game_restarted)
	
	print("📷 CameraManager: камера создана и полностью инкапсулирована (zoom %.1f, конфиг: %s)" % [general_settings.zoom.x, _config_path])

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ЗУМА
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ ЗУМА (внутренняя логика)
# ═══════════════════════════════════════════════════════════════════════════

# Методы зума перенесены в CameraZoomHandler
# _zoom_in -> _zoom_handler.zoom_in
# _zoom_out -> _zoom_handler.zoom_out
# _zoom_guest_X_mode2 -> _zoom_handler.zoom_guest_X_mode2
# _zoom_area -> _zoom_handler.zoom_area

func _zoom_in(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на область карт - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_in(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_out(is_navigation: bool = false) -> void:
	"""Внутренний метод возврата к общему плану - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_out(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_guest_1_mode2(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на гость 1 режим 2 - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_guest_1_mode2(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_guest_2_mode2(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на гость 2 режим 2 - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_guest_2_mode2(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_guest_3_mode2(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на гость 3 режим 2 - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_guest_3_mode2(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_guest_4_mode2(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на гость 4 режим 2 - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_guest_4_mode2(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_guest_5_mode2(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на гость 5 режим 2 - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_guest_5_mode2(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_guest_6_mode2(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на гость 6 режим 2 - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_guest_6_mode2(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_area(area_index: int, is_navigation: bool = false) -> void:
	"""Внутренний метод зума на указанную область (1-6) - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_area(area_index, is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ НАВИГАЦИИ (внутренняя логика)
# ═══════════════════════════════════════════════════════════════════════════

func _zoom_next_area() -> void:
	"""Переключиться на следующую область (вправо) - делегировано в CameraAreaNavigator"""
	if _area_navigator:
		_area_navigator.zoom_next_area(current_area)
	else:
		push_error("❌ CameraAreaNavigator не инициализирован!")

func _zoom_prev_area() -> void:
	"""Переключиться на предыдущую область (влево) - делегировано в CameraAreaNavigator"""
	if _area_navigator:
		_area_navigator.zoom_prev_area(current_area)
	else:
		push_error("❌ CameraAreaNavigator не инициализирован!")

func _zoom_up() -> void:
	"""Вертикальная навигация вверх - делегировано в CameraAreaNavigator"""
	if _area_navigator:
		_area_navigator.zoom_up(current_area)
	else:
		push_error("❌ CameraAreaNavigator не инициализирован!")

func _zoom_down() -> void:
	"""Вертикальная навигация вниз - делегировано в CameraAreaNavigator"""
	if _area_navigator:
		_area_navigator.zoom_down(current_area)
	else:
		push_error("❌ CameraAreaNavigator не инициализирован!")

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ ОПРЕДЕЛЕНИЯ НАПРАВЛЕНИЙ (внутренняя логика)
# ═══════════════════════════════════════════════════════════════════════════

func _get_target_area_by_direction(direction: String) -> int:
	"""Определить целевую область по направлению из текущего состояния - делегировано в CameraAreaNavigator"""
	if not _area_navigator:
		push_error("❌ CameraAreaNavigator не инициализирован!")
		return 0
	# Используем _target_area если анимация идет, иначе current_area
	# Это гарантирует, что запросы во время анимации используют правильное состояние
	var area = _target_area if _is_animating else current_area
	var target = _area_navigator.get_target_area_by_direction(area, direction)
	print("📷 CameraManager: направление '%s' из area=%d (is_animating=%s, current=%d, target=%d) → %d" % [
		direction, area, _is_animating, current_area, _target_area, target
	])
	return target

func _get_target_area_by_direction_from(area: int, direction: String) -> int:
	"""Определить целевую область по направлению из указанной области - делегировано в CameraAreaNavigator"""
	if _area_navigator:
		return _area_navigator.get_target_area_by_direction(area, direction)
	else:
		push_error("❌ CameraAreaNavigator не инициализирован!")
		return 0

func predict_target_area(zoom_type: String) -> int:
	"""Предсказать целевую область (1-6) по zoom_type, 0 — если карты/общий план - делегировано в CameraAreaNavigator
	
	Публичный метод для GameController (используется для подсветки областей).
	
	Args:
		zoom_type: Тип зума (например, "area_1", "next_area", "up", и т.д.)
		
	Returns:
		Целевая область (1-6), 0 для карт/общего плана, -1 для общего плана
	"""
	if _area_navigator:
		return _area_navigator.predict_target_area(zoom_type, current_area)
	else:
		push_error("❌ CameraAreaNavigator не инициализирован!")
		return 0

func is_on_cards() -> bool:
	"""Проверка, находится ли камера на картах
	
	Returns:
		true если камера находится на картах, false иначе
	"""
	return last_zoom_type == "in" or last_zoom_type == "cards"

func is_on_area() -> bool:
	"""Проверка, находится ли камера на области ставок
	
	Returns:
		true если камера находится на области ставок (1-6), false иначе
	"""
	return current_area >= 1 and current_area <= 6

func get_last_zoom_type() -> String:
	"""Получить последний тип зума
	
	Returns:
		Последний тип зума (например, "in", "out", "area_1", и т.д.)
	"""
	return last_zoom_type

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _process_interpolation(_delta: float) -> void:
	"""Обработка экспоненциального сглаживания камеры в _process (делегирует в CameraInterpolationHandler)
	
	Args:
		_delta: Время с последнего кадра (не используется, но требуется для _process)
	"""
	if _interpolation_handler:
		_interpolation_handler.process_interpolation(_delta)

func _animate_to(target_pos: Vector2, target_zoom: Vector2, target_rotation: float, zoom_type: String, is_navigation: bool = false) -> void:
	"""Анимировать камеру к заданной позиции, зуму и повороту
	
	Args:
		target_pos: Целевая позиция камеры
		target_zoom: Целевой зум камеры
		target_rotation: Целевой поворот камеры (в градусах)
		zoom_type: Тип зума (для логирования)
		is_navigation: true если запрос от навигатора (используются медленные настройки)
		              Если false, тип анимации определяется автоматически на основе правил
	"""
	if not _camera or not _scene or not _config:
		return
	
	# ═══════════════════════════════════════════════════════════════════════
	# КРИТИЧЕСКИ ВАЖНО: Сохраняем состояние ПЕРЕД любыми изменениями!
	# 
	# previous_target_area должен содержать ПРЕДЫДУЩУЮ целевую область,
	# чтобы при прерывании анимации мы могли корректно синхронизировать current_area
	# ═══════════════════════════════════════════════════════════════════════
	var was_animating = _is_animating
	var previous_target_area = _target_area  # Сохраняем СТАРОЕ значение ДО обновления!
	
	# ═══════════════════════════════════════════════════════════════════════
	# ОПРЕДЕЛЕНИЕ ТИПА АНИМАЦИИ (БЫСТРАЯ / МЕДЛЕННАЯ)
	# 
	# Упрощённая логика:
	# - is_navigation = false → быстрая анимация (обычные переходы)
	# - is_navigation = true  → медленная анимация (навигация по ставкам)
	# 
	# Настройки анимации находятся в CameraConfig.gd:
	#   - БЫСТРАЯ: min_interpolation_speed, max_interpolation_speed
	#   - МЕДЛЕННАЯ: navigation_min_interpolation_speed, navigation_max_interpolation_speed
	# ═══════════════════════════════════════════════════════════════════════
	
	# Звук перехода камеры (только при быстрых переходах, is_navigation = false)
	if not is_navigation and SoundManager:
		SoundManager.play_camera_transition_sound()
	
	# Сохраняем целевую область, но НЕ обновляем current_area сразу
	# current_area будет обновлен только после завершения анимации
	match zoom_type:
		"in", "cards":
			_target_area = 0  # Карты
		"out":
			_target_area = -1  # Общий план
		"guest_1_mode2", "guest_2_mode2", "guest_3_mode2", "guest_4_mode2", "guest_5_mode2", "guest_6_mode2":
			_target_area = -1  # Остаёмся на общем плане для режима 2
		_:
			if zoom_type.begins_with("area_"):
				# Извлекаем номер области из строки "area_X" (где X от 1 до 6)
				var area_str = zoom_type.substr(5)  # Получаем "1", "2", и т.д.
				var area_num = area_str.to_int()
				if area_num >= 1 and area_num <= 6:
					_target_area = area_num
	
	# Устанавливаем флаг новой анимации
	_is_animating = true
	last_zoom_type = zoom_type
	zoom_started.emit(zoom_type)
	
	# ═══════════════════════════════════════════════════════════════════════
	# ПРЕРЫВАНИЕ ПРЕДЫДУЩЕЙ АНИМАЦИИ (защита от быстрых нажатий)
	# 
	# При прерывании:
	# 1. Останавливаем Tween и интерполяцию
	# 2. Синхронизируем current_area с предыдущей целью (previous_target_area)
	# ═══════════════════════════════════════════════════════════════════════
	
	# Останавливаем Tween если он активен
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	# Останавливаем интерполяцию если она активна
	if _interpolation_handler:
		_interpolation_handler.stop_interpolation()
	
	# Если прерываем предыдущую анимацию, синхронизируем current_area
	# с предыдущей целевой областью (куда камера ДОЛЖНА была прийти)
	if was_animating:
		current_area = previous_target_area
		print("📷 CameraManager: прерывание анимации - синхронизация current_area = %d (было %d)" % [current_area, previous_target_area])
	
	# Если используется экспоненциальное сглаживание с адаптивной скоростью
	if _config.use_adaptive_interpolation and _interpolation_handler:
		_interpolation_handler.start_interpolation(target_pos, target_zoom, target_rotation, zoom_type, is_navigation)
		return
	
	# Если используется Tween анимация (встроенное сглаживание или обычный Tween)
	if _interpolation_handler:
		var on_tween_completed = func(completed_zoom_type: String) -> void:
			# Обновляем current_area только после завершения анимации
			current_area = _target_area
			_is_animating = false
			current_tween = null  # Очищаем ссылку после завершения
			zoom_completed.emit(completed_zoom_type)
		
		current_tween = _interpolation_handler.create_tween_animation(
			target_pos,
			target_zoom,
			target_rotation,
			zoom_type,
			_config.use_camera_smoothing,
			on_tween_completed
		)

# Методы утилит анимации перенесены в CameraAnimationHelper
# _get_transition_type -> CameraAnimationHelper.get_transition_type
# _get_ease_type -> CameraAnimationHelper.get_ease_type
# _get_zoom_name -> CameraAnimationHelper.get_zoom_name

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ EVENTBUS - КОМАНДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _on_zoom_requested(zoom_type: String, is_navigation: bool = false) -> void:
	"""Обработка запроса зума через EventBus"""
	match zoom_type:
		"in":
			_zoom_in(is_navigation)
		"out":
			_zoom_out(is_navigation)
		"cards":
			_zoom_in(is_navigation)
		"area_1":
			_zoom_area(1, is_navigation)
		"area_2":
			_zoom_area(2, is_navigation)
		"area_3":
			_zoom_area(3, is_navigation)
		"area_4":
			_zoom_area(4, is_navigation)
		"area_5":
			_zoom_area(5, is_navigation)
		"area_6":
			_zoom_area(6, is_navigation)
		"guest_1_mode2":
			_zoom_guest_1_mode2(is_navigation)
		"guest_2_mode2":
			_zoom_guest_2_mode2(is_navigation)
		"guest_3_mode2":
			_zoom_guest_3_mode2(is_navigation)
		"guest_4_mode2":
			_zoom_guest_4_mode2(is_navigation)
		"guest_5_mode2":
			_zoom_guest_5_mode2(is_navigation)
		"guest_6_mode2":
			_zoom_guest_6_mode2(is_navigation)
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

func _on_game_restarted() -> void:
	"""Обработка рестарта игры - сброс состояния камеры
	
	Вызывается при рестарте игры через EventBus.game_restarted.
	Полностью сбрасывает состояние камеры к начальному состоянию.
	"""
	# Останавливаем активную интерполяцию (полный сброс состояния)
	if _interpolation_handler:
		_interpolation_handler.stop_interpolation()
	
	# Останавливаем активный Tween
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	# Восстанавливаем камеру к общему плану (используем существующий метод)
	restore_to_general()
	
	print("📷 CameraManager: состояние камеры сброшено при рестарте игры")

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
	"""Получить флаг первой раздачи
	
	Returns:
		true если это первая раздача, false иначе
	"""
	return is_first_deal

func set_is_first_deal(value: bool) -> void:
	"""Установить флаг первой раздачи
	
	Args:
		value: true если это первая раздача, false иначе
	"""
	is_first_deal = value

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ДЛЯ РАБОТЫ С КОНФИГУРАЦИЕЙ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЙ API (для специальных случаев, например StateRestorer)
# ═══════════════════════════════════════════════════════════════════════════

func restore_to_general() -> void:
	"""Восстановить камеру к общему плану (для StateRestorer и рестарта игры)
	
	Публичный метод для МГНОВЕННОГО восстановления состояния камеры без анимации.
	Используется в StateRestorer и при game_restarted для сброса камеры.
	
	КРИТИЧЕСКИ ВАЖНО: Этот метод полностью сбрасывает состояние навигации!
	"""
	print("📷 CameraManager: restore_to_general - ДО сброса: current_area=%d, _target_area=%d, _is_animating=%s, last_zoom_type=%s" % [
		current_area, _target_area, _is_animating, last_zoom_type
	])
	
	if _camera != null and _config != null:
		var general_settings = _config.get_general_settings()
		# Мгновенно устанавливаем позицию камеры (без анимации)
		_camera.position = general_settings.position
		_camera.zoom = general_settings.zoom
		_camera.rotation_degrees = general_settings.get("rotation", 0.0)
		
		# Полный сброс состояния навигации
		is_first_deal = false
		current_area = -1  # Общий план
		_target_area = -1  # Также сбрасываем целевую область
		_is_animating = false  # Сбрасываем флаг анимации
		last_zoom_type = "out"
		
		print("📷 CameraManager: камера восстановлена к общему плану (ПОСЛЕ сброса: current_area=%d, _target_area=%d)" % [
			current_area, _target_area
		])

func reload_config() -> void:
	"""Перезагрузить конфигурацию из файла (для отладки)"""
	var config_script = load(_config_path) as GDScript
	if config_script:
		_config = config_script.new() as CameraConfig
		if _config == null:
			# Если приведение типа не сработало, создаём напрямую
			_config = CameraConfigClass.new() as CameraConfig
	else:
		push_error("❌ CameraManager: не удалось перезагрузить конфигурацию из %s" % _config_path)
		_config = CameraConfigClass.new() as CameraConfig
	
	# Обновляем обработчик зума с новой конфигурацией
	var animate_callback = func(target_pos: Vector2, target_zoom: Vector2, target_rotation: float, zoom_type: String, is_nav: bool) -> void:
		_animate_to(target_pos, target_zoom, target_rotation, zoom_type, is_nav)
	_zoom_handler = CameraZoomHandlerClass.new(_config, animate_callback)
	
	# Обновляем навигатор областей
	var zoom_area_cb = func(area_index: int, is_nav: bool) -> void:
		_zoom_handler.zoom_area(area_index, is_nav)
	var zoom_in_cb = func(is_nav: bool) -> void:
		_zoom_handler.zoom_in(is_nav)
	var zoom_out_cb = func(is_nav: bool) -> void:
		_zoom_handler.zoom_out(is_nav)
	_area_navigator = CameraAreaNavigatorClass.new(zoom_area_cb, zoom_in_cb, zoom_out_cb)
	
	# Обновляем обработчик интерполяции с новой конфигурацией
	if _camera and _scene and _process_node:
		var on_interpolation_completed = func(zoom_type: String) -> void:
			# Обновляем current_area после завершения анимации (как в setup)
			current_area = _target_area
			_is_animating = false
			zoom_completed.emit(zoom_type)
		_interpolation_handler = CameraInterpolationHandlerClass.new(
			_config, 
			_camera, 
			_scene, 
			_process_node,
			on_interpolation_completed
		)
		# Обновляем CameraInterpolationNode
		if _process_node.has_method("setup_interpolation_handler"):
			_process_node.setup_interpolation_handler(_interpolation_handler)
	
	print("📷 CameraManager: конфигурация перезагружена из %s" % _config_path)
