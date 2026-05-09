# res://scripts/ui/HandDecisionScalePresenter.gd
# MVP presenter для визуальных шкал решения Player/Banker

class_name HandDecisionScalePresenter
extends RefCounted

signal decision_scales_flow_completed(flow_token: int)

const CELL_COUNT := 10
const PLAYER_SCALE := "player"
const BANKER_SCALE := "banker"
const SCALE_FADE_OUT_DURATION_SEC: float = 0.2
const SCALE_FADE_OUT_STEPS: int = 6

var player_container: Control = null
var banker_container: Control = null
var _player_cells: Array[Dictionary] = []
var _banker_cells: Array[Dictionary] = []
var _player_animation_token: int = 0
var _banker_animation_token: int = 0
var _player_active_index: int = -1
var _banker_active_index: int = -1
var _player_last_target_index: int = -1
var _banker_last_target_index: int = -1
var _player_scale_visible: bool = false
var _banker_scale_visible: bool = false
var _player_visibility_token: int = 0
var _banker_visibility_token: int = 0
var _scale_sequence_token: int = 0
var _scale_flow_token: int = 0
var _pending_flow_operations: int = 0

func setup(player_container_ref: Control, banker_container_ref: Control) -> void:
	player_container = player_container_ref
	banker_container = banker_container_ref

	_player_cells = _build_scale(player_container)
	_banker_cells = _build_scale(banker_container)
	reset()

func update_from_hint_payload(payload: Dictionary) -> Dictionary:
	var player_source := _dict_value(payload, "player")
	var banker_source := _dict_value(payload, "banker")
	var any_natural := bool(player_source.get("is_natural", false)) or bool(banker_source.get("is_natural", false))
	var banker_has_third_card: bool = bool(banker_source.get("has_third_card", false))
	var player_should_show: bool = _should_show_player_scale(player_source, any_natural, banker_has_third_card, "", "")
	var banker_should_show: bool = _should_show_banker_scale(banker_source, any_natural, "", "")
	var player_target_index: int = _resolve_target_index(player_source)
	var banker_target_index: int = _resolve_target_index(banker_source)
	var sequence_token: int = _next_scale_sequence_token()
	var flow_token: int = _next_scale_flow_token()
	var flow_started: bool = false

	if not player_should_show:
		flow_started = _hide_scale(player_container, _player_cells, PLAYER_SCALE, flow_token) or flow_started
	if not banker_should_show:
		flow_started = _hide_scale(banker_container, _banker_cells, BANKER_SCALE, flow_token) or flow_started

	if player_should_show and banker_should_show and not _is_scale_visible(PLAYER_SCALE) and not _is_scale_visible(BANKER_SCALE):
		_register_flow_operation(flow_token)
		flow_started = true
		_run_scale_sequence(player_target_index, banker_target_index, sequence_token, flow_token)
		return {
			"flow_started": true,
			"flow_token": flow_token
		}

	if player_should_show:
		flow_started = _update_scale(player_container, _player_cells, PLAYER_SCALE, player_target_index, flow_token) or flow_started
	if banker_should_show:
		flow_started = _update_scale(banker_container, _banker_cells, BANKER_SCALE, banker_target_index, flow_token) or flow_started

	return {
		"flow_started": flow_started,
		"flow_token": flow_token if flow_started else -1
	}

func reset() -> void:
	_player_animation_token += 1
	_banker_animation_token += 1
	_player_visibility_token += 1
	_banker_visibility_token += 1
	_scale_sequence_token += 1
	_scale_flow_token += 1
	_pending_flow_operations = 0
	_player_active_index = -1
	_banker_active_index = -1
	_player_last_target_index = -1
	_banker_last_target_index = -1
	_player_scale_visible = false
	_banker_scale_visible = false
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

func _update_scale(
	container: Control,
	cells: Array[Dictionary],
	scale_type: String,
	active_index: int,
	flow_token: int
) -> bool:
	if not container:
		return false

	if not _is_scale_visible(scale_type):
		_register_flow_operation(flow_token)
		_show_scale(container, cells, scale_type, active_index, flow_token, true)
		return true

	_prepare_scale_for_show(container, scale_type)
	if active_index == _get_last_target_index(scale_type):
		return false

	_set_last_target_index(scale_type, active_index)
	_set_active_index(cells, scale_type, active_index)
	return false

func _run_scale_sequence(player_target_index: int, banker_target_index: int, sequence_token: int, flow_token: int) -> void:
	if not is_instance_valid(player_container):
		return

	await _show_scale(player_container, _player_cells, PLAYER_SCALE, player_target_index, flow_token, false)

	if not _is_sequence_token_current(sequence_token):
		return
	if not _is_scale_flow_token_current(flow_token):
		return
	if not _is_scale_visible(PLAYER_SCALE):
		return
	if not is_instance_valid(banker_container):
		return

	await _show_scale(banker_container, _banker_cells, BANKER_SCALE, banker_target_index, flow_token, false)

	if not _is_scale_flow_token_current(flow_token):
		return
	_complete_flow_operation(flow_token)

