# res://scripts/training/ui/TrainingProgressBar.gd
# ═══════════════════════════════════════════════════════════════════════════
# ШКАЛА ПРОГРЕССА ОБУЧЕНИЯ (0–100%)
# ═══════════════════════════════════════════════════════════════════════════
# Полоса прогресса с плавной анимацией и легендой зон правил:
# 🟢 0–2 (всегда нужна карта), 🟣 3–6 (зависит), 🔴 7–9 (никогда).
# ═══════════════════════════════════════════════════════════════════════════

class_name TrainingProgressBar
extends Control

## Полоса заполнения (дочерний узел ProgressBar)
var progress_bar: ProgressBar

## Подпись с процентом (опционально)
var percent_label: Label

## Цветные зоны-легенда (0–2, 3–6, 7–9)
var green_zone: ColorRect
var purple_zone: ColorRect
var red_zone: ColorRect

## Какая зона сейчас подсвечена
var highlighted_zone: ColorRect = null

const TWEEN_DURATION: float = 0.3
const HIGHLIGHT_MODULATE: Color = Color(1.25, 1.25, 1.25)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	progress_bar = get_node_or_null("VBox/ProgressBar") as ProgressBar
	percent_label = get_node_or_null("VBox/PercentLabel") as Label
	var zones: Node = get_node_or_null("VBox/ZonesContainer")
	if zones:
		green_zone = zones.get_node_or_null("GreenZone") as ColorRect
		purple_zone = zones.get_node_or_null("PurpleZone") as ColorRect
		red_zone = zones.get_node_or_null("RedZone") as ColorRect
	if progress_bar:
		progress_bar.min_value = 0.0
		progress_bar.max_value = 100.0
		progress_bar.value = 0.0
	_update_percent_label(0.0)

# ═══════════════════════════════════════════════════════════════════════════
# ПРОГРЕСС
# ═══════════════════════════════════════════════════════════════════════════

## Обновить прогресс (0.0–1.0) с плавной анимацией.
func update_progress(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	var target_value: float = value * 100.0
	if progress_bar:
		var tween: Tween = create_tween()
		tween.tween_property(progress_bar, "value", target_value, TWEEN_DURATION)
		tween.tween_callback(_update_percent_label.bind(value))
	else:
		_update_percent_label(value)

func _update_percent_label(normalized: float) -> void:
	if percent_label:
		percent_label.text = "%d%%" % int(round(normalized * 100.0))

# ═══════════════════════════════════════════════════════════════════════════
# ПОДСВЕТКА ЗОН
# ═══════════════════════════════════════════════════════════════════════════

## Подсветить зону легенды: "green", "purple", "red".
func highlight_zone(zone_type: String) -> void:
	if highlighted_zone:
		highlighted_zone.modulate = Color.WHITE
		highlighted_zone = null
	match zone_type:
		"green":
			highlighted_zone = green_zone
		"purple":
			highlighted_zone = purple_zone
		"red":
			highlighted_zone = red_zone
	if highlighted_zone:
		highlighted_zone.modulate = HIGHLIGHT_MODULATE

## Сбросить подсветку всех зон.
func clear_highlight() -> void:
	if highlighted_zone:
		highlighted_zone.modulate = Color.WHITE
		highlighted_zone = null

## Сбросить прогресс на 0.
func reset_progress() -> void:
	if progress_bar:
		progress_bar.value = 0.0
	_update_percent_label(0.0)
	clear_highlight()
