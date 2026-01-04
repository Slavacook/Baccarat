# res://scripts/TablePreparationExecutor.gd
# ═══════════════════════════════════════════════════════════════════════════
# ИСПОЛНИТЕЛЬ ПОДГОТОВКИ СТОЛА
# Выполняет действия по подготовке стола к новой игре на основе инструкций
# ═══════════════════════════════════════════════════════════════════════════

class_name TablePreparationExecutor
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var round_completion_coordinator: RoundCompletionCoordinator = null
var payout_queue_manager: PayoutQueueManager = null
var bet_filter_manager: BetFilterManager = null
var guest_bet_factory: GuestBetFactory = null
var chip_restoration_coordinator: ChipRestorationCoordinator = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	round_completion_coordinator_ref: RoundCompletionCoordinator = null,
	payout_queue_manager_ref: PayoutQueueManager = null,
	bet_filter_manager_ref: BetFilterManager = null,
	guest_bet_factory_ref: GuestBetFactory = null,
	chip_restoration_coordinator_ref: ChipRestorationCoordinator = null
):
	round_completion_coordinator = round_completion_coordinator_ref
	payout_queue_manager = payout_queue_manager_ref
	bet_filter_manager = bet_filter_manager_ref
	guest_bet_factory = guest_bet_factory_ref
	chip_restoration_coordinator = chip_restoration_coordinator_ref

# ═══════════════════════════════════════════════════════════════════════════
# ВЫПОЛНЕНИЕ ДЕЙСТВИЙ
# ═══════════════════════════════════════════════════════════════════════════

func execute_preparation_actions(
	instructions: Dictionary,
	resolve_heart_bet_callback: Callable,
	reset_round_callback: Callable,
	restore_chips_callback: Callable,
	apply_filters_callback: Callable
) -> Dictionary:
	"""Выполнить действия по подготовке стола
	
	Args:
		instructions: Инструкции от RoundCompletionCoordinator
		resolve_heart_bet_callback: Callable для разрешения Heart Bet (принимает actual_winner: String)
		reset_round_callback: Callable для сброса раунда (принимает update_state: bool)
		restore_chips_callback: Callable для восстановления фишек (без параметров)
		apply_filters_callback: Callable для применения фильтров (без параметров)
		
	Returns:
		Dictionary с результатом выполнения:
		{
			"should_continue": bool,      # Продолжать ли выполнение (false если Heart Bet разрешен)
			"actions_executed": Array[String]  # Список выполненных действий
		}
	"""
	var actions_executed: Array[String] = []
	
	# 1. Разрешение Heart Bet (если нужно)
	if instructions.get("should_resolve_heart_bet", false):
		var actual_winner = TableStateManager.get_actual_winner()
		print("❤️ TablePreparationExecutor: есть активный Heart Bet, вызываем resolve(%s)" % actual_winner)
		if resolve_heart_bet_callback.is_valid():
			resolve_heart_bet_callback.call(actual_winner)
		actions_executed.append("resolve_heart_bet")
		return {
			"should_continue": false,
			"actions_executed": actions_executed
		}
	
	# 2. Показ сообщения о завершении
	if instructions.get("should_show_message", false):
		_show_completion_message()
		actions_executed.append("show_message")
	
	# 3. Зум камеры на общий план
	_execute_camera_zoom()
	actions_executed.append("camera_zoom")
	
	# 4. Начисление очков
	if instructions.get("should_add_score", false):
		_execute_score_addition()
		actions_executed.append("add_score")
	
	# 5. Сброс раунда
	if instructions.get("should_reset_round", false):
		if reset_round_callback.is_valid():
			reset_round_callback.call(false)  # БЕЗ обновления GameStateManager
		actions_executed.append("reset_round")
	
	# 6. Установка состояния WAITING
	if instructions.get("should_set_waiting_state", false):
		GameStateManager.update_state(GameStateManager.GameState.WAITING)
		DebugLogger.log("  → ✅ Состояние установлено в WAITING (готово к использованию карты шанса)")
		actions_executed.append("set_waiting_state")
	
	# 7. Применение фильтров
	if instructions.get("should_apply_filters", false):
		if apply_filters_callback.is_valid():
			apply_filters_callback.call()
		actions_executed.append("apply_filters")
	
	# 8. Генерация ставок гостей
	if instructions.get("should_generate_guest_bets", false):
		_execute_guest_bet_generation()
		actions_executed.append("generate_guest_bets")
	
	# 9. Восстановление фишек
	if instructions.get("should_restore_chips", false):
		if restore_chips_callback.is_valid():
			restore_chips_callback.call()
		actions_executed.append("restore_chips")
	
	return {
		"should_continue": true,
		"actions_executed": actions_executed
	}

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _show_completion_message() -> void:
	"""Показать сообщение о завершении раунда"""
	if not round_completion_coordinator or not payout_queue_manager:
		return
	
	var message_info = round_completion_coordinator.get_completion_message(payout_queue_manager)
	var message_key = message_info.get("message_key", "")
	var has_unpaid = message_info.get("has_unpaid", false)
	
	# Если есть неоплаченные выплаты - не показываем сообщение
	if has_unpaid:
		DebugLogger.log_warning("⚠️ ЕСТЬ НЕОПЛАЧЕННЫЕ ВЫПЛАТЫ → НЕ ЗАВЕРШАЕМ РАУНД")
		return
	
	# Показываем сообщение если есть ключ
	if not message_key.is_empty():
		var log_message = "НЕТ АКТИВНЫХ СТАВОК" if not message_info.get("has_bets", false) else \
						 ("ВСЕ СТАВКИ ОПЛАЧЕНЫ" if message_info.get("has_winning", false) else "НЕТ ВЫИГРЫШНЫХ СТАВОК")
		DebugLogger.log_init("%s → ЗАВЕРШАЕМ РАУНД" % log_message)
		EventBus.show_toast_info.emit(Localization.t(message_key))

func _execute_camera_zoom() -> void:
	"""Выполнить зум камеры на общий план"""
	EventBus.camera_zoom_requested.emit("out", false)
	EventBus.area_buttons_visibility_changed.emit(false)
	EventBus.navigation_arrows_visibility_changed.emit(false)
	DebugLogger.log("  → ✅ Камера отзумлена, кнопки областей скрыты")

func _execute_score_addition() -> void:
	"""Начислить очки за завершение игры"""
	SaveManager.instance.add_score(1)
	if StatsManager.instance:
		StatsManager.instance.update_stats()
	DebugLogger.log("  → ✅ +1 очко за завершение игры")

func _execute_guest_bet_generation() -> void:
	"""Сгенерировать ставки для всех активных гостей"""
	if guest_bet_factory:
		guest_bet_factory.generate_bets_for_all_guests()
		DebugLogger.log("  → ✅ Ставки гостей сгенерированы")
