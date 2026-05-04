## Локальное хранилище tournament activation.
## Хранится отдельно от DealerAccessStore, чтобы не смешивать room и tournament flow.
extends Node

const STORE_PATH := "user://tournament_accesses.json"

var _records: Array[Dictionary] = []
var _loaded := false


func _ready() -> void:
	_ensure_loaded()


func save_access(activation_response: Dictionary) -> Dictionary:
	_ensure_loaded()
	var normalized := _normalize_access(activation_response)
	if normalized.is_empty():
		return {}

	var tournament: Dictionary = normalized.get("tournament", {}) as Dictionary
	var tournament_id := str(tournament.get("id", "")).strip_edges()
	var existing_index := _find_index_by_tournament_id(tournament_id)
	if existing_index >= 0:
		_records[existing_index] = normalized
	else:
		_records.append(normalized)

	if not _save_store():
		return {}

	return normalized.duplicate(true)


func get_all_accesses() -> Array:
	_ensure_loaded()
	var result: Array = []
	for record in _records:
		result.append(record.duplicate(true))
	return result


func get_access_by_tournament_id(tournament_id: String) -> Dictionary:
	_ensure_loaded()
	var normalized_id := tournament_id.strip_edges()
	if normalized_id.is_empty():
		return {}

	var index := _find_index_by_tournament_id(normalized_id)
	if index < 0:
		return {}

	return _records[index].duplicate(true)


func remove_access(tournament_id: String) -> void:
	_ensure_loaded()
	var normalized_id := tournament_id.strip_edges()
	if normalized_id.is_empty():
		return

	var index := _find_index_by_tournament_id(normalized_id)
	if index < 0:
		return

	_records.remove_at(index)
	_save_store()


func clear() -> void:
	_ensure_loaded()
	_records.clear()
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


func _ensure_loaded() -> void:
	if _loaded:
		return
	_load_store()
	_loaded = true


func _load_store() -> void:
	_records.clear()

	if not FileAccess.file_exists(STORE_PATH):
		return

	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		push_warning("TournamentAccessStore: не удалось открыть файл хранилища.")
		return

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Array):
		push_warning("TournamentAccessStore: поврежденный JSON, хранилище сброшено в памяти.")
		return

	for item in parsed:
		if item is Dictionary:
			var normalized := _normalize_access(item)
			if not normalized.is_empty():
				var tournament: Dictionary = normalized.get("tournament", {}) as Dictionary
				var tournament_id := str(tournament.get("id", "")).strip_edges()
				if tournament_id != "":
					var existing_index := _find_index_by_tournament_id(tournament_id)
					if existing_index >= 0:
						_records[existing_index] = normalized
					else:
						_records.append(normalized)


func _save_store() -> bool:
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("TournamentAccessStore: не удалось сохранить файл хранилища.")
		return false

	file.store_string(JSON.stringify(_records))
	file.close()
	return true


func _normalize_access(source: Dictionary) -> Dictionary:
	var participant_token := str(source.get("participant_token", "")).strip_edges()
	var token_type := str(source.get("token_type", "Participant")).strip_edges()

	var tournament_variant: Variant = source.get("tournament", {})
	var participant_variant: Variant = source.get("participant", {})
	if participant_token.is_empty() or not (tournament_variant is Dictionary) or not (participant_variant is Dictionary):
		return {}

	var tournament_source := tournament_variant as Dictionary
	var participant_source := participant_variant as Dictionary
	var tournament_settings: Dictionary = {}
	if tournament_source.has("tournament_settings") and tournament_source["tournament_settings"] is Dictionary:
		tournament_settings = (tournament_source["tournament_settings"] as Dictionary).duplicate(true)

	var tournament_id := str(tournament_source.get("id", "")).strip_edges()
	var participant_id := str(participant_source.get("id", "")).strip_edges()
	var participant_name := str(participant_source.get("display_name", "")).strip_edges()
	if tournament_id.is_empty() or participant_id.is_empty() or participant_name.is_empty():
		return {}

	var tournament: Dictionary = {
		"id": tournament_id,
		"title": str(tournament_source.get("title", "")).strip_edges(),
		"code": str(tournament_source.get("code", "")).strip_edges(),
		"status": str(tournament_source.get("status", "")).strip_edges(),
		"max_rounds": int(tournament_source.get("max_rounds", 0)),
		"attempt_duration_seconds": int(tournament_source.get("attempt_duration_seconds", 0)),
		"tournament_settings": tournament_settings,
	}

	var participant: Dictionary = {
		"id": participant_id,
		"display_name": participant_name
	}

	return {
		"participant_token": participant_token,
		"token_type": token_type if token_type != "" else "Participant",
		"tournament": tournament,
		"participant": participant,
		"saved_at": int(Time.get_unix_time_from_system())
	}


func _find_index_by_tournament_id(tournament_id: String) -> int:
	for i in range(_records.size()):
		var record_tournament: Variant = _records[i].get("tournament", {})
		if record_tournament is Dictionary:
			if str((record_tournament as Dictionary).get("id", "")).strip_edges() == tournament_id:
				return i
	return -1
