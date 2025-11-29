# ═══════════════════════════════════════════════════════════════════════════
# КОД ДЛЯ ДОБАВЛЕНИЯ В GameController.gd
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────
# ШАГ 1: ДОБАВИТЬ ПОСЛЕ СТРОКИ 19 (после is_survival_mode)
# ───────────────────────────────────────────────────────────────────────────

# Новые менеджеры для фишек и выплат
var chip_visual_manager: ChipVisualManager
var winner_selection_manager: WinnerSelectionManager
var payout_queue_manager: PayoutQueueManager
var pair_betting_manager: PairBettingManager

# ───────────────────────────────────────────────────────────────────────────
# ШАГ 2: ДОБАВИТЬ В _ready() ПОСЛЕ СТРОКИ 99 (после GameStateManager.reset())
# ───────────────────────────────────────────────────────────────────────────

	# Инициализация новых менеджеров
	_setup_new_managers()
	_setup_payout_toggles()
	_setup_pair_toggles()

# ───────────────────────────────────────────────────────────────────────────
# ШАГ 3: ДОБАВИТЬ ЭТИ МЕТОДЫ В КОНЕЦ ФАЙЛА (после всех существующих методов)
# ───────────────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════
# НОВЫЕ МЕНЕДЖЕРЫ - ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _setup_new_managers():
	"""Инициализация новых менеджеров для фишек и пар"""

	# ChipVisualManager
	chip_visual_manager = ChipVisualManager.new()
	var chip_player = get_node_or_null("ChipPlayer")
	var chip_banker = get_node_or_null("ChipBanker")
	var chip_tie = get_node_or_null("ChipTie")
	var chip_pair_player = get_node_or_null("ChipPairPlayer")
	var chip_pair_banker = get_node_or_null("ChipPairBanker")

	if chip_player and chip_banker and chip_tie:
		chip_visual_manager.setup(chip_player, chip_banker, chip_tie, chip_pair_player, chip_pair_banker)
		chip_visual_manager.chip_clicked.connect(_on_chip_clicked)
		print("✅ ChipVisualManager инициализирован")
	else:
		push_warning("⚠️  Узлы фишек не найдены в сцене")

	# WinnerSelectionManager
	winner_selection_manager = WinnerSelectionManager.new()
	var player_marker = get_node_or_null("PlayerMarker")
	var banker_marker = get_node_or_null("BankerMarker")
	var tie_marker = get_node_or_null("TieMarker")

	if player_marker and banker_marker and tie_marker:
		winner_selection_manager.setup(player_marker, banker_marker, tie_marker)
		winner_selection_manager.winner_toggled.connect(_on_winner_toggled)
		print("✅ WinnerSelectionManager инициализирован")
	else:
		push_warning("⚠️  Маркеры не найдены в сцене")

	# PayoutQueueManager
	payout_queue_manager = PayoutQueueManager.new()
	print("✅ PayoutQueueManager инициализирован")

	# PairBettingManager
	pair_betting_manager = PairBettingManager.new()
	pair_betting_manager.pair_detected.connect(_on_pair_detected)
	print("✅ PairBettingManager инициализирован")


func _setup_payout_toggles():
	"""Настройка toggles для основных ставок"""

	var player_toggle = get_node_or_null("PayoutTogglePlayer")
	var banker_toggle = get_node_or_null("PayoutToggleBanker")
	var tie_toggle = get_node_or_null("PayoutToggleTie")

	if not player_toggle or not banker_toggle or not tie_toggle:
		print("⚠️  PayoutToggle кнопки не найдены (пропускаем)")
		return

	# Включаем toggle mode
	player_toggle.toggle_mode = true
	banker_toggle.toggle_mode = true
	tie_toggle.toggle_mode = true

	# Устанавливаем начальное состояние
	if PayoutSettingsManager:
		player_toggle.button_pressed = PayoutSettingsManager.player_payout_enabled
		banker_toggle.button_pressed = PayoutSettingsManager.banker_payout_enabled
		tie_toggle.button_pressed = PayoutSettingsManager.tie_payout_enabled

		# Показываем фишки если включено
		if player_toggle.button_pressed and chip_visual_manager:
			chip_visual_manager.show_chip("Player")
		if banker_toggle.button_pressed and chip_visual_manager:
			chip_visual_manager.show_chip("Banker")
		if tie_toggle.button_pressed and chip_visual_manager:
			chip_visual_manager.show_chip("Tie")

	# Подключаем сигналы
	player_toggle.toggled.connect(_on_payout_toggle_player)
	banker_toggle.toggled.connect(_on_payout_toggle_banker)
	tie_toggle.toggled.connect(_on_payout_toggle_tie)

	print("✅ Toggles основных ставок настроены")


