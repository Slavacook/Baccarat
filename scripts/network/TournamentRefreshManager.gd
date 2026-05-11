## Фоновое обновление локально сохранённых турниров.
## Живёт как autoload и не зависит от экранов.
extends Node

const APIClientScript = preload("res://scripts/network/APIClient.gd")
const TournamentAccessStoreScript = preload("res://scripts/network/TournamentAccessStore.gd")
const REFRESH_ALL_COOLDOWN_MS := 5 * 60 * 1000

signal tournament_refresh_completed(code: String, success: bool)
signal refresh_all_started()
signal refresh_all_completed(success_count: int, failed_count: int)

var _api_client: APIClient = null
var _tournament_access_store: Node = null
var _refresh_all_in_progress: bool = false
var _code_refresh_state: Dictionary = {}
var _last_public_tournament_bodies: Dictionary = {}
var _startup_refresh_allowed: bool = true
var _request_in_progress: bool = false
var _request_in_progress_code: String = ""
var _last_refresh_all_finished_ms: int = 0


func _ready() -> void:
	_setup_access_store()
	_setup_api_client()
	_schedule_startup_refresh.call_deferred()


func _exit_tree() -> void:
	_startup_refresh_allowed = false
	_refresh_all_in_progress = false
	_request_in_progress = false
	_request_in_progress_code = ""
	if _api_client != null and _api_client.has_method("cancel_active_request"):
		_api_client.call("cancel_active_request")


func refresh_all_saved_accesses_best_effort() -> void:
	if _refresh_all_in_progress:
		return
	var now_ms := Time.get_ticks_msec()
	if _last_refresh_all_finished_ms > 0 and now_ms - _last_refresh_all_finished_ms < REFRESH_ALL_COOLDOWN_MS:
		return
	_refresh_all_in_progress = true
	refresh_all_started.emit()
	_run_refresh_all.call_deferred()


func refresh_tournament_if_needed(code: String) -> void:
	var normalized_code := code.strip_edges()
	if normalized_code.is_empty():
		return
	if is_refresh_in_progress_for(normalized_code):
		return
	_mark_code_refresh_started(normalized_code)
	_run_single_refresh.call_deferred(normalized_code)


func _schedule_startup_refresh() -> void:
	for _step in range(6):
		if not _startup_refresh_allowed or not is_inside_tree():
			return
		await get_tree().process_frame
	if not _startup_refresh_allowed or not is_inside_tree():
		return
	refresh_all_saved_accesses_best_effort()


func is_refresh_in_progress_for(code: String) -> bool:
	var normalized_code := code.strip_edges()
	if normalized_code.is_empty():
		return false
	var state: Dictionary = _state_for_code(normalized_code)
	return bool(state.get("in_progress", false))


func is_refresh_all_in_progress() -> bool:
	return _refresh_all_in_progress


func get_last_public_tournament_body(code: String) -> Dictionary:
	var normalized_code := code.strip_edges()
	if normalized_code.is_empty():
		return {}
	if not _last_public_tournament_bodies.has(normalized_code):
		return {}
	var body_variant: Variant = _last_public_tournament_bodies[normalized_code]
	if body_variant is Dictionary:
		return (body_variant as Dictionary).duplicate(true)
	return {}


func _run_refresh_all() -> void:
	var success_count := 0
	var failed_count := 0
	var batch_started_ms := Time.get_ticks_msec()

	if _tournament_access_store == null or _api_client == null:
		_refresh_all_in_progress = false
		_last_refresh_all_finished_ms = Time.get_ticks_msec()
		refresh_all_completed.emit(success_count, failed_count)
		return

	_reload_access_store_from_disk()
	var accesses_variant: Variant = _tournament_access_store.call("get_all_accesses")
	if accesses_variant is Array:
		for item in accesses_variant:
			if not (item is Dictionary):
				continue

			var access_record := (item as Dictionary).duplicate(true)
			var code := _extract_code_from_access_record(access_record)
			if code.is_empty():
				continue

			var success := false
			if _was_code_refreshed_after(code, batch_started_ms):
				success = _last_refresh_success(code)
			elif is_refresh_in_progress_for(code):
				success = await _wait_for_refresh_completion(code)
			else:
				success = await _refresh_access_record(access_record, code)

			if success:
				success_count += 1
			else:
				failed_count += 1

	_refresh_all_in_progress = false
	_last_refresh_all_finished_ms = Time.get_ticks_msec()
	refresh_all_completed.emit(success_count, failed_count)


