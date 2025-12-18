# res://scripts/OverlayNotification.gd
# Компонент для показа больших overlay-уведомлений
# НОВАЯ АРХИТЕКТУРА: каждый overlay создаётся заново и удаляется сам
# УСТОЙЧИВЫЙ К СБРОСАМ: работает независимо от состояния игры
extends CanvasLayer

@onready var background = $Background
@onready var message_label = %MessageLabel

enum NotificationType {
	SUCCESS,  # Зелёный (правильная выплата, победа)
	ERROR,    # Красный (ошибка выплаты, неправильный ответ)
	INFO,     # Синий (потеря жизни, game over)
}

var _animation_tween: Tween
var _is_showing: bool = false  # Флаг активного показа


func _ready():
	hide()
	# ═══════════════════════════════════════════════════════════════════
	# ВАЖНО: Overlay должен быть на самом верхнем слое и не зависеть от сцены
	# layer = 200 установлен в сцене, это самый высокий приоритет
	# ═══════════════════════════════════════════════════════════════════


## Показать overlay-уведомление
## text: текст сообщения
## type: тип уведомления (SUCCESS/ERROR/INFO)
## duration: длительность показа в секундах (по умолчанию 1.0)
##
## НОВАЯ АРХИТЕКТУРА: Каждый overlay создаётся заново для каждого показа.
## После завершения анимации overlay удаляет себя через queue_free().
## Это гарантирует полную независимость от сброса раунда.
func show_message(text: String, type: NotificationType = NotificationType.SUCCESS, duration: float = 1.0):
	print("🎬 OverlayNotification.show_message: '%s', type=%d, duration=%.1f" % [text, type, duration])

	# Отменяем предыдущую анимацию если есть (только другой overlay может перебить)
	if _animation_tween:
		_animation_tween.kill()
		_animation_tween = null

	# Настраиваем текст и цвет
	message_label.text = text
	_apply_style(type)

	# Показываем overlay и устанавливаем флаг
	show()
	_is_showing = true
	background.modulate.a = 0.0
	message_label.modulate.a = 0.0

	# ═══════════════════════════════════════════════════════════════════
	# КРИТИЧНО: Используем get_tree().create_tween() вместо create_tween()
	# Это создаёт tween на уровне SceneTree, а не на узле.
	# Такой tween НЕ прерывается при сбросе раунда или изменении сцены!
	# ═══════════════════════════════════════════════════════════════════
	_animation_tween = get_tree().create_tween()
	_animation_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_animation_tween.set_parallel(true)

	# Fade in (0.3 сек)
	_animation_tween.tween_property(background, "modulate:a", 0.7, 0.3)
	_animation_tween.tween_property(message_label, "modulate:a", 1.0, 0.3)

	_animation_tween.set_parallel(false)

	# Пауза (duration) - используем полную длительность
	# ВАЖНО: Эта пауза НЕ прервётся при сбросе раунда!
	print("🎬 Оверлей: пауза %.1f секунд (устойчив к сбросам)" % duration)
	_animation_tween.tween_interval(duration)

	_animation_tween.set_parallel(true)

	# Fade out (0.3 сек)
	_animation_tween.tween_property(background, "modulate:a", 0.0, 0.3)
	_animation_tween.tween_property(message_label, "modulate:a", 0.0, 0.3)

	# Скрываем после анимации и сбрасываем флаг
	_animation_tween.tween_callback(_on_animation_finished)


## Завершение анимации (автоудаление)
func _on_animation_finished() -> void:
	"""Скрыть overlay после завершения анимации и удалить себя"""
	_is_showing = false
	visible = false  # Используем visible напрямую вместо hide()
	_animation_tween = null
	
	# ═══════════════════════════════════════════════════════════════════
	# АВТОУДАЛЕНИЕ: Overlay удаляет себя после завершения анимации
	# Это гарантирует, что каждый overlay живёт своей жизнью
	# и не накапливается в памяти
	# ═══════════════════════════════════════════════════════════════════
	print("🎬 Overlay завершён, удаляю себя (queue_free)")
	queue_free()  # Удаляем себя после завершения


## Безопасное скрытие (с проверкой флага)
## Используйте этот метод вместо hide() для защиты от прерывания
func safe_hide() -> void:
	"""Безопасное скрытие overlay (игнорирует принудительные вызовы во время показа)
	
	ВАЖНО: Во время активного показа overlay НЕ скрывается принудительно.
	Это защищает от прерывания при сбросе раунда.
	Для принудительного скрытия используйте force_hide().
	"""
	# Если overlay активно показывается - НЕ скрываем принудительно
	# Только завершение анимации может скрыть overlay
	if _is_showing:
		print("🎬 Overlay защищён от скрытия (активно показывается)")
		return
	
	# Обычное скрытие (когда не показывается)
	visible = false


## Принудительное скрытие (для экстренных случаев, например Game Over)
func force_hide() -> void:
	"""Принудительно скрыть overlay, даже если он активно показывается
	
	Используется только в экстренных случаях (Game Over, смена сцены).
	В обычной игре overlay должен завершаться сам через анимацию.
	"""
	if _animation_tween:
		_animation_tween.kill()
		_animation_tween = null
	_is_showing = false
	visible = false  # Используем visible напрямую
	print("🎬 Overlay принудительно скрыт (force_hide)")


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
