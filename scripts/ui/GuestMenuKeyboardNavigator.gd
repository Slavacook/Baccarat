# res://scripts/ui/GuestMenuKeyboardNavigator.gd
# Клавиатурная навигация для меню гостей
# Инкапсулирует логику обработки клавиш и переходов между уровнями

extends RefCounted
class_name GuestMenuKeyboardNavigator

# ═══════════════════════════════════════════════════════════════════════════
# ENUM: Уровни навигации
# ═══════════════════════════════════════════════════════════════════════════

enum NavigationLevel {
	OK_BUTTON = 1,           # Кнопка OK
	WEALTH_OPTION = 2,       # Выбор обеспеченности
	CHARACTER_OPTION = 3,    # Выбор характера
	GUESTS = 4               # Уровень гостей
}

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ НАВИГАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

var current_level: NavigationLevel = NavigationLevel.GUESTS
var focused_guest_id: int = 0
var is_active: bool = false
var is_dropdown_open: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# CALLBACK-ИНТЕРФЕЙС (функции, которые должен предоставить владелец)
# ═══════════════════════════════════════════════════════════════════════════

# Callback для проверки видимости досье
var check_dossier_visible_callback: Callable

# Callback для получения выбранного гостя
var get_selected_guest_id_callback: Callable

# Callback для проверки, включён ли гость
var is_guest_enabled_callback: Callable

# Callback для обновления видимости UI
var update_visibility_callback: Callable

# Callback для перехода на уровень (уровень уже изменён в навигаторе)
var navigate_to_level_callback: Callable

# Callback для навигации по гостям горизонтально
var navigate_guests_horizontal_callback: Callable

# Callback для переключения между включёнными гостями
var switch_enabled_guests_callback: Callable

# Callback для активации гостя
var activate_guest_callback: Callable

# Callback для активации кнопки досье
var activate_dossier_button_callback: Callable

# Callback для активации кнопки OK
var activate_ok_button_callback: Callable

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func reset():
	"""Сбросить состояние навигации"""
	current_level = NavigationLevel.GUESTS
	focused_guest_id = 0
	is_active = false
	is_dropdown_open = false

func activate(selected_guest_id: int):
	"""Активировать режим клавиатуры (старый метод для обратной совместимости)"""
	activate_with_level(NavigationLevel.GUESTS, selected_guest_id)

func activate_with_level(level: NavigationLevel, guest_id: int):
	"""Активировать режим клавиатуры с указанным уровнем и ID гостя"""
	is_active = true
	
	# Проверяем доступность уровней 2 и 3 (OptionButton доступны только если досье видно)
	var target_level = level
	if target_level == NavigationLevel.WEALTH_OPTION or target_level == NavigationLevel.CHARACTER_OPTION:
		var dossier_visible = _is_dossier_visible()
		if not dossier_visible:
			# Уровни 2 и 3 недоступны, переключаемся на доступный уровень
			if target_level == NavigationLevel.WEALTH_OPTION:
				target_level = NavigationLevel.GUESTS
			elif target_level == NavigationLevel.CHARACTER_OPTION:
				target_level = NavigationLevel.OK_BUTTON
	
	current_level = target_level
	
	# Устанавливаем focused_guest_id в зависимости от уровня
	if target_level == NavigationLevel.GUESTS:
		# Если есть выбранный гость, фокус на нём, иначе на госте 1
		if guest_id > 0:
			focused_guest_id = guest_id
		else:
			focused_guest_id = 1
	else:
		# Для других уровней сохраняем ID гостя (может быть 0)
		focused_guest_id = guest_id
	
	# Обновляем видимость
	if update_visibility_callback.is_valid():
		update_visibility_callback.call()

func deactivate():
	"""Деактивировать режим клавиатуры"""
	is_active = false
	current_level = NavigationLevel.GUESTS
	focused_guest_id = 0
	is_dropdown_open = false
	
	# Обновляем видимость
	if update_visibility_callback.is_valid():
		update_visibility_callback.call()

func handle_input(key_event: InputEventKey) -> bool:
	"""Обработать клавиатурный ввод. Возвращает true если событие обработано"""
	if not key_event.pressed or key_event.echo:
		return false
	
	# Проверяем, открыто ли выпадающее меню (должен вызываться извне перед handle_input)
	# Здесь мы просто проверяем состояние
	
	# Если выпадающее меню открыто, обрабатываем только навигацию по пунктам
	if is_dropdown_open:
		# Встроенная навигация OptionButton обработает ↑/↓/W/S и SPACE
		# Мы только игнорируем ←/→/A/D
		if key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
			return true
		return false
	
	# Проверяем, нужно ли активировать режим клавиатуры
	if not is_active:
		# Активируем при первом нажатии стрелок/WASD
		if key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]:
			# Активация должна быть вызвана извне с правильным selected_guest_id
			return false
	
	# Обрабатываем клавиши только в активном режиме
	if not is_active:
		return false
	
	# Обрабатываем навигацию
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			_handle_left()
			return true
		KEY_RIGHT, KEY_D:
			_handle_right()
			return true
		KEY_UP, KEY_W:
			_handle_up()
			return true
		KEY_DOWN, KEY_S:
			_handle_down()
			return true
		KEY_SPACE:
			_handle_space()
			return true
	
	return false

