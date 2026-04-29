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

## Карточный дилер (раздача карт)
var card_dealer: CardDealer = null

## Валидатор действий третьих карт
var third_card_validator: ThirdCardActionValidator = null

## Валидатор выбора победителя
var winner_validator: WinnerSelectionValidator = null

## Резолвер действий по фазам
var phase_resolver: PhaseActionResolver = null

## Координатор завершения раунда
var round_completion_coordinator: RoundCompletionCoordinator = null

## Проверщик триггеров карт шанса
var chance_card_trigger_checker: ChanceCardTriggerChecker = null

## Менеджер фильтров ставок
var bet_filter_manager: BetFilterManager = null

## Координатор отображения ставок гостей
var guest_bet_display_coordinator: GuestBetDisplayCoordinator = null

## Форматтер сообщений победы
var victory_message_formatter: VictoryMessageFormatter = null

## Координатор сброса состояния игры
var game_state_reset_coordinator: GameStateResetCoordinator = null

## Форматтер ошибок валидации
var validation_error_formatter: ValidationErrorFormatter = null

## Координатор восстановления фишек
var chip_restoration_coordinator: ChipRestorationCoordinator = null

## Обработчик событий UI для третьих карт
var third_card_ui_handler: ThirdCardUIHandler = null

## Исполнитель действий для третьих карт
var third_card_action_executor: ThirdCardActionExecutor = null

## Исполнитель действий для выбора победителя
var winner_action_executor: WinnerActionExecutor = null

## Обновлятор состояния игры
var game_state_updater: GameStateUpdater = null

## Координатор валидации выбора победителя
var winner_selection_coordinator: WinnerSelectionCoordinator = null

## Исполнитель подготовки стола
var table_preparation_executor: TablePreparationExecutor = null

## Обработчик состояния выбора победителя
var winner_selection_state_handler: WinnerSelectionStateHandler = null

## Обработчик кнопки Tie
var tie_button_handler: TieButtonHandler = null

## Координатор Heart Bet
var heart_bet_coordinator: HeartBetCoordinator = null

## Координатор раздачи первых четырех карт
var first_four_deal_coordinator: FirstFourDealCoordinator = null

## Координатор раздачи третьих карт
var third_card_drawing_coordinator: ThirdCardDrawingCoordinator = null

## Координатор удаления третьих карт
var third_card_removal_coordinator: ThirdCardRemovalCoordinator = null

## Обработчик решения банкира после игрока
var banker_after_player_handler: BankerAfterPlayerHandler = null

## Координатор завершения игры
var game_completion_coordinator: GameCompletionCoordinator = null

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

# DEPRECATED: Используйте bet_filter_manager.filter_snapshot и bet_filter_manager.pending_filter_changes
# Оставлено для обратной совместимости
@warning_ignore("unused_private_class_variable")
var _filter_snapshot: Dictionary:
	get:
		return bet_filter_manager.filter_snapshot if bet_filter_manager else {}
	set(value):
		if bet_filter_manager:
			bet_filter_manager.filter_snapshot = value

@warning_ignore("unused_private_class_variable")
var _pending_filter_changes: Dictionary:
	get:
		return bet_filter_manager.pending_filter_changes if bet_filter_manager else {}
	set(value):
		if bet_filter_manager:
			bet_filter_manager.pending_filter_changes = value

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
	
	# Инициализируем карточного дилера
	card_dealer = CardDealer.new()
	DebugLogger.log("🎴 CardDealer инициализирован в GamePhaseManager")
	
	# Инициализируем валидатор действий третьих карт
	third_card_validator = ThirdCardActionValidator.new()
	DebugLogger.log("✅ ThirdCardActionValidator инициализирован в GamePhaseManager")
	
	# Инициализируем валидатор выбора победителя
	winner_validator = WinnerSelectionValidator.new()
	DebugLogger.log("✅ WinnerSelectionValidator инициализирован в GamePhaseManager")
	
	# Инициализируем резолвер действий по фазам
	phase_resolver = PhaseActionResolver.new()
	DebugLogger.log("✅ PhaseActionResolver инициализирован в GamePhaseManager")
	
	# Инициализируем координатор завершения раунда
	round_completion_coordinator = RoundCompletionCoordinator.new()
	DebugLogger.log("✅ RoundCompletionCoordinator инициализирован в GamePhaseManager")
	
	# Инициализируем проверщик триггеров карт шанса
	chance_card_trigger_checker = ChanceCardTriggerChecker.new()
	DebugLogger.log("✅ ChanceCardTriggerChecker инициализирован в GamePhaseManager")
	
	# Инициализируем менеджер фильтров ставок
	bet_filter_manager = BetFilterManager.new()
	DebugLogger.log("✅ BetFilterManager инициализирован в GamePhaseManager")
	
	# Инициализируем координатор отображения ставок гостей
	guest_bet_display_coordinator = GuestBetDisplayCoordinator.new()
	DebugLogger.log("✅ GuestBetDisplayCoordinator инициализирован в GamePhaseManager")
	
	# Инициализируем форматтер сообщений победы
	victory_message_formatter = VictoryMessageFormatter.new()
	DebugLogger.log("✅ VictoryMessageFormatter инициализирован в GamePhaseManager")
	
	# Инициализируем координатор сброса состояния игры
	game_state_reset_coordinator = GameStateResetCoordinator.new()
	DebugLogger.log("✅ GameStateResetCoordinator инициализирован в GamePhaseManager")
	
	# Инициализируем форматтер ошибок валидации
	validation_error_formatter = ValidationErrorFormatter.new()
	DebugLogger.log("✅ ValidationErrorFormatter инициализирован в GamePhaseManager")
	
	# Инициализируем обработчик событий UI для третьих карт
	third_card_ui_handler = ThirdCardUIHandler.new()
	DebugLogger.log("✅ ThirdCardUIHandler инициализирован в GamePhaseManager")
	
	# Инициализируем исполнитель действий для третьих карт
	third_card_action_executor = ThirdCardActionExecutor.new()
	DebugLogger.log("✅ ThirdCardActionExecutor инициализирован в GamePhaseManager")
	
	# Инициализируем исполнитель действий для выбора победителя
	winner_action_executor = WinnerActionExecutor.new()
	DebugLogger.log("✅ WinnerActionExecutor инициализирован в GamePhaseManager")
	
	# Инициализируем обновлятор состояния игры
	game_state_updater = GameStateUpdater.new()
	DebugLogger.log("✅ GameStateUpdater инициализирован в GamePhaseManager")
	
	# Инициализируем координатор валидации выбора победителя
	winner_selection_coordinator = WinnerSelectionCoordinator.new(winner_validator)
	DebugLogger.log("✅ WinnerSelectionCoordinator инициализирован в GamePhaseManager")
	
	# Инициализируем исполнитель подготовки стола
	table_preparation_executor = TablePreparationExecutor.new(
		round_completion_coordinator,
		payout_queue_manager,
		bet_filter_manager,
		guest_bet_factory,
		chip_restoration_coordinator
	)
	DebugLogger.log("✅ TablePreparationExecutor инициализирован в GamePhaseManager")
	
	# Инициализируем обработчик состояния выбора победителя
	winner_selection_state_handler = WinnerSelectionStateHandler.new(hand_manager)
	DebugLogger.log("✅ WinnerSelectionStateHandler инициализирован в GamePhaseManager")
	
	# Инициализируем обработчик кнопки Tie
	tie_button_handler = TieButtonHandler.new(hand_manager, chance_card_trigger_checker)
	DebugLogger.log("✅ TieButtonHandler инициализирован в GamePhaseManager")
	
	# Инициализируем координатор Heart Bet
	heart_bet_coordinator = HeartBetCoordinator.new(heart_bet_manager, hand_manager)
	DebugLogger.log("✅ HeartBetCoordinator инициализирован в GamePhaseManager")
	
	# Инициализируем координатор раздачи первых четырех карт
	first_four_deal_coordinator = FirstFourDealCoordinator.new(pair_betting_manager, chance_card_trigger_checker)
	DebugLogger.log("✅ FirstFourDealCoordinator инициализирован в GamePhaseManager")
	
	# Инициализируем координатор раздачи третьих карт
	third_card_drawing_coordinator = ThirdCardDrawingCoordinator.new(card_dealer, hand_manager)
	DebugLogger.log("✅ ThirdCardDrawingCoordinator инициализирован в GamePhaseManager")
	
	# Инициализируем координатор удаления третьих карт
	third_card_removal_coordinator = ThirdCardRemovalCoordinator.new(hand_manager)
	DebugLogger.log("✅ ThirdCardRemovalCoordinator инициализирован в GamePhaseManager")
	
	# Инициализируем обработчик решения банкира после игрока
	banker_after_player_handler = BankerAfterPlayerHandler.new(hand_manager, third_card_validator)
	DebugLogger.log("✅ BankerAfterPlayerHandler инициализирован в GamePhaseManager")
	
	# Инициализируем координатор завершения игры
	game_completion_coordinator = GameCompletionCoordinator.new()
	DebugLogger.log("✅ GameCompletionCoordinator инициализирован в GamePhaseManager")

	ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	ui.set_action_button_state("start")

