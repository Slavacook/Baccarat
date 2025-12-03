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
var settings_popup: PopupPanel
var settings_button: Button
var survival_ui: Control
var game_over_popup: PopupPanel
var survival_rounds_completed: int = 0
var is_survival_mode: bool = false
var is_table_prepared_for_new_game: bool = false  # Флаг подготовки к новой игре (после оплаты всех фишек)

# Новые менеджеры для фишек и выплат
var chip_visual_manager: ChipVisualManager
var winner_selection_manager: WinnerSelectionManager
var payout_queue_manager: PayoutQueueManager
var pair_betting_manager: PairBettingManager


# ═══════════════════════════════════════════════════════════════════════════
# КАМЕРА
# ═══════════════════════════════════════════════════════════════════════════

var camera: Camera2D
# Общий план (1:1, показывает весь стол)
const CAMERA_ZOOM_GENERAL = Vector2(1.0, 1.0)
# Зум на карты (1.3:1, фокус на зоне раздачи)
const CAMERA_ZOOM_CARDS = Vector2(1.3, 1.3)
# Зум на фишки (1.3:1, фокус на зоне ставок - выше на 200px)
const CAMERA_ZOOM_CHIPS = Vector2(1.3, 1.3)
# Позиция камеры для общего плана (центр окна 1154x650)
const CAMERA_POS_GENERAL = Vector2(577, 325)
# Позиция камеры для зума на карты (центр зоны Player/Banker)
const CAMERA_POS_CARDS = Vector2(595, 400)
# Позиция камеры для зума на фишки (на 200px выше общего плана)
const CAMERA_POS_CHIPS = Vector2(595, 295)
# Длительность плавного перехода камеры (секунды)
const CAMERA_TRANSITION_DURATION = 0.5
var is_first_deal: bool = true                     # Флаг первой раздачи (для зума)

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
	survival_ui = get_node("TopUI/SurvivalModeUI")  # ← Обновили путь
	survival_ui.game_over.connect(_on_survival_game_over)
	game_over_popup = get_node("GameOverPopup")
	game_over_popup.restart_game.connect(_on_restart_game)

	# ← Подписываемся на Game Over по очкам
	SaveManager.instance.score_game_over.connect(_on_score_game_over)

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
	# ui_manager.winner_selected.connect(_on_winner_selected)  # ← ОТКЛЮЧЕНО: теперь через WinnerSelectionManager + кнопка "Карты"
	ui_manager.help_button_pressed.connect(_on_help_button_pressed)
	ui_manager.lang_button_pressed.connect(_on_lang_button_pressed)

	# ← Проверяем возврат из PayoutScene ДО reset (чтобы не сбрасывать восстановленное состояние)
	var is_payout_return = PayoutContextManager.has_context() and PayoutContextManager.get_context().get("manual_mode", false)

	if not is_payout_return:
		# Только если НЕ возвращаемся из PayoutScene - делаем reset
		phase_manager.reset()
		# Также сбрасываем GameStateManager только при обычной загрузке
		GameStateManager.reset()
	else:
		print("♻️  Пропускаем GameStateManager.reset() при возврате из PayoutScene")

	ui_manager.help_popup.hide()
	ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	# Инициализация новых менеджеров
	_setup_new_managers()
	_setup_payout_toggles()
	_setup_pair_toggles()

	GameStateManager.state_changed.connect(_on_game_state_changed)
	print("🎮 GameStateManager инициализирован")

	var cfg = GameModeManager.get_config()
	# ← Инициализация без toast
	limits_manager.set_limits(
		cfg["main_min"], cfg["main_max"], cfg["main_step"],
		cfg["tie_min"], cfg["tie_max"], cfg["tie_step"],
		cfg["pairs_min"], cfg["pairs_max"], cfg["pairs_step"],
		false  # не показываем toast при инициализации
	)

	StatsManager.instance.update_stats()

	# Настройка камеры
	_setup_camera()

	# Перемещаем UI кнопки в TopUI для защиты от зума камеры
	_setup_fixed_ui()

	# Настройка клавиатурной навигации
	_setup_keyboard_navigation()

	# Проверяем, вернулись ли из PayoutScene
	_check_payout_return()

