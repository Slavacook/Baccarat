# res://scripts/BetCollectionPhaseManager.gd
# Централизованный менеджер для фазы сбора проигрышных ставок и оплаты выигрышных
# Инкапсулирует логику валидации, состояния режимов и проверки возможности завершения раунда

class_name BetCollectionPhaseManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ENUM: Режимы взаимодействия с фишками
# ═══════════════════════════════════════════════════════════════════════════

enum CollectionMode {
	NONE,    # Режим не выбран - клики на фишки игнорируются
	COLLECT, # Режим сбора проигрышных ставок
	PAY      # Режим оплаты выигрышных ставок
}

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal mode_changed(new_mode: CollectionMode)
signal bet_collected(bet_type: String)
# Новый сигнал с идентификатором конкретной фишки
signal chip_collected(bet_type: String, position_index: int)
signal chip_paid(bet_type: String, position_index: int)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var current_mode: CollectionMode = CollectionMode.NONE
var payout_queue_manager: PayoutQueueManager = null
var actual_winner: String = ""  # Победитель раунда (для проверки Tie push)

# Список собранных проигрышных ставок (для обратной совместимости)
var collected_losing_bets: Array[String] = []

# Словарь собранных ставок с position_index: {"Player_0": true, "Banker_2": true}
var collected_bets_by_id: Dictionary = {}

# Отсортированные последовательности ставок для проверки порядка
var collection_sequence: Dictionary = {}  # {"main": [...], "tie": [...], "pairs": [...]}
var payment_sequence: Dictionary = {}     # {"main": [...], "tie": [...], "pairs": [...]}

# Прогресс сбора и оплаты (индекс следующей ставки в последовательности)
var collection_progress: Dictionary = {"main": 0, "tie": 0, "pairs": 0}
var payment_progress: Dictionary = {"main": 0, "tie": 0, "pairs": 0}

# Кэш для номеров позиций в линиях (для производительности)
var _line_position_cache: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(queue_manager: PayoutQueueManager, winner: String) -> void:
	"""Настроить менеджер для нового раунда
	
	Args:
		queue_manager: Менеджер очереди выплат с информацией о ставках
		winner: Победитель раунда ("Player", "Banker", "Tie")
	"""
	payout_queue_manager = queue_manager
	actual_winner = winner
	collected_losing_bets.clear()
	collected_bets_by_id.clear()
	current_mode = CollectionMode.NONE
	
	# Инициализируем последовательности для проверки порядка
	initialize_sequences()
	
	print("✅ BetCollectionPhaseManager: настроен для раунда (победитель: %s)" % winner)

func initialize_sequences() -> void:
	"""Инициализировать последовательности для проверки порядка (вызывается ПОСЛЕ добавления всех ставок)"""
	_initialize_collection_sequence()
	_initialize_payment_sequence()

func reset() -> void:
	"""Сбросить состояние менеджера"""
	payout_queue_manager = null
	actual_winner = ""
	collected_losing_bets.clear()
	collected_bets_by_id.clear()
	collection_sequence.clear()
	payment_sequence.clear()
	collection_progress = {"main": 0, "tie": 0, "pairs": 0}
	payment_progress = {"main": 0, "tie": 0, "pairs": 0}
	_line_position_cache.clear()  # Очищаем кэш номеров позиций
	set_mode(CollectionMode.NONE)
	print("🔄 BetCollectionPhaseManager: сброшен")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ РЕЖИМАМИ
# ═══════════════════════════════════════════════════════════════════════════

func set_mode(mode: CollectionMode) -> void:
	"""Установить режим взаимодействия с фишками"""
	if mode != current_mode:
		current_mode = mode
		mode_changed.emit(mode)
		var mode_name = get_mode_name(mode)
		print("🔄 BetCollectionPhaseManager: режим изменен на %s" % mode_name)

func get_mode() -> CollectionMode:
	"""Получить текущий режим"""
	return current_mode

func toggle_collect_mode() -> void:
	"""Переключить режим сбора"""
	if current_mode == CollectionMode.COLLECT:
		set_mode(CollectionMode.NONE)
	else:
		set_mode(CollectionMode.COLLECT)

