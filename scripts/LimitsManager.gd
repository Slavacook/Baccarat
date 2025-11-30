# res://scripts/LimitsManager.gd
class_name LimitsManager
extends RefCounted

signal limits_changed(
	min_bet: int, max_bet: int, step: int,
	tie_min: int, tie_max: int, tie_step: int
)

var config: GameConfig

# Основные лимиты
var min_bet: int
var max_bet: int
var step: int

# TIE лимиты
var tie_min: int
var tie_max: int
var tie_step: int

# Шансы берутся из BetProfileManager (удалено хардкод)

func _init(conf: GameConfig):
	config = conf
	# ← Инициализация без эмита сигнала
	set_limits(
		conf.table_min_bet, conf.table_max_bet, conf.table_step,
		conf.tie_min_bet, conf.tie_max_bet, conf.tie_step,
		false  # silent = true, не эмитим сигнал при инициализации
	)

func set_limits(new_min: int, new_max: int, new_step: int, new_tie_min: int, new_tie_max: int, new_tie_step: int, should_emit_signal: bool = true):
	min_bet = new_min
	max_bet = new_max
	step = new_step
	tie_min = new_tie_min
	tie_max = new_tie_max
	tie_step = new_tie_step

	config.table_min_bet = new_min
	config.table_max_bet = new_max
	config.table_step = new_step
	config.tie_min_bet = new_tie_min
	config.tie_max_bet = new_tie_max
	config.tie_step = new_tie_step

	# ← Эмитим сигнал только если should_emit_signal = true (реальная смена лимитов)
	if should_emit_signal:
		limits_changed.emit(new_min, new_max, new_step, new_tie_min, new_tie_max, new_tie_step)

# ═══════════════════════════════════════════════════════════════════════════
# ГЕНЕРАЦИЯ СТАВОК С ФИКСИРОВАННЫМИ ДИАПАЗОНАМИ
# ═══════════════════════════════════════════════════════════════════════════

# --- Генерация случайной ставки из фиксированных диапазонов ---
# ranges: [[min, max, chance%], [min, max, chance%], ...]
# step_value: шаг ставок (1 для Classic, 500 для Junket)
func _generate_from_ranges(ranges: Array, step_value: int) -> int:
	# Выбираем категорию по шансам
	var total_chance: float = 0.0
	for range_data in ranges:
		total_chance += range_data[2]  # chance%

	var r: float = randf() * total_chance
	var accumulated: float = 0.0

	for range_data in ranges:
		var min_val = range_data[0]
		var max_val = range_data[1]
		var chance = range_data[2]

		accumulated += chance
		if r <= accumulated:
			# Нормализуем min и max к ближайшим значениям, кратным step_value
			var min_normalized = int(ceil(float(min_val) / step_value)) * step_value
			var max_normalized = int(floor(float(max_val) / step_value)) * step_value

			# Проверка: если диапазон слишком узкий
			if max_normalized < min_normalized:
				return min_normalized

			# Количество возможных ставок в диапазоне
			var steps_count = int((max_normalized - min_normalized) / float(step_value)) + 1
			var random_step = randi() % steps_count
			var bet = min_normalized + (random_step * step_value)

			return bet

	# Fallback (не должно сюда попасть)
	return int(ceil(float(ranges[0][0]) / step_value)) * step_value

# --- Основные ставки (Player/Banker) ---
func generate_bet() -> int:
	var mode = GameModeManager.get_mode_string()  # "classic" или "junket"
	var ranges = BetProfileManager.get_ranges(mode, "main")
	return _generate_from_ranges(ranges, step)

# --- Ставки на TIE (игалите) ---
func generate_tie_bet() -> int:
	var mode = GameModeManager.get_mode_string()  # "classic" или "junket"
	var ranges = BetProfileManager.get_ranges(mode, "tie")
	return _generate_from_ranges(ranges, tie_step)
