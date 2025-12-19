# res://scripts/PairBettingManager.gd
# Менеджер ставок на пары (Player Pair / Banker Pair)

class_name PairBettingManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

const PAIR_PAYOUT_MULTIPLIER = 11.0  # Пары обычно платят 11:1

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@warning_ignore("unused_signal")
signal pair_detected(pair_type: String)  # "PairPlayer" или "PairBanker"
signal pair_bet_placed(pair_type: String)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ ПЕРЕМЕННЫЕ (инкапсуляция)
# ═══════════════════════════════════════════════════════════════════════════

# Активные ставки на пары (приватные)
var _pair_player_bet_enabled: bool = false
var _pair_banker_bet_enabled: bool = false

# Результаты раунда (приватные)
var _player_pair_detected: bool = false
var _banker_pair_detected: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ СВОЙСТВА (для обратной совместимости)
# ═══════════════════════════════════════════════════════════════════════════

## Активна ли ставка на пару игрока (обратная совместимость)
var pair_player_bet_enabled: bool:
	get:
		return _pair_player_bet_enabled
	set(value):
		_pair_player_bet_enabled = value

## Активна ли ставка на пару банкира (обратная совместимость)
var pair_banker_bet_enabled: bool:
	get:
		return _pair_banker_bet_enabled
	set(value):
		_pair_banker_bet_enabled = value

## Обнаружена ли пара у игрока (обратная совместимость)
var player_pair_detected: bool:
	get:
		return _player_pair_detected
	set(value):
		_player_pair_detected = value

## Обнаружена ли пара у банкира (обратная совместимость)
var banker_pair_detected: bool:
	get:
		return _banker_pair_detected
	set(value):
		_banker_pair_detected = value

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ СТАВКАМИ
# ═══════════════════════════════════════════════════════════════════════════

func toggle_pair_player_bet(enabled: bool) -> void:
	"""Переключить ставку на пару игрока"""
	_pair_player_bet_enabled = enabled
	if enabled:
		pair_bet_placed.emit("PairPlayer")
	print("💰 PairBetting: ставка на пару игрока = %s" % enabled)


func toggle_pair_banker_bet(enabled: bool) -> void:
	"""Переключить ставку на пару банкира"""
	_pair_banker_bet_enabled = enabled
	if enabled:
		pair_bet_placed.emit("PairBanker")
	print("💰 PairBetting: ставка на пару банкира = %s" % enabled)


func randomize_pair_bets() -> void:
	"""Рандомно активировать ставки на пары

	Варианты:
	- Только на игрока
	- Только на банкира
	- На обе пары
	- Ни на одну (30% вероятность)
	"""
	var random_choice = randi() % 100

	if random_choice < 30:
		# 30% - нет ставок на пары
		_pair_player_bet_enabled = false
		_pair_banker_bet_enabled = false
	elif random_choice < 55:
		# 25% - только на игрока
		_pair_player_bet_enabled = true
		_pair_banker_bet_enabled = false
		pair_bet_placed.emit("PairPlayer")
	elif random_choice < 80:
		# 25% - только на банкира
		_pair_player_bet_enabled = false
		_pair_banker_bet_enabled = true
		pair_bet_placed.emit("PairBanker")
	else:
		# 20% - на обе пары
		_pair_player_bet_enabled = true
		_pair_banker_bet_enabled = true
		pair_bet_placed.emit("PairPlayer")
		pair_bet_placed.emit("PairBanker")

	print("🎲 PairBetting: рандомизация ставок - Игрок=%s, Банкир=%s" % [_pair_player_bet_enabled, _pair_banker_bet_enabled])


# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ПАР
# ═══════════════════════════════════════════════════════════════════════════

