## Локальное хранилище общего display name для турнира и online training.
extends Node

const STORE_PATH := "user://player_display_name.json"


func load_display_name() -> String:
	if not FileAccess.file_exists(STORE_PATH):
		return ""

	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return ""

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return ""

	var data := parsed as Dictionary
	if not data.has("display_name"):
		return ""

	return str(data["display_name"]).strip_edges()


func save_display_name(display_name: String) -> bool:
	var normalized_name := display_name.strip_edges()
	if normalized_name.is_empty():
		return false

	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify({
		"display_name": normalized_name
	}))
	file.close()
	return true
