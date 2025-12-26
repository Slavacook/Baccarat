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

# OptionButton для характера (внутри досье)
var character_options: Array[OptionButton] = []

# OptionButton для обеспеченности (внутри досье)
var wealth_options: Array[OptionButton] = []

# Label для баланса (внутри досье)
var balance_labels: Array[Label] = []

# Кликабельные зоны (Control узлы)
var guest_slots: Array[Control] = []

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
	character_options.clear()
	wealth_options.clear()
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
		
		# OptionButton для характера
		var char_option = dossiers_layer.get_node_or_null("Dossier%d/CharacterOption%d" % [guest_id, guest_id]) as OptionButton
		if not char_option:
			char_option = dossier.get_node_or_null("CharacterOption%d" % guest_id) as OptionButton if dossier else null
		if char_option:
			character_options.append(char_option)
		else:
			character_options.append(null)
			push_warning("GuestMenuScene: не найден CharacterOption%d" % guest_id)
		
		# OptionButton для обеспеченности
		var wealth_option = dossiers_layer.get_node_or_null("Dossier%d/WealthOption%d" % [guest_id, guest_id]) as OptionButton
		if not wealth_option:
			wealth_option = dossier.get_node_or_null("WealthOption%d" % guest_id) as OptionButton if dossier else null
		if wealth_option:
			wealth_options.append(wealth_option)
		else:
			wealth_options.append(null)
			push_warning("GuestMenuScene: не найден WealthOption%d" % guest_id)
		
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
	
	# OptionButton для характера
	for i in range(character_options.size()):
		var option = character_options[i]
		if option:
			var guest_id = i + 1
			option.item_selected.connect(_on_character_selected.bind(guest_id))
	
	# OptionButton для обеспеченности
	for i in range(wealth_options.size()):
		var option = wealth_options[i]
		if option:
			var guest_id = i + 1
			option.item_selected.connect(_on_wealth_selected.bind(guest_id))

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
	"""Инициализировать OptionButton элементами (если они пустые)"""
	# OptionButton для характера
	for i in range(character_options.size()):
		var option = character_options[i]
		if option and option.get_item_count() == 0:
			option.add_item(Localization.t("GUEST_CHARACTER_GENTLEMAN"))
			option.add_item(Localization.t("GUEST_CHARACTER_CAUTIOUS"))
			option.add_item(Localization.t("GUEST_CHARACTER_GAMBLER"))
	
	# OptionButton для обеспеченности
	for i in range(wealth_options.size()):
		var option = wealth_options[i]
		if option and option.get_item_count() == 0:
			option.add_item(Localization.t("GUEST_WEALTH_POOR"))
			option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
			option.add_item(Localization.t("GUEST_WEALTH_RICH"))

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ UI ЭЛЕМЕНТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _update_all_option_buttons():
	"""Обновить все OptionButton из GuestSettingsManager"""
	for guest_id in range(1, 7):
		_update_option_buttons(guest_id)

func _update_option_buttons(guest_id: int):
	"""Обновить OptionButton для одного гостя"""
	var index = guest_id - 1
	if index < 0 or index >= 6:
		return
	
	var guest = GuestSettingsManager.get_guest(guest_id)
	
	# Характер
	if character_options[index]:
		character_options[index].selected = guest.character
	
	# Обеспеченность
	if wealth_options[index]:
		wealth_options[index].selected = guest.wealth

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
		_update_guest_visibility(guest_id)
		_update_option_buttons(guest_id)
		print("👥 Гость %d включён и выбран" % guest_id)
	
	elif not is_selected:
		# Клик по невыбранному материальному гостю → выбрать, показать досье
		selected_guest_id = guest_id
		_update_all_guests_visibility()  # Обновляем все, чтобы скрыть предыдущее досье
		print("👥 Гость %d выбран" % guest_id)
	
	else:
		# Клик по выбранному материальному гостю → выключить, показать призрака, скрыть досье
		GuestSettingsManager.set_guest_enabled(guest_id, false)
		selected_guest_id = 0
		_update_guest_visibility(guest_id)
		print("👥 Гость %d выключен" % guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ - OPTIONBUTTON
# ═══════════════════════════════════════════════════════════════════════════

func _on_character_selected(index: int, guest_id: int):
	"""Обработка выбора характера гостя"""
	var character = index as GuestSettingsManager.GuestCharacter
	GuestSettingsManager.set_guest_character(guest_id, character)
	print("👥 Гость %d: характер изменён на %s" % [guest_id, GuestSettingsManager.GuestCharacter.keys()[character]])

func _on_wealth_selected(index: int, guest_id: int):
	"""Обработка выбора обеспеченности гостя"""
	var wealth = index as GuestSettingsManager.GuestWealth
	GuestSettingsManager.set_guest_wealth(guest_id, wealth)
	print("👥 Гость %d: обеспеченность изменена на %s" % [guest_id, GuestSettingsManager.GuestWealth.keys()[wealth]])

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
	
	# OptionButton для характера
	for i in range(character_options.size()):
		var option = character_options[i]
		if option:
			# Очищаем и добавляем заново с новыми переводами
			option.clear()
			option.add_item(Localization.t("GUEST_CHARACTER_GENTLEMAN"))
			option.add_item(Localization.t("GUEST_CHARACTER_CAUTIOUS"))
			option.add_item(Localization.t("GUEST_CHARACTER_GAMBLER"))
			
			# Восстанавливаем выбранное значение из GuestSettingsManager
			var guest_id = i + 1
			var guest = GuestSettingsManager.get_guest(guest_id)
			option.selected = guest.character
	
	# OptionButton для обеспеченности
	for i in range(wealth_options.size()):
		var option = wealth_options[i]
		if option:
			# Очищаем и добавляем заново с новыми переводами
			option.clear()
			option.add_item(Localization.t("GUEST_WEALTH_POOR"))
			option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
			option.add_item(Localization.t("GUEST_WEALTH_RICH"))
			
			# Восстанавливаем выбранное значение из GuestSettingsManager
			var guest_id = i + 1
			var guest = GuestSettingsManager.get_guest(guest_id)
			option.selected = guest.wealth
	
	# Балансы (формат не зависит от языка, но обновим на всякий случай)
	_update_all_balances()
