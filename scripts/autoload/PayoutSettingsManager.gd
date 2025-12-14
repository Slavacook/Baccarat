# res://scripts/autoload/PayoutSettingsManager.gd
# Autoload синглтон для управления переключателями выплат
# Определяет, на какие позиции (Player/Banker/Tie) активны ставки

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal payout_settings_changed(player: bool, banker: bool, tie: bool, player_pair: bool, banker_pair: bool)
signal random_positions_changed(enabled: bool)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var player_payout_enabled: bool = true
var banker_payout_enabled: bool = true
var tie_payout_enabled: bool = true
var player_pair_payout_enabled: bool = true
var banker_pair_payout_enabled: bool = true

# Режим позиций фишек: DEFAULT (основные), RANDOM (случайные), MAX (все позиции), REALISTIC (случайное кол-во)
enum PositionMode { DEFAULT, RANDOM, MAX, REALISTIC }
var position_mode: PositionMode = PositionMode.DEFAULT

# Для обратной совместимости
var random_positions_enabled: bool:
	get:
		return position_mode == PositionMode.RANDOM

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Загружаем сохранённые настройки
	_load_settings()

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Переключить выплату для игрока
func toggle_player(enabled: bool) -> void:
	player_payout_enabled = enabled
	_emit_and_save()
	print("💰 Player payout: %s" % ("ON" if enabled else "OFF"))

# ← Переключить выплату для банкира
func toggle_banker(enabled: bool) -> void:
	banker_payout_enabled = enabled
	_emit_and_save()
	print("💰 Banker payout: %s" % ("ON" if enabled else "OFF"))

# ← Переключить выплату для ничьей
func toggle_tie(enabled: bool) -> void:
	tie_payout_enabled = enabled
	_emit_and_save()
	print("💰 Tie payout: %s" % ("ON" if enabled else "OFF"))

# ← Переключить выплату для пары игрока
func toggle_player_pair(enabled: bool) -> void:
	player_pair_payout_enabled = enabled
	_emit_and_save()
	print("💰 Player Pair payout: %s" % ("ON" if enabled else "OFF"))

# ← Переключить выплату для пары банкира
func toggle_banker_pair(enabled: bool) -> void:
	banker_pair_payout_enabled = enabled
	_emit_and_save()
	print("💰 Banker Pair payout: %s" % ("ON" if enabled else "OFF"))

# ← Проверить, активна ли выплата для позиции
func is_payout_enabled(winner: String) -> bool:
	match winner:
		"Player":
			return player_payout_enabled
		"Banker":
			return banker_payout_enabled
		"Tie":
			return tie_payout_enabled
		"PairPlayer":
			return player_pair_payout_enabled
		"PairBanker":
			return banker_pair_payout_enabled
		_:
			push_warning("PayoutSettingsManager: неизвестная позиция '%s'" % winner)
			return false

# ← Получить список активных позиций
func get_active_positions() -> Array[String]:
	var active: Array[String] = []
	if player_payout_enabled:
		active.append("Player")
	if banker_payout_enabled:
		active.append("Banker")
	if tie_payout_enabled:
		active.append("Tie")
	return active

# ← Проверить, есть ли хотя бы одна активная ставка
func has_any_active_bet() -> bool:
	return player_payout_enabled or banker_payout_enabled or tie_payout_enabled

# ← Установить все значения разом (для загрузки из SaveManager)
func set_all(player: bool, banker: bool, tie: bool, player_pair: bool = true, banker_pair: bool = true) -> void:
	player_payout_enabled = player
	banker_payout_enabled = banker
	tie_payout_enabled = tie
	player_pair_payout_enabled = player_pair
	banker_pair_payout_enabled = banker_pair
	payout_settings_changed.emit(player_payout_enabled, banker_payout_enabled, tie_payout_enabled, player_pair_payout_enabled, banker_pair_payout_enabled)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _load_settings() -> void:
	var settings = SaveManager.load_payout_settings()
	player_payout_enabled = settings.get("player", true)
	banker_payout_enabled = settings.get("banker", true)
	tie_payout_enabled = settings.get("tie", true)
	player_pair_payout_enabled = settings.get("player_pair", true)
	banker_pair_payout_enabled = settings.get("banker_pair", true)
	
	# Загружаем режим позиций фишек
	position_mode = SaveManager.load_position_mode() as PositionMode
	
	print("💰 PayoutSettingsManager загружен: Player=%s Banker=%s Tie=%s PlayerPair=%s BankerPair=%s PositionMode=%s" % [
		player_payout_enabled, banker_payout_enabled, tie_payout_enabled, player_pair_payout_enabled, banker_pair_payout_enabled, PositionMode.keys()[position_mode]
	])

# ← Вспомогательный метод для emit и сохранения
func _emit_and_save() -> void:
	payout_settings_changed.emit(player_payout_enabled, banker_payout_enabled, tie_payout_enabled, player_pair_payout_enabled, banker_pair_payout_enabled)
	SaveManager.save_payout_settings(player_payout_enabled, banker_payout_enabled, tie_payout_enabled, player_pair_payout_enabled, banker_pair_payout_enabled)

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ ПОЗИЦИЙ ФИШЕК (DEFAULT / RANDOM / MAX)
# ═══════════════════════════════════════════════════════════════════════════

# ← Установить режим позиций
func set_position_mode(mode: PositionMode) -> void:
	position_mode = mode
	SaveManager.save_position_mode(mode)
	random_positions_changed.emit(mode == PositionMode.RANDOM)
	EventBus.position_mode_changed.emit(mode)
	print("🎲 Position mode: %s" % PositionMode.keys()[mode])

# ← Получить текущий режим
func get_position_mode() -> PositionMode:
	return position_mode

# ← Проверить, включён ли режим случайных позиций (для обратной совместимости)
func is_random_positions_enabled() -> bool:
	return position_mode == PositionMode.RANDOM

# ← Проверить, включён ли MAX режим
func is_max_mode_enabled() -> bool:
	return position_mode == PositionMode.MAX

# ← Проверить, включён ли REALISTIC режим
func is_realistic_mode_enabled() -> bool:
	return position_mode == PositionMode.REALISTIC

# ← Переключить режим случайных позиций (для обратной совместимости)
func toggle_random_positions(enabled: bool) -> void:
	if enabled:
		set_position_mode(PositionMode.RANDOM)
	else:
		set_position_mode(PositionMode.DEFAULT)
