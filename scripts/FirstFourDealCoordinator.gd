# res://scripts/FirstFourDealCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР РАЗДАЧИ ПЕРВЫХ ЧЕТЫРЕХ КАРТ
# Координирует все действия при раздаче первых четырех карт
# ═══════════════════════════════════════════════════════════════════════════

class_name FirstFourDealCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var pair_betting_manager: PairBettingManager = null
var chance_card_trigger_checker: ChanceCardTriggerChecker = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	pair_betting_manager_ref: PairBettingManager = null,
	chance_card_trigger_checker_ref: ChanceCardTriggerChecker = null
):
	pair_betting_manager = pair_betting_manager_ref
	chance_card_trigger_checker = chance_card_trigger_checker_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СТАВОК
# ═══════════════════════════════════════════════════════════════════════════

func has_any_bets() -> Dictionary:
	"""Проверить, есть ли активные ставки
	
	Returns:
		Dictionary с информацией о ставках:
		{
			"has_main_bets": bool,  # Есть ли основные ставки
			"has_pair_bets": bool,  # Есть ли ставки на пары
			"has_any": bool  # Есть ли хотя бы одна ставка
		}
	"""
	var has_main_bets = PayoutSettingsManager.has_any_active_bet()
	var has_pair_bets = false
	if pair_betting_manager:
		has_pair_bets = pair_betting_manager.is_player_pair_bet_enabled() or \
						pair_betting_manager.is_banker_pair_bet_enabled()
	
	return {
		"has_main_bets": has_main_bets,
		"has_pair_bets": has_pair_bets,
		"has_any": has_main_bets or has_pair_bets
	}

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ПАР
# ═══════════════════════════════════════════════════════════════════════════

func check_pairs(
	player_card1: Card,
	player_card2: Card,
	banker_card1: Card,
	banker_card2: Card
) -> Dictionary:
	"""Проверить пары в первых двух картах
	
	Args:
		player_card1: Первая карта игрока
		player_card2: Вторая карта игрока
		banker_card1: Первая карта банкира
		banker_card2: Вторая карта банкира
		
	Returns:
		Dictionary с результатом проверки:
		{
			"has_player_pair": bool,  # Есть ли пара у игрока
			"has_banker_pair": bool,  # Есть ли пара у банкира
			"has_both_pairs": bool  # Есть ли обе пары
		}
	"""
	if not pair_betting_manager:
		return {
			"has_player_pair": false,
			"has_banker_pair": false,
			"has_both_pairs": false
		}
	
	pair_betting_manager.check_pairs(
		player_card1, player_card2,
		banker_card1, banker_card2
	)
	
	var has_player_pair = pair_betting_manager.has_player_pair()
	var has_banker_pair = pair_betting_manager.has_banker_pair()
	
	return {
		"has_player_pair": has_player_pair,
		"has_banker_pair": has_banker_pair,
		"has_both_pairs": has_player_pair and has_banker_pair
	}

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ТРИГГЕРОВ КАРТ ШАНСА
# ═══════════════════════════════════════════════════════════════════════════

func get_triggers_after_deal(
	player_hand: Array[Card],
	banker_hand: Array[Card],
	has_player_pair: bool,
	has_banker_pair: bool,
	is_survival_mode: bool
) -> Dictionary:
	"""Получить триггеры карт шанса после раздачи
	
	Args:
		player_hand: Рука игрока
		banker_hand: Рука банкира
		has_player_pair: Есть ли пара у игрока
		has_banker_pair: Есть ли пара у банкира
		is_survival_mode: Режим выживания активен
		
	Returns:
		Dictionary с триггерами:
		{
			"third_card_change": bool,  # Триггер Third Card Change (две пары)
			"mystery_card": bool  # Триггер Mystery Card (пара тузов, только в режиме выживания)
		}
	"""
	if not chance_card_trigger_checker:
		return {
			"third_card_change": false,
			"mystery_card": false
		}
	
	var triggers = chance_card_trigger_checker.check_triggers_after_deal(
		player_hand, banker_hand,
		has_player_pair, has_banker_pair
	)
	
	# Mystery Card только в режиме выживания
	if not is_survival_mode:
		triggers["mystery_card"] = false
	
	return {
		"third_card_change": triggers.get("third_card_change", false),
		"mystery_card": triggers.get("mystery_card", false)
	}