func _run_single_refresh(code: String) -> void:
	await _refresh_tournament_by_code(code)


func _refresh_tournament_by_code(code: String) -> bool:
	var access_record := _find_access_record_by_code(code)
	if access_record.is_empty():
		print("🏁 TournamentRefreshManager: access_record не найден для кода %s, refresh завершён без HTTP" % code)
		_mark_code_refresh_finished(code, false)
		tournament_refresh_completed.emit(code, false)
		return false
	return await _refresh_access_record(access_record, code)


func _refresh_access_record(access_record: Dictionary, code: String) -> bool:
	_mark_code_refresh_started(code)
	print("🌐 TournamentRefreshManager: старт HTTP refresh для турнира %s" % code)

	var result: Dictionary = await _get_public_tournament(code)
	var status_code := int(result.get("code", 0))
	var body_variant: Variant = result.get("body", {})
	var success := false

	if status_code >= 200 and status_code < 300 and body_variant is Dictionary:
		var body_dict := body_variant as Dictionary
		var tournament_data := _extract_tournament_dictionary(body_dict)
		if not tournament_data.is_empty():
			var merged_variant: Variant = _tournament_access_store.call(
				"merge_public_tournament_data",
				access_record,
				tournament_data
			)
			if merged_variant is Dictionary:
				var merged_record := merged_variant as Dictionary
				if not merged_record.is_empty():
					var saved_variant: Variant = _tournament_access_store.call("save_access", merged_record)
					if saved_variant is Dictionary and not (saved_variant as Dictionary).is_empty():
						_last_public_tournament_bodies[code] = body_dict.duplicate(true)
						success = true

	_mark_code_refresh_finished(code, success)
	tournament_refresh_completed.emit(code, success)
	return success


func _get_public_tournament(code: String) -> Dictionary:
	if _api_client == null:
		return {"code": 0, "body": {}}
	if code.strip_edges().is_empty():
		return {"code": 0, "body": {}}
	await _wait_for_request_slot(code)
	if not is_inside_tree():
		_release_request_slot(code)
		return {"code": 0, "body": {}}

	var request_state: Dictionary = {
		"finished": false,
		"packet": {"code": 0, "body": {}}
	}

	_api_client.request_completed.connect(
		func(_request_id: int, response_code: int, body: Variant) -> void:
			request_state["finished"] = true
			request_state["packet"] = {"code": response_code, "body": body},
		CONNECT_ONE_SHOT
	)
	_api_client.request_failed.connect(
		func(_request_id: int, error_code: int, error_message: String) -> void:
			request_state["finished"] = true
			request_state["packet"] = {
				"code": 0,
				"body": {
					"error_code": error_code,
					"detail": error_message,
				}
			},
		CONNECT_ONE_SHOT
	)

	_api_client.get_public_request("/api/tournaments/public/%s" % code.uri_encode())

	while not bool(request_state.get("finished", false)) and is_inside_tree():
		await get_tree().process_frame

	_release_request_slot(code)

	var packet_variant: Variant = request_state.get("packet", {"code": 0, "body": {}})
	if packet_variant is Dictionary:
		return packet_variant as Dictionary
	return {"code": 0, "body": {}}


func _wait_for_refresh_completion(code: String) -> bool:
	var normalized_code := code.strip_edges()
	if normalized_code.is_empty():
		return false
	if not is_refresh_in_progress_for(normalized_code):
		return _last_refresh_success(normalized_code)

	while is_refresh_in_progress_for(normalized_code):
		var signal_data: Array = await tournament_refresh_completed
		if signal_data.size() >= 2 and str(signal_data[0]).strip_edges() == normalized_code:
			return bool(signal_data[1])

	return _last_refresh_success(normalized_code)


