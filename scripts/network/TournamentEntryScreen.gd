## Экран входа в турнир по коду без запуска игры.
extends Control

const MAIN_MENU_SCENE_PATH := "res://scenes/StartScreen.tscn"
const MY_TOURNAMENTS_SCENE_PATH := "res://scenes/network/MyTournamentsScreen.tscn"
const TOURNAMENT_DETAILS_SCENE_PATH := "res://scenes/network/TournamentDetailsScreen.tscn"
const TOURNAMENT_CODE_ALLOWED_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const TournamentAccessStoreScript = preload("res://scripts/network/TournamentAccessStore.gd")
const PlayerDisplayNameStoreScript = preload("res://scripts/network/PlayerDisplayNameStore.gd")
const TournamentNavigationStoreScript = preload("res://scripts/network/TournamentNavigationStore.gd")
const SCREEN_HOME := "home"
const SCREEN_CODE_ENTRY := "code_entry"
const SCREEN_CONNECTED := "connected"

var tournament_code_input: LineEdit
var display_name_input: LineEdit
var paste_code_btn: Button
var enter_btn: Button
var back_btn: Button
var my_tournaments_btn: Button
var new_code_entry_btn: Button
var home_back_btn: Button
var start_attempt_btn: Button
var edit_access_btn: Button
var connected_back_btn: Button
var home_block: Control
var form_block: Control
var error_label: Label
var status_label: Label
var summary_block: Control
var description_label: Label
var summary_title_value: Label
var summary_code_value: Label
var summary_status_value: Label
var summary_rules_value: Label
var summary_name_value: Label

var _api_service = null
var _tournament_access_store: Node = null
var _display_name_store: Node = null
var _navigation_store: Node = null
var _saved_tournament_access: Dictionary = {}


func _ready() -> void:
	tournament_code_input = find_child("TournamentCodeInput", true, false)
	display_name_input = find_child("DisplayNameInput", true, false)
	paste_code_btn = find_child("PasteCodeBtn", true, false)
	enter_btn = find_child("EnterBtn", true, false)
	back_btn = find_child("BackBtn", true, false)
	my_tournaments_btn = find_child("MyTournamentsBtn", true, false)
	new_code_entry_btn = find_child("NewCodeEntryBtn", true, false)
	home_back_btn = find_child("HomeBackBtn", true, false)
	start_attempt_btn = find_child("StartAttemptBtn", true, false)
	edit_access_btn = find_child("EditAccessBtn", true, false)
	connected_back_btn = find_child("ConnectedBackBtn", true, false)
	home_block = find_child("HomeBlock", true, false)
	form_block = find_child("FormBlock", true, false)
	error_label = find_child("ErrorLabel", true, false)
	status_label = find_child("StatusLabel", true, false)
	summary_block = find_child("SummaryBlock", true, false)
	description_label = find_child("Description", true, false)
	summary_title_value = find_child("SummaryTitleValue", true, false)
	summary_code_value = find_child("SummaryCodeValue", true, false)
	summary_status_value = find_child("SummaryStatusValue", true, false)
	summary_rules_value = find_child("SummaryRulesValue", true, false)
	summary_name_value = find_child("SummaryNameValue", true, false)

	_api_service = _find_api_service()
	_tournament_access_store = TournamentAccessStoreScript.new()
	_tournament_access_store.name = "TournamentAccessStore_Local"
	add_child(_tournament_access_store)
	_display_name_store = PlayerDisplayNameStoreScript.new()
	_display_name_store.name = "PlayerDisplayNameStore_Local"
	add_child(_display_name_store)
	_navigation_store = TournamentNavigationStoreScript.new()
	_navigation_store.name = "TournamentNavigationStore_Local"
	add_child(_navigation_store)

	if enter_btn and not enter_btn.pressed.is_connected(_on_enter_pressed):
		enter_btn.pressed.connect(_on_enter_pressed)
	if paste_code_btn and not paste_code_btn.pressed.is_connected(_on_paste_code_pressed):
		paste_code_btn.pressed.connect(_on_paste_code_pressed)
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if my_tournaments_btn and not my_tournaments_btn.pressed.is_connected(_on_my_tournaments_pressed):
		my_tournaments_btn.pressed.connect(_on_my_tournaments_pressed)
	if new_code_entry_btn and not new_code_entry_btn.pressed.is_connected(_on_new_code_entry_pressed):
		new_code_entry_btn.pressed.connect(_on_new_code_entry_pressed)
	if home_back_btn and not home_back_btn.pressed.is_connected(_on_home_back_pressed):
		home_back_btn.pressed.connect(_on_home_back_pressed)
	if start_attempt_btn and not start_attempt_btn.pressed.is_connected(_on_start_attempt_pressed):
		start_attempt_btn.pressed.connect(_on_start_attempt_pressed)
	if edit_access_btn and not edit_access_btn.pressed.is_connected(_on_edit_access_pressed):
		edit_access_btn.pressed.connect(_on_edit_access_pressed)
	if connected_back_btn and not connected_back_btn.pressed.is_connected(_on_connected_back_pressed):
		connected_back_btn.pressed.connect(_on_connected_back_pressed)
	if tournament_code_input and not tournament_code_input.text_changed.is_connected(_on_tournament_code_changed):
		tournament_code_input.text_changed.connect(_on_tournament_code_changed)
	if display_name_input and not display_name_input.text_changed.is_connected(_on_input_changed):
		display_name_input.text_changed.connect(_on_input_changed)

	_hide_error()
	_set_status("")
	_set_home_visible(false)
	_set_form_visible(false)
	_set_summary_visible(false)
	_set_start_attempt_visible(false)
	_set_edit_access_visible(false)
	_apply_saved_display_name()
	_set_screen_state(SCREEN_HOME)


