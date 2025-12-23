# res://scripts/GameStateUpdater.gd
# Обновлятор состояния игры
# Подготавливает данные для обновления GameStateManager

class_name GameStateUpdater
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_state_update_data(hand_manager: HandManager) -> Dictionary:
	"""Получить данные для обновления состояния игры
	
	Args:
		hand_manager: Менеджер рук для получения данных о картах
		
	Returns:
		Dictionary с полями:
		- cards_hidden: bool - скрыты ли карты (руки пустые)
		- player_hand: Array[Card] - ссылка на руку игрока
		- banker_hand: Array[Card] - ссылка на руку банкира
		- player_third_card: Card - третья карта игрока (или null)
		- banker_third_card: Card - третья карта банкира (или null)
	"""
	return {
		"cards_hidden": hand_manager.are_hands_empty(),
		"player_hand": hand_manager.get_player_hand_ref(),
		"banker_hand": hand_manager.get_banker_hand_ref(),
		"player_third_card": hand_manager.get_player_third_card(),
		"banker_third_card": hand_manager.get_banker_third_card()
	}

func update_game_state(hand_manager: HandManager) -> void:
	"""Обновить состояние игры через GameStateManager
	
	Args:
		hand_manager: Менеджер рук для получения данных о картах
	"""
	var data = get_state_update_data(hand_manager)
	GameStateManager.determine_and_update_state(
		data.get("cards_hidden", true),
		data.get("player_hand", []),
		data.get("banker_hand", []),
		data.get("player_third_card", null),
		data.get("banker_third_card", null)
	)

