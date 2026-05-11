extends GutTest

var session_manager
var _snapshot: Dictionary = {}


func before_each():
	session_manager = get_node("/root/SessionManager")
	_snapshot = {
		"tournament_settings": session_manager.tournament_settings.duplicate(true),
		"tournament_max_rounds": session_manager.tournament_max_rounds,
		"tournament_attempt_duration_seconds": session_manager.tournament_attempt_duration_seconds,
	}


func after_each():
	session_manager.tournament_settings = (_snapshot.get("tournament_settings", {}) as Dictionary).duplicate(true)
	session_manager.tournament_max_rounds = int(_snapshot.get("tournament_max_rounds", 0))
	session_manager.tournament_attempt_duration_seconds = int(_snapshot.get("tournament_attempt_duration_seconds", 0))
	_snapshot.clear()
	session_manager = null


func test_normalizes_new_tournament_finish_settings():
	session_manager.tournament_settings = {
		"finish_preset": "rounds_errors",
		"max_rounds": 12,
		"max_errors": 3,
		"max_duration_minutes": null,
	}
	session_manager.tournament_max_rounds = 50
	session_manager.tournament_attempt_duration_seconds = 600

	var result: Dictionary = session_manager.get_normalized_tournament_finish_settings()

	assert_eq(result.get("finish_preset"), "rounds_errors")
	assert_eq(result.get("max_rounds"), 12)
	assert_eq(result.get("max_errors"), 3)
	assert_eq(result.get("max_duration_seconds"), null)
	assert_eq(result.get("active_limits"), ["round_limit", "error_limit"])
	assert_eq(result.get("source"), "tournament_settings")


func test_falls_back_to_legacy_finish_settings():
	session_manager.tournament_settings = {}
	session_manager.tournament_max_rounds = 25
	session_manager.tournament_attempt_duration_seconds = 900

	var result: Dictionary = session_manager.get_normalized_tournament_finish_settings()

	assert_eq(result.get("finish_preset"), "rounds_time")
	assert_eq(result.get("max_rounds"), 25)
	assert_eq(result.get("max_errors"), null)
	assert_eq(result.get("max_duration_seconds"), 900)
	assert_eq(result.get("active_limits"), ["round_limit", "time_limit"])
	assert_eq(result.get("source"), "legacy_top_level")


func test_invalid_new_finish_settings_fall_back_to_legacy():
	session_manager.tournament_settings = {
		"finish_preset": "rounds_errors",
		"max_rounds": null,
		"max_errors": 2,
		"max_duration_minutes": null,
	}
	session_manager.tournament_max_rounds = 40
	session_manager.tournament_attempt_duration_seconds = 0

	var result: Dictionary = session_manager.get_normalized_tournament_finish_settings()

	assert_eq(result.get("finish_preset"), "rounds_errors")
	assert_eq(result.get("max_rounds"), 40)
	assert_eq(result.get("max_errors"), null)
	assert_eq(result.get("max_duration_seconds"), null)
	assert_eq(result.get("active_limits"), ["round_limit"])
	assert_eq(result.get("source"), "legacy_top_level")
