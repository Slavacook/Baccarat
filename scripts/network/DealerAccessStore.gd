## Локальное хранилище access-доступов дилера для нового room access flow.
## Источник правды о комнатах и статусах остается на backend.
extends Node

const STORE_PATH := "user://dealer_access_store.json"
const DEFAULT_STATUS := "unknown"

var _records: Array[Dictionary] = []


func _ready() -> void:
	load_store()


func load_store() -> Array[Dictionary]:
	_records.clear()

	if not FileAccess.file_exists(STORE_PATH):
		return get_all()

	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		push_warning("DealerAccessStore: не удалось открыть файл хранилища.")
		return get_all()

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Array):
		push_warning("DealerAccessStore: поврежденный JSON, хранилище сброшено в памяти.")
		return get_all()

	for item in parsed:
		if item is Dictionary:
			var normalized := _normalize_record(item)
			if normalized.has("participant_token"):
				_upsert_in_memory(normalized)

	return get_all()


func save_store() -> bool:
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("DealerAccessStore: не удалось сохранить файл хранилища.")
		return false

	file.store_string(JSON.stringify(_records))
	file.close()
	return true


func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in _records:
		result.append(record.duplicate(true))
	return result


func get_participant_tokens() -> Array[String]:
	var tokens: Array[String] = []
	for record in _records:
		var token := str(record.get("participant_token", "")).strip_edges()
		if token != "":
			tokens.append(token)
	return tokens


func add_or_update_access(record: Dictionary) -> bool:
	var normalized := _normalize_record(record)
	if not normalized.has("participant_token"):
		return false

	var now := _now_string()
	var existing_index := _find_index_by_token(str(normalized["participant_token"]))
	if existing_index >= 0:
		var existing := _records[existing_index].duplicate(true)
		for key in normalized.keys():
			if key != "participant_token":
				existing[key] = normalized[key]
		existing["participant_token"] = _records[existing_index]["participant_token"]
		existing["updated_at"] = now
		_records[existing_index] = existing
	else:
		if not normalized.has("id"):
			normalized["id"] = _generate_local_id()
		if not normalized.has("added_at"):
			normalized["added_at"] = now
		normalized["updated_at"] = now
		_records.append(normalized)

	return save_store()


func remove_by_participant_token(token: String) -> bool:
	var normalized_token := token.strip_edges()
	if normalized_token == "":
		return false

	var index := _find_index_by_token(normalized_token)
	if index < 0:
		return false

	_records.remove_at(index)
	return save_store()


func update_cached_info(participant_token: String, cached_info: Dictionary) -> bool:
	var normalized_token := participant_token.strip_edges()
	if normalized_token == "":
		return false

	var index := _find_index_by_token(normalized_token)
	if index < 0:
		return false

	var record := _records[index].duplicate(true)
	record["participant_token"] = _records[index]["participant_token"]
	record["updated_at"] = _now_string()

	for key in cached_info.keys():
		if key == "participant_token":
			continue
		if key == "cached" and (cached_info[key] is Dictionary):
			var existing_cached: Dictionary = {}
			var current_cached: Variant = record.get("cached", {})
			if current_cached is Dictionary:
				existing_cached = current_cached.duplicate(true)
			for cached_key in cached_info[key].keys():
				existing_cached[cached_key] = cached_info[key][cached_key]
			record["cached"] = existing_cached
		else:
			record[key] = cached_info[key]

	_records[index] = _ensure_default_fields(record)
	return save_store()


func clear_all() -> bool:
	_records.clear()
	if FileAccess.file_exists(STORE_PATH):
		var err := DirAccess.remove_absolute(STORE_PATH)
		if err != OK:
			push_warning("DealerAccessStore: не удалось удалить файл хранилища.")
			return false
	return true


func _normalize_record(record: Dictionary) -> Dictionary:
	var token := str(record.get("participant_token", "")).strip_edges()
	if token == "":
		return {}

	var normalized := record.duplicate(true)
	normalized["participant_token"] = token
	return _ensure_default_fields(normalized)


func _ensure_default_fields(record: Dictionary) -> Dictionary:
	if not record.has("room_code"):
		record["room_code"] = ""
	if not record.has("room_title"):
		record["room_title"] = ""
	if not record.has("dealer_display_name"):
		record["dealer_display_name"] = ""
	if not record.has("availability"):
		record["availability"] = DEFAULT_STATUS
	if not record.has("access_status"):
		record["access_status"] = DEFAULT_STATUS
	if not record.has("token_status"):
		record["token_status"] = DEFAULT_STATUS
	if not record.has("cached") or not (record["cached"] is Dictionary):
		record["cached"] = {}
	return record


func _upsert_in_memory(record: Dictionary) -> void:
	var index := _find_index_by_token(str(record["participant_token"]))
	if index >= 0:
		_records[index] = record
	else:
		_records.append(record)


func _find_index_by_token(token: String) -> int:
	for i in range(_records.size()):
		if str(_records[i].get("participant_token", "")).strip_edges() == token:
			return i
	return -1


func _generate_local_id() -> String:
	return "%d-%d" % [int(Time.get_unix_time_from_system()), randi()]


func _now_string() -> String:
	return Time.get_datetime_string_from_system(true, true)
