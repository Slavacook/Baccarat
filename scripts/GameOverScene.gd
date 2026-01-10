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
	# Устанавливаем контекст Game Over
	InputContextManager.set_context(InputContextManager.InputContext.GAME_OVER)
	
	rounds_label.text = "Вы прошли %d раундов!" % rounds_survived
	show()

func show_game_over_score(final_score: int):
	# Устанавливаем контекст Game Over
	InputContextManager.set_context(InputContextManager.InputContext.GAME_OVER)
	
	rounds_label.text = "GAME OVER!\nИтоговый счёт: %d" % final_score
	show()

func _on_restart_pressed():
	# Возвращаем контекст игры (новый раунд начнется)
	InputContextManager.set_context(InputContextManager.InputContext.GAME)
	
	# ═══════════════════════════════════════════════════════════════════════
	# СБРОС ВСЕХ ДАННЫХ ПЕРЕД СМЕНОЙ СЦЕНЫ
	# ═══════════════════════════════════════════════════════════════════════
	
	# 1. Сбрасываем чаевые (ВАЖНО: до emit, чтобы GuestProgressionManager увидел 0)
	if SaveManager and SaveManager.instance:
		SaveManager.instance.reset_stats()
		print("💰 Чаевые сброшены при рестарте из GameOverScene: 0")
	
	# 2. Вызываем restart_game() через GameController, если он доступен
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_method("_on_restart_game"):
		game_controller._on_restart_game()
		print("🔄 Вызван restart_game() через GameController")
	else:
		# Фолбэк: эмитим событие рестарта напрямую
		# GuestProgressionManager обработает это и сбросит гостей
		EventBus.game_restarted.emit()
		print("🔄 Вызван EventBus.game_restarted.emit() напрямую")
	
	# Закрываем overlay и переходим на главную сцену
	hide()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _unhandled_input(event: InputEvent) -> void:
	"""Обработка клавиатурного ввода"""
	# Проверяем контекст (работаем только в контексте GAME_OVER)
	if not InputContextManager.can_handle(InputContextManager.InputContext.GAME_OVER):
		return
	
	# Обрабатываем только когда overlay видим
	if not visible:
		return
	
	if not InputContextManager.is_valid_key_event(event):
		return
	
	var key_event = event as InputEventKey
	if key_event.keycode == KEY_SPACE:
		# При Game Over нажатие пробела → рестарт игры
		get_viewport().set_input_as_handled()
		_on_restart_pressed()