func _unhandled_input(event: InputEvent):
	# Обработка прямых кнопок геймпада (работают параллельно с FocusManager)
	# При использовании прямых кнопок скрываем рамку навигации
	if event.is_action_pressed("CardsButton"):
		FocusManager.deactivate()
		ui_manager.action_button.emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("BankerThirdCardToggle"):
		FocusManager.deactivate()
		var fake_event = InputEventMouseButton.new()
		fake_event.button_index = MOUSE_BUTTON_LEFT
		fake_event.pressed = true
		ui_manager.banker_third_toggle.emit_signal("gui_input", fake_event)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("PlayerThirdCardToggle"):
		FocusManager.deactivate()
		var fake_event = InputEventMouseButton.new()
		fake_event.button_index = MOUSE_BUTTON_LEFT
		fake_event.pressed = true
		ui_manager.player_third_toggle.emit_signal("gui_input", fake_event)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("BankerMarker"):
		FocusManager.deactivate()
		get_node("BankerMarker").emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("TieMarker"):
		FocusManager.deactivate()
		get_node("TieMarker").emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("PlayerMarker"):
		FocusManager.deactivate()
		get_node("PlayerMarker").emit_signal("pressed")
		get_viewport().set_input_as_handled()

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

		# ═══════════════════════════════════════════════════════════════════
		# СОЗДАНИЕ ОЧЕРЕДИ ВЫПЛАТ
		# ═══════════════════════════════════════════════════════════════════

		var player_score = BaccaratRules.hand_value(phase_manager.player_hand)
		var banker_score = BaccaratRules.hand_value(phase_manager.banker_hand)

		# Очищаем очередь перед созданием новой
		GameDataManager.clear_payout_queue()

		# 1. Добавляем основную ставку (Player/Banker/Tie) - если была активна
		if PayoutSettingsManager.is_payout_enabled(actual):
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

			GameDataManager.add_to_payout_queue(actual, stake, payout, player_score, banker_score)

		# 2. Добавляем пару игрока - если обнаружена И ставка была
		if pair_betting_manager.player_pair_detected and pair_betting_manager.pair_player_bet_enabled:
			var stake = limits_manager.generate_pair_bet()  # ← Используем generate_pair_bet()
			var payout = pair_betting_manager.calculate_pair_payout(stake, "PairPlayer")
			GameDataManager.add_to_payout_queue("PairPlayer", stake, payout, player_score, banker_score)

		# 3. Добавляем пару банкира - если обнаружена И ставка была
		if pair_betting_manager.banker_pair_detected and pair_betting_manager.pair_banker_bet_enabled:
			var stake = limits_manager.generate_pair_bet()  # ← Используем generate_pair_bet()
			var payout = pair_betting_manager.calculate_pair_payout(stake, "PairBanker")
			GameDataManager.add_to_payout_queue("PairBanker", stake, payout, player_score, banker_score)

		# Выводим статус очереди
		GameDataManager.print_queue_status()

		# ═══════════════════════════════════════════════════════════════════
		# ОБРАБОТКА ОЧЕРЕДИ ВЫПЛАТ
		# ═══════════════════════════════════════════════════════════════════

		if GameDataManager.has_more_payouts():
			# Есть выплаты → берём первую и переходим в PayoutScene
			var next_payout = GameDataManager.get_next_payout()

			# Сохраняем данные для PayoutScene
			GameDataManager.set_payout_data(
				next_payout.bet_type,
				next_payout.stake,
				next_payout.payout,
				next_payout.player_score,
				next_payout.banker_score
			)

			# Сохраняем состояние игры (сердечки, раунды)
			GameDataManager.set_game_state(
				survival_rounds_completed,
				survival_ui.current_lives,
				survival_ui.is_active
			)

			get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
		else:
			# Нет выплат → сразу новый раунд
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

# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ РЕЖИМ ВЫПЛАТ (новая логика)
# ═══════════════════════════════════════════════════════════════════════════

