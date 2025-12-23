# res://scripts/ThirdCardUIHandler.gd
# Обработчик событий UI для третьих карт
# Управляет состоянием UI и флагами выбора третьих карт

class_name ThirdCardUIHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func handle_player_third_toggled(current_selected: bool) -> Dictionary:
	"""Обработать переключение третьей карты игрока
	
	Args:
		current_selected: Текущее состояние выбора (до переключения)
		
	Returns:
		Dictionary с полями:
		- new_selected: bool - новое состояние выбора
		- ui_text: String - текст для обновления UI ("!" или "?")
		- should_deselect_winner: bool - нужно ли дезактивировать маркер победителя
	"""
	var new_selected = !current_selected
	return {
		"new_selected": new_selected,
		"ui_text": "!" if new_selected else "?",
		"should_deselect_winner": true
	}

func handle_banker_third_toggled(current_selected: bool) -> Dictionary:
	"""Обработать переключение третьей карты банкира
	
	Args:
		current_selected: Текущее состояние выбора (до переключения)
		
	Returns:
		Dictionary с полями:
		- new_selected: bool - новое состояние выбора
		- ui_text: String - текст для обновления UI ("!" или "?")
		- should_deselect_winner: bool - нужно ли дезактивировать маркер победителя
	"""
	var new_selected = !current_selected
	return {
		"new_selected": new_selected,
		"ui_text": "!" if new_selected else "?",
		"should_deselect_winner": true
	}

func get_cancel_instructions(player_selected: bool, banker_selected: bool) -> Dictionary:
	"""Получить инструкции для отмены заказов третьих карт
	
	Args:
		player_selected: Выбрана ли третья карта игрока
		banker_selected: Выбрана ли третья карта банкира
		
	Returns:
		Dictionary с полями:
		- should_cancel_player: bool - нужно ли отменить заказ игрока
		- should_cancel_banker: bool - нужно ли отменить заказ банкира
		- player_ui_text: String - текст для UI игрока ("?" если отменяется)
		- banker_ui_text: String - текст для UI банкира ("?" если отменяется)
	"""
	return {
		"should_cancel_player": player_selected,
		"should_cancel_banker": banker_selected,
		"player_ui_text": "?" if player_selected else "",
		"banker_ui_text": "?" if banker_selected else ""
	}

