# res://scripts/ui/GuestEventHandler.gd
# Обработчик событий, связанных с гостями
# Инкапсулирует логику управления видимостью гостей, их ставками и балансами

class_name GuestEventHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var owner_node: Node2D  # Узел-владелец (для создания tween и доступа к get_tree())
var phase_manager: GamePhaseManager  # Для доступа к guest_bet_storage
var chip_visual_manager: ChipVisualManager  # Для работы с фишками
var guest_sprites: Dictionary  # Словарь спрайтов гостей {guest_id: Sprite2D}
var background_666: Node  # Фон для Heart Bet (для проверки активной атмосферы)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	owner: Node2D,
	phase_mgr: GamePhaseManager,
	chip_mgr: ChipVisualManager,
	sprites: Dictionary,
	bg_666: Node
) -> void:
	owner_node = owner
	phase_manager = phase_mgr
	chip_visual_manager = chip_mgr
	guest_sprites = sprites
	background_666 = bg_666
	DebugLogger.log("✅ GuestEventHandler инициализирован")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ИЗМЕНЕНИЙ НАСТРОЕК ГОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func handle_guest_settings_changed(guest_id: int) -> void:
	"""Настройки гостя изменились - очищаем его фишки если отключён
	
	Args:
		guest_id: ID гостя (1-6)
	"""
	if GuestSettingsManager.is_guest_enabled(guest_id):
		return  # Гость включён - ничего не делаем
	
	# ═══════════════════════════════════════════════════════════════════
	# ЗАЩИТА: Не очищаем ставки во время раздачи
	# Ставки можно удалять ТОЛЬКО в состоянии WAITING (до начала раздачи)
	# Во всех остальных состояниях (включая CHOOSE_WINNER) ставки остаются
	# до полного завершения раунда (сбор/оплата всех ставок)
	# ═══════════════════════════════════════════════════════════════════
	var current_state = GameStateManager.get_current_state()
	if current_state != GameStateManager.GameState.WAITING:
		DebugLogger.log("👥 Гость %d отключён, но идёт раздача (состояние: %s) - ставки останутся до конца раунда" % [guest_id, GameStateManager.get_state_name(current_state)])
		# НЕ очищаем ставки из хранилища и НЕ скрываем визуальные фишки
		# Ставки останутся видимыми и будут использованы в текущей раздаче
		# В следующей раздаче ставки не будут сгенерированы (гость отключен)
		return
	
	DebugLogger.log("👥 Гость %d отключён - очищаем его фишки" % guest_id)
	# Очищаем фишки этого гостя из хранилища
	if phase_manager and phase_manager.guest_bet_storage:
		phase_manager.guest_bet_storage.clear_guest_bets(guest_id)
	# Скрываем визуальные фишки этого гостя
	if chip_visual_manager:
		chip_visual_manager.clear_guest_chips_for_sector(guest_id)

func handle_guest_settings_changed_visibility(guest_id: int) -> void:
	"""Обновить видимость гостей при изменении настроек (не во время Heart Bet)
	
	Args:
		guest_id: ID гостя (1-6)
	"""
	# Проверяем, не активна ли сейчас игра на жизнь
	# Если Background666 видим - значит активна мистическая атмосфера
	if background_666 and background_666.visible:
		# Во время игры на жизнь не обновляем видимость обычных гостей
		return
	
	# Обновляем видимость конкретного гостя с анимацией
	var sprite = guest_sprites.get(guest_id)
	if sprite and guest_id != 666:  # Не трогаем G_666
		var is_enabled = GuestSettingsManager.is_guest_enabled(guest_id)
		if is_enabled:
			# Fade-in 0.5 сек
			sprite.visible = true
			sprite.modulate.a = 0.0
			_create_fade_animation(sprite, 0.0, 1.0, 0.5)
			DebugLogger.log("👥 Гость %d: fade-in 0.5 сек" % guest_id)
		else:
			# Fade-out 0.5 сек
			_create_fade_animation(sprite, 1.0, 0.0, 0.5, func(): sprite.visible = false)
			DebugLogger.log("👥 Гость %d: fade-out 0.5 сек" % guest_id)

func update_guests_visibility() -> void:
	"""Обновить видимость гостей на основе их состояния в GuestSettingsManager"""
	# Инициализируем обычных гостей (1-6)
	for guest_id in range(1, 7):
		var sprite = guest_sprites.get(guest_id)
		if sprite:
			var is_enabled = GuestSettingsManager.is_guest_enabled(guest_id)
			# Устанавливаем видимость без анимации при инициализации
			sprite.visible = is_enabled
			sprite.modulate.a = 1.0 if is_enabled else 0.0
			DebugLogger.log("👥 Гость %d: %s" % [guest_id, "видим" if is_enabled else "скрыт"])
	
	# G_666 всегда скрыт в обычном состоянии
	var guest_666 = guest_sprites.get(666)
	if guest_666:
		guest_666.visible = false
		guest_666.modulate.a = 0.0
	
	# Background666 всегда скрыт в обычном состоянии
	if background_666:
		background_666.visible = false
		background_666.modulate.a = 0.0

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СТАВОК ГОСТЕЙ (Heart Bet)
# ═══════════════════════════════════════════════════════════════════════════

