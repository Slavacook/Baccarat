# res://scripts/BetCollectionPhaseManager.gd
# Централизованный менеджер для фазы сбора проигрышных ставок и оплаты выигрышных
# Инкапсулирует логику валидации, состояний режимов и проверки возможности завершения раунда

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

signal mode_changed(new_mode: int)  # CollectionMode (int для парсинга)
signal bet_collected(bet_type: String)
# Новый сигнал с идентификатором конкретной фишки
signal chip_collected(bet_type: String, position_index: int)
signal chip_paid(bet_type: String, position_index: int)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var current_mode: CollectionMode = CollectionMode.NONE
var payout_queue_manager = null  # PayoutQueueManager (типизация убрана для парсинга)
var actual_winner: String = ""  # Победитель раунда (для проверки Tie push)

# Список собранных проигрышных ставок (для обратной совместимости)
var collected_losing_bets: Array[String] = []

# Словарь собранных ставок с position_index: {"Player_0": true, "Banker_2": true}
var collected_bets_by_id: Dictionary = {}

# Калькулятор номеров позиций в линиях
var position_calculator: LinePositionCalculator = LinePositionCalculator.new()

# Сортировщик ставок
var bet_sorter: BetSorter = BetSorter.new(position_calculator)

# Менеджер последовательностей (управляет collection_sequence, payment_sequence, progress)
var sequence_manager: SequenceManager = SequenceManager.new(bet_sorter, position_calculator)

# Проверка согласованности состояния
var state_checker: StateConsistencyChecker = StateConsistencyChecker.new()

# Свойства для обратной совместимости (делегируют в sequence_manager)
var collection_sequence: Dictionary:
	get: return sequence_manager.collection_sequence
var payment_sequence: Dictionary:
	get: return sequence_manager.payment_sequence
var collection_progress: Dictionary:
	get: return sequence_manager.collection_progress
var payment_progress: Dictionary:
	get: return sequence_manager.payment_progress

# Флаг блокировки для защиты от параллельных операций
var is_processing: bool = false

# Валидатор для операций (Strategy Pattern - для расширяемости)
var validator = null  # IBetCollectionValidator (типизация убрана для парсинга)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(queue_manager, winner: String, custom_validator = null) -> void:  # Типизация убрана для парсинга
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
	
	sequence_manager.initialize_collection_sequence(payout_queue_manager, actual_winner, _get_position_coordinates)
	sequence_manager.initialize_payment_sequence(payout_queue_manager, actual_winner, _get_position_coordinates)

func reset() -> void:
	"""Сбросить состояние менеджера"""
	payout_queue_manager = null
	actual_winner = ""
	collected_losing_bets.clear()
	collected_bets_by_id.clear()
	sequence_manager.reset()  # Сбрасываем последовательности и прогресс
	position_calculator.clear_cache()  # Очищаем кэш номеров позиций
	is_processing = false  # Сбрасываем флаг блокировки
	# Валидатор НЕ сбрасываем - он может быть переиспользован
	set_mode(CollectionMode.NONE)
	DebugLogger.log("🔄 BetCollectionPhaseManager: сброшен")

func set_validator(custom_validator) -> void:  # Типизация убрана для парсинга
	"""Установить кастомный валидатор (для расширяемости)
	
	Args:
		custom_validator: Реализация IBetCollectionValidator
	"""
	validator = custom_validator
	DebugLogger.log("✅ BetCollectionPhaseManager: установлен кастомный валидатор")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ РЕЖИМАМИ
# ═══════════════════════════════════════════════════════════════════════════