func _prepare_payouts_manual(actual_winner: String) -> void:
	"""Подготовка выплат в ручном режиме (без автоматического перехода к сцене)

	Создает payout_queue_manager с информацией о всех ставках:
	- Выигравшие ставки (won=true, is_paid=false)
	- Проигравшие ставки (won=false)

	Делает фишки выигравших ставок кликабельными.
	"""
	var player_score = BaccaratRules.hand_value(phase_manager.player_hand)
	var banker_score = BaccaratRules.hand_value(phase_manager.banker_hand)

	# Создаем новый payout_queue_manager
	payout_queue_manager = PayoutQueueManager.new()

	# ═══════════════════════════════════════════════════════════════════
	# ДОБАВЛЯЕМ ВСЕ СТАВКИ (выигравшие и проигравшие)
	# ═══════════════════════════════════════════════════════════════════

	# 1. Основные ставки (Player/Banker/Tie)
	# Player
	if PayoutSettingsManager.player_payout_enabled:
		var won = (actual_winner == "Player")
		var stake = limits_manager.generate_bet()
		var payout = stake * 1.0 if won else 0.0
		payout_queue_manager.add_bet("Player", stake, payout, won, player_score, banker_score)

	# Banker
	if PayoutSettingsManager.banker_payout_enabled:
		var won = (actual_winner == "Banker")
		var stake = limits_manager.generate_bet()
		var payout = 0.0
		if won:
			var commission = GameModeManager.get_banker_commission()
			if GameModeManager.get_mode_string() == "classic":
				var banker_value = BaccaratRules.hand_value(phase_manager.banker_hand)
				if banker_value == 6:
					commission = 0.5
			payout = stake * commission
			print("🏦 Banker выиграл: stake=%.1f, commission=%.2f, payout=%.1f" % [stake, commission, payout])
		else:
			print("🏦 Banker проиграл: stake=%.1f, payout=0" % stake)
		payout_queue_manager.add_bet("Banker", stake, payout, won, player_score, banker_score)

	# Tie
	if PayoutSettingsManager.tie_payout_enabled:
		var won = (actual_winner == "Tie")
		var stake = limits_manager.generate_tie_bet()
		var payout = stake * 8.0 if won else 0.0
		payout_queue_manager.add_bet("Tie", stake, payout, won, player_score, banker_score)

	# 2. Ставки на пары
	# Pair Player
	if pair_betting_manager.pair_player_bet_enabled:
		var won = pair_betting_manager.player_pair_detected
		var stake = limits_manager.generate_pair_bet()
		var payout = pair_betting_manager.calculate_pair_payout(stake, "PairPlayer") if won else 0.0
		payout_queue_manager.add_bet("PairPlayer", stake, payout, won, player_score, banker_score)

	# Pair Banker
	if pair_betting_manager.pair_banker_bet_enabled:
		var won = pair_betting_manager.banker_pair_detected
		var stake = limits_manager.generate_pair_bet()
		var payout = pair_betting_manager.calculate_pair_payout(stake, "PairBanker") if won else 0.0
		payout_queue_manager.add_bet("PairBanker", stake, payout, won, player_score, banker_score)

	# Выводим статус очереди
	payout_queue_manager.print_status()

	# ═══════════════════════════════════════════════════════════════════
	# УПРАВЛЕНИЕ ФИШКАМИ (показать выигравшие, скрыть проигравшие)
	# ═══════════════════════════════════════════════════════════════════
	_update_chip_visibility()

	# ═══════════════════════════════════════════════════════════════════
	# СОХРАНЕНИЕ СОСТОЯНИЯ СТОЛА в TableStateManager
	# ═══════════════════════════════════════════════════════════════════
	var selected_winner = winner_selection_manager.get_selected_winner() if winner_selection_manager else ""
	var surv_lives = survival_ui.current_lives if survival_ui else 7
	var surv_active = survival_ui.is_active if survival_ui else false

	TableStateManager.save_table_state(
		phase_manager.player_hand,
		phase_manager.banker_hand,
		actual_winner,
		selected_winner,
		payout_queue_manager.get_all_bets(),
		camera.position if camera else Vector2.ZERO,
		camera.zoom if camera else Vector2.ONE,
		GameModeManager.get_mode_string(),
		survival_rounds_completed,
		surv_lives,
		surv_active
	)


func _update_chip_visibility() -> void:
	"""Обновить видимость и кликабельность фишек через ChipVisualManager

	Логика:
	- Проигравшие ставки → скрыть
	- Оплаченные ставки → скрыть
	- Выигравшие неоплаченные → оставить видимыми и кликабельными
	"""
	if not payout_queue_manager or not chip_visual_manager:
		return

	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]

	for bet_type in bet_types:
		var bet = payout_queue_manager.get_bet_by_type(bet_type)

		if bet:
			if not bet.won or bet.is_paid:
				# Проигравшая или оплаченная → скрываем
				chip_visual_manager.hide_chip(bet_type)
			else:
				# Выигравшая и неоплаченная → фишка уже видна, делаем кликабельной
				chip_visual_manager.make_chip_clickable(bet_type, true)
				print("💰 Фишка %s доступна для оплаты" % bet_type)

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
		# ← Жизни отнимаются в PayoutScene, здесь ничего не делаем
	if is_correct:
		phase_manager.reset()

func _on_survival_game_over(_rounds: int):
	print("🎮 GAME OVER! Раундов выжито: %d" % survival_rounds_completed)

	# Зум аут до общего плана при Game Over
	camera_zoom_out()
	is_first_deal = true  # Следующая раздача будет первой (с зумом)

	game_over_popup.show_game_over(survival_rounds_completed)

	# Автоматический рестарт через 3 секунды
	await get_tree().create_timer(3.0).timeout
	_on_restart_game()

