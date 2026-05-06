# res://scripts/GameInitializer.gd
# Класс для извлечения инициализационной логики из GameController
# Использование: GameInitializer.initialize(controller)

class_name GameInitializer

## Главный метод инициализации GameController
## Возвращает словарь с инициализированными менеджерами
static func initialize(controller: Node2D) -> Dictionary:
	"""Инициализация всех подсистем GameController

	Args:
		controller: ссылка на GameController

	Returns:
		Dictionary с ключами:
		- deck: Deck
		- config: GameConfig
		- card_manager: CardTextureManager
		- ui_manager: UIManager
		- limits_manager: LimitsManager
		- survival_ui: Control
		- game_over_popup: Control
		- settings_scene: Node
		- settings_button: Button
		- phase_manager: GamePhaseManager
		- bet_collection_manager: BetCollectionPhaseManager
		- chip_visual_manager: ChipVisualManager
		- winner_selection_manager: WinnerSelectionManager
		- pair_betting_manager: PairBettingManager
		- camera_manager: CameraManager
		- payout_overlay: CanvasLayer
		- is_payout_return: bool
	"""
	var result: Dictionary = {}

	# 1. Инициализация базовых менеджеров
	_initialize_core_managers(controller, result)

	# 2. Настройка SettingsScene и загрузка режима игры
	_setup_settings_and_mode(controller, result)

	# 3. Создание вспомогательных менеджеров (chip, winner, pair)
	_setup_auxiliary_managers(controller, result)

	# 4. Создание GamePhaseManager с DI
	_setup_phase_manager(controller, result)

	# 5. Подключение сигналов UIManager
	_connect_ui_signals(controller, result)

	# 6. Настройка менеджера сбора ставок
	_setup_bet_collection(controller, result)

	# 7. Обработка возврата из PayoutScene или reset
	var is_payout_return: bool = _handle_payout_scene_return_or_reset(controller, result)
	result["is_payout_return"] = is_payout_return

	# 8. Инициализация видимости фишек
	_initialize_chips_visibility(controller, result, is_payout_return)

	# 9. Подписка на события EventBus
	_setup_event_subscriptions(controller, result)

	# 10. Финальная настройка: limits, stats, camera, UI
	_finalize_setup(controller, result)

	# 11. Проверка возврата из PayoutScene
	_check_payout_return(controller, result)

	return result


# ═══════════════════════════════════════════════════════════════════════════
# HELPER МЕТОДЫ ИНИЦИАЛИЗАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

static func _initialize_core_managers(controller: Node2D, result: Dictionary) -> void:
	"""Инициализация базовых менеджеров и компонентов"""
	# Загружаем сохраненный язык
	var saved_lang = SaveManager.load_language()
	Localization.set_lang(saved_lang)

	var deck_rng: RandomNumberGenerator = null
	if Engine.has_singleton("SessionManager"):
		var sm: Node = Engine.get_singleton("SessionManager")
		if sm.current_mode == sm.Mode.ONLINE:
			var seed_hex: String = str(sm.live_round_seed)
			if not seed_hex.is_empty():
				deck_rng = LiveSeedRng.make_rng(seed_hex)
	result["deck"] = Deck.new(deck_rng)
	result["config"] = controller.config if controller.config else GameConfig.new()
	result["card_manager"] = CardTextureManager.new(result["config"])

	var ui_manager: UIManager = UIManager.new(controller, result["card_manager"])
	ui_manager.set_main_node(controller)
	ui_manager.set_flip_cards(controller.flip_cards)
	result["ui_manager"] = ui_manager

	StatsManager.instance.set_label(ui_manager.stats_label)
	result["limits_manager"] = LimitsManager.new(result["config"])

	var survival_ui: Control = controller.get_node("TopUI/SurvivalModeUI")
	survival_ui.game_over.connect(controller._on_survival_game_over)
	result["survival_ui"] = survival_ui


	result["game_over_popup"] = controller.get_node("GameOverScene")

	# Game Over теперь только через сердца (HeartBar.game_over)
	# score_game_over удалён - деньги не вызывают game over


