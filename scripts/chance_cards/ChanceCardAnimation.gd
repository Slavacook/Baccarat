# res://scripts/chance_cards/ChanceCardAnimation.gd
# Отдельный файл для анимации открытия/закрытия карты шанса
# 
# ⚠️ ВАЖНО: Чтобы отключить анимацию, просто закомментируйте вызовы методов
# в BaseChanceCardScene.gd или установите USE_ANIMATION = false

class_name ChanceCardAnimation
extends RefCounted

## Включить/выключить анимацию (можно изменить на false для отключения)
const USE_ANIMATION: bool = true

## Длительность анимации открытия (секунды)
const OPEN_DURATION: float = 0.4

## Длительность анимации закрытия (секунды)
const CLOSE_DURATION: float = 0.2

## Тип анимации открытия
enum OpenType {
	SCALE_FROM_ZERO,      # Карта появляется с масштаба 0
	SCALE_FROM_STORAGE,   # Карта "вылетает" из позиции миниатюры
	FADE_IN               # Простое появление с прозрачности
}

## Тип анимации закрытия
enum CloseType {
	SCALE_TO_ZERO,        # Карта уменьшается до 0
	SCALE_TO_STORAGE,     # Карта "улетает" к миниатюре
	FADE_OUT              # Простое исчезновение
}

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИЯ ОТКРЫТИЯ
# ═══════════════════════════════════════════════════════════════════════════

## Анимировать открытие карты
## card_texture: TextureRect карты
## background: ColorRect фона
## open_type: тип анимации (по умолчанию SCALE_FROM_ZERO)
## storage_pos: позиция миниатюры (для SCALE_FROM_STORAGE)
static func animate_open(
	card_texture: TextureRect,
	background: ColorRect,
	open_type: OpenType = OpenType.SCALE_FROM_ZERO,
	storage_pos: Vector2 = Vector2.ZERO
) -> void:
	if not USE_ANIMATION:
		return
	
	if not card_texture or not background:
		push_warning("ChanceCardAnimation: нет card_texture или background")
		return
	
	# Сохраняем исходные значения
	var original_scale = card_texture.scale
	var original_modulate = card_texture.modulate
	var original_bg_modulate = background.modulate
	
	match open_type:
		OpenType.SCALE_FROM_ZERO:
			_animate_scale_from_zero(card_texture, background, original_scale, original_modulate, original_bg_modulate)
		
		OpenType.SCALE_FROM_STORAGE:
			_animate_scale_from_storage(card_texture, background, storage_pos, original_scale, original_modulate, original_bg_modulate)
		
		OpenType.FADE_IN:
			_animate_fade_in(card_texture, background, original_modulate, original_bg_modulate)