func handle_guest_bets_hide_requested() -> void:
	"""Скрыть ставки гостей при выборе сердца для Heart Bet"""
	# ВАЖНО: Сначала сохраняем ставки в backup, затем скрываем
	if phase_manager and phase_manager.guest_bet_storage:
		phase_manager.guest_bet_storage.backup_all_bets()
		# Очищаем текущие ставки (чтобы они не показывались в Heart Bet раунде)
		phase_manager.guest_bet_storage.clear_all_bets()
	
	if chip_visual_manager:
		chip_visual_manager.hide_all_guest_chips()
		DebugLogger.log("❤️ GuestEventHandler: ставки гостей скрыты и сохранены в backup")

func handle_guest_bets_show_requested() -> void:
	"""Показать ставки гостей после завершения Heart Bet раздачи"""
	# ВАЖНО: Используем _show_guest_bets() вместо show_all_guest_chips(),
	# потому что фишки (узлы) могли быть удалены во время Heart Bet раунда
	if phase_manager:
		phase_manager._show_guest_bets()
		DebugLogger.log("❤️ GuestEventHandler: фишки ставок гостей пересозданы")

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ БАЛАНСА ГОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func update_guest_balance_for_bet(bet_type: String, position_index: int, payout: float) -> void:
	"""Обновить баланс гостя при правильной выплате
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции
		payout: Размер выплаты
	"""
	if not phase_manager or not phase_manager.guest_bet_storage:
		return
	
	# Определяем сектор по position_index
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	if sector < 1 or sector > 6:
		# Не гостевые ставки - пропускаем
		return
	
	var guest_id = sector  # Сектор = ID гостя
	
	# Находим ставку гостя в хранилище
	var guest_bets = phase_manager.guest_bet_storage.get_guest_bets(guest_id)
	for bet in guest_bets:
		if bet.get_bet_type() == bet_type and bet.get_position_index() == position_index:
			# Нашли ставку гостя
			# Обновляем баланс: добавляем payout (выигрыш) и вычитаем stake (ставка уже поставлена)
			var net_profit = payout - bet.get_stake()
			GuestStatsManager.add_to_balance(guest_id, net_profit)
			DebugLogger.log("💰 Гость %d: баланс обновлён (+%.0f - %.0f = %.0f)" % [guest_id, payout, bet.get_stake(), net_profit])
			return
	
	DebugLogger.log_warning("⚠️ Не найдена ставка гостя для %s[%d] в секторе %d" % [bet_type, position_index, sector])

func update_guest_balance_on_collect(bet_type: String, position_index: int) -> void:
	"""Обновить баланс гостя при сборе проигрышной ставки
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции
	"""
	if not phase_manager or not phase_manager.guest_bet_storage:
		return
	
	# Определяем сектор по position_index
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	if sector < 1 or sector > 6:
		# Не гостевые ставки - пропускаем
		return
	
	var guest_id = sector  # Сектор = ID гостя
	
	# Находим ставку гостя в хранилище
	var guest_bets = phase_manager.guest_bet_storage.get_guest_bets(guest_id)
	for bet in guest_bets:
		if bet.get_bet_type() == bet_type and bet.get_position_index() == position_index:
			# Нашли ставку гостя
			# Вычитаем stake (ставка проиграла)
			var stake = bet.get_stake()
			GuestStatsManager.subtract_from_balance(guest_id, stake)
			DebugLogger.log("💰 Гость %d: баланс обновлён (-%.0f при сборе)" % [guest_id, stake])
			return
	
	DebugLogger.log_warning("⚠️ Не найдена ставка гостя для %s[%d] в секторе %d" % [bet_type, position_index, sector])

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _create_fade_animation(node: Node, from_alpha: float, to_alpha: float, duration: float, callback: Callable = Callable()) -> void:
	"""Создать fade анимацию для узла
	
	Args:
		node: Узел для анимации
		from_alpha: Начальная прозрачность
		to_alpha: Конечная прозрачность
		duration: Длительность анимации
		callback: Callback после завершения анимации
	"""
	if not node or not owner_node:
		return
	
	node.modulate.a = from_alpha
	var tween = owner_node.create_tween()
	tween.tween_property(node, "modulate:a", to_alpha, duration)
	if callback.is_valid():
		tween.tween_callback(callback)

