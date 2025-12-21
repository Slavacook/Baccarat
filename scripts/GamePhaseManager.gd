# res://scripts/GamePhaseManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# МЕНЕДЖЕР ФАЗ ИГРЫ
# Управляет логикой раздачи карт, валидацией действий и переходами состояний
# ═══════════════════════════════════════════════════════════════════════════
@tool
class_name GamePhaseManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

var deck: Deck
var card_manager: CardTextureManager
var ui: UIManager
var hand_manager: HandManager
var payout_queue_manager: PayoutQueueManager
var chip_visual_manager: ChipVisualManager
var winner_selection_manager: WinnerSelectionManager
var pair_betting_manager: PairBettingManager
var limits_manager: LimitsManager = null
var guest_bet_storage: GuestBetStorage = null
var guest_bet_factory: GuestBetFactory = null
var bet_collection_manager: BetCollectionPhaseManager = null

## Менеджер ставки сердцем (Heart Bet)
var heart_bet_manager: HeartBetManager = null

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ РАУНДА
# ═══════════════════════════════════════════════════════════════════════════

# ← УДАЛЕНО: player_hand и banker_hand теперь в HandManager (Task 2.2)
# var player_hand: Array[Card] = []
# var banker_hand: Array[Card] = []

var player_third_selected: bool = false
var banker_third_selected: bool = false
var is_first_deal: bool = true
var is_table_prepared: bool = false
var was_heart_bet_round: bool = false  # Флаг Heart Bet раунда (даже при отказе)

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ФИЛЬТРА СТАВОК
# ═══════════════════════════════════════════════════════════════════════════

# Снимок состояния фильтра на момент показки ставок
# Изолирует текущую раздачу от изменений фильтра во время игры
var _filter_snapshot: Dictionary = {}  # {"Player": bool, "Banker": bool, "Tie": bool, "PairPlayer": bool, "PairBanker": bool}

# Накопленные изменения фильтра во время раздачи (для применения в следующей раздаче)
var _pending_filter_changes: Dictionary = {}  # {"Player": bool, "Banker": bool, "Tie": bool, "PairPlayer": bool, "PairBanker": bool}

func _init(
	deck_ref: Deck,
	card_manager_ref: CardTextureManager,
	ui_ref: UIManager,
	hand_mgr: HandManager,
	payout_queue_mgr: PayoutQueueManager,
	chip_visual_mgr: ChipVisualManager,
	winner_selection_mgr: WinnerSelectionManager,
	pair_betting_mgr: PairBettingManager,
	limits_mgr: LimitsManager = null
):
	deck = deck_ref
	card_manager = card_manager_ref
	ui = ui_ref
	hand_manager = hand_mgr
	payout_queue_manager = payout_queue_mgr
	chip_visual_manager = chip_visual_mgr
	winner_selection_manager = winner_selection_mgr
	pair_betting_manager = pair_betting_mgr
	limits_manager = limits_mgr
	
	# Инициализируем хранилище и фабрику ставок гостей
	if limits_manager:
		guest_bet_storage = GuestBetStorage.new()
		guest_bet_factory = GuestBetFactory.new(limits_manager, guest_bet_storage)
	
	# Инициализируем менеджер ставки сердцем
	heart_bet_manager = HeartBetManager.new()
	DebugLogger.log("❤️ HeartBetManager инициализирован в GamePhaseManager")

	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	ui.set_action_button_state("start")

func reset(update_state: bool = true, keep_guest_bets: bool = false):
	"""Сброс раунда

	Args:
		update_state: Обновлять ли GameStateManager (false при подготовке к новой игре)
		keep_guest_bets: Сохранять ли ставки гостей (true при Heart Bet)
	"""
	hand_manager.reset()
	player_third_selected = false
	banker_third_selected = false
	was_heart_bet_round = false  # Сбрасываем флаг Heart Bet раунда
	ui.reset_ui()
	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	ui.set_action_button_state("start")
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.enable_action_button()

	# Скрываем кнопку Игалите при сбросе
	ui.hide_tie_button()

	# Инвалидируем кэш GameStateManager (важно даже при update_state=false)
	GameStateManager._cache_hash = -1
	DebugLogger.log("🔄 Кэш GameStateManager инвалидирован")

	if update_state:
		_update_game_state_manager()

	# Очищаем PayoutQueueManager и фишки для нового раунда
	payout_queue_manager = null
	# При Heart Bet НЕ очищаем фишки гостей - они будут восстановлены
	if chip_visual_manager:
		if not keep_guest_bets:
			chip_visual_manager.hide_all_chips()
			chip_visual_manager.clear_all_active_chips()  # Важно для REALISTIC режима!
		else:
			DebugLogger.log("❤️ Фишки гостей НЕ очищены (Heart Bet)")
	if winner_selection_manager:
		winner_selection_manager.reset()
	# Очищаем TableStateManager (полное состояние стола)
	TableStateManager.clear_state()
	
	# Сбрасываем BetCollectionPhaseManager и кнопки collect/pay
	if bet_collection_manager:
		bet_collection_manager.reset()
	if ui and ui.button_ui:
		ui.button_ui.reset_collect_pay_buttons()

	# Очищаем ставки гостей после завершения раунда (НЕ при Heart Bet!)
	if guest_bet_storage and not keep_guest_bets:
		guest_bet_storage.clear_all_bets()
		DebugLogger.log("🗑️ Ставки гостей очищены после завершения раунда")
	elif keep_guest_bets:
		DebugLogger.log("❤️ Ставки гостей сохранены (Heart Bet)")

	# Скрываем кнопки областей и стрелки навигации
	EventBus.area_buttons_visibility_changed.emit(false)
	EventBus.navigation_arrows_visibility_changed.emit(false)

	DebugLogger.log("🔄 Сброс раунда: очищены выплаты, фишки, маркеры, TableStateManager и режимы collect/pay")

# ═══════════════════════════════════════════════════════════════════════════
# РАЗДАЧА КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func deal_first_four():
	DebugLogger.log_game_flow("deal_first_four() вызван")

	# Проверяем, есть ли активные ставки (включая пары)
	var has_main_bets = PayoutSettingsManager.has_any_active_bet()
	var has_pair_bets = false
	if pair_betting_manager:
		has_pair_bets = pair_betting_manager.is_player_pair_bet_enabled() or \
						pair_betting_manager.is_banker_pair_bet_enabled()

	if not has_main_bets and not has_pair_bets:
		EventBus.show_toast_info.emit(Localization.t("DAMIKU"))

	# Проверяем флаг подготовки к новой игре (после оплаты всех фишек)
	DebugLogger.log("  → is_prepared_table: %s" % is_table_prepared)
	DebugLogger.log("  → is_first_deal: %s" % is_first_deal)

	# Зум на карты при первой раздаче ИЛИ после подготовки стола
	if is_first_deal or is_table_prepared:
		DebugLogger.log("  → Условие зума выполнено → вызываем camera_zoom_requested")
		EventBus.camera_zoom_requested.emit("in")
		is_first_deal = false
		EventBus.first_deal_completed.emit()
		# Сбрасываем флаг подготовки (начинаем новую игру)
		if is_table_prepared:
			is_table_prepared = false
			DebugLogger.log("  → ✅ Флаг is_table_prepared сброшен")
			DebugLogger.log_game_flow("Начинаем новую раздачу после подготовки стола")
	else:
		DebugLogger.log("  → ⚠️ Условие зума НЕ выполнено, зум не произойдет")

	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Подтверждаем или отклоняем ставку перед раздачей
	# Если есть ожидающий выбор - confirm() либо подтвердит, либо отклонит
	# ═══════════════════════════════════════════════════════════════════
	if heart_bet_manager and has_pending_heart_bet():
		# Устанавливаем флаг Heart Bet раунда (даже если будет отказ)
		was_heart_bet_round = true
		var confirmed = confirm_heart_bet()
		if confirmed:
			DebugLogger.log("❤️ Heart Bet подтверждён, раздача со ставкой")
		else:
			DebugLogger.log("❤️ Heart Bet отклонён, обычная раздача")

	hand_manager.deal_first_four(deck)
	player_third_selected = false
	banker_third_selected = false
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.show_first_four_cards(hand_manager.get_player_hand_ref(), hand_manager.get_banker_hand_ref())
	ui.set_action_button_state("confirm")

	# Показываем кнопку Игалите (активна только когда маркеры не выбраны)
	ui.show_tie_button()
	ui.enable_tie_button()

	# Проверяем пары (молча, без оповещений)
	if pair_betting_manager:
		pair_betting_manager.check_pairs(
			hand_manager.get_player_card(0),
			hand_manager.get_player_card(1),
			hand_manager.get_banker_card(0),
			hand_manager.get_banker_card(1)
		)
		DebugLogger.log("🃏 Проверка пар: Player=%s, Banker=%s" % [
			pair_betting_manager.has_player_pair(),
			pair_betting_manager.has_banker_pair()
		])

	# Фишки уже показаны при настройке ставок, не обновляем их здесь

	_update_game_state_manager()

