# res://scripts/CameraInterpolationNode.gd
# Узел для обработки экспоненциального сглаживания камеры в _process

extends Node

var camera_manager: CameraManager = null

func setup(manager: CameraManager) -> void:
	camera_manager = manager
	set_process(false)  # Начинаем с выключенным, включается при старте интерполяции

func _process(delta: float) -> void:
	if camera_manager:
		camera_manager._process_interpolation(delta)

