# res://scripts/ui/HeartBetController.gd
# Контроллер для управления Heart Bet (игра на жизнь)
# Инкапсулирует логику мистической атмосферы, обработки событий Heart Bet и завершения раундов

class_name HeartBetController
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var owner_node: Node2D  # Узел-владелец (для создания tween и доступа к get_tree())
var phase_manager: GamePhaseManager  # Для доступа к guest_bet_storage и heart_bet_manager
var guest_sprites: Dictionary  # Словарь спрайтов гостей {guest_id: Sprite2D}
var background_666: Node  # Фон для Heart Bet
var winner_selection_manager: WinnerSelectionManager  # Для разблокировки маркеров
var prepare_payouts_callback: Callable  # Callback для подготовки выплат (GameController._prepare_payouts_manual)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	owner: Node2D,
	phase_mgr: GamePhaseManager,
	sprites: Dictionary,
	bg_666: Node,
	winner_mgr: WinnerSelectionManager,
	prepare_payouts_cb: Callable
) -> void:
	owner_node = owner
	phase_manager = phase_mgr
	guest_sprites = sprites
	background_666 = bg_666
	winner_selection_manager = winner_mgr
	prepare_payouts_callback = prepare_payouts_cb
	DebugLogger.log("✅ HeartBetController инициализирован")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ АТМОСФЕРОЙ
# ═══════════════════════════════════════════════════════════════════════════

func enable_life_bet_atmosphere() -> void:
	"""Включить мистическую атмосферу для игры на жизнь (последовательно)"""
	DebugLogger.log("🔮 Активация мистической атмосферы (игра на жизнь)")
	
	# 1. Гости G_1-G_6: fade-out 0.5 сек (все одновременно)
	var tween_guests = owner_node.create_tween()
	var has_visible_guests = false
	for guest_id in range(1, 7):
		var sprite = guest_sprites.get(guest_id)
		if sprite and sprite.visible:
			tween_guests.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
			has_visible_guests = true
	
	# После fade-out скрываем гостей
	if has_visible_guests:
		await owner_node.get_tree().create_timer(0.5).timeout
		for guest_id in range(1, 7):
			var sprite = guest_sprites.get(guest_id)
			if sprite:
				sprite.visible = false
	
	# 2. Background666: fade-in 1 сек
	if background_666:
		background_666.visible = true
		background_666.modulate.a = 0.0
		var tween_bg = owner_node.create_tween()
		tween_bg.tween_property(background_666, "modulate:a", 1.0, 1.0)
	
	# Ждём завершения fade-in Background666 (1 сек)
	await owner_node.get_tree().create_timer(1.0).timeout
	
	# 3. G_666: fade-in 0.5 сек
	var guest_666 = guest_sprites.get(666)
	if guest_666:
		guest_666.visible = true
		guest_666.modulate.a = 0.0
		var tween_666 = owner_node.create_tween()
		tween_666.tween_property(guest_666, "modulate:a", 1.0, 0.5)

func disable_life_bet_atmosphere() -> void:
	"""Вернуть обычную атмосферу после завершения игры на жизнь"""
	DebugLogger.log("🔮 Деактивация мистической атмосферы")
	
	# 1. Background666 и G_666: fade-out 1 сек (одновременно)
	var tween_fade_out = owner_node.create_tween()
	var needs_fade_out = false
	
	if background_666 and background_666.visible:
		tween_fade_out.parallel().tween_property(background_666, "modulate:a", 0.0, 1.0)
		needs_fade_out = true
	
	var guest_666 = guest_sprites.get(666)
	if guest_666 and guest_666.visible:
		tween_fade_out.parallel().tween_property(guest_666, "modulate:a", 0.0, 1.0)
		needs_fade_out = true
	
	# После fade-out скрываем узлы
	if needs_fade_out:
		await owner_node.get_tree().create_timer(1.0).timeout
		if background_666:
			background_666.visible = false
		if guest_666:
			guest_666.visible = false
	
	# Background3/Background5 остаются видимыми (просто перекрыты слоем выше, проявятся автоматически)
	
	# 2. Гости: fade-in 0.5 сек (все одновременно)
	var tween_guests_fade_in = owner_node.create_tween()
	for guest_id in range(1, 7):
		var sprite = guest_sprites.get(guest_id)
		if sprite:
			var is_enabled = GuestSettingsManager.is_guest_enabled(guest_id)
			if is_enabled:
				sprite.visible = true
				sprite.modulate.a = 0.0
				tween_guests_fade_in.parallel().tween_property(sprite, "modulate:a", 1.0, 0.5)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СОБЫТИЙ HEART BET
