# res://scripts/ui/PayoutKeyboardNavigator.gd
# Клавиатурная навигация для PayoutOverlay
# Инкапсулирует логику обработки клавиш и управления фокусом

extends RefCounted
class_name PayoutKeyboardNavigator

# ═══════════════════════════════════════════════════════════════════════════
# ENUM: Уровни и элементы фокуса
# ═══════════════════════════════════════════════════════════════════════════

enum FocusLevel {
	BOTTOM,  # Нижний уровень: фишки + кнопка "Выплатить"
	TOP      # Верхний уровень: кнопка "Подсказка"
}

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ НАВИГАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

var focus_level: FocusLevel = FocusLevel.BOTTOM
var focus_index: int = -1
var is_keyboard_active: bool = false
var focus_frame: FocusFrameUI = null

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var owner_node: Node  # Узел для создания FocusFrame
var chip_denominations: Array  # Номиналы фишек
var chip_fleet_container: Control  # Контейнер кнопок фишек
var payout_button: Button  # Кнопка выплаты
var hint_button: Button  # Кнопка подсказки
var stack_manager: ChipStackManager  # Менеджер стопок (для удаления фишек)

# ═══════════════════════════════════════════════════════════════════════════
# CALLBACK-ИНТЕРФЕЙС (функции, которые должен предоставить владелец)
# ═══════════════════════════════════════════════════════════════════════════

var on_payout_pressed_callback: Callable  # Вызывается при нажатии "Выплатить"
var on_hint_pressed_callback: Callable  # Вызывается при нажатии "Подсказка"
var on_chip_added_callback: Callable  # Вызывается при добавлении фишки (denomination: float)
var is_button_blocked_callback: Callable  # Проверка блокировки кнопки -> bool

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	owner_node_ref: Node,
	chip_denominations_ref: Array,
	chip_fleet_container_ref: Control,
	payout_button_ref: Button,
	hint_button_ref: Button,
	stack_manager_ref: ChipStackManager
):
	"""Инициализация навигатора
	
	Args:
		owner_node_ref: Узел для создания FocusFrame
		chip_denominations_ref: Массив номиналов фишек
		chip_fleet_container_ref: Контейнер кнопок фишек
		payout_button_ref: Кнопка выплаты
		hint_button_ref: Кнопка подсказки
		stack_manager_ref: Менеджер стопок
	"""
	owner_node = owner_node_ref
	chip_denominations = chip_denominations_ref
	chip_fleet_container = chip_fleet_container_ref
	payout_button = payout_button_ref
	hint_button = hint_button_ref
	stack_manager = stack_manager_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func initialize() -> void:
	"""Инициализация системы клавиатурной навигации"""
	_create_focus_frame()
	
	# Изначально навигация неактивна (управление мышью)
	is_keyboard_active = false
	focus_index = -1
	focus_level = FocusLevel.BOTTOM

func connect_mouse_handlers() -> void:
	"""Подключить обработчики мыши для сброса клавиатурного фокуса"""
	if payout_button and not payout_button.gui_input.is_connected(_on_payout_button_mouse_input):
		payout_button.gui_input.connect(_on_payout_button_mouse_input)
	if hint_button and not hint_button.gui_input.is_connected(_on_hint_button_mouse_input):
		hint_button.gui_input.connect(_on_hint_button_mouse_input)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - УПРАВЛЕНИЕ НАВИГАЦИЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func handle_navigation_input(key_event: InputEventKey) -> void:
	"""Обработка навигации клавиатурой (deprecated, используйте handle_navigation_direction)"""
	# Конвертируем keycode в направление
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
	
	if direction != "":
		handle_navigation_direction(direction)

func handle_navigation_direction(direction: String) -> void:
	"""Обработка навигации по направлению (для геймпада и клавиатуры через Input Actions)"""
	# Если навигация не активна - активируем
	if not is_keyboard_active:
		activate()
		return
	
	# Обрабатываем навигацию в зависимости от направления
	match direction:
		"left":
			navigate_left()
		"right":
			navigate_right()
		"up":
			navigate_up()
		"down":
			navigate_down()
	
	_update_focus_frame()

