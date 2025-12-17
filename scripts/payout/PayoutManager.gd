# res://scripts/payout/PayoutManager.gd
# Менеджер выплат (SRP - единственная ответственность: подготовка и управление выплатами)

class_name PayoutManager
extends RefCounted

var payout_queue_manager: PayoutQueueManager
var bet_collection_manager: BetCollectionPhaseManager
var chip_visual_manager: ChipVisualManager
var limits_manager: LimitsManager
var pair_betting_manager: PairBettingManager
var hand_manager: HandManager
var payout_calculator: PayoutCalculator
var settings_provider: IPayoutSettingsProvider
var guest_bet_storage: GuestBetStorage = null

func _init(
	queue_manager: PayoutQueueManager,
	collection_manager: BetCollectionPhaseManager,
	chip_manager: ChipVisualManager,
	limits_mgr: LimitsManager,
	pair_mgr: PairBettingManager,
	hand_mgr: HandManager,
	settings: IPayoutSettingsProvider = null,
	guest_storage: GuestBetStorage = null
):
	payout_queue_manager = queue_manager
	bet_collection_manager = collection_manager
	chip_visual_manager = chip_manager
	limits_manager = limits_mgr
	pair_betting_manager = pair_mgr
	hand_manager = hand_mgr
	payout_calculator = PayoutCalculator.new()
	settings_provider = settings if settings else PayoutSettingsProvider.new()
	guest_bet_storage = guest_storage

## Подготовка выплат в ручном режиме
func prepare_manual_payouts(actual_winner: String, ui_manager: UIManager) -> void:
	"""Подготовка выплат в ручном режиме"""
	var player_score = BaccaratRules.hand_value(hand_manager.get_player_hand_ref())
	var banker_score = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	# ═══════════════════════════════════════════════════════════════════
	# ШАГ 1: Подготавливаем выплаты (добавляем ставки в очередь)
	# ═══════════════════════════════════════════════════════════════════
	# В режиме GUEST обычные ставки не используются - только гостевые
	# Но оставляем _prepare_standard_payouts для обратной совместимости
	# (если в будущем понадобятся обычные ставки)
	_prepare_standard_payouts(actual_winner, player_score, banker_score)
	
	# Добавляем гостевые ставки (основной источник ставок в режиме GUEST)
	_prepare_guest_bets(actual_winner, player_score, banker_score)
	
	# Выводим статус очереди
	payout_queue_manager.print_status()
	
	# ═══════════════════════════════════════════════════════════════════
	# ШАГ 2: Настраиваем менеджер фазы сбора/оплаты ПОСЛЕ добавления всех ставок
	# setup() автоматически вызовет initialize_sequences() внутри
	# ═══════════════════════════════════════════════════════════════════
	bet_collection_manager.setup(payout_queue_manager, actual_winner)
	DebugLogger.log("✅ BetCollectionPhaseManager: настроен для раунда (победитель: %s)" % actual_winner)
	
	# ═══════════════════════════════════════════════════════════════════
	# ШАГ 3: Показываем кнопки collect/pay ПОСЛЕ setup()
	# show_collect_pay_buttons() автоматически активирует режим COLLECT
	# ═══════════════════════════════════════════════════════════════════
	ui_manager.button_ui.show_collect_pay_buttons()

func _prepare_standard_payouts(_actual_winner: String, _player_score: int, _banker_score: int) -> void:
	"""Подготовка стандартных выплат (deprecated в режиме GUEST)
	
	В режиме GUEST обычные ставки не используются - только гостевые.
	Этот метод оставлен для обратной совместимости, но не добавляет ставки.
	"""
	# В режиме GUEST обычные ставки не используются
	# Все ставки создаются через гостей
	DebugLogger.log("💰 Режим GUEST: стандартные ставки не используются (только гостевые)")

func _prepare_realistic_payouts(_actual_winner: String, _player_score: int, _banker_score: int) -> void:
	"""Подготовка выплат в REALISTIC режиме (deprecated)
	
	В режиме GUEST этот метод не используется.
	Все ставки создаются через гостей.
	"""
	DebugLogger.log("💰 Режим GUEST: _prepare_realistic_payouts не используется")

