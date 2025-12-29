# res://scripts/payout/PayoutOverlayCoordinator.gd
# Координатор работы с PayoutOverlay (SRP - единственная ответственность: координация PayoutOverlay)
# Отвечает за:
#   - Показ PayoutOverlay для конкретных ставок
#   - Обработку завершения выплат через overlay
#   - Открытие PayoutScene (старый способ)
#   - Обработку результатов выплат

extends RefCounted
class_name PayoutOverlayCoordinator

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var payout_overlay: CanvasLayer
var payout_result_handler: PayoutResultHandler
var survival_state: SurvivalStateProvider
var ui_manager: UIManager
var payout_queue_manager: PayoutQueueManager
var chip_visual_manager: ChipVisualManager

# Callback для установки флага is_payout_processing
var set_payout_processing_callback: Callable

# Callback для обновления видимости фишек
var update_chip_visibility_callback: Callable

# Callback для получения SceneTree
var get_tree_callback: Callable

# Callback для получения survival_rounds_completed
var get_rounds_completed_callback: Callable

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	overlay: CanvasLayer,
	result_handler: PayoutResultHandler,
	survival_provider: SurvivalStateProvider,
	ui_mgr: UIManager,
	queue_mgr: PayoutQueueManager,
	chip_mgr: ChipVisualManager,
	set_processing_callback: Callable,
	update_visibility_callback: Callable,
	get_tree_cb: Callable,
	get_rounds_cb: Callable
):
	payout_overlay = overlay
	payout_result_handler = result_handler
	survival_state = survival_provider
	ui_manager = ui_mgr
	payout_queue_manager = queue_mgr
	chip_visual_manager = chip_mgr
	set_payout_processing_callback = set_processing_callback
	update_chip_visibility_callback = update_visibility_callback
	get_tree_callback = get_tree_cb
	get_rounds_completed_callback = get_rounds_cb

# ═══════════════════════════════════════════════════════════════════════════
# ПОКАЗ PayoutOverlay
# ═══════════════════════════════════════════════════════════════════════════

func show_payout_overlay_instance(bet_type: String, position_index: int, stake: float, payout: float) -> void:
	"""Показать PayoutOverlay для конкретной фишки
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции фишки
		stake: Размер ставки
		payout: Ожидаемая выплата
	"""
	if not payout_overlay:
		push_error("❌ PayoutOverlay не найден! Проверьте Game.tscn")
		return
	
	# ЗАЩИТА: Блокируем обработку других кликов пока открыт PayoutOverlay
	if set_payout_processing_callback.is_valid():
		set_payout_processing_callback.call(true)
	
	DebugLogger.log("💰 Показываем PayoutOverlay: %s[%d], stake=%.1f, payout=%.1f" % [bet_type, position_index, stake, payout])
	
	# Сохраняем position_index для обработчика завершения
	# (пока используем простой способ - храним в метаданных контекста)
	payout_overlay.set_meta("current_position_index", position_index)
	
	# Передаём состояние игры через параметры (вместо get_parent())
	var lives = survival_state.get_lives() if survival_state else 7
	payout_overlay.show_payout(bet_type, stake, payout, true, lives)  # Режим всегда активен

func show_payout_overlay(bet_type: String, stake: float, payout: float) -> void:
	"""Показать PayoutOverlay с параметрами выплаты (новый способ)

	Вызывается при клике на фишку в overlay режиме (USE_OVERLAY_PAYOUT=true).
	Game.tscn остается в памяти, overlay показывается поверх.

	Args:
		bet_type: Тип ставки ("Player"/"Banker"/"Tie"/"PairPlayer"/"PairBanker")
		stake: Размер ставки
		payout: Ожидаемая выплата
	"""
	if not payout_overlay:
		push_error("❌ PayoutOverlay не найден! Проверьте Game.tscn")
		return

	DebugLogger.log("💰 Показываем PayoutOverlay (overlay режим): %s, stake=%.1f, payout=%.1f" % [bet_type, stake, payout])

	# Вызываем метод show_payout() из PayoutOverlay.gd
	# Overlay сам управляет UI, фишками и валидацией

	# Передаём состояние игры через параметры (вместо get_parent())
	var lives = survival_state.get_lives() if survival_state else 7
	payout_overlay.show_payout(bet_type, stake, payout, true, lives)  # Режим всегда активен

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ЗАВЕРШЕНИЯ ВЫПЛАТЫ
# ═══════════════════════════════════════════════════════════════════════════

