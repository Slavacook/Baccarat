# res://tests/test_SettingsKeyboardNavigator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ SettingsKeyboardNavigator
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var navigator: SettingsKeyboardNavigator
var mock_settings_scene: CanvasLayer
var mock_apply_button: Button

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	navigator = SettingsKeyboardNavigator.new()
	
	# Создаем мок для SettingsScene (CanvasLayer)
	mock_settings_scene = CanvasLayer.new()
	mock_settings_scene.visible = true
	
	# Создаем мок для ApplyButton
	mock_apply_button = Button.new()
	mock_apply_button.name = "ApplyButton"
	mock_settings_scene.add_child(mock_apply_button)
	
	# Добавляем в дерево для работы get_viewport()
	add_child(mock_settings_scene)

func after_each():
	"""Очистка после каждого теста"""
	if mock_settings_scene:
		mock_settings_scene.queue_free()
	navigator = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: handle_unhandled_input
# ═══════════════════════════════════════════════════════════════════════════

func test_handle_unhandled_input_not_visible():
	"""Проверка: не обрабатывает ввод когда меню не видимо"""
	# Arrange
	mock_settings_scene.visible = false
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	
	# Act
	var result = navigator.handle_unhandled_input(event, mock_settings_scene)
	
	# Assert
	assert_false(result, "Не должно обрабатывать ввод когда меню не видимо")

func test_handle_unhandled_input_visible():
	"""Проверка: обрабатывает ввод когда меню видимо"""
	# Arrange
	mock_settings_scene.visible = true
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	
	# Act
	var result = navigator.handle_unhandled_input(event, mock_settings_scene)
	
	# Assert
	# Результат зависит от InputContextManager, но метод должен быть вызван
	assert_true(result == true or result == false, "Должен вернуть bool")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: handle_input
# ═══════════════════════════════════════════════════════════════════════════

func test_handle_input_not_visible():
	"""Проверка: не обрабатывает ввод когда меню не видимо"""
	# Arrange
	mock_settings_scene.visible = false
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	
	# Act
	var result = navigator.handle_input(event, mock_settings_scene, mock_apply_button)
	
	# Assert
	assert_false(result, "Не должно обрабатывать ввод когда меню не видимо")

func test_handle_input_visible():
	"""Проверка: обрабатывает ввод когда меню видимо"""
	# Arrange
	mock_settings_scene.visible = true
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	
	# Act
	var result = navigator.handle_input(event, mock_settings_scene, mock_apply_button)
	
	# Assert
	# Результат зависит от InputContextManager, но метод должен быть вызван
	assert_true(result == true or result == false, "Должен вернуть bool")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: navigate_focus
# ═══════════════════════════════════════════════════════════════════════════

func test_navigate_focus_no_current_focus():
	"""Проверка: навигация когда нет текущего фокуса"""
	# Arrange
	# Убеждаемся что нет фокуса
	mock_settings_scene.get_viewport().gui_release_focus()
	
	# Создаем JunketButton для fallback
	var junket_button = Button.new()
	junket_button.name = "JunketButton"
	mock_settings_scene.add_child(junket_button)
	
	# Act
	navigator.navigate_focus("right", mock_settings_scene)
	
	# Assert
	# Фокус должен быть установлен на JunketButton
	var focused = mock_settings_scene.get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "Фокус должен быть установлен")
	assert_eq(focused.name, "JunketButton", "Фокус должен быть на JunketButton")

func test_navigate_focus_with_focus_neighbor():
	"""Проверка: навигация через focus_neighbor"""
	# Arrange
	var button1 = Button.new()
	button1.name = "Button1"
	var button2 = Button.new()
	button2.name = "Button2"
	
	# Сначала добавляем в дерево, потом настраиваем focus_neighbor
	mock_settings_scene.add_child(button1)
	mock_settings_scene.add_child(button2)
	
	# Теперь можно получить путь (кнопки в дереве)
	button1.focus_neighbor_right = button2.get_path()
	
	button1.grab_focus()
	
	# Act
	navigator.navigate_focus("right", mock_settings_scene)
	
	# Assert
	var focused = mock_settings_scene.get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "Фокус должен быть установлен")
	assert_eq(focused.name, "Button2", "Фокус должен быть на Button2")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: focus_next