func _on_score_game_over():
	print("🎮 GAME OVER! Очки упали ниже 0")

	# Зум аут до общего плана при Game Over
	camera_zoom_out()
	is_first_deal = true  # Следующая раздача будет первой (с зумом)

	var final_score = SaveManager.instance.score
	game_over_popup.show_game_over_score(final_score)

	# Автоматический рестарт через 3 секунды
	await get_tree().create_timer(3.0).timeout
	_on_restart_game()

func _on_restart_game():
	survival_rounds_completed = 0
	is_first_deal = true  # После рестарта первая раздача с зумом
	StatsManager.instance.reset()
	if is_survival_mode:
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
	# ← set_limits() сам вызовет limits_changed.emit() → _on_limits_changed()
	limits_manager.set_limits(
		cfg["main_min"], cfg["main_max"], cfg["main_step"],
		cfg["tie_min"], cfg["tie_max"], cfg["tie_step"],
		cfg["pairs_min"], cfg["pairs_max"], cfg["pairs_step"]
	)
	# Убрали дублирующий вызов _on_limits_changed() - он уже вызовется через сигнал

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

	# ← Обновляем отображение статистики (переключаемся между очками и правильно/ошибки)
	StatsManager.instance.update_stats()

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

# ← Метод _on_hint_used() удалён - логика подсказки теперь в PayoutScene

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

	# Уровень 1 (нижний): Кнопка "Карты"
	var level1_elements = [
		ui_manager.action_button
	]

	# Уровень 2: ? банкиру, ? игроку
	var level2_elements = [
		ui_manager.banker_third_toggle,
		ui_manager.player_third_toggle
	]

	# Уровень 3: Banker, Tie, Player
	var level3_elements = [
		get_node("BankerMarker"),
		get_node("TieMarker"),
		get_node("PlayerMarker")
	]

	# Уровень 4 (верхний): Подсказка, Настройки, переключатели выплат
	var level4_elements = [
		ui_manager.help_button
	]
	# Кнопки теперь в TopUI после _setup_fixed_ui()
	if has_node("TopUI/SettingsButton"):
		level4_elements.append(get_node("TopUI/SettingsButton"))
	if has_node("TopUI/PayoutTogglePlayer"):
		level4_elements.append(get_node("TopUI/PayoutTogglePlayer"))
	if has_node("TopUI/PayoutToggleBanker"):
		level4_elements.append(get_node("TopUI/PayoutToggleBanker"))
	if has_node("TopUI/PayoutToggleTie"):
		level4_elements.append(get_node("TopUI/PayoutToggleTie"))
	if has_node("TopUI/PayoutTogglePairPlayer"):
		level4_elements.append(get_node("TopUI/PayoutTogglePairPlayer"))
	if has_node("TopUI/PayoutTogglePairBanker"):
		level4_elements.append(get_node("TopUI/PayoutTogglePairBanker"))

	# Регистрируем уровни (is_payout=false для Game)
	FocusManager.register_level(1, level1_elements, false)
	FocusManager.register_level(2, level2_elements, false)
	FocusManager.register_level(3, level3_elements, false)
	FocusManager.register_level(4, level4_elements, false)

