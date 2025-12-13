# res://scripts/StatsManager.gd
# Менеджер статистики - подписан на события EventBus
extends Node

static var instance: StatsManager

var stats_label: Label = null  # Будет установлена из GameController

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	# Подписываемся на события EventBus
	EventBus.action_correct.connect(_on_action_correct)
	EventBus.action_error.connect(_on_action_error)
	EventBus.payout_correct.connect(_on_payout_correct)
	EventBus.payout_wrong.connect(_on_payout_wrong)
	EventBus.hint_used.connect(_on_hint_used)

	print("📊 StatsManager готов! Подписан на EventBus.")

	# Загружаем статистику
	SaveManager.instance.load_data()

# ← Установить Label из GameController
func set_label(label: Label):
	stats_label = label
	update_stats()

# ← Обновить текст статистики
func update_stats():
	if not stats_label:
		return

	var data = SaveManager.instance.get_data()
	var is_survival = SaveManager.instance.load_survival_mode()

	if is_survival:
		# Режим выживания: показываем правильно/ошибки
		var total_errors = data.errors.values().reduce(func(a, b): return a + b, 0) if data.errors.size() > 0 else 0
		stats_label.text = "Правильно: %d | Ошибок: %d" % [data.correct, total_errors]
	else:
		# Обычный режим: показываем очки
		stats_label.text = "Очки: %d" % data.score

# ← Сбросить статистику
func reset():
	SaveManager.instance.reset_stats()
	update_stats()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ EventBus
# ═══════════════════════════════════════════════════════════════════════════

func _on_action_correct(_type: String):
	SaveManager.instance.increment_correct()

	# ← Если обычный режим: +1 очко за правильное действие
	if not SaveManager.instance.load_survival_mode():
		SaveManager.instance.add_score(1)

	update_stats()

func _on_action_error(type: String, _message: String):
	SaveManager.instance.increment_error(type)

	# ← Если обычный режим: -1 очко за ошибку
	if not SaveManager.instance.load_survival_mode():
		var game_over = SaveManager.instance.subtract_score(1)
		if game_over:
			print("🎮 GAME OVER! Очки упали ниже 0")

	update_stats()

func _on_payout_correct(_collected: float, _expected: float):
	SaveManager.instance.increment_correct()
	# ← Очки начисляются в PayoutScene, здесь только счётчик
	update_stats()

func _on_payout_wrong(_collected: float, _expected: float):
	SaveManager.instance.increment_error("payout_wrong")
	
	# ← Если обычный режим (без сердечек, но с очками): -1 очко за ошибку
	if not SaveManager.instance.load_survival_mode():
		var game_over = SaveManager.instance.subtract_score(1)
		if game_over:
			print("🎮 GAME OVER! Очки упали ниже 0")
	
	update_stats()

func _on_hint_used():
	"""Обработчик использования подсказки
	
	В режиме выживания: жизни отнимаются в SurvivalModeUI
	В обычном режиме: отнимаем 5 очков за подсказку
	"""
	# ← Если обычный режим: -5 очков за подсказку
	if not SaveManager.instance.load_survival_mode():
		var game_over = SaveManager.instance.subtract_score(5)
		if game_over:
			print("🎮 GAME OVER! Очки упали ниже 0")
	
	update_stats()
