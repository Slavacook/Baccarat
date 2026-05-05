# res://scripts/GuestBetFactory.gd
# Фабрика для генерации ставок гостей на основе их характера и обеспеченности

class_name GuestBetFactory
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ: ВЕРОЯТНОСТИ ДЛЯ ХАРАКТЕРОВ
# ═══════════════════════════════════════════════════════════════════════════

# Умеренный
const MODERATE_PROBS = {
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
		"Tie": 10.0,
		"None": 90.0
	},
	"pairs": {
		"Both": 10.0,
		"None": 70.0,
		"PlayerPair": 10.0,
		"BankerPair": 10.0
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
		"Both": 55.0,
		"None": 25.0,
		"PlayerPair": 10.0,
		"BankerPair": 10.0
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var limits_manager: LimitsManager
var bet_storage: GuestBetStorage
var budget_planner: GuestBetBudgetPlanner

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(limits_mgr: LimitsManager, storage: GuestBetStorage):
	limits_manager = limits_mgr
	bet_storage = storage
	budget_planner = GuestBetBudgetPlanner.new()

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Сгенерировать ставки для всех активных гостей
func generate_bets_for_all_guests() -> void:
	"""Сгенерировать ставки для всех активных гостей и сохранить в хранилище"""
	var active_guests = GuestSettingsManager.get_active_guests()
	
	for guest_id in active_guests:
		# Сохраняем баланс перед генерацией ставок
		if GuestStatsManager:
			GuestStatsManager.save_balance_before_bet_generation(guest_id)
		
		var bets = generate_guest_bets(guest_id)
		if bets.is_empty():
			bet_storage.clear_guest_bets(guest_id)
		else:
			bet_storage.store_guest_bets(guest_id, bets)
		print("🎲 GuestBetFactory: сгенерировано %d ставок для гостя %d" % [bets.size(), guest_id])

# ← Сгенерировать ставки для конкретных гостей
func generate_bets_for_specific_guests(guest_ids: Array[int]) -> void:
	"""Сгенерировать ставки для конкретных гостей
	
	Используется для генерации ставок только для гостей, которые были активны
	ДО проверки балансов и возврата гостей, чтобы не генерировать ставки для
	гостей, которые только что вернулись.
	
	Args:
		guest_ids: Массив ID гостей (1-6) для генерации ставок
	"""
	for guest_id in guest_ids:
		# Проверяем, что гость все еще активен (на всякий случай)
		if not GuestSettingsManager.is_guest_enabled(guest_id):
			print("⚠️ GuestBetFactory: гость %d не активен, пропускаем генерацию ставок" % guest_id)
			continue
		
		# Сохраняем баланс перед генерацией ставок
		if GuestStatsManager:
			GuestStatsManager.save_balance_before_bet_generation(guest_id)
		
		var bets = generate_guest_bets(guest_id)
		if bets.is_empty():
			bet_storage.clear_guest_bets(guest_id)
		else:
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
	var balance = GuestStatsManager.get_guest_balance(guest_id) if GuestStatsManager else 0.0
	
	# Получаем вероятности для характера
	var probs = _get_probabilities_for_character(character)
	var allowed_bets = _build_allowed_bets()
	
	# Временно устанавливаем профиль ставок для генерации размера
	var old_profile = BetProfileManager.get_profile()
	var bet_profile = GuestSettingsManager.wealth_to_bet_profile(wealth)
	BetProfileManager.set_profile(bet_profile as BetProfileManager.BetProfile)
	
	var main_choice = _choose_main_choice(probs["main"], allowed_bets)
	var want_tie = _choose_want_tie(probs["tie"], allowed_bets)
	var pair_choice = _choose_pair_choice(probs["pairs"], allowed_bets)

	var desired_main_stake := 0
	if not main_choice.is_empty():
		desired_main_stake = limits_manager.generate_bet()

	var desired_tie_stake := 0
	if want_tie:
		desired_tie_stake = limits_manager.generate_tie_bet()

	var desired_pair_stake := 0
	if pair_choice != "None":
		desired_pair_stake = limits_manager.generate_pair_bet()

	var planner_result = budget_planner.plan_guest_bet_package(
		balance,
		character,
		main_choice,
		want_tie,
		pair_choice,
		desired_main_stake,
		desired_tie_stake,
		desired_pair_stake,
		allowed_bets,
		limits_manager
	)
	
	# Восстанавливаем старый профиль
	BetProfileManager.set_profile(old_profile)

	var should_leave_table := false
	if planner_result.has("should_leave_table") and planner_result["should_leave_table"] is bool:
		should_leave_table = planner_result["should_leave_table"]

	if should_leave_table:
		if GuestStatsManager:
			GuestStatsManager.force_guest_leave_due_to_insufficient_balance(guest_id)
		return bets

	var planned_bets: Array[Dictionary] = []
	if planner_result.has("bets") and planner_result["bets"] is Array:
		for item in planner_result["bets"]:
			if item is Dictionary:
				planned_bets.append(item)

	bets = _create_bets_from_planner_package(guest_id, sector, planned_bets)
	
	# Фильтр настроек НЕ применяется при генерации
	# Все ставки сохраняются в хранилище, фильтр применяется на уровне видимости и участия в игре
	# (при показке в _show_guest_bets() и при добавлении в очередь выплат)
	
	return bets

func _build_allowed_bets() -> Dictionary:
	return {
		"Player": PayoutSettingsManager.player_payout_enabled,
		"Banker": PayoutSettingsManager.banker_payout_enabled,
		"Tie": PayoutSettingsManager.tie_payout_enabled,
		"PairPlayer": PayoutSettingsManager.player_pair_payout_enabled,
		"PairBanker": PayoutSettingsManager.banker_pair_payout_enabled
	}

func _create_bets_from_planner_package(guest_id: int, sector: int, planned_bets: Array[Dictionary]) -> Array[Bet]:
	var result: Array[Bet] = []

	for item in planned_bets:
		if not item.has("bet_type"):
			continue
		if not item.has("stake"):
			continue

		var bet_type_variant = item["bet_type"]
		var stake_variant = item["stake"]
		if not (bet_type_variant is String):
			continue
		if not (stake_variant is int):
			continue

		var bet_type = bet_type_variant as String
		var stake = stake_variant as int
		var position_index = GuestSectorMapper.get_position_index(sector, bet_type)
		result.append(Bet.create_guest_bet(guest_id, bet_type, stake, position_index, sector))

	return result

func _choose_main_choice(probs: Dictionary, allowed_bets: Dictionary) -> String:
	var entries: Array[Dictionary] = []

	if allowed_bets.has("Player") and allowed_bets["Player"] is bool and allowed_bets["Player"]:
		var player_weight = 0.0
		if probs.has("Player") and probs["Player"] is float:
			player_weight = probs["Player"]
		if player_weight > 0.0:
			entries.append({"name": "Player", "weight": player_weight})

	if allowed_bets.has("Banker") and allowed_bets["Banker"] is bool and allowed_bets["Banker"]:
		var banker_weight = 0.0
		if probs.has("Banker") and probs["Banker"] is float:
			banker_weight = probs["Banker"]
		if banker_weight > 0.0:
			entries.append({"name": "Banker", "weight": banker_weight})

	var none_weight = 0.0
	if probs.has("None") and probs["None"] is float:
		none_weight = probs["None"]
	if none_weight > 0.0:
		entries.append({"name": "", "weight": none_weight})

	return _roll_weighted_choice(entries, "")

func _choose_want_tie(probs: Dictionary, allowed_bets: Dictionary) -> bool:
	if not allowed_bets.has("Tie"):
		return false
	if not (allowed_bets["Tie"] is bool):
		return false
	if not allowed_bets["Tie"]:
		return false

	var entries: Array[Dictionary] = []
	var tie_weight = 0.0
	if probs.has("Tie") and probs["Tie"] is float:
		tie_weight = probs["Tie"]
	if tie_weight > 0.0:
		entries.append({"name": "Tie", "weight": tie_weight})

	var none_weight = 0.0
	if probs.has("None") and probs["None"] is float:
		none_weight = probs["None"]
	if none_weight > 0.0:
		entries.append({"name": "None", "weight": none_weight})

	return _roll_weighted_choice(entries, "None") == "Tie"

func _choose_pair_choice(probs: Dictionary, allowed_bets: Dictionary) -> String:
	var entries: Array[Dictionary] = []
	var allow_player_pair = false
	var allow_banker_pair = false

	if allowed_bets.has("PairPlayer") and allowed_bets["PairPlayer"] is bool and allowed_bets["PairPlayer"]:
		allow_player_pair = true
	if allowed_bets.has("PairBanker") and allowed_bets["PairBanker"] is bool and allowed_bets["PairBanker"]:
		allow_banker_pair = true

	if allow_player_pair and allow_banker_pair:
		var both_weight = 0.0
		if probs.has("Both") and probs["Both"] is float:
			both_weight = probs["Both"]
		if both_weight > 0.0:
			entries.append({"name": "Both", "weight": both_weight})

	if allow_player_pair:
		var player_pair_weight = 0.0
		if probs.has("PlayerPair") and probs["PlayerPair"] is float:
			player_pair_weight = probs["PlayerPair"]
		if player_pair_weight > 0.0:
			entries.append({"name": "PlayerPair", "weight": player_pair_weight})

	if allow_banker_pair:
		var banker_pair_weight = 0.0
		if probs.has("BankerPair") and probs["BankerPair"] is float:
			banker_pair_weight = probs["BankerPair"]
		if banker_pair_weight > 0.0:
			entries.append({"name": "BankerPair", "weight": banker_pair_weight})

	var none_weight = 0.0
	if probs.has("None") and probs["None"] is float:
		none_weight = probs["None"]
	if none_weight > 0.0:
		entries.append({"name": "None", "weight": none_weight})

	return _roll_weighted_choice(entries, "None")

func _roll_weighted_choice(entries: Array[Dictionary], fallback: String) -> String:
	var total_weight = 0.0
	for entry in entries:
		if not entry.has("weight"):
			continue
		if not (entry["weight"] is float):
			continue
		total_weight += entry["weight"]

	if total_weight <= 0.0:
		return fallback

	var roll = randf() * total_weight
	var cumulative = 0.0

	for entry in entries:
		if not entry.has("name"):
			continue
		if not entry.has("weight"):
			continue
		if not (entry["name"] is String):
			continue
		if not (entry["weight"] is float):
			continue

		cumulative += entry["weight"]
		if roll < cumulative:
			return entry["name"]

	return fallback

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ ГЕНЕРАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func _get_probabilities_for_character(character: GuestSettingsManager.GuestCharacter) -> Dictionary:
	"""Получить вероятности для характера"""
	match character:
		GuestSettingsManager.GuestCharacter.MODERATE:
			return MODERATE_PROBS
		GuestSettingsManager.GuestCharacter.CAUTIOUS:
			return CAUTIOUS_PROBS
		GuestSettingsManager.GuestCharacter.GAMBLER:
			return GAMBLER_PROBS
		_:
			return MODERATE_PROBS  # По умолчанию

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