func draw_player_third():
	var card: Card = deck.draw()
	hand_manager.add_player_card(card)
	ui.update_player_third_card_ui("card", card)  # Скрываем ДО анимации!
	ui.show_player_third_card(card)
	player_third_selected = false
	_update_game_state_manager()

func draw_banker_third():
	var card: Card = deck.draw()
	hand_manager.add_banker_card(card)
	ui.update_banker_third_card_ui("card", card)  # Скрываем ДО анимации!
	ui.show_banker_third_card(card)
	banker_third_selected = false
	_update_game_state_manager()


func complete_game():
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	# Кнопка НЕ меняется здесь - только после правильного выбора победителя



func _should_banker_draw() -> bool:
	return BaccaratRules.banker_should_draw(
		[hand_manager.get_banker_card(0), hand_manager.get_banker_card(1)],
		hand_manager.has_player_third_card(),
		hand_manager.get_player_third_card()
	)

func on_action_pressed():
	DebugLogger.log_separator()
	DebugLogger.log_game_flow("on_action_pressed() вызван")
	DebugLogger.log("  → is_table_prepared = %s" % is_table_prepared)

	# ═══════════════════════════════════════════════════════════════════
	# GUARD CLAUSE 1: Подготовка к новой игре
	# ═══════════════════════════════════════════════════════════════════
	if is_table_prepared:
		DebugLogger.log_separator("ФЛАГ УСТАНОВЛЕН → вызываем deal_first_four()")
		deal_first_four()
		return

	DebugLogger.log("  → Флаг НЕ установлен, продолжаем обычную логику")
	var state = GameStateManager.get_current_state()
	DebugLogger.log("  → Текущее состояние: %s" % state)

	# ═══════════════════════════════════════════════════════════════════
	# GUARD CLAUSE 2: Начало игры
	# ═══════════════════════════════════════════════════════════════════
	if state == GameStateManager.GameState.WAITING:
		deal_first_four()
		return

	# ═══════════════════════════════════════════════════════════════════
	# GUARD CLAUSE 3: Валидация банкира после третьей игрока
	# ═══════════════════════════════════════════════════════════════════
	if state == GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER:
		_validate_banker_after_player()
		return

	# ═══════════════════════════════════════════════════════════════════
	# CHOOSE_WINNER: Основная логика выбора победителя и завершения
	# ═══════════════════════════════════════════════════════════════════
	if state == GameStateManager.GameState.CHOOSE_WINNER:
		_handle_choose_winner_state()
		return

	# ═══════════════════════════════════════════════════════════════════
	# FALLBACK: Валидация и раздача третьих карт
	# ═══════════════════════════════════════════════════════════════════
	_validate_and_execute_third_cards()


func on_player_third_toggled(_selected: bool):
	player_third_selected = !player_third_selected
	if player_third_selected:
		ui.update_player_third_card_ui("!")
	else:
		ui.update_player_third_card_ui("?")
	# Дезактивируем маркер при нажатии на toggle третьей карты
	if winner_selection_manager:
		winner_selection_manager.deselect_winner()

func on_banker_third_toggled(_selected: bool):
	banker_third_selected = !banker_third_selected
	if banker_third_selected:
		ui.update_banker_third_card_ui("!")
	else:
		ui.update_banker_third_card_ui("?")
	# Дезактивируем маркер при нажатии на toggle третьей карты
	if winner_selection_manager:
		winner_selection_manager.deselect_winner()

func cancel_third_card_orders() -> void:
	"""Отменить заказ всех третьих карт (игрока и банкира)"""
	if player_third_selected:
		player_third_selected = false
		ui.update_player_third_card_ui("?")
		DebugLogger.log("🔄 Отменён заказ третьей карты игрока")

	if banker_third_selected:
		banker_third_selected = false
		ui.update_banker_third_card_ui("?")
		DebugLogger.log("🔄 Отменён заказ третьей карты банкира")


func on_tie_button_pressed():
	"""Обработка нажатия кнопки Игалите

	Кнопка одновременно выбирает и подтверждает ничью.
	Эквивалентна выбору маркера Tie + нажатию кнопки Подтвердить.
	"""
	DebugLogger.log("🎯 Нажата кнопка Игалите")

	# Проверяем что состояние CHOOSE_WINNER
	var state = GameStateManager.get_current_state()
	if state != GameStateManager.GameState.CHOOSE_WINNER:
		return

	# Определяем реального победителя
	var actual_winner = BaccaratRules.get_winner(hand_manager.get_player_hand_ref(), hand_manager.get_banker_hand_ref())

	if actual_winner != "Tie":
		# ❌ Ошибка! Нет ничьей
		EventBus.show_toast_error.emit(Localization.t("ERR_TIE_WRONG"))
		EventBus.action_error.emit("tie_wrong", Localization.t("ERR_TIE_WRONG"))
		DebugLogger.log("❌ Ошибка! Нет ничьей. Выиграл: %s" % actual_winner)
		return

	# ✅ Правильно! Действительно ничья
	EventBus.action_correct.emit("winner")
	
	# ВАЖНО: Сохраняем победителя в TableStateManager для триггеров!
	TableStateManager.set_actual_winner(actual_winner)
	
	# ═══════════════════════════════════════════════════════════════════
	# ТРИГГЕРЫ КАРТ ШАНСА (только в режиме выживания)
	# ═══════════════════════════════════════════════════════════════════
	if SaveManager.instance.load_survival_mode():
		_check_chance_card_triggers(actual_winner)

	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Если есть активная ставка - разрешаем её и завершаем
	# Выплаты НЕ нужны при Heart Bet!
	# ═══════════════════════════════════════════════════════════════════
	if has_active_heart_bet():
		print("❤️ on_tie_button_pressed: есть активный Heart Bet, вызываем resolve(%s)" % actual_winner)
		resolve_heart_bet(actual_winner)
		# НЕ продолжаем с обычной логикой - раунд сбросится через EventBus
		return

	# Меняем кнопку на "complete"
	ui.set_action_button_state("complete")
	# Активируем кнопку при переходе в стадию выплат
	ui.enable_action_button()
	
	# Показываем кнопки Collect/Pay после определения победителя
	if ui.button_ui:
		ui.button_ui.show_collect_pay_buttons()

	# Показываем toast
	EventBus.show_toast_success.emit("Игалите")

	# Возвращаем камеру на общий план и показываем кнопки областей
	EventBus.camera_zoom_requested.emit("out")
	EventBus.area_buttons_visibility_changed.emit(true)
	EventBus.navigation_arrows_visibility_changed.emit(true)  # сразу показываем стрелки после правильной Игалите

	# Формируем очередь выплат
	EventBus.manual_payout_requested.emit("Tie")

	DebugLogger.log_init("Игалите подтверждена!")


