## Страница турнира перед стартом попытки.
extends Control

const DEFAULT_RETURN_SCENE_PATH := "res://scenes/network/TournamentEntryScreen.tscn"
const GAME_SCENE_PATH := "res://scenes/Game.tscn"
const TournamentNavigationStoreScript = preload("res://scripts/network/TournamentNavigationStore.gd")
const TournamentAccessStoreScript = preload("res://scripts/network/TournamentAccessStore.gd")

var tournament_title_label: Label
var tournament_status_label: Label
var tournament_rules_label: Label
var status_label: Label
var empty_leaderboard_label: Label
var leaderboard_list: VBoxContainer
var leaderboard_header_panel: Control
var leaderboard_header_host: VBoxContainer
var start_attempt_btn: Button
var back_btn: Button

var _navigation_store: Node = null
var _tournament_access_store: Node = null
var _refresh_manager = null
var _access_record: Dictionary = {}
var _return_scene_path := DEFAULT_RETURN_SCENE_PATH


func _ready() -> void:
	tournament_title_label = find_child("TournamentTitleLabel", true, false)
	tournament_status_label = find_child("TournamentStatusLabel", true, false)
	tournament_rules_label = find_child("TournamentRulesLabel", true, false)
	status_label = find_child("StatusLabel", true, false)
	empty_leaderboard_label = find_child("EmptyLeaderboardLabel", true, false)
	leaderboard_list = find_child("LeaderboardList", true, false)
	leaderboard_header_panel = find_child("LeaderboardHeaderPanel", true, false)
	leaderboard_header_host = find_child("LeaderboardHeaderHost", true, false)
	start_attempt_btn = find_child("StartAttemptBtn", true, false)
	back_btn = find_child("BackBtn", true, false)

	_navigation_store = TournamentNavigationStoreScript.new()
	_navigation_store.name = "TournamentNavigationStore_Local"
	add_child(_navigation_store)

	_tournament_access_store = TournamentAccessStoreScript.new()
	_tournament_access_store.name = "TournamentAccessStore_Local"
	add_child(_tournament_access_store)

	_refresh_manager = _find_refresh_manager()

	if start_attempt_btn and not start_attempt_btn.pressed.is_connected(_on_start_attempt_pressed):
		start_attempt_btn.pressed.connect(_on_start_attempt_pressed)
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	_connect_refresh_manager()

	_render_leaderboard_header()
	_clear_leaderboard()
	_set_status("")
	_load_pending_payload()
	_render_access_record()
	_apply_cached_public_view_if_available()
	_request_public_refresh()


func _load_pending_payload() -> void:
	if _navigation_store == null:
		_access_record.clear()
		return

	var payload_variant: Variant = _navigation_store.call("load_pending_access")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant as Dictionary
		if payload.has("access_record") and payload["access_record"] is Dictionary:
			_access_record = (payload["access_record"] as Dictionary).duplicate(true)
		if payload.has("return_scene_path"):
			var path: String = str(payload["return_scene_path"]).strip_edges()
			if not path.is_empty():
				_return_scene_path = path
	_navigation_store.call("clear_pending_access")


func _render_access_record() -> void:
	var tournament: Dictionary = _access_tournament()
	var title: String = _dictionary_string(tournament, "title")
	if title.is_empty():
		title = "Турнир"

	var status_text: String = _format_tournament_status(_dictionary_string(tournament, "status"))
	if status_text.is_empty():
		status_text = "—"

	if tournament_title_label:
		tournament_title_label.text = "Турнир · \"%s\"" % title
	if tournament_status_label:
		tournament_status_label.text = "Статус: %s" % status_text
	if tournament_rules_label:
		tournament_rules_label.text = "Правила: %s" % _format_tournament_rules(tournament)
	if start_attempt_btn:
		start_attempt_btn.disabled = not _has_valid_access_record()

	if not _has_valid_access_record():
		_set_status("Не удалось открыть данные турнира")