func reset(update_state: bool = true, keep_guest_bets: bool = false):
	"""Сброс раунда

	Args:
		update_state: Обновлять ли GameStateManager (false при подготовке к новой игре)
		keep_guest_bets: Сохранять ли ставки гостей (true при Heart Bet)
	"""
	# Используем координатор для получения инструкций
	var instructions = game_state_reset_coordinator.get_reset_instructions(update_state, keep_guest_bets)
	
	# Сброс рук и флагов
	if instructions.get("should_reset_hands", false):
		hand_manager.reset()
		player_third_selected = false
		banker_third_selected = false
		was_heart_bet_round = false  # Сбрасываем флаг Heart Bet раунда
	
	# Сброс UI
	if instructions.get("should_reset_ui", false):
		# Сбрасываем список показанных карт шансов (для нового раунда)
		ChanceCardManager.reset_shown_cards()
		ui.reset_ui()
		ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
		ui.set_action_button_state("start")
		ui.update_player_third_card_ui("?")
		ui.update_banker_third_card_ui("?")
		ui.enable_action_button()
		# TieMarker всегда виден (не скрывается)

	# Инвалидация кэша
	if instructions.get("should_invalidate_cache", false):
		GameStateManager._cache_hash = -1
		DebugLogger.log("🔄 Кэш GameStateManager инвалидирован")

	# Обновление состояния
	if instructions.get("should_update_state", false):
		_update_game_state_manager()

	# Очистка фишек
	payout_queue_manager = null
	if instructions.get("should_clear_chips", false) and chip_visual_manager:
		chip_visual_manager.hide_all_chips()
		chip_visual_manager.clear_all_active_chips()  # Важно для REALISTIC режима!
	elif chip_visual_manager and not instructions.get("should_clear_chips", true):
		DebugLogger.log("❤️ Фишки гостей НЕ очищены (Heart Bet)")
	
	# Сброс менеджеров
	if instructions.get("should_reset_managers", false):
		if winner_selection_manager:
			winner_selection_manager.reset()
			winner_selection_manager.unlock_markers()
		# Очищаем TableStateManager (полное состояние стола)
		TableStateManager.clear_state()
		# Сбрасываем BetCollectionPhaseManager и кнопки collect/pay
		if bet_collection_manager:
			bet_collection_manager.reset()
		if ui and ui.button_ui:
			ui.button_ui.reset_collect_pay_buttons()

	# Очистка ставок гостей
	if instructions.get("should_clear_guest_bets", false) and guest_bet_storage:
		guest_bet_storage.clear_all_bets()
		DebugLogger.log("🗑️ Ставки гостей очищены после завершения раунда")
	elif guest_bet_storage and not instructions.get("should_clear_guest_bets", true):
		DebugLogger.log("❤️ Ставки гостей сохранены (Heart Bet)")

	# Скрытие UI элементов
	if instructions.get("should_hide_ui_elements", false):
		EventBus.area_buttons_visibility_changed.emit(false)
		EventBus.navigation_arrows_visibility_changed.emit(false)

	DebugLogger.log("🔄 Сброс раунда: очищены выплаты, фишки, маркеры, TableStateManager и режимы collect/pay")

# ═══════════════════════════════════════════════════════════════════════════
# РАЗДАЧА КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func deal_first_four() -> void:
	"""Раздать первые 4 карты (по 2 игроку и банкиру)
	
	Выполняет раздачу первых карт, проверяет ставки, обрабатывает Heart Bet,
	проверяет триггеры карт шанса (Third Card Change, Mystery Card),
	и обновляет состояние игры.
	
	Делегирует логику в FirstFourDealCoordinator и другие координаторы.
	"""
	DebugLogger.log_game_flow("deal_first_four() вызван")

	# Live-сессия: сид следующего раунда с сервера (пришёл по WS после submit предыдущего).
	if Engine.has_singleton("SessionManager"):
		var sm_live: Node = SessionManager
		if sm_live.current_mode == sm_live.Mode.ONLINE and sm_live.has_method("apply_pending_live_deck_seed_to"):
			sm_live.apply_pending_live_deck_seed_to(deck)

	EventBus.round_reset.emit()

	# Используем координатор для проверки ставок
	if not first_four_deal_coordinator:
		DebugLogger.log_error("❌ FirstFourDealCoordinator не инициализирован!")
		return
	
	# Проверяем, есть ли активные гости
	var active_guests = GuestSettingsManager.get_active_guests() if GuestSettingsManager else []
	var has_active_guests = not active_guests.is_empty()
	
	# Проверяем, есть ли ставки у гостей
	var has_guest_bets = false
	if guest_bet_storage:
		var guests_with_bets = guest_bet_storage.get_guests_with_bets()
		has_guest_bets = not guests_with_bets.is_empty()
	
	# Проверяем, есть ли вообще какие-то ставки (через координатор)
	var bets_info = first_four_deal_coordinator.has_any_bets()
	var has_any_bets = bets_info.get("has_any", true)
	
	# Показываем "Дамику!" если:
	# 1. Нет активных гостей (все ушли) ИЛИ
	# 2. Есть активные гости, но нет ставок (ни у гостей, ни общих)
	if not has_active_guests or (has_active_guests and not has_guest_bets and not has_any_bets):
		EventBus.show_toast_info.emit(Localization.t("DAMIKU_NO_BETS"))

	# Проверяем флаг подготовки к новой игре (после оплаты всех фишек)
	DebugLogger.log("  → is_prepared_table: %s" % is_table_prepared)
	DebugLogger.log("  → is_first_deal: %s" % is_first_deal)

	# Зум на карты при первой раздаче ИЛИ после подготовки стола
	if is_first_deal or is_table_prepared:
		DebugLogger.log("  → Условие зума выполнено → вызываем camera_zoom_requested")
		EventBus.camera_zoom_requested.emit("in", false)
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
	if has_pending_heart_bet():
		# Устанавливаем флаг Heart Bet раунда (даже если будет отказ)
		was_heart_bet_round = true
		var confirmed = confirm_heart_bet()
		if confirmed:
			DebugLogger.log("❤️ Heart Bet подтверждён, раздача со ставкой")
		else:
			DebugLogger.log("❤️ Heart Bet отклонён, обычная раздача")

	# Раздаём первые 4 карты через CardDealer
	card_dealer.deal_first_four(deck, hand_manager)
	player_third_selected = false
	banker_third_selected = false
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")
	ui.show_first_four_cards(hand_manager.get_player_hand_ref(), hand_manager.get_banker_hand_ref())
	ui.set_action_button_state("confirm")
	
	# Эмитим событие начала новой раздачи (для обновления счетчика раздач)
	EventBus.round_started.emit()

	# Проверяем пары через координатор
	var pairs_info = first_four_deal_coordinator.check_pairs(
		hand_manager.get_player_card(0),
		hand_manager.get_player_card(1),
		hand_manager.get_banker_card(0),
		hand_manager.get_banker_card(1)
	)
	DebugLogger.log("🃏 Проверка пар: Player=%s, Banker=%s" % [
		pairs_info.get("has_player_pair", false),
		pairs_info.get("has_banker_pair", false)
	])
	
	# Проверяем триггеры карт шанса через координатор (только если карты шансов включены)
	var triggers = {}
	if SaveManager.instance.load_chance_cards_enabled():
		var player_hand = hand_manager.get_player_hand_ref()
		var banker_hand = hand_manager.get_banker_hand_ref()
		var is_survival_mode = SaveManager.instance.load_survival_mode()
		triggers = first_four_deal_coordinator.get_triggers_after_deal(
			player_hand, banker_hand,
			pairs_info.get("has_player_pair", false),
			pairs_info.get("has_banker_pair", false),
			is_survival_mode
		)
	else:
		print("🎴 deal_first_four: карты шансов отключены, пропускаем проверку триггеров")
	
	# 🔄 ТРИГГЕР: Две пары → Third Card Change (с задержкой 1.5 сек)
	if triggers.get("third_card_change", false):
		print("🔄 Third Card Change: обнаружены две пары, карта через 1.5 сек...")
		# Задержка 1.5 секунды чтобы игрок успел увидеть пары
		EventBus.get_tree().create_timer(1.5).timeout.connect(func():
			EventBus.third_card_change_triggered.emit()
			print("🔄 Third Card Change триггер: две пары при раздаче!")
		)
	
	# ❓ ТРИГГЕР: Пара тузов → Mystery Card (с задержкой 1.5 сек)
	if triggers.get("mystery_card", false):
		print("❓ Mystery Card: обнаружена пара тузов, карта через 1.5 сек...")
		# Задержка 1.5 секунды чтобы игрок успел увидеть пару тузов
		EventBus.get_tree().create_timer(1.5).timeout.connect(func():
			EventBus.mystery_card_triggered.emit()
			print("❓ Mystery Card триггер: пара тузов при раздаче!")
		)

	# Фишки уже показаны при настройке ставок, не обновляем их здесь

	_update_game_state_manager()

func draw_player_third() -> void:
	"""Раздать третью карту игроку
	
	Делегирует раздачу в ThirdCardDrawingCoordinator.
	Обновляет UI и состояние игры после раздачи.
	"""
	# Используем координатор для раздачи третьей карты игроку
	if not third_card_drawing_coordinator:
		DebugLogger.log_error("❌ ThirdCardDrawingCoordinator не инициализирован!")
		return
	
	var result = third_card_drawing_coordinator.draw_player_third(deck)
	if not result.get("success", false):
		DebugLogger.log_error("❌ %s" % result.get("error", "Неизвестная ошибка"))
		return
	
	var card: Card = result.get("card", null)
	if not card:
		DebugLogger.log_error("❌ Карта не получена из координатора")
		return
	
	ui.update_player_third_card_ui("card", card)  # Скрываем ДО анимации!
	ui.show_player_third_card(card)
	player_third_selected = false
	_update_game_state_manager()
	
	# Эмит события успешного доборa третьей карты игроку
	EventBus.action_correct.emit("player_third")

func draw_banker_third() -> void:
	"""Раздать третью карту банкиру
	
	Делегирует раздачу в ThirdCardDrawingCoordinator.
	Обновляет UI и состояние игры после раздачи.
	"""
	# Используем координатор для раздачи третьей карты банкиру
	if not third_card_drawing_coordinator:
		DebugLogger.log_error("❌ ThirdCardDrawingCoordinator не инициализирован!")
		return
	
	var result = third_card_drawing_coordinator.draw_banker_third(deck)
	if not result.get("success", false):
		DebugLogger.log_error("❌ %s" % result.get("error", "Неизвестная ошибка"))
		return
	
	var card: Card = result.get("card", null)
	if not card:
		DebugLogger.log_error("❌ Карта не получена из координатора")
		return
	
	ui.update_banker_third_card_ui("card", card)  # Скрываем ДО анимации!
	ui.show_banker_third_card(card)
	banker_third_selected = false
	
	# Проверяем состояние до обновления, чтобы избежать проблем с изменением состояния
	var is_banker_after_player = GameStateManager.current_state == GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER
	_update_game_state_manager()
	
	# Эмит события успешного доборa третьей карты банкиру
	if is_banker_after_player:
		EventBus.action_correct.emit("banker_third_after_player")
	else:
		EventBus.action_correct.emit("banker_third")