# ========================================
# ВАЛИДАЦИЯ ДЕЙСТВИЙ (перенесено из CardsDealtState)
# ========================================

func _validate_and_execute_third_cards() -> void:
	var ps: int = hand_manager.get_player_initial_score()
	var bs: int = hand_manager.get_banker_initial_score()

	# Проверка натуральных или особых комбинаций (8-9, 6v6, 7v7)
	if BaccaratRules.has_natural_or_no_third(ps, bs):
		_handle_natural_case()
		return

	var player_draw: bool = ps <= 5
	var banker_draw_always: bool = bs <= 2

	# State 2: Карта каждому (банкир 0-2, игрок 0-5)
	if banker_draw_always and player_draw:
		_handle_card_to_each()
		return

	# State 3.1: Карта игроку (банкир 7 стоит)
	if player_draw and bs == 7:
		_handle_card_to_player_with_banker_7(ps, bs)
		return

	# State 3.2: Карта игроку (банкир 3-6 решает потом)
	if player_draw and bs >= 3 and bs <= 6:
		_handle_card_to_player_with_banker_3_6(ps)
		return

	# State 4: Карта банкиру (игрок 6-7 стоит)
	var banker_draw: bool = _should_banker_draw()
	if not player_draw and banker_draw:
		_handle_card_to_banker_only(ps, bs)
		return

	# Fallback: оба стоят
	# Проверяем, не пытается ли игрок заказать карты когда оба должны стоять
	if player_third_selected or banker_third_selected:
		if player_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_PLAYER_NO_DRAW", [ps]))
			EventBus.action_error.emit("player_wrong", "")
			ui.update_player_third_card_ui("?")
			player_third_selected = false
		if banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_NO_DRAW", [bs]))
			EventBus.action_error.emit("banker_wrong", "")
			ui.update_banker_third_card_ui("?")
			banker_third_selected = false
		return

	complete_game()

# ========================================
# ОБРАБОТЧИКИ ДЛЯ КАЖДОГО СЦЕНАРИЯ
# ========================================

# Натуральная 8-9 или особые комбинации (6v6, 7v7, 6v7, 7v6)
func _handle_natural_case() -> void:
	if player_third_selected or banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_NATURAL_NO_DRAW"))
		EventBus.action_error.emit("natural_draw", Localization.t("ERR_NATURAL_NO_DRAW"))
		player_third_selected = false
		banker_third_selected = false
		ui.update_player_third_card_ui("?")
		ui.update_banker_third_card_ui("?")
		return

	complete_game()

# State 2: Карта каждому (банкир 0-2, игрок 0-5)
func _handle_card_to_each() -> void:
	if not player_third_selected or not banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("BOTH_CARDS_NEEDED"))
		EventBus.action_error.emit("both_wrong", Localization.t("BOTH_CARDS_NEEDED"))
		ui.update_player_third_card_ui("?")
		ui.update_banker_third_card_ui("?")
		return

	draw_player_third()
	draw_banker_third()
	complete_game()

# State 3.1: Карта только игроку (банкир 7 стоит)
func _handle_card_to_player_with_banker_7(ps: int, bs: int) -> void:
	# Проверка: игрок должен взять карту
	if not player_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_PLAYER_MUST_DRAW", [ps]))
		EventBus.action_error.emit("player_wrong", "")
		ui.update_player_third_card_ui("?")
		player_third_selected = true
		return

	# Проверка: банкир НЕ должен брать карту
	if banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_NO_DRAW", [bs]))
		EventBus.action_error.emit("banker_wrong", "")
		ui.update_banker_third_card_ui("?")
		banker_third_selected = false
		return

	draw_player_third()
	complete_game()

# State 3.2: Карта игроку, банкир решает потом (банкир 3-6)
func _handle_card_to_player_with_banker_3_6(ps: int) -> void:
	# Проверка: игрок должен взять карту
	if not player_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_PLAYER_MUST_DRAW", [ps]))
		EventBus.action_error.emit("player_wrong", "")
		ui.update_player_third_card_ui("?")
		player_third_selected = true
		return

	# Проверка: банкир пока НЕ должен брать (решение потом)
	if banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("BANKER_NO_CARD_YET"))
		EventBus.action_error.emit("banker_wrong", "")
		ui.update_banker_third_card_ui("?")
		banker_third_selected = false
		return

	draw_player_third()
	_handle_banker_after_player()

# State 4: Карта только банкиру (игрок 6-7 стоит)
func _handle_card_to_banker_only(ps: int, bs: int) -> void:
	# Проверка: банкир должен взять карту
	if not banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_MUST_DRAW", [bs]))
		EventBus.action_error.emit("banker_wrong", "")
		ui.update_banker_third_card_ui("?")
		banker_third_selected = true
		return

	# Проверка: игрок НЕ должен брать карту
	if player_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_PLAYER_NO_DRAW", [ps]))
		EventBus.action_error.emit("player_wrong", "")
		ui.update_player_third_card_ui("?")
		player_third_selected = false
		return

	draw_banker_third()
	complete_game()

func _handle_banker_after_player():
	var banker_draw: bool = _should_banker_draw()
	if banker_draw:
		pass  # Банкир должен взять третью карту - переходим к валидации
	else:
		complete_game()

func _validate_banker_after_player():
	var bs: int = hand_manager.get_banker_initial_score()
	var banker_draw: bool = _should_banker_draw()
	if banker_draw:
		if not banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_MUST_DRAW", [bs]))
			EventBus.action_error.emit("banker_wrong", "")
			ui.update_banker_third_card_ui("?")
			banker_third_selected = true
			return
		draw_banker_third()
		complete_game()
	else:
		if banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_NO_DRAW", [bs]))
			EventBus.action_error.emit("banker_wrong", "")
			ui.update_banker_third_card_ui("?")
			banker_third_selected = false
			return
		complete_game()

