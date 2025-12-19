# res://scripts/GuestBetFactory.gd
# Фабрика для генерации ставок гостей на основе их характера и обеспеченности

class_name GuestBetFactory
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ: ВЕРОЯТНОСТИ ДЛЯ ХАРАКТЕРОВ
# ═══════════════════════════════════════════════════════════════════════════

# Джентельмен
const GENTLEMAN_PROBS = {
	"main": {
		"Player": 44.0,
		"Banker": 48.0,
		"None": 8.0
	},
	"tie": {
		"Tie": 25.0,
		"None": 75.0
	},
	"pairs": {
		"Both": 25.0,
		"None": 65.0,
		"PlayerPair": 5.0,
		"BankerPair": 5.0
	}
}

# Осторожный
const CAUTIOUS_PROBS = {
	"main": {
		"Player": 40.0,
		"Banker": 42.0,
		"None": 18.0
	},
	"tie": {
		"Tie": 15.0,
		"None": 85.0
	},
	"pairs": {
		"Both": 15.0,
		"None": 55.0,
		"PlayerPair": 15.0,
		"BankerPair": 15.0
	}
}

# Азартный
const GAMBLER_PROBS = {
	"main": {
		"Player": 44.0,
		"Banker": 54.0,
		"None": 1.0
	},
	"tie": {
		"Tie": 45.0,
		"None": 55.0
	},
	"pairs": {
		"Both": 45.0,
		"None": 25.0,
		"PlayerPair": 15.0,
		"BankerPair": 15.0
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var limits_manager: LimitsManager
var bet_storage: GuestBetStorage

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(limits_mgr: LimitsManager, storage: GuestBetStorage):
	limits_manager = limits_mgr
	bet_storage = storage

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Сгенерировать ставки для всех активных гостей
func generate_bets_for_all_guests() -> void:
	"""Сгенерировать ставки для всех активных гостей и сохранить в хранилище"""
	var active_guests = GuestSettingsManager.get_active_guests()
	
	for guest_id in active_guests:
		var bets = generate_guest_bets(guest_id)
		bet_storage.store_guest_bets(guest_id, bets)
		print("🎲 GuestBetFactory: сгенерировано %d ставок для гостя %d" % [bets.size(), guest_id])

# ← Сгенерировать ставки для одного гостя
func generate_guest_bets(guest_id: int) -> Array[Bet]:
	"""Сгенерировать ставки для гостя на основе его характера и обеспеченности
	
	Args:
		guest_id: ID гостя (1-6)
	
	Returns:
		Массив ставок гостя (Bet)
	"""
	var bets: Array[Bet] = []
	var character = GuestSettingsManager.get_guest_character(guest_id)
	var wealth = GuestSettingsManager.get_guest_wealth(guest_id)
	var sector = guest_id  # Сектор = ID гостя (1-6)
	
	# Получаем вероятности для характера
	var probs = _get_probabilities_for_character(character)
	
	# Временно устанавливаем профиль ставок для генерации размера
	var old_profile = BetProfileManager.get_profile()
	var bet_profile = GuestSettingsManager.wealth_to_bet_profile(wealth)
	BetProfileManager.set_profile(bet_profile as BetProfileManager.BetProfile)
	
	# 1. Генерируем основную ставку (Player ИЛИ Banker, но не оба)
	var main_bet = _generate_main_bet(guest_id, sector, probs["main"])
	if main_bet:
		bets.append(main_bet)
	
	# 2. Генерируем ставку на Tie
	var tie_bet = _generate_tie_bet(guest_id, sector, probs["tie"])
	if tie_bet:
		bets.append(tie_bet)
	
	# 3. Генерируем ставки на пары
	var pair_bets = _generate_pair_bets(guest_id, sector, probs["pairs"])
	bets.append_array(pair_bets)
	
	# Восстанавливаем старый профиль
	BetProfileManager.set_profile(old_profile)
	
	# 4. Применяем фильтр настроек (PayoutSettingsManager)
	bets = _apply_settings_filter(bets)
	
	return bets

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ ГЕНЕРАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func _get_probabilities_for_character(character: GuestSettingsManager.GuestCharacter) -> Dictionary:
	"""Получить вероятности для характера"""
	match character:
		GuestSettingsManager.GuestCharacter.GENTLEMAN:
			return GENTLEMAN_PROBS
		GuestSettingsManager.GuestCharacter.CAUTIOUS:
			return CAUTIOUS_PROBS
		GuestSettingsManager.GuestCharacter.GAMBLER:
			return GAMBLER_PROBS
		_:
			return GENTLEMAN_PROBS  # По умолчанию

func _generate_main_bet(guest_id: int, sector: int, probs: Dictionary) -> Bet:
	"""Сгенерировать основную ставку (Player или Banker)
	
	Важно: Player ИЛИ Banker, но не оба одновременно
	"""
	var roll = randf() * 100.0
	var cumulative = 0.0
	
	# Проверяем Player
	cumulative += probs.get("Player", 0.0)
	if roll < cumulative:
		var stake = limits_manager.generate_bet()
		var pos_idx = GuestSectorMapper.get_position_index(sector, "Player")
		return Bet.create_guest_bet(guest_id, "Player", stake, pos_idx, sector)
	
	# Проверяем Banker
	cumulative += probs.get("Banker", 0.0)
	if roll < cumulative:
		var stake = limits_manager.generate_bet()
		var pos_idx = GuestSectorMapper.get_position_index(sector, "Banker")
		return Bet.create_guest_bet(guest_id, "Banker", stake, pos_idx, sector)
	
	# None - гость не ставит основную ставку
	return null

func _generate_tie_bet(guest_id: int, sector: int, probs: Dictionary) -> Bet:
	"""Сгенерировать ставку на Tie"""
	var roll = randf() * 100.0
	var tie_prob = probs.get("Tie", 0.0)
	
	if roll < tie_prob:
		var stake = limits_manager.generate_tie_bet()
		var pos_idx = GuestSectorMapper.get_position_index(sector, "Tie")
		return Bet.create_guest_bet(guest_id, "Tie", stake, pos_idx, sector)
	
	return null

func _generate_pair_bets(guest_id: int, sector: int, probs: Dictionary) -> Array[Bet]:
	"""Сгенерировать ставки на пары
	
	Варианты:
	- Обе пары (Both)
	- Только пара игрока (PlayerPair)
	- Только пара банкира (BankerPair)
	- Без пар (None)
	"""
	var bets: Array[Bet] = []
	var roll = randf() * 100.0
	var cumulative = 0.0
	
	# Проверяем Both (обе пары)
	cumulative += probs.get("Both", 0.0)
	if roll < cumulative:
		# Обе пары
		var stake = limits_manager.generate_pair_bet()
		var pos_idx_player = GuestSectorMapper.get_position_index(sector, "PairPlayer")
		var pos_idx_banker = GuestSectorMapper.get_position_index(sector, "PairBanker")
		bets.append(Bet.create_guest_bet(guest_id, "PairPlayer", stake, pos_idx_player, sector))
		bets.append(Bet.create_guest_bet(guest_id, "PairBanker", stake, pos_idx_banker, sector))
		return bets
	
	# Проверяем PlayerPair
	cumulative += probs.get("PlayerPair", 0.0)
	if roll < cumulative:
		var stake = limits_manager.generate_pair_bet()
		var pos_idx = GuestSectorMapper.get_position_index(sector, "PairPlayer")
		bets.append(Bet.create_guest_bet(guest_id, "PairPlayer", stake, pos_idx, sector))
		return bets
	
	# Проверяем BankerPair
	cumulative += probs.get("BankerPair", 0.0)
	if roll < cumulative:
		var stake = limits_manager.generate_pair_bet()
		var pos_idx = GuestSectorMapper.get_position_index(sector, "PairBanker")
		bets.append(Bet.create_guest_bet(guest_id, "PairBanker", stake, pos_idx, sector))
		return bets
	
	# None - гость не ставит на пары
	return bets

# ═══════════════════════════════════════════════════════════════════════════
# ФИЛЬТРАЦИЯ СТАВОК ПО НАСТРОЙКАМ
# ═══════════════════════════════════════════════════════════════════════════

func _apply_settings_filter(bets: Array[Bet]) -> Array[Bet]:
	"""Применить фильтр настроек PayoutSettingsManager
	
	Если ставка выключена в настройках - она удаляется из партии.
	Это позволяет тренировать только определённые типы ставок.
	
	Args:
		bets: Сгенерированные ставки гостя
	
	Returns:
		Отфильтрованные ставки
	"""
	var filtered: Array[Bet] = []
	
	for bet in bets:
		var bet_type = bet.get_bet_type()
		if _is_bet_type_enabled(bet_type):
			filtered.append(bet)
		else:
			print("🎲 GuestBetFactory: ставка %s отфильтрована (выключена в настройках)" % bet_type)
	
	return filtered

func _is_bet_type_enabled(bet_type: String) -> bool:
	"""Проверить, включён ли тип ставки в настройках"""
	match bet_type:
		"Player":
			return PayoutSettingsManager.player_payout_enabled
		"Banker":
			return PayoutSettingsManager.banker_payout_enabled
		"Tie":
			return PayoutSettingsManager.tie_payout_enabled
		"PairPlayer":
			return PayoutSettingsManager.player_pair_payout_enabled
		"PairBanker":
			return PayoutSettingsManager.banker_pair_payout_enabled
		_:
			return true  # Неизвестный тип - пропускаем
