# res://scripts/SettingsScene.gd
# Сцена настроек (overlay поверх Game.tscn)
# Заменяет старый SettingsPopup

extends CanvasLayer

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

# === РАЗДЕЛ 4: РАЗМЕР СТАВОК ===
@onready var bet_size_option: OptionButton = find_child("BetSizeOption", true, false)

# === РАЗДЕЛ 4.5: ЧАЕВЫЕ ===
@onready var tip_percentage_spinbox: SpinBox = find_child("TipPercentageSpinBox", true, false)

# === РАЗДЕЛ 5: ЯЗЫК ===
@onready var ru_button: Button = find_child("RuButton", true, false)
@onready var en_button: Button = find_child("EnButton", true, false)

# === РАЗДЕЛ 6: РУБАШКА КАРТ ===
@onready var tiger_button: Button = find_child("TigerButton", true, false)
@onready var leopard_button: Button = find_child("LeopardButton", true, false)

# === РАЗДЕЛ 7: ТЕСТОВЫЕ КАРТЫ (для отладки) ===
@onready var test_cards_button: Button = find_child("TestCardsButton", true, false)

# === УПРАВЛЯЮЩИЕ КНОПКИ ===
@onready var apply_button: Button = find_child("ApplyButton", true, false)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Скрываем при старте
	hide()

	# Скрываем чекбокс режима выживания (теперь всегда включён)
	if survival_checkbox:
		survival_checkbox.visible = false
		# Также скрываем родительский контейнер если есть
		var parent = survival_checkbox.get_parent()
		if parent and parent.name.contains("Survival"):
			parent.visible = false

	# Подключаем сигналы кнопок
	_connect_signals()

	# Подписываемся на изменение языка через EventBus для синхронизации
	EventBus.language_changed.connect(_on_language_changed_external)

	# Обновляем тексты (локализация)
	_update_texts()

func _connect_signals():
	"""Подключение всех сигналов UI элементов"""
	# Режим игры
	if junket_button:
		junket_button.pressed.connect(_on_junket_pressed)
	if classic_button:
		classic_button.pressed.connect(_on_classic_pressed)

	# Ставки (кнопки с toggle_mode)
	if bet_player_button:
		bet_player_button.toggled.connect(_on_bet_player_toggled)
	if bet_banker_button:
		bet_banker_button.toggled.connect(_on_bet_banker_toggled)
	if bet_tie_button:
		bet_tie_button.toggled.connect(_on_bet_tie_toggled)
	if bet_pair_button:
		bet_pair_button.toggled.connect(_on_bet_pair_toggled)
	
	# Кнопка настроек гостей
	if guest_settings_button:
		guest_settings_button.pressed.connect(_on_guest_settings_pressed)

	# Размер ставок
	if bet_size_option:
		bet_size_option.item_selected.connect(_on_bet_size_selected)

	# Чаевые
	if tip_percentage_spinbox:
		tip_percentage_spinbox.value_changed.connect(_on_tip_percentage_changed)

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
	
	# Тестовые карты
	if test_cards_button:
		test_cards_button.pressed.connect(_on_test_cards_pressed)

	# Управляющие кнопки
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func open_settings():
	"""Открыть окно настроек"""
	# Загружаем значения в UI
	_load_current_values()

	# Устанавливаем контекст меню настроек
	InputContextManager.set_context(InputContextManager.InputContext.MENU_SETTINGS)

	# Показываем окно
	show()
	EventBus.settings_opened.emit()
	print("⚙️  Окно настроек открыто")

func close_settings():
	"""Закрыть окно настроек"""
	# Возвращаем контекст игры
	InputContextManager.set_context(InputContextManager.InputContext.GAME)
	
	hide()
	EventBus.settings_closed.emit()
	print("⚙️  Окно настроек закрыто")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА КЛАВИАТУРЫ
