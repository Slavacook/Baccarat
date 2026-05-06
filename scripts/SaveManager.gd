# res://scripts/SaveManager.gd
extends Node

static var instance: SaveManager

const SAVE_PATH = "user://baccarat_stats.save"
const SETTINGS_PATH = "user://baccarat_settings.save"

## Деньги (начальное значение 0, копятся за правильные действия)
var score: int = 0
var _runtime_chance_cards_enabled_override_active: bool = false
var _runtime_chance_cards_enabled_override: bool = false
var _runtime_tip_percentage_override_active: bool = false
var _runtime_tip_percentage_override: float = 0.0

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
	"""Загрузить настройки из файла или вернуть значения по умолчанию"""
	var settings: Dictionary = {}
	
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary:
				settings = data
	
	# Устанавливаем значения по умолчанию для отсутствующих ключей
	_ensure_default_settings(settings)
	
	return settings

func _ensure_default_settings(settings: Dictionary) -> void:
	"""Убедиться, что все необходимые настройки имеют значения по умолчанию
	
	Если настройка отсутствует в словаре, она будет добавлена с дефолтным значением.
	Это позволяет устанавливать дефолты для новых настроек без потери существующих.
	"""
	var settings_changed: bool = false
	
	# Базовые настройки
	if not settings.has("game_mode"):
		settings["game_mode"] = "junket"
		settings_changed = true
	if not settings.has("survival_mode"):
		settings["survival_mode"] = true
		settings_changed = true
	if not settings.has("language"):
		settings["language"] = "ru"  # По умолчанию русский
		settings_changed = true
	if not settings.has("camera_control_mode"):
		settings["camera_control_mode"] = "independent"  # Режим 1 удалён, всегда используем режим 2 (независимый)
		settings_changed = true
	
	# Настройки прогрессии гостей (сюжет - автоматический режим)
	if not settings.has("guest_progression_auto_mode"):
		settings["guest_progression_auto_mode"] = true  # Автоматический режим включен по умолчанию
		settings_changed = true
	
	# Пороги чаевых для гостей (если не установлены, используем стандартные)
	if not settings.has("guest_progression_thresholds") or settings["guest_progression_thresholds"].is_empty():
		settings["guest_progression_thresholds"] = {
			1: 0,      # Начальное состояние - 1 гость
			2: 100,    # 2-й гость при 100 чаевых
			3: 300,    # 3-й гость при 300 чаевых
			4: 900,    # 4-й гость при 900 чаевых
			5: 2700,   # 5-й гость при 2700 чаевых
			6: 8100    # 6-й гость при 8100 чаевых
		}
		settings_changed = true
	
	# Карты шансов - выключены по умолчанию
	if not settings.has("chance_cards_enabled"):
		settings["chance_cards_enabled"] = false
		settings_changed = true
	
	# Автозабор - включен по умолчанию
	if not settings.has("auto_mode_switch_enabled"):
		settings["auto_mode_switch_enabled"] = true
		settings_changed = true
	
	# Бессмертие - выключено по умолчанию
	if not settings.has("immortality_enabled"):
		settings["immortality_enabled"] = false
		settings_changed = true
	
	# Сохраняем обновленные настройки только если были добавлены дефолты
	# Это нужно, чтобы при следующем запуске дефолты уже были в файле
	if settings_changed:
		save_settings(settings)

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

# ← Настройки режима управления камерой (устарело - режим 1 удалён)
func save_camera_control_mode(_mode: String):
	"""Сохранить режим управления камерой (устарело - режим 1 удалён, всегда используем режим 2)"""
	# Режим 1 удалён, всегда используем режим 2 (independent)
	# Метод оставлен для совместимости, но не сохраняет значение
	pass

func load_camera_control_mode() -> String:
	"""Загрузить режим управления камерой (устарело - режим 1 удалён, всегда возвращает "independent")"""
	# Режим 1 удалён, всегда возвращаем "independent" (режим 2)
	return "independent"

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

func set_runtime_tip_percentage_override(value: float) -> void:
	"""Установить runtime override для процента чаевых без записи в локальные настройки."""
	_runtime_tip_percentage_override_active = true
	_runtime_tip_percentage_override = value

func clear_runtime_tip_percentage_override() -> void:
	"""Очистить runtime override для процента чаевых."""
	_runtime_tip_percentage_override_active = false
	_runtime_tip_percentage_override = 0.0

func load_tip_percentage() -> float:
	"""Загрузить процент чаевых (по умолчанию 0.3 = 0.3%)"""
	if _runtime_tip_percentage_override_active:
		return _runtime_tip_percentage_override
	var settings = load_settings()
	return settings.get("tip_percentage", 0.3)

# ← Настройки карт шансов
func save_chance_cards_enabled(enabled: bool):
	"""Сохранить состояние карт шансов (включены/выключены)"""
	var settings = load_settings()
	settings["chance_cards_enabled"] = enabled
	save_settings(settings)

func set_runtime_chance_cards_enabled_override(enabled: bool) -> void:
	"""Установить runtime override для карт шансов без записи в локальные настройки."""
	_runtime_chance_cards_enabled_override_active = true
	_runtime_chance_cards_enabled_override = enabled

func clear_runtime_chance_cards_enabled_override() -> void:
	"""Очистить runtime override для карт шансов."""
	_runtime_chance_cards_enabled_override_active = false
	_runtime_chance_cards_enabled_override = false

func load_chance_cards_enabled() -> bool:
	"""Загрузить состояние карт шансов (по умолчанию false - выключены)"""
	if _runtime_chance_cards_enabled_override_active:
		return _runtime_chance_cards_enabled_override
	var settings = load_settings()
	return settings.get("chance_cards_enabled", false)

# ← Настройки автоматического переключения режимов сбора/оплаты
func save_auto_mode_switch_enabled(enabled: bool):
	"""Сохранить состояние автоматического переключения режимов сбора/оплаты (включено/выключено)"""
	var settings = load_settings()
	settings["auto_mode_switch_enabled"] = enabled
	save_settings(settings)

func load_auto_mode_switch_enabled() -> bool:
	"""Загрузить состояние автоматического переключения режимов (по умолчанию true - включено)"""
	var settings = load_settings()
	return settings.get("auto_mode_switch_enabled", true)

# ← Настройки бессмертия
func save_immortality_enabled(enabled: bool):
	"""Сохранить состояние бессмертия (включено/выключено)"""
	var settings = load_settings()
	settings["immortality_enabled"] = enabled
	save_settings(settings)

func load_immortality_enabled() -> bool:
	"""Загрузить состояние бессмертия (по умолчанию false - выключено)"""
	var settings = load_settings()
	return settings.get("immortality_enabled", false)

# ← Настройки прогрессии гостей
func save_guest_progression_thresholds(thresholds: Dictionary):
	"""Сохранить пороги прогрессии гостей"""
	var settings = load_settings()
	settings["guest_progression_thresholds"] = thresholds
	save_settings(settings)

func load_guest_progression_thresholds() -> Dictionary:
	"""Загрузить пороги прогрессии гостей"""
	var settings = load_settings()
	return settings.get("guest_progression_thresholds", {})

func save_guest_progression_auto_mode(enabled: bool):
	"""Сохранить состояние автоматического режима прогрессии"""
	var settings = load_settings()
	settings["guest_progression_auto_mode"] = enabled
	save_settings(settings)

func load_guest_progression_auto_mode() -> bool:
	"""Загрузить состояние автоматического режима прогрессии (по умолчанию true)"""
	var settings = load_settings()
	return settings.get("guest_progression_auto_mode", true)
