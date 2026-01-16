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

# Словарь ушедших гостей: {guest_id: {round_when_left: int, rounds_until_return: int, leave_reason: LeaveReason, patience_when_left: int}}
# Гость вернется через случайное количество раундов (10-20)
var guests_left: Dictionary = {}  # {guest_id: Dictionary}

# Список всех гостей, которые когда-либо были активированы в игре
# Используется для определения правила ухода (единственный или нет)
var activated_guests: Array[int] = []

# Текущий номер раунда (отслеживается через round_started)
var current_round: int = 0

# Диапазон раундов до возврата для единственного гостя (если в списке всего 1 гость)
const MIN_ROUNDS_UNTIL_RETURN_SINGLE: int = 3
const MAX_ROUNDS_UNTIL_RETURN_SINGLE: int = 5

# Диапазон раундов до возврата для гостя (если в списке больше 1 гостя)
const MIN_ROUNDS_UNTIL_RETURN_MULTIPLE: int = 10
const MAX_ROUNDS_UNTIL_RETURN_MULTIPLE: int = 20

# Причины ухода гостя
enum LeaveReason {
	PATIENCE,    # Ушел из-за потери терпения (терпение = 0%)
	BANKRUPTCY   # Ушел из-за банкротства (баланс < 0)
}

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Подписываемся на событие начала раунда
	EventBus.round_started.connect(_on_round_started)
	
	# Подписываемся на рестарт игры для сброса
	EventBus.game_restarted.connect(_on_game_restarted)
	
	# Подписываемся на сигнал завершения обработки всех ставок
	# Это момент, когда можно вернуть гостей (за шаг до начала новой раздачи)
	EventBus.all_bets_processed.connect(_on_all_bets_processed)
	
	print("🔄 GuestReturnManager готов")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Зарегистрировать активацию гостя (добавить в список задействованных)
