extends Node2D
class_name FlipCard

@onready var flip_anim: AnimatedSprite2D = $AnimatedSprite2D
# Убираем flip_sound и flip_sounds - теперь используем SoundManager

func _ready():
	visible = false
	flip_anim.connect("animation_finished", Callable(self, "_hide_after_flip"))
	
func play_flip():
	visible = true   # Показать FlipCard перед анимацией
	flip_anim.frame = 0
	flip_anim.play("flip_card")
	# Используем SoundManager вместо прямого воспроизведения
	if SoundManager:
		SoundManager.play_flip_sound()

func _hide_after_flip():
	visible = false  # FlipCard исчезает сразу после flip
