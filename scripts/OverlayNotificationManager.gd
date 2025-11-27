# res://scripts/OverlayNotificationManager.gd
# Autoload singleton для управления overlay-уведомлениями
extends Node

const OverlayNotificationScene = preload("res://scenes/OverlayNotification.tscn")

var _overlay_instance: CanvasLayer = null


func _ready():
	# Подписываемся на сигналы EventBus
	EventBus.show_overlay_success.connect(_on_show_overlay_success)
	EventBus.show_overlay_error.connect(_on_show_overlay_error)
	EventBus.show_overlay_info.connect(_on_show_overlay_info)

	print("✅ OverlayNotificationManager инициализирован")


## Показать успешное уведомление (зелёный)
func show_success(text: String, duration: float = 1.0):
	_ensure_instance()
	_overlay_instance.show_message(text, _overlay_instance.NotificationType.SUCCESS, duration)


## Показать ошибку (красный)
func show_error(text: String, duration: float = 2.0):
	_ensure_instance()
	_overlay_instance.show_message(text, _overlay_instance.NotificationType.ERROR, duration)


## Показать информацию (синий)
func show_info(text: String, duration: float = 1.5):
	_ensure_instance()
	_overlay_instance.show_message(text, _overlay_instance.NotificationType.INFO, duration)


## Создать инстанс overlay если его ещё нет
func _ensure_instance():
	if not _overlay_instance:
		_overlay_instance = OverlayNotificationScene.instantiate()
		get_tree().root.add_child(_overlay_instance)


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
