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
	Localization.set_lang("ru")

	result["deck"] = Deck.new()
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

	# Подписываемся на Game Over по очкам
	SaveManager.instance.score_game_over.connect(controller._on_score_game_over)


static func _setup_settings_and_mode(controller: Node2D, result: Dictionary) -> void:
	"""Настройка SettingsScene и загрузка режима игры"""
	# Настройка SettingsScene
	if controller.has_node("SettingsScene"):
		DebugLogger.log_init("SettingsScene найден в сцене!")
		var settings_scene: Node = controller.get_node("SettingsScene")
		settings_scene.mode_changed.connect(controller._on_mode_changed)
		settings_scene.language_changed.connect(controller._on_language_changed)
		settings_scene.survival_mode_changed.connect(controller._on_survival_mode_changed)
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

		var mode: int = PayoutSettingsManager.get_position_mode()
		chip_visual_manager.set_position_mode(mode as ChipVisualManager.PositionMode)

		var mode_names: Array = ["DEFAULT", "RANDOM", "MAX", "REALISTIC"]
		DebugLogger.log("✅ ChipVisualManager инициализирован (position_mode=%s)" % mode_names[mode])
	else:
		push_warning("⚠️  Узлы фишек не найдены в сцене")

	result["chip_visual_manager"] = chip_visual_manager

	# WinnerSelectionManager
	var winner_selection_manager: WinnerSelectionManager = WinnerSelectionManager.new()
	var player_marker: Node = controller.get_node_or_null("PlayerMarker")
	var banker_marker: Node = controller.get_node_or_null("BankerMarker")

	if player_marker and banker_marker:
		winner_selection_manager.setup(player_marker, banker_marker)
		winner_selection_manager.winner_toggled.connect(controller._on_winner_toggled)
		DebugLogger.log_init("WinnerSelectionManager инициализирован (Player, Banker)")
	else:
		push_warning("⚠️  Маркеры не найдены в сцене")

	result["winner_selection_manager"] = winner_selection_manager

	# PairBettingManager
	result["pair_betting_manager"] = PairBettingManager.new()
	DebugLogger.log_init("PairBettingManager инициализирован")

	# PayoutQueueManager (создается пустым, будет пересоздан при подготовке выплат)
	result["payout_queue_manager"] = PayoutQueueManager.new()
	DebugLogger.log_init("PayoutQueueManager инициализирован (пустой)")

	# HandManager (Task 2.2 - управление руками игрока и банкира)
	result["hand_manager"] = HandManager.new()
	DebugLogger.log_init("HandManager инициализирован")


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
		result["pair_betting_manager"]
	)
	result["phase_manager"] = phase_manager


static func _connect_ui_signals(controller: Node2D, result: Dictionary) -> void:
	"""Подключение сигналов UIManager к обработчикам"""
	var ui_manager: UIManager = result["ui_manager"]
	var phase_manager: GamePhaseManager = result["phase_manager"]

	ui_manager.action_button_pressed.connect(phase_manager.on_action_pressed)
	ui_manager.player_third_toggled.connect(phase_manager.on_player_third_toggled)
	ui_manager.banker_third_toggled.connect(phase_manager.on_banker_third_toggled)
	ui_manager.tie_button_pressed.connect(phase_manager.on_tie_button_pressed)
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
			var lives_from_payout: int = GameDataManager.survival_lives
			survival_ui.set_lives(lives_from_payout)
			DebugLogger.log("♻️  Синхронизированы сердечки: %d (из PayoutScene)" % lives_from_payout)

		# Восстанавливаем состояние кнопки
		var ui_manager: UIManager = result["ui_manager"]
		if ui_manager:
			ui_manager.set_action_button_state(TableStateManager.action_button_state)
			ui_manager.enable_action_button()
			DebugLogger.log("♻️  Восстановлено состояние кнопки: %s" % TableStateManager.action_button_state)

			# Показываем кнопки Collect/Pay если мы в фазе выплат
			if TableStateManager.action_button_state == "complete":
				ui_manager.button_ui.show_collect_pay_buttons()
				DebugLogger.log_restore("⏮ Показаны кнопки Collect/Pay")
	else:
		# При обычной загрузке - показываем фишки на основе настроек
		_show_chips_by_settings(controller, result)