func complete_game() -> void:
	"""Завершить фазу третьих карт и перейти к выбору победителя
	
	Вызывается после раздачи всех необходимых карт.
	Обновляет UI, скрывает toggles третьих карт, переводит игру в состояние CHOOSE_WINNER.
	
	Делегирует логику в GameCompletionCoordinator.
	"""
	if not game_completion_coordinator:
		DebugLogger.log_error("❌ GameCompletionCoordinator не инициализирован!")
		# Fallback на прямое обновление UI
		ui.update_player_third_card_ui("?")
		ui.update_banker_third_card_ui("?")
		ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
		return
	
	var instructions = game_completion_coordinator.get_completion_instructions()
	
	if instructions.get("should_reset_player_third_ui", false):
		ui.update_player_third_card_ui("?")
	
	if instructions.get("should_reset_banker_third_ui", false):
		ui.update_banker_third_card_ui("?")
	
	if instructions.get("should_update_action_button", false):
		ui.update_action_button(instructions.get("action_button_text", Localization.t("ACTION_BUTTON_CARDS")))
	
	# Кнопка НЕ меняется здесь - только после правильного выбора победителя



func _should_banker_draw() -> bool:
	"""Проверить, должна ли банкиру раздаваться третья карта
	
	DEPRECATED: Используйте banker_after_player_handler.should_banker_draw()
	
	Использует BankerAfterPlayerHandler для определения необходимости третьей карты.
	
	Returns:
		true если банкир должен взять третью карту, false иначе
	"""
	if not banker_after_player_handler:
		# Fallback на прямую проверку
		return BaccaratRules.banker_should_draw(
			[hand_manager.get_banker_card(0), hand_manager.get_banker_card(1)],
			hand_manager.has_player_third_card(),
			hand_manager.get_player_third_card()
		)
	return banker_after_player_handler.should_banker_draw()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ UI СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════
# Обработчики событий от UI элементов (кнопки, toggles)
# Логика делегирована в соответствующие координаторы и обработчики

func on_action_pressed() -> void:
	"""Обработчик нажатия главной кнопки действия
	
	Определяет действие на основе текущего состояния игры через PhaseActionResolver.
	Выполняет соответствующее действие (раздача, валидация, выбор победителя).
	"""
	DebugLogger.log_separator()
	DebugLogger.log_game_flow("on_action_pressed() вызван")
	DebugLogger.log("  → is_table_prepared = %s" % is_table_prepared)

	# Используем резолвер для определения действия
	var state = GameStateManager.get_current_state()
	var action_result = phase_resolver.resolve_action(is_table_prepared, state)
	
	var action = action_result.get("action", "validate_third_cards")
	var phase = action_result.get("phase", "unknown")
	var reason = action_result.get("reason", "")
	
	DebugLogger.log("  → Резолвер определил: action=%s, phase=%s, reason=%s" % [action, phase, reason])
	
	# Выполняем действие в зависимости от результата резолвера
	match action:
		"deal_first_four":
			DebugLogger.log_separator("РЕЗОЛВЕР → вызываем deal_first_four()")
			deal_first_four()
		"validate_banker_after_player":
			# Проверка: если выбран победитель в состоянии CARD_TO_BANKER_AFTER_PLAYER, 
			# то нужно обработать выбор победителя, а не продолжать валидацию банкира
			if GameStateManager.get_current_state() == GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER:
				var is_winner_selected = winner_selection_manager and winner_selection_manager.is_winner_selected()
				if is_winner_selected:
					_handle_choose_winner_state()
					return
			
			DebugLogger.log_separator("РЕЗОЛВЕР → вызываем _validate_banker_after_player()")
			_validate_banker_after_player()
		"handle_choose_winner":
			DebugLogger.log_separator("РЕЗОЛВЕР → вызываем _handle_choose_winner_state()")
			_handle_choose_winner_state()
		"validate_third_cards":
			DebugLogger.log_separator("РЕЗОЛВЕР → вызываем _validate_and_execute_third_cards()")
			_validate_and_execute_third_cards()
		_:
			# Fallback на валидацию третьих карт
			DebugLogger.log_warning("  ⚠️ Неизвестное действие от резолвера: %s, используем fallback" % action)
			_validate_and_execute_third_cards()


func on_player_third_toggled(_selected: bool) -> void:
	"""Обработчик переключения toggle третьей карты игрока
	
	Args:
		_selected: Новое состояние toggle (не используется, берется из player_third_selected)
	
	Делегирует обработку в ThirdCardUIHandler.
	"""
	# Используем обработчик для получения инструкций
	var instructions = third_card_ui_handler.handle_player_third_toggled(player_third_selected)
	var was_selected = player_third_selected
	player_third_selected = instructions.get("new_selected", false)
	ui.update_player_third_card_ui(instructions.get("ui_text", "?"))
	
	# Звук активации/деактивации третьей карты игрока
	if not was_selected and player_third_selected:
		# Активация
		if SoundManager:
			SoundManager.play_sound(SoundManager.focus_activate_sound)
	elif was_selected and not player_third_selected:
		# Деактивация
		if SoundManager:
			SoundManager.play_focus_deactivate_sound()

	if was_selected != player_third_selected:
		EventBus.dealer_third_card_toggled.emit("player", player_third_selected)
	
	# Дезактивируем маркер при нажатии на toggle третьей карты
	if instructions.get("should_deselect_winner", false) and winner_selection_manager:
		winner_selection_manager.deselect_winner(false, false)

func on_banker_third_toggled(_selected: bool) -> void:
	"""Обработчик переключения toggle третьей карты банкира
	
	Args:
		_selected: Новое состояние toggle (не используется, берется из banker_third_selected)
	
	Делегирует обработку в ThirdCardUIHandler.
	"""
	# Используем обработчик для получения инструкций
	var instructions = third_card_ui_handler.handle_banker_third_toggled(banker_third_selected)
	var was_selected = banker_third_selected
	banker_third_selected = instructions.get("new_selected", false)
	ui.update_banker_third_card_ui(instructions.get("ui_text", "?"))
	
	# Звук активации/деактивации третьей карты банкира
	if not was_selected and banker_third_selected:
		# Активация
		if SoundManager:
			SoundManager.play_sound(SoundManager.focus_activate_sound)
	elif was_selected and not banker_third_selected:
		# Деактивация
		if SoundManager:
			SoundManager.play_focus_deactivate_sound()

	if was_selected != banker_third_selected:
		EventBus.dealer_third_card_toggled.emit("banker", banker_third_selected)
	
	# Дезактивируем маркер при нажатии на toggle третьей карты
	if instructions.get("should_deselect_winner", false) and winner_selection_manager:
		winner_selection_manager.deselect_winner(false, false)

func cancel_third_card_orders(play_sound: bool = true) -> void:
	"""Отменить заказ всех третьих карт (игрока и банкира)
	
	Args:
		play_sound: Играть ли звук деактивации (по умолчанию true)
	"""
	# Используем обработчик для получения инструкций
	var instructions = third_card_ui_handler.get_cancel_instructions(player_third_selected, banker_third_selected)
	
	if instructions.get("should_cancel_player", false):
		var was_selected = player_third_selected
		player_third_selected = false
		ui.update_player_third_card_ui(instructions.get("player_ui_text", "?"))
		# Звук деактивации третьей карты игрока (только при действии пользователя)
		if play_sound and was_selected and SoundManager:
			SoundManager.play_focus_deactivate_sound()
		DebugLogger.log("🔄 Отменён заказ третьей карты игрока")

	if instructions.get("should_cancel_banker", false):
		var was_selected = banker_third_selected
		banker_third_selected = false
		ui.update_banker_third_card_ui(instructions.get("banker_ui_text", "?"))
		# Звук деактивации третьей карты банкира (только при действии пользователя)
		if play_sound and was_selected and SoundManager:
			SoundManager.play_focus_deactivate_sound()
		DebugLogger.log("🔄 Отменён заказ третьей карты банкира")


func on_tie_button_pressed() -> void:
	"""Обработка нажатия кнопки Игалите

	Кнопка одновременно выбирает и подтверждает ничью.
	Эквивалентна выбору маркера Tie + нажатию кнопки Подтвердить.
	"""
	DebugLogger.log("🎯 Нажата кнопка Игалите")

	# Проверяем что состояние CHOOSE_WINNER
	var state = GameStateManager.get_current_state()
	if state != GameStateManager.GameState.CHOOSE_WINNER:
		return

	# Используем обработчик для получения инструкций
	if not tie_button_handler:
		DebugLogger.log_error("❌ TieButtonHandler не инициализирован!")
		return
	
	var is_survival_mode = SaveManager.instance.load_survival_mode()
	var instructions = tie_button_handler.get_tie_button_instructions(
		has_active_heart_bet(), is_survival_mode
	)
	
	var is_valid = instructions.get("is_valid", false)
	var actual_winner = instructions.get("actual_winner", "")
	
	if not is_valid:
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
	if instructions.get("should_check_chance_cards", false):
		var triggers = tie_button_handler.get_chance_card_triggers(actual_winner)
		_emit_chance_card_triggers(triggers)

	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Если есть активная ставка - разрешаем её и завершаем
	# Выплаты НЕ нужны при Heart Bet!
	# ═══════════════════════════════════════════════════════════════════
	if instructions.get("should_resolve_heart_bet", false):
		print("❤️ on_tie_button_pressed: есть активный Heart Bet, вызываем resolve(%s)" % actual_winner)
		resolve_heart_bet(actual_winner)
		# НЕ продолжаем с обычной логикой - раунд сбросится через EventBus
		return

	# Обновляем UI
	if instructions.get("should_update_ui", false):
		ui.set_action_button_state("complete")
		ui.enable_action_button()
		
		# ВАЖНО: Кнопки Collect/Pay будут показаны автоматически в PayoutQueueHandler.finalize_payouts_manual()
		# после установки правильного режима (COLLECT или PAY) на основе наличия ставок для сбора
		if ui.button_ui:
			var pay_button = ui.button_ui.pay_button
			if pay_button and pay_button.has_method("set_state_take"):
				# Если PayButton имеет свой скрипт - просто показываем кнопку (режим установится позже)
				pay_button.visible = true
			elif ui.button_ui.collect_button:
				# Старая логика: просто показываем кнопку (режим установится позже)
				ui.button_ui.collect_button.visible = true

	# Показываем toast
	if instructions.get("should_show_success", false):
		EventBus.show_toast_success.emit("Игалите")

	# Возвращаем камеру на общий план и показываем кнопки областей
	EventBus.camera_zoom_requested.emit("out", false)
	EventBus.area_buttons_visibility_changed.emit(true)
	# Активируем навигацию по полю (стрелки визуально скрыты, но навигация работает)
	EventBus.navigation_arrows_visibility_changed.emit(true)

	# Формируем очередь выплат
	if instructions.get("should_request_payout", false):
		EventBus.manual_payout_requested.emit("Tie")

	DebugLogger.log_init("Игалите подтверждена!")

