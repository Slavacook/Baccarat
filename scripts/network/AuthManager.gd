## Менеджер авторизации — хранит токены, сохраняет/загружает из файла.
class_name AuthManager
extends Node

# ═══════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════

var access_token: String = ""
var refresh_token: String = ""
var user_data: Dictionary = {}

const SAVE_PATH = "user://auth_save.json"

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal login_succeeded(user: Dictionary)
signal login_failed(error: String)
signal logout()

# ═══════════════════════════════════════════════════════════════
# АВТОЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_tokens()


# ═══════════════════════════════════════════════════════════════
# СОХРАНЕНИЕ / ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════

func save_tokens(at: String, rt: String, user: Dictionary) -> void:
	access_token = at
	refresh_token = rt
	user_data = user

	var save_data = {
		"access_token": at,
		"refresh_token": rt,
		"user_data": user
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

	login_succeeded.emit(user)


func _load_tokens() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var json_text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_text)
	if data == null:
		return false

	access_token = data.get("access_token", "")
	refresh_token = data.get("refresh_token", "")
	user_data = data.get("user_data", {})

	return access_token != ""


func clear_tokens() -> void:
	access_token = ""
	refresh_token = ""
	user_data = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	logout.emit()


# ═══════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ
# ═══════════════════════════════════════════════════════════════

func get_role() -> String:
	return user_data.get("role", "")


func is_trainer() -> bool:
	return get_role() == "trainer"


func is_dealer() -> bool:
	return get_role() == "dealer"


func get_display_name() -> String:
	if is_trainer():
		return user_data.get("full_name", "Тренер")
	return user_data.get("display_name", "Дилер")


func get_room_code() -> String:
	return user_data.get("room_code", "")
