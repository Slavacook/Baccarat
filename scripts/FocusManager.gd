# res://scripts/FocusManager.gd
# Autoload singleton для управления клавиатурной навигацией
extends Node

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

const BORDER_COLOR = Color(1.0, 0.9, 0.3)  # Золотой
const BORDER_WIDTH = 3
const FADE_DURATION = 0.15  # Длительность появления/исчезновения рамки

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var is_keyboard_mode: bool = false  # Активен ли режим клавиатурного управления
var focus_highlight: Panel = null   # Рамка вокруг активного элемента
var current_level: int = 1          # Текущий уровень (1-3)
var current_index: int = 0          # Текущая позиция на уровне

# Структура навигации для главного экрана
var game_navigation = {
	1: [],  # Уровень 1: Карты, ? банкиру, ? игроку
	2: [],  # Уровень 2: Banker, Tie, Player
	3: []   # Уровень 3: Подсказка, Настройки, Ставка игрока, Ставка банкира, Ставка ничьей
}

var _tween: Tween = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Создаём рамку фокуса
	_create_focus_highlight()

	print("🎮 FocusManager инициализирован")


func _input(event: InputEvent):
	# Обработка переключения режимов
	if event is InputEventKey:
		if not event.pressed:
			return

		# Активируем клавиатурный режим при нажатии стрелок/WASD
		if not is_keyboard_mode:
			if _is_navigation_key(event):
				_activate_keyboard_mode()
				return

		# Обработка навигации в клавиатурном режиме
		if is_keyboard_mode:
			_handle_keyboard_input(event)

	elif event is InputEventMouseButton:
		# Деактивируем при клике мыши
		if event.pressed and is_keyboard_mode:
			_deactivate_keyboard_mode()


# ═══════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ РАМКИ
# ═══════════════════════════════════════════════════════════════════════════

func _create_focus_highlight():
	focus_highlight = Panel.new()
	focus_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_highlight.z_index = 1000  # Поверх всего

	# Стиль рамки
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Прозрачный фон
	style.border_color = BORDER_COLOR
	style.border_width_left = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	focus_highlight.add_theme_stylebox_override("panel", style)
	focus_highlight.modulate.a = 0.0  # Скрыта по умолчанию
	focus_highlight.visible = false


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ РЕЖИМАМИ
# ═══════════════════════════════════════════════════════════════════════════

func _activate_keyboard_mode():
	is_keyboard_mode = true
	print("⌨️  Клавиатурный режим активирован")
	_show_highlight()


func _deactivate_keyboard_mode():
	is_keyboard_mode = false
	print("🖱️  Мышиный режим активирован")
	_hide_highlight()


# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИЯ РАМКИ
# ═══════════════════════════════════════════════════════════════════════════

func _show_highlight():
	if not focus_highlight:
		return

	focus_highlight.visible = true

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(focus_highlight, "modulate:a", 1.0, FADE_DURATION)

	_update_highlight_position()


func _hide_highlight():
	if not focus_highlight:
		return

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(focus_highlight, "modulate:a", 0.0, FADE_DURATION)
	_tween.tween_callback(func(): focus_highlight.visible = false)


# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ ПОЗИЦИИ РАМКИ
# ═══════════════════════════════════════════════════════════════════════════

func _update_highlight_position():
	if not is_keyboard_mode or not focus_highlight:
		return

	var current_elements = game_navigation.get(current_level, [])
	if current_elements.is_empty():
		return

	# Получаем текущий элемент
	if current_index >= current_elements.size():
		current_index = 0

	var target_node = current_elements[current_index]
	if not is_instance_valid(target_node):
		return

	# Позиционируем рамку вокруг элемента
	var rect = target_node.get_global_rect()
	focus_highlight.global_position = rect.position - Vector2(BORDER_WIDTH, BORDER_WIDTH)
	focus_highlight.size = rect.size + Vector2(BORDER_WIDTH * 2, BORDER_WIDTH * 2)


# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ВВОДА
# ═══════════════════════════════════════════════════════════════════════════

func _handle_keyboard_input(event: InputEventKey):
	var key = event.keycode

	# Вертикальная навигация (вверх/вниз или W/S)
	if key == KEY_UP or key == KEY_W:
		_navigate_vertical(-1)  # На уровень выше
	elif key == KEY_DOWN or key == KEY_S:
		_navigate_vertical(1)   # На уровень ниже

	# Горизонтальная навигация (влево/вправо или A/D)
	elif key == KEY_LEFT or key == KEY_A:
		_navigate_horizontal(-1)  # Влево
	elif key == KEY_RIGHT or key == KEY_D:
		_navigate_horizontal(1)   # Вправо

	# Подтверждение (пробел)
	elif key == KEY_SPACE:
		_activate_current_element()


func _navigate_vertical(direction: int):
	# Переключение между уровнями: вверх = выше уровень, вниз = ниже уровень
	# direction: -1 = вверх (уровень увеличивается), +1 = вниз (уровень уменьшается)
	current_level -= direction  # Инвертируем: вверх = +1 уровень, вниз = -1 уровень
	current_level = clampi(current_level, 1, 3)  # Ограничение 1-3
	current_index = 0  # Сбрасываем позицию на уровне
	_update_highlight_position()
	print("📍 Уровень: %d, Позиция: %d" % [current_level, current_index])


func _navigate_horizontal(direction: int):
	# Переключение внутри уровня
	var current_elements = game_navigation.get(current_level, [])
	if current_elements.is_empty():
		return

	current_index += direction

	# Уровень 2 (маркеры) - без цикла, только Banker ↔ Tie ↔ Player
	if current_level == 2:
		current_index = clampi(current_index, 0, current_elements.size() - 1)
	else:
		# Остальные уровни - циклическое переключение
		if current_index < 0:
			current_index = current_elements.size() - 1
		elif current_index >= current_elements.size():
			current_index = 0

	_update_highlight_position()
	print("📍 Уровень: %d, Позиция: %d" % [current_level, current_index])


func _activate_current_element():
	var current_elements = game_navigation.get(current_level, [])
	if current_elements.is_empty():
		return

	if current_index >= current_elements.size():
		return

	var element = current_elements[current_index]
	if not is_instance_valid(element):
		return

	# Эмулируем клик на элемент
	if element is BaseButton:
		element.emit_signal("pressed")
		print("✅ Активирован элемент: %s" % element.name)
	elif element is TextureRect:
		# Для toggles третьих карт - эмулируем gui_input
		var fake_event = InputEventMouseButton.new()
		fake_event.button_index = MOUSE_BUTTON_LEFT
		fake_event.pressed = true
		element.emit_signal("gui_input", fake_event)
		print("✅ Активирован toggle: %s" % element.name)


# ═══════════════════════════════════════════════════════════════════════════
# НАВИГАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _is_navigation_key(event: InputEventKey) -> bool:
	return event.keycode in [
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
		KEY_W, KEY_S, KEY_A, KEY_D,
		KEY_SPACE
	]


# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Зарегистрировать элементы навигации для уровня
func register_level(level: int, elements: Array):
	game_navigation[level] = elements
	print("🎮 Уровень %d: зарегистрировано %d элементов" % [level, elements.size()])


## Очистить навигацию (при смене сцены)
func clear_navigation():
	game_navigation[1].clear()
	game_navigation[2].clear()
	game_navigation[3].clear()
	_deactivate_keyboard_mode()


## Добавить рамку в сцену (вызывается из GameController)
func attach_highlight_to_scene(parent: Node):
	if focus_highlight and not focus_highlight.get_parent():
		parent.add_child(focus_highlight)
		print("🎮 Рамка фокуса добавлена в сцену")