func _emit_chance_card_triggers(triggers: Dictionary) -> void:
	"""Эмитить события для активированных триггеров карт шанса
	
	Args:
		triggers: Словарь с флагами триггеров (heart_card, heart_bet_card, revolver_card)
	"""
	if triggers.get("heart_card", false):
		EventBus.heart_card_triggered.emit()
		print("❤️ Heart Card триггер: банкир выиграл с 6!")
	
	if triggers.get("heart_bet_card", false):
		EventBus.heart_bet_card_triggered.emit()
		print("🎰 Heart Bet Card триггер: Tie (игалите)!")
	
	if triggers.get("revolver_card", false):
		EventBus.revolver_card_triggered.emit()
		print("🔫 Revolver Card триггер: все 6 карт по 0 очков!")


# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ И ВЫПОЛНЕНИЕ ТРЕТЬИХ КАРТ
# ═══════════════════════════════════════════════════════════════════════════
# Валидация и выполнение действий с третьими картами
# Логика делегирована в ThirdCardActionValidator и ThirdCardActionExecutor

func _validate_and_execute_third_cards() -> void:
	"""Валидировать и выполнить действия с третьими картами
	
	Проверяет выборы игрока и банкира, валидирует их через ThirdCardActionValidator,
	и выполняет соответствующие действия (раздача карт, завершение игры).
	
	Делегирует валидацию в ThirdCardActionValidator и выполнение в ThirdCardActionExecutor.
	"""
	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ОШИБОЧНОГО ВЫБОРА МАРКЕРА ПОБЕДИТЕЛЯ
	# Если дилер выбрал маркер, но состояние игры требует третьих карт - ошибка
	# ═══════════════════════════════════════════════════════════════════
	var is_winner_selected = winner_selection_manager and winner_selection_manager.is_winner_selected()
	
	if is_winner_selected:
		var current_state = GameStateManager.get_current_state()
		# Состояния, требующие третьих карт (не CHOOSE_WINNER и не WAITING)
		var states_requiring_third_cards = [
			GameStateManager.GameState.CARD_TO_EACH,
			GameStateManager.GameState.CARD_TO_PLAYER,
			GameStateManager.GameState.CARD_TO_BANKER,
			GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER
		]
		
		if current_state in states_requiring_third_cards:
			# Ошибка! Дилер выбрал победителя, но нужны третьи карты
			var error_msg = GameStateManager.get_error_message(GameStateManager.Action.SELECT_WINNER, current_state)
			# Показываем toast с ошибкой
			EventBus.show_toast_error.emit(error_msg)
			# Эмитим событие ошибки (для отнятия сердца)
			EventBus.action_error.emit("winner_early", error_msg)
			DebugLogger.log("🚫 Ошибка: выбран маркер победителя, но нужны третьи карты. %s" % error_msg)
			# Сбрасываем выбор маркера после ошибки
			winner_selection_manager.deselect_winner(false, false)
			return
	
	# Проверка: если ничего не изменено (обе кнопки не активированы), то подтверждать нечего
	if not player_third_selected and not banker_third_selected:
		DebugLogger.log("⚠️ Нет изменений для подтверждения: обе кнопки третьих карт не активированы")
		return
	
	# Используем валидатор для чистой логики валидации
	var ps: int = hand_manager.get_player_initial_score()
	var bs: int = hand_manager.get_banker_initial_score()
	var has_player_third = hand_manager.has_player_third_card()
	var player_third_card = hand_manager.get_player_third_card()
	
	var validation_result = third_card_validator.validate_third_card_action(
		ps, bs,
		player_third_selected, banker_third_selected,
		has_player_third, player_third_card
	)
	
	# Обрабатываем результат валидации
	_handle_validation_result(validation_result, ps, bs)

# ========================================
# ОБРАБОТКА РЕЗУЛЬТАТОВ ВАЛИДАЦИИ
# ========================================

func _handle_validation_result(result: Dictionary, player_score: int, banker_score: int) -> void:
	"""Обработать результат валидации третьих карт
	
	Выполняет действия на основе результата валидации:
	- Раздача карт игроку и/или банкиру
	- Завершение игры
	- Показ ошибок валидации
	
	Args:
		result: Результат валидации от ThirdCardActionValidator
		player_score: Очки игрока (начальные)
		banker_score: Очки банкира (начальные)
	"""
	"""Обработать результат валидации от ThirdCardActionValidator
	
	Args:
		result: Результат валидации от валидатора
		player_score: Очки игрока (для сообщений об ошибках)
		banker_score: Очки банкира (для сообщений об ошибках)
	"""
	# Используем исполнитель для получения инструкций
	var instructions = third_card_action_executor.get_action_instructions(result)
	
	# Сбрасываем выборы если нужно
	if instructions.get("should_reset_player", false):
		player_third_selected = false
		ui.update_player_third_card_ui("?")
	
	if instructions.get("should_reset_banker", false):
		banker_third_selected = false
		ui.update_banker_third_card_ui("?")
	
	# Если валидация не прошла - показываем ошибку
	if instructions.get("should_show_error", false):
		var error_type = instructions.get("error_type", "")
		var error_message = instructions.get("error_message", "")
		
		# Используем форматтер для форматирования сообщения об ошибке
		var message_text = validation_error_formatter.format_third_card_error(
			error_message, player_score, banker_score
		)
		
		EventBus.show_toast_error.emit(message_text)
		EventBus.action_error.emit(error_type, message_text)
		return
	
	# Валидация прошла - выполняем действие
	var action = instructions.get("action", "complete")
	match action:
		"draw_both":
			EventBus.dealer_third_card_decision.emit("each")
			draw_player_third()
			draw_banker_third()
			complete_game()
		"draw_player":
			EventBus.dealer_third_card_decision.emit("player")
			draw_player_third()
			# Проверяем нужно ли ждать решения банкира (сценарий 3.2: банкир 3-6)
			if instructions.get("needs_banker_decision", false):
				_handle_banker_after_player()
			else:
				complete_game()
		"draw_banker":
			EventBus.dealer_third_card_decision.emit("banker")
			draw_banker_third()
			complete_game()
		"wait_banker":
			# Игрок взял карту, ждём решения банкира
			_handle_banker_after_player()
		"complete":
			complete_game()
		_:
			complete_game()

# ========================================
# ОБРАБОТЧИКИ ДЛЯ КАЖДОГО СЦЕНАРИЯ (DEPRECATED - используются через валидатор)
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
	"""Обработать случай раздачи третьих карт обеим сторонам
	
	Раздает третью карту и игроку, и банкиру, затем завершает игру.
	"""
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

func _handle_banker_after_player() -> void:
	"""Обработать решение банкира после того, как игрок взял третью карту
	
	После раздачи карты игроку устанавливаем состояние ожидания.
	Валидация произойдет когда игрок нажмет кнопку "Карты" в этом состоянии.
	"""
	if not banker_after_player_handler:
		DebugLogger.log_error("❌ BankerAfterPlayerHandler не инициализирован!")
		complete_game()
		return
	
	var should_draw = banker_after_player_handler.should_banker_draw()
	if should_draw:
		# Банкир должен взять третью карту - устанавливаем состояние ожидания
		# Валидация будет происходить когда игрок нажмет "Карты" в этом состоянии
		GameStateManager.update_state(GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER)
		# Сбрасываем выбор банкира, чтобы игрок мог выбрать заново
		banker_third_selected = false
		ui.update_banker_third_card_ui("?")
	else:
		complete_game()

func _validate_banker_after_player() -> void:
	"""Валидировать выбор банкира после того, как игрок взял третью карту
	
	Вызывается когда игрок нажал кнопку "Карты" в состоянии CARD_TO_BANKER_AFTER_PLAYER.
	Валидирует выбор банкира и выполняет соответствующее действие.
	
	Делегирует валидацию в BankerAfterPlayerHandler.
	"""
	if not banker_after_player_handler:
		DebugLogger.log_error("❌ BankerAfterPlayerHandler не инициализирован!")
		return
	
	var instructions = banker_after_player_handler.get_validation_instructions(banker_third_selected)
	
	if not instructions.get("should_validate", false):
		complete_game()
		return
	
	# Проверка: если кнопка банкира не активирована, то подтверждать нечего
	if not banker_third_selected:
		DebugLogger.log("⚠️ Нет изменений для подтверждения: кнопка третьей карты банкира не активирована")
		return
	
	var validation_result = instructions.get("validation_result", {})
	var banker_score = instructions.get("banker_score", 0)
	
	# Обрабатываем результат валидации
	_handle_banker_validation_result(validation_result, banker_score)

func _handle_banker_validation_result(result: Dictionary, banker_score: int) -> void:
	"""Обработать результат валидации банкира после игрока
	
	Args:
		result: Результат валидации от валидатора
		banker_score: Очки банкира (для сообщений об ошибках)
	"""
	# Используем исполнитель для получения инструкций
	var instructions = third_card_action_executor.get_banker_action_instructions(result)
	
	# Сбрасываем выбор если нужно
	if instructions.get("should_reset_banker", false):
		banker_third_selected = false
		ui.update_banker_third_card_ui("?")
	elif result.get("action") == "wait_banker" and not banker_third_selected:
		# Банкир должен взять карту, но не выбрал - устанавливаем флаг
		banker_third_selected = true
	
	# Если валидация не прошла - показываем ошибку
	if instructions.get("should_show_error", false):
		var error_type = instructions.get("error_type", "")
		var error_message = instructions.get("error_message", "")
		
		# Используем форматтер для форматирования сообщения об ошибке
		var message_text = validation_error_formatter.format_third_card_error(
			error_message, -1, banker_score
		)
		
		EventBus.show_toast_error.emit(message_text)
		EventBus.action_error.emit(error_type, message_text)
		return
	
	# Валидация прошла - выполняем действие
	var action = instructions.get("action", "complete")
	match action:
		"draw_banker":
			EventBus.dealer_third_card_decision.emit("banker")
			draw_banker_third()
			complete_game()
		"complete":
			complete_game()
		"wait_banker":
			# Ждём выбора банкира (ничего не делаем, состояние уже обновлено)
			pass
		_:
			complete_game()

