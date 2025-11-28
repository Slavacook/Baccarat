# res://scripts/GameController.gd
extends Node2D

@export var config: GameConfig

var deck: Deck
var card_manager: CardTextureManager
var ui_manager: UIManager
var phase_manager: GamePhaseManager
var limits_manager: LimitsManager
var limits_popup: PopupPanel
var limits_button: Button
var payout_popup: PopupPanel
var settings_popup: PopupPanel
var settings_button: Button
var survival_ui: Control
var game_over_popup: PopupPanel
var survival_rounds_completed: int = 0
var is_survival_mode: bool = false

# Добавляем FlipCard ссылки
# Массивы для ссылок на flip-анимации и карты:
@onready var flip_cards := [
	$OpenCard/FlipCard1, $OpenCard/FlipCard2, $OpenCard/FlipCard3,
	$OpenCard/FlipCard4, $OpenCard/FlipCard5, $OpenCard/FlipCard6,
]
@onready var card_nodes := [
	$PlayerZone/Card1, $PlayerZone/Card2, $PlayerZone/Card3,
	$BankerZone/Card1, $BankerZone/Card2, $BankerZone/Card3,
]




func _ready():
	Localization.set_lang("ru")
	deck = Deck.new()
	if not config:
		config = GameConfig.new()
	card_manager = CardTextureManager.new(config)
	ui_manager = UIManager.new(self, card_manager)
	ui_manager.set_main_node(self)   # <-- Вот эта строка!
	ui_manager.set_flip_cards(flip_cards)  # <-- И эта строка!
	StatsManager.instance.set_label(ui_manager.stats_label)
	limits_manager = LimitsManager.new(config)
	limits_popup = get_node("LimitsPopup")
	limits_button = get_node("LimitsButton")
	limits_button.pressed.connect(_on_limits_button_pressed)
	limits_popup.limits_changed.connect(limits_manager.set_limits)
	limits_manager.limits_changed.connect(_on_limits_changed)
	payout_popup = get_node("PayoutPopup")
	payout_popup.payout_confirmed.connect(_on_payout_confirmed)
	payout_popup.hint_used.connect(_on_hint_used)
	survival_ui = get_node("TopUI/SurvivalModeUI")  # ← Обновили путь
	survival_ui.game_over.connect(_on_survival_game_over)
	game_over_popup = get_node("GameOverPopup")
	game_over_popup.restart_game.connect(_on_restart_game)

	if has_node("SettingsPopup"):
		settings_popup = get_node("SettingsPopup")
		settings_popup.mode_changed.connect(_on_mode_changed)
		settings_popup.language_changed.connect(_on_language_changed)
		settings_popup.survival_mode_changed.connect(_on_survival_mode_changed)

	if has_node("SettingsButton"):
		settings_button = get_node("SettingsButton")
		settings_button.pressed.connect(_on_settings_button_pressed)

	GameModeManager.load_saved_mode()
	_load_survival_mode_setting()
	phase_manager = GamePhaseManager.new(deck, card_manager, ui_manager)
	phase_manager.set_game_controller(self)

	ui_manager.action_button_pressed.connect(phase_manager.on_action_pressed)
	ui_manager.player_third_toggled.connect(phase_manager.on_player_third_toggled)
	ui_manager.banker_third_toggled.connect(phase_manager.on_banker_third_toggled)
	ui_manager.winner_selected.connect(_on_winner_selected)
	ui_manager.help_button_pressed.connect(_on_help_button_pressed)
	ui_manager.lang_button_pressed.connect(_on_lang_button_pressed)
	phase_manager.reset()
	ui_manager.help_popup.hide()
	ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))

	GameStateManager.reset()
	GameStateManager.state_changed.connect(_on_game_state_changed)
	print("🎮 GameStateManager инициализирован")

	var cfg = GameModeManager.get_config()
	limits_manager.set_limits(
		cfg["main_min"], cfg["main_max"], cfg["main_step"],
		cfg["tie_min"], cfg["tie_max"], cfg["tie_step"]
	)

	StatsManager.instance.update_stats()

	# Настройка клавиатурной навигации
	_setup_keyboard_navigation()

	# Проверяем, вернулись ли из PayoutScene
	_check_payout_return()

