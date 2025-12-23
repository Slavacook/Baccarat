# res://scripts/PhaseActionResolver.gd
# ═══════════════════════════════════════════════════════════════════════════
# РЕЗОЛВЕР ДЕЙСТВИЙ ПО ФАЗАМ ИГРЫ
# Определяет какое действие нужно выполнить в текущем состоянии игры
# Чистая логика без зависимостей от UI, EventBus и других систем
# ═══════════════════════════════════════════════════════════════════════════

class_name PhaseActionResolver
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# РЕЗУЛЬТАТ РЕЗОЛВИНГА
# ═══════════════════════════════════════════════════════════════════════════

# Структура результата:
# {
#   "action": String,        # Действие: "deal_first_four", "validate_third_cards", "validate_banker_after_player", "handle_choose_winner"
#   "phase": String,        # Текущая фаза (для логирования)
#   "reason": String        # Причина выбора действия (для отладки)
# }

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНОЙ МЕТОД
# ═══════════════════════════════════════════════════════════════════════════

func resolve_action(
	is_table_prepared: bool,
	current_state: GameStateManager.GameState
) -> Dictionary:
	"""Определить какое действие нужно выполнить
	
	Args:
		is_table_prepared: Флаг подготовки стола к новой игре
		current_state: Текущее состояние игры
		
	Returns:
		Dictionary с действием и информацией о фазе
	"""
	# GUARD CLAUSE 1: Подготовка к новой игре
	if is_table_prepared:
		return {
			"action": "deal_first_four",
			"phase": "table_preparation",
			"reason": "Стол подготовлен к новой игре"
		}
	
	# GUARD CLAUSE 2: Начало игры
	if current_state == GameStateManager.GameState.WAITING:
		return {
			"action": "deal_first_four",
			"phase": "waiting",
			"reason": "Ожидание начала игры"
		}
	
	# GUARD CLAUSE 3: Валидация банкира после третьей игрока
	if current_state == GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER:
		return {
			"action": "validate_banker_after_player",
			"phase": "banker_after_player",
			"reason": "Игрок взял карту, нужно проверить должен ли банкир взять"
		}
	
	# GUARD CLAUSE 4: Выбор победителя
	if current_state == GameStateManager.GameState.CHOOSE_WINNER:
		return {
			"action": "handle_choose_winner",
			"phase": "choose_winner",
			"reason": "Фаза выбора победителя"
		}
	
	# FALLBACK: Валидация и раздача третьих карт
	return {
		"action": "validate_third_cards",
		"phase": "third_cards",
		"reason": "Обычная фаза валидации третьих карт"
	}

