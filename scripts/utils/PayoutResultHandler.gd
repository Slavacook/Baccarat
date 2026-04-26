# res://scripts/utils/PayoutResultHandler.gd
# Обработчик результатов выплат
# Инкапсулирует логику обработки правильных/неправильных выплат
# Extract Class - извлечено из GameController

extends RefCounted
class_name PayoutResultHandler

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются через dependency injection)
# ═══════════════════════════════════════════════════════════════════════════

var bet_collection_manager: BetCollectionPhaseManager = null
var chip_visual_manager: ChipVisualManager = null
var payout_queue_manager: PayoutQueueManager = null
var ui_manager: UIManager = null

# Callback для обновления баланса гостя (делегируется в GameController)
var update_guest_balance_callback: Callable = Callable()

# Callback для обновления видимости фишек (делегируется в GameController)
var update_chip_visibility_callback: Callable = Callable()

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	p_bet_collection_manager: BetCollectionPhaseManager = null,
	p_chip_visual_manager: ChipVisualManager = null,
	p_payout_queue_manager: PayoutQueueManager = null,
	p_ui_manager: UIManager = null
):
	bet_collection_manager = p_bet_collection_manager
	chip_visual_manager = p_chip_visual_manager
	payout_queue_manager = p_payout_queue_manager
	ui_manager = p_ui_manager

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА РЕЗУЛЬТАТОВ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

func handle_payout_result(
	bet_type: String,
	position_index: int,
	is_correct: bool,
	collected: float,
	expected: float
) -> void:
	"""Обработать результат выплаты (правильная или неправильная)
	
	Args:
		bet_type: Тип ставки ("Player"/"Banker"/"Tie"/"PairPlayer"/"PairBanker")
		position_index: Индекс позиции фишки
		is_correct: Правильная ли выплата
		collected: Собранная сумма
		expected: Ожидаемая сумма
	"""
	if is_correct:
		_handle_correct_payout(bet_type, position_index, collected, expected)
	else:
		_handle_wrong_payout(bet_type, position_index, collected, expected)

func _handle_correct_payout(
	bet_type: String,
	position_index: int,
	_collected: float,
	expected: float
) -> void:
	"""Обработать правильную выплату
	
	ПРИМЕЧАНИЕ: payout_correct теперь эмитится синхронно с показом анимации "ВЕРНО!"
	в PayoutOverlayPaymentHandler._show_success_animation(), поэтому здесь не эмитим.
	"""
	# Событие payout_correct уже эмитится в PayoutOverlayPaymentHandler синхронно с анимацией
	# Здесь только обрабатываем результат (обновление баланса, скрытие фишек и т.д.)
	DebugLogger.log("  ✅ Правильная выплата %s[%d]: %.1f" % [bet_type, position_index, expected])
	
	# Обновляем баланс гостя (если это гостевые ставки)
	if update_guest_balance_callback.is_valid():
		DebugLogger.log("  💰 Вызываем callback обновления баланса гостя: %s[%d], payout=%.0f" % [bet_type, position_index, expected])
		update_guest_balance_callback.call(bet_type, position_index, expected)
	else:
		DebugLogger.log_warning("  ⚠️ Callback обновления баланса гостя не установлен!")
	
	# Помечаем ставку как оплаченную через BetCollectionPhaseManager
	if bet_collection_manager:
		if bet_collection_manager.pay_bet(bet_type, position_index):
			DebugLogger.log("  ✅ Ставка %s[%d] оплачена через BetCollectionPhaseManager" % [bet_type, position_index])
		else:
			DebugLogger.log_error("  ❌ Не удалось оплатить ставку %s[%d] через BetCollectionPhaseManager" % [bet_type, position_index])
	
	# Помечаем ставку как оплаченную в PayoutQueueManager (для обратной совместимости)
	if payout_queue_manager:
		payout_queue_manager.mark_as_paid(bet_type)
	
	# Скрываем фишку
	if chip_visual_manager:
		chip_visual_manager.hide_chip_instance(bet_type, position_index)
		DebugLogger.log("  🎨 Фишка %s[%d] скрыта" % [bet_type, position_index])
	
	# Активируем кнопку "Завершить"
	if ui_manager:
		ui_manager.enable_action_button()
		DebugLogger.log("  🔓 Кнопка 'Завершить' активирована после оплаты ставки")

func _handle_wrong_payout(
	bet_type: String,
	position_index: int,
	collected: float,
	expected: float
) -> void:
	"""Обработать неправильную выплату
	
	ВАЖНО: Если collected == 0.0, это отмена (ESC), а не ошибка.
	В этом случае не эмитим payout_wrong и не отнимаем сердце.
	"""
	# Если collected == 0.0, это отмена (ESC) - не считаем это ошибкой
	if collected == 0.0:
		DebugLogger.log("  ⏸️ Отмена выплаты %s[%d] (ESC нажата, сердце НЕ отнимается)" % [
			bet_type, position_index
		])
		return  # НЕ эмитим payout_wrong для отмены
	
	# Эмитим событие (потеря жизни обрабатывается через EventBus в HeartBar)
	var payload = {
		"type": "payout_wrong",
		"phase": "payout",
		"expected": {
			"amount": expected,
			"bet_type": bet_type,
			"position_index": position_index
		},
		"actual": {
			"amount": collected,
			"bet_type": bet_type,
			"position_index": position_index
		},
		"result": "error",
		"reason": "wrong_amount",
		"message": "Неверная выплата"
	}
	EventBus.payout_wrong.emit(payload)
	DebugLogger.log("  ❌ Неправильная выплата %s[%d]: собрано=%.1f, ожидалось=%.1f" % [
		bet_type, position_index, collected, expected
	])

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func has_unpaid_winnings() -> bool:
	"""Проверить, есть ли неоплаченные выигрыши"""
	return payout_queue_manager.has_unpaid_winnings() if payout_queue_manager else false

func set_update_guest_balance_callback(callback: Callable) -> void:
	"""Установить callback для обновления баланса гостя"""
	update_guest_balance_callback = callback

func set_update_chip_visibility_callback(callback: Callable) -> void:
	"""Установить callback для обновления видимости фишек"""
	update_chip_visibility_callback = callback
