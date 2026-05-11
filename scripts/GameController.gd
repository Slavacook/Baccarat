# res://scripts/GameController.gd
# ═══════════════════════════════════════════════════════════════════════════
# ГЛАВНЫЙ КОНТРОЛЛЕР ИГРЫ
# Роль: Координатор всех подсистем игры (Facade/Mediator pattern)
# Отвечает за:
#   - Инициализацию и связывание всех менеджеров
#   - Обработку пользовательского ввода
#   - Координацию между подсистемами через EventBus
# ═══════════════════════════════════════════════════════════════════════════
extends Node2D

# Явная загрузка классов для избежания проблем с парсингом
const PayoutQueueHandlerScript = preload("res://scripts/payout/PayoutQueueHandler.gd")
const RoundResultSenderScript = preload("res://scripts/session/RoundResultSender.gd")
const OnlineLiveEventBridgeScript = preload("res://scripts/session/OnlineLiveEventBridge.gd")
const TournamentAccessStoreScript = preload("res://scripts/network/TournamentAccessStore.gd")
const TournamentNavigationStoreScript = preload("res://scripts/network/TournamentNavigationStore.gd")
const TOURNAMENT_DETAILS_SCENE_PATH := "res://scenes/network/TournamentDetailsScreen.tscn"
const START_SCREEN_SCENE_PATH := "res://scenes/StartScreen.tscn"
const GAME_SCENE_PATH := "res://scenes/Game.tscn"

# ═══════════════════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

@export var config: GameConfig
const USE_OVERLAY_PAYOUT = true  # true = overlay, false = scene transition

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНЫЕ МЕНЕДЖЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

var deck: Deck
var card_manager: CardTextureManager
var ui_manager: UIManager
var hand_manager: HandManager
var phase_manager: GamePhaseManager
var limits_manager: LimitsManager
var camera_manager: CameraManager

# ═══════════════════════════════════════════════════════════════════════════
# МЕНЕДЖЕРЫ ФИШЕК И ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

var chip_visual_manager: ChipVisualManager
var winner_selection_manager: WinnerSelectionManager
var payout_queue_manager: PayoutQueueManager
var pair_betting_manager: PairBettingManager
var bet_collection_manager: BetCollectionPhaseManager
var payout_overlay: CanvasLayer = null

# Индикаторы терпения и баланса гостей
var patience_indicator_manager: Node = null

# ═══════════════════════════════════════════════════════════════════════════
# РЕФАКТОРЕННЫЕ МЕНЕДЖЕРЫ (SRP)
# ═══════════════════════════════════════════════════════════════════════════

var payout_manager: PayoutManager
var state_restorer: StateRestorer

# ═══════════════════════════════════════════════════════════════════════════
# UI КОМПОНЕНТЫ
# ═══════════════════════════════════════════════════════════════════════════

var settings_scene: CanvasLayer
var settings_button: Button
var survival_ui: Control
var game_over_popup: CanvasLayer
var crib_sheet_scene: CribSheetScene = null

## HeartBar - менеджер жизней (новая система)
var heart_bar: HeartBar = null

# Провайдер состояния режима выживания (инкапсулирует heart_bar/survival_ui)
var survival_state: SurvivalStateProvider

# Контроллер для управления отображением карт (Extract Class)
var card_controller: CardController

# Обработчик результатов выплат (Extract Class)
var payout_result_handler: PayoutResultHandler

# Обработчик кликов на фишек (Extract Class)
var chip_click_handler: ChipClickHandler

# Обработчик событий настроек (Extract Class)
var settings_handler: SettingsEventHandler

# Обработчик событий гостей (Extract Class)
var guest_event_handler: GuestEventHandler

# Контроллер Heart Bet (Extract Class)
var heart_bet_controller: HeartBetController

# Обработчик выбора победителя (Extract Class)
var winner_selection_handler: WinnerSelectionHandler

# Обработчик очереди выплат (Extract Class)
var payout_queue_handler: PayoutQueueHandler

# Координатор PayoutOverlay (Extract Class)
var payout_overlay_coordinator: PayoutOverlayCoordinator

# Менеджер клавиатурной навигации по ставкам
var chip_navigation_manager: ChipNavigationManager

# Навигатор для карт шансов
var chance_card_navigator: ChanceCardNavigator = null

# Контроллер навигации камеры (Extract Class)
var camera_navigation_controller: CameraNavigationController

# Координатор навигации по ставкам (Extract Class)
var chip_navigation_coordinator: ChipNavigationCoordinator

# Обработчик режимов сбора и оплаты (Extract Class)
var collection_mode_handler: CollectionModeHandler

# Обработчик клавиатурного фокуса (Extract Class)
var keyboard_focus_handler: KeyboardFocusHandler

# Монитор геймпадов (Extract Class)
var gamepad_monitor: GamepadMonitor

# Обновлятель счетчика раундов (Extract Class)
var rounds_counter_updater: RoundsCounterUpdater
# Счетчики возврата гостей теперь только в настройках, не на главном экране
# var guest_return_counter_ui: GuestReturnCounterUI  # Убрано - теперь только в SettingsScene

# Обработчик возврата из PayoutScene (Extract Class)
var payout_return_handler: PayoutReturnHandler

# Обработчик подготовки выплат (Extract Class)
var payout_preparation_handler: PayoutPreparationHandler

# Обработчик UI событий (Extract Class)
var ui_event_handler: UIEventHandler

# Обработчик ввода (Extract Class)
var input_handler: InputHandler

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

var training_mode_manager: TrainingModeManager = null
var training_stage_manager: TrainingStageManager = null
var is_training_mode_active: bool = false
var training_progress_bar: TrainingProgressBar = null
var training_instruction_popup: TrainingInstructionPopup = null
var training_question_popup: TrainingQuestionPopup = null
var training_stage_complete_popup: TrainingStageCompletePopup = null

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ИГРЫ
# ═══════════════════════════════════════════════════════════════════════════

var survival_rounds_completed: int = 0
# is_survival_mode удалён - режим всегда активен (не нужна проверка)
var is_table_prepared_for_new_game: bool = false
var is_payout_processing: bool = false  # Флаг обработки выплаты (защита от спама Space)

# Переменная для отложенной смены режима (аналогично pending_filter_changes)
var pending_mode_change: String = GameConstants.MODE_EMPTY  # "junket" или "classic", пустая = нет отложенной смены
var _last_tournament_remaining_seconds: int = -1

# Контроллер состояния игры (Extract Class)
var game_state_controller: GameStateController

# Добавляем FlipCard ссылки
# Массивы для ссылок на flip-анимации и карты:
@onready var flip_cards := [
	$OpenCard/FlipCard1, $OpenCard/FlipCard2, $OpenCard/FlipCard3,
	$OpenCard/FlipCard4, $OpenCard/FlipCard5, $OpenCard/FlipCard6,
]
@onready var card_nodes := [
	$PlayerZone/Card1, $PlayerZone/Card2, $PlayerZone/Card3,
	$BankerZone/Card1, $BankerZone/Card2, $BankerZone/Card3,
]

# Ссылки на узлы гостей и фона
@onready var background_3: TextureRect = $Background3
@onready var rounds_counter_label: Label = $RoundsCounterLabel
@onready var background_5: TextureRect = $Background5
@onready var background_666: TextureRect = $Background666
@onready var tournament_info_panel: Control = $TopUI/TournamentInfoPanel
@onready var tournament_title_label: Label = $TopUI/TournamentInfoPanel/MarginContainer/TournamentInfoContainer/TournamentTitleLabel
@onready var tournament_participant_label: Label = $TopUI/TournamentInfoPanel/MarginContainer/TournamentInfoContainer/TournamentParticipantLabel
@onready var tournament_rounds_label: Label = $TopUI/TournamentInfoPanel/MarginContainer/TournamentInfoContainer/TournamentRoundsLabel
@onready var tournament_time_label: Label = $TopUI/TournamentInfoPanel/MarginContainer/TournamentInfoContainer/TournamentTimeLabel
@onready var tournament_errors_label: Label = $TopUI/TournamentInfoPanel/MarginContainer/TournamentInfoContainer/TournamentErrorsLabel
@onready var tournament_finish_overlay: Control = $TopUI/TournamentFinishOverlay
@onready var tournament_finish_title_label: Label = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishTitleLabel
@onready var tournament_finish_reason_label: Label = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishReasonLabel
@onready var tournament_finish_status_label: Label = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishStatusLabel
@onready var tournament_finish_rank_label: Label = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishRankLabel
@onready var tournament_finish_menu_btn: Button = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishButtons/TournamentFinishMenuBtn
@onready var tournament_finish_retry_btn: Button = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishButtons/TournamentFinishRetryBtn
@onready var tournament_finish_rounds_label: Label = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishMetrics/TournamentFinishRoundsCard/MarginContainer/VBoxContainer/TournamentFinishRoundsLabel
@onready var tournament_finish_errors_label: Label = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishMetrics/TournamentFinishErrorsCard/MarginContainer/VBoxContainer/TournamentFinishErrorsLabel
@onready var tournament_finish_time_label: Label = $TopUI/TournamentFinishOverlay/CenterContainer/TournamentFinishPanel/MarginContainer/TournamentFinishContainer/TournamentFinishMetrics/TournamentFinishTimeCard/MarginContainer/VBoxContainer/TournamentFinishTimeLabel
@onready var guest_sprites: Dictionary = {
	1: $G_1,
	2: $G_2,
	3: $G_3,
	4: $G_4,
	5: $G_5,
	6: $G_6,
	666: $G_666,
}




func _ready():
	"""Инициализация GameController

	Рефакторенная версия с GameInitializer (Extract Class паттерн).
	Было: 198 строк монолитной инициализации в _ready()
	Стало: Делегирование в GameInitializer.initialize()
	"""
	# Добавляем в группу для доступа из других скриптов
	add_to_group(GameConstants.GROUP_GAME_CONTROLLER)
	
	# Инициализация через GameInitializer (все ~200 строк вынесены в отдельный класс)
	var initialized: Dictionary = GameInitializer.initialize(self)
	
	# Распаковка результатов в member variables
	deck = initialized["deck"]
	config = initialized["config"]
	card_manager = initialized["card_manager"]
	ui_manager = initialized["ui_manager"]
	hand_manager = initialized["hand_manager"]
	limits_manager = initialized["limits_manager"]
	survival_ui = initialized["survival_ui"]
	game_over_popup = initialized["game_over_popup"]
	settings_scene = initialized.get("settings_scene")
	settings_button = initialized.get("settings_button")
	
	# HeartBar будет инициализирован в _ready() после того как survival_ui._ready() вызван
	phase_manager = initialized["phase_manager"]
	bet_collection_manager = initialized["bet_collection_manager"]
	chip_visual_manager = initialized["chip_visual_manager"]
	winner_selection_manager = initialized["winner_selection_manager"]
	pair_betting_manager = initialized["pair_betting_manager"]
	payout_queue_manager = initialized["payout_queue_manager"]
	camera_manager = initialized["camera_manager"]
	payout_overlay = initialized.get("payout_overlay")

	# Подсветка областей: подписки перенесены в CameraNavigationController
	# camera_manager.zoom_completed.connect(_on_camera_zoom_completed) - перенесено
	# _update_area_highlights(0) - будет вызвано в CameraNavigationController
	# EventBus.camera_zoom_requested.connect(_on_camera_zoom_requested) - перенесено
	
	# Heart Bet: скрытие/показ ставок гостей
	# Сигналы guest_bets_hide_requested и guest_bets_show_requested
	# перенесены в GuestEventHandler (подключаются в _connect_guest_signals())
	# Сигналы heart_bet_show_ui, heart_bet_declined, heart_bet_round_complete
	# перенесены в HeartBetController (подключаются в _connect_heart_bet_signals())
	
	# Настройки: скрываем/показываем UI элементы
	EventBus.settings_opened.connect(_on_settings_opened)
	EventBus.settings_closed.connect(_on_settings_closed)
	if settings_scene:
		settings_scene.language_changed.connect(_refresh_top_bar_texts)
	
	# Начало новой раздачи: увеличиваем счетчик раздач
	EventBus.round_started.connect(_on_round_started)
	if not EventBus.all_bets_processed.is_connected(_on_tournament_round_completed):
		EventBus.all_bets_processed.connect(_on_tournament_round_completed)
	
	# Heart Bet: триггеры обрабатываются через ChanceCardManager
	# Старые сигналы оставлены для обратной совместимости
	
	# Подписка на изменение настроек гостей перенесена в GuestEventHandler
	# (подключается в _initialize_guest_event_handler())
	
	# Настройка новой системы карт шанса
	_setup_chance_card_system()
	
	# Инициализируем навигатор карт шансов (после настройки системы карт)
	_initialize_chance_card_navigation()
	
	# Инициализируем HeartBar (если ещё не инициализирован)
	_initialize_heart_bar()
	
	# Инициализируем провайдер состояния режима выживания (после heart_bar)
	_initialize_survival_state_provider()
	
	# Инициализируем контроллер для управления картами
	_initialize_card_controller()
	
	# Инициализируем обработчик событий гостей (ПЕРЕД другими обработчиками, чтобы установить callbacks)
	_initialize_guest_event_handler()
	
	# Инициализируем обработчик результатов выплат (после инициализации менеджеров)
	_initialize_payout_result_handler()
	
	# Инициализируем контроллер состояния игры (после инициализации менеджеров)
	_initialize_game_state_controller()
	
	# Инициализируем обработчик кликов на фишки (после инициализации менеджеров)
	_initialize_chip_click_handler()
	# Инициализируем менеджер навигации по ставкам (после chip_click_handler)
	_initialize_chip_navigation()
	_initialize_settings_handler()
	_initialize_heart_bet_controller()
	_initialize_winner_selection_handler()
	_initialize_payout_queue_handler()
	_initialize_payout_overlay_coordinator()
	_initialize_camera_navigation_controller()
	_initialize_chip_navigation_coordinator()
	_initialize_collection_mode_handler()
	_initialize_keyboard_focus_handler()
	_initialize_gamepad_monitor()
	_initialize_rounds_counter_updater()
	_initialize_guest_return_counter_ui()
	_initialize_payout_return_handler()
	_initialize_payout_preparation_handler()
	
	# Инициализируем шпаргалку ПЕРЕД UIEventHandler (чтобы crib_sheet_scene был доступен)
	_initialize_crib_sheet()
	
	_initialize_ui_event_handler()
	_initialize_input_handler()
	_initialize_training_mode()
	
	# Проверка подключения геймпадов (после инициализации GamepadMonitor)
	_check_gamepad_connection()
	
	# Активируем режим выживания (всегда активен)
	if survival_state:
		survival_state.activate()
	
	# Передаём heart_bar в ChanceCardManager после инициализации (если он был инициализирован)
	if heart_bar:
		ChanceCardManager.set_heart_bar(heart_bar)
		print("🎴 HeartBar передан в ChanceCardManager (после инициализации)")
	
	# Инициализируем счетчик раздач
	_update_rounds_counter()
	_refresh_top_bar_texts()
	_update_tournament_info_panel()
	_connect_tournament_runtime_signals()
	if tournament_finish_overlay:
		tournament_finish_overlay.visible = false
	if tournament_finish_menu_btn and not tournament_finish_menu_btn.pressed.is_connected(_on_tournament_finish_menu_pressed):
		tournament_finish_menu_btn.pressed.connect(_on_tournament_finish_menu_pressed)
	if tournament_finish_retry_btn and not tournament_finish_retry_btn.pressed.is_connected(_on_tournament_retry_submit_pressed):
		tournament_finish_retry_btn.pressed.connect(_on_tournament_retry_submit_pressed)
	
	# Инициализируем менеджер индикаторов терпения и баланса гостей
	_setup_patience_indicators()
	
	# Сбрасываем флаг Game Over при инициализации (на случай перезагрузки сцены)
	# Флаг сбрасывается через game_state_controller после инициализации
	
	# Сбрасываем все данные при инициализации сцены (на случай перезагрузки после Game Over)
	# Это гарантирует, что чаевые, терпение гостей и таймеры будут сброшены
	StatsManager.instance.reset()
	if GuestStatsManager:
		GuestStatsManager.reset_all_patience()
	if PatienceTimerManager:
		PatienceTimerManager.reset_all_timers()
	DebugLogger.log("🔄 Данные сброшены при инициализации сцены (чаевые, терпение, таймеры)")

	# ─── Сетевая интеграция: RoundResultSender, живые события для тренера ───
	_initialize_round_result_sender()
	_initialize_online_live_event_bridge()
	_setup_live_session_ws()

