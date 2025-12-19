# res://scripts/GameDataManager.gd
# Autoload singleton для передачи данных между сценами Game и PayoutScene
extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ ПОЛЯ (инкапсулированные)
# ═══════════════════════════════════════════════════════════════════════════

# Данные для PayoutScene
var _payout_winner: String = ""
var _payout_stake: float = 0.0
var _payout_amount: float = 0.0
var _payout_player_score: int = 0
var _payout_banker_score: int = 0

# Результат из PayoutScene (для возврата в Game)
var _payout_is_correct: bool = false
var _payout_collected: float = 0.0
var _payout_expected: float = 0.0

# Состояние игры (сохраняется при переходе в PayoutScene)
var _survival_rounds: int = 0
var _survival_lives: int = 7
var _is_survival_active: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ОЧЕРЕДЬ ВЫПЛАТ (для множественных ставок в одном раунде)
# Использует единый класс Bet
# ═══════════════════════════════════════════════════════════════════════════

# Очередь выплат (обрабатываются по порядку)
var payout_queue: Array[Bet] = []


func set_payout_data(winner: String, stake: float, amount: float, player_score: int = 0, banker_score: int = 0):
	"""Установить данные выплаты (валидация: stake >= 0, amount >= 0)"""
	if stake < 0:
		push_error("GameDataManager.set_payout_data(): stake не может быть отрицательным (получено: %.2f)" % stake)
		return
	if amount < 0:
		push_error("GameDataManager.set_payout_data(): amount не может быть отрицательным (получено: %.2f)" % amount)
		return
	_payout_winner = winner
	_payout_stake = stake
	_payout_amount = amount
	_payout_player_score = player_score
	_payout_banker_score = banker_score
	print("💰 GameDataManager: Данные выплаты сохранены (%s, stake=%.1f, payout=%.1f, scores=%d vs %d)" % [winner, stake, amount, player_score, banker_score])


func set_payout_result(is_correct: bool, collected: float, expected: float):
	"""Установить результат выплаты (валидация: collected >= 0, expected >= 0)"""
	if collected < 0:
		push_error("GameDataManager.set_payout_result(): collected не может быть отрицательным (получено: %.2f)" % collected)
		return
	if expected < 0:
		push_error("GameDataManager.set_payout_result(): expected не может быть отрицательным (получено: %.2f)" % expected)
		return
	_payout_is_correct = is_correct
	_payout_collected = collected
	_payout_expected = expected
	print("💰 GameDataManager: Результат выплаты сохранён (correct=%s, collected=%.1f, expected=%.1f)" % [is_correct, collected, expected])


func set_game_state(rounds: int, lives: int, is_active: bool):
	"""Установить состояние игры (валидация: rounds >= 0, lives в диапазоне 0-7)"""
	if rounds < 0:
		push_error("GameDataManager.set_game_state(): rounds не может быть отрицательным (получено: %d)" % rounds)
		return
	if lives < 0 or lives > 7:
		push_error("GameDataManager.set_game_state(): lives должен быть в диапазоне 0-7 (получено: %d)" % lives)
		return
	_survival_rounds = rounds
	_survival_lives = lives
	_is_survival_active = is_active
	print("💾 GameDataManager: Состояние игры сохранено (rounds=%d, lives=%d, active=%s)" % [rounds, lives, is_active])


func clear():
	"""Очистить данные выплаты (НЕ очищает survival_rounds/lives/is_active - они нужны при возврате!)"""
	_payout_winner = ""
	_payout_stake = 0.0
	_payout_amount = 0.0
	_payout_player_score = 0
	_payout_banker_score = 0
	_payout_is_correct = false
	_payout_collected = 0.0
	_payout_expected = 0.0
	# НЕ очищаем survival_rounds/lives/is_active - они нужны при возврате!


# ═══════════════════════════════════════════════════════════════════════════
# ГЕТТЕРЫ (публичный доступ к приватным полям)
# ═══════════════════════════════════════════════════════════════════════════

func get_payout_winner() -> String:
	"""Получить победителя выплаты"""
	return _payout_winner


func get_payout_stake() -> float:
	"""Получить размер ставки"""
	return _payout_stake


func get_payout_amount() -> float:
	"""Получить размер выплаты"""
	return _payout_amount


func get_payout_player_score() -> int:
	"""Получить очки игрока"""
	return _payout_player_score


func get_payout_banker_score() -> int:
	"""Получить очки банкира"""
	return _payout_banker_score


func get_payout_is_correct() -> bool:
	"""Получить результат выплаты (правильно/неправильно)"""
	return _payout_is_correct


func get_payout_collected() -> float:
	"""Получить собранную сумму"""
	return _payout_collected


func get_payout_expected() -> float:
	"""Получить ожидаемую сумму"""
	return _payout_expected


func get_survival_rounds() -> int:
	"""Получить количество пройденных раундов"""
	return _survival_rounds


func get_survival_lives() -> int:
	"""Получить количество жизней"""
	return _survival_lives


func is_survival_active() -> bool:
	"""Проверить, активен ли режим выживания"""
	return _is_survival_active


# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ДЛЯ РАБОТЫ С ОЧЕРЕДЬЮ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

func add_to_payout_queue(bet_type: String, stake: float, payout: float, p_score: int = 0, b_score: int = 0) -> void:
	"""Добавить выплату в очередь"""
	var payout_data = Bet.create_payout_bet(bet_type, stake, payout, p_score, b_score)
	payout_queue.append(payout_data)
	DebugLogger.log("💰 PayoutQueue: добавлена выплата %s (stake=%.1f, payout=%.1f)" % [bet_type, stake, payout])


func get_next_payout() -> Bet:
	"""Получить следующую выплату из очереди (и удалить её)"""
	if payout_queue.is_empty():
		return null

	var next_payout = payout_queue[0]
	payout_queue.remove_at(0)
	DebugLogger.log("💰 PayoutQueue: взята выплата %s из очереди (осталось: %d)" % [next_payout.get_bet_type(), payout_queue.size()])
	return next_payout


func has_more_payouts() -> bool:
	"""Проверить, есть ли ещё выплаты в очереди"""
	return not payout_queue.is_empty()


func get_queue_size() -> int:
	"""Получить количество выплат в очереди"""
	return payout_queue.size()


func clear_payout_queue() -> void:
	"""Очистить очередь выплат"""
	var count = payout_queue.size()
	payout_queue.clear()
	if count > 0:
		DebugLogger.log("🗑️  PayoutQueue: очищено (%d выплат удалено)" % count)


func print_queue_status() -> void:
	"""Вывести текущий статус очереди"""
	DebugLogger.log("═══ PayoutQueue Status ═══")
	DebugLogger.log("Выплат в очереди: %d" % payout_queue.size())
	for i in range(payout_queue.size()):
		var p = payout_queue[i]
		DebugLogger.log("  [%d] %s: %.1f → %.1f" % [i + 1, p.get_bet_type(), p.get_stake(), p.get_payout()])
	DebugLogger.log("═══════════════════════════")
