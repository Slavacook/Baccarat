# scripts/utils/AnalyticsHelper.gd
# Хелпер для интеграции аналитики (Google Analytics, Яндекс.Метрика)

extends RefCounted
class_name AnalyticsHelper

## Отслеживание события
static func track_event(event_name: String, parameters: Dictionary = {}) -> void:
	"""Отправить событие в аналитику"""
	if not OS.has_feature("HTML5") or Engine.is_editor_hint():
		return
	
	# Используем JavaScriptBridge для доступа к JavaScript
	var js_bridge = Engine.get_singleton("JavaScriptBridge")
	if not js_bridge:
		return
	
	# Проверяем наличие gtag (Google Analytics)
	var script = """
	(function() {
		if (typeof gtag !== 'undefined') {
			gtag('event', '%s', %s);
		}
	})();
	""" % [event_name, JSON.stringify(parameters)]
	
	js_bridge.eval(script)

## Отслеживание начала сессии
static func track_session_start() -> void:
	"""Отследить начало сессии"""
	track_event("session_start", {
		"timestamp": Time.get_unix_time_from_system()
	})

## Отслеживание времени в игре
static func track_game_time(seconds: int) -> void:
	"""Отследить время, проведённое в игре"""
	track_event("game_time", {
		"duration_seconds": seconds,
		"duration_minutes": seconds / 60
	})

## Отслеживание действия пользователя
static func track_user_action(action: String, details: Dictionary = {}) -> void:
	"""Отследить действие пользователя"""
	var params = details.duplicate()
	params["action"] = action
	track_event("user_action", params)
