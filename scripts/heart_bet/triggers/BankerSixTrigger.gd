# res://scripts/heart_bet/triggers/BankerSixTrigger.gd
# Триггер: Победа банкира с 6 очками (Super6)
# Срабатывает когда банкир выигрывает с итоговым счётом 6

class_name BankerSixTrigger
extends HeartBetBaseTrigger


func _init():
	trigger_name = "BankerSix"
	description = "Победа банкира с 6 очками"
	enabled = true  # Включён по умолчанию


## Проверить условие: банкир победил с 6 очками
func check(winner: String, banker_score: int, _player_score: int, _is_natural: bool) -> bool:
	return winner == "Banker" and banker_score == 6
