# res://scripts/GamePhaseManager.gd

@tool
class_name GamePhaseManager
extends RefCounted

var game_controller = null

var player_hand: Array[Card] = []
var banker_hand: Array[Card] = []
var player_third_selected: bool = false
var banker_third_selected: bool = false

var deck: Deck
var card_manager: CardTextureManager
var ui: UIManager

func _init(deck_ref: Deck, card_manager_ref: CardTextureManager, ui_ref: UIManager):
	deck = deck_ref
	card_manager = card_manager_ref
	ui = ui_ref
	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))

func set_game_controller(controller) -> void:
	game_controller = controller

func on_error_occurred() -> void:
	if game_controller and game_controller.is_survival_mode:
		game_controller.survival_ui.lose_life()

func reset(update_state: bool = true):
	"""Сброс раунда

	Args:
		update_state: Обновлять ли GameStateManager (false при подготовке к новой игре)
	"""
	player_hand.clear()
	banker_hand.clear()
	player_third_selected = false
	banker_third_selected = false
	ui.reset_ui()
	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.enable_action_button()

	# ← ВАЖНО: Инвалидируем кэш GameStateManager даже при update_state=false
	# чтобы при следующей раздаче состояние определялось правильно
	GameStateManager._cache_hash = -1
	print("🔄 Кэш GameStateManager инвалидирован")

	if update_state:
		_update_game_state_manager()

	# ← Очищаем PayoutQueueManager и фишки для нового раунда
	if game_controller:
		game_controller.payout_queue_manager = null
		if game_controller.chip_visual_manager:
			game_controller.chip_visual_manager.hide_all_chips()
		if game_controller.winner_selection_manager:
			game_controller.winner_selection_manager.reset()
		# Очищаем TableStateManager (полное состояние стола)
		TableStateManager.clear_state()
		print("🔄 Сброс раунда: очищены выплаты, фишки, маркеры и TableStateManager")

func deal_first_four():
	print("🎮 deal_first_four() вызван")

	# Проверяем, есть ли активные ставки (включая пары)
	var has_main_bets = PayoutSettingsManager.has_any_active_bet()
	var has_pair_bets = false
	if game_controller and game_controller.pair_betting_manager:
		has_pair_bets = game_controller.pair_betting_manager.pair_player_bet_enabled or \
						 game_controller.pair_betting_manager.pair_banker_bet_enabled

	if not has_main_bets and not has_pair_bets:
		EventBus.show_toast_info.emit(Localization.t("DAMIKU"))

	# Проверяем флаг подготовки к новой игре (после оплаты всех фишек)
	var is_prepared_table = game_controller and game_controller.is_table_prepared_for_new_game
	print("  → is_prepared_table: %s" % is_prepared_table)
	print("  → is_first_deal: %s" % (game_controller.is_first_deal if game_controller else "N/A"))

	# Зум на карты при первой раздаче ИЛИ после подготовки стола
	if game_controller and (game_controller.is_first_deal or is_prepared_table):
		print("  → Условие зума выполнено → вызываем camera_zoom_in()")
		game_controller.camera_zoom_in()
		game_controller.is_first_deal = false
		# Сбрасываем флаг подготовки (начинаем новую игру)
		if is_prepared_table:
			game_controller.is_table_prepared_for_new_game = false
			print("  → ✅ Флаг is_table_prepared_for_new_game сброшен")
			print("🎮 Начинаем новую раздачу после подготовки стола")
	else:
		print("  → ⚠️ Условие зума НЕ выполнено, зум не произойдет")

	player_hand = [deck.draw(), deck.draw()]
	banker_hand = [deck.draw(), deck.draw()]
	player_third_selected = false
	banker_third_selected = false
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.show_first_four_cards(player_hand, banker_hand)

	# ← Проверяем пары МОЛЧА (без оповещений)
	if game_controller and game_controller.pair_betting_manager:
		game_controller.pair_betting_manager.check_pairs(
			player_hand[0], player_hand[1],
			banker_hand[0], banker_hand[1]
		)
		print("🃏 Проверка пар: Player=%s, Banker=%s" % [
			game_controller.pair_betting_manager.player_pair_detected,
			game_controller.pair_betting_manager.banker_pair_detected
		])

	# Фишки уже показаны при настройке ставок, не обновляем их здесь

	_update_game_state_manager()

func draw_player_third():
	player_hand.append(deck.draw())
	ui.update_player_third_card_ui("card", player_hand[2])  # Скрываем ДО анимации!
	ui.show_player_third_card(player_hand[2])
	player_third_selected = false
	_update_game_state_manager()

func draw_banker_third():
	banker_hand.append(deck.draw())
	ui.update_banker_third_card_ui("card", banker_hand[2])  # Скрываем ДО анимации!
	ui.show_banker_third_card(banker_hand[2])
	banker_third_selected = false
	_update_game_state_manager()