func set_mode(mode: CollectionMode, play_sound: bool = true) -> void:
	"""Установить режим взаимодействия с фишками
	
	Args:
		mode: Новый режим (COLLECT, PAY, NONE)
		play_sound: Играть ли звук переключения (по умолчанию true)
		           Если play_sound не указан явно, используется логика:
		           - Переход из NONE в COLLECT - без звука (автоматическая активация)
		           - Переключение COLLECT ↔ PAY - со звуком (действие пользователя)
	"""
	if mode != current_mode:
		var previous_mode = current_mode
		current_mode = mode
		mode_changed.emit(mode)
		var mode_name = get_mode_name(mode)
		DebugLogger.log("🔄 BetCollectionPhaseManager: режим изменен на %s" % mode_name)

		# Определяем, нужно ли играть звук
		var should_play_sound = play_sound
		
		# Если play_sound не указан явно (по умолчанию true), проверяем тип переключения
		if play_sound:
			# Переход из NONE в COLLECT - автоматическая активация (без звука)
			if previous_mode == CollectionMode.NONE and mode == CollectionMode.COLLECT:
				should_play_sound = false
			# Все остальные переключения (COLLECT ↔ PAY, PAY → COLLECT) - со звуком
		
		# Звук переключения режима
		if should_play_sound and SoundManager and mode != CollectionMode.NONE:
			SoundManager.play_mode_switch_sound()

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
	"""Проверить, активен ли режим сбора
	
	Returns:
		true если режим COLLECT активен, false иначе
	"""
	return current_mode == CollectionMode.COLLECT

func is_pay_mode() -> bool:
	"""Проверить, активен ли режим оплаты
	
	Returns:
		true если режим PAY активен, false иначе
	"""
	return current_mode == CollectionMode.PAY

static func get_mode_name(mode: CollectionMode) -> String:
	"""Получить строковое представление режима
	
	Args:
		mode: Режим CollectionMode
		
	Returns:
		Строковое представление режима ("NONE", "COLLECT", "PAY", "UNKNOWN")
	"""
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
# НУМЕРАЦИЯ ПОЗИЦИЙ В ЛИНИЯХ (делегировано в LinePositionCalculator)
# ═══════════════════════════════════════════════════════════════════════════

func get_line_position_number(bet_type: String, position_index: int) -> int:
	"""Получить номер позиции в линии (1 = самый правый, N = самый левый)
	
	Делегирует вычисление в LinePositionCalculator.
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		position_index: Индекс позиции в массиве ALTERNATIVE_POSITIONS
		
	Returns:
		Номер позиции в линии (1 = самый правый, N = самый левый)
	"""
	return position_calculator.get_line_position_number(bet_type, position_index)

func get_bet_group(bet_type: String) -> String:
	"""Определить группу ставки (публичный метод)
	
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

func _get_bet_group(bet_type: String) -> String:
	"""Приватный метод для обратной совместимости"""
	return get_bet_group(bet_type)

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

# ═══════════════════════════════════════════════════════════════════════════
# СОРТИРОВКА СТАВОК (делегировано в BetSorter)
# ═══════════════════════════════════════════════════════════════════════════

func _get_sorted_main_bets(winning: bool) -> Array:
	"""Получить отсортированные основные ставки (Player/Banker) справа налево
	
	Делегирует сортировку в BetSorter.
	
	Args:
		winning: true для выигрышных ставок, false для проигрышных
		
	Returns:
		Отсортированный массив ставок справа налево
	"""
	return bet_sorter.get_sorted_main_bets(payout_queue_manager, actual_winner, winning)

func _get_sorted_tie_bets(winning: bool) -> Array:
	"""Получить отсортированные Tie ставки
	
	Делегирует сортировку в BetSorter.
	- Для сбора (winning=false): слева направо (обратный порядок номеров)
	- Для оплаты (winning=true): справа налево (прямой порядок номеров)
	
	Args:
		winning: true для выигрышных ставок, false для проигрышных
		
	Returns:
		Отсортированный массив Tie ставок
	"""
	return bet_sorter.get_sorted_tie_bets(payout_queue_manager, winning)

func _get_sorted_pair_bets(winning: bool) -> Array:
	"""Получить отсортированные пары (PairPlayer + PairBanker вместе) справа налево
	
	Делегирует сортировку в BetSorter.
	Пары объединены в одну линию и сортируются по номеру позиции (1 = самый правый)
	
	Args:
		winning: true для выигрышных ставок, false для проигрышных
		
	Returns:
		Отсортированный массив пар ставок
	"""
	return bet_sorter.get_sorted_pair_bets(payout_queue_manager, winning)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ ПОСЛЕДОВАТЕЛЬНОСТЕЙ (делегировано в SequenceManager)
# ═══════════════════════════════════════════════════════════════════════════

func _get_expected_next_bet(group: String, is_collecting: bool):
	"""Получить следующую ожидаемую ставку в группе
	
	Делегирует в SequenceManager.
	
	Args:
		group: Группа ставок ("main", "tie", "pairs")
		is_collecting: true для сбора, false для оплаты
		
	Returns:
		Bet следующей ожидаемой ставки или null если все собраны/оплачены
	"""
	return sequence_manager.get_expected_next_bet(group, is_collecting)

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
	
	# Режим не выбран - возвращаем специальную ошибку для показа тоста без штрафа
	if current_mode == CollectionMode.NONE:
		return _error_result("mode_none", "ERR_MODE_NONE")
	
	var bet_data = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	if not bet_data:
		# Пробуем найти по типу (для обратной совместимости)
		bet_data = payout_queue_manager.get_bet_by_type(bet_type)
	if not bet_data:
		return _error_result("no_bet", "Ставка %s[%d] не найдена" % [bet_type, position_index])
	
	# Проверка Tie push - применяется только к режиму PAY (в COLLECT это обрабатывается как collect_winning)
	if current_mode == CollectionMode.PAY and is_tie_push_bet(bet_type):
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

func _bet_to_payload_dict(bet) -> Dictionary:
	"""Преобразовать объект ставки в словарь для payload"""
	return {
		"bet_type": bet.get_bet_type(),
		"position_index": bet.get_position_index(),
		"stake": bet.get_stake()
	}

func _validate_collect_internal(bet, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Внутренний метод валидации сбора (используется валидатором)"""
	return _validate_collect(bet, bet_type, position_index)

