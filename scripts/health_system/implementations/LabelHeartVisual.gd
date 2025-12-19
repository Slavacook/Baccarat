# res://scripts/health_system/implementations/LabelHeartVisual.gd
# Реализация визуализации для Label + TextureRect (PayoutSurvivalInfo)

class_name LabelHeartVisual
extends IHeartVisual

## Label с количеством жизней
var lives_label: Label

## TextureRect с иконкой сердца
var heart_icon: TextureRect

## Текстура полного сердца
var heart_full: Texture2D

## Конструктор
## Args:
##   label: Label для отображения количества жизней
##   icon: TextureRect для иконки сердца
##   heart_full_texture: Текстура полного сердца
func _init(
	label: Label,
	icon: TextureRect,
	heart_full_texture: Texture2D
) -> void:
	lives_label = label
	heart_icon = icon
	heart_full = heart_full_texture

## Обновить визуальное отображение
## Args:
##   _state: Новое состояние (для LabelHeartVisual не используется, оставлено для совместимости)
##   lives_count: Количество жизней (0-7)
func update_visual(_state: HeartState.State, lives_count: int = 0) -> void:
	if lives_label:
		lives_label.text = str(clamp(lives_count, 0, 7))
	
	if heart_icon:
		# Иконка всегда показывает полное сердце
		heart_icon.texture = heart_full
		heart_icon.modulate = Color.WHITE

## Получить узел сцены (Label)
func get_node() -> Node:
	if lives_label:
		return lives_label
	return heart_icon if heart_icon else null
