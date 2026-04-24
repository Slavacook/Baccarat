# res://scripts/training/ui/TrainingStageCompletePopup.gd
# ═══════════════════════════════════════════════════════════════════════════
# ПОПАП ЗАВЕРШЕНИЯ ЭТАПА ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════
# Показывает прогресс 100% и кнопки «Повторить» / «Продолжить».
# На последнем этапе кнопка «Продолжить» заменяется на «Завершить обучение».
# ═══════════════════════════════════════════════════════════════════════════

class_name TrainingStageCompletePopup
extends PopupPanel

var title_label: Label
var progress_label: Label
var repeat_button: Button
var continue_button: Button

signal repeat_pressed()
signal continue_pressed()

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	title_label = get_node_or_null("MarginContainer/VBox/TitleLabel") as Label
	progress_label = get_node_or_null("MarginContainer/VBox/ProgressLabel") as Label
	repeat_button = get_node_or_null("MarginContainer/VBox/ButtonsContainer/RepeatButton") as Button
	continue_button = get_node_or_null("MarginContainer/VBox/ButtonsContainer/ContinueButton") as Button
	if repeat_button:
		repeat_button.pressed.connect(_on_repeat_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Настроить попап: прогресс (0.0–1.0) и флаг последнего этапа.
func setup(progress: float, is_last_stage: bool = false) -> void:
	if progress_label:
		progress_label.text = "Прогресс: %d%%" % int(round(progress * 100.0))
	if continue_button:
		if is_last_stage:
			continue_button.text = "Завершить обучение"
		else:
			continue_button.text = "Продолжить"

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_repeat_pressed() -> void:
	repeat_pressed.emit()
	hide()

func _on_continue_pressed() -> void:
	continue_pressed.emit()
	hide()
