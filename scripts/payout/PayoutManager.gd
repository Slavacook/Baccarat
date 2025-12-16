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

func _init(
	queue_manager: PayoutQueueManager,
	collection_manager: BetCollectionPhaseManager,
	chip_manager: ChipVisualManager,
	limits_mgr: LimitsManager,
	pair_mgr: PairBettingManager,
	hand_mgr: HandManager,
	settings: IPayoutSettingsProvider = null
):
	payout_queue_manager = queue_manager
	bet_collection_manager = collection_manager
	chip_visual_manager = chip_manager
	limits_manager = limits_mgr
	pair_betting_manager = pair_mgr
	hand_manager = hand_mgr
	payout_calculator = PayoutCalculator.new()
	settings_provider = settings if settings else PayoutSettingsProvider.new()

## Подготовка выплат в ручном режиме
func prepare_manual_payouts(actual_winner: String, ui_manager: UIManager) -> void:
	"""Подготовка выплат в ручном режиме"""
	var player_score = BaccaratRules.hand_value(hand_manager.get_player_hand_ref())
	var banker_score = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	# ═══════════════════════════════════════════════════════════════════
	# ШАГ 1: Подготавливаем выплаты (добавляем ставки в очередь)
	# ═══════════════════════════════════════════════════════════════════
	var is_realistic = settings_provider.is_realistic_mode_enabled()
	if is_realistic:
		_prepare_realistic_payouts(actual_winner, player_score, banker_score)
	else:
		_prepare_standard_payouts(actual_winner, player_score, banker_score)
	
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

func _prepare_standard_payouts(actual_winner: String, player_score: int, banker_score: int) -> void:
	"""Стандартная подготовка выплат (DEFAULT, RANDOM, MAX режимы)"""
	var is_max_mode = settings_provider.get_position_mode() == PayoutSettingsManager.PositionMode.MAX
	var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	# Получаем все типы ставок из фабрики
	var all_bet_types = BetTypeFactory.get_all_types()
	
	for bet_type_name in all_bet_types:
		var bet_type = BetTypeFactory.create(bet_type_name)
		if not bet_type:
			continue
		
		# Проверяем, включена ли ставка
		if not _is_bet_enabled(bet_type_name):
			continue
		
		# Определяем выиграла ли ставка
		var won = bet_type.is_winner(
			actual_winner,
			pair_betting_manager.player_pair_detected if pair_betting_manager else false,
			pair_betting_manager.banker_pair_detected if pair_betting_manager else false
		)
		
		# Генерируем ставку и выплату
		var stake = bet_type.get_stake(limits_manager)
		var payout = 0.0
		
		if won:
			if bet_type.get_group() == "pairs" and pair_betting_manager:
				payout = payout_calculator.calculate_pair_payout(bet_type, stake, pair_betting_manager)
			else:
				payout = payout_calculator.calculate(
					bet_type,
					stake,
					actual_winner,
					pair_betting_manager.player_pair_detected if pair_betting_manager else false,
					pair_betting_manager.banker_pair_detected if pair_betting_manager else false,
					banker_value
				)
		
		# Добавляем ставку (в MAX режиме для всех позиций)
		if is_max_mode:
			var positions = ChipVisualManager.ALTERNATIVE_POSITIONS.get(bet_type_name, [])
			for pos_idx in range(positions.size()):
				payout_queue_manager.add_bet(bet_type_name, stake, payout, won, player_score, banker_score, pos_idx)
		else:
			payout_queue_manager.add_bet(bet_type_name, stake, payout, won, player_score, banker_score, 0)

func _prepare_realistic_payouts(actual_winner: String, player_score: int, banker_score: int) -> void:
	"""Подготовка выплат в REALISTIC режиме"""
	DebugLogger.log_bet("REALISTIC режим: генерируем случайные ставки...")
	
	# Очищаем все активные фишки перед созданием новых
	if chip_visual_manager:
		chip_visual_manager.clear_all_active_chips()
	
	# Генерируем ставки для каждого типа
	var bet_type_names = BetTypeFactory.get_all_types()
	
	for bet_type_name in bet_type_names:
		var bet_type = BetTypeFactory.create(bet_type_name)
		if not bet_type:
			continue
		
		# Проверяем, включена ли ставка
		if not _is_bet_enabled(bet_type_name):
			continue
		
		# Определяем выиграла ли ставка этого типа
		var won = bet_type.is_winner(
			actual_winner,
			pair_betting_manager.player_pair_detected if pair_betting_manager else false,
			pair_betting_manager.banker_pair_detected if pair_betting_manager else false
		)
		
		# Создаём фишки в REALISTIC режиме
		var created_chips = chip_visual_manager.show_chips_realistic(bet_type_name)
		
		# Для каждой созданной фишки добавляем ставку в очередь
		for chip_instance in created_chips:
			var stake = bet_type.get_stake(limits_manager)
			var payout = _calculate_payout_for_bet_type(bet_type_name, bet_type, stake, won, actual_winner)
			
			payout_queue_manager.add_bet(
				bet_type_name, 
				stake, 
				payout, 
				won, 
				player_score, 
				banker_score, 
				chip_instance.position_index
			)
		
		DebugLogger.log("  %s: создано %d ставок (won=%s)" % [bet_type_name, created_chips.size(), won])

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