# ═══════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	"""Обработка клавиатурного ввода (используем _input вместо _unhandled_input, 
	чтобы перехватывать Escape даже если фокус на кнопке)"""
	# Обрабатываем только когда меню видимо
	if not visible:
		return
	
	# Проверяем контекст напрямую (не используем can_handle, так как оно проверяет блокировку)
	# Настройки должны обрабатывать ввод независимо от блокировки
	if InputContextManager.get_context() != InputContextManager.InputContext.MENU_SETTINGS:
		return
	
	if not InputContextManager.is_valid_key_event(event):
		return
	
	var key_event = event as InputEventKey
	
	# Escape в меню → закрыть меню (работает даже если фокус на кнопке)
	if key_event.keycode == KEY_ESCAPE:
		close_settings()
		get_viewport().set_input_as_handled()
		return

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════════════════

func _load_current_values():
	"""Загрузить текущие значения из менеджеров в UI"""
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

	# Язык
	_update_lang_buttons()

	# Рубашка карт
	_update_card_back_buttons()

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ UI
# ═══════════════════════════════════════════════════════════════════════════

func _update_texts():
	"""Обновить все тексты на основе текущего языка"""
	if title_label:
		title_label.text = Localization.t("SETTINGS_TITLE")

	if apply_button:
		apply_button.text = Localization.t("SETTINGS_BUTTON_APPLY")

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

func _update_mode_buttons(mode: String):
	"""Обновить состояние кнопок режима игры"""
	if not junket_button or not classic_button:
		return

	if mode == "junket":
		junket_button.disabled = true
		classic_button.disabled = false
	else:
		junket_button.disabled = false
		classic_button.disabled = true

func _update_mode_info(mode: String):
	"""Обновить информацию о режиме игры"""
	if not mode_info_label:
		return

	# Используем локализацию вместо хардкода
	if mode == "junket":
		mode_info_label.text = Localization.t("MODE_INFO_JUNKET")
	else:  # classic
		mode_info_label.text = Localization.t("MODE_INFO_CLASSIC")

func _update_lang_buttons():
	"""Обновить состояние кнопок языка"""
	if not ru_button or not en_button:
		return

	var current_lang = Localization.get_lang()
	ru_button.disabled = (current_lang == "ru")
	en_button.disabled = (current_lang == "en")

func _update_card_back_buttons():
	"""Обновить состояние кнопок рубашки карт"""
	if not tiger_button or not leopard_button:
		return

	var current_style = SaveManager.instance.load_card_back_style()
	tiger_button.disabled = (current_style == "tiger")
	leopard_button.disabled = (current_style == "leopard")

func _setup_bet_size_options():
	"""Настроить опции для OptionButton размера ставок"""
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

func _switch_game_mode(mode: String):
	"""Переключить режим игры (Junket/Classic)"""
	_update_mode_buttons(mode)
	_update_mode_info(mode)
	mode_changed.emit(mode)
	print("🎮 Режим игры изменён: %s" % mode.capitalize())

# === СТАВКИ ===

func _on_guest_settings_pressed():
	"""Обработка нажатия кнопки 'Ставки' для открытия меню настроек гостей"""
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

# === ТЕСТОВЫЕ КАРТЫ ===
func _on_test_cards_pressed():
	"""Открыть попап настройки тестовых карт"""
	# Ищем или создаём попап
	var game_scene = get_tree().get_first_node_in_group("game")
	if not game_scene:
		game_scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	
	var test_popup = null
	if game_scene:
		test_popup = game_scene.get_node_or_null("TestCardsPopup")
	
	if not test_popup:
		# Создаём попап программно (скрипт создаёт UI сам)
		var popup_script = load("res://scripts/popups/TestCardsPopup.gd")
		if popup_script:
			test_popup = CanvasLayer.new()
			test_popup.name = "TestCardsPopup"
			test_popup.set_script(popup_script)
			if game_scene:
				game_scene.add_child(test_popup)
			else:
				get_tree().root.add_child(test_popup)
		else:
			push_error("SettingsScene: не удалось загрузить TestCardsPopup.gd")
			return
	
	if test_popup and test_popup.has_method("open_popup"):
		test_popup.open_popup()
		print("🧪 Открыт попап тестовых карт")

# === УПРАВЛЯЮЩИЕ КНОПКИ ===
func _on_apply_pressed():
	"""Обработка нажатия кнопки "ОК" """
	# Все изменения уже применены в реальном времени через менеджеры
	# Просто закрываем окно
	close_settings()
	print("✅ Настройки применены")

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
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	
	if enabled:
		# Включено: белая рамка, нормальная прозрачность
		style_normal.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Темно-серый фон
		style_normal.border_color = Color.WHITE
		button.modulate.a = 1.0
	else:
		# Выключено: серая рамка, пониженная прозрачность
		style_normal.bg_color = Color(0.1, 0.1, 0.1, 0.5)  # Очень темный фон
		style_normal.border_color = Color(0.5, 0.5, 0.5, 0.5)
		button.modulate.a = 0.6
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("pressed", style_normal)
	button.add_theme_stylebox_override("hover", style_normal)