func complete_game():
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))



func _should_banker_draw() -> bool:
	return BaccaratRules.banker_should_draw(
		[banker_hand[0], banker_hand[1]],
		player_hand.size() >= 3,
		player_hand[2] if player_hand.size() >= 3 else null
	)

func on_action_pressed():
	print("==================================================")
	print("🎮 on_action_pressed() вызван")

	# Детальная проверка game_controller
	print("  → game_controller существует: %s" % (game_controller != null))
	if game_controller:
		print("  → game_controller.is_table_prepared_for_new_game = %s" % game_controller.is_table_prepared_for_new_game)

	# Проверяем флаг подготовки
	var flag_is_set = game_controller and game_controller.is_table_prepared_for_new_game
	print("  → Результат проверки флага: %s" % flag_is_set)

	# ← ВАЖНО: Проверяем флаг подготовки ДО определения состояния
	# (после reset(false) руки пустые, и состояние определится как WAITING)
	if flag_is_set:
		print("==================================================")
		print("  → ✅ ФЛАГ УСТАНОВЛЕН → вызываем deal_first_four()")
		print("==================================================")
		deal_first_four()
		return
	else:
		print("  → Флаг НЕ установлен, продолжаем обычную логику")

	var state = GameStateManager.get_current_state()
	print("  → Текущее состояние: %s" % state)

	if state == GameStateManager.GameState.WAITING:
		deal_first_four()
		return
	
	if state == GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER:
		_validate_banker_after_player()
		return
	
	# ← НОВОЕ: Обработка состояния финала (состояние №6)
	if state == GameStateManager.GameState.CHOOSE_WINNER:
		# Проверяем, пытается ли игрок заказать карты в финале
		if player_third_selected or banker_third_selected:
			EventBus.show_toast_error.emit("Игра закончена! Нельзя заказывать карты. Выберите победителя.")
			EventBus.action_error.emit("final_card_error", "")
			on_error_occurred()
			# Сбрасываем галочки
			player_third_selected = false
			banker_third_selected = false
			ui.update_player_third_card_ui("?")
			ui.update_banker_third_card_ui("?")
			return

		# Проверяем, есть ли неоплаченные выплаты (ручной режим)
		if game_controller and game_controller.payout_queue_manager:
			var queue_mgr = game_controller.payout_queue_manager
			if queue_mgr.has_unpaid_winnings():
				var unpaid_count = queue_mgr.get_unpaid_count()
				EventBus.show_toast_error.emit(Localization.t("ERR_UNPAID_BETS", [unpaid_count]))
				EventBus.action_error.emit("unpaid_bets", "")
				on_error_occurred()
				return

			# Все выплаты оплачены → подготовка к новой игре
			print("==================================================")
			print("✅ ВСЕ ВЫПЛАТЫ ОПЛАЧЕНЫ → ПОДГОТОВКА К НОВОЙ ИГРЕ")
			print("==================================================")
			print("  → Выполняем camera_zoom_out()")

			# Зумаут камеры на общий план
			if game_controller and game_controller.camera:
				game_controller.camera_zoom_out()
				print("  → ✅ Камера отзумлена на общий план")
			else:
				print("  → ⚠️ camera отсутствует, зум не выполнен")

			print("  → Вызываем reset(false) - сброс БЕЗ обновления состояния")
			# Сброс раунда (карты, маркеры, TableStateManager)
			reset(false)  # ← НЕ обновляем GameStateManager
			print("  → ✅ Сброс выполнен, карты показаны рубашками")

			# Восстанавливаем видимость активных фишек для следующей игры
			if game_controller and game_controller.chip_visual_manager:
				_restore_active_bet_chips()
				print("  → ✅ Активные фишки восстановлены")

			print("  → Устанавливаем флаг is_table_prepared_for_new_game = true")
			# Устанавливаем флаг подготовки к новой игре
			if game_controller:
				game_controller.is_table_prepared_for_new_game = true
				print("  → ✅ Флаг is_table_prepared_for_new_game установлен!")
				print("  → Следующее нажатие 'Карты' начнет новую раздачу")
			else:
				print("  → ⚠️ game_controller отсутствует, флаг не установлен!")

			print("==================================================")
			print("✅ ПОДГОТОВКА ЗАВЕРШЕНА. Нажмите 'Карты' для новой раздачи")
			print("==================================================")
			return
		# Если нет PayoutQueueManager → проверяем выбор победителя (первый выбор)
		_validate_winner_selection()
		return

	_validate_and_execute_third_cards()


func on_player_third_toggled(_selected: bool):
	player_third_selected = !player_third_selected
	if player_third_selected:
		ui.update_player_third_card_ui("!")
	else:
		ui.update_player_third_card_ui("?")

