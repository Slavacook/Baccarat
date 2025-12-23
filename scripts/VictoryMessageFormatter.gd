# res://scripts/VictoryMessageFormatter.gd
# ═══════════════════════════════════════════════════════════════════════════
# ФОРМАТТЕР СООБЩЕНИЙ ПОБЕДЫ
# Форматирует сообщения о победе для отображения в UI
# Чистая логика без зависимостей от UI и EventBus
# ═══════════════════════════════════════════════════════════════════════════

class_name VictoryMessageFormatter
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНОЙ МЕТОД
# ═══════════════════════════════════════════════════════════════════════════

func format_victory_message(
	winner: String,
	player_score: int,
	banker_score: int
) -> String:
	"""Форматировать сообщение о победе
	
	Args:
		winner: Победитель ("Player"/"Banker"/"Tie")
		player_score: Очки игрока
		banker_score: Очки банкира
		
	Returns:
		Отформатированное сообщение о победе
	"""
	if winner == "Tie":
		return "Игалите"
	
	var winner_text = ""
	var winner_score = 0
	var loser_score = 0
	
	if winner == "Player":
		winner_text = Localization.t("PLAYER")
		winner_score = player_score
		loser_score = banker_score
	else:  # Banker
		winner_text = Localization.t("BANKER")
		winner_score = banker_score
		loser_score = player_score
	
	return "Выиграл %s: %d vs %d" % [winner_text, winner_score, loser_score]

