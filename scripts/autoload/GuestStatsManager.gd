# res://scripts/autoload/GuestStatsManager.gd
# Autoload синглтон для управления статистикой гостей
# Хранит баланс каждого гостя (может быть отрицательным)

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal guest_balance_changed(guest_id: int, new_balance: float)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Баланс 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Баланс может быть отрицательным (проигрыш) или положительным (выигрыш)
var guest_balances: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Загружаем сохранённые балансы
	_load_stats()
	print("💰 GuestStatsManager загружен: балансы %d гостей" % guest_balances.size())

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