func on_banker_third_toggled(_selected: bool):
	banker_third_selected = !banker_third_selected
	if banker_third_selected:
		ui.update_banker_third_card_ui("!")
	else:
		ui.update_banker_third_card_ui("?")


# ========================================
# ВАЛИДАЦИЯ ДЕЙСТВИЙ (перенесено из CardsDealtState)
# ========================================

func _validate_and_execute_third_cards() -> void:
	var ps: int = BaccaratRules.hand_value([player_hand[0], player_hand[1]])
	var bs: int = BaccaratRules.hand_value([banker_hand[0], banker_hand[1]])

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
	complete_game()

# ========================================
# ОБРАБОТЧИКИ ДЛЯ КАЖДОГО СЦЕНАРИЯ
# ========================================

# Натуральная 8-9 или особые комбинации (6v6, 7v7, 6v7, 7v6)
func _handle_natural_case() -> void:
	if player_third_selected or banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_NATURAL_NO_DRAW"))
		EventBus.action_error.emit("natural_draw", Localization.t("ERR_NATURAL_NO_DRAW"))
		on_error_occurred()
		player_third_selected = false
		banker_third_selected = false
		ui.update_player_third_card_ui("?")
		ui.update_banker_third_card_ui("?")
		return

	EventBus.show_toast_info.emit(Localization.t("INFO_NATURAL_CHOOSE_WINNER"))
	complete_game()

# State 2: Карта каждому (банкир 0-2, игрок 0-5)
func _handle_card_to_each() -> void:
	if not player_third_selected or not banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("BOTH_CARDS_NEEDED"))
		EventBus.action_error.emit("both_wrong", Localization.t("BOTH_CARDS_NEEDED"))
		on_error_occurred()
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
		on_error_occurred()
		ui.update_player_third_card_ui("?")
		player_third_selected = true
		return

	# Проверка: банкир НЕ должен брать карту
	if banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_NO_DRAW", [bs]))
		EventBus.action_error.emit("banker_wrong", "")
		on_error_occurred()
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
		on_error_occurred()
		ui.update_player_third_card_ui("?")
		player_third_selected = true
		return

	# Проверка: банкир пока НЕ должен брать (решение потом)
	if banker_third_selected:
		EventBus.show_toast_error.emit(Localization.t("BANKER_NO_CARD_YET"))
		EventBus.action_error.emit("banker_wrong", "")
		on_error_occurred()
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
		on_error_occurred()
		ui.update_banker_third_card_ui("?")
		banker_third_selected = true
		return

	# Проверка: игрок НЕ должен брать карту
	if player_third_selected:
		EventBus.show_toast_error.emit(Localization.t("ERR_PLAYER_NO_DRAW", [ps]))
		EventBus.action_error.emit("player_wrong", "")
		on_error_occurred()
		ui.update_player_third_card_ui("?")
		player_third_selected = false
		return

	draw_banker_third()
	complete_game()

func _handle_banker_after_player():
	var banker_draw: bool = _should_banker_draw()
	if banker_draw:
		EventBus.show_toast_info.emit(Localization.t("INFO_BANKER_DECISION"))
	else:
		EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))
		complete_game()

func _validate_banker_after_player():
	var bs: int = BaccaratRules.hand_value([banker_hand[0], banker_hand[1]])
	var banker_draw: bool = _should_banker_draw()
	if banker_draw:
		if not banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_MUST_DRAW", [bs]))
			EventBus.action_error.emit("banker_wrong", "")
			on_error_occurred()
			ui.update_banker_third_card_ui("?")
			banker_third_selected = true
			return
		if player_third_selected:
			EventBus.show_toast_error.emit("Игроку уже дали карту!")
			EventBus.action_error.emit("player_wrong", "")
			on_error_occurred()
			ui.update_player_third_card_ui("?")
			player_third_selected = false
			return
		draw_banker_third()
		complete_game()
	else:
		if banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_NO_DRAW", [bs]))
			EventBus.action_error.emit("banker_wrong", "")
			on_error_occurred()
			ui.update_banker_third_card_ui("?")
			banker_third_selected = false
			return
		complete_game()

