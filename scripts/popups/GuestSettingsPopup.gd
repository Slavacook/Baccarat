# res://scripts/popups/GuestSettingsPopup.gd
# Попап для настройки гостей (характер, обеспеченность, включен/выключен)

extends PopupPanel

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ (ищем через find_child)
# ═══════════════════════════════════════════════════════════════════════════

# Заголовок
@onready var title_label: Label = find_child("TitleLabel", true, false)

# Контейнер для списка гостей
@onready var guests_container: VBoxContainer = find_child("GuestsContainer", true, false)

# Кнопки управления
@onready var close_button: Button = find_child("CloseButton", true, false)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Ссылки на UI элементы для каждого гостя (динамически создаются)
var guest_ui_elements: Dictionary = {}  # {guest_id: {enabled_checkbox, character_option, wealth_option, balance_label}}

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Скрываем при старте
	hide()
	
	# Подключаем сигналы
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Подписываемся на изменения баланса гостей
	GuestStatsManager.guest_balance_changed.connect(_on_guest_balance_changed)
	
	# Подписываемся на изменение языка
	EventBus.language_changed.connect(_on_language_changed)
	
	# Создаём UI для 6 гостей
	_create_guests_ui()
	
	# Обновляем тексты
	_update_texts()

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func open_popup():
	"""Открыть попап настроек гостей"""
	_update_guests_ui()
	popup_centered()
	print("👥 Попап настроек гостей открыт")

func close_popup():
	"""Закрыть попап"""
	hide()

# ═══════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ UI
# ═══════════════════════════════════════════════════════════════════════════

func _create_guests_ui():
	"""Создать UI элементы для всех 6 гостей"""
	if not guests_container:
		push_error("GuestSettingsPopup: GuestsContainer не найден")
		return
	
	# Очищаем контейнер
	for child in guests_container.get_children():
		child.queue_free()
	
	guest_ui_elements.clear()
	
	# Создаём UI для каждого гостя (1-6)
	for guest_id in range(1, 7):
		_create_guest_ui(guest_id)

func _create_guest_ui(guest_id: int):
	"""Создать UI элементы для одного гостя"""
	# Контейнер для гостя
	var guest_container = VBoxContainer.new()
	guest_container.name = "Guest%dContainer" % guest_id
	guests_container.add_child(guest_container)
	
	# Заголовок гостя
	var guest_label = Label.new()
	guest_label.name = "Guest%dLabel" % guest_id
	guest_label.text = Localization.t("GUEST_N", [guest_id])
	guest_label.add_theme_font_size_override("font_size", 18)
	guest_container.add_child(guest_label)
	
	# Чекбокс включения
	var enabled_checkbox = CheckBox.new()
	enabled_checkbox.name = "Guest%dEnabled" % guest_id
	enabled_checkbox.text = Localization.t("GUEST_ENABLED")
	enabled_checkbox.toggled.connect(_on_guest_enabled_toggled.bind(guest_id))
	guest_container.add_child(enabled_checkbox)
	
	# Контейнер для настроек (показывается только если гость включён)
	var settings_container = VBoxContainer.new()
	settings_container.name = "Guest%dSettings" % guest_id
	settings_container.visible = false
	guest_container.add_child(settings_container)
	
	# Выбор характера
	var character_label = Label.new()
	character_label.name = "Guest%dCharacterLabel" % guest_id
	character_label.text = Localization.t("GUEST_CHARACTER")
	settings_container.add_child(character_label)
	
	var character_option = OptionButton.new()
	character_option.name = "Guest%dCharacter" % guest_id
	character_option.add_item(Localization.t("GUEST_CHARACTER_GENTLEMAN"))
	character_option.add_item(Localization.t("GUEST_CHARACTER_CAUTIOUS"))
	character_option.add_item(Localization.t("GUEST_CHARACTER_GAMBLER"))
	character_option.item_selected.connect(_on_guest_character_selected.bind(guest_id))
	settings_container.add_child(character_option)
	
	# Выбор обеспеченности
	var wealth_label = Label.new()
	wealth_label.name = "Guest%dWealthLabel" % guest_id
	wealth_label.text = Localization.t("GUEST_WEALTH")
	settings_container.add_child(wealth_label)
	
	var wealth_option = OptionButton.new()
	wealth_option.name = "Guest%dWealth" % guest_id
	wealth_option.add_item(Localization.t("GUEST_WEALTH_POOR"))
	wealth_option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
	wealth_option.add_item(Localization.t("GUEST_WEALTH_RICH"))
	wealth_option.item_selected.connect(_on_guest_wealth_selected.bind(guest_id))
	settings_container.add_child(wealth_option)
	
	# Баланс гостя
	var balance_label = Label.new()
	balance_label.name = "Guest%dBalance" % guest_id
	balance_label.text = "%s %s" % [Localization.t("GUEST_BALANCE"), GuestStatsManager.get_balance_string(guest_id)]
	balance_label.add_theme_font_size_override("font_size", 14)
	settings_container.add_child(balance_label)
	
	# Разделитель
	var separator = HSeparator.new()
	guest_container.add_child(separator)
	
	# Сохраняем ссылки
	guest_ui_elements[guest_id] = {
		"enabled_checkbox": enabled_checkbox,
		"settings_container": settings_container,
		"character_option": character_option,
		"wealth_option": wealth_option,
		"balance_label": balance_label
	}
	
	# Обновляем видимость настроек при изменении чекбокса
	enabled_checkbox.toggled.connect(func(enabled): settings_container.visible = enabled)

func _update_guests_ui():
	"""Обновить UI всех гостей из GuestSettingsManager"""
	for guest_id in range(1, 7):
		_update_guest_ui(guest_id)