func on_payout_overlay_completed(bet_type: String, is_correct: bool, collected: float, expected: float) -> void:
	"""Обработчик завершения выплаты в overlay режиме

	Вызывается когда PayoutOverlay эмитит сигнал payout_completed.
	Обрабатывает результат (правильно/неправильно) и управляет переходом к следующей выплате.

	Args:
		bet_type: Тип ставки ("Player"/"Banker"/"Tie"/"PairPlayer"/"PairBanker")
		is_correct: Правильная ли выплата
		collected: Собранная сумма
		expected: Ожидаемая сумма
	"""
	# Получаем position_index из метаданных (устанавливается в show_payout_overlay_instance)
	var position_index = 0
	if payout_overlay and payout_overlay.has_meta("current_position_index"):
		position_index = payout_overlay.get_meta("current_position_index")
	
	DebugLogger.log("💰 Завершена выплата в overlay режиме: bet_type=%s[%d], correct=%s, collected=%.1f, expected=%.1f" % [bet_type, position_index, is_correct, collected, expected])
	
	# Проверяем, что payout_result_handler инициализирован
	if not payout_result_handler:
		DebugLogger.log_error("❌ PayoutResultHandler не инициализирован!")
		return

	# ═══════════════════════════════════════════════════════════════════
	# ОБРАБОТКА РЕЗУЛЬТАТА (делегировано в PayoutResultHandler)
	# ═══════════════════════════════════════════════════════════════════
	DebugLogger.log("💰 Вызываем payout_result_handler.handle_payout_result: %s[%d], correct=%s" % [bet_type, position_index, is_correct])
	payout_result_handler.handle_payout_result(bet_type, position_index, is_correct, collected, expected)
	
	# ВАЖНО: Счетчик раздач НЕ увеличивается здесь - он увеличивается при открытии первых 4 карт
	if is_correct:
		DebugLogger.log("  ✅ Правильная выплата завершена")

	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ОСТАВШИХСЯ ВЫПЛАТ
	# ═══════════════════════════════════════════════════════════════════
	# TODO: Если есть еще неоплаченные выплаты - можно автоматически показать следующую
	# Пока оставляем ручной режим - пользователь кликает на следующую фишку

	# ═══════════════════════════════════════════════════════════════════
	# ЗАВЕРШЕНИЕ РАУНДА (если все выплаты оплачены И последняя правильная)
	# ═══════════════════════════════════════════════════════════════════
	if is_correct:
		# После оплаты ставки всегда активируем кнопку "Завершить"
		# Проверка неоплаченных ставок будет при нажатии на кнопку
		if ui_manager:
			ui_manager.enable_action_button()
			DebugLogger.log("  🔓 Кнопка 'Завершить' активирована после оплаты ставки")

# ═══════════════════════════════════════════════════════════════════════════
# ОТКРЫТИЕ PayoutScene (старый способ)
# ═══════════════════════════════════════════════════════════════════════════