func set_dropdown_open(open: bool):
	"""Установить состояние выпадающего меню (вызывается извне)"""
	is_dropdown_open = open
	if not open and update_visibility_callback.is_valid():
		update_visibility_callback.call()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_left() -> void:
	"""Обработка нажатия ← или A"""
	match current_level:
		NavigationLevel.GUESTS:
			if navigate_guests_horizontal_callback.is_valid():
				navigate_guests_horizontal_callback.call(-1)
		NavigationLevel.CHARACTER_OPTION, NavigationLevel.WEALTH_OPTION:
			if switch_enabled_guests_callback.is_valid():
				switch_enabled_guests_callback.call(-1)
		NavigationLevel.OK_BUTTON:
			pass  # Игнорируем

func _handle_right() -> void:
	"""Обработка нажатия → или D"""
	match current_level:
		NavigationLevel.GUESTS:
			if navigate_guests_horizontal_callback.is_valid():
				navigate_guests_horizontal_callback.call(1)
		NavigationLevel.CHARACTER_OPTION, NavigationLevel.WEALTH_OPTION:
			if switch_enabled_guests_callback.is_valid():
				switch_enabled_guests_callback.call(1)
		NavigationLevel.OK_BUTTON:
			pass  # Игнорируем

func _handle_up() -> void:
	"""Обработка нажатия ↑ или W"""
	match current_level:
		NavigationLevel.GUESTS:
			_navigate_to_level(NavigationLevel.OK_BUTTON)
		NavigationLevel.CHARACTER_OPTION:
			# Переход на уровень гостей (на текущего гостя, чьё досье открыто)
			if _is_dossier_visible():
				var selected_id = _get_selected_guest_id()
				if selected_id > 0:
					focused_guest_id = selected_id
			_navigate_to_level(NavigationLevel.GUESTS)
		NavigationLevel.WEALTH_OPTION:
			_navigate_to_level(NavigationLevel.CHARACTER_OPTION)
		NavigationLevel.OK_BUTTON:
			# Если досье видно → уровень 2, иначе → уровень 4 (на гостя 1)
			if _is_dossier_visible():
				_navigate_to_level(NavigationLevel.WEALTH_OPTION)
			else:
				focused_guest_id = 1
				_navigate_to_level(NavigationLevel.GUESTS)

func _handle_down() -> void:
	"""Обработка нажатия ↓ или S"""
	match current_level:
		NavigationLevel.GUESTS:
			# Если гость включён → уровень 3, иначе → уровень 1
			if focused_guest_id > 0 and _is_guest_enabled(focused_guest_id):
				_navigate_to_level(NavigationLevel.CHARACTER_OPTION)
			else:
				_navigate_to_level(NavigationLevel.OK_BUTTON)
		NavigationLevel.CHARACTER_OPTION:
			_navigate_to_level(NavigationLevel.WEALTH_OPTION)
		NavigationLevel.WEALTH_OPTION:
			_navigate_to_level(NavigationLevel.OK_BUTTON)
		NavigationLevel.OK_BUTTON:
			# Всегда переход на уровень гостей (закольцовывание)
			_navigate_to_level(NavigationLevel.GUESTS)

func _handle_space() -> void:
	"""Обработка нажатия SPACE"""
	match current_level:
		NavigationLevel.GUESTS:
			if activate_guest_callback.is_valid():
				activate_guest_callback.call()
		NavigationLevel.CHARACTER_OPTION, NavigationLevel.WEALTH_OPTION:
			if activate_dossier_button_callback.is_valid():
				activate_dossier_button_callback.call()
		NavigationLevel.OK_BUTTON:
			if activate_ok_button_callback.is_valid():
				activate_ok_button_callback.call()

func _navigate_to_level(target_level: NavigationLevel) -> void:
	"""Переход на указанный уровень с учётом доступности"""
	# Проверяем доступность уровней 2 и 3
	if target_level == NavigationLevel.WEALTH_OPTION or target_level == NavigationLevel.CHARACTER_OPTION:
		var dossier_visible = _is_dossier_visible()
		if not dossier_visible:
			# Уровни 2 и 3 недоступны, пропускаем их
			if target_level == NavigationLevel.WEALTH_OPTION:
				target_level = NavigationLevel.GUESTS
			elif target_level == NavigationLevel.CHARACTER_OPTION:
				target_level = NavigationLevel.OK_BUTTON
	
	# Специальная логика для перехода с уровня 1 вниз
	if current_level == NavigationLevel.OK_BUTTON and target_level == NavigationLevel.GUESTS:
		var dossier_visible = _is_dossier_visible()
		if dossier_visible:
			var selected_id = _get_selected_guest_id()
			if selected_id > 0:
				focused_guest_id = selected_id
		else:
			focused_guest_id = 1
	
	# Выполняем переход
	current_level = target_level
	
	# Уведомляем через callback
	if navigate_to_level_callback.is_valid():
		navigate_to_level_callback.call(current_level)

func _is_dossier_visible() -> bool:
	"""Проверить, видно ли досье"""
	if check_dossier_visible_callback.is_valid():
		return check_dossier_visible_callback.call()
	return false

func _get_selected_guest_id() -> int:
	"""Получить ID выбранного гостя"""
	if get_selected_guest_id_callback.is_valid():
		return get_selected_guest_id_callback.call()
	return 0

func _is_guest_enabled(guest_id: int) -> bool:
	"""Проверить, включён ли гость"""
	if is_guest_enabled_callback.is_valid():
		return is_guest_enabled_callback.call(guest_id)
	return false