func toggle_pay_mode() -> void:
	"""Переключить режим оплаты"""
	if current_mode == CollectionMode.PAY:
		set_mode(CollectionMode.NONE)
	else:
		set_mode(CollectionMode.PAY)

func is_collect_mode() -> bool:
	return current_mode == CollectionMode.COLLECT

func is_pay_mode() -> bool:
	return current_mode == CollectionMode.PAY

static func get_mode_name(mode: CollectionMode) -> String:
	match mode:
		CollectionMode.NONE:
			return "NONE"
		CollectionMode.COLLECT:
			return "COLLECT"
		CollectionMode.PAY:
			return "PAY"
		_:
			return "UNKNOWN"

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА TIE PUSH
# ═══════════════════════════════════════════════════════════════════════════

func is_tie_push_bet(bet_type: String) -> bool:
	"""Проверить, является ли ставка 'push' при Tie
	
	Рефакторено: использует IBetType вместо прямых проверок (OCP)
	
	При Tie ставки Player и Banker не выиграли и не проиграли - их нельзя трогать.
	Пары (PairPlayer, PairBanker) НЕ являются push при Tie.
	"""
	var bet_type_obj = BetTypeFactory.create(bet_type)
	if bet_type_obj:
		return bet_type_obj.is_tie_push(actual_winner)
	return false

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ПОСЛЕДОВАТЕЛЬНОСТЯМИ И ПОРЯДКОМ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# НУМЕРАЦИЯ ПОЗИЦИЙ В ЛИНИЯХ
# ═══════════════════════════════════════════════════════════════════════════

func get_line_position_number(bet_type: String, position_index: int) -> int:
	"""Получить номер позиции в линии (1 = самый правый, N = самый левый)
	
	Для всех типов ставок нумерация одинаковая: справа налево.
	Исключение: Tie при сборе использует обратный порядок (см. _get_sorted_tie_bets)
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		position_index: Индекс позиции в массиве ALTERNATIVE_POSITIONS
		
	Returns:
		Номер позиции в линии (1 = самый правый, N = самый левый)
	"""
	var key = "%s_%d" % [bet_type, position_index]
	
	# Проверяем кэш
	if _line_position_cache.has(key):
		return _line_position_cache[key]
	
	var number = 0
	
	# Для пар: объединяем PairPlayer и PairBanker
	if bet_type in ["PairPlayer", "PairBanker"]:
		number = _get_pairs_line_number(bet_type, position_index)
	else:
		# Для остальных: используем обычную логику
		number = _get_standard_line_number(bet_type, position_index)
	
	# Сохраняем в кэш
	_line_position_cache[key] = number
	return number

func _get_standard_line_number(bet_type: String, position_index: int) -> int:
	"""Получить номер позиции для стандартного типа (не пары)
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie")
		position_index: Индекс позиции
		
	Returns:
		Номер позиции (1 = самый правый)
	"""
	if not ChipVisualManager.ALTERNATIVE_POSITIONS.has(bet_type):
		return 0
	
	var positions = ChipVisualManager.ALTERNATIVE_POSITIONS[bet_type]
	if position_index < 0 or position_index >= positions.size():
		return 0
	
	# Сортируем все позиции по X (справа налево: больший X = меньший номер)
	var sorted_positions = []
	for i in range(positions.size()):
		sorted_positions.append({"index": i, "x": positions[i].x})
	
	sorted_positions.sort_custom(func(a, b): return a.x > b.x)  # Убывание X
	
	# Находим номер нашей позиции (1 = самый правый)
	for i in range(sorted_positions.size()):
		if sorted_positions[i].index == position_index:
			return i + 1  # Нумерация с 1
	
	return 0