static func _show_chips_by_settings(_controller: Node2D, result: Dictionary) -> void:
	"""Показ фишек на основе настроек PayoutSettingsManager"""
	var chip_visual_manager: ChipVisualManager = result.get("chip_visual_manager")
	if not chip_visual_manager:
		return

	var pair_betting_manager: PairBettingManager = result.get("pair_betting_manager")
	var is_realistic: bool = PayoutSettingsManager.is_realistic_mode_enabled()

	if is_realistic:
		# REALISTIC режим - случайное количество фишек
		if PayoutSettingsManager.player_payout_enabled:
			chip_visual_manager.show_chips_realistic("Player")
		if PayoutSettingsManager.banker_payout_enabled:
			chip_visual_manager.show_chips_realistic("Banker")
		if PayoutSettingsManager.tie_payout_enabled:
			chip_visual_manager.show_chips_realistic("Tie")
		if PayoutSettingsManager.player_pair_payout_enabled:
			chip_visual_manager.show_chips_realistic("PairPlayer")
			if pair_betting_manager:
				pair_betting_manager.toggle_pair_player_bet(true)
		if PayoutSettingsManager.banker_pair_payout_enabled:
			chip_visual_manager.show_chips_realistic("PairBanker")
			if pair_betting_manager:
				pair_betting_manager.toggle_pair_banker_bet(true)
		DebugLogger.log_init("Фишки синхронизированы (REALISTIC режим)")
	else:
		# Стандартный режим (DEFAULT, RANDOM, MAX)
		if PayoutSettingsManager.player_payout_enabled:
			chip_visual_manager.show_chip("Player")
		if PayoutSettingsManager.banker_payout_enabled:
			chip_visual_manager.show_chip("Banker")
		if PayoutSettingsManager.tie_payout_enabled:
			chip_visual_manager.show_chip("Tie")
		if PayoutSettingsManager.player_pair_payout_enabled:
			chip_visual_manager.show_chip("PairPlayer")
			if pair_betting_manager:
				pair_betting_manager.toggle_pair_player_bet(true)
		if PayoutSettingsManager.banker_pair_payout_enabled:
			chip_visual_manager.show_chip("PairBanker")
			if pair_betting_manager:
				pair_betting_manager.toggle_pair_banker_bet(true)
		DebugLogger.log_init("Фишки синхронизированы с настройками")


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

	# Восстанавливаем ВСЕ фишки из сохраненных ставок
	for bet in TableStateManager.bets:
		if bet.chip_texture.is_empty():
			# Нет сохраненной текстуры - используем случайную
			chip_visual_manager.show_chip(bet.bet_type)
		else:
			# Восстанавливаем конкретную текстуру
			chip_visual_manager.set_chip_texture(bet.bet_type, bet.chip_texture)

	DebugLogger.log_restore("✅ Все фишки восстановлены (%d ставок)" % TableStateManager.bets.size())


static func _setup_event_subscriptions(controller: Node2D, _result: Dictionary) -> void:
	"""Подписка на события EventBus"""
	GameStateManager.state_changed.connect(controller._on_game_state_changed)
	DebugLogger.log_game_flow("GameStateManager инициализирован")

	# Подписки на новые события EventBus
	EventBus.manual_payout_requested.connect(controller._on_manual_payout_requested)
	EventBus.table_prepared_for_new_game.connect(controller._on_table_prepared)
	EventBus.payout_setting_changed.connect(controller._on_payout_setting_changed)
	EventBus.card_back_style_changed.connect(controller._on_card_back_style_changed)
	EventBus.position_mode_changed.connect(controller._on_position_mode_changed)
	DebugLogger.log_init("Подписки на EventBus события установлены (payouts, flags, settings, card backs, position mode)")


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

	# Настройка кнопок областей и стрелок навигации
	_setup_area_buttons()
	_setup_navigation_arrows(controller)

	# Настройка клавиатурной навигации
	_setup_keyboard_navigation(controller, result)

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


