# res://scripts/ChanceCardTriggerChecker.gd
# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРЩИК ТРИГГЕРОВ КАРТ ШАНСА
# Чистая логика проверки условий для активации карт шанса
# Не зависит от UI, EventBus и других внешних систем
# ═══════════════════════════════════════════════════════════════════════════

class_name ChanceCardTriggerChecker
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# РЕЗУЛЬТАТ ПРОВЕРКИ ТРИГГЕРОВ
# ═══════════════════════════════════════════════════════════════════════════

# Структура результата check_triggers_after_winner():
# {
#   "heart_card": bool,        # Триггер Heart Card (банкир выиграл с 6)
#   "heart_bet_card": bool,    # Триггер Heart Bet Card (Tie)
#   "revolver_card": bool      # Триггер Revolver Card (все 6 карт по 0)
# }

# Структура результата check_triggers_after_deal():
# {
#   "mystery_card": bool,      # Триггер Mystery Card (пара тузов)
#   "third_card_change": bool  # Триггер Third Card Change (две пары)
# }

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ТРИГГЕРОВ ПОСЛЕ ОПРЕДЕЛЕНИЯ ПОБЕДИТЕЛЯ
# ═══════════════════════════════════════════════════════════════════════════

func check_triggers_after_winner(
	actual_winner: String,
	player_hand: Array,
	banker_hand: Array
) -> Dictionary:
	"""Проверить триггеры карт шанса после определения победителя
	
	Args:
		actual_winner: Фактический победитель ("Player"/"Banker"/"Tie")
		player_hand: Рука игрока (Array[Card])
		banker_hand: Рука банкира (Array[Card])
		
	Returns:
		Dictionary с результатами проверки триггеров
	"""
	if player_hand.is_empty() or banker_hand.is_empty():
		return {
			"heart_card": false,
			"heart_bet_card": false,
			"revolver_card": false
		}
	
	# Создаём типизированные массивы для BaccaratRules
	var player_hand_typed: Array[Card] = []
	var banker_hand_typed: Array[Card] = []
	for card in player_hand:
		player_hand_typed.append(card as Card)
	for card in banker_hand:
		banker_hand_typed.append(card as Card)
	
	var banker_score = BaccaratRules.hand_value(banker_hand_typed)
	
	return {
		"heart_card": _check_heart_card_trigger(actual_winner, banker_score),
		"heart_bet_card": _check_heart_bet_card_trigger(actual_winner),
		"revolver_card": _check_revolver_card_trigger(player_hand, banker_hand)
	}

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ТРИГГЕРОВ ПОСЛЕ РАЗДАЧИ ПЕРВЫХ 4 КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func check_triggers_after_deal(
	player_hand: Array,
	banker_hand: Array,
	has_player_pair: bool,
	has_banker_pair: bool
) -> Dictionary:
	"""Проверить триггеры карт шанса после раздачи первых 4 карт
	
	Args:
		player_hand: Рука игрока (Array[Card])
		banker_hand: Рука банкира (Array[Card])
		has_player_pair: Есть ли пара у игрока
		has_banker_pair: Есть ли пара у банкира
		
	Returns:
		Dictionary с результатами проверки триггеров
	"""
	return {
		"mystery_card": _check_mystery_card_trigger(player_hand, banker_hand),
		"third_card_change": _check_third_card_change_trigger(has_player_pair, has_banker_pair)
	}

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА КОНКРЕТНЫХ ТРИГГЕРОВ
# ═══════════════════════════════════════════════════════════════════════════

func _check_heart_card_trigger(actual_winner: String, banker_score: int) -> bool:
	"""Проверить триггер Heart Card: победа банкира с 6 очками"""
	return actual_winner == "Banker" and banker_score == 6

func _check_heart_bet_card_trigger(actual_winner: String) -> bool:
	"""Проверить триггер Heart Bet Card: Tie (игалите)"""
	return actual_winner == "Tie"

func _check_revolver_card_trigger(player_hand: Array, banker_hand: Array) -> bool:
	"""Проверить триггер Revolver Card: все 6 карт по 0 очков (10, J, Q, K)"""
	return _check_all_zero_cards(player_hand, banker_hand)

func _check_mystery_card_trigger(player_hand: Array, banker_hand: Array) -> bool:
	"""Проверить триггер Mystery Card: пара тузов"""
	return _check_aces_pair(player_hand) or _check_aces_pair(banker_hand)

func _check_third_card_change_trigger(has_player_pair: bool, has_banker_pair: bool) -> bool:
	"""Проверить триггер Third Card Change: две пары одновременно"""
	return has_player_pair and has_banker_pair

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _check_pair(hand: Array) -> bool:
	"""Проверить, есть ли пара в руке (первые две карты одного ранга)"""
	if hand.size() < 2:
		return false
	
	var card1 = hand[0]
	var card2 = hand[1]
	
	var rank1 = _get_card_rank(card1)
	var rank2 = _get_card_rank(card2)
	
	return rank1 == rank2 and rank1 != ""

func _check_aces_pair(hand: Array) -> bool:
	"""Проверить, есть ли пара тузов в руке (первые две карты - тузы)
	
	Card.value: 1 = Ace
	"""
	if hand.size() < 2:
		return false
	
	var card1 = hand[0]
	var card2 = hand[1]
	
	if not (card1 is Card and card2 is Card):
		return false
	
	return card1.value == 1 and card2.value == 1

func _check_all_zero_cards(player_hand: Array, banker_hand: Array) -> bool:
	"""Проверить, все ли 6 карт по 0 очков (10, J, Q, K)
	
	Карты с 0 очков: 10, J (11), Q (12), K (13)
	Должно быть по 3 карты у каждого (с третьими картами)
	"""
	# Должно быть по 3 карты у каждого (с третьими картами)
	if player_hand.size() < 3 or banker_hand.size() < 3:
		return false
	
	var all_cards = []
	all_cards.append_array(player_hand)
	all_cards.append_array(banker_hand)
	
	# Карты с 0 очков: 10, J (11), Q (12), K (13)
	var zero_values = [10, 11, 12, 13]
	
	for card in all_cards:
		if not card is Card:
			return false
		if card.value not in zero_values:
			return false
	
	return true

func _get_card_rank(card) -> String:
	"""Получить ранг карты (2-10, J, Q, K, A)"""
	if card is Card:
		return str(card.value)  # Возвращаем value как строку для сравнения
	elif card is Dictionary:
		return card.get("rank", "")
	elif card is String:
		# Парсим из строки типа "8_diamonds" или "queen_spades"
		var parts = card.split("_")
		if parts.size() >= 1:
			return parts[0]
	return ""
