# res://scripts/utils/ChipClickHandler.gd
# Обработчик кликов на фишки
# Инкапсулирует логику обработки кликов на фишки (сбор/оплата ставок)
# Extract Class - извлечено из GameController

extends RefCounted
class_name ChipClickHandler

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются через dependency injection)
# ═══════════════════════════════════════════════════════════════════════════

var chip_visual_manager: ChipVisualManager = null
var bet_collection_manager: BetCollectionPhaseManager = null
var payout_queue_manager: PayoutQueueManager = null
var phase_manager: GamePhaseManager = null
var ui_manager: UIManager = null
var survival_state: SurvivalStateProvider = null
var payout_overlay: CanvasLayer = null

# Флаг использования overlay режима выплат
var use_overlay_payout: bool = true

# ═══════════════════════════════════════════════════════════════════════════
# CALLBACKS (делегируются в GameController)
# ═══════════════════════════════════════════════════════════════════════════

# Callback для проверки флага is_payout_processing
var is_payout_processing_getter: Callable = Callable()

# Callback для обновления баланса гостя при сборе ставки
var update_guest_balance_on_collect_callback: Callable = Callable()

# Callback для показа PayoutOverlay
var show_payout_overlay_callback: Callable = Callable()

# Callback для открытия PayoutScene
var open_payout_scene_callback: Callable = Callable()

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	p_chip_visual_manager: ChipVisualManager = null,
	p_bet_collection_manager: BetCollectionPhaseManager = null,
	p_payout_queue_manager: PayoutQueueManager = null,
	p_phase_manager: GamePhaseManager = null,
	p_ui_manager: UIManager = null,
	p_survival_state: SurvivalStateProvider = null,
	p_payout_overlay: CanvasLayer = null,
	p_use_overlay_payout: bool = true
):
	chip_visual_manager = p_chip_visual_manager
	bet_collection_manager = p_bet_collection_manager
	payout_queue_manager = p_payout_queue_manager
	phase_manager = p_phase_manager
	ui_manager = p_ui_manager
	survival_state = p_survival_state
	payout_overlay = p_payout_overlay
	use_overlay_payout = p_use_overlay_payout

# ═══════════════════════════════════════════════════════════════════════════
# УСТАНОВКА CALLBACKS
# ═══════════════════════════════════════════════════════════════════════════

func set_is_payout_processing_getter(callback: Callable) -> void:
	"""Установить callback для получения is_payout_processing"""
	is_payout_processing_getter = callback

func set_update_guest_balance_callback(callback: Callable) -> void:
	"""Установить callback для обновления баланса гостя"""
	update_guest_balance_on_collect_callback = callback

func set_show_payout_overlay_callback(callback: Callable) -> void:
	"""Установить callback для показа PayoutOverlay"""
	show_payout_overlay_callback = callback

func set_open_payout_scene_callback(callback: Callable) -> void:
	"""Установить callback для открытия PayoutScene"""
	open_payout_scene_callback = callback

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНОЙ МЕТОД
# ═══════════════════════════════════════════════════════════════════════════

