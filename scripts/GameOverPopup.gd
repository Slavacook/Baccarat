# res://scripts/GameOverPopup.gd
extends PopupPanel

signal restart_game()

@onready var rounds_label: Label = %RoundsLabel
@onready var restart_button: Button = %RestartButton

func _ready():
	restart_button.pressed.connect(_on_restart_pressed)

func show_game_over(rounds_survived: int):
	rounds_label.text = "Вы прошли %d раундов!" % rounds_survived
	popup_centered()

func show_game_over_score(final_score: int):
	rounds_label.text = "GAME OVER!\nИтоговый счёт: %d" % final_score
	popup_centered()

func _on_restart_pressed():
	hide()
	restart_game.emit()
