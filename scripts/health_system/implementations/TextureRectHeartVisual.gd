# res://scripts/health_system/implementations/TextureRectHeartVisual.gd
# Реализация визуализации для массива TextureRect (SurvivalModeUI)

class_name TextureRectHeartVisual
extends IHeartVisual

## Массив TextureRect для отображения сердец
var texture_rects: Array[TextureRect] = []

## Текстуры для разных состояний
var heart_full: Texture2D
var heart_empty: Texture2D
var heart_pledged: Texture2D = null

## Индекс текущего сердца (для обновления одного сердца)
var current_index: int = -1

## Конструктор
## Args:
##   texture_rects: Массив TextureRect для отображения
##   heart_full: Текстура полного сердца
##   heart_empty: Текстура пустого сердца
##   heart_pledged: Текстура заложенного сердца (опционально)
func _init(
	texture_rects_array: Array[TextureRect],
	heart_full_texture: Texture2D,
	heart_empty_texture: Texture2D,
	heart_pledged_texture: Texture2D = null
) -> void:
	texture_rects = texture_rects_array
	heart_full = heart_full_texture
	heart_empty = heart_empty_texture
	heart_pledged = heart_pledged_texture

## Обновить визуальное отображение одного сердца
## Args:
##   state: Новое состояние сердца
##   index: Индекс сердца в массиве (если -1, обновляет все)
func update_visual(state: HeartState.State, index: int = -1) -> void:
	var target_index = index if index >= 0 else current_index
	
	if target_index < 0 or target_index >= texture_rects.size():
		return
	
	var texture_rect = texture_rects[target_index]
	
	match state:
		HeartState.State.FULL:
			texture_rect.texture = heart_full
			texture_rect.modulate = Color.WHITE
		HeartState.State.EMPTY:
			texture_rect.texture = heart_empty
			texture_rect.modulate = Color.WHITE
		HeartState.State.PLEDGED:
			if heart_pledged:
				texture_rect.texture = heart_pledged
			else:
				# Заглушка - полупрозрачное сердце с оттенком
				texture_rect.texture = heart_full
				texture_rect.modulate = Color(1.0, 0.7, 0.3, 0.8)  # Оранжевый оттенок
		HeartState.State.PROTECTED:
			# Будущее расширение - пока как FULL
			texture_rect.texture = heart_full
			texture_rect.modulate = Color(0.3, 1.0, 0.3, 1.0)  # Зелёный оттенок
		HeartState.State.DAMAGED:
			# Будущее расширение - пока как EMPTY
			texture_rect.texture = heart_empty
			texture_rect.modulate = Color(1.0, 0.5, 0.5, 1.0)  # Красноватый оттенок

## Обновить все сердца (для синхронизации всего бара)
## Args:
##   full_count: Количество полных сердец
##   pledged_index: Индекс заложенного сердца (-1 если нет)
func update_all_hearts(full_count: int, pledged_index: int = -1) -> void:
	for i in range(texture_rects.size()):
		if i < full_count:
			if i == pledged_index:
				update_visual(HeartState.State.PLEDGED, i)
			else:
				update_visual(HeartState.State.FULL, i)
		else:
			update_visual(HeartState.State.EMPTY, i)

## Установить индекс текущего сердца
func set_current_index(index: int) -> void:
	current_index = index

## Получить узел сцены (первый TextureRect)
func get_node() -> Node:
	if texture_rects.is_empty():
		return null
	return texture_rects[0]
