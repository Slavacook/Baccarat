# res://scripts/ui/StopHintPresenter.gd
# Минимальный presenter для отдельной панели мгновенного STOP-предупреждения

class_name StopHintPresenter
extends RefCounted

const STOP_TEXT := "СТОП"

var panel: Control = null
var label: Label = null

func setup(panel_ref: Control, label_ref: Label) -> void:
	panel = panel_ref
	label = label_ref
	reset()

func show_stop() -> void:
	if label:
		label.text = STOP_TEXT
	if panel:
		panel.visible = true

func hide_stop() -> void:
	if panel:
		panel.visible = false

func reset() -> void:
	if label:
		label.text = STOP_TEXT
	hide_stop()