func _setup_live_session_ws() -> void:
	"""Подписка на события live WebSocket (сессия завершена и т.д.)."""
	var sm: Node = get_node_or_null("/root/SessionManager")
	if not sm or sm.current_mode != sm.Mode.ONLINE:
		return
	if not Engine.has_singleton("LiveSessionClient"):
		return
	var lsc: Node = LiveSessionClient
	if lsc.live_event.is_connected(_on_live_session_ws_event):
		return
	lsc.live_event.connect(_on_live_session_ws_event)


func _on_live_session_ws_event(event_type: String, data: Dictionary) -> void:
	if event_type == "session_ended":
		var reason: String = str(_dict_value(data, "reason", ""))
		var msg: String = "Live-сессия завершена тренером"
		if reason != "":
			msg += " (%s)" % reason
		EventBus.show_toast_info.emit(msg)
	elif event_type == "round_sync":
		var sm_rs: Node = get_node_or_null("/root/SessionManager")
		if sm_rs and sm_rs.has_method("apply_server_round_sync"):
			sm_rs.apply_server_round_sync(data)
		if training_mode_manager and training_mode_manager.has_method("queue_deck_reseed_from_server"):
			training_mode_manager.queue_deck_reseed_from_server(str(_dict_value(data, "round_seed", "")))


func _initialize_round_result_sender() -> void:
	"""Создаёт RoundResultSender если сессия онлайн."""
	var sm = get_node_or_null("/root/SessionManager")
	if sm and sm.current_mode == sm.Mode.ONLINE:
		var sender = RoundResultSenderScript.new()
		sender.name = "RoundResultSender"
		add_child(sender)
		print("🌐 RoundResultSender создан (сетевая сессия)")


func _initialize_online_live_event_bridge() -> void:
	"""Создаёт OnlineLiveEventBridge: EventBus → WebSocket для дашборда тренера."""
	var sm: Node = get_node_or_null("/root/SessionManager")
	if sm == null or sm.current_mode != sm.Mode.ONLINE:
		return
	if get_node_or_null("OnlineLiveEventBridge") != null:
		return
	var bridge: Node = OnlineLiveEventBridgeScript.new()
	bridge.name = "OnlineLiveEventBridge"
	add_child(bridge)
	print("🌐 OnlineLiveEventBridge создан (live-события для тренера)")

func _exit_tree() -> void:
	"""Очистка при удалении сцены (важно при change_scene!)
	
	КРИТИЧЕСКИ ВАЖНО: Отписываем CameraManager от EventBus,
	иначе старый экземпляр продолжит получать события после рестарта.
	"""
	print("🧹 GameController._exit_tree: очистка CameraManager")
	if Engine.has_singleton("LiveSessionClient"):
		var lsc_ws: Node = LiveSessionClient
		if lsc_ws.live_event.is_connected(_on_live_session_ws_event):
			lsc_ws.live_event.disconnect(_on_live_session_ws_event)
	if camera_manager:
		camera_manager.cleanup()
		camera_manager = null
	_disconnect_tournament_runtime_signals()

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ КОМПОНЕНТОВ
# ═══════════════════════════════════════════════════════════════════════════
# Методы инициализации различных компонентов GameController
# Вызываются из _ready() в порядке зависимостей

## Инициализировать HeartBar из survival_ui
func _initialize_heart_bar() -> void:
	if survival_ui and GameConstants.PROPERTY_HEART_BAR in survival_ui and survival_ui.heart_bar != null:
		heart_bar = survival_ui.heart_bar
		print("✅ HeartBar инициализирован в GameController")
	else:
		print("⚠️  HeartBar не найден в survival_ui (возможно, survival_ui ещё не готов)")

## Инициализировать менеджер индикаторов терпения гостей
func _setup_patience_indicators() -> void:
	"""Создает и настраивает менеджер индикаторов терпения для всех гостей"""
	var indicator_manager = Node.new()
	indicator_manager.name = "GuestPatienceIndicatorManager"
	var script = load("res://scripts/ui/GuestPatienceIndicatorManager.gd")
	indicator_manager.set_script(script)
	add_child(indicator_manager)
	indicator_manager.setup(self, camera_manager)  # Передаем Game scene и camera_manager
	patience_indicator_manager = indicator_manager
	print("✅ GuestPatienceIndicatorManager инициализирован")

func _initialize_survival_state_provider() -> void:
	"""Инициализировать провайдер состояния режима выживания"""
	survival_state = SurvivalStateProvider.new(heart_bar, survival_ui)
	print("✅ SurvivalStateProvider инициализирован (heart_bar=%s, survival_ui=%s)" % [heart_bar != null, survival_ui != null])

func _initialize_crib_sheet() -> void:
	"""Инициализировать шпаргалку"""
	var crib_scene = load("res://scenes/ui/CribSheetScene.tscn") as PackedScene
	if crib_scene:
		var crib_instance = crib_scene.instantiate() as CribSheetScene
		if crib_instance:
			add_child(crib_instance)
			crib_sheet_scene = crib_instance
			print("✅ CribSheetScene инициализирована")
		else:
			push_error("CribSheetScene: не удалось создать экземпляр")
	else:
		push_error("CribSheetScene: не удалось загрузить сцену")

func _initialize_card_controller() -> void:
	"""Инициализировать контроллер для управления картами"""
	card_controller = CardController.new(flip_cards, card_nodes, get_tree())
	print("✅ CardController инициализирован (flip_cards=%d, card_nodes=%d)" % [flip_cards.size(), card_nodes.size()])

func _initialize_payout_result_handler() -> void:
	"""Инициализировать обработчик результатов выплат"""
	payout_result_handler = PayoutResultHandler.new(
		bet_collection_manager,
		chip_visual_manager,
		payout_queue_manager,
		ui_manager
	)
	# Устанавливаем callbacks для методов GameController
	# Callback для обновления баланса гостя при выплате
	if guest_event_handler:
		payout_result_handler.set_update_guest_balance_callback(guest_event_handler.update_guest_balance_for_bet)
		DebugLogger.log("✅ PayoutResultHandler: callback обновления баланса установлен")
	else:
		DebugLogger.log_warning("⚠️ PayoutResultHandler: guest_event_handler не инициализирован, callback НЕ установлен!")
	print("✅ PayoutResultHandler инициализирован")

func _initialize_game_state_controller() -> void:
	"""Инициализировать контроллер состояния игры"""
	game_state_controller = GameStateController.new(
		phase_manager,
		game_over_popup,
		payout_overlay,
		survival_state,
		winner_selection_manager
	)
	# Устанавливаем callback для зума камеры
	game_state_controller.set_camera_zoom_out_callback(camera_zoom_out)
	# Сбрасываем состояние Game Over при инициализации
	game_state_controller.set_is_game_over(false)
	print("✅ GameStateController инициализирован")

func _initialize_chip_click_handler() -> void:
	"""Инициализировать обработчик кликов на фишки"""
	chip_click_handler = ChipClickHandler.new(
		chip_visual_manager,
		bet_collection_manager,
		payout_queue_manager,
		phase_manager,
		ui_manager,
		survival_state,
		payout_overlay,
		USE_OVERLAY_PAYOUT
	)
	
	# Устанавливаем callbacks для методов GameController
	chip_click_handler.set_is_payout_processing_getter(func(): return is_payout_processing)
	# Callback для обновления баланса гостя при сборе
	if guest_event_handler:
		chip_click_handler.set_update_guest_balance_callback(guest_event_handler.update_guest_balance_on_collect)
	chip_click_handler.set_show_payout_overlay_callback(_show_payout_overlay_instance)
	chip_click_handler.set_open_payout_scene_callback(_open_payout_scene)
	print("✅ ChipClickHandler инициализирован")

func _initialize_chip_navigation() -> void:
	"""Инициализировать менеджер клавиатурной навигации по ставкам"""
	# Создаём визуальную рамку
	var navigation_frame = ChipNavigationFrame.new()
	
	# Добавляем рамку в тот же родительский узел, что и фишки (scene_root)
	# Это гарантирует правильное позиционирование
	if chip_visual_manager and chip_visual_manager.scene_root:
		chip_visual_manager.scene_root.add_child(navigation_frame)
		# Устанавливаем высокий z_index чтобы рамка была поверх фишек
		navigation_frame.z_index = 100
	else:
		# Fallback: используем CanvasLayer
		var canvas_layer = CanvasLayer.new()
		canvas_layer.name = "ChipNavigationLayer"
		canvas_layer.layer = 100  # Высокий слой
		add_child(canvas_layer)
		canvas_layer.add_child(navigation_frame)
	
	# Создаём менеджер навигации
	chip_navigation_manager = ChipNavigationManager.new()
	chip_navigation_manager.setup(
		chip_visual_manager,
		bet_collection_manager,
		chip_click_handler,
		navigation_frame,
		camera_manager
	)
	
	# Подписываемся на сигналы сбора/оплаты фишек
	if bet_collection_manager:
		bet_collection_manager.chip_collected.connect(chip_navigation_manager._on_chip_collected)
		bet_collection_manager.chip_paid.connect(chip_navigation_manager._on_chip_paid)
	
	# Подписки на сигналы chip navigation перенесены в ChipNavigationCoordinator
	# EventBus.chip_navigation_activation_requested.connect(...) - перенесено
	# EventBus.auto_switch_to_pay_mode_requested.connect(...) - перенесено
	
	print("✅ ChipNavigationManager инициализирован")

func is_chip_navigation_active() -> bool:
	"""Проверить, активна ли навигация по ставкам (для KeyboardNavigationController)"""
	if chip_navigation_manager:
		return chip_navigation_manager.is_active
	return false

func _initialize_settings_handler() -> void:
	"""Инициализировать обработчик событий настроек"""
	settings_handler = SettingsEventHandler.new(
		limits_manager,
		phase_manager,
		chip_visual_manager,
		ui_manager,
		pair_betting_manager,
		survival_state
	)
	
	# Устанавливаем callbacks для доступа к pending_mode_change
	settings_handler.get_pending_mode_change_callback = func(): return pending_mode_change
	settings_handler.set_pending_mode_change_callback = func(mode: String): pending_mode_change = mode
	
	# Подключаем сигналы настроек
	_connect_settings_signals()
	
	print("✅ SettingsEventHandler инициализирован")

