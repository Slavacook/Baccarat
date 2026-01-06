# res://scripts/utils/CameraInterpolationHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК ИНТЕРПОЛЯЦИИ КАМЕРЫ
# 
# Отвечает за:
# - Экспоненциальное сглаживание камеры (_process)
# - Создание Tween анимаций
# - Управление процессом интерполяции
# ═══════════════════════════════════════════════════════════════════════════

class_name CameraInterpolationHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются через _init)
# ═══════════════════════════════════════════════════════════════════════════

var _config: CameraConfig = null
var _camera: Camera2D = null
var _scene: Node = null
var _process_node: Node = null

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ИНТЕРПОЛЯЦИИ
# ═══════════════════════════════════════════════════════════════════════════

var _is_interpolating: bool = false
var _is_navigation_mode: bool = false
var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: Vector2 = Vector2.ONE
var _target_rotation: float = 0.0
var _current_zoom_type: String = ""

# ═══════════════════════════════════════════════════════════════════════════
# КОЛБЭКИ (для уведомления о завершении)
# ═══════════════════════════════════════════════════════════════════════════

var _on_interpolation_completed: Callable = Callable()  # (zoom_type: String) -> void

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(config: CameraConfig, camera: Camera2D, scene: Node, process_node: Node, on_completed: Callable) -> void:
	"""Инициализация обработчика интерполяции
	
	Args:
		config: Конфигурация камеры
		camera: Камера для анимации
		scene: Сцена для создания Tween
		process_node: Node для обработки _process
		on_completed: Колбэк при завершении интерполяции (zoom_type: String) -> void
	"""
	_config = config
	_camera = camera
	_scene = scene
	_process_node = process_node
	_on_interpolation_completed = on_completed

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func process_interpolation(_delta: float) -> void:
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
	# 
	# _is_navigation_mode = true  → МЕДЛЕННАЯ анимация (переходы между режимами 2)
	# _is_navigation_mode = false → БЫСТРАЯ анимация (все остальные переходы)
	# 
	# Настройки находятся в CameraConfig.gd:
	#   - БЫСТРАЯ: min_interpolation_speed, max_interpolation_speed, distance_threshold, rotation_threshold
	#   - МЕДЛЕННАЯ: navigation_min_interpolation_speed, navigation_max_interpolation_speed, 
	#                navigation_distance_threshold, navigation_rotation_threshold
	var min_speed: float
	var max_speed: float
	var distance_thresh: float
	var rotation_thresh: float
	
	if _is_navigation_mode:
		# 🟢 МЕДЛЕННАЯ анимация (навигация между режимами 2: guest_1_mode2 - guest_6_mode2)
		min_speed = _config.navigation_min_interpolation_speed
		max_speed = _config.navigation_max_interpolation_speed
		distance_thresh = _config.navigation_distance_threshold
		rotation_thresh = _config.navigation_rotation_threshold
	else:
		# 🔵 БЫСТРАЯ анимация (обычные переходы: карты, области, общий план)
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
		
		# Сохраняем тип зума ДО остановки (stop_interpolation сбрасывает _current_zoom_type)
		var completed_zoom_type = _current_zoom_type
		
		# Останавливаем интерполяцию
		stop_interpolation()
		
		# Эмитим сигнал завершения (используем сохраненный тип)
		if _on_interpolation_completed.is_valid():
			_on_interpolation_completed.call(completed_zoom_type)
		print("📷 CameraInterpolationHandler: камера достигла цели через экспоненциальное сглаживание (%s)" % completed_zoom_type)

func start_interpolation(target_pos: Vector2, target_zoom: Vector2, target_rotation: float, zoom_type: String, is_navigation: bool) -> void:
	"""Запустить экспоненциальное сглаживание
	
	Args:
		target_pos: Целевая позиция
		target_zoom: Целевой зум
		target_rotation: Целевой поворот
		zoom_type: Тип зума (для логирования)
		is_navigation: true если это навигация (медленные настройки)
	"""
	if not _camera or not _config:
		return
	
	# Устанавливаем целевые значения
	_target_position = target_pos
	_target_zoom = target_zoom
	_target_rotation = target_rotation
	_current_zoom_type = zoom_type
	_is_navigation_mode = is_navigation
	
	# Запускаем интерполяцию
	_is_interpolating = true
	if _process_node:
		if _process_node.has_method("set_process"):
			_process_node.set_process(true)
		else:
			_process_node.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	print("📷 CameraInterpolationHandler: %s (экспоненциальное сглаживание: pos %s, zoom %.1f, rotation %.1f°)" % [
		CameraAnimationHelper.get_zoom_name(zoom_type),
		target_pos,
		target_zoom.x,
		target_rotation
	])

func stop_interpolation() -> void:
	"""Остановить экспоненциальное сглаживание и полностью сбросить состояние"""
	_is_interpolating = false
	_is_navigation_mode = false  # Сбрасываем режим навигации
	_current_zoom_type = ""  # Сбрасываем тип зума
	if _process_node and _process_node.has_method("set_process"):
		_process_node.set_process(false)

func create_tween_animation(
	target_pos: Vector2, 
	target_zoom: Vector2, 
	target_rotation: float, 
	zoom_type: String,
	use_camera_smoothing: bool,
	on_completed: Callable
) -> Tween:
	"""Создать Tween анимацию для камеры
	
	Args:
		target_pos: Целевая позиция
		target_zoom: Целевой зум
		target_rotation: Целевой поворот
		zoom_type: Тип зума (для логирования)
		use_camera_smoothing: true если используется встроенное сглаживание Camera2D
		on_completed: Колбэк при завершении (zoom_type: String) -> void
		
	Returns:
		Tween объект для управления анимацией
	"""
	if not _camera or not _scene or not _config:
		return null
	
	var tween: Tween = null
	
	# Если используется встроенное сглаживание Camera2D
	if use_camera_smoothing:
		# Используем Tween только для zoom (так как Camera2D не имеет встроенного сглаживания для zoom)
		tween = _scene.create_tween()
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
			if on_completed.is_valid():
				on_completed.call(zoom_type)
		)
		
		print("📷 CameraInterpolationHandler: %s (zoom %.1f через Tween, pos %s, rotation %.1f° через сглаживание)" % [
			CameraAnimationHelper.get_zoom_name(zoom_type), 
			target_zoom.x,
			target_pos,
			target_rotation
		])
	else:
		# Старый способ: используем Tween для всего
		tween = _scene.create_tween()
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
		print("📷 CameraInterpolationHandler: tween_property rotation_degrees установлен: %.1f°" % target_rotation)
		
		# Сигнал завершения после окончания анимации
		tween.finished.connect(func(): 
			var final_rotation_deg = _camera.rotation_degrees
			print("📷 CameraInterpolationHandler: ПОСЛЕ анимации - rotation_degrees камеры: %.1f°, ожидалось: %.1f°" % [final_rotation_deg, target_rotation])
			if on_completed.is_valid():
				on_completed.call(zoom_type)
		)
		
		var _settings = _config.get_settings_by_type(zoom_type)
		print("📷 CameraInterpolationHandler: %s (zoom %.1f, pos %s, rotation %.1f°)" % [
			CameraAnimationHelper.get_zoom_name(zoom_type), 
			target_zoom.x,
			target_pos,
			target_rotation
		])
	
	return tween