# ═══════════════════════════════════════════════════════════════════════════

func handle_heart_bet_show_ui() -> void:
	"""Обработчик начала игры на жизнь - включить мистическую атмосферу"""
	enable_life_bet_atmosphere()

func handle_heart_bet_declined() -> void:
	"""Обработчик отказа от карты Heart Bet - восстанавливаем ставки и продолжаем обычную игру"""
	# Восстанавливаем ставки гостей из backup (если был backup)
	if phase_manager and phase_manager.guest_bet_storage:
		phase_manager.guest_bet_storage.restore_all_bets()
	
	# ВАЖНО: Сбрасываем флаг Heart Bet раунда, чтобы игра продолжалась с обычной логикой выплат
	if phase_manager:
		phase_manager.was_heart_bet_round = false
		DebugLogger.log("❤️ HeartBetController: флаг was_heart_bet_round сброшен (отказ от Heart Bet)")
	
	# Пересоздаём фишки ставок гостей
	# ВАЖНО: Используем _show_guest_bets() вместо show_all_guest_chips(),
	# потому что фишки (узлы) могли быть удалены
	if phase_manager:
		phase_manager._show_guest_bets()
		DebugLogger.log("❤️ HeartBetController: фишки ставок гостей пересозданы после отказа от карты")
	
	# Инициализируем очередь выплат для восстановленных ставок
	# Нужно получить победителя из предыдущего раунда (если был выбран)
	var actual_winner = ""
	if winner_selection_manager:
		var selected = winner_selection_manager.get_selected_winner()
		if selected != "":
			actual_winner = selected
	
	# Если победитель был выбран, инициализируем очередь выплат через callback
	# Это позволит собирать проигрышные и оплачивать выигрышные ставки
	if actual_winner != "" and prepare_payouts_callback.is_valid():
		prepare_payouts_callback.call(actual_winner)
		DebugLogger.log("❤️ HeartBetController: очередь выплат инициализирована для восстановленных ставок (победитель: %s)" % actual_winner)
		DebugLogger.log("❤️ HeartBetController: игра продолжается - можно собирать проигрышные и оплачивать выигрышные ставки")
	else:
		DebugLogger.log("⚠️ HeartBetController: не удалось инициализировать очередь выплат (победитель: %s, callback: %s)" % [actual_winner, "valid" if prepare_payouts_callback.is_valid() else "invalid"])
		DebugLogger.log("⚠️ HeartBetController: игра будет продолжена, но очередь выплат не инициализирована")
	
	# Возвращаем обычную атмосферу при отказе
	disable_life_bet_atmosphere()