func _check_payout_return():
	"""Проверка возврата из PayoutScene (ручной или автоматический режим)"""

	# ═══════════════════════════════════════════════════════════════════
	# РУЧНОЙ РЕЖИМ (через PayoutContextManager)
	# ═══════════════════════════════════════════════════════════════════
	if PayoutContextManager.has_context():
		var context = PayoutContextManager.get_context()
		var is_manual = context.get("manual_mode", false)

		if is_manual:
			print("♻️  Возврат из PayoutScene (ручной режим)")

			# ═══════════════════════════════════════════════════════════════════
			# ВОССТАНОВЛЕНИЕ ПОЛНОГО СОСТОЯНИЯ СТОЛА из TableStateManager
			# ═══════════════════════════════════════════════════════════════════

			if not TableStateManager.has_saved_state():
				push_error("❌ TableStateManager не содержит сохраненного состояния!")
				PayoutContextManager.clear_context()
				GameDataManager.clear()
				return

			# 1. Восстанавливаем карты
			phase_manager.player_hand = TableStateManager.player_hand.duplicate()
			phase_manager.banker_hand = TableStateManager.banker_hand.duplicate()
			print("♻️  Восстановлены карты: Player=%d, Banker=%d" % [
				phase_manager.player_hand.size(),
				phase_manager.banker_hand.size()
			])

			# 2. Показываем карты на UI
			_restore_cards_ui()

			# 2.5. Обновляем GameStateManager с восстановленными картами
			var player_third_card = phase_manager.player_hand[2] if phase_manager.player_hand.size() >= 3 else null
			var banker_third_card = phase_manager.banker_hand[2] if phase_manager.banker_hand.size() >= 3 else null
			GameStateManager.determine_and_update_state(
				false,  # cards_hidden = false (карты открыты)
				phase_manager.player_hand,
				phase_manager.banker_hand,
				player_third_card,
				banker_third_card
			)
			print("♻️  GameStateManager обновлен: состояние = %s" % GameStateManager.get_current_state())

			# 3. Восстанавливаем маркер победителя
			var saved_winner = TableStateManager.selected_winner
			if saved_winner != "" and winner_selection_manager:
				winner_selection_manager.select_winner(saved_winner)
				print("🎯 Восстановлен маркер: %s" % saved_winner)

			# 4. Восстанавливаем survival режим
			survival_rounds_completed = TableStateManager.survival_rounds
			if survival_ui:
				survival_ui.current_lives = TableStateManager.survival_lives
				survival_ui.is_active = TableStateManager.survival_active

			# 5. Восстанавливаем PayoutQueueManager из TableStateManager
			payout_queue_manager = PayoutQueueManager.new()
			for bet_state in TableStateManager.bets:
				payout_queue_manager.add_bet(
					bet_state.bet_type,
					bet_state.stake,
					bet_state.payout,
					bet_state.won,
					bet_state.player_score,
					bet_state.banker_score
				)
				# Восстанавливаем статус оплаты
				if bet_state.is_paid:
					payout_queue_manager.mark_as_paid(bet_state.bet_type)

			print("♻️  Восстановлен PayoutQueueManager: %d ставок" % TableStateManager.bets.size())


			# Обновляем видимость фишек (показываем неоплаченные выигрыши)
			_update_chip_visibility()
			# 6. Обрабатываем результат текущей выплаты
			var bet_type = context.get("bet_type", "")
			var is_correct = GameDataManager.payout_is_correct
			var collected = GameDataManager.payout_collected
			var expected = GameDataManager.payout_expected

			if is_correct:
				EventBus.payout_correct.emit(collected, expected)
				print("✅ Правильная выплата для %s: %.1f" % [bet_type, expected])

				# Отмечаем ставку как оплаченную в обоих менеджерах
				payout_queue_manager.mark_as_paid(bet_type)
				TableStateManager.mark_bet_as_paid(bet_type)

				# Обновляем видимость фишек
				_update_chip_visibility()

				print("✅ Все выплаты оплачены! Можно начинать новый раунд")
			else:
				EventBus.payout_wrong.emit(collected, expected)
				print("❌ Неправильная выплата для %s: собрано=%.1f, ожидалось=%.1f" % [bet_type, collected, expected])

			# 7. Восстанавливаем камеру (для выбора следующей выплаты)
			if camera:
				camera.position = CAMERA_POS_CHIPS
				camera.zoom = CAMERA_ZOOM_CHIPS
				is_first_deal = false
				print("📷 Камера восстановлена: зум на фишки")

			# Очищаем контексты
			PayoutContextManager.clear_context()
			PayoutContextManager.clear_saved_state()
			GameDataManager.clear()
			return

	# ═══════════════════════════════════════════════════════════════════
	# АВТОМАТИЧЕСКИЙ РЕЖИМ (через GameDataManager) - СТАРАЯ ЛОГИКА
	# ═══════════════════════════════════════════════════════════════════
	if GameDataManager.payout_winner != "":
		# ← Восстанавливаем состояние игры
		survival_rounds_completed = GameDataManager.survival_rounds
		survival_ui.current_lives = GameDataManager.survival_lives
		survival_ui.is_active = GameDataManager.is_survival_active

		# Восстанавливаем приближенное состояние камеры (без анимации)
		if camera:
			camera.position = CAMERA_POS_CHIPS
			camera.zoom = CAMERA_ZOOM_CHIPS
			is_first_deal = false  # Уже не первая раздача
			print("📷 Камера восстановлена: приближенный план")

		# Обновляем визуальное отображение сердечек
		if survival_ui.is_active:
			survival_ui._update_hearts()
			survival_ui.show()
		else:
			survival_ui.hide()

		print("♻️  Состояние игры восстановлено: rounds=%d, lives=%d, active=%s" % [
			survival_rounds_completed, survival_ui.current_lives, survival_ui.is_active
		])

		# ← Проверка Game Over в режиме выживания
		if survival_ui.is_active and survival_ui.current_lives <= 0:
			print("🎮 GAME OVER! Закончились жизни (проверка после возврата из PayoutScene)")
			_on_survival_game_over(survival_rounds_completed)
			GameDataManager.clear()
			return

		# Обрабатываем результат выплаты
		var is_correct = GameDataManager.payout_is_correct
		var collected = GameDataManager.payout_collected
		var expected = GameDataManager.payout_expected

		# Обновляем статистику
		if is_correct:
			EventBus.payout_correct.emit(collected, expected)
			print("✅ Правильно! Выплата: %s" % expected)
			if is_survival_mode:
				survival_rounds_completed += 1
		else:
			EventBus.payout_wrong.emit(collected, expected)
			print("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])

		# ═══════════════════════════════════════════════════════════════════
		# ПРОВЕРКА ОЧЕРЕДИ ВЫПЛАТ
		# ═══════════════════════════════════════════════════════════════════

		if GameDataManager.has_more_payouts():
			# Есть ещё выплаты в очереди → берём следующую
			var next_payout = GameDataManager.get_next_payout()

			print("🔄 Следующая выплата: %s (осталось %d)" % [next_payout.bet_type, GameDataManager.get_queue_size()])

			# Сохраняем данные для PayoutScene
			GameDataManager.set_payout_data(
				next_payout.bet_type,
				next_payout.stake,
				next_payout.payout,
				next_payout.player_score,
				next_payout.banker_score
			)

			# Переходим в PayoutScene для следующей выплаты
			get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
		else:
			# Очередь пуста → сбрасываем раунд
			print("✅ Все выплаты обработаны, сброс раунда")
			GameDataManager.clear()

			# Сброс раунда только если последняя выплата была правильной
			if is_correct:
				phase_manager.reset()

# ═══════════════════════════════════════════════════════════════════════════
# КАМЕРА - УПРАВЛЕНИЕ ЗУМОМ
# ═══════════════════════════════════════════════════════════════════════════

func _setup_camera():
	# Создаём камеру
	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)

	# Начинаем с общего плана
	camera.position = CAMERA_POS_GENERAL
	camera.zoom = CAMERA_ZOOM_GENERAL

	print("📷 Камера создана: общий план (zoom %.1f)" % CAMERA_ZOOM_GENERAL.x)


