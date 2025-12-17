# res://scripts/OverlayNotification.gd
# Компонент для показа больших overlay-уведомлений
extends CanvasLayer

@onready var background = $Background
@onready var message_label = %MessageLabel

enum NotificationType {
	SUCCESS,  # Зелёный (правильная выплата, победа)
	ERROR,    # Красный (ошибка выплаты, неправильный ответ)
	INFO,     # Синий (потеря жизни, game over)
}

var _animation_tween: Tween


func _ready():
	hide()


## Показать overlay-уведомление
## text: текст сообщения
## type: тип уведомления (SUCCESS/ERROR/INFO)
## duration: длительность показа в секундах (по умолчанию 1.0)
func show_message(text: String, type: NotificationType = NotificationType.SUCCESS, duration: float = 1.0):
	print("🎬 OverlayNotification.show_message: '%s', type=%d, duration=%.1f" % [text, type, duration])

	# Отменяем предыдущую анимацию если есть
	if _animation_tween:
		_animation_tween.kill()

	# Настраиваем текст и цвет
	message_label.text = text
	_apply_style(type)

	# Показываем overlay
	show()
	background.modulate.a = 0.0
	message_label.modulate.a = 0.0

	# Анимация появления → пауза → исчезновения
	_animation_tween = create_tween()
	# Привязываем tween к SceneTree чтобы он не прерывался при изменениях сцены
	_animation_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_animation_tween.set_parallel(true)

	# Fade in (0.3 сек)
	_animation_tween.tween_property(background, "modulate:a", 0.7, 0.3)
	_animation_tween.tween_property(message_label, "modulate:a", 1.0, 0.3)

	_animation_tween.set_parallel(false)

	# Пауза (duration) - используем полную длительность
	print("🎬 Оверлей: пауза %.1f секунд" % duration)
	_animation_tween.tween_interval(duration)

	_animation_tween.set_parallel(true)

	# Fade out (0.3 сек)
	_animation_tween.tween_property(background, "modulate:a", 0.0, 0.3)
	_animation_tween.tween_property(message_label, "modulate:a", 0.0, 0.3)

	# Скрываем после анимации
	_animation_tween.tween_callback(hide)


## Применить стиль в зависимости от типа уведомления
func _apply_style(type: NotificationType):
	var color: Color
	var font_size: int = 96  # Большой шрифт

	match type:
		NotificationType.SUCCESS:
			color = Color(0.2, 0.9, 0.2)  # Зелёный
		NotificationType.ERROR:
			color = Color(0.9, 0.2, 0.2)  # Красный
		NotificationType.INFO:
			color = Color(0.3, 0.6, 0.9)  # Синий

	message_label.add_theme_font_size_override("font_size", font_size)
	message_label.add_theme_color_override("font_color", color)