func set_flip_cards(cards):
	flip_cards = cards


func show_all_backs(back_texture: Texture2D):
	for card in flip_cards:
		card.show_back(back_texture)

func open_all_cards(face_textures: Array, delay: float = 0.3):
	for i in range(face_textures.size()):
		await get_tree().create_timer(i * delay).timeout
		flip_cards[i].open_card(face_textures[i])

func open_all_cards_with_flip(face_textures: Array, delay: float = 0.3):
	# Открываем каждую карту с flip-анимацией
	for i in range(face_textures.size()):
		flip_cards[i].play_flip()                 # Запустить анимацию flip
		await get_tree().create_timer(delay).timeout   # Подождать, пока проиграется flip (~0.3 сек)
		card_nodes[i].texture = face_textures[i]  # Показать открытую карту

func open_two_third_cards(texture1: Texture2D, texture2: Texture2D):
	flip_cards[4].open_card(texture1)
	flip_cards[5].open_card(texture2)

func reset_cards(back_texture: Texture2D):
	show_all_backs(back_texture)

func _on_limits_button_pressed():
	limits_popup.show_current_limits(
		limits_manager.min_bet,
		limits_manager.max_bet,
		limits_manager.step,
		limits_manager.tie_min,
		limits_manager.tie_max,
		limits_manager.tie_step
	)

func _on_limits_changed(min_bet: int, max_bet: int, step: int, tie_min: int, tie_max: int, tie_step: int):
	EventBus.show_toast_info.emit(
		"Лимиты: %d–%d (шаг %d)\nTIE: %d–%d (шаг %d)" % 
		[min_bet, max_bet, step, tie_min, tie_max, tie_step]
	)

func _on_winner_selected(chosen: String):
	if not GameStateManager.is_action_valid(GameStateManager.Action.SELECT_WINNER):
		var error_msg = GameStateManager.get_error_message(GameStateManager.Action.SELECT_WINNER)
		EventBus.show_toast_error.emit(error_msg)

		# Штраф только если не в состоянии WAITING (карты уже раздавались)
		var current_state = GameStateManager.get_current_state()
		if current_state != GameStateManager.GameState.WAITING:
			EventBus.action_error.emit("winner_early", error_msg)
			if is_survival_mode:
				survival_ui.lose_life()

		print("🚫 [НОВАЯ СИСТЕМА] %s" % error_msg)
		return

	var actual = BaccaratRules.get_winner(phase_manager.player_hand, phase_manager.banker_hand)

	if chosen == actual:
		# ✅ Правильный выбор победителя
		EventBus.action_correct.emit("winner")

		# Показываем краткий тост победы
		var victory_msg = _format_victory_toast(actual)
		EventBus.show_toast_success.emit(victory_msg)

		# Пауза 1 секунда (карты остаются открытыми, маркер активен)
		await get_tree().create_timer(GameConstants.VICTORY_TOAST_DELAY).timeout

		# Проверяем, активна ли выплата для этой позиции
		if PayoutSettingsManager.is_payout_enabled(actual):
			# Есть ставка → переходим в PayoutScene
			var stake: float = 0.0
			var payout: float = 0.0
			if actual == "Banker":
				stake = limits_manager.generate_bet()
				var commission = GameModeManager.get_banker_commission()
				if GameModeManager.get_mode_string() == "classic":
					var banker_value = BaccaratRules.hand_value(phase_manager.banker_hand)
					if banker_value == 6:
						commission = 0.5
				payout = stake * commission
			elif actual == "Tie":
				stake = limits_manager.generate_tie_bet()
				payout = stake * 8.0
			else:  # Player
				stake = limits_manager.generate_bet()
				payout = stake * 1.0

			# Сохраняем данные и переходим в PayoutScene
			GameDataManager.set_payout_data(actual, stake, payout)
			get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
		else:
			# Нет ставки → сразу новый раунд
			phase_manager.reset()
	else:
		# ❌ Неправильный выбор
		var res = _format_result()
		var t = Localization.t("WIN_PLAYER") if actual == "Player" else Localization.t("WIN_BANKER") if actual == "Banker" else Localization.t("WIN_TIE")
		var chosen_t = Localization.t("WIN_PLAYER") if chosen == "Player" else Localization.t("WIN_BANKER") if chosen == "Banker" else Localization.t("WIN_TIE")
		EventBus.show_toast_error.emit(Localization.t("WIN_INCORRECT", [chosen_t, t, res]))
		EventBus.action_error.emit("winner_wrong", Localization.t("WIN_INCORRECT", [chosen_t, t, res]))
		if is_survival_mode:
			survival_ui.lose_life()

