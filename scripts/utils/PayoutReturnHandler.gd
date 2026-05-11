# res://scripts/utils/PayoutReturnHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК ВОЗВРАТА ИЗ PAYOUTSCENE
# 
# Отвечает за:
# - Обработку возврата из PayoutScene (ручной и автоматический режимы)
# - Восстановление состояния игры после выплаты
# - Координацию между StateRestorer, PayoutOverlayCoordinator и другими компонентами
# ═══════════════════════════════════════════════════════════════════════════

class_name PayoutReturnHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var state_restorer: StateRestorer
var payout_overlay_coordinator: PayoutOverlayCoordinator
var payout_queue_handler: PayoutQueueHandler
var phase_manager: GamePhaseManager
var survival_state: SurvivalStateProvider
var camera_manager: CameraManager
var game_state_controller: GameStateController
var hand_manager: HandManager
var winner_selection_manager: WinnerSelectionManager
var survival_ui: Control
var ui_manager: UIManager
var card_manager: CardTextureManager

# Callbacks для обновления состояния в GameController
var update_rounds_counter_callback: Callable
var update_chip_visibility_callback: Callable
var get_tree_callback: Callable

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	state_rest: StateRestorer,
	overlay_coord: PayoutOverlayCoordinator,
	queue_handler: PayoutQueueHandler,
	phase_mgr: GamePhaseManager,
	survival: SurvivalStateProvider,
	camera_mgr: CameraManager,
	game_state: GameStateController,
	hand_mgr: HandManager,
	winner_mgr: WinnerSelectionManager,
	survival_ui_node: Control,
	ui_mgr: UIManager,
	card_mgr: CardTextureManager,
	update_rounds_cb: Callable,
	update_chips_cb: Callable,
	get_tree_cb: Callable
) -> void:
	"""Инициализировать обработчик возврата из PayoutScene
	
	Args:
		state_rest: Восстановитель состояния
		overlay_coord: Координатор PayoutOverlay
		queue_handler: Обработчик очереди выплат
		phase_mgr: Менеджер фаз игры
		survival: Провайдер состояния выживания
		camera_mgr: Менеджер камеры
		game_state: Контроллер состояния игры
		hand_mgr: Менеджер рук
		winner_mgr: Менеджер выбора победителя
		survival_ui_node: UI режима выживания
		ui_mgr: Менеджер UI
		card_mgr: Менеджер текстур карт
		update_rounds_cb: Callback для обновления счетчика раундов
		update_chips_cb: Callback для обновления видимости фишек
		get_tree_cb: Callback для получения SceneTree
	"""
	state_restorer = state_rest
	payout_overlay_coordinator = overlay_coord
	payout_queue_handler = queue_handler
	phase_manager = phase_mgr
	survival_state = survival
	camera_manager = camera_mgr
	game_state_controller = game_state
	hand_manager = hand_mgr
	winner_selection_manager = winner_mgr
	survival_ui = survival_ui_node
	ui_manager = ui_mgr
	card_manager = card_mgr
	update_rounds_counter_callback = update_rounds_cb
	update_chip_visibility_callback = update_chips_cb
	get_tree_callback = get_tree_cb

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - РУЧНОЙ РЕЖИМ
# ═══════════════════════════════════════════════════════════════════════════

func handle_manual_mode_payout_return(context: Dictionary, survival_rounds_completed_ref: int, payout_queue_manager_ref: PayoutQueueManager) -> Dictionary:
	"""Обработка возврата из PayoutScene в ручном режиме
	
	Args:
		context: Контекст возврата из PayoutScene
		survival_rounds_completed_ref: Текущее значение survival_rounds_completed
		payout_queue_manager_ref: Текущий payout_queue_manager
		
	Returns:
		Dictionary с ключами:
		- "survival_rounds_completed": int - обновленное значение
		- "payout_queue_manager": PayoutQueueManager - обновленный менеджер
	"""
	DebugLogger.log_restore("⏮ Возврат из PayoutScene (ручной режим)")
	
	# Guard: проверка сохранённого состояния
	if not TableStateManager.has_saved_state():
		push_error("❌ TableStateManager не содержит сохраненного состояния!")
		PayoutContextManager.clear_context()
		GameDataManager.clear()
		return {
			"survival_rounds_completed": survival_rounds_completed_ref,
			"payout_queue_manager": payout_queue_manager_ref
		}
	
	# 1-3. Восстановление карт, UI и GameStateManager
	restore_table_state()
	
	# 4-6. Восстановление survival режима и очереди выплат
	var result = restore_survival_and_queue(survival_rounds_completed_ref, payout_queue_manager_ref)
	
	# 7. Обработка результата текущей выплаты
	process_manual_payout_result(context)
	
	# 8. Восстановление камеры и очистка контекстов
	restore_camera_and_cleanup()
	
	return result

