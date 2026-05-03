## Экран сохранённых турниров для быстрого запуска попытки.
extends Control

const TOURNAMENT_ENTRY_SCENE_PATH := "res://scenes/network/TournamentEntryScreen.tscn"
const GAME_SCENE_PATH := "res://scenes/Game.tscn"
const TournamentAccessStoreScript = preload("res://scripts/network/TournamentAccessStore.gd")

var back_btn: Button
var empty_state_label: Label
var list_container: VBoxContainer

var _tournament_access_store: Node = null


func _ready() -> void:
	back_btn = find_child("BackBtn", true, false)
	empty_state_label = find_child("EmptyStateLabel", true, false)
	list_container = find_child("ListContainer", true, false)

	_tournament_access_store = TournamentAccessStoreScript.new()
	_tournament_access_store.name = "TournamentAccessStore_Local"
	add_child(_tournament_access_store)

	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)

	_reload_accesses()


func _reload_accesses() -> void:
	_clear_list()

	var added_count := 0
	var accesses_variant: Variant = []
	if _tournament_access_store:
		accesses_variant = _tournament_access_store.call("get_all_accesses")

	if accesses_variant is Array:
		for item in accesses_variant:
			if item is Dictionary:
				var access_record := (item as Dictionary).duplicate(true)
				list_container.add_child(_build_access_item(access_record))
				added_count += 1

	if empty_state_label:
		empty_state_label.visible = added_count == 0


func _build_access_item(access_record: Dictionary) -> Control:
	var tournament := _dictionary_or_empty(_dict_value(access_record, "tournament", {}))

	var item_button := Button.new()
	item_button.custom_minimum_size = Vector2(0, 64)
	item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item_button.text = ""
	item_button.pressed.connect(_on_start_attempt_pressed.bind(access_record.duplicate(true)))

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 14)
	padding.add_theme_constant_override("margin_top", 12)
	padding.add_theme_constant_override("margin_right", 14)
	padding.add_theme_constant_override("margin_bottom", 12)
	item_button.add_child(padding)

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	padding.add_child(content)

	var title_label := Label.new()
	title_label.text = _safe_title(tournament)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_label)

	var status_label := Label.new()
	status_label.text = _safe_status(tournament)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(status_label)

	return item_button


func _on_start_attempt_pressed(access_record: Dictionary) -> void:
	var session_manager: Variant = _find_session_manager()
	if session_manager == null:
		push_warning("MyTournamentsScreen: SessionManager не найден.")
		return
	if not session_manager.has_method("start_tournament_session"):
		push_warning("MyTournamentsScreen: tournament launch недоступен.")
		return

	session_manager.call("start_tournament_session", access_record)
	if get_tree():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_back_pressed() -> void:
	if get_tree():
		get_tree().change_scene_to_file(TOURNAMENT_ENTRY_SCENE_PATH)


func _clear_list() -> void:
	if list_container == null:
		return
	for child in list_container.get_children():
		child.queue_free()


func _find_session_manager():
	if Engine.has_singleton("SessionManager"):
		return Engine.get_singleton("SessionManager")
	return get_node_or_null("/root/SessionManager")


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _dict_value(source: Dictionary, key: String, fallback: Variant) -> Variant:
	if source.has(key):
		return source[key]
	return fallback


func _safe_title(tournament: Dictionary) -> String:
	var value := str(_dict_value(tournament, "title", "")).strip_edges()
	if value.is_empty():
		return "Турнир"
	return value


func _safe_status(tournament: Dictionary) -> String:
	var value := str(_dict_value(tournament, "status", "")).strip_edges()
	if value.is_empty():
		return "—"
	if value == "active":
		return "Активен"
	if value == "closed":
		return "Закрыт"
	return value
