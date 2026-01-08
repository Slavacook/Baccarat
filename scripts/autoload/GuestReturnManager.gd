# res://scripts/autoload/GuestReturnManager.gd
# Autoload синглтон для управления возвратом ушедших гостей
# Отслеживает гостей, ушедших в минус, и возвращает их через 10-20 раундов (случайно)

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal guest_returned(guest_id: int)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Словарь ушедших гостей: {guest_id: {round_when_left: int, rounds_until_return: int}}
# Гость вернется через случайное количество раундов (10-20)
var guests_left: Dictionary = {}  # {guest_id: Dictionary}

# Текущий номер раунда (отслеживается через round_started)
var current_round: int = 0

# Диапазон раундов до возврата
const MIN_ROUNDS_UNTIL_RETURN: int = 10
const MAX_ROUNDS_UNTIL_RETURN: int = 20

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Подписываемся на событие начала раунда
	EventBus.round_started.connect(_on_round_started)
	
	# Подписываемся на рестарт игры для сброса
	EventBus.game_restarted.connect(_on_game_restarted)
	
	print("🔄 GuestReturnManager готов")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Генерировать случайное количество раундов до возврата
func _generate_return_rounds() -> int:
	"""Генерирует случайное количество раундов от 10 до 20"""
	return randi_range(MIN_ROUNDS_UNTIL_RETURN, MAX_ROUNDS_UNTIL_RETURN)

