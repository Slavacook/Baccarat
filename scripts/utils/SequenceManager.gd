# res://scripts/utils/SequenceManager.gd
# Менеджер последовательностей сбора и оплаты ставок
# 
# Отвечает за:
# - Инициализацию последовательностей сбора и оплаты
# - Управление прогрессом обработки ставок
# - Получение следующей ожидаемой ставки

class_name SequenceManager

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var bet_sorter: BetSorter
var position_calculator: LinePositionCalculator

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ
# ═══════════════════════════════════════════════════════════════════════════

# Отсортированные последовательности ставок для проверки порядка
var collection_sequence: Dictionary = {}  # {"main": [...], "tie": [...], "pairs": [...]}
var payment_sequence: Dictionary = {}     # {"main": [...], "tie": [...], "pairs": [...]}

# Прогресс сбора и оплаты (индекс следующей ставки в последовательности)
var collection_progress: Dictionary = {"main": 0, "tie": 0, "pairs": 0}
var payment_progress: Dictionary = {"main": 0, "tie": 0, "pairs": 0}

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(sorter: BetSorter, calc: LinePositionCalculator) -> void:
	"""Инициализировать менеджер последовательностей
	
	Args:
		sorter: Сортировщик ставок
		calc: Калькулятор номеров позиций
	"""
	bet_sorter = sorter
	position_calculator = calc

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func initialize_collection_sequence(payout_queue_manager, actual_winner: String, get_position_coordinates: Callable) -> void:
	"""Инициализировать последовательности для сбора проигрышных ставок
	
	Args:
		payout_queue_manager: Менеджер очереди выплат с информацией о ставках
		actual_winner: Победитель раунда ("Player", "Banker", "Tie")
		get_position_coordinates: Функция для получения координат позиции (для отладки)
	"""
	collection_sequence.clear()
	collection_progress = {"main": 0, "tie": 0, "pairs": 0}
	
	collection_sequence["main"] = bet_sorter.get_sorted_main_bets(payout_queue_manager, actual_winner, false)
	collection_sequence["tie"] = bet_sorter.get_sorted_tie_bets(payout_queue_manager, false)
	collection_sequence["pairs"] = bet_sorter.get_sorted_pair_bets(payout_queue_manager, false)
	
	DebugLogger.log("📋 Последовательности сбора инициализированы:")
	DebugLogger.log("  Основные: %d, Tie: %d, Пары: %d" % [
		collection_sequence["main"].size(),
		collection_sequence["tie"].size(),
		collection_sequence["pairs"].size()
	])
	
	# Отладочный вывод порядка основных ставок (если есть)
	if collection_sequence["main"].size() > 0:
		DebugLogger.log("  📍 Порядок основных (справа налево):")
		for i in range(collection_sequence["main"].size()):
			var bet = collection_sequence["main"][i]
			var bet_type = bet.get_bet_type()
			var pos_idx = bet.get_position_index()
			var pos_num = position_calculator.get_line_position_number(bet_type, pos_idx)
			var pos = get_position_coordinates.call(bet_type, pos_idx)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet_type, pos_idx, pos_num, pos.x, pos.y])
	
	# Отладочный вывод порядка Tie ставок (если есть)
	if collection_sequence["tie"].size() > 0:
		DebugLogger.log("  📍 Порядок Tie (слева направо):")
		for i in range(collection_sequence["tie"].size()):
			var bet = collection_sequence["tie"][i]
			var bet_type = bet.get_bet_type()
			var pos_idx = bet.get_position_index()
			var pos_num = position_calculator.get_line_position_number(bet_type, pos_idx)
			var pos = get_position_coordinates.call(bet_type, pos_idx)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet_type, pos_idx, pos_num, pos.x, pos.y])
	
	# Отладочный вывод порядка пар (если есть)
	if collection_sequence["pairs"].size() > 0:
		DebugLogger.log("  📍 Порядок пар (справа налево):")
		for i in range(collection_sequence["pairs"].size()):
			var bet = collection_sequence["pairs"][i]
			var bet_type = bet.get_bet_type()
			var pos_idx = bet.get_position_index()
			var pos_num = position_calculator.get_line_position_number(bet_type, pos_idx)
			var pos = get_position_coordinates.call(bet_type, pos_idx)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet_type, pos_idx, pos_num, pos.x, pos.y])

