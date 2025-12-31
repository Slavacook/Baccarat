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

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ИГРЫ
# ═══════════════════════════════════════════════════════════════════════════

var survival_rounds_completed: int = 0
# is_survival_mode удалён - режим всегда активен (не нужна проверка)
var is_table_prepared_for_new_game: bool = false
var is_payout_processing: bool = false  # Флаг обработки выплаты (защита от спама Space)

# Переменная для отложенной смены режима (аналогично pending_filter_changes)
var pending_mode_change: String = ""  # "junket" или "classic", пустая = нет отложенной смены

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
	add_to_group("game_controller")
	
	# Инициализация через GameInitializer (все ~200 строк вынесены в отдельный класс)
	var initialized: Dictionary = GameInitializer.initialize(self)
	
	# Проверка подключения геймпадов (после инициализации, чтобы DebugLogger был готов)
	_check_gamepad_connection()

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

	# Подсветка областей: подписываемся на завершение зума камеры
	if camera_manager:
		camera_manager.zoom_completed.connect(_on_camera_zoom_completed)
		_update_area_highlights(0)  # скрыть все подсветки на старте

	# Реакция на запрос зума: подсвечиваем целевую область сразу при нажатии
	if EventBus:
		EventBus.camera_zoom_requested.connect(_on_camera_zoom_requested)
		
		# Heart Bet: скрытие/показ ставок гостей
		# Сигналы guest_bets_hide_requested и guest_bets_show_requested
		# перенесены в GuestEventHandler (подключаются в _connect_guest_signals())
		# Сигналы heart_bet_show_ui, heart_bet_declined, heart_bet_round_complete
		# перенесены в HeartBetController (подключаются в _connect_heart_bet_signals())
		
		# Настройки: включаем action_button при закрытии
		EventBus.settings_closed.connect(_on_settings_closed)
		
		# Начало новой раздачи: увеличиваем счетчик раздач
		EventBus.round_started.connect(_on_round_started)
		
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
	
	# Активируем режим выживания (всегда активен)
	if survival_state:
		survival_state.activate()
	
	# Передаём heart_bar в ChanceCardManager после инициализации (если он был инициализирован)
	if heart_bar:
		ChanceCardManager.set_heart_bar(heart_bar)
		print("🎴 HeartBar передан в ChanceCardManager (после инициализации)")
	
	# Инициализируем счетчик раздач
	_update_rounds_counter()
	
	# Инициализируем менеджер индикаторов терпения и баланса гостей
	_setup_patience_indicators()
	
	# Инициализируем шпаргалку
	_initialize_crib_sheet()
	
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

## Инициализировать HeartBar из survival_ui
func _initialize_heart_bar() -> void:
	if survival_ui and "heart_bar" in survival_ui and survival_ui.heart_bar != null:
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
	
	# Сигналы от EventBus для Heart Bet
	EventBus.guest_bets_hide_requested.connect(guest_event_handler.handle_guest_bets_hide_requested)
	EventBus.guest_bets_show_requested.connect(guest_event_handler.handle_guest_bets_show_requested)
	
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

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ - ВЫНЕСЕНА В GameInitializer.gd (Task 2.1)
# ═══════════════════════════════════════════════════════════════════════════
# Все helper методы инициализации перенесены в GameInitializer.initialize()
# Удалено ~235 строк дублирующего кода

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КАРТАМИ (делегировано в CardController)
# ═══════════════════════════════════════════════════════════════════════════

func set_flip_cards(cards):
	"""Установить массив анимаций переворота карт (для обратной совместимости)"""
	flip_cards = cards
	if card_controller:
		card_controller.set_flip_cards(cards)

func show_all_backs(back_texture: Texture2D):
	"""Показать рубашки всех карт (делегировано в CardController)"""
	if card_controller:
		card_controller.show_all_backs(back_texture)

func open_all_cards(face_textures: Array, delay: float = 0.3):
	"""Открыть все карты с задержкой (делегировано в CardController)"""
	if card_controller:
		await card_controller.open_all_cards(face_textures, delay)

func open_all_cards_with_flip(face_textures: Array, delay: float = 0.3):
	"""Открыть все карты с flip-анимацией (делегировано в CardController)"""
	if card_controller:
		await card_controller.open_all_cards_with_flip(face_textures, delay)

func open_two_third_cards(texture1: Texture2D, texture2: Texture2D):
	"""Открыть две третьи карты (делегировано в CardController)"""
	if card_controller:
		card_controller.open_two_third_cards(texture1, texture2)

func reset_cards(back_texture: Texture2D):
	"""Сбросить все карты (делегировано в CardController)"""
	if card_controller:
		card_controller.reset_cards(back_texture)


func _on_winner_selected(chosen: String):
	"""Обработка выбора победителя игроком (делегировано в WinnerSelectionHandler)"""
	if winner_selection_handler:
		await winner_selection_handler.handle_winner_selected(chosen)


# ═══════════════════════════════════════════════════════════════════════════
# ВЫБОР ПОБЕДИТЕЛЯ - ДЕЛЕГИРОВАНО В WinnerSelectionHandler
# ═══════════════════════════════════════════════════════════════════════════


