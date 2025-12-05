# res://scripts/SaveManager.gd
extends Node

static var instance: SaveManager

signal score_game_over()  # ← Сигнал когда очки упали ниже 0

const SAVE_PATH = "user://baccarat_stats.save"
const SETTINGS_PATH = "user://baccarat_settings.save"

var total: int = 0
var correct: int = 0
var errors: Dictionary = {}
var score: int = 10  # ← Очки (начальное значение 10)

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
		file.store_var({"total": total, "correct": correct, "errors": errors, "score": score})
		file.close()

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary:
				total = data.get("total", 0)
				correct = data.get("correct", 0)
				errors = data.get("errors", {})
				score = data.get("score", 10)  # ← По умолчанию 10 очков

func get_data() -> Dictionary:
	return {"total": total, "correct": correct, "errors": errors, "score": score}

func increment_total():
	total += 1
	save_data()

func increment_correct():
	correct += 1
	save_data()

func increment_error(type: String):
	errors[type] = errors.get(type, 0) + 1
	save_data()

func reset_stats():
	total = 0
	correct = 0
	errors = {}
	score = 10  # ← Начальный счёт при сбросе
	save_data()

# ← Управление очками
func add_score(points: int):
	score += points
	save_data()

func subtract_score(points: int) -> bool:
	score -= points
	save_data()

	# ← Проверка Game Over (очки < 0)
	if score < 0:
		score_game_over.emit()
		return true  # Game Over
	return false  # Продолжаем игру

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
	return {"game_mode": "junket", "survival_mode": false}  # По умолчанию

func save_game_mode(mode: String):
	var settings = load_settings()
	settings["game_mode"] = mode
	save_settings(settings)

func load_game_mode() -> String:
	var settings = load_settings()
	return settings.get("game_mode", "junket")

func save_survival_mode(enabled: bool):
	var settings = load_settings()
	settings["survival_mode"] = enabled
	save_settings(settings)

func load_survival_mode() -> bool:
	var settings = load_settings()
	return settings.get("survival_mode", false)

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