func open_payout_scene(bet_type: String) -> void:
	"""Открыть PayoutScene для конкретной ставки

	Использует TableStateManager для полного сохранения состояния стола

	Args:
		bet_type: Тип ставки ("main"/"player_pair"/"banker_pair")
	"""
	# Получаем данные ставки из TableStateManager
	var bet_data = TableStateManager.get_bet_data(bet_type)
	if not bet_data:
		push_error("❌ open_payout_scene: ставка %s не найдена в TableStateManager" % bet_type)
		return

	DebugLogger.log("💰 Открываем PayoutScene для %s: stake=%.1f, payout=%.1f" % [bet_type, bet_data.get_stake(), bet_data.get_payout()])

	# Устанавливаем данные в GameDataManager (PayoutScene читает данные оттуда)
	GameDataManager.set_payout_data(
		bet_type,
		bet_data.get_stake(),
		bet_data.get_payout(),
		0,  # player_score (не используется в ручном режиме)
		0   # banker_score (не используется в ручном режиме)
	)
	DebugLogger.log("  → Установлены данные в GameDataManager: winner=%s, stake=%.1f, amount=%.1f" % [bet_type, bet_data.get_stake(), bet_data.get_payout()])

	# Устанавливаем контекст для PayoutScene через старый PayoutContextManager (для совместимости)
	PayoutContextManager.set_context({
		"bet_type": bet_type,
		"stake": bet_data.get_stake(),
		"expected_payout": bet_data.get_payout(),
		"return_to_game": true,
		"manual_mode": true
	})

	# Передаем состояние режима выживания в GameDataManager
	DebugLogger.log("🔍 DEBUG open_payout_scene:")
	DebugLogger.log("  → survival_state exists = %s" % (survival_state != null))
	if survival_state:
		var lives = survival_state.get_lives()
		DebugLogger.log("  → survival_state.current_lives = %d" % lives)
	DebugLogger.log("  → GameDataManager.survival_lives (before) = %d" % GameDataManager.get_survival_lives())

	var surv_lives = 7  # Значение по умолчанию
	if survival_state:
		# Берем текущее количество жизней
		surv_lives = survival_state.get_lives()
		DebugLogger.log("  → Берем из survival_state: %d" % surv_lives)
	else:
		# Если survival_state не инициализирован - берем из GameDataManager
		surv_lives = GameDataManager.get_survival_lives()
		DebugLogger.log("  → Берем из GameDataManager: %d" % surv_lives)

	var rounds_completed = get_rounds_completed_callback.call() if get_rounds_completed_callback.is_valid() else 0

	GameDataManager.set_game_state(
		rounds_completed,
		surv_lives,
		true  # Режим всегда активен
	)
	DebugLogger.log("  → ✅ Установлено состояние игры: rounds=%d, lives=%d" % [rounds_completed, surv_lives])

	# Переходим к PayoutScene
	var scene_tree = get_tree_callback.call() if get_tree_callback.is_valid() else null
	if scene_tree:
		scene_tree.change_scene_to_file("res://scenes/PayoutScene.tscn")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА РЕЗУЛЬТАТА ВЫПЛАТЫ (старый способ)
# ═══════════════════════════════════════════════════════════════════════════

func process_manual_payout_result(context: Dictionary) -> void:
	"""Обработка результата текущей выплаты в ручном режиме"""
	var bet_type = context.get("bet_type", "")
	var position_index = context.get("position_index", -1)  # Может не быть в context
	var is_correct = GameDataManager.get_payout_is_correct()
	var collected = GameDataManager.get_payout_collected()
	var expected = GameDataManager.get_payout_expected()
	
	if is_correct:
		EventBus.payout_correct.emit(collected, expected, bet_type, position_index)
		DebugLogger.log("✅ Правильная выплата для %s: %.1f" % [bet_type, expected])
		
		# Отмечаем ставку как оплаченную в обоих менеджерах
		if payout_queue_manager:
			payout_queue_manager.mark_as_paid(bet_type)
		TableStateManager.mark_bet_as_paid(bet_type)
		
		# Обновляем видимость фишек
		if update_chip_visibility_callback.is_valid():
			update_chip_visibility_callback.call()
		
		DebugLogger.log_init("Все выплаты оплачены! Можно начинать новый раунд")
	else:
		# Здесь нет информации о position_index, используем -1
		EventBus.payout_wrong.emit(collected, expected, bet_type, -1)
		DebugLogger.log("❌ Неправильная выплата для %s: собрано=%.1f, ожидалось=%.1f" % [
			bet_type, collected, expected
		])

