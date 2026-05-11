extends GutTest

var session_manager
var _snapshot: Dictionary = {}


func before_each():
	session_manager = get_node("/root/SessionManager")
	_snapshot = {
		"current_mode": session_manager.current_mode,
		"tournament_settings": session_manager.tournament_settings.duplicate(true),
		"tournament_max_rounds": session_manager.tournament_max_rounds,
		"tournament_attempt_duration_seconds": session_manager.tournament_attempt_duration_seconds,
		"tournament_errors_total": session_manager.tournament_errors_total,
		"tournament_attempt_finished": session_manager.tournament_attempt_finished,
	}


func after_each():
	session_manager.tournament_settings = (_snapshot.get("tournament_settings", {}) as Dictionary).duplicate(true)
	session_manager.current_mode = int(_snapshot.get("current_mode", session_manager.Mode.OFFLINE))
	session_manager.tournament_max_rounds = int(_snapshot.get("tournament_max_rounds", 0))
	session_manager.tournament_attempt_duration_seconds = int(_snapshot.get("tournament_attempt_duration_seconds", 0))
	session_manager.tournament_errors_total = int(_snapshot.get("tournament_errors_total", 0))
	session_manager.tournament_attempt_finished = bool(_snapshot.get("tournament_attempt_finished", false))
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


func test_mark_tournament_error_emits_error_count_signal():
	session_manager.current_mode = session_manager.Mode.TOURNAMENT
	session_manager.tournament_attempt_finished = false
	session_manager.tournament_errors_total = 0

	var state := {"emitted_total": -1}
	session_manager.tournament_error_count_changed.connect(func(total_errors: int):
		state["emitted_total"] = total_errors
	, CONNECT_ONE_SHOT)

	session_manager.mark_tournament_error()

	assert_eq(session_manager.tournament_errors_total, 1)
	assert_eq(state.get("emitted_total"), 1)
