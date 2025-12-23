# res://scripts/WinnerSelectionCoordinator.gd
# Координатор валидации выбора победителя
# Координирует процесс валидации, сохранения победителя и проверки триггеров

class_name WinnerSelectionCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var winner_validator: WinnerSelectionValidator = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(validator: WinnerSelectionValidator = null):
	winner_validator = validator

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_validation_instructions(
	selected_winner: String,
	player_hand: Array[Card],
	banker_hand: Array[Card],
	is_survival_mode: bool,
	was_heart_bet_round: bool,
	has_active_heart_bet: bool
) -> Dictionary:
	"""Получить инструкции для валидации выбора победителя
	
	Args:
		selected_winner: Выбранный победитель ("Player"/"Banker"/"Tie" или "")
		player_hand: Рука игрока
		banker_hand: Рука банкира
		is_survival_mode: Режим выживания включен
		was_heart_bet_round: Был ли Heart Bet раунд
		has_active_heart_bet: Есть ли активная Heart Bet ставка
		
	Returns:
		Dictionary с полями:
		- needs_selection: bool - нужно ли выбрать победителя
		- validation_result: Dictionary - результат валидации от WinnerSelectionValidator
		- actual_winner: String - фактический победитель (если определен)
		- should_save_winner: bool - нужно ли сохранить победителя в TableStateManager
		- should_check_heart_bet_triggers: bool - нужно ли проверить триггеры Heart Bet
		- heart_bet_trigger_data: Dictionary - данные для проверки триггеров (если нужно)
		  {winner: String, banker_score: int, player_score: int, is_natural: bool}
	"""
	var instructions = {
		"needs_selection": false,
		"validation_result": {},
		"actual_winner": "",
		"should_save_winner": false,
		"should_check_heart_bet_triggers": false,
		"heart_bet_trigger_data": {}
	}
	
	# Если нет валидатора - возвращаем пустые инструкции
	if not winner_validator:
		return instructions
	
	# Валидируем выбор победителя
	var validation_result = winner_validator.validate_winner_selection(
		selected_winner, player_hand, banker_hand
	)
	instructions["validation_result"] = validation_result
	
	# Не выбран ни один маркер?
	if validation_result.get("needs_selection", false):
		instructions["needs_selection"] = true
		return instructions
	
	# Получаем фактического победителя
	var actual_winner = validation_result.get("actual_winner", "")
	instructions["actual_winner"] = actual_winner
	instructions["should_save_winner"] = true
	
	# Проверяем нужно ли проверить триггеры Heart Bet
	# Только в режиме выживания, если не был Heart Bet раунд и нет активной ставки
	if is_survival_mode and not was_heart_bet_round and not has_active_heart_bet:
		if not player_hand.is_empty() and not banker_hand.is_empty():
			instructions["should_check_heart_bet_triggers"] = true
			var player_score = BaccaratRules.hand_value(player_hand)
			var banker_score = BaccaratRules.hand_value(banker_hand)
			var is_natural = BaccaratRules.is_natural(player_hand) or BaccaratRules.is_natural(banker_hand)
			instructions["heart_bet_trigger_data"] = {
				"winner": actual_winner,
				"banker_score": banker_score,
				"player_score": player_score,
				"is_natural": is_natural
			}
	
	return instructions

