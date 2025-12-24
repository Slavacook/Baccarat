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

## HeartBar - менеджер жизней (новая система)
var heart_bar: HeartBar = null

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ИГРЫ
# ═══════════════════════════════════════════════════════════════════════════

var survival_rounds_completed: int = 0
var is_survival_mode: bool = true  # Всегда включён (сердца + деньги)
var is_table_prepared_for_new_game: bool = false
var is_game_over: bool = false  # Флаг Game Over для блокировки процессов
var is_payout_processing: bool = false  # Флаг обработки выплаты (защита от спама Space)

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




func _ready():
	"""Инициализация GameController

	Рефакторенная версия с GameInitializer (Extract Class паттерн).
	Было: 198 строк монолитной инициализации в _ready()
	Стало: Делегирование в GameInitializer.initialize()
	"""
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

	# Подсветка областей: подписываемся на завершение зума камеры
	if camera_manager:
		camera_manager.zoom_completed.connect(_on_camera_zoom_completed)
		_update_area_highlights(0)  # скрыть все подсветки на старте

	# Реакция на запрос зума: подсвечиваем целевую область сразу при нажатии
	if EventBus:
		EventBus.camera_zoom_requested.connect(_on_camera_zoom_requested)
		
		# Heart Bet: скрытие/показ ставок гостей
		EventBus.guest_bets_hide_requested.connect(_on_guest_bets_hide_requested)
		EventBus.guest_bets_show_requested.connect(_on_guest_bets_show_requested)
		EventBus.heart_bet_round_complete.connect(_on_heart_bet_round_complete)
		EventBus.heart_bet_declined.connect(_on_heart_bet_declined)
		
		# Настройки: включаем action_button при закрытии
		EventBus.settings_closed.connect(_on_settings_closed)
		
		# Heart Bet: триггеры обрабатываются через ChanceCardManager
		# Старые сигналы оставлены для обратной совместимости
	
	# Подписка на изменение настроек гостей (для очистки фишек при отключении)
	GuestSettingsManager.guest_settings_changed.connect(_on_guest_settings_changed)
	
	# Настройка новой системы карт шанса
	_setup_chance_card_system()
	
	# Инициализируем HeartBar (если ещё не инициализирован)
	_initialize_heart_bar()
	
	# Передаём heart_bar в ChanceCardManager после инициализации (если он был инициализирован)
	if heart_bar:
		ChanceCardManager.set_heart_bar(heart_bar)
		print("🎴 HeartBar передан в ChanceCardManager (после инициализации)")
	
	# Сбрасываем флаг Game Over при инициализации (на случай перезагрузки сцены)
	is_game_over = false
	EventBus.is_game_active = true

## Инициализировать HeartBar из survival_ui
func _initialize_heart_bar() -> void:
	if survival_ui and "heart_bar" in survival_ui and survival_ui.heart_bar != null:
		heart_bar = survival_ui.heart_bar
		print("✅ HeartBar инициализирован в GameController")
	else:
		print("⚠️  HeartBar не найден в survival_ui (возможно, survival_ui ещё не готов)")


# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ - ВЫНЕСЕНА В GameInitializer.gd (Task 2.1)
# ═══════════════════════════════════════════════════════════════════════════
# Все helper методы инициализации перенесены в GameInitializer.initialize()
# Удалено ~235 строк дублирующего кода

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КАРТАМИ
# ═══════════════════════════════════════════════════════════════════════════

func set_flip_cards(cards):
	flip_cards = cards

func show_all_backs(back_texture: Texture2D):
	for card in flip_cards:
		card.show_back(back_texture)

func open_all_cards(face_textures: Array, delay: float = 0.3):
	for i in range(face_textures.size()):
		await get_tree().create_timer(i * delay).timeout
		flip_cards[i].open_card(face_textures[i])

func open_all_cards_with_flip(face_textures: Array, delay: float = 0.3):
	# Открываем каждую карту с flip-анимацией
	for i in range(face_textures.size()):
		flip_cards[i].play_flip()                 # Запустить анимацию flip
		await get_tree().create_timer(delay).timeout   # Подождать, пока проиграется flip (~0.3 сек)
		card_nodes[i].texture = face_textures[i]  # Показать открытую карту

func open_two_third_cards(texture1: Texture2D, texture2: Texture2D):
	flip_cards[4].open_card(texture1)
	flip_cards[5].open_card(texture2)

func reset_cards(back_texture: Texture2D):
	show_all_backs(back_texture)


func _on_winner_selected(chosen: String):
	"""Обработка выбора победителя игроком
	
	Рефакторенная версия с guard clauses + Extract Method.
	Было: 106 строк с глубокой вложенностью
	Стало: ~15 строк главный метод + 7 helper методов
	"""
	# Guard 1: Проверка валидности выбора победителя
	if not _is_winner_selection_valid():
		return
	
	var actual = BaccaratRules.get_winner(hand_manager.get_player_hand_ref(), hand_manager.get_banker_hand_ref())
	
	# Guard 2: Неправильный выбор победителя
	if chosen != actual:
		_handle_incorrect_winner_choice()
		return
	
	# Правильный выбор → обработка выплат
	await _handle_correct_winner_choice(actual)


# ═══════════════════════════════════════════════════════════════════════════
# ВЫБОР ПОБЕДИТЕЛЯ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _is_winner_selection_valid() -> bool:
	"""Проверка валидности выбора победителя
	
	Returns:
		true если выбор валиден, false если нет (с эмитом ошибки)
	"""
	if not GameStateManager.is_action_valid(GameStateManager.Action.SELECT_WINNER):
		var error_msg = GameStateManager.get_error_message(GameStateManager.Action.SELECT_WINNER)
		
		# Штраф только если не в состоянии WAITING (карты уже раздавались)
		var current_state = GameStateManager.get_current_state()
		if current_state != GameStateManager.GameState.WAITING:
			EventBus.action_error.emit("winner_early", error_msg)
		
		DebugLogger.log("🚫 [НОВАЯ СИСТЕМА] %s" % error_msg)
		return false
	
	return true


func _handle_incorrect_winner_choice() -> void:
	"""Обработка неправильного выбора победителя"""
	EventBus.action_error.emit("winner_wrong", "")
	# Жизнь отнимается автоматически через EventBus → SurvivalModeUI