func restore_table_state() -> void:
	"""Восстановление карт, UI карт и GameStateManager
	
	Рефакторено: использует StateRestorer (SRP)
	"""
	if not state_restorer:
		state_restorer = StateRestorer.new(
			hand_manager,
			winner_selection_manager,
			survival_ui,
			camera_manager,
			ui_manager,
			card_manager
		)
	
	state_restorer.restore_table_state()

func restore_survival_and_queue(_survival_rounds_completed_ref: int, payout_queue_manager_ref: PayoutQueueManager) -> Dictionary:
	"""Восстановление маркера победителя, survival режима и очереди выплат
	
	Args:
		_survival_rounds_completed_ref: Текущее значение survival_rounds_completed (не используется, берется из TableStateManager)
		payout_queue_manager_ref: Текущий payout_queue_manager
		
	Returns:
		Dictionary с ключами:
		- "survival_rounds_completed": int - обновленное значение
		- "payout_queue_manager": PayoutQueueManager - обновленный менеджер
		
	Рефакторено: использует StateRestorer (SRP)
	"""
	if not state_restorer:
		state_restorer = StateRestorer.new(
			hand_manager,
			winner_selection_manager,
			survival_ui,
			camera_manager,
			ui_manager,
			card_manager
		)
	
	# Восстанавливаем survival режим
	var updated_rounds = TableStateManager.get_survival_rounds()
	if update_rounds_counter_callback.is_valid():
		update_rounds_counter_callback.call()
	
	# Восстанавливаем очередь выплат через StateRestorer
	var updated_queue_manager = state_restorer.restore_survival_and_queue(
		payout_queue_manager_ref,
		updated_rounds
	)
	
	# КРИТИЧНО: Обновляем ссылку в phase_manager после восстановления!
	phase_manager.payout_queue_manager = updated_queue_manager
	DebugLogger.log_restore("⏮ Ссылка phase_manager.payout_queue_manager обновлена")
	
	# Обновляем видимость фишек (показываем неоплаченные выигрыши)
	if update_chip_visibility_callback.is_valid():
		update_chip_visibility_callback.call()
	
	return {
		"survival_rounds_completed": updated_rounds,
		"payout_queue_manager": updated_queue_manager
	}

func process_manual_payout_result(context: Dictionary) -> void:
	"""Обработка результата текущей выплаты в ручном режиме - делегировано в PayoutOverlayCoordinator"""
	if payout_overlay_coordinator:
		payout_overlay_coordinator.process_manual_payout_result(context)
	else:
		push_error("❌ PayoutOverlayCoordinator не инициализирован!")

func restore_camera_and_cleanup() -> void:
	"""Восстановление камеры и очистка контекстов
	
	Рефакторено: использует StateRestorer (SRP)
	"""
	if not state_restorer:
		state_restorer = StateRestorer.new(
			hand_manager,
			winner_selection_manager,
			survival_ui,
			camera_manager,
			ui_manager,
			card_manager
		)
	
	state_restorer.restore_camera()
	
	# Очищаем контексты
	PayoutContextManager.clear_context()
	PayoutContextManager.clear_saved_state()
	GameDataManager.clear()

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - АВТОМАТИЧЕСКИЙ РЕЖИМ
# ═══════════════════════════════════════════════════════════════════════════

func handle_automatic_mode_payout_return(survival_rounds_completed_ref: int) -> Dictionary:
	"""Обработка возврата из PayoutScene в автоматическом режиме
	
	Args:
		survival_rounds_completed_ref: Текущее значение survival_rounds_completed
		
	Returns:
		Dictionary с ключами:
		- "survival_rounds_completed": int - обновленное значение
		- "should_reset": bool - нужно ли сбросить раунд
	"""
	# 1. Восстанавливаем состояние игры и камеру
	var updated_rounds = restore_automatic_mode_state(survival_rounds_completed_ref)
	
	# 2. Проверка Game Over
	if check_and_handle_game_over(updated_rounds):
		return {
			"survival_rounds_completed": updated_rounds,
			"should_reset": false  # Game Over произошёл
		}
	
	# 3. Обрабатываем результат выплаты
	process_automatic_payout_result()
	
	# 4. Обрабатываем очередь выплат
	var should_reset = handle_payout_queue()
	
	return {
		"survival_rounds_completed": updated_rounds,
		"should_reset": should_reset
	}

