# res://scripts/KeyboardNavigationController.gd
# Контроллер клавиатурного управления стрелками навигации камеры
# Обрабатывает нажатия клавиш Left/Right/Up/Down для переключения между областями ставок
# АКТИВЕН ТОЛЬКО В ФАЗЕ ВЫПЛАТ (после определения победителя)
# 
# Примечание: Space обрабатывается в KeyboardFocusController и работает в обеих фазах
# WASD в фазе раздачи обрабатывается в KeyboardFocusController для управления фокусом

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Активна ли навигация (стрелки видны на экране = фаза выплат)
var is_navigation_active: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Подписываемся на изменение видимости стрелок навигации
	if EventBus:
		EventBus.navigation_arrows_visibility_changed.connect(_on_navigation_visibility_changed)
		# Подписываемся на ответы от CameraManager
		EventBus.camera_target_area_received.connect(_on_target_area_received)
	
	print("⌨️ KeyboardNavigationController инициализирован (фаза выплат: стрелки + WASD для камеры)")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ВВОДА (через EventBus)
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# Проверяем блокировки через InputContextManager
	if InputContextManager.is_blocked():
		return
	
	# Проверяем контекст (работаем только в контексте GAME)
	if not InputContextManager.can_handle(InputContextManager.InputContext.GAME):
		return
	
	# Обрабатываем когда навигация активна ИЛИ когда состояние игры WAITING (карты не открыты)
	var should_handle = is_navigation_active
	if not should_handle and GameStateManager:
		var current_state = GameStateManager.get_current_state()
		should_handle = (current_state == GameStateManager.GameState.WAITING)
	
	if not should_handle:
		return

	# Проверяем валидность события клавиатуры
	if not InputContextManager.is_valid_key_event(event):
		return
	
	var key_event = event as InputEventKey
	var direction: String = ""
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			direction = "left"
		KEY_RIGHT, KEY_D:
			direction = "right"
		KEY_UP, KEY_W:
			direction = "up"
		KEY_DOWN, KEY_S:
			direction = "down"
		_:
			return
	
	if direction != "":
		# Запрашиваем целевую область через EventBus
		_request_target_area(direction)
		get_viewport().set_input_as_handled()

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
	"""Обработка ответа от CameraManager
	
	Args:
		direction: Направление запроса
		target_area: Целевая область (-1 = общий план, 0 = карты, 1-3 = области ставок)
	"""
	if target_area > 0:
		EventBus.camera_zoom_requested.emit("area_%d" % target_area)
	elif target_area == -1:
		EventBus.camera_zoom_requested.emit("out")
	else:
		EventBus.camera_zoom_requested.emit("in")
	
	var key_name = direction.capitalize()
	var target_name = "out" if target_area == -1 else ("area_%d" % target_area if target_area > 0 else "in")
	print("⌨️ Клавиша %s → %s" % [key_name, target_name])

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_navigation_visibility_changed(visible: bool) -> void:
	"""Обработка изменения видимости стрелок навигации

	Args:
		visible: true если стрелки видны, false если скрыты
	"""
	is_navigation_active = visible

	if visible:
		print("⌨️ Навигация активирована (стрелки ←→↑↓ или клавиши WASD)")
	else:
		print("⌨️ Навигация деактивирована")

func _on_target_area_received(_direction: String, _target_area: int) -> void:
	"""Обработка ответа от CameraManager (может быть вызван из других мест)"""
	# Этот метод может использоваться для других целей, если нужно
	pass
