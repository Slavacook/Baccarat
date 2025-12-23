# res://scripts/ThirdCardRemovalCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР УДАЛЕНИЯ ТРЕТЬИХ КАРТ
# Координирует удаление третьих карт и пересчёт состояния игры
# Используется картой Third Card Change
# ═══════════════════════════════════════════════════════════════════════════

class_name ThirdCardRemovalCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var hand_manager: HandManager = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(hand_manager_ref: HandManager = null):
	hand_manager = hand_manager_ref

# ═══════════════════════════════════════════════════════════════════════════
# УДАЛЕНИЕ ТРЕТЬИХ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func get_removal_instructions() -> Dictionary:
	"""Получить инструкции для удаления третьих карт
	
	Returns:
		Dictionary с инструкциями:
		{
			"should_remove_cards": bool,  # Нужно ли удалять карты
			"has_player_third": bool,  # Есть ли третья карта у игрока
			"has_banker_third": bool,  # Есть ли третья карта у банкира
			"should_reset_flags": bool,  # Нужно ли сбросить флаги выбора
			"should_update_ui": bool,  # Нужно ли обновить UI
			"should_recalculate_state": bool  # Нужно ли пересчитать состояние
		}
	"""
	if not hand_manager:
		return {
			"should_remove_cards": false,
			"has_player_third": false,
			"has_banker_third": false,
			"should_reset_flags": false,
			"should_update_ui": false,
			"should_recalculate_state": false
		}
	
	var has_player_third = hand_manager.has_player_third_card()
	var has_banker_third = hand_manager.has_banker_third_card()
	var should_remove = has_player_third or has_banker_third
	
	return {
		"should_remove_cards": should_remove,
		"has_player_third": has_player_third,
		"has_banker_third": has_banker_third,
		"should_reset_flags": should_remove,
		"should_update_ui": should_remove,
		"should_recalculate_state": should_remove
	}

func remove_third_cards() -> bool:
	"""Удалить третьи карты из рук
	
	Returns:
		true если карты были удалены, false если нечего удалять
	"""
	if not hand_manager:
		return false
	
	var has_player_third = hand_manager.has_player_third_card()
	var has_banker_third = hand_manager.has_banker_third_card()
	
	if not has_player_third and not has_banker_third:
		return false
	
	hand_manager.remove_third_cards()
	return true

