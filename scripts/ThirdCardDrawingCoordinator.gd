# res://scripts/ThirdCardDrawingCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР РАЗДАЧИ ТРЕТЬИХ КАРТ
# Координирует раздачу третьих карт игроку и банкиру
# ═══════════════════════════════════════════════════════════════════════════

class_name ThirdCardDrawingCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var card_dealer: CardDealer = null
var hand_manager: HandManager = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	card_dealer_ref: CardDealer = null,
	hand_manager_ref: HandManager = null
):
	card_dealer = card_dealer_ref
	hand_manager = hand_manager_ref

# ═══════════════════════════════════════════════════════════════════════════
# РАЗДАЧА ТРЕТЬИХ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func draw_player_third(deck: Deck) -> Dictionary:
	"""Раздать третью карту игроку
	
	Args:
		deck: Колода для взятия карты
		
	Returns:
		Dictionary с результатом:
		{
			"success": bool,  # Успешно ли раздана карта
			"card": Card,  # Разданная карта (если успешно)
			"error": String  # Сообщение об ошибке (если не успешно)
		}
	"""
	if not card_dealer:
		return {
			"success": false,
			"card": null,
			"error": "CardDealer не инициализирован"
		}
	
	if not hand_manager:
		return {
			"success": false,
			"card": null,
			"error": "HandManager не инициализирован"
		}
	
	var card: Card = card_dealer.draw_player_third(deck, hand_manager)
	if not card:
		return {
			"success": false,
			"card": null,
			"error": "Не удалось раздать третью карту игроку"
		}
	
	return {
		"success": true,
		"card": card,
		"error": ""
	}

func draw_banker_third(deck: Deck) -> Dictionary:
	"""Раздать третью карту банкиру
	
	Args:
		deck: Колода для взятия карты
		
	Returns:
		Dictionary с результатом:
		{
			"success": bool,  # Успешно ли раздана карта
			"card": Card,  # Разданная карта (если успешно)
			"error": String  # Сообщение об ошибке (если не успешно)
		}
	"""
	if not card_dealer:
		return {
			"success": false,
			"card": null,
			"error": "CardDealer не инициализирован"
		}
	
	if not hand_manager:
		return {
			"success": false,
			"card": null,
			"error": "HandManager не инициализирован"
		}
	
	var card: Card = card_dealer.draw_banker_third(deck, hand_manager)
	if not card:
		return {
			"success": false,
			"card": null,
			"error": "Не удалось раздать третью карту банкиру"
		}
	
	return {
		"success": true,
		"card": card,
		"error": ""
	}

