# res://scripts/SettingsScene.gd
# Сцена настроек (overlay поверх Game.tscn)
# Заменяет старый SettingsPopup

extends CanvasLayer
class_name SettingsScene

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
@onready var background_music_button: Button = find_child("BackgroundMusicButton", true, false)

# === РАЗДЕЛ 8: ТЕСТОВЫЕ КАРТЫ (для отладки) ===
@onready var test_cards_button: Button = find_child("TestCardsButton", true, false)

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

	# Подключаем сигналы кнопок
	_connect_signals()

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
	
	# Кнопка прогрессии гостей
	if guest_progression_button:
		guest_progression_button.pressed.connect(_on_guest_progression_pressed)

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
	if background_music_button:
		background_music_button.pressed.connect(_on_background_music_pressed)
		# Убеждаемся, что кнопка активна
		background_music_button.disabled = false
		background_music_button.mouse_filter = Control.MOUSE_FILTER_STOP
		print("✅ SettingsScene: Кнопка 'Фоновый шум' найдена и сигнал подключен")
		print("   - disabled: %s" % background_music_button.disabled)
		print("   - mouse_filter: %s" % background_music_button.mouse_filter)
		print("   - visible: %s" % background_music_button.visible)
	else:
		push_warning("⚠️ SettingsScene: Кнопка 'Фоновый шум' НЕ найдена!")
	
	# Тестовые карты
	if test_cards_button:
		test_cards_button.pressed.connect(_on_test_cards_pressed)

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
	print("⚙️  Окно настроек открыто")

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
	"""
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
	
	# Фоновая музыка
	_update_background_music_button()

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
	
	# Кнопка прогрессии гостей
	if guest_progression_button:
		guest_progression_button.text = Localization.t("GUEST_PROGRESSION_BUTTON")

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
	"""Обработка нажатия кнопки 'ПРОГРЕССИЯ ГОСТЕЙ' для открытия попапа настроек прогрессии"""
	# Ищем попап в сцене Game
	var game_scene = get_tree().get_first_node_in_group("game")
	if not game_scene:
		game_scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	
	var progression_popup = null
	if game_scene:
		progression_popup = game_scene.get_node_or_null("GuestProgressionPopup")
	
	if not progression_popup:
		# Создаём попап если его нет
		var popup_scene = load("res://scenes/popups/GuestProgressionPopup.tscn")
		if popup_scene:
			progression_popup = popup_scene.instantiate()
			progression_popup.name = "GuestProgressionPopup"
			if game_scene:
				game_scene.add_child(progression_popup)
			else:
				get_tree().root.add_child(progression_popup)
		else:
			push_error("SettingsScene: не удалось загрузить сцену GuestProgressionPopup.tscn")
			return
	
	if progression_popup and progression_popup.has_method("open_popup"):
		progression_popup.open_popup()
		print("🎯 Открыт попап прогрессии гостей")

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

# === ЗВУК ===
func _update_background_music_button() -> void:
	"""Обновить текст кнопки фоновой музыки"""
	if not background_music_button:
		return
	
	var enabled = false
	if SoundManager:
		enabled = SoundManager.is_background_music_enabled()
	
	# Текст кнопки: "Фоновый шум" всегда, но показываем состояние
	if Localization:
		# Если включено - показываем "Фоновый шум ✓", если выключено - "Фоновый шум"
		if enabled:
			background_music_button.text = Localization.t("SETTINGS_BACKGROUND_NOISE") + " ✓"
		else:
			background_music_button.text = Localization.t("SETTINGS_BACKGROUND_NOISE")
	else:
		background_music_button.text = "Фоновый шум" + (" ✓" if enabled else "")
	
	# Кнопка всегда активна для переключения (не disabled)
	background_music_button.disabled = false
	background_music_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_background_music_pressed():
	"""Обработка нажатия кнопки фоновой музыки"""
	print("🔘 Кнопка 'Фоновый шум' нажата!")
	
	if not SoundManager:
		push_error("SettingsScene: SoundManager не найден!")
		return
	
	if not background_music_button:
		push_error("SettingsScene: background_music_button не найден!")
		return
	
	var current_enabled = SoundManager.is_background_music_enabled()
	var new_enabled = not current_enabled
	
	var current_text = "включен" if current_enabled else "выключен"
	var new_text = "включен" if new_enabled else "выключен"
	print("🎵 Переключение фонового шума: %s → %s" % [current_text, new_text])
	
	# Переключаем состояние
	SoundManager.set_background_music_enabled(new_enabled)
	
	# Проверяем, что состояние изменилось
	var verify_enabled = SoundManager.is_background_music_enabled()
	if verify_enabled != new_enabled:
		push_error("SettingsScene: Ошибка! Состояние не изменилось: ожидалось %s, получено %s" % [new_enabled, verify_enabled])
	
	# Обновляем текст кнопки
	_update_background_music_button()
	
	print("🎵 Фоновый шум: %s" % ("включен" if verify_enabled else "выключен"))

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
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_font_size_override("font_size", 16)
