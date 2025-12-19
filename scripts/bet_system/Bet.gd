# res://scripts/bet_system/Bet.gd
# Единый инкапсулированный класс для всех ставок
# Заменяет BetData, BetStateData, PayoutData, GuestBet

class_name Bet
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ ПОЛЯ
# ═══════════════════════════════════════════════════════════════════════════

var _bet_type: String = ""  # "Player", "Banker", "Tie", "PairPlayer", "PairBanker"
var _stake: float = 0.0  # Размер ставки
var _payout: float = 0.0  # Размер выплаты (0.0 если проиграла)
var _won: bool = false  # Выиграла ли ставка
var _is_paid: bool = false  # Оплачена ли выплата (только для выигравших)
var _is_collected: bool = false  # Собрана ли проигрышная ставка
var _position_index: int = 0  # Индекс позиции фишки (для множественных ставок)
var _player_score: int = 0  # Очки игрока в раунде
var _banker_score: int = 0  # Очки банкира в раунде
var _guest_id: int = -1  # ID гостя (для гостевых ставок, -1 = не гостевая)
var _sector: int = -1  # Сектор гостя (1-6, -1 = не гостевая)
var _chip_texture: String = ""  # Путь к текстуре фишки (для TableStateManager)

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	bet_type: String = "",
	stake: float = 0.0,
	payout: float = 0.0,
	won: bool = false,
	position_index: int = 0,
	player_score: int = 0,
	banker_score: int = 0,
	guest_id: int = -1,
	sector: int = -1,
	chip_texture: String = ""
) -> void:
	_bet_type = bet_type
	_stake = stake
	_payout = payout
	_won = won
	_position_index = position_index
	_player_score = player_score
	_banker_score = banker_score
	_guest_id = guest_id
	_sector = sector
	_chip_texture = chip_texture

# ═══════════════════════════════════════════════════════════════════════════
# ГЕТТЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_bet_type() -> String:
	return _bet_type

func get_stake() -> float:
	return _stake

func get_payout() -> float:
	return _payout

func is_won() -> bool:
	return _won

func is_paid() -> bool:
	return _is_paid

func is_collected() -> bool:
	return _is_collected

func get_position_index() -> int:
	return _position_index

func get_player_score() -> int:
	return _player_score

func get_banker_score() -> int:
	return _banker_score

func get_guest_id() -> int:
	"""Возвращает ID гостя или -1 если ставка не гостевая"""
	return _guest_id

func get_sector() -> int:
	"""Возвращает сектор гостя (1-6) или -1 если ставка не гостевая"""
	return _sector

func get_chip_texture() -> String:
	return _chip_texture

func get_id() -> String:
	"""Уникальный идентификатор ставки: "bet_type_position_index" """
	return "%s_%d" % [_bet_type, _position_index]

# ═══════════════════════════════════════════════════════════════════════════
# СЕТТЕРЫ (с валидацией)
# ═══════════════════════════════════════════════════════════════════════════

func set_bet_type(type: String) -> void:
	_bet_type = type

func set_stake(amount: float) -> void:
	"""Установить размер ставки (валидация: amount >= 0)"""
	if amount < 0:
		push_error("Bet.set_stake(): stake не может быть отрицательным (получено: %.2f)" % amount)
		return
	_stake = amount

func set_payout(amount: float) -> void:
	"""Установить размер выплаты (валидация: amount >= 0)"""
	if amount < 0:
		push_error("Bet.set_payout(): payout не может быть отрицательным (получено: %.2f)" % amount)
		return
	_payout = amount

func set_won(won: bool) -> void:
	_won = won

func mark_as_paid() -> void:
	"""Отметить ставку как оплаченную (только если won == true)"""
	if not _won:
		push_error("Bet.mark_as_paid(): нельзя отметить проигрышную ставку как оплаченную")
		return
	_is_paid = true

func mark_as_collected() -> void:
	"""Отметить проигрышную ставку как собранную (только если won == false)"""
	if _won:
		push_error("Bet.mark_as_collected(): нельзя отметить выигрышную ставку как собранную")
		return
	_is_collected = true

func set_collected(collected: bool) -> void:
	"""Установить состояние is_collected (для rollback транзакций)"""
	if _won and collected:
		push_error("Bet.set_collected(): нельзя установить is_collected=true для выигрышной ставки")
		return
	_is_collected = collected

