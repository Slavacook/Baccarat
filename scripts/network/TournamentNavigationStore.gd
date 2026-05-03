## Временное хранилище перехода на страницу турнира.
extends Node

const STORE_PATH := "user://tournament_navigation.json"


func save_pending_access(access_record: Dictionary, return_scene_path: String) -> bool:
	if access_record.is_empty():
		return false

	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		return false

	var payload := {
		"access_record": access_record.duplicate(true),
		"return_scene_path": return_scene_path.strip_edges()
	}
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


func load_pending_access() -> Dictionary:
	if not FileAccess.file_exists(STORE_PATH):
		return {}

	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return {}

	var payload := parsed as Dictionary
	if not payload.has("access_record"):
		return {}
	if not (payload["access_record"] is Dictionary):
		return {}

	var result: Dictionary = {
		"access_record": (payload["access_record"] as Dictionary).duplicate(true)
	}
	if payload.has("return_scene_path"):
		result["return_scene_path"] = str(payload["return_scene_path"]).strip_edges()
	else:
		result["return_scene_path"] = ""
	return result


func clear_pending_access() -> void:
	if FileAccess.file_exists(STORE_PATH):
		var absolute_path := ProjectSettings.globalize_path(STORE_PATH)
		DirAccess.remove_absolute(absolute_path)