func _on_enter_pressed() -> void:
	var code := _normalize_tournament_code(tournament_code_input.text if tournament_code_input else "")
	var display_name := display_name_input.text.strip_edges() if display_name_input else ""

	if code.is_empty():
		_show_error("Введите код турнира")
		return
	if display_name.is_empty():
		_show_error("Введите ваше имя")
		return
	if _api_service == null:
		_show_error("ApiService не найден")
		return
	if _tournament_access_store == null:
		_show_error("TournamentAccessStore не найден")
		return

	if _display_name_store:
		_display_name_store.call("save_display_name", display_name)

	_hide_error()
	_set_summary_visible(false)
	_set_loading(true)

	var result: Dictionary = await _api_service.activate_tournament(code, display_name)

	_set_loading(false)

	var status_code := int(result.get("code", 0))
	var body: Variant = result.get("body", {})
	if status_code < 200 or status_code >= 300:
		_show_error(_activation_error_message(status_code, body))
		return
	if not (body is Dictionary):
		_show_error("Не удалось войти в турнир")
		return

	var response := body as Dictionary
	var participant_token := str(response.get("participant_token", "")).strip_edges()
	var tournament := _dictionary_or_empty(response.get("tournament", {}))
	var participant := _dictionary_or_empty(response.get("participant", {}))
	if participant_token.is_empty() or tournament.is_empty() or participant.is_empty():
		_show_error("Не удалось войти в турнир")
		return

	var saved: Variant = _tournament_access_store.call("save_access", response)
	if not (saved is Dictionary) or (saved as Dictionary).is_empty():
		_show_error("Не удалось сохранить доступ к турниру")
		return

	_saved_tournament_access = (saved as Dictionary).duplicate(true)
	if _navigation_store == null:
		_show_error("Не удалось открыть страницу турнира")
		return

	var navigation_saved: Variant = _navigation_store.call(
		"save_pending_access",
		_saved_tournament_access,
		"res://scenes/network/TournamentEntryScreen.tscn"
	)
	if not bool(navigation_saved):
		_show_error("Не удалось открыть страницу турнира")
		return

	if get_tree():
		get_tree().change_scene_to_file(TOURNAMENT_DETAILS_SCENE_PATH)