func _show_scale(
	container: Control,
	cells: Array[Dictionary],
	scale_type: String,
	target_index: int,
	flow_token: int,
	complete_on_finish: bool
) -> void:
	if not is_instance_valid(container):
		return

	_prepare_scale_for_show(container, scale_type)
	_mark_scale_visible(scale_type, true)
	_set_last_target_index(scale_type, target_index)

	if not is_instance_valid(container):
		return
	await _start_scale_animation(container, cells, scale_type, target_index)

	if not is_instance_valid(container):
		return
	if not _is_scale_flow_token_current(flow_token):
		return
	if complete_on_finish:
		_complete_flow_operation(flow_token)

func _start_scale_animation(container: Control, cells: Array[Dictionary], scale_type: String, target_index: int) -> void:
	if not is_instance_valid(container):
		return

	var token := _next_animation_token(scale_type)
	_set_active_index(cells, scale_type, 0)

	if not is_instance_valid(container):
		return
	await _animate_scale_to_target(container, cells, scale_type, target_index, token)

func _animate_scale_to_target(
	container: Control,
	cells: Array[Dictionary],
	scale_type: String,
	target_index: int,
	token: int
) -> void:
	if not is_instance_valid(container) or not container.get_tree():
		_set_active_index(cells, scale_type, target_index)
		return

	var sequence: Array[int] = _build_animation_sequence(target_index)
	var total_steps: int = max(sequence.size() - 1, 1)

	for step_index in range(sequence.size()):
		if not _is_animation_token_current(scale_type, token):
			return
		if not is_instance_valid(container):
			return
		if not container.visible:
			return

		var did_change: bool = _set_active_index(cells, scale_type, int(sequence[step_index]))
		if did_change:
			_play_tick_sound()

		if step_index == sequence.size() - 1:
			return

		var progress := float(step_index) / float(total_steps)
		var delay := lerpf(0.03, 0.095, progress)
		if not is_instance_valid(container) or not container.get_tree():
			return
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

func _set_active_index(cells: Array[Dictionary], scale_type: String, active_index: int) -> bool:
	var previous_index: int = _get_last_active_index(scale_type)
	var did_change: bool = previous_index != active_index
	_set_last_active_index(scale_type, active_index)

	for cell in cells:
		var index := int(cell.get("index", -1))
		var panel := cell.get("panel") as PanelContainer
		var zone_color := _get_zone_color(scale_type, index)
		var is_active := index == active_index
		if panel:
			panel.add_theme_stylebox_override("panel", _build_cell_style(zone_color, is_active))

	return did_change

func _next_animation_token(scale_type: String) -> int:
	if scale_type == PLAYER_SCALE:
		_player_animation_token += 1
		return _player_animation_token

	_banker_animation_token += 1
	return _banker_animation_token

func _cancel_animation(scale_type: String) -> void:
	if scale_type == PLAYER_SCALE:
		_player_animation_token += 1
		_player_active_index = -1
		_player_last_target_index = -1
		_player_scale_visible = false
		return

	_banker_animation_token += 1
	_banker_active_index = -1
	_banker_last_target_index = -1
	_banker_scale_visible = false

func _is_animation_token_current(scale_type: String, token: int) -> bool:
	if scale_type == PLAYER_SCALE:
		return token == _player_animation_token
	return token == _banker_animation_token

func _get_last_active_index(scale_type: String) -> int:
	if scale_type == PLAYER_SCALE:
		return _player_active_index
	return _banker_active_index

func _set_last_active_index(scale_type: String, active_index: int) -> void:
	if scale_type == PLAYER_SCALE:
		_player_active_index = active_index
		return
	_banker_active_index = active_index

func _get_last_target_index(scale_type: String) -> int:
	if scale_type == PLAYER_SCALE:
		return _player_last_target_index
	return _banker_last_target_index

func _set_last_target_index(scale_type: String, target_index: int) -> void:
	if scale_type == PLAYER_SCALE:
		_player_last_target_index = target_index
		return
	_banker_last_target_index = target_index

func _is_scale_visible(scale_type: String) -> bool:
	if scale_type == PLAYER_SCALE:
		return _player_scale_visible
	return _banker_scale_visible

func _mark_scale_visible(scale_type: String, visible: bool) -> void:
	if scale_type == PLAYER_SCALE:
		_player_scale_visible = visible
		return
	_banker_scale_visible = visible

