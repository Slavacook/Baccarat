# res://scripts/payout/PayoutQueueHandler.gd
# Обработчик очереди выплат (SRP - единственная ответственность: обработка очереди выплат)
# Отвечает за:
#   - Обработку очереди выплат или сброс раунда
#   - Подготовку выплат в ручном режиме
#   - Завершение подготовки выплат (обновление видимости, сохранение состояния)
#   - Обновление видимости фишек

extends RefCounted
class_name PayoutQueueHandler

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var phase_manager: GamePhaseManager
var payout_manager: PayoutManager
var payout_queue_manager: PayoutQueueManager
var bet_collection_manager: BetCollectionPhaseManager
var chip_visual_manager: ChipVisualManager
var hand_manager: HandManager
var winner_selection_manager: WinnerSelectionManager
var camera_manager: CameraManager
var limits_manager: LimitsManager
var pair_betting_manager: PairBettingManager
var survival_state: SurvivalStateProvider

# Callback для получения survival_rounds_completed
var get_rounds_completed_callback: Callable

# Callback для установки payout_queue_manager в GameController
var set_payout_queue_manager_callback: Callable

# Callback для получения SceneTree
var get_tree_callback: Callable

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	phase_mgr: GamePhaseManager,
	payout_mgr: PayoutManager,
	queue_mgr: PayoutQueueManager,
	collection_mgr: BetCollectionPhaseManager,
	chip_mgr: ChipVisualManager,
	hand_mgr: HandManager,
	winner_mgr: WinnerSelectionManager,
	camera_mgr: CameraManager,
	limits_mgr: LimitsManager,
	pair_mgr: PairBettingManager,
	survival_provider: SurvivalStateProvider,
	get_rounds_callback: Callable,
	set_queue_callback: Callable,
	get_tree_cb: Callable
):
	phase_manager = phase_mgr
	payout_manager = payout_mgr
	payout_queue_manager = queue_mgr
	bet_collection_manager = collection_mgr
	chip_visual_manager = chip_mgr
	hand_manager = hand_mgr
	winner_selection_manager = winner_mgr
	camera_manager = camera_mgr
	limits_manager = limits_mgr
	pair_betting_manager = pair_mgr
	survival_state = survival_provider
	get_rounds_completed_callback = get_rounds_callback
	set_payout_queue_manager_callback = set_queue_callback
	get_tree_callback = get_tree_cb

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ОЧЕРЕДИ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

func process_payout_queue_or_reset(scene_tree: SceneTree) -> void:
	"""Обработка очереди выплат или сброс раунда (если очередь пуста)"""
	if GameDataManager.has_more_payouts():
		# Есть выплаты → берём первую и переходим в PayoutScene
		var next_payout = GameDataManager.get_next_payout()
		
		# Сохраняем данные для PayoutScene
		GameDataManager.set_payout_data(
			next_payout.get_bet_type(),
			next_payout.get_stake(),
			next_payout.get_payout(),
			next_payout.get_player_score(),
			next_payout.get_banker_score()
		)
		
		# Сохраняем состояние игры (сердечки, раунды)
		var lives = survival_state.get_lives() if survival_state else 7
		var active = survival_state.is_active_mode() if survival_state else false
		var rounds_completed = get_rounds_completed_callback.call() if get_rounds_completed_callback.is_valid() else 0
		
		GameDataManager.set_game_state(
			rounds_completed,
			lives,
			active
		)
		
		scene_tree.change_scene_to_file("res://scenes/PayoutScene.tscn")
	else:
		# Нет выплат → сразу новый раунд
		phase_manager.reset()

# ═══════════════════════════════════════════════════════════════════════════
# ПОДГОТОВКА ВЫПЛАТ В РУЧНОМ РЕЖИМЕ
# ═══════════════════════════════════════════════════════════════════════════