func _handle_correct_winner_choice(actual: String) -> void:
	"""Обработка правильного выбора победителя
	
	Args:
		actual: Фактический победитель (Player/Banker/Tie)
	"""
	# ✅ Правильный выбор победителя
	EventBus.action_correct.emit("winner")
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Если это был Heart Bet раунд (даже с отказом) - пропускаем выплаты
	# ═══════════════════════════════════════════════════════════════════
	if phase_manager and phase_manager.was_heart_bet_round:
		print("❤️ GameController: был Heart Bet раунд (даже с отказом), пропускаем выплаты")
		# Если была активная ставка - разрешаем её
		if phase_manager.has_active_heart_bet():
			phase_manager.resolve_heart_bet(actual)
		else:
			# Отказ от шанса - просто завершаем раунд без выплат
			# Эмитим сигнал завершения Heart Bet раунда для сброса
			EventBus.heart_bet_round_complete.emit()
		# В любом случае НЕ продолжаем с обычной логикой выплат
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Разрешаем ставку сердцем (если была активна)
	# При активной Heart Bet выплаты не производятся!
	# ═══════════════════════════════════════════════════════════════════
	var has_heart_bet = phase_manager and phase_manager.has_active_heart_bet()
	print("❤️ GameController: has_active_heart_bet = %s" % has_heart_bet)
	
	if has_heart_bet:
		print("❤️ GameController: вызываем resolve_heart_bet(%s)" % actual)
		phase_manager.resolve_heart_bet(actual)
		# Раунд сбросится через heart_bet_round_complete в EventBus
		# НЕ продолжаем с выплатами - это особая раздача на жизнь
		return
	
	# Блокируем маркеры, чтобы игрок не мог случайно изменить выбор во время выплат
	if winner_selection_manager:
		winner_selection_manager.lock_markers()
	
	# Пауза 1 секунда (карты остаются открытыми, маркер активен)
	await get_tree().create_timer(GameConstants.VICTORY_TOAST_DELAY).timeout
	
	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ВАЛИДНОСТИ ПОСЛЕ AWAIT (защита от race conditions)
	# ═══════════════════════════════════════════════════════════════════
	if not is_instance_valid(self):
		DebugLogger.log("⚠️  GameController удалён во время await, прерываем операцию")
		return
	
	# Проверяем что менеджеры всё ещё инициализированы
	if not hand_manager or not limits_manager:
		push_error("❌ Критические менеджеры не инициализированы после await!")
		return
	
	# Проверяем что руки не пустые (игра не была сброшена)
	var player_hand = hand_manager.get_player_hand_ref()
	var banker_hand = hand_manager.get_banker_hand_ref()
	if player_hand.is_empty() or banker_hand.is_empty():
		DebugLogger.log("⚠️  Руки пустые после await, возможно раунд был сброшен")
		return
	
	# Создаём очередь выплат
	_create_payout_queue(actual)
	
	# Обрабатываем очередь или сбрасываем раунд
	_process_payout_queue_or_reset()


func _create_payout_queue(actual: String) -> void:
	"""Создание очереди выплат (основная ставка + пары)
	
	Args:
		actual: Фактический победитель (Player/Banker/Tie)
	"""
	var player_score = BaccaratRules.hand_value(hand_manager.get_player_hand_ref())
	var banker_score = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	# Очищаем очередь перед созданием новой
	GameDataManager.clear_payout_queue()
	
	# 1. Добавляем основную ставку (если активна)
	_add_main_bet_to_queue(actual, player_score, banker_score)
	
	# 2. Добавляем ставки на пары (если обнаружены)
	_add_pair_bets_to_queue(player_score, banker_score)
	
	# Выводим статус очереди
	GameDataManager.print_queue_status()


func _add_main_bet_to_queue(actual: String, player_score: int, banker_score: int) -> void:
	"""Добавление основной ставки в очередь (Player/Banker/Tie)
	
	Рефакторено: использует IBetType вместо match bet_type (OCP)
	
	Args:
		actual: Фактический победитель
		player_score: Очки игрока
		banker_score: Очки банкира
	"""
	var bet_type = BetTypeFactory.create(actual)
	if not bet_type:
		return
	
	if not PayoutSettingsManager.is_payout_enabled(actual):
		return
	
	var stake = bet_type.get_stake(limits_manager)
	var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
	
	var payout_calculator = PayoutCalculator.new()
	var payout = payout_calculator.calculate(
		bet_type, 
		stake, 
		actual,
		pair_betting_manager.has_player_pair() if pair_betting_manager else false,
		pair_betting_manager.has_banker_pair() if pair_betting_manager else false,
		banker_value
	)
	
	GameDataManager.add_to_payout_queue(actual, stake, payout, player_score, banker_score)


func _add_pair_bets_to_queue(player_score: int, banker_score: int) -> void:
	"""Добавление ставок на пары в очередь выплат
	
	Рефакторено: использует IBetType вместо прямых проверок (OCP)
	
	Args:
		player_score: Очки игрока
		banker_score: Очки банкира
	"""
	if not pair_betting_manager:
		return
	
	var payout_calculator = PayoutCalculator.new()
	
	# Пара игрока - если обнаружена И ставка была
	if pair_betting_manager.has_player_pair() and pair_betting_manager.is_player_pair_bet_enabled():
		var bet_type = BetTypeFactory.create("PairPlayer")
		var stake = bet_type.get_stake(limits_manager)
		var payout = payout_calculator.calculate_pair_payout(bet_type, stake, pair_betting_manager)
		GameDataManager.add_to_payout_queue("PairPlayer", stake, payout, player_score, banker_score)
	
	# Пара банкира - если обнаружена И ставка была
	if pair_betting_manager.has_banker_pair() and pair_betting_manager.is_banker_pair_bet_enabled():
		var bet_type = BetTypeFactory.create("PairBanker")
		var stake = bet_type.get_stake(limits_manager)
		var payout = payout_calculator.calculate_pair_payout(bet_type, stake, pair_betting_manager)
		GameDataManager.add_to_payout_queue("PairBanker", stake, payout, player_score, banker_score)


