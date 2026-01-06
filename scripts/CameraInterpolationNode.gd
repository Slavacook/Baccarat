# res://scripts/CameraInterpolationNode.gd
# Узел для обработки экспоненциального сглаживания камеры в _process

extends Node

var camera_manager: CameraManager = null
var interpolation_handler: RefCounted = null  # CameraInterpolationHandler

func setup(manager: CameraManager) -> void:
	"""Старый метод для обратной совместимости"""
	camera_manager = manager
	set_process(false)  # Начинаем с выключенным, включается при старте интерполяции

func setup_interpolation_handler(handler: RefCounted) -> void:
	"""Новый метод для использования CameraInterpolationHandler"""
	interpolation_handler = handler
	set_process(false)  # Начинаем с выключенным, включается при старте интерполяции

func _process(delta: float) -> void:
	# Приоритет: используем interpolation_handler если доступен, иначе старый способ
	if interpolation_handler and interpolation_handler.has_method("process_interpolation"):
		interpolation_handler.process_interpolation(delta)
	elif camera_manager:
		camera_manager._process_interpolation(delta)