func _calculate_payout_for_bet_type(_bet_type_name: String, bet_type: IBetType, stake: float, won: bool, actual_winner: String) -> float:
	"""Расчёт выплаты для типа ставки
	
	Args:
		_bet_type_name: Название типа ставки (не используется, но нужен для совместимости)
		bet_type: Объект типа ставки
		stake: Размер ставки
		won: Выиграла ли ставка
		actual_winner: Фактический победитель раунда (важно для правильного расчета!)
	"""
	if not won:
		return 0.0
	
	var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	# Для пар используем специальную логику
	if bet_type.get_group() == "pairs" and pair_betting_manager:
		return payout_calculator.calculate_pair_payout(bet_type, stake, pair_betting_manager)
	
	# Для остальных используем стандартный расчет с правильным actual_winner
	# ВАЖНО: actual_winner нужен для проверки is_winner() в PayoutCalculator
	return payout_calculator.calculate(
		bet_type,
		stake,
		actual_winner,
		pair_betting_manager.player_pair_detected if pair_betting_manager else false,
		pair_betting_manager.banker_pair_detected if pair_betting_manager else false,
		banker_value
	)

func _is_bet_enabled(bet_type_name: String) -> bool:
	"""Проверка, включена ли ставка в настройках"""
	match bet_type_name:
		"Player":
			return settings_provider.is_player_enabled()
		"Banker":
			return settings_provider.is_banker_enabled()
		"Tie":
			return settings_provider.is_tie_enabled()
		"PairPlayer":
			return pair_betting_manager and pair_betting_manager.pair_player_bet_enabled
		"PairBanker":
			return pair_betting_manager and pair_betting_manager.pair_banker_bet_enabled
		_:
			return false

func _prepare_guest_bets(actual_winner: String, player_score: int, banker_score: int) -> void:
	"""Добавить гостевые ставки в очередь выплат
	
	Гостевые ставки уже сгенерированы и сохранены в guest_bet_storage.
	Здесь мы добавляем их в PayoutQueueManager с расчётом выплат.
	"""
	if not guest_bet_storage:
		return
	
	var guests_with_bets = guest_bet_storage.get_guests_with_bets()
	if guests_with_bets.is_empty():
		DebugLogger.log("👥 Нет гостевых ставок для добавления в очередь")
		return
	
	DebugLogger.log("👥 Добавление ставок %d гостей в очередь выплат..." % guests_with_bets.size())
	
	var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	for guest_id in guests_with_bets:
		var bets = guest_bet_storage.get_guest_bets(guest_id)
		for bet in bets:
			# Определяем выиграла ли ставка
			var bet_type_obj = BetTypeFactory.create(bet.bet_type)
			if not bet_type_obj:
				continue
			
			var won = bet_type_obj.is_winner(
				actual_winner,
				pair_betting_manager.player_pair_detected if pair_betting_manager else false,
				pair_betting_manager.banker_pair_detected if pair_betting_manager else false
			)
			
			# Рассчитываем выплату
			var payout = 0.0
			if won:
				if bet_type_obj.get_group() == "pairs" and pair_betting_manager:
					payout = payout_calculator.calculate_pair_payout(bet_type_obj, bet.stake, pair_betting_manager)
				else:
					payout = payout_calculator.calculate(
						bet_type_obj,
						bet.stake,
						actual_winner,
						pair_betting_manager.player_pair_detected if pair_betting_manager else false,
						pair_betting_manager.banker_pair_detected if pair_betting_manager else false,
						banker_value
					)
			
			# Добавляем ставку в очередь
			payout_queue_manager.add_bet(
				bet.bet_type,
				bet.stake,
				payout,
				won,
				player_score,
				banker_score,
				bet.position_index
			)
			
			DebugLogger.log("  → Гость %d: %s ставка %.0f (won=%s, payout=%.0f)" % [guest_id, bet.bet_type, bet.stake, won, payout])
	
	DebugLogger.log("👥 Добавлено %d гостевых ставок в очередь" % guest_bet_storage.get_all_bets().size())