func _process_payout_queue_or_reset() -> void:
	"""Обработка очереди выплат или сброс раунда (если очередь пуста)"""
	if GameDataManager.has_more_payouts():
		# Есть выплаты → берём первую и переходим в PayoutScene
		var next_payout = GameDataManager.get_next_payout()
		
		# Сохраняем данные для PayoutScene
		GameDataManager.set_payout_data(
			next_payout.get_bet_type(),
			next_payout.get_stake(),
			next_payout.get_payout(),
			next_payout.get_player_score(),
			next_payout.get_banker_score()
		)
		
		# Сохраняем состояние игры (сердечки, раунды)
		var lives = heart_bar.get_lives() if heart_bar else (survival_ui.get_lives() if survival_ui else 7)
		var active = heart_bar.is_active_mode() if heart_bar else (survival_ui.is_active if survival_ui else false)
		GameDataManager.set_game_state(
			survival_rounds_completed,
			lives,
			active
		)
		
		get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
	else:
		# Нет выплат → сразу новый раунд
		phase_manager.reset()



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
	"""Подготовка выплат в ручном режиме (без автоматического перехода к сцене)

	Рефакторено: использует PayoutManager (SRP)
	"""
	# Создаем новый payout_queue_manager
	payout_queue_manager = PayoutQueueManager.new()
	
	# ВАЖНО: Обновляем ссылку в phase_manager
	phase_manager.payout_queue_manager = payout_queue_manager
	DebugLogger.log_init("Создан новый PayoutQueueManager, ссылка обновлена в phase_manager")
	
	# Создаем или обновляем PayoutManager
	if not payout_manager:
		# Передаём guest_bet_storage и phase_manager из phase_manager
		var guest_storage = phase_manager.guest_bet_storage if phase_manager else null
		payout_manager = PayoutManager.new(
			payout_queue_manager,
			bet_collection_manager,
			chip_visual_manager,
			limits_manager,
			pair_betting_manager,
			hand_manager,
			null,  # settings_provider (по умолчанию)
			guest_storage,  # guest_bet_storage
			phase_manager  # phase_manager (для доступа к snapshot фильтра)
		)
	else:
		# Обновляем ссылки
		payout_manager.payout_queue_manager = payout_queue_manager
		payout_manager.guest_bet_storage = phase_manager.guest_bet_storage if phase_manager else null
		payout_manager.phase_manager = phase_manager  # Обновляем ссылку на phase_manager
	
	# Делегируем подготовку выплат в PayoutManager
	payout_manager.prepare_manual_payouts(actual_winner)
	
	# Завершаем подготовку - обновляем видимость и сохраняем состояние
	_finalize_payouts_manual(actual_winner)


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
	"""Завершение подготовки выплат - обновление видимости и сохранение состояния"""
	# ═══════════════════════════════════════════════════════════════════
	# УПРАВЛЕНИЕ ФИШКАМИ (показать выигравшие, скрыть проигравшие)
	# ═══════════════════════════════════════════════════════════════════
	_update_chip_visibility()

	# ═══════════════════════════════════════════════════════════════════
	# НАСТРОЙКА BetCollectionPhaseManager для работы с очередью выплат
	# ═══════════════════════════════════════════════════════════════════
	if bet_collection_manager and payout_queue_manager:
		bet_collection_manager.setup(payout_queue_manager, actual_winner)
		# Устанавливаем режим COLLECT по умолчанию (после определения победителя)
		bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.COLLECT)
		DebugLogger.log("✅ BetCollectionPhaseManager настроен для раунда (победитель: %s, режим: COLLECT)" % actual_winner)

	# ═══════════════════════════════════════════════════════════════════
	# СОХРАНЕНИЕ СОСТОЯНИЯ СТОЛА в TableStateManager
	# ═══════════════════════════════════════════════════════════════════
	var selected_winner = winner_selection_manager.get_selected_winner() if winner_selection_manager else ""
	var surv_lives = heart_bar.get_lives() if heart_bar else (survival_ui.get_lives() if survival_ui else 7)
	var surv_active = heart_bar.is_active_mode() if heart_bar else (survival_ui.is_active if survival_ui else false)

	# Получаем состояние ставок на пары из настроек
	var pair_player_pressed = PayoutSettingsManager.player_pair_payout_enabled
	var pair_banker_pressed = PayoutSettingsManager.banker_pair_payout_enabled

	# Получаем текущие текстуры фишек
	var chip_textures = chip_visual_manager.current_textures if chip_visual_manager else {}

	# Запрашиваем настройки камеры через EventBus
	var camera_data = {"position": Vector2.ZERO, "zoom": Vector2.ONE, "received": false}
	
	if camera_manager:
		var response_handler = func(pos: Vector2, zoom: Vector2):
			camera_data.position = pos
			camera_data.zoom = zoom
			camera_data.received = true
			# CONNECT_ONE_SHOT автоматически отписывает после первого вызова
		
		EventBus.camera_settings_received.connect(response_handler, CONNECT_ONE_SHOT)
		EventBus.camera_settings_requested.emit()
		
		# Ждём ответ (синхронно, но с таймаутом)
		var timeout = 0.1
		var elapsed = 0.0
		while not camera_data.received and elapsed < timeout:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
	
	TableStateManager.save_table_state(
		hand_manager.get_player_hand_ref(),
		hand_manager.get_banker_hand_ref(),
		actual_winner,
		selected_winner,
		payout_queue_manager.get_all_bets(),
		camera_data.position,
		camera_data.zoom,
		GameModeManager.get_mode_string(),
		survival_rounds_completed,
		surv_lives,
		surv_active,
		pair_player_pressed,
		pair_banker_pressed,
		chip_textures,
		"complete"  # Кнопка всегда в состоянии "complete" при переходе к выплатам
	)


func _update_chip_visibility() -> void:
	"""Обновить видимость и кликабельность фишек через ChipVisualManager

	Режим GUEST: работаем с каждой ставкой индивидуально (гостевые ставки)
	- Оплаченные ставки → скрыть
	- Собранные проигрышные ставки → скрыть
	- Все остальные ставки (выигрышные, проигрышные, Tie push) → видимы и кликабельны
	  (валидация клика в BetCollectionPhaseManager)
	"""
	if not payout_queue_manager or not chip_visual_manager:
		return

	# В режиме GUEST работаем с каждой ставкой индивидуально (гостевые ставки)
	for bet in payout_queue_manager.get_all_bets():
		var bet_type = bet.get_bet_type()
		var pos_idx = bet.get_position_index()
		var is_collected = bet.is_collected() or (bet_collection_manager and bet_collection_manager.is_bet_collected(bet_type, pos_idx))
		
		if bet.is_paid() or is_collected:
			# Оплаченная или собранная → скрываем конкретную фишку
			chip_visual_manager.hide_chip_instance(bet_type, pos_idx)
		else:
			# Все остальные → видимы и кликабельны
			# В режиме GUEST фишки уже созданы через _show_guest_bets()
			# и уже кликабельны через _on_chip_instance_pressed
			# НЕ вызываем make_chip_clickable() - это подключит дополнительный обработчик
			# _on_chip_pressed, который вызовет двойной сбор ставки!
			var chip_instance = chip_visual_manager.get_chip_instance(bet.get_bet_type(), bet.get_position_index())
			if chip_instance and chip_instance.node:
				chip_instance.node.visible = true
				# Убеждаемся что фишка не заблокирована
				chip_instance.node.disabled = false
				chip_instance.node.mouse_filter = Control.MOUSE_FILTER_STOP
			
			var status = ""
			if bet.is_won():
				status = "выигрышная"
			elif bet_collection_manager and bet_collection_manager.is_tie_push_bet(bet.get_bet_type()):
				status = "Tie push"
			else:
				status = "проигрышная"
			DebugLogger.log("💰 Фишка %s[%d] видна (%s)" % [bet.get_bet_type(), bet.get_position_index(), status])

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ UI СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_help_button_pressed():
	ui_manager.help_popup.popup_centered()

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
		if is_survival_mode:
			survival_rounds_completed += 1
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
	"""Проверка, активна ли игра (не в Game Over)"""
	return not is_game_over

