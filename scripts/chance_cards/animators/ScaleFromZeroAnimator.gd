# res://scripts/chance_cards/animators/ScaleFromZeroAnimator.gd
# Аниматор: карта появляется с масштаба 0 до полного размера
# Основной тип анимации для карт шанса

class_name ScaleFromZeroAnimator
extends BaseCardAnimator

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕОПРЕДЕЛЕНИЕ ВИРТУАЛЬНЫХ МЕТОДОВ
# ═══════════════════════════════════════════════════════════════════════════

func prepare_for_open(card_texture: TextureRect, background: ColorRect) -> void:
	"""Подготовить карту: масштаб 0, полностью прозрачная"""
	# Карта начинает с невидимого состояния
	card_texture.scale = Vector2.ZERO
	card_texture.modulate = Color(1, 1, 1, 0)
	
	# Фон начинает прозрачным
	background.modulate.a = 0.0

func animate_open(card_texture: TextureRect, _background: ColorRect) -> void:
	"""Анимация открытия: масштаб от 0 до 1 с эффектом отскока"""
	# Устанавливаем pivot в центр для масштабирования из центра
	_setup_pivot(card_texture)
	
	# Создаём твин для карты
	var tween = _create_tween(card_texture)
	
	# Анимация масштаба карты (с эффектом "отскока")
	tween.tween_property(card_texture, "scale", target_scale, OPEN_DURATION) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	
	# Анимация прозрачности карты (быстрее чем масштаб)
	tween.tween_property(card_texture, "modulate", target_modulate, OPEN_DURATION * 0.6)
	
	# Анимация фона делается в BaseChanceCardScene напрямую

func animate_close(card_texture: TextureRect, background: ColorRect, on_complete: Callable = Callable()) -> void:
	"""Анимация закрытия: масштаб от 1 до 0"""
	# Устанавливаем pivot в центр
	_setup_pivot(card_texture)
	
	# Создаём твин для карты
	var tween = _create_tween(card_texture)
	
	# Анимация масштаба (плавное уменьшение)
	tween.tween_property(card_texture, "scale", Vector2.ZERO, CLOSE_DURATION) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	
	# Анимация прозрачности карты
	tween.tween_property(card_texture, "modulate:a", 0.0, CLOSE_DURATION * 0.7)
	
	# Анимация исчезновения фона
	tween.tween_property(background, "modulate:a", 0.0, CLOSE_DURATION * 0.8)
	
	# Подключаем callback
	_connect_on_complete(tween, on_complete)

