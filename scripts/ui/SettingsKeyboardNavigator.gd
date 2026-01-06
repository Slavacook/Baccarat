# res://scripts/ui/SettingsKeyboardNavigator.gd
# Навигатор клавиатуры для SettingsScene
# 
# Отвечает за:
# - Обработку ввода (клавиатура и геймпад)
# - Навигацию по элементам меню
# - Настройку focus_neighbor для элементов

class_name SettingsKeyboardNavigator

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func handle_unhandled_input(event: InputEvent, settings_scene: CanvasLayer) -> bool:
	"""Обработка ввода для навигации
	
	Args:
		event: Событие ввода
		settings_scene: Сцена настроек для проверки видимости и получения viewport
		
	Returns:
		true если событие обработано, false иначе
	"""
	# Обрабатываем только когда меню видимо
	if not settings_scene.visible:
		return false
	
	# Проверяем блокировки через InputContextManager
	if InputContextManager.is_blocked():
		return false
	
	# Проверяем контекст
	if not InputContextManager.can_handle(InputContextManager.InputContext.MENU_SETTINGS):
		return false
	
	# Escape/Exit в меню → закрыть меню (работает для клавиатуры и геймпада)
	if event.is_action_pressed("exit"):
		if settings_scene.has_method("close_settings"):
			settings_scene.close_settings()
		settings_scene.get_viewport().set_input_as_handled()
		return true
	
	# Навигация стрелками/WASD/геймпадом
	# Используем focus_neighbor для автоматической навигации
	if event.is_action_pressed("left"):
		navigate_focus("left", settings_scene)
		settings_scene.get_viewport().set_input_as_handled()
		return true
	elif event.is_action_pressed("right"):
		navigate_focus("right", settings_scene)
		settings_scene.get_viewport().set_input_as_handled()
		return true
	elif event.is_action_pressed("up"):
		navigate_focus("up", settings_scene)
		settings_scene.get_viewport().set_input_as_handled()
		return true
	elif event.is_action_pressed("down"):
		navigate_focus("down", settings_scene)
		settings_scene.get_viewport().set_input_as_handled()
		return true
	
	return false


func handle_input(event: InputEvent, settings_scene: CanvasLayer, apply_button: Button) -> bool:
	"""Обработка ввода для перехвата Escape и action
	
	Args:
		event: Событие ввода
		settings_scene: Сцена настроек
		apply_button: Кнопка Apply для проверки фокуса
		
	Returns:
		true если событие обработано, false иначе
	"""
	# Обрабатываем только когда меню видимо
	if not settings_scene.visible:
		return false
	
	# Проверяем контекст напрямую (не используем can_handle, так как оно проверяет блокировку)
	# Настройки должны обрабатывать ввод независимо от блокировки
	if InputContextManager.get_context() != InputContextManager.InputContext.MENU_SETTINGS:
		return false
	
	# Escape/Exit в меню → закрыть меню (работает для клавиатуры и геймпада, даже если фокус на кнопке)
	if event.is_action_pressed("exit"):
		if settings_scene.has_method("close_settings"):
			settings_scene.close_settings()
		settings_scene.get_viewport().set_input_as_handled()
		return true
	
	# Action (Space/Enter/геймпад кнопка 2) - обрабатываем в _input чтобы перехватить раньше
	# Проверяем как через action, так и напрямую через событие геймпада
	var is_action = event.is_action_pressed("action")
	var is_gamepad_button_2 = false
	
	# Дополнительная проверка для геймпада (кнопка 2 = button_index 2 в project.godot)
	if event is InputEventJoypadButton:
		var joypad_event = event as InputEventJoypadButton
		# В project.godot указан button_index=2 для action
		if joypad_event.pressed and joypad_event.button_index == 2:
			is_gamepad_button_2 = true
	
	if is_action or is_gamepad_button_2:
		var focused = settings_scene.get_viewport().gui_get_focus_owner()
		if focused:
			# Если это кнопка Apply (ОК) - закрываем меню
			if focused == apply_button:
				if settings_scene.has_method("close_settings"):
					settings_scene.close_settings()
				settings_scene.get_viewport().set_input_as_handled()
				return true
			
			# Если это кнопка - нажимаем её
			if focused is Button:
				var button = focused as Button
				# Для toggle кнопок - переключаем состояние
				if button.toggle_mode:
					button.button_pressed = !button.button_pressed
					# Эмитим сигнал toggled для toggle кнопок
					button.toggled.emit(button.button_pressed)
				else:
					# Для обычных кнопок - эмитим pressed
					button.pressed.emit()
			# Если это SpinBox - активируем его для редактирования
			elif focused is SpinBox:
				var spinbox = focused as SpinBox
				spinbox.grab_focus()
			settings_scene.get_viewport().set_input_as_handled()
			return true
	
	return false