func _on_survival_game_over(_rounds: int):
	if is_game_over:
		return  # Уже в Game Over, игнорируем повторные вызовы
	
	is_game_over = true
	EventBus.is_game_active = false  # Синхронизируем с EventBus
	DebugLogger.log("🎮 GAME OVER! Раундов выжито: %d" % survival_rounds_completed)

	# 1. Сбрасываем шансы (чтобы не переходили в новую игру)
	if phase_manager and phase_manager.heart_bet_manager:
		phase_manager.heart_bet_manager.force_reset()
		DebugLogger.log("❤️ Шансы сброшены при Game Over")
	
	# 1.1. Обнуляем карты шансов (чтобы не переходили в новую игру)
	ChanceCardManager.reset_all_cards()

	# 2. Закрываем окно выплат, если оно открыто
	if payout_overlay and payout_overlay.visible:
		payout_overlay.hide()
		DebugLogger.log_payout("PayoutOverlay закрыт при Game Over")

	# 3. Зум аут до общего плана при Game Over
	camera_zoom_out()
	EventBus.camera_first_deal_set_requested.emit(true)  # Следующая раздача будет первой (с зумом)

	# 4. Уведомляем все системы через EventBus
	EventBus.game_over.emit(survival_rounds_completed)

	# 5. Показываем UI
	game_over_popup.show_game_over(survival_rounds_completed)

# _on_score_game_over удалён - Game Over теперь только через сердца (HeartBar)

func _on_restart_game():
	# Сбрасываем флаг Game Over
	is_game_over = false
	EventBus.is_game_active = true  # Синхронизируем с EventBus
	
	survival_rounds_completed = 0
	EventBus.camera_first_deal_set_requested.emit(true)  # После рестарта первая раздача с зумом
	StatsManager.instance.reset()
	if is_survival_mode:
		survival_ui.reset()
		survival_ui.activate()

	# Разблокируем маркеры для новой игры
	if winner_selection_manager:
		winner_selection_manager.unlock_markers()

	# Сбрасываем шансы (на всякий случай)
	if phase_manager and phase_manager.heart_bet_manager:
		phase_manager.heart_bet_manager.force_reset()
		DebugLogger.log("❤️ Шансы сброшены при рестарте")
	
	# Обнуляем карты шансов (на всякий случай)
	ChanceCardManager.reset_all_cards()

	phase_manager.reset()
	
	# Уведомляем все системы о рестарте
	EventBus.game_restarted.emit()
	
	DebugLogger.log("🔄 Игра перезапущена, все системы сброшены")

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
			# Защита от удаления ставок во время раздачи реализована в _on_guest_settings_changed()
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


func _on_mode_changed(mode: String):
	DebugLogger.log("Режим игры изменён на: %s" % mode)
	GameModeManager.set_mode(mode)
	var cfg = GameModeManager.get_config()
	# ← set_limits() сам вызовет limits_changed.emit() → _on_limits_changed()
	limits_manager.set_limits(
		cfg["main_min"], cfg["main_max"], cfg["main_step"],
		cfg["tie_min"], cfg["tie_max"], cfg["tie_step"],
		cfg["pairs_min"], cfg["pairs_max"], cfg["pairs_step"]
	)
	# Убрали дублирующий вызов _on_limits_changed() - он уже вызовется через сигнал

func _on_language_changed(_lang: String):
	ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	# Обновление toggles третьих карт (если видимы)
	if ui_manager.player_third_toggle.visible:
		var state = "!" if phase_manager.player_third_selected else "?"
		ui_manager.update_player_third_card_ui(state)
	if ui_manager.banker_third_toggle.visible:
		var state = "!" if phase_manager.banker_third_selected else "?"
		ui_manager.update_banker_third_card_ui(state)

func _on_survival_mode_changed(_enabled: bool):
	"""DEPRECATED: Режим выживания теперь всегда включён"""
	# Ничего не делаем - режим всегда включён
	pass

func _load_survival_mode_setting():
	"""Активировать режим выживания (теперь всегда включён)"""
	is_survival_mode = true  # Всегда true
	if survival_ui:
		survival_ui.activate()
	# StatsLabel показывает деньги (управляется в StatsManager)
	DebugLogger.log("Режим выживания активирован (сердца + деньги)")

func _on_game_state_changed(old_state: int, new_state: int):
	var old_name = GameStateManager.get_state_name(old_state)
	var new_name = GameStateManager.get_state_name(new_state)
	DebugLogger.log("📊 [НОВАЯ СИСТЕМА] Состояние: %s → %s" % [old_name, new_name])

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
	"""Обработка результата текущей выплаты в ручном режиме"""
	var bet_type = context.get("bet_type", "")
	var position_index = context.get("position_index", -1)  # Может не быть в context
	var is_correct = GameDataManager.get_payout_is_correct()
	var collected = GameDataManager.get_payout_collected()
	var expected = GameDataManager.get_payout_expected()
	
	if is_correct:
		EventBus.payout_correct.emit(collected, expected, bet_type, position_index)
		DebugLogger.log("✅ Правильная выплата для %s: %.1f" % [bet_type, expected])
		
		# Отмечаем ставку как оплаченную в обоих менеджерах
		payout_queue_manager.mark_as_paid(bet_type)
		TableStateManager.mark_bet_as_paid(bet_type)
		
		# Обновляем видимость фишек
		_update_chip_visibility()
		
		DebugLogger.log_init("Все выплаты оплачены! Можно начинать новый раунд")
	else:
		# Здесь нет информации о position_index, используем -1
		EventBus.payout_wrong.emit(collected, expected, bet_type, -1)
		DebugLogger.log("❌ Неправильная выплата для %s: собрано=%.1f, ожидалось=%.1f" % [
			bet_type, collected, expected
		])


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
	if heart_bar:
		heart_bar.set_lives(GameDataManager.get_survival_lives())
		if GameDataManager.is_survival_active():
			heart_bar.activate()
		else:
			heart_bar.deactivate()
	elif survival_ui:
		survival_ui.set_lives(GameDataManager.get_survival_lives())
		survival_ui.activate()  # Всегда активен
	
	# Восстанавливаем камеру на общий план (без анимации)
	if camera_manager:
		camera_manager.restore_to_general()
		DebugLogger.log("📷 Камера восстановлена: общий план")
	
	# Показываем кнопки областей
	EventBus.area_buttons_visibility_changed.emit(true)
	
	# Обновляем визуальное отображение сердечек
	var is_active = heart_bar.is_active_mode() if heart_bar else (survival_ui.is_active if survival_ui else false)
	var lives = heart_bar.get_lives() if heart_bar else (survival_ui.get_lives() if survival_ui else 7)
	if is_active:
		if survival_ui:
			survival_ui.show()
	else:
		if survival_ui:
			survival_ui.hide()

	DebugLogger.log("♻️  Состояние игры восстановлено: rounds=%d, lives=%d, active=%s" % [
		survival_rounds_completed, lives, is_active
	])