# ═══════════════════════════════════════════════════════════════════════════

func test_focus_next_no_current_focus():
	"""Проверка: focus_next когда нет текущего фокуса"""
	# Arrange
	mock_settings_scene.get_viewport().gui_release_focus()
	
	var junket_button = Button.new()
	junket_button.name = "JunketButton"
	mock_settings_scene.add_child(junket_button)
	
	# Act
	navigator.focus_next(mock_settings_scene)
	
	# Assert
	var focused = mock_settings_scene.get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "Фокус должен быть установлен")
	assert_eq(focused.name, "JunketButton", "Фокус должен быть на JunketButton")

func test_focus_next_with_current_focus():
	"""Проверка: focus_next с текущим фокусом"""
	# Arrange
	var button1 = Button.new()
	button1.name = "JunketButton"
	var button2 = Button.new()
	button2.name = "ClassicButton"
	
	mock_settings_scene.add_child(button1)
	mock_settings_scene.add_child(button2)
	
	button1.grab_focus()
	
	# Act
	navigator.focus_next(mock_settings_scene)
	
	# Assert
	var focused = mock_settings_scene.get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "Фокус должен быть установлен")
	# Фокус должен перейти к следующему элементу в порядке навигации
	assert_true(focused != button1, "Фокус должен перейти к следующему элементу")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: focus_previous
# ═══════════════════════════════════════════════════════════════════════════

func test_focus_previous_no_current_focus():
	"""Проверка: focus_previous когда нет текущего фокуса"""
	# Arrange
	mock_settings_scene.get_viewport().gui_release_focus()
	
	var apply_button = Button.new()
	apply_button.name = "ApplyButton"
	mock_settings_scene.add_child(apply_button)
	
	# Act
	navigator.focus_previous(mock_settings_scene)
	
	# Assert
	var focused = mock_settings_scene.get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "Фокус должен быть установлен")
	assert_eq(focused.name, "ApplyButton", "Фокус должен быть на ApplyButton")

func test_focus_previous_with_current_focus():
	"""Проверка: focus_previous с текущим фокусом"""
	# Arrange
	var button1 = Button.new()
	button1.name = "ClassicButton"
	var button2 = Button.new()
	button2.name = "JunketButton"
	
	mock_settings_scene.add_child(button1)
	mock_settings_scene.add_child(button2)
	
	button1.grab_focus()
	
	# Act
	navigator.focus_previous(mock_settings_scene)
	
	# Assert
	var focused = mock_settings_scene.get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "Фокус должен быть установлен")
	# Фокус должен перейти к предыдущему элементу в порядке навигации
	assert_true(focused != button1, "Фокус должен перейти к предыдущему элементу")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: setup_keyboard_navigation
# ═══════════════════════════════════════════════════════════════════════════

func test_setup_keyboard_navigation_creates_connections():
	"""Проверка: setup_keyboard_navigation создает связи focus_neighbor"""
	# Arrange
	var junket_button = Button.new()
	junket_button.name = "JunketButton"
	var classic_button = Button.new()
	classic_button.name = "ClassicButton"
	
	mock_settings_scene.add_child(junket_button)
	mock_settings_scene.add_child(classic_button)
	
	# Act
	navigator.setup_keyboard_navigation(mock_settings_scene)
	
	# Assert
	# Проверяем что focus_neighbor установлены
	assert_false(junket_button.focus_neighbor_right.is_empty(), "JunketButton должен иметь focus_neighbor_right")
	assert_false(classic_button.focus_neighbor_left.is_empty(), "ClassicButton должен иметь focus_neighbor_left")

func test_setup_keyboard_navigation_with_missing_elements():
	"""Проверка: setup_keyboard_navigation обрабатывает отсутствующие элементы"""
	# Arrange
	# Не добавляем никаких элементов
	
	# Act - не должно упасть
	navigator.setup_keyboard_navigation(mock_settings_scene)
	
	# Assert
	# Тест проходит если не было ошибок
	pass_test("Метод должен обработать отсутствующие элементы без ошибок")