func _request_public_refresh() -> void:
	if not _has_valid_access_record():
		return
	if _refresh_manager == null:
		_set_status("Не удалось загрузить таблицу")
		_show_empty_leaderboard(true)
		return

	var tournament: Dictionary = _access_tournament()
	var code: String = _dictionary_string(tournament, "code")
	if code.is_empty():
		_set_status("Таблица пока пустая")
		_show_empty_leaderboard(true)
		return

	_set_status("Загружаем таблицу...")
	if not bool(_refresh_manager.call("is_refresh_in_progress_for", code)):
		_refresh_manager.call("refresh_tournament_if_needed", code)


func _apply_cached_public_view_if_available() -> void:
	if not _has_valid_access_record():
		return
	if _refresh_manager == null:
		return
	if not _refresh_manager.has_method("get_last_public_tournament_body"):
		return

	var tournament: Dictionary = _access_tournament()
	var code: String = _dictionary_string(tournament, "code")
	if code.is_empty():
		return

	var cached_variant: Variant = _refresh_manager.call("get_last_public_tournament_body", code)
	if not (cached_variant is Dictionary):
		return

	var cached_body: Dictionary = cached_variant as Dictionary
	if cached_body.is_empty():
		return

	_apply_public_tournament_data(cached_body)
	var cached_leaderboard: Array = _extract_leaderboard(cached_body)
	if cached_leaderboard.is_empty():
		return

	_render_leaderboard(cached_leaderboard)
	_set_header_visible(true)


func _apply_public_tournament_data(body: Dictionary) -> void:
	var tournament_data: Dictionary = _extract_tournament_dictionary(body)
	if tournament_data.is_empty():
		return

	var merged := _merge_public_tournament_into_access_record(tournament_data)
	_save_refreshed_access_record()

	if tournament_title_label:
		var title := _dictionary_string(merged, "title")
		tournament_title_label.text = "Турнир · \"%s\"" % (title if not title.is_empty() else "Турнир")
	if tournament_status_label:
		var status_text := _format_tournament_status(_dictionary_string(merged, "status"))
		tournament_status_label.text = "Статус: %s" % (status_text if not status_text.is_empty() else "—")
	if tournament_rules_label:
		tournament_rules_label.text = "Правила: %s" % _format_tournament_rules(merged)


func _merge_public_tournament_into_access_record(tournament_data: Dictionary) -> Dictionary:
	if _tournament_access_store == null:
		var local_tournament: Dictionary = _access_tournament()
		return local_tournament.duplicate(true)

	var merged_variant: Variant = _tournament_access_store.call(
		"merge_public_tournament_data",
		_access_record,
		tournament_data
	)
	if merged_variant is Dictionary and not (merged_variant as Dictionary).is_empty():
		_access_record = (merged_variant as Dictionary).duplicate(true)
	return _access_tournament()


func _save_refreshed_access_record() -> void:
	if _tournament_access_store == null:
		return

	var saved_variant: Variant = _tournament_access_store.call("save_access", _access_record)
	if saved_variant is Dictionary:
		var saved_record := saved_variant as Dictionary
		if not saved_record.is_empty():
			_access_record = saved_record.duplicate(true)


func _extract_tournament_dictionary(body: Dictionary) -> Dictionary:
	for key in ["tournament", "data", "item"]:
		if body.has(key) and body[key] is Dictionary:
			var candidate: Dictionary = body[key] as Dictionary
			if candidate.has("title") or candidate.has("status") or candidate.has("max_rounds"):
				return candidate
	return body


