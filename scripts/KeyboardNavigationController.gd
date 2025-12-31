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
	
	# Блокируем обработку, если шпаргалка открыта
	if _is_crib_sheet_open():
		return
	
	# Блокируем управление камерой, если активна навигация по ставкам
	# Проверяем через GameController (если доступен)
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_method("is_chip_navigation_active"):
		if game_controller.is_chip_navigation_active():
			return  # Блокируем управление камерой
	
	# Обрабатываем когда навигация активна ИЛИ когда состояние игры WAITING (карты не открыты)
	var should_handle = is_navigation_active
	if not should_handle and GameStateManager:
		var current_state = GameStateManager.get_current_state()
		should_handle = (current_state == GameStateManager.GameState.WAITING)
	
	if not should_handle:
		return

	# Отладка: логируем события геймпада
	if event is InputEventJoypadButton:
		var joypad_event = event as InputEventJoypadButton
		if joypad_event.pressed:
			DebugLogger.log("🎮 KeyboardNavigationController: геймпад кнопка %d нажата" % joypad_event.button_index)
	
	# Используем Input Actions для поддержки клавиатуры и геймпада
	# В _unhandled_input() используем event.is_action_pressed() для проверки конкретного события
	var direction: String = ""
	if event.is_action_pressed("left"):
		direction = "left"
	elif event.is_action_pressed("right"):
		direction = "right"
	elif event.is_action_pressed("up"):
		direction = "up"
	elif event.is_action_pressed("down"):
		direction = "down"
	else:
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
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _is_crib_sheet_open() -> bool:
	"""Проверить, открыта ли шпаргалка"""
	# Ищем CribSheetScene в дереве сцены
	var scene_tree = get_tree()
	if not scene_tree:
		return false
	
	# Ищем узел CribSheetScene через группу
	var crib_sheets = get_tree().get_nodes_in_group("crib_sheet")
	if crib_sheets.size() > 0:
		var crib_sheet = crib_sheets[0]
		if crib_sheet and "visible" in crib_sheet:
			return crib_sheet.visible
	
	# Если не нашли через группу, ищем по имени
	var root = scene_tree.root
	if root:
		var crib_sheet = root.find_child("CribSheetScene", true, false)
		if crib_sheet and "visible" in crib_sheet:
			return crib_sheet.visible
	
	return false

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
