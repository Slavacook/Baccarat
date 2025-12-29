# res://scripts/ui/SettingsEventHandler.gd
# Обработчик событий настроек для GameController
# Инкапсулирует логику обработки изменений настроек (режим, язык, выплаты, стили)

extends RefCounted
class_name SettingsEventHandler

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var limits_manager: LimitsManager
var phase_manager: GamePhaseManager
var chip_visual_manager: ChipVisualManager
var ui_manager: UIManager
var pair_betting_manager: PairBettingManager
var survival_state: SurvivalStateProvider

# ═══════════════════════════════════════════════════════════════════════════
# CALLBACK-ИНТЕРФЕЙС (функции, которые должен предоставить владелец)
# ═══════════════════════════════════════════════════════════════════════════

var get_pending_mode_change_callback: Callable  # Получить pending_mode_change -> String
var set_pending_mode_change_callback: Callable  # Установить pending_mode_change (mode: String)

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	limits_manager_ref: LimitsManager,
	phase_manager_ref: GamePhaseManager,
	chip_visual_manager_ref: ChipVisualManager,
	ui_manager_ref: UIManager,
	pair_betting_manager_ref: PairBettingManager,
	survival_state_ref: SurvivalStateProvider
):
	"""Инициализация обработчика настроек
	
	Args:
		limits_manager_ref: Менеджер лимитов
		phase_manager_ref: Менеджер фаз игры
		chip_visual_manager_ref: Менеджер визуализации фишек
		ui_manager_ref: Менеджер UI
		pair_betting_manager_ref: Менеджер ставок на пары
		survival_state_ref: Провайдер состояния выживания
	"""
	limits_manager = limits_manager_ref
	phase_manager = phase_manager_ref
	chip_visual_manager = chip_visual_manager_ref
	ui_manager = ui_manager_ref
	pair_betting_manager = pair_betting_manager_ref
	survival_state = survival_state_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ОБРАБОТКА ИЗМЕНЕНИЙ НАСТРОЕК
# ═══════════════════════════════════════════════════════════════════════════

func handle_mode_changed(mode: String) -> void:
	"""Обработать изменение режима игры
	
	Args:
		mode: Режим игры ("junket" или "classic")
	"""
	DebugLogger.log("Режим игры изменён на: %s" % mode)
	
	# ВАЖНО: Смена лимитов возможна ТОЛЬКО в состоянии WAITING
	var current_state = GameStateManager.get_current_state()
	var state_name = GameStateManager.get_state_name(current_state)
	DebugLogger.log("🔍 Текущее состояние игры: %s" % state_name)
	
	if current_state == GameStateManager.GameState.WAITING:
		# Можно менять сразу - применяем
		DebugLogger.log("✅ Состояние WAITING - применяем смену лимитов сразу")
		apply_mode_change(mode)
	else:
		# Откладываем смену
		if set_pending_mode_change_callback.is_valid():
			set_pending_mode_change_callback.call(mode)
		
		# Оповещаем игрока
		var mode_display_name = Localization.t("MODE_JUNKET_NAME") if mode == "junket" else Localization.t("MODE_CLASSIC_NAME")
		var message = Localization.t("LIMITS_CHANGE_PENDING", [mode_display_name])
		EventBus.show_toast_info.emit(message)
		
		# Логируем
		log_mode_change(mode, state_name, true)
		
		DebugLogger.log("⏳ Смена лимитов отложена до состояния WAITING (текущее состояние: %s, режим и лимиты НЕ изменены, фишки и ставки сохранены)" % state_name)

