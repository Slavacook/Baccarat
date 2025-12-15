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

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ВВОДА
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# Обрабатываем только когда навигация активна
	if not is_navigation_active:
		return

	# Проверяем нажатия клавиш стрелок и A/D/W/S
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				# Переключение на предыдущую область
				EventBus.camera_zoom_requested.emit("prev_area")
				get_viewport().set_input_as_handled()
				var key_name = "Left" if event.keycode == KEY_LEFT else "A"
				print("⌨️ Клавиша %s → prev_area" % key_name)

			KEY_RIGHT, KEY_D:
				# Переключение на следующую область
				EventBus.camera_zoom_requested.emit("next_area")
				get_viewport().set_input_as_handled()
				var key_name = "Right" if event.keycode == KEY_RIGHT else "D"
				print("⌨️ Клавиша %s → next_area" % key_name)

			KEY_UP, KEY_W:
				# Вертикальная навигация вверх (карты → area_2)
				EventBus.camera_zoom_requested.emit("up")
				get_viewport().set_input_as_handled()
				var key_name = "Up" if event.keycode == KEY_UP else "W"
				print("⌨️ Клавиша %s → up" % key_name)

			KEY_DOWN, KEY_S:
				# Вертикальная навигация вниз (area → карты)
				EventBus.camera_zoom_requested.emit("down")
				get_viewport().set_input_as_handled()
				var key_name = "Down" if event.keycode == KEY_DOWN else "S"
				print("⌨️ Клавиша %s → down" % key_name)

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