func _setup_fixed_ui():
	"""Перемещает UI кнопки в TopUI CanvasLayer чтобы они не зумились"""
	var top_ui = get_node("TopUI")
	if not top_ui:
		print("⚠️ TopUI CanvasLayer не найден!")
		return

	# Список кнопок для перемещения
	var buttons_to_move = [
		"HelpButton",
		"StatsLabel",
		"SettingsButton",
		"PayoutTogglePlayer",
		"PayoutToggleBanker",
		"PayoutToggleTie",
		"PayoutTogglePairPlayer",
		"PayoutTogglePairBanker",
		"LimitsButton"
	]

	for button_name in buttons_to_move:
		if has_node(button_name):
			var button = get_node(button_name)
			# Сохраняем глобальную позицию
			var global_pos = button.global_position
			# Перемещаем в TopUI
			remove_child(button)
			top_ui.add_child(button)
			# Восстанавливаем позицию
			button.global_position = global_pos
			print("✅ %s перемещён в TopUI" % button_name)
		else:
			print("⚠️ %s не найден" % button_name)

	print("📌 UI элементы закреплены (не зумятся с камерой)")


func camera_zoom_in():
	"""Плавный зум на область карт"""
	if not camera:
		return

	var tween = create_tween()
	tween.set_parallel(true)  # Позиция и зум меняются одновременно
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(camera, "position", CAMERA_POS_CHIPS, CAMERA_TRANSITION_DURATION)
	tween.tween_property(camera, "zoom", CAMERA_ZOOM_CHIPS, CAMERA_TRANSITION_DURATION)

	print("📷 Зум на карты (zoom %.1f)" % CAMERA_ZOOM_CHIPS.x)


func camera_zoom_out():
	"""Возврат к общему плану"""
	if not camera:
		return

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(camera, "position", CAMERA_POS_GENERAL, CAMERA_TRANSITION_DURATION)
	tween.tween_property(camera, "zoom", CAMERA_ZOOM_GENERAL, CAMERA_TRANSITION_DURATION)

	print("📷 Общий план (zoom %.1f)" % CAMERA_ZOOM_GENERAL.x)


func camera_zoom_chips():
	"""Плавный зум на область фишек (выше на 200px от общего плана)"""
	if not camera:
		return

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(camera, "position", CAMERA_POS_CHIPS, CAMERA_TRANSITION_DURATION)
	tween.tween_property(camera, "zoom", CAMERA_ZOOM_CHIPS, CAMERA_TRANSITION_DURATION)

	print("📷 Зум на фишки (zoom %.1f)" % CAMERA_ZOOM_CHIPS.x)