static func _setup_settings_and_mode(controller: Node2D, result: Dictionary) -> void:
	"""Настройка SettingsScene и загрузка режима игры"""
	# Настройка SettingsScene
	if controller.has_node("SettingsScene"):
		DebugLogger.log_init("SettingsScene найден в сцене!")
		var settings_scene: Node = controller.get_node("SettingsScene")
		# Сигналы подключаются после инициализации settings_handler в _ready()
		# settings_scene.mode_changed.connect(controller._on_mode_changed)
		# settings_scene.language_changed.connect(controller._on_language_changed)
		# survival_mode_changed удалён - режим выживания всегда включён
		result["settings_scene"] = settings_scene
		DebugLogger.log_init("SettingsScene подключен к GameController")
	else:
		DebugLogger.log_error("SettingsScene НЕ НАЙДЕН в сцене Game.tscn!")

	# Настройка кнопки настроек
	if controller.has_node("SettingsButton"):
		var settings_button: Button = controller.get_node("SettingsButton")
		settings_button.pressed.connect(controller._on_settings_button_pressed)
		result["settings_button"] = settings_button

	# Загрузка режима игры
	GameModeManager.load_saved_mode()

	# ← ВАЖНО: Присваиваем необходимые поля ДО вызова _load_survival_mode_setting()
	controller.survival_ui = result["survival_ui"]
	controller.ui_manager = result["ui_manager"]
	controller.settings_scene = result.get("settings_scene")
	controller._load_survival_mode_setting()


static func _setup_auxiliary_managers(controller: Node2D, result: Dictionary) -> void:
	"""Создание вспомогательных менеджеров (chip, winner, pair)"""
	# ChipVisualManager
	var chip_visual_manager: ChipVisualManager = ChipVisualManager.new()
	var chip_player: Node = controller.get_node_or_null("ChipPlayer")
	var chip_banker: Node = controller.get_node_or_null("ChipBanker")
	var chip_tie: Node = controller.get_node_or_null("ChipTie")
	var chip_pair_player: Node = controller.get_node_or_null("ChipPairPlayer")
	var chip_pair_banker: Node = controller.get_node_or_null("ChipPairBanker")

	if chip_player and chip_banker and chip_tie:
		chip_visual_manager.setup(chip_player, chip_banker, chip_tie, chip_pair_player, chip_pair_banker, controller)
		chip_visual_manager.chip_clicked.connect(controller._on_chip_clicked)
		chip_visual_manager.chip_instance_clicked.connect(controller._on_chip_instance_clicked)

		# Режим всегда GUEST
		chip_visual_manager.set_position_mode(ChipVisualManager.PositionMode.GUEST)
		DebugLogger.log("✅ ChipVisualManager инициализирован (position_mode=GUEST)")
	else:
		push_warning("⚠️  Узлы фишек не найдены в сцене")

	result["chip_visual_manager"] = chip_visual_manager

	# WinnerSelectionManager
	var winner_selection_manager: WinnerSelectionManager = WinnerSelectionManager.new()
	var player_marker: Node = controller.get_node_or_null("PlayerMarker")
	var banker_marker: Node = controller.get_node_or_null("BankerMarker")
	var tie_marker: Node = controller.get_node_or_null("TieMarker")

	if player_marker and banker_marker:
		winner_selection_manager.setup(player_marker, banker_marker, tie_marker)
		winner_selection_manager.winner_toggled.connect(controller._on_winner_toggled)
		# Отключаем фокус для маркеров, чтобы они не реагировали на пробел
		player_marker.focus_mode = Control.FOCUS_NONE
		banker_marker.focus_mode = Control.FOCUS_NONE
		if tie_marker:
			tie_marker.focus_mode = Control.FOCUS_NONE
		var marker_list = "Player, Banker" + (", Tie" if tie_marker else "")
		DebugLogger.log_init("WinnerSelectionManager инициализирован (%s)" % marker_list)
	
	# Отключаем фокус для кнопки "Карты", чтобы она не реагировала на пробел
	var ui_manager: UIManager = result.get("ui_manager")
	if ui_manager and ui_manager.button_ui:
		if ui_manager.button_ui.action_button:
			ui_manager.button_ui.action_button.focus_mode = Control.FOCUS_NONE
			DebugLogger.log_init("CardsButton: фокус отключен (не реагирует на пробел)")
		if ui_manager.button_ui.action_button_broken:
			ui_manager.button_ui.action_button_broken.focus_mode = Control.FOCUS_NONE
			DebugLogger.log_init("CardsButtonBroken: фокус отключен (не реагирует на пробел)")

	result["winner_selection_manager"] = winner_selection_manager

	# PairBettingManager
	result["pair_betting_manager"] = PairBettingManager.new()
	DebugLogger.log_init("PairBettingManager инициализирован")
	_apply_runtime_payout_state(result["pair_betting_manager"])

	# PayoutQueueManager (создается пустым, будет пересоздан при подготовке выплат)
	result["payout_queue_manager"] = PayoutQueueManager.new()
	DebugLogger.log_init("PayoutQueueManager инициализирован (пустой)")

	# HandManager (Task 2.2 - управление руками игрока и банкира)
	result["hand_manager"] = HandManager.new()
	DebugLogger.log_init("HandManager инициализирован")