func handle_heart_bet_round_complete() -> void:
	"""Завершение Heart Bet раздачи - сброс без выплат
	
	После Heart Bet раздачи игра возвращается в состояние ожидания.
	Выплаты не производятся (это была особая раздача на жизнь).
	"""
	DebugLogger.log("❤️ HeartBetController: Heart Bet раздача завершена, сбрасываем раунд без выплат")
	
	# Возвращаем обычную атмосферу
	disable_life_bet_atmosphere()
	
	# Разблокируем маркеры (если были заблокированы)
	if winner_selection_manager:
		winner_selection_manager.unlock_markers()
		winner_selection_manager.reset()
	
	# Небольшая задержка чтобы увидеть результат
	await owner_node.get_tree().create_timer(1.5).timeout
	
	# Зум камеры на общий план
	EventBus.camera_zoom_requested.emit("out", false)
	
	# Проверяем, был ли Tie draw (карта сгорела, chance_count = 0)
	# ВАЖНО: проверяем ДО проверки триггеров, чтобы не изменилось состояние
	var was_tie_draw = false
	if phase_manager and phase_manager.heart_bet_manager:
		var hb_manager = phase_manager.heart_bet_manager
		# Если chance_count = 0 и состояние IDLE - значит был Tie draw
		was_tie_draw = (hb_manager.chance_count == 0 and hb_manager.current_state == HeartBetManager.State.IDLE)
	
	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ТРИГГЕРОВ Heart Bet ДО СБРОСА!
	# Если в этом раунде тоже был триггер - сохраняем его
	# ═══════════════════════════════════════════════════════════════════
	var new_trigger_available = false
	if phase_manager and phase_manager.heart_bet_manager:
		# Проверяем триггеры (сработает если была натуральная победа или банкир с 6)
		phase_manager._check_heart_bet_triggers()
		new_trigger_available = phase_manager.heart_bet_manager.is_available()
		DebugLogger.log("❤️ Проверка триггеров после Heart Bet раунда: %s" % ("сработал!" if new_trigger_available else "нет"))
	
	# ВАЖНО: Восстанавливаем ставки гостей из backup ПЕРЕД reset(),
	# чтобы они не были очищены при сбросе раунда
	# При Tie draw ставки НЕ восстанавливаем (они будут очищены в reset)
	if not was_tie_draw:
		if phase_manager and phase_manager.guest_bet_storage:
			# Проверяем, есть ли backup для восстановления
			if phase_manager.guest_bet_storage.has_backup():
				phase_manager.guest_bet_storage.restore_all_bets()
				DebugLogger.log("❤️ Ставки гостей восстановлены из backup перед reset()")
			else:
				DebugLogger.log("⚠️ Нет backup для восстановления ставок гостей")
	
	if phase_manager:
		# Сбрасываем флаг Heart Bet раунда
		phase_manager.was_heart_bet_round = false
		# При Tie draw НЕ сохраняем ставки гостей (они будут очищены в reset)
		# Если НЕ было Tie draw, то keep_guest_bets=true - ставки сохранятся
		# (они уже восстановлены из backup выше)
		phase_manager.reset(true, not was_tie_draw)  # update_state=true, keep_guest_bets=!was_tie_draw
		phase_manager.is_table_prepared = true  # Готовы к новой раздаче
		DebugLogger.log("❤️ Раунд сброшен, готов к новой раздаче (Tie draw: %s, keep_guest_bets: %s)" % [was_tie_draw, not was_tie_draw])
	
	# Восстанавливаем ФИШКИ ставок гостей ТОЛЬКО если НЕ было Tie draw
	# ВАЖНО: Используем _show_guest_bets() вместо show_all_guest_chips(),
	# потому что фишки (узлы) могли быть удалены во время Heart Bet раунда
	if not was_tie_draw and phase_manager:
		# Проверяем, что ставки действительно есть в хранилище
		if phase_manager.guest_bet_storage:
			var guests_with_bets = phase_manager.guest_bet_storage.get_guests_with_bets()
			if guests_with_bets.size() > 0:
				phase_manager._show_guest_bets()
				DebugLogger.log("❤️ Фишки ставок гостей пересозданы (%d гостей с ставками)" % guests_with_bets.size())
			else:
				DebugLogger.log("⚠️ Нет ставок гостей для отображения после восстановления")
	elif was_tie_draw:
		DebugLogger.log("❤️ Tie draw: ставки гостей очищены, новые будут показаны при начале новой раздачи")
		# При Tie draw ставки очищены, новые будут сгенерированы и показаны
		# при начале новой раздачи через _complete_round_and_prepare_new_game()
	
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Автоматический показ сердец УБРАН!
	# Карта шанса уже видна (если есть шансы), игрок сам нажмёт когда захочет
	# ═══════════════════════════════════════════════════════════════════
	if phase_manager and phase_manager.heart_bet_manager:
		var chances = phase_manager.heart_bet_manager.get_chance_count()
		if chances > 0:
			DebugLogger.log("❤️ Шансов доступно: %d (игрок может использовать карту)" % chances)
