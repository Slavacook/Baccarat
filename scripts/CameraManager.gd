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
var _zoom_handler: CameraZoomHandler = null  # Обработчик зума (Extract Class)

# Целевые значения для экспоненциального сглаживания
var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: Vector2 = Vector2.ONE
var _target_rotation: float = 0.0
var _is_interpolating: bool = false
var _current_zoom_type: String = ""
var _is_navigation_mode: bool = false  # Флаг режима навигации (для медленной анимации)
var _initial_distance: float = 0.0  # Начальное расстояние для плавного старта

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ ПЕРЕМЕННЫЕ (для внутреннего использования)
# ═══════════════════════════════════════════════════════════════════════════

var is_first_deal: bool = true
var current_area: int = -1  # Текущая активная область (-1 = общий план, 0 = карты, 1-3 = область)
var last_zoom_type: String = "out"  # Последний тип зума (для вертикальной навигации)
var current_tween: Tween = null  # Текущий активный tween (для предотвращения конфликтов)
var _was_on_cards_before_out: bool = false  # Флаг: была ли камера на картах перед переходом на "out" (для правильной анимации)

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
	_target_position = general_settings.position
	_target_zoom = general_settings.zoom
	_target_rotation = general_settings.get("rotation", 0.0)
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

# Методы зума перенесены в CameraZoomHandler
# _zoom_in -> _zoom_handler.zoom_in
# _zoom_out -> _zoom_handler.zoom_out
# _zoom_mode2_right -> _zoom_handler.zoom_mode2_right
# _zoom_mode2_left -> _zoom_handler.zoom_mode2_left
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