static func _apply_runtime_payout_state(pair_betting_manager: PairBettingManager) -> void:
	var session_manager: Variant = null
	if Engine.has_singleton("SessionManager"):
		session_manager = Engine.get_singleton("SessionManager")
	else:
		var tree := Engine.get_main_loop()
		if tree is SceneTree:
			session_manager = (tree as SceneTree).root.get_node_or_null("SessionManager")

	if session_manager != null and session_manager.current_mode == session_manager.Mode.TOURNAMENT:
		_apply_tournament_payout_state(session_manager, pair_betting_manager)
		_apply_tournament_first_four_cards(session_manager)
		_apply_tournament_chance_cards_enabled(session_manager)
		_apply_tournament_tip_percentage(session_manager)
		return

	_clear_tournament_chance_cards_enabled_override()
	_clear_tournament_tip_percentage_override()
	_restore_local_payout_state(pair_betting_manager)


static func _apply_tournament_payout_state(session_manager: Variant, pair_betting_manager: PairBettingManager) -> void:
	var player_enabled := PayoutSettingsManager.player_payout_enabled
	var banker_enabled := PayoutSettingsManager.banker_payout_enabled
	var tie_enabled := PayoutSettingsManager.tie_payout_enabled
	var pairs_enabled := PayoutSettingsManager.player_pair_payout_enabled and PayoutSettingsManager.banker_pair_payout_enabled

	var tournament_settings_variant: Variant = session_manager.tournament_settings
	if tournament_settings_variant is Dictionary:
		var tournament_settings := tournament_settings_variant as Dictionary
		if tournament_settings.has("bets") and tournament_settings["bets"] is Dictionary:
			var bets := tournament_settings["bets"] as Dictionary
			if bets.has("player") and bets["player"] is bool:
				player_enabled = bets["player"]
			if bets.has("banker") and bets["banker"] is bool:
				banker_enabled = bets["banker"]
			if bets.has("tie") and bets["tie"] is bool:
				tie_enabled = bets["tie"]
			if bets.has("pairs") and bets["pairs"] is bool:
				pairs_enabled = bets["pairs"]

	PayoutSettingsManager.set_all(player_enabled, banker_enabled, tie_enabled, pairs_enabled, pairs_enabled)
	if pair_betting_manager != null:
		pair_betting_manager.toggle_pair_player_bet(pairs_enabled)
		pair_betting_manager.toggle_pair_banker_bet(pairs_enabled)


