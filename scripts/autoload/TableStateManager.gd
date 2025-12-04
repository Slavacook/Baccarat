# res://scripts/autoload/TableStateManager.gd
# Централизованное хранилище состояния стола
# Автозагружаемый синглтон для сохранения/восстановления между сценами

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

var player_hand: Array[Card] = []
var banker_hand: Array[Card] = []

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ПОБЕДИТЕЛЯ
# ═══════════════════════════════════════════════════════════════════════════

var actual_winner: String = ""  # Реальный победитель (Player/Banker/Tie)
var selected_winner: String = ""  # Выбранный игроком маркер

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ СТАВОК (из PayoutQueueManager)
# ═══════════════════════════════════════════════════════════════════════════

class BetStateData:
	var bet_type: String  # "Player", "Banker", "Tie", "PlayerPair", "BankerPair"
	var stake: float
	var payout: float
	var won: bool
	var is_paid: bool
	var player_score: int
	var banker_score: int
	var chip_texture: String  # Путь к текстуре фишки

	func _init(type: String, s: float, p: float, w: bool, paid: bool, ps: int, bs: int, texture: String = ""):
		bet_type = type
		stake = s
		payout = p
		won = w
		is_paid = paid
		player_score = ps
		banker_score = bs
		chip_texture = texture

var bets: Array[BetStateData] = []

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ КАМЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

var camera_position: Vector2 = Vector2.ZERO
var camera_zoom: Vector2 = Vector2.ONE

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМЫ ИГРЫ
# ═══════════════════════════════════════════════════════════════════════════

var game_mode: String = ""
var survival_rounds: int = 0
var survival_lives: int = 7
var survival_active: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ TOGGLES (для восстановления после возврата из PayoutScene)
# ═══════════════════════════════════════════════════════════════════════════

var pair_player_toggle_pressed: bool = false
var pair_banker_toggle_pressed: bool = false

# Состояние кнопки действия ("start", "confirm", "complete")
var action_button_state: String = "start"

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

	player_hand = p_hand.duplicate()
	banker_hand = b_hand.duplicate()
	actual_winner = winner
	selected_winner = sel_winner
	camera_position = cam_pos
	camera_zoom = cam_zoom
	game_mode = mode
	survival_rounds = surv_rounds
	survival_lives = surv_lives
	survival_active = surv_active
	pair_player_toggle_pressed = pair_player_pressed
	pair_banker_toggle_pressed = pair_banker_pressed
	action_button_state = button_state

	# Сохраняем ставки с текстурами
	bets.clear()
	for bet in bet_data:
		var texture = chip_textures.get(bet.bet_type, "")
		var bet_state = BetStateData.new(
			bet.bet_type,
			bet.stake,
			bet.payout,
			bet.won,
			bet.is_paid,
			bet.player_score,
			bet.banker_score,
			texture
		)
		bets.append(bet_state)

	print("💾 TableStateManager: состояние стола сохранено")
	print("   Карты: Player=%d, Banker=%d" % [player_hand.size(), banker_hand.size()])
	print("   Победитель: %s (выбран: %s)" % [actual_winner, selected_winner])
	print("   Ставок: %d" % bets.size())
	print("   Toggles пар: Player=%s, Banker=%s" % [pair_player_pressed, pair_banker_pressed])


func has_saved_state() -> bool:
	"""Есть ли сохранённое состояние?"""
	return player_hand.size() > 0 and actual_winner != ""


func clear_state() -> void:
	"""Очистить состояние (для новой раздачи)"""
	player_hand.clear()
	banker_hand.clear()
	actual_winner = ""
	selected_winner = ""
	bets.clear()
	camera_position = Vector2.ZERO
	camera_zoom = Vector2.ONE
	game_mode = ""
	survival_rounds = 0
	survival_lives = 7
	survival_active = false
	pair_player_toggle_pressed = false
	pair_banker_toggle_pressed = false
	action_button_state = "start"

	print("🗑️  TableStateManager: состояние очищено")


func get_unpaid_bets() -> Array[BetStateData]:
	"""Получить список неоплаченных выигрышных ставок"""
	var unpaid: Array[BetStateData] = []
	for bet in bets:
		if bet.won and not bet.is_paid:
			unpaid.append(bet)
	return unpaid


func mark_bet_as_paid(bet_type: String) -> void:
	"""Отметить ставку как оплаченную"""
	for bet in bets:
		if bet.bet_type == bet_type:
			bet.is_paid = true
			print("✅ TableStateManager: ставка %s отмечена как оплаченная" % bet_type)
			return


func get_bet_data(bet_type: String) -> BetStateData:
	"""Получить данные ставки по типу"""
	for bet in bets:
		if bet.bet_type == bet_type:
			return bet
	return null


func has_unpaid_bets() -> bool:
	"""Есть ли неоплаченные выигрышные ставки?"""
	return get_unpaid_bets().size() > 0


func get_unpaid_count() -> int:
	"""Количество неоплаченных ставок"""
	return get_unpaid_bets().size()
