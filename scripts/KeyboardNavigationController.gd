# res://scripts/KeyboardNavigationController.gd
# Контроллер клавиатурного управления стрелками навигации камеры
# Обрабатывает нажатия клавиш Left/Right для переключения между областями ставок

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

	# Проверяем нажатия клавиш стрелок
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				# Переключение на предыдущую область
				EventBus.camera_zoom_requested.emit("prev_area")
				get_viewport().set_input_as_handled()
				print("⌨️ Клавиша Left → prev_area")

			KEY_RIGHT:
				# Переключение на следующую область
				EventBus.camera_zoom_requested.emit("next_area")
				get_viewport().set_input_as_handled()
				print("⌨️ Клавиша Right → next_area")

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
		print("⌨️ Навигация активирована (стрелки Left/Right)")
	else:
		print("⌨️ Навигация деактивирована")