static func _setup_fixed_ui(controller: Node2D) -> void:
	"""Перемещает UI кнопки в TopUI CanvasLayer чтобы они не зумились"""
	var top_ui: Node = controller.get_node("TopUI")
	if not top_ui:
		DebugLogger.log_warning("TopUI CanvasLayer не найден!")
		return

	# Список кнопок для перемещения
	var buttons_to_move: Array = [
		"HelpButton",
		"StatsLabel",
		"SettingsButton",
		"CardsButton",
		"CardsButtonBroken",
		"TieButton"
	]

	for button_name in buttons_to_move:
		if controller.has_node(button_name):
			var button: Node = controller.get_node(button_name)
			# Сохраняем глобальную позицию
			var global_pos: Vector2 = button.global_position
			# Перемещаем в TopUI
			controller.remove_child(button)
			top_ui.add_child(button)
			# Восстанавливаем позицию
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


static func _setup_navigation_arrows(controller: Node2D) -> void:
	"""Инициализация стрелок навигации"""
	var left_arrow: Node = controller.get_node_or_null("TopUI/LeftArrowButton")
	var right_arrow: Node = controller.get_node_or_null("TopUI/RightArrowButton")

	if left_arrow:
		left_arrow.pressed.connect(controller._on_left_arrow_pressed)
	if right_arrow:
		right_arrow.pressed.connect(controller._on_right_arrow_pressed)

	# Подписываемся на EventBus для управления видимостью стрелок
	if EventBus:
		EventBus.navigation_arrows_visibility_changed.connect(controller._on_arrows_visibility_changed)
		# Скрываем стрелки при старте - они появятся только после выбора победителя
		EventBus.navigation_arrows_visibility_changed.emit(false)

	DebugLogger.log_init("Стрелки навигации инициализированы")


static func _setup_keyboard_navigation(controller: Node2D, result: Dictionary) -> void:
	"""Настройка клавиатурной навигации"""
	# Добавляем рамку в сцену
	FocusManager.attach_highlight_to_scene(controller)

	var ui_manager: UIManager = result["ui_manager"]

	# Уровень 1 (нижний): Кнопка "Карты"
	var level1_elements: Array = [
		ui_manager.action_button
	]

	# Уровень 2: ? банкиру, ? игроку
	var level2_elements: Array = [
		ui_manager.banker_third_toggle,
		ui_manager.player_third_toggle
	]

	# Уровень 3: Banker, Player (Tie теперь кнопка, не маркер)
	var level3_elements: Array = [
		controller.get_node("BankerMarker"),
		controller.get_node("PlayerMarker")
	]

	# Уровень 4 (верхний): Подсказка, Настройки
	var level4_elements: Array = [
		ui_manager.help_button
	]
	# Кнопка настроек теперь в TopUI после _setup_fixed_ui()
	if controller.has_node("TopUI/SettingsButton"):
		level4_elements.append(controller.get_node("TopUI/SettingsButton"))

	# Регистрируем уровни (is_payout=false для Game)
	FocusManager.register_level(1, level1_elements, false)
	FocusManager.register_level(2, level2_elements, false)
	FocusManager.register_level(3, level3_elements, false)
	FocusManager.register_level(4, level4_elements, false)


static func _check_payout_return(controller: Node2D, _result: Dictionary) -> void:
	"""Проверка возврата из PayoutScene (ручной или автоматический режим)"""
	# Guard Clause 1: Ручной режим через PayoutContextManager
	if PayoutContextManager.has_context():
		var context: Dictionary = PayoutContextManager.get_context()
		if context.get("manual_mode", false):
			controller._handle_manual_mode_payout_return(context)
			return

	# Guard Clause 2: Автоматический режим через GameDataManager
	if GameDataManager.payout_winner != "":
		controller._handle_automatic_mode_payout_return()
		return
