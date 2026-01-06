# res://scripts/utils/PayoutPreparationHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК ПОДГОТОВКИ ВЫПЛАТ
# 
# Отвечает за:
# - Подготовку выплат в ручном режиме
# - Генерацию размера ставок
# - Расчет выплат для типов ставок
# - Форматирование результатов раздачи
# ═══════════════════════════════════════════════════════════════════════════

class_name PayoutPreparationHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var hand_manager: HandManager
var limits_manager: LimitsManager
var pair_betting_manager: PairBettingManager
var payout_queue_handler: PayoutQueueHandler

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	hand_mgr: HandManager,
	limits_mgr: LimitsManager,
	pair_mgr: PairBettingManager,
	queue_handler: PayoutQueueHandler
) -> void:
	"""Инициализировать обработчик подготовки выплат
	
	Args:
		hand_mgr: Менеджер рук
		limits_mgr: Менеджер лимитов
		pair_mgr: Менеджер парных ставок
		queue_handler: Обработчик очереди выплат
	"""
	hand_manager = hand_mgr
	limits_manager = limits_mgr
	pair_betting_manager = pair_mgr
	payout_queue_handler = queue_handler

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func prepare_payouts_manual(actual_winner: String) -> PayoutQueueManager:
	"""Подготовка выплат в ручном режиме (без автоматического перехода к сцене)
	
	Args:
		actual_winner: Реальный победитель раздачи
		
	Returns:
		Обновленный payout_queue_manager
	"""
	if payout_queue_handler:
		payout_queue_handler.prepare_payouts_manual(actual_winner)
		# Возвращаем обновленный менеджер
		if payout_queue_handler.payout_queue_manager:
			return payout_queue_handler.payout_queue_manager
	else:
		push_error("❌ PayoutQueueHandler не инициализирован!")
		return null

func finalize_payouts_manual(actual_winner: String) -> void:
	"""Завершение подготовки выплат - обновление видимости и сохранение состояния
	
	Args:
		actual_winner: Реальный победитель раздачи
	"""
	if payout_queue_handler:
		payout_queue_handler.finalize_payouts_manual(actual_winner)
	else:
		push_error("❌ PayoutQueueHandler не инициализирован!")

func generate_stake_for_bet_type(bet_type: String) -> float:
	"""Генерация размера ставки для типа
	
	Args:
		bet_type: Тип ставки (например, "Player", "Banker", "Tie")
	
	Returns:
		Размер ставки для данного типа (с учетом лимитов стола)
	
	Рефакторено: использует IBetType вместо match (OCP)
	"""
	var bet_type_obj = BetTypeFactory.create(bet_type)
	if not bet_type_obj:
		return 0.0
	return bet_type_obj.get_stake(limits_manager)

func calculate_payout_for_bet_type(bet_type: String, stake: float, won: bool) -> float:
	"""Расчёт выплаты для типа ставки
	
	Args:
		bet_type: Тип ставки (например, "Player", "Banker", "Tie", "PlayerPair")
		stake: Размер ставки
		won: Выиграла ли ставка
	
	Returns:
		Размер выплаты (0.0 если ставка проиграла)
	
	Рефакторено: использует PayoutCalculator вместо match (OCP, SRP)
	"""
	if not won:
		return 0.0
	
	var bet_type_obj = BetTypeFactory.create(bet_type)
	if not bet_type_obj:
		return 0.0
	
	var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	var payout_calculator = PayoutCalculator.new()
	
	# Для пар используем специальную логику
	if bet_type_obj.get_group() == GameConstants.BET_GROUP_PAIRS and pair_betting_manager:
		return payout_calculator.calculate_pair_payout(bet_type_obj, stake, pair_betting_manager)
	
	# Для остальных используем стандартный расчет
	# actual_winner нужен для проверки is_winner, но здесь мы уже знаем что won=true
	var actual_winner = "Player"  # Значение не важно, т.к. won уже проверен
	return payout_calculator.calculate(
		bet_type_obj,
		stake, 
		actual_winner,
		pair_betting_manager.has_player_pair() if pair_betting_manager else false,
		pair_betting_manager.has_banker_pair() if pair_betting_manager else false,
		banker_value
	)

func format_result() -> String:
	"""Форматирование результата раздачи для отображения
	
	Returns:
		Строка с результатом (например, "Натуральная 9 против 8" или "7 против 5")
	"""
	var p0 = BaccaratRules.hand_value([hand_manager.get_player_hand_ref()[0], hand_manager.get_player_hand_ref()[1]])
	var b0 = BaccaratRules.hand_value([hand_manager.get_banker_hand_ref()[0], hand_manager.get_banker_hand_ref()[1]])
	if p0 >= 8 or b0 >= 8:
		return "Натуральная %d против %d" % [p0 if p0 >= 8 else b0, b0 if p0 >= 8 else p0]
	return "%d против %d" % [BaccaratRules.hand_value(hand_manager.get_banker_hand_ref()), BaccaratRules.hand_value(hand_manager.get_player_hand_ref())]

func format_victory_toast(winner: String) -> String:
	"""Форматирование краткого тоста победы (например, 'Выигрывает Банкир: 7 vs 5')
	
	Args:
		winner: Победитель раздачи ("Player", "Banker", "Tie")
		
	Returns:
		Отформатированная строка с результатом
	"""
	var player_score = BaccaratRules.hand_value(hand_manager.get_player_hand_ref())
	var banker_score = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())

	match winner:
		"Banker":
			return Localization.t("VICTORY_BANKER", [banker_score, player_score])
		"Player":
			return Localization.t("VICTORY_PLAYER", [player_score, banker_score])
		"Tie":
			return Localization.t("VICTORY_TIE")  # Без параметров
		_:
			return "???"

