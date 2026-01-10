# res://scripts/autoload/GuestStatsManager.gd
# Autoload синглтон для управления статистикой гостей
# Хранит баланс каждого гостя (может быть отрицательным)

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal guest_balance_changed(guest_id: int, new_balance: float)
signal guest_patience_changed(guest_id: int, new_patience: int)
signal guest_left(guest_id: int)

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Начальные балансы по статусу богатства
const POOR_BALANCE: float = 50000.0    # Бедный
const MEDIUM_BALANCE: float = 100000.0  # Средний
const RICH_BALANCE: float = 300000.0    # Богатый

# Пороги для изменения статуса богатства (динамическое обновление)
const WEALTH_THRESHOLD_POOR_TO_MEDIUM: float = 70000.0   # Бедный → Средний
const WEALTH_THRESHOLD_MEDIUM_TO_RICH: float = 150000.0  # Средний → Богатый
const WEALTH_THRESHOLD_RICH_TO_MEDIUM: float = 70000.0   # Богатый → Средний
const WEALTH_THRESHOLD_MEDIUM_TO_POOR: float = 30000.0   # Средний → Бедный
const WEALTH_THRESHOLD_RICH_TO_POOR: float = 30000.0     # Богатый → Бедный (прямой переход)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Баланс 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Баланс может быть отрицательным (проигрыш) или положительным (выигрыш)
var guest_balances: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# Начальные балансы 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Используется для расчета изменения баланса
var guest_initial_balances: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# Терпение 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Терпение 0-100 (100 = полное терпение/спокоен, 0 = нет терпения/раздражен)
# НЕ сохраняется между сеансами (сбрасывается при перезапуске)
var guest_patience: Array[int] = [100, 100, 100, 100, 100, 100]

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Загружаем сохранённые балансы
	_load_stats()
	
	# Инициализируем балансы всех включенных гостей
	_initialize_all_enabled_guests()
	
	print("💰 GuestStatsManager загружен: балансы %d гостей" % guest_balances.size())
	
	# Подписываемся на событие рестарта игры для сброса терпения
	EventBus.game_restarted.connect(_on_game_restarted)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Получить баланс гостя (guest_id: 1-6)
func get_guest_balance(guest_id: int) -> float:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0.0
	return guest_balances[guest_id - 1]

# ← Установить баланс гостя
func set_guest_balance(guest_id: int, balance: float) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	guest_balances[guest_id - 1] = balance
	_save_stats()
	guest_balance_changed.emit(guest_id, balance)
	print("💰 Гость %d: баланс = %.2f" % [guest_id, balance])

# ← Добавить к балансу гостя (выигрыш)
func add_to_balance(guest_id: int, amount: float) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var new_balance = guest_balances[guest_id - 1] + amount
	set_guest_balance(guest_id, new_balance)

# ← Вычесть из баланса гостя (проигрыш)
func subtract_from_balance(guest_id: int, amount: float) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var new_balance = guest_balances[guest_id - 1] - amount
	set_guest_balance(guest_id, new_balance)

# ← Сбросить баланс гостя
func reset_guest_balance(guest_id: int) -> void:
	set_guest_balance(guest_id, 0.0)

# ← Сбросить балансы всех гостей до начальных значений (в зависимости от статуса богатства)
func reset_all_balances() -> void:
	"""Сбрасывает балансы всех гостей до начальных значений в зависимости от их статуса богатства"""
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	# Сбрасываем балансы всех гостей (1-6) до начальных значений
	for guest_id in range(1, 7):
		var wealth = GuestSettingsManager.get_guest_wealth(guest_id)
		var initial_balance: float = 0.0
		
		match wealth:
			GuestSettingsManager.GuestWealth.POOR:
				initial_balance = POOR_BALANCE
			GuestSettingsManager.GuestWealth.MEDIUM:
				initial_balance = MEDIUM_BALANCE
			GuestSettingsManager.GuestWealth.RICH:
				initial_balance = RICH_BALANCE
			_:
				initial_balance = MEDIUM_BALANCE  # По умолчанию средний
		
		# Устанавливаем начальный баланс
		guest_initial_balances[guest_id - 1] = initial_balance
		set_guest_balance(guest_id, initial_balance)
	
	_save_stats()
	print("💰 Все балансы гостей сброшены до начальных значений (в зависимости от статуса богатства)")

# ← Получить форматированную строку баланса (для UI)
func get_balance_string(guest_id: int) -> String:
	var balance = get_guest_balance(guest_id)
	if balance >= 0:
		return "+%.0f" % balance
	else:
		return "%.0f" % balance

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ РАБОТЫ С НАЧАЛЬНЫМИ БАЛАНСАМИ
# ═══════════════════════════════════════════════════════════════════════════

