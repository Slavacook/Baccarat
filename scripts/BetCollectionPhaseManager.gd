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

# Флаг блокировки для защиты от параллельных операций
var is_processing: bool = false

# Валидатор для операций (Strategy Pattern - для расширяемости)
var validator: IBetCollectionValidator = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(queue_manager: PayoutQueueManager, winner: String, custom_validator: IBetCollectionValidator = null) -> void:
	"""Настроить менеджер для нового раунда
	
	ВАЖНО: Должен вызываться ПОСЛЕ того, как все ставки добавлены в queue_manager
	
	Args:
		queue_manager: Менеджер очереди выплат с информацией о ставках
		winner: Победитель раунда ("Player", "Banker", "Tie")
		custom_validator: Кастомный валидатор (опционально, для расширяемости)
	"""
	payout_queue_manager = queue_manager
	actual_winner = winner
	collected_losing_bets.clear()
	collected_bets_by_id.clear()
	current_mode = CollectionMode.NONE
	
	# Устанавливаем валидатор (по умолчанию используем внутреннюю логику)
	if custom_validator:
		validator = custom_validator
	else:
		# Создаём валидатор по умолчанию, который использует внутренние методы
		if not validator:
			validator = DefaultBetCollectionValidator.new(self)
	
	# Сбрасываем флаг блокировки при настройке нового раунда
	is_processing = false
	
	# Инициализируем последовательности для проверки порядка (ПОСЛЕ добавления всех ставок)
	initialize_sequences()
	
	DebugLogger.log("✅ BetCollectionPhaseManager: настроен для раунда (победитель: %s)" % winner)

func initialize_sequences() -> void:
	"""Инициализировать последовательности для проверки порядка (вызывается ПОСЛЕ добавления всех ставок)
	
	ВАЖНО: Должен вызываться ПОСЛЕ того, как все ставки добавлены в payout_queue_manager
	"""
	if not payout_queue_manager:
		DebugLogger.log_error("initialize_sequences() вызван без payout_queue_manager!")
		return
	
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
	is_processing = false  # Сбрасываем флаг блокировки
	# Валидатор НЕ сбрасываем - он может быть переиспользован
	set_mode(CollectionMode.NONE)
	DebugLogger.log("🔄 BetCollectionPhaseManager: сброшен")

func set_validator(custom_validator: IBetCollectionValidator) -> void:
	"""Установить кастомный валидатор (для расширяемости)
	
	Args:
		custom_validator: Реализация IBetCollectionValidator
	"""
	validator = custom_validator
	DebugLogger.log("✅ BetCollectionPhaseManager: установлен кастомный валидатор")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ РЕЖИМАМИ
# ═══════════════════════════════════════════════════════════════════════════

func set_mode(mode: CollectionMode) -> void:
	"""Установить режим взаимодействия с фишками"""
	if mode != current_mode:
		current_mode = mode
		mode_changed.emit(mode)
		var mode_name = get_mode_name(mode)
		DebugLogger.log("🔄 BetCollectionPhaseManager: режим изменен на %s" % mode_name)

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
	
	DebugLogger.log("📋 Последовательности сбора инициализированы:")
	DebugLogger.log("  Основные: %d, Tie: %d, Пары: %d" % [
		collection_sequence["main"].size(),
		collection_sequence["tie"].size(),
		collection_sequence["pairs"].size()
	])
	
	# Отладочный вывод порядка пар (если есть)
	if collection_sequence["pairs"].size() > 0:
		DebugLogger.log("  📍 Порядок пар (справа налево):")
		for i in range(collection_sequence["pairs"].size()):
			var bet = collection_sequence["pairs"][i]
			var pos_num = get_line_position_number(bet.bet_type, bet.position_index)
			var pos = _get_position_coordinates(bet.bet_type, bet.position_index)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet.bet_type, bet.position_index, pos_num, pos.x, pos.y])

