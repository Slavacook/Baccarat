# res://scripts/autoload/PayoutSettingsManager.gd
# Autoload синглтон для управления переключателями выплат
# Определяет, на какие позиции (Player/Banker/Tie) активны ставки

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal payout_settings_changed(player: bool, banker: bool, tie: bool, player_pair: bool, banker_pair: bool)
# signal random_positions_changed(enabled: bool)  # Deprecated - режим всегда GUEST

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var player_payout_enabled: bool = true
var banker_payout_enabled: bool = true
var tie_payout_enabled: bool = true
var player_pair_payout_enabled: bool = true
var banker_pair_payout_enabled: bool = true

# Режим позиций фишек: GUEST (гости ставят в своих секторах)
enum PositionMode { GUEST }
var position_mode: PositionMode = PositionMode.GUEST

# Для обратной совместимости (deprecated, всегда false)
var random_positions_enabled: bool:
	get:
		return false

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
	
	# Режим позиций всегда GUEST (миграция старых настроек)
	position_mode = PositionMode.GUEST
	SaveManager.save_position_mode(PositionMode.GUEST)
	
	print("💰 PayoutSettingsManager загружен: Player=%s Banker=%s Tie=%s PlayerPair=%s BankerPair=%s PositionMode=GUEST" % [
		player_payout_enabled, banker_payout_enabled, tie_payout_enabled, player_pair_payout_enabled, banker_pair_payout_enabled
	])

# ← Вспомогательный метод для emit и сохранения
func _emit_and_save() -> void:
	payout_settings_changed.emit(player_payout_enabled, banker_payout_enabled, tie_payout_enabled, player_pair_payout_enabled, banker_pair_payout_enabled)
	SaveManager.save_payout_settings(player_payout_enabled, banker_payout_enabled, tie_payout_enabled, player_pair_payout_enabled, banker_pair_payout_enabled)

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ ПОЗИЦИЙ ФИШЕК (DEFAULT / RANDOM / MAX)
# ═══════════════════════════════════════════════════════════════════════════

# ← Установить режим позиций (всегда GUEST)
func set_position_mode(_mode: PositionMode) -> void:
	position_mode = PositionMode.GUEST  # Всегда GUEST
	SaveManager.save_position_mode(PositionMode.GUEST)
	EventBus.position_mode_changed.emit(PositionMode.GUEST)
	print("🎲 Position mode: GUEST (гости)")

# ← Получить текущий режим (всегда GUEST)
func get_position_mode() -> PositionMode:
	return PositionMode.GUEST

# ← Проверить, включён ли режим случайных позиций (deprecated, всегда false)
func is_random_positions_enabled() -> bool:
	return false

# ← Проверить, включён ли MAX режим (deprecated, всегда false)
func is_max_mode_enabled() -> bool:
	return false

# ← Проверить, включён ли REALISTIC режим (deprecated, всегда false)
func is_realistic_mode_enabled() -> bool:
	return false

# ← Проверить, включён ли режим гостей
func is_guest_mode_enabled() -> bool:
	return true

# ← Переключить режим случайных позиций (deprecated, ничего не делает)
func toggle_random_positions(_enabled: bool) -> void:
	# Режим всегда GUEST, игнорируем
	pass
