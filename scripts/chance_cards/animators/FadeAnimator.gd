# res://scripts/chance_cards/animators/FadeAnimator.gd
# Аниматор: простое появление/исчезновение (fade in/out)
# Без масштабирования, только прозрачность

class_name FadeAnimator
extends BaseCardAnimator

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕОПРЕДЕЛЕНИЕ ВИРТУАЛЬНЫХ МЕТОДОВ
# ═══════════════════════════════════════════════════════════════════════════

func prepare_for_open(card_texture: TextureRect, background: ColorRect) -> void:
	"""Подготовить карту: полностью прозрачная, нормальный масштаб"""
	# Карта начинает полностью прозрачной, но в нормальном размере
	card_texture.scale = target_scale
	card_texture.modulate = Color(1, 1, 1, 0)
	
	# Фон начинает прозрачным
	background.modulate.a = 0.0

func animate_open(card_texture: TextureRect, _background: ColorRect) -> void:
	"""Анимация открытия: простое появление"""
	# Создаём твин для карты
	var tween = _create_tween(card_texture)
	
	# Анимация прозрачности карты
	tween.tween_property(card_texture, "modulate", target_modulate, OPEN_DURATION) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)
	
	# Анимация фона делается в BaseChanceCardScene напрямую

func animate_close(card_texture: TextureRect, background: ColorRect, on_complete: Callable = Callable()) -> void:
	"""Анимация закрытия: простое исчезновение"""
	# Создаём твин для карты
	var tween = _create_tween(card_texture)
	
	# Анимация прозрачности карты
	tween.tween_property(card_texture, "modulate:a", 0.0, CLOSE_DURATION) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_SINE)
	
	# Анимация исчезновения фона
	tween.tween_property(background, "modulate:a", 0.0, CLOSE_DURATION)
	
	# Подключаем callback
	_connect_on_complete(tween, on_complete)

