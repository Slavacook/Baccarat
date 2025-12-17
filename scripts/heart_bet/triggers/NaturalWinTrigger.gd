# res://scripts/heart_bet/triggers/NaturalWinTrigger.gd
# Триггер: Любая натуральная победа (8 или 9 очков)
# Срабатывает когда кто-то побеждает с натуральной 8 или 9
# Используется для тестирования (настраиваемый)

class_name NaturalWinTrigger
extends HeartBetBaseTrigger


func _init():
	trigger_name = "NaturalWin"
	description = "Натуральная победа (8 или 9)"
	enabled = true  # Включён для тестов, можно отключить в настройках


## Проверить условие: натуральная победа (не ничья)
func check(winner: String, _banker_score: int, _player_score: int, is_natural: bool) -> bool:
	# Натуральная победа Player или Banker (не Tie)
	return is_natural and winner != "Tie"
