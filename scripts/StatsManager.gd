# res://scripts/StatsManager.gd
# Менеджер статистики - подписан на события EventBus
# Отвечает за накопление денег (очков) за правильные действия и отображение на главном экране
extends Node

static var instance: StatsManager

var stats_label: Label = null  # Отображение денег на главном экране

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	# Подписываемся на события EventBus
	EventBus.action_correct.connect(_on_action_correct)
	EventBus.payout_correct.connect(_on_payout_correct)
	# Ошибки больше не отнимают деньги (за ошибки отнимаются сердца в HeartBar)

	print("📊 StatsManager готов! Подписан на EventBus (только правильные действия).")

	# Сбрасываем чаевые на 0 при старте игры
	SaveManager.instance.score = 0
	SaveManager.instance.save_data()
	print("💰 Чаевые сброшены на 0 при старте")

# ← Установить Label из GameController
func set_label(label: Label):
	stats_label = label
	update_stats()

# ← Обновить текст статистики (деньги)
func update_stats():
	if not stats_label:
		return
	
	var money = SaveManager.instance.score
	stats_label.text = "Чаевые: %d" % money
	stats_label.visible = true

# ← Сбросить статистику
func reset():
	SaveManager.instance.reset_stats()
	update_stats()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ EventBus
# ═══════════════════════════════════════════════════════════════════════════

func _on_action_correct(_type: String):
	"""Правильное действие (третья карта, маркер) → +1 деньги"""
	SaveManager.instance.add_score(1)
	update_stats()

func _on_payout_correct(_collected: float, _expected: float):
	"""Правильная выплата → +1 деньги"""
	SaveManager.instance.add_score(1)
	update_stats()

# Примечание: _on_action_error, _on_payout_wrong, _on_hint_used - 
# больше не отнимают деньги. За ошибки отнимаются сердца в HeartBar.