func _initialize_guest_event_handler() -> void:
	"""Инициализировать обработчик событий гостей"""
	guest_event_handler = GuestEventHandler.new(
		self,
		phase_manager,
		chip_visual_manager,
		guest_sprites,
		background_666
	)
	
	# Подключаем сигналы
	_connect_guest_signals()
	
	print("✅ GuestEventHandler инициализирован")

func _connect_guest_signals() -> void:
	"""Подключить сигналы гостей к guest_event_handler"""
	if not guest_event_handler:
		return
	
	# Сигналы от GuestSettingsManager
	GuestSettingsManager.guest_settings_changed.connect(guest_event_handler.handle_guest_settings_changed)
	GuestSettingsManager.guest_settings_changed.connect(guest_event_handler.handle_guest_settings_changed_visibility)
	EventBus.guest_force_visible.connect(guest_event_handler.force_guest_visible)
	
	# Сигналы от EventBus для Heart Bet
	EventBus.guest_bets_hide_requested.connect(guest_event_handler.handle_guest_bets_hide_requested)
	EventBus.guest_bets_show_requested.connect(guest_event_handler.handle_guest_bets_show_requested)
	
	# Сигналы ухода гостей - очищаем ставки при уходе
	EventBus.guest_left_due_to_bankruptcy.connect(guest_event_handler.handle_guest_left)
	EventBus.guest_left_due_to_patience.connect(guest_event_handler.handle_guest_left)
	
	# Инициализируем видимость гостей на основе настроек
	guest_event_handler.update_guests_visibility()

func _initialize_heart_bet_controller() -> void:
	"""Инициализировать контроллер Heart Bet"""
	heart_bet_controller = HeartBetController.new(
		self,
		phase_manager,
		guest_sprites,
		background_666,
		winner_selection_manager,
		_prepare_payouts_manual  # Callback для подготовки выплат
	)
	
	# Подключаем сигналы
	_connect_heart_bet_signals()
	
	print("✅ HeartBetController инициализирован")

func _connect_heart_bet_signals() -> void:
	"""Подключить сигналы Heart Bet к heart_bet_controller"""
	if not heart_bet_controller:
		return
	
	# Сигналы от EventBus для Heart Bet
	EventBus.heart_bet_show_ui.connect(heart_bet_controller.handle_heart_bet_show_ui)
	EventBus.heart_bet_declined.connect(heart_bet_controller.handle_heart_bet_declined)
	EventBus.heart_bet_round_complete.connect(heart_bet_controller.handle_heart_bet_round_complete)

func _connect_settings_signals() -> void:
	"""Подключить сигналы настроек к settings_handler"""
	if not settings_handler:
		return
	
	# Сигналы от SettingsScene
	if settings_scene:
		settings_scene.mode_changed.connect(settings_handler.handle_mode_changed)
		settings_scene.language_changed.connect(settings_handler.handle_language_changed)
	
	# Сигналы от EventBus
	EventBus.payout_setting_changed.connect(settings_handler.handle_payout_setting_changed)
	EventBus.card_back_style_changed.connect(settings_handler.handle_card_back_style_changed)
	EventBus.position_mode_changed.connect(settings_handler.handle_position_mode_changed)
	
	# Сигнал от GameStateManager
	GameStateManager.state_changed.connect(settings_handler.handle_game_state_changed)

func _initialize_winner_selection_handler() -> void:
	"""Инициализировать обработчик выбора победителя"""
	winner_selection_handler = WinnerSelectionHandler.new(
		hand_manager,
		limits_manager,
		pair_betting_manager,
		phase_manager,
		winner_selection_manager,
		survival_state,
		_process_payout_queue_or_reset,
		_get_survival_rounds_completed,
		_get_tree
	)
	print("✅ WinnerSelectionHandler инициализирован")

func _get_survival_rounds_completed() -> int:
	"""Получить количество завершенных раундов (callback для WinnerSelectionHandler)"""
	return survival_rounds_completed

func _get_tree() -> SceneTree:
	"""Получить SceneTree (callback для WinnerSelectionHandler)"""
	return get_tree()

func _initialize_payout_queue_handler() -> void:
	"""Инициализировать обработчик очереди выплат"""
	var get_rounds_callback = func() -> int:
		return survival_rounds_completed
	
	var set_queue_callback = func(new_queue: PayoutQueueManager) -> void:
		payout_queue_manager = new_queue
	
	var get_tree_callback = func() -> SceneTree:
		return get_tree()
	
	payout_queue_handler = PayoutQueueHandler.new(
		phase_manager,
		payout_manager,
		payout_queue_manager,
		bet_collection_manager,
		chip_visual_manager,
		hand_manager,
		winner_selection_manager,
		camera_manager,
		limits_manager,
		pair_betting_manager,
		survival_state,
		get_rounds_callback,
		set_queue_callback,
		get_tree_callback
	)
	print("✅ PayoutQueueHandler инициализирован")

func _initialize_payout_overlay_coordinator() -> void:
	"""Инициализировать координатор PayoutOverlay"""
	var set_processing_callback = func(value: bool) -> void:
		is_payout_processing = value
	
	var update_visibility_callback = func() -> void:
		_update_chip_visibility()
	
	var get_tree_callback = func() -> SceneTree:
		return get_tree()
	
	var get_rounds_callback = func() -> int:
		return survival_rounds_completed
	
	payout_overlay_coordinator = PayoutOverlayCoordinator.new(
		payout_overlay,
		payout_result_handler,
		survival_state,
		ui_manager,
		payout_queue_manager,
		chip_visual_manager,
		set_processing_callback,
		update_visibility_callback,
		get_tree_callback,
		get_rounds_callback
	)
	
	# Подключаем сигнал payout_completed от PayoutOverlay к координатору
	if payout_overlay:
		# Отключаем старое подключение (если было)
		if payout_overlay.payout_completed.is_connected(_on_payout_overlay_completed):
			payout_overlay.payout_completed.disconnect(_on_payout_overlay_completed)
		# Подключаем к координатору
		payout_overlay.payout_completed.connect(_on_payout_overlay_completed)
	
	print("✅ PayoutOverlayCoordinator инициализирован")

func _initialize_camera_navigation_controller() -> void:
	"""Инициализировать контроллер навигации камеры"""
	if camera_manager:
		camera_navigation_controller = CameraNavigationController.new(camera_manager, self)
		
		# Подключаем сигналы EventBus
		if EventBus:
			EventBus.camera_zoom_requested.connect(camera_navigation_controller.on_camera_zoom_requested)
			EventBus.navigation_arrows_visibility_changed.connect(camera_navigation_controller.on_arrows_visibility_changed)
		
		print("✅ CameraNavigationController инициализирован")
	else:
		push_error("❌ CameraManager не инициализирован для CameraNavigationController!")

func _initialize_chip_navigation_coordinator() -> void:
	"""Инициализировать координатор навигации по ставкам"""
	if chip_navigation_manager and bet_collection_manager and ui_manager:
		# Создаем callback для call_deferred
		var deferred_callback = func():
			call_deferred("_activate_chip_navigation_deferred_internal")
		
		chip_navigation_coordinator = ChipNavigationCoordinator.new(
			chip_navigation_manager,
			bet_collection_manager,
			ui_manager,
			deferred_callback
		)
		
		# Подключаем сигналы EventBus
		if EventBus:
			EventBus.chip_navigation_activation_requested.connect(chip_navigation_coordinator.on_chip_navigation_activation_requested)
			EventBus.auto_switch_to_pay_mode_requested.connect(chip_navigation_coordinator.on_auto_switch_to_pay_mode_requested)
		
		print("✅ ChipNavigationCoordinator инициализирован")
	else:
		push_error("❌ Не все зависимости инициализированы для ChipNavigationCoordinator!")

func _initialize_collection_mode_handler() -> void:
	"""Инициализировать обработчик режимов сбора и оплаты"""
	if bet_collection_manager:
		collection_mode_handler = CollectionModeHandler.new(bet_collection_manager)
		print("✅ CollectionModeHandler инициализирован")
	else:
		push_error("❌ BetCollectionPhaseManager не инициализирован для CollectionModeHandler!")

func _initialize_keyboard_focus_handler() -> void:
	"""Инициализировать обработчик клавиатурного фокуса"""
	if phase_manager and winner_selection_manager:
		keyboard_focus_handler = KeyboardFocusHandler.new(phase_manager, winner_selection_manager)
		print("✅ KeyboardFocusHandler инициализирован")
	else:
		push_error("❌ Не все зависимости инициализированы для KeyboardFocusHandler!")

func _initialize_gamepad_monitor() -> void:
	"""Инициализировать монитор геймпадов"""
	gamepad_monitor = GamepadMonitor.new()
	gamepad_monitor.check_connection()  # Первоначальная проверка
	print("✅ GamepadMonitor инициализирован")

func _initialize_rounds_counter_updater() -> void:
	"""Инициализировать обновлятель счетчика раундов"""
	var rounds_callback = func() -> int:
		return survival_rounds_completed
	
	if rounds_counter_label:
		rounds_counter_updater = RoundsCounterUpdater.new(rounds_counter_label, rounds_callback)
		print("✅ RoundsCounterUpdater инициализирован")
	else:
		push_warning("⚠️ rounds_counter_label не найден для RoundsCounterUpdater")

func _initialize_guest_return_counter_ui() -> void:
	"""Инициализировать UI счетчиков возврата гостей (теперь только в настройках, не на главном экране)"""
	# Счетчики теперь показываются только в меню настроек
	# На главном экране они не нужны
	# Удаляем контейнер, если он был создан ранее
	var container = get_node_or_null("GuestReturnCounterContainer")
	if container:
		container.queue_free()
		print("✅ GuestReturnCounterContainer удален с главного экрана (счетчики теперь только в настройках)")
	
	# Счетчики теперь создаются только в SettingsScene при открытии настроек
	# На главном экране они не нужны

func _initialize_payout_return_handler() -> void:
	"""Инициализировать обработчик возврата из PayoutScene"""
	# Создаем StateRestorer если его еще нет
	if not state_restorer:
		state_restorer = StateRestorer.new(
			hand_manager,
			winner_selection_manager,
			survival_ui,
			camera_manager,
			ui_manager,
			card_manager
		)
	
	# Callbacks для обновления состояния
	var update_rounds_callback = func() -> void:
		_update_rounds_counter()
	
	var update_chips_callback = func() -> void:
		_update_chip_visibility()
	
	var get_tree_callback = func() -> SceneTree:
		return get_tree()
	
	payout_return_handler = PayoutReturnHandler.new(
		state_restorer,
		payout_overlay_coordinator,
		payout_queue_handler,
		phase_manager,
		survival_state,
		camera_manager,
		game_state_controller,
		hand_manager,
		winner_selection_manager,
		survival_ui,
		ui_manager,
		card_manager,
		update_rounds_callback,
		update_chips_callback,
		get_tree_callback
	)
	print("✅ PayoutReturnHandler инициализирован")

func _initialize_payout_preparation_handler() -> void:
	"""Инициализировать обработчик подготовки выплат"""
	payout_preparation_handler = PayoutPreparationHandler.new(
		hand_manager,
		limits_manager,
		pair_betting_manager,
		payout_queue_handler
	)
	print("✅ PayoutPreparationHandler инициализирован")

func _initialize_ui_event_handler() -> void:
	"""Инициализировать обработчик UI событий"""
	ui_event_handler = UIEventHandler.new(
		ui_manager,
		phase_manager,
		crib_sheet_scene,
		survival_state,
		self  # owner_node для доступа к дочерним элементам
	)
	print("✅ UIEventHandler инициализирован")

func _initialize_input_handler() -> void:
	"""Инициализировать обработчик ввода"""
	var restart_callback = func() -> void:
		_on_restart_game()
	
	var get_viewport_callback = func() -> Viewport:
		return get_viewport()
	
	input_handler = InputHandler.new(
		chance_card_navigator,
		chip_navigation_manager,
		game_state_controller,
		ui_manager,
		settings_scene,
		self,  # owner_node
		restart_callback,
		get_viewport_callback
	)
	print("✅ InputHandler инициализирован")

func _initialize_training_mode() -> void:
	"""Инициализировать режим обучения (менеджеры и UI-ссылки)"""
	var training_rng: RandomNumberGenerator = null
	if Engine.has_singleton("SessionManager"):
		var sm2: Node = Engine.get_singleton("SessionManager")
		if sm2.current_mode == sm2.Mode.ONLINE:
			var tseed: String = str(sm2.live_round_seed)
			if not tseed.is_empty():
				training_rng = LiveSeedRng.make_rng(tseed)
	var training_deck: Deck = Deck.new(training_rng)
	training_mode_manager = TrainingModeManager.new(training_deck, card_manager, ui_manager)
	training_stage_manager = TrainingStageManager.new()
	_setup_training_stages()
	training_progress_bar = get_node_or_null("TrainingLayer/TrainingProgressBar") as TrainingProgressBar
	training_instruction_popup = get_node_or_null("TrainingLayer/TrainingInstructionPopup") as TrainingInstructionPopup
	training_question_popup = get_node_or_null("TrainingLayer/TrainingQuestionPopup") as TrainingQuestionPopup
	training_stage_complete_popup = get_node_or_null("TrainingLayer/TrainingStageCompletePopup") as TrainingStageCompletePopup
	if training_instruction_popup:
		training_instruction_popup.start_button_pressed.connect(_on_training_instruction_start_pressed)
	if training_question_popup:
		training_question_popup.answer_selected.connect(_on_training_answer_selected)
	if training_stage_complete_popup:
		training_stage_complete_popup.repeat_pressed.connect(_on_training_repeat_pressed)
		training_stage_complete_popup.continue_pressed.connect(_on_training_continue_pressed)
	if training_mode_manager:
		training_mode_manager.progress_changed.connect(_on_training_progress_changed)
		training_mode_manager.stage_completed.connect(_on_training_stage_completed)
	print("✅ Режим обучения инициализирован")

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМ ОБУЧЕНИЯ — АКТИВАЦИЯ И ПОТОК
# ═══════════════════════════════════════════════════════════════════════════

