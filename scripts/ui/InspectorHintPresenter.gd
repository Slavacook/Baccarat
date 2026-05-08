# res://scripts/ui/InspectorHintPresenter.gd
# Минимальный presenter для постоянной верхней строки "Инспектор"

class_name InspectorHintPresenter
extends RefCounted

const INSPECTOR_HINT_DELAY_SEC: float = 5.0
const INSPECTOR_FINAL_HINT_DELAY_SEC: float = 15.0

var panel: Control = null
var label: Label = null
var _show_token: int = 0

func setup(panel_ref: Control, label_ref: Label) -> void:
	panel = panel_ref
	label = label_ref
	reset()

func update_from_hint_payload(payload: Dictionary) -> void:
	var inspector := _dict_value(payload, "inspector")
	var short_message := str(inspector.get("short_message", "")).strip_edges()
	var final_message := str(inspector.get("final_message", "")).strip_edges()

	if short_message.is_empty() and final_message.is_empty():
		reset()
		return

	var token: int = _next_show_token()
	_hide_panel()

	if not panel or not label:
		return
	if not panel.get_tree():
		return

	if not short_message.is_empty():
		await panel.get_tree().create_timer(INSPECTOR_HINT_DELAY_SEC).timeout

		if token != _show_token:
			return
		if not panel or not label:
			return

		label.text = short_message
		panel.visible = true

	if final_message.is_empty():
		return

	var extra_delay: float = INSPECTOR_FINAL_HINT_DELAY_SEC - INSPECTOR_HINT_DELAY_SEC
	if extra_delay > 0.0:
		await panel.get_tree().create_timer(extra_delay).timeout

	if token != _show_token:
		return
	if not panel or not label:
		return

	label.text = final_message
	panel.visible = true

func reset() -> void:
	_show_token += 1
	_hide_panel()

func _next_show_token() -> int:
	_show_token += 1
	return _show_token

func _hide_panel() -> void:
	if label:
		label.text = ""
	if panel:
		panel.visible = false

func _dict_value(payload: Dictionary, key: String) -> Dictionary:
	var value: Variant = payload.get(key, {})
	if value is Dictionary:
		return value
	return {}
