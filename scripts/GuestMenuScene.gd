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

# Текущий выбранный гость (0 = никто не выбран, 1-6 = выбранный гость)
var selected_guest_id: int = 0

# Текущий гость под курсором (для hover эффекта)
var hovered_guest_id: int = 0

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Скрываем при старте
	hide()
	
	# Инициализируем массивы узлов для всех 6 гостей
	_initialize_guest_nodes()
	
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
	# Сбрасываем состояние
	selected_guest_id = 0
	hovered_guest_id = 0
	
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
	print("👥 GuestMenuScene открыто")

func close_menu():
	"""Закрыть меню"""
	hide()
	print("👥 GuestMenuScene закрыто")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func _update_all_guests_visibility():
	"""Обновить видимость всех гостей на основе их состояния"""
	for guest_id in range(1, 7):
		_update_guest_visibility(guest_id)

func _update_guest_visibility(guest_id: int):
	"""Обновить видимость одного гостя (guest_id: 1-6)"""
	var index = guest_id - 1
	if index < 0 or index >= 6:
		return
	
	var guest = GuestSettingsManager.get_guest(guest_id)
	var is_enabled = guest.enabled
	var is_selected = (selected_guest_id == guest_id)
	
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
	
	# Hover свечение: видно если наведён курсор (даже для выбранного гостя)
	if hover_glow_textures[index]:
		hover_glow_textures[index].visible = (hovered_guest_id == guest_id)
	
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
# ОБНОВЛЕНИЕ UI ЭЛЕМЕНТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _update_all_option_buttons():
	"""Обновить общие OptionButton из настроек выбранного гостя"""
	if selected_guest_id > 0:
		_update_option_buttons(selected_guest_id)
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
	hovered_guest_id = guest_id
	_update_guest_visibility(guest_id)
	
	# Меняем курсор на pointer
	if guest_slots[guest_id - 1]:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_guest_slot_mouse_exited(guest_id: int):
	"""Обработка ухода курсора с кликабельной зоны гостя"""
	hovered_guest_id = 0
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
	
	var guest = GuestSettingsManager.get_guest(guest_id)
	var is_enabled = guest.enabled
	var is_selected = (selected_guest_id == guest_id)
	
	if not is_enabled:
		# Клик по призраку → включить гостя, выбрать, показать досье
		GuestSettingsManager.set_guest_enabled(guest_id, true)
		selected_guest_id = guest_id
		_update_all_guests_visibility()  # Обновляем всех, чтобы у предыдущего исчезла текстура духа
		_update_option_buttons(guest_id)
		print("👥 Гость %d включён и выбран" % guest_id)
	
	elif not is_selected:
		# Клик по невыбранному материальному гостю → выбрать, показать досье
		selected_guest_id = guest_id
		_update_all_guests_visibility()  # Обновляем всех, чтобы у предыдущего исчезла текстура духа
		_update_option_buttons(guest_id)
		print("👥 Гость %d выбран" % guest_id)
	
	else:
		# Клик по выбранному материальному гостю → выключить, показать призрака, скрыть досье
		GuestSettingsManager.set_guest_enabled(guest_id, false)
		selected_guest_id = 0
		_update_all_guests_visibility()  # Обновляем всех
		print("👥 Гость %d выключен" % guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - OPTIONBUTTON
# ═══════════════════════════════════════════════════════════════════════════

func _on_character_selected(index: int):
	"""Обработка выбора характера для выбранного гостя"""
	if selected_guest_id == 0:
		return  # Никто не выбран
	
	var character = index as GuestSettingsManager.GuestCharacter
	GuestSettingsManager.set_guest_character(selected_guest_id, character)
	print("👥 Гость %d: характер изменён на %s" % [selected_guest_id, GuestSettingsManager.GuestCharacter.keys()[character]])

func _on_wealth_selected(index: int):
	"""Обработка выбора обеспеченности для выбранного гостя"""
	if selected_guest_id == 0:
		return  # Никто не выбран
	
	var wealth = index as GuestSettingsManager.GuestWealth
	GuestSettingsManager.set_guest_wealth(selected_guest_id, wealth)
	print("👥 Гость %d: обеспеченность изменена на %s" % [selected_guest_id, GuestSettingsManager.GuestWealth.keys()[wealth]])

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - КНОПКА ОК
# ═══════════════════════════════════════════════════════════════════════════

func _on_ok_pressed():
	"""Обработка нажатия кнопки ОК"""
	close_menu()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - ВНЕШНИЕ ИЗМЕНЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _on_guest_settings_changed(guest_id: int):
	"""Обработка изменения настроек гостя через GuestSettingsManager"""
	_update_guest_visibility(guest_id)
	# Обновляем кнопки только если это выбранный гость
	if guest_id == selected_guest_id:
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
		if selected_guest_id > 0:
			var guest = GuestSettingsManager.get_guest(selected_guest_id)
			character_option.selected = guest.character
	
	# Общие OptionButton для обеспеченности
	if wealth_option:
		# Очищаем и добавляем заново с новыми переводами
		wealth_option.clear()
		wealth_option.add_item(Localization.t("GUEST_WEALTH_POOR"))
		wealth_option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
		wealth_option.add_item(Localization.t("GUEST_WEALTH_RICH"))
		
		# Восстанавливаем выбранное значение из выбранного гостя
		if selected_guest_id > 0:
			var guest = GuestSettingsManager.get_guest(selected_guest_id)
			wealth_option.selected = guest.wealth
	
	# Балансы (формат не зависит от языка, но обновим на всякий случай)
	_update_all_balances()
