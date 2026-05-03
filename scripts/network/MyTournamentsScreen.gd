## Экран сохранённых турниров для быстрого запуска попытки.
extends Control

const TOURNAMENT_ENTRY_SCENE_PATH := "res://scenes/network/TournamentEntryScreen.tscn"
const TOURNAMENT_DETAILS_SCENE_PATH := "res://scenes/network/TournamentDetailsScreen.tscn"
const TournamentAccessStoreScript = preload("res://scripts/network/TournamentAccessStore.gd")
const TournamentNavigationStoreScript = preload("res://scripts/network/TournamentNavigationStore.gd")

var back_btn: Button
var empty_state_label: Label
var list_container: VBoxContainer

var _tournament_access_store: Node = null
var _navigation_store: Node = null


func _ready() -> void:
	back_btn = find_child("BackBtn", true, false)
	empty_state_label = find_child("EmptyStateLabel", true, false)
	list_container = find_child("ListContainer", true, false)

	_tournament_access_store = TournamentAccessStoreScript.new()
	_tournament_access_store.name = "TournamentAccessStore_Local"
	add_child(_tournament_access_store)
	_navigation_store = TournamentNavigationStoreScript.new()
	_navigation_store.name = "TournamentNavigationStore_Local"
	add_child(_navigation_store)

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
	var title := _safe_title(tournament)
	var status := _safe_status(tournament)

	var item_button := Button.new()
	item_button.custom_minimum_size = Vector2(0, 60)
	item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item_button.text = _format_tournament_list_row(title, status)
	_apply_access_item_style(item_button)
	item_button.pressed.connect(_on_start_attempt_pressed.bind(access_record.duplicate(true)))

	return item_button


func _on_start_attempt_pressed(access_record: Dictionary) -> void:
	if _navigation_store == null:
		push_warning("MyTournamentsScreen: TournamentNavigationStore не найден.")
		return
	var saved_ok: Variant = _navigation_store.call(
		"save_pending_access",
		access_record,
		"res://scenes/network/MyTournamentsScreen.tscn"
	)
	if not bool(saved_ok):
		push_warning("MyTournamentsScreen: не удалось сохранить переход к турниру.")
		return

	if get_tree():
		get_tree().change_scene_to_file(TOURNAMENT_DETAILS_SCENE_PATH)


func _on_back_pressed() -> void:
	if get_tree():
		get_tree().change_scene_to_file(TOURNAMENT_ENTRY_SCENE_PATH)


func _clear_list() -> void:
	if list_container == null:
		return
	for child in list_container.get_children():
		child.queue_free()


func _apply_access_item_style(item_button: Button) -> void:
	if item_button == null:
		return

	var normal_style := StyleBoxFlat.new()
	normal_style.content_margin_left = 18.0
	normal_style.content_margin_top = 12.0
	normal_style.content_margin_right = 18.0
	normal_style.content_margin_bottom = 12.0
	normal_style.bg_color = Color(0.11, 0.14, 0.19, 0.92)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.9, 0.72, 0.42, 0.22)
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.shadow_color = Color(0, 0, 0, 0.22)
	normal_style.shadow_size = 4
	normal_style.shadow_offset = Vector2(0, 2)

	var hover_style := StyleBoxFlat.new()
	hover_style.content_margin_left = 18.0
	hover_style.content_margin_top = 12.0
	hover_style.content_margin_right = 18.0
	hover_style.content_margin_bottom = 12.0
	hover_style.bg_color = Color(0.15, 0.19, 0.25, 0.96)
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.border_color = Color(0.95, 0.75, 0.44, 0.3)
	hover_style.corner_radius_top_left = 10
	hover_style.corner_radius_top_right = 10
	hover_style.corner_radius_bottom_right = 10
	hover_style.corner_radius_bottom_left = 10
	hover_style.shadow_color = Color(0, 0, 0, 0.24)
	hover_style.shadow_size = 5
	hover_style.shadow_offset = Vector2(0, 2)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.content_margin_left = 18.0
	pressed_style.content_margin_top = 12.0
	pressed_style.content_margin_right = 18.0
	pressed_style.content_margin_bottom = 12.0
	pressed_style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	pressed_style.border_width_left = 1
	pressed_style.border_width_top = 1
	pressed_style.border_width_right = 1
	pressed_style.border_width_bottom = 1
	pressed_style.border_color = Color(0.82, 0.66, 0.38, 0.16)
	pressed_style.corner_radius_top_left = 10
	pressed_style.corner_radius_top_right = 10
	pressed_style.corner_radius_bottom_right = 10
	pressed_style.corner_radius_bottom_left = 10
	pressed_style.shadow_color = Color(0, 0, 0, 0.18)
	pressed_style.shadow_size = 2
	pressed_style.shadow_offset = Vector2(0, 1)

	item_button.add_theme_stylebox_override("normal", normal_style)
	item_button.add_theme_stylebox_override("hover", hover_style)
	item_button.add_theme_stylebox_override("pressed", pressed_style)


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


func _format_tournament_list_row(title: String, status: String) -> String:
	return "%s  —  %s" % [title, status]
