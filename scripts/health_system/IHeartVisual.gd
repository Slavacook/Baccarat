# res://scripts/health_system/IHeartVisual.gd
# Интерфейс для визуализации сердец

class_name IHeartVisual
extends RefCounted

## Обновить визуальное отображение сердца
## Args:
##   state: Новое состояние сердца
func update_visual(_state: HeartState.State) -> void:
	assert(false, "IHeartVisual.update_visual() must be overridden")

## Получить узел сцены (для доступа к TextureRect/Label и т.д.)
func get_node() -> Node:
	assert(false, "IHeartVisual.get_node() must be overridden")
	return null
