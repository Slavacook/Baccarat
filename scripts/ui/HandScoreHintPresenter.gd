# res://scripts/ui/HandScoreHintPresenter.gd
# Минимальный presenter для отображения суммы Player/Banker под картами

class_name HandScoreHintPresenter
extends RefCounted

var player_label: Label = null
var banker_label: Label = null

func setup(player_label_ref: Label, banker_label_ref: Label) -> void:
	player_label = player_label_ref
	banker_label = banker_label_ref
	reset()

func update_from_hint_payload(payload: Dictionary) -> void:
	if player_label:
		player_label.text = _build_hand_text(_dict_value(payload, "player"), "Player")
	if banker_label:
		banker_label.text = _build_hand_text(_dict_value(payload, "banker"), "Banker")

func reset() -> void:
	if player_label:
		player_label.text = "—"
	if banker_label:
		banker_label.text = "—"

func _build_hand_text(source: Dictionary, prefix: String) -> String:
	var card_count := int(source.get("card_count", 0))
	if card_count < 2:
		return "—"

	var score := int(source.get("score", 0))
	var is_natural := bool(source.get("is_natural", false))
	var first_line := ""
	if is_natural:
		first_line = "Natural %d" % score
	else:
		first_line = "%s: %d" % [prefix, score]

	var short_zone_title := str(source.get("short_zone_title", "")).strip_edges()
	if short_zone_title.is_empty():
		return first_line

	return "%s\n%s" % [first_line, short_zone_title]

func _dict_value(payload: Dictionary, key: String) -> Dictionary:
	var value: Variant = payload.get(key, {})
	if value is Dictionary:
		return value
	return {}
