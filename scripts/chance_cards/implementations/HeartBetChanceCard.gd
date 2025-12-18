# res://scripts/chance_cards/implementations/HeartBetChanceCard.gd
# Карта шанса для Heart Bet (Ставка сердцем)
# Наследует BaseChanceCard и реализует логику Heart Bet

extends BaseChanceCard

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init():
	card_id = "heart_bet"
	
	# Загружаем текстуру карты
	if ResourceLoader.exists("res://assets/ui/invitation_card.png"):
		card_texture = load("res://assets/ui/invitation_card.png")
	else:
		# Заглушка
		if ResourceLoader.exists("res://assets/ui/heart_focus.png"):
			card_texture = load("res://assets/ui/heart_focus.png")
		else:
			card_texture = preload("res://assets/ui/heart.png")
		print("⚠️ HeartBetChanceCard: invitation_card.png не найден, используем заглушку")
	
	# Инициализируем счётчик из HeartBetManager если доступен
	# (будет обновлён через EventBus.chance_count_changed)
	count = 0
	
	print("❤️ HeartBetChanceCard инициализирована")

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕОПРЕДЕЛЕНИЕ ВИРТУАЛЬНЫХ МЕТОДОВ
# ═══════════════════════════════════════════════════════════════════════════

func can_use() -> bool:
	"""Проверка, можно ли использовать карту"""
	# Получаем HeartBetManager через GamePhaseManager
	# (используем EventBus для изоляции)
	var phase_manager = _get_phase_manager()
	if not phase_manager or not phase_manager.heart_bet_manager:
		print("⚠️ HeartBetChanceCard.can_use(): phase_manager или heart_bet_manager не найден")
		return false
	
	var hb_manager = phase_manager.heart_bet_manager
	
	# Проверяем состояние и количество
	var state_name = hb_manager.get_state_name()
	if state_name != "IDLE":
		print("⚠️ HeartBetChanceCard.can_use(): HeartBetManager не в состоянии IDLE (текущее: %s)" % state_name)
		return false
	
	if count <= 0:
		print("⚠️ HeartBetChanceCard.can_use(): нет доступных шансов (count=%d)" % count)
		return false
	
	# Проверяем состояние игры
	# Карту можно использовать в WAITING (перед раздачей) или CHOOSE_WINNER (между раундами)
	var game_state = GameStateManager.current_state
	if game_state not in [GameStateManager.GameState.WAITING, GameStateManager.GameState.CHOOSE_WINNER]:
		var game_state_name = GameStateManager.get_state_name(game_state)
		print("⚠️ HeartBetChanceCard.can_use(): игра не в состоянии WAITING или CHOOSE_WINNER (текущее: %s)" % game_state_name)
		return false
	
	return true

func on_use() -> void:
	"""Использовать карту - вызвать HeartBetManager.use_chance()"""
	var phase_manager = _get_phase_manager()
	if not phase_manager or not phase_manager.heart_bet_manager:
		push_error("⚠️ HeartBetChanceCard: HeartBetManager не найден")
		return
	
	var hb_manager = phase_manager.heart_bet_manager
	var success = hb_manager.use_chance()
	
	if not success:
		push_warning("⚠️ HeartBetChanceCard: не удалось использовать шанс")
		EventBus.show_toast_error.emit(Localization.t("CANNOT_USE_CHANCE"))
	else:
		print("❤️ HeartBetChanceCard: шанс использован успешно")

func get_card_name() -> String:
	"""Получить имя карты для локализации"""
	return "HEART_BET_CHANCE"

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _get_phase_manager():
	"""Получить GamePhaseManager через ChanceCardManager"""
	return ChanceCardManager.phase_manager