func _on_back_pressed() -> void:
	_hide_error()
	_set_status("")
	_set_screen_state(SCREEN_HOME)


func _on_start_attempt_pressed() -> void:
	if _saved_tournament_access.is_empty():
		_show_error("Турнир не подключён")
		return

	var session_manager: Variant = _find_session_manager()
	if session_manager == null:
		_show_error("SessionManager не найден")
		return
	if not session_manager.has_method("start_tournament_session"):
		_show_error("Tournament launch недоступен")
		return

	session_manager.call("start_tournament_session", _saved_tournament_access)
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_my_tournaments_pressed() -> void:
	if get_tree():
		get_tree().change_scene_to_file(MY_TOURNAMENTS_SCENE_PATH)


func _on_new_code_entry_pressed() -> void:
	_hide_error()
	_set_status("")
	_set_screen_state(SCREEN_CODE_ENTRY)


func _on_home_back_pressed() -> void:
	if get_tree():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_connected_back_pressed() -> void:
	_hide_error()
	_set_status("")
	_set_screen_state(SCREEN_HOME)


func _on_edit_access_pressed() -> void:
	_saved_tournament_access.clear()
	_hide_error()
	_set_status("")
	_set_screen_state(SCREEN_CODE_ENTRY)


func _on_tournament_code_changed(text: String) -> void:
	_on_input_changed("")
	var formatted := _format_tournament_code(text)
	if formatted == text:
		return
	tournament_code_input.text = formatted
	tournament_code_input.caret_column = formatted.length()


func _on_paste_code_pressed() -> void:
	if tournament_code_input == null:
		return

	var clipboard_text := str(DisplayServer.clipboard_get()).strip_edges()
	if clipboard_text == "":
		_show_error("Буфер обмена пуст")
		return

	_hide_error()
	var normalized_code := _normalize_tournament_code(clipboard_text)
	if normalized_code == "":
		_show_error("В буфере нет кода турнира")
		return

	tournament_code_input.text = normalized_code
	tournament_code_input.caret_column = normalized_code.length()
	_set_status("Код вставлен из буфера обмена")


func _on_input_changed(_text: String) -> void:
	_saved_tournament_access.clear()
	_hide_error()
	_set_status("")
	_set_screen_state(SCREEN_CODE_ENTRY)
	_set_start_attempt_visible(false)
	_set_edit_access_visible(false)


func _format_tournament_code(value: String) -> String:
	var cleaned := ""
	for ch in value.to_upper():
		if TOURNAMENT_CODE_ALLOWED_CHARS.contains(ch):
			cleaned += ch
		if cleaned.length() >= 8:
			break

	if cleaned.length() <= 4:
		return cleaned
	return "%s-%s" % [cleaned.substr(0, 4), cleaned.substr(4)]


func _normalize_tournament_code(value: String) -> String:
	return _format_tournament_code(value.strip_edges())


func _activation_error_message(status_code: int, _body: Variant) -> String:
	if status_code == 0:
		return "Нет связи с сервером"
	if status_code == 404:
		return "Турнир не найден"
	if status_code == 409:
		return "Турнир закрыт"
	return "Не удалось войти в турнир"


func _show_summary(saved_access: Dictionary) -> void:
	var tournament_value: Variant = {}
	if saved_access.has("tournament"):
		tournament_value = saved_access["tournament"]
	var tournament := _dictionary_or_empty(tournament_value)
	var title_text := _dictionary_string(tournament, "title")
	if title_text.is_empty():
		title_text = "Турнир"
	var status_text := _format_tournament_status(_dictionary_string(tournament, "status"))
	if status_text.is_empty():
		status_text = "—"

	if summary_title_value:
		summary_title_value.text = title_text
	if summary_code_value:
		summary_code_value.text = ""
	if summary_status_value:
		summary_status_value.text = "Статус: %s" % status_text
	if summary_rules_value:
		summary_rules_value.text = "Правила: %s" % _format_tournament_rules(tournament)
	if summary_name_value:
		summary_name_value.text = ""

	_set_summary_visible(true)