func _extract_tournament_dictionary(body: Dictionary) -> Dictionary:
	for key in ["tournament", "data", "item"]:
		if body.has(key) and body[key] is Dictionary:
			var candidate: Dictionary = body[key] as Dictionary
			if candidate.has("title") or candidate.has("status") or candidate.has("max_rounds"):
				return candidate
	return body


func _find_access_record_by_code(code: String) -> Dictionary:
	if _tournament_access_store == null:
		return {}

	_reload_access_store_from_disk()
	var normalized_code := code.strip_edges()
	if normalized_code.is_empty():
		return {}

	var accesses_variant: Variant = _tournament_access_store.call("get_all_accesses")
	if not (accesses_variant is Array):
		return {}

	for item in accesses_variant:
		if not (item is Dictionary):
			continue
		var access_record := item as Dictionary
		if _extract_code_from_access_record(access_record) == normalized_code:
			print("🏁 TournamentRefreshManager: найден access_record для кода %s" % normalized_code)
			return access_record.duplicate(true)

	print("🏁 TournamentRefreshManager: access_record для кода %s не найден после reload_from_disk()" % normalized_code)
	return {}


func _extract_code_from_access_record(access_record: Dictionary) -> String:
	if access_record.has("tournament") and access_record["tournament"] is Dictionary:
		return str((access_record["tournament"] as Dictionary).get("code", "")).strip_edges()
	return ""


func _setup_access_store() -> void:
	_tournament_access_store = TournamentAccessStoreScript.new()
	_tournament_access_store.name = "TournamentAccessStore_Internal"
	add_child(_tournament_access_store)


func _reload_access_store_from_disk() -> void:
	if _tournament_access_store == null:
		return
	if _tournament_access_store.has_method("reload_from_disk"):
		print("♻️ TournamentRefreshManager: reload TournamentAccessStore перед поиском/refresh")
		_tournament_access_store.call("reload_from_disk")


func _setup_api_client() -> void:
	_api_client = APIClientScript.new()
	_api_client.name = "TournamentRefreshAPIClient"
	add_child(_api_client)

	var api_service = _find_api_service()
	if api_service != null and api_service.api_client != null:
		_api_client.base_url = str(api_service.api_client.base_url)


func _find_api_service():
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService")
	return get_node_or_null("/root/ApiService")


func _state_for_code(code: String) -> Dictionary:
	if _code_refresh_state.has(code) and _code_refresh_state[code] is Dictionary:
		return _code_refresh_state[code] as Dictionary
	return {}


func _mark_code_refresh_started(code: String) -> void:
	_code_refresh_state[code] = {
		"in_progress": true,
		"last_success": _last_refresh_success(code),
		"last_finished_ms": _last_finished_ms(code)
	}


func _mark_code_refresh_finished(code: String, success: bool) -> void:
	_code_refresh_state[code] = {
		"in_progress": false,
		"last_success": success,
		"last_finished_ms": Time.get_ticks_msec()
	}


func _last_refresh_success(code: String) -> bool:
	var state: Dictionary = _state_for_code(code)
	return bool(state.get("last_success", false))


func _last_finished_ms(code: String) -> int:
	var state: Dictionary = _state_for_code(code)
	return int(state.get("last_finished_ms", 0))


func _was_code_refreshed_after(code: String, started_ms: int) -> bool:
	return _last_finished_ms(code) >= started_ms


func _wait_for_request_slot(code: String) -> void:
	while _request_in_progress and is_inside_tree():
		await get_tree().process_frame

	_request_in_progress = true
	_request_in_progress_code = code


func _release_request_slot(code: String) -> void:
	if not _request_in_progress:
		return
	if _request_in_progress_code != code:
		return
	_request_in_progress = false
	_request_in_progress_code = ""
