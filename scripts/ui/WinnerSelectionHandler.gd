# res://scripts/ui/WinnerSelectionHandler.gd
# Обработчик выбора победителя и создания очереди выплат
# Извлечено из GameController для улучшения SRP

class_name WinnerSelectionHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var hand_manager: HandManager
var limits_manager: LimitsManager
var pair_betting_manager: PairBettingManager
var phase_manager: GamePhaseManager
var winner_selection_manager: WinnerSelectionManager
var survival_state: SurvivalStateProvider

# Callbacks для взаимодействия с GameController
var process_payout_queue_callback: Callable
var get_survival_rounds_callback: Callable
var get_tree_callback: Callable

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	p_hand_manager: HandManager,
	p_limits_manager: LimitsManager,
	p_pair_betting_manager: PairBettingManager,
	p_phase_manager: GamePhaseManager,
	p_winner_selection_manager: WinnerSelectionManager,
	p_survival_state: SurvivalStateProvider,
	p_process_payout_queue_callback: Callable,
	p_get_survival_rounds_callback: Callable,
	p_get_tree_callback: Callable
):
	hand_manager = p_hand_manager
	limits_manager = p_limits_manager
	pair_betting_manager = p_pair_betting_manager
	phase_manager = p_phase_manager
	winner_selection_manager = p_winner_selection_manager
	survival_state = p_survival_state
	process_payout_queue_callback = p_process_payout_queue_callback
	get_survival_rounds_callback = p_get_survival_rounds_callback
	get_tree_callback = p_get_tree_callback

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func handle_winner_selected(chosen: String) -> void:
	"""Обработка выбора победителя игроком
	
	Args:
		chosen: Выбранный победитель (Player/Banker/Tie)
	"""
	# Guard 1: Проверка валидности выбора победителя
	if not _is_winner_selection_valid():
		return
	
	var actual = BaccaratRules.get_winner(hand_manager.get_player_hand_ref(), hand_manager.get_banker_hand_ref())
	
	# Guard 2: Неправильный выбор победителя
	if chosen != actual:
		_handle_incorrect_winner_choice()
		return
	
	# Правильный выбор → обработка выплат (async)
	await _handle_correct_winner_choice(actual)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _is_winner_selection_valid() -> bool:
	"""Проверка валидности выбора победителя
	
	Returns:
		true если выбор валиден, false если нет (с эмитом ошибки)
	"""
	if not GameStateManager.is_action_valid(GameStateManager.Action.SELECT_WINNER):
		var error_msg = GameStateManager.get_error_message(GameStateManager.Action.SELECT_WINNER)
		
		# Штраф только если не в состоянии WAITING (карты уже раздавались)
		var current_state = GameStateManager.get_current_state()
		if current_state != GameStateManager.GameState.WAITING:
			EventBus.action_error.emit("winner_early", error_msg)
		
		DebugLogger.log("🚫 [НОВАЯ СИСТЕМА] %s" % error_msg)
		return false
	
	return true

func _handle_incorrect_winner_choice() -> void:
	"""Обработка неправильного выбора победителя"""
	EventBus.action_error.emit("winner_wrong", "")
	# Жизнь отнимается автоматически через EventBus → SurvivalModeUI

