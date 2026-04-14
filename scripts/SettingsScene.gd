# res://scripts/SettingsScene.gd
# Сцена настроек (overlay поверх Game.tscn)
# Заменяет старый SettingsPopup

extends CanvasLayer
class_name SettingsScene

const SHOW_TRAINING_MENU_ENTRY: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ (для совместимости с GameController)
# ═══════════════════════════════════════════════════════════════════════════

signal mode_changed(mode: String)  # "junket" или "classic"
signal language_changed(lang: String)  # "ru" или "en"

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ (ищем по имени через find_child)
# ═══════════════════════════════════════════════════════════════════════════

# Заголовок
@onready var title_label: Label = find_child("TitleLabel", true, false)

# === ГЛАВНОЕ МЕНЮ ===
@onready var main_menu_container: HBoxContainer = find_child("MainMenuContainer", true, false)
@onready var limits_button: Button = find_child("LimitsButton", true, false)
@onready var bets_filter_button: Button = find_child("BetsFilterButton", true, false)
@onready var guests_button: Button = find_child("GuestsButton", true, false)
@onready var story_button: Button = find_child("StoryButton", true, false)
@onready var advanced_settings_button: Button = find_child("AdvancedSettingsButton", true, false)
@onready var training_button: Button = find_child("TrainingButton", true, false)
# ok_button больше не используется (убрана из UI)

# Онлайн режим (создаётся программно)
var online_mode_button: Button = null

# === ОБЛАСТЬ КОНТЕНТА ===
@onready var content_area: VBoxContainer = find_child("ContentArea", true, false)
@onready var content_footer_separator: HSeparator = find_child("HSeparator4", true, false)

# === ПОДМЕНЮ ===
@onready var limits_submenu: VBoxContainer = find_child("LimitsSubmenu", true, false)
@onready var bets_filter_submenu: HBoxContainer = find_child("BetsFilterSubmenu", true, false)  # Изменено на HBoxContainer (два столбца)
@onready var advanced_settings_submenu: VBoxContainer = find_child("AdvancedSettingsSubmenu", true, false)
@onready var story_submenu: VBoxContainer = find_child("StorySubmenu", true, false)

# === КНОПКА НАЗАД ===
@onready var back_button: Button = find_child("BackButton", true, false)
@onready var hseparator_bottom: HSeparator = find_child("HSeparatorBottom", true, false)

# === ПОДМЕНЮ: СЮЖЕТ (прогрессия гостей) ===
var story_table_container: VBoxContainer = null  # Будет найден в _initialize_story_submenu
var story_scroll_container: ScrollContainer = null  # Будет найден в _initialize_story_submenu
var story_description_label: Label = null  # Будет найден в _initialize_story_submenu
var story_mode_info_label: Label = null  # Будет найден в _initialize_story_submenu
var story_toggle_button: Button = null  # Будет найден в _initialize_story_submenu
var story_threshold_spinboxes: Dictionary = {}  # {количество_гостей: SpinBox}
var story_reset_buttons: Dictionary = {}  # {количество_гостей: Button}

# === ПОДМЕНЮ: ФИЛЬТР СТАВОК И КАРТ ===
@onready var card_settings_label: Label = find_child("CardSettingsLabel", true, false)
@onready var test_cards_enabled_checkbox: CheckBox = find_child("TestCardsEnabledCheckbox", true, false)
@onready var banker1_card_option: OptionButton = find_child("Banker1CardOption", true, false)
@onready var banker2_card_option: OptionButton = find_child("Banker2CardOption", true, false)
@onready var player1_card_option: OptionButton = find_child("Player1CardOption", true, false)
@onready var player2_card_option: OptionButton = find_child("Player2CardOption", true, false)

# === ПОДМЕНЮ: РАСШИРЕННЫЕ НАСТРОЙКИ ===
@onready var section_immortality_label: Label = find_child("SectionImmortality", true, false)
@onready var immortality_button: Button = find_child("ImmortalityButton", true, false)

# Текущее активное меню
var current_menu: String = "main"  # "main", "limits", "bets", "advanced", "story"

# === РАЗДЕЛ 1: РЕЖИМ ВЫЖИВАНИЯ === (DEPRECATED - скрыт)
@onready var survival_checkbox: CheckBox = find_child("SurvivalCheckbox", true, false)

# === РАЗДЕЛ 2: РЕЖИМ ИГРЫ ===
@onready var junket_button: Button = find_child("JunketButton", true, false)
@onready var classic_button: Button = find_child("ClassicButton", true, false)
@onready var mode_info_label: Label = find_child("ModeInfoLabel", true, false)

# === РАЗДЕЛ 3: СТАВКИ ===
@onready var bet_player_button: Button = find_child("BetPlayerButton", true, false)
@onready var bet_banker_button: Button = find_child("BetBankerButton", true, false)
@onready var bet_tie_button: Button = find_child("BetTieButton", true, false)
@onready var bet_pair_button: Button = find_child("BetPairButton", true, false)
@onready var guest_settings_button: Button = find_child("GuestSettingsButton", true, false)
@onready var guest_progression_button: Button = find_child("GuestProgressionButton", true, false)

# === РАЗДЕЛ 4: РАЗМЕР СТАВОК ===
@onready var bet_size_option: OptionButton = find_child("BetSizeOption", true, false)

# === РАЗДЕЛ 4.5: ЧАЕВЫЕ ===
@onready var tip_percentage_spinbox: SpinBox = find_child("TipPercentageSpinBox", true, false)

# === РАЗДЕЛ 4.6: КАРТЫ ШАНСОВ ===
@onready var chance_cards_checkbox: CheckBox = find_child("ChanceCardsCheckbox", true, false)

# === РАЗДЕЛ 4.6.5: АВТОМАТИЧЕСКОЕ ПЕРЕКЛЮЧЕНИЕ РЕЖИМОВ ===
@onready var auto_mode_switch_checkbox: CheckBox = find_child("AutoModeSwitchCheckbox", true, false)

# === РАЗДЕЛ 4.7: ВОЗВРАТ ГОСТЕЙ ===
@onready var guest_return_container: VBoxContainer = find_child("GuestReturnContainer", true, false)
var guest_return_counter_ui: GuestReturnCounterUI = null

# === РАЗДЕЛ 5: ЯЗЫК ===
@onready var ru_button: Button = find_child("RuButton", true, false)
@onready var en_button: Button = find_child("EnButton", true, false)

# === РАЗДЕЛ 6: РУБАШКА КАРТ ===
@onready var tiger_button: Button = find_child("TigerButton", true, false)
@onready var leopard_button: Button = find_child("LeopardButton", true, false)

# === РАЗДЕЛ 7: ЗВУК ===

# === РАЗДЕЛ 8: ТЕСТОВЫЕ КАРТЫ (для отладки) ===
# УДАЛЕНО: test_cards_button теперь не используется (настройка карт перенесена в подменю Фильтр ставок и карт)

# === УПРАВЛЯЮЩИЕ КНОПКИ ===
@onready var apply_button: Button = find_child("ApplyButton", true, false)

# === АНИМАЦИЯ ===
@onready var panel_container: PanelContainer = find_child("PanelContainer", true, false)
var tween: Tween