func _restore_active_bet_chips() -> void:
	"""Восстановить ВСЕ фишки из TableStateManager для новой раздачи

	При подготовке к новой игре восстанавливаем ВСЕ фишки (включая проигрышные из предыдущей раздачи)
	с их оригинальными текстурами. Это показывает игроку какие ставки будут в следующей раздаче.
	"""
	if not chip_visual_manager:
		return

	# Сначала показываем ставки гостей (если есть)
	_show_guest_bets()

	# Проверяем есть ли сохраненное состояние
	if TableStateManager.has_saved_state() and TableStateManager.get_bets().size() > 0:
		# В режиме GUEST: восстанавливаем ТОЛЬКО если есть гостевые ставки
		# Иначе фишки появятся в секторе 4 и будут нерабочими
		var has_guests = guest_bet_storage and not guest_bet_storage.get_guests_with_bets().is_empty()
		if not has_guests:
			DebugLogger.log_warning(" Режим GUEST: нет гостей, пропускаем восстановление из TableStateManager")
		else:
			# Восстанавливаем ВСЕ фишки из предыдущей раздачи (включая проигрышные)
			DebugLogger.log_restore(" Восстановление фишек для новой раздачи из TableStateManager...")
			for bet in TableStateManager.get_bets():
				var bet_type = bet.get_bet_type()
				var chip_texture = bet.get_chip_texture()
				if chip_texture.is_empty():
					chip_visual_manager.make_chip_visible(bet_type)
				else:
					chip_visual_manager.set_chip_texture(bet_type, chip_texture)
				DebugLogger.log("  → Восстановлена фишка %s" % bet_type)
	else:
		# Fallback: показываем на основе toggles (первая игра или нет сохраненного состояния)
		# НО только если нет гостевых ставок (гости имеют приоритет)
		# В режиме GUEST: если нет гостей - фишки НЕ показываем (режим GUEST только для гостей)
		if not guest_bet_storage or guest_bet_storage.get_guests_with_bets().is_empty():
			DebugLogger.log_warning(" Нет сохраненного состояния и нет гостей")
			# В режиме GUEST фишки показываются ТОЛЬКО для гостей
			# Если гостей нет - фишки не показываем (иначе они появятся в секторе 4 и будут нерабочими)
			DebugLogger.log(" Режим GUEST: гостей нет, фишки не показываем")

	DebugLogger.log_payout("Показаны фишки всех активных ставок")

func _show_guest_bets() -> void:
	"""Показать ставки гостей на их позициях в секторах"""
	if not guest_bet_storage or not chip_visual_manager:
		DebugLogger.log("👥 _show_guest_bets: нет guest_bet_storage или chip_visual_manager")
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# СОХРАНЕНИЕ SNAPSHOT ФИЛЬТРА: фиксируем состояние на момент показки
	# ═══════════════════════════════════════════════════════════════════
	_save_filter_snapshot()
	
	var guests_with_bets = guest_bet_storage.get_guests_with_bets()
	if guests_with_bets.is_empty():
		DebugLogger.log("👥 Нет ставок гостей для отображения")
		return
	
	DebugLogger.log("👥 Отображение ставок %d гостей: %s" % [guests_with_bets.size(), guests_with_bets])
	
	for guest_id in guests_with_bets:
		var bets = guest_bet_storage.get_guest_bets(guest_id)
		DebugLogger.log("👥 Гость %d: %d ставок" % [guest_id, bets.size()])
		for bet in bets:
			# Получаем координаты позиции
			var bet_type = bet.get_bet_type()
			
			# ═══════════════════════════════════════════════════════════════════
			# ФИЛЬТР НАСТРОЕК: Показываем только включенные ставки
			# ═══════════════════════════════════════════════════════════════════
			if not _is_bet_type_enabled_in_settings(bet_type):
				DebugLogger.log("  → Гость %d: ставка %s отфильтрована (выключена в настройках)" % [guest_id, bet_type])
				continue
			
			var sector = bet.get_sector()
			var pos_idx = bet.get_position_index()
			var stake = bet.get_stake()
			var coords = GuestSectorMapper.get_position_coordinates(sector, bet_type)
			if coords == Vector2.ZERO:
				DebugLogger.log_warning("⚠️ Не найдены координаты для %s в секторе %d" % [bet_type, sector])
				continue
			
			# Создаём фишку на позиции гостя
			_show_guest_chip_at_position(bet_type, pos_idx, coords, stake)
			DebugLogger.log("  → Гость %d: фишка %s на позиции %d (%.0f)" % [guest_id, bet_type, pos_idx, stake])

func _show_guest_chip_at_position(bet_type: String, position_index: int, coords: Vector2, stake: float) -> void:
	"""Показать фишку гостя на конкретной позиции
	
	Использует метод show_chips_realistic для создания фишки на конкретной позиции
	"""
	if not chip_visual_manager:
		return
	
	# Определяем сектор для логирования
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	DebugLogger.log("👥 _show_guest_chip_at_position: %s[%d] → сектор %d, coords=%s, stake=%.0f" % [bet_type, position_index, sector, coords, stake])
	
	# Проверяем, есть ли уже фишка на этой позиции
	var existing_chip = chip_visual_manager.get_chip_instance(bet_type, position_index)
	if existing_chip:
		# Обновляем существующую фишку (текстура уже установлена)
		if existing_chip.node:
			existing_chip.node.visible = true
			existing_chip.stake = stake
		DebugLogger.log("  → Обновлена существующая фишка %s[%d]" % [bet_type, position_index])
		return
	
	# Создаём фишку через show_chips_realistic с конкретной позицией
	# Но нам нужен способ указать конкретную позицию, а не случайную
	# Пока используем упрощённый подход: создаём фишку на позиции через прямое обращение
	
	# Получаем текстуру
	var texture_path = chip_visual_manager.get_current_texture(bet_type)
	if texture_path.is_empty():
		# Если нет сохранённой текстуры - используем случайную
		# ВАЖНО: используем get_random_texture() вместо show_chip(), чтобы не показывать фишку на дефолтной позиции
		texture_path = chip_visual_manager.get_random_texture(bet_type)
		# Сохраняем текстуру для следующих фишек того же типа
		chip_visual_manager.set_current_texture(bet_type, texture_path)
	
	var texture = load(texture_path) if not texture_path.is_empty() else null
	if not texture:
		DebugLogger.log_error("❌ Не удалось загрузить текстуру для %s" % bet_type)
		return
	
	# Получаем оригинальную фишку
	var original_chip = chip_visual_manager.chip_nodes.get(bet_type)
	if not original_chip:
		DebugLogger.log_error("❌ Нет оригинальной фишки для типа %s" % bet_type)
		return
	
	# Проверяем, есть ли уже активные фишки этого типа
	var active_chips_of_type = chip_visual_manager.get_active_chips_by_type(bet_type)
	
	if active_chips_of_type.is_empty():
		# Первая фишка - используем оригинальную
		original_chip.texture_normal = texture
		original_chip.position = coords
		original_chip.visible = true
		
		# Отключаем ВСЕ старые обработчики (и _on_chip_pressed, и _on_chip_instance_pressed)
		# В Godot 4 используем get_connections() который возвращает Array[Dictionary]
		# с ключами: signal, callable, flags
		# ВАЖНО: _on_chip_instance_pressed с разными bind() аргументами - это разные Callable,
		# поэтому нужно отключать ВСЕ, иначе при клике вызовутся несколько обработчиков!
		var connections = original_chip.pressed.get_connections()
		for conn in connections:
			var callable: Callable = conn["callable"]
			var method_name = callable.get_method()
			if method_name == "_on_chip_pressed" or method_name == "_on_chip_instance_pressed":
				original_chip.pressed.disconnect(callable)
		
		# Подключаем новый обработчик с position_index
		original_chip.pressed.connect(chip_visual_manager._on_chip_instance_pressed.bind(bet_type, position_index))
		
		# Создаём ChipInstance
		var chip_instance = ChipVisualManager.ChipInstance.new(bet_type, position_index, original_chip, true)
		chip_instance.stake = stake
		chip_visual_manager.active_chips.append(chip_instance)
	else:
		# Создаём копию фишки (используем приватный метод через публичный интерфейс)
		# Для этого создадим фишку через show_chips_realistic, но нам нужна конкретная позиция
		# Временно создадим фишку вручную
		if not chip_visual_manager.scene_root:
			DebugLogger.log_error("❌ scene_root не задан в ChipVisualManager")
			return
		
		var new_chip = TextureButton.new()
		new_chip.texture_normal = texture
		new_chip.position = coords
		new_chip.scale = original_chip.scale
		new_chip.modulate = original_chip.modulate
		new_chip.mouse_filter = Control.MOUSE_FILTER_STOP
		new_chip.visible = true
		
		# Подключаем сигнал
		new_chip.pressed.connect(chip_visual_manager._on_chip_instance_pressed.bind(bet_type, position_index))
		
		chip_visual_manager.scene_root.add_child(new_chip)
		
		# Добавляем в extra_chips для совместимости
		# В GDScript приватные переменные доступны напрямую
		# TODO: Создать публичный метод в ChipVisualManager для добавления фишки
		if not chip_visual_manager.extra_chips.has(bet_type):
			chip_visual_manager.extra_chips[bet_type] = []
		chip_visual_manager.extra_chips[bet_type].append(new_chip)
		
		# Создаём ChipInstance
		var chip_instance = ChipVisualManager.ChipInstance.new(bet_type, position_index, new_chip, false)
		chip_instance.stake = stake
		chip_visual_manager.active_chips.append(chip_instance)

