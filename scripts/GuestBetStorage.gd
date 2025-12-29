# res://scripts/GuestBetStorage.gd
# Хранилище сгенерированных ставок гостей до следующей раздачи
# Ставки генерируются при нажатии "Завершить" и используются при подготовке новой игры

class_name GuestBetStorage
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Хранилище ставок: Dictionary[guest_id: int, Array[Bet]]
# Ключ - guest_id (1-6), значение - массив ставок этого гостя (использует единый класс Bet)
var stored_bets: Dictionary = {}

# Временное хранилище для backup (используется при Heart Bet)
var _backup_bets: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Сохранить ставки гостя
func store_guest_bets(guest_id: int, bets: Array) -> void:  # Array[Bet] (типизация убрана для парсинга)
	"""Сохранить ставки гостя до следующей раздачи
	
	Args:
		guest_id: ID гостя (1-6)
		bets: Массив ставок гостя (Bet)
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestBetStorage: неверный guest_id %d" % guest_id)
		return
	
	stored_bets[guest_id] = bets.duplicate()
	print("💾 GuestBetStorage: сохранено %d ставок для гостя %d" % [bets.size(), guest_id])

# ← Получить ставки гостя
func get_guest_bets(guest_id: int) -> Array:  # Array[Bet] (типизация убрана для парсинга)
	"""Получить сохранённые ставки гостя
	
	Args:
		guest_id: ID гостя (1-6)
	
	Returns:
		Массив ставок гостя (Bet) или пустой массив если нет ставок
	"""
	if guest_id < 1 or guest_id > 6:
		return []
	
	if not stored_bets.has(guest_id):
		return []
	
	return stored_bets[guest_id].duplicate()

# ← Получить все сохранённые ставки (для всех гостей)
func get_all_bets() -> Array:  # Array[Bet] (типизация убрана для парсинга)
	"""Получить все сохранённые ставки всех гостей
	
	Returns:
		Массив всех ставок (Bet)
	"""
	var all_bets: Array = []  # Array[Bet] (типизация убрана для парсинга)
	for guest_id in stored_bets.keys():
		all_bets.append_array(stored_bets[guest_id])
	return all_bets

# ← Очистить ставки гостя
func clear_guest_bets(guest_id: int) -> void:
	"""Очистить ставки гостя после использования
	
	Args:
		guest_id: ID гостя (1-6)
	"""
	if stored_bets.has(guest_id):
		stored_bets.erase(guest_id)
		print("🗑️ GuestBetStorage: очищены ставки гостя %d" % guest_id)

# ← Очистить все ставки
func clear_all_bets() -> void:
	"""Очистить все сохранённые ставки"""
	stored_bets.clear()
	print("🗑️ GuestBetStorage: очищены все ставки")

# ← Проверить, есть ли ставки для гостя
func has_guest_bets(guest_id: int) -> bool:
	"""Проверить, есть ли сохранённые ставки для гостя"""
	if guest_id < 1 or guest_id > 6:
		return false
	return stored_bets.has(guest_id) and stored_bets[guest_id].size() > 0

# ← Получить количество ставок гостя
func get_guest_bets_count(guest_id: int) -> int:
	"""Получить количество сохранённых ставок гостя"""
	if not has_guest_bets(guest_id):
		return 0
	return stored_bets[guest_id].size()

# ← Получить список гостей, у которых есть ставки
func get_guests_with_bets() -> Array[int]:
	"""Получить список ID гостей, у которых есть сохранённые ставки"""
	var guests: Array[int] = []
	for guest_id in stored_bets.keys():
		if stored_bets[guest_id].size() > 0:
			guests.append(guest_id)
	print("👥 get_guests_with_bets(): найдено %d гостей с ставками: %s (stored_bets.keys=%s)" % [guests.size(), guests, stored_bets.keys()])
	return guests

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ BACKUP/RESTORE (для Heart Bet)
# ═══════════════════════════════════════════════════════════════════════════

# ← Сохранить все ставки в backup (для Heart Bet)
func backup_all_bets() -> void:
	"""Сохранить все текущие ставки в backup
	
	Используется при использовании карты Heart Bet для временного сохранения ставок.
	"""
	_backup_bets.clear()
	
	# Глубокое копирование всех ставок
	for guest_id in stored_bets.keys():
		var bets_copy: Array = []
		for bet in stored_bets[guest_id]:
			bets_copy.append(bet)  # Bet - это RefCounted, копируем ссылки
		_backup_bets[guest_id] = bets_copy
	
	var total_bets = 0
	for guest_id in _backup_bets.keys():
		total_bets += _backup_bets[guest_id].size()
	
	print("💾 GuestBetStorage: backup создан (%d ставок для %d гостей)" % [total_bets, _backup_bets.size()])

# ← Восстановить все ставки из backup (после Heart Bet)
func restore_all_bets() -> void:
	"""Восстановить все ставки из backup
	
	Используется после завершения Heart Bet раунда для восстановления ставок.
	ВАЖНО: Backup НЕ очищается после восстановления, чтобы можно было использовать карту несколько раз подряд.
	Backup очищается только при создании нового backup (в backup_all_bets).
	"""
	if _backup_bets.is_empty():
		print("⚠️ GuestBetStorage: нет backup для восстановления (ставок не было)")
		# Это нормально - если ставок не было, backup будет пустым
		return
	
	# Очищаем текущие ставки
	stored_bets.clear()
	
	# Восстанавливаем из backup
	for guest_id in _backup_bets.keys():
		var bets_copy: Array = []
		for bet in _backup_bets[guest_id]:
			bets_copy.append(bet)  # Bet - это RefCounted, копируем ссылки
		stored_bets[guest_id] = bets_copy
	
	var total_bets = 0
	for guest_id in stored_bets.keys():
		total_bets += stored_bets[guest_id].size()
	
	print("💾 GuestBetStorage: ставки восстановлены из backup (%d ставок для %d гостей)" % [total_bets, stored_bets.size()])
	
	# ВАЖНО: НЕ очищаем backup после восстановления!
	# Это позволяет использовать карту Heart Bet несколько раз подряд.
	# Backup будет очищен только при создании нового backup (в backup_all_bets).
	# _backup_bets.clear()  # УБРАНО - backup должен сохраняться для повторного использования

# ← Проверить, есть ли backup
func has_backup() -> bool:
	"""Проверить, есть ли сохранённый backup"""
	return not _backup_bets.is_empty()
