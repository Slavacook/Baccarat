# res://scripts/health_system/Heart.gd
# Абстрактный класс одного сердца

class_name Heart
extends RefCounted

## Текущее состояние сердца
var state: HeartState.State = HeartState.State.FULL

## Сигнал изменения состояния
signal state_changed(new_state: HeartState.State)

## Установить новое состояние
func set_state(new_state: HeartState.State) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(new_state)

## Получить текущее состояние
func get_state() -> HeartState.State:
	return state

## Проверить, является ли сердце полным
func is_full() -> bool:
	return state == HeartState.State.FULL

## Проверить, является ли сердце пустым
func is_empty() -> bool:
	return state == HeartState.State.EMPTY

## Проверить, находится ли сердце в залоге
func is_pledged() -> bool:
	return state == HeartState.State.PLEDGED