func register_guest_activation(guest_id: int) -> void:
	"""Зарегистрировать активацию гостя (добавить в список задействованных)
	
	Args:
		guest_id: ID гостя (1-6)
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestReturnManager: неверный guest_id %d" % guest_id)
		return
	
	# Добавляем только если еще не в списке
	if not guest_id in activated_guests:
		activated_guests.append(guest_id)
		print("📝 Гость %d добавлен в список задействованных (всего: %d)" % [guest_id, activated_guests.size()])

## Получить количество задействованных гостей
func get_activated_guests_count() -> int:
	"""Получить количество задействованных гостей
	
	Returns:
		Количество гостей, которые когда-либо были активированы
	"""
	return activated_guests.size()

## Генерировать случайное количество раундов до возврата
func _generate_return_rounds(is_single_in_list: bool = false) -> int:
	"""Генерирует случайное количество раундов до возврата
	
	Args:
		is_single_in_list: true если это последний активный гость за столом
	
	Returns:
		Количество раундов до возврата (3-5 для последнего активного, 10-20 для остальных)
	"""
	if is_single_in_list:
		return randi_range(MIN_ROUNDS_UNTIL_RETURN_SINGLE, MAX_ROUNDS_UNTIL_RETURN_SINGLE)
	else:
		return randi_range(MIN_ROUNDS_UNTIL_RETURN_MULTIPLE, MAX_ROUNDS_UNTIL_RETURN_MULTIPLE)

## Отметить гостя как ушедшего
func mark_guest_left(guest_id: int, round_number: int, leave_reason: LeaveReason = LeaveReason.BANKRUPTCY, is_single_in_list: bool = false) -> void:
	"""Отметить гостя как ушедшего
	
	Args:
		guest_id: ID гостя (1-6)
		round_number: Номер раунда, когда гость ушел
		leave_reason: Причина ухода (PATIENCE или BANKRUPTCY), по умолчанию BANKRUPTCY
		is_single_in_list: true если это последний активный гость за столом
			ВАЖНО: Это значение должно быть вычислено ДО выключения гостя в вызывающем коде
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestReturnManager: неверный guest_id %d" % guest_id)
		return
	
	# Убеждаемся, что round_number не меньше 1
	if round_number < 1:
		push_warning("GuestReturnManager: round_number < 1 (%d), устанавливаем 1" % round_number)
		round_number = 1
	
	# ВАЖНО: НЕ переопределяем is_single_in_list, если он был передан
	# Проверка должна происходить ДО выключения гостя в вызывающем коде
	# Если параметр не передан (остался false по умолчанию), проверяем заново
	# Но это не должно происходить, так как вызывающий код всегда передает правильное значение
	
	# Логируем, если это последний активный гость
	if is_single_in_list:
		print("👋 Гость %d - последний активный гость за столом, вернется через 3-5 раундов" % guest_id)
	else:
		print("👋 Гость %d - НЕ последний активный гость за столом (есть еще активные), вернется через 10-20 раундов" % guest_id)
	
	# Сохраняем текущее терпение гостя (нужно для возврата с правильным терпением при банкротстве)
	var patience_when_left = 100
	if GuestStatsManager:
		patience_when_left = GuestStatsManager.get_guest_patience(guest_id)
	
	# Генерируем количество раундов до возврата (3-5 для последнего активного, 10-20 для остальных)
	var rounds_until_return = _generate_return_rounds(is_single_in_list)
	guests_left[guest_id] = {
		"round_when_left": round_number,
		"rounds_until_return": rounds_until_return,
		"leave_reason": leave_reason,
		"patience_when_left": patience_when_left
	}
	
	var reason_text = "из-за банкротства" if leave_reason == LeaveReason.BANKRUPTCY else "из-за потери терпения"
	var return_range_text = "3-5" if is_single_in_list else "10-20"
	print("👋 Гость %d ушел %s в раунде %d (терпение было %d%%, вернется через %d раундов, в раунде %d, диапазон: %s)" % [
		guest_id, reason_text, round_number, patience_when_left, rounds_until_return, round_number + rounds_until_return, return_range_text
	])
	print("👋 Текущий раунд в GuestReturnManager: %d" % get_current_round())