func activate_training_mode() -> void:
	if not training_mode_manager or training_mode_manager.stages.is_empty():
		return
	is_training_mode_active = true
	training_mode_manager.activate_training_mode()
	_hide_main_game_elements()
	_show_training_elements()
	training_mode_manager.start_stage(0)
	if training_progress_bar:
		training_progress_bar.reset_progress()
	if training_instruction_popup and training_mode_manager.current_stage:
		training_instruction_popup.setup(training_mode_manager.current_stage.instruction_text)
		training_instruction_popup.popup_centered()
	EventBus.training_mode_activated.emit()

func deactivate_training_mode() -> void:
	is_training_mode_active = false
	if training_mode_manager:
		training_mode_manager.deactivate_training_mode()
	_show_main_game_elements()
	_hide_training_elements()
	EventBus.training_mode_deactivated.emit()

func _hide_main_game_elements() -> void:
	var top_ui: Node = get_node_or_null("TopUI")
	if top_ui:
		top_ui.visible = false
	for path in ["PlayerMarker", "BankerMarker", "TieMarker", "SettingsButton", "HelpButton"]:
		var n: Node = get_node_or_null(path)
		if n:
			n.visible = false

func _show_main_game_elements() -> void:
	var top_ui: Node = get_node_or_null("TopUI")
	if top_ui:
		top_ui.visible = true
	for path in ["PlayerMarker", "BankerMarker", "TieMarker", "SettingsButton", "HelpButton"]:
		var n: Node = get_node_or_null(path)
		if n:
			n.visible = true

func _show_training_elements() -> void:
	var layer: Node = get_node_or_null("TrainingLayer")
	if layer:
		layer.visible = true
	if training_progress_bar:
		training_progress_bar.visible = true

func _hide_training_elements() -> void:
	var layer: Node = get_node_or_null("TrainingLayer")
	if layer:
		layer.visible = false
	if training_instruction_popup and training_instruction_popup.visible:
		training_instruction_popup.hide()
	if training_question_popup and training_question_popup.visible:
		training_question_popup.hide()
	if training_stage_complete_popup and training_stage_complete_popup.visible:
		training_stage_complete_popup.hide()

func _training_show_cards(scenario: Dictionary) -> void:
	var p_hand: Array = _dict_value(scenario, "player_hand", [])
	var b_hand: Array = _dict_value(scenario, "banker_hand", [])
	if p_hand.size() >= 2 and b_hand.size() >= 2:
		var p1: TextureRect = get_node_or_null("PlayerZone/Card1") as TextureRect
		var p2: TextureRect = get_node_or_null("PlayerZone/Card2") as TextureRect
		var b1: TextureRect = get_node_or_null("BankerZone/Card1") as TextureRect
		var b2: TextureRect = get_node_or_null("BankerZone/Card2") as TextureRect
		if p1: p1.texture = (p_hand[0] as Card).get_texture(card_manager)
		if p2: p2.texture = (p_hand[1] as Card).get_texture(card_manager)
		if b1: b1.texture = (b_hand[0] as Card).get_texture(card_manager)
		if b2: b2.texture = (b_hand[1] as Card).get_texture(card_manager)
	var card3_p: TextureRect = get_node_or_null("PlayerZone/Card3") as TextureRect
	var card3_b: TextureRect = get_node_or_null("BankerZone/Card3") as TextureRect
	if card3_p: card3_p.visible = false
	if card3_b: card3_b.visible = false

func _on_training_instruction_start_pressed() -> void:
	if not training_mode_manager or not training_mode_manager.current_stage:
		return
	var scenario: Dictionary = training_mode_manager.generate_current_scenario()
	if scenario.is_empty():
		return
	_training_show_cards(scenario)
	if training_question_popup and training_mode_manager.current_stage:
		var stage: TrainingStageBase = training_mode_manager.current_stage
		var qtype: int = TrainingQuestionPopup.QuestionType.BINARY if stage.question_type == "binary" else TrainingQuestionPopup.QuestionType.ACTION_CHOICE
		training_question_popup.setup(stage.question_text, qtype, stage.get_answer_options(scenario))
		training_question_popup.popup_centered()

func _on_training_answer_selected(answer: Variant) -> void:
	if not training_mode_manager:
		return
	var result: Dictionary = training_mode_manager.process_answer(answer)
	if result.is_empty():
		return
	var is_correct: bool = bool(_dict_value(result, "is_correct", false))
	var explanation: String = str(_dict_value(result, "explanation", ""))
	var current_progress: float = float(_dict_value(result, "current_progress", 0.0))
	if is_correct:
		EventBus.show_overlay_success.emit("Верно!", 1.0)
	else:
		EventBus.show_overlay_error.emit("Ошибка!", 1.0)
	if explanation != "":
		EventBus.show_toast_info.emit(explanation)
	if training_progress_bar:
		training_progress_bar.update_progress(current_progress)
	EventBus.training_answer_processed.emit(is_correct, explanation, current_progress)
	# Если этап не завершён — через короткую паузу показать следующий вопрос (новые карты + попап).
	# Таймер даёт время закрыться попапу и показать «Верно!», затем стабильно открыть следующий вопрос.
	if not training_mode_manager.is_current_stage_complete():
		var t: SceneTreeTimer = get_tree().create_timer(0.45)
		t.timeout.connect(_training_next_round)
	else:
		# stage_completed уже эмитится из process_answer, попап покажет _on_training_stage_completed
		pass

func _training_next_round() -> void:
	"""Следующий раунд этапа: новые карты и вопрос"""
	if not training_mode_manager or not training_mode_manager.current_stage:
		return
	var scenario: Dictionary = training_mode_manager.generate_current_scenario()
	if scenario.is_empty():
		return
	_training_show_cards(scenario)
	if training_question_popup and training_mode_manager.current_stage:
		var stage: TrainingStageBase = training_mode_manager.current_stage
		var qtype: int = TrainingQuestionPopup.QuestionType.BINARY if stage.question_type == "binary" else TrainingQuestionPopup.QuestionType.ACTION_CHOICE
		training_question_popup.setup(stage.question_text, qtype, stage.get_answer_options(scenario))
		training_question_popup.popup_centered()

func _on_training_progress_changed(_stage_id: String, progress: float) -> void:
	if training_progress_bar:
		training_progress_bar.update_progress(progress)

func _on_training_stage_completed(_stage_id: String) -> void:
	if training_stage_manager and training_mode_manager and training_mode_manager.current_stage:
		training_stage_manager.mark_stage_completed(training_mode_manager.current_stage.stage_id)
	if training_stage_complete_popup:
		var is_last: bool = not training_mode_manager.has_next_stage()
		training_stage_complete_popup.setup(training_mode_manager.get_current_progress(), is_last)
		training_stage_complete_popup.popup_centered()

func _on_training_repeat_pressed() -> void:
	if not training_mode_manager or not training_mode_manager.current_stage:
		return
	training_mode_manager.stage_progress[training_mode_manager.current_stage.stage_id] = 0.0
	if training_progress_bar:
		training_progress_bar.reset_progress()
	if training_instruction_popup and training_mode_manager.current_stage:
		training_instruction_popup.setup(training_mode_manager.current_stage.instruction_text)
		training_instruction_popup.popup_centered()

func _on_training_continue_pressed() -> void:
	if not training_mode_manager:
		return
	var next_idx: int = training_mode_manager.get_next_stage_index()
	if next_idx < 0:
		deactivate_training_mode()
		if settings_scene and settings_scene is CanvasLayer:
			settings_scene.visible = false
		return
	training_mode_manager.start_stage(next_idx)
	if training_progress_bar:
		training_progress_bar.reset_progress()
	if training_instruction_popup and training_mode_manager.current_stage:
		training_instruction_popup.setup(training_mode_manager.current_stage.instruction_text)
		training_instruction_popup.popup_centered()

func _setup_training_stages() -> void:
	if not training_mode_manager:
		return
	var card_gen: TrainingCardGenerator = TrainingCardGenerator.new(training_mode_manager.deck)
	var natural_stage: NaturalWinStage = NaturalWinStage.new(card_gen)
	training_mode_manager.stages.append(natural_stage)
	if training_stage_manager:
		training_stage_manager.register_stage(natural_stage)
	print("✅ Этапы обучения зарегистрированы (1 этап)")

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ - ВЫНЕСЕНА В GameInitializer.gd
# ═══════════════════════════════════════════════════════════════════════════
# Все helper методы инициализации перенесены в GameInitializer.initialize()
# Удалено ~235 строк дублирующего кода

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КАРТАМИ
# ═══════════════════════════════════════════════════════════════════════════
# Методы управления отображением карт (делегировано в CardController)
# Все методы являются обертками для обратной совместимости

func set_flip_cards(cards: Array) -> void:
	"""Установить массив анимаций переворота карт (для обратной совместимости)
	
	Args:
		cards: Массив FlipCard узлов для анимаций
	
	Делегирует установку в CardController. flip_cards хранится только в CardController.
	"""
	# Обновляем локальную переменную для обратной совместимости (если где-то используется напрямую)
	flip_cards = cards
	# Делегируем в CardController (основное хранилище)
	if card_controller:
		card_controller.set_flip_cards(cards)

func show_all_backs(back_texture: Texture2D) -> void:
	"""Показать рубашки всех карт (делегировано в CardController)
	
	Args:
		back_texture: Текстура рубашки карты
	"""
	if card_controller:
		card_controller.show_all_backs(back_texture)

func open_all_cards(face_textures: Array, delay: float = GameConstants.FLIP_CARD_DELAY):
	"""Открыть все карты с задержкой (делегировано в CardController)
	
	Args:
		face_textures: Массив текстур карт для отображения
		delay: Задержка между открытием карт (по умолчанию из GameConstants)
	"""
	if card_controller:
		await card_controller.open_all_cards(face_textures, delay)

func open_all_cards_with_flip(face_textures: Array, delay: float = GameConstants.FLIP_CARD_DELAY):
	"""Открыть все карты с flip-анимацией (делегировано в CardController)
	
	Args:
		face_textures: Массив текстур карт для отображения
		delay: Задержка между картами (по умолчанию из GameConstants)
	"""
	if card_controller:
		await card_controller.open_all_cards_with_flip(face_textures, delay)

func open_two_third_cards(texture1: Texture2D, texture2: Texture2D) -> void:
	"""Открыть две третьи карты (делегировано в CardController)
	
	Args:
		texture1: Текстура первой третьей карты (Player)
		texture2: Текстура второй третьей карты (Banker)
	"""
	if card_controller:
		card_controller.open_two_third_cards(texture1, texture2)

func reset_cards(back_texture: Texture2D) -> void:
	"""Сбросить все карты (делегировано в CardController)
	
	Args:
		back_texture: Текстура рубашки карты
	"""
	if card_controller:
		card_controller.reset_cards(back_texture)

# ═══════════════════════════════════════════════════════════════════════════
# ВЫБОР ПОБЕДИТЕЛЯ
# ═══════════════════════════════════════════════════════════════════════════
# Обработка выбора победителя (делегировано в WinnerSelectionHandler)

func _on_winner_selected(chosen: String):
	"""Обработка выбора победителя игроком (делегировано в WinnerSelectionHandler)"""
	if winner_selection_handler:
		await winner_selection_handler.handle_winner_selected(chosen)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ОЧЕРЕДИ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════
# Методы для работы с очередью выплат (делегировано в PayoutQueueHandler)

func _process_payout_queue_or_reset() -> void:
	"""Обработка очереди выплат или сброс раунда (если очередь пуста) - делегировано в PayoutQueueHandler"""
	if payout_queue_handler:
		payout_queue_handler.process_payout_queue_or_reset(get_tree())
	else:
		push_error("❌ PayoutQueueHandler не инициализирован!")



func _format_result() -> String:
	"""Форматирование результата раздачи для отображения - делегировано в PayoutPreparationHandler"""
	if payout_preparation_handler:
		return payout_preparation_handler.format_result()
	return ""

func _format_victory_toast(winner: String) -> String:
	"""Форматирование краткого тоста победы - делегировано в PayoutPreparationHandler"""
	if payout_preparation_handler:
		return payout_preparation_handler.format_victory_toast(winner)
	return "???"

# ═══════════════════════════════════════════════════════════════════════════
# ПОДГОТОВКА И РАСЧЕТ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════
# Методы для подготовки и расчета выплат в ручном режиме

func _prepare_payouts_manual(actual_winner: String) -> void:
	"""Подготовка выплат в ручном режиме - делегировано в PayoutPreparationHandler"""
	if payout_preparation_handler:
		var updated_manager = payout_preparation_handler.prepare_payouts_manual(actual_winner)
		if updated_manager:
			payout_queue_manager = updated_manager
	else:
		push_error("❌ PayoutPreparationHandler не инициализирован!")


# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ _prepare_payouts_standard и _prepare_payouts_realistic ПЕРЕНЕСЕНЫ
# В PayoutManager для соблюдения SRP
# ═══════════════════════════════════════════════════════════════════════════


