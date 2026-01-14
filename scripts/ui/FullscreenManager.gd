# scripts/ui/FullscreenManager.gd
# Менеджер для управления полноэкранным режимом в браузере и на десктопе

extends Control
class_name FullscreenManager

## Сигнал изменения состояния полноэкранного режима
signal fullscreen_changed(is_fullscreen: bool)

var is_fullscreen: bool = false
var fullscreen_button: Button = null

func _ready() -> void:
	"""Инициализация менеджера"""
	# Находим кнопку (connection уже настроен в Game.tscn)
	fullscreen_button = get_node_or_null("FullscreenButton")
	
	# Подписка на изменение размера окна
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Проверяем начальное состояние (только в HTML5 экспорте)
	if OS.has_feature("HTML5") and not Engine.is_editor_hint():
		_check_fullscreen_state_html5()

func toggle_fullscreen() -> void:
	"""Переключить полноэкранный режим"""
	if OS.has_feature("HTML5") and not Engine.is_editor_hint():
		# Для HTML5 используем JavaScript API
		_toggle_fullscreen_html5()
	else:
		# Для десктопа используем DisplayServer
		_toggle_fullscreen_desktop()

func _toggle_fullscreen_html5() -> void:
	"""Переключение полноэкранного режима через JavaScript API для HTML5"""
	# Используем JavaScriptBridge для доступа к JavaScript
	var js_bridge = Engine.get_singleton("JavaScriptBridge")
	if not js_bridge:
		return
	
	var script = """
	(function() {
		if (document.fullscreenElement) {
			document.exitFullscreen().catch(function(err) {
				console.log('Fullscreen exit error:', err);
			});
		} else {
			document.documentElement.requestFullscreen().catch(function(err) {
				console.log('Fullscreen request error:', err);
			});
		}
	})();
	"""
	js_bridge.eval(script)

func _toggle_fullscreen_desktop() -> void:
	"""Переключение полноэкранного режима для десктопных платформ"""
	var current_mode = DisplayServer.window_get_mode()
	
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		is_fullscreen = false
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		is_fullscreen = true
	
	fullscreen_changed.emit(is_fullscreen)

func _check_fullscreen_state_html5() -> void:
	"""Проверка текущего состояния полноэкранного режима в HTML5"""
	if not OS.has_feature("HTML5") or Engine.is_editor_hint():
		return
	
	var js_bridge = Engine.get_singleton("JavaScriptBridge")
	if not js_bridge:
		return
	
	var script = "document.fullscreenElement != null"
	var result = js_bridge.eval(script)
	
	if result != null and result != is_fullscreen:
		is_fullscreen = result
		fullscreen_changed.emit(is_fullscreen)

func _on_viewport_size_changed() -> void:
	"""Обновляем состояние при изменении размера окна"""
	if OS.has_feature("HTML5") and not Engine.is_editor_hint():
		# Для HTML5 проверяем состояние через JavaScript
		_check_fullscreen_state_html5()
	else:
		# Для десктопа проверяем через DisplayServer
		var current_mode = DisplayServer.window_get_mode()
		var new_fullscreen = (current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN)
		
		if new_fullscreen != is_fullscreen:
			is_fullscreen = new_fullscreen
			fullscreen_changed.emit(is_fullscreen)
