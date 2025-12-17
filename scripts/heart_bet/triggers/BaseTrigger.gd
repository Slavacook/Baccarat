# res://scripts/heart_bet/triggers/BaseTrigger.gd
# Базовый класс триггера для системы "Ставка сердцем"
# Все триггеры наследуются от этого класса

class_name HeartBetBaseTrigger
extends RefCounted

## Имя триггера (для идентификации и отладки)
var trigger_name: String = "BaseTrigger"

## Включён ли триггер
var enabled: bool = true

## Описание триггера (для UI настроек)
var description: String = ""


func _init():
	pass


## Проверить, включён ли триггер
func is_enabled() -> bool:
	return enabled


## Включить триггер
func enable() -> void:
	enabled = true


## Отключить триггер
func disable() -> void:
	enabled = false


## Проверить условие триггера
## Возвращает true если условие выполнено
## 
## Args:
##   winner: Победитель раунда ("Player", "Banker", "Tie")
##   banker_score: Очки банкира (0-9)
##   player_score: Очки игрока (0-9)
##   is_natural: Была ли натуральная победа (8 или 9)
func check(_winner: String, _banker_score: int, _player_score: int, _is_natural: bool) -> bool:
	push_error("HeartBetBaseTrigger.check() должен быть переопределён в дочернем классе")
	return false


## Получить имя триггера
func get_trigger_name() -> String:
	return trigger_name


## Получить описание триггера
func get_description() -> String:
	return description
