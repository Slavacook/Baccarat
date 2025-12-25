# res://scripts/SwipeNavigationController.gd
# Контроллер свайпов для навигации камеры
# Обрабатывает свайпы (touch/mouse drag) для переключения между областями ставок
# АКТИВЕН ТОЛЬКО В ФАЗЕ ВЫПЛАТ (после определения победителя)

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

## Минимальная дистанция свайпа (в пикселях) для регистрации
const MIN_SWIPE_DISTANCE: float = 50.0

## Минимальная скорость свайпа (пиксели в секунду) для регистрации
const MIN_SWIPE_VELOCITY: float = 200.0

## Максимальная дистанция по перпендикулярной оси (для определения направления)
const MAX_PERPENDICULAR_DISTANCE: float = 100.0

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Активна ли навигация (стрелки видны на экране = фаза выплат)
var is_navigation_active: bool = false

## Флаг открытых настроек (блокирует весь ввод)
var _settings_open: bool = false

## Состояние свайпа
var _swipe_start_position: Vector2 = Vector2.ZERO
var _swipe_start_time: float = 0.0
var _is_swiping: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Подписываемся на изменение видимости стрелок навигации
	if EventBus:
		EventBus.navigation_arrows_visibility_changed.connect(_on_navigation_visibility_changed)
		# Подписываемся на ответы от CameraManager (для логирования/отладки)
		EventBus.camera_target_area_received.connect(_on_target_area_received)
		# Подписываемся на открытие/закрытие настроек
		EventBus.settings_opened.connect(func(): _settings_open = true)
		EventBus.settings_closed.connect(func(): _settings_open = false)
	
	print("👆 SwipeNavigationController инициализирован (фаза выплат: свайпы для камеры)")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ВВОДА
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# Блокируем ввод когда настройки открыты
	if _settings_open:
		return
	
	# Обрабатываем только когда навигация активна
	if not is_navigation_active:
		return
	
	# Обработка touch событий (мобильные устройства)
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	
	# Обработка drag событий (touch drag на мобильных)
	if event is InputEventScreenDrag:
		_handle_drag_event(event)
	
	# Обработка мыши (для десктопа - drag-and-drop)
	if event is InputEventMouseButton:
		_handle_mouse_button_event(event)
	
	if event is InputEventMouseMotion:
		_handle_mouse_motion_event(event)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА TOUCH СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_touch_event(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Начало касания
		_swipe_start_position = event.position
		_swipe_start_time = Time.get_ticks_msec() / 1000.0
		_is_swiping = true
	else:
		# Конец касания - проверяем на свайп
		# Позиция события всегда актуальна при отпускании
		if _is_swiping:
			_handle_swipe_end(event.position)
			_is_swiping = false

func _handle_drag_event(event: InputEventScreenDrag) -> void:
	# Обновляем последнюю позицию во время drag
	if _is_swiping:
		_last_mouse_position = event.position

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА МЫШИ (для десктопа)
# ═══════════════════════════════════════════════════════════════════════════

func _handle_mouse_button_event(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Начало drag
			_swipe_start_position = event.position
			_swipe_start_time = Time.get_ticks_msec() / 1000.0
			_is_swiping = true
			_last_mouse_position = event.position
		else:
			# Конец drag - проверяем на свайп
			if _is_swiping:
				_handle_swipe_end(event.position)
				_is_swiping = false

func _handle_mouse_motion_event(event: InputEventMouseMotion) -> void:
	# Обновляем последнюю позицию во время движения мыши
	if _is_swiping:
		_last_mouse_position = event.position

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СВАЙПА
# ═══════════════════════════════════════════════════════════════════════════

func _handle_swipe_end(end_position: Vector2) -> void:
	_is_swiping = false
	
	var swipe_vector: Vector2 = end_position - _swipe_start_position
	var swipe_distance: float = swipe_vector.length()
	
	# Проверяем минимальную дистанцию
	if swipe_distance < MIN_SWIPE_DISTANCE:
		return
	
	# Проверяем скорость свайпа
	var swipe_duration: float = (Time.get_ticks_msec() / 1000.0) - _swipe_start_time
	if swipe_duration <= 0.0:
		return
	
	var swipe_velocity: float = swipe_distance / swipe_duration
	if swipe_velocity < MIN_SWIPE_VELOCITY:
		return
	
	# Определяем направление свайпа
	var direction: String = _determine_swipe_direction(swipe_vector)
	if direction != "":
		# Запрашиваем целевую область через EventBus (как в KeyboardNavigationController)
		_request_target_area(direction)
		get_viewport().set_input_as_handled()

func _determine_swipe_direction(swipe_vector: Vector2) -> String:
	"""Определить направление свайпа на основе вектора
	
	Args:
		swipe_vector: Вектор от начальной до конечной позиции
	
	Returns:
		Направление: "left", "right", "up", "down" или "" если не определено
	"""
	var abs_x: float = abs(swipe_vector.x)
	var abs_y: float = abs(swipe_vector.y)
	
	# Определяем, какая ось преобладает
	if abs_x > abs_y:
		# Горизонтальный свайп (ИНВЕРТИРОВАН)
		# Проверяем, что вертикальное отклонение не слишком большое
		if abs_y <= MAX_PERPENDICULAR_DISTANCE:
			if swipe_vector.x < 0:
				return "right"  # Свайп влево → навигация вправо
			else:
				return "left"   # Свайп вправо → навигация влево
	else:
		# Вертикальный свайп (ИНВЕРТИРОВАН)
		# Проверяем, что горизонтальное отклонение не слишком большое
		if abs_x <= MAX_PERPENDICULAR_DISTANCE:
			if swipe_vector.y < 0:
				return "down"   # Свайп вверх → навигация вниз
			else:
				return "up"     # Свайп вниз → навигация вверх
	
	return ""

# ═══════════════════════════════════════════════════════════════════════════
# ЗАПРОС НАВИГАЦИИ (как в KeyboardNavigationController)
# ═══════════════════════════════════════════════════════════════════════════

func _request_target_area(direction: String) -> void:
	"""Запросить целевую область через EventBus
	
	Args:
		direction: "left", "right", "up", "down"
	"""
	# Создаём временную подписку на ответ (одноразово)
	var response_handler = func(dir: String, area: int):
		if dir == direction:
			_handle_target_area_response(direction, area)
			# CONNECT_ONE_SHOT автоматически отписывает после первого вызова
	
	EventBus.camera_target_area_received.connect(response_handler, CONNECT_ONE_SHOT)
	EventBus.camera_target_area_requested.emit(direction)

func _handle_target_area_response(direction: String, target_area: int) -> void:
	"""Обработка ответа от CameraManager"""
	if target_area > 0:
		EventBus.camera_zoom_requested.emit("area_%d" % target_area)
	elif target_area == -1:
		EventBus.camera_zoom_requested.emit("out")
	else:
		EventBus.camera_zoom_requested.emit("in")
	
	var direction_name = direction.capitalize()
	var target_name = "out" if target_area == -1 else ("area_%d" % target_area if target_area > 0 else "in")
	print("👆 Свайп %s → %s" % [direction_name, target_name])

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_navigation_visibility_changed(visible: bool) -> void:
	"""Обработка изменения видимости стрелок навигации"""
	is_navigation_active = visible
	
	if visible:
		print("👆 Навигация свайпами активирована")
	else:
		print("👆 Навигация свайпами деактивирована")
		# Сбрасываем состояние свайпа при деактивации
		_is_swiping = false

func _on_target_area_received(_direction: String, _target_area: int) -> void:
	"""Обработка ответа от CameraManager (может быть вызван из других мест)"""
	pass