func prepare_payouts_manual(actual_winner: String) -> void:
	"""Подготовка выплат в ручном режиме (без автоматического перехода к сцене)
	
	Рефакторено: использует PayoutManager (SRP)
	"""
	# Создаем новый payout_queue_manager
	var new_queue_manager = PayoutQueueManager.new()
	
	# Обновляем ссылку через callback
	if set_payout_queue_manager_callback.is_valid():
		set_payout_queue_manager_callback.call(new_queue_manager)
	
	# ВАЖНО: Обновляем ссылку в phase_manager
	phase_manager.payout_queue_manager = new_queue_manager
	DebugLogger.log_init("Создан новый PayoutQueueManager, ссылка обновлена в phase_manager")
	
	# Обновляем ссылку в текущем объекте
	payout_queue_manager = new_queue_manager
	
	# Создаем или обновляем PayoutManager
	if not payout_manager:
		# Передаём guest_bet_storage и phase_manager из phase_manager
		var guest_storage = phase_manager.guest_bet_storage if phase_manager else null
		payout_manager = PayoutManager.new(
			payout_queue_manager,
			bet_collection_manager,
			chip_visual_manager,
			limits_manager,
			pair_betting_manager,
			hand_manager,
			null,  # settings_provider (по умолчанию)
			guest_storage,  # guest_bet_storage
			phase_manager  # phase_manager (для доступа к snapshot фильтра)
		)
	else:
		# Обновляем ссылки
		payout_manager.payout_queue_manager = payout_queue_manager
		payout_manager.guest_bet_storage = phase_manager.guest_bet_storage if phase_manager else null
		payout_manager.phase_manager = phase_manager  # Обновляем ссылку на phase_manager
	
	# Делегируем подготовку выплат в PayoutManager
	payout_manager.prepare_manual_payouts(actual_winner)
	
	# Завершаем подготовку - обновляем видимость и сохраняем состояние
	finalize_payouts_manual(actual_winner)

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВЕРШЕНИЕ ПОДГОТОВКИ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