# ═══════════════════════════════════════════════════════════════════════════
# ВОССТАНОВЛЕНИЕ И ОТОБРАЖЕНИЕ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════
# Методы для восстановления и отображения ставок гостей
# Логика делегирована в координаторы

func _restore_active_bet_chips() -> void:
	"""Восстановить ВСЕ фишки из TableStateManager для новой раздачи

	При подготовке к новой игре восстанавливаем ВСЕ фишки (включая проигрышные из предыдущей раздачи)
	с их оригинальными текстурами. Это показывает игроку какие ставки будут в следующей раздаче.
	"""
	if not chip_visual_manager:
		return

	# Инициализируем координатор если нужно
	if not chip_restoration_coordinator:
		chip_restoration_coordinator = ChipRestorationCoordinator.new(guest_bet_storage)

	# Получаем инструкции от координатора
	var instructions = chip_restoration_coordinator.get_restoration_instructions()
	
	# Показываем ставки гостей (если нужно)
	if instructions.get("should_show_guest_bets", false):
		_show_guest_bets()

	# Восстанавливаем фишки из TableStateManager (если нужно)
	if instructions.get("should_restore_from_table_state", false):
		DebugLogger.log_restore(" Восстановление фишек для новой раздачи из TableStateManager...")
		var chips_to_restore = instructions.get("chips_to_restore", [])
		for chip_data in chips_to_restore:
			var bet_type = chip_data.get("bet_type", "")
			var chip_texture = chip_data.get("chip_texture", "")
			if chip_texture.is_empty():
				chip_visual_manager.make_chip_visible(bet_type)
			else:
				chip_visual_manager.set_chip_texture(bet_type, chip_texture)
			DebugLogger.log("  → Восстановлена фишка %s" % bet_type)
	else:
		# Логируем причину если не восстанавливаем
		var reason = instructions.get("reason", "")
		if not reason.is_empty():
			DebugLogger.log_warning(" %s" % reason)

	DebugLogger.log_payout("Показаны фишки всех активных ставок")

func _show_guest_bets() -> void:
	"""Показать ставки гостей на их позициях в секторах (по очереди с задержкой)"""
	if not guest_bet_storage or not chip_visual_manager:
		DebugLogger.log("👥 _show_guest_bets: нет guest_bet_storage или chip_visual_manager")
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# СОХРАНЕНИЕ SNAPSHOT ФИЛЬТРА: фиксируем состояние на момент показки
	# ═══════════════════════════════════════════════════════════════════
	_save_filter_snapshot()
	
	# Используем координатор для получения инструкций
	var instructions = guest_bet_display_coordinator.get_display_instructions(
		guest_bet_storage, bet_filter_manager, PayoutSettingsManager, pair_betting_manager
	)
	
	if instructions.is_empty():
		DebugLogger.log("👥 Нет ставок гостей для отображения")
		return
	
	# Группируем по гостям для логирования
	var guests_count = guest_bet_display_coordinator.get_guests_with_bets_count(guest_bet_storage)
	DebugLogger.log("👥 Отображение ставок %d гостей" % guests_count)
	
	# ═══════════════════════════════════════════════════════════════════
	# ГРУППИРОВКА ПО СЕКТОРАМ И ПОКАЗ ПО ОЧЕРЕДИ
	# ═══════════════════════════════════════════════════════════════════
	# Группируем инструкции по секторам (1-6)
	var bets_by_sector: Dictionary = {}  # {sector: Array[Dictionary]}
	
	for instruction in instructions:
		var sector = instruction.get("sector", -1)
		if sector >= 1 and sector <= 6:
			if not bets_by_sector.has(sector):
				bets_by_sector[sector] = []
			bets_by_sector[sector].append(instruction)
	
	# Показываем ставки по очереди по секторам (1, 2, 3, 4, 5, 6)
	for sector in range(1, 7):  # 1-6
		if not bets_by_sector.has(sector):
			continue  # Пропускаем сектора без ставок (без задержки)
		
		# Проверяем, что гость активен и у него есть ставки
		if not GuestSettingsManager.is_guest_enabled(sector):
			continue  # Пропускаем неактивных гостей (без задержки)
		
		# Показываем все ставки этого сектора
		var sector_bets = bets_by_sector[sector]
		for instruction in sector_bets:
			var bet_type = instruction.get("bet_type", "")
			var pos_idx = instruction.get("position_index", -1)
			var coords = instruction.get("coords", Vector2.ZERO)
			var stake = instruction.get("stake", 0.0)
			var guest_id = instruction.get("guest_id", -1)
			
			# Создаём фишку на позиции гостя
			_show_guest_chip_at_position(bet_type, pos_idx, coords, stake)
			
			# Звук ставки
			if SoundManager:
				SoundManager.play_bet_sound()
			
			DebugLogger.log("  → Гость %d: фишка %s на позиции %d (%.0f) в секторе %d" % [guest_id, bet_type, pos_idx, stake, sector])
		
		# Задержка 0.3 сек перед следующим сектором (только если есть следующий сектор)
		if sector < 6:
			# Проверяем, есть ли следующий сектор с активными ставками
			var has_next_sector = false
			for next_sector in range(sector + 1, 7):
				if bets_by_sector.has(next_sector) and GuestSettingsManager.is_guest_enabled(next_sector):
					has_next_sector = true
					break
			
			if has_next_sector:
				await EventBus.get_tree().create_timer(0.3).timeout

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
			# Обновляем или создаём label для суммы ставки
			if existing_chip.stake > 0:
				if existing_chip.stake_label:
					# Обновляем существующий label
					chip_visual_manager._update_stake_label(existing_chip)
				else:
					# Создаём новый label
					existing_chip.stake_label = chip_visual_manager.create_stake_label(existing_chip)
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
		original_chip.focus_mode = Control.FOCUS_NONE  # Отключаем фокус чтобы Space не активировал фишки
		
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
		# Создаём label для суммы ставки (если stake > 0)
		if chip_instance.stake > 0:
			chip_instance.stake_label = chip_visual_manager.create_stake_label(chip_instance)
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
		new_chip.focus_mode = Control.FOCUS_NONE  # Отключаем фокус чтобы Space не активировал фишки
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
		# Создаём label для суммы ставки (если stake > 0)
		if chip_instance.stake > 0:
			chip_instance.stake_label = chip_visual_manager.create_stake_label(chip_instance)
		chip_visual_manager.active_chips.append(chip_instance)

# ═══════════════════════════════════════════════════════════════════════════
# ФИЛЬТРЫ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════
# Методы для работы с фильтрами ставок (включение/выключение типов)
# Логика делегирована в BetFilterManager

func _is_bet_type_enabled_in_settings(bet_type: String) -> bool:
	"""Проверить, включён ли тип ставки в настройках PayoutSettingsManager
	
	DEPRECATED: Используйте bet_filter_manager.is_bet_type_enabled_in_settings()
	
	Args:
		bet_type: Тип ставки (Player, Banker, Tie, PairPlayer, PairBanker)
	
	Returns:
		true если ставка включена в настройках, false если отключена
	"""
	return bet_filter_manager.is_bet_type_enabled_in_settings(
		bet_type, PayoutSettingsManager, pair_betting_manager
	)

func _save_filter_snapshot() -> void:
	"""Сохранить снимок текущего состояния фильтра
	
	DEPRECATED: Используйте bet_filter_manager.save_filter_snapshot()
	
	Вызывается при показке ставок для изоляции текущей раздачи от изменений фильтра.
	"""
	bet_filter_manager.save_filter_snapshot(PayoutSettingsManager, pair_betting_manager)
	DebugLogger.log("📸 Snapshot фильтра сохранён: %s" % bet_filter_manager.filter_snapshot)

func _is_bet_type_enabled_in_snapshot(bet_type: String) -> bool:
	"""Проверить, включён ли тип ставки в snapshot фильтра
	
	DEPRECATED: Используйте bet_filter_manager.is_bet_type_enabled_in_snapshot()
	
	Args:
		bet_type: Тип ставки (Player, Banker, Tie, PairPlayer, PairBanker)
	
	Returns:
		true если ставка включена в snapshot, false если отключена
	"""
	return bet_filter_manager.is_bet_type_enabled_in_snapshot(
		bet_type, PayoutSettingsManager, pair_betting_manager
	)

func is_bet_type_enabled_in_snapshot(bet_type: String) -> bool:
	"""Публичный метод для проверки ставки через snapshot (для PayoutManager)
	
	Args:
		bet_type: Тип ставки (Player, Banker, Tie, PairPlayer, PairBanker)
	
	Returns:
		true если ставка включена в snapshot, false если отключена
	"""
	return bet_filter_manager.is_bet_type_enabled_in_snapshot(
		bet_type, PayoutSettingsManager, pair_betting_manager
	)

func _apply_pending_filter_changes() -> void:
	"""Применить накопленные изменения фильтра к PayoutSettingsManager
	
	DEPRECATED: Используйте bet_filter_manager.apply_pending_filter_changes()
	
	Вызывается при завершении раунда перед генерацией новых ставок.
	Применяет все изменения из pending_filter_changes и обновляет snapshot.
	"""
	if not bet_filter_manager.has_pending_filter_changes():
		DebugLogger.log("📋 Нет накопленных изменений фильтра для применения")
		return
	
	DebugLogger.log("📋 Применение накопленных изменений фильтра: %s" % bet_filter_manager.get_pending_filter_changes())
	
	# Применяем изменения через менеджер
	var result = bet_filter_manager.apply_pending_filter_changes(PayoutSettingsManager, pair_betting_manager)
	
	if result.get("applied", false):
		var changes = result.get("changes", {})
		for bet_type in changes.keys():
			var enabled = changes[bet_type]
			DebugLogger.log("  → Применено: %s = %s" % [bet_type, "ВКЛ" if enabled else "ВЫКЛ"])
		
		# Обновляем snapshot на основе примененных изменений
		_save_filter_snapshot()
		DebugLogger.log("📋 Все накопленные изменения применены, snapshot обновлён")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ СОСТОЯНИЕМ ИГРЫ
# ═══════════════════════════════════════════════════════════════════════════
# Методы для обновления и управления состоянием игры
# Логика делегирована в GameStateUpdater

func _update_game_state_manager() -> void:
	"""Обновить состояние игры в GameStateManager
	
	Делегирует обновление в GameStateUpdater.
	"""
	# Используем обновлятор для обновления состояния игры
	game_state_updater.update_game_state(hand_manager)