# ← Инициализировать баланс гостя по статусу богатства
func initialize_guest_balance(guest_id: int) -> void:
	"""Инициализирует баланс гостя на основе его текущего статуса богатства
	
	ВАЖНО: Эта функция ПРИНУДИТЕЛЬНО устанавливает баланс согласно статусу.
	Используется при активации нового гостя или при изменении статуса богатства.
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	# Получаем статус богатства гостя
	var wealth = GuestSettingsManager.get_guest_wealth(guest_id)
	var initial_balance: float = 0.0
	
	match wealth:
		GuestSettingsManager.GuestWealth.POOR:
			initial_balance = POOR_BALANCE
		GuestSettingsManager.GuestWealth.MEDIUM:
			initial_balance = MEDIUM_BALANCE
		GuestSettingsManager.GuestWealth.RICH:
			initial_balance = RICH_BALANCE
		_:
			initial_balance = MEDIUM_BALANCE  # По умолчанию средний
	
	# Устанавливаем начальный баланс ПРИНУДИТЕЛЬНО (перезаписываем текущий баланс)
	guest_initial_balances[guest_id - 1] = initial_balance
	set_guest_balance(guest_id, initial_balance)
	
	print("💰 Гость %d: начальный баланс установлен = %.0f (статус: %s)" % [guest_id, initial_balance, GuestSettingsManager.GuestWealth.keys()[wealth]])

# ← Получить начальный баланс гостя
func get_initial_balance(guest_id: int) -> float:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0.0
	return guest_initial_balances[guest_id - 1]

# ← Получить изменение баланса (текущий - начальный)
func get_balance_change(guest_id: int) -> float:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0.0
	
	var current_balance = get_guest_balance(guest_id)
	var initial_balance = get_initial_balance(guest_id)
	return current_balance - initial_balance

# ← Проверить балансы всех гостей в конце раунда
func check_guests_balance_at_round_end() -> void:
	"""Проверяет всех включенных гостей и выключает тех, кто ушел в минус"""
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	if not GuestReturnManager:
		push_error("GuestStatsManager: GuestReturnManager не найден!")
		return
	
	# Получаем текущий номер раунда
	var current_round = GuestReturnManager.get_current_round()
	
	# Проверяем всех включенных гостей
	for guest_id in range(1, 7):
		if not GuestSettingsManager.is_guest_enabled(guest_id):
			continue  # Пропускаем выключенных гостей
		
		var balance = get_guest_balance(guest_id)
		
		# Если баланс отрицательный - выключаем гостя и отмечаем уход
		if balance < 0:
			# Выключаем гостя
			GuestSettingsManager.set_guest_enabled(guest_id, false)
			
			# Отмечаем в GuestReturnManager (причина ухода: банкротство)
			GuestReturnManager.mark_guest_left(guest_id, current_round, GuestReturnManager.LeaveReason.BANKRUPTCY)
			
			# Эмитим сигнал с причиной ухода
			guest_left.emit(guest_id)
			EventBus.guest_left_due_to_bankruptcy.emit(guest_id)
			
			print("👋 Гость %d ушел в минус (баланс: %.0f)" % [guest_id, balance])

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА И ОБНОВЛЕНИЕ СТАТУСА БОГАТСТВА
# ═══════════════════════════════════════════════════════════════════════════

func check_and_update_guest_wealth(guest_id: int) -> void:
	"""Проверяет баланс гостя и обновляет статус богатства при необходимости
	
	Логика переходов:
	- Бедный → Средний: если баланс >= 70000
	- Средний → Богатый: если баланс >= 150000
	- Богатый → Средний: если баланс < 70000 (но >= 30000)
	- Богатый → Бедный: если баланс < 30000 (прямой переход, если большая проигрышная ставка)
	- Средний → Бедный: если баланс < 30000
	
	ВАЖНО: Текущий баланс НЕ меняется, меняется только статус (влияет на размер будущих ставок)
	"""
	if guest_id < 1 or guest_id > 6:
		return
	
	if not GuestSettingsManager:
		return
	
	var current_balance = get_guest_balance(guest_id)
	var current_wealth = GuestSettingsManager.get_guest_wealth(guest_id)
	var new_wealth: GuestSettingsManager.GuestWealth = current_wealth
	
	# Логика перехода между статусами
	match current_wealth:
		GuestSettingsManager.GuestWealth.POOR:
			# Бедный → Средний
			if current_balance >= WEALTH_THRESHOLD_POOR_TO_MEDIUM:
				new_wealth = GuestSettingsManager.GuestWealth.MEDIUM
		
		GuestSettingsManager.GuestWealth.MEDIUM:
			# Средний → Богатый
			if current_balance >= WEALTH_THRESHOLD_MEDIUM_TO_RICH:
				new_wealth = GuestSettingsManager.GuestWealth.RICH
			# Средний → Бедный
			elif current_balance < WEALTH_THRESHOLD_MEDIUM_TO_POOR:
				new_wealth = GuestSettingsManager.GuestWealth.POOR
		
		GuestSettingsManager.GuestWealth.RICH:
			# Богатый → Бедный (прямой переход при большой проигрышной ставке)
			if current_balance < WEALTH_THRESHOLD_RICH_TO_POOR:
				new_wealth = GuestSettingsManager.GuestWealth.POOR
			# Богатый → Средний
			elif current_balance < WEALTH_THRESHOLD_RICH_TO_MEDIUM:
				new_wealth = GuestSettingsManager.GuestWealth.MEDIUM
	
	# Обновляем статус, если он изменился
	if new_wealth != current_wealth:
		var old_wealth_name = GuestSettingsManager.GuestWealth.keys()[current_wealth]
		var new_wealth_name = GuestSettingsManager.GuestWealth.keys()[new_wealth]
		
		# ВАЖНО: Изменяем статус с preserve_balance = true, чтобы не сбросить баланс
		GuestSettingsManager.set_guest_wealth(guest_id, new_wealth, true)
		
		print("💼 Гость %d: статус изменился %s → %s (баланс: %.0f)" % [
			guest_id, old_wealth_name, new_wealth_name, current_balance
		])

func check_all_guests_wealth_at_round_end() -> void:
	"""Проверяет всех активных гостей и обновляет их статус богатства при необходимости
	
	Вызывается в конце раунда после всех выплат (в _complete_round_and_prepare_new_game)
	"""
	if not GuestSettingsManager:
		return
	
	for guest_id in range(1, 7):
		if GuestSettingsManager.is_guest_enabled(guest_id):
			check_and_update_guest_wealth(guest_id)

# ← Обработать уход гостя из-за терпения (терпение достигло 0)
func _handle_guest_left_due_to_patience(guest_id: int) -> void:
	"""Обработать уход гостя из-за терпения (терпение достигло 0)
	
	Выключает гостя, отмечает в GuestReturnManager и эмитит события.
	Аналогично уходу при банкротстве, но с дополнительным событием для отнятия сердца.
	"""
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	if not GuestSettingsManager.is_guest_enabled(guest_id):
		return  # Гость уже выключен
	
	if not GuestReturnManager:
		push_error("GuestStatsManager: GuestReturnManager не найден!")
		return
	
	# Получаем текущий номер раунда
	var current_round = GuestReturnManager.get_current_round()
	
	# Выключаем гостя
	GuestSettingsManager.set_guest_enabled(guest_id, false)
	
	# Отмечаем в GuestReturnManager (причина ухода: потеря терпения)
	GuestReturnManager.mark_guest_left(guest_id, current_round, GuestReturnManager.LeaveReason.PATIENCE)
	
	# Эмитим стандартный сигнал ухода (для совместимости)
	guest_left.emit(guest_id)
	
	# Эмитим специальное событие для отнятия сердца
	if EventBus:
		EventBus.guest_left_due_to_patience.emit(guest_id)
	
	print("👋 Гость %d ушел из-за терпения (терпение = 0%%)" % guest_id)

# ← Инициализировать балансы всех включенных гостей
func _initialize_all_enabled_guests() -> void:
	"""Инициализирует балансы всех включенных гостей при загрузке"""
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	for guest_id in range(1, 7):
		if GuestSettingsManager.is_guest_enabled(guest_id):
			# Проверяем, был ли баланс уже инициализирован
			# Если начальный баланс = 0, значит еще не инициализирован
			if get_initial_balance(guest_id) == 0.0:
				initialize_guest_balance(guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ РАБОТЫ С ТЕРПЕНИЕМ
# ═══════════════════════════════════════════════════════════════════════════

# ← Получить терпение гостя (guest_id: 1-6)
func get_guest_patience(guest_id: int) -> int:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0
	return guest_patience[guest_id - 1]

# ← Увеличить терпение гостя (+10 при восстановлении через таймер)
func add_patience(guest_id: int, amount: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var current_patience = guest_patience[guest_id - 1]
	var new_patience = min(current_patience + amount, 100)  # Максимум 100
	
	if new_patience != current_patience:
		guest_patience[guest_id - 1] = new_patience
		guest_patience_changed.emit(guest_id, new_patience)
		print("😌 Гость %d: терпение %d -> %d (+%d)" % [guest_id, current_patience, new_patience, amount])

# ← Уменьшить терпение гостя (-10 при ошибке или истечении таймера)
func decrease_patience(guest_id: int, amount: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var current_patience = guest_patience[guest_id - 1]
	var new_patience = max(current_patience - amount, 0)  # Минимум 0
	
	# Обновляем терпение всегда, даже если оно уже 0 (чтобы сработала проверка на уход)
	guest_patience[guest_id - 1] = new_patience
	
	if new_patience != current_patience:
		guest_patience_changed.emit(guest_id, new_patience)
		print("😤 Гость %d: терпение %d -> %d (-%d)" % [guest_id, current_patience, new_patience, amount])
	else:
		# Терпение уже было 0, но нужно проверить уход (для возвращенных гостей)
		if current_patience == 0 and new_patience == 0:
			print("😤 Гость %d: терпение уже 0%%, проверяем уход" % guest_id)
	
	# Проверяем, достигло ли терпение 0 (после обновления)
	if new_patience == 0:
		# Терпение закончилось - гость уходит (если он еще активен)
		if GuestSettingsManager and GuestSettingsManager.is_guest_enabled(guest_id):
			_handle_guest_left_due_to_patience(guest_id)
	elif current_patience != new_patience:
		# Терпение уменьшилось, но не стало 0 - запускаем таймер терпения (если PatienceTimerManager доступен)
		# Таймер будет восстанавливать терпение обратно
		if PatienceTimerManager and new_patience < 100:
			PatienceTimerManager.start_timer(guest_id)

# ← Установить терпение гостя (произвольное значение от 0 до 100)
func set_guest_patience(guest_id: int, patience: int) -> void:
	"""Установить терпение гостя
	
	Args:
		guest_id: ID гостя (1-6)
		patience: Значение терпения (0-100)
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var clamped_patience = clamp(patience, 0, 100)
	var current_patience = guest_patience[guest_id - 1]
	
	if clamped_patience != current_patience:
		guest_patience[guest_id - 1] = clamped_patience
		guest_patience_changed.emit(guest_id, clamped_patience)
		print("😌 Гость %d: терпение установлено до %d%%" % [guest_id, clamped_patience])

