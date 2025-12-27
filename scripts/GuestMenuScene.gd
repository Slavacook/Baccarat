# res://scripts/GuestMenuScene.gd
# Визуальное меню настроек гостей на основе PNG изображений
# Заменяет старый GuestSettingsPopup

extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ - СЛОИ
# ═══════════════════════════════════════════════════════════════════════════

# Фон (стол)
@onready var background_layer: Control = find_child("BackgroundLayer", true, false)
@onready var table_texture: TextureRect = find_child("TableTexture", true, false)

# Слои визуальных элементов
@onready var ghosts_layer: Control = find_child("GhostsLayer", true, false)
@onready var guests_layer: Control = find_child("GuestsLayer", true, false)
@onready var hover_glows_layer: Control = find_child("HoverGlowsLayer", true, false)
@onready var dossiers_layer: Control = find_child("DossiersLayer", true, false)

# Кликабельные зоны
@onready var clickable_zones_layer: Control = find_child("ClickableZonesLayer", true, false)

# UI элементы
@onready var ui_layer: Control = find_child("UILayer", true, false)
@onready var ok_button: Button = find_child("OKButton", true, false)

# ═══════════════════════════════════════════════════════════════════════════
# МАССИВЫ УЗЛОВ ДЛЯ 6 ГОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════

# Призраки (guest_ghost_1-6.png)
var ghost_textures: Array[TextureRect] = []

# Материальные гости (guest_1-6.png)
var guest_textures: Array[TextureRect] = []

# Свечения hover (select_guest_1-6.png)
var hover_glow_textures: Array[TextureRect] = []

# Досье (dossier_guest_1-6.png)
var dossier_textures: Array[TextureRect] = []

# Label для баланса (внутри досье)
var balance_labels: Array[Label] = []

# Кликабельные зоны (Control узлы)
var guest_slots: Array[Control] = []

# Общие кнопки для настройки выбранного гостя (на верхнем слое)
@onready var character_option: OptionButton = find_child("CharacterOption", true, false)
@onready var wealth_option: OptionButton = find_child("WealthOption", true, false)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

# Состояние меню (инкапсулирует selected_guest_id и hovered_guest_id)
var menu_state: GuestMenuState

# Клавиатурный навигатор (инкапсулирует логику навигации)
var keyboard_navigator: GuestMenuKeyboardNavigator

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Скрываем при старте
	hide()
	
	# Инициализируем массивы узлов для всех 6 гостей
	_initialize_guest_nodes()
	
	# Инициализируем состояние меню
	_initialize_menu_state()
	
	# Инициализируем клавиатурный навигатор
	_initialize_keyboard_navigator()
	
	# Подключаем сигналы
	_connect_signals()
	
	# Подписываемся на изменения
	EventBus.language_changed.connect(_on_language_changed)
	GuestStatsManager.guest_balance_changed.connect(_on_guest_balance_changed)
	GuestSettingsManager.guest_settings_changed.connect(_on_guest_settings_changed)
	
	# Обновляем тексты
	_update_texts()
	
	print("👥 GuestMenuScene готов")

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ СОСТОЯНИЯ МЕНЮ
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_menu_state():
	"""Инициализировать состояние меню"""
	menu_state = GuestMenuState.new()
	menu_state.state_changed_callback = _update_all_guests_visibility

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ КЛАВИАТУРНОГО НАВИГАТОРА
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_keyboard_navigator():
	"""Инициализировать клавиатурный навигатор с callbacks"""
	keyboard_navigator = GuestMenuKeyboardNavigator.new()
	
	# Устанавливаем все необходимые callbacks
	keyboard_navigator.check_dossier_visible_callback = _is_dossier_visible
	keyboard_navigator.get_selected_guest_id_callback = func(): return menu_state.get_selected_guest()
	keyboard_navigator.is_guest_enabled_callback = _is_guest_enabled_for_navigator
	keyboard_navigator.update_visibility_callback = _update_all_guests_visibility
	keyboard_navigator.navigate_to_level_callback = _on_navigator_level_changed
	keyboard_navigator.navigate_guests_horizontal_callback = _on_navigator_guests_horizontal
	keyboard_navigator.switch_enabled_guests_callback = _on_navigator_switch_enabled_guests
	keyboard_navigator.activate_guest_callback = _on_navigator_activate_guest
	keyboard_navigator.activate_dossier_button_callback = _on_navigator_activate_dossier_button
	keyboard_navigator.activate_ok_button_callback = _on_navigator_activate_ok_button

