# res://scripts/autoload/TableStateManager.gd
# Централизованное хранилище состояния стола
# Автозагружаемый синглтон для сохранения/восстановления между сценами

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ ПОЛЯ (инкапсулированные)
# ═══════════════════════════════════════════════════════════════════════════

# Состояние карт
var _player_hand: Array[Card] = []
var _banker_hand: Array[Card] = []

# Состояние победителя
var _actual_winner: String = ""  # Реальный победитель (Player/Banker/Tie)
var _selected_winner: String = ""  # Выбранный игроком маркер

# Состояние ставок (использует единый класс Bet)
var _bets: Array = []  # Array[Bet] (типизация убрана для парсинга)

# Состояние камеры
var _camera_position: Vector2 = Vector2.ZERO
var _camera_zoom: Vector2 = Vector2.ONE

# Режимы игры
var _game_mode: String = ""
var _survival_rounds: int = 0
var _survival_lives: int = 7
var _survival_active: bool = false

# Состояние toggles (для восстановления после возврата из PayoutScene)
var _pair_player_toggle_pressed: bool = false
var _pair_banker_toggle_pressed: bool = false

# Состояние кнопки действия ("start", "confirm", "complete")
var _action_button_state: String = "start"

# ═══════════════════════════════════════════════════════════════════════════
# ГЕТТЕРЫ (публичный API для доступа к состоянию)
# ═══════════════════════════════════════════════════════════════════════════

func get_player_hand() -> Array[Card]:
	"""Получить руку игрока (копию)"""
	return _player_hand.duplicate()


func get_banker_hand() -> Array[Card]:
	"""Получить руку банкира (копию)"""
	return _banker_hand.duplicate()


func get_actual_winner() -> String:
	"""Получить реального победителя раунда"""
	return _actual_winner


func get_selected_winner() -> String:
	"""Получить выбранный игроком маркер"""
	return _selected_winner


func get_bets() -> Array:  # Array[Bet] (типизация убрана для парсинга)
	"""Получить массив ставок (копию)"""
	return _bets.duplicate()


func get_camera_position() -> Vector2:
	"""Получить позицию камеры"""
	return _camera_position


func get_camera_zoom() -> Vector2:
	"""Получить зум камеры"""
	return _camera_zoom


func get_game_mode() -> String:
	"""Получить режим игры"""
	return _game_mode


func get_survival_rounds() -> int:
	"""Получить количество раундов выживания"""
	return _survival_rounds


func get_survival_lives() -> int:
	"""Получить количество жизней"""
	return _survival_lives


func is_survival_active() -> bool:
	"""Проверить, активен ли режим выживания"""
	return _survival_active


func is_pair_player_toggle_pressed() -> bool:
	"""Проверить, нажат ли toggle пары игрока"""
	return _pair_player_toggle_pressed


func is_pair_banker_toggle_pressed() -> bool:
	"""Проверить, нажат ли toggle пары банкира"""
	return _pair_banker_toggle_pressed


func get_action_button_state() -> String:
	"""Получить состояние кнопки действия"""
	return _action_button_state


# ═══════════════════════════════════════════════════════════════════════════
# СЕТТЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

func set_actual_winner(winner: String) -> void:
	"""Установить реального победителя раунда"""
	_actual_winner = winner

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ СОХРАНЕНИЯ/ВОССТАНОВЛЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func save_table_state(
	p_hand: Array[Card],
	b_hand: Array[Card],
	winner: String,
	sel_winner: String,
	bet_data: Array,
	cam_pos: Vector2,
	cam_zoom: Vector2,
	mode: String,
	surv_rounds: int,
	surv_lives: int,
	surv_active: bool,
	pair_player_pressed: bool = false,
	pair_banker_pressed: bool = false,
	chip_textures: Dictionary = {},
	button_state: String = "complete"
) -> void:
	"""Сохранить полное состояние стола перед переходом в PayoutScene

	Args:
		chip_textures: Словарь {bet_type: texture_path} для сохранения текстур фишек
		button_state: Состояние кнопки действия ("start", "confirm", "complete")
	"""

	_player_hand = p_hand.duplicate()
	_banker_hand = b_hand.duplicate()
	_actual_winner = winner
	_selected_winner = sel_winner
	_camera_position = cam_pos
	_camera_zoom = cam_zoom
	_game_mode = mode
	_survival_rounds = surv_rounds
	_survival_lives = surv_lives
	_survival_active = surv_active
	_pair_player_toggle_pressed = pair_player_pressed
	_pair_banker_toggle_pressed = pair_banker_pressed
	_action_button_state = button_state

	# Сохраняем ставки с текстурами
	_bets.clear()
	for bet in bet_data:
		var texture = chip_textures.get(bet.get_bet_type(), "")
		# Создаём Bet из существующей ставки (конвертация)
		var bet_state = Bet.new(
			bet.get_bet_type(),
			bet.get_stake(),
			bet.get_payout(),
			bet.is_won(),
			0,  # position_index не хранится в TableStateManager
			bet.get_player_score(),
			bet.get_banker_score()
		)
		if bet.is_paid():
			bet_state.mark_as_paid()
		bet_state.set_chip_texture(texture)
		_bets.append(bet_state)

	print("💾 TableStateManager: состояние стола сохранено")
	print("   Карты: Player=%d, Banker=%d" % [_player_hand.size(), _banker_hand.size()])
	print("   Победитель: %s (выбран: %s)" % [_actual_winner, _selected_winner])
	print("   Ставок: %d" % _bets.size())
	print("   Toggles пар: Player=%s, Banker=%s" % [pair_player_pressed, pair_banker_pressed])


func has_saved_state() -> bool:
	"""Есть ли сохранённое состояние?"""
	return _player_hand.size() > 0 and _actual_winner != ""


func clear_state() -> void:
	"""Очистить состояние (для новой раздачи)"""
	_player_hand.clear()
	_banker_hand.clear()
	_actual_winner = ""
	_selected_winner = ""
	_bets.clear()
	_camera_position = Vector2.ZERO
	_camera_zoom = Vector2.ONE
	_game_mode = ""
	_survival_rounds = 0
	_survival_lives = 7
	_survival_active = false
	_pair_player_toggle_pressed = false
	_pair_banker_toggle_pressed = false
	_action_button_state = "start"

	print("🗑️  TableStateManager: состояние очищено")


func get_unpaid_bets() -> Array:  # Array[Bet] (типизация убрана для парсинга)
	"""Получить список неоплаченных выигрышных ставок"""
	var unpaid: Array = []  # Array[Bet] (типизация убрана для парсинга)
	for bet in _bets:
		if bet.is_won() and not bet.is_paid():
			unpaid.append(bet)
	return unpaid


func mark_bet_as_paid(bet_type: String) -> void:
	"""Отметить ставку как оплаченную"""
	for bet in _bets:
		if bet.get_bet_type() == bet_type:
			bet.mark_as_paid()
			print("✅ TableStateManager: ставка %s отмечена как оплаченная" % bet_type)
			return


func get_bet_data(bet_type: String) -> Bet:
	"""Получить данные ставки по типу"""
	for bet in _bets:
		if bet.get_bet_type() == bet_type:
			return bet
	return null


func has_unpaid_bets() -> bool:
	"""Есть ли неоплаченные выигрышные ставки?"""
	return get_unpaid_bets().size() > 0


func get_unpaid_count() -> int:
	"""Количество неоплаченных ставок"""
	return get_unpaid_bets().size()