func handle_chip_click(bet_type: String, position_index: int) -> void:
	"""Обработать клик на фишку (корутина - может использовать await)
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции фишки
	"""
	print("🔴 ChipClickHandler.handle_chip_click ВЫЗВАН: %s[%d]" % [bet_type, position_index])
	
	# Проверяем все предварительные условия (защиты, валидация ставки, гости)
	if not _validate_prerequisites(bet_type, position_index):
		print("⏸️  Проверка не прошла, клик игнорируется")
		return  # Проверка не прошла, клик игнорируется
	
	# ═══════════════════════════════════════════════════════════════════
	# ВАЛИДАЦИЯ КЛИКА ЧЕРЕЗ BetCollectionPhaseManager
	# ═══════════════════════════════════════════════════════════════════
	print("🔍 Валидация клика через BetCollectionPhaseManager: %s[%d]" % [bet_type, position_index])
	DebugLogger.log("🔍 Валидация клика через BetCollectionPhaseManager: %s[%d]" % [bet_type, position_index])
	
	if not bet_collection_manager:
		print("❌ bet_collection_manager is null!")
		return
	
	var validation = bet_collection_manager.validate_chip_click(bet_type, position_index)
	
	if validation == null or validation.is_empty():
		print("❌ validate_chip_click вернул null или пустой Dictionary!")
		return
	
	print("🔍 Результат валидации: action=%s, can_proceed=%s, error_type=%s" % [validation.get("action", "unknown"), validation.get("can_proceed", false), validation.get("error_type", "")])
	DebugLogger.log("🔍 Результат валидации: action=%s, can_proceed=%s, error_type=%s" % [validation.get("action", "unknown"), validation.get("can_proceed", false), validation.get("error_type", "")])
	
	# Если режим не выбран - ничего не делаем
	if validation.action == "none" and validation.can_proceed:
		print("  ⏸️  Режим не выбран, клик игнорируется")
		DebugLogger.log("  ⏸️  Режим не выбран, клик игнорируется")
		return
	
	# Если ошибка валидации - показываем сообщение и штрафуем
	if not validation.can_proceed:
		print("  ❌ Ошибка валидации, обрабатываем...")
		if await _handle_validation_error(validation, bet_type, position_index):
			print("  ✅ Ошибка обработана, выходим")
			return  # Ошибка обработана, выходим
	
	# ═══════════════════════════════════════════════════════════════════
	# ВЫПОЛНЕНИЕ ДЕЙСТВИЯ
	# ═══════════════════════════════════════════════════════════════════
	
	print("🔍 Действие: %s" % validation.action)
	if validation.action == "collect":
		print("  → Выполняем действие COLLECT")
		_handle_collect_action(bet_type, position_index)
		return
	
	if validation.action == "pay":
		print("  → Выполняем действие PAY")
		_handle_pay_action(bet_type, position_index)
		return
	
	print("  ⚠️ Неизвестное действие: %s" % validation.action)

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _validate_prerequisites(bet_type: String, position_index: int):
	"""Проверить все предварительные условия для клика на фишку
	
	Проверяет:
	- Блокировка во время обработки выплаты
	- Существование фишки
	- Инициализацию менеджеров
	- Наличие ставки в очереди выплат
	- Активность гостя (в режиме GUEST)
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции фишки
		
	Returns:
		true если все проверки пройдены, false если проверка не прошла
	"""
	# ═══════════════════════════════════════════════════════════════════
	# ЗАЩИТА: Блокировка во время обработки выплаты (защита от спама Space)
	# ═══════════════════════════════════════════════════════════════════
	var is_processing = false
	if is_payout_processing_getter.is_valid():
		is_processing = is_payout_processing_getter.call()
	
	print("🔍 Проверка is_payout_processing: %s" % is_processing)
	if is_processing:
		DebugLogger.log("⏸️  Клик на %s[%d] заблокирован (идёт обработка выплаты)" % [bet_type, position_index])
		return false
	
	DebugLogger.log("🖱️  Клик на фишку: %s[%d]" % [bet_type, position_index])
	
	# ═══════════════════════════════════════════════════════════════════
	# ЗАЩИТА: Проверяем что фишка существует (защита от множественных кликов)
	# ═══════════════════════════════════════════════════════════════════
	print("🔍 Проверка chip_visual_manager: %s" % (chip_visual_manager != null))
	if chip_visual_manager:
		var chip = chip_visual_manager.get_chip_instance(bet_type, position_index)
		print("🔍 get_chip_instance(%s, %d) = %s" % [bet_type, position_index, "найдена" if chip else "null"])
		if not chip:
			DebugLogger.log("⏸️  Фишка %s[%d] не найдена (уже обработана), игнорируем клик" % [bet_type, position_index])
			return false
	
	# Проверяем что bet_collection_manager инициализирован
	print("🔍 Проверка bet_collection_manager: %s" % (bet_collection_manager != null))
	if not bet_collection_manager:
		print("🔍 ВЫХОД: bet_collection_manager не инициализирован")
		return false
	
	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА: В режиме GUEST игнорируем клики на фишки неактивных гостей
	# Определяем сектор по position_index и проверяем GuestBetStorage
	# ═══════════════════════════════════════════════════════════════════
	if phase_manager and phase_manager.guest_bet_storage:
		# Определяем сектор по position_index
		var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
		print("🔍 Сектор по position_index: %s[%d] → сектор %d" % [bet_type, position_index, sector])
		
		if sector >= 1 and sector <= 6:
			# Это гостевой сектор - проверяем есть ли активный гость
			var guest_id = sector
			var guest_bets = phase_manager.guest_bet_storage.get_guest_bets(guest_id)
			print("🔍 Гость %d: найдено %d ставок" % [guest_id, guest_bets.size()])
			if guest_bets.is_empty():
				# Гость не включён или нет ставок - игнорируем клик
				print("⚠️ Клик на фишку %s[%d] в секторе %d, но гостя %d нет или он не включён - игнорируем" % [bet_type, position_index, sector, guest_id])
				DebugLogger.log_warning("⚠️ Клик на фишку %s[%d] в секторе %d, но гостя %d нет или он не включён - игнорируем" % [bet_type, position_index, sector, guest_id])
				return false
	
	print("✅ _validate_prerequisites завершена, продолжаем обработку")
	return true  # Все проверки пройдены, можно продолжать