func _initialize_payment_sequence() -> void:
	"""Инициализировать последовательности для оплаты выигрышных ставок"""
	payment_sequence.clear()
	payment_progress = {"main": 0, "tie": 0, "pairs": 0}
	
	payment_sequence["main"] = _get_sorted_main_bets(true)
	payment_sequence["tie"] = _get_sorted_tie_bets(true)
	payment_sequence["pairs"] = _get_sorted_pair_bets(true)
	
	DebugLogger.log("📋 Последовательности оплаты инициализированы:")
	DebugLogger.log("  Основные: %d, Tie: %d, Пары: %d" % [
		payment_sequence["main"].size(),
		payment_sequence["tie"].size(),
		payment_sequence["pairs"].size()
	])
	
	# Выводим порядок основных ставок для отладки
	if payment_sequence["main"].size() > 0:
		DebugLogger.log("  📍 Порядок основных ставок (справа налево):")
		for i in range(payment_sequence["main"].size()):
			var bet = payment_sequence["main"][i]
			var pos_num = get_line_position_number(bet.bet_type, bet.position_index)
			var pos = _get_position_coordinates(bet.bet_type, bet.position_index)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet.bet_type, bet.position_index, pos_num, pos.x, pos.y])
	
	# Отладочный вывод порядка пар (если есть)
	if payment_sequence["pairs"].size() > 0:
		DebugLogger.log("  📍 Порядок пар (справа налево):")
		for i in range(payment_sequence["pairs"].size()):
			var bet = payment_sequence["pairs"][i]
			var pos_num = get_line_position_number(bet.bet_type, bet.position_index)
			var pos = _get_position_coordinates(bet.bet_type, bet.position_index)
			DebugLogger.log("    %d. %s[%d] номер=%d позиция=(%.0f, %.0f)" % [i, bet.bet_type, bet.position_index, pos_num, pos.x, pos.y])

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
		DebugLogger.log_warning("Последовательность для группы '%s' не найдена" % group)
		return null
	
	if progress >= sequence.size():
		DebugLogger.log("  ✅ Все ставки в группе '%s' обработаны (progress=%d, size=%d)" % [group, progress, sequence.size()])
		return null
	
	var expected = sequence[progress]
	DebugLogger.log("  📍 Ожидаемая ставка в группе '%s' (progress=%d/%d): %s[%d]" % [group, progress, sequence.size(), expected.bet_type, expected.position_index])
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
	
	var bet_data = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	if not bet_data:
		# Пробуем найти по типу (для обратной совместимости)
		bet_data = payout_queue_manager.get_bet_by_type(bet_type)
	if not bet_data:
		return _error_result("no_bet", "Ставка %s[%d] не найдена" % [bet_type, position_index])
	
	# Проверка Tie push - применяется к обоим режимам
	if is_tie_push_bet(bet_type):
		return _error_result("tie_push", "ERR_CANNOT_COLLECT_TIE_PUSH")
	
	# Валидация в режиме COLLECT
	if current_mode == CollectionMode.COLLECT:
		# Используем валидатор если установлен, иначе внутреннюю логику
		if validator:
			var context = {
				"current_mode": current_mode,
				"actual_winner": actual_winner,
				"collection_progress": collection_progress,
				"collection_sequence": collection_sequence
			}
			return validator.validate_collect(bet_data, bet_type, position_index, context)
		else:
			return _validate_collect(bet_data, bet_type, position_index)
	
	# Валидация в режиме PAY
	if current_mode == CollectionMode.PAY:
		# Используем валидатор если установлен, иначе внутреннюю логику
		if validator:
			var context = {
				"current_mode": current_mode,
				"actual_winner": actual_winner,
				"payment_progress": payment_progress,
				"payment_sequence": payment_sequence
			}
			return validator.validate_pay(bet_data, bet_type, position_index, context)
		else:
			return _validate_pay(bet_data, bet_type, position_index)
	
	return _error_result("unknown_mode", "Неизвестный режим")