func handle_focus_action() -> void:
	"""Обработать действие на элементе в фокусе (пробел)"""
	if not is_keyboard_active or focus_index < 0:
		return
	
	if focus_level == FocusLevel.BOTTOM:
		if focus_index < chip_denominations.size():
			# Добавляем фишку выбранного номинала
			var denomination = chip_denominations[focus_index]
			if on_chip_added_callback.is_valid():
				on_chip_added_callback.call(denomination)
		else:
			# Нажимаем кнопку "Выплатить"
			var is_blocked = false
			if is_button_blocked_callback.is_valid():
				is_blocked = is_button_blocked_callback.call()
			if not is_blocked and not payout_button.disabled:
				if on_payout_pressed_callback.is_valid():
					on_payout_pressed_callback.call()
	elif focus_level == FocusLevel.TOP:
		# Нажимаем кнопку "Подсказка"
		if on_hint_pressed_callback.is_valid():
			on_hint_pressed_callback.call()

func clear_focus() -> void:
	"""Сбросить клавиатурный фокус (при использовании мыши)"""
	is_keyboard_active = false
	focus_index = -1
	if focus_frame:
		focus_frame.hide_frame()

func set_focus_to_payout_button() -> void:
	"""Установить фокус на кнопку выплаты (после использования подсказки)"""
	if not is_keyboard_active:
		return
	
	# ВАЖНО: НЕ используем grab_focus(), чтобы не создавать системную рамку фокуса Godot
	# Просто обновляем внутреннее состояние навигатора и показываем нашу рамку
	focus_level = FocusLevel.BOTTOM
	# Индекс кнопки выплаты = размер массива фишек (фишки: 0..size-1, выплата: size)
	focus_index = chip_denominations.size()
	
	# Убираем системный фокус с кнопки, если он был установлен
	if payout_button:
		payout_button.release_focus()
	
	_update_focus_frame()
	DebugLogger.log("⌨️ Фокус установлен на кнопку выплаты (индекс: %d)" % focus_index)

func activate() -> void:
	"""Активировать клавиатурную навигацию"""
	if is_keyboard_active:
		return
	
	# Проверка безопасности: если chip_denominations пуст, не активируем навигацию
	if chip_denominations.is_empty():
		push_warning("PayoutKeyboardNavigator: Невозможно активировать навигацию - chip_denominations пуст")
		return
	
	# ВАЖНО: Убираем системный фокус со всех элементов, чтобы не было конфликтов с нашей рамкой
	_release_all_focus()
	
	is_keyboard_active = true
	focus_level = FocusLevel.BOTTOM
	# Устанавливаем фокус на 5-ю фишку (индекс 4, так как начинается с 0)
	focus_index = 4
	if focus_index >= chip_denominations.size():
		# Если фишек меньше 5, берем последнюю
		focus_index = chip_denominations.size() - 1
	if focus_index < 0:
		focus_index = 0
	
	_update_focus_frame()

func _release_all_focus() -> void:
	"""Убрать системный фокус со всех элементов, чтобы не было конфликтов с нашей рамкой"""
	if payout_button:
		payout_button.release_focus()
	if hint_button:
		hint_button.release_focus()
	if chip_fleet_container:
		for child in chip_fleet_container.get_children():
			if child is Control:
				(child as Control).release_focus()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - НАВИГАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func navigate_left() -> void:
	"""Навигация влево (предыдущий элемент на текущем уровне)"""
	if focus_level == FocusLevel.BOTTOM:
		# На нижнем уровне: фишки + кнопка выплатить
		var total_items = chip_denominations.size() + 1  # +1 для кнопки выплатить
		focus_index = (focus_index - 1 + total_items) % total_items
		# Звук переключения между фишками
		if SoundManager:
			SoundManager.play_payout_chip_navigation_sound()
	elif focus_level == FocusLevel.TOP:
		# На верхнем уровне только кнопка подсказки (ничего не делаем)
		pass

func navigate_right() -> void:
	"""Навигация вправо (следующий элемент на текущем уровне)"""
	if focus_level == FocusLevel.BOTTOM:
		# На нижнем уровне: фишки + кнопка выплатить
		var total_items = chip_denominations.size() + 1  # +1 для кнопки выплатить
		focus_index = (focus_index + 1) % total_items
		# Звук переключения между фишками
		if SoundManager:
			SoundManager.play_payout_chip_navigation_sound()
	elif focus_level == FocusLevel.TOP:
		# На верхнем уровне только кнопка подсказки (ничего не делаем)
		pass

func navigate_up() -> void:
	"""Навигация вверх (переключение на верхний уровень)"""
	if focus_level == FocusLevel.BOTTOM:
		# Переходим на верхний уровень (кнопка подсказки)
		focus_level = FocusLevel.TOP
		focus_index = 0  # На верхнем уровне только один элемент
		# Звук переключения между фишками
		if SoundManager:
			SoundManager.play_payout_chip_navigation_sound()