func _handle_validation_error(validation: Dictionary, bet_type: String, position_index: int) -> bool:
	"""Обработать ошибку валидации клика на фишку
	
	Args:
		validation: Результат валидации от BetCollectionPhaseManager
		bet_type: Тип ставки
		position_index: Индекс позиции фишки
		
	Returns:
		bool: true если ошибка обработана и нужно вернуться, false если продолжить
	"""
	# "already_collected" - это не ошибка игрока, а техническая ситуация (двойной клик)
	# Просто игнорируем без тоста и без отнятия жизни
	if validation.error_type == "already_collected":
		DebugLogger.log("  ⏸️  Ставка %s[%d] уже собрана, клик игнорируется" % [bet_type, position_index])
		return true  # Ошибка обработана, выходим
	
	# Для ошибки "collect_winning" - уменьшаем терпение гостя и накладываем штраф
	if validation.error_type == "collect_winning":
		# Проверяем, ушел ли гость
		var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
		if sector >= 1 and sector <= 6:
			var guest_id = sector
			# Если гость ушел - применяем специальную обработку
			if GuestSettingsManager and not GuestSettingsManager.is_guest_enabled(guest_id):
				# Гость ушел - применяем 3 штрафа по 100 чаевых с задержкой 0.2 сек между каждым
				await _apply_triple_penalty_for_left_guest()
				DebugLogger.log("  💸 Применено 3 штрафа по 100 чаевых для ушедшего гостя %d" % guest_id)
			else:
				# Гость не ушел - обычная обработка
				await _apply_penalty_to_guest(bet_type, position_index, "попытки собрать выигрышную ставку")
		
		# Показываем сообщение об ошибке
		var error_msg = Localization.t(validation.error_message) if validation.error_message.begins_with("ERR_") else validation.error_message
		EventBus.show_toast_error.emit(error_msg)
		DebugLogger.log("  ❌ Ошибка: %s" % validation.error_message)
		return true  # Ошибка обработана, выходим
	
	# Для ошибки "wrong_order" при сборе - штрафуем только гостя, чья ставка была собрана неправильно
	if validation.error_type == "wrong_order" and bet_collection_manager and bet_collection_manager.is_collect_mode():
		# Проверяем, ушел ли гость, чья ставка была собрана неправильно
		var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
		var is_left_guest = false
		if sector >= 1 and sector <= 6:
			var guest_id = sector
			is_left_guest = GuestSettingsManager and not GuestSettingsManager.is_guest_enabled(guest_id)
		
		if is_left_guest:
			# Гость ушел - применяем только штраф -100 чаевых (без уменьшения терпения)
			var current_tips = SaveManager.instance.score if SaveManager.instance else 0
			if current_tips >= 100:
				# Чаевых достаточно - применяем быстрый штраф
				await _apply_penalty_quick(100)
				DebugLogger.log("  💰 Штраф -100 чаевых для ушедшего гостя %d за неправильный порядок сбора ставки %s[%d] (осталось %d)" % [sector, bet_type, position_index, SaveManager.instance.score])
			else:
				# Чаевых недостаточно - отнимаем сердце (если не бессмертие)
				if not SaveManager.instance.load_immortality_enabled():
					_lose_life_directly()
				DebugLogger.log("  ❌ Чаевых недостаточно (%d < 100) для штрафа ушедшему гостю %d" % [current_tips, sector])
		else:
			# Гость не ушел - обычная обработка (уменьшение терпения на 20% и штраф -100 чаевых)
			await _apply_penalty_to_guest(bet_type, position_index, "неправильного порядка сбора ставок")
		
		# Показываем сообщение об ошибке
		var error_msg = Localization.t(validation.error_message) if validation.error_message.begins_with("ERR_") else validation.error_message
		EventBus.show_toast_error.emit(error_msg)
		DebugLogger.log("  ❌ Ошибка: %s" % validation.error_message)
		return true  # Ошибка обработана, выходим
	
	# Для ошибки "wrong_order" при оплате - штрафуем двух гостей:
	# 1. Того, чью ставку оплатили неправильно
	# 2. Того, чью ставку должны были оплатить
	if validation.error_type == "wrong_order" and bet_collection_manager and bet_collection_manager.is_pay_mode():
		# Проверяем, ушел ли гость, чью ставку оплатили неправильно
		var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
		var is_left_guest = false
		if sector >= 1 and sector <= 6:
			var guest_id = sector
			is_left_guest = GuestSettingsManager and not GuestSettingsManager.is_guest_enabled(guest_id)
		
		if is_left_guest:
			# Гость ушел - если есть чаевые, применяем 1 штраф на 100 чаевых
			var current_tips = SaveManager.instance.score if SaveManager.instance else 0
			if current_tips >= 100:
				# Чаевых достаточно - применяем быстрый штраф
				await _apply_penalty_quick(100)
				DebugLogger.log("  💰 Отнято 100 чаевых для ушедшего гостя (осталось %d)" % SaveManager.instance.score)
			else:
				# Чаевых недостаточно - отнимаем сердце
				_lose_life_directly()
				DebugLogger.log("  ❌ Чаевых недостаточно (%d < 100) - отнимается сердце" % current_tips)
		else:
			# Гость не ушел - обычная обработка (штрафуем двух гостей)
			# Штрафуем гостя, чью ставку оплатили неправильно
			await _apply_penalty_to_guest(bet_type, position_index, "неправильного порядка оплаты ставок")
			
			# Получаем ожидаемую ставку из bet_collection_manager
			if bet_collection_manager:
				# Определяем группу ставки
				var group = bet_collection_manager.get_bet_group(bet_type) if bet_collection_manager.has_method("get_bet_group") else ""
				if group.is_empty():
					# Пробуем определить группу вручную
					if bet_type in ["Player", "Banker"]:
						group = "main"
					elif bet_type == "Tie":
						group = "tie"
					elif bet_type.begins_with("PlayerPair") or bet_type.begins_with("BankerPair"):
						group = "pairs"
				
				# Получаем ожидаемую ставку через sequence_manager
				if bet_collection_manager.sequence_manager and not group.is_empty():
					var expected_bet = bet_collection_manager.sequence_manager.get_expected_next_bet(group, false)
					if expected_bet:
						var expected_bet_type = expected_bet.get_bet_type()
						var expected_position_index = expected_bet.get_position_index()
						# Штрафуем гостя, чью ставку должны были оплатить
						await _apply_penalty_to_guest(expected_bet_type, expected_position_index, "неправильного порядка оплаты ставок (ожидалась его ставка)")
					else:
						DebugLogger.log_warning("  ⚠️ Не удалось определить ожидаемую ставку для штрафа")
		
		# Показываем сообщение об ошибке
		var error_msg = Localization.t(validation.error_message) if validation.error_message.begins_with("ERR_") else validation.error_message
		EventBus.show_toast_error.emit(error_msg)
		DebugLogger.log("  ❌ Ошибка: %s" % validation.error_message)
		return true  # Ошибка обработана, выходим
	
	# Для ошибки "pay_losing" - штраф -100 чаевых И уменьшение терпения на -20% (для любых типов ставок: Player, Banker, Tie, пары)
	if validation.error_type == "pay_losing":
		# Уменьшаем терпение на 20% у гостя, чья ставка была попытка оплатить проигранную
		var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
		if sector >= 1 and sector <= 6:
			var guest_id = sector
			var patience_before = GuestStatsManager.get_guest_patience(guest_id)
			
			# Уменьшаем терпение на 20%
			GuestStatsManager.decrease_patience(guest_id, 20)
			var patience_after = GuestStatsManager.get_guest_patience(guest_id)
			
			DebugLogger.log("  😤 Гость %d: терпение %d%% -> %d%% (-20%%) из-за попытки оплатить проигранную ставку %s[%d]" % [guest_id, patience_before, patience_after, bet_type, position_index])
			
			# Проверяем терпение перед штрафом
			if patience_before == 100:
				# Терпение было 100% - показываем тост о прощении (штраф не применяем)
				DebugLogger.log("  ✅ Терпение было 100% - ошибка прощена, штраф не применяется")
				EventBus.show_toast_info.emit("На первый раз прощаю")
			else:
				# Терпение было < 100% - применяем штраф -100 чаевых
				var current_tips = SaveManager.instance.score if SaveManager.instance else 0
				if current_tips >= 100:
					# Чаевых достаточно - применяем быстрый штраф
					await _apply_penalty_quick(100)
					DebugLogger.log("  💰 Штраф -100 чаевых за попытку оплатить проигранную ставку %s[%d] (осталось %d)" % [bet_type, position_index, SaveManager.instance.score])
				else:
					# Чаевых недостаточно - отнимаем сердце (если не бессмертие)
					if not SaveManager.instance.load_immortality_enabled():
						_lose_life_directly()
					DebugLogger.log("  ❌ Чаевых недостаточно (%d < 100) для штрафа за попытку оплатить проигранную ставку %s[%d]" % [current_tips, bet_type, position_index])
		else:
			# Не гостевые ставки - только штраф без терпения
			var current_tips = SaveManager.instance.score if SaveManager.instance else 0
			if current_tips >= 100:
				await _apply_penalty_quick(100)
				DebugLogger.log("  💰 Штраф -100 чаевых за попытку оплатить проигранную ставку %s[%d] (осталось %d)" % [bet_type, position_index, SaveManager.instance.score])
			else:
				if not SaveManager.instance.load_immortality_enabled():
					_lose_life_directly()
				DebugLogger.log("  ❌ Чаевых недостаточно (%d < 100) для штрафа" % current_tips)
		
		# Показываем сообщение об ошибке
		var error_msg = Localization.t(validation.error_message) if validation.error_message.begins_with("ERR_") else validation.error_message
		EventBus.show_toast_error.emit(error_msg)
		DebugLogger.log("  ❌ Ошибка: %s" % validation.error_message)
		return true  # Ошибка обработана, выходим
	
	# Для остальных ошибок - показываем тост и отнимаем жизнь (штрафуем всех гостей через HeartBar)
	var error_message = Localization.t(validation.error_message) if validation.error_message.begins_with("ERR_") else validation.error_message
	EventBus.show_toast_error.emit(error_message)
	EventBus.action_error.emit(validation.error_type, error_message)
	DebugLogger.log("  ❌ Ошибка: %s" % validation.error_message)
	return true  # Ошибка обработана, выходим