func _is_bet_type_enabled_in_settings(bet_type: String) -> bool:
	"""Проверить, включён ли тип ставки в настройках PayoutSettingsManager
	
	Используется для фильтрации ставок при показке и добавлении в очередь выплат.
	
	Args:
		bet_type: Тип ставки (Player, Banker, Tie, PairPlayer, PairBanker)
	
	Returns:
		true если ставка включена в настройках, false если отключена
	"""
	match bet_type:
		"Player":
			return PayoutSettingsManager.player_payout_enabled
		"Banker":
			return PayoutSettingsManager.banker_payout_enabled
		"Tie":
			return PayoutSettingsManager.tie_payout_enabled
		"PairPlayer":
			return pair_betting_manager and pair_betting_manager.is_player_pair_bet_enabled()
		"PairBanker":
			return pair_betting_manager and pair_betting_manager.is_banker_pair_bet_enabled()
		_:
			return true  # Неизвестный тип - пропускаем (не фильтруем)

func _save_filter_snapshot() -> void:
	"""Сохранить снимок текущего состояния фильтра
	
	Вызывается при показке ставок для изоляции текущей раздачи от изменений фильтра.
	"""
	_filter_snapshot.clear()
	_filter_snapshot["Player"] = PayoutSettingsManager.player_payout_enabled
	_filter_snapshot["Banker"] = PayoutSettingsManager.banker_payout_enabled
	_filter_snapshot["Tie"] = PayoutSettingsManager.tie_payout_enabled
	_filter_snapshot["PairPlayer"] = pair_betting_manager.is_player_pair_bet_enabled() if pair_betting_manager else false
	_filter_snapshot["PairBanker"] = pair_betting_manager.is_banker_pair_bet_enabled() if pair_betting_manager else false
	DebugLogger.log("📸 Snapshot фильтра сохранён: %s" % _filter_snapshot)

func _is_bet_type_enabled_in_snapshot(bet_type: String) -> bool:
	"""Проверить, включён ли тип ставки в snapshot фильтра
	
	Используется при добавлении ставок в очередь выплат для изоляции текущей раздачи.
	Если snapshot пустой - использует текущее состояние (fallback).
	
	Args:
		bet_type: Тип ставки (Player, Banker, Tie, PairPlayer, PairBanker)
	
	Returns:
		true если ставка включена в snapshot, false если отключена
	"""
	# Если snapshot пустой - используем текущее состояние (fallback)
	if _filter_snapshot.is_empty():
		return _is_bet_type_enabled_in_settings(bet_type)
	
	# Проверяем snapshot
	if _filter_snapshot.has(bet_type):
		return _filter_snapshot[bet_type]
	
	# Если типа нет в snapshot - используем текущее состояние (fallback)
	return _is_bet_type_enabled_in_settings(bet_type)

func is_bet_type_enabled_in_snapshot(bet_type: String) -> bool:
	"""Публичный метод для проверки ставки через snapshot (для PayoutManager)
	
	Args:
		bet_type: Тип ставки (Player, Banker, Tie, PairPlayer, PairBanker)
	
	Returns:
		true если ставка включена в snapshot, false если отключена
	"""
	return _is_bet_type_enabled_in_snapshot(bet_type)

func _apply_pending_filter_changes() -> void:
	"""Применить накопленные изменения фильтра к PayoutSettingsManager
	
	Вызывается при завершении раунда перед генерацией новых ставок.
	Применяет все изменения из _pending_filter_changes и обновляет snapshot.
	"""
	if _pending_filter_changes.is_empty():
		DebugLogger.log("📋 Нет накопленных изменений фильтра для применения")
		return
	
	DebugLogger.log("📋 Применение накопленных изменений фильтра: %s" % _pending_filter_changes)
	
	# Применяем каждое изменение к PayoutSettingsManager
	for bet_type in _pending_filter_changes.keys():
		var enabled = _pending_filter_changes[bet_type]
		match bet_type:
			"Player":
				PayoutSettingsManager.player_payout_enabled = enabled
			"Banker":
				PayoutSettingsManager.banker_payout_enabled = enabled
			"Tie":
				PayoutSettingsManager.tie_payout_enabled = enabled
			"PairPlayer":
				if pair_betting_manager:
					pair_betting_manager.toggle_pair_player_bet(enabled)
			"PairBanker":
				if pair_betting_manager:
					pair_betting_manager.toggle_pair_banker_bet(enabled)
		DebugLogger.log("  → Применено: %s = %s" % [bet_type, "ВКЛ" if enabled else "ВЫКЛ"])
	
	# Обновляем snapshot на основе примененных изменений
	_save_filter_snapshot()
	
	# Очищаем pending_changes
	_pending_filter_changes.clear()
	DebugLogger.log("📋 Все накопленные изменения применены, snapshot обновлён")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ СОСТОЯНИЕМ
# ═══════════════════════════════════════════════════════════════════════════

func _update_game_state_manager():
	var cards_hidden = hand_manager.are_hands_empty()
	var player_third_card = hand_manager.get_player_third_card()
	var banker_third_card = hand_manager.get_banker_third_card()
	GameStateManager.determine_and_update_state(
		cards_hidden,
		hand_manager.get_player_hand_ref(),
		hand_manager.get_banker_hand_ref(),
		player_third_card,
		banker_third_card
	)

# ========================================
# ВАЛИДАЦИЯ ВЫБОРА ПОБЕДИТЕЛЯ (новая логика)
# ========================================