func navigate_down() -> void:
	"""Навигация вниз (переключение на нижний уровень или удаление фишки)"""
	if focus_level == FocusLevel.BOTTOM:
		# Если фокус на фишке - удаляем фишку этого номинала
		if focus_index < chip_denominations.size():
			var denomination = chip_denominations[focus_index]
			# Проверяем, есть ли стек с таким номиналом перед удалением
			var has_stack = false
			for stack in stack_manager.get_stacks():
				if stack.denomination == denomination:
					has_stack = true
					break
			if has_stack:
				stack_manager.remove_chip(denomination)
				# Звук деактивации (удаления фишки)
				if SoundManager:
					SoundManager.play_focus_deactivate_sound()
	elif focus_level == FocusLevel.TOP:
		# Переходим на нижний уровень
		focus_level = FocusLevel.BOTTOM
		# Сохраняем последний индекс или устанавливаем на 5-ю фишку
		if focus_index < 0 or focus_index >= chip_denominations.size() + 1:
			focus_index = 4
			if focus_index >= chip_denominations.size():
				focus_index = chip_denominations.size() - 1
			if focus_index < 0:
				focus_index = 0
		# Звук переключения между фишками
		if SoundManager:
			SoundManager.play_payout_chip_navigation_sound()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - FOCUS FRAME
# ═══════════════════════════════════════════════════════════════════════════

func _create_focus_frame() -> void:
	"""Создать FocusFrameUI для PayoutOverlay (в том же CanvasLayer)"""
	if focus_frame:
		return  # Уже создан
	
	# Проверяем, нет ли уже FocusFrame в owner_node
	var existing = owner_node.find_child("PayoutFocusFrame", true, false)
	if existing:
		focus_frame = existing as FocusFrameUI
		_remove_duplicate_focus_frames(existing)
		return
	
	# Создаём новый FocusFrameUI
	focus_frame = FocusFrameUI.new()
	focus_frame.name = "PayoutFocusFrame"
	focus_frame.z_index = 1000
	
	# Добавляем в корневой элемент (ColorRect), чтобы рамка была в той же системе координат
	var color_rect = owner_node.get_node_or_null("ColorRect")
	var parent = color_rect if color_rect else owner_node
	parent.add_child(focus_frame)

func _remove_duplicate_focus_frames(keep_frame: Node) -> void:
	"""Удалить все дубликаты PayoutFocusFrame, кроме указанного"""
	if not owner_node or not keep_frame:
		return
	
	var color_rect = owner_node.get_node_or_null("ColorRect")
	var search_root = color_rect if color_rect else owner_node
	
	# Рекурсивно ищем и удаляем все PayoutFocusFrame, кроме keep_frame
	_remove_duplicates_recursive(search_root, keep_frame)

func _remove_duplicates_recursive(node: Node, keep_frame: Node) -> void:
	"""Рекурсивно найти и удалить все PayoutFocusFrame, кроме keep_frame"""
	if node.name == "PayoutFocusFrame" and node != keep_frame:
		node.queue_free()
		return
	
	for child in node.get_children():
		_remove_duplicates_recursive(child, keep_frame)

func _update_focus_frame() -> void:
	"""Обновить позицию рамки фокуса"""
	if not is_keyboard_active or focus_index < 0:
		if focus_frame:
			focus_frame.hide_frame()
		return
	
	if not focus_frame:
		_create_focus_frame()
	
	if not focus_frame:
		return
	
	var target_node: Control = null
	
	if focus_level == FocusLevel.BOTTOM:
		if focus_index < chip_denominations.size():
			# Фокус на фишке
			var chip_buttons = chip_fleet_container.get_children()
			if focus_index < chip_buttons.size():
				target_node = chip_buttons[focus_index] as Control
		else:
			# Фокус на кнопке "Выплатить"
			target_node = payout_button
	elif focus_level == FocusLevel.TOP:
		# Фокус на кнопке "Подсказка"
		target_node = hint_button
	
	if target_node:
		focus_frame.show_on_node(target_node)
	else:
		focus_frame.hide_frame()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - ОБРАБОТЧИКИ МЫШИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_payout_button_mouse_input(event: InputEvent) -> void:
	"""Обработка ввода мыши на кнопке выплаты"""
	if event is InputEventMouseButton and event.pressed:
		clear_focus()

func _on_hint_button_mouse_input(event: InputEvent) -> void:
	"""Обработка ввода мыши на кнопке подсказки"""
	if event is InputEventMouseButton and event.pressed:
		clear_focus()