func _generate_stake_for_bet_type(bet_type: String) -> float:
	"""Генерация размера ставки для типа - делегировано в PayoutPreparationHandler"""
	if payout_preparation_handler:
		return payout_preparation_handler.generate_stake_for_bet_type(bet_type)
	return 0.0

func _calculate_payout_for_bet_type(bet_type: String, stake: float, won: bool) -> float:
	"""Расчёт выплаты для типа ставки - делегировано в PayoutPreparationHandler"""
	if payout_preparation_handler:
		return payout_preparation_handler.calculate_payout_for_bet_type(bet_type, stake, won)
	return 0.0

func _finalize_payouts_manual(actual_winner: String) -> void:
	"""Завершение подготовки выплат - делегировано в PayoutPreparationHandler"""
	if payout_preparation_handler:
		payout_preparation_handler.finalize_payouts_manual(actual_winner)
	else:
		push_error("❌ PayoutPreparationHandler не инициализирован!")


func _update_chip_visibility() -> void:
	"""Обновить видимость и кликабельность фишек через ChipVisualManager - делегировано в PayoutQueueHandler"""
	if payout_queue_handler:
		payout_queue_handler.update_chip_visibility()
	else:
		push_error("❌ PayoutQueueHandler не инициализирован!")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ UI СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════
# Обработчики событий от UI элементов (кнопки, переключатели)

func _on_help_button_pressed() -> void:
	"""Обработчик нажатия кнопки помощи - делегировано в UIEventHandler"""
	if ui_event_handler:
		ui_event_handler.on_help_button_pressed()
	else:
		push_error("❌ UIEventHandler не инициализирован!")

func _on_lang_button_pressed() -> void:
	"""Обработчик нажатия кнопки переключения языка - делегировано в UIEventHandler"""
	if ui_event_handler:
		ui_event_handler.on_lang_button_pressed()
	else:
		push_error("❌ UIEventHandler не инициализирован!")

func _on_payout_confirmed(is_correct: bool, collected: float, expected: float) -> void:
	"""Обработчик подтверждения выплаты - делегировано в UIEventHandler"""
	if ui_event_handler:
		ui_event_handler.on_payout_confirmed(is_correct, collected, expected)
	else:
		push_error("❌ UIEventHandler не инициализирован!")

# ═══════════════════════════════════════════════════════════════════════════
# GAME OVER И РЕСТАРТ
# ═══════════════════════════════════════════════════════════════════════════

func is_game_active() -> bool:
	"""Проверка, активна ли игра (не в Game Over) - делегировано в GameStateController"""
	if game_state_controller:
		return game_state_controller.is_game_active()
	return true  # По умолчанию игра активна

func _on_survival_game_over(_rounds: int):
	"""Обработчик Game Over - делегировано в GameStateController"""
	if game_state_controller:
		game_state_controller.handle_game_over(survival_rounds_completed)

# _on_score_game_over удалён - Game Over теперь только через сердца (HeartBar)

func _on_restart_game():
	"""Обработчик рестарта игры - делегировано в GameStateController"""
	# Сбрасываем счетчик раундов
	survival_rounds_completed = 0
	_update_rounds_counter()
	EventBus.camera_first_deal_set_requested.emit(true)  # После рестарта первая раздача с зумом
	StatsManager.instance.reset()
	
	# Делегируем рестарт в GameStateController
	if game_state_controller:
		game_state_controller.restart_game()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА КЛАВИАТУРЫ
# ═══════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	"""Обработка ввода (клавиатура и геймпад) - делегировано в InputHandler"""
	# Проверяем инициализацию и валидность input_handler
	if input_handler and is_instance_valid(input_handler):
		if input_handler.handle_input(event):
			get_viewport().set_input_as_handled()
	# Не выводим ошибку, если input_handler еще не инициализирован (может быть вызвано до _ready)

func _unhandled_input(event: InputEvent) -> void:
	"""Обработка необработанного ввода - делегировано в InputHandler"""
	# Проверяем инициализацию и валидность input_handler
	if input_handler and is_instance_valid(input_handler):
		if input_handler.handle_unhandled_input(event):
			get_viewport().set_input_as_handled()
	# Не выводим ошибку, если input_handler еще не инициализирован (может быть вызвано до _ready)

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_settings_button_pressed() -> void:
	"""Обработчик нажатия кнопки настроек
	
	Открывает или закрывает меню настроек в зависимости от текущего состояния.
	UI элементы игры скрываются/показываются автоматически через сигналы.
	"""
	DebugLogger.log("🔘 Кнопка настроек нажата!")
	DebugLogger.log("  settings_scene существует: %s" % (settings_scene != null))

	if settings_scene:
		DebugLogger.log("  settings_scene.visible = %s" % settings_scene.visible)
		if settings_scene.visible:
			DebugLogger.log("  → Закрываем настройки")
			settings_scene.close_settings()
			# Кнопка "Карты" включится через сигнал settings_closed
		else:
			# Настройки можно открыть в любое время
			# Защита от удаления ставок во время раздачи реализована в GuestEventHandler.handle_guest_settings_changed()
			DebugLogger.log("  → Открываем настройки")
			settings_scene.open_settings()
			# UI элементы будут скрыты через сигнал EventBus.settings_opened в _on_settings_opened()
	else:
		DebugLogger.log("  ❌ ОШИБКА: settings_scene = null!")

func _on_settings_opened():
	"""Обработчик открытия настроек — скрываем UI элементы игры"""
	# Отключаем кнопку "Карты" чтобы случайно не нажать
	if ui_manager and ui_manager.button_ui and ui_manager.button_ui.action_button:
		ui_manager.button_ui.action_button.disabled = true
		DebugLogger.log("⚙️ Кнопка 'Карты' отключена (настройки открыты)")
	
	# Скрываем UI элементы игры
	if ui_event_handler:
		ui_event_handler.hide_game_ui_elements()
	else:
		push_error("❌ UIEventHandler не инициализирован!")

func _on_settings_closed():
	"""Обработчик закрытия настроек — включаем кнопку 'Карты' обратно"""
	# Напрямую disabled = false (не через enable_action_button)
	if ui_manager and ui_manager.button_ui and ui_manager.button_ui.action_button:
		ui_manager.button_ui.action_button.disabled = false
		DebugLogger.log("⚙️ Настройки закрыты → кнопка 'Карты' включена")
	
	# Убираем фокус с кнопки настроек, чтобы пробел не активировал её
	if settings_button:
		settings_button.release_focus()
	# Также сбрасываем фокус со всего viewport
	if get_viewport():
		get_viewport().gui_release_focus()
	
	# Включаем обратно все UI элементы
	if ui_event_handler:
		ui_event_handler.show_game_ui_elements()
	else:
		push_error("❌ UIEventHandler не инициализирован!")

func apply_training_hints_enabled(enabled: bool) -> void:
	"""Применить настройку показа учебных подсказок дилера к текущему UI"""
	if ui_manager:
		ui_manager.set_training_hints_enabled(enabled)

# Методы управления видимостью UI элементов перенесены в UIEventHandler
# _hide_game_ui_elements -> ui_event_handler.hide_game_ui_elements
# _show_game_ui_elements -> ui_event_handler.show_game_ui_elements


# Методы обработки настроек перенесены в SettingsEventHandler
# _on_mode_changed -> settings_handler.handle_mode_changed
# _apply_mode_change -> settings_handler.apply_mode_change
# _on_language_changed -> settings_handler.handle_language_changed
# _on_survival_mode_changed -> settings_handler.handle_survival_mode_changed

func _load_survival_mode_setting():
	"""Активировать режим выживания (всегда включён)"""
	if survival_state:
		survival_state.activate()
	_apply_survival_ui_visibility_for_current_mode()
	# StatsLabel показывает деньги (управляется в StatsManager)
	DebugLogger.log("Режим выживания активирован (сердца + деньги)")


func _apply_survival_ui_visibility_for_current_mode() -> void:
	if not survival_ui:
		return
	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")
	if sm != null and sm.get("current_mode") == sm.Mode.TOURNAMENT:
		survival_ui.hide()
		return
	if survival_state:
		survival_ui.visible = survival_state.is_active_mode()

# Метод _on_game_state_changed перенесён в SettingsEventHandler.handle_game_state_changed

# ═══════════════════════════════════════════════════════════════════════════
# КЛАВИАТУРНАЯ НАВИГАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ РЕЖИМ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_manual_mode_payout_return(context: Dictionary) -> void:
	"""Обработка возврата из PayoutScene в ручном режиме - делегировано в PayoutReturnHandler"""
	if payout_return_handler:
		var result = payout_return_handler.handle_manual_mode_payout_return(context, survival_rounds_completed, payout_queue_manager)
		survival_rounds_completed = result["survival_rounds_completed"]
		payout_queue_manager = result["payout_queue_manager"]
		# Обновляем ссылку в phase_manager (уже сделано в restore_survival_and_queue, но на всякий случай)
		phase_manager.payout_queue_manager = payout_queue_manager
	else:
		push_error("❌ PayoutReturnHandler не инициализирован!")


# Методы восстановления состояния перенесены в PayoutReturnHandler
# _restore_table_state -> payout_return_handler.restore_table_state
# _restore_survival_and_queue -> payout_return_handler.restore_survival_and_queue
# _process_manual_payout_result -> payout_return_handler.process_manual_payout_result
# _restore_camera_and_cleanup -> payout_return_handler.restore_camera_and_cleanup


# ═══════════════════════════════════════════════════════════════════════════
# АВТОМАТИЧЕСКИЙ РЕЖИМ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_automatic_mode_payout_return() -> void:
	"""Обработка возврата из PayoutScene в автоматическом режиме - делегировано в PayoutReturnHandler"""
	if payout_return_handler:
		var result = payout_return_handler.handle_automatic_mode_payout_return(survival_rounds_completed)
		survival_rounds_completed = result["survival_rounds_completed"]
		# should_reset уже обработан в PayoutReturnHandler
	else:
		push_error("❌ PayoutReturnHandler не инициализирован!")

# Методы автоматического режима перенесены в PayoutReturnHandler
# _restore_automatic_mode_state -> payout_return_handler.restore_automatic_mode_state
# _check_and_handle_game_over -> payout_return_handler.check_and_handle_game_over
# _process_automatic_payout_result -> payout_return_handler.process_automatic_payout_result
# _handle_payout_queue -> payout_return_handler.handle_payout_queue



# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КАМЕРОЙ
# ═══════════════════════════════════════════════════════════════════════════
# Методы для управления камерой (зум, навигация по областям)
# Все запросы идут через EventBus для слабой связанности

func camera_zoom_in() -> void:
	"""Плавный зум на область карт (через EventBus) - делегировано в CameraNavigationController"""
	if camera_navigation_controller:
		camera_navigation_controller.camera_zoom_in()
	else:
		push_error("❌ CameraNavigationController не инициализирован!")

func camera_zoom_out() -> void:
	"""Возврат к общему плану (через EventBus) - делегировано в CameraNavigationController"""
	if camera_navigation_controller:
		camera_navigation_controller.camera_zoom_out()
	else:
		push_error("❌ CameraNavigationController не инициализирован!")

func camera_zoom_cards() -> void:
	"""Плавный зум на область карт (через EventBus) - делегировано в CameraNavigationController"""
	if camera_navigation_controller:
		camera_navigation_controller.camera_zoom_cards()
	else:
		push_error("❌ CameraNavigationController не инициализирован!")

func camera_zoom_area(area_index: int) -> void:
	"""Плавный зум на область ставок (через EventBus) - делегировано в CameraNavigationController
	
	Args:
		area_index: Индекс области (1-3)
	"""
	if camera_navigation_controller:
		camera_navigation_controller.camera_zoom_area(area_index)
	else:
		push_error("❌ CameraNavigationController не инициализирован!")

# ═══════════════════════════════════════════════════════════════════════════
# НАВИГАЦИЯ ПО ОБЛАСТЯМ (СТРЕЛКИ)
# ═══════════════════════════════════════════════════════════════════════════
# Обработчики навигации по областям через стрелки
# Все запросы идут через EventBus

# Методы управления камерой перенесены в CameraNavigationController
# _request_camera_target_area -> camera_navigation_controller.request_camera_target_area
# _on_arrows_visibility_changed -> camera_navigation_controller.on_arrows_visibility_changed
# _update_arrows_state -> camera_navigation_controller.update_arrows_state
# _update_arrows_for_area -> camera_navigation_controller.update_arrows_for_area
# _apply_arrows_state -> camera_navigation_controller.apply_arrows_state



# Методы обработки настроек перенесены в SettingsEventHandler
# _on_payout_setting_changed -> settings_handler.handle_payout_setting_changed
# _on_card_back_style_changed -> settings_handler.handle_card_back_style_changed
# _on_position_mode_changed -> settings_handler.handle_position_mode_changed

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СТАВОК И ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════
# Обработчики событий для работы со ставками и фишками
# Большая часть логики делегирована в специализированные обработчики

func _on_winner_toggled(winner: String, selected: bool):
	EventBus.dealer_winner_marker_toggled.emit(winner, selected)
	if selected:
		DebugLogger.log("🎯 Выбран: %s" % winner)
		if ui_manager:
			ui_manager.reset_inspector_hint()
		# TieMarker всегда виден (не деактивируется)
		# Отменяем заказ третьих карт при активации маркера
		if phase_manager:
			phase_manager.cancel_third_card_orders()
			# ВАЖНО: Сбрасываем состояние кнопки обратно в "confirm" при выборе нового маркера
			# Это позволяет повторно проверить правильность выбора при следующем нажатии
			var current_button_state = ui_manager.get_action_button_state()
			if current_button_state == "complete":
				ui_manager.set_action_button_state("confirm")
				ui_manager.enable_action_button()
				DebugLogger.log("🔄 Состояние кнопки сброшено с 'complete' на 'confirm' при выборе маркера")
	else:
		DebugLogger.log("🎯 Снят выбор: %s" % winner)
		# TieMarker всегда виден и доступен (не нужно активировать/деактивировать)

	_update_stop_hint_for_winner_preview()