func finalize_payouts_manual(actual_winner: String) -> void:
	"""Завершение подготовки выплат - обновление видимости и сохранение состояния"""
	# ═══════════════════════════════════════════════════════════════════
	# УПРАВЛЕНИЕ ФИШКАМИ (показать выигравшие, скрыть проигравшие)
	# ═══════════════════════════════════════════════════════════════════
	update_chip_visibility()

	# ═══════════════════════════════════════════════════════════════════
	# НАСТРОЙКА BetCollectionPhaseManager для работы с очередью выплат
	# ═══════════════════════════════════════════════════════════════════
	if bet_collection_manager and payout_queue_manager:
		bet_collection_manager.setup(payout_queue_manager, actual_winner)
		# Устанавливаем режим COLLECT по умолчанию (после определения победителя)
		# Звук не играется автоматически (первая активация определяется внутри set_mode)
		bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.COLLECT)
		DebugLogger.log("✅ BetCollectionPhaseManager настроен для раунда (победитель: %s, режим: COLLECT)" % actual_winner)

	# ═══════════════════════════════════════════════════════════════════
	# СОХРАНЕНИЕ СОСТОЯНИЯ СТОЛА в TableStateManager
	# ═══════════════════════════════════════════════════════════════════
	var selected_winner = winner_selection_manager.get_selected_winner() if winner_selection_manager else ""
	var surv_lives = survival_state.get_lives() if survival_state else 7
	var surv_active = survival_state.is_active_mode() if survival_state else false

	# Получаем состояние ставок на пары из настроек
	var pair_player_pressed = PayoutSettingsManager.player_pair_payout_enabled
	var pair_banker_pressed = PayoutSettingsManager.banker_pair_payout_enabled

	# Получаем текущие текстуры фишек
	var chip_textures = {}
	if chip_visual_manager and chip_visual_manager.texture_manager:
		chip_textures = chip_visual_manager.texture_manager.current_textures

	# Запрашиваем настройки камеры через EventBus
	var camera_data = {"position": Vector2.ZERO, "zoom": Vector2.ONE, "received": false}
	
	if camera_manager:
		var response_handler = func(pos: Vector2, zoom: Vector2):
			camera_data.position = pos
			camera_data.zoom = zoom
			camera_data.received = true
			# CONNECT_ONE_SHOT автоматически отписывает после первого вызова
		
		EventBus.camera_settings_received.connect(response_handler, CONNECT_ONE_SHOT)
		EventBus.camera_settings_requested.emit()
		
		# Ждём ответ (синхронно, но с таймаутом)
		var timeout = 0.1
		var elapsed = 0.0
		var scene_tree = get_tree_callback.call() if get_tree_callback.is_valid() else null
		if scene_tree:
			while not camera_data.received and elapsed < timeout:
				await scene_tree.process_frame
				elapsed += scene_tree.get_process_delta_time()
	
	var rounds_completed = get_rounds_completed_callback.call() if get_rounds_completed_callback.is_valid() else 0
	
	TableStateManager.save_table_state(
		hand_manager.get_player_hand_ref(),
		hand_manager.get_banker_hand_ref(),
		actual_winner,
		selected_winner,
		payout_queue_manager.get_all_bets(),
		camera_data.position,
		camera_data.zoom,
		GameModeManager.get_mode_string(),
		rounds_completed,
		surv_lives,
		surv_active,
		pair_player_pressed,
		pair_banker_pressed,
		chip_textures,
		"complete"  # Кнопка всегда в состоянии "complete" при переходе к выплатам
	)

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ ВИДИМОСТИ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func update_chip_visibility() -> void:
	"""Обновить видимость и кликабельность фишек через ChipVisualManager

	Режим GUEST: работаем с каждой ставкой индивидуально (гостевые ставки)
	- Оплаченные ставки → скрыть
	- Собранные проигрышные ставки → скрыть
	- Все остальные ставки (выигрышные, проигрышные, Tie push) → видимы и кликабельны
	  (валидация клика в BetCollectionPhaseManager)
	"""
	if not payout_queue_manager or not chip_visual_manager:
		return

	# В режиме GUEST работаем с каждой ставкой индивидуально (гостевые ставки)
	for bet in payout_queue_manager.get_all_bets():
		var bet_type = bet.get_bet_type()
		var pos_idx = bet.get_position_index()
		var is_collected = bet.is_collected() or (bet_collection_manager and bet_collection_manager.is_bet_collected(bet_type, pos_idx))
		
		if bet.is_paid() or is_collected:
			# Оплаченная или собранная → скрываем конкретную фишку
			chip_visual_manager.hide_chip_instance(bet_type, pos_idx)
		else:
			# Все остальные → видимы и кликабельны
			# В режиме GUEST фишки уже созданы через _show_guest_bets()
			# и уже кликабельны через _on_chip_instance_pressed
			# НЕ вызываем make_chip_clickable() - это подключит дополнительный обработчик
			# _on_chip_pressed, который вызовет двойной сбор ставки!
			var chip_instance = chip_visual_manager.get_chip_instance(bet.get_bet_type(), bet.get_position_index())
			if chip_instance and chip_instance.node:
				chip_instance.node.visible = true
				# Убеждаемся что фишка не заблокирована
				chip_instance.node.disabled = false
				chip_instance.node.mouse_filter = Control.MOUSE_FILTER_STOP
				# Создаём или обновляем label для суммы ставки
				if chip_instance.stake > 0:
					if chip_instance.stake_label:
						# Обновляем существующий label
						chip_visual_manager._update_stake_label(chip_instance)
					else:
						# Создаём новый label
						chip_instance.stake_label = chip_visual_manager.create_stake_label(chip_instance)
			
			var status = ""
			if bet.is_won():
				status = "выигрышная"
			elif bet_collection_manager and bet_collection_manager.is_tie_push_bet(bet.get_bet_type()):
				status = "Tie push"
			else:
				status = "проигрышная"
			DebugLogger.log("💰 Фишка %s[%d] видна (%s)" % [bet.get_bet_type(), bet.get_position_index(), status])