static func _apply_tournament_first_four_cards(session_manager: Variant) -> void:
	if TestCardsManager == null:
		print("🧪 TOURNAMENT SETTINGS TRACE first_four_cards: TestCardsManager not available")
		return

	var tournament_settings_variant: Variant = session_manager.tournament_settings
	if not (tournament_settings_variant is Dictionary):
		print("🧪 TOURNAMENT SETTINGS TRACE first_four_cards: tournament_settings missing")
		return

	var tournament_settings := tournament_settings_variant as Dictionary
	if not tournament_settings.has("first_four_cards"):
		print("🧪 TOURNAMENT SETTINGS TRACE first_four_cards: not found")
		return
	if not (tournament_settings["first_four_cards"] is Dictionary):
		print("🧪 TOURNAMENT SETTINGS TRACE first_four_cards: invalid type")
		return

	var first_four_cards := tournament_settings["first_four_cards"] as Dictionary
	print("🧪 TOURNAMENT SETTINGS TRACE first_four_cards: found")

	TestCardsManager.clear_all()

	var mappings: Array[Dictionary] = [
		{"source": "player_1", "target": "player1"},
		{"source": "player_2", "target": "player2"},
		{"source": "banker_1", "target": "banker1"},
		{"source": "banker_2", "target": "banker2"}
	]
	var applied_positions: Array[String] = []
	var has_fixed_cards := false

	for mapping_variant in mappings:
		if not (mapping_variant is Dictionary):
			continue
		var mapping := mapping_variant as Dictionary
		if not mapping.has("source") or not mapping.has("target"):
			continue

		var source_key := str(mapping["source"]).strip_edges()
		var target_key := str(mapping["target"]).strip_edges()
		var raw_value := ""
		if first_four_cards.has(source_key):
			raw_value = str(first_four_cards[source_key]).strip_edges()

		if raw_value.is_empty() or raw_value.to_upper() == "RANDOM":
			continue

		var card_value := _map_tournament_card_value(raw_value)
		if card_value <= 0:
			print("🧪 TOURNAMENT SETTINGS TRACE first_four_cards: skip unknown value key=%s value=%s" % [
				source_key,
				raw_value
			])
			continue

		TestCardsManager.set_test_card(target_key, 0, card_value)
		has_fixed_cards = true
		applied_positions.append("%s=%s" % [target_key, raw_value.to_upper()])

	TestCardsManager.set_enabled(has_fixed_cards)

	print("🧪 TOURNAMENT SETTINGS TRACE first_four_cards applied=%s enabled=%s" % [
		str(applied_positions),
		"true" if has_fixed_cards else "false"
	])
	if TestCardsManager.has_method("get_summary"):
		print("🧪 TOURNAMENT SETTINGS TRACE first_four_cards summary=%s" % str(TestCardsManager.get_summary()))


static func _map_tournament_card_value(raw_value: String) -> int:
	var normalized := raw_value.strip_edges().to_upper()
	if normalized.is_empty():
		return 0

	match normalized:
		"A":
			return 1
		"2":
			return 2
		"3":
			return 3
		"4":
			return 4
		"5":
			return 5
		"6":
			return 6
		"7":
			return 7
		"8":
			return 8
		"9":
			return 9
		"10":
			return 10
		"J":
			return 11
		"Q":
			return 12
		"K":
			return 13
		_:
			return 0


static func _apply_tournament_chance_cards_enabled(session_manager: Variant) -> void:
	if SaveManager == null or SaveManager.instance == null:
		print("🧪 TOURNAMENT SETTINGS TRACE chance_cards_enabled: SaveManager not available")
		return

	var tournament_settings_variant: Variant = session_manager.tournament_settings
	if not (tournament_settings_variant is Dictionary):
		print("🧪 TOURNAMENT SETTINGS TRACE chance_cards_enabled: tournament_settings missing, override cleared")
		SaveManager.instance.clear_runtime_chance_cards_enabled_override()
		return

	var tournament_settings := tournament_settings_variant as Dictionary
	if not tournament_settings.has("chance_cards_enabled"):
		print("🧪 TOURNAMENT SETTINGS TRACE chance_cards_enabled: not found, override cleared")
		SaveManager.instance.clear_runtime_chance_cards_enabled_override()
		return
	if not (tournament_settings["chance_cards_enabled"] is bool):
		print("🧪 TOURNAMENT SETTINGS TRACE chance_cards_enabled: invalid type, override cleared")
		SaveManager.instance.clear_runtime_chance_cards_enabled_override()
		return

	var enabled := tournament_settings["chance_cards_enabled"] as bool
	SaveManager.instance.set_runtime_chance_cards_enabled_override(enabled)
	print("🧪 TOURNAMENT SETTINGS TRACE chance_cards_enabled applied=%s" % [
		"true" if enabled else "false"
	])


static func _clear_tournament_chance_cards_enabled_override() -> void:
	if SaveManager == null or SaveManager.instance == null:
		return
	SaveManager.instance.clear_runtime_chance_cards_enabled_override()
	print("🧪 TOURNAMENT SETTINGS TRACE chance_cards_enabled override cleared")


