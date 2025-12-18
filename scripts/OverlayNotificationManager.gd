# res://scripts/OverlayNotificationManager.gd
# Autoload singleton для управления overlay-уведомлениями
# НОВАЯ АРХИТЕКТУРА: создаём новый overlay для каждого показа
# Каждый overlay живёт своей жизнью и удаляется сам после завершения
extends Node

const OverlayNotificationScene = preload("res://scenes/OverlayNotification.tscn")

# Текущий активный overlay (если есть)
# Используется только для перебивания предыдущего overlay
var _current_overlay: CanvasLayer = null


func _ready():
	# Подписываемся на сигналы EventBus
	EventBus.show_overlay_success.connect(_on_show_overlay_success)
	EventBus.show_overlay_error.connect(_on_show_overlay_error)
	EventBus.show_overlay_info.connect(_on_show_overlay_info)

	print("✅ OverlayNotificationManager инициализирован (новая архитектура: создание заново)")


## Показать успешное уведомление (зелёный)
func show_success(text: String, duration: float = 1.0):
	_create_and_show_overlay(text, 0, duration)  # 0 = SUCCESS


## Показать ошибку (красный)
func show_error(text: String, duration: float = 2.0):
	_create_and_show_overlay(text, 1, duration)  # 1 = ERROR


## Показать информацию (синий)
func show_info(text: String, duration: float = 1.5):
	_create_and_show_overlay(text, 2, duration)  # 2 = INFO


## Создать новый overlay и показать сообщение
## НОВАЯ АРХИТЕКТУРА: каждый overlay создаётся заново и удаляется сам
## type: 0 = SUCCESS, 1 = ERROR, 2 = INFO (соответствует enum NotificationType)
func _create_and_show_overlay(text: String, type: int, duration: float):
	# ═══════════════════════════════════════════════════════════════════
	# ОЧИСТКА: Проверяем и очищаем ссылку на предыдущий overlay (если удалён)
	# ═══════════════════════════════════════════════════════════════════
	if _current_overlay and not is_instance_valid(_current_overlay):
		_current_overlay = null  # Очищаем ссылку если overlay уже удалён
	
	# ═══════════════════════════════════════════════════════════════════
	# ПЕРЕБИВАНИЕ: Если есть активный overlay - убиваем его tween и удаляем
	# ═══════════════════════════════════════════════════════════════════
	if _current_overlay and is_instance_valid(_current_overlay):
		_current_overlay.force_hide()
		_current_overlay.queue_free()  # Удаляем старый overlay
		_current_overlay = null
		print("🎬 Предыдущий overlay удалён (перебит новым)")
	
	# ═══════════════════════════════════════════════════════════════════
	# СОЗДАНИЕ: Создаём НОВЫЙ overlay для этого показа
	# ═══════════════════════════════════════════════════════════════════
	var new_overlay = OverlayNotificationScene.instantiate()
	
	# ═══════════════════════════════════════════════════════════════════
	# КРИТИЧНО: Добавляем в get_tree().root, а не в текущую сцену!
	# Это гарантирует независимость от сброса раунда.
	# ═══════════════════════════════════════════════════════════════════
	get_tree().root.add_child(new_overlay)
	
	# Сохраняем ссылку для возможного перебивания
	_current_overlay = new_overlay
	
	# Показываем сообщение
	new_overlay.show_message(text, type, duration)
	
	# ═══════════════════════════════════════════════════════════════════
	# АВТООЧИСТКА: Overlay сам удалит себя после завершения анимации
	# через callback в _on_animation_finished()
	# ═══════════════════════════════════════════════════════════════════
	print("🎬 Создан новый OverlayNotification (устойчив к сбросам, автоудаление)")


## Принудительно скрыть текущий overlay (только для экстренных случаев)
## Обычно overlay должен завершаться сам через анимацию.
## Используйте только при Game Over или смене сцены.
func force_hide() -> void:
	"""Принудительно скрыть текущий overlay, даже если он активно показывается"""
	if _current_overlay and is_instance_valid(_current_overlay):
		_current_overlay.force_hide()
		_current_overlay.queue_free()
		_current_overlay = null


# ═══════════════════════════════════════════════════════════════════════════
# EventBus обработчики
# ═══════════════════════════════════════════════════════════════════════════

func _on_show_overlay_success(text: String, duration: float):
	print("🎬 OverlayManager: SUCCESS - '%s' (%.1fs)" % [text, duration])
	show_success(text, duration)


func _on_show_overlay_error(text: String, duration: float):
	print("🎬 OverlayManager: ERROR - '%s' (%.1fs)" % [text, duration])
	show_error(text, duration)


func _on_show_overlay_info(text: String, duration: float):
	print("🎬 OverlayManager: INFO - '%s' (%.1fs)" % [text, duration])
	show_info(text, duration)
