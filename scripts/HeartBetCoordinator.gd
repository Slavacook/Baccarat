# res://scripts/HeartBetCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР HEART BET
# Координирует все действия, связанные с Heart Bet (ставка сердцем)
# ═══════════════════════════════════════════════════════════════════════════

class_name HeartBetCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var heart_bet_manager: HeartBetManager = null
var hand_manager: HandManager = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	heart_bet_manager_ref: HeartBetManager = null,
	hand_manager_ref: HandManager = null
):
	heart_bet_manager = heart_bet_manager_ref
	hand_manager = hand_manager_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func has_active_heart_bet() -> bool:
	"""Проверить, есть ли активная ставка Heart Bet"""
	if not heart_bet_manager:
		return false
	return heart_bet_manager.is_active()

func has_pending_heart_bet() -> bool:
	"""Проверить, есть ли ожидающий выбор Heart Bet"""
	if not heart_bet_manager:
		return false
	return heart_bet_manager.is_pending() or heart_bet_manager.is_selected()

func is_available() -> bool:
	"""Проверить, доступен ли Heart Bet"""
	if not heart_bet_manager:
		return false
	return heart_bet_manager.is_available()

# ═══════════════════════════════════════════════════════════════════════════
# ДЕЙСТВИЯ
# ═══════════════════════════════════════════════════════════════════════════

func start_selection() -> bool:
	"""Начать фазу выбора Heart Bet
	
	Returns:
		true если фаза начата, false если Heart Bet недоступен
	"""
	if not is_available():
		return false
	
	heart_bet_manager.start_selection_phase()
	return true

func confirm() -> bool:
	"""Подтвердить или отклонить ставку Heart Bet
	
	Returns:
		true если ставка подтверждена, false если отклонена или не было выбора
	"""
	if not has_pending_heart_bet():
		return false
	
	return heart_bet_manager.confirm()

func resolve(actual_winner: String) -> bool:
	"""Разрешить ставку Heart Bet (определить результат)
	
	Args:
		actual_winner: Победитель раздачи ("Player", "Banker" или "Tie")
		
	Returns:
		true если ставка разрешена, false если нет активной ставки
	"""
	# Валидация параметра
	if actual_winner.is_empty():
		return false
	
	if actual_winner not in ["Player", "Banker", "Tie"]:
		return false
	
	if not has_active_heart_bet():
		return false
	
	heart_bet_manager.resolve(actual_winner)
	return true

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ТРИГГЕРОВ
# ═══════════════════════════════════════════════════════════════════════════

func get_trigger_check_instructions(
	is_game_active: bool
) -> Dictionary:
	"""Получить инструкции для проверки триггеров Heart Bet
	
	Args:
		is_game_active: Активна ли игра
		
	Returns:
		Dictionary с инструкциями:
		{
			"should_check": bool,  # Нужно ли проверять триггеры
			"winner": String,  # Победитель раздачи
			"player_score": int,  # Очки игрока
			"banker_score": int,  # Очки банкира
			"is_natural": bool  # Натуральная раздача
		}
	"""
	# ПРОВЕРКА: Если Game Over - не проверяем триггеры
	if not is_game_active:
		return {
			"should_check": false,
			"winner": "",
			"player_score": 0,
			"banker_score": 0,
			"is_natural": false
		}
	
	if not heart_bet_manager:
		return {
			"should_check": false,
			"winner": "",
			"player_score": 0,
			"banker_score": 0,
			"is_natural": false
		}
	
	# Получаем данные о завершённом раунде
	var winner = TableStateManager.get_actual_winner()
	
	if winner.is_empty():
		return {
			"should_check": false,
			"winner": "",
			"player_score": 0,
			"banker_score": 0,
			"is_natural": false
		}
	
	# Вычисляем очки
	if not hand_manager:
		return {
			"should_check": false,
			"winner": winner,
			"player_score": 0,
			"banker_score": 0,
			"is_natural": false
		}
	
	var player_hand = hand_manager.get_player_hand_ref()
	var banker_hand = hand_manager.get_banker_hand_ref()
	
	if player_hand.is_empty() or banker_hand.is_empty():
		return {
			"should_check": false,
			"winner": winner,
			"player_score": 0,
			"banker_score": 0,
			"is_natural": false
		}
	
	var player_score = BaccaratRules.hand_value(player_hand)
	var banker_score = BaccaratRules.hand_value(banker_hand)
	var is_natural = BaccaratRules.is_natural(player_hand) or BaccaratRules.is_natural(banker_hand)
	
	return {
		"should_check": true,
		"winner": winner,
		"player_score": player_score,
		"banker_score": banker_score,
		"is_natural": is_natural
	}

func check_triggers(instructions: Dictionary) -> void:
	"""Проверить триггеры Heart Bet на основе инструкций
	
	Args:
		instructions: Инструкции от get_trigger_check_instructions()
	"""
	if not instructions.get("should_check", false):
		return
	
	var winner = instructions.get("winner", "")
	var banker_score = instructions.get("banker_score", 0)
	var player_score = instructions.get("player_score", 0)
	var is_natural = instructions.get("is_natural", false)
	
	# HeartBetManager.check_triggers() уже эмитит EventBus.heart_bet_trigger_activated,
	# поэтому просто вызываем его - карта покажется автоматически через ChanceCardManager
	heart_bet_manager.check_triggers(winner, banker_score, player_score, is_natural)

