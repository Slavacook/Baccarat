# res://scripts/health_system/HeartState.gd
# Enum состояний сердца для State Pattern

class_name HeartState
extends RefCounted

## Состояния сердца
enum State {
	FULL,        # Полное сердце (обычное состояние)
	EMPTY,       # Пустое сердце (потеряно)
	PLEDGED,     # В залоге (для Heart Bet)
	PROTECTED,   # Защищённое (будущее расширение)
	DAMAGED      # Повреждённое (будущее расширение)
}
