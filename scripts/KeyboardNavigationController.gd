# res://scripts/KeyboardNavigationController.gd
# Контроллер клавиатурного управления стрелками навигации камеры
# Обрабатывает нажатия клавиш Left/Right/A/D/Up/Down/W/S для переключения между областями ставок

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Активна ли навигация (стрелки видны на экране)
var is_navigation_active: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Подписываемся на изменение видимости стрелок навигации
	if EventBus:
		EventBus.navigation_arrows_visibility_changed.connect(_on_navigation_visibility_changed)

	print("⌨️ KeyboardNavigationController инициализирован")

func _get_camera_manager() -> CameraManager:
	"""Получить camera_manager через GameController"""
	var game = get_node_or_null("/root/Game")
	if game and game.has_method("get") and game.get("camera_manager"):
		return game.camera_manager
	return null

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ВВОДА
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# Обрабатываем только когда навигация активна
	if not is_navigation_active:
		return

	# Проверяем нажатия клавиш стрелок и A/D/W/S
	if event is InputEventKey and event.pressed and not event.echo:
		var camera_mgr = _get_camera_manager()
		if not camera_mgr:
			return  # camera_manager недоступен, пропускаем
		
		match event.keycode:
			KEY_LEFT, KEY_A:
				# Вычисляем конкретную область по направлению
				var target_area = camera_mgr.get_target_area_by_direction("left")
				if target_area > 0:
					EventBus.camera_zoom_requested.emit("area_%d" % target_area)
				else:
					EventBus.camera_zoom_requested.emit("in")
				get_viewport().set_input_as_handled()
				var key_name = "Left" if event.keycode == KEY_LEFT else "A"
				print("⌨️ Клавиша %s → area_%d" % [key_name, target_area])

			KEY_RIGHT, KEY_D:
				# Вычисляем конкретную область по направлению
				var target_area = camera_mgr.get_target_area_by_direction("right")
				if target_area > 0:
					EventBus.camera_zoom_requested.emit("area_%d" % target_area)
				else:
					EventBus.camera_zoom_requested.emit("in")
				get_viewport().set_input_as_handled()
				var key_name = "Right" if event.keycode == KEY_RIGHT else "D"
				print("⌨️ Клавиша %s → area_%d" % [key_name, target_area])

			KEY_UP, KEY_W:
				# Вычисляем конкретную область по направлению
				var target_area = camera_mgr.get_target_area_by_direction("up")
				if target_area > 0:
					EventBus.camera_zoom_requested.emit("area_%d" % target_area)
				else:
					EventBus.camera_zoom_requested.emit("in")
				get_viewport().set_input_as_handled()
				var key_name = "Up" if event.keycode == KEY_UP else "W"
				print("⌨️ Клавиша %s → area_%d" % [key_name, target_area])

			KEY_DOWN, KEY_S:
				# Вычисляем конкретную область по направлению
				var target_area = camera_mgr.get_target_area_by_direction("down")
				if target_area > 0:
					EventBus.camera_zoom_requested.emit("area_%d" % target_area)
				else:
					EventBus.camera_zoom_requested.emit("in")
				get_viewport().set_input_as_handled()
				var key_name = "Down" if event.keycode == KEY_DOWN else "S"
				print("⌨️ Клавиша %s → in (карты)" % key_name)

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