func _check_and_handle_game_over() -> bool:
	"""Проверка Game Over в режиме выживания
	
	Returns:
		true если Game Over произошёл, false если игра продолжается
	"""
	var is_active = heart_bar.is_active_mode() if heart_bar else (survival_ui.is_active if survival_ui else false)
	var lives = heart_bar.get_lives() if heart_bar else (survival_ui.get_lives() if survival_ui else 7)
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
		if is_survival_mode:
			survival_rounds_completed += 1
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

func _on_arrows_visibility_changed(should_show: bool):
	"""Обработчик изменения видимости стрелок"""
	var left_arrow = get_node_or_null("TopUI/LeftArrowButton")
	var right_arrow = get_node_or_null("TopUI/RightArrowButton")
	var up_arrow = get_node_or_null("TopUI/UpArrowButton")
	var down_arrow = get_node_or_null("TopUI/DownArrowButton")

	if left_arrow:
		left_arrow.visible = should_show
	if right_arrow:
		right_arrow.visible = should_show
	if up_arrow:
		up_arrow.visible = should_show
	if down_arrow:
		down_arrow.visible = should_show

	if should_show:
		_update_arrows_state()

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



func _on_payout_setting_changed(bet_type: String, enabled: bool):
	"""Обработка изменения настроек выплат из SettingsScene"""
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

func _on_card_back_style_changed(style: String):
	"""Обработка изменения стиля рубашки карт из SettingsScene

	Args:
		style: "tiger" или "leopard"
	"""
	if not ui_manager:
		return

	# Обновляем все рубашки карт на столе
	ui_manager.update_all_card_backs()

	DebugLogger.log("🎴 Стиль рубашки карт изменён: %s" % style)


func _on_position_mode_changed(_mode: int):
	"""Обработка изменения режима позиций фишек из SettingsScene

	Args:
		mode: 0=DEFAULT, 1=RANDOM, 2=MAX, 3=REALISTIC
	"""
	if not chip_visual_manager:
		return

	# Режим всегда GUEST
	chip_visual_manager.set_position_mode(ChipVisualManager.PositionMode.GUEST)
	DebugLogger.log("🎲 Режим позиций фишек: GUEST (гости)")

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



func _on_guest_settings_changed(guest_id: int) -> void:
	"""Настройки гостя изменились - очищаем его фишки если отключён"""
	if not GuestSettingsManager.is_guest_enabled(guest_id):
		# ═══════════════════════════════════════════════════════════════════
		# ЗАЩИТА: Не очищаем ставки во время раздачи
		# Ставки можно удалять ТОЛЬКО в состоянии WAITING (до начала раздачи)
		# Во всех остальных состояниях (включая CHOOSE_WINNER) ставки остаются
		# до полного завершения раунда (сбор/оплата всех ставок)
		# ═══════════════════════════════════════════════════════════════════
		var current_state = GameStateManager.get_current_state()
		if current_state != GameStateManager.GameState.WAITING:
			print("👥 Гость %d отключён, но идёт раздача (состояние: %s) - ставки останутся до конца раунда" % [guest_id, GameStateManager.get_state_name(current_state)])
			# НЕ очищаем ставки из хранилища и НЕ скрываем визуальные фишки
			# Ставки останутся видимыми и будут использованы в текущей раздаче
			# В следующей раздаче ставки не будут сгенерированы (гость отключен)
			return
		
		print("👥 Гость %d отключён - очищаем его фишки" % guest_id)
		# Очищаем фишки этого гостя из хранилища
		if phase_manager and phase_manager.guest_bet_storage:
			phase_manager.guest_bet_storage.clear_guest_bets(guest_id)
		# Скрываем визуальные фишки этого гостя
		if chip_visual_manager:
			chip_visual_manager.clear_guest_chips_for_sector(guest_id)


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


func _on_guest_bets_hide_requested() -> void:
	"""Скрыть ставки гостей при выборе сердца для Heart Bet"""
	# ВАЖНО: Сначала сохраняем ставки в backup, затем скрываем
	if phase_manager and phase_manager.guest_bet_storage:
		phase_manager.guest_bet_storage.backup_all_bets()
		# Очищаем текущие ставки (чтобы они не показывались в Heart Bet раунде)
		phase_manager.guest_bet_storage.clear_all_bets()
	
	if chip_visual_manager:
		chip_visual_manager.hide_all_guest_chips()
		print("❤️ GameController: ставки гостей скрыты и сохранены в backup")


func _on_guest_bets_show_requested() -> void:
	"""Показать ставки гостей после завершения Heart Bet раздачи"""
	# ВАЖНО: Используем _show_guest_bets() вместо show_all_guest_chips(),
	# потому что фишки (узлы) могли быть удалены во время Heart Bet раунда
	if phase_manager:
		phase_manager._show_guest_bets()
		print("❤️ GameController: фишки ставок гостей пересозданы")


func _on_heart_bet_declined() -> void:
	"""Обработчик отказа от карты Heart Bet - восстанавливаем ставки"""
	# Восстанавливаем ставки гостей из backup (если был backup)
	if phase_manager and phase_manager.guest_bet_storage:
		phase_manager.guest_bet_storage.restore_all_bets()
	
	# Пересоздаём фишки ставок гостей
	# ВАЖНО: Используем _show_guest_bets() вместо show_all_guest_chips(),
	# потому что фишки (узлы) могли быть удалены
	if phase_manager:
		phase_manager._show_guest_bets()
		print("❤️ GameController: фишки ставок гостей пересозданы после отказа от карты")


