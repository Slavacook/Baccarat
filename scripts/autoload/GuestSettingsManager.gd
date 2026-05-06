# res://scripts/autoload/GuestSettingsManager.gd
# Autoload синглтон для управления настройками гостей
# Хранит настройки 6 гостей: включен/выключен, характер, обеспеченность

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ENUM: Характеры гостей
# ═══════════════════════════════════════════════════════════════════════════

enum GuestCharacter {
	MODERATE,    # Умеренный
	CAUTIOUS,    # Осторожный
	GAMBLER      # Азартный
}

# ═══════════════════════════════════════════════════════════════════════════
# ENUM: Обеспеченность гостей (соответствует BetProfileManager)
# ═══════════════════════════════════════════════════════════════════════════

enum GuestWealth {
	POOR,    # Бедный (соответствует SMALL)
	MEDIUM,  # Средний (соответствует MEDIUM)
	RICH     # Богатый (соответствует LARGE)
}

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal guest_settings_changed(guest_id: int)

# ═══════════════════════════════════════════════════════════════════════════
# СТРУКТУРА ДАННЫХ ГОСТЯ
# ═══════════════════════════════════════════════════════════════════════════

class GuestSettings:
	var enabled: bool = false
	var character: GuestCharacter = GuestCharacter.MODERATE
	var wealth: GuestWealth = GuestWealth.MEDIUM
	
	func _init(en: bool = false, char_type: GuestCharacter = GuestCharacter.MODERATE, w: GuestWealth = GuestWealth.MEDIUM):
		enabled = en
		character = char_type
		wealth = w
	
	func to_dict() -> Dictionary:
		return {
			"enabled": enabled,
			"character": character,
			"wealth": wealth
		}
	
	static func from_dict(data: Dictionary) -> GuestSettings:
		return GuestSettings.new(
			data.get("enabled", false),
			data.get("character", GuestCharacter.MODERATE) as GuestCharacter,
			data.get("wealth", GuestWealth.MEDIUM) as GuestWealth
		)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Настройки 6 гостей (индекс 0-5 соответствует гостю 1-6)
var guests: Array[GuestSettings] = []
var _runtime_guests_enabled_override_active: bool = false
var _runtime_guests_snapshot: Array[GuestSettings] = []

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Инициализируем 6 гостей с настройками по умолчанию
	for i in range(6):
		guests.append(GuestSettings.new())
	
	# Загружаем сохранённые настройки
	_load_settings()
	
	print("👥 GuestSettingsManager загружен: %d гостей" % guests.size())

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Получить настройки гостя (guest_id: 1-6)
func get_guest(guest_id: int) -> GuestSettings:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestSettingsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return GuestSettings.new()
	return guests[guest_id - 1]

# ← Установить, включён ли гость
func set_guest_enabled(guest_id: int, enabled: bool) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestSettingsManager: неверный guest_id %d" % guest_id)
		return
	
	guests[guest_id - 1].enabled = enabled
	_save_settings()
	guest_settings_changed.emit(guest_id)
	print("👥 Гость %d: %s" % [guest_id, "включён" if enabled else "выключен"])
	
	# Управление балансом при включении/выключении
	if GuestStatsManager:
		if enabled:
			# При включении - инициализируем начальный баланс
			GuestStatsManager.initialize_guest_balance(guest_id)
		else:
			# При выключении - сбрасываем баланс
			GuestStatsManager.reset_guest_balance(guest_id)

# ← Установить характер гостя
func set_guest_character(guest_id: int, character: GuestCharacter) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestSettingsManager: неверный guest_id %d" % guest_id)
		return
	
	guests[guest_id - 1].character = character
	_save_settings()
	guest_settings_changed.emit(guest_id)
	print("👥 Гость %d: характер = %s" % [guest_id, GuestCharacter.keys()[character]])

