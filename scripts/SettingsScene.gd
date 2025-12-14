# res://scripts/SettingsScene.gd
# Сцена настроек (overlay поверх Game.tscn)
# Заменяет старый SettingsPopup

extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ (для совместимости с GameController)
# ═══════════════════════════════════════════════════════════════════════════

signal mode_changed(mode: String)  # "junket" или "classic"
signal language_changed(lang: String)  # "ru" или "en"
signal survival_mode_changed(enabled: bool)  # вкл/выкл режим выживания

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ (ищем по имени через find_child)
# ═══════════════════════════════════════════════════════════════════════════

# Заголовок
@onready var title_label: Label = find_child("TitleLabel", true, false)

# === РАЗДЕЛ 1: РЕЖИМ ВЫЖИВАНИЯ ===
@onready var survival_checkbox: CheckBox = find_child("SurvivalCheckbox", true, false)

# === РАЗДЕЛ 2: РЕЖИМ ИГРЫ ===
@onready var junket_button: Button = find_child("JunketButton", true, false)
@onready var classic_button: Button = find_child("ClassicButton", true, false)
@onready var mode_info_label: Label = find_child("ModeInfoLabel", true, false)

# === РАЗДЕЛ 3: СТАВКИ ===
@onready var bet_player_checkbox: CheckBox = find_child("BetPlayerCheckbox", true, false)
@onready var bet_banker_checkbox: CheckBox = find_child("BetBankerCheckbox", true, false)
@onready var bet_tie_checkbox: CheckBox = find_child("BetTieCheckbox", true, false)
@onready var bet_pair_player_checkbox: CheckBox = find_child("BetPairPlayerCheckbox", true, false)
@onready var bet_pair_banker_checkbox: CheckBox = find_child("BetPairBankerCheckbox", true, false)
@onready var position_mode_option: OptionButton = find_child("PositionModeOption", true, false)

# === РАЗДЕЛ 4: РАЗМЕР СТАВОК ===
@onready var bet_size_option: OptionButton = find_child("BetSizeOption", true, false)

# === РАЗДЕЛ 5: ЯЗЫК ===
@onready var ru_button: Button = find_child("RuButton", true, false)
@onready var en_button: Button = find_child("EnButton", true, false)

# === РАЗДЕЛ 6: РУБАШКА КАРТ ===
@onready var tiger_button: Button = find_child("TigerButton", true, false)
@onready var leopard_button: Button = find_child("LeopardButton", true, false)

# === УПРАВЛЯЮЩИЕ КНОПКИ ===
@onready var apply_button: Button = find_child("ApplyButton", true, false)
@onready var cancel_button: Button = find_child("CancelButton", true, false)

# ═══════════════════════════════════════════════════════════════════════════
# СОХРАНЁННЫЕ ЗНАЧЕНИЯ (для кнопки "Отменить")
# ═══════════════════════════════════════════════════════════════════════════

var saved_survival_mode: bool
var saved_game_mode: String
var saved_language: String
var saved_card_back_style: String
var saved_bet_profile: int
var saved_player_payout: bool
var saved_banker_payout: bool
var saved_tie_payout: bool
var saved_player_pair_payout: bool
var saved_banker_pair_payout: bool
var saved_position_mode: int

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Скрываем при старте
	hide()

	# Подключаем сигналы кнопок
	_connect_signals()

	# Подписываемся на изменение языка через EventBus для синхронизации
	EventBus.language_changed.connect(_on_language_changed_external)

	# Обновляем тексты (локализация)
	_update_texts()

func _connect_signals():
	"""Подключение всех сигналов UI элементов"""
	# Режим выживания
	if survival_checkbox:
		survival_checkbox.toggled.connect(_on_survival_toggled)

	# Режим игры
	if junket_button:
		junket_button.pressed.connect(_on_junket_pressed)
	if classic_button:
		classic_button.pressed.connect(_on_classic_pressed)

	# Ставки (чекбоксы уже подключены к PayoutSettingsManager при создании)
	if bet_player_checkbox:
		bet_player_checkbox.toggled.connect(_on_bet_player_toggled)
	if bet_banker_checkbox:
		bet_banker_checkbox.toggled.connect(_on_bet_banker_toggled)
	if bet_tie_checkbox:
		bet_tie_checkbox.toggled.connect(_on_bet_tie_toggled)
	if bet_pair_player_checkbox:
		bet_pair_player_checkbox.toggled.connect(_on_bet_pair_player_toggled)
	if bet_pair_banker_checkbox:
		bet_pair_banker_checkbox.toggled.connect(_on_bet_pair_banker_toggled)
	if position_mode_option:
		_setup_position_mode_options()
		position_mode_option.item_selected.connect(_on_position_mode_selected)

	# Размер ставок
	if bet_size_option:
		bet_size_option.item_selected.connect(_on_bet_size_selected)

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

	# Управляющие кнопки
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func open_settings():
	"""Открыть окно настроек"""
	# Сохраняем текущие значения (для кнопки "Отменить")
	_save_current_values()

	# Загружаем значения в UI
	_load_current_values()

	# Показываем окно
	show()
	print("⚙️  Окно настроек открыто")