static func _apply_tournament_tip_percentage(session_manager: Variant) -> void:
	if SaveManager == null or SaveManager.instance == null:
		print("🧪 TOURNAMENT SETTINGS TRACE tip_percentage: SaveManager not available")
		return

	var tournament_settings_variant: Variant = session_manager.tournament_settings
	if not (tournament_settings_variant is Dictionary):
		print("🧪 TOURNAMENT SETTINGS TRACE tip_percentage: tournament_settings missing, override cleared")
		SaveManager.instance.clear_runtime_tip_percentage_override()
		return

	var tournament_settings := tournament_settings_variant as Dictionary
	if not tournament_settings.has("tip_percentage"):
		print("🧪 TOURNAMENT SETTINGS TRACE tip_percentage: not found, override cleared")
		SaveManager.instance.clear_runtime_tip_percentage_override()
		return

	var tip_variant: Variant = tournament_settings["tip_percentage"]
	if not (tip_variant is float) and not (tip_variant is int):
		print("🧪 TOURNAMENT SETTINGS TRACE tip_percentage: invalid type, override cleared")
		SaveManager.instance.clear_runtime_tip_percentage_override()
		return

	var tip_percentage := float(tip_variant)
	SaveManager.instance.set_runtime_tip_percentage_override(tip_percentage)
	print("🧪 TOURNAMENT SETTINGS TRACE tip_percentage applied=%.3f" % tip_percentage)


static func _clear_tournament_tip_percentage_override() -> void:
	if SaveManager == null or SaveManager.instance == null:
		return
	SaveManager.instance.clear_runtime_tip_percentage_override()
	print("🧪 TOURNAMENT SETTINGS TRACE tip_percentage override cleared")


static func _restore_local_payout_state(pair_betting_manager: PairBettingManager) -> void:
	var player_enabled := PayoutSettingsManager.player_payout_enabled
	var banker_enabled := PayoutSettingsManager.banker_payout_enabled
	var tie_enabled := PayoutSettingsManager.tie_payout_enabled
	var player_pair_enabled := PayoutSettingsManager.player_pair_payout_enabled
	var banker_pair_enabled := PayoutSettingsManager.banker_pair_payout_enabled

	var settings_variant: Variant = SaveManager.load_payout_settings()
	if settings_variant is Dictionary:
		var settings := settings_variant as Dictionary
		if settings.has("player") and settings["player"] is bool:
			player_enabled = settings["player"]
		if settings.has("banker") and settings["banker"] is bool:
			banker_enabled = settings["banker"]
		if settings.has("tie") and settings["tie"] is bool:
			tie_enabled = settings["tie"]
		if settings.has("player_pair") and settings["player_pair"] is bool:
			player_pair_enabled = settings["player_pair"]
		if settings.has("banker_pair") and settings["banker_pair"] is bool:
			banker_pair_enabled = settings["banker_pair"]

	PayoutSettingsManager.set_all(player_enabled, banker_enabled, tie_enabled, player_pair_enabled, banker_pair_enabled)
	if pair_betting_manager != null:
		pair_betting_manager.toggle_pair_player_bet(player_pair_enabled)
		pair_betting_manager.toggle_pair_banker_bet(banker_pair_enabled)


static func _setup_phase_manager(_controller: Node2D, result: Dictionary) -> void:
	"""Создание GamePhaseManager с Dependency Injection"""
	var phase_manager: GamePhaseManager = GamePhaseManager.new(
		result["deck"],
		result["card_manager"],
		result["ui_manager"],
		result["hand_manager"],
		result["payout_queue_manager"],
		result["chip_visual_manager"],
		result["winner_selection_manager"],
		result["pair_betting_manager"],
		result["limits_manager"]  # Передаём limits_manager для генерации ставок гостей
	)
	result["phase_manager"] = phase_manager


static func _connect_ui_signals(controller: Node2D, result: Dictionary) -> void:
	"""Подключение сигналов UIManager к обработчикам"""
	var ui_manager: UIManager = result["ui_manager"]
	var phase_manager: GamePhaseManager = result["phase_manager"]

	ui_manager.action_button_pressed.connect(phase_manager.on_action_pressed)
	ui_manager.player_third_toggled.connect(phase_manager.on_player_third_toggled)
	ui_manager.banker_third_toggled.connect(phase_manager.on_banker_third_toggled)
	# TieMarker теперь обрабатывается через WinnerSelectionManager.winner_toggled
	ui_manager.help_button_pressed.connect(controller._on_help_button_pressed)
	ui_manager.lang_button_pressed.connect(controller._on_lang_button_pressed)


