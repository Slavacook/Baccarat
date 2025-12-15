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
# UI КОМПОНЕНТЫ
# ═══════════════════════════════════════════════════════════════════════════

var settings_scene: CanvasLayer
var settings_button: Button
var survival_ui: Control
var game_over_popup: CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ИГРЫ
# ═══════════════════════════════════════════════════════════════════════════

var survival_rounds_completed: int = 0
var is_survival_mode: bool = false
var is_table_prepared_for_new_game: bool = false

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
	
	# Блокируем маркеры, чтобы игрок не мог случайно изменить выбор во время выплат
	if winner_selection_manager:
		winner_selection_manager.lock_markers()
	
	# Пауза 1 секунда (карты остаются открытыми, маркер активен)
	await get_tree().create_timer(GameConstants.VICTORY_TOAST_DELAY).timeout
	
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
	
	Args:
		actual: Фактический победитель
		player_score: Очки игрока
		banker_score: Очки банкира
	"""
	if not PayoutSettingsManager.is_payout_enabled(actual):
		return
	
	var stake: float = 0.0
	var payout: float = 0.0
	
	if actual == "Banker":
		stake = limits_manager.generate_bet()
		var commission = GameModeManager.get_banker_commission()
		if GameModeManager.get_mode_string() == "classic":
			var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
			if banker_value == 6:
				commission = 0.5
		payout = stake * commission
	elif actual == "Tie":
		stake = limits_manager.generate_tie_bet()
		payout = stake * 8.0
	else:  # Player
		stake = limits_manager.generate_bet()
		payout = stake * 1.0
	
	GameDataManager.add_to_payout_queue(actual, stake, payout, player_score, banker_score)


func _add_pair_bets_to_queue(player_score: int, banker_score: int) -> void:
	"""Добавление ставок на пары в очередь выплат
	
	Args:
		player_score: Очки игрока
		banker_score: Очки банкира
	"""
	# Пара игрока - если обнаружена И ставка была
	if pair_betting_manager.player_pair_detected and pair_betting_manager.pair_player_bet_enabled:
		var stake = limits_manager.generate_pair_bet()
		var payout = pair_betting_manager.calculate_pair_payout(stake, "PairPlayer")
		GameDataManager.add_to_payout_queue("PairPlayer", stake, payout, player_score, banker_score)
	
	# Пара банкира - если обнаружена И ставка была
	if pair_betting_manager.banker_pair_detected and pair_betting_manager.pair_banker_bet_enabled:
		var stake = limits_manager.generate_pair_bet()
		var payout = pair_betting_manager.calculate_pair_payout(stake, "PairBanker")
		GameDataManager.add_to_payout_queue("PairBanker", stake, payout, player_score, banker_score)


func _process_payout_queue_or_reset() -> void:
	"""Обработка очереди выплат или сброс раунда (если очередь пуста)"""
	if GameDataManager.has_more_payouts():
		# Есть выплаты → берём первую и переходим в PayoutScene
		var next_payout = GameDataManager.get_next_payout()
		
		# Сохраняем данные для PayoutScene
		GameDataManager.set_payout_data(
			next_payout.bet_type,
			next_payout.stake,
			next_payout.payout,
			next_payout.player_score,
			next_payout.banker_score
		)
		
		# Сохраняем состояние игры (сердечки, раунды)
		GameDataManager.set_game_state(
			survival_rounds_completed,
			survival_ui.current_lives,
			survival_ui.is_active
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

	Создает payout_queue_manager с информацией о всех ставках:
	- Выигравшие ставки (won=true, is_paid=false)
	- Проигравшие ставки (won=false)

	В REALISTIC режиме создает множественные ставки со случайным количеством.
	Делает фишки выигравших ставок кликабельными.
	"""
	var player_score = BaccaratRules.hand_value(hand_manager.get_player_hand_ref())
	var banker_score = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())

	# Создаем новый payout_queue_manager
	payout_queue_manager = PayoutQueueManager.new()
	
	# ВАЖНО: Обновляем ссылку в phase_manager
	phase_manager.payout_queue_manager = payout_queue_manager
	DebugLogger.log_init("Создан новый PayoutQueueManager, ссылка обновлена в phase_manager")
	
	# ← Настраиваем менеджер фазы сбора/оплаты с информацией о победителе (БЕЗ инициализации последовательностей)
	bet_collection_manager.payout_queue_manager = payout_queue_manager
	bet_collection_manager.actual_winner = actual_winner
	bet_collection_manager.collected_losing_bets.clear()
	bet_collection_manager.collected_bets_by_id.clear()
	bet_collection_manager.current_mode = BetCollectionPhaseManager.CollectionMode.NONE
	
	# Показываем кнопки collect/pay (они уже должны быть показаны из GamePhaseManager,
	# но на всякий случай показываем снова)
	ui_manager.button_ui.show_collect_pay_buttons()

	# ═══════════════════════════════════════════════════════════════════
	# ПРОВЕРКА РЕЖИМА REALISTIC
	# ═══════════════════════════════════════════════════════════════════
	var is_realistic = PayoutSettingsManager.is_realistic_mode_enabled()
	
	if is_realistic:
		_prepare_payouts_realistic(actual_winner, player_score, banker_score)
	else:
		_prepare_payouts_standard(actual_winner, player_score, banker_score)

	# Выводим статус очереди
	payout_queue_manager.print_status()
	
	# ⚠️ ВАЖНО: Инициализируем последовательности ПОСЛЕ добавления всех ставок
	bet_collection_manager.initialize_sequences()
	DebugLogger.log("✅ BetCollectionPhaseManager: настроен для раунда (победитель: %s)" % actual_winner)
	
	# Завершаем подготовку - обновляем видимость и сохраняем состояние
	_finalize_payouts_manual(actual_winner)