## Анимация: масштаб от 0 до 1
static func _animate_scale_from_zero(
	card_texture: TextureRect,
	background: ColorRect,
	original_scale: Vector2,
	original_modulate: Color,
	original_bg_modulate: Color
) -> void:
	# Устанавливаем pivot_offset в центр карты для масштабирования из центра
	# pivot_offset работает в локальных координатах (от левого верхнего угла)
	var card_size = card_texture.size
	if card_size == Vector2.ZERO:
		# Если размер ещё не установлен, вычисляем из offset
		var width = card_texture.offset_right - card_texture.offset_left
		var height = card_texture.offset_bottom - card_texture.offset_top
		card_texture.pivot_offset = Vector2(width / 2.0, height / 2.0)
	else:
		card_texture.pivot_offset = card_size / 2.0
	
	# Начальное состояние
	card_texture.scale = Vector2.ZERO
	card_texture.modulate = Color(1, 1, 1, 0)
	background.modulate = Color(1, 1, 1, 0)
	
	# Создаём твин
	var tween = card_texture.get_tree().create_tween()
	tween.set_parallel(true)
	
	# Анимация масштаба карты (с эффектом "отскока")
	tween.tween_property(card_texture, "scale", original_scale, OPEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Анимация прозрачности карты
	tween.tween_property(card_texture, "modulate", original_modulate, OPEN_DURATION * 0.6)
	
	# Анимация фона
	tween.tween_property(background, "modulate", original_bg_modulate, OPEN_DURATION * 0.4)

## Анимация: карта "вылетает" из позиции миниатюры
static func _animate_scale_from_storage(
	card_texture: TextureRect,
	background: ColorRect,
	storage_pos: Vector2,
	original_scale: Vector2,
	original_modulate: Color,
	original_bg_modulate: Color
) -> void:
	if storage_pos == Vector2.ZERO:
		# Если позиция не указана, используем простую анимацию
		_animate_scale_from_zero(card_texture, background, original_scale, original_modulate, original_bg_modulate)
		return
	
	# Получаем текущую позицию карты (в глобальных координатах)
	var viewport = card_texture.get_viewport()
	var viewport_rect = viewport.get_visible_rect()
	var card_center_global = card_texture.get_global_rect().get_center()
	
	# Начальное состояние: карта в позиции миниатюры, маленькая
	card_texture.scale = Vector2(0.1, 0.1)
	card_texture.modulate = original_modulate
	background.modulate = Color(1, 1, 1, 0)
	
	# Вычисляем смещение для анимации
	var start_pos = storage_pos
	var end_pos = card_center_global
	var offset = start_pos - end_pos
	
	# Временно устанавливаем позицию
	var original_position = card_texture.position
	card_texture.position = original_position + offset
	
	# Создаём твин
	var tween = card_texture.get_tree().create_tween()
	tween.set_parallel(true)
	
	# Анимация позиции
	tween.tween_property(card_texture, "position", original_position, OPEN_DURATION)
	
	# Анимация масштаба
	tween.tween_property(card_texture, "scale", original_scale, OPEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Анимация фона
	tween.tween_property(background, "modulate", original_bg_modulate, OPEN_DURATION * 0.4)

## Анимация: простое появление (fade in)
static func _animate_fade_in(
	card_texture: TextureRect,
	background: ColorRect,
	original_modulate: Color,
	original_bg_modulate: Color
) -> void:
	# Начальное состояние
	card_texture.modulate = Color(1, 1, 1, 0)
	background.modulate = Color(1, 1, 1, 0)
	
	# Создаём твин
	var tween = card_texture.get_tree().create_tween()
	tween.set_parallel(true)
	
	# Анимация прозрачности
	tween.tween_property(card_texture, "modulate", original_modulate, OPEN_DURATION)
	tween.tween_property(background, "modulate", original_bg_modulate, OPEN_DURATION * 0.6)

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИЯ ЗАКРЫТИЯ
# ═══════════════════════════════════════════════════════════════════════════

## Анимировать закрытие карты
## card_texture: TextureRect карты
## background: ColorRect фона
## close_type: тип анимации (по умолчанию SCALE_TO_ZERO)
## storage_pos: позиция миниатюры (для SCALE_TO_STORAGE)
## on_complete: функция обратного вызова после завершения
static func animate_close(
	card_texture: TextureRect,
	background: ColorRect,
	close_type: CloseType = CloseType.SCALE_TO_ZERO,
	storage_pos: Vector2 = Vector2.ZERO,
	on_complete: Callable = Callable()
) -> void:
	if not USE_ANIMATION:
		if on_complete.is_valid():
			on_complete.call()
		return
	
	if not card_texture or not background:
		push_warning("ChanceCardAnimation: нет card_texture или background")
		if on_complete.is_valid():
			on_complete.call()
		return
	
	# Сохраняем исходные значения
	var original_scale = card_texture.scale
	var original_position = card_texture.position
	
	match close_type:
		CloseType.SCALE_TO_ZERO:
			_animate_scale_to_zero(card_texture, background, original_scale, on_complete)
		
		CloseType.SCALE_TO_STORAGE:
			_animate_scale_to_storage(card_texture, background, storage_pos, original_scale, original_position, on_complete)
		
		CloseType.FADE_OUT:
			_animate_fade_out(card_texture, background, on_complete)

## Анимация: масштаб от 1 до 0 (из центра, с эффектом "отскока")
static func _animate_scale_to_zero(
	card_texture: TextureRect,
	background: ColorRect,
	original_scale: Vector2,
	on_complete: Callable
) -> void:
	# Устанавливаем pivot_offset в центр карты для масштабирования из центра
	# (такой же, как при открытии)
	var card_size = card_texture.size
	if card_size == Vector2.ZERO:
		# Если размер ещё не установлен, вычисляем из offset
		var width = card_texture.offset_right - card_texture.offset_left
		var height = card_texture.offset_bottom - card_texture.offset_top
		card_texture.pivot_offset = Vector2(width / 2.0, height / 2.0)
	else:
		card_texture.pivot_offset = card_size / 2.0
	
	# Создаём твин и настраиваем его
	var tween = card_texture.get_tree().create_tween()
	tween.set_parallel(true)
	
	# Анимация масштаба (плавное уменьшение без отскока)
	var scale_tween = tween.tween_property(card_texture, "scale", Vector2.ZERO, CLOSE_DURATION)
	scale_tween.set_ease(Tween.EASE_IN)
	scale_tween.set_trans(Tween.TRANS_QUAD)
	
	# Анимация прозрачности
	tween.tween_property(card_texture, "modulate:a", 0.0, CLOSE_DURATION * 0.7)
	tween.tween_property(background, "modulate:a", 0.0, CLOSE_DURATION * 0.8)
	
	# Вызов callback после завершения анимации
	# Подключаемся к сигналу finished твина
	if on_complete.is_valid():
		var callback_func = func():
			if on_complete.is_valid():
				on_complete.call()
		tween.finished.connect(callback_func, CONNECT_ONE_SHOT)

## Анимация: карта "улетает" к миниатюре
static func _animate_scale_to_storage(
	card_texture: TextureRect,
	background: ColorRect,
	storage_pos: Vector2,
	original_scale: Vector2,
	original_position: Vector2,
	on_complete: Callable
) -> void:
	if storage_pos == Vector2.ZERO:
		# Если позиция не указана, используем простую анимацию
		_animate_scale_to_zero(card_texture, background, original_scale, on_complete)
		return
	
	# Вычисляем конечную позицию
	var card_center_global = card_texture.get_global_rect().get_center()
	var offset = storage_pos - card_center_global
	var target_position = original_position + offset
	
	var tween = card_texture.get_tree().create_tween()
	tween.set_parallel(true)
	
	# Анимация позиции
	tween.tween_property(card_texture, "position", target_position, CLOSE_DURATION)
	
	# Анимация масштаба
	tween.tween_property(card_texture, "scale", Vector2(0.1, 0.1), CLOSE_DURATION).set_ease(Tween.EASE_IN)
	
	# Анимация прозрачности
	tween.tween_property(card_texture, "modulate:a", 0.0, CLOSE_DURATION * 0.7)
	tween.tween_property(background, "modulate:a", 0.0, CLOSE_DURATION * 0.8)
	
	# Вызов callback после завершения анимации
	if on_complete.is_valid():
		var callback_func = func():
			if on_complete.is_valid():
				on_complete.call()
		tween.finished.connect(callback_func, CONNECT_ONE_SHOT)

## Анимация: простое исчезновение (fade out)
static func _animate_fade_out(
	card_texture: TextureRect,
	background: ColorRect,
	on_complete: Callable
) -> void:
	var tween = card_texture.get_tree().create_tween()
	tween.set_parallel(true)
	
	# Анимация прозрачности
	tween.tween_property(card_texture, "modulate:a", 0.0, CLOSE_DURATION)
	tween.tween_property(background, "modulate:a", 0.0, CLOSE_DURATION)
	
	# Вызов callback после завершения анимации
	if on_complete.is_valid():
		var callback_func = func():
			if on_complete.is_valid():
				on_complete.call()
		tween.finished.connect(callback_func, CONNECT_ONE_SHOT)
