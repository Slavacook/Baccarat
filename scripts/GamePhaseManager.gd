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

func reset():
	player_hand.clear()
	banker_hand.clear()
	player_third_selected = false
	banker_third_selected = false
	ui.reset_ui()
	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.enable_action_button()
	_update_game_state_manager()

func deal_first_four():
	# Проверяем, есть ли активные ставки
	if not PayoutSettingsManager.has_any_active_bet():
		EventBus.show_toast_info.emit(Localization.t("DAMIKU"))

	# Зум на карты при раздаче
	if game_controller:
		game_controller.camera_zoom_in()

	player_hand = [deck.draw(), deck.draw()]
	banker_hand = [deck.draw(), deck.draw()]
	player_third_selected = false
	banker_third_selected = false
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.show_first_four_cards(player_hand, banker_hand)
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
	# ui.disable_action_button()  # ← УБРАТЬ эту строку!
	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))



func _should_banker_draw() -> bool:
	return BaccaratRules.banker_should_draw(
		[banker_hand[0], banker_hand[1]],
		player_hand.size() >= 3,
		player_hand[2] if player_hand.size() >= 3 else null
	)

func on_action_pressed():
	var state = GameStateManager.get_current_state()
	
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
		# Если галочки не стоят — просто напоминаем выбрать победителя
		EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))
		return
	
	_validate_and_execute_third_cards()


func on_player_third_toggled(selected: bool):
	player_third_selected = !player_third_selected
	if player_third_selected:
		ui.update_player_third_card_ui("!")
	else:
		ui.update_player_third_card_ui("?")

func on_banker_third_toggled(selected: bool):
	banker_third_selected = !banker_third_selected
	if banker_third_selected:
		ui.update_banker_third_card_ui("!")
	else:
		ui.update_banker_third_card_ui("?")


# ========================================
# ВАЛИДАЦИЯ ДЕЙСТВИЙ (перенесено из CardsDealtState)
# ========================================

func _validate_and_execute_third_cards():
	var ps = BaccaratRules.hand_value([player_hand[0], player_hand[1]])
	var bs = BaccaratRules.hand_value([banker_hand[0], banker_hand[1]])

	if BaccaratRules.has_natural_or_no_third(ps, bs):
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
		return

	var player_draw = ps <= 5
	var banker_draw_always = bs <= 2

	# В обработке ошибки "карта каждому":
	if banker_draw_always and player_draw:
		if not player_third_selected or not banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("BOTH_CARDS_NEEDED"))
			EventBus.action_error.emit("both_wrong", Localization.t("BOTH_CARDS_NEEDED"))
			on_error_occurred()
			# Оба тумблера должны остаться доступны для выбора!
			ui.update_player_third_card_ui("?")
			ui.update_banker_third_card_ui("?")
			return
		draw_player_third()
		draw_banker_third()
		complete_game()
		return


	if player_draw and bs == 7:
		if not player_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_PLAYER_MUST_DRAW", [ps]))
			EventBus.action_error.emit("player_wrong", "")
			on_error_occurred()
			ui.update_player_third_card_ui("?")
			player_third_selected = true
			return
		if banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_NO_DRAW", [bs]))
			EventBus.action_error.emit("banker_wrong", "")
			on_error_occurred()
			ui.update_banker_third_card_ui("?")
			banker_third_selected = false
			return
		draw_player_third()
		complete_game()
		return

	if player_draw and bs >= 3 and bs <= 6:
		if not player_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_PLAYER_MUST_DRAW", [ps]))
			EventBus.action_error.emit("player_wrong", "")
			on_error_occurred()
			ui.update_player_third_card_ui("?")
			player_third_selected = true
			return
		if banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("BANKER_NO_CARD_YET"))
			EventBus.action_error.emit("banker_wrong", "")
			on_error_occurred()
			ui.update_banker_third_card_ui("?")
			banker_third_selected = false
			return
		draw_player_third()
		_handle_banker_after_player()
		return

	var banker_draw = _should_banker_draw()
	if not player_draw and banker_draw:
		if not banker_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_BANKER_MUST_DRAW", [bs]))
			EventBus.action_error.emit("banker_wrong", "")
			on_error_occurred()
			ui.update_banker_third_card_ui("?")
			banker_third_selected = true
			return
		if player_third_selected:
			EventBus.show_toast_error.emit(Localization.t("ERR_PLAYER_NO_DRAW", [ps]))
			EventBus.action_error.emit("player_wrong", "")
			on_error_occurred()
			ui.update_player_third_card_ui("?")
			player_third_selected = false
			return
		draw_banker_third()
		complete_game()
		return

	complete_game()

func _handle_banker_after_player():
	var banker_draw = _should_banker_draw()
	if banker_draw:
		EventBus.show_toast_info.emit(Localization.t("INFO_BANKER_DECISION"))
	else:
		EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))
		complete_game()

func _validate_banker_after_player():
	var bs = BaccaratRules.hand_value([banker_hand[0], banker_hand[1]])
	var banker_draw = _should_banker_draw()
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