func camera_zoom_cards():
	"""Плавный зум на область карт (алиас для camera_zoom_in)"""
	camera_zoom_in()


# ═══════════════════════════════════════════════════════════════════════════
# НОВЫЕ МЕНЕДЖЕРЫ - ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _setup_new_managers():
	"""Инициализация новых менеджеров для фишек и пар"""
	chip_visual_manager = ChipVisualManager.new()
	var chip_player = get_node_or_null("ChipPlayer")
	var chip_banker = get_node_or_null("ChipBanker")
	var chip_tie = get_node_or_null("ChipTie")
	var chip_pair_player = get_node_or_null("ChipPairPlayer")
	var chip_pair_banker = get_node_or_null("ChipPairBanker")
	if chip_player and chip_banker and chip_tie:
		chip_visual_manager.setup(chip_player, chip_banker, chip_tie, chip_pair_player, chip_pair_banker)
		chip_visual_manager.chip_clicked.connect(_on_chip_clicked)
		print("✅ ChipVisualManager инициализирован")
	else:
		push_warning("⚠️  Узлы фишек не найдены в сцене")
	winner_selection_manager = WinnerSelectionManager.new()
	var player_marker = get_node_or_null("PlayerMarker")
	var banker_marker = get_node_or_null("BankerMarker")
	var tie_marker = get_node_or_null("TieMarker")
	if player_marker and banker_marker and tie_marker:
		winner_selection_manager.setup(player_marker, banker_marker, tie_marker)
		winner_selection_manager.winner_toggled.connect(_on_winner_toggled)
		print("✅ WinnerSelectionManager инициализирован")
	else:
		push_warning("⚠️  Маркеры не найдены в сцене")
	# PayoutQueueManager создается динамически в _prepare_payouts_manual()
	pair_betting_manager = PairBettingManager.new()
	# ← Сигнал pair_detected больше не используется (молчаливая проверка)
	print("✅ PairBettingManager инициализирован")

func _setup_payout_toggles():
	"""Настройка toggles для основных ставок"""
	var player_toggle = get_node_or_null("PayoutTogglePlayer")
	var banker_toggle = get_node_or_null("PayoutToggleBanker")
	var tie_toggle = get_node_or_null("PayoutToggleTie")
	if not player_toggle or not banker_toggle or not tie_toggle:
		print("⚠️  PayoutToggle кнопки не найдены (пропускаем)")
		return
	player_toggle.toggle_mode = true
	banker_toggle.toggle_mode = true
	tie_toggle.toggle_mode = true
	if PayoutSettingsManager:
		player_toggle.button_pressed = PayoutSettingsManager.player_payout_enabled
		banker_toggle.button_pressed = PayoutSettingsManager.banker_payout_enabled
		tie_toggle.button_pressed = PayoutSettingsManager.tie_payout_enabled
		if player_toggle.button_pressed and chip_visual_manager:
			chip_visual_manager.show_chip("Player")
		if banker_toggle.button_pressed and chip_visual_manager:
			chip_visual_manager.show_chip("Banker")
		if tie_toggle.button_pressed and chip_visual_manager:
			chip_visual_manager.show_chip("Tie")
	player_toggle.toggled.connect(_on_payout_toggle_player)
	banker_toggle.toggled.connect(_on_payout_toggle_banker)
	tie_toggle.toggled.connect(_on_payout_toggle_tie)
	print("✅ Toggles основных ставок настроены")

func _setup_pair_toggles():
	"""Настройка toggles для ставок на пары"""
	var pair_player_toggle = get_node_or_null("PayoutTogglePairPlayer")
	var pair_banker_toggle = get_node_or_null("PayoutTogglePairBanker")
	if not pair_player_toggle or not pair_banker_toggle:
		print("⚠️  Toggles для пар не найдены (пропускаем)")
		return
	pair_player_toggle.toggle_mode = true
	pair_banker_toggle.toggle_mode = true
	pair_player_toggle.toggled.connect(_on_payout_toggle_pair_player)
	pair_banker_toggle.toggled.connect(_on_payout_toggle_pair_banker)
	print("✅ Toggles пар настроены")

func _on_payout_toggle_player(enabled: bool):
	if PayoutSettingsManager:
		PayoutSettingsManager.toggle_player(enabled)
	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("Player")
		else:
			chip_visual_manager.hide_chip("Player")

func _on_payout_toggle_banker(enabled: bool):
	if PayoutSettingsManager:
		PayoutSettingsManager.toggle_banker(enabled)
	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("Banker")
		else:
			chip_visual_manager.hide_chip("Banker")

