# res://scripts/training/ui/TrainingInstructionPopup.gd
# ═══════════════════════════════════════════════════════════════════════════
# ПОПАП ИНСТРУКЦИИ ЭТАПА ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════
# Показывает текст правила и кнопку «Начать». Переиспользуется для всех этапов.
# ═══════════════════════════════════════════════════════════════════════════

class_name TrainingInstructionPopup
extends PopupPanel

var instruction_label: Label
var start_button: Button

signal start_button_pressed()

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	instruction_label = get_node_or_null("MarginContainer/VBox/InstructionLabel") as Label
	start_button = get_node_or_null("MarginContainer/VBox/StartButton") as Button
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Настроить попап текстом инструкции.
func setup(instruction_text: String) -> void:
	if instruction_label:
		instruction_label.text = instruction_text

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_start_button_pressed() -> void:
	start_button_pressed.emit()
	hide()
