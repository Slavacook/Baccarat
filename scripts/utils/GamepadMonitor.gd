# res://scripts/utils/GamepadMonitor.gd
# ═══════════════════════════════════════════════════════════════════════════
# МОНИТОР ГЕЙМПАДОВ
# 
# Отвечает за:
# - Проверку подключения геймпадов
# - Логирование изменений подключения
# ═══════════════════════════════════════════════════════════════════════════

class_name GamepadMonitor
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ
# ═══════════════════════════════════════════════════════════════════════════

var last_check_time: int = 0
var last_connected_count: int = 0
var check_interval: int = 5000  # 5 секунд

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func check_connection() -> void:
	"""Проверить подключение геймпадов и вывести информацию"""
	var connected_joypads = Input.get_connected_joypads()
	
	if connected_joypads.size() > 0:
		DebugLogger.log("🎮 Подключено геймпадов: %d" % connected_joypads.size())
		for device_id in connected_joypads:
			var joypad_name = Input.get_joy_name(device_id)
			DebugLogger.log("🎮 Геймпад %d: %s" % [device_id, joypad_name])
	
	# Инициализируем состояние
	last_check_time = Time.get_ticks_msec()
	last_connected_count = connected_joypads.size()

func process(_delta: float) -> void:
	"""Проверка изменения подключения геймпадов (только при изменении)
	
	Args:
		delta: Время с последнего кадра
	"""
	var current_time = Time.get_ticks_msec()
	
	if current_time - last_check_time > check_interval:
		last_check_time = current_time
		
		var connected = Input.get_connected_joypads()
		
		# Логируем только при изменении количества подключенных геймпадов
		if connected.size() != last_connected_count:
			last_connected_count = connected.size()
			DebugLogger.log("🎮 Изменение подключения геймпадов: найдено устройств = %d (было %d)" % [connected.size(), last_connected_count])
			
			if connected.size() > 0:
				for device_id in connected:
					var joypad_name = Input.get_joy_name(device_id)
					DebugLogger.log("🎮 Геймпад подключен: device_id=%d, name=%s" % [device_id, joypad_name])