func _extract_leaderboard(body: Dictionary) -> Array:
	var direct_rows: Array = _extract_array_from_dictionary(body)
	if not direct_rows.is_empty():
		return direct_rows

	if body.has("leaderboard") and body["leaderboard"] is Dictionary:
		var leaderboard_dict: Dictionary = body["leaderboard"] as Dictionary
		var leaderboard_rows: Array = _extract_array_from_dictionary(leaderboard_dict)
		if not leaderboard_rows.is_empty():
			return leaderboard_rows

	for nested_key in ["data", "tournament"]:
		if body.has(nested_key) and body[nested_key] is Dictionary:
			var nested_dict: Dictionary = body[nested_key] as Dictionary
			var nested_rows: Array = _extract_array_from_dictionary(nested_dict)
			if not nested_rows.is_empty():
				return nested_rows
			if nested_dict.has("leaderboard") and nested_dict["leaderboard"] is Dictionary:
				var nested_leaderboard: Dictionary = nested_dict["leaderboard"] as Dictionary
				var nested_leaderboard_rows: Array = _extract_array_from_dictionary(nested_leaderboard)
				if not nested_leaderboard_rows.is_empty():
					return nested_leaderboard_rows

	return []


func _render_leaderboard(rows: Array) -> void:
	if leaderboard_list == null:
		_show_empty_leaderboard(true)
		return

	_clear_leaderboard()
	var added_count := 0

	for row in rows:
		if row is Dictionary:
			var row_dict: Dictionary = row as Dictionary
			leaderboard_list.add_child(_build_leaderboard_row(row_dict))
			added_count += 1

	_show_empty_leaderboard(added_count == 0)
	_set_header_visible(true)


func _build_leaderboard_row(row: Dictionary) -> Control:
	var is_current_player: bool = _is_current_player_row(row)
	var rank: String = _first_rank_string(row, ["rank", "place", "position"])
	var participant_name: String = _first_non_empty_string(row, ["display_name", "participant_name", "name"])
	var rounds_text: String = _first_numeric_string(row, ["rounds_completed", "rounds"])
	var errors: String = _first_numeric_string(row, ["errors_total", "errors"])
	var time_text: String = _time_string_from_row(row)
	var attempt_text: String = _first_numeric_string(row, ["attempt_number", "attempt"])

	if rank.is_empty():
		rank = "—"
	if participant_name.is_empty():
		participant_name = "—"
	if rounds_text.is_empty():
		rounds_text = "0"
	if errors.is_empty():
		errors = "—"
	if time_text.is_empty():
		time_text = "—"
	if attempt_text.is_empty():
		attempt_text = "0"

	return _build_table_row(rank, participant_name, rounds_text, errors, time_text, attempt_text, false, is_current_player)


func _render_leaderboard_header() -> void:
	if leaderboard_header_host == null:
		return
	for child in leaderboard_header_host.get_children():
		child.queue_free()
	leaderboard_header_host.add_child(_build_table_row("Место", "Участник", "Раздачи", "Ошибки", "Время", "Попытка", true, false))

func _build_table_row(
	place_text: String,
	name_text: String,
	rounds_text: String,
	errors_text: String,
	time_text: String,
	attempt_text: String,
	is_header: bool,
	is_current_player: bool
) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	if is_header:
		style.bg_color = Color(1, 1, 1, 0.08)
	elif is_current_player:
		style.bg_color = Color(0.10, 0.18, 0.12, 0.72)
	else:
		style.bg_color = Color(0.02, 0.03, 0.05, 0.34)
	style.border_width_bottom = 1
	if is_header:
		style.border_color = Color(1, 1, 1, 0.12)
	elif is_current_player:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.86, 0.72, 0.38, 0.68)
		style.shadow_color = Color(0.86, 0.72, 0.38, 0.18)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 0)
	else:
		style.border_color = Color(1, 1, 1, 0.08)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var padding := MarginContainer.new()
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_theme_constant_override("margin_left", 12)
	padding.add_theme_constant_override("margin_top", 10)
	padding.add_theme_constant_override("margin_right", 12)
	padding.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(padding)

	var row_box := HBoxContainer.new()
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_box.add_theme_constant_override("separation", 12)
	padding.add_child(row_box)

	row_box.add_child(_build_table_cell(place_text, 80, HORIZONTAL_ALIGNMENT_CENTER, is_header, false, is_current_player))
	row_box.add_child(_build_column_separator())
	row_box.add_child(_build_name_cell(name_text, is_header, is_current_player))
	row_box.add_child(_build_column_separator())
	row_box.add_child(_build_table_cell(rounds_text, 96, HORIZONTAL_ALIGNMENT_CENTER, is_header, false, is_current_player))
	row_box.add_child(_build_column_separator())
	row_box.add_child(_build_table_cell(errors_text, 96, HORIZONTAL_ALIGNMENT_CENTER, is_header, false, is_current_player))
	row_box.add_child(_build_column_separator())
	row_box.add_child(_build_table_cell(time_text, 110, HORIZONTAL_ALIGNMENT_CENTER, is_header, false, is_current_player))
	row_box.add_child(_build_column_separator())
	row_box.add_child(_build_table_cell(attempt_text, 96, HORIZONTAL_ALIGNMENT_CENTER, is_header, false, is_current_player))

	return panel