func _apply_penalty_quick(penalty_amount: int) -> void:
	"""Применить штраф на чаевые с быстрой задержкой 0.2 сек
	
	Args:
		penalty_amount: Сумма штрафа
	"""
	if penalty_amount <= 0 or not SaveManager.instance:
		return
	
	# Получаем дерево сцен через Engine (надежный способ для RefCounted классов)
	var tree = Engine.get_main_loop().root.get_tree()
	if not tree:
		DebugLogger.log_error("  ❌ Не удалось получить дерево сцен для таймера")
		return
	
	# Задержка 0.2 сек перед применением штрафа
	await tree.create_timer(0.2).timeout
	
	var tips_before = SaveManager.instance.score
	SaveManager.instance.subtract_score(penalty_amount)
	var tips_after = SaveManager.instance.score
	
	# Обновляем статистику если есть StatsManager
	if StatsManager.instance:
		StatsManager.instance.update_stats()
	
	# Эмитим событие для синхронизации оповещения и звука
	EventBus.penalty_applied.emit(penalty_amount)
	
	DebugLogger.log("  💰 Быстрый штраф применен: чаевые %d → %d (-%d)" % [tips_before, tips_after, penalty_amount])

func _apply_triple_penalty_for_left_guest() -> void:
	"""Применить 3 штрафа по 100 чаевых подряд с задержкой 0.2 секунды между каждым
	
	Используется для ушедших гостей при попытке собрать их выигрышную ставку.
	"""
	var penalty_amount = 100
	
	# Проверяем, достаточно ли чаевых для всех трех штрафов
	var total_penalty = penalty_amount * 3
	var current_tips = SaveManager.instance.score if SaveManager.instance else 0
	
	if current_tips < total_penalty:
		# Чаевых недостаточно для всех штрафов - отнимаем сердце
		_lose_life_directly()
		DebugLogger.log("  ❌ Чаевых недостаточно для тройного штрафа (%d < %d) - отнимается сердце" % [current_tips, total_penalty])
		return
	
	# Применяем 3 штрафа по 100 с задержкой 0.2 сек между каждым
	for i in range(3):
		await _apply_penalty_quick(penalty_amount)
		DebugLogger.log("  💰 Штраф %d/3 применен: -100 чаевых (осталось %d)" % [i + 1, SaveManager.instance.score if SaveManager.instance else 0])