func _update_stop_hint_for_winner_preview() -> void:
	if not ui_manager:
		return
	if not winner_selection_manager:
		ui_manager.hide_stop_hint()
		return

	var selected_winner: String = winner_selection_manager.get_selected_winner()
	if selected_winner.is_empty():
		ui_manager.hide_stop_hint()
		return

	if not GameStateManager.is_action_valid(GameStateManager.Action.SELECT_WINNER):
		ui_manager.show_stop_hint()
		return

	if not phase_manager or not phase_manager.winner_validator or not hand_manager:
		ui_manager.hide_stop_hint()
		return

	var validation: Dictionary = phase_manager.winner_validator.validate_winner_selection(
		selected_winner,
		hand_manager.get_player_hand_ref(),
		hand_manager.get_banker_hand_ref()
	)

	if bool(validation.get("is_valid", false)):
		ui_manager.hide_stop_hint()
		return

	if bool(validation.get("needs_selection", false)):
		ui_manager.hide_stop_hint()
		return

	ui_manager.show_stop_hint()


# Методы обработки событий камеры перенесены в CameraNavigationController
# _on_camera_zoom_completed -> camera_navigation_controller.on_camera_zoom_completed
# _update_area_highlights -> camera_navigation_controller.update_area_highlights
# _on_camera_zoom_requested -> camera_navigation_controller.on_camera_zoom_requested


# ═══════════════════════════════════════════════════════════════════════════
# ❤️ HEART BET - СКРЫТИЕ/ПОКАЗ СТАВОК ГОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════



# Методы обработки событий гостей перенесены в GuestEventHandler
# _on_guest_settings_changed -> guest_event_handler.handle_guest_settings_changed
# _on_guest_settings_changed_visibility -> guest_event_handler.handle_guest_settings_changed_visibility
# _update_guests_visibility -> guest_event_handler.update_guests_visibility

# Методы управления атмосферой Heart Bet перенесены в HeartBetController
# _enable_life_bet_atmosphere -> heart_bet_controller.enable_life_bet_atmosphere
# _disable_life_bet_atmosphere -> heart_bet_controller.disable_life_bet_atmosphere
# _create_fade_animation -> удалён (используется только в HeartBetController)
# _on_heart_bet_show_ui -> heart_bet_controller.handle_heart_bet_show_ui


# ═══════════════════════════════════════════════════════════════════════════
# 🎴 НОВАЯ СИСТЕМА КАРТ ШАНСА
# ═══════════════════════════════════════════════════════════════════════════

func _setup_chance_card_system() -> void:
	"""Настройка новой системы карт шанса"""
	# Находим хранилище карт в сцене
	var storage = get_node_or_null("TopUI/ChanceCardStorage")
	if storage:
		ChanceCardManager.set_storage(storage)
		print("🎴 ChanceCardStorage подключен к ChanceCardManager")
		
		# Устанавливаем видимость в зависимости от настройки
		var chance_cards_enabled = SaveManager.instance.load_chance_cards_enabled()
		storage.visible = chance_cards_enabled
		print("🎴 ChanceCardStorage: %s (настройка: %s)" % [
			"показан" if chance_cards_enabled else "скрыт",
			"включено" if chance_cards_enabled else "выключено"
		])
	else:
		push_warning("⚠️ ChanceCardStorage не найден в TopUI")
	
	# Передаём phase_manager для доступа к HeartBetManager
	if phase_manager:
		ChanceCardManager.set_phase_manager(phase_manager)
		print("🎴 GamePhaseManager передан в ChanceCardManager")
	
	# Передаём heart_bar для доступа к жизням
	if heart_bar:
		ChanceCardManager.set_heart_bar(heart_bar)
		print("🎴 HeartBar передан в ChanceCardManager")
	
	print("🎴 Система карт шанса настроена")

func _initialize_chance_card_navigation() -> void:
	"""Инициализировать навигатор карт шансов"""
	# Ждём, пока система карт полностью инициализируется
	await get_tree().process_frame
	
	# Проверяем, что хранилище и сцена полного экрана доступны
	if not ChanceCardManager.storage:
		push_warning("⚠️ ChanceCardStorage не доступен для навигатора")
		return
	
	# Создаём сцену полного экрана если её ещё нет
	if not ChanceCardManager.fullscreen_scene:
		var scene_path = "res://scenes/chance_cards/BaseChanceCardScene.tscn"
		var scene = load(scene_path) as PackedScene
		if scene:
			ChanceCardManager.fullscreen_scene = scene.instantiate()
			get_tree().root.add_child(ChanceCardManager.fullscreen_scene)
			print("🎴 BaseChanceCardScene создана для навигатора")
		else:
			push_warning("⚠️ BaseChanceCardScene.tscn не найден")
			return
	
	# Создаём навигатор
	chance_card_navigator = ChanceCardNavigator.new(
		ChanceCardManager.storage,
		ChanceCardManager.fullscreen_scene
	)
	
	print("✅ ChanceCardNavigator инициализирован")

# Методы обработки ставок гостей перенесены в GuestEventHandler
# _on_guest_bets_hide_requested -> guest_event_handler.handle_guest_bets_hide_requested
# _on_guest_bets_show_requested -> guest_event_handler.handle_guest_bets_show_requested


# Методы обработки событий Heart Bet перенесены в HeartBetController
# _on_heart_bet_declined -> heart_bet_controller.handle_heart_bet_declined
# _on_heart_bet_round_complete -> heart_bet_controller.handle_heart_bet_round_complete


# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМЫ СБОРА И ОПЛАТЫ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════
# Обработчики переключения режимов сбора и оплаты ставок

func _on_collect_mode_toggled(enabled: bool) -> void:
	"""Обработчик toggle кнопки 'Забрать' - делегировано в CollectionModeHandler
	
	Args:
		enabled: Включен ли режим сбора ставок
	"""
	if collection_mode_handler:
		collection_mode_handler.on_collect_mode_toggled(enabled)
	else:
		push_error("❌ CollectionModeHandler не инициализирован!")

func _on_pay_mode_toggled(enabled: bool) -> void:
	"""Обработчик toggle кнопки 'Оплатить' - делегировано в CollectionModeHandler
	
	Args:
		enabled: Включен ли режим оплаты ставок
	"""
	if collection_mode_handler:
		collection_mode_handler.on_pay_mode_toggled(enabled)
	else:
		push_error("❌ CollectionModeHandler не инициализирован!")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА КЛИКОВ НА ФИШКИ
# ═══════════════════════════════════════════════════════════════════════════
# Обработчики кликов на фишки (делегировано в ChipClickHandler)

func _on_chip_clicked(bet_type: String) -> void:
	"""Обработчик клика на фишку (старый интерфейс, для обратной совместимости)
	
	Args:
		bet_type: Тип ставки (например, "Player", "Banker", "Tie")
	
	Вызывает новый обработчик с position_index = 0 для обратной совместимости.
	"""
	# Вызываем новый обработчик с position_index = 0
	_on_chip_instance_clicked(bet_type, 0)

func _on_chip_instance_clicked(bet_type: String, position_index: int):
	"""Обработчик клика на конкретную фишку (с position_index)
	
	Делегирует обработку в ChipClickHandler (Extract Class)
	"""
	if chip_click_handler:
		await chip_click_handler.handle_chip_click(bet_type, position_index)
	else:
		push_error("❌ ChipClickHandler не инициализирован!")


func _show_payout_overlay_instance(bet_type: String, position_index: int, stake: float, payout: float) -> void:
	"""Показать PayoutOverlay для конкретной фишки - делегировано в PayoutOverlayCoordinator
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции ставки
		stake: Размер ставки
		payout: Размер выплаты
	"""
	if payout_overlay_coordinator:
		payout_overlay_coordinator.show_payout_overlay_instance(bet_type, position_index, stake, payout)
	else:
		push_error("❌ PayoutOverlayCoordinator не инициализирован!")

func _open_payout_scene(bet_type: String) -> void:
	"""Открыть PayoutScene для конкретной ставки - делегировано в PayoutOverlayCoordinator
	
	Args:
		bet_type: Тип ставки
	"""
	if payout_overlay_coordinator:
		payout_overlay_coordinator.open_payout_scene(bet_type)
	else:
		push_error("❌ PayoutOverlayCoordinator не инициализирован!")


# ═══════════════════════════════════════════════════════════════════════════
# OVERLAY РЕЖИМ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════
# Методы для работы с PayoutOverlay (делегировано в PayoutOverlayCoordinator)
# Overlay режим - выплаты показываются поверх игры без перехода в другую сцену

func _show_payout_overlay(bet_type: String, stake: float, payout: float):
	"""Показать PayoutOverlay с параметрами выплаты - делегировано в PayoutOverlayCoordinator"""
	if payout_overlay_coordinator:
		payout_overlay_coordinator.show_payout_overlay(bet_type, stake, payout)
	else:
		push_error("❌ PayoutOverlayCoordinator не инициализирован!")


func _on_payout_overlay_completed(bet_type: String, is_correct: bool, collected: float, expected: float):
	"""Обработчик завершения выплаты в overlay режиме - делегировано в PayoutOverlayCoordinator"""
	if payout_overlay_coordinator:
		payout_overlay_coordinator.on_payout_overlay_completed(bet_type, is_correct, collected, expected)
	else:
		push_error("❌ PayoutOverlayCoordinator не инициализирован!")

		# Проверяем, остались ли неоплаченные выплаты
		var has_unpaid = payout_queue_manager.has_unpaid_winnings() if payout_queue_manager else false

		if not has_unpaid:
			# Все выплаты оплачены → эмитим событие подготовки стола
			DebugLogger.log("  ✅ Все выплаты оплачены! Стол готов к новой раздаче")
			# НЕ скрываем стрелки здесь - они скроются при нажатии "Завершить"
			# Эмитим событие для разблокировки маркеров и подготовки стола
			EventBus.table_prepared_for_new_game.emit()
			# НЕ вызываем phase_manager.reset() в overlay режиме!
			# Карты остаются на столе, пользователь нажимает "Завершить" для новой раздачи
		else:
			DebugLogger.log("  ⏳ Есть еще неоплаченные выплаты, ждем клика на следующую фишку")
	
	# ═══════════════════════════════════════════════════════════════════
	# СНЯТИЕ БЛОКИРОВКИ (с задержкой для защиты от спама Space)
	# ═══════════════════════════════════════════════════════════════════
	_release_payout_processing_lock()


func _release_payout_processing_lock():
	"""Снять блокировку обработки выплат с небольшой задержкой"""
	# Ждём несколько кадров чтобы все нажатия Space успели "затухнуть"
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	is_payout_processing = false
	DebugLogger.log("🔓 Блокировка выплат снята")


# ═══════════════════════════════════════════════════════════════════════════
# ВОССТАНОВЛЕНИЕ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════
# Методы для восстановления состояния игры (делегировано в StateRestorer)

func _restore_cards_ui():
	"""Восстановить карты на UI после возврата из PayoutScene
	
	Рефакторено: использует StateRestorer (SRP)
	"""
	if not state_restorer:
		state_restorer = StateRestorer.new(
			hand_manager,
			winner_selection_manager,
			survival_ui,
			camera_manager,
			ui_manager,
			card_manager
		)
	
	state_restorer.restore_cards_ui()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ EVENTBUS
# ═══════════════════════════════════════════════════════════════════════════
# Обработчики событий от EventBus для различных систем
# Все обработчики используют EventBus для слабой связанности

func _on_manual_payout_requested(winner: String):
	"""Обработка запроса подготовки выплат от GamePhaseManager через EventBus"""
	_prepare_payouts_manual(winner)

# Методы навигации по ставкам перенесены в ChipNavigationCoordinator
# _on_chip_navigation_activation_requested -> chip_navigation_coordinator.on_chip_navigation_activation_requested
# _has_bets_to_process -> chip_navigation_coordinator.has_bets_to_process
# _on_auto_switch_to_pay_mode_requested -> chip_navigation_coordinator.on_auto_switch_to_pay_mode_requested

func _activate_chip_navigation_deferred_internal() -> void:
	"""Внутренний метод для отложенной активации chip navigation (через call_deferred)"""
	if chip_navigation_coordinator:
		chip_navigation_coordinator.activate_chip_navigation_deferred()
	else:
		push_error("❌ ChipNavigationCoordinator не инициализирован!")

func _on_table_prepared():
	"""Обработка подготовки стола к новой игре"""
	is_table_prepared_for_new_game = true

	# Разблокируем маркеры для новой игры
	if winner_selection_manager:
		winner_selection_manager.unlock_markers()
	
	# Новая система карт управляется через ChanceCardManager
	# Видимость обновляется автоматически через EventBus.chance_count_changed

	DebugLogger.log_game_flow("Стол подготовлен к новой игре (флаг is_table_prepared установлен, маркеры разблокированы)")

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ БАЛАНСА ГОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════

# Методы обновления баланса гостей перенесены в GuestEventHandler
# _update_guest_balance_for_bet -> guest_event_handler.update_guest_balance_for_bet
# _update_guest_balance_on_collect -> guest_event_handler.update_guest_balance_on_collect


