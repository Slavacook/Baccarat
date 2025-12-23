# res://scripts/GameCompletionCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР ЗАВЕРШЕНИЯ ИГРЫ
# Координирует завершение фазы третьих карт и переход к выбору победителя
# ═══════════════════════════════════════════════════════════════════════════

class_name GameCompletionCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_completion_instructions() -> Dictionary:
	"""Получить инструкции для завершения игры
	
	Returns:
		Dictionary с инструкциями:
		{
			"should_reset_player_third_ui": bool,  # Нужно ли сбросить UI третьей карты игрока
			"should_reset_banker_third_ui": bool,  # Нужно ли сбросить UI третьей карты банкира
			"should_update_action_button": bool,  # Нужно ли обновить кнопку действия
			"action_button_text": String  # Текст для кнопки действия
		}
	"""
	return {
		"should_reset_player_third_ui": true,
		"should_reset_banker_third_ui": true,
		"should_update_action_button": true,
		"action_button_text": Localization.t("ACTION_BUTTON_CARDS")
	}