func navigate_focus(direction: String, settings_scene: CanvasLayer) -> void:
	"""Навигация по меню с помощью стрелок/WASD/геймпада
	
	Использует встроенную систему focus_neighbor для навигации.
	Если focus_neighbor не настроен, использует циклическую навигацию.
	
	Args:
		direction: Направление ("left", "right", "up", "down")
		settings_scene: Сцена настроек для получения viewport
	"""
	var current_focus = settings_scene.get_viewport().gui_get_focus_owner()
	if not current_focus:
		# Если нет фокуса, устанавливаем на первую кнопку
		var junket_button = settings_scene.find_child("JunketButton", true, false)
		if junket_button:
			junket_button.grab_focus()
		return
	
	# Используем встроенную систему focus_neighbor для навигации
	# Получаем соседний элемент через focus_neighbor
	var neighbor_path: NodePath = NodePath("")
	
	match direction:
		"left":
			neighbor_path = current_focus.focus_neighbor_left
		"right":
			neighbor_path = current_focus.focus_neighbor_right
		"up":
			neighbor_path = current_focus.focus_neighbor_top
		"down":
			neighbor_path = current_focus.focus_neighbor_bottom
	
	# Если нашли соседа через focus_neighbor - переходим к нему
	if neighbor_path and not neighbor_path.is_empty():
		var next_focus = settings_scene.get_node_or_null(neighbor_path) as Control
		if next_focus:
			next_focus.grab_focus()
			return
	
	# Fallback: если focus_neighbor не настроен, используем циклическую навигацию
	match direction:
		"left", "up":
			focus_previous(settings_scene)
		"right", "down":
			focus_next(settings_scene)


func focus_next(settings_scene: CanvasLayer) -> void:
	"""Перейти к следующему элементу меню
	
	Args:
		settings_scene: Сцена настроек для получения элементов
	"""
	var current_focus = settings_scene.get_viewport().gui_get_focus_owner()
	if not current_focus:
		var junket_button = settings_scene.find_child("JunketButton", true, false)
		if junket_button:
			junket_button.grab_focus()
		return
	
	# Список всех элементов в порядке навигации
	var navigation_order = [
		settings_scene.find_child("JunketButton", true, false),
		settings_scene.find_child("ClassicButton", true, false),
		settings_scene.find_child("BetPlayerButton", true, false),
		settings_scene.find_child("BetBankerButton", true, false),
		settings_scene.find_child("BetTieButton", true, false),
		settings_scene.find_child("BetPairButton", true, false),
		settings_scene.find_child("GuestSettingsButton", true, false),
		settings_scene.find_child("TipPercentageSpinBox", true, false),
		settings_scene.find_child("RuButton", true, false),
		settings_scene.find_child("EnButton", true, false),
		settings_scene.find_child("TigerButton", true, false),
		settings_scene.find_child("LeopardButton", true, false),
		settings_scene.find_child("TestCardsButton", true, false),
		settings_scene.find_child("ApplyButton", true, false)
	]
	
	# Убираем null элементы
	navigation_order = navigation_order.filter(func(item): return item != null)
	
	# Находим текущий индекс
	var current_index = -1
	for i in range(navigation_order.size()):
		if navigation_order[i] == current_focus:
			current_index = i
			break
	
	# Переходим к следующему элементу (с закольцовыванием)
	var next_index = (current_index + 1) % navigation_order.size()
	if navigation_order[next_index]:
		navigation_order[next_index].grab_focus()