func _restore_active_bet_chips() -> void:
	"""Восстановить ВСЕ фишки из TableStateManager для новой раздачи

	При подготовке к новой игре восстанавливаем ВСЕ фишки (включая проигрышные из предыдущей раздачи)
	с их оригинальными текстурами. Это показывает игроку какие ставки будут в следующей раздаче.
	"""
	if not game_controller or not game_controller.chip_visual_manager:
		return

	var chip_mgr = game_controller.chip_visual_manager

	# Проверяем есть ли сохраненное состояние
	if TableStateManager.has_saved_state() and TableStateManager.bets.size() > 0:
		# Восстанавливаем ВСЕ фишки из предыдущей раздачи (включая проигрышные)
		print("♻️  Восстановление фишек для новой раздачи из TableStateManager...")
		for bet in TableStateManager.bets:
			if bet.chip_texture.is_empty():
				chip_mgr.make_chip_visible(bet.bet_type)
			else:
				chip_mgr.set_chip_texture(bet.bet_type, bet.chip_texture)
			print("  → Восстановлена фишка %s" % bet.bet_type)
	else:
		# Fallback: показываем на основе toggles (первая игра или нет сохраненного состояния)
		print("⚠️  Нет сохраненного состояния, показываем фишки на основе toggles")
		if PayoutSettingsManager.player_payout_enabled:
			chip_mgr.make_chip_visible("Player")
		if PayoutSettingsManager.banker_payout_enabled:
			chip_mgr.make_chip_visible("Banker")
		if PayoutSettingsManager.tie_payout_enabled:
			chip_mgr.make_chip_visible("Tie")
		if game_controller.pair_betting_manager:
			if game_controller.pair_betting_manager.pair_player_bet_enabled:
				chip_mgr.make_chip_visible("PairPlayer")
			if game_controller.pair_betting_manager.pair_banker_bet_enabled:
				chip_mgr.make_chip_visible("PairBanker")

	print("💰 Показаны фишки всех активных ставок")


func _show_active_bet_chips() -> void:
	"""Показать фишки всех активных ставок при раздаче"""
	if not game_controller or not game_controller.chip_visual_manager:
		return

	var chip_mgr = game_controller.chip_visual_manager

	# Основные ставки
	if PayoutSettingsManager.player_payout_enabled:
		chip_mgr.show_chip("Player")
		chip_mgr.make_chip_clickable("Player", false)  # Пока некликабельны

	if PayoutSettingsManager.banker_payout_enabled:
		chip_mgr.show_chip("Banker")
		chip_mgr.make_chip_clickable("Banker", false)

	if PayoutSettingsManager.tie_payout_enabled:
		chip_mgr.show_chip("Tie")
		chip_mgr.make_chip_clickable("Tie", false)

	# Ставки на пары
	if game_controller.pair_betting_manager:
		if game_controller.pair_betting_manager.pair_player_bet_enabled:
			chip_mgr.show_chip("PairPlayer")
			chip_mgr.make_chip_clickable("PairPlayer", false)

		if game_controller.pair_betting_manager.pair_banker_bet_enabled:
			chip_mgr.show_chip("PairBanker")
			chip_mgr.make_chip_clickable("PairBanker", false)

	print("💰 Показаны фишки всех активных ставок")


func _update_game_state_manager():
	var cards_hidden = player_hand.size() == 0 or banker_hand.size() == 0
	var player_third_card = player_hand[2] if player_hand.size() > 2 else null
	var banker_third_card = banker_hand[2] if banker_hand.size() > 2 else null
	GameStateManager.determine_and_update_state(
		cards_hidden,
		player_hand,
		banker_hand,
		player_third_card,
		banker_third_card
	)

# ========================================
# ВАЛИДАЦИЯ ВЫБОРА ПОБЕДИТЕЛЯ (новая логика)
# ========================================

func _validate_winner_selection() -> void:
	"""Проверка выбранного победителя через маркеры"""
	if not game_controller or not game_controller.winner_selection_manager:
		EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))
		return

	var winner_mgr = game_controller.winner_selection_manager
	var selected_winner = winner_mgr.get_selected_winner()

	# Не выбран ни один маркер?
	if selected_winner == "":
		EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))
		return

	# Проверяем правильность
	var actual_winner = BaccaratRules.get_winner(player_hand, banker_hand)

	if selected_winner != actual_winner:
		# ❌ Неправильный выбор
		EventBus.show_toast_error.emit(Localization.t("ERR_WRONG_WINNER", [actual_winner]))
		EventBus.action_error.emit("winner_wrong", "")
		on_error_occurred()
		# Сбрасываем выбор маркера
		winner_mgr.reset()
		return

	# ✅ Правильный выбор!
	EventBus.action_correct.emit("winner")

	# Показываем toast с результатом (кто выиграл и с какими картами)
	var victory_msg = _format_victory_toast(actual_winner)
	EventBus.show_toast_success.emit(victory_msg)

	# Зум камеры на фишки после валидации победителя
	if game_controller:
		game_controller.camera_zoom_chips()

	# Вызываем метод формирования очереди выплат в GameController
	if game_controller:
		game_controller._prepare_payouts_manual(actual_winner)

func _format_victory_toast(winner: String) -> String:
	"""Форматирование сообщения победы"""
	var player_score = BaccaratRules.hand_value(player_hand)
	var banker_score = BaccaratRules.hand_value(banker_hand)

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

	return "Выиграл %s: [color=red]%d[/color] vs [color=red]%d[/color]" % [winner_text, winner_score, loser_score]