# ← Сбросить терпение гостя
func reset_guest_patience(guest_id: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	guest_patience[guest_id - 1] = 100
	guest_patience_changed.emit(guest_id, 100)

# ← Сбросить терпение всех гостей (при перезапуске игры)
func reset_all_patience() -> void:
	for i in range(6):
		guest_patience[i] = 100
	print("😌 Все терпения гостей сброшены (восстановлено до 100%)")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_payout_wrong(_collected: float, _expected: float, bet_type: String, position_index: int) -> void:
	"""Обработчик неправильной выплаты - уменьшаем терпение гостя
	
	Терпение уменьшается когда:
	- Дилер пытается забрать не проигравшую ставку гостя
	- Дилер нажал неправильную выплату для ставки гостя
	"""
	# Проверяем, является ли ставка гостевой
	if bet_type.is_empty() or position_index < 0:
		# Нет информации о ставке - пропускаем
		return
	
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	if sector < 1 or sector > 6:
		# Не гостевые ставки - терпение не уменьшаем
		return
	
	var guest_id = sector
	decrease_patience(guest_id, 10)
	print("😤 Гость %d: терпение уменьшено на 10 из-за неправильной выплаты %s[%d]" % [guest_id, bet_type, position_index])

func _on_game_restarted() -> void:
	"""Обработчик рестарта игры - сбрасываем все терпения и балансы"""
	# 1. Сбрасываем терпение всех гостей до 100%
	reset_all_patience()
	
	# 2. Сбрасываем таймеры терпения
	if PatienceTimerManager:
		PatienceTimerManager.reset_all_timers()
	
	# 3. Сбрасываем все балансы гостей на 0 (не используем reset_all_balances, т.к. она устанавливает начальные значения)
	for i in range(6):
		guest_balances[i] = 0.0
		guest_initial_balances[i] = 0.0
	
	# 4. Переинициализируем включенных гостей (установим начальные балансы согласно их статусу богатства)
	_initialize_all_enabled_guests()
	
	print("🔄 GuestStatsManager: все данные сброшены при рестарте (терпение=100%, балансы=0)")

# ═══════════════════════════════════════════════════════════════════════════
# СОХРАНЕНИЕ/ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════════════════

func _save_stats() -> void:
	var data: Dictionary = {}
	for i in range(6):
		data["guest_%d" % (i + 1)] = guest_balances[i]
	SaveManager.save_guest_stats(data)

func _load_stats() -> void:
	var data = SaveManager.load_guest_stats()
	if data.is_empty():
		# Нет сохранённых данных - используем нули
		return
	
	for i in range(6):
		var key = "guest_%d" % (i + 1)
		if data.has(key):
			guest_balances[i] = data[key] as float
		else:
			guest_balances[i] = 0.0