func _build_table_cell(
	text: String,
	min_width: int,
	alignment: HorizontalAlignment,
	is_header: bool,
	expand: bool,
	is_current_player: bool
) -> Control:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if is_header else TextServer.AUTOWRAP_WORD_SMART
	if is_header:
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
	elif is_current_player:
		label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 0.98))
	else:
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	if min_width > 0:
		label.custom_minimum_size = Vector2(min_width, 0)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _build_name_cell(text: String, is_header: bool, is_current_player: bool) -> Control:
	if is_header:
		return _build_table_cell(text, 0, HORIZONTAL_ALIGNMENT_LEFT, true, true, false)

	var container: HBoxContainer = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.alignment = BoxContainer.ALIGNMENT_BEGIN
	container.add_theme_constant_override("separation", 8)

	var name_label: Label = Label.new()
	name_label.text = text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_current_player:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 0.98))
	else:
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	container.add_child(name_label)

	if is_current_player:
		container.add_child(_build_current_player_badge())

	return container


func _build_current_player_badge() -> Control:
	var badge_panel: PanelContainer = PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.82, 0.69, 0.32, 0.22)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(0.90, 0.76, 0.40, 0.54)
	badge_style.corner_radius_top_left = 7
	badge_style.corner_radius_top_right = 7
	badge_style.corner_radius_bottom_left = 7
	badge_style.corner_radius_bottom_right = 7
	badge_panel.add_theme_stylebox_override("panel", badge_style)

	var padding: MarginContainer = MarginContainer.new()
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_theme_constant_override("margin_left", 8)
	padding.add_theme_constant_override("margin_top", 3)
	padding.add_theme_constant_override("margin_right", 8)
	padding.add_theme_constant_override("margin_bottom", 3)
	badge_panel.add_child(padding)

	var badge_label: Label = Label.new()
	badge_label.text = "Вы"
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90, 0.98))
	padding.add_child(badge_label)

	return badge_panel


func _build_column_separator() -> Control:
	var separator: ColorRect = ColorRect.new()
	separator.custom_minimum_size = Vector2(1, 24)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.color = Color(1, 1, 1, 0.12)
	return separator


func _time_string_from_row(row: Dictionary) -> String:
	for key in ["time_spent_seconds", "time_seconds"]:
		if row.has(key):
			return _format_duration_mmss(int(row[key]))
	return ""


func _on_start_attempt_pressed() -> void:
	if not _has_valid_access_record():
		_set_status("Турнир недоступен для старта")
		return

	var session_manager: Variant = _find_session_manager()
	if session_manager == null:
		_set_status("SessionManager не найден")
		return
	if not session_manager.has_method("start_tournament_session"):
		_set_status("Tournament launch недоступен")
		return

	session_manager.call("start_tournament_session", _access_record)
	if get_tree():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_back_pressed() -> void:
	var path := _return_scene_path
	if path.is_empty():
		path = DEFAULT_RETURN_SCENE_PATH
	if get_tree():
		get_tree().change_scene_to_file(path)


func _clear_leaderboard() -> void:
	if leaderboard_list == null:
		return
	for child in leaderboard_list.get_children():
		child.queue_free()


