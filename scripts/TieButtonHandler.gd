# res://scripts/TieButtonHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК КНОПКИ TIE (ИГАЛИТЕ)
# Обрабатывает нажатие кнопки Tie и координирует все связанные действия
# ═══════════════════════════════════════════════════════════════════════════

class_name TieButtonHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var hand_manager: HandManager = null
var chance_card_trigger_checker: ChanceCardTriggerChecker = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	hand_manager_ref: HandManager = null,
	chance_card_trigger_checker_ref: ChanceCardTriggerChecker = null
):
	hand_manager = hand_manager_ref
	chance_card_trigger_checker = chance_card_trigger_checker_ref

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА НАЖАТИЯ
# ═══════════════════════════════════════════════════════════════════════════

func get_tie_button_instructions(
	has_active_heart_bet: bool,
	is_survival_mode: bool
) -> Dictionary:
	"""Получить инструкции для обработки нажатия кнопки Tie
	
	Args:
		has_active_heart_bet: Есть ли активная ставка Heart Bet
		is_survival_mode: Режим выживания активен
		
	Returns:
		Dictionary с инструкциями:
		{
			"is_valid": bool,  # Валидна ли ничья
			"actual_winner": String,  # Фактический победитель
			"should_resolve_heart_bet": bool,  # Нужно ли разрешить Heart Bet
			"should_check_chance_cards": bool,  # Нужно ли проверить карты шанса
			"should_show_success": bool,  # Показать сообщение об успехе
			"should_update_ui": bool,  # Обновить UI
			"should_request_payout": bool  # Запросить выплаты
		}
	"""
	if not hand_manager:
		return {
			"is_valid": false,
			"actual_winner": "",
			"should_resolve_heart_bet": false,
			"should_check_chance_cards": false,
			"should_show_success": false,
			"should_update_ui": false,
			"should_request_payout": false
		}
	
	# Определяем реального победителя
	var player_hand = hand_manager.get_player_hand_ref()
	var banker_hand = hand_manager.get_banker_hand_ref()
	
	if player_hand.is_empty() or banker_hand.is_empty():
		return {
			"is_valid": false,
			"actual_winner": "",
			"should_resolve_heart_bet": false,
			"should_check_chance_cards": false,
			"should_show_success": false,
			"should_update_ui": false,
			"should_request_payout": false
		}
	
	var actual_winner = BaccaratRules.get_winner(player_hand, banker_hand)
	var is_valid = actual_winner == "Tie"
	
	return {
		"is_valid": is_valid,
		"actual_winner": actual_winner,
		"should_resolve_heart_bet": has_active_heart_bet and is_valid,
		"should_check_chance_cards": is_survival_mode and is_valid,
		"should_show_success": is_valid,
		"should_update_ui": is_valid,
		"should_request_payout": is_valid and not has_active_heart_bet
	}

func get_chance_card_triggers(actual_winner: String) -> Dictionary:
	"""Получить триггеры карт шанса для Tie
	
	Args:
		actual_winner: Победитель раздачи (должен быть "Tie")
		
	Returns:
		Dictionary с триггерами от ChanceCardTriggerChecker
	"""
	if not chance_card_trigger_checker or not hand_manager:
		return {}
	
	var player_hand = hand_manager.get_player_hand_ref()
	var banker_hand = hand_manager.get_banker_hand_ref()
	
	if player_hand.is_empty() or banker_hand.is_empty():
		return {}
	
	return chance_card_trigger_checker.check_triggers_after_winner(
		actual_winner, player_hand, banker_hand
	)