func check_pairs(player_card1: Card, player_card2: Card,
				 banker_card1: Card, banker_card2: Card) -> Dictionary:
	"""Проверить наличие пар в первых 4 картах

	Пара = две карты одного ранга (не важно масть)
	Например: два валета, два туза, две тройки и т.д.

	Возвращает словарь: {"player_pair": bool, "banker_pair": bool}
	"""
	_player_pair_detected = _is_pair(player_card1, player_card2)
	_banker_pair_detected = _is_pair(banker_card1, banker_card2)

	# ← Молча проверяем пары (без toast оповещений)
	# Это проверка внимательности дилера - он должен заметить пару сам!

	return {
		"player_pair": _player_pair_detected,
		"banker_pair": _banker_pair_detected
	}


func _is_pair(card1: Card, card2: Card) -> bool:
	"""Проверить, является ли пара картами одного ранга"""
	if card1 == null or card2 == null:
		return false

	# Сравниваем значения карт (Card.value: 1=A, 2-10, 11=J, 12=Q, 13=K)
	return card1.value == card2.value


# ═══════════════════════════════════════════════════════════════════════════
# РАСЧЕТ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

func get_winning_pairs() -> Array:
	"""Получить список выигравших пар

	Пара считается выигравшей, если:
	1. Пара была обнаружена в картах
	2. На эту пару была сделана ставка
	"""
	var winning_pairs = []

	if _player_pair_detected and _pair_player_bet_enabled:
		winning_pairs.append("PairPlayer")

	if _banker_pair_detected and _pair_banker_bet_enabled:
		winning_pairs.append("PairBanker")

	return winning_pairs


func calculate_pair_payout(stake: float, pair_type: String) -> float:
	"""Рассчитать выплату для пары"""
	if pair_type in ["PairPlayer", "PairBanker"]:
		return stake * PAIR_PAYOUT_MULTIPLIER
	return 0.0


func has_winning_pairs() -> bool:
	"""Проверить, есть ли выигравшие пары"""
	return get_winning_pairs().size() > 0


# ═══════════════════════════════════════════════════════════════════════════
# СБРОС
# ═══════════════════════════════════════════════════════════════════════════

func reset_round() -> void:
	"""Сбросить результаты раунда (не сбрасывает ставки!)"""
	_player_pair_detected = false
	_banker_pair_detected = false
	print("🔄 PairBetting: раунд сброшен")


func reset_all() -> void:
	"""Полный сброс (ставки + результаты)"""
	_pair_player_bet_enabled = false
	_pair_banker_bet_enabled = false
	_player_pair_detected = false
	_banker_pair_detected = false
	print("🔄 PairBetting: полный сброс")


# ═══════════════════════════════════════════════════════════════════════════
# ИНФОРМАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func print_status() -> void:
	"""Вывести текущий статус"""
	print("═══ PairBetting Status ═══")
	print("Ставки:")
	print("  Player Pair: %s" % ("✅" if _pair_player_bet_enabled else "❌"))
	print("  Banker Pair: %s" % ("✅" if _pair_banker_bet_enabled else "❌"))
	print("Результаты:")
	print("  Player Pair: %s" % ("🃏 ПАРА" if _player_pair_detected else "—"))
	print("  Banker Pair: %s" % ("🃏 ПАРА" if _banker_pair_detected else "—"))

	var winning = get_winning_pairs()
	if winning.size() > 0:
		print("Выигравшие пары: %s" % ", ".join(winning))
	print("═════════════════════════")

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ-ГЕТТЕРЫ (новый API для инкапсуляции)
# ═══════════════════════════════════════════════════════════════════════════

## Проверить, обнаружена ли пара у игрока
func has_player_pair() -> bool:
	return _player_pair_detected

## Проверить, обнаружена ли пара у банкира
func has_banker_pair() -> bool:
	return _banker_pair_detected

## Проверить, активна ли ставка на пару игрока
func is_player_pair_bet_enabled() -> bool:
	return _pair_player_bet_enabled

## Проверить, активна ли ставка на пару банкира
func is_banker_pair_bet_enabled() -> bool:
	return _pair_banker_bet_enabled
