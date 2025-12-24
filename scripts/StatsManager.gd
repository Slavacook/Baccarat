# res://scripts/StatsManager.gd
# Менеджер статистики - подписан на события EventBus
# Отвечает за накопление денег (чаевых) как процент от выигрыша гостя
extends Node

static var instance: StatsManager

var stats_label: Label = null  # Отображение денег на главном экране

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	# Подписываемся на события EventBus (только payout_correct для чаевых)
	EventBus.payout_correct.connect(_on_payout_correct)
	# Ошибки больше не отнимают деньги (за ошибки отнимаются сердца в HeartBar)

	print("📊 StatsManager готов! Подписан на EventBus (только payout_correct для чаевых).")

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

func _on_payout_correct(collected: float, expected: float, bet_type: String, position_index: int):
	"""Обработка правильной выплаты - начисление чаевых как процент от выигрыша гостя
	
	Args:
		collected: Собранная сумма (не используется)
		expected: Ожидаемая выплата (размер выигрыша)
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		position_index: Индекс позиции ставки (для определения гостевых ставок)
	"""
	# Проверяем, является ли ставка гостевой
	if bet_type.is_empty() or position_index < 0:
		# Нет информации о ставке - пропускаем (старая логика для обратной совместимости)
		return
	
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	if sector < 1 or sector > 6:
		# Не гостевые ставки - чаевые не начисляем
		return
	
	# Это гостевая ставка и есть выигрыш - начисляем чаевые
	if expected > 0:
		var tip_percentage = SaveManager.instance.load_tip_percentage()  # Например 1.0 для 1%
		var tip_amount = ceil(expected * tip_percentage / 100.0)  # Округление вверх
		
		SaveManager.instance.add_score(int(tip_amount))
		update_stats()
		print("💰 Чаевые начислены: %.0f * %.1f%% = %d" % [expected, tip_percentage, int(tip_amount)])

# Примечание: _on_action_error, _on_payout_wrong, _on_hint_used - 
# больше не отнимают деньги. За ошибки отнимаются сердца в HeartBar.