func _play_tick_sound() -> void:
	if SoundManager and SoundManager.has_method("play_decision_scale_tick"):
		SoundManager.play_decision_scale_tick()

func _hide_scale(container: Control, cells: Array[Dictionary], scale_type: String, flow_token: int) -> bool:
	if not container:
		return false

	var was_visible := container.visible and _is_scale_visible(scale_type)
	var token := _next_visibility_token(scale_type)
	_cancel_animation(scale_type)
	if not was_visible:
		_reset_scale(container, cells, scale_type)
		return false

	_register_flow_operation(flow_token)
	_fade_out_scale(container, cells, scale_type, token, flow_token)
	return true

func _prepare_scale_for_show(container: Control, scale_type: String) -> void:
	if not is_instance_valid(container):
		return

	_next_visibility_token(scale_type)
	container.visible = true
	_set_container_alpha(container, 1.0)

func _fade_out_scale(
	container: Control,
	cells: Array[Dictionary],
	scale_type: String,
	token: int,
	flow_token: int
) -> void:
	if not is_instance_valid(container) or not container.get_tree():
		_reset_scale(container, cells, scale_type)
		if _is_scale_flow_token_current(flow_token):
			_complete_flow_operation(flow_token)
		return

	var step_delay: float = SCALE_FADE_OUT_DURATION_SEC / float(SCALE_FADE_OUT_STEPS)
	for step in range(1, SCALE_FADE_OUT_STEPS + 1):
		if not is_instance_valid(container) or not container.get_tree():
			return
		await container.get_tree().create_timer(step_delay).timeout
		if not _is_visibility_token_current(scale_type, token):
			return
		if not is_instance_valid(container):
			return
		var alpha: float = 1.0 - (float(step) / float(SCALE_FADE_OUT_STEPS))
		_set_container_alpha(container, alpha)

	if not _is_visibility_token_current(scale_type, token):
		return
	_reset_scale(container, cells, scale_type)
	if not _is_scale_flow_token_current(flow_token):
		return
	_complete_flow_operation(flow_token)

func _next_visibility_token(scale_type: String) -> int:
	if scale_type == PLAYER_SCALE:
		_player_visibility_token += 1
		return _player_visibility_token
	_banker_visibility_token += 1
	return _banker_visibility_token

func _next_scale_sequence_token() -> int:
	_scale_sequence_token += 1
	return _scale_sequence_token

func _is_sequence_token_current(token: int) -> bool:
	return token == _scale_sequence_token

func _next_scale_flow_token() -> int:
	_scale_flow_token += 1
	_pending_flow_operations = 0
	return _scale_flow_token

func _is_scale_flow_token_current(token: int) -> bool:
	return token == _scale_flow_token

func _register_flow_operation(flow_token: int) -> void:
	if not _is_scale_flow_token_current(flow_token):
		return
	_pending_flow_operations += 1

func _complete_flow_operation(flow_token: int) -> void:
	if not _is_scale_flow_token_current(flow_token):
		return
	_pending_flow_operations = maxi(_pending_flow_operations - 1, 0)
	if _pending_flow_operations == 0:
		decision_scales_flow_completed.emit(flow_token)

func _is_visibility_token_current(scale_type: String, token: int) -> bool:
	if scale_type == PLAYER_SCALE:
		return token == _player_visibility_token
	return token == _banker_visibility_token

func _set_container_alpha(container: Control, alpha: float) -> void:
	if not is_instance_valid(container):
		return
	var color := container.modulate
	color.a = alpha
	container.modulate = color

func _reset_scale(container: Control, cells: Array[Dictionary], scale_type: String) -> void:
	if is_instance_valid(container):
		_set_container_alpha(container, 1.0)
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

func _resolve_target_index(source: Dictionary) -> int:
	var active_index: int = int(source.get("scale_position", -1))
	if active_index < 0:
		active_index = int(source.get("decision_score", 0))
	return clampi(active_index, 0, CELL_COUNT - 1)

func _should_show_player_scale(
	player_source: Dictionary,
	any_natural: bool,
	banker_has_third_card: bool,
	_expected_action: String,
	_current_state: String
) -> bool:
	if int(player_source.get("card_count", 0)) < 2:
		return false
	if any_natural:
		return false
	if bool(player_source.get("has_third_card", false)):
		return false
	if banker_has_third_card:
		return false
	return true

func _should_show_banker_scale(
	banker_source: Dictionary,
	any_natural: bool,
	_expected_action: String,
	_current_state: String
) -> bool:
	if int(banker_source.get("card_count", 0)) < 2:
		return false
	if any_natural:
		return false
	if bool(banker_source.get("has_third_card", false)):
		return false
	return true