func restore_automatic_mode_state(_survival_rounds_completed_ref: int) -> int:
	"""Восстановление состояния игры, камеры и UI
	
	Args:
		_survival_rounds_completed_ref: Текущее значение survival_rounds_completed (не используется, берется из GameDataManager)
		
	Returns:
		Обновленное значение survival_rounds_completed
	"""
	# Восстанавливаем состояние survival режима
	var updated_rounds = GameDataManager.get_survival_rounds()
	var session_manager: Variant = null
	if Engine.has_singleton("SessionManager"):
		session_manager = Engine.get_singleton("SessionManager")
	else:
		var tree: SceneTree = null
		if get_tree_callback.is_valid():
			var tree_value: Variant = get_tree_callback.call()
			if tree_value is SceneTree:
				tree = tree_value
		if tree != null:
			session_manager = tree.root.get_node_or_null("SessionManager")
	var is_tournament_mode: bool = session_manager != null and session_manager.get("current_mode") == session_manager.Mode.TOURNAMENT
	if update_rounds_counter_callback.is_valid():
		update_rounds_counter_callback.call()
	
	if survival_state:
		survival_state.set_lives(GameDataManager.get_survival_lives())
		if GameDataManager.is_survival_active():
			survival_state.activate()
		else:
			survival_state.deactivate()
	
	# Восстанавливаем камеру на общий план (без анимации)
	if camera_manager:
		camera_manager.restore_to_general()
		DebugLogger.log("📷 Камера восстановлена: общий план")
	
	# Показываем кнопки областей
	EventBus.area_buttons_visibility_changed.emit(true)
	
	# Обновляем визуальное отображение сердечек
	var is_active = survival_state.is_active_mode() if survival_state else false
	var lives = survival_state.get_lives() if survival_state else 7
	if is_tournament_mode:
		survival_state.hide()
	elif is_active:
		survival_state.show()
	else:
		survival_state.hide()
	
	DebugLogger.log("♻️  Состояние игры восстановлено: rounds=%d, lives=%d, active=%s" % [
		updated_rounds, lives, is_active
	])
	
	return updated_rounds

func check_and_handle_game_over(survival_rounds_completed: int) -> bool:
	"""Проверка Game Over в режиме выживания - делегировано в GameStateController
	
	Args:
		survival_rounds_completed: Количество завершенных раундов
		
	Returns:
		true если Game Over произошёл, false если игра продолжается
	"""
	if game_state_controller:
		var result = game_state_controller.check_and_handle_game_over(survival_rounds_completed)
		if result:
			GameDataManager.clear()  # Очищаем данные после Game Over
		return result
	return false

func process_automatic_payout_result() -> void:
	"""Обработка результата выплаты в автоматическом режиме"""
	var is_correct = GameDataManager.get_payout_is_correct()
	var collected = GameDataManager.get_payout_collected()
	var expected = GameDataManager.get_payout_expected()
	
	if is_correct:
		# Для автоматического режима нет информации о bet_type/position_index
		# Передаем пустые значения - StatsManager пропустит такие случаи
		var payload = {
			"type": "payout_correct",
			"phase": "payout",
			"expected": {
				"amount": expected,
				"bet_type": "",
				"position_index": -1
			},
			"actual": {
				"amount": collected,
				"bet_type": "",
				"position_index": -1
			},
			"result": "correct"
		}
		EventBus.payout_correct.emit(payload)
		DebugLogger.log("✅ Правильно! Выплата: %s" % expected)
		# ВАЖНО: Счетчик раздач НЕ увеличивается здесь - он увеличивается при открытии первых 4 карт
	else:
		# Для старого метода нет информации о bet_type/position_index
		var payload = {
			"type": "payout_wrong",
			"phase": "payout",
			"expected": {
				"amount": expected,
				"bet_type": "",
				"position_index": -1
			},
			"actual": {
				"amount": collected,
				"bet_type": "",
				"position_index": -1
			},
			"result": "error",
			"reason": "wrong_amount",
			"message": "Неверная выплата"
		}
		EventBus.payout_wrong.emit(payload)
		DebugLogger.log("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])

func handle_payout_queue() -> bool:
	"""Обработка очереди выплат (переход к следующей или сброс раунда)
	
	Returns:
		true если нужно сбросить раунд, false если есть следующая выплата
	"""
	if GameDataManager.has_more_payouts():
		# Есть ещё выплаты в очереди → берём следующую
		var next_payout = GameDataManager.get_next_payout()
		
		DebugLogger.log("🔄 Следующая выплата: %s (осталось %d)" % [
			next_payout.get_bet_type(), GameDataManager.get_queue_size()
		])
		
		# Сохраняем данные для PayoutScene
		GameDataManager.set_payout_data(
			next_payout.get_bet_type(),
			next_payout.get_stake(),
			next_payout.get_payout(),
			next_payout.get_player_score(),
			next_payout.get_banker_score()
		)
		
		# Переходим в PayoutScene для следующей выплаты
		if get_tree_callback.is_valid():
			var tree = get_tree_callback.call()
			if tree:
				tree.change_scene_to_file("res://scenes/PayoutScene.tscn")
		
		return false  # Не сбрасываем раунд, есть следующая выплата
	else:
		# Очередь пуста → сбрасываем раунд
		DebugLogger.log_init("Все выплаты обработаны, сброс раунда")
		GameDataManager.clear()
		
		# Сброс раунда только если последняя выплата была правильной
		var is_correct = GameDataManager.get_payout_is_correct()
		if is_correct:
			phase_manager.reset()
		
		return true  # Сбрасываем раунд