func _validate_winner_selection() -> void:
	"""Проверка выбранного победителя через маркеры"""
	if not winner_selection_manager:
		EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))
		return

	var selected_winner = winner_selection_manager.get_selected_winner()

	# Не выбран ни один маркер?
	if selected_winner == "":
		return

	# Проверяем правильность
	var actual_winner = BaccaratRules.get_winner(hand_manager.get_player_hand_ref(), hand_manager.get_banker_hand_ref())
	
	# ВАЖНО: Сохраняем победителя в TableStateManager для триггеров Heart Bet!
	TableStateManager.set_actual_winner(actual_winner)

	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ТРИГГЕРОВ HEART BET: сразу после определения победителя
	# Карта шанса показывается немедленно через EventBus.heart_bet_trigger_activated
	# ═══════════════════════════════════════════════════════════════════
	if heart_bet_manager and SaveManager.instance.load_survival_mode() and not was_heart_bet_round and not has_active_heart_bet():
		var player_hand_ref = hand_manager.get_player_hand_ref()
		var banker_hand_ref = hand_manager.get_banker_hand_ref()
		if not player_hand_ref.is_empty() and not banker_hand_ref.is_empty():
			var player_score = BaccaratRules.hand_value(player_hand_ref)
			var banker_score = BaccaratRules.hand_value(banker_hand_ref)
			var is_natural = BaccaratRules.is_natural(player_hand_ref) or BaccaratRules.is_natural(banker_hand_ref)
			# HeartBetManager.check_triggers() уже эмитит EventBus.heart_bet_trigger_activated
			# ChanceCardManager автоматически покажет карту через подписку на это событие
			heart_bet_manager.check_triggers(actual_winner, banker_score, player_score, is_natural)

	if selected_winner != actual_winner:
		# ❌ Неправильный выбор
		var error_msg: String
		if actual_winner == "Tie":
			error_msg = "Ошибка! Неправильный выбор. Игалите"
		else:
			error_msg = Localization.t("ERR_WRONG_WINNER", [actual_winner])
		EventBus.show_toast_error.emit(error_msg)
		EventBus.action_error.emit("winner_wrong", "")
		# Сбрасываем выбор маркера
		winner_selection_manager.reset()
		return

	# ✅ Правильный выбор!
	EventBus.action_correct.emit("winner")
	
	# ═══════════════════════════════════════════════════════════════════
	# ТРИГГЕРЫ КАРТ ШАНСА (только в режиме выживания)
	# ═══════════════════════════════════════════════════════════════════
	if SaveManager.instance.load_survival_mode():
		_check_chance_card_triggers(actual_winner)
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Если это был Heart Bet раунд (даже с отказом) - пропускаем выплаты
	# ═══════════════════════════════════════════════════════════════════
	if was_heart_bet_round:
		print("❤️ _validate_winner_selection: был Heart Bet раунд (даже с отказом), пропускаем выплаты")
		# Если была активная ставка - разрешаем её
		if has_active_heart_bet():
			resolve_heart_bet(actual_winner)
		else:
			# Отказ от шанса - просто завершаем раунд без выплат
			# Эмитим сигнал завершения Heart Bet раунда для сброса
			EventBus.heart_bet_round_complete.emit()
		# В любом случае НЕ продолжаем с обычной логикой выплат
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Если есть активная ставка - разрешаем её и завершаем
	# Выплаты НЕ нужны при Heart Bet!
	# ═══════════════════════════════════════════════════════════════════
	if has_active_heart_bet():
		print("❤️ _validate_winner_selection: есть активный Heart Bet, вызываем resolve(%s)" % actual_winner)
		resolve_heart_bet(actual_winner)
		# НЕ продолжаем с обычной логикой - раунд сбросится через EventBus
		return

	# Меняем кнопку на "complete" (готовность к выплатам)
	ui.set_action_button_state("complete")
	# Активируем кнопку при переходе в стадию выплат
	ui.enable_action_button()

	# Показываем кнопки Collect/Pay после определения победителя
	if ui.button_ui:
		ui.button_ui.show_collect_pay_buttons()

	# Показываем toast с результатом (кто выиграл и с какими картами)
	var victory_msg = _format_victory_toast(actual_winner)
	EventBus.show_toast_success.emit(victory_msg)

	# Возвращаем камеру на общий план и показываем кнопки областей
	EventBus.camera_zoom_requested.emit("out")
	EventBus.area_buttons_visibility_changed.emit(true)
	EventBus.navigation_arrows_visibility_changed.emit(true)  # сразу показываем стрелки после правильного выбора

	# Вызываем метод формирования очереди выплат через EventBus
	EventBus.manual_payout_requested.emit(actual_winner)

func _format_victory_toast(winner: String) -> String:
	"""Форматирование сообщения победы"""
	var player_score = hand_manager.get_player_score()
	var banker_score = hand_manager.get_banker_score()

	if winner == "Tie":
		return "Игалите"

	var winner_text = ""
	var winner_score = 0
	var loser_score = 0

	if winner == "Player":
		winner_text = Localization.t("PLAYER")
		winner_score = player_score
		loser_score = banker_score
	else:  # Banker
		winner_text = Localization.t("BANKER")
		winner_score = banker_score
		loser_score = player_score

	return "Выиграл %s: %d vs %d" % [winner_text, winner_score, loser_score]

# ═══════════════════════════════════════════════════════════════════════════
# РЕФАКТОРЕННЫЕ HELPER МЕТОДЫ (из on_action_pressed)
# ═══════════════════════════════════════════════════════════════════════════

func _handle_choose_winner_state() -> void:
	"""Обработка состояния CHOOSE_WINNER (выбор победителя и завершение раунда)

	Рефакторенная версия с guard clauses для уменьшения вложенности.
	Было: 6+ уровней вложенности, 134 строки
	Стало: 2-3 уровня вложенности, разбито на методы
	"""

	# GUARD 1: Ошибочная попытка заказать карты в финале
	if player_third_selected or banker_third_selected:
		_handle_invalid_card_selection_in_final()
		return

	# GUARD 2: Первое нажатие - выбор победителя
	var button_state = ui.get_action_button_state()
	if button_state != "complete":
		_validate_winner_selection()
		return

	# GUARD 3: Проверка завершения раунда (неоплаченные ставки)
	if not _can_complete_round():
		return  # Сообщение об ошибке показано в _can_complete_round()

	# Все проверки пройдены → завершаем раунд
	_complete_round_and_prepare_new_game()


func _handle_invalid_card_selection_in_final() -> void:
	"""Обработка ошибочной попытки заказать карты когда все карты открыты"""

	var player_first_two = hand_manager.get_player_initial_score()
	var banker_first_two = hand_manager.get_banker_initial_score()
	var is_natural = player_first_two >= 8 or banker_first_two >= 8

	var error_message = Localization.t("ERR_NATURAL_NO_DRAW") if is_natural else Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER")
	EventBus.show_toast_error.emit(error_message)
	EventBus.action_error.emit("final_card_error", "")

	# Сбрасываем галочки
	player_third_selected = false
	banker_third_selected = false
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")


func _can_complete_round() -> bool:
	"""Проверка возможности завершения раунда (нет неоплаченных ставок)

	Returns:
		true если раунд можно завершить, false если есть неоплаченные ставки
	"""

	# Проверка через BetCollectionPhaseManager (приоритет)
	if bet_collection_manager:
		var completion_check = bet_collection_manager.can_complete_round()
		if not completion_check.can:
			var error_key = completion_check.error_key
			EventBus.show_toast_error.emit(Localization.t(error_key))
			EventBus.action_error.emit("incomplete_bets", error_key)
			ui.disable_action_button()
			DebugLogger.log("🔒 Кнопка 'Завершить' дезактивирована (причины: %s)" % str(completion_check.reasons))
			return false
		return true

	# Fallback: старая логика без bet_collection_manager
	if payout_queue_manager and payout_queue_manager.has_unpaid_winnings():
		var unpaid_count = payout_queue_manager.get_unpaid_count()
		EventBus.show_toast_error.emit(Localization.t("ERR_UNPAID_BETS"))
		EventBus.action_error.emit("unpaid_bets", "")
		ui.disable_action_button()
		DebugLogger.log("🔒 Кнопка 'Завершить' дезактивирована (неоплаченных ставок: %d)" % unpaid_count)
		return false

	return true