func focus_previous(settings_scene: CanvasLayer) -> void:
	"""Перейти к предыдущему элементу меню
	
	Args:
		settings_scene: Сцена настроек для получения элементов
	"""
	var current_focus = settings_scene.get_viewport().gui_get_focus_owner()
	if not current_focus:
		var apply_button = settings_scene.find_child("ApplyButton", true, false)
		if apply_button:
			apply_button.grab_focus()
		return
	
	# Список всех элементов в порядке навигации
	var navigation_order = [
		settings_scene.find_child("JunketButton", true, false),
		settings_scene.find_child("ClassicButton", true, false),
		settings_scene.find_child("BetPlayerButton", true, false),
		settings_scene.find_child("BetBankerButton", true, false),
		settings_scene.find_child("BetTieButton", true, false),
		settings_scene.find_child("BetPairButton", true, false),
		settings_scene.find_child("GuestSettingsButton", true, false),
		settings_scene.find_child("TipPercentageSpinBox", true, false),
		settings_scene.find_child("RuButton", true, false),
		settings_scene.find_child("EnButton", true, false),
		settings_scene.find_child("TigerButton", true, false),
		settings_scene.find_child("LeopardButton", true, false),
		settings_scene.find_child("TestCardsButton", true, false),
		settings_scene.find_child("ApplyButton", true, false)
	]
	
	# Убираем null элементы
	navigation_order = navigation_order.filter(func(item): return item != null)
	
	# Находим текущий индекс
	var current_index = -1
	for i in range(navigation_order.size()):
		if navigation_order[i] == current_focus:
			current_index = i
			break
	
	# Переходим к предыдущему элементу (с закольцовыванием)
	var prev_index = (current_index - 1 + navigation_order.size()) % navigation_order.size()
	if navigation_order[prev_index]:
		navigation_order[prev_index].grab_focus()


