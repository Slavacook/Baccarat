# res://scripts/autoload/GuestStatsManager.gd
# Autoload синглтон для управления статистикой гостей
# Хранит баланс каждого гостя (может быть отрицательным)

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal guest_balance_changed(guest_id: int, new_balance: float)
signal guest_patience_changed(guest_id: int, new_patience: int)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Баланс 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Баланс может быть отрицательным (проигрыш) или положительным (выигрыш)
var guest_balances: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# Терпение 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Терпение 0-100 (0 = полный чай, 100 = нет чая)
# НЕ сохраняется между сеансами (сбрасывается при перезапуске)
var guest_patience: Array[int] = [0, 0, 0, 0, 0, 0]

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Загружаем сохранённые балансы
	_load_stats()
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

# ← Сбросить балансы всех гостей
func reset_all_balances() -> void:
	for i in range(6):
		guest_balances[i] = 0.0
	_save_stats()
	print("💰 Все балансы гостей сброшены")

# ← Получить форматированную строку баланса (для UI)
func get_balance_string(guest_id: int) -> String:
	var balance = get_guest_balance(guest_id)
	if balance >= 0:
		return "+%.0f" % balance
	else:
		return "%.0f" % balance

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ РАБОТЫ С ТЕРПЕНИЕМ
# ═══════════════════════════════════════════════════════════════════════════

# ← Получить терпение гостя (guest_id: 1-6)
func get_guest_patience(guest_id: int) -> int:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0
	return guest_patience[guest_id - 1]

# ← Добавить терпение гостю (+10 при ошибке)
func add_patience(guest_id: int, amount: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var current_patience = guest_patience[guest_id - 1]
	var new_patience = min(current_patience + amount, 100)  # Максимум 100
	
	if new_patience != current_patience:
		guest_patience[guest_id - 1] = new_patience
		guest_patience_changed.emit(guest_id, new_patience)
		print("😤 Гость %d: терпение %d -> %d (+%d)" % [guest_id, current_patience, new_patience, amount])
		
		# Запускаем таймер терпения (если PatienceTimerManager доступен)
		# PatienceTimerManager - autoload singleton, доступен через имя класса
		if PatienceTimerManager:
			PatienceTimerManager.start_timer(guest_id)

# ← Уменьшить терпение гостя (-10 при истечении таймера)
func decrease_patience(guest_id: int, amount: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var current_patience = guest_patience[guest_id - 1]
	var new_patience = max(current_patience - amount, 0)  # Минимум 0
	
	if new_patience != current_patience:
		guest_patience[guest_id - 1] = new_patience
		guest_patience_changed.emit(guest_id, new_patience)
		print("😌 Гость %d: терпение %d -> %d (-%d)" % [guest_id, current_patience, new_patience, amount])

# ← Сбросить терпение гостя
func reset_guest_patience(guest_id: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	guest_patience[guest_id - 1] = 0
	guest_patience_changed.emit(guest_id, 0)

# ← Сбросить терпение всех гостей (при перезапуске игры)
func reset_all_patience() -> void:
	for i in range(6):
		guest_patience[i] = 0
	print("😌 Все терпения гостей сброшены")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_payout_wrong(_collected: float, _expected: float, bet_type: String, position_index: int) -> void:
	"""Обработчик неправильной выплаты - увеличиваем терпение гостя
	
	Терпение увеличивается когда:
	- Дилер пытается забрать не проигравшую ставку гостя
	- Дилер нажал неправильную выплату для ставки гостя
	"""
	# Проверяем, является ли ставка гостевой
	if bet_type.is_empty() or position_index < 0:
		# Нет информации о ставке - пропускаем
		return
	
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	if sector < 1 or sector > 6:
		# Не гостевые ставки - терпение не увеличиваем
		return
	
	var guest_id = sector
	add_patience(guest_id, 10)
	print("😤 Гость %d: терпение увеличено на 10 из-за неправильной выплаты %s[%d]" % [guest_id, bet_type, position_index])

func _on_game_restarted() -> void:
	"""Обработчик рестарта игры - сбрасываем все терпения"""
	reset_all_patience()
	if PatienceTimerManager:
		PatienceTimerManager.reset_all_timers()

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