static func _setup_bet_collection(controller: Node2D, result: Dictionary) -> void:
	"""Настройка менеджера фазы сбора/оплаты ставок"""
	var bet_collection_manager: BetCollectionPhaseManager = BetCollectionPhaseManager.new()
	result["phase_manager"].bet_collection_manager = bet_collection_manager
	result["bet_collection_manager"] = bet_collection_manager

	var ui_manager: UIManager = result["ui_manager"]
	ui_manager.button_ui.setup_collect_pay_buttons(controller)
	ui_manager.button_ui.collect_button_toggled.connect(controller._on_collect_mode_toggled)
	ui_manager.button_ui.pay_button_toggled.connect(controller._on_pay_mode_toggled)


static func _handle_payout_scene_return_or_reset(_controller: Node2D, result: Dictionary) -> bool:
	"""Обработка возврата из PayoutScene или стандартный reset

	Returns:
		true если возвращаемся из PayoutScene, false если обычная загрузка
	"""
	var is_payout_return: bool = PayoutContextManager.has_context() and PayoutContextManager.get_context().get("manual_mode", false)
	var phase_manager: GamePhaseManager = result["phase_manager"]
	var ui_manager: UIManager = result["ui_manager"]

	if not is_payout_return:
		# Только если НЕ возвращаемся из PayoutScene - делаем reset
		phase_manager.reset()
		GameStateManager.reset()

		# Разблокируем маркеры для начала новой игры
		var winner_selection_manager: WinnerSelectionManager = result["winner_selection_manager"]
		if winner_selection_manager:
			winner_selection_manager.unlock_markers()
	else:
		DebugLogger.log_restore("⏮ Пропускаем GameStateManager.reset() при возврате из PayoutScene")

	ui_manager.help_popup.hide()
	ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))

	return is_payout_return


static func _initialize_chips_visibility(controller: Node2D, result: Dictionary, is_payout_return: bool) -> void:
	"""Инициализация видимости фишек (восстановление или стандартная)

	Args:
		is_payout_return: true если возвращаемся из PayoutScene
	"""
	if is_payout_return:
		# При возврате - восстанавливаем полный snapshot стола
		_restore_chips_from_table_state(controller, result)
		DebugLogger.log_restore("⏮ Восстановлено состояние из TableStateManager snapshot")

		# Синхронизируем сердечки из GameDataManager
		var survival_ui: Control = result["survival_ui"]
		if controller.is_survival_mode and survival_ui:
			var lives_from_payout: int = GameDataManager.get_survival_lives()
			survival_ui.set_lives(lives_from_payout)
			DebugLogger.log("♻️  Синхронизированы сердечки: %d (из PayoutScene)" % lives_from_payout)

		# Восстанавливаем состояние кнопки
		var ui_manager: UIManager = result["ui_manager"]
		if ui_manager:
			ui_manager.set_action_button_state(TableStateManager.get_action_button_state())
			ui_manager.enable_action_button()
			DebugLogger.log("♻️  Восстановлено состояние кнопки: %s" % TableStateManager.get_action_button_state())

			# Показываем кнопки Collect/Pay если мы в фазе выплат
			if TableStateManager.get_action_button_state() == "complete":
				ui_manager.button_ui.show_collect_pay_buttons()
				DebugLogger.log_restore("⏮ Показаны кнопки Collect/Pay")
	else:
		# При обычной загрузке - показываем фишки на основе настроек
		_show_chips_by_settings(controller, result)


static func _show_chips_by_settings(_controller: Node2D, _result: Dictionary) -> void:
	"""Показ фишек на основе настроек (режим GUEST)
	
	В режиме GUEST фишки показываются только для гостевых ставок.
	Гостевые ставки отображаются через _show_guest_bets() в GamePhaseManager.
	Здесь ничего не делаем - фишки будут показаны при подготовке новой игры.
	"""
	# В режиме GUEST фишки создаются через _show_guest_bets() в GamePhaseManager
	# при подготовке новой игры (когда есть сгенерированные ставки гостей)
	DebugLogger.log_init("Режим GUEST: фишки будут показаны при подготовке новой игры (через гостевые ставки)")