func _format_tournament_status(status: String) -> String:
	match status:
		"active":
			return "Активен"
		"closed":
			return "Закрыт"
	return status


func _format_tournament_rules(tournament: Dictionary) -> String:
	var rounds := _dictionary_int(tournament, "max_rounds")
	var seconds := _dictionary_int(tournament, "attempt_duration_seconds")
	var minutes: int = int(float(seconds) / 60.0)
	return "%d раздач / %d мин" % [rounds, minutes]


func _find_api_service():
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService")
	return get_node_or_null("/root/ApiService")


func _find_session_manager():
	if Engine.has_singleton("SessionManager"):
		return Engine.get_singleton("SessionManager")
	return get_node_or_null("/root/SessionManager")


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _apply_saved_display_name() -> void:
	if display_name_input == null:
		return
	if not display_name_input.text.strip_edges().is_empty():
		return
	if _display_name_store == null:
		return

	var saved_name_variant: Variant = _display_name_store.call("load_display_name")
	var saved_name := str(saved_name_variant).strip_edges()
	if not saved_name.is_empty():
		display_name_input.text = saved_name


func _set_screen_state(state: String) -> void:
	_set_home_visible(state == SCREEN_HOME)
	_set_form_visible(state == SCREEN_CODE_ENTRY)
	_set_summary_visible(state == SCREEN_CONNECTED)
	_set_start_attempt_visible(state == SCREEN_CONNECTED and not _saved_tournament_access.is_empty())
	_set_edit_access_visible(false)

	if description_label:
		if state == SCREEN_HOME:
			description_label.text = ""
		elif state == SCREEN_CODE_ENTRY:
			description_label.text = "Введите код турнира и ваше имя"
		else:
			description_label.text = ""


func _set_home_visible(should_show: bool) -> void:
	if home_block:
		home_block.visible = should_show


func _dictionary_string(source: Dictionary, key: String) -> String:
	if source.has(key):
		return str(source[key]).strip_edges()
	return ""


func _dictionary_int(source: Dictionary, key: String) -> int:
	if source.has(key):
		return int(source[key])
	return 0


func _show_error(text: String) -> void:
	if error_label:
		error_label.text = text
		error_label.visible = true
	_set_status("")


func _hide_error() -> void:
	if error_label:
		error_label.visible = false


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _set_loading(loading: bool) -> void:
	if enter_btn:
		enter_btn.disabled = loading
		enter_btn.text = "Подключение..." if loading else "Войти"
	if paste_code_btn:
		paste_code_btn.disabled = loading
	if back_btn:
		back_btn.disabled = loading
	if my_tournaments_btn:
		my_tournaments_btn.disabled = loading
	if new_code_entry_btn:
		new_code_entry_btn.disabled = loading
	if home_back_btn:
		home_back_btn.disabled = loading
	if start_attempt_btn:
		start_attempt_btn.disabled = loading
	if edit_access_btn:
		edit_access_btn.disabled = loading
	if connected_back_btn:
		connected_back_btn.disabled = loading
	if tournament_code_input:
		tournament_code_input.editable = not loading
	if display_name_input:
		display_name_input.editable = not loading
	_set_status("Проверяем турнир..." if loading else "")


func _set_summary_visible(should_show: bool) -> void:
	if summary_block:
		summary_block.visible = should_show


func _set_start_attempt_visible(should_show: bool) -> void:
	if start_attempt_btn:
		start_attempt_btn.visible = should_show


func _set_edit_access_visible(should_show: bool) -> void:
	if edit_access_btn:
		edit_access_btn.visible = should_show


func _set_form_visible(should_show: bool) -> void:
	if form_block:
		form_block.visible = should_show
