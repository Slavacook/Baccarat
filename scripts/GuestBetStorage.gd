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