func remove_third_cards_and_recalculate() -> void:
	"""Убрать третьи карты и пересчитать состояние игры (для Third Card Change)
	
	Используется картой Third Card Change для:
	1. Удаления третьих карт из рук
	2. Скрытия третьих карт в UI (и текстуры карт, и тумблеры)
	3. Сброса флагов выбора
	4. Пересчёта состояния игры (возврат к фазе заказа третьих карт)
	"""
	if not third_card_removal_coordinator:
		DebugLogger.log_error("❌ ThirdCardRemovalCoordinator не инициализирован!")
		return
	
	print("🔄 Third Card Change: убираем третьи карты...")
	
	# Получаем инструкции от координатора
	var instructions = third_card_removal_coordinator.get_removal_instructions()
	
	# Сбрасываем флаги выбора третьих карт
	if instructions.get("should_reset_flags", false):
		player_third_selected = false
		banker_third_selected = false
	
	# Убираем карты из hand_manager
	if instructions.get("should_remove_cards", false):
		third_card_removal_coordinator.remove_third_cards()
	
	# Обновляем UI
	if instructions.get("should_update_ui", false):
		# Скрываем текстуры третьих карт на столе
		ui.hide_third_cards()
		
		# Показываем тумблеры "?" для заказа новых третьих карт
		ui.update_player_third_card_ui("?")
		ui.update_banker_third_card_ui("?")
	
	# Пересчитываем состояние игры
	if instructions.get("should_recalculate_state", false):
		_update_game_state_manager()
	
	var new_state = GameStateManager.get_state_name(GameStateManager.current_state)
	print("🔄 Third Card Change: третьи карты убраны, новое состояние: %s" % new_state)
	
	# Показываем уведомление
	EventBus.show_toast_info.emit("Третьи карты убраны! Заказывайте заново.")


# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ ВЫБОРА ПОБЕДИТЕЛЯ
# ═══════════════════════════════════════════════════════════════════════════
# Валидация выбора победителя через маркеры
# Логика делегирована в WinnerSelectionValidator и WinnerSelectionCoordinator