# ═══════════════════════════════════════════════════════════════════════════
# ЛОГИРОВАНИЕ СМЕНЫ ЛИМИТОВ
# ═══════════════════════════════════════════════════════════════════════════

# Метод _log_mode_change перенесён в SettingsEventHandler.log_mode_change


# ═══════════════════════════════════════════════════════════════════════════
# КЛАВИАТУРНОЕ УПРАВЛЕНИЕ ФОКУСОМ
# ═══════════════════════════════════════════════════════════════════════════

func _on_focus_activated(target: String) -> void:
	"""Обработчик активации элемента через клавиатурный фокус - делегировано в KeyboardFocusHandler
	
	Args:
		target: Имя активированного элемента
	"""
	if keyboard_focus_handler:
		keyboard_focus_handler.on_focus_activated(target)
	else:
		push_error("❌ KeyboardFocusHandler не инициализирован!")

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ГЕЙМПАДА
# ═══════════════════════════════════════════════════════════════════════════

func _check_gamepad_connection() -> void:
	"""Проверить подключение геймпадов - делегировано в GamepadMonitor"""
	if gamepad_monitor:
		gamepad_monitor.check_connection()
	else:
		push_error("❌ GamepadMonitor не инициализирован!")

func _process(_delta: float) -> void:
	"""Проверка изменения подключения геймпадов - делегировано в GamepadMonitor"""
	if gamepad_monitor:
		gamepad_monitor.process(_delta)
	_update_tournament_countdown_if_needed()

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ UI - СЧЕТЧИК РАУНДОВ
# ═══════════════════════════════════════════════════════════════════════════

func _on_round_started() -> void:
	"""Обработчик начала новой раздачи - делегировано в RoundsCounterUpdater"""
	survival_rounds_completed += 1
	if rounds_counter_updater:
		rounds_counter_updater.on_round_started()
	_update_tournament_info_panel()
	DebugLogger.log("🎮 Началась раздача #%d" % survival_rounds_completed)

func _update_rounds_counter() -> void:
	"""Обновить отображение счетчика раздач - делегировано в RoundsCounterUpdater"""
	if rounds_counter_updater:
		rounds_counter_updater.update_counter()

func _refresh_top_bar_texts(_lang: String = "") -> void:
	"""Обновить тексты верхней панели под текущий язык."""
	var help_button_node: Button = find_child("HelpButton", true, false) as Button
	if help_button_node:
		help_button_node.text = Localization.t("TOPBAR_HELP")

	var top_settings_button: Button = settings_button if settings_button else find_child("SettingsButton", true, false) as Button
	if top_settings_button:
		top_settings_button.text = Localization.t("TOPBAR_SETTINGS")

	_update_rounds_counter()
	_update_tournament_info_panel()

	if StatsManager.instance:
		StatsManager.instance.update_stats()


func _update_tournament_info_panel() -> void:
	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	if sm == null:
		_last_tournament_remaining_seconds = -1
		if tournament_info_panel:
			tournament_info_panel.visible = false
		return

	if sm.get("current_mode") != sm.Mode.TOURNAMENT:
		_last_tournament_remaining_seconds = -1
		if tournament_info_panel:
			tournament_info_panel.visible = false
		return

	if tournament_info_panel:
		tournament_info_panel.visible = true

	var title_text: String = str(sm.get("tournament_title")).strip_edges()
	var code_text: String = str(sm.get("tournament_code")).strip_edges()
	var participant_text: String = str(sm.get("tournament_participant_display_name")).strip_edges()
	var rounds_completed: int = int(sm.get("tournament_rounds_completed"))
	var finish_settings: Dictionary = _get_tournament_finish_settings(sm)
	var max_rounds: int = _tournament_finish_limit_value(finish_settings, "max_rounds")
	var attempt_duration_seconds: int = _tournament_finish_limit_value(finish_settings, "max_duration_seconds")
	var attempt_started_at: float = float(sm.get("tournament_attempt_started_at"))
	var elapsed_seconds: int = 0
	if attempt_started_at > 0.0:
		elapsed_seconds = int(max((Time.get_ticks_msec() / 1000.0) - attempt_started_at, 0.0))
	var has_time_limit: bool = _tournament_finish_has_limit(finish_settings, "time_limit")
	var has_round_limit: bool = _tournament_finish_has_limit(finish_settings, "round_limit")
	var has_error_limit: bool = _tournament_finish_has_limit(finish_settings, "error_limit")
	var max_errors: int = _tournament_finish_limit_value(finish_settings, "max_errors")
	var errors_total: int = int(sm.get("tournament_errors_total"))
	var remaining_seconds: int = max(attempt_duration_seconds - elapsed_seconds, 0) if has_time_limit else 0
	_last_tournament_remaining_seconds = remaining_seconds

	if title_text.is_empty():
		title_text = code_text
	if participant_text.is_empty():
		participant_text = "—"

	if tournament_title_label:
		tournament_title_label.text = "ТУРНИР"
		if not title_text.is_empty():
			tournament_title_label.text = "ТУРНИР · %s" % title_text
	if tournament_participant_label:
		tournament_participant_label.text = "Игрок: %s" % participant_text
	if tournament_rounds_label:
		tournament_rounds_label.text = "Раздачи %d / %d" % [rounds_completed, max_rounds] if has_round_limit else "Раздачи %d" % rounds_completed
	if tournament_time_label:
		tournament_time_label.text = "Осталось %s" % _format_duration_mmss(remaining_seconds) if has_time_limit else "Время без лимита"
	if tournament_errors_label:
		if has_error_limit and max_errors > 0:
			tournament_errors_label.visible = true
			tournament_errors_label.text = "Ошибки: %d / %d" % [errors_total, max_errors]
		else:
			tournament_errors_label.visible = false


func _format_duration_mmss(total_seconds: int) -> String:
	var clamped_seconds: int = max(total_seconds, 0)
	var minutes: int = int(floor(float(clamped_seconds) / 60.0))
	var seconds: int = clamped_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _connect_tournament_runtime_signals() -> void:
	var sm: Variant = get_node_or_null("/root/SessionManager")
	if sm == null:
		return
	if sm.has_signal("tournament_error_count_changed") and not sm.tournament_error_count_changed.is_connected(_on_tournament_error_count_changed):
		sm.tournament_error_count_changed.connect(_on_tournament_error_count_changed)


func _disconnect_tournament_runtime_signals() -> void:
	var sm: Variant = get_node_or_null("/root/SessionManager")
	if sm == null:
		return
	if sm.has_signal("tournament_error_count_changed") and sm.tournament_error_count_changed.is_connected(_on_tournament_error_count_changed):
		sm.tournament_error_count_changed.disconnect(_on_tournament_error_count_changed)


func _get_tournament_finish_settings(sm: Variant = null) -> Dictionary:
	var session_manager: Variant = sm
	if session_manager == null:
		if Engine.has_singleton("SessionManager"):
			session_manager = Engine.get_singleton("SessionManager")
		else:
			session_manager = get_node_or_null("/root/SessionManager")
	if session_manager == null:
		return {}
	if not session_manager.has_method("get_normalized_tournament_finish_settings"):
		return {}
	var settings_variant: Variant = session_manager.get_normalized_tournament_finish_settings()
	return settings_variant if settings_variant is Dictionary else {}


func _tournament_finish_has_limit(finish_settings: Dictionary, limit_name: String) -> bool:
	var active_limits_variant: Variant = _dict_value(finish_settings, "active_limits", [])
	if not (active_limits_variant is Array):
		return false
	for item in active_limits_variant:
		if str(item) == limit_name:
			return true
	return false


func _tournament_finish_limit_value(finish_settings: Dictionary, key: String) -> int:
	var value: Variant = _dict_value(finish_settings, key, null)
	if value is int:
		return max(int(value), 0)
	return 0


func _update_tournament_countdown_if_needed() -> void:
	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	if sm == null:
		return
	if sm.get("current_mode") != sm.Mode.TOURNAMENT:
		return
	if bool(sm.get("tournament_attempt_finished")):
		return

	var finish_settings: Dictionary = _get_tournament_finish_settings(sm)
	if not _tournament_finish_has_limit(finish_settings, "time_limit"):
		return
	var attempt_duration_seconds: int = _tournament_finish_limit_value(finish_settings, "max_duration_seconds")
	if attempt_duration_seconds <= 0:
		return
	var attempt_started_at: float = float(sm.get("tournament_attempt_started_at"))
	if attempt_started_at <= 0.0:
		return

	var elapsed_seconds: int = int(max((Time.get_ticks_msec() / 1000.0) - attempt_started_at, 0.0))
	var remaining_seconds: int = max(attempt_duration_seconds - elapsed_seconds, 0)
	if remaining_seconds <= 0:
		_finish_tournament_attempt("time_limit")
		return
	if remaining_seconds == _last_tournament_remaining_seconds:
		return

	_update_tournament_info_panel()


func _on_tournament_round_completed() -> void:
	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	if sm == null:
		return
	if sm.get("current_mode") != sm.Mode.TOURNAMENT:
		return
	if bool(sm.get("tournament_attempt_finished")):
		return
	if not sm.has_method("mark_tournament_round_completed"):
		return

	sm.mark_tournament_round_completed()
	_update_tournament_info_panel()

	var finish_settings: Dictionary = _get_tournament_finish_settings(sm)
	if not _tournament_finish_has_limit(finish_settings, "round_limit"):
		return
	var rounds_completed: int = int(sm.get("tournament_rounds_completed"))
	var max_rounds: int = _tournament_finish_limit_value(finish_settings, "max_rounds")
	if max_rounds > 0 and rounds_completed >= max_rounds:
		_finish_tournament_attempt("round_limit")


func _on_tournament_error_count_changed(total_errors: int) -> void:
	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	if sm == null:
		return
	if sm.get("current_mode") != sm.Mode.TOURNAMENT:
		return
	if bool(sm.get("tournament_attempt_finished")):
		return

	var finish_settings: Dictionary = _get_tournament_finish_settings(sm)
	if not _tournament_finish_has_limit(finish_settings, "error_limit"):
		_update_tournament_info_panel()
		return
	var max_errors: int = _tournament_finish_limit_value(finish_settings, "max_errors")
	_update_tournament_info_panel()
	if max_errors > 0 and total_errors >= max_errors:
		_finish_tournament_attempt("error_limit")


func _finish_tournament_attempt(reason: String) -> void:
	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	if sm == null:
		return
	if sm.get("current_mode") != sm.Mode.TOURNAMENT:
		return
	if bool(sm.get("tournament_attempt_finished")):
		return
	if not sm.has_method("finish_tournament_attempt"):
		return

	var payload: Dictionary = _build_tournament_attempt_payload(reason)
	if payout_overlay and payout_overlay.visible:
		if payout_overlay.has_method("force_close_for_tournament_finish"):
			payout_overlay.force_close_for_tournament_finish()
		else:
			payout_overlay.hide()
	sm.finish_tournament_attempt(reason)
	if sm.has_method("save_tournament_attempt_payload"):
		sm.save_tournament_attempt_payload(payload)
	_update_tournament_info_panel()
	_show_tournament_finish_overlay(reason)
	_submit_tournament_attempt_async.call_deferred()

	var input_context_manager: Variant = null
	if Engine.has_singleton("InputContextManager"):
		input_context_manager = Engine.get_singleton("InputContextManager")
	else:
		input_context_manager = get_node_or_null("/root/InputContextManager")
	if input_context_manager != null and input_context_manager.has_method("set_global_block"):
		input_context_manager.set_global_block(true)


func _show_tournament_finish_overlay(reason: String) -> void:
	if not tournament_finish_overlay:
		return

	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	var rounds_completed: int = 0
	var max_rounds: int = 0
	var errors_total: int = 0
	var remaining_seconds: int = 0
	if sm != null:
		rounds_completed = int(sm.get("tournament_rounds_completed"))
		max_rounds = int(sm.get("tournament_max_rounds"))
		errors_total = int(sm.get("tournament_errors_total"))
		var attempt_duration_seconds: int = int(sm.get("tournament_attempt_duration_seconds"))
		var attempt_started_at: float = float(sm.get("tournament_attempt_started_at"))
		if reason == "time_limit":
			remaining_seconds = 0
		elif attempt_started_at > 0.0:
			var elapsed_seconds: int = int(max((Time.get_ticks_msec() / 1000.0) - attempt_started_at, 0.0))
			remaining_seconds = max(attempt_duration_seconds - elapsed_seconds, 0)
		else:
			remaining_seconds = max(attempt_duration_seconds, 0)

	_set_tournament_finish_overlay_state({
		"title": "Турнир завершён",
		"note": "Отправляем результат...",
		"place_text": "— место",
		"errors_value": str(errors_total),
		"time_value": _format_duration_mmss(remaining_seconds),
		"rounds_value": "%d / %d" % [rounds_completed, max_rounds],
		"menu_enabled": false,
		"menu_text": "Выйти",
		"retry_enabled": false,
		"retry_text": "Ещё раз",
	})

	tournament_finish_overlay.visible = true