# ← Установить обеспеченность гостя
func set_guest_wealth(guest_id: int, wealth: GuestWealth, preserve_balance: bool = false) -> void:
	"""Установить обеспеченность гостя
	
	Args:
		guest_id: ID гостя (1-6)
		wealth: Новый статус богатства
		preserve_balance: Если true, баланс не меняется (только статус)
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestSettingsManager: неверный guest_id %d" % guest_id)
		return
	
	guests[guest_id - 1].wealth = wealth
	_save_settings()
	guest_settings_changed.emit(guest_id)
	print("👥 Гость %d: обеспеченность = %s" % [guest_id, GuestWealth.keys()[wealth]])
	
	# Переинициализируем баланс ТОЛЬКО если preserve_balance = false
	if not preserve_balance and GuestStatsManager:
		GuestStatsManager.initialize_guest_balance(guest_id)

func set_runtime_guests_enabled_override(enabled_flags: Array[bool]) -> void:
	"""Применить runtime override состава гостей без записи в локальные настройки."""
	if enabled_flags.size() != 6:
		push_error("GuestSettingsManager: enabled_flags должен содержать 6 элементов")
		return

	if not _runtime_guests_enabled_override_active:
		_runtime_guests_snapshot = _duplicate_guests_array(guests)
		_runtime_guests_enabled_override_active = true

	var changed_guest_ids: Array[int] = []
	for i in range(6):
		var guest_id := i + 1
		var new_enabled := enabled_flags[i]
		if guests[i].enabled == new_enabled:
			continue

		guests[i].enabled = new_enabled
		changed_guest_ids.append(guest_id)

		if GuestStatsManager:
			if new_enabled:
				GuestStatsManager.initialize_guest_balance(guest_id)
			else:
				GuestStatsManager.reset_guest_balance(guest_id)

		if new_enabled and GuestReturnManager:
			GuestReturnManager.register_guest_activation(guest_id)

	for guest_id in changed_guest_ids:
		guest_settings_changed.emit(guest_id)

	var active_guests := get_active_guests()
	print("🧪 TOURNAMENT SETTINGS TRACE guests_enabled override applied active_guests=%s" % str(active_guests))

func clear_runtime_guests_enabled_override() -> void:
	"""Очистить runtime override и вернуть локальные настройки гостей."""
	if not _runtime_guests_enabled_override_active:
		return

	var changed_guest_ids: Array[int] = []
	for i in range(6):
		var guest_id := i + 1
		var snapshot_guest := _runtime_guests_snapshot[i]
		var was_enabled := guests[i].enabled
		var restored_enabled := snapshot_guest.enabled

		guests[i].enabled = snapshot_guest.enabled
		guests[i].character = snapshot_guest.character
		guests[i].wealth = snapshot_guest.wealth

		if was_enabled == restored_enabled:
			continue

		changed_guest_ids.append(guest_id)

		if GuestStatsManager:
			if restored_enabled:
				GuestStatsManager.initialize_guest_balance(guest_id)
			else:
				GuestStatsManager.reset_guest_balance(guest_id)

		if restored_enabled and GuestReturnManager:
			GuestReturnManager.register_guest_activation(guest_id)

	for guest_id in changed_guest_ids:
		guest_settings_changed.emit(guest_id)

	_runtime_guests_snapshot.clear()
	_runtime_guests_enabled_override_active = false
	print("🧪 TOURNAMENT SETTINGS TRACE guests_enabled override cleared active_guests=%s" % str(get_active_guests()))

# ← Получить список активных гостей (возвращает массив guest_id: 1-6)
func get_active_guests() -> Array[int]:
	var active: Array[int] = []
	for i in range(6):
		if guests[i].enabled:
			active.append(i + 1)  # guest_id начинается с 1
	return active

# ← Проверить, включён ли гость
func is_guest_enabled(guest_id: int) -> bool:
	if guest_id < 1 or guest_id > 6:
		return false
	return guests[guest_id - 1].enabled

# ← Получить характер гостя
func get_guest_character(guest_id: int) -> GuestCharacter:
	if guest_id < 1 or guest_id > 6:
		return GuestCharacter.MODERATE
	return guests[guest_id - 1].character

# ← Получить обеспеченность гостя
func get_guest_wealth(guest_id: int) -> GuestWealth:
	if guest_id < 1 or guest_id > 6:
		return GuestWealth.MEDIUM
	return guests[guest_id - 1].wealth

# ← Конвертировать GuestWealth в BetProfileManager.BetProfile
func wealth_to_bet_profile(wealth: GuestWealth) -> int:
	match wealth:
		GuestWealth.POOR:
			return BetProfileManager.BetProfile.SMALL
		GuestWealth.MEDIUM:
			return BetProfileManager.BetProfile.MEDIUM
		GuestWealth.RICH:
			return BetProfileManager.BetProfile.LARGE
		_:
			return BetProfileManager.BetProfile.MEDIUM

# ═══════════════════════════════════════════════════════════════════════════
# СОХРАНЕНИЕ/ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════════════════

func _save_settings() -> void:
	var data: Dictionary = {}
	for i in range(6):
		data["guest_%d" % (i + 1)] = guests[i].to_dict()
	SaveManager.save_guest_settings(data)

func _load_settings() -> void:
	var data = SaveManager.load_guest_settings()
	if data.is_empty():
		# Нет сохранённых настроек - используем значения по умолчанию
		return
	
	for i in range(6):
		var key = "guest_%d" % (i + 1)
		if data.has(key):
			guests[i] = GuestSettings.from_dict(data[key])
		else:
			# Нет данных для этого гостя - используем значения по умолчанию
			guests[i] = GuestSettings.new()

func _duplicate_guests_array(source_guests: Array[GuestSettings]) -> Array[GuestSettings]:
	var result: Array[GuestSettings] = []
	for guest in source_guests:
		result.append(GuestSettings.new(guest.enabled, guest.character, guest.wealth))
	return result