func _validate_winner_selection() -> void:
	"""Проверка выбранного победителя через маркеры"""
	if not winner_selection_manager:
		EventBus.show_toast_info.emit(Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER"))
		return

	var selected_winner = winner_selection_manager.get_selected_winner()
	var player_hand_ref = hand_manager.get_player_hand_ref()
	var banker_hand_ref = hand_manager.get_banker_hand_ref()
	
	# Используем координатор для получения инструкций
	var is_survival_mode = SaveManager.instance.load_survival_mode()
	var instructions = winner_selection_coordinator.get_validation_instructions(
		selected_winner,
		player_hand_ref,
		banker_hand_ref,
		is_survival_mode,
		was_heart_bet_round,
		has_active_heart_bet()
	)
	
	# Не выбран ни один маркер?
	if instructions.get("needs_selection", false):
		return
	
	var actual_winner = instructions.get("actual_winner", "")
	var validation_result = instructions.get("validation_result", {})
	
	# ВАЖНО: Сохраняем победителя в TableStateManager для триггеров Heart Bet!
	if instructions.get("should_save_winner", false):
		TableStateManager.set_actual_winner(actual_winner)

	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ТРИГГЕРОВ HEART BET: сразу после определения победителя
	# Карта шанса показывается немедленно через EventBus.heart_bet_trigger_activated
	# ═══════════════════════════════════════════════════════════════════
	if instructions.get("should_check_heart_bet_triggers", false) and heart_bet_manager:
		var trigger_data = instructions.get("heart_bet_trigger_data", {})
		# HeartBetManager.check_triggers() уже эмитит EventBus.heart_bet_trigger_activated
		# ChanceCardManager автоматически покажет карту через подписку на это событие
		heart_bet_manager.check_triggers(
			trigger_data.get("winner", ""),
			trigger_data.get("banker_score", 0),
			trigger_data.get("player_score", 0),
			trigger_data.get("is_natural", false)
		)

	# Обрабатываем результат валидации
	_handle_winner_validation_result(validation_result, actual_winner)

func _handle_winner_validation_result(result: Dictionary, actual_winner: String) -> void:
	"""Обработать результат валидации выбора победителя
	
	Args:
		result: Результат валидации от WinnerSelectionValidator
		actual_winner: Фактический победитель (уже определён)
	"""
	# Используем исполнитель для получения инструкций
	var instructions = winner_action_executor.get_action_instructions(result, actual_winner)
	
	# Если валидация не прошла - показываем ошибку
	if instructions.get("should_show_error", false):
		var error_type = instructions.get("error_type", "")
		var error_message = instructions.get("error_message", "")
		var error_params = instructions.get("error_params", [])
		
		# Используем форматтер для форматирования сообщения об ошибке
		var message_text = validation_error_formatter.format_winner_selection_error(
			error_message, error_params
		)
		
		EventBus.show_toast_error.emit(message_text)
		EventBus.action_error.emit(error_type, message_text)
		# Сбрасываем выбор маркера
		if instructions.get("should_reset_winner_selection", false) and winner_selection_manager:
			winner_selection_manager.reset()
		return
	
	# ✅ Правильный выбор!
	if winner_selection_manager:
		winner_selection_manager.lock_markers()

	if instructions.get("should_emit_correct", false):
		EventBus.action_correct.emit("winner")
	
	# ═══════════════════════════════════════════════════════════════════
	# ТРИГГЕРЫ КАРТ ШАНСА (только в режиме выживания)
	# ═══════════════════════════════════════════════════════════════════
	if instructions.get("should_check_chance_card_triggers", false) and SaveManager.instance.load_survival_mode():
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
	if instructions.get("should_update_button_state", false):
		ui.set_action_button_state(instructions.get("button_state", "complete"))
		# Активируем кнопку при переходе в стадию выплат
		ui.enable_action_button()

	# ВАЖНО: Кнопки Collect/Pay будут показаны автоматически в PayoutQueueHandler.finalize_payouts_manual()
	# после установки правильного режима (COLLECT или PAY) на основе наличия ставок для сбора
	# Поэтому здесь просто убеждаемся, что кнопки видны (без установки режима по умолчанию)
	if ui.button_ui:
		var pay_button = ui.button_ui.pay_button
		if pay_button and pay_button.has_method("set_state_take"):
			# Если PayButton имеет свой скрипт - просто показываем кнопку (режим установится позже)
			pay_button.visible = true
		elif ui.button_ui.collect_button:
			# Старая логика: просто показываем кнопку (режим установится позже)
			ui.button_ui.collect_button.visible = true

	# Показываем toast с результатом (кто выиграл и с какими картами)
	var player_score = hand_manager.get_player_score()
	var banker_score = hand_manager.get_banker_score()
	var victory_msg = victory_message_formatter.format_victory_message(actual_winner, player_score, banker_score)
	EventBus.show_toast_success.emit(victory_msg)

	# Проверяем способ управления (клавиатура или мышь/сенсор)
	var was_keyboard_input = false
	if winner_selection_manager:
		was_keyboard_input = winner_selection_manager.was_last_toggle_by_keyboard
	
	# Проверяем есть ли активные гости
	var active_guests = GuestSettingsManager.get_active_guests()
	if active_guests.is_empty():
		# Нет гостей - камера остается на картах (не перемещаем)
		DebugLogger.log("📷 GamePhaseManager: нет гостей - камера остается на картах")
		EventBus.navigation_arrows_visibility_changed.emit(true)
		# Вызываем метод формирования очереди выплат через EventBus
		EventBus.manual_payout_requested.emit(actual_winner)
		return
	
	# Проверяем есть ли ставки для обработки
	if guest_bet_storage:
		var guests_with_bets = guest_bet_storage.get_guests_with_bets()
		if guests_with_bets.is_empty():
			# Нет ставок - камера на общий план
			EventBus.camera_zoom_requested.emit("out", false)
			DebugLogger.log("📷 GamePhaseManager: нет ставок - камера на общий план")
			EventBus.navigation_arrows_visibility_changed.emit(true)
			# Вызываем метод формирования очереди выплат через EventBus
			EventBus.manual_payout_requested.emit(actual_winner)
			return
	
	# Есть ставки - перемещаем камеру на соответствующую Area (для обоих режимов управления)
	var rightmost_sector = _find_rightmost_sector_with_bets()
	var target_area = _sector_to_area(rightmost_sector)
	
	# Перемещаем камеру на соответствующую Area
	var area_zoom_type = "area_%d" % target_area
	EventBus.camera_zoom_requested.emit(area_zoom_type, false)
	DebugLogger.log("📷 GamePhaseManager: камера перемещена на Area %d (сектор %d)" % [target_area, rightmost_sector])
	
	# Активируем навигацию по полю (стрелки визуально скрыты, но навигация работает)
	EventBus.navigation_arrows_visibility_changed.emit(true)
	
	# Если управление клавиатурой - дополнительно активируем chip navigation
	if was_keyboard_input:
		EventBus.chip_navigation_activation_requested.emit(false)

	# Вызываем метод формирования очереди выплат через EventBus
	EventBus.manual_payout_requested.emit(actual_winner)

func _find_rightmost_sector_with_bets() -> int:
	"""Найти самый правый сектор со ставками (для режима 2)
	
	Секторы соответствуют гостям (1-6):
	- Сектор 1 = Гость 1
	- Сектор 2 = Гость 2
	- ...
	- Сектор 6 = Гость 6 (самый правый)
	
	Returns:
		Номер сектора (1-6) с самой правой ставкой, или 6 по умолчанию
	"""
	if not guest_bet_storage:
		return 6  # По умолчанию самый правый сектор
	
	# Сначала проверяем, есть ли вообще ставки
	var guests_with_bets = guest_bet_storage.get_guests_with_bets()
	if guests_with_bets.is_empty():
		return 6  # По умолчанию самый правый сектор
	
	# Проверяем секторы справа налево (6, 5, 4, 3, 2, 1)
	var sector_order = [6, 5, 4, 3, 2, 1]
	for sector in sector_order:
		# Сектор соответствует гостю с тем же номером
		if guest_bet_storage.has_guest_bets(sector):
			DebugLogger.log("📍 GamePhaseManager: найден самый правый сектор со ставками: сектор %d (гость %d)" % [sector, sector])
			return sector
	
	# Не нашли ставок - возвращаем дефолтный сектор
	return 6

func _sector_to_area(sector: int) -> int:
	"""Преобразовать номер сектора (1-6) в номер Area (1-3)
	
	Маппинг:
	- Сектора 1-2 → Area 1 (левая)
	- Сектора 3-4 → Area 2 (центральная)
	- Сектора 5-6 → Area 3 (правая)
	
	Args:
		sector: Номер сектора (1-6)
		
	Returns:
		Номер Area (1-3)
	"""
	if sector >= 1 and sector <= 2:
		return 1
	elif sector >= 3 and sector <= 4:
		return 2
	elif sector >= 5 and sector <= 6:
		return 3
	else:
		return 1  # По умолчанию Area 1

func _get_guest_mode2_zoom_for_sector(sector: int) -> String:
	"""Получить тип зума guest_X_mode2 для сектора
	
	Args:
		sector: Номер сектора (1-6)
		
	Returns:
		Тип зума: "guest_X_mode2" где X соответствует номеру сектора (1-6)
	"""
	match sector:
		1:
			return "guest_1_mode2"
		2:
			return "guest_2_mode2"
		3:
			return "guest_3_mode2"
		4:
			return "guest_4_mode2"
		5:
			return "guest_5_mode2"
		6:
			return "guest_6_mode2"
		_:
			push_error("GamePhaseManager: неверный номер сектора %d, используется guest_6_mode2" % sector)
			return "guest_6_mode2"

# DEPRECATED: Используйте victory_message_formatter.format_victory_message()
# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════
# Вспомогательные методы для форматирования и обработки

func _format_victory_toast(winner: String) -> String:
	"""Форматирование сообщения победы
	
	DEPRECATED: Используйте victory_message_formatter.format_victory_message()
	
	Args:
		winner: Победитель ("Player", "Banker", "Tie")
	
	Returns:
		Отформатированное сообщение победы
	"""
	var player_score = hand_manager.get_player_score()
	var banker_score = hand_manager.get_banker_score()
	return victory_message_formatter.format_victory_message(winner, player_score, banker_score)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СОСТОЯНИЯ ВЫБОРА ПОБЕДИТЕЛЯ
# ═══════════════════════════════════════════════════════════════════════════
# Методы для обработки состояния CHOOSE_WINNER
# Логика делегирована в WinnerSelectionStateHandler

func _handle_choose_winner_state() -> void:
	"""Обработка состояния CHOOSE_WINNER (выбор победителя и завершение раунда)

	Рефакторенная версия с guard clauses для уменьшения вложенности.
	Было: 6+ уровней вложенности, 134 строки
	Стало: 2-3 уровня вложенности, разбито на методы
	"""
	if not winner_selection_state_handler:
		DebugLogger.log_error("❌ WinnerSelectionStateHandler не инициализирован!")
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ОШИБОЧНОГО ВЫБОРА МАРКЕРА ПОБЕДИТЕЛЯ
	# Если дилер выбрал маркер, но состояние игры требует третьих карт - ошибка
	# Это может произойти если состояние игры определилось неправильно
	# ═══════════════════════════════════════════════════════════════════
	var is_winner_selected = winner_selection_manager and winner_selection_manager.is_winner_selected()
	
	if is_winner_selected:
		var current_state = GameStateManager.get_current_state()
		# Состояния, требующие третьих карт (не CHOOSE_WINNER и не WAITING)
		var states_requiring_third_cards = [
			GameStateManager.GameState.CARD_TO_EACH,
			GameStateManager.GameState.CARD_TO_PLAYER,
			GameStateManager.GameState.CARD_TO_BANKER,
			GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER
		]
		
		if current_state in states_requiring_third_cards:
			# Ошибка! Дилер выбрал победителя, но нужны третьи карты
			var error_msg = GameStateManager.get_error_message(GameStateManager.Action.SELECT_WINNER, current_state)
			# Показываем toast с ошибкой
			EventBus.show_toast_error.emit(error_msg)
			# Эмитим событие ошибки (для отнятия сердца)
			EventBus.action_error.emit("winner_early", error_msg)
			DebugLogger.log("🚫 Ошибка: выбран маркер победителя, но нужны третьи карты. %s" % error_msg)
			# Сбрасываем выбор маркера после ошибки
			winner_selection_manager.deselect_winner(false, false)
			return
	
	var button_state = ui.get_action_button_state()
	var can_complete = _can_complete_round()
	
	# DEBUG: Добавлено для диагностики проблемы с пустым winner marker
	print("DEBUG: GameStateManager.get_state_name(GameStateManager.current_state) = %s" % GameStateManager.get_state_name(GameStateManager.current_state))
	print("DEBUG: button_state = %s" % button_state)
	print("DEBUG: player_third_selected = %s" % player_third_selected)
	print("DEBUG: banker_third_selected = %s" % banker_third_selected)
	
	# Используем обработчик для получения инструкций
	var instructions = winner_selection_state_handler.get_state_handling_instructions(
		player_third_selected,
		banker_third_selected,
		button_state,
		can_complete
	)
	
	var action = instructions.get("action", "none")
	match action:
		"handle_invalid_selection":
			_handle_invalid_card_selection_in_final(instructions)
		"validate_winner":
			_validate_winner_selection()
		"complete_round":
			_complete_round_and_prepare_new_game()
		"none":
			pass  # Сообщение об ошибке уже показано


func _handle_invalid_card_selection_in_final(instructions: Dictionary = {}) -> void:
	"""Обработка ошибочной попытки заказать карты когда все карты открыты
	
	Args:
		instructions: Инструкции от WinnerSelectionStateHandler (опционально)
	"""
	# Если инструкции не переданы - получаем их
	if instructions.is_empty():
		if not winner_selection_state_handler:
			DebugLogger.log_error("❌ WinnerSelectionStateHandler не инициализирован!")
			return
		var button_state = ui.get_action_button_state()
		instructions = winner_selection_state_handler.get_state_handling_instructions(
			player_third_selected,
			banker_third_selected,
			button_state,
			_can_complete_round()
		)
	
	var error_message_key = instructions.get("error_message_key", "INFO_ALL_OPENED_CHOOSE_WINNER")
	var error_message = Localization.t(error_message_key)
	EventBus.show_toast_error.emit(error_message)
	EventBus.action_error.emit("final_card_error", "")

	# Сбрасываем галочки
	player_third_selected = false
	banker_third_selected = false
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")


func _apply_penalties_for_unpaid_bets() -> void:
	"""Применить штрафы за неоплаченные выигрышные ставки
	
	Для каждой неоплаченной ставки:
	- Уменьшает терпение гостя на -20%
	- Штрафует на -100 чаевых
	- Если чаевые заканчиваются, отнимает максимум 1 сердце
	"""
	if not payout_queue_manager:
		return
	
	# Получаем все неоплаченные выигрышные ставки
	var unpaid_bets = payout_queue_manager.get_unpaid_winning_bets()
	if unpaid_bets.is_empty():
		return
	
	# Фильтруем ставки, исключая Tie push (если есть bet_collection_manager)
	var filtered_unpaid_bets: Array = []
	for bet in unpaid_bets:
		if bet_collection_manager:
			var bet_type = bet.get_bet_type()
			if bet_collection_manager.is_tie_push_bet(bet_type):
				continue  # Пропускаем Tie push ставки
		filtered_unpaid_bets.append(bet)
	
	if filtered_unpaid_bets.is_empty():
		return
	
	DebugLogger.log_separator("ПРИМЕНЕНИЕ ШТРАФОВ ЗА НЕОПЛАЧЕННЫЕ СТАВКИ")
	DebugLogger.log("  Неоплаченных ставок: %d" % filtered_unpaid_bets.size())
	
	var total_tip_penalty = 0
	
	# Словарь для группировки штрафов по гостям (для логирования)
	var penalties_by_guest: Dictionary = {}  # {guest_id: {patience: int, tips: int, bets: Array}}
	
	# Применяем штрафы к каждой неоплаченной ставке
	for bet in filtered_unpaid_bets:
		var bet_type = bet.get_bet_type()
		var position_index = bet.get_position_index()
		
		# Определяем гостя по position_index и bet_type
		var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
		
		# Пропускаем не гостевые ставки
		if sector < 1 or sector > 6:
			DebugLogger.log("  ⚠️ Ставка %s[%d] не является гостевой, пропускаем" % [bet_type, position_index])
			continue
		
		var guest_id = sector
		
		# Инициализируем словарь для гостя если нужно
		if not penalties_by_guest.has(guest_id):
			penalties_by_guest[guest_id] = {
				"patience": 0,
				"tips": 0,
				"bets": []
			}
		
		# Уменьшаем терпение гостя на -20% за каждую ставку
		GuestStatsManager.decrease_patience(guest_id, 20)
		penalties_by_guest[guest_id].patience += 20
		penalties_by_guest[guest_id].bets.append("%s[%d]" % [bet_type, position_index])
		
		# Штрафуем на -100 чаевых за каждую ставку
		var tip_penalty = 100
		total_tip_penalty += tip_penalty
		penalties_by_guest[guest_id].tips += tip_penalty
		
		DebugLogger.log("  💸 Гость %d: -20%% терпения, -100 чаевых за ставку %s[%d]" % [guest_id, bet_type, position_index])
	
	# Логируем итоги по каждому гостю
	for guest_id in penalties_by_guest.keys():
		var penalty_data = penalties_by_guest[guest_id]
		DebugLogger.log("  👤 Гость %d: итого -%d%% терпения, -%d чаевых (%d ставок: %s)" % [
			guest_id,
			penalty_data.patience,
			penalty_data.tips,
			penalty_data.bets.size(),
			str(penalty_data.bets)
		])
	
	# Применяем штрафы к чаевым с задержкой
	if total_tip_penalty > 0:
		var tips_before = SaveManager.instance.score
		# Используем метод с задержкой для синхронизации оповещения и звука
		if StatsManager.instance:
			await StatsManager.instance.apply_penalty_with_delay(total_tip_penalty)
		var tips_after = SaveManager.instance.score
		
		# Если чаевые закончились (стали 0) из-за штрафа, отнимаем максимум 1 сердце
		if tips_before > 0 and tips_after == 0 and total_tip_penalty > tips_before:
			EventBus.action_error.emit("unpaid_bets_heart_penalty", "")
			DebugLogger.log("  ❌ Чаевые закончились - отнимается 1 сердце (было %d, штраф %d)" % [tips_before, total_tip_penalty])
	
	DebugLogger.log_separator("ШТРАФЫ ПРИМЕНЕНЫ")


# ═══════════════════════════════════════════════════════════════════════════
# ЗАВЕРШЕНИЕ РАУНДА
# ═══════════════════════════════════════════════════════════════════════════
# Методы для проверки и завершения раунда
# Логика делегирована в GameCompletionCoordinator и RoundCompletionCoordinator

func _can_complete_round() -> bool:
	"""Проверка возможности завершения раунда (нет неоплаченных ставок)

	Returns:
		true если раунд можно завершить, false если есть неоплаченные ставки
	"""
	# Используем координатор для проверки
	var completion_check = round_completion_coordinator.can_complete_round(
		bet_collection_manager, payout_queue_manager
	)
	
	if not completion_check.get("can_complete", false):
		var error_key = completion_check.get("error_key", "")
		var error_type = completion_check.get("error_type", "")
		var reasons = completion_check.get("reasons", [])
		
		# Если есть неоплаченные выигрышные ставки - применяем штрафы вместо отнятия сердца
		if error_type == "unpaid_bets" or (error_type == "incomplete_bets" and reasons.has("unpaid_winnings")):
			_apply_penalties_for_unpaid_bets()
			if not error_key.is_empty():
				EventBus.show_toast_error.emit(Localization.t(error_key))
			ui.disable_action_button()
			DebugLogger.log("🔒 Кнопка 'Завершить' дезактивирована (причины: %s)" % str(reasons))
			return false
		
		# Для других ошибок - обычная логика (отнимаем сердце)
		if not error_key.is_empty():
			EventBus.show_toast_error.emit(Localization.t(error_key))
		EventBus.action_error.emit(error_type, error_key)
		ui.disable_action_button()
		DebugLogger.log("🔒 Кнопка 'Завершить' дезактивирована (причины: %s)" % str(reasons))
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

	# Используем координатор для получения инструкций
	var is_survival_mode = SaveManager.instance.load_survival_mode()
	var instructions = round_completion_coordinator.get_completion_instructions(
		has_active_heart_bet(), is_survival_mode
	)
	
	# Используем исполнитель для выполнения действий
	if not table_preparation_executor:
		DebugLogger.log_error("❌ TablePreparationExecutor не инициализирован!")
		return
	
	DebugLogger.log_separator("ВСЕ ВЫПЛАТЫ ОПЛАЧЕНЫ → ПОДГОТОВКА К НОВОЙ ИГРЕ")
	
	# ВАЖНО: Сохраняем список активных гостей ДО проверки балансов и возврата
	# Это нужно, чтобы генерировать ставки только для гостей, которые были активны
	# в конце предыдущего раунда, а не для тех, кто только что вернулся
	var active_guests_before_preparation: Array[int] = []
	if GuestSettingsManager:
		active_guests_before_preparation = GuestSettingsManager.get_active_guests().duplicate()
		DebugLogger.log("📝 GamePhaseManager: сохранен список активных гостей ДО подготовки: %s" % str(active_guests_before_preparation))
	
	# Проверяем балансы гостей и выключаем тех, кто ушел в минус
	# ВАЖНО: Это должно быть ДО эмита all_bets_processed, чтобы GuestProgressionManager
	# видел ушедших гостей в guests_left и не активировал нового гостя преждевременно
	if GuestStatsManager:
		GuestStatsManager.check_guests_balance_at_round_end()
		# Проверяем и обновляем статус богатства после проверки балансов
		GuestStatsManager.check_all_guests_wealth_at_round_end()
	
	# Эмитим сигнал all_bets_processed ПОСЛЕ проверки балансов гостей
	# Это гарантирует, что ушедшие гости уже добавлены в guests_left
	# и GuestProgressionManager правильно учитывает их при проверке
	if EventBus:
		EventBus.all_bets_processed.emit()
		DebugLogger.log("🎯 GamePhaseManager: все ставки обработаны, эмитим all_bets_processed (после проверки балансов гостей)")
	
	# Проверяем возврат гостей перед следующей раздачей (до обновления стола)
	# Гости должны вернуться до того, как стол обновится и они смогут сделать ставки
	# ПРИМЕЧАНИЕ: Основной вызов теперь происходит через сигнал all_bets_processed
	# Этот вызов оставлен как резервный механизм на случай, если сигнал не сработает
	if GuestReturnManager:
		GuestReturnManager.check_guests_return_before_next_round()
	
	var result = table_preparation_executor.execute_preparation_actions(
		instructions,
		resolve_heart_bet,  # Callable для разрешения Heart Bet
		reset,  # Callable для сброса раунда
		_restore_active_bet_chips,  # Callable для восстановления фишек
		_apply_pending_filter_changes,  # Callable для применения фильтров
		active_guests_before_preparation  # Список активных гостей ДО подготовки
	)
	
	# Если Heart Bet был разрешен - не продолжаем
	if not result.get("should_continue", true):
		return
	
	# Устанавливаем флаг подготовки к новой игре
	is_table_prepared = true
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Автоматический показ сердец УБРАН!
	# Теперь игрок сам нажимает на карту шанса чтобы активировать игру на жизнь
	# ═══════════════════════════════════════════════════════════════════
	# if heart_bet_manager and heart_bet_manager.is_available():
	#     start_heart_bet_selection()  # ← СТАРАЯ ЛОГИКА
	
	DebugLogger.log_separator("ПОДГОТОВКА ЗАВЕРШЕНА. Нажмите 'Карты' для новой раздачи")


# DEPRECATED: Метод _show_round_completion_message() перенесен в TablePreparationExecutor._show_completion_message()


# ═══════════════════════════════════════════════════════════════════════════
# ❤️ HEART BET - СТАВКА СЕРДЦЕМ
# ═══════════════════════════════════════════════════════════════════════════

func _check_heart_bet_triggers() -> void:
	"""Проверить триггеры Heart Bet после завершения раунда
	
	Вызывается ПЕРЕД сбросом раунда, чтобы данные о раздаче ещё были доступны.
	"""
	if not heart_bet_coordinator:
		DebugLogger.log_error("❌ HeartBetCoordinator не инициализирован!")
		return
	
	# Используем координатор для получения инструкций
	var instructions = heart_bet_coordinator.get_trigger_check_instructions(EventBus.is_game_active)
	
	if not instructions.get("should_check", false):
		return
	
	# Проверяем триггеры через координатор
	heart_bet_coordinator.check_triggers(instructions)


func start_heart_bet_selection() -> void:
	"""Начать фазу выбора Heart Bet (вызывается при начале раздачи)
	
	Если есть доступный шанс - показывает сердца на столе.
	"""
	if not heart_bet_coordinator:
		return
	
	if heart_bet_coordinator.start_selection():
		DebugLogger.log("❤️ Фаза выбора Heart Bet начата")


func confirm_heart_bet() -> bool:
	"""Подтвердить или отклонить ставку Heart Bet
	
	Вызывается при нажатии кнопки "Начать" если есть ожидающий выбор.
	Returns: true если ставка подтверждена, false если отклонена или не было выбора
	"""
	if not heart_bet_coordinator:
		return false
	
	return heart_bet_coordinator.confirm()


func resolve_heart_bet(actual_winner: String) -> void:
	"""Разрешить ставку Heart Bet (определить результат)

	Вызывается после определения победителя раздачи.
	
	Args:
		actual_winner: Победитель раздачи ("Player", "Banker" или "Tie")
	"""
	if not heart_bet_coordinator:
		DebugLogger.log_error("❌ HeartBetCoordinator не инициализирован!")
		return
	
	if heart_bet_coordinator.resolve(actual_winner):
		DebugLogger.log("❤️ Heart Bet разрешён (winner=%s)" % actual_winner)


func has_active_heart_bet() -> bool:
	"""Проверить, есть ли активная ставка Heart Bet"""
	if not heart_bet_coordinator:
		return false
	return heart_bet_coordinator.has_active_heart_bet()


func has_pending_heart_bet() -> bool:
	"""Проверить, есть ли ожидающий выбор Heart Bet"""
	if not heart_bet_coordinator:
		return false
	return heart_bet_coordinator.has_pending_heart_bet()


# ═══════════════════════════════════════════════════════════════════════════
# 🎴 ТРИГГЕРЫ КАРТ ШАНСА
# ═══════════════════════════════════════════════════════════════════════════

func _check_chance_card_triggers(actual_winner: String) -> void:
	"""Проверить и активировать триггеры карт шанса после определения победителя
	
	Триггеры (проверяются здесь):
	- Heart Card: победа банкира с 6 очками
	- Heart Bet Card: Tie (игалите)
	- Revolver Card: все 6 карт по 0 очков (10, J, Q, K)
	
	Триггеры (проверяются в deal_first_four):
	- Third Card Change: две пары — срабатывает сразу после раздачи
	- Mystery Card: пара тузов — срабатывает сразу после раздачи
	"""
	# Проверяем, включены ли карты шансов
	if not SaveManager.instance.load_chance_cards_enabled():
		print("🎴 _check_chance_card_triggers: карты шансов отключены, пропускаем")
		return
	
	var player_hand = hand_manager.get_player_hand_ref()
	var banker_hand = hand_manager.get_banker_hand_ref()
	
	if player_hand.is_empty() or banker_hand.is_empty():
		print("🎴 _check_chance_card_triggers: руки пустые, пропускаем")
		return
	
	# Используем проверщик для определения триггеров
	var triggers = chance_card_trigger_checker.check_triggers_after_winner(
		actual_winner, player_hand, banker_hand
	)
	
	var player_score = BaccaratRules.hand_value(player_hand)
	var banker_score = BaccaratRules.hand_value(banker_hand)
	print("🎴 Проверка триггеров карт шанса: winner=%s, player=%d, banker=%d" % [actual_winner, player_score, banker_score])
	
	# Эмитим события для активированных триггеров
	if triggers.get("heart_card", false):
		EventBus.heart_card_triggered.emit()
		print("❤️ Heart Card триггер: банкир выиграл с 6!")
	
	if triggers.get("heart_bet_card", false):
		EventBus.heart_bet_card_triggered.emit()
		print("🎰 Heart Bet Card триггер: Tie (игалите)!")
	
	if triggers.get("revolver_card", false):
		EventBus.revolver_card_triggered.emit()
		print("🔫 Revolver Card триггер: все 6 карт по 0 очков!")


# DEPRECATED методы удалены - используются через ChanceCardTriggerChecker
