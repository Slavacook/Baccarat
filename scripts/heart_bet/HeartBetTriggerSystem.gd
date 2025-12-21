# res://scripts/heart_bet/HeartBetTriggerSystem.gd
# Система триггеров для "Ставки сердцем"
# Управляет регистрацией и проверкой триггеров

class_name HeartBetTriggerSystem
extends RefCounted

## Список зарегистрированных триггеров
var triggers: Array[HeartBetBaseTrigger] = []


func _init():
	_register_default_triggers()


## Зарегистрировать стандартные триггеры
func _register_default_triggers() -> void:
	# УБРАЛИ ВСЕ ТРИГГЕРЫ - теперь карты шансов управляются через
	# _check_chance_card_triggers в GamePhaseManager:
	# - Heart Card: победа банкира с 6 → heart_card_triggered
	# - Heart Bet Card: Tie → heart_bet_card_triggered
	# - Mystery Card: натуральная победа → mystery_card_triggered
	# - Revolver Card: две пары → revolver_card_triggered
	# - Third Card Change: все 6 картинки → third_card_change_triggered
	
	# triggers.append(BankerSixTrigger.new())  # Заменён на Heart Card триггер
	# triggers.append(NaturalWinTrigger.new())  # Заменён на Mystery Card триггер
	
	print("🎰 HeartBetTriggerSystem: триггеры отключены (управление через _check_chance_card_triggers)")


## Проверить все триггеры
## Возвращает первый сработавший триггер или null
func check_all(winner: String, banker_score: int, player_score: int, is_natural: bool) -> HeartBetBaseTrigger:
	for trigger in triggers:
		if trigger.is_enabled() and trigger.check(winner, banker_score, player_score, is_natural):
			print("🎰 Триггер '%s' сработал!" % trigger.get_trigger_name())
			return trigger
	return null


## Получить триггер по имени
func get_trigger(trigger_name: String) -> HeartBetBaseTrigger:
	for trigger in triggers:
		if trigger.get_trigger_name() == trigger_name:
			return trigger
	return null


## Включить триггер по имени
func enable_trigger(trigger_name: String) -> bool:
	var trigger = get_trigger(trigger_name)
	if trigger:
		trigger.enable()
		print("🎰 Триггер '%s' включён" % trigger_name)
		return true
	return false


## Отключить триггер по имени
func disable_trigger(trigger_name: String) -> bool:
	var trigger = get_trigger(trigger_name)
	if trigger:
		trigger.disable()
		print("🎰 Триггер '%s' отключён" % trigger_name)
		return true
	return false


## Проверить, включён ли триггер
func is_trigger_enabled(trigger_name: String) -> bool:
	var trigger = get_trigger(trigger_name)
	return trigger != null and trigger.is_enabled()


## Получить список всех триггеров
func get_all_triggers() -> Array[HeartBetBaseTrigger]:
	return triggers


## Получить список включённых триггеров
func get_enabled_triggers() -> Array[HeartBetBaseTrigger]:
	var enabled_triggers: Array[HeartBetBaseTrigger] = []
	for trigger in triggers:
		if trigger.is_enabled():
			enabled_triggers.append(trigger)
	return enabled_triggers


## Добавить новый триггер
func register_trigger(trigger: HeartBetBaseTrigger) -> void:
	if trigger and not triggers.has(trigger):
		triggers.append(trigger)
		print("🎰 Триггер '%s' зарегистрирован" % trigger.get_trigger_name())


## Удалить триггер
func unregister_trigger(trigger_name: String) -> bool:
	var trigger = get_trigger(trigger_name)
	if trigger:
		triggers.erase(trigger)
		print("🎰 Триггер '%s' удалён" % trigger_name)
		return true
	return false
