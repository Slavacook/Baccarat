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

func get_tip_multiplier(bet_type: String) -> int:
	"""Получить коэффициент для расчета чаевых в зависимости от типа ставки
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		
	Returns:
		Коэффициент: 1 для Player/Banker, 8 для Tie, 11 для Pair
	"""
	match bet_type:
		"Player", "Banker":
			return 1
		"Tie":
			return 8
		"PairPlayer", "PairBanker":
			return 11
		_:
			return 1  # По умолчанию коэффициент 1

func calculate_tip_amount(payout: float, tip_percentage: float, bet_type: String) -> int:
	"""Рассчитать сумму чаевых (публичная функция для тестирования)
	
	Args:
		payout: Размер выплаты (выигрыш)
		tip_percentage: Процент чаевых (например 1.0 для 1%)
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		
	Returns:
		Сумма чаевых (целое число)
	"""
	if payout <= 0:
		return 0
	
	# 1. Рассчитываем базовые чаевые с округлением вверх ДО умножения на коэффициент
	var base_tip = ceil(payout * tip_percentage / 100.0)
	
	# 2. Получаем коэффициент для типа ставки
	var multiplier = get_tip_multiplier(bet_type)
	
	# 3. Умножаем базовые чаевые на коэффициент
	return int(base_tip * multiplier)

func _on_payout_correct(_collected: float, expected: float, bet_type: String, position_index: int):
	"""Обработка правильной выплаты - начисление чаевых как процент от выигрыша гостя
	
	Новая система чаевых:
	1. Базовые чаевые = ceil(payout × процент_чаевых / 100) - округление ДО умножения на коэффициент
	2. Итоговые чаевые = базовые_чаевые × коэффициент_ставки
	3. Коэффициенты: Player/Banker = 1, Tie = 8, Pair = 11
	
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
		var tip_amount = calculate_tip_amount(expected, tip_percentage, bet_type)
		
		# Вычисляем базовые чаевые для логирования
		var base_tip = ceil(expected * tip_percentage / 100.0)
		var multiplier = get_tip_multiplier(bet_type)
		
		SaveManager.instance.add_score(tip_amount)
		update_stats()
		print("💰 Чаевые начислены: выплата=%.0f, базовые=%.0f (%.1f%%), коэффициент=%d, итого=%d" % [expected, base_tip, tip_percentage, multiplier, tip_amount])

# Примечание: _on_action_error, _on_payout_wrong, _on_hint_used - 
# больше не отнимают деньги. За ошибки отнимаются сердца в HeartBar.