func _complete_round_and_prepare_new_game() -> void:
	"""Завершение раунда и подготовка к новой игре

	Выполняет:
	1. РАЗРЕШЕНИЕ АКТИВНОГО Heart Bet (если есть)
	2. Проверка триггеров Heart Bet (ПЕРЕД сбросом!)
	3. Показ сообщения о завершении (зависит от результата ставок)
	4. Зум камеры на общий план
	5. Начисление очков
	6. Сброс раунда
	7. Восстановление фишек
	8. Установка флага подготовки
	"""

	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Разрешаем активную ставку сердцем (если есть)
	# При активном Heart Bet НЕ делаем обычное завершение!
	# ═══════════════════════════════════════════════════════════════════
	if has_active_heart_bet():
		var actual_winner = TableStateManager.get_actual_winner()
		print("❤️ GamePhaseManager: есть активный Heart Bet, вызываем resolve(%s)" % actual_winner)
		resolve_heart_bet(actual_winner)
		# НЕ продолжаем - раунд сбросится через EventBus heart_bet_round_complete
		return

	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ТРИГГЕРОВ HEART BET перенесена в _validate_winner_selection()
	# (происходит сразу после определения победителя)
	# ═══════════════════════════════════════════════════════════════════

	# Показываем сообщение о завершении
	_show_round_completion_message()

	DebugLogger.log_separator("ВСЕ ВЫПЛАТЫ ОПЛАЧЕНЫ → ПОДГОТОВКА К НОВОЙ ИГРЕ")

	# Зумаут камеры на общий план
	EventBus.camera_zoom_requested.emit("out")
	EventBus.area_buttons_visibility_changed.emit(false)
	EventBus.navigation_arrows_visibility_changed.emit(false)
	DebugLogger.log("  → ✅ Камера отзумлена, кнопки областей скрыты")

	# Начисляем +1 очко (только в режиме без сердечек)
	if not SaveManager.instance.load_survival_mode():
		SaveManager.instance.add_score(1)
		if StatsManager.instance:
			StatsManager.instance.update_stats()
		DebugLogger.log("  → ✅ +1 очко за завершение игры")

	# Сброс раунда БЕЗ обновления GameStateManager
	reset(false)
	DebugLogger.log("  → ✅ Сброс выполнен, карты показаны рубашками")

	# ВАЖНО: Явно устанавливаем WAITING, так как reset(false) не обновляет состояние
	# Это нужно для того, чтобы карту шанса можно было использовать
	GameStateManager.update_state(GameStateManager.GameState.WAITING)
	DebugLogger.log("  → ✅ Состояние установлено в WAITING (готово к использованию карты шанса)")

	# ═══════════════════════════════════════════════════════════════════
	# ПРИМЕНЕНИЕ НАКОПЛЕННЫХ ИЗМЕНЕНИЙ ФИЛЬТРА
	# ═══════════════════════════════════════════════════════════════════
	_apply_pending_filter_changes()

	# Генерируем ставки для всех активных гостей
	if guest_bet_factory and limits_manager:
		guest_bet_factory.generate_bets_for_all_guests()
		DebugLogger.log("  → ✅ Ставки гостей сгенерированы")

	# Восстанавливаем видимость активных фишек
	if chip_visual_manager:
		_restore_active_bet_chips()
		DebugLogger.log("  → ✅ Активные фишки восстановлены")

	# Устанавливаем флаг подготовки к новой игре
	is_table_prepared = true
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Автоматический показ сердец УБРАН!
	# Теперь игрок сам нажимает на карту шанса чтобы активировать игру на жизнь
	# ═══════════════════════════════════════════════════════════════════
	# if heart_bet_manager and heart_bet_manager.is_available():
	#     start_heart_bet_selection()  # ← СТАРАЯ ЛОГИКА
	
	DebugLogger.log_separator("ПОДГОТОВКА ЗАВЕРШЕНА. Нажмите 'Карты' для новой раздачи")


func _show_round_completion_message() -> void:
	"""Показ сообщения о завершении раунда (зависит от результата ставок)"""

	DebugLogger.log_separator("Проверка завершения раунда")

	# Нет payout_queue_manager
	if not payout_queue_manager:
		DebugLogger.log_init("НЕТ АКТИВНЫХ СТАВОК → ЗАВЕРШАЕМ РАУНД")
		EventBus.show_toast_info.emit(Localization.t("NO_ACTIVE_BETS"))
		return

	# Нет ставок вообще
	if not payout_queue_manager.has_any_payouts():
		DebugLogger.log_init("НЕТ АКТИВНЫХ СТАВОК → ЗАВЕРШАЕМ РАУНД")
		EventBus.show_toast_info.emit(Localization.t("NO_ACTIVE_BETS"))
		return

	# Есть ставки - проверяем результат
	if payout_queue_manager.has_unpaid_winnings():
		DebugLogger.log_warning("⚠️ ЕСТЬ НЕОПЛАЧЕННЫЕ ВЫПЛАТЫ → НЕ ЗАВЕРШАЕМ РАУНД")
		return

	# Все выплаты оплачены
	var has_winning = payout_queue_manager.has_any_winning_bets()
	if has_winning:
		DebugLogger.log_init("ВСЕ СТАВКИ ОПЛАЧЕНЫ → ЗАВЕРШАЕМ РАУНД")
		EventBus.show_toast_info.emit(Localization.t("ALL_BETS_PAID"))
	else:
		DebugLogger.log_init("НЕТ ВЫИГРЫШНЫХ СТАВОК → ЗАВЕРШАЕМ РАУНД")
		EventBus.show_toast_info.emit(Localization.t("NO_WINNING_BETS"))


# ═══════════════════════════════════════════════════════════════════════════
# ❤️ HEART BET - СТАВКА СЕРДЦЕМ
# ═══════════════════════════════════════════════════════════════════════════

func _check_heart_bet_triggers() -> void:
	"""Проверить триггеры Heart Bet после завершения раунда
	
	Вызывается ПЕРЕД сбросом раунда, чтобы данные о раздаче ещё были доступны.
	"""
	# ПРОВЕРКА: Если Game Over - не проверяем триггеры
	if not EventBus.is_game_active:
		print("❤️ _check_heart_bet_triggers: Game Over, триггеры не проверяются")
		return
	
	if not heart_bet_manager:
		print("❤️ _check_heart_bet_triggers: heart_bet_manager не существует")
		return
	
	# Получаем данные о завершённом раунде
	var winner = TableStateManager.get_actual_winner()
	print("❤️ _check_heart_bet_triggers: winner='%s'" % winner)
	
	if winner.is_empty():
		print("❤️ _check_heart_bet_triggers: нет данных о победителе, пропускаем")
		return
	
	# Вычисляем очки
	var player_hand = hand_manager.get_player_hand_ref()
	var banker_hand = hand_manager.get_banker_hand_ref()
	
	print("❤️ _check_heart_bet_triggers: player_hand.size=%d, banker_hand.size=%d" % [player_hand.size(), banker_hand.size()])
	
	if player_hand.is_empty() or banker_hand.is_empty():
		print("❤️ _check_heart_bet_triggers: руки пустые, пропускаем")
		return
	
	var player_score = BaccaratRules.hand_value(player_hand)
	var banker_score = BaccaratRules.hand_value(banker_hand)
	var is_natural = BaccaratRules.is_natural(player_hand) or BaccaratRules.is_natural(banker_hand)
	
	print("❤️ _check_heart_bet_triggers: player=%d, banker=%d, natural=%s" % [player_score, banker_score, is_natural])
	
	# Проверяем триггеры
	# HeartBetManager.check_triggers() уже эмитит EventBus.heart_bet_trigger_activated,
	# поэтому просто вызываем его - карта покажется автоматически через ChanceCardManager
	heart_bet_manager.check_triggers(winner, banker_score, player_score, is_natural)


