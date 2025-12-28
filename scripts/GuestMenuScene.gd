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

# UI рендерер (инкапсулирует логику отображения UI-элементов)
var ui_renderer: GuestMenuUIRenderer

# Обновление текстов (инкапсулирует логику локализации)
var text_updater: GuestMenuTextUpdater

# Рендерер балансов (инкапсулирует логику отображения балансов)
var balance_renderer: GuestMenuBalanceRenderer

# Последний выделенный объект (для восстановления фокуса при активации клавиатуры)
var last_selected_level: GuestMenuKeyboardNavigator.NavigationLevel = GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
var last_selected_guest_id: int = 0

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
	
	# Инициализируем UI рендерер (после инициализации узлов)
	_initialize_ui_renderer()
	
	# Инициализируем обновление текстов
	_initialize_text_updater()
	
	# Инициализируем рендерер балансов
	_initialize_balance_renderer()
	
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
# ИНИЦИАЛИЗАЦИЯ UI РЕНДЕРЕРА
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_ui_renderer():
	"""Инициализировать UI рендерер с массивами узлов"""
	# Массивы узлов уже должны быть инициализированы в _ready перед вызовом этого метода
	
	# Создаём UI рендерер
	ui_renderer = GuestMenuUIRenderer.new(
		ghost_textures,
		guest_textures,
		hover_glow_textures,
		dossier_textures,
		character_option,
		wealth_option
	)

func _initialize_text_updater():
	"""Инициализировать обновление текстов"""
	text_updater = GuestMenuTextUpdater.new(
		ok_button,
		character_option,
		wealth_option
	)

func _initialize_balance_renderer():
	"""Инициализировать рендерер балансов"""
	balance_renderer = GuestMenuBalanceRenderer.new(balance_labels)

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
		character_option.gui_input.connect(_on_character_option_gui_input)
	
	if wealth_option:
		wealth_option.item_selected.connect(_on_wealth_selected)
		wealth_option.gui_input.connect(_on_wealth_option_gui_input)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func open_menu():
	"""Открыть меню настроек гостей"""
	# Если меню уже видимо, не сбрасываем состояние (чтобы не потерять выбранного гостя)
	if visible:
		return
	
	# Устанавливаем контекст меню гостей
	InputContextManager.set_context(InputContextManager.InputContext.MENU_GUEST)
	
	# Сбрасываем состояние только если меню было скрыто
	if menu_state:
		menu_state.reset()
	
	# Сбрасываем состояние клавиатуры через навигатор
	if keyboard_navigator:
		keyboard_navigator.reset()
	
	# Сбрасываем информацию о последнем выделенном объекте
	last_selected_level = GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
	last_selected_guest_id = 0
	
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
	# Возвращаем контекст: если настройки открыты - возвращаем MENU_SETTINGS, иначе GAME
	# Ищем SettingsScene в текущей сцене (Game)
	var game_scene = get_tree().current_scene
	var settings_scene = null
	if game_scene:
		settings_scene = game_scene.get_node_or_null("SettingsScene")
	
	if settings_scene and settings_scene.visible:
		InputContextManager.set_context(InputContextManager.InputContext.MENU_SETTINGS)
	else:
		InputContextManager.set_context(InputContextManager.InputContext.GAME)
	
	if keyboard_navigator:
		keyboard_navigator.deactivate()
	hide()

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func _update_all_guests_visibility():
	"""Обновить видимость всех гостей на основе их состояния"""
	if not ui_renderer or not menu_state:
		return
	
	# Вычисляем визуальное состояние для всех гостей
	var visual_states: Array[GuestUIVisualState] = []
	for guest_id in range(1, 7):
		var visual_state = _calculate_guest_visual_state(guest_id)
		visual_states.append(visual_state)
	
	# Обновляем видимость через рендерер
	ui_renderer.update_all_guests_visibility(visual_states)
	
	# Обновляем видимость общих кнопок
	_update_common_buttons_visibility()

func _update_guest_visibility(guest_id: int):
	"""Обновить видимость одного гостя (guest_id: 1-6)"""
	if not ui_renderer:
		return
	
	var visual_state = _calculate_guest_visual_state(guest_id)
	ui_renderer.update_guest_visibility(guest_id, visual_state)

func _calculate_guest_visual_state(guest_id: int) -> GuestUIVisualState:
	"""Вычислить визуальное состояние гостя на основе данных из меню состояния и настроек"""
	if not menu_state:
		return GuestUIVisualState.new()
	
	var guest = GuestSettingsManager.get_guest(guest_id)
	var is_enabled = guest.enabled
	var is_selected = menu_state.get_selected_guest() == guest_id
	var is_hovered = menu_state.get_hovered_guest() == guest_id
	
	# Определяем, есть ли фокус клавиатуры на этом госте
	var has_keyboard_focus = false
	if keyboard_navigator and keyboard_navigator.is_active:
		if keyboard_navigator.current_level == GuestMenuKeyboardNavigator.NavigationLevel.GUESTS:
			has_keyboard_focus = (keyboard_navigator.focused_guest_id == guest_id)
	
	return GuestUIVisualState.new(is_enabled, is_selected, is_hovered, has_keyboard_focus)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ UI ЭЛЕМЕНТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_option_buttons():
	"""Инициализировать общие OptionButton элементами (если они пустые)"""
	if text_updater:
		text_updater.initialize_option_buttons()

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ ОБЩИХ КНОПОК
# ═══════════════════════════════════════════════════════════════════════════