func _get_pairs_line_number(bet_type: String, position_index: int) -> int:
	"""Получить номер позиции в объединённой линии пар
	
	Объединяет PairPlayer и PairBanker в одну линию, сортирует по X справа налево.
	
	Args:
		bet_type: "PairPlayer" или "PairBanker"
		position_index: Индекс позиции
		
	Returns:
		Номер позиции в объединённой линии (1 = самый правый)
	"""
	var all_pairs_positions = []
	
	# Собираем все позиции PairPlayer
	if ChipVisualManager.ALTERNATIVE_POSITIONS.has("PairPlayer"):
		var positions = ChipVisualManager.ALTERNATIVE_POSITIONS["PairPlayer"]
		for i in range(positions.size()):
			all_pairs_positions.append({
				"bet_type": "PairPlayer",
				"index": i,
				"x": positions[i].x
			})
	
	# Собираем все позиции PairBanker
	if ChipVisualManager.ALTERNATIVE_POSITIONS.has("PairBanker"):
		var positions = ChipVisualManager.ALTERNATIVE_POSITIONS["PairBanker"]
		for i in range(positions.size()):
			all_pairs_positions.append({
				"bet_type": "PairBanker",
				"index": i,
				"x": positions[i].x
			})
	
	# Сортируем по X (справа налево: больший X = меньший номер)
	all_pairs_positions.sort_custom(func(a, b): return a.x > b.x)
	
	# Находим номер нашей позиции (1 = самый правый)
	for i in range(all_pairs_positions.size()):
		if all_pairs_positions[i].bet_type == bet_type and \
		   all_pairs_positions[i].index == position_index:
			return i + 1  # Нумерация с 1
	
	return 0

func _get_bet_group(bet_type: String) -> String:
	"""Определить группу ставки
	
	Рефакторено: использует IBetType вместо match (OCP)
	
	Returns:
		"main" для Player/Banker
		"tie" для Tie
		"pairs" для PairPlayer/PairBanker
	"""
	var bet_type_obj = BetTypeFactory.create(bet_type)
	if bet_type_obj:
		return bet_type_obj.get_group()
	return ""

func _get_position_coordinates(bet_type: String, position_index: int) -> Vector2:
	"""Получить координаты позиции фишки
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции
		
	Returns:
		Vector2 координаты позиции или Vector2.ZERO если не найдено
	"""
	if not ChipVisualManager.ALTERNATIVE_POSITIONS.has(bet_type):
		return Vector2.ZERO
	
	var positions = ChipVisualManager.ALTERNATIVE_POSITIONS[bet_type]
	if position_index < 0 or position_index >= positions.size():
		return Vector2.ZERO
	
	return positions[position_index]

func _get_sorted_main_bets(winning: bool) -> Array[PayoutQueueManager.BetData]:
	"""Получить отсортированные основные ставки (Player/Banker) справа налево
	
	Args:
		winning: true для выигрышных ставок, false для проигрышных
		
	Returns:
		Отсортированный массив ставок справа налево (по X координате по убыванию)
	"""
	if not payout_queue_manager:
		return []
	
	var bets: Array[PayoutQueueManager.BetData] = []
	
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
		if bet.bet_type in types_to_include and bet.won == winning:
			bets.append(bet)
	
	# Сортируем справа налево по номеру позиции (номер 1, 2, 3...)
	bets.sort_custom(func(a, b): 
		var num_a = get_line_position_number(a.bet_type, a.position_index)
		var num_b = get_line_position_number(b.bet_type, b.position_index)
		return num_a < num_b  # Меньший номер = правее = идёт первым
	)
	
	return bets

func _get_sorted_tie_bets(winning: bool) -> Array[PayoutQueueManager.BetData]:
	"""Получить отсортированные Tie ставки
	- Для сбора (winning=false): слева направо (обратный порядок номеров)
	- Для оплаты (winning=true): справа налево (прямой порядок номеров)
	"""
	if not payout_queue_manager:
		return []
	
	var bets: Array[PayoutQueueManager.BetData] = []
	
	for bet in payout_queue_manager.bets:
		if bet.bet_type == "Tie" and bet.won == winning:
			bets.append(bet)
	
	# Используем нумерацию позиций (1 = самый правый)
	if winning:
		# Оплата: справа налево (номер 1, 2, 3...)
		bets.sort_custom(func(a, b):
			var num_a = get_line_position_number(a.bet_type, a.position_index)
			var num_b = get_line_position_number(b.bet_type, b.position_index)
			return num_a < num_b  # Меньший номер = правее = идёт первым
		)
	else:
		# Сбор: слева направо (номер 3, 2, 1...)
		bets.sort_custom(func(a, b):
			var num_a = get_line_position_number(a.bet_type, a.position_index)
			var num_b = get_line_position_number(b.bet_type, b.position_index)
			return num_a > num_b  # Больший номер = левее = идёт первым
		)
	
	return bets

