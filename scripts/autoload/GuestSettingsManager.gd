# res://scripts/autoload/GuestSettingsManager.gd
# Autoload синглтон для управления настройками гостей
# Хранит настройки 6 гостей: включен/выключен, характер, обеспеченность

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ENUM: Характеры гостей
# ═══════════════════════════════════════════════════════════════════════════

enum GuestCharacter {
	GENTLEMAN,   # Джентельмен
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
	var character: GuestCharacter = GuestCharacter.GENTLEMAN
	var wealth: GuestWealth = GuestWealth.MEDIUM
	
	func _init(en: bool = false, char_type: GuestCharacter = GuestCharacter.GENTLEMAN, w: GuestWealth = GuestWealth.MEDIUM):
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
			data.get("character", GuestCharacter.GENTLEMAN) as GuestCharacter,
			data.get("wealth", GuestWealth.MEDIUM) as GuestWealth
		)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Настройки 6 гостей (индекс 0-5 соответствует гостю 1-6)
var guests: Array[GuestSettings] = []

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
func set_guest_wealth(guest_id: int, wealth: GuestWealth) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestSettingsManager: неверный guest_id %d" % guest_id)
		return
	
	guests[guest_id - 1].wealth = wealth
	_save_settings()
	guest_settings_changed.emit(guest_id)
	print("👥 Гость %d: обеспеченность = %s" % [guest_id, GuestWealth.keys()[wealth]])
	
	# Переинициализируем баланс при изменении статуса богатства
	if GuestStatsManager:
		GuestStatsManager.initialize_guest_balance(guest_id)

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
		return GuestCharacter.GENTLEMAN
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