func initialize_payment_sequence(payout_queue_manager, actual_winner: String, get_position_coordinates: Callable) -> void:
	"""Инициализировать последовательности для оплаты выигрышных ставок
	
	Args:
		payout_queue_manager: Менеджер очереди выплат с информацией о ставках
		actual_winner: Победитель раунда ("Player", "Banker", "Tie")
		get_position_coordinates: Функция для получения координат позиции (для отладки)
	"""
	payment_sequence.clear()
	payment_progress = {"main": 0, "tie": 0, "pairs": 0}
	
	payment_sequence["main"] = bet_sorter.get_sorted_main_bets(payout_queue_manager, actual_winner, true)
	payment_sequence["tie"] = bet_sorter.get_sorted_tie_bets(payout_queue_manager, true)
	payment_sequence["pairs"] = bet_sorter.get_sorted_pair_bets(payout_queue_manager, true)
	
	DebugLogger.log("📋 Последовательности оплаты инициализированы:")
	DebugLogger.log("  Основные: %d, Tie: %d, Пары: %d" % [
		payment_sequence["main"].size(),
		payment_sequence["tie"].size(),
		payment_sequence["pairs"].size()
	])
	
	# Отладочный вывод порядка основных ставок (если есть)
	if payment_sequence["main"].size() > 0:
		DebugLogger.log("  📍 Порядок основных (справа налево):")
		for i in range(payment_sequence["main"].size()):
			var bet = payment_sequence["main"][i]
			var bet_type = bet.get_bet_type()
			var pos_idx = bet.get_position_index()
			var pos_num = position_calculator.get_line_position_number(bet_type, pos_idx)
			var pos = get_position_coordinates.call(bet_type, pos_idx)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet_type, pos_idx, pos_num, pos.x, pos.y])
	
	# Отладочный вывод порядка Tie ставок (если есть)
	if payment_sequence["tie"].size() > 0:
		DebugLogger.log("  📍 Порядок Tie (справа налево):")
		for i in range(payment_sequence["tie"].size()):
			var bet = payment_sequence["tie"][i]
			var bet_type = bet.get_bet_type()
			var pos_idx = bet.get_position_index()
			var pos_num = position_calculator.get_line_position_number(bet_type, pos_idx)
			var pos = get_position_coordinates.call(bet_type, pos_idx)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet_type, pos_idx, pos_num, pos.x, pos.y])
	
	# Отладочный вывод порядка пар (если есть)
	if payment_sequence["pairs"].size() > 0:
		DebugLogger.log("  📍 Порядок пар (справа налево):")
		for i in range(payment_sequence["pairs"].size()):
			var bet = payment_sequence["pairs"][i]
			var bet_type = bet.get_bet_type()
			var pos_idx = bet.get_position_index()
			var pos_num = position_calculator.get_line_position_number(bet_type, pos_idx)
			var pos = get_position_coordinates.call(bet_type, pos_idx)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet_type, pos_idx, pos_num, pos.x, pos.y])

func get_expected_next_bet(group: String, is_collecting: bool):
	"""Получить следующую ожидаемую ставку в группе
	
	Args:
		group: Группа ставок ("main", "tie", "pairs")
		is_collecting: true для сбора, false для оплаты
		
	Returns:
		Bet следующей ожидаемой ставки или null если все собраны/оплачены
	"""
	var sequence = collection_sequence[group] if is_collecting else payment_sequence[group]
	var progress = collection_progress[group] if is_collecting else payment_progress[group]
	
	if not sequence:
		DebugLogger.log_warning("Последовательность для группы '%s' не найдена" % group)
		return null
	
	if progress >= sequence.size():
		DebugLogger.log("  ✅ Все ставки в группе '%s' обработаны (progress=%d, size=%d)" % [group, progress, sequence.size()])
		return null
	
	var expected = sequence[progress]
	DebugLogger.log("  📍 Ожидаемая ставка в группе '%s' (progress=%d/%d): %s[%d]" % [group, progress, sequence.size(), expected.get_bet_type(), expected.get_position_index()])
	return expected

func increment_progress(group: String, is_collecting: bool) -> void:
	"""Увеличить прогресс обработки для группы
	
	Args:
		group: Группа ставок ("main", "tie", "pairs")
		is_collecting: true для сбора, false для оплаты
	"""
	if is_collecting:
		if collection_progress.has(group):
			collection_progress[group] += 1
	else:
		if payment_progress.has(group):
			payment_progress[group] += 1

func reset() -> void:
	"""Сбросить состояние менеджера"""
	collection_sequence.clear()
	payment_sequence.clear()
	collection_progress = {"main": 0, "tie": 0, "pairs": 0}
	payment_progress = {"main": 0, "tie": 0, "pairs": 0}