func apply_mode_change(mode: String, should_clear_chips: bool = true) -> void:
	"""Применить смену режима игры и лимитов
	
	Args:
		mode: Режим игры ("junket" или "classic")
		should_clear_chips: Нужно ли скрывать фишки и очищать ставки
	"""
	# ВАЖНО: Сохраняем карты шанса перед сменой режима
	var saved_chance_count = 0
	if phase_manager and phase_manager.heart_bet_manager:
		saved_chance_count = phase_manager.heart_bet_manager.chance_count
		DebugLogger.log("🎴 Сохранён счётчик карт шанса перед сменой режима: %d" % saved_chance_count)
	
	GameModeManager.set_mode(mode)
	
	# Очищаем все сгенерированные ставки при переключении режима
	if should_clear_chips:
		if phase_manager and phase_manager.guest_bet_storage:
			phase_manager.guest_bet_storage.clear_all_bets()
			DebugLogger.log("🗑️ Все ставки гостей очищены при переключении режима игры")
		
		# Скрываем все визуальные фишки ставок
		if chip_visual_manager:
			chip_visual_manager.hide_all_chips()
			chip_visual_manager.clear_all_active_chips()
			DebugLogger.log("🚫 Все визуальные фишки ставок скрыты при переключении режима игры")
	else:
		DebugLogger.log("⏳ Смена режима применена, но фишки и ставки сохранены (раздача продолжается)")
	
	# ВАЖНО: Восстанавливаем карты шанса после смены режима
	# (они не должны теряться при смене режима игры)
	if phase_manager and phase_manager.heart_bet_manager:
		if phase_manager.heart_bet_manager.chance_count != saved_chance_count:
			phase_manager.heart_bet_manager.chance_count = saved_chance_count
			EventBus.chance_count_changed.emit(saved_chance_count)
			DebugLogger.log("🎴 Восстановлен счётчик карт шанса после смены режима: %d" % saved_chance_count)
	
	var cfg = GameModeManager.get_config()
	# ← set_limits() сам вызовет limits_changed.emit()
	limits_manager.set_limits(
		cfg["main_min"], cfg["main_max"], cfg["main_step"],
		cfg["tie_min"], cfg["tie_max"], cfg["tie_step"],
		cfg["pairs_min"], cfg["pairs_max"], cfg["pairs_step"]
	)
	
	# Оповещаем игрока
	var mode_display_name = Localization.t("MODE_JUNKET_NAME") if mode == "junket" else Localization.t("MODE_CLASSIC_NAME")
	var message = Localization.t("LIMITS_CHANGED", [mode_display_name])
	EventBus.show_overlay_info.emit(message, 2.0)
	
	# Логируем
	log_mode_change(mode, GameStateManager.get_state_name(GameStateManager.get_current_state()), false)
	
	DebugLogger.log("✅ Лимиты изменены на режим: %s" % mode_display_name)

func handle_language_changed(_lang: String) -> void:
	"""Обработать изменение языка
	
	Args:
		_lang: Язык (не используется, но нужен для сигнала)
	"""
	if not ui_manager:
		return
	
	ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	
	# Обновление toggles третьих карт (если видимы)
	if ui_manager.player_third_toggle.visible:
		var state = "!" if phase_manager.player_third_selected else "?"
		ui_manager.update_player_third_card_ui(state)
	if ui_manager.banker_third_toggle.visible:
		var state = "!" if phase_manager.banker_third_selected else "?"
		ui_manager.update_banker_third_card_ui(state)

func handle_survival_mode_changed(_enabled: bool) -> void:
	"""Обработать изменение режима выживания
	
	DEPRECATED: Режим выживания теперь всегда включён
	
	Args:
		_enabled: Включен ли режим (не используется)
	"""
	# Ничего не делаем - режим всегда включён
	pass

func handle_payout_setting_changed(bet_type: String, enabled: bool) -> void:
	"""Обработать изменение настроек выплат
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		enabled: Включена ли выплата
	"""
	if not chip_visual_manager:
		return

	# Для пар - также обновляем PairBettingManager
	if bet_type == "PairPlayer" and pair_betting_manager:
		pair_betting_manager.toggle_pair_player_bet(enabled)
	elif bet_type == "PairBanker" and pair_betting_manager:
		pair_betting_manager.toggle_pair_banker_bet(enabled)

	# ═══════════════════════════════════════════════════════════════════
	# ПРИМЕНЕНИЕ ФИЛЬТРА: В WAITING применяем сразу, иначе накапливаем
	# ═══════════════════════════════════════════════════════════════════
	var current_state = GameStateManager.get_current_state()
	if current_state == GameStateManager.GameState.WAITING:
		# В состоянии ожидания - применяем фильтр сразу и обновляем snapshot
		var chips_of_type = chip_visual_manager.get_active_chips_by_type(bet_type)
		DebugLogger.log("💰 Настройка выплаты изменена: %s = %s (состояние: WAITING, найдено %d фишек)" % [bet_type, "ВКЛ" if enabled else "ВЫКЛ", chips_of_type.size()])
		
		if enabled:
			# Ставка включена - показываем существующие фишки или создаём новые
			for chip in chips_of_type:
				if chip.node and is_instance_valid(chip.node):
					chip.node.visible = true
					DebugLogger.log("  → Фишка %s[%d] показана" % [bet_type, chip.position_index])
			
			# Если фишек нет, но есть ставки в хранилище - создаём их
			if chips_of_type.is_empty() and phase_manager and phase_manager.guest_bet_storage:
				var guests_with_bets = phase_manager.guest_bet_storage.get_guests_with_bets()
				for guest_id in guests_with_bets:
					var bets = phase_manager.guest_bet_storage.get_guest_bets(guest_id)
					for bet in bets:
						if bet.get_bet_type() == bet_type:
							# Создаём фишку для этой ставки
							var sector = bet.get_sector()
							var pos_idx = bet.get_position_index()
							var stake = bet.get_stake()
							var coords = GuestSectorMapper.get_position_coordinates(sector, bet_type)
							if coords != Vector2.ZERO:
								phase_manager._show_guest_chip_at_position(bet_type, pos_idx, coords, stake)
								DebugLogger.log("  → Создана фишка %s[%d] для гостя %d" % [bet_type, pos_idx, guest_id])
		else:
			# Ставка отключена - скрываем существующие фишки
			for chip in chips_of_type:
				if chip.node and is_instance_valid(chip.node):
					chip.node.visible = false
					DebugLogger.log("  → Фишка %s[%d] скрыта (фильтр)" % [bet_type, chip.position_index])
		
		# Обновляем snapshot после применения изменений
		if phase_manager:
			phase_manager._save_filter_snapshot()
			# Очищаем pending_changes для этого типа ставки (если был)
			if phase_manager._pending_filter_changes.has(bet_type):
				phase_manager._pending_filter_changes.erase(bet_type)
			DebugLogger.log("📸 Snapshot фильтра обновлён после изменения в WAITING")
	else:
		# После начала раздачи - записываем в pending_changes для следующей раздачи
		if phase_manager:
			phase_manager._pending_filter_changes[bet_type] = enabled
			DebugLogger.log("💰 Настройка выплаты изменена: %s = %s (состояние: %s - записано в pending_changes для следующей раздачи)" % [bet_type, "ВКЛ" if enabled else "ВЫКЛ", GameStateManager.get_state_name(current_state)])
		else:
			DebugLogger.log("💰 Настройка выплаты изменена: %s = %s (состояние: %s - phase_manager недоступен)" % [bet_type, "ВКЛ" if enabled else "ВЫКЛ", GameStateManager.get_state_name(current_state)])