func close_settings():
	"""Закрыть окно настроек"""
	hide()
	print("⚙️  Окно настроек закрыто")

func set_survival_mode(enabled: bool):
	"""Установить режим выживания (вызывается из GameController)"""
	saved_survival_mode = enabled
	if survival_checkbox:
		survival_checkbox.button_pressed = enabled

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - СОХРАНЕНИЕ/ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════════════════

func _save_current_values():
	"""Сохранить текущие значения настроек для возможности отмены"""
	# Получаем текущий режим выживания из SaveManager
	saved_survival_mode = SaveManager.load_survival_mode()

	# Получаем текущий режим игры из GameModeManager
	saved_game_mode = GameModeManager.get_mode_string()

	saved_language = Localization.get_lang()
	saved_card_back_style = SaveManager.instance.load_card_back_style()
	saved_bet_profile = BetProfileManager.get_profile()

	saved_player_payout = PayoutSettingsManager.player_payout_enabled
	saved_banker_payout = PayoutSettingsManager.banker_payout_enabled
	saved_tie_payout = PayoutSettingsManager.tie_payout_enabled
	saved_player_pair_payout = PayoutSettingsManager.player_pair_payout_enabled
	saved_banker_pair_payout = PayoutSettingsManager.banker_pair_payout_enabled
	saved_position_mode = PayoutSettingsManager.get_position_mode()

func _load_current_values():
	"""Загрузить текущие значения из менеджеров в UI"""
	# Режим выживания - загружаем из SaveManager
	if survival_checkbox:
		survival_checkbox.button_pressed = SaveManager.load_survival_mode()

	# Режим игры - загружаем из GameModeManager
	var current_mode = GameModeManager.get_mode_string()
	_update_mode_buttons(current_mode)
	_update_mode_info(current_mode)

	# Ставки
	if bet_player_checkbox:
		bet_player_checkbox.button_pressed = PayoutSettingsManager.player_payout_enabled
	if bet_banker_checkbox:
		bet_banker_checkbox.button_pressed = PayoutSettingsManager.banker_payout_enabled
	if bet_tie_checkbox:
		bet_tie_checkbox.button_pressed = PayoutSettingsManager.tie_payout_enabled
	if bet_pair_player_checkbox:
		bet_pair_player_checkbox.button_pressed = PayoutSettingsManager.player_pair_payout_enabled
	if bet_pair_banker_checkbox:
		bet_pair_banker_checkbox.button_pressed = PayoutSettingsManager.banker_pair_payout_enabled
	if position_mode_option:
		position_mode_option.selected = PayoutSettingsManager.get_position_mode()

	# Размер ставок
	if bet_size_option:
		bet_size_option.selected = BetProfileManager.get_profile()

	# Язык
	_update_lang_buttons()

	# Рубашка карт
	_update_card_back_buttons()

func _restore_saved_values():
	"""Восстановить сохранённые значения (для кнопки "Отменить")"""
	# Режим выживания - эмитим сигнал для GameController
	survival_mode_changed.emit(saved_survival_mode)

	# Режим игры - эмитим сигнал для GameController
	mode_changed.emit(saved_game_mode)

	# Язык
	Localization.set_lang(saved_language)

	# Рубашка карт
	SaveManager.instance.save_card_back_style(saved_card_back_style)
	EventBus.card_back_style_changed.emit(saved_card_back_style)

	# Размер ставок
	BetProfileManager.set_profile(saved_bet_profile as BetProfileManager.BetProfile)

	# Ставки
	PayoutSettingsManager.toggle_player(saved_player_payout)
	PayoutSettingsManager.toggle_banker(saved_banker_payout)
	PayoutSettingsManager.toggle_tie(saved_tie_payout)
	PayoutSettingsManager.toggle_player_pair(saved_player_pair_payout)
	PayoutSettingsManager.toggle_banker_pair(saved_banker_pair_payout)
	PayoutSettingsManager.set_position_mode(saved_position_mode as PayoutSettingsManager.PositionMode)

	print("↩️  Настройки восстановлены")

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ UI
# ═══════════════════════════════════════════════════════════════════════════