func _lose_life_directly() -> void:
	"""Отнять сердце напрямую без уменьшения терпения у всех гостей
	
	Используется для ошибок, которые уже обработали терпение конкретного гостя.
	"""
	if survival_state and survival_state.heart_bar:
		survival_state.heart_bar.lose_life()
	else:
		# Fallback: если survival_state недоступен, используем EventBus
		# Но это не должно происходить в нормальной работе
		EventBus.action_error.emit("life_lost", "Потеря жизни")

func _apply_penalty_to_guest(bet_type: String, position_index: int, reason: String) -> void:
	"""Применить штраф к конкретному гостю (уменьшение терпения на 20% и штраф на 100 чаевых)
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции
		reason: Причина штрафа (для логирования)
	
	ВАЖНО: Применяет штрафы даже для возвращенных гостей, независимо от их текущего статуса активности.
	"""
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	if sector < 1 or sector > 6:
		# Не гостевые ставки - пропускаем
		return
	
	var guest_id = sector
	
	# Если гость не активен, но есть ставки на столе - это возвращенный гость со ставками
	# Применяем штрафы в любом случае (даже если гость уже выключен)
	var is_guest_active = GuestSettingsManager and GuestSettingsManager.is_guest_enabled(guest_id)
	if not is_guest_active:
		DebugLogger.log("  ⚠️ Гость %d не активен, но применяем штраф для ставки %s[%d] (возвращенный гость)" % [guest_id, bet_type, position_index])
	
	var patience_before = GuestStatsManager.get_guest_patience(guest_id)
	
	# Уменьшаем терпение на 20% (даже если гость не активен - это для возвращенных гостей)
	# Если гость не активен, сначала включаем его обратно (для возвращенных гостей)
	if not is_guest_active and GuestSettingsManager:
		GuestSettingsManager.set_guest_enabled(guest_id, true)
		DebugLogger.log("  🔄 Гость %d включен обратно для применения штрафа" % guest_id)
	
	GuestStatsManager.decrease_patience(guest_id, 20)
	var patience_after = GuestStatsManager.get_guest_patience(guest_id)
	
	DebugLogger.log("  😤 Гость %d: терпение %d%% -> %d%% (-20%%) из-за %s %s[%d]" % [guest_id, patience_before, patience_after, reason, bet_type, position_index])
	
	# Определяем штраф в зависимости от терпения ДО уменьшения
	if patience_before == 100:
		# Терпение было 100% - ошибка прощается (ничего не отнимаем)
		DebugLogger.log("  ✅ Терпение было 100% - ошибка прощена")
		# Показываем тост о прощении
		EventBus.show_toast_info.emit("На первый раз прощаю")
	elif patience_after == 0:
		# Терпение стало 0% - отнимаем сердце напрямую (без уменьшения терпения у всех)
		_lose_life_directly()
		DebugLogger.log("  ❌ Терпение = 0% - отнимается сердце")
	else:
		# Терпение стало < 100% - пытаемся отнять 100 чаевых
		var current_tips = SaveManager.instance.score
		if current_tips >= 100:
			# Чаевых достаточно - применяем штраф с задержкой
			if StatsManager.instance:
				await StatsManager.instance.apply_penalty_with_delay(100)
			DebugLogger.log("  💰 Отнято 100 чаевых (осталось %d)" % SaveManager.instance.score)
		else:
			# Чаевых недостаточно - отнимаем сердце напрямую (без уменьшения терпения у всех)
			_lose_life_directly()
			DebugLogger.log("  ❌ Чаевых недостаточно (%d < 100) - отнимается сердце" % current_tips)

