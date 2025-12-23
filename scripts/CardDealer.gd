# res://scripts/CardDealer.gd
# ═══════════════════════════════════════════════════════════════════════════
# КАРТОЧНЫЙ ДИЛЕР
# Отвечает только за раздачу карт из колоды в руки
# Инкапсулирует логику раздачи, не зависит от UI и состояния игры
# ═══════════════════════════════════════════════════════════════════════════

class_name CardDealer
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# РАЗДАЧА ПЕРВЫХ ЧЕТЫРЁХ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func deal_first_four(deck: Deck, hand_manager: HandManager) -> void:
	"""Раздать первые 4 карты (2 игроку, 2 банкиру)
	
	Args:
		deck: Колода для взятия карт
		hand_manager: Менеджер рук для добавления карт
		
	Note:
		Делегирует работу в HandManager.deal_first_four() для соблюдения SRP
	"""
	hand_manager.deal_first_four(deck)
	DebugLogger.log("🎴 CardDealer: разданы первые 4 карты")

# ═══════════════════════════════════════════════════════════════════════════
# РАЗДАЧА ТРЕТЬИХ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func draw_player_third(deck: Deck, hand_manager: HandManager) -> Card:
	"""Раздать третью карту игроку
	
	Args:
		deck: Колода для взятия карты
		hand_manager: Менеджер рук для добавления карты
		
	Returns:
		Разданная карта или null если колода пуста
	"""
	var card: Card = deck.draw()
	if card:
		hand_manager.add_player_card(card)
		DebugLogger.log("🎴 CardDealer: раздана третья карта игроку: %s" % card.card_to_string())
	else:
		DebugLogger.log_error("❌ CardDealer: не удалось взять карту из колоды для игрока")
	return card

func draw_banker_third(deck: Deck, hand_manager: HandManager) -> Card:
	"""Раздать третью карту банкиру
	
	Args:
		deck: Колода для взятия карты
		hand_manager: Менеджер рук для добавления карты
		
	Returns:
		Разданная карта или null если колода пуста
	"""
	var card: Card = deck.draw()
	if card:
		hand_manager.add_banker_card(card)
		DebugLogger.log("🎴 CardDealer: раздана третья карта банкиру: %s" % card.card_to_string())
	else:
		DebugLogger.log_error("❌ CardDealer: не удалось взять карту из колоды для банкира")
	return card

