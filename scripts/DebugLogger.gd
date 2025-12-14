# res://scripts/DebugLogger.gd
# Система условного логирования для отладки
# Использование: DebugLogger.log("Сообщение"), DebugLogger.warn("Предупреждение")
class_name DebugLogger
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

## Включить/выключить логирование (false = production, true = debug)
const ENABLE_LOGGING: bool = false

## Категории логирования (можно включать отдельно)
const LOG_GAME_FLOW: bool = false      # 🎮 Игровой процесс
const LOG_INITIALIZATION: bool = false  # ✅ Инициализация
const LOG_ERRORS: bool = true          # ❌ Ошибки (всегда включены)
const LOG_STATE_RESTORE: bool = false  # ♻️ Восстановление состояния
const LOG_PAYOUTS: bool = false        # 💰 Выплаты
const LOG_BETS: bool = false           # 🎲 Ставки

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Базовое логирование
static func log(message: String) -> void:
	if ENABLE_LOGGING:
		print(message)

## Логирование игрового процесса (🎮)
static func log_game_flow(message: String) -> void:
	if ENABLE_LOGGING and LOG_GAME_FLOW:
		print("🎮 %s" % message)

## Логирование инициализации (✅)
static func log_init(message: String) -> void:
	if ENABLE_LOGGING and LOG_INITIALIZATION:
		print("✅ %s" % message)

## Логирование ошибок (❌) - всегда активно
static func log_error(message: String) -> void:
	if LOG_ERRORS:
		push_error("❌ %s" % message)

## Логирование предупреждений (⚠️)
static func log_warning(message: String) -> void:
	if ENABLE_LOGGING:
		push_warning("⚠️ %s" % message)

## Логирование восстановления состояния (♻️)
static func log_restore(message: String) -> void:
	if ENABLE_LOGGING and LOG_STATE_RESTORE:
		print("♻️ %s" % message)

## Логирование выплат (💰)
static func log_payout(message: String) -> void:
	if ENABLE_LOGGING and LOG_PAYOUTS:
		print("💰 %s" % message)

## Логирование ставок (🎲)
static func log_bet(message: String) -> void:
	if ENABLE_LOGGING and LOG_BETS:
		print("🎲 %s" % message)

## Логирование с разделителем (для больших блоков)
static func log_separator(message: String = "") -> void:
	if ENABLE_LOGGING:
		print("=".repeat(50))
		if message != "":
			print(message)
			print("=".repeat(50))

## Условное логирование (только если condition = true)
static func log_if(condition: bool, message: String) -> void:
	if ENABLE_LOGGING and condition:
		print(message)