func handle_card_back_style_changed(style: String) -> void:
	"""Обработать изменение стиля рубашки карт
	
	Args:
		style: "tiger" или "leopard"
	"""
	if not ui_manager:
		return

	# Обновляем все рубашки карт на столе
	ui_manager.update_all_card_backs()

	DebugLogger.log("🎴 Стиль рубашки карт изменён: %s" % style)

func handle_position_mode_changed(_mode: int) -> void:
	"""Обработать изменение режима позиций фишек
	
	Args:
		_mode: 0=DEFAULT, 1=RANDOM, 2=MAX, 3=REALISTIC (не используется, режим всегда GUEST)
	"""
	if not chip_visual_manager:
		return

	# Режим всегда GUEST
	chip_visual_manager.set_position_mode(ChipVisualManager.PositionMode.GUEST)
	DebugLogger.log("🎲 Режим позиций фишек: GUEST (гости)")

func handle_game_state_changed(old_state: int, new_state: int) -> void:
	"""Обработать изменение состояния игры
	
	Применяет отложенную смену режима при переходе в WAITING
	
	Args:
		old_state: Предыдущее состояние
		new_state: Новое состояние
	"""
	var old_name = GameStateManager.get_state_name(old_state)
	var new_name = GameStateManager.get_state_name(new_state)
	DebugLogger.log("📊 [НОВАЯ СИСТЕМА] Состояние: %s → %s" % [old_name, new_name])
	
	# Если перешли в WAITING и есть отложенная смена режима - применяем её
	if new_state == GameStateManager.GameState.WAITING:
		var pending_mode = ""
		if get_pending_mode_change_callback.is_valid():
			pending_mode = get_pending_mode_change_callback.call()
		
		if pending_mode != "":
			if set_pending_mode_change_callback.is_valid():
				set_pending_mode_change_callback.call("")  # Очищаем отложенную смену
			apply_mode_change(pending_mode)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - ВСПОМОГАТЕЛЬНЫЕ
# ═══════════════════════════════════════════════════════════════════════════

func log_mode_change(mode: String, state: String, is_pending: bool) -> void:
	"""Логировать смену режима в файл
	
	Args:
		mode: Новый режим
		state: Состояние игры
		is_pending: Отложена ли смена
	"""
	var file = FileAccess.open("user://limits_change.log", FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open("user://limits_change.log", FileAccess.WRITE)
	
	if file:
		file.seek_end()
		var timestamp = Time.get_datetime_string_from_system()
		var status = "PENDING" if is_pending else "APPLIED"
		var log_line = "[%s] Mode: %s -> %s (State: %s, Status: %s)" % [
			timestamp, 
			GameModeManager.get_mode_string(), 
			mode, 
			state, 
			status
		]
		file.store_line(log_line)
		file.close()
		DebugLogger.log("📝 Limits change logged: %s" % log_line)

