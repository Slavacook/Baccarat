# res://scripts/GuestBetDisplayCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР ОТОБРАЖЕНИЯ СТАВОК ГОСТЕЙ
# Координирует получение, фильтрацию и подготовку ставок гостей для отображения
# Не создаёт UI элементы напрямую, возвращает инструкции
# ═══════════════════════════════════════════════════════════════════════════

class_name GuestBetDisplayCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СТРУКТУРА ИНСТРУКЦИИ ДЛЯ ОТОБРАЖЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

# Структура инструкции для отображения фишки:
# {
#   "bet_type": String,        # Тип ставки (Player, Banker, Tie, etc.)
#   "position_index": int,     # Индекс позиции
#   "coords": Vector2,         # Координаты для размещения
#   "stake": float,            # Размер ставки
#   "sector": int,             # Сектор гостя (1-6)
#   "guest_id": int            # ID гостя (для логирования)
# }

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНОЙ МЕТОД
# ═══════════════════════════════════════════════════════════════════════════

func get_display_instructions(
	guest_bet_storage: GuestBetStorage,
	bet_filter_manager: BetFilterManager,
	payout_settings_manager: PayoutSettingsManager = null,
	pair_betting_manager: PairBettingManager = null
) -> Array[Dictionary]:
	"""Получить инструкции для отображения ставок гостей
	
	Args:
		guest_bet_storage: Хранилище ставок гостей
		bet_filter_manager: Менеджер фильтров ставок
		payout_settings_manager: Менеджер настроек выплат
		pair_betting_manager: Менеджер ставок на пары
		
	Returns:
		Array[Dictionary] с инструкциями для отображения каждой ставки
	"""
	var instructions: Array[Dictionary] = []
	
	if not guest_bet_storage:
		return instructions
	
	var guests_with_bets = guest_bet_storage.get_guests_with_bets()
	if guests_with_bets.is_empty():
		return instructions
	
	# Обрабатываем ставки каждого гостя
	for guest_id in guests_with_bets:
		var bets = guest_bet_storage.get_guest_bets(guest_id)
		
		for bet in bets:
			var bet_type = bet.get_bet_type()
			
			# Фильтруем ставки через менеджер фильтров
			if not bet_filter_manager.is_bet_type_enabled_in_settings(
				bet_type, payout_settings_manager, pair_betting_manager
			):
				continue  # Ставка отфильтрована
			
			var sector = bet.get_sector()
			var pos_idx = bet.get_position_index()
			var stake = bet.get_stake()
			
			# Получаем координаты через GuestSectorMapper
			var coords = GuestSectorMapper.get_position_coordinates(sector, bet_type)
			if coords == Vector2.ZERO:
				continue  # Координаты не найдены
			
			# Добавляем инструкцию
			instructions.append({
				"bet_type": bet_type,
				"position_index": pos_idx,
				"coords": coords,
				"stake": stake,
				"sector": sector,
				"guest_id": guest_id
			})
	
	return instructions

func get_guests_with_bets_count(
	guest_bet_storage: GuestBetStorage
) -> int:
	"""Получить количество гостей со ставками
	
	Args:
		guest_bet_storage: Хранилище ставок гостей
		
	Returns:
		Количество гостей со ставками
	"""
	if not guest_bet_storage:
		return 0
	
	var guests_with_bets = guest_bet_storage.get_guests_with_bets()
	return guests_with_bets.size()

func get_bets_count_for_guest(
	guest_bet_storage: GuestBetStorage,
	guest_id: int
) -> int:
	"""Получить количество ставок для конкретного гостя
	
	Args:
		guest_bet_storage: Хранилище ставок гостей
		guest_id: ID гостя
		
	Returns:
		Количество ставок гостя
	"""
	if not guest_bet_storage:
		return 0
	
	var bets = guest_bet_storage.get_guest_bets(guest_id)
	return bets.size() if bets else 0

