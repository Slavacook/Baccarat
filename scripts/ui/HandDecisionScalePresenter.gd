# res://scripts/ui/HandDecisionScalePresenter.gd
# MVP presenter для визуальных шкал решения Player/Banker

class_name HandDecisionScalePresenter
extends RefCounted

const CELL_COUNT := 10
const PLAYER_SCALE := "player"
const BANKER_SCALE := "banker"

var player_container: Control = null
var banker_container: Control = null
var _player_cells: Array[Dictionary] = []
var _banker_cells: Array[Dictionary] = []
var _player_animation_token: int = 0
var _banker_animation_token: int = 0

func setup(player_container_ref: Control, banker_container_ref: Control) -> void:
	player_container = player_container_ref
	banker_container = banker_container_ref

	_player_cells = _build_scale(player_container)
	_banker_cells = _build_scale(banker_container)
	reset()

func update_from_hint_payload(payload: Dictionary) -> void:
	_update_scale(player_container, _player_cells, _dict_value(payload, "player"), PLAYER_SCALE)
	_update_scale(banker_container, _banker_cells, _dict_value(payload, "banker"), BANKER_SCALE)

func reset() -> void:
	_player_animation_token += 1
	_banker_animation_token += 1
	_reset_scale(player_container, _player_cells, PLAYER_SCALE)
	_reset_scale(banker_container, _banker_cells, BANKER_SCALE)

func _build_scale(container: Control) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not container:
		return result

	for child in container.get_children():
		child.queue_free()

	for index in range(CELL_COUNT):
		var cell_panel := PanelContainer.new()
		cell_panel.custom_minimum_size = Vector2(22, 16)
		cell_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var label := Label.new()
		label.text = str(index)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 0.96))

		cell_panel.add_child(label)
		container.add_child(cell_panel)
		result.append({
			"panel": cell_panel,
			"label": label,
			"index": index
		})

	return result

func _update_scale(container: Control, cells: Array[Dictionary], source: Dictionary, scale_type: String) -> void:
	if not container:
		return

	var card_count := int(source.get("card_count", 0))
	if card_count < 2:
		_cancel_animation(scale_type)
		container.visible = false
		return

	container.visible = true
	var active_index := int(source.get("scale_position", -1))
	if active_index < 0:
		active_index = int(source.get("decision_score", 0))
	active_index = clampi(active_index, 0, CELL_COUNT - 1)
	_start_scale_animation(container, cells, scale_type, active_index)

func _start_scale_animation(container: Control, cells: Array[Dictionary], scale_type: String, target_index: int) -> void:
	var token := _next_animation_token(scale_type)
	_set_active_index(cells, scale_type, 0)
	_animate_scale_to_target(container, cells, scale_type, target_index, token)

func _animate_scale_to_target(
	container: Control,
	cells: Array[Dictionary],
	scale_type: String,
	target_index: int,
	token: int
) -> void:
	if not container or not container.get_tree():
		_set_active_index(cells, scale_type, target_index)
		return

	var sequence: Array[int] = _build_animation_sequence(target_index)
	var total_steps: int = max(sequence.size() - 1, 1)

	for step_index in range(sequence.size()):
		if not _is_animation_token_current(scale_type, token):
			return
		if not container.visible:
			return

		_set_active_index(cells, scale_type, int(sequence[step_index]))

		if step_index == sequence.size() - 1:
			return

		var progress := float(step_index) / float(total_steps)
		var delay := lerpf(0.02, 0.075, progress)
		await container.get_tree().create_timer(delay).timeout

func _build_animation_sequence(target_index: int) -> Array[int]:
	var sequence: Array[int] = []
	_append_range(sequence, 0, 9, 1)
	_append_range(sequence, 8, 0, -1)
	_append_range(sequence, 1, 9, 1)
	_append_range(sequence, 8, 0, -1)
	if target_index > 0:
		_append_range(sequence, 1, target_index, 1)
	return sequence

func _append_range(sequence: Array[int], start_index: int, end_index: int, step: int) -> void:
	if step == 0:
		return

	var index := start_index
	while true:
		sequence.append(index)
		if index == end_index:
			return
		index += step

func _set_active_index(cells: Array[Dictionary], scale_type: String, active_index: int) -> void:
	for cell in cells:
		var index := int(cell.get("index", -1))
		var panel := cell.get("panel") as PanelContainer
		var zone_color := _get_zone_color(scale_type, index)
		var is_active := index == active_index
		if panel:
			panel.add_theme_stylebox_override("panel", _build_cell_style(zone_color, is_active))

func _next_animation_token(scale_type: String) -> int:
	if scale_type == PLAYER_SCALE:
		_player_animation_token += 1
		return _player_animation_token

	_banker_animation_token += 1
	return _banker_animation_token

func _cancel_animation(scale_type: String) -> void:
	if scale_type == PLAYER_SCALE:
		_player_animation_token += 1
		return

	_banker_animation_token += 1

func _is_animation_token_current(scale_type: String, token: int) -> bool:
	if scale_type == PLAYER_SCALE:
		return token == _player_animation_token
	return token == _banker_animation_token

func _reset_scale(container: Control, cells: Array[Dictionary], scale_type: String) -> void:
	if container:
		container.visible = false

	for cell in cells:
		var index := int(cell.get("index", -1))
		var panel := cell.get("panel") as PanelContainer
		if panel:
			panel.add_theme_stylebox_override("panel", _build_cell_style(_get_zone_color(scale_type, index), false))

func _get_zone_color(scale_type: String, index: int) -> Color:
	if scale_type == PLAYER_SCALE:
		if index <= 5:
			return Color(0.13, 0.44, 0.19, 0.92)
		if index <= 7:
			return Color(0.57, 0.18, 0.18, 0.92)
		return Color(0.62, 0.48, 0.12, 0.96)

	if index <= 2:
		return Color(0.13, 0.44, 0.19, 0.92)
	if index <= 6:
		return Color(0.17, 0.34, 0.60, 0.92)
	if index == 7:
		return Color(0.57, 0.18, 0.18, 0.92)
	return Color(0.62, 0.48, 0.12, 0.96)

func _build_cell_style(base_color: Color, is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base_color.lerp(Color(1, 1, 1, 1), 0.14) if is_active else base_color
	style.border_width_left = 2 if is_active else 1
	style.border_width_top = 2 if is_active else 1
	style.border_width_right = 2 if is_active else 1
	style.border_width_bottom = 2 if is_active else 1
	style.border_color = Color(0.97, 0.89, 0.70, 0.98) if is_active else Color(0.04, 0.05, 0.07, 0.75)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func _dict_value(payload: Dictionary, key: String) -> Dictionary:
	var value: Variant = payload.get(key, {})
	if value is Dictionary:
		return value
	return {}
