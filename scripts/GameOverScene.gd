# res://scripts/GameOverScene.gd
# Overlay для экрана Game Over
# Отображается поверх Game.tscn (CanvasLayer)

extends CanvasLayer

@onready var rounds_label: Label = %RoundsLabel
@onready var restart_button: Button = %RestartButton

func _ready():
	restart_button.pressed.connect(_on_restart_pressed)
	hide()  # Скрываем по умолчанию

func show_game_over(rounds_survived: int):
	rounds_label.text = "Вы прошли %d раундов!" % rounds_survived
	show()

func show_game_over_score(final_score: int):
	rounds_label.text = "GAME OVER!\nИтоговый счёт: %d" % final_score
	show()

func _on_restart_pressed():
	# Закрываем overlay и переходим на главную сцену
	hide()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