func _on_heart_bet_round_complete() -> void:
	"""Завершение Heart Bet раздачи - сброс без выплат

	После Heart Bet раздачи игра возвращается в состояние ожидания.
	Выплаты не производятся (это была особая раздача на жизнь).
	"""
	# #region agent log
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H4","location":"GameController._on_heart_bet_round_complete","message":"round complete received","data":{},"timestamp":%d}' % [int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	print("❤️ GameController: Heart Bet раздача завершена, сбрасываем раунд без выплат")
	
	# Разблокируем маркеры (если были заблокированы)
	if winner_selection_manager:
		winner_selection_manager.unlock_markers()
		winner_selection_manager.reset()
	
	# Небольшая задержка чтобы увидеть результат
	await get_tree().create_timer(1.5).timeout
	
	# Зум камеры на общий план
	EventBus.camera_zoom_requested.emit("out")
	
	
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
		print("❤️ Проверка триггеров после Heart Bet раунда: %s" % ("сработал!" if new_trigger_available else "нет"))
	if phase_manager:
		# Сбрасываем флаг Heart Bet раунда
		phase_manager.was_heart_bet_round = false
		# При Tie draw НЕ сохраняем ставки гостей
		phase_manager.reset(true, not was_tie_draw)  # update_state=true, keep_guest_bets=!was_tie_draw
		phase_manager.is_table_prepared = true  # Готовы к новой раздаче
		print("❤️ Раунд сброшен, готов к новой раздаче (Tie draw: %s)" % was_tie_draw)
	
	# Восстанавливаем ставки гостей из backup (если был backup)
	if phase_manager and phase_manager.guest_bet_storage:
		phase_manager.guest_bet_storage.restore_all_bets()
	
	# Восстанавливаем ФИШКИ ставок гостей ТОЛЬКО если НЕ было Tie draw
	# ВАЖНО: Используем _show_guest_bets() вместо show_all_guest_chips(),
	# потому что фишки (узлы) могли быть удалены во время Heart Bet раунда
	if not was_tie_draw and phase_manager:
		phase_manager._show_guest_bets()
		print("❤️ Фишки ставок гостей пересозданы")
	elif was_tie_draw:
		print("❤️ Tie draw: ставки гостей НЕ показываются, игра переходит к новой раздаче")
	
	
	# ═══════════════════════════════════════════════════════════════════
	# HEART BET: Автоматический показ сердец УБРАН!
	# Карта шанса уже видна (если есть шансы), игрок сам нажмёт когда захочет
	# ═══════════════════════════════════════════════════════════════════
	if phase_manager and phase_manager.heart_bet_manager:
		var chances = phase_manager.heart_bet_manager.get_chance_count()
		if chances > 0:
			print("❤️ Шансов доступно: %d (игрок может использовать карту)" % chances)


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
	"""Обработчик клика на конкретную фишку (с position_index)"""
	print("🔴 _on_chip_instance_clicked ВЫЗВАН: %s[%d]" % [bet_type, position_index])
	
	# ═══════════════════════════════════════════════════════════════════
	# ЗАЩИТА: Блокировка во время обработки выплаты (защита от спама Space)
	# ═══════════════════════════════════════════════════════════════════
	print("🔍 Проверка is_payout_processing: %s" % is_payout_processing)
	if is_payout_processing:
		DebugLogger.log("⏸️  Клик на %s[%d] заблокирован (идёт обработка выплаты)" % [bet_type, position_index])
		return
	
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
			return
	
	# Проверяем что менеджеры инициализированы
	print("🔍 Проверка менеджеров: payout_queue_manager=%s, bet_collection_manager=%s" % [payout_queue_manager != null, bet_collection_manager != null])
	if not payout_queue_manager or not bet_collection_manager:
		print("🔍 ВЫХОД: менеджеры не инициализированы")
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА: Ставка должна быть в очереди выплат
	# Если ставки нет в очереди - игнорируем клик (ставка отключена фильтром)
	# ═══════════════════════════════════════════════════════════════════
	var bet_in_queue = payout_queue_manager.get_bet_by_id(bet_type, position_index)
	DebugLogger.log("🔍 Поиск ставки в очереди: %s[%d] → %s" % [bet_type, position_index, "найдена" if bet_in_queue else "не найдена"])
	if not bet_in_queue:
		# Пробуем найти по типу (для обратной совместимости)
		bet_in_queue = payout_queue_manager.get_bet_by_type(bet_type)
		DebugLogger.log("🔍 Fallback поиск по типу: %s → %s" % [bet_type, "найдена" if bet_in_queue else "не найдена"])
	
	if not bet_in_queue:
		# Ставки нет в очереди - игнорируем клик без ошибки
		# Это нормально, если ставка была отключена фильтром
		DebugLogger.log("  ⏸️  Ставка %s[%d] не найдена в очереди выплат - игнорируем клик" % [bet_type, position_index])
		# Логируем все ставки в очереди для отладки
		DebugLogger.log("  📋 Все ставки в очереди:")
		for bet in payout_queue_manager.get_all_bets():
			DebugLogger.log("    → %s[%d], won=%s, collected=%s" % [bet.get_bet_type(), bet.get_position_index(), bet.is_won(), bet.is_collected()])
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА: В режиме GUEST игнорируем клики на фишки неактивных гостей
	# ИСПРАВЛЕНИЕ: Используем сектор из ставки, а не определяем по position_index
	# ═══════════════════════════════════════════════════════════════════
	if phase_manager and phase_manager.guest_bet_storage:
		# Определяем сектор: сначала из ставки (если она гостевая), иначе по position_index
		var sector = -1
		if bet_in_queue and bet_in_queue.get_sector() >= 1 and bet_in_queue.get_sector() <= 6:
			# Используем сектор из ставки (правильный способ)
			sector = bet_in_queue.get_sector()
			DebugLogger.log("🔍 Сектор из ставки: %s[%d] → сектор %d (из bet.get_sector())" % [bet_type, position_index, sector])
		else:
			# Fallback: определяем по position_index (может быть неточным для Banker[9])
			sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
			DebugLogger.log("🔍 Сектор по position_index: %s[%d] → сектор %d (fallback)" % [bet_type, position_index, sector])
		
		if sector >= 1 and sector <= 6:
			# Это гостевой сектор - проверяем есть ли активный гость
			var guest_id = sector
			var guest_bets = phase_manager.guest_bet_storage.get_guest_bets(guest_id)
			DebugLogger.log("🔍 Гость %d: найдено %d ставок" % [guest_id, guest_bets.size()])
			if guest_bets.is_empty():
				# Гость не включён или нет ставок - игнорируем клик
				DebugLogger.log_warning("⚠️ Клик на фишку %s[%d] в секторе %d, но гостя %d нет или он не включён - игнорируем" % [bet_type, position_index, sector, guest_id])
				return
			else:
				# Логируем все ставки гостя для отладки
				for bet in guest_bets:
					DebugLogger.log("  → Ставка гостя %d: %s[%d], won=%s, collected=%s" % [guest_id, bet.get_bet_type(), bet.get_position_index(), bet.is_won(), bet.is_collected()])
	
	# ═══════════════════════════════════════════════════════════════════
	# ВАЛИДАЦИЯ КЛИКА ЧЕРЕЗ BetCollectionPhaseManager
	# ═══════════════════════════════════════════════════════════════════
	DebugLogger.log("🔍 Валидация клика через BetCollectionPhaseManager: %s[%d]" % [bet_type, position_index])
	var validation = bet_collection_manager.validate_chip_click(bet_type, position_index)
	DebugLogger.log("🔍 Результат валидации: action=%s, can_proceed=%s, error_type=%s" % [validation.get("action", "unknown"), validation.get("can_proceed", false), validation.get("error_type", "")])
	
	# Если режим не выбран - ничего не делаем
	if validation.action == "none" and validation.can_proceed:
		DebugLogger.log("  ⏸️  Режим не выбран, клик игнорируется")
		return
	
	# Если ошибка валидации - показываем сообщение и штрафуем
	if not validation.can_proceed:
		# "already_collected" - это не ошибка игрока, а техническая ситуация (двойной клик)
		# Просто игнорируем без тоста и без отнятия жизни
		if validation.error_type == "already_collected":
			DebugLogger.log("  ⏸️  Ставка %s[%d] уже собрана, клик игнорируется" % [bet_type, position_index])
			return
		
		# Для ошибки "collect_winning" - увеличиваем терпение гостя
		if validation.error_type == "collect_winning":
			var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
			if sector >= 1 and sector <= 6:
				var guest_id = sector
				GuestStatsManager.add_patience(guest_id, 5)
				DebugLogger.log("  😤 Гость %d: терпение увеличено на 5 из-за попытки собрать выигрышную ставку %s[%d]" % [guest_id, bet_type, position_index])
		
		# Для остальных ошибок - показываем тост и отнимаем жизнь
		var error_message = Localization.t(validation.error_message) if validation.error_message.begins_with("ERR_") else validation.error_message
		EventBus.show_toast_error.emit(error_message)
		EventBus.action_error.emit(validation.error_type, error_message)
		DebugLogger.log("  ❌ Ошибка: %s" % validation.error_message)
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# ВЫПОЛНЕНИЕ ДЕЙСТВИЯ
	# ═══════════════════════════════════════════════════════════════════
	
	if validation.action == "collect":
		# Собираем проигрышную ставку
		bet_collection_manager.collect_bet(bet_type, position_index)
		
		# Обновляем баланс гостя при сборе проигрышной ставки
		_update_guest_balance_on_collect(bet_type, position_index)
		
		# Скрываем конкретную фишку по position_index (работает для всех режимов)
		if chip_visual_manager:
			chip_visual_manager.hide_chip_instance(bet_type, position_index)
		DebugLogger.log("  ✅ Ставка %s[%d] собрана" % [bet_type, position_index])
		
		# Если кнопка "Завершить" была broken - восстанавливаем
		if ui_manager.button_ui.is_action_button_broken():
			ui_manager.enable_action_button()
			DebugLogger.log("  🔓 Кнопка 'Завершить' восстановлена")
		return
	
	if validation.action == "pay":
		# Оплачиваем выигрышную ставку
		var bet = payout_queue_manager.get_bet_by_id(bet_type, position_index)
		if not bet:
			# Для обратной совместимости пробуем по типу
			bet = payout_queue_manager.get_bet_by_type(bet_type)
		if not bet:
			return
		
		# ═══════════════════════════════════════════════════════════════════
		# ПЕРЕКЛЮЧАТЕЛЬ РЕЖИМА ВЫПЛАТ
		# ═══════════════════════════════════════════════════════════════════
		if USE_OVERLAY_PAYOUT:
			# НОВЫЙ СПОСОБ: показать overlay поверх Game.tscn
			_show_payout_overlay_instance(bet_type, position_index, bet.get_stake(), bet.get_payout())
		else:
			# СТАРЫЙ СПОСОБ: переход к PayoutScene (scene transition)
			_open_payout_scene(bet_type)
		return


