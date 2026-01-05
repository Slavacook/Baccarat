# res://scripts/utils/BetSorter.gd
# Сортировщик ставок для BetCollectionPhaseManager
# 
# Отвечает за:
# - Сортировку основных ставок (Player/Banker)
# - Сортировку Tie ставок (с учетом направления для сбора/оплаты)
# - Сортировку пар (PairPlayer/PairBanker)

class_name BetSorter

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var position_calculator: LinePositionCalculator

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(calc: LinePositionCalculator) -> void:
	"""Инициализировать сортировщик
	
	Args:
		calc: Калькулятор номеров позиций
	"""
	position_calculator = calc

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_sorted_main_bets(payout_queue_manager, actual_winner: String, winning: bool) -> Array:
	"""Получить отсортированные основные ставки (Player/Banker) справа налево
	
	Args:
		payout_queue_manager: Менеджер очереди выплат с информацией о ставках
		actual_winner: Победитель раунда ("Player", "Banker", "Tie")
		winning: true для выигрышных ставок, false для проигрышных
		
	Returns:
		Отсортированный массив ставок справа налево (по X координате по убыванию)
	"""
	if not payout_queue_manager:
		return []
	
	var bets: Array = []
	
	# Определяем какие типы собирать/оплачивать
	var types_to_include: Array[String] = []
	
	if winning:
		# Для оплаты - только выигрышные основные ставки
		if actual_winner == "Player":
			types_to_include = ["Player"]
		elif actual_winner == "Banker":
			types_to_include = ["Banker"]
		# При Tie основные ставки не оплачиваются (push)
	else:
		# Для сбора - только проигрышные основные ставки
		if actual_winner == "Player":
			types_to_include = ["Banker"]  # Проиграл Banker
		elif actual_winner == "Banker":
			types_to_include = ["Player"]  # Проиграл Player
		# При Tie основные ставки не собираются (push)
	
	# Собираем ставки нужных типов
	for bet in payout_queue_manager.bets:
		if bet.get_bet_type() in types_to_include and bet.is_won() == winning:
			bets.append(bet)
	
	# Сортируем справа налево по номеру позиции (номер 1, 2, 3...)
	bets.sort_custom(func(a, b): 
		var num_a = position_calculator.get_line_position_number(a.get_bet_type(), a.get_position_index())
		var num_b = position_calculator.get_line_position_number(b.get_bet_type(), b.get_position_index())
		return num_a < num_b  # Меньший номер = правее = идёт первым
	)
	
	return bets

func get_sorted_tie_bets(payout_queue_manager, winning: bool) -> Array:
	"""Получить отсортированные Tie ставки
	- Для сбора (winning=false): слева направо (обратный порядок номеров)
	- Для оплаты (winning=true): справа налево (прямой порядок номеров)
	
	Args:
		payout_queue_manager: Менеджер очереди выплат с информацией о ставках
		winning: true для выигрышных ставок, false для проигрышных
		
	Returns:
		Отсортированный массив Tie ставок
	"""
	if not payout_queue_manager:
		return []
	
	var bets: Array = []
	
	for bet in payout_queue_manager.bets:
		if bet.get_bet_type() == "Tie" and bet.is_won() == winning:
			bets.append(bet)
	
	# Используем нумерацию позиций (1 = самый правый)
	if winning:
		# Оплата: справа налево (номер 1, 2, 3...)
		bets.sort_custom(func(a, b):
			var num_a = position_calculator.get_line_position_number(a.get_bet_type(), a.get_position_index())
			var num_b = position_calculator.get_line_position_number(b.get_bet_type(), b.get_position_index())
			return num_a < num_b  # Меньший номер = правее = идёт первым
		)
	else:
		# Сбор: слева направо (номер 3, 2, 1...)
		bets.sort_custom(func(a, b):
			var num_a = position_calculator.get_line_position_number(a.get_bet_type(), a.get_position_index())
			var num_b = position_calculator.get_line_position_number(b.get_bet_type(), b.get_position_index())
			return num_a > num_b  # Больший номер = левее = идёт первым
		)
	
	return bets

func get_sorted_pair_bets(payout_queue_manager, winning: bool) -> Array:
	"""Получить отсортированные пары (PairPlayer + PairBanker вместе) справа налево
	
	Пары объединены в одну линию и сортируются по номеру позиции (1 = самый правый)
	
	Args:
		payout_queue_manager: Менеджер очереди выплат с информацией о ставках
		winning: true для выигрышных ставок, false для проигрышных
		
	Returns:
		Отсортированный массив пар ставок
	"""
	if not payout_queue_manager:
		return []
	
	var bets: Array = []
	
	for bet in payout_queue_manager.bets:
		var bet_type = bet.get_bet_type()
		if (bet_type == "PairPlayer" or bet_type == "PairBanker") and bet.is_won() == winning:
			bets.append(bet)
	
	# Сортируем справа налево по номеру позиции (номер 1, 2, 3...)
	bets.sort_custom(func(a, b):
		var num_a = position_calculator.get_line_position_number(a.get_bet_type(), a.get_position_index())
		var num_b = position_calculator.get_line_position_number(b.get_bet_type(), b.get_position_index())
		return num_a < num_b  # Меньший номер = правее = идёт первым
	)
	
	return bets

