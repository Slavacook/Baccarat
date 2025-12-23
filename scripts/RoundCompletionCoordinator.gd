# res://scripts/RoundCompletionCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР ЗАВЕРШЕНИЯ РАУНДА
# Координирует логику завершения раунда и подготовки к новой игре
# Возвращает инструкции для выполнения, но не выполняет действия напрямую
# ═══════════════════════════════════════════════════════════════════════════

class_name RoundCompletionCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# РЕЗУЛЬТАТ ПРОВЕРКИ ЗАВЕРШЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

# Структура результата can_complete_round():
# {
#   "can_complete": bool,           # Можно ли завершить раунд
#   "error_key": String,            # Ключ локализации ошибки (если есть)
#   "error_type": String,          # Тип ошибки для EventBus (если есть)
#   "reasons": Array[String]        # Причины блокировки (для отладки)
# }

# Структура результата get_completion_message():
# {
#   "message_key": String,          # Ключ локализации сообщения
#   "has_bets": bool,               # Есть ли ставки
#   "has_winning": bool,            # Есть ли выигрышные ставки
#   "has_unpaid": bool              # Есть ли неоплаченные выплаты
# }

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ВОЗМОЖНОСТИ ЗАВЕРШЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func can_complete_round(
	bet_collection_manager: BetCollectionPhaseManager = null,
	payout_queue_manager: PayoutQueueManager = null
) -> Dictionary:
	"""Проверить можно ли завершить раунд
	
	Args:
		bet_collection_manager: Менеджер сбора ставок (приоритет)
		payout_queue_manager: Менеджер очереди выплат (fallback)
		
	Returns:
		Dictionary с результатом проверки
	"""
	# Проверка через BetCollectionPhaseManager (приоритет)
	if bet_collection_manager:
		var completion_check = bet_collection_manager.can_complete_round()
		if not completion_check.can:
			return {
				"can_complete": false,
				"error_key": completion_check.error_key,
				"error_type": "incomplete_bets",
				"reasons": completion_check.reasons if completion_check.has("reasons") else []
			}
		return {
			"can_complete": true,
			"error_key": "",
			"error_type": "",
			"reasons": []
		}
	
	# Fallback: старая логика без bet_collection_manager
	if payout_queue_manager and payout_queue_manager.has_unpaid_winnings():
		var unpaid_count = payout_queue_manager.get_unpaid_count()
		return {
			"can_complete": false,
			"error_key": "ERR_UNPAID_BETS",
			"error_type": "unpaid_bets",
			"reasons": ["Неоплаченных ставок: %d" % unpaid_count]
		}
	
	return {
		"can_complete": true,
		"error_key": "",
		"error_type": "",
		"reasons": []
	}

# ═══════════════════════════════════════════════════════════════════════════
# ОПРЕДЕЛЕНИЕ СООБЩЕНИЯ О ЗАВЕРШЕНИИ
# ═══════════════════════════════════════════════════════════════════════════

func get_completion_message(
	payout_queue_manager: PayoutQueueManager = null
) -> Dictionary:
	"""Определить какое сообщение показать при завершении раунда
	
	Args:
		payout_queue_manager: Менеджер очереди выплат
		
	Returns:
		Dictionary с информацией о сообщении
	"""
	# Нет payout_queue_manager
	if not payout_queue_manager:
		return {
			"message_key": "NO_ACTIVE_BETS",
			"has_bets": false,
			"has_winning": false,
			"has_unpaid": false
		}
	
	# Нет ставок вообще
	if not payout_queue_manager.has_any_payouts():
		return {
			"message_key": "NO_ACTIVE_BETS",
			"has_bets": false,
			"has_winning": false,
			"has_unpaid": false
		}
	
	# Есть неоплаченные выплаты - не завершаем
	if payout_queue_manager.has_unpaid_winnings():
		return {
			"message_key": "",
			"has_bets": true,
			"has_winning": false,
			"has_unpaid": true
		}
	
	# Все выплаты оплачены
	var has_winning = payout_queue_manager.has_any_winning_bets()
	return {
		"message_key": "ALL_BETS_PAID" if has_winning else "NO_WINNING_BETS",
		"has_bets": true,
		"has_winning": has_winning,
		"has_unpaid": false
	}

# ═══════════════════════════════════════════════════════════════════════════
# ИНСТРУКЦИИ ДЛЯ ЗАВЕРШЕНИЯ РАУНДА
# ═══════════════════════════════════════════════════════════════════════════

func get_completion_instructions(
	has_active_heart_bet: bool,
	is_survival_mode: bool
) -> Dictionary:
	"""Получить инструкции для завершения раунда
	
	Args:
		has_active_heart_bet: Есть ли активная ставка Heart Bet
		is_survival_mode: Режим выживания активен
		
	Returns:
		Dictionary с инструкциями для выполнения
	"""
	# Если есть активный Heart Bet - не делаем обычное завершение
	if has_active_heart_bet:
		return {
			"should_resolve_heart_bet": true,
			"should_show_message": false,
			"should_reset_round": false,
			"should_restore_chips": false,
			"should_apply_filters": false,
			"should_generate_guest_bets": false,
			"should_add_score": false,
			"should_set_waiting_state": false
		}
	
	# Обычное завершение раунда
	return {
		"should_resolve_heart_bet": false,
		"should_show_message": true,
		"should_reset_round": true,
		"should_restore_chips": true,
		"should_apply_filters": true,
		"should_generate_guest_bets": true,
		"should_add_score": not is_survival_mode,  # Очки только в обычном режиме
		"should_set_waiting_state": true
	}