func _show_payout_overlay_instance(bet_type: String, position_index: int, stake: float, payout: float):
	"""Показать PayoutOverlay для конкретной фишки
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции фишки
		stake: Размер ставки
		payout: Ожидаемая выплата
	"""
	if not payout_overlay:
		push_error("❌ PayoutOverlay не найден! Проверьте Game.tscn")
		return
	
	# ЗАЩИТА: Блокируем обработку других кликов пока открыт PayoutOverlay
	is_payout_processing = true

	DebugLogger.log("💰 Показываем PayoutOverlay: %s[%d], stake=%.1f, payout=%.1f" % [bet_type, position_index, stake, payout])

	# Сохраняем position_index для обработчика завершения
	# (пока используем простой способ - храним в метаданных контекста)
	payout_overlay.set_meta("current_position_index", position_index)

	# Передаём состояние игры через параметры (вместо get_parent())
	var lives = heart_bar.get_lives() if heart_bar else (survival_ui.get_lives() if survival_ui else 7)
	payout_overlay.show_payout(bet_type, stake, payout, is_survival_mode, lives)

func _open_payout_scene(bet_type: String):
	"""Открыть PayoutScene для конкретной ставки

	Использует TableStateManager для полного сохранения состояния стола

	Args:
		bet_type: Тип ставки ("main"/"player_pair"/"banker_pair")
	"""
	# Получаем данные ставки из TableStateManager
	var bet_data = TableStateManager.get_bet_data(bet_type)
	if not bet_data:
		push_error("❌ _open_payout_scene: ставка %s не найдена в TableStateManager" % bet_type)
		return

	DebugLogger.log("💰 Открываем PayoutScene для %s: stake=%.1f, payout=%.1f" % [bet_type, bet_data.get_stake(), bet_data.get_payout()])

	# Устанавливаем данные в GameDataManager (PayoutScene читает данные оттуда)
	GameDataManager.set_payout_data(
		bet_type,
		bet_data.get_stake(),
		bet_data.get_payout(),
		0,  # player_score (не используется в ручном режиме)
		0   # banker_score (не используется в ручном режиме)
	)
	DebugLogger.log("  → Установлены данные в GameDataManager: winner=%s, stake=%.1f, amount=%.1f" % [bet_type, bet_data.get_stake(), bet_data.get_payout()])

	# Устанавливаем контекст для PayoutScene через старый PayoutContextManager (для совместимости)
	PayoutContextManager.set_context({
		"bet_type": bet_type,
		"stake": bet_data.get_stake(),
		"expected_payout": bet_data.get_payout(),
		"return_to_game": true,
		"manual_mode": true
	})

	# Передаем состояние режима выживания в GameDataManager
	DebugLogger.log("🔍 DEBUG _open_payout_scene:")
	DebugLogger.log("  → is_survival_mode = %s" % is_survival_mode)
	DebugLogger.log("  → survival_ui exists = %s" % (survival_ui != null))
	if survival_ui:
		var lives = heart_bar.get_lives() if heart_bar else survival_ui.get_lives()
		DebugLogger.log("  → survival_ui.current_lives = %d" % lives)
	DebugLogger.log("  → GameDataManager.survival_lives (before) = %d" % GameDataManager.get_survival_lives())

	var surv_lives = 7  # Значение по умолчанию
	if is_survival_mode and survival_ui:
		# Режим выживания активен - берем текущее количество жизней
		surv_lives = heart_bar.get_lives() if heart_bar else survival_ui.get_lives()
		DebugLogger.log("  → Берем из survival_ui: %d" % surv_lives)
	elif is_survival_mode:
		# Режим выживания активен, но survival_ui не инициализирован - берем из GameDataManager
		surv_lives = GameDataManager.get_survival_lives()
		DebugLogger.log("  → Берем из GameDataManager: %d" % surv_lives)
	else:
		DebugLogger.log("  → Используем значение по умолчанию: %d" % surv_lives)

	GameDataManager.set_game_state(
		survival_rounds_completed,
		surv_lives,
		is_survival_mode
	)
	DebugLogger.log("  → ✅ Установлено состояние игры: rounds=%d, lives=%d, survival=%s" % [survival_rounds_completed, surv_lives, is_survival_mode])

	# Переходим к PayoutScene
	get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")