func _setup_pair_toggles():
	"""Настройка toggles для ставок на пары"""

	var pair_player_toggle = get_node_or_null("PayoutTogglePairPlayer")
	var pair_banker_toggle = get_node_or_null("PayoutTogglePairBanker")

	if not pair_player_toggle or not pair_banker_toggle:
		print("⚠️  Toggles для пар не найдены (пропускаем)")
		return

	# Включаем toggle mode
	pair_player_toggle.toggle_mode = true
	pair_banker_toggle.toggle_mode = true

	# Подключаем сигналы
	pair_player_toggle.toggled.connect(_on_payout_toggle_pair_player)
	pair_banker_toggle.toggled.connect(_on_payout_toggle_pair_banker)

	print("✅ Toggles пар настроены")


# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ TOGGLES
# ═══════════════════════════════════════════════════════════════════════════

func _on_payout_toggle_player(enabled: bool):
	"""Переключатель ставки на игрока"""
	if PayoutSettingsManager:
		PayoutSettingsManager.toggle_player(enabled)

	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("Player")
		else:
			chip_visual_manager.hide_chip("Player")


func _on_payout_toggle_banker(enabled: bool):
	"""Переключатель ставки на банкира"""
	if PayoutSettingsManager:
		PayoutSettingsManager.toggle_banker(enabled)

	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("Banker")
		else:
			chip_visual_manager.hide_chip("Banker")


func _on_payout_toggle_tie(enabled: bool):
	"""Переключатель ставки на ничью"""
	if PayoutSettingsManager:
		PayoutSettingsManager.toggle_tie(enabled)

	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("Tie")
		else:
			chip_visual_manager.hide_chip("Tie")


func _on_payout_toggle_pair_player(enabled: bool):
	"""Переключатель ставки на пару игрока"""
	if pair_betting_manager:
		pair_betting_manager.toggle_pair_player_bet(enabled)

	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("PairPlayer")
		else:
			chip_visual_manager.hide_chip("PairPlayer")


func _on_payout_toggle_pair_banker(enabled: bool):
	"""Переключатель ставки на пару банкира"""
	if pair_betting_manager:
		pair_betting_manager.toggle_pair_banker_bet(enabled)

	if chip_visual_manager:
		if enabled:
			chip_visual_manager.show_chip("PairBanker")
		else:
			chip_visual_manager.hide_chip("PairBanker")


# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_winner_toggled(winner: String, selected: bool):
	"""Обработка переключения маркера победителя"""
	if selected:
		print("🎯 Выбран: %s" % winner)
	else:
		print("🎯 Снят выбор: %s" % winner)


func _on_chip_clicked(bet_type: String):
	"""Обработка клика на фишку - переход в PayoutScene"""
	print("🖱️  Клик на фишку: %s" % bet_type)

	if not payout_queue_manager:
		return

	var bet = payout_queue_manager.get_bet_by_type(bet_type)
	if not bet:
		ToastManager.instance.show_error("Нет ставки %s" % bet_type)
		return

	if not bet.won:
		ToastManager.instance.show_error("Эта ставка не выиграла")
		return

	if bet.is_paid:
		ToastManager.instance.show_info("Эта ставка уже оплачена")
		return

	# Открываем PayoutScene
	_open_payout_scene(bet_type, bet.stake, bet.payout)


func _on_pair_detected(pair_type: String):
	"""Обработка обнаружения пары"""
	ToastManager.instance.show_info("🃏 Обнаружена %s!" % pair_type)


func _open_payout_scene(bet_type: String, stake: float, expected_payout: float):
	"""Открыть сцену выплаты"""

	# Сохраняем контекст
	PayoutContextManager.set_context({
		"bet_type": bet_type,
		"stake": stake,
		"expected_payout": expected_payout,
		"return_to_game": true
	})

	# Переходим в PayoutScene
	get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")


# ═══════════════════════════════════════════════════════════════════════════
# КОНЕЦ КОДА ДЛЯ ИНТЕГРАЦИИ
# ═══════════════════════════════════════════════════════════════════════════
