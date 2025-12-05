# res://scripts/GameModeManager.gd
# Глобальный синглтон для управления режимами игры
extends Node

signal mode_changed(mode: String)

enum Mode { JUNKET, CLASSIC }

var current_mode: Mode = Mode.CLASSIC  # ← По умолчанию Classic

# Конфигурация Junket режима
const JUNKET_CONFIG = {
	"main_min": 2000,
	"main_max": 200000,
	"main_step": 500,
	"tie_min": 100,
	"tie_max": 900,
	"tie_step": 25,
	"pairs_min": 100,
	"pairs_max": 15000,
	"pairs_step": 100,
	"banker_commission": 0.95,  # 5% комиссия = 95% выплата
	"chip_denominations": [50000, 25000, 10000, 5000, 1000, 500, 100, 25]
}

# Конфигурация Classic режима
const CLASSIC_CONFIG = {
	"main_min": 50,
	"main_max": 3000,
	"main_step": 1,
	"tie_min": 25,
	"tie_max": 300,
	"tie_step": 1,
	"pairs_min": 25,
	"pairs_max": 900,
	"pairs_step": 1,
	"banker_commission": 1.0,  # ← 100% выплата (1:1), но 50% если банкир выигрывает с 6
	"chip_denominations": [5000, 1000, 500, 100, 25, 5, 1, 0.5]
}

func get_mode_string() -> String:
	return "junket" if current_mode == Mode.JUNKET else "classic"

func set_mode(mode: String):
	if mode == "junket":
		current_mode = Mode.JUNKET
	else:
		current_mode = Mode.CLASSIC
	mode_changed.emit(mode)
	SaveManager.save_game_mode(mode)

func get_config() -> Dictionary:
	if current_mode == Mode.JUNKET:
		return JUNKET_CONFIG
	else:
		return CLASSIC_CONFIG

func get_banker_commission() -> float:
	return get_config()["banker_commission"]

func get_chip_denominations() -> Array:
	return get_config()["chip_denominations"]

func load_saved_mode():
	var saved_mode = SaveManager.load_game_mode()
	if saved_mode:
		set_mode(saved_mode)