## Вернуть гостя с полным балансом (в зависимости от богатства)
func return_guest(guest_id: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestReturnManager: неверный guest_id %d" % guest_id)
		return
	
	# Получаем данные гостя перед удалением из списка
	var guest_data = guests_left.get(guest_id, {})
	var leave_reason = guest_data.get("leave_reason", LeaveReason.BANKRUPTCY)
	var patience_when_left = guest_data.get("patience_when_left", 100)
	
	# Удаляем из списка ушедших
	guests_left.erase(guest_id)
	
	# Обновляем баланс в зависимости от причины ухода:
	# - Если ушел из-за терпения (PATIENCE) → сохраняем текущий баланс (не обновляем)
	# - Если ушел из-за банкротства (BANKRUPTCY) → полный баланс
	if GuestStatsManager and GuestSettingsManager:
		if leave_reason == LeaveReason.PATIENCE:
			# Ушел из-за терпения - сохраняем баланс (не обновляем)
			var current_balance = GuestStatsManager.get_guest_balance(guest_id)
			print("💰 Гость %d вернулся с сохраненным балансом %.0f (ушел из-за терпения)" % [guest_id, current_balance])
		else:
			# Ушел из-за банкротства - полный баланс
			var wealth = GuestSettingsManager.get_guest_wealth(guest_id)
			var full_balance = GuestStatsManager.generate_random_balance(wealth)
			
			GuestStatsManager.set_guest_balance(guest_id, full_balance)
			# Также обновляем начальный баланс
			GuestStatsManager.guest_initial_balances[guest_id - 1] = full_balance
			# Сбрасываем сохраненный баланс при возврате
			GuestStatsManager.reset_saved_balance(guest_id)
			print("💰 Гость %d вернулся с балансом %.0f (статус: %s)" % [
				guest_id, full_balance, GuestSettingsManager.GuestWealth.keys()[wealth]
			])
	
	# Включаем гостя обратно
	if GuestSettingsManager:
		GuestSettingsManager.set_guest_enabled(guest_id, true)
	
	# Устанавливаем терпение в зависимости от причины ухода:
	# - Если ушел из-за терпения (PATIENCE) → возвращается с 60% терпения
	# - Если ушел из-за банкротства (BANKRUPTCY) → возвращается с тем же терпением, какое было
	if GuestStatsManager:
		if leave_reason == LeaveReason.PATIENCE:
			# Ушел из-за терпения - возвращается с 60% терпения
			GuestStatsManager.set_guest_patience(guest_id, 60)
			print("😌 Гость %d: терпение установлено до 60%% при возврате (ушел из-за терпения)" % guest_id)
		else:
			# Ушел из-за банкротства - возвращается с тем же терпением, какое было
			GuestStatsManager.set_guest_patience(guest_id, patience_when_left)
			print("😌 Гость %d: терпение восстановлено до %d%% при возврате (ушел из-за банкротства)" % [guest_id, patience_when_left])
	
	# Эмитим сигнал
	guest_returned.emit(guest_id)
	print("👋 Гость %d вернулся" % guest_id)
	
	# Автоматически переводим камеру на вернувшегося гостя
	if EventBus:
		EventBus.camera_zoom_requested.emit("guest_%d" % guest_id, false)
		print("📷 Камера автоматически переведена на вернувшегося гостя %d" % guest_id)

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
		# Возвращаем гостя через return_guest (который правильно обработает терпение)
		return_guest(guest_id)
	
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
	
	Считает количество раздач до возврата, используя ту же логику,
	что и check_guests_return_before_next_round() - с учетом следующего раунда.
	
	Args:
		guest_id: ID гостя (1-6)
		
	Returns:
		Количество оставшихся раздач (0 или больше), или -1 если гость не ушел
	"""
	if not guests_left.has(guest_id):
		return -1  # Гость не ушел
	
	# Используем get_current_round() + 1 для получения следующего раунда
	# Это соответствует логике check_guests_return_before_next_round()
	var next_round = get_current_round() + 1
	
	var guest_data = guests_left[guest_id]
	var round_when_left = guest_data["round_when_left"]
	var rounds_until_return = guest_data["rounds_until_return"]
	var rounds_passed = next_round - round_when_left
	var remaining = rounds_until_return - rounds_passed
	
	return max(0, remaining)  # Не меньше 0

## Получить минимальное количество оставшихся раундов до возврата ближайшего гостя
func get_min_remaining_rounds() -> int:
	"""Получить минимальное количество оставшихся раундов до возврата ближайшего гостя
	
	Returns:
		Минимальное количество раундов до возврата, или -1 если нет ушедших гостей
	"""
	if guests_left.is_empty():
		return -1
	
	var min_rounds = -1
	for guest_id in guests_left.keys():
		var remaining = get_remaining_rounds(guest_id)
		if remaining >= 0:
			if min_rounds == -1 or remaining < min_rounds:
				min_rounds = remaining
	
	return min_rounds

## Проверить, остались ли активные гости за столом (только для отладки)
func _check_and_return_guest_if_table_empty(_round_number: int) -> void:
	"""Проверить, остались ли активные гости за столом
	
	Используется только для отладки. Не изменяет счетчики возврата гостей.
	Если за столом никого нет, просто показываем пустую раздачу (ДАМИКУ)
	и ждем, пока кто-то вернется по своему счетчику.
	
	Args:
		_round_number: Номер текущего раунда (не используется, оставлен для совместимости)
	"""
	if not GuestSettingsManager:
		return
	
	# Проверяем, есть ли активные гости за столом
	var active_guests = GuestSettingsManager.get_active_guests()
	if active_guests.size() > 0:
		return  # Есть активные гости - ничего не делаем
	
	# За столом никого нет - логируем для отладки
	if guests_left.is_empty():
		print("🔄 За столом никого нет, и нет ушедших гостей (пустая раздача)")
		return
	
	# Есть ушедшие гости - показываем информацию о ближайшем возврате
	var min_remaining = get_min_remaining_rounds()
	if min_remaining >= 0:
		print("🔄 За столом никого нет, ближайший гость вернется через %d раздач" % min_remaining)
	else:
		print("🔄 За столом никого нет, есть ушедшие гости")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ПРОВЕРКА ВОЗВРАТА
# ═══════════════════════════════════════════════════════════════════════════

## Проверить возврат гостей перед следующим раундом (вызывается при подготовке стола)
func check_guests_return_before_next_round() -> void:
	"""Проверяет возврат гостей с учетом следующего раунда
	
	Вызывается в момент подготовки стола (после завершения раздачи, до начала новой).
	Проверяет, должны ли гости вернуться на следующей раздаче (current_round + 1).
	Гости возвращаются только по своему счетчику, без принудительного возврата.
	"""
	if guests_left.is_empty():
		print("🔄 GuestReturnManager: нет ушедших гостей для проверки возврата")
		return
	
	# Используем текущий раунд + 1 для проверки (следующий раунд)
	var next_round = get_current_round() + 1
	print("🔄 GuestReturnManager: проверка возврата гостей перед следующим раундом (текущий: %d, следующий: %d)" % [
		get_current_round(), next_round
	])
	
	# Проверяем всех ушедших гостей
	var guests_to_return: Array[int] = []
	
	for guest_id in guests_left.keys():
		var guest_data = guests_left[guest_id]
		var round_when_left = guest_data["round_when_left"]
		var rounds_until_return = guest_data["rounds_until_return"]
		var rounds_passed = next_round - round_when_left
		
		print("🔄 Проверка возврата гостя %d: ушел в раунде %d, будет %d раундов, нужно %d" % [
			guest_id, round_when_left, rounds_passed, rounds_until_return
		])
		
		if rounds_passed >= rounds_until_return:
			guests_to_return.append(guest_id)
			print("✅ Гость %d должен вернуться перед следующей раздачей (будет %d >= нужно %d)" % [
				guest_id, rounds_passed, rounds_until_return
			])
	
	# Возвращаем гостей, которые должны вернуться
	if guests_to_return.size() > 0:
		print("🔄 GuestReturnManager: возвращаем %d гостей перед следующей раздачей" % guests_to_return.size())
		for guest_id in guests_to_return:
			return_guest(guest_id)
	else:
		print("🔄 GuestReturnManager: гостей для возврата перед следующей раздачей нет")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_round_started() -> void:
	"""Обработчик начала нового раунда - только увеличиваем счетчик
	
	Проверка возврата гостей теперь происходит в check_guests_return_before_next_round()
	который вызывается при подготовке стола (до начала новой раздачи).
	"""
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

func _on_all_bets_processed() -> void:
	"""Обработчик завершения обработки всех ставок
	
	Вызывается когда:
	- Оплачена последняя выигрышная ставка (если были выигрышные)
	- Забрана последняя проигрышная ставка (если не было выигрышных, но были проигрышные)
	- Сразу после выяснения победителя (если не было ни выигрышных, ни проигрышных ставок)
	
	Это момент, когда можно вернуть гостей (за шаг до начала новой раздачи).
	"""
	check_guests_return_before_next_round()

func _on_game_restarted() -> void:
	"""Обработчик рестарта игры - сбрасываем все"""
	guests_left.clear()
	activated_guests.clear()  # Сбрасываем список задействованных гостей
	current_round = 0
	print("🔄 GuestReturnManager: все данные сброшены при рестарте")
