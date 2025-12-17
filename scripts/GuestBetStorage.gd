# res://scripts/GuestBetStorage.gd
# Хранилище сгенерированных ставок гостей до следующей раздачи
# Ставки генерируются при нажатии "Завершить" и используются при подготовке новой игры

class_name GuestBetStorage
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СТРУКТУРА ДАННЫХ СТАВКИ ГОСТЯ
# ═══════════════════════════════════════════════════════════════════════════

class GuestBet:
	var guest_id: int  # 1-6
	var bet_type: String  # "Player", "Banker", "Tie", "PairPlayer", "PairBanker"
	var stake: float  # Размер ставки
	var position_index: int  # Индекс позиции в секторе гостя
	var sector: int  # Сектор гостя (1-6)
	
	func _init(g_id: int, b_type: String, s: float, pos_idx: int, sec: int):
		guest_id = g_id
		bet_type = b_type
		stake = s
		position_index = pos_idx
		sector = sec
	
	func to_dict() -> Dictionary:
		return {
			"guest_id": guest_id,
			"bet_type": bet_type,
			"stake": stake,
			"position_index": position_index,
			"sector": sector
		}
	
	static func from_dict(data: Dictionary) -> GuestBet:
		return GuestBet.new(
			data.get("guest_id", 0),
			data.get("bet_type", ""),
			data.get("stake", 0.0),
			data.get("position_index", 0),
			data.get("sector", 0)
		)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Хранилище ставок: Dictionary[guest_id: int, Array[GuestBet]]
# Ключ - guest_id (1-6), значение - массив ставок этого гостя
var stored_bets: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Сохранить ставки гостя
func store_guest_bets(guest_id: int, bets: Array[GuestBet]) -> void:
	"""Сохранить ставки гостя до следующей раздачи
	
	Args:
		guest_id: ID гостя (1-6)
		bets: Массив ставок гостя
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestBetStorage: неверный guest_id %d" % guest_id)
		return
	
	stored_bets[guest_id] = bets.duplicate()
	print("💾 GuestBetStorage: сохранено %d ставок для гостя %d" % [bets.size(), guest_id])

# ← Получить ставки гостя
func get_guest_bets(guest_id: int) -> Array[GuestBet]:
	"""Получить сохранённые ставки гостя
	
	Args:
		guest_id: ID гостя (1-6)
	
	Returns:
		Массив ставок гостя или пустой массив если нет ставок
	"""
	if guest_id < 1 or guest_id > 6:
		return []
	
	if not stored_bets.has(guest_id):
		return []
	
	return stored_bets[guest_id].duplicate()

# ← Получить все сохранённые ставки (для всех гостей)
func get_all_bets() -> Array[GuestBet]:
	"""Получить все сохранённые ставки всех гостей
	
	Returns:
		Массив всех ставок
	"""
	var all_bets: Array[GuestBet] = []
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
	return guests