func _prepare_payouts_standard(actual_winner: String, player_score: int, banker_score: int) -> void:
	"""Стандартная подготовка выплат (DEFAULT, RANDOM, MAX режимы)"""
	
	var is_max_mode = PayoutSettingsManager.get_position_mode() == PayoutSettingsManager.PositionMode.MAX
	
	# 1. Основные ставки (Player/Banker/Tie)
	# Player
	if PayoutSettingsManager.player_payout_enabled:
		var won = (actual_winner == "Player")
		var stake = limits_manager.generate_bet()
		var payout = stake * 1.0 if won else 0.0
		
		if is_max_mode:
			# В MAX режиме добавляем ставку для каждой позиции
			var positions = ChipVisualManager.ALTERNATIVE_POSITIONS.get("Player", [])
			for pos_idx in range(positions.size()):
				payout_queue_manager.add_bet("Player", stake, payout, won, player_score, banker_score, pos_idx)
		else:
			payout_queue_manager.add_bet("Player", stake, payout, won, player_score, banker_score, 0)

	# Banker
	if PayoutSettingsManager.banker_payout_enabled:
		var won = (actual_winner == "Banker")
		var stake = limits_manager.generate_bet()
		var payout = 0.0
		if won:
			var commission = GameModeManager.get_banker_commission()
			if GameModeManager.get_mode_string() == "classic":
				var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
				if banker_value == 6:
					commission = 0.5
			payout = stake * commission
			DebugLogger.log("🏦 Banker выиграл: stake=%.1f, commission=%.2f, payout=%.1f" % [stake, commission, payout])
		else:
			DebugLogger.log("🏦 Banker проиграл: stake=%.1f, payout=0" % stake)
		
		if is_max_mode:
			# В MAX режиме добавляем ставку для каждой позиции
			var positions = ChipVisualManager.ALTERNATIVE_POSITIONS.get("Banker", [])
			for pos_idx in range(positions.size()):
				payout_queue_manager.add_bet("Banker", stake, payout, won, player_score, banker_score, pos_idx)
		else:
			payout_queue_manager.add_bet("Banker", stake, payout, won, player_score, banker_score, 0)

	# Tie
	if PayoutSettingsManager.tie_payout_enabled:
		var won = (actual_winner == "Tie")
		var stake = limits_manager.generate_tie_bet()
		var payout = stake * 8.0 if won else 0.0
		
		if is_max_mode:
			# В MAX режиме добавляем ставку для каждой позиции
			var positions = ChipVisualManager.ALTERNATIVE_POSITIONS.get("Tie", [])
			for pos_idx in range(positions.size()):
				payout_queue_manager.add_bet("Tie", stake, payout, won, player_score, banker_score, pos_idx)
		else:
			payout_queue_manager.add_bet("Tie", stake, payout, won, player_score, banker_score, 0)

	# 2. Ставки на пары
	if pair_betting_manager:
		# Pair Player
		if pair_betting_manager.pair_player_bet_enabled:
			var won = pair_betting_manager.player_pair_detected
			var stake = limits_manager.generate_pair_bet()
			var payout = pair_betting_manager.calculate_pair_payout(stake, "PairPlayer") if won else 0.0
			
			if is_max_mode:
				# В MAX режиме добавляем ставку для каждой позиции
				var positions = ChipVisualManager.ALTERNATIVE_POSITIONS.get("PairPlayer", [])
				for pos_idx in range(positions.size()):
					payout_queue_manager.add_bet("PairPlayer", stake, payout, won, player_score, banker_score, pos_idx)
			else:
				payout_queue_manager.add_bet("PairPlayer", stake, payout, won, player_score, banker_score, 0)

		# Pair Banker
		if pair_betting_manager.pair_banker_bet_enabled:
			var won = pair_betting_manager.banker_pair_detected
			var stake = limits_manager.generate_pair_bet()
			var payout = pair_betting_manager.calculate_pair_payout(stake, "PairBanker") if won else 0.0
			
			if is_max_mode:
				# В MAX режиме добавляем ставку для каждой позиции
				var positions = ChipVisualManager.ALTERNATIVE_POSITIONS.get("PairBanker", [])
				for pos_idx in range(positions.size()):
					payout_queue_manager.add_bet("PairBanker", stake, payout, won, player_score, banker_score, pos_idx)
			else:
				payout_queue_manager.add_bet("PairBanker", stake, payout, won, player_score, banker_score, 0)
	else:
		push_warning("⚠️  pair_betting_manager is null в _prepare_payouts_standard")


