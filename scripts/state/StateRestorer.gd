# res://scripts/state/StateRestorer.gd
# Восстановитель состояния игры (SRP - единственная ответственность: восстановление состояния)

class_name StateRestorer
extends RefCounted

var hand_manager: HandManager
var winner_selection_manager: WinnerSelectionManager
var survival_ui: Control
var camera_manager: CameraManager
var ui_manager: UIManager
var card_manager: CardTextureManager

func _init(
	hand_mgr: HandManager,
	winner_mgr: WinnerSelectionManager,
	survival: Control,
	camera_mgr: CameraManager,
	ui_mgr: UIManager,
	card_mgr: CardTextureManager
):
	hand_manager = hand_mgr
	winner_selection_manager = winner_mgr
	survival_ui = survival
	camera_manager = camera_mgr
	ui_manager = ui_mgr
	card_manager = card_mgr

## Восстановить состояние стола (карты, UI, GameStateManager)
func restore_table_state() -> void:
	"""Восстановление карт, UI карт и GameStateManager"""
	# 1. Восстанавливаем карты через HandManager
	hand_manager.restore_from_arrays(
		TableStateManager.player_hand,
		TableStateManager.banker_hand
	)
	DebugLogger.log("♻️  Восстановлены карты: Player=%d, Banker=%d" % [
		hand_manager.get_player_size(),
		hand_manager.get_banker_size()
	])

	# 2. Показываем карты на UI
	restore_cards_ui()

	# 3. Обновляем GameStateManager с восстановленными картами
	var player_third_card = hand_manager.get_player_third_card()
	var banker_third_card = hand_manager.get_banker_third_card()
	GameStateManager.determine_and_update_state(
		false,  # cards_hidden = false (карты открыты)
		hand_manager.get_player_hand_ref(),
		hand_manager.get_banker_hand_ref(),
		player_third_card,
		banker_third_card
	)
	DebugLogger.log("♻️  GameStateManager обновлен: состояние = %s" % GameStateManager.get_current_state())

## Восстановить карты на UI
func restore_cards_ui() -> void:
	"""Восстановить карты на UI после возврата из PayoutScene"""
	# Показываем первые две карты игрока
	if hand_manager.get_player_hand_ref().size() >= 1:
		ui_manager.player_card1.texture = hand_manager.get_player_hand_ref()[0].get_texture(card_manager)
		ui_manager.player_card1.visible = true
	if hand_manager.get_player_hand_ref().size() >= 2:
		ui_manager.player_card2.texture = hand_manager.get_player_hand_ref()[1].get_texture(card_manager)
		ui_manager.player_card2.visible = true
	if hand_manager.get_player_hand_ref().size() >= 3:
		ui_manager.player_card3.texture = hand_manager.get_player_hand_ref()[2].get_texture(card_manager)
		ui_manager.player_card3.visible = true

	# Показываем первые две карты банкира
	if hand_manager.get_banker_hand_ref().size() >= 1:
		ui_manager.banker_card1.texture = hand_manager.get_banker_hand_ref()[0].get_texture(card_manager)
		ui_manager.banker_card1.visible = true
	if hand_manager.get_banker_hand_ref().size() >= 2:
		ui_manager.banker_card2.texture = hand_manager.get_banker_hand_ref()[1].get_texture(card_manager)
		ui_manager.banker_card2.visible = true
	if hand_manager.get_banker_hand_ref().size() >= 3:
		ui_manager.banker_card3.texture = hand_manager.get_banker_hand_ref()[2].get_texture(card_manager)
		ui_manager.banker_card3.visible = true

	# Скрываем toggles третьих карт (карты уже открыты)
	ui_manager.player_third_toggle.visible = false
	ui_manager.banker_third_toggle.visible = false

	DebugLogger.log_restore(" Карты восстановлены на UI")

## Восстановить survival режим и очередь выплат
func restore_survival_and_queue(
	_payout_queue_manager: PayoutQueueManager,
	survival_rounds_completed: int
) -> PayoutQueueManager:
	"""Восстановление маркера победителя, survival режима и очереди выплат
	
	Returns:
		Восстановленный PayoutQueueManager
	"""
	# 1. Восстанавливаем маркер победителя
	var saved_winner = TableStateManager.selected_winner
	if saved_winner != "" and winner_selection_manager:
		winner_selection_manager.select_winner(saved_winner)
		DebugLogger.log("🎯 Восстановлен маркер: %s" % saved_winner)
	
	# 2. Восстанавливаем survival режим
	if survival_ui:
		survival_ui.is_active = TableStateManager.survival_active
		survival_ui.set_lives(GameDataManager.get_survival_lives())
		DebugLogger.log("♻️  Survival режим восстановлен: жизней=%d, раундов=%d" % [
			GameDataManager.get_survival_lives(), survival_rounds_completed
		])
	
	# 3. Восстанавливаем PayoutQueueManager из TableStateManager
	var restored_queue = PayoutQueueManager.new()
	for bet_state in TableStateManager.bets:
		restored_queue.add_bet(
			bet_state.get_bet_type(),
			bet_state.get_stake(),
			bet_state.get_payout(),
			bet_state.is_won(),
			bet_state.get_player_score(),
			bet_state.get_banker_score()
		)
		# Восстанавливаем статус оплаты
		if bet_state.is_paid():
			restored_queue.mark_as_paid(bet_state.get_bet_type())
	
	DebugLogger.log("♻️  Восстановлен PayoutQueueManager: %d ставок" % TableStateManager.bets.size())
	
	return restored_queue

## Восстановить камеру
func restore_camera() -> void:
	"""Восстановление камеры на общий план (через публичный API)"""
	if camera_manager:
		# Используем публичный метод вместо прямого доступа
		camera_manager.restore_to_general()
		DebugLogger.log("📷 Камера восстановлена: общий план")
	
	# Показываем кнопки областей для выбора следующей области
	EventBus.area_buttons_visibility_changed.emit(true)