static func _restore_chips_from_table_state(_controller: Node2D, result: Dictionary) -> void:
	"""Восстановить ВСЕ фишки из TableStateManager при возврате из PayoutScene"""
	DebugLogger.log_restore("🔄 Восстановление фишек из TableStateManager snapshot...")

	var chip_visual_manager: ChipVisualManager = result.get("chip_visual_manager")
	if not chip_visual_manager:
		push_warning("⚠️  chip_visual_manager is null")
		return

	if not TableStateManager.has_saved_state():
		DebugLogger.log_warning("⚠️ Нет сохраненного состояния в TableStateManager")
		return

	# В режиме GUEST фишки создаются через фабрику ставок, не восстанавливаем из TableStateManager
	if chip_visual_manager.current_mode == ChipVisualManager.PositionMode.GUEST:
		DebugLogger.log_restore("⚠️ Режим GUEST: фишки создаются через фабрику ставок, пропускаем восстановление из TableStateManager")
		return

	# Восстанавливаем ВСЕ фишки из сохраненных ставок (для других режимов, если будут)
	for bet in TableStateManager.get_bets():
		if bet.get_chip_texture().is_empty():
			# Нет сохраненной текстуры - используем случайную
			chip_visual_manager.show_chip(bet.get_bet_type())
		else:
			# Восстанавливаем конкретную текстуру
			chip_visual_manager.set_chip_texture(bet.get_bet_type(), bet.get_chip_texture())

	DebugLogger.log_restore("✅ Все фишки восстановлены (%d ставок)" % TableStateManager.get_bets().size())


static func _setup_event_subscriptions(controller: Node2D, result: Dictionary) -> void:
	"""Подписка на события EventBus"""
	# GameStateManager.state_changed подключается после инициализации settings_handler в _ready()
	# GameStateManager.state_changed.connect(controller._on_game_state_changed)
	DebugLogger.log_game_flow("GameStateManager инициализирован")

	# Подписки на новые события EventBus
	EventBus.manual_payout_requested.connect(controller._on_manual_payout_requested)
	EventBus.table_prepared_for_new_game.connect(controller._on_table_prepared)
	# Сигналы настроек подключаются после инициализации settings_handler в _ready()
	# EventBus.payout_setting_changed.connect(controller._on_payout_setting_changed)
	# EventBus.card_back_style_changed.connect(controller._on_card_back_style_changed)
	# EventBus.position_mode_changed.connect(controller._on_position_mode_changed)
	DebugLogger.log_init("Подписки на EventBus события установлены (payouts, flags, settings, card backs, position mode)")
	
	# Подписки на клавиатурное управление фокусом
	var phase_manager: GamePhaseManager = result["phase_manager"]
	EventBus.keyboard_action_requested.connect(phase_manager.on_action_pressed)
	EventBus.focus_activated.connect(controller._on_focus_activated)
	DebugLogger.log_init("Подписки на клавиатурное управление установлены (keyboard_action_requested, focus_activated)")


static func _finalize_setup(controller: Node2D, result: Dictionary) -> void:
	"""Финальная настройка: limits, stats, camera, UI, keyboard, overlay"""
	# Установка лимитов
	var cfg: Dictionary = GameModeManager.get_config()
	var limits_manager: LimitsManager = result["limits_manager"]
	limits_manager.set_limits(
		cfg["main_min"], cfg["main_max"], cfg["main_step"],
		cfg["tie_min"], cfg["tie_max"], cfg["tie_step"],
		cfg["pairs_min"], cfg["pairs_max"], cfg["pairs_step"],
		false  # не показываем toast при инициализации
	)

	StatsManager.instance.update_stats()

	# Настройка камеры
	var camera_manager: CameraManager = CameraManager.new()
	camera_manager.setup(controller)
	result["camera_manager"] = camera_manager

	# Перемещаем UI кнопки в TopUI для защиты от зума камеры
	_setup_fixed_ui(controller)

	# Настройка кнопок областей
	_setup_area_buttons()
	# Стрелки навигации удалены - навигация только через клавиатуру и свайп

	# Подключаем PayoutOverlay
	if controller.has_node("PayoutOverlay"):
		var payout_overlay: CanvasLayer = controller.get_node("PayoutOverlay")
		payout_overlay.payout_completed.connect(controller._on_payout_overlay_completed)
		payout_overlay.hide()
		result["payout_overlay"] = payout_overlay
		DebugLogger.log_init("PayoutOverlay подключен к GameController (overlay режим)")
	else:
		if controller.USE_OVERLAY_PAYOUT:
			DebugLogger.log_warning("⚠️ PayoutOverlay НЕ НАЙДЕН в Game.tscn (но USE_OVERLAY_PAYOUT=true)")
	
	# Создаём FocusFrame для клавиатурного управления
	_setup_focus_frame(controller)