func _process_payout_queue_or_reset() -> void:
	"""Обработка очереди выплат или сброс раунда (если очередь пуста) - делегировано в PayoutQueueHandler"""
	if payout_queue_handler:
		payout_queue_handler.process_payout_queue_or_reset(get_tree())
	else:
		push_error("❌ PayoutQueueHandler не инициализирован!")



func _format_result() -> String:
	var p0 = BaccaratRules.hand_value([hand_manager.get_player_hand_ref()[0], hand_manager.get_player_hand_ref()[1]])
	var b0 = BaccaratRules.hand_value([hand_manager.get_banker_hand_ref()[0], hand_manager.get_banker_hand_ref()[1]])
	if p0 >= 8 or b0 >= 8:
		return "Натуральная %d против %d" % [p0 if p0 >= 8 else b0, b0 if p0 >= 8 else p0]
	return "%d против %d" % [BaccaratRules.hand_value(hand_manager.get_banker_hand_ref()), BaccaratRules.hand_value(hand_manager.get_player_hand_ref())]

func _format_victory_toast(winner: String) -> String:
	"""Форматирование краткого тоста победы (например, 'Выигрывает Банкир: 7 vs 5')"""
	var player_score = BaccaratRules.hand_value(hand_manager.get_player_hand_ref())
	var banker_score = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())

	match winner:
		"Banker":
			return Localization.t("VICTORY_BANKER", [banker_score, player_score])
		"Player":
			return Localization.t("VICTORY_PLAYER", [player_score, banker_score])
		"Tie":
			return Localization.t("VICTORY_TIE")  # Без параметров
		_:
			return "???"

# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ РЕЖИМ ВЫПЛАТ (новая логика)
# ═══════════════════════════════════════════════════════════════════════════

func _prepare_payouts_manual(actual_winner: String) -> void:
	"""Подготовка выплат в ручном режиме (без автоматического перехода к сцене) - делегировано в PayoutQueueHandler"""
	if payout_queue_handler:
		payout_queue_handler.prepare_payouts_manual(actual_winner)
		# Обновляем ссылку на payout_queue_manager после создания нового
		if payout_queue_handler.payout_queue_manager:
			payout_queue_manager = payout_queue_handler.payout_queue_manager
	else:
		push_error("❌ PayoutQueueHandler не инициализирован!")


# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ _prepare_payouts_standard и _prepare_payouts_realistic ПЕРЕНЕСЕНЫ
# В PayoutManager для соблюдения SRP
# ═══════════════════════════════════════════════════════════════════════════


func _generate_stake_for_bet_type(bet_type: String) -> float:
	"""Генерация размера ставки для типа
	
	Рефакторено: использует IBetType вместо match (OCP)
	"""
	var bet_type_obj = BetTypeFactory.create(bet_type)
	if not bet_type_obj:
		return 0.0
	return bet_type_obj.get_stake(limits_manager)


func _calculate_payout_for_bet_type(bet_type: String, stake: float, won: bool) -> float:
	"""Расчёт выплаты для типа ставки
	
	Рефакторено: использует PayoutCalculator вместо match (OCP, SRP)
	"""
	if not won:
		return 0.0
	
	var bet_type_obj = BetTypeFactory.create(bet_type)
	if not bet_type_obj:
		return 0.0
	
	var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	var payout_calculator = PayoutCalculator.new()
	
	# Для пар используем специальную логику
	if bet_type_obj.get_group() == "pairs" and pair_betting_manager:
		return payout_calculator.calculate_pair_payout(bet_type_obj, stake, pair_betting_manager)
	
	# Для остальных используем стандартный расчет
	# actual_winner нужен для проверки is_winner, но здесь мы уже знаем что won=true
	var actual_winner = "Player"  # Значение не важно, т.к. won уже проверен
	return payout_calculator.calculate(
		bet_type_obj,
				stake, 
		actual_winner,
		pair_betting_manager.has_player_pair() if pair_betting_manager else false,
		pair_betting_manager.has_banker_pair() if pair_betting_manager else false,
		banker_value
	)


func _finalize_payouts_manual(actual_winner: String) -> void:
	"""Завершение подготовки выплат - обновление видимости и сохранение состояния - делегировано в PayoutQueueHandler"""
	if payout_queue_handler:
		payout_queue_handler.finalize_payouts_manual(actual_winner)
	else:
		push_error("❌ PayoutQueueHandler не инициализирован!")


func _update_chip_visibility() -> void:
	"""Обновить видимость и кликабельность фишек через ChipVisualManager - делегировано в PayoutQueueHandler"""
	if payout_queue_handler:
		payout_queue_handler.update_chip_visibility()
	else:
		push_error("❌ PayoutQueueHandler не инициализирован!")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ UI СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_help_button_pressed():
	# Открываем шпаргалку вместо старого help_popup
	if crib_sheet_scene:
		# Сбрасываем фокус с кнопки, чтобы пробел не активировал её
		if ui_manager.help_button:
			ui_manager.help_button.release_focus()
		# Также сбрасываем фокус со всего viewport
		if get_viewport():
			get_viewport().gui_release_focus()
		crib_sheet_scene.show_cribsheet()
	else:
		push_warning("CribSheetScene: шпаргалка не инициализирована")

