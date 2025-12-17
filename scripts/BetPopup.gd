# res://scripts/BetPopup.gd
# Попап для ввода ставки (устаревший компонент, оставлен для совместимости)

extends PopupPanel

# UI узлы
@onready var bet_label: Label = $MarginContainer/VBoxContainer/BetLabel
@onready var bet_input: LineEdit = $MarginContainer/VBoxContainer/BetInput
@onready var confirm_button: Button = $MarginContainer/VBoxContainer/ConfirmButton

# Сигнал подтверждения ставки
signal bet_confirmed(amount: int)

func _ready():
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	if bet_label:
		bet_label.text = "Введите ставку:"
	
	if confirm_button:
		confirm_button.text = "OK"

func _on_confirm_pressed():
	if bet_input:
		var amount = bet_input.text.to_int()
		bet_confirmed.emit(amount)
		hide()

func open_popup(default_value: int = 0):
	if bet_input:
		bet_input.text = str(default_value)
	popup_centered()
