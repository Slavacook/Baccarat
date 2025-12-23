# res://scripts/ChipRestorationCoordinator.gd
# Координатор восстановления фишек из TableStateManager
# Отвечает за определение того, какие фишки нужно восстановить и как

class_name ChipRestorationCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var guest_bet_storage: GuestBetStorage = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(storage: GuestBetStorage = null):
	guest_bet_storage = storage

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_restoration_instructions() -> Dictionary:
	"""Получить инструкции по восстановлению фишек
	
	Returns:
		Dictionary с полями:
		- should_restore_from_table_state: bool - нужно ли восстанавливать из TableStateManager
		- should_show_guest_bets: bool - нужно ли показывать ставки гостей
		- chips_to_restore: Array[Dictionary] - массив фишек для восстановления
		  Каждый элемент: {bet_type: String, chip_texture: String}
		- reason: String - причина решения (для логирования)
	"""
	var instructions = {
		"should_restore_from_table_state": false,
		"should_show_guest_bets": false,
		"chips_to_restore": [],
		"reason": ""
	}
	
	# Проверяем есть ли сохраненное состояние
	if not TableStateManager.has_saved_state() or TableStateManager.get_bets().size() == 0:
		instructions["reason"] = "Нет сохраненного состояния в TableStateManager"
		instructions["should_show_guest_bets"] = _has_guests_with_bets()
		return instructions
	
	# Проверяем есть ли гости с ставками (для режима GUEST)
	var has_guests = _has_guests_with_bets()
	
	if not has_guests:
		instructions["reason"] = "Режим GUEST: нет гостей, пропускаем восстановление из TableStateManager"
		return instructions
	
	# Восстанавливаем фишки из TableStateManager
	instructions["should_restore_from_table_state"] = true
	instructions["should_show_guest_bets"] = true
	instructions["chips_to_restore"] = _get_chips_to_restore()
	instructions["reason"] = "Восстановление фишек из TableStateManager (%d ставок)" % instructions["chips_to_restore"].size()
	
	return instructions

func should_restore_from_table_state() -> bool:
	"""Проверить, нужно ли восстанавливать фишки из TableStateManager
	
	Returns:
		true если есть сохраненное состояние и есть гости с ставками
	"""
	if not TableStateManager.has_saved_state() or TableStateManager.get_bets().size() == 0:
		return false
	
	return _has_guests_with_bets()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _has_guests_with_bets() -> bool:
	"""Проверить, есть ли гости с ставками"""
	if not guest_bet_storage:
		return false
	return not guest_bet_storage.get_guests_with_bets().is_empty()

func _get_chips_to_restore() -> Array[Dictionary]:
	"""Получить список фишек для восстановления из TableStateManager
	
	Returns:
		Array[Dictionary] где каждый элемент: {bet_type: String, chip_texture: String}
	"""
	var chips: Array[Dictionary] = []
	
	for bet in TableStateManager.get_bets():
		var bet_type = bet.get_bet_type()
		var chip_texture = bet.get_chip_texture()
		chips.append({
			"bet_type": bet_type,
			"chip_texture": chip_texture
		})
	
	return chips