func _show_empty_leaderboard(should_show: bool) -> void:
	if empty_leaderboard_label:
		empty_leaderboard_label.visible = should_show


func _set_header_visible(should_show: bool) -> void:
	if leaderboard_header_panel:
		leaderboard_header_panel.visible = should_show


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _find_refresh_manager():
	if Engine.has_singleton("TournamentRefreshManager"):
		return Engine.get_singleton("TournamentRefreshManager")
	return get_node_or_null("/root/TournamentRefreshManager")


func _find_session_manager():
	if Engine.has_singleton("SessionManager"):
		return Engine.get_singleton("SessionManager")
	return get_node_or_null("/root/SessionManager")


func _connect_refresh_manager() -> void:
	if _refresh_manager == null:
		return
	if _refresh_manager.has_signal("tournament_refresh_completed"):
		if not _refresh_manager.tournament_refresh_completed.is_connected(_on_tournament_refresh_completed):
			_refresh_manager.tournament_refresh_completed.connect(_on_tournament_refresh_completed)


func _disconnect_refresh_manager() -> void:
	if _refresh_manager == null:
		return
	if _refresh_manager.has_signal("tournament_refresh_completed"):
		if _refresh_manager.tournament_refresh_completed.is_connected(_on_tournament_refresh_completed):
			_refresh_manager.tournament_refresh_completed.disconnect(_on_tournament_refresh_completed)


func _on_tournament_refresh_completed(code: String, success: bool) -> void:
	if not is_inside_tree():
		return

	var current_tournament := _access_tournament()
	var current_code := _dictionary_string(current_tournament, "code")
	if current_code.is_empty() or current_code != code:
		return

	_reload_access_record_from_store()
	_render_access_record()
	_apply_refreshed_public_view(code, success)


func _reload_access_record_from_store() -> void:
	if _tournament_access_store == null:
		return

	var tournament := _access_tournament()
	var tournament_id := _dictionary_string(tournament, "id")
	if tournament_id.is_empty():
		return

	var access_variant: Variant = _tournament_access_store.call("get_access_by_tournament_id", tournament_id)
	if access_variant is Dictionary and not (access_variant as Dictionary).is_empty():
		_access_record = (access_variant as Dictionary).duplicate(true)


func _apply_refreshed_public_view(code: String, success: bool) -> void:
	if not success:
		var cached_body: Dictionary = {}
		if _refresh_manager != null and _refresh_manager.has_method("get_last_public_tournament_body"):
			var cached_variant: Variant = _refresh_manager.call("get_last_public_tournament_body", code)
			if cached_variant is Dictionary:
				cached_body = cached_variant as Dictionary
		if not cached_body.is_empty():
			print("📋 TournamentDetailsScreen: refresh %s завершён неуспешно, используем cached fallback" % code)
			_set_status("Не удалось обновить турнир, будет использована сохранённая версия")
		else:
			print("📋 TournamentDetailsScreen: refresh %s завершён неуспешно, cached fallback отсутствует" % code)
			_set_status("Не удалось обновить турнир")
		if not cached_body.is_empty():
			_apply_public_tournament_data(cached_body)
			var cached_leaderboard: Array = _extract_leaderboard(cached_body)
			if not cached_leaderboard.is_empty():
				_render_leaderboard(cached_leaderboard)
				_set_header_visible(true)
				return
		return

	if _refresh_manager == null or not _refresh_manager.has_method("get_last_public_tournament_body"):
		_set_status("")
		_clear_leaderboard()
		_show_empty_leaderboard(true)
		_set_header_visible(false)
		return

	var body_variant: Variant = _refresh_manager.call("get_last_public_tournament_body", code)
	if not (body_variant is Dictionary):
		_set_status("")
		_clear_leaderboard()
		_show_empty_leaderboard(true)
		_set_header_visible(false)
		return

	var body_dict := body_variant as Dictionary
	_apply_public_tournament_data(body_dict)
	var leaderboard: Array = _extract_leaderboard(body_dict)
	if leaderboard.is_empty():
		_clear_leaderboard()
		_show_empty_leaderboard(true)
		_set_header_visible(false)
		_set_status("")
		return

	_render_leaderboard(leaderboard)
	_set_status("")


