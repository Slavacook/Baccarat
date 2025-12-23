# res://scripts/BetFilterManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# МЕНЕДЖЕР ФИЛЬТРОВ СТАВОК
# Управляет фильтрацией ставок через snapshot и настройки
# Чистая логика без зависимостей от UI и EventBus
# ═══════════════════════════════════════════════════════════════════════════

class_name BetFilterManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ
# ═══════════════════════════════════════════════════════════════════════════

# Снимок состояния фильтра на момент показки ставок
var filter_snapshot: Dictionary = {}  # {"Player": bool, "Banker": bool, ...}

# Накопленные изменения фильтра во время раздачи
var pending_filter_changes: Dictionary = {}  # {"Player": bool, "Banker": bool, ...}

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА ВКЛЮЧЁННОСТИ СТАВОК
# ═══════════════════════════════════════════════════════════════════════════

func is_bet_type_enabled_in_settings(
	bet_type: String,
	payout_settings_manager: PayoutSettingsManager = null,
	pair_betting_manager: PairBettingManager = null
) -> bool:
	"""Проверить, включён ли тип ставки в настройках
	
	Args:
		bet_type: Тип ставки (Player, Banker, Tie, PairPlayer, PairBanker)
		payout_settings_manager: Менеджер настроек выплат
		pair_betting_manager: Менеджер ставок на пары
		
	Returns:
		true если ставка включена в настройках, false если отключена
	"""
	match bet_type:
		"Player":
			return payout_settings_manager.player_payout_enabled if payout_settings_manager else true
		"Banker":
			return payout_settings_manager.banker_payout_enabled if payout_settings_manager else true
		"Tie":
			return payout_settings_manager.tie_payout_enabled if payout_settings_manager else true
		"PairPlayer":
			return pair_betting_manager.is_player_pair_bet_enabled() if pair_betting_manager else false
		"PairBanker":
			return pair_betting_manager.is_banker_pair_bet_enabled() if pair_betting_manager else false
		_:
			return true  # Неизвестный тип - пропускаем (не фильтруем)

func is_bet_type_enabled_in_snapshot(
	bet_type: String,
	payout_settings_manager: PayoutSettingsManager = null,
	pair_betting_manager: PairBettingManager = null
) -> bool:
	"""Проверить, включён ли тип ставки в snapshot фильтра
	
	Используется при добавлении ставок в очередь выплат для изоляции текущей раздачи.
	Если snapshot пустой - использует текущее состояние (fallback).
	
	Args:
		bet_type: Тип ставки (Player, Banker, Tie, PairPlayer, PairBanker)
		payout_settings_manager: Менеджер настроек выплат
		pair_betting_manager: Менеджер ставок на пары
		
	Returns:
		true если ставка включена в snapshot, false если отключена
	"""
	# Если snapshot пустой - используем текущее состояние (fallback)
	if filter_snapshot.is_empty():
		return is_bet_type_enabled_in_settings(bet_type, payout_settings_manager, pair_betting_manager)
	
	# Проверяем snapshot
	if filter_snapshot.has(bet_type):
		return filter_snapshot[bet_type]
	
	# Если типа нет в snapshot - используем текущее состояние (fallback)
	return is_bet_type_enabled_in_settings(bet_type, payout_settings_manager, pair_betting_manager)

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ SNAPSHOT
# ═══════════════════════════════════════════════════════════════════════════

func save_filter_snapshot(
	payout_settings_manager: PayoutSettingsManager = null,
	pair_betting_manager: PairBettingManager = null
) -> void:
	"""Сохранить снимок текущего состояния фильтра
	
	Вызывается при показке ставок для изоляции текущей раздачи от изменений фильтра.
	
	Args:
		payout_settings_manager: Менеджер настроек выплат
		pair_betting_manager: Менеджер ставок на пары
	"""
	filter_snapshot.clear()
	
	if payout_settings_manager:
		filter_snapshot["Player"] = payout_settings_manager.player_payout_enabled
		filter_snapshot["Banker"] = payout_settings_manager.banker_payout_enabled
		filter_snapshot["Tie"] = payout_settings_manager.tie_payout_enabled
	
	if pair_betting_manager:
		filter_snapshot["PairPlayer"] = pair_betting_manager.is_player_pair_bet_enabled()
		filter_snapshot["PairBanker"] = pair_betting_manager.is_banker_pair_bet_enabled()
	else:
		filter_snapshot["PairPlayer"] = false
		filter_snapshot["PairBanker"] = false

func clear_filter_snapshot() -> void:
	"""Очистить snapshot фильтра"""
	filter_snapshot.clear()

func has_filter_snapshot() -> bool:
	"""Проверить, есть ли сохранённый snapshot"""
	return not filter_snapshot.is_empty()

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ PENDING CHANGES
# ═══════════════════════════════════════════════════════════════════════════

func add_pending_filter_change(bet_type: String, enabled: bool) -> void:
	"""Добавить изменение фильтра в очередь
	
	Args:
		bet_type: Тип ставки
		enabled: Включена ли ставка
	"""
	pending_filter_changes[bet_type] = enabled

func clear_pending_filter_changes() -> void:
	"""Очистить очередь изменений фильтра"""
	pending_filter_changes.clear()

func has_pending_filter_changes() -> bool:
	"""Проверить, есть ли накопленные изменения"""
	return not pending_filter_changes.is_empty()

func get_pending_filter_changes() -> Dictionary:
	"""Получить накопленные изменения фильтра"""
	return pending_filter_changes.duplicate()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИМЕНЕНИЕ ИЗМЕНЕНИЙ
# ═══════════════════════════════════════════════════════════════════════════

func apply_pending_filter_changes(
	payout_settings_manager: PayoutSettingsManager = null,
	pair_betting_manager: PairBettingManager = null
) -> Dictionary:
	"""Применить накопленные изменения фильтра
	
	Args:
		payout_settings_manager: Менеджер настроек выплат
		pair_betting_manager: Менеджер ставок на пары
		
	Returns:
		Dictionary с информацией о применённых изменениях
	"""
	if pending_filter_changes.is_empty():
		return {
			"applied": false,
			"changes": {}
		}
	
	var applied_changes = {}
	
	# Применяем каждое изменение
	for bet_type in pending_filter_changes.keys():
		var enabled = pending_filter_changes[bet_type]
		var applied = false
		
		match bet_type:
			"Player":
				if payout_settings_manager:
					payout_settings_manager.player_payout_enabled = enabled
					applied = true
			"Banker":
				if payout_settings_manager:
					payout_settings_manager.banker_payout_enabled = enabled
					applied = true
			"Tie":
				if payout_settings_manager:
					payout_settings_manager.tie_payout_enabled = enabled
					applied = true
			"PairPlayer":
				if pair_betting_manager:
					pair_betting_manager.toggle_pair_player_bet(enabled)
					applied = true
			"PairBanker":
				if pair_betting_manager:
					pair_betting_manager.toggle_pair_banker_bet(enabled)
					applied = true
		
		if applied:
			applied_changes[bet_type] = enabled
	
	# Очищаем pending_changes
	pending_filter_changes.clear()
	
	return {
		"applied": true,
		"changes": applied_changes
	}