func _on_lang_button_pressed():
	var new_lang = "en" if Localization.get_lang() == "ru" else "ru"
	Localization.set_lang(new_lang)
	ui_manager.update_lang_button()
	ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	# Обновление toggles третьих карт (если видимы)
	if ui_manager.player_third_toggle.visible:
		var state = "!" if phase_manager.player_third_selected else "?"
		ui_manager.update_player_third_card_ui(state)
	if ui_manager.banker_third_toggle.visible:
		var state = "!" if phase_manager.banker_third_selected else "?"
		ui_manager.update_banker_third_card_ui(state)
	# Обновление текста кнопок collect/pay
	ui_manager.button_ui.update_collect_pay_buttons_text()

func _on_payout_confirmed(is_correct: bool, collected: float, expected: float):
	if is_correct:
		# Для старого метода нет информации о bet_type/position_index
		# Передаем пустые значения - StatsManager пропустит такие случаи
		EventBus.payout_correct.emit(collected, expected, "", -1)
		DebugLogger.log("✅ Правильно! Выплата: %s" % expected)
		# ВАЖНО: Счетчик раздач НЕ увеличивается здесь - он увеличивается при открытии первых 4 карт
	else:
		# Для старого метода нет информации о bet_type/position_index
		EventBus.payout_wrong.emit(collected, expected, "", -1)
		DebugLogger.log("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])
		# ← Жизни отнимаются в PayoutScene, здесь ничего не делаем
	if is_correct:
		phase_manager.reset()

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
	"""Обработка ввода (клавиатура и геймпад) - используем _input для перехвата раньше"""
	# Переключение режима навигации по картам (C/кнопка 4) - обрабатываем в _input для раннего перехвата
	if event.is_action_pressed("chance_cards"):
		# Проверяем блокировки
		if InputContextManager.is_blocked():
			return
		# Проверяем контекст GAME или CHANCE_CARDS_NAV для переключения режима
		var current_context = InputContextManager.get_context()
		if current_context == InputContextManager.InputContext.GAME or \
		   current_context == InputContextManager.InputContext.CHANCE_CARDS_NAV:
			if chance_card_navigator:
				if chance_card_navigator.is_active:
					chance_card_navigator.deactivate()
				else:
					chance_card_navigator.activate()
				get_viewport().set_input_as_handled()
				return
	
	# Обработка навигации по картам - обрабатываем в _input для раннего перехвата
	if chance_card_navigator and chance_card_navigator.is_active:
		# Проверяем контекст для навигации по картам
		if not InputContextManager.is_blocked():
			var current_context = InputContextManager.get_context()
			if current_context == InputContextManager.InputContext.CHANCE_CARDS_NAV:
				if chance_card_navigator.handle_input(event):
					get_viewport().set_input_as_handled()
					return
	
	# Обрабатываем только toggle_navigation здесь, остальное в _unhandled_input
	# В _input() используем event.is_action_pressed() для проверки конкретного события
	if event.is_action_pressed("toggle_navigation"):
		# Проверяем блокировки
		if InputContextManager.is_blocked():
			return
		if not InputContextManager.can_handle(InputContextManager.InputContext.GAME):
			return
		
		# toggle_navigation → включить/выключить навигацию по ставкам
		if chip_navigation_manager:
			if chip_navigation_manager.is_active:
				chip_navigation_manager.deactivate()
			else:
				chip_navigation_manager.activate()
			get_viewport().set_input_as_handled()
			return
		else:
			DebugLogger.log_error("❌ chip_navigation_manager не инициализирован!")
			get_viewport().set_input_as_handled()
			return

func _unhandled_input(event: InputEvent) -> void:
	"""Обработка ввода (клавиатура и геймпад)"""
	# Проверяем блокировки через InputContextManager
	if InputContextManager.is_blocked():
		return
	
	# Обработка навигации по картам уже обработана в _input() для раннего перехвата
	# Здесь не обрабатываем, чтобы избежать дублирования
	
	# Проверяем контекст (работаем только в контексте GAME для остальных действий)
	if not InputContextManager.can_handle(InputContextManager.InputContext.GAME):
		return
	
	# Space при Game Over → рестарт игры
	if event.is_action_pressed("action"):
		if game_state_controller and not game_state_controller.is_game_active():
			# Game Over - рестарт игры
			_on_restart_game()
			# Скрываем Game Over overlay
			if game_over_popup and game_over_popup.visible:
				game_over_popup.hide()
			get_viewport().set_input_as_handled()
			return
	
	# Если навигация по ставкам активна - обрабатываем ввод там
	if chip_navigation_manager and chip_navigation_manager.is_active:
		if chip_navigation_manager.handle_input(event):
			get_viewport().set_input_as_handled()
			return
	
	# Переключение режима сбора/выплаты ставок (геймпад или клавиатура)
	if event.is_action_pressed("toggle_collect_pay_mode"):
		# Проверяем, что кнопка PayButton видима (режим сбора/выплаты активен)
		if ui_manager and ui_manager.button_ui:
			var pay_button = ui_manager.button_ui.pay_button
			if pay_button and pay_button.visible:
				# Переключаем состояние PayButton
				if pay_button.has_method("toggle_state"):
					pay_button.toggle_state()
				else:
					# Fallback: вызываем напрямую _on_pressed, если метод не найден
					pay_button._on_pressed()
		get_viewport().set_input_as_handled()
		return
	
	# Escape во время игры → открыть/закрыть меню
	if event.is_action_pressed("exit"):
		# Проверяем, не открыто ли меню гостей (приоритет выше)
		var guest_menu = get_node_or_null("GuestMenuScene")
		if guest_menu and guest_menu.visible:
			# Если меню гостей открыто, закрываем его
			guest_menu.close_menu()
			get_viewport().set_input_as_handled()
			return
		
		# Проверяем, не открыто ли меню настроек
		if settings_scene and settings_scene.visible:
			# Если меню открыто, закрываем его
			settings_scene.close_settings()
		else:
			# Если меню закрыто, открываем его
			if settings_scene:
				settings_scene.open_settings()
		get_viewport().set_input_as_handled()
		return

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_settings_button_pressed():
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
			# Отключаем кнопку "Карты" чтобы случайно не нажать
			# Напрямую disabled = true (не через disable_action_button который только для "complete")
			if ui_manager and ui_manager.button_ui and ui_manager.button_ui.action_button:
				ui_manager.button_ui.action_button.disabled = true
				DebugLogger.log("⚙️ Кнопка 'Карты' отключена (настройки открыты)")
	else:
		DebugLogger.log("  ❌ ОШИБКА: settings_scene = null!")

func _on_settings_closed():
	"""Обработчик закрытия настроек — включаем кнопку 'Карты' обратно"""
	# Напрямую disabled = false (не через enable_action_button)
	if ui_manager and ui_manager.button_ui and ui_manager.button_ui.action_button:
		ui_manager.button_ui.action_button.disabled = false
		DebugLogger.log("⚙️ Настройки закрыты → кнопка 'Карты' включена")


# Методы обработки настроек перенесены в SettingsEventHandler
# _on_mode_changed -> settings_handler.handle_mode_changed
# _apply_mode_change -> settings_handler.apply_mode_change
# _on_language_changed -> settings_handler.handle_language_changed
# _on_survival_mode_changed -> settings_handler.handle_survival_mode_changed

func _load_survival_mode_setting():
	"""Активировать режим выживания (всегда включён)"""
	if survival_state:
		survival_state.activate()
	# StatsLabel показывает деньги (управляется в StatsManager)
	DebugLogger.log("Режим выживания активирован (сердца + деньги)")

# Метод _on_game_state_changed перенесён в SettingsEventHandler.handle_game_state_changed

# ═══════════════════════════════════════════════════════════════════════════
# КЛАВИАТУРНАЯ НАВИГАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ РЕЖИМ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_manual_mode_payout_return(context: Dictionary) -> void:
	"""Обработка возврата из PayoutScene в ручном режиме"""
	DebugLogger.log_restore("⏮ Возврат из PayoutScene (ручной режим)")
	
	# Guard: проверка сохранённого состояния
	if not TableStateManager.has_saved_state():
		push_error("❌ TableStateManager не содержит сохраненного состояния!")
		PayoutContextManager.clear_context()
		GameDataManager.clear()
		return
	
	# 1-3. Восстановление карт, UI и GameStateManager
	_restore_table_state()
	
	# 4-6. Восстановление survival режима и очереди выплат
	_restore_survival_and_queue()
	
	# 7. Обработка результата текущей выплаты
	_process_manual_payout_result(context)
	
	# 8. Восстановление камеры и очистка контекстов
	_restore_camera_and_cleanup()


func _restore_table_state() -> void:
	"""Восстановление карт, UI карт и GameStateManager
	
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
	
	state_restorer.restore_table_state()


func _restore_survival_and_queue() -> void:
	"""Восстановление маркера победителя, survival режима и очереди выплат
	
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
	
	# Восстанавливаем survival режим
	survival_rounds_completed = TableStateManager.get_survival_rounds()
	_update_rounds_counter()
	
	# Восстанавливаем очередь выплат через StateRestorer
	payout_queue_manager = state_restorer.restore_survival_and_queue(
		payout_queue_manager,
		survival_rounds_completed
	)
	
	# КРИТИЧНО: Обновляем ссылку в phase_manager после восстановления!
	phase_manager.payout_queue_manager = payout_queue_manager
	DebugLogger.log_restore("⏮ Ссылка phase_manager.payout_queue_manager обновлена")
	
	# Обновляем видимость фишек (показываем неоплаченные выигрыши)
	_update_chip_visibility()


func _process_manual_payout_result(context: Dictionary) -> void:
	"""Обработка результата текущей выплаты в ручном режиме - делегировано в PayoutOverlayCoordinator"""
	if payout_overlay_coordinator:
		payout_overlay_coordinator.process_manual_payout_result(context)
	else:
		push_error("❌ PayoutOverlayCoordinator не инициализирован!")


func _restore_camera_and_cleanup() -> void:
	"""Восстановление камеры и очистка контекстов
	
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
	
	state_restorer.restore_camera()
	
	# Очищаем контексты
	PayoutContextManager.clear_context()
	PayoutContextManager.clear_saved_state()
	GameDataManager.clear()


# ═══════════════════════════════════════════════════════════════════════════
# АВТОМАТИЧЕСКИЙ РЕЖИМ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_automatic_mode_payout_return() -> void:
	"""Обработка возврата из PayoutScene в автоматическом режиме"""
	# 1. Восстанавливаем состояние игры и камеру
	_restore_automatic_mode_state()
	
	# 2. Проверка Game Over
	if _check_and_handle_game_over():
		return  # Game Over произошёл, выходим
	
	# 3. Обрабатываем результат выплаты
	_process_automatic_payout_result()
	
	# 4. Обрабатываем очередь выплат
	_handle_payout_queue()


func _restore_automatic_mode_state() -> void:
	"""Восстановление состояния игры, камеры и UI"""
	# Восстанавливаем состояние survival режима
	survival_rounds_completed = GameDataManager.get_survival_rounds()
	_update_rounds_counter()
	if survival_state:
		survival_state.set_lives(GameDataManager.get_survival_lives())
		if GameDataManager.is_survival_active():
			survival_state.activate()
		else:
			survival_state.deactivate()
	
	# Восстанавливаем камеру на общий план (без анимации)
	if camera_manager:
		camera_manager.restore_to_general()
		DebugLogger.log("📷 Камера восстановлена: общий план")
	
	# Показываем кнопки областей
	EventBus.area_buttons_visibility_changed.emit(true)
	
	# Обновляем визуальное отображение сердечек
	var is_active = survival_state.is_active_mode() if survival_state else false
	var lives = survival_state.get_lives() if survival_state else 7
	if is_active:
		survival_state.show()
	else:
		survival_state.hide()

	DebugLogger.log("♻️  Состояние игры восстановлено: rounds=%d, lives=%d, active=%s" % [
		survival_rounds_completed, lives, is_active
	])


func _check_and_handle_game_over() -> bool:
	"""Проверка Game Over в режиме выживания
	
	Returns:
		true если Game Over произошёл, false если игра продолжается
	"""
	var is_active = survival_state.is_active_mode() if survival_state else false
	var lives = survival_state.get_lives() if survival_state else 7
	if is_active and lives <= 0:
		DebugLogger.log_game_flow("GAME OVER! Закончились жизни (проверка после возврата из PayoutScene)")
		_on_survival_game_over(survival_rounds_completed)
		GameDataManager.clear()
		return true
	
	return false


func _process_automatic_payout_result() -> void:
	"""Обработка результата выплаты в автоматическом режиме"""
	var is_correct = GameDataManager.get_payout_is_correct()
	var collected = GameDataManager.get_payout_collected()
	var expected = GameDataManager.get_payout_expected()
	
	if is_correct:
		# Для автоматического режима нет информации о bet_type/position_index
		# Передаем пустые значения - StatsManager пропустит такие случаи
		EventBus.payout_correct.emit(collected, expected, "", -1)
		DebugLogger.log("✅ Правильно! Выплата: %s" % expected)
		# ВАЖНО: Счетчик раздач НЕ увеличивается здесь - он увеличивается при открытии первых 4 карт
	else:
		# Для старого метода нет информации о bet_type/position_index
		EventBus.payout_wrong.emit(collected, expected, "", -1)
		DebugLogger.log("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])


func _handle_payout_queue() -> void:
	"""Обработка очереди выплат (переход к следующей или сброс раунда)"""
	if GameDataManager.has_more_payouts():
		# Есть ещё выплаты в очереди → берём следующую
		var next_payout = GameDataManager.get_next_payout()
		
		DebugLogger.log("🔄 Следующая выплата: %s (осталось %d)" % [
			next_payout.get_bet_type(), GameDataManager.get_queue_size()
		])
		
		# Сохраняем данные для PayoutScene
		GameDataManager.set_payout_data(
			next_payout.get_bet_type(),
			next_payout.get_stake(),
			next_payout.get_payout(),
			next_payout.get_player_score(),
			next_payout.get_banker_score()
		)
		
		# Переходим в PayoutScene для следующей выплаты
		get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
	else:
		# Очередь пуста → сбрасываем раунд
		DebugLogger.log_init("Все выплаты обработаны, сброс раунда")
		GameDataManager.clear()
		
		# Сброс раунда только если последняя выплата была правильной
		var is_correct = GameDataManager.get_payout_is_correct()
		if is_correct:
			phase_manager.reset()



func camera_zoom_in():
	"""Плавный зум на область карт (через EventBus)"""
	EventBus.camera_zoom_requested.emit("in")

func camera_zoom_out():
	"""Возврат к общему плану (через EventBus)"""
	EventBus.camera_zoom_requested.emit("out")

func camera_zoom_cards():
	"""Плавный зум на область карт (через EventBus)"""
	EventBus.camera_zoom_requested.emit("cards")

func camera_zoom_area(area_index: int):
	"""Плавный зум на область ставок (через EventBus)"""
	EventBus.camera_zoom_requested.emit("area_%d" % area_index)


func _on_left_arrow_pressed():
	"""Обработчик нажатия левой стрелки (через EventBus)"""
	_request_camera_target_area("left")

func _on_right_arrow_pressed():
	"""Обработчик нажатия правой стрелки (через EventBus)"""
	_request_camera_target_area("right")

func _on_up_arrow_pressed():
	"""Обработчик нажатия стрелки вверх (через EventBus)"""
	_request_camera_target_area("up")

func _on_down_arrow_pressed():
	"""Обработчик нажатия стрелки вниз (через EventBus)"""
	_request_camera_target_area("down")

func _request_camera_target_area(direction: String) -> void:
	"""Запросить целевую область через EventBus и выполнить зум
	
	Args:
		direction: "left", "right", "up", "down"
	"""
	# Создаём временную подписку на ответ (одноразово)
	var response_handler = func(dir: String, area: int):
		if dir == direction:
			if area > 0:
				EventBus.camera_zoom_requested.emit("area_%d" % area)
			elif area == -1:
				EventBus.camera_zoom_requested.emit("out")
			else:
				EventBus.camera_zoom_requested.emit("in")
			_update_arrows_state()
			# CONNECT_ONE_SHOT автоматически отписывает после первого вызова
	
	EventBus.camera_target_area_received.connect(response_handler, CONNECT_ONE_SHOT)
	EventBus.camera_target_area_requested.emit(direction)

func _on_arrows_visibility_changed(_should_show: bool):
	"""Обработчик изменения видимости стрелок
	
	Примечание: стрелки визуально всегда скрыты (visible = false),
	но сигнал используется для активации/деактивации навигации по полю.
	Параметр _should_show не используется, так как стрелки всегда скрыты.
	"""
	var left_arrow = get_node_or_null("TopUI/LeftArrowButton")
	var right_arrow = get_node_or_null("TopUI/RightArrowButton")
	var up_arrow = get_node_or_null("TopUI/UpArrowButton")
	var down_arrow = get_node_or_null("TopUI/DownArrowButton")

	# Стрелки визуально всегда скрыты (навигация через клавиатуру и свайп)
	if left_arrow:
		left_arrow.visible = false
	if right_arrow:
		right_arrow.visible = false
	if up_arrow:
		up_arrow.visible = false
	if down_arrow:
		down_arrow.visible = false

	# Обновление состояния стрелок не нужно - они всегда скрыты

func _update_arrows_state(target_area: int = -1):
	"""Обновить состояние стрелок (активность) в зависимости от текущей области
	
	Args:
		target_area: Целевая область для мгновенного обновления (если -1, запрашивается через EventBus)
	"""
	if target_area >= 0:
		# Если область передана, используем её напрямую
		_update_arrows_for_area(target_area)
	else:
		# Запрашиваем текущую область через EventBus
		var response_handler = func(area: int):
			_update_arrows_for_area(area)
			# CONNECT_ONE_SHOT автоматически отписывает после первого вызова
		
		EventBus.camera_current_area_received.connect(response_handler, CONNECT_ONE_SHOT)
		EventBus.camera_current_area_requested.emit()

func _update_arrows_for_area(current_area: int) -> void:
	"""Обновить состояние стрелок для указанной области
	
	Args:
		current_area: Текущая область (0 = карты, 1-3 = области ставок)
	"""
	var left_arrow = get_node_or_null("TopUI/LeftArrowButton")
	var right_arrow = get_node_or_null("TopUI/RightArrowButton")
	var up_arrow = get_node_or_null("TopUI/UpArrowButton")
	var down_arrow = get_node_or_null("TopUI/DownArrowButton")
	
	# Счётчик ожидаемых ответов и словарь ответов (используем словарь для изменяемых значений)
	var state = {
		"pending": 4,
		"completed": false,
		"responses": {
			"left": null,
			"right": null,
			"up": null,
			"down": null
		}
	}
	
	# Обработчик ответов (не отписываемся вручную - просто игнорируем после завершения)
	var response_handler = func(area: int, dir: String, target: int):
		# Игнорируем, если уже завершено
		if state.completed:
			return
		# Проверяем, что ответ относится к текущему запросу
		if area == current_area and dir in state.responses and state.responses[dir] == null:
			state.responses[dir] = target
			state.pending -= 1
			if state.pending == 0:
				# Все ответы получены, обновляем стрелки
				state.completed = true
				_apply_arrows_state(left_arrow, right_arrow, up_arrow, down_arrow, current_area, state.responses)
				# Не отписываемся - обработчик просто будет игнорировать дальнейшие вызовы
	
	EventBus.camera_target_area_from_received.connect(response_handler)
	
	# Запрашиваем целевые области для всех направлений
	EventBus.camera_target_area_from_requested.emit(current_area, "left")
	EventBus.camera_target_area_from_requested.emit(current_area, "right")
	EventBus.camera_target_area_from_requested.emit(current_area, "up")
	EventBus.camera_target_area_from_requested.emit(current_area, "down")

func _apply_arrows_state(left_arrow: Node, right_arrow: Node, up_arrow: Node, down_arrow: Node, current_area: int, responses: Dictionary) -> void:
	"""Применить состояние стрелок на основе ответов
	
	Args:
		left_arrow, right_arrow, up_arrow, down_arrow: Узлы стрелок
		current_area: Текущая область
		responses: Словарь с целевыми областями {"left": int, "right": int, ...}
	"""
	# Левая стрелка
	if left_arrow and responses.has("left"):
		var target_left = responses["left"]
		var can_go_left = (target_left != current_area)
		left_arrow.disabled = not can_go_left
		left_arrow.modulate.a = 0.3 if not can_go_left else 1.0
	
	# Правая стрелка
	if right_arrow and responses.has("right"):
		var target_right = responses["right"]
		var can_go_right = (target_right != current_area)
		right_arrow.disabled = not can_go_right
		right_arrow.modulate.a = 0.3 if not can_go_right else 1.0
	
	# Стрелка вверх
	if up_arrow and responses.has("up"):
		var target_up = responses["up"]
		var can_go_up = (target_up != current_area)
		up_arrow.disabled = not can_go_up
		up_arrow.modulate.a = 0.3 if not can_go_up else 1.0
	
	# Стрелка вниз
	if down_arrow and responses.has("down"):
		var target_down = responses["down"]
		var can_go_down = (target_down != current_area)
		down_arrow.disabled = not can_go_down
		down_arrow.modulate.a = 0.3 if not can_go_down else 1.0



# Методы обработки настроек перенесены в SettingsEventHandler
# _on_payout_setting_changed -> settings_handler.handle_payout_setting_changed
# _on_card_back_style_changed -> settings_handler.handle_card_back_style_changed
# _on_position_mode_changed -> settings_handler.handle_position_mode_changed

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СТАВОК И ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func _on_winner_toggled(winner: String, selected: bool):
	if selected:
		DebugLogger.log("🎯 Выбран: %s" % winner)
		# TieMarker всегда виден (не деактивируется)
		# Отменяем заказ третьих карт при активации маркера
		if phase_manager:
			phase_manager.cancel_third_card_orders()
	else:
		DebugLogger.log("🎯 Снят выбор: %s" % winner)
		# TieMarker всегда виден и доступен (не нужно активировать/деактивировать)


func _on_camera_zoom_completed(_zoom_type: String) -> void:
	"""Обработка завершения зума камеры (синхронизация подсветки при необходимости)"""
	# Подсветка уже обновлена мгновенно в _on_camera_zoom_requested
	# Обновляем состояние стрелок после завершения зума (current_area точно обновлён)
	_update_arrows_state()


func _update_area_highlights(area_idx: int) -> void:
	"""Показать подсветку выбранной области (1-3), 0 — скрыть все"""
	for i in range(1, 4):
		var node_path = "AreaHighlight%d" % i
		var hl = get_node_or_null(node_path)
		if hl:
			var active = (i == area_idx)
			hl.visible = active
			hl.modulate.a = 1.0 if active else 0.0


func _on_camera_zoom_requested(zoom_type: String) -> void:
	"""Мгновенно подсвечиваем целевую область по запросу зума (до завершения анимации)"""
	var target_area := camera_manager.predict_target_area(zoom_type)
	_update_area_highlights(target_area)
	
	# Мгновенно обновляем состояние стрелок на основе целевой области
	# (так же быстро, как меняется подсветка зон)
	_update_arrows_state(target_area)
	
	# Скрываем кнопки областей если переходим в область через стрелки/клавиши
	# (они уже не нужны, так как зона выбрана)
	if zoom_type.begins_with("area_"):
		EventBus.area_buttons_visibility_changed.emit(false)


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


func _on_collect_mode_toggled(enabled: bool):
	"""Обработчик toggle кнопки 'Забрать'"""
	if bet_collection_manager:
		if enabled:
			bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.COLLECT)
		else:
			# Если режим сбора был активен, отключаем
			if bet_collection_manager.is_collect_mode():
				bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.NONE)

func _on_pay_mode_toggled(enabled: bool):
	"""Обработчик toggle кнопки 'Оплатить'"""
	if bet_collection_manager:
		if enabled:
			bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.PAY)
		else:
			# Если режим оплаты был активен, отключаем
			if bet_collection_manager.is_pay_mode():
				bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.NONE)

func _on_chip_clicked(bet_type: String):
	"""Обработчик клика на фишку (старый интерфейс, для обратной совместимости)"""
	# Вызываем новый обработчик с position_index = 0
	_on_chip_instance_clicked(bet_type, 0)


func _on_chip_instance_clicked(bet_type: String, position_index: int):
	"""Обработчик клика на конкретную фишку (с position_index)
	
	Делегирует обработку в ChipClickHandler (Extract Class)
	"""
	if chip_click_handler:
		chip_click_handler.handle_chip_click(bet_type, position_index)
	else:
		push_error("❌ ChipClickHandler не инициализирован!")


func _show_payout_overlay_instance(bet_type: String, position_index: int, stake: float, payout: float):
	"""Показать PayoutOverlay для конкретной фишки - делегировано в PayoutOverlayCoordinator"""
	if payout_overlay_coordinator:
		payout_overlay_coordinator.show_payout_overlay_instance(bet_type, position_index, stake, payout)
	else:
		push_error("❌ PayoutOverlayCoordinator не инициализирован!")

func _open_payout_scene(bet_type: String):
	"""Открыть PayoutScene для конкретной ставки - делегировано в PayoutOverlayCoordinator"""
	if payout_overlay_coordinator:
		payout_overlay_coordinator.open_payout_scene(bet_type)
	else:
		push_error("❌ PayoutOverlayCoordinator не инициализирован!")


# ═══════════════════════════════════════════════════════════════════════════
# OVERLAY РЕЖИМ ВЫПЛАТ (новая логика)
# ═══════════════════════════════════════════════════════════════════════════

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
# ОБРАБОТЧИКИ СОБЫТИЙ EVENTBUS (для Dependency Injection рефакторинга Фазы 1)
# ═══════════════════════════════════════════════════════════════════════════

func _on_manual_payout_requested(winner: String):
	"""Обработка запроса подготовки выплат от GamePhaseManager через EventBus"""
	_prepare_payouts_manual(winner)

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
	"""Обработчик активации элемента через клавиатурный фокус
	
	Вызывается когда пользователь дважды нажал клавишу для активации элемента.
	
	Args:
		target: Имя активированного элемента:
			- "BankerThird" - третья карта банкиру
			- "PlayerThird" - третья карта игроку
			- "BankerMarker" - маркер банкира
			- "PlayerMarker" - маркер игрока  
			- "TieMarker" - маркер ничьи
	"""
	match target:
		"BankerThird":
			# Активируем toggle третьей карты банкира
			if phase_manager:
				phase_manager.on_banker_third_toggled(true)
				DebugLogger.log("⌨️ Активирован BankerThird через клавиатуру")
		
		"PlayerThird":
			# Активируем toggle третьей карты игрока
			if phase_manager:
				phase_manager.on_player_third_toggled(true)
				DebugLogger.log("⌨️ Активирован PlayerThird через клавиатуру")
		
		"BankerMarker":
			# Активируем маркер банкира
			if winner_selection_manager:
				winner_selection_manager.toggle_winner("Banker")
				DebugLogger.log("⌨️ Активирован BankerMarker через клавиатуру")
		
		"PlayerMarker":
			# Активируем маркер игрока
			if winner_selection_manager:
				winner_selection_manager.toggle_winner("Player")
				DebugLogger.log("⌨️ Активирован PlayerMarker через клавиатуру")
		
		"TieMarker":
			# Активируем маркер Tie (toggle как и другие маркеры)
			if winner_selection_manager:
				winner_selection_manager.toggle_winner("Tie")
				DebugLogger.log("⌨️ Активирован TieMarker через клавиатуру")
		
		_:
			DebugLogger.log_warning("⚠️ Неизвестная цель фокуса: %s" % target)

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ГЕЙМПАДА
# ═══════════════════════════════════════════════════════════════════════════

func _check_gamepad_connection() -> void:
	"""Проверить подключение геймпадов и вывести информацию"""
	var connected_joypads = Input.get_connected_joypads()
	
	if connected_joypads.size() > 0:
		DebugLogger.log("🎮 Подключено геймпадов: %d" % connected_joypads.size())
		for device_id in connected_joypads:
			var joypad_name = Input.get_joy_name(device_id)
			DebugLogger.log("🎮 Геймпад %d: %s" % [device_id, joypad_name])

func _process(_delta: float) -> void:
	"""Проверка изменения подключения геймпадов (только при изменении)"""
	# Проверяем подключение геймпадов периодически (раз в 5 секунд)
	if not has_meta("last_gamepad_check"):
		set_meta("last_gamepad_check", Time.get_ticks_msec())
		set_meta("last_connected_count", Input.get_connected_joypads().size())
		return
	
	var last_check = get_meta("last_gamepad_check", 0) as int
	var current_time = Time.get_ticks_msec()
	var last_connected_count = get_meta("last_connected_count", 0) as int
	
	if current_time - last_check > 5000:  # Раз в 5 секунд
		set_meta("last_gamepad_check", current_time)
		
		var connected = Input.get_connected_joypads()
		
		# Логируем только при изменении количества подключенных геймпадов
		if connected.size() != last_connected_count:
			set_meta("last_connected_count", connected.size())
			DebugLogger.log("🎮 Изменение подключения геймпадов: найдено устройств = %d (было %d)" % [connected.size(), last_connected_count])
			
			if connected.size() > 0:
				for device_id in connected:
					var joypad_name = Input.get_joy_name(device_id)
					DebugLogger.log("🎮 Геймпад подключен: device_id=%d, name=%s" % [device_id, joypad_name])

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ UI - СЧЕТЧИК РАУНДОВ
# ═══════════════════════════════════════════════════════════════════════════

func _on_round_started() -> void:
	"""Обработчик начала новой раздачи (открыты первые 4 карты)"""
	survival_rounds_completed += 1
	_update_rounds_counter()
	DebugLogger.log("🎮 Началась раздача #%d" % survival_rounds_completed)

func _update_rounds_counter() -> void:
	"""Обновить отображение счетчика раздач"""
	if rounds_counter_label:
		rounds_counter_label.text = "Раздача: %d" % survival_rounds_completed