func set_paid(paid: bool) -> void:
	"""Установить состояние is_paid (для rollback транзакций)"""
	if not _won and paid:
		push_error("Bet.set_paid(): нельзя установить is_paid=true для проигрышной ставки")
		return
	_is_paid = paid

func set_position_index(index: int) -> void:
	_position_index = index

func set_player_score(score: int) -> void:
	_player_score = score

func set_banker_score(score: int) -> void:
	_banker_score = score

func set_guest_id(id: int) -> void:
	"""Установить ID гостя (валидация: 1-6 или -1 для не гостевой ставки)"""
	if id != -1 and (id < 1 or id > 6):
		push_error("Bet.set_guest_id(): guest_id должен быть 1-6 или -1 (получено: %d)" % id)
		return
	_guest_id = id

func set_sector(sec: int) -> void:
	"""Установить сектор гостя (валидация: 1-6 или -1 для не гостевой ставки)"""
	if sec != -1 and (sec < 1 or sec > 6):
		push_error("Bet.set_sector(): sector должен быть 1-6 или -1 (получено: %d)" % sec)
		return
	_sector = sec

func set_chip_texture(texture: String) -> void:
	_chip_texture = texture

# ═══════════════════════════════════════════════════════════════════════════
# СТАТИЧЕСКИЕ ФАБРИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

static func create_payout_bet(bet_type: String, stake: float, payout: float, p_score: int = 0, b_score: int = 0):
	"""Создать ставку для очереди выплат (GameDataManager.PayoutData)"""
	return Bet.new(bet_type, stake, payout, false, 0, p_score, b_score)

static func create_guest_bet(guest_id: int, bet_type: String, stake: float, position_index: int, sector: int):
	"""Создать гостевую ставку (GuestBetStorage.GuestBet)"""
	return Bet.new(bet_type, stake, 0.0, false, position_index, 0, 0, guest_id, sector)

static func from_bet_data(old_bet):
	"""Конвертация из PayoutQueueManager.BetData"""
	if not old_bet:
		return null
	var bet = Bet.new(
		old_bet.bet_type,
		old_bet.stake,
		old_bet.payout,
		old_bet.won,
		old_bet.position_index,
		old_bet.player_score,
		old_bet.banker_score
	)
	bet._is_paid = old_bet.is_paid
	bet._is_collected = old_bet.is_collected
	return bet

static func from_bet_state_data(old_bet):
	"""Конвертация из TableStateManager.BetStateData"""
	if not old_bet:
		return null
	var bet = Bet.new(
		old_bet.bet_type,
		old_bet.stake,
		old_bet.payout,
		old_bet.won,
		0,  # position_index не хранится в BetStateData
		old_bet.player_score,
		old_bet.banker_score
	)
	bet._is_paid = old_bet.is_paid
	bet._chip_texture = old_bet.chip_texture
	return bet

static func from_payout_data(old_bet):
	"""Конвертация из GameDataManager.PayoutData"""
	if not old_bet:
		return null
	return Bet.create_payout_bet(
		old_bet.bet_type,
		old_bet.stake,
		old_bet.payout,
		old_bet.player_score,
		old_bet.banker_score
	)

static func from_guest_bet(old_bet):
	"""Конвертация из GuestBetStorage.GuestBet"""
	if not old_bet:
		return null
	return Bet.create_guest_bet(
		old_bet.guest_id,
		old_bet.bet_type,
		old_bet.stake,
		old_bet.position_index,
		old_bet.sector
	)

# ═══════════════════════════════════════════════════════════════════════════
# СЕРИАЛИЗАЦИЯ (для GuestBetStorage)
# ═══════════════════════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	"""Преобразовать ставку в словарь для сохранения (используется для гостевых ставок)"""
	return {
		"bet_type": _bet_type,
		"stake": _stake,
		"position_index": _position_index,
		"guest_id": _guest_id,
		"sector": _sector
	}

static func from_dict(data: Dictionary):
	"""Создать ставку из словаря (для загрузки гостевых ставок)"""
	return Bet.create_guest_bet(
		data.get("guest_id", -1),
		data.get("bet_type", ""),
		data.get("stake", 0.0),
		data.get("position_index", 0),
		data.get("sector", -1)
	)