func _format_result() -> String:
	var p0 = BaccaratRules.hand_value([phase_manager.player_hand[0], phase_manager.player_hand[1]])
	var b0 = BaccaratRules.hand_value([phase_manager.banker_hand[0], phase_manager.banker_hand[1]])
	if p0 >= 8 or b0 >= 8:
		return "Натуральная %d против %d" % [p0 if p0 >= 8 else b0, b0 if p0 >= 8 else p0]
	return "%d против %d" % [BaccaratRules.hand_value(phase_manager.banker_hand), BaccaratRules.hand_value(phase_manager.player_hand)]

# ← Форматирование краткого тоста победы (например, "Выигрывает Банкир: 7 vs 5")
func _format_victory_toast(winner: String) -> String:
	var player_score = BaccaratRules.hand_value(phase_manager.player_hand)
	var banker_score = BaccaratRules.hand_value(phase_manager.banker_hand)

	match winner:
		"Banker":
			return Localization.t("VICTORY_BANKER", [banker_score, player_score])
		"Player":
			return Localization.t("VICTORY_PLAYER", [player_score, banker_score])
		"Tie":
			return Localization.t("VICTORY_TIE")  # Без параметров
		_:
			return "???"

func _on_help_button_pressed():
	ui_manager.help_popup.popup_centered()

func _on_lang_button_pressed():
	var new_lang = "en" if Localization.get_lang() == "ru" else "ru"
	Localization.set_lang(new_lang)
	ui_manager.update_lang_button()
	ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	if ui_manager.player_third_toggle.visible:
		ui_manager.update_player_toggle(phase_manager.player_third_selected)
	if ui_manager.banker_third_toggle.visible:
		ui_manager.update_banker_toggle(phase_manager.banker_third_selected)