static func _setup_fixed_ui(controller: Node2D) -> void:
	"""Перемещает UI кнопки в TopUI CanvasLayer чтобы они не зумились"""
	var top_ui: Node = controller.get_node("TopUI")
	if not top_ui:
		DebugLogger.log_warning("TopUI CanvasLayer не найден!")
		return

	# Список кнопок для перемещения
	# TieMarker НЕ перемещается - он на уровне стола как PlayerMarker и BankerMarker
	var buttons_to_move: Array = [
		"HelpButton",
		"RoundsCounterLabel",
		"StatsLabel",
		"SettingsButton",
		"CardsButton",
		"CardsButtonBroken"
	]

	for button_name in buttons_to_move:
		if controller.has_node(button_name):
			var button: Node = controller.get_node(button_name)

			if button is Control:
				var control := button as Control
				var anchors := Vector4(
					control.anchor_left,
					control.anchor_top,
					control.anchor_right,
					control.anchor_bottom
				)
				var offsets := Vector4(
					control.offset_left,
					control.offset_top,
					control.offset_right,
					control.offset_bottom
				)
				var grow_horizontal := control.grow_horizontal
				var grow_vertical := control.grow_vertical

				controller.remove_child(control)
				top_ui.add_child(control)

				control.anchor_left = anchors.x
				control.anchor_top = anchors.y
				control.anchor_right = anchors.z
				control.anchor_bottom = anchors.w
				control.offset_left = offsets.x
				control.offset_top = offsets.y
				control.offset_right = offsets.z
				control.offset_bottom = offsets.w
				control.grow_horizontal = grow_horizontal
				control.grow_vertical = grow_vertical
			else:
				# Сохраняем глобальную позицию для не-Control узлов
				var global_pos: Vector2 = button.global_position
				controller.remove_child(button)
				top_ui.add_child(button)
				button.global_position = global_pos

			DebugLogger.log("✅ %s перемещён в TopUI" % button_name)
		else:
			DebugLogger.log("⚠️ %s не найден" % button_name)

	DebugLogger.log("📌 UI элементы закреплены (не зумятся с камерой)")


static func _setup_area_buttons() -> void:
	"""Инициализация кнопок областей ставок"""
	# Кнопки областей уже настроены через скрипт AreaButton.gd
	# Они подключаются к EventBus автоматически
	DebugLogger.log_init("Кнопки областей инициализированы")


static func _check_payout_return(controller: Node2D, _result: Dictionary) -> void:
	"""Проверка возврата из PayoutScene (ручной или автоматический режим)"""
	# Guard Clause 1: Ручной режим через PayoutContextManager
	if PayoutContextManager.has_context():
		var context: Dictionary = PayoutContextManager.get_context()
		if context.get("manual_mode", false):
			controller._handle_manual_mode_payout_return(context)
			return

	# Guard Clause 2: Автоматический режим через GameDataManager
	if GameDataManager.get_payout_winner() != "":
		controller._handle_automatic_mode_payout_return()
		return


static func _setup_focus_frame(controller: Node2D) -> void:
	"""Создание FocusFrame для клавиатурного управления
	
	FocusFrame создаётся на уровне основной сцены (не в TopUI),
	чтобы он двигался вместе с камерой и элементами стола.
	"""
	# Проверяем, нет ли уже FocusFrame в сцене (добавлен вручную в редакторе)
	var existing_frame = controller.find_child("FocusFrame", true, false)
	if existing_frame:
		DebugLogger.log_init("🔲 FocusFrame найден в сцене (настроен вручную)")
		return
	
	# Создаём FocusFrame программно на уровне основной сцены
	var focus_frame: FocusFrameUI = FocusFrameUI.new()
	focus_frame.name = "FocusFrame"
	
	# Добавляем на уровень основной сцены (не в TopUI!)
	# Это позволяет рамке двигаться вместе с камерой
	controller.add_child(focus_frame)
	
	DebugLogger.log_init("🔲 FocusFrame создан на уровне основной сцены (двигается с камерой)")
