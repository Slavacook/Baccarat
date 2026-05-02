## Экран входа в турнир по коду без запуска игры.
extends Control

const MAIN_MENU_SCENE_PATH := "res://scenes/StartScreen.tscn"
const TOURNAMENT_CODE_ALLOWED_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const TournamentAccessStoreScript = preload("res://scripts/network/TournamentAccessStore.gd")

var tournament_code_input: LineEdit
var display_name_input: LineEdit
var enter_btn: Button
var back_btn: Button
var error_label: Label
var status_label: Label
var summary_block: Control
var summary_title_value: Label
var summary_code_value: Label
var summary_status_value: Label
var summary_rules_value: Label
var summary_name_value: Label

var _api_service = null
var _tournament_access_store: Node = null


func _ready() -> void:
	tournament_code_input = find_child("TournamentCodeInput", true, false)
	display_name_input = find_child("DisplayNameInput", true, false)
	enter_btn = find_child("EnterBtn", true, false)
	back_btn = find_child("BackBtn", true, false)
	error_label = find_child("ErrorLabel", true, false)
	status_label = find_child("StatusLabel", true, false)
	summary_block = find_child("SummaryBlock", true, false)
	summary_title_value = find_child("SummaryTitleValue", true, false)
	summary_code_value = find_child("SummaryCodeValue", true, false)
	summary_status_value = find_child("SummaryStatusValue", true, false)
	summary_rules_value = find_child("SummaryRulesValue", true, false)
	summary_name_value = find_child("SummaryNameValue", true, false)

	_api_service = _find_api_service()
	_tournament_access_store = TournamentAccessStoreScript.new()
	_tournament_access_store.name = "TournamentAccessStore_Local"
	add_child(_tournament_access_store)

	if enter_btn and not enter_btn.pressed.is_connected(_on_enter_pressed):
		enter_btn.pressed.connect(_on_enter_pressed)
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if tournament_code_input and not tournament_code_input.text_changed.is_connected(_on_tournament_code_changed):
		tournament_code_input.text_changed.connect(_on_tournament_code_changed)
	if display_name_input and not display_name_input.text_changed.is_connected(_on_input_changed):
		display_name_input.text_changed.connect(_on_input_changed)

	_hide_error()
	_set_status("")
	_set_summary_visible(false)


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

	_show_summary(saved as Dictionary)
	_set_status("Вход в турнир сохранён")


func _on_back_pressed() -> void:
	if get_tree():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_tournament_code_changed(text: String) -> void:
	_on_input_changed("")
	var formatted := _format_tournament_code(text)
	if formatted == text:
		return
	tournament_code_input.text = formatted
	tournament_code_input.caret_column = formatted.length()


func _on_input_changed(_text: String) -> void:
	_hide_error()
	_set_status("")
	_set_summary_visible(false)


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
	var tournament := _dictionary_or_empty(saved_access.get("tournament", {}))
	var participant := _dictionary_or_empty(saved_access.get("participant", {}))

	if summary_title_value:
		summary_title_value.text = str(tournament.get("title", "")).strip_edges()
	if summary_code_value:
		summary_code_value.text = str(tournament.get("code", "")).strip_edges()
	if summary_status_value:
		summary_status_value.text = _format_tournament_status(str(tournament.get("status", "")).strip_edges())
	if summary_rules_value:
		summary_rules_value.text = _format_tournament_rules(tournament)
	if summary_name_value:
		summary_name_value.text = str(participant.get("display_name", "")).strip_edges()

	_set_summary_visible(true)


func _format_tournament_status(status: String) -> String:
	match status:
		"active":
			return "Активен"
		"closed":
			return "Закрыт"
	return status


func _format_tournament_rules(tournament: Dictionary) -> String:
	var rounds := int(tournament.get("max_rounds", 0))
	var seconds := int(tournament.get("attempt_duration_seconds", 0))
	var minutes := int(seconds / 60)
	return "%d раздач / %d мин" % [rounds, minutes]


func _find_api_service():
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService")
	return get_node_or_null("/root/ApiService")


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


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
	if back_btn:
		back_btn.disabled = loading
	if tournament_code_input:
		tournament_code_input.editable = not loading
	if display_name_input:
		display_name_input.editable = not loading
	_set_status("Проверяем турнир..." if loading else "")


func _set_summary_visible(visible: bool) -> void:
	if summary_block:
		summary_block.visible = visible