func _on_payout_confirmed(is_correct: bool, collected: float, expected: float):
	if is_correct:
		EventBus.payout_correct.emit(collected, expected)
		print("✅ Правильно! Выплата: %s" % expected)
		if is_survival_mode:
			survival_rounds_completed += 1
	else:
		EventBus.payout_wrong.emit(collected, expected)
		print("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])
		if is_survival_mode:
			survival_ui.lose_life()
	if is_correct:
		phase_manager.reset()

func _on_survival_game_over(_rounds: int):
	print("🎮 GAME OVER! Раундов выжито: %d" % survival_rounds_completed)
	game_over_popup.show_game_over(survival_rounds_completed)

	# Автоматический рестарт через 3 секунды
	await get_tree().create_timer(3.0).timeout
	_on_restart_game()

func _on_restart_game():
	survival_rounds_completed = 0
	StatsManager.instance.reset()
	survival_ui.reset()
	survival_ui.activate()
	phase_manager.reset()

func _on_settings_button_pressed():
	if settings_popup:
		if settings_popup.visible:
			settings_popup.hide()
		else:
			if not GameStateManager.can_change_settings():
				var msg = GameStateManager.get_settings_lock_message()
				EventBus.show_toast_error.emit(msg)
				print("🔒 [НОВАЯ СИСТЕМА] " + msg)
				return
			settings_popup.popup_centered()

func _on_mode_changed(mode: String):
	print("Режим игры изменён на: ", mode)
	GameModeManager.set_mode(mode)
	var cfg = GameModeManager.get_config()
	limits_manager.set_limits(
		cfg["main_min"], cfg["main_max"], cfg["main_step"],
		cfg["tie_min"], cfg["tie_max"], cfg["tie_step"]
	)
	_on_limits_changed(cfg["main_min"], cfg["main_max"], cfg["main_step"], cfg["tie_min"], cfg["tie_max"], cfg["tie_step"])

func _on_language_changed(_lang: String):
	ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	if ui_manager.player_third_toggle.visible:
		ui_manager.update_player_toggle(phase_manager.player_third_selected)
	if ui_manager.banker_third_toggle.visible:
		ui_manager.update_banker_toggle(phase_manager.banker_third_selected)

func _on_survival_mode_changed(enabled: bool):
	is_survival_mode = enabled
	SaveManager.save_survival_mode(enabled)
	if enabled:
		survival_ui.activate()
		ui_manager.stats_label.visible = false
		print("Режим выживания включён")
	else:
		survival_ui.deactivate()
		ui_manager.stats_label.visible = true
		print("Режим выживания выключен")

func _load_survival_mode_setting():
	var enabled = SaveManager.load_survival_mode()
	is_survival_mode = enabled
	if settings_popup:
		settings_popup.set_survival_mode(enabled)
	if enabled:
		survival_ui.activate()
		ui_manager.stats_label.visible = false
	else:
		survival_ui.deactivate()
		ui_manager.stats_label.visible = true

func _on_hint_used():
	if is_survival_mode:
		survival_ui.lose_life()
		EventBus.show_toast_info.emit("💡 Подсказка использована (-1 жизнь)")
		print("💡 Подсказка: -1 жизнь")
	else:
		var data = SaveManager.instance.get_data()
		for i in range(10):
			if data.correct > 0:
				data.correct -= 1
		SaveManager.instance.save_data()
		StatsManager.instance.update_stats()
		EventBus.show_toast_info.emit("💡 Подсказка использована (-10 очков)")
		print("💡 Подсказка: -10 очков")

func _on_game_state_changed(old_state: int, new_state: int):
	var old_name = GameStateManager.get_state_name(old_state)
	var new_name = GameStateManager.get_state_name(new_state)
	print("📊 [НОВАЯ СИСТЕМА] Состояние: %s → %s" % [old_name, new_name])

# ═══════════════════════════════════════════════════════════════════════════
# КЛАВИАТУРНАЯ НАВИГАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _setup_keyboard_navigation():
	# Добавляем рамку в сцену
	FocusManager.attach_highlight_to_scene(self)

	# Уровень 1: Карты, ? банкиру, ? игроку
	var level1_elements = [
		ui_manager.action_button,
		ui_manager.banker_third_toggle,
		ui_manager.player_third_toggle
	]

	# Уровень 2: Banker, Tie, Player
	var level2_elements = [
		get_node("BankerMarker"),
		get_node("TieMarker"),
		get_node("PlayerMarker")
	]

	# Уровень 3: Подсказка, Настройки, переключатели выплат
	var level3_elements = [
		ui_manager.help_button
	]
	if has_node("SettingsButton"):
		level3_elements.append(get_node("SettingsButton"))
	if has_node("PayoutTogglePlayer"):
		level3_elements.append(get_node("PayoutTogglePlayer"))
	if has_node("PayoutToggleBanker"):
		level3_elements.append(get_node("PayoutToggleBanker"))
	if has_node("PayoutToggleTie"):
		level3_elements.append(get_node("PayoutToggleTie"))

	# Регистрируем уровни
	FocusManager.register_level(1, level1_elements)
	FocusManager.register_level(2, level2_elements)
	FocusManager.register_level(3, level3_elements)

func _check_payout_return():
	# Проверяем, есть ли данные возврата из PayoutScene
	if GameDataManager.payout_winner != "":
		# Обрабатываем результат выплаты
		var is_correct = GameDataManager.payout_is_correct
		var collected = GameDataManager.payout_collected
		var expected = GameDataManager.payout_expected

		# Вызываем обработчик как раньше
		_on_payout_confirmed(is_correct, collected, expected)

		# Очищаем данные
		GameDataManager.clear()