func _get_sorted_pair_bets(winning: bool) -> Array[PayoutQueueManager.BetData]:
	"""Получить отсортированные пары (PairPlayer + PairBanker вместе) справа налево
	
	Пары объединены в одну линию и сортируются по номеру позиции (1 = самый правый)
	"""
	if not payout_queue_manager:
		return []
	
	var bets: Array[PayoutQueueManager.BetData] = []
	
	for bet in payout_queue_manager.bets:
		if (bet.bet_type == "PairPlayer" or bet.bet_type == "PairBanker") and bet.won == winning:
			bets.append(bet)
	
	# Сортируем справа налево по номеру позиции (номер 1, 2, 3...)
	bets.sort_custom(func(a, b):
		var num_a = get_line_position_number(a.bet_type, a.position_index)
		var num_b = get_line_position_number(b.bet_type, b.position_index)
		return num_a < num_b  # Меньший номер = правее = идёт первым
	)
	
	return bets

func _initialize_collection_sequence() -> void:
	"""Инициализировать последовательности для сбора проигрышных ставок"""
	collection_sequence.clear()
	collection_progress = {"main": 0, "tie": 0, "pairs": 0}
	
	collection_sequence["main"] = _get_sorted_main_bets(false)
	collection_sequence["tie"] = _get_sorted_tie_bets(false)
	collection_sequence["pairs"] = _get_sorted_pair_bets(false)
	
	print("📋 Последовательности сбора инициализированы:")
	print("  Основные: %d, Tie: %d, Пары: %d" % [
		collection_sequence["main"].size(),
		collection_sequence["tie"].size(),
		collection_sequence["pairs"].size()
	])
	
	# Отладочный вывод порядка пар (если есть)
	if collection_sequence["pairs"].size() > 0:
		print("  📍 Порядок пар (справа налево):")
		for i in range(collection_sequence["pairs"].size()):
			var bet = collection_sequence["pairs"][i]
			var pos_num = get_line_position_number(bet.bet_type, bet.position_index)
			var pos = _get_position_coordinates(bet.bet_type, bet.position_index)
			print("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet.bet_type, bet.position_index, pos_num, pos.x, pos.y])

func _initialize_payment_sequence() -> void:
	"""Инициализировать последовательности для оплаты выигрышных ставок"""
	payment_sequence.clear()
	payment_progress = {"main": 0, "tie": 0, "pairs": 0}
	
	payment_sequence["main"] = _get_sorted_main_bets(true)
	payment_sequence["tie"] = _get_sorted_tie_bets(true)
	payment_sequence["pairs"] = _get_sorted_pair_bets(true)
	
	print("📋 Последовательности оплаты инициализированы:")
	print("  Основные: %d, Tie: %d, Пары: %d" % [
		payment_sequence["main"].size(),
		payment_sequence["tie"].size(),
		payment_sequence["pairs"].size()
	])
	
	# Выводим порядок основных ставок для отладки
	if payment_sequence["main"].size() > 0:
		print("  📍 Порядок основных ставок (справа налево):")
		for i in range(payment_sequence["main"].size()):
			var bet = payment_sequence["main"][i]
			var pos_num = get_line_position_number(bet.bet_type, bet.position_index)
			var pos = _get_position_coordinates(bet.bet_type, bet.position_index)
			print("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet.bet_type, bet.position_index, pos_num, pos.x, pos.y])
	
	# Отладочный вывод порядка пар (если есть)
	if payment_sequence["pairs"].size() > 0:
		print("  📍 Порядок пар (справа налево):")
		for i in range(payment_sequence["pairs"].size()):
			var bet = payment_sequence["pairs"][i]
			var pos_num = get_line_position_number(bet.bet_type, bet.position_index)
			var pos = _get_position_coordinates(bet.bet_type, bet.position_index)
			print("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet.bet_type, bet.position_index, pos_num, pos.x, pos.y])

func _get_expected_next_bet(group: String, is_collecting: bool) -> PayoutQueueManager.BetData:
	"""Получить следующую ожидаемую ставку в группе
	
	Args:
		group: Группа ставок ("main", "tie", "pairs")
		is_collecting: true для сбора, false для оплаты
		
	Returns:
		BetData следующей ожидаемой ставки или null если все собраны/оплачены
	"""
	var sequence = collection_sequence[group] if is_collecting else payment_sequence[group]
	var progress = collection_progress[group] if is_collecting else payment_progress[group]
	
	if not sequence:
		print("  ⚠️  Последовательность для группы '%s' не найдена" % group)
		return null
	
	if progress >= sequence.size():
		print("  ✅ Все ставки в группе '%s' обработаны (progress=%d, size=%d)" % [group, progress, sequence.size()])
		return null
	
	var expected = sequence[progress]
	print("  📍 Ожидаемая ставка в группе '%s' (progress=%d/%d): %s[%d]" % [group, progress, sequence.size(), expected.bet_type, expected.position_index])
	return expected

# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ ДЕЙСТВИЙ
# ═══════════════════════════════════════════════════════════════════════════

func validate_chip_click(bet_type: String, position_index: int = 0) -> Dictionary:
	"""Валидация клика на фишку
	
	Returns:
		Dictionary с полями:
		- can_proceed: bool - можно ли выполнить действие
		- error_type: String - тип ошибки (если есть)
		- error_message: String - сообщение об ошибке (если есть)
		- action: String - действие которое нужно выполнить ("collect", "pay", "none")
	"""
	# Проверка инициализации
	if not payout_queue_manager:
		return _error_result("no_queue", "Менеджер ставок не инициализирован")
	
	# Режим не выбран - ничего не делаем
	if current_mode == CollectionMode.NONE:
		return _success_result("none")
	
	var bet = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	if not bet:
		# Пробуем найти по типу (для обратной совместимости)
		bet = payout_queue_manager.get_bet_by_type(bet_type)
	if not bet:
		return _error_result("no_bet", "Ставка %s[%d] не найдена" % [bet_type, position_index])
	
	# Проверка Tie push - применяется к обоим режимам
	if is_tie_push_bet(bet_type):
		return _error_result("tie_push", "ERR_CANNOT_COLLECT_TIE_PUSH")
	
	# Валидация в режиме COLLECT
	if current_mode == CollectionMode.COLLECT:
		return _validate_collect(bet, bet_type, position_index)
	
	# Валидация в режиме PAY
	if current_mode == CollectionMode.PAY:
		return _validate_pay(bet, bet_type, position_index)
	
	return _error_result("unknown_mode", "Неизвестный режим")

func _validate_collect(bet: PayoutQueueManager.BetData, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Валидация попытки собрать ставку"""
	
	# Нельзя собирать выигрышные
	if bet.won:
		return _error_result("collect_winning", "ERR_COLLECT_WINNING")
	
	# Проверяем, не собрана ли уже
	var bet_id = "%s_%d" % [bet_type, position_index]
	if collected_bets_by_id.has(bet_id) or bet.is_collected:
		return _error_result("already_collected", "Ставка уже собрана")
	
	# Проверяем порядок сбора
	var group = _get_bet_group(bet_type)
	if group.is_empty():
		return _error_result("unknown_group", "Неизвестная группа ставки")
	
	# Проверяем порядок внутри группы
	var expected_bet = _get_expected_next_bet(group, true)
	
	# Если в группе ещё есть не собранные ставки, проверяем порядок
	if expected_bet:
		# Сначала проверяем, закончена ли предыдущая группа
		# Основные должны собираться первыми, затем Tie, затем пары
		var group_order = ["main", "tie", "pairs"]
		var current_group_index = group_order.find(group)
		
		# Проверяем, что все предыдущие группы закончены
		for i in range(current_group_index):
			var prev_group = group_order[i]
			var prev_sequence = collection_sequence.get(prev_group, [])
			var prev_progress = collection_progress[prev_group]
			
			if prev_progress < prev_sequence.size():
				# Предыдущая группа не закончена
				match prev_group:
					"main":
						return _error_result("wrong_order", "ERR_COLLECT_MAIN_FIRST")
					"tie":
						return _error_result("wrong_order", "ERR_COLLECT_TIE_FIRST")
					"pairs":
						# Пары собираются последними, это не должно произойти
						return _error_result("wrong_order", "ERR_WRONG_COLLECT_ORDER")
		
		# Проверяем, что кликнули на правильную следующую ставку
		if expected_bet.bet_type != bet_type or expected_bet.position_index != position_index:
			return _error_result("wrong_order", "ERR_WRONG_COLLECT_ORDER")
	
	return _success_result("collect")

func _validate_pay(bet: PayoutQueueManager.BetData, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Валидация попытки оплатить ставку"""
	
	# Нельзя оплачивать проигрышные
	if not bet.won:
		return _error_result("pay_losing", "Нельзя оплачивать проигрышные ставки")
	
	# Проверяем, не оплачена ли уже
	if bet.is_paid:
		return _error_result("already_paid", "Ставка уже оплачена")
	
	# Проверяем, все ли проигрышные собраны
	if has_uncollected_losing_bets():
		return _error_result("uncollected_losing", "ERR_PAY_BEFORE_COLLECT")
	
	# Проверяем порядок оплаты
	var group = _get_bet_group(bet_type)
	if group.is_empty():
		return _error_result("unknown_group", "Неизвестная группа ставки")
	
	# Сначала проверяем, закончена ли предыдущая группа
	# Основные должны оплачиваться первыми, затем Tie, затем пары
	var group_order = ["main", "tie", "pairs"]
	var current_group_index = group_order.find(group)
	
	# Проверяем, что все предыдущие группы закончены
	for i in range(current_group_index):
		var prev_group = group_order[i]
		var prev_sequence = payment_sequence.get(prev_group, [])
		var prev_progress = payment_progress[prev_group]
		
		print("🔍 DEBUG: Проверка группы '%s': progress=%d, sequence_size=%d" % [prev_group, prev_progress, prev_sequence.size()])
		
		if prev_progress < prev_sequence.size():
			# Предыдущая группа не закончена
			print("  ❌ Группа '%s' не закончена!" % prev_group)
			match prev_group:
				"main":
					return _error_result("wrong_order", "ERR_PAY_MAIN_FIRST")
				"tie":
					return _error_result("wrong_order", "ERR_PAY_TIE_FIRST")
				"pairs":
					# Пары оплачиваются последними, это не должно произойти
					return _error_result("wrong_order", "ERR_WRONG_PAY_ORDER")
		else:
			print("  ✅ Группа '%s' закончена" % prev_group)
	
	# Проверяем порядок внутри группы
	var expected_bet = _get_expected_next_bet(group, false)
	
	# Если в группе ещё есть неоплаченные ставки, проверяем порядок
	if expected_bet:
		print("🔍 DEBUG: Ожидаемая ставка: %s[%d], кликнута: %s[%d]" % [expected_bet.bet_type, expected_bet.position_index, bet_type, position_index])
		# Проверяем, что кликнули на правильную следующую ставку
		if expected_bet.bet_type != bet_type or expected_bet.position_index != position_index:
			print("  ❌ Неправильный порядок! Ожидалась %s[%d], кликнута %s[%d]" % [expected_bet.bet_type, expected_bet.position_index, bet_type, position_index])
			return _error_result("wrong_order", "ERR_WRONG_PAY_ORDER")
		else:
			print("  ✅ Правильная ставка!")
	else:
		print("🔍 DEBUG: Все ставки в группе '%s' уже оплачены" % group)
	
	return _success_result("pay")

func _success_result(action: String) -> Dictionary:
	return {
		"can_proceed": true,
		"error_type": "",
		"error_message": "",
		"action": action
	}

func _error_result(error_type: String, message: String) -> Dictionary:
	return {
		"can_proceed": false,
		"error_type": error_type,
		"error_message": message,
		"action": "none"
	}

# ═══════════════════════════════════════════════════════════════════════════
# ВЫПОЛНЕНИЕ ДЕЙСТВИЙ
# ═══════════════════════════════════════════════════════════════════════════

func collect_bet(bet_type: String, position_index: int = 0) -> bool:
	"""Собрать проигрышную ставку
	
	Returns:
		true если ставка успешно собрана
	"""
	var bet_id = "%s_%d" % [bet_type, position_index]
	
	if collected_bets_by_id.has(bet_id):
		return false
	
	collected_bets_by_id[bet_id] = true
	
	# Для обратной совместимости - добавляем тип, если его ещё нет
	if bet_type not in collected_losing_bets:
		collected_losing_bets.append(bet_type)
	
	# Отмечаем в PayoutQueueManager
	if payout_queue_manager:
		payout_queue_manager.mark_as_collected(bet_type, position_index)
	
	# Обновляем прогресс сбора
	var group = _get_bet_group(bet_type)
	if not group.is_empty() and collection_progress.has(group):
		collection_progress[group] += 1
	
	bet_collected.emit(bet_type)
	chip_collected.emit(bet_type, position_index)
	print("💰 BetCollectionPhaseManager: ставка %s[%d] собрана" % [bet_type, position_index])
	return true


func pay_bet(bet_type: String, position_index: int = 0) -> bool:
	"""Оплатить выигрышную ставку
	
	Returns:
		true если ставка успешно оплачена
	"""
	print("🔍 DEBUG pay_bet(): вызван для %s[%d]" % [bet_type, position_index])
	
	if not payout_queue_manager:
		print("  ❌ payout_queue_manager не установлен!")
		return false
	
	# Проверяем, оплачена ли ставка (может быть уже оплачена в GameController)
	var bet = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	if not bet:
		print("  ❌ Ставка %s[%d] не найдена!" % [bet_type, position_index])
		return false
	
	if not bet.is_paid:
		# Если еще не оплачена, отмечаем
		if not payout_queue_manager.mark_as_paid(bet_type, position_index):
			print("  ❌ Не удалось отметить ставку как оплаченную!")
			return false
	
	# Обновляем прогресс оплаты (независимо от того, была ли ставка уже оплачена)
	var group = _get_bet_group(bet_type)
	if not group.is_empty() and payment_progress.has(group):
		var old_progress = payment_progress[group]
		var sequence = payment_sequence.get(group, [])
		
		# Проверяем, что оплачиваемая ставка действительно следующая в последовательности
		if old_progress < sequence.size():
			var expected = sequence[old_progress]
			if expected.bet_type == bet_type and expected.position_index == position_index:
				payment_progress[group] += 1
				print("💰 BetCollectionPhaseManager: ставка %s[%d] оплачена, группа '%s': progress %d -> %d" % [bet_type, position_index, group, old_progress, payment_progress[group]])
				
				# Показываем следующую ожидаемую ставку
				if payment_progress[group] < sequence.size():
					var next_expected = sequence[payment_progress[group]]
					print("  📍 Следующая ожидаемая ставка: %s[%d]" % [next_expected.bet_type, next_expected.position_index])
				else:
					print("  ✅ Все ставки в группе '%s' оплачены" % group)
			else:
				push_error("❌ КРИТИЧЕСКАЯ ОШИБКА: Оплачивается ставка %s[%d], но ожидалась %s[%d]!" % [bet_type, position_index, expected.bet_type, expected.position_index])
				# Все равно увеличиваем прогресс, но это ошибка
				payment_progress[group] += 1
		else:
			push_error("❌ КРИТИЧЕСКАЯ ОШИБКА: Прогресс группы '%s' (%d) >= размера последовательности (%d)!" % [group, old_progress, sequence.size()])
	
	chip_paid.emit(bet_type, position_index)
	print("💰 BetCollectionPhaseManager: ставка %s[%d] оплачена" % [bet_type, position_index])
	return true


func is_bet_collected(bet_type: String, position_index: int = -1) -> bool:
	"""Проверить, собрана ли ставка"""
	if position_index < 0:
		# Для обратной совместимости
		return bet_type in collected_losing_bets
	
	var bet_id = "%s_%d" % [bet_type, position_index]
	return collected_bets_by_id.has(bet_id)

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СОСТОЯНИЯ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════

func has_uncollected_losing_bets() -> bool:
	"""Проверить, есть ли не собранные проигрышные ставки (исключая Tie push)"""
	if not payout_queue_manager:
		return false
	
	for bet in payout_queue_manager.bets:
		if not bet.won and not bet.is_collected:
			# Проверяем по ID
			var bet_id = "%s_%d" % [bet.bet_type, bet.position_index]
			if not collected_bets_by_id.has(bet_id):
				# Исключаем Tie push ставки
				if not is_tie_push_bet(bet.bet_type):
					return true
	return false

func get_uncollected_losing_count() -> int:
	"""Количество не собранных проигрышных ставок (исключая Tie push)"""
	if not payout_queue_manager:
		return 0
	
	var count = 0
	for bet in payout_queue_manager.bets:
		if not bet.won and not bet.is_collected:
			var bet_id = "%s_%d" % [bet.bet_type, bet.position_index]
			if not collected_bets_by_id.has(bet_id):
				if not is_tie_push_bet(bet.bet_type):
					count += 1
	return count

func has_unpaid_winnings() -> bool:
	"""Проверить, есть ли неоплаченные выигрышные ставки (исключая Tie push)"""
	if not payout_queue_manager:
		return false
	
	for bet in payout_queue_manager.bets:
		if bet.won and not bet.is_paid:
			# Исключаем Tie push ставки
			if not is_tie_push_bet(bet.bet_type):
				return true
	return false

func get_unpaid_winnings_count() -> int:
	"""Количество неоплаченных выигрышных ставок (исключая Tie push)"""
	if not payout_queue_manager:
		return 0
	
	var count = 0
	for bet in payout_queue_manager.bets:
		if bet.won and not bet.is_paid:
			if not is_tie_push_bet(bet.bet_type):
				count += 1
	return count

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ВОЗМОЖНОСТИ ЗАВЕРШЕНИЯ РАУНДА
# ═══════════════════════════════════════════════════════════════════════════

func can_complete_round() -> Dictionary:
	"""Проверить, можно ли завершить раунд
	
	Returns:
		Dictionary с полями:
		- can: bool - можно ли завершить
		- reasons: Array[String] - список причин почему нельзя
		- error_key: String - ключ локализации для сообщения об ошибке
	"""
	var reasons: Array[String] = []
	var error_key = ""
	
	# Проверяем не собранные проигрышные ставки
	if has_uncollected_losing_bets():
		reasons.append("uncollected_losing")
		if error_key.is_empty():
			error_key = "ERR_COMPLETE_BEFORE_COLLECT"
	
	# Проверяем неоплаченные выигрышные ставки
	if has_unpaid_winnings():
		reasons.append("unpaid_winnings")
		if error_key.is_empty():
			error_key = "ERR_COMPLETE_BEFORE_PAY"
	
	return {
		"can": reasons.is_empty(),
		"reasons": reasons,
		"error_key": error_key
	}

# ═══════════════════════════════════════════════════════════════════════════
# ОТЛАДКА
# ═══════════════════════════════════════════════════════════════════════════

func print_status() -> void:
	"""Вывести статус для отладки"""
	print("═══ BetCollectionPhaseManager Status ═══")
	print("Режим: %s" % get_mode_name(current_mode))
	print("Победитель: %s" % actual_winner)
	print("Собрано проигрышных (по ID): %d" % collected_bets_by_id.size())
	for bet_id in collected_bets_by_id.keys():
		print("  - %s" % bet_id)
	print("Не собрано проигрышных: %d" % get_uncollected_losing_count())
	print("Не оплачено выигрышных: %d" % get_unpaid_winnings_count())
	var completion = can_complete_round()
	print("Можно завершить: %s" % completion.can)
	if not completion.can:
		print("  Причины: %s" % str(completion.reasons))
	print("═════════════════════════════════════════")