func _prepare_payouts_realistic(actual_winner: String, player_score: int, banker_score: int) -> void:
	"""Подготовка выплат в REALISTIC режиме со случайным количеством ставок"""
	
	DebugLogger.log_bet("REALISTIC режим: генерируем случайные ставки...")
	
	# Очищаем все активные фишки перед созданием новых
	if chip_visual_manager:
		chip_visual_manager.clear_all_active_chips()
	
	# Генерируем ставки для каждого типа
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	
	for bet_type in bet_types:
		# Проверяем, включена ли ставка
		var is_enabled = false
		match bet_type:
			"Player":
				is_enabled = PayoutSettingsManager.player_payout_enabled
			"Banker":
				is_enabled = PayoutSettingsManager.banker_payout_enabled
			"Tie":
				is_enabled = PayoutSettingsManager.tie_payout_enabled
			"PairPlayer":
				is_enabled = pair_betting_manager and pair_betting_manager.pair_player_bet_enabled
			"PairBanker":
				is_enabled = pair_betting_manager and pair_betting_manager.pair_banker_bet_enabled
		
		if not is_enabled:
			continue
		
		# Определяем выиграла ли ставка этого типа
		var won = false
		match bet_type:
			"Player":
				won = (actual_winner == "Player")
			"Banker":
				won = (actual_winner == "Banker")
			"Tie":
				won = (actual_winner == "Tie")
			"PairPlayer":
				won = pair_betting_manager.player_pair_detected if pair_betting_manager else false
			"PairBanker":
				won = pair_betting_manager.banker_pair_detected if pair_betting_manager else false
		
		# Создаём фишки в REALISTIC режиме
		var created_chips = chip_visual_manager.show_chips_realistic(bet_type)
		
		# Для каждой созданной фишки добавляем ставку в очередь
		for chip_instance in created_chips:
			var stake = _generate_stake_for_bet_type(bet_type)
			var payout = _calculate_payout_for_bet_type(bet_type, stake, won)
			
			payout_queue_manager.add_bet(
				bet_type, 
				stake, 
				payout, 
				won, 
				player_score, 
				banker_score, 
				chip_instance.position_index
			)
		
		DebugLogger.log("  %s: создано %d ставок (won=%s)" % [bet_type, created_chips.size(), won])


func _generate_stake_for_bet_type(bet_type: String) -> float:
	"""Генерация размера ставки для типа"""
	match bet_type:
		"Tie":
			return limits_manager.generate_tie_bet()
		"PairPlayer", "PairBanker":
			return limits_manager.generate_pair_bet()
		_:  # Player, Banker
			return limits_manager.generate_bet()


func _calculate_payout_for_bet_type(bet_type: String, stake: float, won: bool) -> float:
	"""Расчёт выплаты для типа ставки"""
	if not won:
		return 0.0
	
	match bet_type:
		"Player":
			return stake * 1.0
		"Banker":
			var commission = GameModeManager.get_banker_commission()
			if GameModeManager.get_mode_string() == "classic":
				var banker_value = BaccaratRules.hand_value(hand_manager.get_banker_hand_ref())
				if banker_value == 6:
					commission = 0.5
			return stake * commission
		"Tie":
			return stake * 8.0
		"PairPlayer", "PairBanker":
			return pair_betting_manager.calculate_pair_payout(stake, bet_type) if pair_betting_manager else 0.0
		_:
			return 0.0


