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

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var current_mode: CollectionMode = CollectionMode.NONE
var payout_queue_manager: PayoutQueueManager = null
var actual_winner: String = ""  # Победитель раунда (для проверки Tie push)

# Список собранных проигрышных ставок
var collected_losing_bets: Array[String] = []

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
	current_mode = CollectionMode.NONE
	print("✅ BetCollectionPhaseManager: настроен для раунда (победитель: %s)" % winner)

func reset() -> void:
	"""Сбросить состояние менеджера"""
	payout_queue_manager = null
	actual_winner = ""
	collected_losing_bets.clear()
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
	
	При Tie ставки Player и Banker не выиграли и не проиграли - их нельзя трогать.
	Пары (PairPlayer, PairBanker) НЕ являются push при Tie.
	"""
	if actual_winner == "Tie":
		return bet_type == "Player" or bet_type == "Banker"
	return false

# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ ДЕЙСТВИЙ
# ═══════════════════════════════════════════════════════════════════════════

func validate_chip_click(bet_type: String) -> Dictionary:
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
	
	var bet = payout_queue_manager.get_bet_by_type(bet_type)
	if not bet:
		return _error_result("no_bet", "Ставка %s не найдена" % bet_type)
	
	# Проверка Tie push - применяется к обоим режимам
	if is_tie_push_bet(bet_type):
		return _error_result("tie_push", "ERR_CANNOT_COLLECT_TIE_PUSH")
	
	# Валидация в режиме COLLECT
	if current_mode == CollectionMode.COLLECT:
		return _validate_collect(bet, bet_type)
	
	# Валидация в режиме PAY
	if current_mode == CollectionMode.PAY:
		return _validate_pay(bet, bet_type)
	
	return _error_result("unknown_mode", "Неизвестный режим")

func _validate_collect(bet: PayoutQueueManager.BetData, bet_type: String) -> Dictionary:
	"""Валидация попытки собрать ставку"""
	
	# Нельзя собирать выигрышные
	if bet.won:
		return _error_result("collect_winning", "ERR_COLLECT_WINNING")
	
	# Проверяем, не собрана ли уже
	if bet_type in collected_losing_bets:
		return _error_result("already_collected", "Ставка уже собрана")
	
	return _success_result("collect")

func _validate_pay(bet: PayoutQueueManager.BetData, _bet_type: String) -> Dictionary:
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

func collect_bet(bet_type: String) -> bool:
	"""Собрать проигрышную ставку
	
	Returns:
		true если ставка успешно собрана
	"""
	if bet_type in collected_losing_bets:
		return false
	
	collected_losing_bets.append(bet_type)
	bet_collected.emit(bet_type)
	print("💰 BetCollectionPhaseManager: ставка %s собрана" % bet_type)
	return true

func is_bet_collected(bet_type: String) -> bool:
	"""Проверить, собрана ли ставка"""
	return bet_type in collected_losing_bets

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СОСТОЯНИЯ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════

func has_uncollected_losing_bets() -> bool:
	"""Проверить, есть ли не собранные проигрышные ставки (исключая Tie push)"""
	if not payout_queue_manager:
		return false
	
	for bet in payout_queue_manager.bets:
		if not bet.won and bet.bet_type not in collected_losing_bets:
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
		if not bet.won and bet.bet_type not in collected_losing_bets:
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
	print("Собрано проигрышных: %d" % collected_losing_bets.size())
	for bet_type in collected_losing_bets:
		print("  - %s" % bet_type)
	print("Не собрано проигрышных: %d" % get_uncollected_losing_count())
	print("Не оплачено выигрышных: %d" % get_unpaid_winnings_count())
	var completion = can_complete_round()
	print("Можно завершить: %s" % completion.can)
	if not completion.can:
		print("  Причины: %s" % str(completion.reasons))
	print("═════════════════════════════════════════")