func _validate_pay_internal(bet, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Внутренний метод валидации оплаты (используется валидатором)"""
	return _validate_pay(bet, bet_type, position_index)

func _validate_collect(bet, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Валидация попытки собрать ставку"""
	
	# Сначала проверяем Tie push (более специфичный случай)
	# При Tie: Player и Banker - это push ставки (не выиграли, но и не проиграли)
	if is_tie_push_bet(bet_type):
		return _error_result("collect_winning", "ERR_COLLECT_TIE_PUSH")
	
	# Потом проверяем реально выигрышные ставки
	# Например: Player выиграл, пытаемся собрать выигрышную ставку Player
	if bet.is_won():
		return _error_result("collect_winning", "ERR_COLLECT_WINNING")
	
	# Проверяем, не собрана ли уже (используем bet.is_collected как единственный источник истины)
	if bet.is_collected():
		return _error_result("already_collected", "Ставка уже собрана")
	
	# Проверяем согласованность с кэшем (для обнаружения рассинхронизации)
	var bet_id = "%s_%d" % [bet_type, position_index]
	if collected_bets_by_id.has(bet_id) and not bet.is_collected():
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
		if expected_bet.get_bet_type() != bet_type or expected_bet.get_position_index() != position_index:
			var payload = {
				"type": "collection_error",
				"phase": "collection",
				"expected": _bet_to_payload_dict(expected_bet),
				"actual": _bet_to_payload_dict(bet),
				"result": "error",
				"message": "ERR_WRONG_COLLECT_ORDER",
				"reason": "wrong_order"
			}
			EventBus.collection_error.emit(payload)
			return _error_result("wrong_order", "ERR_WRONG_COLLECT_ORDER")
	
	return _success_result("collect")

func _validate_pay(bet, bet_type: String, position_index: int = 0) -> Dictionary:
	"""Валидация попытки оплатить ставку"""
	
	# Нельзя оплачивать проигрышные
	if not bet.is_won():
		return _error_result("pay_losing", "Нельзя оплачивать проигрышные ставки")
	
	# Проверяем, не оплачена ли уже
	if bet.is_paid():
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
		
		DebugLogger.log("🔍 Проверка группы '%s': progress=%d, sequence_size=%d" % [prev_group, prev_progress, prev_sequence.size()])
		
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
		DebugLogger.log("🔍 Ожидаемая ставка: %s[%d], кликнута: %s[%d]" % [expected_bet.get_bet_type(), expected_bet.get_position_index(), bet_type, position_index])
		# Проверяем, что кликнули на правильную следующую ставку
		if expected_bet.get_bet_type() != bet_type or expected_bet.get_position_index() != position_index:
			DebugLogger.log("  ❌ Неправильный порядок! Ожидалась %s[%d], кликнута %s[%d]" % [expected_bet.get_bet_type(), expected_bet.get_position_index(), bet_type, position_index])
			var payload = {
				"type": "payment_error",
				"phase": "payment",
				"expected": _bet_to_payload_dict(expected_bet),
				"actual": _bet_to_payload_dict(bet),
				"result": "error",
				"message": "ERR_WRONG_PAY_ORDER",
				"reason": "wrong_order"
			}
			EventBus.payment_error.emit(payload)
			return _error_result("wrong_order", "ERR_WRONG_PAY_ORDER")
		else:
			DebugLogger.log("  ✅ Правильная ставка!")
	else:
		DebugLogger.log("🔍 Все ставки в группе '%s' уже оплачены" % group)
	
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
	var used_fallback = false
	if not bet:
		# Для обратной совместимости пробуем по типу
		bet = payout_queue_manager.get_bet_by_type(bet_type)
		used_fallback = true
		if not bet:
			DebugLogger.log_error("Ставка %s[%d] не найдена в collect_bet()" % [bet_type, position_index])
			is_processing = false
			return false
	
	# Если использовали fallback - используем position_index из найденной ставки
	if used_fallback and bet.get_position_index() != position_index:
		DebugLogger.log("⚠️  collect_bet: использован fallback, корректируем position_index %d -> %d" % [position_index, bet.get_position_index()])
		position_index = bet.get_position_index()

	# Проверяем что ставка ещё не собрана (единственный источник истины - bet.is_collected)
	if bet.is_collected():
		DebugLogger.log("⏸️  Ставка %s[%d] уже собрана, игнорируем" % [bet_type, position_index])
		is_processing = false
		return false
	
	# ═══════════════════════════════════════════════════════════════════
	# ТРАНЗАКЦИОННАЯ ОПЕРАЦИЯ (всё или ничего)
	# ═══════════════════════════════════════════════════════════════════
	var bet_id = "%s_%d" % [bet_type, position_index]
	var group = _get_bet_group(bet_type)
	
	# Получаем ожидаемую ставку ДО любых изменений состояния
	var expected_bet = _get_expected_next_bet(group, true)
	
	# Сохраняем старое состояние для возможного rollback
	var old_collected_state = bet.is_collected()
	var old_progress = collection_progress.get(group, 0) if not group.is_empty() else 0
	
	# Атомарно обновляем всё состояние
	bet.mark_as_collected()
	collected_bets_by_id[bet_id] = true
	
	# Для обратной совместимости - добавляем тип, если его ещё нет
	if bet_type not in collected_losing_bets:
		collected_losing_bets.append(bet_type)
	
	# Обновляем прогресс сбора
	if not group.is_empty():
		sequence_manager.increment_progress(group, true)
	
	# Проверяем согласованность состояния после обновления
	if not state_checker.check_state_consistency(bet, bet_id, collected_bets_by_id):
		# Rollback при ошибке
		bet.set_collected(old_collected_state)
		collected_bets_by_id.erase(bet_id)
		if not group.is_empty():
			sequence_manager.collection_progress[group] = old_progress
		DebugLogger.log_error("Рассинхронизация состояния при сборе ставки %s[%d], выполнен rollback" % [bet_type, position_index])
		is_processing = false
		return false
	
	# Эмитим сигналы только после успешного обновления
	bet_collected.emit(bet_type)
	chip_collected.emit(bet_type, position_index)
	
	# Звук забора проигрышных ставок
	if SoundManager:
		SoundManager.play_chip_collect_sound()
	
	DebugLogger.log("💰 BetCollectionPhaseManager: ставка %s[%d] собрана" % [bet_type, position_index])
	
	# Проверяем, все ли ставки обработаны (после успешного сбора)
	_check_and_notify_if_all_processed()
	
	# Формируем payload для успешного сбора
	var payload = {
		"type": "collection_correct",
		"phase": "collection",
		"expected": _bet_to_payload_dict(expected_bet) if expected_bet else {},
		"actual": _bet_to_payload_dict(bet),
		"result": "correct"
	}
	EventBus.collection_correct.emit(payload)
	
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
	if used_fallback and bet.get_position_index() != position_index:
		DebugLogger.log("⚠️  pay_bet: использован fallback, корректируем position_index %d -> %d" % [position_index, bet.get_position_index()])
		position_index = bet.get_position_index()
	
	# Проверяем что ставка выигрышная (можно оплачивать только выигрышные)
	if not bet.is_won():
		DebugLogger.log("⚠️  Ставка %s[%d] не выиграла (won=%s), пропускаем оплату" % [bet_type, position_index, bet.is_won()])
		is_processing = false
		return true  # Не ошибка, просто пропускаем

	# Проверяем что ставка ещё не оплачена (единственный источник истины - bet.is_paid)
	if bet.is_paid():
		DebugLogger.log("⏸️  Ставка %s[%d] уже оплачена, игнорируем" % [bet_type, position_index])
		is_processing = false
		return false
	
	# ═══════════════════════════════════════════════════════════════════
	# ТРАНЗАКЦИОННАЯ ОПЕРАЦИЯ (всё или ничего)
	# ═══════════════════════════════════════════════════════════════════
	var group = _get_bet_group(bet_type)
	
	# Получаем ожидаемую ставку ДО любых изменений состояния
	var expected_bet = _get_expected_next_bet(group, false)
	
	# Сохраняем старое состояние для возможного rollback
	var old_paid_state = bet.is_paid()
	var old_progress = payment_progress.get(group, 0) if not group.is_empty() else 0
	var sequence = payment_sequence.get(group, []) if not group.is_empty() else []
	
	# Отмечаем ставку как оплаченную
	if not payout_queue_manager.mark_as_paid(bet_type, position_index):
		DebugLogger.log_error("Не удалось отметить ставку %s[%d] как оплаченную" % [bet_type, position_index])
		is_processing = false
		return false
	
	# Обновляем прогресс оплаты с проверкой последовательности
	if not group.is_empty() and old_progress < sequence.size():
		var expected = sequence[old_progress]
		if expected.get_bet_type() == bet_type and expected.get_position_index() == position_index:
			sequence_manager.increment_progress(group, false)
			var new_progress = sequence_manager.payment_progress[group]
			DebugLogger.log("💰 BetCollectionPhaseManager: ставка %s[%d] оплачена, группа '%s': progress %d -> %d" % [bet_type, position_index, group, old_progress, new_progress])
			
			# Показываем следующую ожидаемую ставку
			if new_progress < sequence.size():
				var next_expected = sequence[new_progress]
				DebugLogger.log("  📍 Следующая ожидаемая ставка: %s[%d]" % [next_expected.get_bet_type(), next_expected.get_position_index()])
			else:
				DebugLogger.log("  ✅ Все ставки в группе '%s' оплачены" % group)
		else:
			# Критическая ошибка: оплачивается не та ставка
			DebugLogger.log_error("КРИТИЧЕСКАЯ ОШИБКА: Оплачивается ставка %s[%d], но ожидалась %s[%d]!" % [bet_type, position_index, expected.get_bet_type(), expected.get_position_index()])
			# Перед rollback добавляем payment_error
			var payload = {
				"type": "payment_error",
				"phase": "payment",
				"expected": _bet_to_payload_dict(expected_bet) if expected_bet else {},
				"actual": _bet_to_payload_dict(bet),
				"result": "error",
				"message": "ERR_WRONG_PAYMENT_ORDER",
				"reason": "wrong_order"
			}
			EventBus.payment_error.emit(payload)
			# Rollback
			bet.set_paid(old_paid_state)
			sequence_manager.payment_progress[group] = old_progress
			is_processing = false
			return false
	elif not group.is_empty() and old_progress >= sequence.size():
		DebugLogger.log_error("КРИТИЧЕСКАЯ ОШИБКА: Прогресс группы '%s' (%d) >= размера последовательности (%d)!" % [group, old_progress, sequence.size()])
		# Перед rollback добавляем payment_error
		var payload = {
			"type": "payment_error",
			"phase": "payment",
			"expected": _bet_to_payload_dict(expected_bet) if expected_bet else {},
			"actual": _bet_to_payload_dict(bet),
			"result": "error",
			"message": "ERR_WRONG_PAYMENT_ORDER",
			"reason": "wrong_order"
		}
		EventBus.payment_error.emit(payload)
		# Rollback
		bet.set_paid(old_paid_state)
		is_processing = false
		return false
	
	# Проверяем согласованность состояния после обновления
	if not state_checker.check_payment_state_consistency(bet):
		# Rollback при ошибке
		bet.set_paid(old_paid_state)
		if not group.is_empty() and payment_progress.has(group):
			sequence_manager.payment_progress[group] = old_progress
		DebugLogger.log_error("Рассинхронизация состояния при оплате ставки %s[%d], выполнен rollback" % [bet_type, position_index])
		is_processing = false
		return false
	
	# Эмитим сигналы только после успешного обновления
	chip_paid.emit(bet_type, position_index)
	
	DebugLogger.log("💰 BetCollectionPhaseManager: ставка %s[%d] оплачена" % [bet_type, position_index])
	
	# Проверяем, все ли ставки обработаны (после успешной оплаты)
	_check_and_notify_if_all_processed()
	
	# После успешной оплаты добавляем payment_correct
	var payload = {
		"type": "payment_correct",
		"phase": "payment",
		"expected": _bet_to_payload_dict(expected_bet) if expected_bet else {},
		"actual": _bet_to_payload_dict(bet),
		"result": "correct"
	}
	EventBus.payment_correct.emit(payload)
	
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
			return bet_data.is_collected()
		return bet_type in collected_losing_bets
	
	# Используем bet.is_collected как единственный источник истины
	var bet = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	if bet:
		# Проверяем согласованность с кэшем
		var bet_id = "%s_%d" % [bet_type, position_index]
		var in_cache = collected_bets_by_id.has(bet_id)
		if in_cache != bet.is_collected():
			# Автоматическое исправление рассинхронизации
			DebugLogger.log_warning("Рассинхронизация для %s: кэш=%s, bet=%s, исправляем" % [bet_id, in_cache, bet.is_collected()])
			if bet.is_collected():
				collected_bets_by_id[bet_id] = true
			else:
				collected_bets_by_id.erase(bet_id)
		return bet.is_collected()
	
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
		if not bet.is_won() and not bet.is_collected():
			# Исключаем Tie push ставки
			if not is_tie_push_bet(bet.get_bet_type()):
				# Проверяем согласованность с кэшем (автоисправление)
				var bet_id = "%s_%d" % [bet.get_bet_type(), bet.get_position_index()]
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
		if not bet.is_won() and not bet.is_collected():
			# Исключаем Tie push ставки
			if not is_tie_push_bet(bet.get_bet_type()):
				# Проверяем согласованность с кэшем (автоисправление)
				var bet_id = "%s_%d" % [bet.get_bet_type(), bet.get_position_index()]
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
		if bet.is_won() and not bet.is_paid():
			# Исключаем Tie push ставки
			if not is_tie_push_bet(bet.get_bet_type()):
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
		if bet.is_won() and not bet.is_paid():
			if not is_tie_push_bet(bet.get_bet_type()):
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

func _check_and_notify_if_all_processed() -> void:
	"""Проверить, все ли ставки обработаны
	
	Вызывается после успешного сбора или оплаты ставки.
	ПРИМЕЧАНИЕ: Сигнал all_bets_processed теперь эмитится в _complete_round_and_prepare_new_game()
	после проверки балансов гостей, чтобы гарантировать правильный порядок операций.
	Это предотвращает преждевременную активацию нового гостя, когда текущий только что ушел.
	"""
	var completion_check = can_complete_round()
	if completion_check.can:
		# Все ставки обработаны, но сигнал будет эмитирован позже в _complete_round_and_prepare_new_game()
		# после проверки балансов гостей
		DebugLogger.log("🎯 BetCollectionPhaseManager: все ставки обработаны (сигнал будет эмитирован позже после проверки балансов гостей)")

# ═══════════════════════════════════════════════════════════════════════════
# ОТЛАДКА
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СОГЛАСОВАННОСТИ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СОГЛАСОВАННОСТИ СОСТОЯНИЯ (делегировано в StateConsistencyChecker)
# ═══════════════════════════════════════════════════════════════════════════

func validate_all_state() -> Dictionary:
	"""Проверить согласованность всего состояния (для отладки)
	
	Делегирует в StateConsistencyChecker.
	
	Returns:
		Dictionary с результатами проверки:
		- is_consistent: bool - согласовано ли состояние
		- issues: Array[String] - список проблем
	"""
	return state_checker.validate_all_state(payout_queue_manager, collected_bets_by_id, is_tie_push_bet)

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