func _zoom_mode2_right(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на режим 2 (справа) - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_mode2_right(is_navigation)
	else:
		push_error("❌ CameraZoomHandler не инициализирован!")

func _zoom_mode2_left(is_navigation: bool = false) -> void:
	"""Внутренний метод зума на режим 2 (слева) - делегировано в CameraZoomHandler"""
	if _zoom_handler:
		_zoom_handler.zoom_mode2_left(is_navigation)
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
	"""Переключиться на следующую область (вправо)
	
	Использует циклическую навигацию: area_6 → area_1
	"""
	var target = _get_target_area_by_direction("right")
	if target > 0 and target != current_area:
		_zoom_area(target)

func _zoom_prev_area() -> void:
	"""Переключиться на предыдущую область (влево)
	
	Использует циклическую навигацию: area_1 → area_6
	"""
	var target = _get_target_area_by_direction("left")
	if target > 0 and target != current_area:
		_zoom_area(target)

func _zoom_up() -> void:
	"""Вертикальная навигация вверх
	
	Переходы:
	- С карт → area_4 (центральная область)
	- Из областей → общий план
	"""
	var target = _get_target_area_by_direction("up")
	if target > 0 and target != current_area:
		_zoom_area(target)
	elif target == -1:
		_zoom_out()

func _zoom_down() -> void:
	"""Вертикальная навигация вниз
	
	Переходы:
	- Из областей → карты
	- С карт → общий план
	"""
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
		Целевая область (1-6), 0 для карт, -1 для общего плана
	"""
	match direction:
		"left":
			match current_area:
				0: return 1  # карты → area_1
				1: return 6  # area_1 → area_6 (циклически)
				2: return 1  # area_2 → area_1
				3: return 2  # area_3 → area_2
				4: return 3  # area_4 → area_3
				5: return 4  # area_5 → area_4
				6: return 5  # area_6 → area_5
		"right":
			match current_area:
				0: return 6  # карты → area_6
				1: return 2  # area_1 → area_2
				2: return 3  # area_2 → area_3
				3: return 4  # area_3 → area_4
				4: return 5  # area_4 → area_5
				5: return 6  # area_5 → area_6
				6: return 1  # area_6 → area_1 (циклически)
		"up":
			match current_area:
				0: return 4  # карты → area_4 (центральная)
				1, 2, 3, 4, 5, 6: return -1  # из областей → общий план
		"down":
			match current_area:
				-1: return 0  # общий план → карты
				0: return -1  # карты → общий план
				1, 2, 3, 4, 5, 6: return 0  # из областей → карты
		_:
			return 0
	return 0

func _get_target_area_by_direction_from(area: int, direction: String) -> int:
	"""Определить целевую область по направлению из указанной области
	
	Аналогично get_target_area_by_direction(), но принимает область как параметр.
	Используется для предсказания состояния стрелок на основе целевой области.
	
	Args:
		area: Исходная область (0 = карты, 1-6 = области ставок, -1 = общий план)
		direction: "left", "right", "up", "down"
	
	Returns:
		Целевая область (1-6), 0 для карт, -1 для общего плана
	"""
	match direction:
		"left":
			match area:
				0: return 1  # карты → area_1
				1: return 6  # area_1 → area_6 (циклически)
				2: return 1  # area_2 → area_1
				3: return 2  # area_3 → area_2
				4: return 3  # area_4 → area_3
				5: return 4  # area_5 → area_4
				6: return 5  # area_6 → area_5
		"right":
			match area:
				0: return 6  # карты → area_6
				1: return 2  # area_1 → area_2
				2: return 3  # area_2 → area_3
				3: return 4  # area_3 → area_4
				4: return 5  # area_4 → area_5
				5: return 6  # area_5 → area_6
				6: return 1  # area_6 → area_1 (циклически)
		"up":
			match area:
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

func predict_target_area(zoom_type: String) -> int:
	"""Предсказать целевую область (1-6) по zoom_type, 0 — если карты/общий план
	
	Использует _get_target_area_by_direction() для единообразия логики.
	Публичный метод для GameController (используется для подсветки областей).
	
	Args:
		zoom_type: Тип зума (например, "area_1", "next_area", "up", и т.д.)
		
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
	"""Обработка экспоненциального сглаживания камеры в _process
	
	Использует адаптивную скорость интерполяции на основе расстояния до цели.
	Применяет плавное ускорение и замедление для естественного движения камеры.
	
	Args:
		_delta: Время с последнего кадра (не используется, но требуется для _process)
	"""
	if not _is_interpolating or not _camera:
		return
	
	# Вычисляем расстояние до цели (ДО интерполяции)
	var position_distance = _camera.position.distance_to(_target_position)
	
	# Выбираем настройки в зависимости от типа анимации (обычная или навигация)
	var min_speed: float
	var max_speed: float
	var distance_thresh: float
	var rotation_thresh: float
	
	if _is_navigation_mode:
		# Используем медленные настройки для навигации
		min_speed = _config.navigation_min_interpolation_speed
		max_speed = _config.navigation_max_interpolation_speed
		distance_thresh = _config.navigation_distance_threshold
		rotation_thresh = _config.navigation_rotation_threshold
	else:
		# Обычные настройки
		min_speed = _config.min_interpolation_speed
		max_speed = _config.max_interpolation_speed
		distance_thresh = _config.distance_threshold
		rotation_thresh = _config.rotation_threshold
	
	# Вычисляем адаптивный коэффициент интерполяции на основе расстояния
	# Чем дальше, тем больше коэффициент (быстрее), чем ближе, тем меньше (медленнее)
	var max_distance = 1000.0  # Максимальное ожидаемое расстояние для нормализации
	var distance_factor = clamp(position_distance / max_distance, 0.0, 1.0)
	
	# Для плавного старта: применяем нелинейную функцию (степень для плавного ускорения)
	# Это делает старт медленнее, а затем плавное ускорение
	if _is_navigation_mode:
		# Для навигации используем более плавное ускорение (степень 2.5)
		distance_factor = pow(distance_factor, 2.5)
	else:
		# Для обычной анимации используем стандартное ускорение (степень 1.5)
		distance_factor = pow(distance_factor, 1.5)
	
	var interpolation_speed = lerp(min_speed, max_speed, distance_factor)
	
	# Если камера очень близко к цели, используем минимальную скорость для плавного завершения
	# Это предотвращает рывок в момент остановки
	if position_distance < distance_thresh * 3.0:
		# Когда очень близко, используем минимальную скорость для плавного подхода
		# Чем ближе, тем медленнее
		var close_factor = clamp(position_distance / (distance_thresh * 3.0), 0.0, 1.0)
		interpolation_speed = lerp(min_speed * 0.2, min_speed, close_factor)
	
	# Интерполируем позицию
	_camera.position = _camera.position.lerp(_target_position, interpolation_speed)
	
	# Интерполируем поворот (используем меньший коэффициент для более плавного поворота)
	var rotation_speed = interpolation_speed * 0.7  # Поворот чуть медленнее
	var current_rot = _camera.rotation_degrees
	_camera.rotation_degrees = lerp(current_rot, _target_rotation, rotation_speed)
	
	# Zoom интерполируем отдельно (можно использовать тот же коэффициент или отдельный)
	var zoom_speed = interpolation_speed
	_camera.zoom = _camera.zoom.lerp(_target_zoom, zoom_speed)
	
	# Вычисляем новые расстояния ПОСЛЕ интерполяции для проверки достижения цели
	var new_position_distance = _camera.position.distance_to(_target_position)
	var new_rotation_distance = abs(_camera.rotation_degrees - _target_rotation)
	var new_zoom_distance = _camera.zoom.distance_to(_target_zoom)
	
	# Используем очень строгие пороги для остановки (почти вплотную к цели)
	# Это гарантирует, что камера действительно достигла цели без рывка
	var position_reached = new_position_distance < 0.05  # Очень маленький порог
	var rotation_reached = new_rotation_distance < rotation_thresh * 0.1  # Пропорционально порогу
	var zoom_reached = new_zoom_distance < 0.001  # Очень маленький порог
	
	if position_reached and rotation_reached and zoom_reached:
		# Камера действительно достигла цели - устанавливаем финальные значения
		# На этом этапе камера уже очень близко, поэтому рывка не будет
		_camera.position = _target_position
		_camera.rotation_degrees = _target_rotation
		_camera.zoom = _target_zoom
		
		# Останавливаем интерполяцию
		_is_interpolating = false
		if _process_node and _process_node.has_method("set_process"):
			_process_node.set_process(false)
		
		# Эмитим сигнал завершения
		zoom_completed.emit(_current_zoom_type)
		print("📷 CameraManager: камера достигла цели через экспоненциальное сглаживание")

func _animate_to(target_pos: Vector2, target_zoom: Vector2, target_rotation: float, zoom_type: String, is_navigation: bool = false) -> void:
	"""Анимировать камеру к заданной позиции, зуму и повороту
	
	Args:
		target_pos: Целевая позиция камеры
		target_zoom: Целевой зум камеры
		target_rotation: Целевой поворот камеры (в градусах)
		zoom_type: Тип зума (для логирования)
		is_navigation: true если запрос от навигатора (используются медленные настройки)
	"""
	if not _camera or not _scene or not _config:
		return
	
	# Сохраняем текущую позицию (откуда мы идем) ДО обновления current_area
	var from_zoom_type = last_zoom_type  # Тип зума, откуда мы идем (стартовая точка)
	
	# Если камера переходит на "out", сохраняем информацию о том, была ли она на картах
	if zoom_type == "out":
		_was_on_cards_before_out = (from_zoom_type == "in" or from_zoom_type == "cards")
	
	# Определяем, является ли СТАРТОВАЯ позиция одним из режимов 2 (out, mode2_right, mode2_left)
	var from_is_mode2 = (from_zoom_type == "out" or from_zoom_type == "mode2_right" or from_zoom_type == "mode2_left")
	
	# Определяем, является ли ЦЕЛЕВАЯ позиция одним из режимов 2 (out, mode2_right, mode2_left)
	var to_is_mode2 = (zoom_type == "out" or zoom_type == "mode2_right" or zoom_type == "mode2_left")
	
	# Автоматически определяем is_navigation: медленная анимация ТОЛЬКО если камера УЖЕ на одной из точек режима 2
	# И переходит на другую точку режима 2 (обе точки должны быть в списке)
	# ИСКЛЮЧЕНИЕ: если камера была на картах перед переходом на "out", то переход с "out" на mode2_right/mode2_left тоже быстрый
	var should_use_fast_animation = false
	if from_zoom_type == "out" and to_is_mode2 and _was_on_cards_before_out:
		# Камера была на картах → перешла на "out" → теперь переходит на mode2_right/mode2_left
		# Это должно быть быстро, так как визуально это один переход с карт
		should_use_fast_animation = true
		_was_on_cards_before_out = false  # Сбрасываем флаг после использования
	
	if from_is_mode2 and to_is_mode2 and not should_use_fast_animation:
		is_navigation = true
		print("📷 CameraManager: медленная анимация (режим 2: %s → %s)" % [from_zoom_type, zoom_type])
	else:
		is_navigation = false
		if should_use_fast_animation:
			print("📷 CameraManager: быстрая анимация (%s → %s) [камера была на картах]" % [from_zoom_type, zoom_type])
		else:
			print("📷 CameraManager: быстрая анимация (%s → %s)" % [from_zoom_type, zoom_type])
	
	# Обновляем current_area на основе zoom_type
	match zoom_type:
		"in", "cards":
			current_area = 0  # Карты
			_was_on_cards_before_out = false  # Сбрасываем флаг при переходе на карты
		"out":
			current_area = -1  # Общий план
		"mode2_right", "mode2_left":
			current_area = -1  # Остаёмся на общем плане для режима 2
		_:
			if zoom_type.begins_with("area_"):
				# Извлекаем номер области из строки "area_X" (где X от 1 до 6)
				var area_str = zoom_type.substr(5)  # Получаем "1", "2", и т.д.
				var area_num = area_str.to_int()
				if area_num >= 1 and area_num <= 6:
					current_area = area_num
			_was_on_cards_before_out = false  # Сбрасываем флаг при переходе на другие позиции
	
	last_zoom_type = zoom_type
	_current_zoom_type = zoom_type
	_is_navigation_mode = is_navigation
	zoom_started.emit(zoom_type)
	
	# Останавливаем предыдущую анимацию если она ещё идёт (защита от быстрых нажатий)
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	# Останавливаем интерполяцию если она активна
	if _is_interpolating and _process_node:
		_is_interpolating = false
		if _process_node.has_method("set_process"):
			_process_node.set_process(false)
	
	# Если используется экспоненциальное сглаживание с адаптивной скоростью
	if _config.use_adaptive_interpolation:
		# Устанавливаем целевые значения
		_target_position = target_pos
		_target_zoom = target_zoom
		_target_rotation = target_rotation
		
		# Сохраняем начальное расстояние для плавного старта
		_initial_distance = _camera.position.distance_to(target_pos)
		
		# Запускаем интерполяцию
		_is_interpolating = true
		if _process_node:
			if _process_node.has_method("set_process"):
				_process_node.set_process(true)
			else:
				_process_node.set_process_mode(Node.PROCESS_MODE_ALWAYS)
		
		print("📷 CameraManager: %s (экспоненциальное сглаживание: pos %s, zoom %.1f, rotation %.1f°)" % [
			CameraAnimationHelper.get_zoom_name(zoom_type),
			target_pos,
			target_zoom.x,
			target_rotation
		])
		return
	
	# Если используется встроенное сглаживание Camera2D
	if _config.use_camera_smoothing:
		
		# Используем Tween только для zoom (так как Camera2D не имеет встроенного сглаживания для zoom)
		var tween = _scene.create_tween()
		current_tween = tween
		tween.set_parallel(false)
		
		# Используем настройки из конфигурации
		var transition_type = CameraAnimationHelper.get_transition_type(_config.transition_type)
		var ease_type = CameraAnimationHelper.get_ease_type(_config.ease_type)
		tween.set_trans(transition_type)
		tween.set_ease(ease_type)
		
		# Анимируем только zoom через Tween
		tween.tween_property(_camera, "zoom", target_zoom, _config.transition_duration)
		
		# Позицию и поворот устанавливаем напрямую - камера сама плавно движется к цели
		_camera.position = target_pos
		_camera.rotation_degrees = target_rotation
		
		# Сигнал завершения после окончания анимации zoom
		tween.finished.connect(func(): 
			current_tween = null  # Очищаем ссылку после завершения
			zoom_completed.emit(zoom_type)
		)
		
		print("📷 CameraManager: %s (zoom %.1f через Tween, pos %s, rotation %.1f° через сглаживание)" % [
			CameraAnimationHelper.get_zoom_name(zoom_type), 
			target_zoom.x,
			target_pos,
			target_rotation
		])
	else:
		# Старый способ: используем Tween для всего
		var tween = _scene.create_tween()
		current_tween = tween  # Сохраняем ссылку для возможности остановки
		tween.set_parallel(true)  # Позиция, зум и поворот меняются одновременно
		
		# Используем настройки из конфигурации
		var transition_type = CameraAnimationHelper.get_transition_type(_config.transition_type)
		var ease_type = CameraAnimationHelper.get_ease_type(_config.ease_type)
		tween.set_trans(transition_type)
		tween.set_ease(ease_type)
		
		# Используем длительность из конфигурации
		tween.tween_property(_camera, "position", target_pos, _config.transition_duration)
		tween.tween_property(_camera, "zoom", target_zoom, _config.transition_duration)
		# Устанавливаем rotation_degrees (может не работать визуально в Godot 4.5 Camera2D)
		tween.tween_property(_camera, "rotation_degrees", target_rotation, _config.transition_duration)
		print("📷 CameraManager: tween_property rotation_degrees установлен: %.1f°" % target_rotation)
		
		# Сигнал завершения после окончания анимации
		tween.finished.connect(func(): 
			var final_rotation_deg = _camera.rotation_degrees
			print("📷 CameraManager: ПОСЛЕ анимации - rotation_degrees камеры: %.1f°, ожидалось: %.1f°" % [final_rotation_deg, target_rotation])
			current_tween = null  # Очищаем ссылку после завершения
			zoom_completed.emit(zoom_type)
		)
		
		var _settings = _config.get_settings_by_type(zoom_type)
		print("📷 CameraManager: %s (zoom %.1f, pos %s, rotation %.1f°)" % [
			CameraAnimationHelper.get_zoom_name(zoom_type), 
			target_zoom.x,
			target_pos,
			target_rotation
		])

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
		"mode2_right":
			_zoom_mode2_right(is_navigation)
		"mode2_left":
			_zoom_mode2_left(is_navigation)
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
	"""Восстановить камеру к общему плану (для StateRestorer)
	
	Публичный метод для восстановления состояния камеры без анимации.
	Используется только в StateRestorer для восстановления состояния стола.
	"""
	if _camera != null and _config != null:
		var general_settings = _config.get_general_settings()
		_camera.position = general_settings.position
		_camera.zoom = general_settings.zoom
		_camera.rotation_degrees = general_settings.get("rotation", 0.0)
		is_first_deal = false
		current_area = -1  # Общий план
		last_zoom_type = "out"
		print("📷 CameraManager: камера восстановлена к общему плану")

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
	_zoom_handler = CameraZoomHandler.new(_config, animate_callback)
	
	print("📷 CameraManager: конфигурация перезагружена из %s" % _config_path)
