# res://scripts/GameStateResetCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР СБРОСА СОСТОЯНИЯ ИГРЫ
# Координирует логику сброса состояния игры
# Возвращает инструкции для выполнения, но не выполняет действия напрямую
# ═══════════════════════════════════════════════════════════════════════════

class_name GameStateResetCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# РЕЗУЛЬТАТ КООРДИНАЦИИ СБРОСА
# ═══════════════════════════════════════════════════════════════════════════

# Структура результата get_reset_instructions():
# {
#   "should_reset_hands": bool,           # Сбросить руки
#   "should_reset_ui": bool,              # Сбросить UI
#   "should_clear_chips": bool,           # Очистить фишки
#   "should_clear_guest_bets": bool,      # Очистить ставки гостей
#   "should_update_state": bool,          # Обновить GameStateManager
#   "should_invalidate_cache": bool,      # Инвалидировать кэш
#   "should_reset_managers": bool,        # Сбросить менеджеры
#   "should_hide_ui_elements": bool       # Скрыть UI элементы
# }

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНОЙ МЕТОД
# ═══════════════════════════════════════════════════════════════════════════

func get_reset_instructions(
	update_state: bool = true,
	keep_guest_bets: bool = false
) -> Dictionary:
	"""Получить инструкции для сброса состояния игры
	
	Args:
		update_state: Обновлять ли GameStateManager
		keep_guest_bets: Сохранять ли ставки гостей (true при Heart Bet)
		
	Returns:
		Dictionary с инструкциями для выполнения сброса
	"""
	return {
		"should_reset_hands": true,
		"should_reset_ui": true,
		"should_clear_chips": not keep_guest_bets,  # Не очищаем фишки если сохраняем ставки гостей
		"should_clear_guest_bets": not keep_guest_bets,  # Не очищаем ставки гостей если keep_guest_bets=true
		"should_update_state": update_state,
		"should_invalidate_cache": true,  # Всегда инвалидируем кэш
		"should_reset_managers": true,
		"should_hide_ui_elements": true
	}