func _update_common_buttons_visibility():
	"""Обновить видимость общих кнопок (видны только если есть выбранный включённый гость)"""
	if not ui_renderer or not menu_state:
		return
	
	var selected_id = menu_state.get_selected_guest()
	var has_selected_guest = (selected_id > 0) and GuestSettingsManager.is_guest_enabled(selected_id)
	
	ui_renderer.update_common_buttons_visibility(has_selected_guest)

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
	if balance_renderer:
		balance_renderer.update_all_balances()

func _update_balance(guest_id: int):
	"""Обновить баланс для одного гостя"""
	if balance_renderer:
		balance_renderer.update_balance(guest_id)

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
	
	# Сохраняем информацию о выделенном объекте (гость)
	last_selected_level = GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
	last_selected_guest_id = guest_id
	
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

func _on_character_option_gui_input(event: InputEvent):
	"""Обработка клика по OptionButton характера"""
	if not event is InputEventMouseButton:
		return
	
	var mouse_event = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# Сохраняем информацию о выделенном объекте (OptionButton характера)
	last_selected_level = GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION
	last_selected_guest_id = menu_state.get_selected_guest() if menu_state else 0
	
	# Деактивируем режим клавиатуры при клике мышью
	if keyboard_navigator:
		keyboard_navigator.deactivate()

func _on_wealth_option_gui_input(event: InputEvent):
	"""Обработка клика по OptionButton обеспеченности"""
	if not event is InputEventMouseButton:
		return
	
	var mouse_event = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# Сохраняем информацию о выделенном объекте (OptionButton обеспеченности)
	last_selected_level = GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION
	last_selected_guest_id = menu_state.get_selected_guest() if menu_state else 0
	
	# Деактивируем режим клавиатуры при клике мышью
	if keyboard_navigator:
		keyboard_navigator.deactivate()

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
	# Сохраняем информацию о выделенном объекте (кнопка OK)
	last_selected_level = GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON
	last_selected_guest_id = 0
	
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
	if not text_updater:
		return
	
	var selected_id = 0
	if menu_state:
		selected_id = menu_state.get_selected_guest()
	
	text_updater.update_all_texts(selected_id)
	
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

func _calculate_next_target(level: GuestMenuKeyboardNavigator.NavigationLevel, guest_id: int, direction: String) -> Dictionary:
	"""Вычислить следующий объект в направлении нажатой клавиши
	
	Args:
		level: Текущий уровень навигации
		guest_id: Текущий ID гостя (0 если не применимо)
		direction: Направление ("left", "right", "up", "down")
	
	Returns:
		Dictionary с ключами "level" и "guest_id"
	"""
	var result = {
		"level": level,
		"guest_id": guest_id
	}
	
	match direction:
		"left", "right":
			var dir = 1 if direction == "right" else -1
			match level:
				GuestMenuKeyboardNavigator.NavigationLevel.GUESTS:
					# Навигация по гостям закольцовано
					var new_guest_id = guest_id + dir
					if new_guest_id < 1:
						new_guest_id = 6
					elif new_guest_id > 6:
						new_guest_id = 1
					result.guest_id = new_guest_id
				GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION, GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION:
					# Переключение между включёнными гостями
					var active_guests = GuestSettingsManager.get_active_guests()
					if active_guests.is_empty():
						# Если нет включённых гостей, остаёмся на месте
						pass
					else:
						# Находим текущего гостя в списке
						var current_index = -1
						var selected_id = menu_state.get_selected_guest() if menu_state else 0
						for i in range(active_guests.size()):
							if active_guests[i] == selected_id:
								current_index = i
								break
						
						# Если текущий гость не в списке, берём первого
						if current_index == -1:
							current_index = 0
						
						# Переключаемся на следующего/предыдущего (закольцовано)
						current_index += dir
						if current_index < 0:
							current_index = active_guests.size() - 1
						elif current_index >= active_guests.size():
							current_index = 0
						
						var new_guest_id = active_guests[current_index]
						result.guest_id = new_guest_id
						# Уровень остаётся тем же (CHARACTER_OPTION или WEALTH_OPTION)
				GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON:
					# Игнорируем влево/вправо на кнопке OK
					pass
		
		"up":
			match level:
				GuestMenuKeyboardNavigator.NavigationLevel.GUESTS:
					result.level = GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON
				GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION:
					# Переход на уровень гостей (на текущего гостя, чьё досье открыто)
					result.level = GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
					var selected_id = menu_state.get_selected_guest() if menu_state else 0
					if selected_id > 0:
						result.guest_id = selected_id
				GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION:
					result.level = GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION
				GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON:
					# Если досье видно → уровень 2, иначе → уровень 4 (на гостя 1)
					if _is_dossier_visible():
						result.level = GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION
					else:
						result.level = GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
						result.guest_id = 1
		
		"down":
			match level:
				GuestMenuKeyboardNavigator.NavigationLevel.GUESTS:
					# Если досье открыто → уровень 3, иначе → уровень 1
					if _is_dossier_visible():
						result.level = GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION
					else:
						result.level = GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON
				GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION:
					result.level = GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION
				GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION:
					result.level = GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON
				GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON:
					# Всегда переход на уровень гостей (закольцовывание)
					result.level = GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
					# Если досье видно, переходим на выбранного гостя, иначе на гостя 1
					if _is_dossier_visible():
						var selected_id = menu_state.get_selected_guest() if menu_state else 0
						result.guest_id = selected_id if selected_id > 0 else 1
					else:
						result.guest_id = 1
	
	# Проверяем доступность уровней 2 и 3 (OptionButton доступны только если досье видно)
	if result.level == GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION or result.level == GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION:
		if not _is_dossier_visible():
			# Уровни 2 и 3 недоступны, переключаемся на доступный уровень
			if result.level == GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION:
				result.level = GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
			elif result.level == GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION:
				result.level = GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON
	
	return result