func _update_texts():
	"""Обновить все тексты на основе текущего языка"""
	if title_label:
		title_label.text = Localization.t("SETTINGS_TITLE")

	if apply_button:
		apply_button.text = Localization.t("SETTINGS_BUTTON_APPLY")
	if cancel_button:
		cancel_button.text = Localization.t("SETTINGS_BUTTON_CANCEL")

	if survival_checkbox:
		survival_checkbox.text = Localization.t("SETTINGS_SURVIVAL_CHECKBOX")

	# Рубашка карт
	if tiger_button:
		tiger_button.text = Localization.t("SETTINGS_CARD_BACK_TIGER")
	if leopard_button:
		leopard_button.text = Localization.t("SETTINGS_CARD_BACK_LEOPARD")

	# Размер ставок - обновляем опции
	if bet_size_option:
		_setup_bet_size_options()
	
	# Режим позиций - обновляем опции
	if position_mode_option:
		_setup_position_mode_options()

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

# === РЕЖИМ ВЫЖИВАНИЯ ===
func _on_survival_toggled(pressed: bool):
	"""Обработка переключения режима выживания"""
	survival_mode_changed.emit(pressed)
	print("💔 Режим выживания: %s" % ("ВКЛ" if pressed else "ВЫКЛ"))

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
func _on_bet_player_toggled(pressed: bool):
	"""Обработка переключения ставки Player"""
	PayoutSettingsManager.toggle_player(pressed)
	# Эмитим сигнал для управления фишками (слушает GameController)
	EventBus.payout_setting_changed.emit("Player", pressed)

func _on_bet_banker_toggled(pressed: bool):
	"""Обработка переключения ставки Banker"""
	PayoutSettingsManager.toggle_banker(pressed)
	EventBus.payout_setting_changed.emit("Banker", pressed)

func _on_bet_tie_toggled(pressed: bool):
	"""Обработка переключения ставки Tie"""
	PayoutSettingsManager.toggle_tie(pressed)
	EventBus.payout_setting_changed.emit("Tie", pressed)

func _on_bet_pair_player_toggled(pressed: bool):
	"""Обработка переключения пары игрока"""
	PayoutSettingsManager.toggle_player_pair(pressed)
	EventBus.payout_setting_changed.emit("PairPlayer", pressed)

func _on_bet_pair_banker_toggled(pressed: bool):
	"""Обработка переключения пары банкира"""
	PayoutSettingsManager.toggle_banker_pair(pressed)
	EventBus.payout_setting_changed.emit("PairBanker", pressed)

func _on_position_mode_selected(index: int):
	"""Обработка выбора режима позиций фишек"""
	PayoutSettingsManager.set_position_mode(index as PayoutSettingsManager.PositionMode)
	var mode_names = ["DEFAULT", "RANDOM", "MAX", "REALISTIC"]
	print("🎲 Режим позиций: %s" % mode_names[index])


func _setup_position_mode_options():
	"""Настроить опции для OptionButton режима позиций"""
	if not position_mode_option:
		return
	
	position_mode_option.clear()
	position_mode_option.add_item(Localization.t("POSITION_MODE_DEFAULT"), 0)
	position_mode_option.add_item(Localization.t("POSITION_MODE_RANDOM"), 1)
	position_mode_option.add_item(Localization.t("POSITION_MODE_MAX"), 2)
	position_mode_option.add_item(Localization.t("POSITION_MODE_REALISTIC"), 3)
	position_mode_option.selected = PayoutSettingsManager.get_position_mode()

# === РАЗМЕР СТАВОК ===
func _on_bet_size_selected(index: int):
	"""Обработка выбора размера ставок"""
	BetProfileManager.set_profile(index as BetProfileManager.BetProfile)
	print("💰 Размер ставок изменён: %s" % BetProfileManager.get_profile_name())

# === ЯЗЫК ===
func _on_ru_pressed():
	"""Обработка нажатия кнопки RU"""
	Localization.set_lang("ru")
	_update_lang_buttons()
	_update_texts()
	language_changed.emit("ru")
	print("🌍 Язык изменён: Русский")

func _on_en_pressed():
	"""Обработка нажатия кнопки EN"""
	Localization.set_lang("en")
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

# === УПРАВЛЯЮЩИЕ КНОПКИ ===
func _on_apply_pressed():
	"""Обработка нажатия кнопки "Применить" """
	# Все изменения уже применены в реальном времени через менеджеры
	# Просто закрываем окно
	close_settings()
	print("✅ Настройки применены")

func _on_cancel_pressed():
	"""Обработка нажатия кнопки "Отменить" """
	# Восстанавливаем сохранённые значения
	_restore_saved_values()

	# Обновляем UI
	_load_current_values()
	_update_texts()

	# Закрываем окно
	close_settings()
	print("❌ Настройки отменены")

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