func _handle_correct_winner_choice(actual: String) -> void:
	"""Обработка правильного выбора победителя
	
	Args:
		actual: Фактический победитель (Player/Banker/Tie)
	"""
	# ✅ Правильный выбор победителя
	EventBus.action_correct.emit("winner")
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Если это был Heart Bet раунд (даже с отказом) - пропускаем выплаты
	# ═══════════════════════════════════════════════════════════════════
	if phase_manager and phase_manager.was_heart_bet_round:
		print("❤️ WinnerSelectionHandler: был Heart Bet раунд (даже с отказом), пропускаем выплаты")
		# Если была активная ставка - разрешаем её
		if phase_manager.has_active_heart_bet():
			phase_manager.resolve_heart_bet(actual)
		else:
			# Отказ от шанса - просто завершаем раунд без выплат
			# Эмитим сигнал завершения Heart Bet раунда для сброса
			EventBus.heart_bet_round_complete.emit()
		# В любом случае НЕ продолжаем с обычной логикой выплат
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Разрешаем ставку сердцем (если была активна)
	# При активной Heart Bet выплаты не производятся!
	# ═══════════════════════════════════════════════════════════════════
	var has_heart_bet = phase_manager and phase_manager.has_active_heart_bet()
	print("❤️ WinnerSelectionHandler: has_active_heart_bet = %s" % has_heart_bet)
	
	if has_heart_bet:
		print("❤️ WinnerSelectionHandler: вызываем resolve_heart_bet(%s)" % actual)
		phase_manager.resolve_heart_bet(actual)
		# Раунд сбросится через heart_bet_round_complete в EventBus
		# НЕ продолжаем с выплатами - это особая раздача на жизнь
		return
	
	# Блокируем маркеры, чтобы игрок не мог случайно изменить выбор во время выплат
	if winner_selection_manager:
		winner_selection_manager.lock_markers()
	
	# Пауза 1 секунда (карты остаются открытыми, маркер активен)
	var tree = get_tree_callback.call()
	if tree:
		await tree.create_timer(GameConstants.VICTORY_TOAST_DELAY).timeout
	
	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ВАЛИДНОСТИ ПОСЛЕ AWAIT (защита от race conditions)
	# ═══════════════════════════════════════════════════════════════════
	# Проверяем что менеджеры всё ещё инициализированы
	if not hand_manager or not limits_manager:
		push_error("❌ Критические менеджеры не инициализированы после await!")
		return
	
	# Проверяем что руки не пустые (игра не была сброшена)
	var player_hand = hand_manager.get_player_hand_ref()
	var banker_hand = hand_manager.get_banker_hand_ref()
	if player_hand.is_empty() or banker_hand.is_empty():
		DebugLogger.log("⚠️  Руки пустые после await, возможно раунд был сброшен")
		return
	
	# Создаём очередь выплат
	_create_payout_queue(actual)
	
	# Обрабатываем очередь или сбрасываем раунд
	if process_payout_queue_callback.is_valid():
		process_payout_queue_callback.call()

func _create_payout_queue(actual: String) -> void:
	"""Создание очереди выплат (основная ставка + пары)
	
	Args:
		actual: Фактический победитель (Player/Banker/Tie)
	"""
	var player_score = BaccaratRules.hand_value(hand_manager.get_player_hand_ref())
	var banker_score = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	# Очищаем очередь перед созданием новой
	GameDataManager.clear_payout_queue()
	
	# 1. Добавляем основную ставку (если активна)
	_add_main_bet_to_queue(actual, player_score, banker_score)
	
	# 2. Добавляем ставки на пары (если обнаружены)
	_add_pair_bets_to_queue(player_score, banker_score)
	
	# Выводим статус очереди
	GameDataManager.print_queue_status()

func _add_main_bet_to_queue(actual: String, player_score: int, banker_score: int) -> void:
	"""Добавление основной ставки в очередь (Player/Banker/Tie)
	
	Рефакторено: использует IBetType вместо match bet_type (OCP)
	
	Args:
		actual: Фактический победитель
		player_score: Очки игрока
		banker_score: Очки банкира
	"""
	var bet_type = BetTypeFactory.create(actual)
	if not bet_type:
		return
	
	if not PayoutSettingsManager.is_payout_enabled(actual):
		return
	
	var stake = bet_type.get_stake(limits_manager)
	var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	var payout_calculator = PayoutCalculator.new()
	var payout = payout_calculator.calculate(
		bet_type, 
		stake, 
		actual,
		pair_betting_manager.has_player_pair() if pair_betting_manager else false,
		pair_betting_manager.has_banker_pair() if pair_betting_manager else false,
		banker_value
	)
	
	GameDataManager.add_to_payout_queue(actual, stake, payout, player_score, banker_score)

func _add_pair_bets_to_queue(player_score: int, banker_score: int) -> void:
	"""Добавление ставок на пары в очередь выплат
	
	Рефакторено: использует IBetType вместо прямых проверок (OCP)
	
	Args:
		player_score: Очки игрока
		banker_score: Очки банкира
	"""
	if not pair_betting_manager:
		return
	
	var payout_calculator = PayoutCalculator.new()
	
	# Пара игрока - если обнаружена И ставка была
	if pair_betting_manager.has_player_pair() and pair_betting_manager.is_player_pair_bet_enabled():
		var bet_type = BetTypeFactory.create("PairPlayer")
		var stake = bet_type.get_stake(limits_manager)
		var payout = payout_calculator.calculate_pair_payout(bet_type, stake, pair_betting_manager)
		GameDataManager.add_to_payout_queue("PairPlayer", stake, payout, player_score, banker_score)
	
	# Пара банкира - если обнаружена И ставка была
	if pair_betting_manager.has_banker_pair() and pair_betting_manager.is_banker_pair_bet_enabled():
		var bet_type = BetTypeFactory.create("PairBanker")
		var stake = bet_type.get_stake(limits_manager)
		var payout = payout_calculator.calculate_pair_payout(bet_type, stake, pair_betting_manager)
		GameDataManager.add_to_payout_queue("PairBanker", stake, payout, player_score, banker_score)