# ═══════════════════════════════════════════════════════════════════════════
# ВНУТРЕННИЕ МЕТОДЫ ВАЛИДАЦИИ (для использования валидатором)
# ═══════════════════════════════════════════════════════════════════════════

func _validate_collect_internal(bet: PayoutQueueManager.BetData, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Внутренний метод валидации сбора (используется валидатором)"""
	return _validate_collect(bet, bet_type, position_index)

func _validate_pay_internal(bet: PayoutQueueManager.BetData, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Внутренний метод валидации оплаты (используется валидатором)"""
	return _validate_pay(bet, bet_type, position_index)

func _validate_collect(bet: PayoutQueueManager.BetData, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Валидация попытки собрать ставку"""
	
	# Нельзя собирать выигрышные
	if bet.won:
		return _error_result("collect_winning", "ERR_COLLECT_WINNING")
	
	# Проверяем, не собрана ли уже (используем bet.is_collected как единственный источник истины)
	if bet.is_collected:
		return _error_result("already_collected", "Ставка уже собрана")
	
	# Проверяем согласованность с кэшем (для обнаружения рассинхронизации)
	var bet_id = "%s_%d" % [bet_type, position_index]
	if collected_bets_by_id.has(bet_id) and not bet.is_collected:
		# Рассинхронизация: в кэше есть, но bet.is_collected = false
		DebugLogger.log_warning("Рассинхронизация обнаружена для %s: исправляем кэш" % bet_id)
		collected_bets_by_id.erase(bet_id)
	
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
		
		DebugLogger.log("🔍 DEBUG: Проверка группы '%s': progress=%d, sequence_size=%d" % [prev_group, prev_progress, prev_sequence.size()])
		
		if prev_progress < prev_sequence.size():
			# Предыдущая группа не закончена
			DebugLogger.log("  ❌ Группа '%s' не закончена!" % prev_group)
			match prev_group:
				"main":
					return _error_result("wrong_order", "ERR_PAY_MAIN_FIRST")
				"tie":
					return _error_result("wrong_order", "ERR_PAY_TIE_FIRST")
				"pairs":
					# Пары оплачиваются последними, это не должно произойти
					return _error_result("wrong_order", "ERR_WRONG_PAY_ORDER")
		else:
			DebugLogger.log("  ✅ Группа '%s' закончена" % prev_group)
	
	# Проверяем порядок внутри группы
	var expected_bet = _get_expected_next_bet(group, false)
	
	# Если в группе ещё есть неоплаченные ставки, проверяем порядок
	if expected_bet:
		DebugLogger.log("🔍 DEBUG: Ожидаемая ставка: %s[%d], кликнута: %s[%d]" % [expected_bet.bet_type, expected_bet.position_index, bet_type, position_index])
		# Проверяем, что кликнули на правильную следующую ставку
		if expected_bet.bet_type != bet_type or expected_bet.position_index != position_index:
			DebugLogger.log("  ❌ Неправильный порядок! Ожидалась %s[%d], кликнута %s[%d]" % [expected_bet.bet_type, expected_bet.position_index, bet_type, position_index])
			return _error_result("wrong_order", "ERR_WRONG_PAY_ORDER")
		else:
			DebugLogger.log("  ✅ Правильная ставка!")
	else:
		DebugLogger.log("🔍 DEBUG: Все ставки в группе '%s' уже оплачены" % group)
	
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
	"""Собрать проигрышную ставку (транзакционная операция)
	
	Returns:
		true если ставка успешно собрана
	"""
	# ═══════════════════════════════════════════════════════════════════
	# ЗАЩИТА ОТ ПАРАЛЛЕЛЬНЫХ ОПЕРАЦИЙ
	# ═══════════════════════════════════════════════════════════════════
	if is_processing:
		DebugLogger.log_warning("⚠️  BetCollectionPhaseManager: операция уже выполняется, игнорируем клик")
		return false
	
	is_processing = true
	
	# ═══════════════════════════════════════════════════════════════════
	# ВАЛИДАЦИЯ ПЕРЕД ОПЕРАЦИЕЙ
	# ═══════════════════════════════════════════════════════════════════
	if not payout_queue_manager:
		DebugLogger.log_error("payout_queue_manager не установлен в collect_bet()")
		is_processing = false
		return false
	
	var bet = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	if not bet:
		# Для обратной совместимости пробуем по типу
		bet = payout_queue_manager.get_bet_by_type(bet_type)
		if not bet:
			DebugLogger.log_error("Ставка %s[%d] не найдена в collect_bet()" % [bet_type, position_index])
			is_processing = false
			return false
	
	# Проверяем что ставка ещё не собрана (единственный источник истины - bet.is_collected)
	if bet.is_collected:
		DebugLogger.log("⏸️  Ставка %s[%d] уже собрана, игнорируем" % [bet_type, position_index])
		is_processing = false
		return false
	
	# ═══════════════════════════════════════════════════════════════════
	# ТРАНЗАКЦИОННАЯ ОПЕРАЦИЯ (всё или ничего)
	# ═══════════════════════════════════════════════════════════════════
	var bet_id = "%s_%d" % [bet_type, position_index]
	var group = _get_bet_group(bet_type)
	
	# Сохраняем старое состояние для возможного rollback
	var old_collected_state = bet.is_collected
	var old_progress = collection_progress.get(group, 0) if not group.is_empty() else 0
	
	# Атомарно обновляем всё состояние
	bet.is_collected = true
	collected_bets_by_id[bet_id] = true
	
	# Для обратной совместимости - добавляем тип, если его ещё нет
	if bet_type not in collected_losing_bets:
		collected_losing_bets.append(bet_type)
	
	# Обновляем прогресс сбора
	if not group.is_empty() and collection_progress.has(group):
		collection_progress[group] += 1
	
	# Проверяем согласованность состояния после обновления
	if not _check_state_consistency(bet, bet_id):
		# Rollback при ошибке
		bet.is_collected = old_collected_state
		collected_bets_by_id.erase(bet_id)
		if not group.is_empty() and collection_progress.has(group):
			collection_progress[group] = old_progress
		DebugLogger.log_error("Рассинхронизация состояния при сборе ставки %s[%d], выполнен rollback" % [bet_type, position_index])
		is_processing = false
		return false
	
	# Эмитим сигналы только после успешного обновления
	bet_collected.emit(bet_type)
	chip_collected.emit(bet_type, position_index)
	
	DebugLogger.log("💰 BetCollectionPhaseManager: ставка %s[%d] собрана" % [bet_type, position_index])
	
	is_processing = false
	return true


func pay_bet(bet_type: String, position_index: int = 0) -> bool:
	"""Оплатить выигрышную ставку (транзакционная операция)
	
	Returns:
		true если ставка успешно оплачена
	"""
	# ═══════════════════════════════════════════════════════════════════
	# ЗАЩИТА ОТ ПАРАЛЛЕЛЬНЫХ ОПЕРАЦИЙ
	# ═══════════════════════════════════════════════════════════════════
	if is_processing:
		DebugLogger.log_warning("⚠️  BetCollectionPhaseManager: операция уже выполняется, игнорируем клик")
		return false
	
	is_processing = true
	
	# ═══════════════════════════════════════════════════════════════════
	# ВАЛИДАЦИЯ ПЕРЕД ОПЕРАЦИЕЙ
	# ═══════════════════════════════════════════════════════════════════
	if not payout_queue_manager:
		DebugLogger.log_error("payout_queue_manager не установлен в pay_bet()")
		is_processing = false
		return false
	
	var bet = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	var used_fallback = false
	if not bet:
		# Для обратной совместимости пробуем по типу
		bet = payout_queue_manager.get_bet_by_type(bet_type)
		used_fallback = true
		if not bet:
			DebugLogger.log_error("Ставка %s[%d] не найдена в pay_bet()" % [bet_type, position_index])
			is_processing = false
			return false
	
	# Если использовали fallback - используем position_index из найденной ставки
	if used_fallback and bet.position_index != position_index:
		DebugLogger.log("⚠️  pay_bet: использован fallback, корректируем position_index %d -> %d" % [position_index, bet.position_index])
		position_index = bet.position_index
	
	# Проверяем что ставка выигрышная (можно оплачивать только выигрышные)
	if not bet.won:
		DebugLogger.log("⚠️  Ставка %s[%d] не выиграла (won=%s), пропускаем оплату" % [bet_type, position_index, bet.won])
		is_processing = false
		return true  # Не ошибка, просто пропускаем

	# Проверяем что ставка ещё не оплачена (единственный источник истины - bet.is_paid)
	if bet.is_paid:
		DebugLogger.log("⏸️  Ставка %s[%d] уже оплачена, игнорируем" % [bet_type, position_index])
		is_processing = false
		return false
	
	# ═══════════════════════════════════════════════════════════════════
	# ТРАНЗАКЦИОННАЯ ОПЕРАЦИЯ (всё или ничего)
	# ═══════════════════════════════════════════════════════════════════
	var group = _get_bet_group(bet_type)
	
	# Сохраняем старое состояние для возможного rollback
	var old_paid_state = bet.is_paid
	var old_progress = payment_progress.get(group, 0) if not group.is_empty() else 0
	var sequence = payment_sequence.get(group, []) if not group.is_empty() else []
	
	# Отмечаем ставку как оплаченную
	if not payout_queue_manager.mark_as_paid(bet_type, position_index):
		DebugLogger.log_error("Не удалось отметить ставку %s[%d] как оплаченную" % [bet_type, position_index])
		is_processing = false
		return false
	
	# Обновляем прогресс оплаты с проверкой последовательности
	if not group.is_empty() and payment_progress.has(group) and old_progress < sequence.size():
		var expected = sequence[old_progress]
		if expected.bet_type == bet_type and expected.position_index == position_index:
			payment_progress[group] += 1
			DebugLogger.log("💰 BetCollectionPhaseManager: ставка %s[%d] оплачена, группа '%s': progress %d -> %d" % [bet_type, position_index, group, old_progress, payment_progress[group]])
			
			# Показываем следующую ожидаемую ставку
			if payment_progress[group] < sequence.size():
				var next_expected = sequence[payment_progress[group]]
				DebugLogger.log("  📍 Следующая ожидаемая ставка: %s[%d]" % [next_expected.bet_type, next_expected.position_index])
			else:
				DebugLogger.log("  ✅ Все ставки в группе '%s' оплачены" % group)
		else:
			# Критическая ошибка: оплачивается не та ставка
			DebugLogger.log_error("КРИТИЧЕСКАЯ ОШИБКА: Оплачивается ставка %s[%d], но ожидалась %s[%d]!" % [bet_type, position_index, expected.bet_type, expected.position_index])
			# Rollback
			bet.is_paid = old_paid_state
			payment_progress[group] = old_progress
			is_processing = false
			return false
	elif not group.is_empty() and old_progress >= sequence.size():
		DebugLogger.log_error("КРИТИЧЕСКАЯ ОШИБКА: Прогресс группы '%s' (%d) >= размера последовательности (%d)!" % [group, old_progress, sequence.size()])
		# Rollback
		bet.is_paid = old_paid_state
		is_processing = false
		return false
	
	# Проверяем согласованность состояния после обновления
	if not _check_payment_state_consistency(bet):
		# Rollback при ошибке
		bet.is_paid = old_paid_state
		if not group.is_empty() and payment_progress.has(group):
			payment_progress[group] = old_progress
		DebugLogger.log_error("Рассинхронизация состояния при оплате ставки %s[%d], выполнен rollback" % [bet_type, position_index])
		is_processing = false
		return false
	
	# Эмитим сигналы только после успешного обновления
	chip_paid.emit(bet_type, position_index)
	
	DebugLogger.log("💰 BetCollectionPhaseManager: ставка %s[%d] оплачена" % [bet_type, position_index])
	
	is_processing = false
	return true


func is_bet_collected(bet_type: String, position_index: int = -1) -> bool:
	"""Проверить, собрана ли ставка
	
	ВАЖНО: Использует bet.is_collected как единственный источник истины
	collected_bets_by_id - только для быстрого поиска (кэш)
	"""
	if not payout_queue_manager:
		return false
	
	if position_index < 0:
		# Для обратной совместимости - проверяем первую ставку по типу
		var bet_data = payout_queue_manager.get_bet_by_type(bet_type)
		if bet_data:
			return bet_data.is_collected
		return bet_type in collected_losing_bets
	
	# Используем bet.is_collected как единственный источник истины
	var bet = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	if bet:
		# Проверяем согласованность с кэшем
		var bet_id = "%s_%d" % [bet_type, position_index]
		var in_cache = collected_bets_by_id.has(bet_id)
		if in_cache != bet.is_collected:
			# Автоматическое исправление рассинхронизации
			DebugLogger.log_warning("Рассинхронизация для %s: кэш=%s, bet=%s, исправляем" % [bet_id, in_cache, bet.is_collected])
			if bet.is_collected:
				collected_bets_by_id[bet_id] = true
			else:
				collected_bets_by_id.erase(bet_id)
		return bet.is_collected
	
	return false

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СОСТОЯНИЯ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════

func has_uncollected_losing_bets() -> bool:
	"""Проверить, есть ли не собранные проигрышные ставки (исключая Tie push)
	
	ВАЖНО: Использует bet.is_collected как единственный источник истины
	"""
	if not payout_queue_manager:
		return false
	
	for bet in payout_queue_manager.bets:
		if not bet.won and not bet.is_collected:
			# Исключаем Tie push ставки
			if not is_tie_push_bet(bet.bet_type):
				# Проверяем согласованность с кэшем (автоисправление)
				var bet_id = "%s_%d" % [bet.bet_type, bet.position_index]
				if collected_bets_by_id.has(bet_id):
					# Рассинхронизация: в кэше есть, но bet.is_collected = false
					DebugLogger.log_warning("Рассинхронизация для %s: исправляем кэш" % bet_id)
					collected_bets_by_id.erase(bet_id)
				return true
	return false

func get_uncollected_losing_count() -> int:
	"""Количество не собранных проигрышных ставок (исключая Tie push)
	
	ВАЖНО: Использует bet.is_collected как единственный источник истины
	"""
	if not payout_queue_manager:
		return 0
	
	var count = 0
	for bet in payout_queue_manager.bets:
		if not bet.won and not bet.is_collected:
			# Исключаем Tie push ставки
			if not is_tie_push_bet(bet.bet_type):
				# Проверяем согласованность с кэшем (автоисправление)
				var bet_id = "%s_%d" % [bet.bet_type, bet.position_index]
				if collected_bets_by_id.has(bet_id):
					# Рассинхронизация: исправляем
					DebugLogger.log_warning("Рассинхронизация для %s: исправляем кэш" % bet_id)
					collected_bets_by_id.erase(bet_id)
				count += 1
	return count

func has_unpaid_winnings() -> bool:
	"""Проверить, есть ли неоплаченные выигрышные ставки (исключая Tie push)
	
	ВАЖНО: Использует bet.is_paid как единственный источник истины
	"""
	if not payout_queue_manager:
		return false
	
	for bet in payout_queue_manager.bets:
		if bet.won and not bet.is_paid:
			# Исключаем Tie push ставки
			if not is_tie_push_bet(bet.bet_type):
				return true
	return false

func get_unpaid_winnings_count() -> int:
	"""Количество неоплаченных выигрышных ставок (исключая Tie push)
	
	ВАЖНО: Использует bet.is_paid как единственный источник истины
	"""
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

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СОГЛАСОВАННОСТИ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _check_state_consistency(bet: PayoutQueueManager.BetData, bet_id: String) -> bool:
	"""Проверить согласованность состояния для собранной ставки
	
	Args:
		bet: Объект ставки
		bet_id: Идентификатор ставки (для кэша)
	
	Returns:
		true если состояние согласовано, false если есть рассинхронизация
	"""
	if not bet:
		return false
	
	var in_cache = collected_bets_by_id.has(bet_id)
	var in_bet = bet.is_collected
	
	if in_cache != in_bet:
		# Рассинхронизация обнаружена
		DebugLogger.log_warning("Рассинхронизация для %s: кэш=%s, bet.is_collected=%s" % [bet_id, in_cache, in_bet])
		# Автоматическое исправление
		if in_bet:
			collected_bets_by_id[bet_id] = true
		else:
			collected_bets_by_id.erase(bet_id)
		return false
	
	return true

func _check_payment_state_consistency(bet: PayoutQueueManager.BetData) -> bool:
	"""Проверить согласованность состояния для оплаченной ставки
	
	Args:
		bet: Объект ставки
	
	Returns:
		true если состояние согласовано
	"""
	if not bet:
		return false
	
	# Для оплаченных ставок проверяем что они действительно выиграли
	if bet.is_paid and not bet.won:
		DebugLogger.log_error("КРИТИЧЕСКАЯ ОШИБКА: Ставка %s[%d] помечена как оплаченная, но не выиграла!" % [bet.bet_type, bet.position_index])
		return false
	
	return true

func validate_all_state() -> Dictionary:
	"""Проверить согласованность всего состояния (для отладки)
	
	Returns:
		Dictionary с результатами проверки:
		- is_consistent: bool - согласовано ли состояние
		- issues: Array[String] - список проблем
	"""
	var issues: Array[String] = []
	
	if not payout_queue_manager:
		return {"is_consistent": false, "issues": ["payout_queue_manager не установлен"]}
	
	# Проверяем все ставки
	for bet in payout_queue_manager.get_all_bets():
		var bet_id = "%s_%d" % [bet.bet_type, bet.position_index]
		
		# Проверка для собранных ставок
		if bet.is_collected:
			var in_cache = collected_bets_by_id.has(bet_id)
			if not in_cache:
				issues.append("Ставка %s собрана (bet.is_collected=true), но отсутствует в кэше" % bet_id)
		
		# Проверка для оплаченных ставок
		if bet.is_paid and not bet.won:
			issues.append("Ставка %s оплачена, но не выиграла (won=false)" % bet_id)
	
	return {
		"is_consistent": issues.is_empty(),
		"issues": issues
	}

func print_status() -> void:
	"""Вывести статус для отладки"""
	DebugLogger.log("═══ BetCollectionPhaseManager Status ═══")
	DebugLogger.log("Режим: %s" % get_mode_name(current_mode))
	DebugLogger.log("Победитель: %s" % actual_winner)
	DebugLogger.log("Собрано проигрышных (по ID): %d" % collected_bets_by_id.size())
	for bet_id in collected_bets_by_id.keys():
		DebugLogger.log("  - %s" % bet_id)
	DebugLogger.log("Не собрано проигрышных: %d" % get_uncollected_losing_count())
	DebugLogger.log("Не оплачено выигрышных: %d" % get_unpaid_winnings_count())
	var completion = can_complete_round()
	DebugLogger.log("Можно завершить: %s" % completion.can)
	if not completion.can:
		DebugLogger.log("  Причины: %s" % str(completion.reasons))
	
	# Проверка согласованности состояния
	var consistency = validate_all_state()
	if not consistency.is_consistent:
		DebugLogger.log_warning("⚠️  Обнаружены проблемы согласованности:")
		for issue in consistency.issues:
			DebugLogger.log_warning("  - %s" % issue)
	
	DebugLogger.log("═════════════════════════════════════════")