# ═══════════════════════════════════════════════════════════════════════════
# КЛАВИАТУРНОЕ УПРАВЛЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	"""Обработка клавиатурного ввода"""
	# Обрабатываем только когда меню видимо
	if not visible:
		return
	
	# Проверяем контекст напрямую (не используем can_handle, так как оно проверяет блокировку)
	# Меню гостей должно работать даже когда настройки открыты
	if InputContextManager.get_context() != InputContextManager.InputContext.MENU_GUEST:
		return
	
	# Проверяем валидность события клавиатуры
	if not InputContextManager.is_valid_key_event(event):
		return
	
	var key_event = event as InputEventKey
	
	# Escape в меню гостей → закрыть меню
	if key_event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()
		return
	
	if not keyboard_navigator:
		return
	
	# Проверяем, открыто ли выпадающее меню (обновляем состояние навигатора)
	_check_dropdown_state()
	
	# Если выпадающее меню открыто, пропускаем события стрелок вверх/вниз и пробел,
	# чтобы они дошли до OptionButton для навигации по пунктам меню
	if keyboard_navigator and keyboard_navigator.is_dropdown_open:
		# Блокируем только горизонтальные стрелки (влево/вправо), остальные пропускаем
		if key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
			get_viewport().set_input_as_handled()
			return
		# Для остальных клавиш (вверх/вниз, пробел) не обрабатываем, позволяем дойти до OptionButton
		return
	
	# Проверяем, нужно ли активировать режим клавиатуры
	if not keyboard_navigator.is_active:
		# Активируем при первом нажатии стрелок/WASD
		if key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]:
			# Определяем направление
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
				# Используем последний выделенный объект, если он был, иначе используем выбранного гостя или первого гостя
				var current_level = last_selected_level
				var current_guest_id = last_selected_guest_id
				
				# Если не было выделенного объекта, используем выбранного гостя или первого гостя
				if current_level == GuestMenuKeyboardNavigator.NavigationLevel.GUESTS and current_guest_id == 0:
					current_guest_id = menu_state.get_selected_guest() if menu_state else 0
					if current_guest_id == 0:
						current_guest_id = 1
				
				# Вычисляем следующий объект в направлении нажатой клавиши
				var next_target = _calculate_next_target(current_level, current_guest_id, direction)
				var target_level = next_target.level
				var target_guest_id = next_target.guest_id
				
				keyboard_navigator.activate_with_level(target_level, target_guest_id)
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
	
	# Проверяем CharacterOption и его popup
	if character_option:
		var popup = character_option.get_popup()
		if popup and popup.visible:
			is_open = true
		# Также проверяем, имеет ли OptionButton или его popup фокус
		elif character_option.has_focus():
			var popup_check = character_option.get_popup()
			if popup_check and popup_check.visible:
				is_open = true
	
	# Проверяем WealthOption и его popup
	if wealth_option:
		var popup = wealth_option.get_popup()
		if popup and popup.visible:
			is_open = true
		# Также проверяем, имеет ли OptionButton или его popup фокус
		elif wealth_option.has_focus():
			var popup_check = wealth_option.get_popup()
			if popup_check and popup_check.visible:
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
				# Убеждаемся, что popup получает фокус для обработки клавиатуры
				var popup = character_option.get_popup()
				if popup:
					popup.grab_focus()
		GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION:
			if wealth_option:
				wealth_option.grab_focus()
				wealth_option.show_popup()
				# Убеждаемся, что popup получает фокус для обработки клавиатуры
				var popup = wealth_option.get_popup()
				if popup:
					popup.grab_focus()
	
	# Обновляем состояние выпадающего меню
	_check_dropdown_state()
	_update_all_guests_visibility()

func _activate_ok_button() -> void:
	"""Активировать кнопку OK (закрыть меню)"""
	close_menu()
