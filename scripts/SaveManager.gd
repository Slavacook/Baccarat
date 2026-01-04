# res://scripts/SaveManager.gd
extends Node

static var instance: SaveManager

const SAVE_PATH = "user://baccarat_stats.save"
const SETTINGS_PATH = "user://baccarat_settings.save"

## Деньги (начальное значение 0, копятся за правильные действия)
var score: int = 0

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	load_data()

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({"score": score})
		file.close()

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary:
				score = data.get("score", 0)  # По умолчанию 0 денег

func get_data() -> Dictionary:
	return {"score": score}

func reset_stats():
	"""Сброс денег на 0 (при Game Over или новой игре)"""
	score = 0
	save_data()

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ДЕНЬГАМИ
# ═══════════════════════════════════════════════════════════════════════════

func add_score(points: int):
	"""Добавить деньги за правильные действия"""
	score += points
	save_data()
	print("💰 Деньги: +%d → %d" % [points, score])

func subtract_score(points: int):
	"""Вычесть деньги (штраф) - минимум 0"""
	var old_score = score
	score = max(score - points, 0)
	save_data()
	print("💰 Деньги: -%d → %d (было %d)" % [points, score, old_score])

# ← Управление настройками игры
func save_settings(settings: Dictionary):
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(settings)
		file.close()

func load_settings() -> Dictionary:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary:
				return data
	return {
		"game_mode": "junket",
		"survival_mode": true,
		"language": "ru",  # По умолчанию русский
		"camera_control_mode": "linked"  # По умолчанию режим 1 (привязанный)
	}

func save_game_mode(mode: String):
	var settings = load_settings()
	settings["game_mode"] = mode
	save_settings(settings)

func load_game_mode() -> String:
	var settings = load_settings()
	return settings.get("game_mode", "junket")

func save_survival_mode(_enabled: bool):
	"""DEPRECATED: Режим выживания теперь всегда включён"""
	pass  # Ничего не делаем, режим всегда включён

func load_survival_mode() -> bool:
	"""Режим выживания всегда включён (сердца + деньги)"""
	return true  # Всегда true

# ← Настройки языка
func save_language(lang: String):
	"""Сохранить язык: "ru" или "en" """
	var settings = load_settings()
	settings["language"] = lang
	save_settings(settings)

func load_language() -> String:
	"""Загрузить язык (по умолчанию "ru")"""
	var settings = load_settings()
	return settings.get("language", "ru")

# ← Настройки режима управления камерой
func save_camera_control_mode(mode: String):
	"""Сохранить режим управления камерой: "linked" (режим 1) или "independent" (режим 2)"""
	var settings = load_settings()
	settings["camera_control_mode"] = mode
	save_settings(settings)

func load_camera_control_mode() -> String:
	"""Загрузить режим управления камерой (по умолчанию "linked" - режим 1)"""
	var settings = load_settings()
	return settings.get("camera_control_mode", "linked")

# ← Настройки рубашки карт
func save_card_back_style(style: String):
	"""Сохранить стиль рубашки карт: "tiger" или "leopard" """
	var settings = load_settings()
	settings["card_back_style"] = style
	save_settings(settings)

func load_card_back_style() -> String:
	"""Загрузить стиль рубашки карт (по умолчанию "tiger")"""
	var settings = load_settings()
	return settings.get("card_back_style", "tiger")

# ← Настройки выплат (переключатели ставок)
func save_payout_settings(player: bool, banker: bool, tie: bool, player_pair: bool = true, banker_pair: bool = true):
	var settings = load_settings()
	settings["payout_player"] = player
	settings["payout_banker"] = banker
	settings["payout_tie"] = tie
	settings["payout_player_pair"] = player_pair
	settings["payout_banker_pair"] = banker_pair
	save_settings(settings)

func load_payout_settings() -> Dictionary:
	var settings = load_settings()
	return {
		"player": settings.get("payout_player", true),
		"banker": settings.get("payout_banker", true),
		"tie": settings.get("payout_tie", true),
		"player_pair": settings.get("payout_player_pair", true),
		"banker_pair": settings.get("payout_banker_pair", true)
	}

# ← Настройки профиля ставок
func save_bet_profile(profile: int):
	var settings = load_settings()
	settings["bet_profile"] = profile
	save_settings(settings)

func load_bet_profile() -> int:
	var settings = load_settings()
	return settings.get("bet_profile", 1)  # По умолчанию MEDIUM (1)

# ← Настройки режима позиций фишек (0=DEFAULT, 1=RANDOM, 2=MAX, 3=REALISTIC)
func save_position_mode(mode: int):
	"""Сохранить режим позиций фишек"""
	var settings = load_settings()
	settings["position_mode"] = mode
	save_settings(settings)

func load_position_mode() -> int:
	"""Загрузить режим позиций фишек (по умолчанию 3 = REALISTIC)"""
	var settings = load_settings()

	# Миграция v5.9+: если сохранен RANDOM (1), переключаем на REALISTIC (3)
	var saved_mode = settings.get("position_mode", -1)
	if saved_mode == 1:  # Был RANDOM
		print("🔄 Миграция: RANDOM (1) → REALISTIC (3)")
		save_position_mode(3)  # Сохраняем новое значение
		return 3

	# Миграция: если есть старый флаг random_positions_enabled
	if settings.has("random_positions_enabled") and settings.get("random_positions_enabled", false):
		print("🔄 Миграция: random_positions_enabled → REALISTIC (3)")
		save_position_mode(3)
		return 3

	# Если ничего не сохранено - возвращаем REALISTIC (3)
	if saved_mode == -1:
		return 3

	return saved_mode  # Возвращаем сохраненное значение (0, 2 или 3)

# Для обратной совместимости
func save_random_positions_mode(enabled: bool):
	"""Сохранить режим случайных позиций фишек (deprecated, используй save_position_mode)"""
	save_position_mode(1 if enabled else 0)

func load_random_positions_mode() -> bool:
	"""Загрузить режим случайных позиций фишек (deprecated)"""
	return load_position_mode() == 1

# ← Настройки гостей
func save_guest_settings(guests_data: Dictionary):
	"""Сохранить настройки гостей"""
	var settings = load_settings()
	settings["guests"] = guests_data
	save_settings(settings)

func load_guest_settings() -> Dictionary:
	"""Загрузить настройки гостей"""
	var settings = load_settings()
	return settings.get("guests", {})

# ← Статистика гостей (баланс)
func save_guest_stats(guest_stats: Dictionary):
	"""Сохранить статистику гостей (баланс каждого)"""
	# Сначала читаем существующие данные
	var data: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var read_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if read_file:
			var existing = read_file.get_var()
			read_file.close()
			if existing is Dictionary:
				data = existing
	
	# Обновляем данные
	data["guest_stats"] = guest_stats
	
	# Записываем обратно
	var write_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if write_file:
		write_file.store_var(data)
		write_file.close()

func load_guest_stats() -> Dictionary:
	"""Загрузить статистику гостей (баланс каждого)"""
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary:
				return data.get("guest_stats", {})
	return {}

# ← Настройки процента чаевых
func save_tip_percentage(percentage: float):
	"""Сохранить процент чаевых (в процентах: 1.0 = 1%, 0.5 = 0.5%)"""
	var settings = load_settings()
	settings["tip_percentage"] = percentage
	save_settings(settings)

func load_tip_percentage() -> float:
	"""Загрузить процент чаевых (по умолчанию 1.0 = 1%)"""
	var settings = load_settings()
	return settings.get("tip_percentage", 1.0)