func start_heart_bet_selection() -> void:
	"""Начать фазу выбора Heart Bet (вызывается при начале раздачи)
	
	Если есть доступный шанс - показывает сердца на столе.
	"""
	if heart_bet_manager and heart_bet_manager.is_available():
		heart_bet_manager.start_selection_phase()
		DebugLogger.log("❤️ Фаза выбора Heart Bet начата")


func confirm_heart_bet() -> bool:
	"""Подтвердить или отклонить ставку Heart Bet
	
	Вызывается при нажатии кнопки "Начать" если есть ожидающий выбор.
	Returns: true если ставка подтверждена, false если отклонена или не было выбора
	"""
	if not heart_bet_manager:
		return false
	
	if heart_bet_manager.is_pending() or heart_bet_manager.is_selected():
		return heart_bet_manager.confirm()
	
	return false


func resolve_heart_bet(actual_winner: String) -> void:
	"""Разрешить ставку Heart Bet (определить результат)

	Вызывается после определения победителя раздачи.
	"""
	# #region agent log
	var _hb_active = heart_bet_manager.is_active() if heart_bet_manager else false
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H1","location":"GamePhaseManager.resolve_heart_bet","message":"resolve_heart_bet called","data":{"actual_winner":"%s","heart_bet_active":%s},"timestamp":%d}' % [actual_winner, str(_hb_active).to_lower(), int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	if heart_bet_manager and heart_bet_manager.is_active():
		heart_bet_manager.resolve(actual_winner)
		DebugLogger.log("❤️ Heart Bet разрешён (winner=%s)" % actual_winner)


func has_active_heart_bet() -> bool:
	"""Проверить, есть ли активная ставка Heart Bet"""
	var result = heart_bet_manager != null and heart_bet_manager.is_active()
	if heart_bet_manager:
		print("❤️ has_active_heart_bet: manager exists, state=%s, is_active=%s" % [
			heart_bet_manager.get_state_name(),
			heart_bet_manager.is_active()
		])
	return result


func has_pending_heart_bet() -> bool:
	"""Проверить, есть ли ожидающий выбор Heart Bet"""
	return heart_bet_manager != null and (heart_bet_manager.is_pending() or heart_bet_manager.is_selected())


# ═══════════════════════════════════════════════════════════════════════════
# 🎴 ТРИГГЕРЫ КАРТ ШАНСА
# ═══════════════════════════════════════════════════════════════════════════

func _check_chance_card_triggers(actual_winner: String) -> void:
	"""Проверить и активировать триггеры карт шанса после определения победителя
	
	Триггеры:
	- Mystery Card: натуральная победа (8 или 9)
	- Heart Card: победа банкира с 6 очками
	- Heart Bet Card: Tie (игалите)
	- Revolver Card: две пары одновременно (Player Pair + Banker Pair)
	- Third Card Change: все 6 карт - картинки (J, Q, K)
	"""
	var player_hand = hand_manager.get_player_hand_ref()
	var banker_hand = hand_manager.get_banker_hand_ref()
	
	if player_hand.is_empty() or banker_hand.is_empty():
		print("🎴 _check_chance_card_triggers: руки пустые, пропускаем")
		return
	
	var player_score = BaccaratRules.hand_value(player_hand)
	var banker_score = BaccaratRules.hand_value(banker_hand)
	var is_natural = BaccaratRules.is_natural(player_hand) or BaccaratRules.is_natural(banker_hand)
	
	print("🎴 Проверка триггеров карт шанса: winner=%s, player=%d, banker=%d, natural=%s" % [actual_winner, player_score, banker_score, is_natural])
	
	# ═══════════════════════════════════════════════════════════════════
	# 1. MYSTERY CARD: натуральная победа (8 или 9)
	# ═══════════════════════════════════════════════════════════════════
	if is_natural and actual_winner != "Tie":
		EventBus.mystery_card_triggered.emit()
		print("❓ Mystery Card триггер: натуральная победа!")
	
	# ═══════════════════════════════════════════════════════════════════
	# 2. HEART CARD: победа банкира с 6 очками
	# ═══════════════════════════════════════════════════════════════════
	if actual_winner == "Banker" and banker_score == 6:
		EventBus.heart_card_triggered.emit()
		print("❤️ Heart Card триггер: банкир выиграл с 6!")
	
	# ═══════════════════════════════════════════════════════════════════
	# 3. HEART BET CARD: Tie (игалите) - шанс сыграть на жизнь
	# ═══════════════════════════════════════════════════════════════════
	if actual_winner == "Tie":
		EventBus.heart_bet_card_triggered.emit()
		print("🎰 Heart Bet Card триггер: Tie (игалите)!")
	
	# ═══════════════════════════════════════════════════════════════════
	# 4. REVOLVER CARD: две пары одновременно (Player Pair + Banker Pair)
	# ═══════════════════════════════════════════════════════════════════
	var has_player_pair = _check_pair(player_hand)
	var has_banker_pair = _check_pair(banker_hand)
	if has_player_pair and has_banker_pair:
		EventBus.revolver_card_triggered.emit()
		print("🔫 Revolver Card триггер: две пары одновременно!")
	
	# ═══════════════════════════════════════════════════════════════════
	# 5. THIRD CARD CHANGE: все 6 карт - картинки (J, Q, K)
	# ═══════════════════════════════════════════════════════════════════
	if _check_all_face_cards(player_hand, banker_hand):
		EventBus.third_card_change_triggered.emit()
		print("🔄 Third Card Change триггер: все 6 карт картинки!")


func _check_pair(hand: Array) -> bool:
	"""Проверить, есть ли пара в руке (первые две карты одного ранга)"""
	if hand.size() < 2:
		return false
	
	var card1 = hand[0]
	var card2 = hand[1]
	
	# Получаем ранг карты из её данных
	var rank1 = _get_card_rank(card1)
	var rank2 = _get_card_rank(card2)
	
	var is_pair = rank1 == rank2 and rank1 != ""
	print("🎴 _check_pair: card1=%s, card2=%s, rank1=%s, rank2=%s, is_pair=%s" % [
		card1.card_to_string() if card1 is Card else str(card1),
		card2.card_to_string() if card2 is Card else str(card2),
		rank1, rank2, is_pair
	])
	
	return is_pair


func _get_card_rank(card) -> String:
	"""Получить ранг карты (2-10, J, Q, K, A)"""
	# card — объект Card с полем value (1=A, 2-10, 11=J, 12=Q, 13=K)
	if card is Card:
		return str(card.value)  # Возвращаем value как строку для сравнения
	# Fallback: card может быть словарём {rank, suit} или строкой
	elif card is Dictionary:
		return card.get("rank", "")
	elif card is String:
		# Парсим из строки типа "8_diamonds" или "queen_spades"
		var parts = card.split("_")
		if parts.size() >= 1:
			return parts[0]
	return ""


func _check_all_face_cards(player_hand: Array, banker_hand: Array) -> bool:
	"""Проверить, все ли 6 карт - картинки (J, Q, K)
	
	Картинки имеют значение 0 очков: Jack, Queen, King, 10
	Card.value: 10=10, 11=J, 12=Q, 13=K
	"""
	# Должно быть по 3 карты у каждого (с третьими картами)
	if player_hand.size() < 3 or banker_hand.size() < 3:
		return false
	
	var all_cards = player_hand + banker_hand
	# Для объектов Card: 10, 11(J), 12(Q), 13(K)
	# Для строк/словарей: jack, queen, king, 10, j, q, k
	var face_ranks = ["jack", "queen", "king", "10", "j", "q", "k", "11", "12", "13"]
	
	for card in all_cards:
		var rank = _get_card_rank(card).to_lower()
		if rank not in face_ranks:
			return false
	
	return true