# === НАВИГАТОР КЛАВИАТУРЫ ===
var keyboard_navigator: SettingsKeyboardNavigator = SettingsKeyboardNavigator.new()

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Инициализация сцены настроек
	
	Скрывает сцену при старте, подключает сигналы, настраивает локализацию
	и клавиатурную навигацию.
	"""
	# Скрываем при старте
	hide()

	# Скрываем чекбокс режима выживания (теперь всегда включён)
	if survival_checkbox:
		survival_checkbox.visible = false
		# Также скрываем родительский контейнер если есть
		var parent = survival_checkbox.get_parent()
		if parent and parent.name.contains("Survival"):
			parent.visible = false

	# Временно скрываем вход в режим обучения из релизного UI.
	# Сам режим и его код остаются в проекте для будущего обновления.
	if training_button and not SHOW_TRAINING_MENU_ENTRY:
		training_button.visible = false
		training_button.disabled = true
		training_button.focus_mode = Control.FOCUS_NONE
		training_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Подключаем сигналы кнопок
	_connect_signals()
	
	# Подключаем кнопки "Назад" в подменю (после того как подменю загружены)
	await get_tree().process_frame
	_connect_submenu_buttons()
	
	# Инициализируем подменю Сюжет (таблица прогрессии) - после загрузки всех узлов
	await get_tree().process_frame
	_initialize_story_submenu()
	
	# Инициализируем подменю Фильтр ставок и карт (OptionButton для карт)
	await get_tree().process_frame
	_initialize_card_options()

	# Подписываемся на изменение языка через EventBus для синхронизации
	EventBus.language_changed.connect(_on_language_changed_external)

	# Обновляем тексты (локализация)
	_update_texts()
	
	# Настраиваем навигацию с клавиатуры
	_setup_keyboard_navigation()

func _connect_signals() -> void:
	"""Подключение всех сигналов UI элементов
	
	Подключает сигналы кнопок, переключателей и других UI элементов
	к соответствующим обработчикам событий.
	"""
	# === ГЛАВНОЕ МЕНЮ ===
	if limits_button:
		limits_button.pressed.connect(func(): _show_menu("limits"))
	if bets_filter_button:
		bets_filter_button.pressed.connect(func(): _show_menu("bets"))
	if guests_button:
		guests_button.pressed.connect(_on_guest_settings_pressed)
	if story_button:
		story_button.pressed.connect(func(): _show_menu("story"))
	if advanced_settings_button:
		advanced_settings_button.pressed.connect(func(): _show_menu("advanced"))
	if training_button and SHOW_TRAINING_MENU_ENTRY:
		training_button.pressed.connect(_on_training_button_pressed)

	# Онлайн режим (программная кнопка)
	_create_online_mode_button()
	if online_mode_button:
		online_mode_button.pressed.connect(_on_online_mode_pressed)
	# ok_button больше не используется (убрана из UI)
	
	# === ПОДМЕНЮ: ЛИМИТЫ ===
	# Режим игры (внутри подменю Лимиты)
	if junket_button:
		junket_button.pressed.connect(_on_junket_pressed)
	if classic_button:
		classic_button.pressed.connect(_on_classic_pressed)

	# === ПОДМЕНЮ: ФИЛЬТР СТАВОК ===
	# Ставки (кнопки с toggle_mode) - теперь в подменю Фильтр ставок
	if bet_player_button:
		bet_player_button.toggled.connect(_on_bet_player_toggled)
	if bet_banker_button:
		bet_banker_button.toggled.connect(_on_bet_banker_toggled)
	if bet_tie_button:
		bet_tie_button.toggled.connect(_on_bet_tie_toggled)
	if bet_pair_button:
		bet_pair_button.toggled.connect(_on_bet_pair_toggled)
	
	# === ПОДМЕНЮ: РАСШИРЕННЫЕ НАСТРОЙКИ ===

	# Размер ставок
	if bet_size_option:
		bet_size_option.item_selected.connect(_on_bet_size_selected)

	# Чаевые
	if tip_percentage_spinbox:
		tip_percentage_spinbox.value_changed.connect(_on_tip_percentage_changed)

	# Карты шансов
	if chance_cards_checkbox:
		chance_cards_checkbox.toggled.connect(_on_chance_cards_toggled)

	# Автоматическое переключение режимов
	if auto_mode_switch_checkbox:
		auto_mode_switch_checkbox.toggled.connect(_on_auto_mode_switch_toggled)

	# Язык
	if ru_button:
		ru_button.pressed.connect(_on_ru_pressed)
	if en_button:
		en_button.pressed.connect(_on_en_pressed)

	# Рубашка карт
	if tiger_button:
		tiger_button.pressed.connect(_on_tiger_pressed)
	if leopard_button:
		leopard_button.pressed.connect(_on_leopard_pressed)

	# Ручная раздача теперь находится в подменю "Фильтр ставок и карт"
	
	# === ПОДМЕНЮ: ФИЛЬТР СТАВОК И КАРТ ===
	if test_cards_enabled_checkbox:
		test_cards_enabled_checkbox.toggled.connect(_on_test_cards_enabled_toggled)
	if banker1_card_option:
		banker1_card_option.item_selected.connect(func(idx): _on_card_selected("banker1", idx))
	if banker2_card_option:
		banker2_card_option.item_selected.connect(func(idx): _on_card_selected("banker2", idx))
	if player1_card_option:
		player1_card_option.item_selected.connect(func(idx): _on_card_selected("player1", idx))
	if player2_card_option:
		player2_card_option.item_selected.connect(func(idx): _on_card_selected("player2", idx))
	
	# === ПОДМЕНЮ: РАСШИРЕННЫЕ НАСТРОЙКИ ===
	if immortality_button:
		immortality_button.pressed.connect(_on_immortality_pressed)

	# Управляющие кнопки
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func open_settings() -> void:
	"""Открыть окно настроек
	
	Загружает текущие значения в UI, устанавливает контекст меню,
	показывает окно с анимацией и настраивает клавиатурную навигацию.
	"""
	# Загружаем значения в UI
	_load_current_values()
	
	# Инициализируем счетчики возврата гостей
	_setup_guest_return_counters()

	# Устанавливаем контекст меню настроек
	InputContextManager.set_context(InputContextManager.InputContext.MENU_SETTINGS)

	# Показываем окно
	show()
	
	# Анимация появления
	if panel_container:
		# Ждём кадр, чтобы панель получила правильный размер
		await get_tree().process_frame
		
		# Устанавливаем pivot_offset в центр для масштабирования из центра
		var panel_size = panel_container.size
		if panel_size.x > 0 and panel_size.y > 0:
			panel_container.pivot_offset = panel_size / 2.0
		else:
			# Если размер ещё не известен, используем rect_size
			panel_container.pivot_offset = panel_container.get_rect().size / 2.0
		
		panel_container.scale = Vector2(0.8, 0.8)
		panel_container.modulate.a = 0.0
		
		if tween:
			tween.kill()
		tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.3)
		tween.tween_property(panel_container, "modulate:a", 1.0, 0.3)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		
		# Настраиваем навигацию и устанавливаем начальный focus
		keyboard_navigator.setup_keyboard_navigation(self)
		if junket_button:
			junket_button.grab_focus()
	
	EventBus.settings_opened.emit()
	
	# Показываем главное меню при открытии
	_show_menu("main")
	
	print("⚙️  Окно настроек открыто")

# ═══════════════════════════════════════════════════════════════════════════
# НАВИГАЦИЯ МЕЖДУ МЕНЮ
# ═══════════════════════════════════════════════════════════════════════════

func _show_menu(menu_name: String) -> void:
	"""Показать указанное меню и скрыть остальные"""
	current_menu = menu_name
	
	# Скрываем все меню в области контента
	if main_menu_container:
		main_menu_container.visible = (menu_name == "main")
	
	if limits_submenu:
		limits_submenu.visible = (menu_name == "limits")
	
	if bets_filter_submenu:
		bets_filter_submenu.visible = (menu_name == "bets")
	
	if advanced_settings_submenu:
		advanced_settings_submenu.visible = (menu_name == "advanced")
	
	if story_submenu:
		story_submenu.visible = (menu_name == "story")

	if story_toggle_button:
		story_toggle_button.visible = (menu_name == "story")

	if content_footer_separator:
		content_footer_separator.visible = (menu_name != "story")
	
	# GuestReturnContainer виден только в главном меню
	if guest_return_container:
		guest_return_container.visible = (menu_name == "main")
	
	# Инициализируем OptionButton для карт при открытии подменю "Фильтр ставок и карт"
	if menu_name == "bets":
		# Убеждаемся, что OptionButton инициализированы
		if banker1_card_option and banker1_card_option.get_item_count() == 0:
			_initialize_card_options()
		else:
			# Просто обновляем значения
			_load_card_values()
	
	# BackButton и hseparator_bottom больше не используются (убраны из подменю)
	
	# Обновляем заголовок
	if title_label:
		if Localization:
			match menu_name:
				"main":
					title_label.text = Localization.t("SETTINGS_TITLE")
				"limits":
					title_label.text = Localization.t("SETTINGS_LIMITS")
				"bets":
					title_label.text = Localization.t("SETTINGS_BETS_FILTER")
				"advanced":
					title_label.text = Localization.t("SETTINGS_ADVANCED")
				"story":
					title_label.text = Localization.t("SETTINGS_STORY")
		else:
			match menu_name:
				"main":
					title_label.text = "НАСТРОЙКИ"
				"limits":
					title_label.text = "ЛИМИТЫ"
				"bets":
					title_label.text = "ФИЛЬТР СТАВОК И КАРТ"
				"advanced":
					title_label.text = "РАСШИРЕННЫЕ НАСТРОЙКИ"
				"story":
					title_label.text = "СЮЖЕТ ГОСТЕЙ"
		title_label.visible = true
	
	if menu_name == "story":
		_update_story_submenu_texts()
		if story_scroll_container:
			story_scroll_container.set_deferred("scroll_vertical", 0)
	
	print("📋 Показано меню: %s" % menu_name)

func _on_back_pressed() -> void:
	"""Возврат в главное меню (DEPRECATED - теперь используется _on_apply_pressed)"""
	_on_apply_pressed()

# ═══════════════════════════════════════════════════════════════════════════
# ПОДМЕНЮ: СЮЖЕТ (прогрессия гостей)
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_story_submenu() -> void:
	"""Инициализировать подменю Сюжет (таблица прогрессии гостей)"""
	if not story_submenu:
		return
	
	# Ищем элементы подменю и верхнего блока Сюжет гостей
	story_description_label = story_submenu.find_child("StoryDescriptionLabel", true, false)
	story_scroll_container = story_submenu.find_child("StoryScrollContainer", true, false)
	story_table_container = story_submenu.find_child("TableContainer", true, false)
	story_mode_info_label = story_submenu.find_child("StoryModeInfoLabel", true, false)
	story_toggle_button = find_child("StoryToggleButton", true, false)
	
	if not story_table_container:
		push_warning("SettingsScene: TableContainer не найден в подменю Сюжет")
		return
	
	# Создаём таблицу программно
	_create_story_table()
	
	# Загружаем текущие значения
	_load_story_values()
	
	# Подключаем сигналы
	_connect_story_signals()
	_update_story_submenu_texts()

func _create_story_table() -> void:
	"""Создать строки порогов прогрессии в подменю Сюжет"""
	if not story_table_container:
		return
	
	# Очищаем контейнер
	for child in story_table_container.get_children():
		child.queue_free()
	story_threshold_spinboxes.clear()
	story_reset_buttons.clear()
	story_table_container.add_theme_constant_override("separation", 8)
	
	# Создаём строки для порогов 2-6 (порог для 1 гостя = 0, не показываем)
	for guest_count in range(2, 7):  # 2, 3, 4, 5, 6
		var row = HBoxContainer.new()
		row.name = "Row%d" % guest_count
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		story_table_container.add_child(row)
		
		# Поясняющий текст слева
		var prompt_label = Label.new()
		prompt_label.name = "PromptLabel%d" % guest_count
		prompt_label.text = _get_story_threshold_text(guest_count)
		prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prompt_label.custom_minimum_size = Vector2(0, 44)
		prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
		prompt_label.add_theme_font_size_override("font_size", 21)
		row.add_child(prompt_label)
		
		# SpinBox для порога
		var spinbox = SpinBox.new()
		spinbox.name = "SpinBox%d" % guest_count
		spinbox.min_value = 0
		spinbox.max_value = 999999
		spinbox.step = 10
		spinbox.custom_minimum_size = Vector2(120, 44)
		spinbox.size_flags_horizontal = Control.SIZE_SHRINK_END
		spinbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		spinbox.set_meta("guest_count", guest_count)
		row.add_child(spinbox)
		_configure_story_threshold_spinbox(spinbox)
		
		# Большая кнопка-пилюля сброса с понятной подписью
		var reset_button = Button.new()
		reset_button.name = "ResetButton%d" % guest_count
		reset_button.text = Localization.t("SETTINGS_STORY_RESET")
		reset_button.custom_minimum_size = Vector2(96, 44)
		reset_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		reset_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		reset_button.add_theme_font_size_override("font_size", 15)
		reset_button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
		reset_button.add_theme_stylebox_override("normal", _create_story_reset_button_style(Color(0.22, 0.22, 0.27, 1), Color(0.58, 0.58, 0.68, 1)))
		reset_button.add_theme_stylebox_override("hover", _create_story_reset_button_style(Color(0.28, 0.28, 0.34, 1), Color(0.76, 0.76, 0.86, 1)))
		reset_button.add_theme_stylebox_override("pressed", _create_story_reset_button_style(Color(0.18, 0.18, 0.23, 1), Color(0.68, 0.68, 0.78, 1)))
		reset_button.add_theme_stylebox_override("focus", _create_story_reset_button_style(Color(0.28, 0.28, 0.34, 1), Color(0.88, 0.76, 0.48, 1)))
		reset_button.tooltip_text = Localization.t("SETTINGS_STORY_RESET_TOOLTIP")
		reset_button.set_meta("guest_count", guest_count)
		
		row.add_child(reset_button)
		
		story_threshold_spinboxes[guest_count] = spinbox
		story_reset_buttons[guest_count] = reset_button
	
	print("🎯 Список порогов прогрессии создан в подменю Сюжет")

func _load_story_values() -> void:
	"""Загрузить текущие значения прогрессии в таблицу"""
	if not GuestProgressionManager:
		return
	
	var thresholds = GuestProgressionManager.get_thresholds()
	var auto_mode = GuestProgressionManager.is_auto_mode_enabled()
	
	# Обновляем SpinBox'ы
	for guest_count in range(2, 7):
		if story_threshold_spinboxes.has(guest_count):
			var spinbox = story_threshold_spinboxes[guest_count]
			if spinbox:
				var value = thresholds.get(guest_count, 0)
				spinbox.value = value
	
	_update_story_mode_texts(auto_mode)
	_update_story_button_text()

func _connect_story_signals() -> void:
	"""Подключить сигналы для подменю Сюжет"""
	# Подключаем сигналы SpinBox'ов
	for guest_count in story_threshold_spinboxes.keys():
		var spinbox = story_threshold_spinboxes[guest_count]
		if spinbox:
			spinbox.value_changed.connect(_on_story_threshold_changed.bind(guest_count))
	
	# Подключаем кнопки сброса
	for guest_count in story_reset_buttons.keys():
		var reset_button = story_reset_buttons[guest_count]
		if reset_button:
			reset_button.pressed.connect(_on_story_reset_pressed.bind(guest_count))
	
	# Подключаем кнопку переключения режима
	if story_toggle_button and story_toggle_button.pressed.get_connections().is_empty():
		story_toggle_button.pressed.connect(_on_story_toggle_pressed)

func _on_story_threshold_changed(value: float, guest_count: int) -> void:
	"""Обработка изменения порога прогрессии
	
	Args:
		value: Новое значение из SpinBox
		guest_count: Количество гостей (передается через bind)
	"""
	if not GuestProgressionManager:
		return
	
	var spinbox = story_threshold_spinboxes.get(guest_count)
	if not spinbox:
		return
	
	# Получаем все текущие пороги
	var current_thresholds = GuestProgressionManager.get_thresholds()
	
	# Обновляем порог для указанного количества гостей
	var new_value = int(value)
	current_thresholds[guest_count] = new_value
	
	# Устанавливаем все пороги обратно
	GuestProgressionManager.set_thresholds(current_thresholds)
	print("🎯 Порог для %d гостей изменён: %d" % [guest_count, new_value])

func _on_story_reset_pressed(guest_count: int) -> void:
	"""Обработка нажатия кнопки сброса порога"""
	if not GuestProgressionManager:
		return
	
	# Получаем пороги по умолчанию
	var default_thresholds = GuestProgressionManager.get_default_thresholds()
	var default_value = default_thresholds.get(guest_count, 0)
	
	# Получаем все текущие пороги и обновляем один
	var current_thresholds = GuestProgressionManager.get_thresholds()
	current_thresholds[guest_count] = default_value
	
	# Устанавливаем все пороги обратно
	GuestProgressionManager.set_thresholds(current_thresholds)
	
	# Обновляем SpinBox
	if story_threshold_spinboxes.has(guest_count):
		var spinbox = story_threshold_spinboxes[guest_count]
		if spinbox:
			spinbox.value = default_value
	
	print("🎯 Порог для %d гостей сброшен: %d" % [guest_count, default_value])

func _on_story_toggle_pressed() -> void:
	"""Переключить режим сюжета гостей"""
	if not GuestProgressionManager:
		return
	
	var new_state = not GuestProgressionManager.is_auto_mode_enabled()
	GuestProgressionManager.set_auto_mode(new_state)
	_update_story_mode_texts(new_state)
	_update_story_button_text()
	print("🎯 Автоматический режим прогрессии: %s" % ("включен" if new_state else "выключен"))

func _update_story_submenu_texts() -> void:
	"""Обновить тексты подменю Сюжет гостей."""
	if story_description_label:
		story_description_label.text = Localization.t("SETTINGS_STORY_DESCRIPTION")
	
	var auto_mode_enabled = true
	if GuestProgressionManager:
		auto_mode_enabled = GuestProgressionManager.is_auto_mode_enabled()
	
	_update_story_mode_texts(auto_mode_enabled)
	
	if story_table_container:
		for guest_count in range(2, 7):
			var prompt_label = story_table_container.get_node_or_null("Row%d/PromptLabel%d" % [guest_count, guest_count]) as Label
			if prompt_label:
				prompt_label.text = _get_story_threshold_text(guest_count)
			if story_reset_buttons.has(guest_count):
				var reset_button = story_reset_buttons[guest_count]
				if reset_button:
					reset_button.text = Localization.t("SETTINGS_STORY_RESET")
					reset_button.tooltip_text = Localization.t("SETTINGS_STORY_RESET_TOOLTIP")

func _update_story_mode_texts(is_enabled: bool) -> void:
	"""Обновить подписи переключателя и пояснение режима сюжета."""
	if story_toggle_button:
		story_toggle_button.text = Localization.t("SETTINGS_STORY_TOGGLE_ON") if is_enabled else Localization.t("SETTINGS_STORY_TOGGLE_OFF")
	if story_mode_info_label:
		story_mode_info_label.text = Localization.t("SETTINGS_STORY_MODE_INFO_ON") if is_enabled else Localization.t("SETTINGS_STORY_MODE_INFO_OFF")

func _update_story_button_text() -> void:
	"""Обновить подпись кнопки Сюжет в главном меню с текущим статусом."""
	if not story_button:
		return
	
	var auto_mode_enabled = true
	if GuestProgressionManager:
		auto_mode_enabled = GuestProgressionManager.is_auto_mode_enabled()
	
	story_button.text = Localization.t("SETTINGS_STORY_BUTTON_ON") if auto_mode_enabled else Localization.t("SETTINGS_STORY_BUTTON_OFF")

func _get_story_threshold_text(guest_count: int) -> String:
	"""Получить локализованный текст строки порога для указанного гостя."""
	return Localization.t("SETTINGS_STORY_ROW_%d" % guest_count)

func _configure_story_threshold_spinbox(spinbox: SpinBox) -> void:
	"""Сделать компактное числовое поле без боковых стрелок."""
	spinbox.add_theme_constant_override("buttons_width", 0)
	spinbox.add_theme_constant_override("field_and_buttons_separation", 0)
	spinbox.add_theme_constant_override("set_min_buttons_width_from_icons", 0)

	var transparent = Color(1, 1, 1, 0)
	for color_name in [
		"up_icon_modulate",
		"up_hover_icon_modulate",
		"up_pressed_icon_modulate",
		"up_disabled_icon_modulate",
		"down_icon_modulate",
		"down_hover_icon_modulate",
		"down_pressed_icon_modulate",
		"down_disabled_icon_modulate"
	]:
		spinbox.add_theme_color_override(color_name, transparent)

	var line_edit = spinbox.get_line_edit()
	if line_edit:
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.select_all_on_focus = true

func _create_story_reset_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	"""Создать круглую stylebox для кнопки сброса."""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	style.corner_radius_bottom_left = 24
	return style

func _connect_submenu_buttons() -> void:
	"""Подключить кнопку 'Назад' (DEPRECATED - BackButton больше не используется)"""
	# BackButton больше не используется, используется только ApplyButton (переименована в "Назад")
	pass

func close_settings() -> void:
	"""Закрыть окно настроек
	
	Возвращает контекст игры, скрывает окно с анимацией
	и эмитит сигнал закрытия настроек.
	"""
	# Очищаем счетчики возврата гостей
	_cleanup_guest_return_counters()
	
	# Возвращаем контекст игры
	InputContextManager.set_context(InputContextManager.InputContext.GAME)
	
	# Анимация исчезновения
	if panel_container:
		# Убеждаемся, что pivot_offset установлен в центр
		var panel_size = panel_container.size
		if panel_size.x > 0 and panel_size.y > 0:
			panel_container.pivot_offset = panel_size / 2.0
		else:
			# Если размер ещё не известен, используем rect_size
			panel_container.pivot_offset = panel_container.get_rect().size / 2.0
		
		if tween:
			tween.kill()
		tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel_container, "scale", Vector2(0.8, 0.8), 0.2)
		tween.tween_property(panel_container, "modulate:a", 0.0, 0.2)
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BACK)
		await tween.finished
	
	# Очищаем счетчики возврата гостей при закрытии
	_cleanup_guest_return_counters()
	
	# Возвращаемся в главное меню перед закрытием
	_show_menu("main")
	
	hide()
	EventBus.settings_closed.emit()
	print("⚙️  Окно настроек закрыто")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА КЛАВИАТУРЫ
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	"""Обработка ввода (клавиатура и геймпад) - используем _unhandled_input для навигации
	
	Делегирует в SettingsKeyboardNavigator.
	"""
	if keyboard_navigator.handle_unhandled_input(event, self):
		return
	
	# Action обрабатывается в _input() для перехвата событий геймпада

func _input(event: InputEvent) -> void:
	"""Обработка ввода (используем _input для перехвата Escape и action даже если фокус на кнопке)
	
	Делегирует в SettingsKeyboardNavigator.
	Обрабатывает ESC для вызова кнопки "Назад" (только когда меню видно).
	"""
	# Обрабатываем ESC только когда меню настроек видно
	if not visible:
		return
	
	# Обработка ESC - вызывает кнопку "Назад" (используем action "exit" как в InputHandler)
	if event.is_action_pressed("exit") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		_on_apply_pressed()
		get_viewport().set_input_as_handled()
		return
	
	if keyboard_navigator.handle_input(event, self, apply_button):
		return

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════════════════

func _load_current_values() -> void:
	"""Загрузить текущие значения из менеджеров в UI
	
	Синхронизирует все UI элементы с текущими значениями из менеджеров:
	- Режим игры (Junket/Classic)
	- Настройки ставок (Player, Banker, Tie, Pair)
	- Размер ставок
	- Чаевые
	- Язык
	- Рубашка карт
	- Режим управления камерой
	"""
	# Режим игры - загружаем из GameModeManager
	var current_mode = GameModeManager.get_mode_string()
	_update_mode_buttons(current_mode)
	_update_mode_info(current_mode)

	# Ставки
	if bet_player_button:
		bet_player_button.button_pressed = PayoutSettingsManager.player_payout_enabled
		_update_bet_button_style(bet_player_button, PayoutSettingsManager.player_payout_enabled)
	if bet_banker_button:
		bet_banker_button.button_pressed = PayoutSettingsManager.banker_payout_enabled
		_update_bet_button_style(bet_banker_button, PayoutSettingsManager.banker_payout_enabled)
	if bet_tie_button:
		bet_tie_button.button_pressed = PayoutSettingsManager.tie_payout_enabled
		_update_bet_button_style(bet_tie_button, PayoutSettingsManager.tie_payout_enabled)
	if bet_pair_button:
		# Для пары проверяем, включена ли хотя бы одна пара
		var pairs_enabled = PayoutSettingsManager.player_pair_payout_enabled or PayoutSettingsManager.banker_pair_payout_enabled
		bet_pair_button.button_pressed = pairs_enabled
		_update_bet_button_style(bet_pair_button, pairs_enabled)

	# Размер ставок
	if bet_size_option:
		bet_size_option.selected = BetProfileManager.get_profile()

	# Чаевые
	if tip_percentage_spinbox:
		tip_percentage_spinbox.value = SaveManager.instance.load_tip_percentage()

	# Карты шансов
	if chance_cards_checkbox:
		chance_cards_checkbox.button_pressed = SaveManager.instance.load_chance_cards_enabled()

	# Автоматическое переключение режимов
	if auto_mode_switch_checkbox:
		auto_mode_switch_checkbox.button_pressed = SaveManager.instance.load_auto_mode_switch_enabled()

	# Язык
	_update_lang_buttons()

	# Рубашка карт
	_update_card_back_buttons()
	
	# Ручная раздача (в подменю Фильтр ставок и карт)
	_load_card_values()
	
	# Свободная тренировка
	_update_immortality_button()

# ═══════════════════════════════════════════════════════════════════════════
# НАВИГАЦИЯ С КЛАВИАТУРЫ И ГЕЙМПАДА (делегировано в SettingsKeyboardNavigator)
# ═══════════════════════════════════════════════════════════════════════════

func _navigate_focus(direction: String) -> void:
	"""Навигация по меню с помощью стрелок/WASD/геймпада
	
	Делегирует в SettingsKeyboardNavigator.
	
	Args:
		direction: Направление ("left", "right", "up", "down")
	"""
	keyboard_navigator.navigate_focus(direction, self)

func _focus_next() -> void:
	"""Перейти к следующему элементу меню
	
	Делегирует в SettingsKeyboardNavigator.
	"""
	keyboard_navigator.focus_next(self)

func _focus_previous() -> void:
	"""Перейти к предыдущему элементу меню
	
	Делегирует в SettingsKeyboardNavigator.
	"""
	keyboard_navigator.focus_previous(self)

func _setup_keyboard_navigation() -> void:
	"""Настроить навигацию с клавиатуры между элементами меню
	
	Делегирует в SettingsKeyboardNavigator.
	"""
	keyboard_navigator.setup_keyboard_navigation(self)

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ UI
# ═══════════════════════════════════════════════════════════════════════════

func _update_texts() -> void:
	"""Обновить все тексты на основе текущего языка
	
	Обновляет все текстовые элементы UI с использованием локализации:
	- Заголовок
	- Кнопка Apply
	- Кнопки рубашки карт
	- Опции размера ставок
	- Секция чаевых
	- Кнопка настроек гостей
	"""
	if title_label:
		match current_menu:
			"limits":
				title_label.text = Localization.t("SETTINGS_LIMITS")
			"bets":
				title_label.text = Localization.t("SETTINGS_BETS_FILTER")
			"advanced":
				title_label.text = Localization.t("SETTINGS_ADVANCED")
			"story":
				title_label.text = Localization.t("SETTINGS_STORY")
			_:
				title_label.text = Localization.t("SETTINGS_TITLE")

	if apply_button:
		apply_button.text = "Назад"  # Переименовано из "ОК"

	# Рубашка карт
	if tiger_button:
		tiger_button.text = Localization.t("SETTINGS_CARD_BACK_TIGER")
	if leopard_button:
		leopard_button.text = Localization.t("SETTINGS_CARD_BACK_LEOPARD")

	# Размер ставок - обновляем опции
	if bet_size_option:
		_setup_bet_size_options()
	
	# Чаевые
	var tip_section_label = find_child("SectionTipPercentage", true, false)
	if tip_section_label:
		tip_section_label.text = Localization.t("SETTINGS_SECTION_TIP_PERCENTAGE")
	
	# Кнопка настроек гостей
	if guest_settings_button:
		guest_settings_button.text = Localization.t("GUEST_SETTINGS_BUTTON")
	
	# Кнопка прогрессии гостей
	if guest_progression_button:
		guest_progression_button.text = Localization.t("GUEST_PROGRESSION_BUTTON")
	if story_button:
		_update_story_button_text()
	
	# Ручная раздача
	if card_settings_label:
		card_settings_label.text = Localization.t("SETTINGS_CARD_SETTINGS")
	if test_cards_enabled_checkbox:
		test_cards_enabled_checkbox.text = Localization.t("SETTINGS_TEST_CARDS_ENABLED")
	
	# Свободная тренировка
	if section_immortality_label:
		section_immortality_label.text = Localization.t("SETTINGS_SECTION_FREE_PRACTICE")
	if immortality_button:
		_update_immortality_button()
	
	_update_story_submenu_texts()

func _update_mode_buttons(mode: String) -> void:
	"""Обновить состояние кнопок режима игры
	
	Отключает активный режим и включает неактивный.
	
	Args:
		mode: Режим игры ("junket" или "classic")
	"""
	if not junket_button or not classic_button:
		return

	if mode == "junket":
		junket_button.disabled = true
		classic_button.disabled = false
	else:
		junket_button.disabled = false
		classic_button.disabled = true

func _update_mode_info(mode: String) -> void:
	"""Обновить информацию о режиме игры
	
	Обновляет текст информационной метки с описанием режима.
	
	Args:
		mode: Режим игры ("junket" или "classic")
	"""
	if not mode_info_label:
		return

	# Используем локализацию вместо хардкода
	if mode == "junket":
		mode_info_label.text = Localization.t("MODE_INFO_JUNKET")
	else:  # classic
		mode_info_label.text = Localization.t("MODE_INFO_CLASSIC")

func _update_lang_buttons() -> void:
	"""Обновить состояние кнопок языка
	
	Отключает активный язык и включает неактивный.
	"""
	if not ru_button or not en_button:
		return

	var current_lang = Localization.get_lang()
	ru_button.disabled = (current_lang == "ru")
	en_button.disabled = (current_lang == "en")

func _update_card_back_buttons() -> void:
	"""Обновить состояние кнопок рубашки карт
	
	Отключает активную рубашку и включает неактивную.
	"""
	if not tiger_button or not leopard_button:
		return

	var current_style = SaveManager.instance.load_card_back_style()
	tiger_button.disabled = (current_style == "tiger")
	leopard_button.disabled = (current_style == "leopard")

func _setup_bet_size_options() -> void:
	"""Настроить опции для OptionButton размера ставок
	
	Очищает и заполняет OptionButton опциями размера ставок
	с использованием локализации.
	"""
	if not bet_size_option:
		return

	bet_size_option.clear()
	bet_size_option.add_item(Localization.t("BET_PROFILE_SMALL"), 0)
	bet_size_option.add_item(Localization.t("BET_PROFILE_MEDIUM"), 1)
	bet_size_option.add_item(Localization.t("BET_PROFILE_LARGE"), 2)
	bet_size_option.selected = BetProfileManager.get_profile()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

# === РЕЖИМ ИГРЫ ===
func _on_junket_pressed():
	"""Обработка нажатия кнопки Junket"""
	_switch_game_mode("junket")

func _on_classic_pressed():
	"""Обработка нажатия кнопки Classic"""
	_switch_game_mode("classic")

func _switch_game_mode(mode: String) -> void:
	"""Переключить режим игры (Junket/Classic)
	
	Обновляет UI и эмитит сигнал изменения режима.
	
	Args:
		mode: Режим игры ("junket" или "classic")
	"""
	_update_mode_buttons(mode)
	_update_mode_info(mode)
	mode_changed.emit(mode)
	print("🎮 Режим игры изменён: %s" % mode.capitalize())

# === СТАВКИ ===

func _on_training_button_pressed() -> void:
	"""Обработка нажатия кнопки 'Обучение' — включить режим обучения и закрыть настройки"""
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_method("activate_training_mode"):
		game_controller.activate_training_mode()
		hide()

func _on_guest_settings_pressed():
	"""Обработка нажатия кнопки 'ГОСТИ' для открытия меню настроек гостей"""
	# Ищем меню в сцене Game
	var game_scene = get_tree().get_first_node_in_group("game")
	if not game_scene:
		game_scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	
	var guest_menu = null
	if game_scene:
		guest_menu = game_scene.get_node_or_null("GuestMenuScene")
	
	if not guest_menu:
		# Создаём меню если его нет
		var menu_scene = load("res://scenes/GuestMenuScene.tscn")
		if menu_scene:
			guest_menu = menu_scene.instantiate()
			if game_scene:
				game_scene.add_child(guest_menu)
			else:
				get_tree().root.add_child(guest_menu)
		else:
			push_error("SettingsScene: не удалось загрузить сцену GuestMenuScene.tscn")
			return
	
	if guest_menu and guest_menu.has_method("open_menu"):
		guest_menu.open_menu()
		print("👥 Открыто меню настроек гостей")

func _on_guest_progression_pressed():
	"""Обработка нажатия кнопки 'ПРОГРЕССИЯ ГОСТЕЙ' (DEPRECATED - теперь используется подменю Сюжет)"""
	# Теперь открываем подменю Сюжет вместо попапа
	_show_menu("story")

func _on_bet_player_toggled(pressed: bool):
	"""Обработка переключения ставки Player"""
	PayoutSettingsManager.toggle_player(pressed)
	# Эмитим сигнал для управления фишками (слушает GameController)
	EventBus.payout_setting_changed.emit("Player", pressed)
	_update_bet_button_style(bet_player_button, pressed)

func _on_bet_banker_toggled(pressed: bool):
	"""Обработка переключения ставки Banker"""
	PayoutSettingsManager.toggle_banker(pressed)
	EventBus.payout_setting_changed.emit("Banker", pressed)
	_update_bet_button_style(bet_banker_button, pressed)

func _on_bet_tie_toggled(pressed: bool):
	"""Обработка переключения ставки Tie"""
	PayoutSettingsManager.toggle_tie(pressed)
	EventBus.payout_setting_changed.emit("Tie", pressed)
	_update_bet_button_style(bet_tie_button, pressed)

func _on_bet_pair_toggled(pressed: bool):
	"""Обработка переключения пары (объединенная кнопка для обеих пар)"""
	# Переключаем обе пары одновременно
	PayoutSettingsManager.toggle_player_pair(pressed)
	PayoutSettingsManager.toggle_banker_pair(pressed)
	EventBus.payout_setting_changed.emit("PairPlayer", pressed)
	EventBus.payout_setting_changed.emit("PairBanker", pressed)
	_update_bet_button_style(bet_pair_button, pressed)

# === РАЗМЕР СТАВОК ===
func _on_bet_size_selected(index: int):
	"""Обработка выбора размера ставок"""
	BetProfileManager.set_profile(index as BetProfileManager.BetProfile)
	print("💰 Размер ставок изменён: %s" % BetProfileManager.get_profile_name())

# === ЧАЕВЫЕ ===
func _on_tip_percentage_changed(value: float):
	"""Обработка изменения процента чаевых"""
	SaveManager.instance.save_tip_percentage(value)
	print("💰 Процент чаевых изменён: %.1f%%" % value)

# === КАРТЫ ШАНСОВ ===
func _on_chance_cards_toggled(pressed: bool):
	"""Обработка переключения карт шансов"""
	SaveManager.instance.save_chance_cards_enabled(pressed)
	print("🎴 Карты шансов: %s" % ("включены" if pressed else "выключены"))
	# Обновляем видимость ChanceCardStorage в реальном времени
	_update_chance_card_storage_visibility()

func _on_auto_mode_switch_toggled(pressed: bool):
	"""Обработка переключения автоматического переключения режимов"""
	SaveManager.instance.save_auto_mode_switch_enabled(pressed)
	print("🔄 Автоматическое переключение режимов: %s" % ("включено" if pressed else "выключено"))

func _update_chance_card_storage_visibility() -> void:
	"""Обновить видимость ChanceCardStorage в зависимости от настройки"""
	var game_scene = get_tree().get_first_node_in_group("game")
	if not game_scene:
		game_scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	
	if game_scene:
		var chance_storage = game_scene.get_node_or_null("TopUI/ChanceCardStorage")
		if chance_storage:
			var enabled = SaveManager.instance.load_chance_cards_enabled()
			chance_storage.visible = enabled
			print("🎴 ChanceCardStorage: %s" % ("показан" if enabled else "скрыт"))

# === ЯЗЫК ===
func _on_ru_pressed():
	"""Обработка нажатия кнопки RU"""
	Localization.set_lang("ru")
	SaveManager.instance.save_language("ru")  # Сохраняем выбор языка
	_update_lang_buttons()
	_update_texts()
	language_changed.emit("ru")
	print("🌍 Язык изменён: Русский")

func _on_en_pressed():
	"""Обработка нажатия кнопки EN"""
	Localization.set_lang("en")
	SaveManager.instance.save_language("en")  # Сохраняем выбор языка
	_update_lang_buttons()
	_update_texts()
	language_changed.emit("en")
	print("🌍 Язык изменён: English")

# === РУБАШКА КАРТ ===
func _on_tiger_pressed():
	"""Обработка нажатия кнопки Tiger"""
	SaveManager.instance.save_card_back_style("tiger")
	_update_card_back_buttons()
	EventBus.card_back_style_changed.emit("tiger")
	print("🎴 Рубашка карт изменена: Тигр")

func _on_leopard_pressed():
	"""Обработка нажатия кнопки Leopard"""
	SaveManager.instance.save_card_back_style("leopard")
	_update_card_back_buttons()
	EventBus.card_back_style_changed.emit("leopard")
	print("🎴 Рубашка карт изменена: Леопард")

# === ТЕСТОВЫЕ КАРТЫ (в подменю Фильтр ставок и карт) ===
func _initialize_card_options() -> void:
	"""Инициализировать OptionButton для выбора карт"""
	var card_options = [
		banker1_card_option,
		banker2_card_option,
		player1_card_option,
		player2_card_option
	]
	
	# Список значений карт: Случайная, A, 2, 3, 4, 5, 6, 7, 8, 9, J, Q, K
	var card_values = ["Случайная", "A", "2", "3", "4", "5", "6", "7", "8", "9", "J", "Q", "K"]
	
	for option_button in card_options:
		if not option_button:
			continue
		
		option_button.clear()
		for value in card_values:
			option_button.add_item(value)
	
	# Загружаем текущие значения из TestCardsManager
	_load_card_values()

func _load_card_values() -> void:
	"""Загрузить текущие значения карт из TestCardsManager в OptionButton"""
	if not TestCardsManager:
		return
	
	var positions = {
		"banker1": banker1_card_option,
		"banker2": banker2_card_option,
		"player1": player1_card_option,
		"player2": player2_card_option
	}
	
	for position in positions.keys():
		var option_button = positions[position]
		if not option_button:
			continue
		
		var card_data = TestCardsManager.get_card_data(position)
		var value = card_data.get("value", 0)
		
		# Преобразуем значение TestCardsManager в индекс OptionButton
		# TestCardsManager: 0=случайная, 1=A, 2-9, 11=J, 12=Q, 13=K (нет 10)
		# OptionButton: 0=Случайная, 1=A, 2-9, 10=J, 11=Q, 12=K
		var option_index = 0
		if value == 0:
			option_index = 0  # Случайная
		elif value >= 1 and value <= 9:
			option_index = value  # A, 2-9
		elif value == 11:
			option_index = 10  # J
		elif value == 12:
			option_index = 11  # Q
		elif value == 13:
			option_index = 12  # K
		
		option_button.selected = option_index
	
	# Загружаем состояние чекбокса
	if test_cards_enabled_checkbox:
		test_cards_enabled_checkbox.button_pressed = TestCardsManager.enabled

func _on_test_cards_enabled_toggled(pressed: bool) -> void:
	"""Обработка переключения режима ручной раздачи"""
	if TestCardsManager:
		TestCardsManager.set_enabled(pressed)

func _on_card_selected(position: String, value_index: int) -> void:
	"""Обработка выбора карты в OptionButton
	position: "banker1", "banker2", "player1", "player2"
	value_index: 0=Случайная, 1=A, 2-9, 10=J, 11=Q, 12=K
	"""
	if not TestCardsManager:
		return
	
	# Преобразуем индекс OptionButton в значение TestCardsManager
	# OptionButton: 0=Случайная, 1=A, 2-9, 10=J, 11=Q, 12=K
	# TestCardsManager: 0=случайная, 1=A, 2-9, 11=J, 12=Q, 13=K (нет 10)
	var test_value = 0
	if value_index == 0:
		test_value = 0  # Случайная
	elif value_index >= 1 and value_index <= 9:
		test_value = value_index  # A, 2-9
	elif value_index == 10:
		test_value = 11  # J
	elif value_index == 11:
		test_value = 12  # Q
	elif value_index == 12:
		test_value = 13  # K
	
	if test_value == 0:
		# Случайная карта
		TestCardsManager.set_test_card(position, 0, 0)
	else:
		# Случайная масть (0-3)
		var random_suit = randi() % 4
		TestCardsManager.set_test_card(position, random_suit, test_value)
	
	# Автоматически включаем ручную раздачу при выборе карты
	if not TestCardsManager.enabled:
		TestCardsManager.set_enabled(true)
		if test_cards_enabled_checkbox:
			test_cards_enabled_checkbox.button_pressed = true

# === СВОБОДНАЯ ТРЕНИРОВКА ===
func _on_immortality_pressed() -> void:
	"""Обработка нажатия кнопки 'Свободная тренировка'"""
	if not SaveManager:
		return
	
	var current = SaveManager.instance.load_immortality_enabled()
	var new_value = not current
	SaveManager.instance.save_immortality_enabled(new_value)
	
	if new_value:
		# При включении свободной тренировки добавляем бонусные чаевые
		SaveManager.instance.add_score(100)
		
		# Обновляем статистику если есть StatsManager
		if StatsManager and StatsManager.instance:
			StatsManager.instance.update_stats()
	else:
		# При выключении свободной тренировки сбрасываем чаевые на ноль
		SaveManager.instance.score = 0
		SaveManager.instance.save_data()
		
		# Обновляем статистику если есть StatsManager
		if StatsManager and StatsManager.instance:
			StatsManager.instance.update_stats()
	
	_update_immortality_button()

func _update_immortality_button() -> void:
	"""Обновить текст кнопки свободной тренировки"""
	if not immortality_button:
		return
	
	if not SaveManager:
		return
	
	var enabled = SaveManager.instance.load_immortality_enabled()
	if Localization:
		immortality_button.text = Localization.t("SETTINGS_IMMORTALITY") + (" (вкл)" if enabled else " (выкл)")
	else:
		immortality_button.text = "Свободная тренировка" + (" (вкл)" if enabled else " (выкл)")

# === УПРАВЛЯЮЩИЕ КНОПКИ ===
func _on_apply_pressed():
	"""Обработка нажатия кнопки "Назад" (переименована из "ОК")
	
	Логика:
	- Если открыто подменю → возврат в главное меню
	- Если открыто главное меню → закрыть настройки
	"""
	# Если мы в подменю, возвращаемся в главное меню
	if current_menu != "main":
		_show_menu("main")
		print("⬅️ Возврат в главное меню настроек")
		return
	
	# Если в главном меню, закрываем настройки
	close_settings()
	print("✅ Настройки закрыты")

func _on_ok_pressed():
	"""Обработка нажатия кнопки "ОК" (DEPRECATED - теперь используется _on_apply_pressed)"""
	_on_apply_pressed()

# === СИНХРОНИЗАЦИЯ С EVENTBUS ===
func _on_language_changed_external(lang: String):
	"""Обработка внешнего изменения языка через EventBus"""
	# Синхронизируем UI с новым языком
	_update_lang_buttons()
	_update_texts()

	# Обновляем информацию о режиме игры с учетом нового языка
	var current_mode = GameModeManager.get_mode_string()
	_update_mode_info(current_mode)

	print("🔄 SettingsScene синхронизирован с языком: %s" % lang)

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ СЧЕТЧИКАМИ ВОЗВРАТА ГОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func _setup_guest_return_counters() -> void:
	"""Настроить счетчики возврата гостей в меню настроек"""
	if not guest_return_container:
		return
	
	# Очищаем старые счетчики, если есть
	_cleanup_guest_return_counters()
	
	# Создаем новый экземпляр GuestReturnCounterUI
	guest_return_counter_ui = GuestReturnCounterUI.new()
	guest_return_container.add_child(guest_return_counter_ui)
	print("👋 Счетчики возврата гостей настроены в меню настроек")

func _cleanup_guest_return_counters() -> void:
	"""Очистить счетчики возврата гостей"""
	if guest_return_counter_ui and is_instance_valid(guest_return_counter_ui):
		guest_return_counter_ui.queue_free()
		guest_return_counter_ui = null
	if guest_return_container:
		# Удаляем все дочерние элементы
		for child in guest_return_container.get_children():
			if is_instance_valid(child):
				child.queue_free()

# ═══════════════════════════════════════════════════════════════════════════
# СТИЛИЗАЦИЯ КНОПОК СТАВОК
# ═══════════════════════════════════════════════════════════════════════════

func _update_bet_button_style(button: Button, enabled: bool) -> void:
	"""Обновить визуальный стиль кнопки ставки (вкл/выкл)
	
	Args:
		button: Кнопка для стилизации
		enabled: Включена ли ставка
	"""
	if not button:
		return
	
	# Создаём StyleBoxFlat для кнопки
	var style_normal = StyleBoxFlat.new()
	var style_hover = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	
	# Общие настройки для всех состояний
	for style in [style_normal, style_hover, style_pressed]:
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	
	if enabled:
		# Включено: яркая рамка, активный фон
		style_normal.bg_color = Color(0.25, 0.35, 0.25, 0.9)  # Зеленоватый фон
		style_normal.border_color = Color(0.4, 0.7, 0.4, 1.0)  # Яркая зеленая рамка
		
		style_hover.bg_color = Color(0.3, 0.4, 0.3, 0.95)
		style_hover.border_color = Color(0.5, 0.8, 0.5, 1.0)
		
		style_pressed.bg_color = Color(0.2, 0.3, 0.2, 0.9)
		style_pressed.border_color = Color(0.4, 0.7, 0.4, 1.0)
		
		button.modulate.a = 1.0
		button.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95, 1.0))
	else:
		# Выключено: тусклая рамка, неактивный фон
		style_normal.bg_color = Color(0.15, 0.15, 0.15, 0.6)  # Темный фон
		style_normal.border_color = Color(0.4, 0.4, 0.4, 0.6)  # Серая рамка
		
		style_hover.bg_color = Color(0.18, 0.18, 0.18, 0.7)
		style_hover.border_color = Color(0.5, 0.5, 0.5, 0.7)
		
		style_pressed.bg_color = Color(0.12, 0.12, 0.12, 0.5)
		style_pressed.border_color = Color(0.4, 0.4, 0.4, 0.6)
		
		button.modulate.a = 0.65
		button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))


# ═══════════════════════════════════════════════════════════════════════════
# ОНЛАЙН РЕЖИМ
# ═══════════════════════════════════════════════════════════════════════════

func _create_online_mode_button() -> void:
	"""Создаёт кнопку «Онлайн режим» в главном меню настроек."""
	if not main_menu_container:
		return

	online_mode_button = Button.new()
	online_mode_button.name = "OnlineModeButton"
	online_mode_button.text = "🌐 Онлайн режим"
	online_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_mode_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	online_mode_button.custom_minimum_size = Vector2(180, 40)

	# Стиль под остальные кнопки
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.25, 0.4, 0.8)
	style_normal.border_color = Color(0.3, 0.6, 0.9, 0.9)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.15, 0.35, 0.5, 0.9)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.08, 0.2, 0.35, 0.9)

	online_mode_button.add_theme_stylebox_override("normal", style_normal)
	online_mode_button.add_theme_stylebox_override("hover", style_hover)
	online_mode_button.add_theme_stylebox_override("pressed", style_pressed)

	main_menu_container.add_child(online_mode_button)
	print("🌐 Кнопка «Онлайн режим» создана")


func _on_online_mode_pressed() -> void:
	"""Переход в онлайн меню."""
	print("🌐 Переход в онлайн режим...")
	# Закрываем настройки
	close_settings()
	# Небольшая задержка для завершения анимации
	await get_tree().create_timer(0.1).timeout
	# Переходим на сцену онлайн меню
	get_tree().change_scene_to_file("res://scenes/network/MainMenu.tscn")