func _update_guest_ui(guest_id: int):
	"""Обновить UI одного гостя"""
	if not guest_ui_elements.has(guest_id):
		return
	
	var elements = guest_ui_elements[guest_id]
	var guest = GuestSettingsManager.get_guest(guest_id)
	
	# Обновляем чекбокс
	if elements.enabled_checkbox:
		elements.enabled_checkbox.button_pressed = guest.enabled
	
	# Обновляем видимость настроек
	if elements.settings_container:
		elements.settings_container.visible = guest.enabled
	
	# Обновляем характер
	if elements.character_option:
		elements.character_option.selected = guest.character
	
	# Обновляем обеспеченность
	if elements.wealth_option:
		elements.wealth_option.selected = guest.wealth
	
	# Обновляем баланс
	if elements.balance_label:
		elements.balance_label.text = "%s %s" % [Localization.t("GUEST_BALANCE"), GuestStatsManager.get_balance_string(guest_id)]

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_guest_enabled_toggled(enabled: bool, guest_id: int):
	"""Обработка переключения включения гостя
	Порядок аргументов: enabled от сигнала toggled, guest_id от bind()
	"""
	GuestSettingsManager.set_guest_enabled(guest_id, enabled)
	
	# Обновляем видимость настроек
	if guest_ui_elements.has(guest_id):
		var elements = guest_ui_elements[guest_id]
		if elements.settings_container:
			elements.settings_container.visible = enabled

func _on_guest_character_selected(index: int, guest_id: int):
	"""Обработка выбора характера гостя
	Порядок аргументов: index от сигнала item_selected, guest_id от bind()
	"""
	var character = index as GuestSettingsManager.GuestCharacter
	GuestSettingsManager.set_guest_character(guest_id, character)

func _on_guest_wealth_selected(index: int, guest_id: int):
	"""Обработка выбора обеспеченности гостя
	Порядок аргументов: index от сигнала item_selected, guest_id от bind()
	"""
	var wealth = index as GuestSettingsManager.GuestWealth
	GuestSettingsManager.set_guest_wealth(guest_id, wealth)

func _on_guest_balance_changed(guest_id: int, _new_balance: float):
	"""Обработка изменения баланса гостя"""
	if guest_ui_elements.has(guest_id):
		var elements = guest_ui_elements[guest_id]
		if elements.balance_label:
			elements.balance_label.text = "%s %s" % [Localization.t("GUEST_BALANCE"), GuestStatsManager.get_balance_string(guest_id)]

func _on_close_pressed():
	"""Обработка нажатия кнопки закрытия"""
	close_popup()

func _on_language_changed(_lang: String):
	"""Обработка изменения языка"""
	_update_texts()

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ ТЕКСТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _update_texts():
	"""Обновить все тексты при смене языка"""
	if title_label:
		title_label.text = Localization.t("GUEST_SETTINGS_TITLE")
	
	if close_button:
		close_button.text = Localization.t("CLOSE")
	
	# Обновляем тексты для всех гостей
	for guest_id in range(1, 7):
		if guest_ui_elements.has(guest_id):
			var elements = guest_ui_elements[guest_id]
			# Обновляем заголовок гостя
			var guest_container = guests_container.get_node_or_null("Guest%dContainer" % guest_id)
			if guest_container:
				var guest_label = guest_container.get_node_or_null("Guest%dLabel" % guest_id)
				if guest_label:
					guest_label.text = Localization.t("GUEST_N", [guest_id])
			
			# Обновляем чекбокс
			if elements.enabled_checkbox:
				elements.enabled_checkbox.text = Localization.t("GUEST_ENABLED")
			
			# Обновляем лейблы
			var settings_container = elements.settings_container
			if settings_container:
				var character_label = settings_container.get_node_or_null("Guest%dCharacterLabel" % guest_id)
				if character_label:
					character_label.text = Localization.t("GUEST_CHARACTER")
				
				var wealth_label = settings_container.get_node_or_null("Guest%dWealthLabel" % guest_id)
				if wealth_label:
					wealth_label.text = Localization.t("GUEST_WEALTH")
			
			# Обновляем OptionButton
			if elements.character_option:
				if elements.character_option.get_item_count() == 0:
					elements.character_option.add_item(Localization.t("GUEST_CHARACTER_GENTLEMAN"))
					elements.character_option.add_item(Localization.t("GUEST_CHARACTER_CAUTIOUS"))
					elements.character_option.add_item(Localization.t("GUEST_CHARACTER_GAMBLER"))
				else:
					elements.character_option.set_item_text(0, Localization.t("GUEST_CHARACTER_GENTLEMAN"))
					elements.character_option.set_item_text(1, Localization.t("GUEST_CHARACTER_CAUTIOUS"))
					elements.character_option.set_item_text(2, Localization.t("GUEST_CHARACTER_GAMBLER"))
			
			if elements.wealth_option:
				if elements.wealth_option.get_item_count() == 0:
					elements.wealth_option.add_item(Localization.t("GUEST_WEALTH_POOR"))
					elements.wealth_option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
					elements.wealth_option.add_item(Localization.t("GUEST_WEALTH_RICH"))
				else:
					elements.wealth_option.set_item_text(0, Localization.t("GUEST_WEALTH_POOR"))
					elements.wealth_option.set_item_text(1, Localization.t("GUEST_WEALTH_MEDIUM"))
					elements.wealth_option.set_item_text(2, Localization.t("GUEST_WEALTH_RICH"))
			
			# Обновляем баланс
			if elements.balance_label:
				elements.balance_label.text = "%s %s" % [Localization.t("GUEST_BALANCE"), GuestStatsManager.get_balance_string(guest_id)]