func _exit_tree() -> void:
	_disconnect_refresh_manager()


func _access_tournament() -> Dictionary:
	if _access_record.has("tournament") and _access_record["tournament"] is Dictionary:
		return (_access_record["tournament"] as Dictionary).duplicate(true)
	return {}


func _current_participant_id() -> String:
	if not _access_record.has("participant") or not (_access_record["participant"] is Dictionary):
		return ""
	var participant: Dictionary = _access_record["participant"] as Dictionary
	return _dictionary_string(participant, "id")


func _current_participant_display_name() -> String:
	if not _access_record.has("participant") or not (_access_record["participant"] is Dictionary):
		return ""
	var participant: Dictionary = _access_record["participant"] as Dictionary
	return _dictionary_string(participant, "display_name")


func _is_current_player_row(row: Dictionary) -> bool:
	var current_participant_id: String = _current_participant_id()
	if not current_participant_id.is_empty():
		var row_participant_id: String = _dictionary_string(row, "participant_id")
		if not row_participant_id.is_empty():
			return row_participant_id == current_participant_id

	var current_name: String = _current_participant_display_name()
	if current_name.is_empty():
		return false

	var row_name: String = _first_non_empty_string(row, ["display_name", "participant_name", "name"])
	if row_name.is_empty():
		return false

	return row_name == current_name


func _has_valid_access_record() -> bool:
	if _access_record.is_empty():
		return false
	if not _access_record.has("participant_token"):
		return false
	if not (_access_record["participant_token"] is String):
		return false
	if str(_access_record["participant_token"]).strip_edges().is_empty():
		return false

	var tournament: Dictionary = _access_tournament()
	return not tournament.is_empty()


func _dictionary_string(source: Dictionary, key: String) -> String:
	if source.has(key):
		return str(source[key]).strip_edges()
	return ""


func _format_tournament_status(status: String) -> String:
	match status:
		"active":
			return "Активен"
		"closed":
			return "Закрыт"
	return status


func _format_tournament_rules(tournament: Dictionary) -> String:
	var rounds := 0
	if tournament.has("max_rounds"):
		rounds = int(tournament["max_rounds"])
	var seconds := 0
	if tournament.has("attempt_duration_seconds"):
		seconds = int(tournament["attempt_duration_seconds"])
	var minutes: int = int(float(seconds) / 60.0)
	return "%d раздач · %d мин" % [rounds, minutes]


func _response_code(packet: Dictionary) -> int:
	if packet.has("code"):
		return int(packet["code"])
	return 0


func _response_body(packet: Dictionary) -> Variant:
	if packet.has("body"):
		return packet["body"]
	return {}


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _extract_array_from_dictionary(source: Dictionary) -> Array:
	for key in ["leaderboard", "results", "participants", "entries", "items"]:
		if source.has(key) and source[key] is Array:
			return (source[key] as Array).duplicate(true)
	return []


func _first_non_empty_string(source: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		if source.has(key):
			var value := str(source[key]).strip_edges()
			if not value.is_empty():
				return value
	return ""


func _first_numeric_string(source: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		if source.has(key):
			return str(int(source[key]))
	return ""


func _first_rank_string(source: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		if source.has(key):
			var value: Variant = source[key]
			if value is int:
				return str(value)
			if value is float:
				return str(int(value))
			var text := str(value).strip_edges()
			if text.is_empty():
				continue
			if text.contains("."):
				var as_float := text.to_float()
				return str(int(as_float))
			if text.is_valid_int():
				return text
			return text
	return ""


func _format_duration_mmss(total_seconds: int) -> String:
	var clamped_seconds: int = max(total_seconds, 0)
	var minutes: int = int(float(clamped_seconds) / 60.0)
	var seconds: int = int(clamped_seconds % 60)
	return "%02d:%02d" % [minutes, seconds]
