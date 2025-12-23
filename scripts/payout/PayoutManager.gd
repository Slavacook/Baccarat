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
var phase_manager: GamePhaseManager = null  # Для доступа к snapshot фильтра

func _init(
	queue_manager: PayoutQueueManager,
	collection_manager: BetCollectionPhaseManager,
	chip_manager: ChipVisualManager,
	limits_mgr: LimitsManager,
	pair_mgr: PairBettingManager,
	hand_mgr: HandManager,
	settings: IPayoutSettingsProvider = null,
	guest_storage: GuestBetStorage = null,
	phase_mgr: GamePhaseManager = null
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
	phase_manager = phase_mgr

## Подготовка выплат в ручном режиме
func prepare_manual_payouts(actual_winner: String) -> void:
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
	
	# Добавляем гостевые ставки в очередь
	_prepare_guest_bets(actual_winner, player_score, banker_score)
	
	# Overlay показывается автоматически при клике на фишку в GameController
	# Здесь мы только подготавливаем очередь выплат

func _prepare_standard_payouts(_actual_winner: String, _player_score: int, _banker_score: int) -> void:
	"""Подготовка стандартных выплат (Player/Banker/Tie)
	
	В режиме GUEST этот метод не используется, но оставлен для обратной совместимости.
	"""
	# В режиме GUEST обычные ставки не используются
	# Все ставки генерируются через гостей
	pass

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
			return pair_betting_manager and pair_betting_manager.is_player_pair_bet_enabled()
		"PairBanker":
			return pair_betting_manager and pair_betting_manager.is_banker_pair_bet_enabled()
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
			# ═══════════════════════════════════════════════════════════════════
			# ФИЛЬТР НАСТРОЕК: Добавляем в очередь только ставки из snapshot
			# Snapshot сохраняется при показке ставок и изолирует текущую раздачу
			# ═══════════════════════════════════════════════════════════════════
			var bet_type = bet.get_bet_type()
			var pos_idx = bet.get_position_index()
			
			# Проверяем через snapshot фильтра (если доступен phase_manager)
			if phase_manager:
				if not phase_manager.is_bet_type_enabled_in_snapshot(bet_type):
					DebugLogger.log("  → Гость %d: ставка %s[%d] отфильтрована (выключена в snapshot)" % [guest_id, bet_type, pos_idx])
					continue
			else:
				# Fallback: проверяем наличие фишки на столе
				var chip_instance = chip_visual_manager.get_chip_instance(bet_type, pos_idx)
				if not chip_instance:
					DebugLogger.log("  → Гость %d: ставка %s[%d] отфильтрована (нет фишки на столе)" % [guest_id, bet_type, pos_idx])
					continue
			
			# Определяем выиграла ли ставка
			var bet_type_obj = BetTypeFactory.create(bet_type)
			if not bet_type_obj:
				continue
			
			var won = bet_type_obj.is_winner(
				actual_winner,
				pair_betting_manager.has_player_pair() if pair_betting_manager else false,
				pair_betting_manager.has_banker_pair() if pair_betting_manager else false
			)
			
			# Рассчитываем выплату
			var payout = 0.0
			if won:
				if bet_type_obj.get_group() == "pairs" and pair_betting_manager:
					payout = payout_calculator.calculate_pair_payout(bet_type_obj, bet.get_stake(), pair_betting_manager)
				else:
					payout = payout_calculator.calculate(
						bet_type_obj,
						bet.get_stake(),
						actual_winner,
						pair_betting_manager.has_player_pair() if pair_betting_manager else false,
						pair_betting_manager.has_banker_pair() if pair_betting_manager else false,
						banker_value
					)
			
			# Добавляем ставку в очередь (сохраняем guest_id и sector для гостевых ставок)
			payout_queue_manager.add_bet(
				bet.get_bet_type(),
				bet.get_stake(),
				payout,
				won,
				player_score,
				banker_score,
				bet.get_position_index(),
				bet.get_guest_id(),
				bet.get_sector()
			)
			
			DebugLogger.log("  → Гость %d: %s ставка %.0f (won=%s, payout=%.0f)" % [guest_id, bet.get_bet_type(), bet.get_stake(), won, payout])
	
	DebugLogger.log("👥 Добавлено %d гостевых ставок в очередь" % guest_bet_storage.get_all_bets().size())
