# res://scripts/SurvivalModeUI.gd
extends Control

signal game_over(rounds_survived: int)

# TextureRect вместо Label!
@onready var hearts: Array[TextureRect] = [
	%Heart1, %Heart2, %Heart3, %Heart4, %Heart5, %Heart6, %Heart7
]

const MAX_LIVES = 7
var current_lives: int = MAX_LIVES
var is_active: bool = false

var heart_full = preload("res://assets/ui/heart.png")
var heart_empty = preload("res://assets/ui/heart_empty.png")

func _ready():
	hide()  # Скрыто по умолчанию

# ← Активировать режим выживания
func activate():
	if is_active:
		# Уже активен - НЕ сбрасываем жизни, просто показываем
		show()
		print("♻️  Режим выживания уже активен, жизней: ", current_lives)
		return

	is_active = true
	current_lives = MAX_LIVES
	_update_hearts()
	show()
	print("Режим выживания активирован! Жизней: ", current_lives)

# ← Деактивировать режим выживания
func deactivate():
	is_active = false
	hide()
	print("Режим выживания деактивирован")

# ← Потерять жизнь при ошибке
func lose_life():
	if not is_active:
		return

	current_lives -= 1
	print("Жизнь потеряна! Осталось: ", current_lives)

	_update_hearts()
	_play_damage_animation()

	if current_lives <= 0:
		_trigger_game_over()

# ← Обновить визуальное отображение сердечек
func _update_hearts():
	for i in range(MAX_LIVES):
		if i < current_lives:
			hearts[i].texture = heart_full  # Полное сердечко
		else:
			hearts[i].texture = heart_empty  # Пустое сердечко

# ← Анимация потери жизни
func _play_damage_animation():
	var tween = create_tween()
	tween.set_parallel(true)

	# Все сердечки мигают
	for heart in hearts:
		tween.tween_property(heart, "modulate", Color(1, 0.3, 0.3), 0.1)

	tween.chain().set_parallel(true)
	for heart in hearts:
		tween.tween_property(heart, "modulate", Color.WHITE, 0.1)

# ← Триггер окончания игры
func _trigger_game_over():
	is_active = false
	print("GAME OVER! Режим выживания завершён")
	game_over.emit(0)  # 0 пока, GameController передаст реальное значение

# ← Сбросить жизни (для начала новой игры)
func reset():
	current_lives = MAX_LIVES
	_update_hearts()

# ← Установить количество жизней (для синхронизации из PayoutScene)
func set_lives(lives: int):
	current_lives = clamp(lives, 0, MAX_LIVES)
	_update_hearts()
	print("♻️  SurvivalModeUI: установлено жизней: %d" % current_lives)
