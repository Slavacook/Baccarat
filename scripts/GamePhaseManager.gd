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
var bet_collection_manager: BetCollectionPhaseManager = null

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

func _init(
	deck_ref: Deck,
	card_manager_ref: CardTextureManager,
	ui_ref: UIManager,
	hand_mgr: HandManager,
	payout_queue_mgr: PayoutQueueManager,
	chip_visual_mgr: ChipVisualManager,
	winner_selection_mgr: WinnerSelectionManager,
	pair_betting_mgr: PairBettingManager
):
	deck = deck_ref
	card_manager = card_manager_ref
	ui = ui_ref
	hand_manager = hand_mgr
	payout_queue_manager = payout_queue_mgr
	chip_visual_manager = chip_visual_mgr
	winner_selection_manager = winner_selection_mgr
	pair_betting_manager = pair_betting_mgr

	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	ui.set_action_button_state("start")

func reset(update_state: bool = true):
	"""Сброс раунда

	Args:
		update_state: Обновлять ли GameStateManager (false при подготовке к новой игре)
	"""
	hand_manager.reset()
	player_third_selected = false
	banker_third_selected = false
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
	if chip_visual_manager:
		chip_visual_manager.hide_all_chips()
		chip_visual_manager.clear_all_active_chips()  # Важно для REALISTIC режима!
	if winner_selection_manager:
		winner_selection_manager.reset()
	# Очищаем TableStateManager (полное состояние стола)
	TableStateManager.clear_state()
	
	# Сбрасываем BetCollectionPhaseManager и кнопки collect/pay
	if bet_collection_manager:
		bet_collection_manager.reset()
	if ui and ui.button_ui:
		ui.button_ui.reset_collect_pay_buttons()
	
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
		has_pair_bets = pair_betting_manager.pair_player_bet_enabled or \
						pair_betting_manager.pair_banker_bet_enabled

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
			pair_betting_manager.player_pair_detected,
			pair_betting_manager.banker_pair_detected
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

	# Проверяем есть ли сохраненное состояние
	if TableStateManager.has_saved_state() and TableStateManager.bets.size() > 0:
		# Восстанавливаем ВСЕ фишки из предыдущей раздачи (включая проигрышные)
		DebugLogger.log_restore(" Восстановление фишек для новой раздачи из TableStateManager...")
		for bet in TableStateManager.bets:
			if bet.chip_texture.is_empty():
				chip_visual_manager.make_chip_visible(bet.bet_type)
			else:
				chip_visual_manager.set_chip_texture(bet.bet_type, bet.chip_texture)
			DebugLogger.log("  → Восстановлена фишка %s" % bet.bet_type)
	else:
		# Fallback: показываем на основе toggles (первая игра или нет сохраненного состояния)
		DebugLogger.log_warning(" Нет сохраненного состояния, показываем фишки на основе toggles")
		if PayoutSettingsManager.player_payout_enabled:
			chip_visual_manager.make_chip_visible("Player")
		if PayoutSettingsManager.banker_payout_enabled:
			chip_visual_manager.make_chip_visible("Banker")
		if PayoutSettingsManager.tie_payout_enabled:
			chip_visual_manager.make_chip_visible("Tie")
		if pair_betting_manager:
			if pair_betting_manager.pair_player_bet_enabled:
				chip_visual_manager.make_chip_visible("PairPlayer")
			if pair_betting_manager.pair_banker_bet_enabled:
				chip_visual_manager.make_chip_visible("PairBanker")

	DebugLogger.log_payout("Показаны фишки всех активных ставок")

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
	1. Показ сообщения о завершении (зависит от результата ставок)
	2. Зум камеры на общий план
	3. Начисление очков
	4. Сброс раунда
	5. Восстановление фишек
	6. Установка флага подготовки
	"""

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

	# Восстанавливаем видимость активных фишек
	if chip_visual_manager:
		_restore_active_bet_chips()
		DebugLogger.log("  → ✅ Активные фишки восстановлены")

	# Устанавливаем флаг подготовки к новой игре
	is_table_prepared = true
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
