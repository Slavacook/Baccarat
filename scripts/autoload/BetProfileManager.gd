# res://scripts/autoload/BetProfileManager.gd
# Autoload синглтон для управления профилями ставок
# Определяет размер и частоту ставок (малые/средние/крупные)

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ - ПРОФИЛИ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════

enum BetProfile {
	SMALL,   # Малые ставки (для новичков)
	MEDIUM,  # Средние ставки (реалистичная игра)
	LARGE    # Крупные ставки (VIP-клиент)
}

# ═══════════════════════════════════════════════════════════════════════════
# ФИКСИРОВАННЫЕ ДИАПАЗОНЫ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════
# Формат: [[min, max, chance%], ...]
# Проценты: [70, 22, 7.5, 0.5] = чаще/реже/редко/невероятно

const BET_RANGES = {
	"classic": {
		"small_main": [[50, 150, 70], [151, 400, 22], [401, 700, 7.5], [701, 2000, 0.5]],
		"small_tie": [[25, 50, 70], [51, 70, 22], [71, 100, 7.5], [101, 150, 0.5]],
		"small_pair": [[25, 100, 70], [101, 300, 22], [301, 600, 7.5], [601, 900, 0.5]],

		"medium_main": [[50, 700, 70], [701, 1000, 22], [1001, 1500, 7.5], [1501, 3000, 0.5]],
		"medium_tie": [[100, 300, 70], [301, 600, 22], [601, 900, 7.5], [901, 1000, 0.5]],
		"medium_pair": [[25, 300, 70], [301, 500, 22], [501, 700, 7.5], [701, 900, 0.5]],

		"large_main": [[200, 700, 70], [701, 1200, 22], [1201, 2000, 7.5], [2001, 3000, 0.5]],
		"large_tie": [[100, 500, 70], [501, 700, 22], [701, 900, 7.5], [901, 1000, 0.5]],
		"large_pair": [[100, 400, 70], [401, 600, 22], [601, 800, 7.5], [801, 900, 0.5]]
	},
	"junket": {
		"small_main": [[2000, 10000, 70], [10500, 30000, 22], [30500, 45000, 7.5], [45500, 90000, 0.5]],
		"small_tie": [[100, 200, 70], [200, 300, 22], [300, 400, 7.5], [400, 500, 0.5]],
		"small_pair": [[100, 1000, 70], [1100, 3000, 22], [3100, 7000, 7.5], [7100, 15000, 0.5]],

		"medium_main": [[2000, 20000, 70], [20500, 50000, 22], [50500, 70000, 7.5], [150000, 200000, 0.5]],
		"medium_tie": [[100, 300, 70], [300, 600, 22], [600, 900, 7.5], [900, 1000, 0.5]],
		"medium_pair": [[100, 3000, 70], [3100, 7000, 22], [7100, 10000, 7.5], [10100, 15000, 0.5]],

		"large_main": [[30000, 70000, 70], [70500, 120000, 22], [120500, 200000, 7.5], [2000, 10000, 0.5]],
		"large_tie": [[200, 400, 70], [400, 700, 22], [700, 900, 7.5], [900, 1000, 0.5]],
		"large_pair": [[1000, 5000, 70], [5100, 9000, 22], [9100, 12000, 7.5], [12100, 15000, 0.5]]
	}
}

# Устаревшие шансы (больше не используются, оставлены для совместимости)
const PROFILE_CHANCES = {
	BetProfile.SMALL: {
		"main": [70, 22, 7.5, 0.5],
		"tie": [70, 22, 7.5, 0.5],
		"name_ru": "Малые",
		"name_en": "Small",
		"description_ru": "Небольшие ставки для тренировки",
		"description_en": "Smaller bets for practice"
	},
	BetProfile.MEDIUM: {
		"main": [70, 22, 7.5, 0.5],
		"tie": [70, 22, 7.5, 0.5],
		"name_ru": "Средние",
		"name_en": "Medium",
		"description_ru": "Реалистичная тренировка за столом",
		"description_en": "Realistic table practice"
	},
	BetProfile.LARGE: {
		"main": [70, 22, 7.5, 0.5],
		"tie": [70, 22, 7.5, 0.5],
		"name_ru": "Крупные",
		"name_en": "Large",
		"description_ru": "Сценарий крупного гостя",
		"description_en": "VIP guest scenario"
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal profile_changed(profile: BetProfile)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var current_profile: BetProfile = BetProfile.MEDIUM

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	_load_profile()
	print("💰 BetProfileManager загружен: профиль = %s" % get_profile_name())

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Установить профиль
func set_profile(profile: BetProfile) -> void:
	current_profile = profile
	profile_changed.emit(profile)
	SaveManager.save_bet_profile(profile)
	print("💰 Профиль ставок изменён: %s" % get_profile_name())

# ← Получить текущий профиль
func get_profile() -> BetProfile:
	return current_profile

# ← Получить шансы для основных ставок (Player/Banker)
func get_main_chances() -> Array:
	return PROFILE_CHANCES[current_profile]["main"]

# ← Получить шансы для TIE ставок
func get_tie_chances() -> Array:
	return PROFILE_CHANCES[current_profile]["tie"]

# ← Получить название профиля (локализованное)
func get_profile_name(lang: String = "") -> String:
	if lang == "":
		lang = Localization.get_lang()
	var key = "name_ru" if lang == "ru" else "name_en"
	return PROFILE_CHANCES[current_profile][key]

# ← Получить описание профиля (локализованное)
func get_profile_description(lang: String = "") -> String:
	if lang == "":
		lang = Localization.get_lang()
	var key = "description_ru" if lang == "ru" else "description_en"
	return PROFILE_CHANCES[current_profile][key]

# ← Получить название профиля по enum
func get_profile_name_by_enum(profile: BetProfile, lang: String = "") -> String:
	if lang == "":
		lang = Localization.get_lang()
	var key = "name_ru" if lang == "ru" else "name_en"
	return PROFILE_CHANCES[profile][key]

# ← Циклическое переключение профиля (для UI кнопки)
func cycle_profile() -> void:
	match current_profile:
		BetProfile.SMALL:
			set_profile(BetProfile.MEDIUM)
		BetProfile.MEDIUM:
			set_profile(BetProfile.LARGE)
		BetProfile.LARGE:
			set_profile(BetProfile.SMALL)

# ← Получить фиксированные диапазоны для текущего профиля
func get_ranges(mode: String, bet_type: String) -> Array:
	var profile_name = ""
	match current_profile:
		BetProfile.SMALL:
			profile_name = "small"
		BetProfile.MEDIUM:
			profile_name = "medium"
		BetProfile.LARGE:
			profile_name = "large"

	var key = profile_name + "_" + bet_type  # "small_main", "medium_tie", etc.
	return BET_RANGES[mode][key]

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _load_profile() -> void:
	var saved = SaveManager.load_bet_profile()
	if saved >= 0 and saved <= 2:
		current_profile = saved as BetProfile
	else:
		current_profile = BetProfile.MEDIUM