# ═══════════════════════════════════════════════════════════════════════════
# OVERLAY РЕЖИМ ВЫПЛАТ (новая логика)
# ═══════════════════════════════════════════════════════════════════════════

func _show_payout_overlay(bet_type: String, stake: float, payout: float):
	"""Показать PayoutOverlay с параметрами выплаты (новый способ)

	Вызывается при клике на фишку в overlay режиме (USE_OVERLAY_PAYOUT=true).
	Game.tscn остается в памяти, overlay показывается поверх.

	Args:
		bet_type: Тип ставки ("Player"/"Banker"/"Tie"/"PairPlayer"/"PairBanker")
		stake: Размер ставки
		payout: Ожидаемая выплата
	"""
	if not payout_overlay:
		push_error("❌ PayoutOverlay не найден! Проверьте Game.tscn")
		return

	DebugLogger.log("💰 Показываем PayoutOverlay (overlay режим): %s, stake=%.1f, payout=%.1f" % [bet_type, stake, payout])

	# Вызываем метод show_payout() из PayoutOverlay.gd
	# Overlay сам управляет UI, фишками и валидацией

	# Передаём состояние игры через параметры (вместо get_parent())
	var lives = heart_bar.get_lives() if heart_bar else (survival_ui.get_lives() if survival_ui else 7)
	payout_overlay.show_payout(bet_type, stake, payout, is_survival_mode, lives)


func _on_payout_overlay_completed(bet_type: String, is_correct: bool, collected: float, expected: float):
	"""Обработчик завершения выплаты в overlay режиме

	Вызывается когда PayoutOverlay эмитит сигнал payout_completed.
	Обрабатывает результат (правильно/неправильно) и управляет переходом к следующей выплате.

	Args:
		bet_type: Тип ставки ("Player"/"Banker"/"Tie"/"PairPlayer"/"PairBanker")
		is_correct: Правильная ли выплата
		collected: Собранная сумма
		expected: Ожидаемая сумма
	"""
	# Получаем position_index из метаданных (устанавливается в _show_payout_overlay_instance)
	var position_index = 0
	if payout_overlay and payout_overlay.has_meta("current_position_index"):
		position_index = payout_overlay.get_meta("current_position_index")
	
	DebugLogger.log("💰 Завершена выплата в overlay режиме: bet_type=%s[%d], correct=%s, collected=%.1f, expected=%.1f" % [bet_type, position_index, is_correct, collected, expected])

	# ═══════════════════════════════════════════════════════════════════
	# ОБРАБОТКА РЕЗУЛЬТАТА (эмитим события как в старом режиме)
	# ═══════════════════════════════════════════════════════════════════
	if is_correct:
		EventBus.payout_correct.emit(collected, expected, bet_type, position_index)
		DebugLogger.log("  ✅ Правильная выплата %s[%d]: %.1f" % [bet_type, position_index, expected])

		# ═══════════════════════════════════════════════════════════════════
		# ОБНОВЛЕНИЕ БАЛАНСА ГОСТЯ (если это гостевые ставки)
		# ═══════════════════════════════════════════════════════════════════
		_update_guest_balance_for_bet(bet_type, position_index, expected)

		# ═══════════════════════════════════════════════════════════════════
		# ВАЖНО: pay_bet() сам вызывает mark_as_paid() внутри
		# НЕ вызываем mark_as_paid() отдельно, иначе pay_bet() выйдет раньше
		# и не обновит payment_progress!
		# ═══════════════════════════════════════════════════════════════════
		if bet_collection_manager:
			# pay_bet() автоматически:
			# 1. Помечает ставку как оплаченную (mark_as_paid)
			# 2. Обновляет payment_progress[group]
			# 3. Проверяет порядок оплаты
			if bet_collection_manager.pay_bet(bet_type, position_index):
				DebugLogger.log("  ✅ Ставка %s[%d] оплачена через BetCollectionPhaseManager" % [bet_type, position_index])
			else:
				DebugLogger.log_error("  ❌ Не удалось оплатить ставку %s[%d] через BetCollectionPhaseManager" % [bet_type, position_index])

		# Скрываем конкретную фишку по position_index (работает для всех режимов)
		if chip_visual_manager:
			chip_visual_manager.hide_chip_instance(bet_type, position_index)
			DebugLogger.log("  🎨 Фишка %s[%d] скрыта" % [bet_type, position_index])

		# Увеличиваем счетчик раундов в survival mode
		if is_survival_mode:
			survival_rounds_completed += 1
			DebugLogger.log("  🎮 Survival: раунд %d завершен" % survival_rounds_completed)
	else:
		EventBus.payout_wrong.emit(collected, expected, bet_type, position_index)
		DebugLogger.log("  ❌ Неправильная выплата %s[%d]: собрано=%.1f, ожидалось=%.1f" % [bet_type, position_index, collected, expected])

		# Потеря жизни обрабатывается через EventBus в SurvivalUI
		# (EventBus.payout_wrong → SurvivalUI.lose_life)

	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА ОСТАВШИХСЯ ВЫПЛАТ
	# ═══════════════════════════════════════════════════════════════════
	# TODO: Если есть еще неоплаченные выплаты - можно автоматически показать следующую
	# Пока оставляем ручной режим - пользователь кликает на следующую фишку

	# ═══════════════════════════════════════════════════════════════════
	# ЗАВЕРШЕНИЕ РАУНДА (если все выплаты оплачены И последняя правильная)
	# ═══════════════════════════════════════════════════════════════════
	if is_correct:
		# После оплаты ставки всегда активируем кнопку "Завершить"
		# Проверка неоплаченных ставок будет при нажатии на кнопку
		if ui_manager:
			ui_manager.enable_action_button()
			DebugLogger.log("  🔓 Кнопка 'Завершить' активирована после оплаты ставки")

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

func _update_guest_balance_for_bet(bet_type: String, position_index: int, payout: float) -> void:
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

func _update_guest_balance_on_collect(bet_type: String, position_index: int) -> void:
	"""Обновить баланс гостя при сборе проигрышной ставки
	
	При сборе проигрышной ставки вычитаем stake из баланса гостя
	
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
			# Вычитаем stake (проигрыш)
			GuestStatsManager.subtract_from_balance(guest_id, bet.get_stake())
			DebugLogger.log("💰 Гость %d: баланс обновлён (-%.0f за проигрыш)" % [guest_id, bet.get_stake()])
			return
	
	DebugLogger.log_warning("⚠️ Не найдена ставка гостя для %s[%d] в секторе %d" % [bet_type, position_index, sector])


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