func _set_tournament_finish_overlay_state(state: Dictionary) -> void:
	if tournament_finish_title_label:
		tournament_finish_title_label.text = str(_dict_value(state, "title", "Турнир завершён"))
	if tournament_finish_reason_label:
		var note_text: String = str(_dict_value(state, "note", "")).strip_edges()
		tournament_finish_reason_label.visible = not note_text.is_empty()
		tournament_finish_reason_label.text = note_text
	if tournament_finish_status_label:
		tournament_finish_status_label.visible = false
		tournament_finish_status_label.text = ""
	if tournament_finish_rank_label:
		tournament_finish_rank_label.text = str(_dict_value(state, "place_text", "— место"))
	if tournament_finish_errors_label:
		tournament_finish_errors_label.text = str(_dict_value(state, "errors_value", "0"))
	if tournament_finish_time_label:
		tournament_finish_time_label.text = str(_dict_value(state, "time_value", "00:00"))
	if tournament_finish_rounds_label:
		tournament_finish_rounds_label.text = str(_dict_value(state, "rounds_value", "0 / 0"))
	if tournament_finish_retry_btn:
		tournament_finish_retry_btn.visible = true
		tournament_finish_retry_btn.disabled = not bool(_dict_value(state, "retry_enabled", false))
		tournament_finish_retry_btn.text = str(_dict_value(state, "retry_text", "Ещё раз"))
	if tournament_finish_menu_btn:
		tournament_finish_menu_btn.disabled = not bool(_dict_value(state, "menu_enabled", false))
		tournament_finish_menu_btn.text = str(_dict_value(state, "menu_text", "Выйти"))


func _build_tournament_attempt_payload(finish_reason: String = "") -> Dictionary:
	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	if sm == null or sm.get("current_mode") != sm.Mode.TOURNAMENT:
		return {}

	var finish_settings: Dictionary = _get_tournament_finish_settings(sm)
	var attempt_started_at: float = float(sm.get("tournament_attempt_started_at"))
	var time_spent_seconds: int = 0
	if attempt_started_at > 0.0:
		time_spent_seconds = int(max((Time.get_ticks_msec() / 1000.0) - attempt_started_at, 0.0))

	return {
		"tournament_id": str(_node_prop(sm, "tournament_id", "")).strip_edges(),
		"participant_token": str(_node_prop(sm, "tournament_participant_token", "")).strip_edges(),
		"rounds_completed": int(_node_prop(sm, "tournament_rounds_completed", 0)),
		"errors_total": int(_node_prop(sm, "tournament_errors_total", 0)),
		"time_spent_seconds": time_spent_seconds,
		"finish_reason": finish_reason if not finish_reason.strip_edges().is_empty() else str(_node_prop(sm, "tournament_finish_reason", "")).strip_edges(),
		"max_rounds": _tournament_finish_limit_value(finish_settings, "max_rounds"),
	}


func _get_api_service() -> Variant:
	if Engine.has_singleton("ApiService"):
		return Engine.get_singleton("ApiService")
	return get_node_or_null("/root/ApiService")


func _submit_tournament_attempt_async(force_retry: bool = false) -> void:
	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	if sm == null:
		return
	if sm.get("current_mode") != sm.Mode.TOURNAMENT:
		return
	if force_retry:
		if not sm.has_method("reset_tournament_submit_state_for_retry"):
			return
		if not sm.reset_tournament_submit_state_for_retry():
			return
	if not sm.has_method("start_tournament_submit"):
		return
	if not sm.start_tournament_submit():
		return

	var payload: Dictionary = {}
	if sm.has_method("get_tournament_attempt_payload"):
		payload = sm.get_tournament_attempt_payload()
	if payload.is_empty():
		if sm.has_method("complete_tournament_submit"):
			sm.complete_tournament_submit(false)
		if sm.has_method("set_tournament_submit_error"):
			sm.set_tournament_submit_error("Нет данных попытки для отправки")
		var empty_payload_time: int = 0
		_set_tournament_finish_overlay_state({
			"title": "Турнир завершён",
			"note": "Не удалось отправить результат",
			"place_text": "— место",
			"errors_value": str(int(_node_prop(sm, "tournament_errors_total", 0))),
			"time_value": _format_duration_mmss(empty_payload_time),
			"rounds_value": "%d / %d" % [int(_node_prop(sm, "tournament_rounds_completed", 0)), int(_node_prop(sm, "tournament_max_rounds", 0))],
			"menu_enabled": true,
			"menu_text": "Выйти",
			"retry_enabled": false,
			"retry_text": "Ещё раз",
		})
		return

	var api_service: Variant = _get_api_service()
	if api_service == null or not api_service.has_method("submit_tournament_attempt"):
		if sm.has_method("complete_tournament_submit"):
			sm.complete_tournament_submit(false)
		var api_error_text: String = "ApiService недоступен"
		if sm.has_method("set_tournament_submit_error"):
			sm.set_tournament_submit_error(api_error_text)
		_set_tournament_finish_overlay_state({
			"title": "Турнир завершён",
			"note": api_error_text,
			"place_text": "— место",
			"errors_value": str(int(_dict_value(payload, "errors_total", 0))),
			"time_value": _format_duration_mmss(int(_dict_value(payload, "time_spent_seconds", 0))),
			"rounds_value": "%d / %d" % [int(_dict_value(payload, "rounds_completed", 0)), int(_dict_value(payload, "max_rounds", 0))],
			"menu_enabled": true,
			"menu_text": "Выйти",
			"retry_enabled": false,
			"retry_text": "Ещё раз",
		})
		return

	_set_tournament_finish_overlay_state({
		"title": "Турнир завершён",
		"note": "Отправляем результат...",
		"place_text": "— место",
		"errors_value": str(int(_dict_value(payload, "errors_total", 0))),
		"time_value": _format_duration_mmss(int(_dict_value(payload, "time_spent_seconds", 0))),
		"rounds_value": "%d / %d" % [int(_dict_value(payload, "rounds_completed", 0)), int(_dict_value(payload, "max_rounds", 0))],
		"menu_enabled": false,
		"menu_text": "Выйти",
		"retry_enabled": false,
		"retry_text": "Ещё раз",
	})

	var response: Dictionary = await api_service.submit_tournament_attempt(
		str(_dict_value(payload, "tournament_id", "")),
		str(_dict_value(payload, "participant_token", "")),
		str(_dict_value(payload, "finish_reason", "")),
		int(_dict_value(payload, "rounds_completed", 0)),
		int(_dict_value(payload, "errors_total", 0)),
		int(_dict_value(payload, "time_spent_seconds", 0))
	)

	var response_code: int = int(_dict_value(response, "code", 0))
	var response_body_variant: Variant = _dict_value(response, "body", {})
	var response_body: Dictionary = response_body_variant if response_body_variant is Dictionary else {}
	if response_code >= 200 and response_code < 300:
		if sm.has_method("complete_tournament_submit"):
			sm.complete_tournament_submit(true)
		if sm.has_method("save_tournament_submit_response"):
			sm.save_tournament_submit_response(response_body)
		var rank_text: String = ""
		if response_body.has("rank") and response_body["rank"] != null:
			rank_text = "%d место" % int(response_body["rank"])
		else:
			rank_text = "— место"
		_set_tournament_finish_overlay_state({
			"title": "Турнир завершён",
			"note": "",
			"place_text": rank_text,
			"errors_value": str(int(_dict_value(payload, "errors_total", 0))),
			"time_value": _format_duration_mmss(int(_dict_value(payload, "time_spent_seconds", 0))),
			"rounds_value": "%d / %d" % [int(_dict_value(payload, "rounds_completed", 0)), int(_dict_value(payload, "max_rounds", 0))],
			"menu_enabled": true,
			"menu_text": "Выйти",
			"retry_enabled": true,
			"retry_text": "Ещё раз",
		})
	else:
		if sm.has_method("complete_tournament_submit"):
			sm.complete_tournament_submit(false)
		var error_text: String = "Не удалось отправить результат"
		var detail: Variant = _dict_value(response_body, "detail", "")
		if detail is String and not str(detail).strip_edges().is_empty():
			error_text = str(detail).strip_edges()
		elif detail is Dictionary:
			var detail_dict: Dictionary = detail as Dictionary
			var message_text: String = str(_dict_value(detail_dict, "message", "")).strip_edges()
			if not message_text.is_empty():
				error_text = message_text
		if sm.has_method("set_tournament_submit_error"):
			sm.set_tournament_submit_error(error_text)
		_set_tournament_finish_overlay_state({
			"title": "Турнир завершён",
			"note": error_text,
			"place_text": "— место",
			"errors_value": str(int(_dict_value(payload, "errors_total", 0))),
			"time_value": _format_duration_mmss(int(_dict_value(payload, "time_spent_seconds", 0))),
			"rounds_value": "%d / %d" % [int(_dict_value(payload, "rounds_completed", 0)), int(_dict_value(payload, "max_rounds", 0))],
			"menu_enabled": true,
			"menu_text": "Выйти",
			"retry_enabled": false,
			"retry_text": "Ещё раз",
		})


func _format_tournament_finish_reason(reason: String) -> String:
	match reason:
		"round_limit":
			return "Лимит раздач достигнут"
		"time_limit":
			return "Время вышло"
		"error_limit":
			return "Лимит ошибок достигнут"
		_:
			return "Попытка завершена"


func _on_tournament_retry_submit_pressed() -> void:
	var input_context_manager: Variant = null
	if Engine.has_singleton("InputContextManager"):
		input_context_manager = Engine.get_singleton("InputContextManager")
	else:
		input_context_manager = get_node_or_null("/root/InputContextManager")
	if input_context_manager != null and input_context_manager.has_method("set_global_block"):
		input_context_manager.set_global_block(false)

	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")
	if sm == null:
		DebugLogger.log_warning("⚠️ TournamentFinishOverlay: SessionManager не найден для старта новой попытки")
		return

	var is_tournament: bool = false
	if sm.get("current_mode") == sm.Mode.TOURNAMENT:
		is_tournament = true
	if not is_tournament:
		DebugLogger.log_warning("⚠️ TournamentFinishOverlay: кнопка 'Ещё раз' вызвана вне tournament mode")
		return

	var access_record: Dictionary = _get_current_tournament_access_record(sm)
	if access_record.is_empty():
		var tournament_id: String = str(_node_prop(sm, "tournament_id", "")).strip_edges()
		DebugLogger.log_warning("⚠️ TournamentFinishOverlay: access_record не найден для tournament_id=%s" % tournament_id)
		return
	if not sm.has_method("start_tournament_session"):
		DebugLogger.log_warning("⚠️ TournamentFinishOverlay: start_tournament_session недоступен")
		return

	sm.call("start_tournament_session", access_record)
	if get_tree():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _compose_tournament_submit_failure_reason(base_reason: String, error_text: String) -> String:
	var normalized_reason := base_reason.strip_edges()
	var normalized_error := error_text.strip_edges()
	if normalized_error.is_empty():
		return normalized_reason
	if normalized_reason.is_empty():
		return normalized_error
	return "%s\n%s" % [normalized_reason, normalized_error]


func _dict_value(source: Dictionary, key: String, fallback: Variant) -> Variant:
	if source.has(key):
		return source[key]
	return fallback


func _node_prop(node: Variant, key: String, fallback: Variant) -> Variant:
	if node == null:
		return fallback
	var value: Variant = node.get(key)
	if value == null:
		return fallback
	return value


func _get_current_tournament_access_record(sm: Variant) -> Dictionary:
	if sm == null:
		return {}

	var tournament_id: String = str(_node_prop(sm, "tournament_id", "")).strip_edges()
	if tournament_id.is_empty():
		return {}

	var access_store: Variant = TournamentAccessStoreScript.new()
	if access_store == null or not access_store.has_method("get_access_by_tournament_id"):
		return {}

	var access_variant: Variant = access_store.call("get_access_by_tournament_id", tournament_id)
	if access_variant is Dictionary:
		return (access_variant as Dictionary).duplicate(true)
	return {}


func _on_tournament_finish_menu_pressed() -> void:
	var input_context_manager: Variant = null
	if Engine.has_singleton("InputContextManager"):
		input_context_manager = Engine.get_singleton("InputContextManager")
	else:
		input_context_manager = get_node_or_null("/root/InputContextManager")
	if input_context_manager != null and input_context_manager.has_method("set_global_block"):
		input_context_manager.set_global_block(false)

	var sm: Variant = null
	if Engine.has_singleton("SessionManager"):
		sm = Engine.get_singleton("SessionManager")
	else:
		sm = get_node_or_null("/root/SessionManager")

	var is_tournament: bool = false
	if sm != null and sm.get("current_mode") == sm.Mode.TOURNAMENT:
		is_tournament = true

	if is_tournament:
		var tournament_id: String = str(_node_prop(sm, "tournament_id", "")).strip_edges()
		var access_record: Dictionary = _get_current_tournament_access_record(sm)

		if not access_record.is_empty():
			var navigation_store: Variant = TournamentNavigationStoreScript.new()
			var pending_saved: bool = false
			if navigation_store != null and navigation_store.has_method("save_pending_access"):
				var saved_variant: Variant = navigation_store.call(
					"save_pending_access",
					access_record,
					"res://scenes/network/MyTournamentsScreen.tscn"
				)
				pending_saved = bool(saved_variant)

			if pending_saved:
				if sm != null and sm.has_method("end_session"):
					sm.end_session()
				get_tree().change_scene_to_file(TOURNAMENT_DETAILS_SCENE_PATH)
				return

			DebugLogger.log_warning("⚠️ TournamentFinishOverlay: не удалось сохранить pending access для перехода к турниру")
		else:
			DebugLogger.log_warning("⚠️ TournamentFinishOverlay: access_record не найден для tournament_id=%s" % tournament_id)

	if sm != null and sm.has_method("end_session"):
		sm.end_session()

	get_tree().change_scene_to_file(START_SCREEN_SCENE_PATH)