## Отметить гостя как ушедшего
func mark_guest_left(guest_id: int, round_number: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestReturnManager: неверный guest_id %d" % guest_id)
		return
	
	# Убеждаемся, что round_number не меньше 1
	if round_number < 1:
		push_warning("GuestReturnManager: round_number < 1 (%d), устанавливаем 1" % round_number)
		round_number = 1
	
	var rounds_until_return = _generate_return_rounds()
	guests_left[guest_id] = {
		"round_when_left": round_number,
		"rounds_until_return": rounds_until_return
	}
	print("👋 Гость %d ушел в раунде %d (вернется через %d раундов, в раунде %d)" % [
		guest_id, round_number, rounds_until_return, round_number + rounds_until_return
	])
	print("👋 Текущий раунд в GuestReturnManager: %d" % get_current_round())

## Вернуть гостя с полным балансом (в зависимости от богатства)
func return_guest(guest_id: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestReturnManager: неверный guest_id %d" % guest_id)
		return
	
	# Удаляем из списка ушедших
	guests_left.erase(guest_id)
	
	# Обновляем баланс до полной суммы (в зависимости от богатства)
	if GuestStatsManager and GuestSettingsManager:
		var wealth = GuestSettingsManager.get_guest_wealth(guest_id)
		var full_balance: float
		match wealth:
			GuestSettingsManager.GuestWealth.POOR:
				full_balance = GuestStatsManager.POOR_BALANCE
			GuestSettingsManager.GuestWealth.MEDIUM:
				full_balance = GuestStatsManager.MEDIUM_BALANCE
			GuestSettingsManager.GuestWealth.RICH:
				full_balance = GuestStatsManager.RICH_BALANCE
			_:
				full_balance = GuestStatsManager.MEDIUM_BALANCE
		
		GuestStatsManager.set_guest_balance(guest_id, full_balance)
		# Также обновляем начальный баланс
		GuestStatsManager.guest_initial_balances[guest_id - 1] = full_balance
		print("💰 Гость %d вернулся с балансом %.0f (статус: %s)" % [
			guest_id, full_balance, GuestSettingsManager.GuestWealth.keys()[wealth]
		])
	
	# Включаем гостя обратно
	if GuestSettingsManager:
		GuestSettingsManager.set_guest_enabled(guest_id, true)
	
	# Эмитим сигнал
	guest_returned.emit(guest_id)
	print("👋 Гость %d вернулся" % guest_id)

## Вернуть всех ушедших гостей после геймовера
func return_all_guests_after_game_over() -> void:
	"""Возвращает всех ушедших гостей после геймовера
	
	Используется когда игра заканчивается, но у гостей есть отсчет раздач до возврата.
	Все гости возвращаются сразу, независимо от оставшихся раундов.
	"""
	if guests_left.is_empty():
		print("🔄 GuestReturnManager: нет ушедших гостей для возврата после геймовера")
		return
	
	var guests_to_return: Array[int] = []
	for guest_id in guests_left.keys():
		guests_to_return.append(guest_id)
	
	print("🔄 GuestReturnManager: возвращаем %d гостей после геймовера" % guests_to_return.size())
	
	for guest_id in guests_to_return:
		# Возвращаем гостя (баланс уже сброшен до начального значения в reset_all_balances())
		# Нужно только включить гостя обратно и удалить из списка ушедших
		guests_left.erase(guest_id)
		
		# Включаем гостя обратно
		if GuestSettingsManager:
			GuestSettingsManager.set_guest_enabled(guest_id, true)
		
		# Эмитим сигнал
		guest_returned.emit(guest_id)
		print("👋 Гость %d вернулся после геймовера" % guest_id)
	
	print("✅ GuestReturnManager: все гости возвращены после геймовера")

## Получить текущий номер раунда
func get_current_round() -> int:
	# Используем собственный счетчик как основной источник
	# TableStateManager может быть не синхронизирован или возвращать 0 в не-survival режиме
	return current_round

## Проверить, ушел ли гость
func is_guest_left(guest_id: int) -> bool:
	return guests_left.has(guest_id)

## Получить количество оставшихся раундов до возврата гостя
func get_remaining_rounds(guest_id: int) -> int:
	"""Получить количество оставшихся раундов до возврата гостя
	
	Args:
		guest_id: ID гостя (1-6)
		
	Returns:
		Количество оставшихся раундов (0 или больше), или -1 если гость не ушел
	"""
	if not guests_left.has(guest_id):
		return -1  # Гость не ушел
	
	# Используем get_current_round() для получения актуального значения
	var current = get_current_round()
	
	var guest_data = guests_left[guest_id]
	var round_when_left = guest_data["round_when_left"]
	var rounds_until_return = guest_data["rounds_until_return"]
	var rounds_passed = current - round_when_left
	var remaining = rounds_until_return - rounds_passed
	
	return max(0, remaining)  # Не меньше 0

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_round_started() -> void:
	"""Обработчик начала нового раунда - проверяем возврат гостей"""
	# ВСЕГДА увеличиваем счетчик при начале нового раунда
	current_round += 1
	
	# Синхронизируем с TableStateManager (если доступен и возвращает значение > 0)
	# Это нужно для режима выживания, где TableStateManager - источник истины
	if TableStateManager:
		var table_rounds = TableStateManager.get_survival_rounds()
		if table_rounds > 0 and table_rounds > current_round:
			# Если TableStateManager имеет большее значение, используем его
			current_round = table_rounds
			print("🔄 GuestReturnManager: синхронизирован с TableStateManager, текущий раунд = %d" % current_round)
		else:
			print("🔄 GuestReturnManager: текущий раунд = %d (локальный счетчик)" % current_round)
	else:
		print("🔄 GuestReturnManager: текущий раунд = %d (локальный счетчик)" % current_round)
	
	# Используем get_current_round() для получения актуального значения
	var current = get_current_round()
	print("🔄 GuestReturnManager: проверка возврата гостей, текущий раунд = %d, ушедших гостей = %d" % [
		current, guests_left.size()
	])
	
	# Проверяем всех ушедших гостей
	var guests_to_return: Array[int] = []
	
	for guest_id in guests_left.keys():
		var guest_data = guests_left[guest_id]
		var round_when_left = guest_data["round_when_left"]
		var rounds_until_return = guest_data["rounds_until_return"]
		var rounds_passed = current - round_when_left
		
		print("🔄 Проверка возврата гостя %d: ушел в раунде %d, прошло %d раундов, нужно %d" % [
			guest_id, round_when_left, rounds_passed, rounds_until_return
		])
		
		if rounds_passed >= rounds_until_return:
			guests_to_return.append(guest_id)
			print("✅ Гость %d должен вернуться (прошло %d >= нужно %d)" % [
				guest_id, rounds_passed, rounds_until_return
			])
	
	# Возвращаем гостей, которые должны вернуться
	if guests_to_return.size() > 0:
		print("🔄 GuestReturnManager: возвращаем %d гостей" % guests_to_return.size())
		for guest_id in guests_to_return:
			return_guest(guest_id)
	else:
		print("🔄 GuestReturnManager: гостей для возврата нет")

func _on_game_restarted() -> void:
	"""Обработчик рестарта игры - сбрасываем все"""
	guests_left.clear()
	current_round = 0
	print("🔄 GuestReturnManager: все данные сброшены при рестарте")