func _is_guest_enabled_for_navigator(guest_id: int) -> bool:
	"""Проверка для навигатора - включён ли гость"""
	return GuestSettingsManager.is_guest_enabled(guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ УЗЛОВ
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_guest_nodes():
	"""Инициализировать массивы узлов для всех 6 гостей"""
	ghost_textures.clear()
	guest_textures.clear()
	hover_glow_textures.clear()
	dossier_textures.clear()
	balance_labels.clear()
	guest_slots.clear()
	
	for guest_id in range(1, 7):
		# Призраки
		var ghost = ghosts_layer.get_node_or_null("Ghost%d" % guest_id) as TextureRect
		if ghost:
			ghost_textures.append(ghost)
		else:
			ghost_textures.append(null)
			push_warning("GuestMenuScene: не найден Ghost%d" % guest_id)
		
		# Материальные гости
		var guest = guests_layer.get_node_or_null("Guest%d" % guest_id) as TextureRect
		if guest:
			guest_textures.append(guest)
		else:
			guest_textures.append(null)
			push_warning("GuestMenuScene: не найден Guest%d" % guest_id)
		
		# Свечения hover
		var hover_glow = hover_glows_layer.get_node_or_null("HoverGlow%d" % guest_id) as TextureRect
		if hover_glow:
			hover_glow_textures.append(hover_glow)
		else:
			hover_glow_textures.append(null)
			push_warning("GuestMenuScene: не найден HoverGlow%d" % guest_id)
		
		# Досье
		var dossier = dossiers_layer.get_node_or_null("Dossier%d" % guest_id) as TextureRect
		if dossier:
			dossier_textures.append(dossier)
		else:
			dossier_textures.append(null)
			push_warning("GuestMenuScene: не найден Dossier%d" % guest_id)
		
		# Label для баланса
		var balance_label = dossiers_layer.get_node_or_null("Dossier%d/BalanceLabel%d" % [guest_id, guest_id]) as Label
		if not balance_label:
			balance_label = dossier.get_node_or_null("BalanceLabel%d" % guest_id) as Label if dossier else null
		if balance_label:
			balance_labels.append(balance_label)
		else:
			balance_labels.append(null)
			push_warning("GuestMenuScene: не найден BalanceLabel%d" % guest_id)
		
		# Кликабельные зоны
		var slot = clickable_zones_layer.get_node_or_null("GuestSlot%d" % guest_id) as Control
		if slot:
			guest_slots.append(slot)
		else:
			guest_slots.append(null)
			push_warning("GuestMenuScene: не найден GuestSlot%d" % guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# ПОДКЛЮЧЕНИЕ СИГНАЛОВ
# ═══════════════════════════════════════════════════════════════════════════

func _connect_signals():
	"""Подключить все сигналы"""
	# Кнопка ОК
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	
	# Кликабельные зоны (hover и клики)
	for i in range(guest_slots.size()):
		var slot = guest_slots[i]
		if slot:
			var guest_id = i + 1
			slot.mouse_entered.connect(_on_guest_slot_mouse_entered.bind(guest_id))
			slot.mouse_exited.connect(_on_guest_slot_mouse_exited.bind(guest_id))
			slot.gui_input.connect(_on_guest_slot_gui_input.bind(guest_id))
	
	# Общие OptionButton для характера и обеспеченности
	if character_option:
		character_option.item_selected.connect(_on_character_selected)
	
	if wealth_option:
		wealth_option.item_selected.connect(_on_wealth_selected)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func open_menu():
	"""Открыть меню настроек гостей"""
	# Если меню уже видимо, не сбрасываем состояние (чтобы не потерять выбранного гостя)
	if visible:
		return
	
	# Сбрасываем состояние только если меню было скрыто
	if menu_state:
		menu_state.reset()
	
	# Сбрасываем состояние клавиатуры через навигатор
	if keyboard_navigator:
		keyboard_navigator.reset()
	
	# Обновляем видимость всех элементов
	_update_all_guests_visibility()
	
	# Инициализируем OptionButton (если они пустые)
	_initialize_option_buttons()
	
	# Обновляем значения OptionButton
	_update_all_option_buttons()
	
	# Обновляем балансы
	_update_all_balances()
	
	# Показываем меню
	show()

func close_menu():
	"""Закрыть меню"""
	if keyboard_navigator:
		keyboard_navigator.deactivate()
	hide()

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func _update_all_guests_visibility():
	"""Обновить видимость всех гостей на основе их состояния"""
	for guest_id in range(1, 7):
		_update_guest_visibility(guest_id)
	
	# Обновляем видимость общих кнопок после обновления всех гостей
	_update_common_buttons_visibility()

func _update_guest_visibility(guest_id: int):
	"""Обновить видимость одного гостя (guest_id: 1-6)"""
	var index = guest_id - 1
	if index < 0 or index >= 6:
		return
	
	if not menu_state:
		return
	
	var guest = GuestSettingsManager.get_guest(guest_id)
	var is_enabled = guest.enabled
	var is_selected = menu_state.get_selected_guest() == guest_id
	
	# Призрак: виден если гость выключен ИЛИ если гость включён и выбран (для эффекта свечения)
	if ghost_textures[index]:
		ghost_textures[index].visible = not is_enabled or (is_enabled and is_selected)
		# Прозрачность: 25% если выключен, 100% если выбран (для эффекта свечения)
		if not is_enabled:
			ghost_textures[index].modulate.a = 0.25
		elif is_enabled and is_selected:
			ghost_textures[index].modulate.a = 1.0
	
	# Материальный гость: виден если гость включён
	if guest_textures[index]:
		guest_textures[index].visible = is_enabled
	
	# Hover свечение: видно если наведён курсор ИЛИ если это focused_guest_id в режиме клавиатуры на уровне 4
	if hover_glow_textures[index]:
		var show_hover = (menu_state.get_hovered_guest() == guest_id)
		if keyboard_navigator and keyboard_navigator.is_active:
			if keyboard_navigator.current_level == GuestMenuKeyboardNavigator.NavigationLevel.GUESTS:
				show_hover = show_hover or (keyboard_navigator.focused_guest_id == guest_id)
		hover_glow_textures[index].visible = show_hover
	
	# Досье: видно только для выбранного включённого гостя
	if dossier_textures[index]:
		dossier_textures[index].visible = is_enabled and is_selected

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ UI ЭЛЕМЕНТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_option_buttons():
	"""Инициализировать общие OptionButton элементами (если они пустые)"""
	# OptionButton для характера
	if character_option and character_option.get_item_count() == 0:
		character_option.add_item(Localization.t("GUEST_CHARACTER_GENTLEMAN"))
		character_option.add_item(Localization.t("GUEST_CHARACTER_CAUTIOUS"))
		character_option.add_item(Localization.t("GUEST_CHARACTER_GAMBLER"))
	
	# OptionButton для обеспеченности
	if wealth_option and wealth_option.get_item_count() == 0:
		wealth_option.add_item(Localization.t("GUEST_WEALTH_POOR"))
		wealth_option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
		wealth_option.add_item(Localization.t("GUEST_WEALTH_RICH"))

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ ОБЩИХ КНОПОК
# ═══════════════════════════════════════════════════════════════════════════

func _update_common_buttons_visibility():
	"""Обновить видимость общих кнопок (видны только если есть выбранный включённый гость)"""
	if not menu_state:
		return
	
	var selected_id = menu_state.get_selected_guest()
	var has_selected_guest = (selected_id > 0) and GuestSettingsManager.is_guest_enabled(selected_id)
	
	if character_option:
		character_option.visible = has_selected_guest
	
	if wealth_option:
		wealth_option.visible = has_selected_guest

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ UI ЭЛЕМЕНТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _update_all_option_buttons():
	"""Обновить общие OptionButton из настроек выбранного гостя"""
	if not menu_state:
		return
	
	var selected_id = menu_state.get_selected_guest()
	if selected_id > 0:
		_update_option_buttons(selected_id)
	else:
		# Если никто не выбран, сбрасываем кнопки
		if character_option:
			character_option.selected = 0
		if wealth_option:
			wealth_option.selected = 0

func _update_option_buttons(guest_id: int):
	"""Обновить общие OptionButton для выбранного гостя"""
	if guest_id < 1 or guest_id > 6:
		return
	
	var guest = GuestSettingsManager.get_guest(guest_id)
	
	# Характер
	if character_option:
		character_option.selected = guest.character
	
	# Обеспеченность
	if wealth_option:
		wealth_option.selected = guest.wealth

func _update_all_balances():
	"""Обновить все балансы"""
	for guest_id in range(1, 7):
		_update_balance(guest_id)

func _update_balance(guest_id: int):
	"""Обновить баланс для одного гостя"""
	var index = guest_id - 1
	if index < 0 or index >= 6:
		return
	
	if balance_labels[index]:
		balance_labels[index].text = GuestStatsManager.get_balance_string(guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - HOVER
# ═══════════════════════════════════════════════════════════════════════════

func _on_guest_slot_mouse_entered(guest_id: int):
	"""Обработка наведения курсора на кликабельную зону гостя"""
	if menu_state:
		menu_state.set_hovered_guest(guest_id)
	_update_guest_visibility(guest_id)
	
	# Меняем курсор на pointer
	if guest_slots[guest_id - 1]:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_guest_slot_mouse_exited(guest_id: int):
	"""Обработка ухода курсора с кликабельной зоны гостя"""
	if menu_state:
		menu_state.clear_hover()
	_update_guest_visibility(guest_id)
	
	# Возвращаем обычный курсор
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - КЛИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_guest_slot_gui_input(event: InputEvent, guest_id: int):
	"""Обработка клика по кликабельной зоне гостя"""
	if not event is InputEventMouseButton:
		return
	
	var mouse_event = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# ВАЖНО: при клике мышью деактивируем режим клавиатуры
	if keyboard_navigator:
		keyboard_navigator.deactivate()
	if menu_state:
		menu_state.clear_hover()
	
	if not menu_state:
		return
	
	var guest = GuestSettingsManager.get_guest(guest_id)
	var is_enabled = guest.enabled
	var is_selected = menu_state.get_selected_guest() == guest_id
	
	if not is_enabled:
		# Клик по призраку → включить гостя, выбрать, показать досье
		GuestSettingsManager.set_guest_enabled(guest_id, true)
		if menu_state:
			menu_state.set_selected_guest(guest_id)
		_update_all_guests_visibility()
		_update_option_buttons(guest_id)
	
	elif not is_selected:
		# Клик по невыбранному материальному гостю → выбрать, показать досье
		if menu_state:
			menu_state.set_selected_guest(guest_id)
		_update_all_guests_visibility()
		_update_option_buttons(guest_id)
	
	else:
		# Клик по выбранному материальному гостю → выключить, показать призрака, скрыть досье
		GuestSettingsManager.set_guest_enabled(guest_id, false)
		if menu_state:
			menu_state.set_selected_guest(0)
		_update_all_guests_visibility()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - OPTIONBUTTON
# ═══════════════════════════════════════════════════════════════════════════

func _on_character_selected(index: int):
	"""Обработка выбора характера для выбранного гостя"""
	if not menu_state:
		return
	
	var selected_id = menu_state.get_selected_guest()
	if selected_id == 0:
		return  # Никто не выбран
	
	var character = index as GuestSettingsManager.GuestCharacter
	GuestSettingsManager.set_guest_character(selected_id, character)

func _on_wealth_selected(index: int):
	"""Обработка выбора обеспеченности для выбранного гостя"""
	if not menu_state:
		return
	
	var selected_id = menu_state.get_selected_guest()
	if selected_id == 0:
		return  # Никто не выбран
	
	var wealth = index as GuestSettingsManager.GuestWealth
	GuestSettingsManager.set_guest_wealth(selected_id, wealth)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - КНОПКА ОК
# ═══════════════════════════════════════════════════════════════════════════

func _on_ok_pressed():
	"""Обработка нажатия кнопки ОК"""
	# Если нажали мышью, деактивируем режим клавиатуры
	if keyboard_navigator:
		keyboard_navigator.deactivate()
	close_menu()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - ВНЕШНИЕ ИЗМЕНЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _on_guest_settings_changed(guest_id: int):
	"""Обработка изменения настроек гостя через GuestSettingsManager"""
	# Обновляем видимость только этого гостя
	# НЕ вызываем _update_all_guests_visibility, т.к. это может вызвать проблемы при включении гостя
	_update_guest_visibility(guest_id)
	
	# Обновляем кнопки только если это выбранный гость
	if menu_state and guest_id == menu_state.get_selected_guest():
		_update_option_buttons(guest_id)

func _on_guest_balance_changed(guest_id: int, _new_balance: float):
	"""Обработка изменения баланса гостя"""
	_update_balance(guest_id)

func _on_language_changed(_lang: String):
	"""Обработка изменения языка"""
	_update_texts()

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ ТЕКСТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _update_texts():
	"""Обновить все тексты при смене языка"""
	# Кнопка ОК
	if ok_button:
		ok_button.text = Localization.t("CLOSE")
	
	# Общие OptionButton для характера
	if character_option:
		# Очищаем и добавляем заново с новыми переводами
		character_option.clear()
		character_option.add_item(Localization.t("GUEST_CHARACTER_GENTLEMAN"))
		character_option.add_item(Localization.t("GUEST_CHARACTER_CAUTIOUS"))
		character_option.add_item(Localization.t("GUEST_CHARACTER_GAMBLER"))
		
		# Восстанавливаем выбранное значение из выбранного гостя
		if not menu_state:
			return
		
		var selected_id = menu_state.get_selected_guest()
		if selected_id > 0:
			var guest = GuestSettingsManager.get_guest(selected_id)
			character_option.selected = guest.character
	
	# Общие OptionButton для обеспеченности
	if wealth_option:
		# Очищаем и добавляем заново с новыми переводами
		wealth_option.clear()
		wealth_option.add_item(Localization.t("GUEST_WEALTH_POOR"))
		wealth_option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
		wealth_option.add_item(Localization.t("GUEST_WEALTH_RICH"))
		
		# Восстанавливаем выбранное значение из выбранного гостя
		if not menu_state:
			return
		
		var selected_id = menu_state.get_selected_guest()
		if selected_id > 0:
			var guest = GuestSettingsManager.get_guest(selected_id)
			wealth_option.selected = guest.wealth
	
	# Балансы (формат не зависит от языка, но обновим на всякий случай)
	_update_all_balances()

# ═══════════════════════════════════════════════════════════════════════════
# КЛАВИАТУРНОЕ УПРАВЛЕНИЕ - CALLBACK-ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_navigator_level_changed(level: GuestMenuKeyboardNavigator.NavigationLevel):
	"""Callback: навигатор изменил уровень"""
	_update_level_visuals(level)

func _on_navigator_guests_horizontal(direction: int):
	"""Callback: навигация по гостям горизонтально"""
	_navigate_guests_horizontal(direction)

func _on_navigator_switch_enabled_guests(direction: int):
	"""Callback: переключение между включёнными гостями"""
	_switch_enabled_guests(direction)

func _on_navigator_activate_guest():
	"""Callback: активация гостя"""
	_activate_guest()

func _on_navigator_activate_dossier_button():
	"""Callback: активация кнопки досье"""
	_activate_dossier_button()

func _on_navigator_activate_ok_button():
	"""Callback: активация кнопки OK"""
	_activate_ok_button()

func _is_dossier_visible() -> bool:
	"""Проверить, видно ли досье (для навигатора)"""
	if not menu_state:
		return false
	
	var selected_id = menu_state.get_selected_guest()
	if selected_id == 0:
		return false
	return GuestSettingsManager.is_guest_enabled(selected_id)

# ═══════════════════════════════════════════════════════════════════════════
# КЛАВИАТУРНОЕ УПРАВЛЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	"""Обработка клавиатурного ввода"""
	# Обрабатываем только когда меню видимо
	if not visible:
		return
	
	# Проверяем, что это нажатие клавиши
	if not event is InputEventKey:
		return
	
	if not keyboard_navigator:
		return
	
	var key_event = event as InputEventKey
	
	# Проверяем, открыто ли выпадающее меню (обновляем состояние навигатора)
	_check_dropdown_state()
	
	# Проверяем, нужно ли активировать режим клавиатуры
	if not keyboard_navigator.is_active:
		# Активируем при первом нажатии стрелок/WASD
		if key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]:
			var selected_id = menu_state.get_selected_guest() if menu_state else 0
			keyboard_navigator.activate(selected_id)
			if menu_state:
				menu_state.clear_hover()  # Сбрасываем hover от мыши
			get_viewport().set_input_as_handled()
			return
	
	# Обрабатываем через навигатор
	if keyboard_navigator.handle_input(key_event):
			get_viewport().set_input_as_handled()

func _check_dropdown_state() -> void:
	"""Проверить, открыто ли выпадающее меню и обновить состояние навигатора"""
	if not keyboard_navigator:
		return
	
	var is_open = false
	
	if character_option and character_option.has_focus():
		var popup = character_option.get_popup()
		if popup and popup.visible:
			is_open = true
	
	if wealth_option and wealth_option.has_focus():
		var popup = wealth_option.get_popup()
		if popup and popup.visible:
			is_open = true
	
	keyboard_navigator.set_dropdown_open(is_open)

# ═══════════════════════════════════════════════════════════════════════════
# НАВИГАЦИЯ ПО ГОСТЯМ
# ═══════════════════════════════════════════════════════════════════════════

func _navigate_guests_horizontal(direction: int) -> void:
	"""Навигация по гостям горизонтально (direction: -1 = влево, 1 = вправо)"""
	if not keyboard_navigator:
		return
	
	if keyboard_navigator.focused_guest_id == 0:
		keyboard_navigator.focused_guest_id = 1
	
	# Перемещаемся по гостям закольцовано
	keyboard_navigator.focused_guest_id += direction
	
	if keyboard_navigator.focused_guest_id < 1:
		keyboard_navigator.focused_guest_id = 6
	elif keyboard_navigator.focused_guest_id > 6:
		keyboard_navigator.focused_guest_id = 1
	
	# Обновляем видимость
	_update_all_guests_visibility()

func _activate_guest() -> void:
	"""Активировать/деактивировать гостя (включить/выключить)"""
	if not keyboard_navigator or not menu_state:
		return
	
	var guest_id = keyboard_navigator.focused_guest_id
	if guest_id == 0:
		return
	
	var guest = GuestSettingsManager.get_guest(guest_id)
	var is_enabled = guest.enabled
	
	if not is_enabled:
		# Включаем гостя и выбираем его
		# ВАЖНО: Порядок операций критичен!
		# 1. Сначала устанавливаем focused_guest_id для навигатора
		if keyboard_navigator.is_active:
			keyboard_navigator.focused_guest_id = guest_id
		
		# 2. Устанавливаем selected_guest ПЕРЕД включением гостя, чтобы при обработке сигнала guest_settings_changed
		#    состояние было уже корректным
		#    ВАЖНО: Временно отключаем callback, чтобы избежать преждевременного обновления видимости
		var old_callback = menu_state.state_changed_callback
		menu_state.state_changed_callback = Callable()  # Отключаем callback
		
		menu_state.set_selected_guest(guest_id)
		
		# 3. Включаем гостя (это вызовет сигнал guest_settings_changed, который обновит видимость)
		GuestSettingsManager.set_guest_enabled(guest_id, true)
		
		# 4. Восстанавливаем callback и вызываем обновление видимости вручную
		menu_state.state_changed_callback = old_callback
		_update_all_guests_visibility()
		
		# 4. Обновляем кнопки досье
		_update_option_buttons(guest_id)
		
		# 5. Убеждаемся, что навигатор остается активным (is_active уже должен быть true, но проверяем)
		if not keyboard_navigator.is_active:
			keyboard_navigator.is_active = true
	else:
		# Выключаем гостя
		GuestSettingsManager.set_guest_enabled(guest_id, false)
		# Если это был выбранный гость, сбрасываем выбор
		var was_selected = menu_state.get_selected_guest() == guest_id
		if was_selected:
			# set_selected_guest вызовет callback _update_all_guests_visibility, поэтому не вызываем явно
			menu_state.set_selected_guest(0)
			# Если навигатор был на уровнях досье, возвращаем его на уровень гостей
			if keyboard_navigator.is_active:
				var current_level = keyboard_navigator.current_level
				if current_level == GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION or \
				   current_level == GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION:
					# Досье исчезло, возвращаем на уровень гостей
					keyboard_navigator.current_level = GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
					_on_navigator_level_changed(GuestMenuKeyboardNavigator.NavigationLevel.GUESTS)
		else:
			# Если не был выбран, просто обновляем видимость
			_update_all_guests_visibility()
		# Навигатор остается активным, focused_guest_id остается на этом госте (для возможности повторного включения)

func _update_level_visuals(level: GuestMenuKeyboardNavigator.NavigationLevel) -> void:
	"""Обновить визуальные элементы при смене уровня"""
	# Обновляем видимость всех гостей (включая hover glow)
	_update_all_guests_visibility()
	
	# Управляем focus кнопок
	match level:
		GuestMenuKeyboardNavigator.NavigationLevel.GUESTS:
			# Убираем focus с кнопок
			if character_option:
				character_option.release_focus()
			if wealth_option:
				wealth_option.release_focus()
			if ok_button:
				ok_button.release_focus()
		GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION:
			if character_option:
				character_option.grab_focus()
			if wealth_option:
				wealth_option.release_focus()
			if ok_button:
				ok_button.release_focus()
		GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION:
			if character_option:
				character_option.release_focus()
			if wealth_option:
				wealth_option.grab_focus()
			if ok_button:
				ok_button.release_focus()
		GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON:
			if character_option:
				character_option.release_focus()
			if wealth_option:
				wealth_option.release_focus()
			if ok_button:
				ok_button.grab_focus()

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕКЛЮЧЕНИЕ МЕЖДУ ВКЛЮЧЁННЫМИ ГОСТЯМИ
# ═══════════════════════════════════════════════════════════════════════════

func _switch_enabled_guests(direction: int) -> void:
	"""Переключение между включёнными гостями (direction: -1 = влево, 1 = вправо)"""
	if not keyboard_navigator or not menu_state:
		return
	
	var active_guests = GuestSettingsManager.get_active_guests()
	
	if active_guests.is_empty():
		return
	
	# Находим текущего гостя в списке
	var current_index = -1
	var selected_id = menu_state.get_selected_guest()
	for i in range(active_guests.size()):
		if active_guests[i] == selected_id:
			current_index = i
			break
	
	# Если текущий гость не в списке включённых, остаёмся на нём
	if current_index == -1:
		return
	
	# Переключаемся на следующего/предыдущего (закольцовано)
	current_index += direction
	if current_index < 0:
		current_index = active_guests.size() - 1
	elif current_index >= active_guests.size():
		current_index = 0
	
	var new_guest_id = active_guests[current_index]
	
	# Обновляем состояние
	if menu_state:
		menu_state.set_selected_guest(new_guest_id)
	if keyboard_navigator:
		keyboard_navigator.focused_guest_id = new_guest_id
	
	# Обновляем видимость всех гостей
	_update_all_guests_visibility()
	
	# Обновляем значения кнопок досье
	_update_option_buttons(new_guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# АКТИВАЦИЯ КНОПОК
# ═══════════════════════════════════════════════════════════════════════════

func _activate_dossier_button() -> void:
	"""Активировать кнопку досье (открыть выпадающее меню)"""
	if not keyboard_navigator:
		return
	
	match keyboard_navigator.current_level:
		GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION:
			if character_option:
				character_option.grab_focus()
				character_option.show_popup()
		GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION:
			if wealth_option:
				wealth_option.grab_focus()
				wealth_option.show_popup()
	
	# Обновляем состояние выпадающего меню
	_check_dropdown_state()
	_update_all_guests_visibility()

func _activate_ok_button() -> void:
	"""Активировать кнопку OK (закрыть меню)"""
	close_menu()
