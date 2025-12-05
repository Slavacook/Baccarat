# res://scripts/Toast.gd
extends PanelContainer

@onready var label: Label = $MarginContainer/Label

func _ready():
	# ← Непрозрачная подложка для тоста
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.15, 0.15, 0.2, 0.8)  # Тёмный, непрозрачный
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.4, 0.4, 0.5)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", stylebox)

func show_message(text: String, duration: float = 2.5, on_finished: Callable = Callable()):
	label.text = text
	var tween = create_tween().set_parallel(false)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).from(0.0)
	tween.tween_interval(duration)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

	# ← Если передан callback - вызываем его (возврат в пул)
	# ← Если нет - удаляем узел (старое поведение)
	if on_finished.is_valid():
		tween.tween_callback(on_finished)
	else:
		tween.tween_callback(queue_free)
