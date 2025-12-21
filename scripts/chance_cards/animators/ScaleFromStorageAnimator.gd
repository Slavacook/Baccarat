# res://scripts/chance_cards/animators/ScaleFromStorageAnimator.gd
# Аниматор: карта "вылетает" из позиции миниатюры в хранилище
# и "улетает" обратно при закрытии

class_name ScaleFromStorageAnimator
extends BaseCardAnimator

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Исходная позиция карты (для восстановления)
var _original_position: Vector2 = Vector2.ZERO

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕОПРЕДЕЛЕНИЕ ВИРТУАЛЬНЫХ МЕТОДОВ
# ═══════════════════════════════════════════════════════════════════════════

func prepare_for_open(card_texture: TextureRect, background: ColorRect) -> void:
	"""Подготовить карту: маленькая в позиции хранилища"""
	# Сохраняем исходную позицию
	_original_position = card_texture.position
	
	# Если storage_pos не задан, используем fallback на ScaleFromZero
	if storage_pos == Vector2.ZERO:
		card_texture.scale = Vector2.ZERO
		card_texture.modulate = Color(1, 1, 1, 0)
	else:
		# Начинаем маленькими в позиции хранилища
		card_texture.scale = Vector2(0.1, 0.1)
		card_texture.modulate = Color(1, 1, 1, 0.5)
		
		# Вычисляем смещение для позиционирования
		var card_center_global = card_texture.get_global_rect().get_center()
		var offset = storage_pos - card_center_global
		card_texture.position = _original_position + offset
	
	# Фон начинает прозрачным
	background.modulate.a = 0.0

func animate_open(card_texture: TextureRect, _background: ColorRect) -> void:
	"""Анимация открытия: карта вылетает из хранилища"""
	# Если storage_pos не задан, делаем простую анимацию масштаба
	if storage_pos == Vector2.ZERO:
		_animate_simple_scale_open(card_texture)
		return
	
	# Устанавливаем pivot в центр
	_setup_pivot(card_texture)
	
	# Создаём твин
	var tween = _create_tween(card_texture)
	
	# Анимация позиции (возврат к исходной)
	tween.tween_property(card_texture, "position", _original_position, OPEN_DURATION) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_CUBIC)
	
	# Анимация масштаба (с эффектом отскока)
	tween.tween_property(card_texture, "scale", target_scale, OPEN_DURATION) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	
	# Анимация прозрачности карты
	tween.tween_property(card_texture, "modulate", target_modulate, OPEN_DURATION * 0.6)
	
	# Анимация фона делается в BaseChanceCardScene напрямую

func animate_close(card_texture: TextureRect, background: ColorRect, on_complete: Callable = Callable()) -> void:
	"""Анимация закрытия: карта улетает к хранилищу"""
	# Если storage_pos не задан, делаем простую анимацию масштаба
	if storage_pos == Vector2.ZERO:
		_animate_simple_scale_close(card_texture, background, on_complete)
		return
	
	# Устанавливаем pivot в центр
	_setup_pivot(card_texture)
	
	# Вычисляем конечную позицию (к хранилищу)
	var card_center_global = card_texture.get_global_rect().get_center()
	var offset = storage_pos - card_center_global
	var target_position = card_texture.position + offset
	
	# Создаём твин
	var tween = _create_tween(card_texture)
	
	# Анимация позиции (к хранилищу)
	tween.tween_property(card_texture, "position", target_position, CLOSE_DURATION) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_CUBIC)
	
	# Анимация масштаба (уменьшение)
	tween.tween_property(card_texture, "scale", Vector2(0.1, 0.1), CLOSE_DURATION) \
		.set_ease(Tween.EASE_IN)
	
	# Анимация прозрачности карты
	tween.tween_property(card_texture, "modulate:a", 0.0, CLOSE_DURATION * 0.7)
	
	# Анимация исчезновения фона
	tween.tween_property(background, "modulate:a", 0.0, CLOSE_DURATION * 0.8)
	
	# Подключаем callback
	_connect_on_complete(tween, on_complete)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ (fallback анимации)
# ═══════════════════════════════════════════════════════════════════════════

func _animate_simple_scale_open(card_texture: TextureRect) -> void:
	"""Fallback: простая анимация масштаба (как ScaleFromZero)"""
	_setup_pivot(card_texture)
	
	var tween = _create_tween(card_texture)
	
	tween.tween_property(card_texture, "scale", target_scale, OPEN_DURATION) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(card_texture, "modulate", target_modulate, OPEN_DURATION * 0.6)
	
	# Анимация фона делается в BaseChanceCardScene напрямую

func _animate_simple_scale_close(card_texture: TextureRect, background: ColorRect, on_complete: Callable) -> void:
	"""Fallback: простая анимация закрытия (как ScaleToZero)"""
	_setup_pivot(card_texture)
	
	var tween = _create_tween(card_texture)
	
	tween.tween_property(card_texture, "scale", Vector2.ZERO, CLOSE_DURATION) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(card_texture, "modulate:a", 0.0, CLOSE_DURATION * 0.7)
	tween.tween_property(background, "modulate:a", 0.0, CLOSE_DURATION * 0.8)
	
	_connect_on_complete(tween, on_complete)