func setup_keyboard_navigation(settings_scene: CanvasLayer) -> void:
	"""Настроить навигацию с клавиатуры между элементами меню
	
	Устанавливает focus_neighbor для всех элементов меню,
	создавая сетку навигации с тремя колонками:
	- Левая: Режим игры
	- Средняя: Фильтр ставок
	- Правая: Чаевые, Язык, Рубашка
	
	Args:
		settings_scene: Сцена настроек для получения элементов
	"""
	var junket_button = settings_scene.find_child("JunketButton", true, false)
	var classic_button = settings_scene.find_child("ClassicButton", true, false)
	var bet_player_button = settings_scene.find_child("BetPlayerButton", true, false)
	var bet_banker_button = settings_scene.find_child("BetBankerButton", true, false)
	var bet_tie_button = settings_scene.find_child("BetTieButton", true, false)
	var bet_pair_button = settings_scene.find_child("BetPairButton", true, false)
	var guest_settings_button = settings_scene.find_child("GuestSettingsButton", true, false)
	var tip_percentage_spinbox = settings_scene.find_child("TipPercentageSpinBox", true, false)
	var ru_button = settings_scene.find_child("RuButton", true, false)
	var en_button = settings_scene.find_child("EnButton", true, false)
	var tiger_button = settings_scene.find_child("TigerButton", true, false)
	var leopard_button = settings_scene.find_child("LeopardButton", true, false)
	var test_cards_button = settings_scene.find_child("TestCardsButton", true, false)
	var apply_button = settings_scene.find_child("ApplyButton", true, false)
	
	# ЛЕВАЯ КОЛОНКА: Режим игры
	if junket_button and classic_button:
		# Junket → Classic (вправо)
		junket_button.focus_neighbor_right = classic_button.get_path()
		# Classic → Junket (влево)
		classic_button.focus_neighbor_left = junket_button.get_path()
		# Junket → BetPlayer (вниз)
		junket_button.focus_neighbor_bottom = bet_player_button.get_path() if bet_player_button else NodePath("")
		# Classic → BetPlayer (вниз)
		classic_button.focus_neighbor_bottom = bet_player_button.get_path() if bet_player_button else NodePath("")
	
	# СРЕДНЯЯ КОЛОНКА: Фильтр ставок
	if bet_player_button:
		# BetPlayer → Junket (вверх)
		bet_player_button.focus_neighbor_top = junket_button.get_path() if junket_button else NodePath("")
		# BetPlayer → BetBanker (вниз)
		bet_player_button.focus_neighbor_bottom = bet_banker_button.get_path() if bet_banker_button else NodePath("")
		# BetPlayer → TipPercentageSpinBox (вправо)
		bet_player_button.focus_neighbor_right = tip_percentage_spinbox.get_path() if tip_percentage_spinbox else NodePath("")
	
	if bet_banker_button:
		# BetBanker → BetPlayer (вверх)
		bet_banker_button.focus_neighbor_top = bet_player_button.get_path() if bet_player_button else NodePath("")
		# BetBanker → BetTie (вниз)
		bet_banker_button.focus_neighbor_bottom = bet_tie_button.get_path() if bet_tie_button else NodePath("")
		# BetBanker → TipPercentageSpinBox (вправо)
		bet_banker_button.focus_neighbor_right = tip_percentage_spinbox.get_path() if tip_percentage_spinbox else NodePath("")
	
	if bet_tie_button:
		# BetTie → BetBanker (вверх)
		bet_tie_button.focus_neighbor_top = bet_banker_button.get_path() if bet_banker_button else NodePath("")
		# BetTie → BetPair (вниз)
		bet_tie_button.focus_neighbor_bottom = bet_pair_button.get_path() if bet_pair_button else NodePath("")
		# BetTie → RuButton (вправо)
		bet_tie_button.focus_neighbor_right = ru_button.get_path() if ru_button else NodePath("")
	
	if bet_pair_button:
		# BetPair → BetTie (вверх)
		bet_pair_button.focus_neighbor_top = bet_tie_button.get_path() if bet_tie_button else NodePath("")
		# BetPair → GuestSettingsButton (вниз)
		bet_pair_button.focus_neighbor_bottom = guest_settings_button.get_path() if guest_settings_button else NodePath("")
		# BetPair → RuButton (вправо)
		bet_pair_button.focus_neighbor_right = ru_button.get_path() if ru_button else NodePath("")
	
	if guest_settings_button:
		# GuestSettingsButton → BetPair (вверх)
		guest_settings_button.focus_neighbor_top = bet_pair_button.get_path() if bet_pair_button else NodePath("")
		# GuestSettingsButton → ApplyButton (вниз)
		guest_settings_button.focus_neighbor_bottom = apply_button.get_path() if apply_button else NodePath("")
		# GuestSettingsButton → TigerButton (вправо)
		guest_settings_button.focus_neighbor_right = tiger_button.get_path() if tiger_button else NodePath("")
	
	# ПРАВАЯ КОЛОНКА: Чаевые, Язык, Рубашка
	if tip_percentage_spinbox:
		# TipPercentageSpinBox → BetPlayer (влево)
		tip_percentage_spinbox.focus_neighbor_left = bet_player_button.get_path() if bet_player_button else NodePath("")
		# TipPercentageSpinBox → RuButton (вниз)
		tip_percentage_spinbox.focus_neighbor_bottom = ru_button.get_path() if ru_button else NodePath("")
	
	if ru_button and en_button:
		# RuButton → EnButton (вправо)
		ru_button.focus_neighbor_right = en_button.get_path()
		# EnButton → RuButton (влево)
		en_button.focus_neighbor_left = ru_button.get_path()
		# RuButton → TipPercentageSpinBox (вверх)
		ru_button.focus_neighbor_top = tip_percentage_spinbox.get_path() if tip_percentage_spinbox else NodePath("")
		# EnButton → TipPercentageSpinBox (вверх)
		en_button.focus_neighbor_top = tip_percentage_spinbox.get_path() if tip_percentage_spinbox else NodePath("")
		# RuButton → TigerButton (вниз)
		ru_button.focus_neighbor_bottom = tiger_button.get_path() if tiger_button else NodePath("")
		# EnButton → TigerButton (вниз)
		en_button.focus_neighbor_bottom = tiger_button.get_path() if tiger_button else NodePath("")
	
	if tiger_button and leopard_button:
		# TigerButton → LeopardButton (вправо)
		tiger_button.focus_neighbor_right = leopard_button.get_path()
		# LeopardButton → TigerButton (влево)
		leopard_button.focus_neighbor_left = tiger_button.get_path()
		# TigerButton → RuButton (вверх)
		tiger_button.focus_neighbor_top = ru_button.get_path() if ru_button else NodePath("")
		# LeopardButton → RuButton (вверх)
		leopard_button.focus_neighbor_top = ru_button.get_path() if ru_button else NodePath("")
		# TigerButton → TestCardsButton (вниз)
		tiger_button.focus_neighbor_bottom = test_cards_button.get_path() if test_cards_button else NodePath("")
		# LeopardButton → TestCardsButton (вниз)
		leopard_button.focus_neighbor_bottom = test_cards_button.get_path() if test_cards_button else NodePath("")
	
	if test_cards_button:
		# TestCardsButton → TigerButton (вверх)
		test_cards_button.focus_neighbor_top = tiger_button.get_path() if tiger_button else NodePath("")
		# TestCardsButton → ApplyButton (вниз)
		test_cards_button.focus_neighbor_bottom = apply_button.get_path() if apply_button else NodePath("")
	
	# КНОПКА ПРИМЕНЕНИЯ
	if apply_button:
		# ApplyButton → GuestSettingsButton (вверх)
		apply_button.focus_neighbor_top = guest_settings_button.get_path() if guest_settings_button else NodePath("")
		# ApplyButton → TestCardsButton (вверх, альтернативный путь)
		if apply_button.focus_neighbor_top.is_empty():
			apply_button.focus_neighbor_top = test_cards_button.get_path() if test_cards_button else NodePath("")
		# ApplyButton → JunketButton (закольцовывание вверх)
		# Это позволит Tab циклически переходить по меню