func _handle_collect_action(bet_type: String, position_index: int) -> void:
	"""Обработать действие "collect" (собрать проигрышную ставку)
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции фишки
	"""
	# Собираем проигрышную ставку
	bet_collection_manager.collect_bet(bet_type, position_index)
	
	# Обновляем баланс гостя при сборе проигрышной ставки
	if update_guest_balance_on_collect_callback.is_valid():
		update_guest_balance_on_collect_callback.call(bet_type, position_index)
	
	# Скрываем конкретную фишку по position_index (работает для всех режимов)
	if chip_visual_manager:
		chip_visual_manager.hide_chip_instance(bet_type, position_index)
	DebugLogger.log("  ✅ Ставка %s[%d] собрана" % [bet_type, position_index])
	
	# Если кнопка "Завершить" была broken - восстанавливаем
	if ui_manager and ui_manager.button_ui.is_action_button_broken():
		ui_manager.enable_action_button()
		DebugLogger.log("  🔓 Кнопка 'Завершить' восстановлена")

func _handle_pay_action(bet_type: String, position_index: int) -> void:
	"""Обработать действие "pay" (оплатить выигрышную ставку)
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции фишки
	"""
	print("💰 _handle_pay_action: %s[%d]" % [bet_type, position_index])
	
	# ВАЖНО: Используем payout_queue_manager из bet_collection_manager,
	# так как он обновляется через setup() при каждом новом раунде
	var queue_manager = bet_collection_manager.payout_queue_manager if bet_collection_manager else payout_queue_manager
	
	if not queue_manager:
		print("❌ payout_queue_manager is null!")
		return
	
	var bet = queue_manager.get_bet_by_id(bet_type, position_index)
	print("🔍 Поиск ставки в очереди: %s[%d] → %s" % [bet_type, position_index, "найдена" if bet else "не найдена"])
	if not bet:
		# Для обратной совместимости пробуем по типу
		bet = queue_manager.get_bet_by_type(bet_type)
		print("🔍 Fallback поиск по типу: %s → %s" % [bet_type, "найдена" if bet else "не найдена"])
	if not bet:
		print("❌ Ставка не найдена в очереди выплат, не можем оплатить")
		# Логируем все ставки в очереди для отладки
		print("  📋 Все ставки в очереди:")
		for b in queue_manager.get_all_bets():
			print("    → %s[%d], won=%s, collected=%s" % [b.get_bet_type(), b.get_position_index(), b.is_won(), b.is_collected()])
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# ПЕРЕКЛЮЧАТЕЛЬ РЕЖИМА ВЫПЛАТ
	# ═══════════════════════════════════════════════════════════════════
	if use_overlay_payout:
		# НОВЫЙ СПОСОБ: показать overlay поверх Game.tscn
		if show_payout_overlay_callback.is_valid():
			show_payout_overlay_callback.call(bet_type, position_index, bet.get_stake(), bet.get_payout())
	else:
		# СТАРЫЙ СПОСОБ: переход к PayoutScene (scene transition)
		if open_payout_scene_callback.is_valid():
			open_payout_scene_callback.call(bet_type)
