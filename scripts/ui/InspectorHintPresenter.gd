# res://scripts/ui/InspectorHintPresenter.gd
# Минимальный presenter для постоянной верхней строки "Инспектор"

class_name InspectorHintPresenter
extends RefCounted

var panel: Control = null
var label: Label = null

func setup(panel_ref: Control, label_ref: Label) -> void:
	panel = panel_ref
	label = label_ref
	reset()

func update_from_hint_payload(payload: Dictionary) -> void:
	var inspector := _dict_value(payload, "inspector")
	var short_message := str(inspector.get("short_message", "")).strip_edges()

	if short_message.is_empty():
		reset()
		return

	if label:
		label.text = short_message
	if panel:
		panel.visible = true

func reset() -> void:
	if label:
		label.text = ""
	if panel:
		panel.visible = false

func _dict_value(payload: Dictionary, key: String) -> Dictionary:
	var value: Variant = payload.get(key, {})
	if value is Dictionary:
		return value
	return {}