func _finalize_payouts_manual(actual_winner: String) -> void:
	"""Завершение подготовки выплат - обновление видимости и сохранение состояния"""
	# ═══════════════════════════════════════════════════════════════════
	# УПРАВЛЕНИЕ ФИШКАМИ (показать выигравшие, скрыть проигравшие)
	# ═══════════════════════════════════════════════════════════════════
	_update_chip_visibility()

	# ═══════════════════════════════════════════════════════════════════
	# СОХРАНЕНИЕ СОСТОЯНИЯ СТОЛА в TableStateManager
	# ═══════════════════════════════════════════════════════════════════
	var selected_winner = winner_selection_manager.get_selected_winner() if winner_selection_manager else ""
	var surv_lives = survival_ui.current_lives if survival_ui else 7
	var surv_active = survival_ui.is_active if survival_ui else false

	# Получаем состояние ставок на пары из настроек
	var pair_player_pressed = PayoutSettingsManager.player_pair_payout_enabled
	var pair_banker_pressed = PayoutSettingsManager.banker_pair_payout_enabled

	# Получаем текущие текстуры фишек
	var chip_textures = chip_visual_manager.current_textures if chip_visual_manager else {}

	TableStateManager.save_table_state(
		hand_manager.get_player_hand_ref(),
		hand_manager.get_banker_hand_ref(),
		actual_winner,
		selected_winner,
		payout_queue_manager.get_all_bets(),
		camera_manager.camera.position if camera_manager and camera_manager.camera else Vector2.ZERO,
		camera_manager.camera.zoom if camera_manager and camera_manager.camera else Vector2.ONE,
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

	Новая логика (с фазой сбора ставок):
	- Оплаченные ставки → скрыть
	- Собранные проигрышные ставки → скрыть
	- Все остальные ставки (выигрышные, проигрышные, Tie push) → видимы и кликабельны
	  (валидация клика в BetCollectionPhaseManager)
	
	В REALISTIC режиме работает с множественными ставками одного типа.
	"""
	if not payout_queue_manager or not chip_visual_manager:
		return

	var is_realistic = PayoutSettingsManager.is_realistic_mode_enabled()
	
	if is_realistic:
		# В REALISTIC режиме работаем с каждой ставкой индивидуально
		for bet in payout_queue_manager.get_all_bets():
			var is_collected = bet.is_collected or (bet_collection_manager and bet_collection_manager.is_bet_collected(bet.bet_type, bet.position_index))
			
			if bet.is_paid or is_collected:
				# Оплаченная или собранная → скрываем конкретную фишку
				chip_visual_manager.hide_chip_instance(bet.bet_type, bet.position_index)
			else:
				# Все остальные → видимы и кликабельны
				# В REALISTIC режиме фишки уже созданы через show_chips_realistic()
				var status = ""
				if bet.won:
					status = "выигрышная"
				elif bet_collection_manager and bet_collection_manager.is_tie_push_bet(bet.bet_type):
					status = "Tie push"
				else:
					status = "проигрышная"
				DebugLogger.log("💰 Фишка %s[%d] видна (%s)" % [bet.bet_type, bet.position_index, status])
	else:
		# Стандартный режим - по одной фишке на тип
		var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]

		for bet_type in bet_types:
			var bet = payout_queue_manager.get_bet_by_type(bet_type)

			if bet:
				# Проверяем, собрана ли проигрышная ставка
				var is_collected = bet.is_collected or (bet_collection_manager and bet_collection_manager.is_bet_collected(bet_type))
				
				if bet.is_paid or is_collected:
					# Оплаченная или собранная → скрываем
					chip_visual_manager.hide_chip(bet_type)
				else:
					# Все остальные → видимы и кликабельны
					# (валидация клика происходит в BetCollectionPhaseManager)
					# Используем make_chip_visible чтобы не менять текстуру
					chip_visual_manager.make_chip_visible(bet_type)
					chip_visual_manager.make_chip_clickable(bet_type, true)
					
					# Логирование для отладки
					var status = ""
					if bet.won:
						status = "выигрышная"
					elif bet_collection_manager and bet_collection_manager.is_tie_push_bet(bet_type):
						status = "Tie push"
					else:
						status = "проигрышная"
					DebugLogger.log("💰 Фишка %s видна (%s)" % [bet_type, status])

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
		EventBus.payout_correct.emit(collected, expected)
		DebugLogger.log("✅ Правильно! Выплата: %s" % expected)
		if is_survival_mode:
			survival_rounds_completed += 1
	else:
		EventBus.payout_wrong.emit(collected, expected)
		DebugLogger.log("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])
		# ← Жизни отнимаются в PayoutScene, здесь ничего не делаем
	if is_correct:
		phase_manager.reset()

# ═══════════════════════════════════════════════════════════════════════════
# GAME OVER И РЕСТАРТ
# ═══════════════════════════════════════════════════════════════════════════

func _on_survival_game_over(_rounds: int):
	DebugLogger.log("🎮 GAME OVER! Раундов выжито: %d" % survival_rounds_completed)

	# Закрываем окно выплат, если оно открыто
	if payout_overlay and payout_overlay.visible:
		payout_overlay.hide()
		DebugLogger.log_payout("PayoutOverlay закрыт при Game Over")

	# Зум аут до общего плана при Game Over
	camera_zoom_out()
	camera_manager.set_is_first_deal(true)  # Следующая раздача будет первой (с зумом)

	game_over_popup.show_game_over(survival_rounds_completed)

func _on_score_game_over():
	DebugLogger.log_game_flow("GAME OVER! Очки достигли 0")

	# Закрываем окно выплат, если оно открыто
	if payout_overlay and payout_overlay.visible:
		payout_overlay.hide()
		DebugLogger.log_payout("PayoutOverlay закрыт при Game Over")

	# Зум аут до общего плана при Game Over
	camera_zoom_out()
	camera_manager.set_is_first_deal(true)  # Следующая раздача будет первой (с зумом)

	var final_score = SaveManager.instance.score
	game_over_popup.show_game_over_score(final_score)
	
	# ← Сбрасываем очки на 10 после геймовера (в режиме без сердечек)
	if not SaveManager.instance.load_survival_mode():
		SaveManager.instance.score = 10
		SaveManager.instance.save_data()
		DebugLogger.log("🔄 Очки сброшены на 10 после геймовера")

func _on_restart_game():
	survival_rounds_completed = 0
	camera_manager.set_is_first_deal(true)  # После рестарта первая раздача с зумом
	StatsManager.instance.reset()
	if is_survival_mode:
		survival_ui.reset()
		survival_ui.activate()

	# Разблокируем маркеры для новой игры
	if winner_selection_manager:
		winner_selection_manager.unlock_markers()

	phase_manager.reset()

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
		else:
			if not GameStateManager.can_change_settings():
				var msg = GameStateManager.get_settings_lock_message()
				EventBus.show_toast_error.emit(msg)
				DebugLogger.log("🔒 [НОВАЯ СИСТЕМА] " + msg)
				return
			DebugLogger.log("  → Открываем настройки")
			settings_scene.open_settings()
	else:
		DebugLogger.log("  ❌ ОШИБКА: settings_scene = null!")

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

func _on_survival_mode_changed(enabled: bool):
	is_survival_mode = enabled
	SaveManager.save_survival_mode(enabled)
	if enabled:
		survival_ui.activate()
		ui_manager.stats_label.visible = false
		DebugLogger.log("Режим выживания включён")
	else:
		survival_ui.deactivate()
		ui_manager.stats_label.visible = true
		DebugLogger.log("Режим выживания выключен")

	# ← Обновляем отображение статистики (переключаемся между очками и правильно/ошибки)
	StatsManager.instance.update_stats()

func _load_survival_mode_setting():
	var enabled = SaveManager.load_survival_mode()
	is_survival_mode = enabled
	if settings_scene:
		settings_scene.set_survival_mode(enabled)
	if survival_ui:  # ← Проверяем, что survival_ui инициализирован
		if enabled:
			survival_ui.activate()
			if ui_manager:
				ui_manager.stats_label.visible = false
		else:
			survival_ui.deactivate()
			if ui_manager:
				ui_manager.stats_label.visible = true

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
	"""Восстановление карт, UI карт и GameStateManager"""
	# 1. Восстанавливаем карты через HandManager
	hand_manager.restore_from_arrays(
		TableStateManager.player_hand,
		TableStateManager.banker_hand
	)
	DebugLogger.log("♻️  Восстановлены карты: Player=%d, Banker=%d" % [
		hand_manager.get_player_size(),
		hand_manager.get_banker_size()
	])

	# 2. Показываем карты на UI
	_restore_cards_ui()

	# 3. Обновляем GameStateManager с восстановленными картами
	var player_third_card = hand_manager.get_player_third_card()
	var banker_third_card = hand_manager.get_banker_third_card()
	GameStateManager.determine_and_update_state(
		false,  # cards_hidden = false (карты открыты)
		hand_manager.get_player_hand_ref(),
		hand_manager.get_banker_hand_ref(),
		player_third_card,
		banker_third_card
	)
	DebugLogger.log("♻️  GameStateManager обновлен: состояние = %s" % GameStateManager.get_current_state())


func _restore_survival_and_queue() -> void:
	"""Восстановление маркера победителя, survival режима и очереди выплат"""
	# 1. Восстанавливаем маркер победителя
	var saved_winner = TableStateManager.selected_winner
	if saved_winner != "" and winner_selection_manager:
		winner_selection_manager.select_winner(saved_winner)
		DebugLogger.log("🎯 Восстановлен маркер: %s" % saved_winner)
	
	# 2. Восстанавливаем survival режим
	survival_rounds_completed = TableStateManager.survival_rounds
	if survival_ui:
		survival_ui.is_active = TableStateManager.survival_active
		survival_ui.set_lives(GameDataManager.survival_lives)
		DebugLogger.log("♻️  Survival режим восстановлен: жизней=%d, раундов=%d" % [
			GameDataManager.survival_lives, survival_rounds_completed
		])
	
	# 3. Восстанавливаем PayoutQueueManager из TableStateManager
	payout_queue_manager = PayoutQueueManager.new()
	for bet_state in TableStateManager.bets:
		payout_queue_manager.add_bet(
			bet_state.bet_type,
			bet_state.stake,
			bet_state.payout,
			bet_state.won,
			bet_state.player_score,
			bet_state.banker_score
		)
		# Восстанавливаем статус оплаты
		if bet_state.is_paid:
			payout_queue_manager.mark_as_paid(bet_state.bet_type)
	
	DebugLogger.log("♻️  Восстановлен PayoutQueueManager: %d ставок" % TableStateManager.bets.size())
	
	# КРИТИЧНО: Обновляем ссылку в phase_manager после восстановления!
	phase_manager.payout_queue_manager = payout_queue_manager
	DebugLogger.log_restore("⏮ Ссылка phase_manager.payout_queue_manager обновлена")
	
	# Обновляем видимость фишек (показываем неоплаченные выигрыши)
	_update_chip_visibility()


func _process_manual_payout_result(context: Dictionary) -> void:
	"""Обработка результата текущей выплаты в ручном режиме"""
	var bet_type = context.get("bet_type", "")
	var is_correct = GameDataManager.payout_is_correct
	var collected = GameDataManager.payout_collected
	var expected = GameDataManager.payout_expected
	
	if is_correct:
		EventBus.payout_correct.emit(collected, expected)
		DebugLogger.log("✅ Правильная выплата для %s: %.1f" % [bet_type, expected])
		
		# Отмечаем ставку как оплаченную в обоих менеджерах
		payout_queue_manager.mark_as_paid(bet_type)
		TableStateManager.mark_bet_as_paid(bet_type)
		
		# Обновляем видимость фишек
		_update_chip_visibility()
		
		DebugLogger.log_init("Все выплаты оплачены! Можно начинать новый раунд")
	else:
		EventBus.payout_wrong.emit(collected, expected)
		DebugLogger.log("❌ Неправильная выплата для %s: собрано=%.1f, ожидалось=%.1f" % [
			bet_type, collected, expected
		])


func _restore_camera_and_cleanup() -> void:
	"""Восстановление камеры и очистка контекстов"""
	# Восстанавливаем камеру на общий план
	if camera_manager and camera_manager.camera:
		var general_settings = camera_manager.get_config().get_general_settings()
		camera_manager.camera.position = general_settings.position
		camera_manager.camera.zoom = general_settings.zoom
		camera_manager.set_is_first_deal(false)
		DebugLogger.log("📷 Камера восстановлена: общий план")
	
	# Показываем кнопки областей для выбора следующей области
	EventBus.area_buttons_visibility_changed.emit(true)
	
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
	survival_rounds_completed = GameDataManager.survival_rounds
	survival_ui.current_lives = GameDataManager.survival_lives
	survival_ui.is_active = GameDataManager.is_survival_active
	
	# Восстанавливаем камеру на общий план (без анимации)
	if camera_manager and camera_manager.camera:
		var general_settings = camera_manager.get_config().get_general_settings()
		camera_manager.camera.position = general_settings.position
		camera_manager.camera.zoom = general_settings.zoom
		camera_manager.set_is_first_deal(false)
		DebugLogger.log("📷 Камера восстановлена: общий план")
	
	# Показываем кнопки областей
	EventBus.area_buttons_visibility_changed.emit(true)
	
	# Обновляем визуальное отображение сердечек
	if survival_ui.is_active:
		survival_ui._update_hearts()
		survival_ui.show()
	else:
		survival_ui.hide()
	
	DebugLogger.log("♻️  Состояние игры восстановлено: rounds=%d, lives=%d, active=%s" % [
		survival_rounds_completed, survival_ui.current_lives, survival_ui.is_active
	])


func _check_and_handle_game_over() -> bool:
	"""Проверка Game Over в режиме выживания
	
	Returns:
		true если Game Over произошёл, false если игра продолжается
	"""
	if survival_ui.is_active and survival_ui.current_lives <= 0:
		DebugLogger.log_game_flow("GAME OVER! Закончились жизни (проверка после возврата из PayoutScene)")
		_on_survival_game_over(survival_rounds_completed)
		GameDataManager.clear()
		return true
	
	return false


func _process_automatic_payout_result() -> void:
	"""Обработка результата выплаты в автоматическом режиме"""
	var is_correct = GameDataManager.payout_is_correct
	var collected = GameDataManager.payout_collected
	var expected = GameDataManager.payout_expected
	
	if is_correct:
		EventBus.payout_correct.emit(collected, expected)
		DebugLogger.log("✅ Правильно! Выплата: %s" % expected)
		if is_survival_mode:
			survival_rounds_completed += 1
	else:
		EventBus.payout_wrong.emit(collected, expected)
		DebugLogger.log("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])


func _handle_payout_queue() -> void:
	"""Обработка очереди выплат (переход к следующей или сброс раунда)"""
	if GameDataManager.has_more_payouts():
		# Есть ещё выплаты в очереди → берём следующую
		var next_payout = GameDataManager.get_next_payout()
		
		DebugLogger.log("🔄 Следующая выплата: %s (осталось %d)" % [
			next_payout.bet_type, GameDataManager.get_queue_size()
		])
		
		# Сохраняем данные для PayoutScene
		GameDataManager.set_payout_data(
			next_payout.bet_type,
			next_payout.stake,
			next_payout.payout,
			next_payout.player_score,
			next_payout.banker_score
		)
		
		# Переходим в PayoutScene для следующей выплаты
		get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
	else:
		# Очередь пуста → сбрасываем раунд
		DebugLogger.log_init("Все выплаты обработаны, сброс раунда")
		GameDataManager.clear()
		
		# Сброс раунда только если последняя выплата была правильной
		var is_correct = GameDataManager.payout_is_correct
		if is_correct:
			phase_manager.reset()



func camera_zoom_in():
	"""Плавный зум на область карт (делегирование к CameraManager)"""
	if camera_manager:
		camera_manager.zoom_in()

func camera_zoom_out():
	"""Возврат к общему плану (делегирование к CameraManager)"""
	if camera_manager:
		camera_manager.zoom_out()

func camera_zoom_cards():
	"""Плавный зум на область карт (делегирование к CameraManager)"""
	if camera_manager:
		camera_manager.zoom_cards()

func camera_zoom_area(area_index: int):
	"""Плавный зум на область ставок (делегирование к CameraManager)"""
	if camera_manager:
		camera_manager.zoom_area(area_index)


func _on_left_arrow_pressed():
	"""Обработчик нажатия левой стрелки"""
	if not camera_manager:
		return
	var target_area = camera_manager.get_target_area_by_direction("left")
	if target_area > 0:
		EventBus.camera_zoom_requested.emit("area_%d" % target_area)
	else:
		EventBus.camera_zoom_requested.emit("in")
	_update_arrows_state()

func _on_right_arrow_pressed():
	"""Обработчик нажатия правой стрелки"""
	if not camera_manager:
		return
	var target_area = camera_manager.get_target_area_by_direction("right")
	if target_area > 0:
		EventBus.camera_zoom_requested.emit("area_%d" % target_area)
	else:
		EventBus.camera_zoom_requested.emit("in")
	_update_arrows_state()

func _on_up_arrow_pressed():
	"""Обработчик нажатия стрелки вверх"""
	if not camera_manager:
		return
	var target_area = camera_manager.get_target_area_by_direction("up")
	if target_area > 0:
		EventBus.camera_zoom_requested.emit("area_%d" % target_area)
	else:
		EventBus.camera_zoom_requested.emit("in")
	_update_arrows_state()

func _on_down_arrow_pressed():
	"""Обработчик нажатия стрелки вниз"""
	if not camera_manager:
		return
	var target_area = camera_manager.get_target_area_by_direction("down")
	if target_area > 0:
		EventBus.camera_zoom_requested.emit("area_%d" % target_area)
	else:
		EventBus.camera_zoom_requested.emit("in")
	_update_arrows_state()

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
		target_area: Целевая область для мгновенного обновления (если -1, используется текущая)
	"""
	if not camera_manager:
		return
	
	# Используем целевую область если передана, иначе текущую
	var current_area = target_area if target_area >= 0 else camera_manager.get_current_area()
	var left_arrow = get_node_or_null("TopUI/LeftArrowButton")
	var right_arrow = get_node_or_null("TopUI/RightArrowButton")
	var up_arrow = get_node_or_null("TopUI/UpArrowButton")
	var down_arrow = get_node_or_null("TopUI/DownArrowButton")
	
	# Используем get_target_area_by_direction_from для определения доступности стрелок
	# Стрелка активна, если целевая область отличается от текущей (есть переход)
	# Стрелка неактивна, если целевая область равна текущей (нет перехода)
	
	# Левая стрелка
	if left_arrow:
		var target_left = camera_manager.get_target_area_by_direction_from(current_area, "left")
		var can_go_left = (target_left != current_area)
		left_arrow.disabled = not can_go_left
		left_arrow.modulate.a = 0.3 if not can_go_left else 1.0
	
	# Правая стрелка
	if right_arrow:
		var target_right = camera_manager.get_target_area_by_direction_from(current_area, "right")
		var can_go_right = (target_right != current_area)
		right_arrow.disabled = not can_go_right
		right_arrow.modulate.a = 0.3 if not can_go_right else 1.0
	
	# Стрелка вверх
	if up_arrow:
		var target_up = camera_manager.get_target_area_by_direction_from(current_area, "up")
		var can_go_up = (target_up != current_area)
		up_arrow.disabled = not can_go_up
		up_arrow.modulate.a = 0.3 if not can_go_up else 1.0
	
	# Стрелка вниз
	if down_arrow:
		var target_down = camera_manager.get_target_area_by_direction_from(current_area, "down")
		var can_go_down = (target_down != current_area)
		down_arrow.disabled = not can_go_down
		down_arrow.modulate.a = 0.3 if not can_go_down else 1.0



func _on_payout_setting_changed(bet_type: String, enabled: bool):
	"""Обработка изменения настроек выплат из SettingsScene"""
	if not chip_visual_manager:
		return

	var is_realistic = PayoutSettingsManager.is_realistic_mode_enabled()

	# Управляем видимостью фишек
	if enabled:
		if is_realistic:
			chip_visual_manager.show_chips_realistic(bet_type)
		else:
			chip_visual_manager.show_chip(bet_type)
	else:
		chip_visual_manager.hide_chip(bet_type)
		# В REALISTIC режиме также очищаем активные фишки этого типа
		if is_realistic:
			var chips_to_remove = chip_visual_manager.get_active_chips_by_type(bet_type)
			for chip in chips_to_remove:
				chip_visual_manager.hide_chip_instance(bet_type, chip.position_index)

	# Для пар - также обновляем PairBettingManager
	if bet_type == "PairPlayer" and pair_betting_manager:
		pair_betting_manager.toggle_pair_player_bet(enabled)
	elif bet_type == "PairBanker" and pair_betting_manager:
		pair_betting_manager.toggle_pair_banker_bet(enabled)

	DebugLogger.log("💰 Настройка выплаты изменена: %s = %s" % [bet_type, "ВКЛ" if enabled else "ВЫКЛ"])

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


func _on_position_mode_changed(mode: int):
	"""Обработка изменения режима позиций фишек из SettingsScene

	Args:
		mode: 0=DEFAULT, 1=RANDOM, 2=MAX, 3=REALISTIC
	"""
	if not chip_visual_manager:
		return

	# Применяем новый режим
	chip_visual_manager.set_position_mode(mode as ChipVisualManager.PositionMode)

	var mode_names = ["DEFAULT", "RANDOM", "MAX", "REALISTIC"]
	DebugLogger.log("🎲 Режим позиций фишек изменён: %s" % mode_names[mode])

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СТАВОК И ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func _on_winner_toggled(winner: String, selected: bool):
	if selected:
		DebugLogger.log("🎯 Выбран: %s" % winner)
		# Деактивируем кнопку Игалите когда выбран маркер Player или Banker
		ui_manager.disable_tie_button()
		# Отменяем заказ третьих карт при активации маркера
		if phase_manager:
			phase_manager.cancel_third_card_orders()
	else:
		DebugLogger.log("🎯 Снят выбор: %s" % winner)
		# Активируем кнопку Игалите если ни один маркер не выбран
		if not winner_selection_manager.is_winner_selected():
			ui_manager.enable_tie_button()


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
	DebugLogger.log("🖱️  Клик на фишку: %s[%d]" % [bet_type, position_index])
	
	# Проверяем что менеджеры инициализированы
	if not payout_queue_manager or not bet_collection_manager:
		return
	
	# ═══════════════════════════════════════════════════════════════════
	# ВАЛИДАЦИЯ КЛИКА ЧЕРЕЗ BetCollectionPhaseManager
	# ═══════════════════════════════════════════════════════════════════
	var validation = bet_collection_manager.validate_chip_click(bet_type, position_index)
	
	# Если режим не выбран - ничего не делаем
	if validation.action == "none" and validation.can_proceed:
		DebugLogger.log("  ⏸️  Режим не выбран, клик игнорируется")
		return
	
	# Если ошибка валидации - показываем сообщение и штрафуем
	if not validation.can_proceed:
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
		# Скрываем фишку
		if chip_visual_manager:
			var is_realistic = PayoutSettingsManager.is_realistic_mode_enabled()
			if is_realistic:
				chip_visual_manager.hide_chip_instance(bet_type, position_index)
			else:
				chip_visual_manager.hide_chip(bet_type)
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
			_show_payout_overlay_instance(bet_type, position_index, bet.stake, bet.payout)
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

	DebugLogger.log("💰 Показываем PayoutOverlay: %s[%d], stake=%.1f, payout=%.1f" % [bet_type, position_index, stake, payout])

	# Сохраняем position_index для обработчика завершения
	# (пока используем простой способ - храним в метаданных контекста)
	payout_overlay.set_meta("current_position_index", position_index)

	# Передаём состояние игры через параметры (вместо get_parent())
	var lives = survival_ui.current_lives if survival_ui else 7
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

	DebugLogger.log("💰 Открываем PayoutScene для %s: stake=%.1f, payout=%.1f" % [bet_type, bet_data.stake, bet_data.payout])

	# Устанавливаем данные в GameDataManager (PayoutScene читает данные оттуда)
	GameDataManager.payout_winner = bet_type
	GameDataManager.payout_stake = bet_data.stake
	GameDataManager.payout_amount = bet_data.payout
	DebugLogger.log("  → Установлены данные в GameDataManager: winner=%s, stake=%.1f, amount=%.1f" % [bet_type, bet_data.stake, bet_data.payout])

	# Устанавливаем контекст для PayoutScene через старый PayoutContextManager (для совместимости)
	PayoutContextManager.set_context({
		"bet_type": bet_type,
		"stake": bet_data.stake,
		"expected_payout": bet_data.payout,
		"return_to_game": true,
		"manual_mode": true
	})

	# Передаем состояние режима выживания в GameDataManager
	DebugLogger.log("🔍 DEBUG _open_payout_scene:")
	DebugLogger.log("  → is_survival_mode = %s" % is_survival_mode)
	DebugLogger.log("  → survival_ui exists = %s" % (survival_ui != null))
	if survival_ui:
		DebugLogger.log("  → survival_ui.current_lives = %d" % survival_ui.current_lives)
	DebugLogger.log("  → GameDataManager.survival_lives (before) = %d" % GameDataManager.survival_lives)

	var surv_lives = 7  # Значение по умолчанию
	if is_survival_mode and survival_ui:
		# Режим выживания активен - берем текущее количество жизней
		surv_lives = survival_ui.current_lives
		DebugLogger.log("  → Берем из survival_ui: %d" % surv_lives)
	elif is_survival_mode:
		# Режим выживания активен, но survival_ui не инициализирован - берем из GameDataManager
		surv_lives = GameDataManager.survival_lives
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
	var lives = survival_ui.current_lives if survival_ui else 7
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
		EventBus.payout_correct.emit(collected, expected)
		DebugLogger.log("  ✅ Правильная выплата %s[%d]: %.1f" % [bet_type, position_index, expected])

		# Отмечаем ставку как оплаченную в PayoutQueueManager
		if payout_queue_manager:
			payout_queue_manager.mark_as_paid(bet_type, position_index)
			DebugLogger.log("  ✅ Ставка %s[%d] отмечена как оплаченная" % [bet_type, position_index])
		
		# Отмечаем в BetCollectionPhaseManager
		if bet_collection_manager:
			bet_collection_manager.pay_bet(bet_type, position_index)

		# Скрываем фишку оплаченной ставки
		if chip_visual_manager:
			var is_realistic = PayoutSettingsManager.is_realistic_mode_enabled()
			if is_realistic:
				chip_visual_manager.hide_chip_instance(bet_type, position_index)
			else:
				chip_visual_manager.hide_chip(bet_type)
			DebugLogger.log("  🎨 Фишка %s[%d] скрыта" % [bet_type, position_index])

		# Увеличиваем счетчик раундов в survival mode
		if is_survival_mode:
			survival_rounds_completed += 1
			DebugLogger.log("  🎮 Survival: раунд %d завершен" % survival_rounds_completed)
	else:
		EventBus.payout_wrong.emit(collected, expected)
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


func _restore_cards_ui():
	"""Восстановить карты на UI после возврата из PayoutScene"""
	# Показываем первые две карты игрока
	if hand_manager.get_player_hand_ref().size() >= 1:
		ui_manager.player_card1.texture = hand_manager.get_player_hand_ref()[0].get_texture(card_manager)
		ui_manager.player_card1.visible = true
	if hand_manager.get_player_hand_ref().size() >= 2:
		ui_manager.player_card2.texture = hand_manager.get_player_hand_ref()[1].get_texture(card_manager)
		ui_manager.player_card2.visible = true
	if hand_manager.get_player_hand_ref().size() >= 3:
		ui_manager.player_card3.texture = hand_manager.get_player_hand_ref()[2].get_texture(card_manager)
		ui_manager.player_card3.visible = true

	# Показываем первые две карты банкира
	if hand_manager.get_banker_hand_ref().size() >= 1:
		ui_manager.banker_card1.texture = hand_manager.get_banker_hand_ref()[0].get_texture(card_manager)
		ui_manager.banker_card1.visible = true
	if hand_manager.get_banker_hand_ref().size() >= 2:
		ui_manager.banker_card2.texture = hand_manager.get_banker_hand_ref()[1].get_texture(card_manager)
		ui_manager.banker_card2.visible = true
	if hand_manager.get_banker_hand_ref().size() >= 3:
		ui_manager.banker_card3.texture = hand_manager.get_banker_hand_ref()[2].get_texture(card_manager)
		ui_manager.banker_card3.visible = true

	# Скрываем toggles третьих карт (карты уже открыты)
	ui_manager.player_third_toggle.visible = false
	ui_manager.banker_third_toggle.visible = false

	DebugLogger.log_restore(" Карты восстановлены на UI")

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

	DebugLogger.log_game_flow("Стол подготовлен к новой игре (флаг is_table_prepared установлен, маркеры разблокированы)")