func _on_payout_toggle_tie(enabled: bool):
	if PayoutSettingsManager:
		PayoutSettingsManager.toggle_tie(enabled)
	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("Tie")
		else:
			chip_visual_manager.hide_chip("Tie")

func _on_payout_toggle_pair_player(enabled: bool):
	if pair_betting_manager:
		pair_betting_manager.toggle_pair_player_bet(enabled)
	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("PairPlayer")
		else:
			chip_visual_manager.hide_chip("PairPlayer")

func _on_payout_toggle_pair_banker(enabled: bool):
	if pair_betting_manager:
		pair_betting_manager.toggle_pair_banker_bet(enabled)
	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("PairBanker")
		else:
			chip_visual_manager.hide_chip("PairBanker")

func _on_winner_toggled(winner: String, selected: bool):
	if selected:
		print("🎯 Выбран: %s" % winner)
	else:
		print("🎯 Снят выбор: %s" % winner)

func _on_chip_clicked(bet_type: String):
	print("🖱️  Клик на фишку: %s" % bet_type)
	if not payout_queue_manager:
		return
	var bet = payout_queue_manager.get_bet_by_type(bet_type)
	if not bet:
		ToastManager.instance.show_error("Нет ставки %s" % bet_type)
		return
	if not bet.won:
		ToastManager.instance.show_error("Эта ставка не выиграла")
		return
	if bet.is_paid:
		ToastManager.instance.show_info("Эта ставка уже оплачена")
		return
	_open_payout_scene(bet_type, bet.stake, bet.payout)

# ← Метод удалён - пары проверяются молча (проверка внимательности дилера)

func _open_payout_scene(bet_type: String, stake: float, expected_payout: float):
	"""Открыть PayoutScene для конкретной ставки

	Использует TableStateManager для полного сохранения состояния стола
	"""
	# Получаем данные ставки из TableStateManager
	var bet_data = TableStateManager.get_bet_data(bet_type)
	if not bet_data:
		push_error("❌ _open_payout_scene: ставка %s не найдена в TableStateManager" % bet_type)
		return

	print("💰 Открываем PayoutScene для %s: stake=%.1f, payout=%.1f" % [bet_type, bet_data.stake, bet_data.payout])

	# Устанавливаем данные в GameDataManager (PayoutScene читает данные оттуда)
	GameDataManager.payout_winner = bet_type
	GameDataManager.payout_stake = bet_data.stake
	GameDataManager.payout_amount = bet_data.payout
	print("  → Установлены данные в GameDataManager: winner=%s, stake=%.1f, amount=%.1f" % [bet_type, bet_data.stake, bet_data.payout])

	# Устанавливаем контекст для PayoutScene через старый PayoutContextManager (для совместимости)
	PayoutContextManager.set_context({
		"bet_type": bet_type,
		"stake": bet_data.stake,  # ← Используем данные из TableStateManager
		"expected_payout": bet_data.payout,
		"return_to_game": true,
		"manual_mode": true
	})

	# Переходим к PayoutScene
	get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")

func _restore_cards_ui():
	"""Восстановить карты на UI после возврата из PayoutScene"""
	# Показываем первые две карты игрока
	if phase_manager.player_hand.size() >= 1:
		ui_manager.player_card1.texture = phase_manager.player_hand[0].get_texture(card_manager)
		ui_manager.player_card1.visible = true
	if phase_manager.player_hand.size() >= 2:
		ui_manager.player_card2.texture = phase_manager.player_hand[1].get_texture(card_manager)
		ui_manager.player_card2.visible = true
	if phase_manager.player_hand.size() >= 3:
		ui_manager.player_card3.texture = phase_manager.player_hand[2].get_texture(card_manager)
		ui_manager.player_card3.visible = true

	# Показываем первые две карты банкира
	if phase_manager.banker_hand.size() >= 1:
		ui_manager.banker_card1.texture = phase_manager.banker_hand[0].get_texture(card_manager)
		ui_manager.banker_card1.visible = true
	if phase_manager.banker_hand.size() >= 2:
		ui_manager.banker_card2.texture = phase_manager.banker_hand[1].get_texture(card_manager)
		ui_manager.banker_card2.visible = true
	if phase_manager.banker_hand.size() >= 3:
		ui_manager.banker_card3.texture = phase_manager.banker_hand[2].get_texture(card_manager)
		ui_manager.banker_card3.visible = true

	# Скрываем toggles третьих карт (карты уже открыты)
	ui_manager.player_third_toggle.visible = false
	ui_manager.banker_third_toggle.visible = false

	print("♻️  Карты восстановлены на UI")
