# res://scripts/ui/PayoutAnimationController.gd
# Контроллер анимаций для PayoutOverlay
# Ответственность: управление анимациями успеха/ошибки, показ/скрытие изображений

class_name PayoutAnimationController
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# UI ЭЛЕМЕНТЫ (ссылки на узлы для анимаций)
# ═══════════════════════════════════════════════════════════════════════════

var success_image: Control
var error_image: Control
var payout_button: Button

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var owner_node: Node  # Узел для создания Tween (обычно сам PayoutOverlay)

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	owner_node_ref: Node,
	success_image_ref: Control,
	error_image_ref: Control,
	payout_button_ref: Button
):
	"""Инициализация контроллера анимаций
	
	Args:
		owner_node_ref: Узел для создания Tween (обычно сам PayoutOverlay)
		success_image_ref: Изображение успеха
		error_image_ref: Изображение ошибки
		payout_button_ref: Кнопка выплаты (для тряски)
	"""
	owner_node = owner_node_ref
	success_image = success_image_ref
	error_image = error_image_ref
	payout_button = payout_button_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - АНИМАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func show_success_animation() -> void:
	"""Показать анимацию успеха (fade in изображения)"""
	_show_success_image()

func hide_success_animation():
	"""Скрыть анимацию успеха (fade out с движением вверх)"""
	await _hide_success_image()

func show_error_animation() -> void:
	"""Показать анимацию ошибки (fade in изображения + тряска кнопки)"""
	_show_error_image()
	_shake_payout_button()

func hide_error_animation():
	"""Скрыть анимацию ошибки (fade out с движением вверх)"""
	await _hide_error_image()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - ПОКАЗ/СКРЫТИЕ ИЗОБРАЖЕНИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _show_success_image():
	"""Показать изображение 'Верно!' с анимацией fade in"""
	if not success_image:
		return
	
	# Сбрасываем состояние перед показом
	success_image.modulate = Color(1, 1, 1, 0.0)  # Начинаем с прозрачного
	success_image.visible = true
	
	# Анимация fade in (без зума)
	var tween: Tween = owner_node.create_tween()
	tween.tween_property(success_image, "modulate:a", 1.0, 0.3)

func _hide_success_image():
	"""Скрыть изображение 'Верно!' с анимацией fade out и движением вверх"""
	if not success_image:
		return
	
	# Сохраняем оригинальную позицию
	var original_position: Vector2 = success_image.position
	
	# Анимация fade out с движением вверх
	var tween: Tween = owner_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(success_image, "modulate:a", 0.0, 0.2)
	tween.tween_property(success_image, "position:y", original_position.y - 30.0, 0.2)
	await tween.finished
	
	# Возвращаем позицию на место
	success_image.position = original_position
	success_image.visible = false

func _show_error_image():
	"""Показать изображение 'Ошибка!' с анимацией fade in"""
	if not error_image:
		return
	
	# Сбрасываем состояние перед показом
	error_image.modulate = Color(1, 1, 1, 0.0)  # Начинаем с прозрачного
	error_image.visible = true
	
	# Анимация fade in (без зума)
	var tween: Tween = owner_node.create_tween()
	tween.tween_property(error_image, "modulate:a", 1.0, 0.3)

func _hide_error_image():
	"""Скрыть изображение 'Ошибка!' с анимацией fade out и движением вверх"""
	if not error_image:
		return
	
	# Сохраняем оригинальную позицию
	var original_position: Vector2 = error_image.position
	
	# Анимация fade out с движением вверх
	var tween: Tween = owner_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(error_image, "modulate:a", 0.0, 0.2)
	tween.tween_property(error_image, "position:y", original_position.y - 30.0, 0.2)
	await tween.finished
	
	# Возвращаем позицию на место
	error_image.position = original_position
	error_image.visible = false

func _shake_payout_button():
	"""Анимация тряски кнопки выплаты"""
	if not payout_button:
		return
	
	var tween: Tween = owner_node.create_tween()
	var original_pos: Vector2 = payout_button.position
	var shake: float = GameConstants.SHAKE_OFFSET
	var dur: float = GameConstants.SHAKE_DURATION
	tween.tween_property(payout_button, "position:x", original_pos.x + shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x - shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x + shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x - shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x, dur)

