## Менеджер тренировочной сессии.
## Хранит контекст: оффлайн или сетевая игра, данные комнаты, раунды.
## (autoload — class_name НЕ нужен)
extends Node

# ═══════════════════════════════════════════════════════════════
# РЕЖИМЫ
# ═══════════════════════════════════════════════════════════════

enum Mode {
	OFFLINE,      # Обычная игра без сервера
	ONLINE        # Игра с отправкой результатов на сервер
}

var current_mode: Mode = Mode.OFFLINE

# Данные сессии (заполняются при входе дилера)
var room_code: String = ""
var session_id: String = ""
var dealer_id: String = ""
var display_name: String = ""
## Сид текущего раунда с сервера (после применения к колоде совпадает с последней раздачей).
var live_round_seed: String = ""
## Сид следующего раунда из WS `round_sync` (применяется в deal_first_four перед раздачей).
var pending_live_round_seed: String = ""

# Статистика текущей сессии
var rounds_played: int = 0
var correct_answers: int = 0
var total_errors: int = 0
var round_start_time: float = 0.0
var _last_player_cards: Array[String] = []
var _last_banker_cards: Array[String] = []

# ═══════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

signal session_started(mode: Mode)
signal session_ended(stats: Dictionary)


# ═══════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	# Подписываемся на события игры
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.round_reset.connect(_on_round_reset)
		eb.action_correct.connect(_on_action_correct)
		eb.payout_correct.connect(_on_payout_correct)
		eb.cards_dealt.connect(_on_cards_dealt)
		eb.player_third_drawn.connect(_on_player_third_drawn)
		eb.banker_third_drawn.connect(_on_banker_third_drawn)


# ═══════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════

func start_offline_session() -> void:
	if Engine.has_singleton("LiveSessionClient"):
		LiveSessionClient.disconnect_live()
	current_mode = Mode.OFFLINE
	session_id = ""
	live_round_seed = ""
	pending_live_round_seed = ""
	_reset_stats()
	session_started.emit(current_mode)


func start_online_session(
	room_code_str: String,
	dealer_id_str: String,
	display_name_str: String,
	live_session_uuid: String = ""
) -> void:
	current_mode = Mode.ONLINE
	room_code = room_code_str
	dealer_id = dealer_id_str
	display_name = display_name_str
	session_id = live_session_uuid
	pending_live_round_seed = ""
	_reset_stats()
	session_started.emit(current_mode)


func apply_live_sync(data: Dictionary) -> void:
	if data.has("round_seed"):
		var rs: String = str(data["round_seed"])
		if rs != "":
			live_round_seed = rs


func apply_server_round_sync(data: Dictionary) -> void:
	if not data.has("round_seed"):
		return
	var rs: String = str(data["round_seed"]).strip_edges()
	if rs != "":
		pending_live_round_seed = rs


func apply_pending_live_deck_seed_to(deck: Deck) -> void:
	if current_mode != Mode.ONLINE:
		return
	if deck == null:
		return
	var pending: String = pending_live_round_seed.strip_edges()
	if pending.is_empty():
		return
	deck.reseed_from_hex(pending)
	live_round_seed = pending
	pending_live_round_seed = ""


func end_session() -> Dictionary:
	if Engine.has_singleton("LiveSessionClient"):
		LiveSessionClient.disconnect_live()
	var stats = get_session_stats()
	session_ended.emit(stats)
	_reset_stats()
	current_mode = Mode.OFFLINE
	session_id = ""
	live_round_seed = ""
	pending_live_round_seed = ""
	return stats


func get_session_stats() -> Dictionary:
	return {
		"mode": current_mode,
		"room_code": room_code,
		"session_id": session_id,
		"dealer_id": dealer_id,
		"display_name": display_name,
		"rounds_played": rounds_played,
		"correct_answers": correct_answers,
		"total_errors": total_errors,
		"accuracy": _calc_accuracy()
	}


func get_round_context_snapshot() -> Dictionary:
	return {
		"player_cards": _last_player_cards.duplicate(),
		"banker_cards": _last_banker_cards.duplicate(),
	}


func _reset_stats() -> void:
	rounds_played = 0
	correct_answers = 0
	total_errors = 0
	round_start_time = 0.0
	_last_player_cards.clear()
	_last_banker_cards.clear()


func _calc_accuracy() -> float:
	if rounds_played == 0:
		return 0.0
	return float(correct_answers) / float(rounds_played)


# ═══════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════

func _on_round_reset() -> void:
	# Новый раунд начался
	rounds_played += 1
	round_start_time = Time.get_ticks_msec() / 1000.0
	_last_player_cards.clear()
	_last_banker_cards.clear()


func _on_action_correct(_type: String) -> void:
	correct_answers += 1


func _on_payout_correct(_payload: Dictionary) -> void:
	correct_answers += 1


func _on_cards_dealt(player_hand: Array[Card], banker_hand: Array[Card]) -> void:
	_last_player_cards = _cards_to_strings(player_hand)
	_last_banker_cards = _cards_to_strings(banker_hand)


func _on_player_third_drawn(card: Card) -> void:
	if card and card.has_method("card_to_string"):
		_last_player_cards.append(str(card.card_to_string()))


func _on_banker_third_drawn(card: Card) -> void:
	if card and card.has_method("card_to_string"):
		_last_banker_cards.append(str(card.card_to_string()))


func _cards_to_strings(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for c in cards:
		if c and c.has_method("card_to_string"):
			out.append(str(c.card_to_string()))
	return out
