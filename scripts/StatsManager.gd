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

func _on_payout_correct(_collected: float, expected: float, bet_type: String, position_index: int):
	"""Обработка правильной выплаты - начисление чаевых как процент от выигрыша гостя
	
	Использует TipCalculator для расчета чаевых с учетом терпения гостя.
	Добавляет задержку 0.5 сек перед начислением чаевых.
	
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
	
	# Это гостевая ставка и есть выигрыш - начисляем чаевые с задержкой
	if expected > 0:
		_process_tip_with_delay(expected, bet_type, sector)

func _process_tip_with_delay(expected: float, bet_type: String, guest_id: int) -> void:
	"""Обработать начисление чаевых с задержкой 0.5 сек
	
	Args:
		expected: Ожидаемая выплата (размер выигрыша)
		bet_type: Тип ставки
		guest_id: ID гостя (сектор)
	"""
	# Задержка 1.5 сек перед начислением чаевых
	await get_tree().create_timer(1.5).timeout
	
	# Используем TipCalculator для расчета чаевых с учетом терпения
	var tip_amount = TipCalculator.calculate_tip(expected, bet_type, guest_id)
	
	if tip_amount > 0:
		SaveManager.instance.add_score(tip_amount)
		update_stats()
		
		# Эмитим событие для синхронизации оповещения и звука
		EventBus.tip_received.emit(tip_amount)
		
		# Логирование для отладки
		var patience = GuestStatsManager.get_guest_patience(guest_id)
		var base_percentage = SaveManager.instance.load_tip_percentage()
		var effective_percentage = base_percentage * (float(patience) / 100.0)  # Новая формула: 100% терпения = полный чай
		var multiplier = TipCalculator.get_tip_multiplier(bet_type)
		
		print("💰 Чаевые начислены гостю %d: выплата=%.0f, базовый процент=%.1f%%, терпение=%d%%, эффективный=%.2f%%, коэффициент=%d, итого=%d" % [
			guest_id, expected, base_percentage, patience, effective_percentage, multiplier, tip_amount
		])

func apply_penalty_with_delay(penalty_amount: int) -> void:
	"""Применить штраф на чаевые с задержкой 0.7 сек
	
	Args:
		penalty_amount: Сумма штрафа
	"""
	if penalty_amount <= 0:
		return
	
	# Задержка 1.5 сек перед применением штрафа
	await get_tree().create_timer(0.7).timeout
	
	var tips_before = SaveManager.instance.score
	SaveManager.instance.subtract_score(penalty_amount)
	var tips_after = SaveManager.instance.score
	update_stats()
	
	# Эмитим событие для синхронизации оповещения и звука
	EventBus.penalty_applied.emit(penalty_amount)
	
	DebugLogger.log("  💰 Штраф применен: чаевые %d → %d (-%d)" % [tips_before, tips_after, penalty_amount])

# Примечание: _on_action_error, _on_payout_wrong, _on_hint_used - 
# больше не отнимают деньги. За ошибки отнимаются сердца в HeartBar.
