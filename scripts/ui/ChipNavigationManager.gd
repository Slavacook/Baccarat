# res://scripts/ui/ChipNavigationManager.gd
# Менеджер клавиатурной навигации по ставкам
# Управляет перемещением фокуса по фишкам с помощью клавиатуры (WASD/стрелки)
# Интегрируется с BetCollectionPhaseManager для правильного порядка сбора/оплаты

extends RefCounted
class_name ChipNavigationManager

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

var chip_visual_manager: ChipVisualManager = null
var bet_collection_manager: BetCollectionPhaseManager = null
var chip_click_handler: ChipClickHandler = null
var navigation_frame: Control = null  # ChipNavigationFrame
var camera_manager: CameraManager = null  # Для определения текущей области камеры

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ НАВИГАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

# Текущая позиция навигации (фиксированная матрица)
var current_bet_type: String = "Player"  # "Player", "Banker", "Tie", "PairPlayer", "PairBanker"
var current_sector: int = 6  # 1-6

# Флаг активности навигации
var is_active: bool = false

# Порядок уровней для вертикальной навигации (4 уровня)
# Вниз: Player → Banker → Tie → Pairs → Player (цикл)
# Вверх: Player → Pairs → Tie → Banker → Player (цикл)
# Pairs включает PairPlayer и PairBanker (переключение горизонтально)
const LEVEL_ORDER = ["Player", "Banker", "Tie", "Pairs"]  # Вниз
const LEVEL_ORDER_REVERSE = ["Player", "Pairs", "Tie", "Banker"]  # Вверх

# Порядок секторов для горизонтальной навигации (справа налево)
const SECTOR_ORDER = [6, 5, 4, 3, 2, 1]  # Справа налево
const SECTOR_ORDER_REVERSE = [1, 2, 3, 4, 5, 6]  # Слева направо

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(
	p_chip_visual_manager: ChipVisualManager,
	p_bet_collection_manager: BetCollectionPhaseManager,
	p_chip_click_handler: ChipClickHandler,
	p_navigation_frame: Control = null,
	p_camera_manager: CameraManager = null
) -> void:
	"""Настроить менеджер навигации
	
	Args:
		p_chip_visual_manager: Менеджер визуализации фишек
		p_bet_collection_manager: Менеджер фазы сбора/оплаты
		p_chip_click_handler: Обработчик кликов на фишки
		p_navigation_frame: Визуальная рамка (опционально)
		p_camera_manager: Менеджер камеры (для определения текущей области)
	"""
	chip_visual_manager = p_chip_visual_manager
	bet_collection_manager = p_bet_collection_manager
	chip_click_handler = p_chip_click_handler
	navigation_frame = p_navigation_frame
	camera_manager = p_camera_manager
	
	DebugLogger.log("✅ ChipNavigationManager: настроен")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ АКТИВАЦИЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func activate() -> void:
	"""Активировать навигацию по ставкам"""
	if is_active:
		return
	
	is_active = true
	
	# Определяем текущую область камеры и устанавливаем начальную позицию
	_set_initial_focus_by_camera_area()
	
	# Показываем рамку на текущей позиции
	_update_frame_position()
	
	# Обновляем камеру для текущей позиции
	_update_camera_for_position()
	
	DebugLogger.log("⌨️ ChipNavigationManager: навигация активирована (позиция: %s, сектор %d)" % [
		current_bet_type, current_sector
	])

func deactivate() -> void:
	"""Деактивировать навигацию по ставкам"""
	if not is_active:
		return
	
	is_active = false
	
	# Скрываем рамку
	if navigation_frame:
		navigation_frame.hide_frame()
	
	DebugLogger.log("⌨️ ChipNavigationManager: навигация деактивирована")

# ═══════════════════════════════════════════════════════════════════════════
# УСТАНОВКА НАЧАЛЬНОГО ФОКУСА
# ═══════════════════════════════════════════════════════════════════════════

func _set_initial_focus_by_camera_area() -> void:
	"""Установить начальный фокус в зависимости от текущей области камеры"""
	var current_area = -1
	
	# Пытаемся получить область напрямую из camera_manager
	if camera_manager:
		current_area = camera_manager.current_area
		_set_focus_for_area(current_area)
	else:
		# Fallback: запрашиваем через EventBus
		if EventBus:
			# Используем массив для обхода проблемы с lambda capture
			var area_container = [current_area]
			var response_handler = func(area: int):
				if area_container[0] == -1:
					area_container[0] = area
					_set_focus_for_area(area)
			
			EventBus.camera_current_area_received.connect(response_handler, CONNECT_ONE_SHOT)
			EventBus.camera_current_area_requested.emit()
			# Устанавливаем фокус с задержкой (когда область будет получена)
			call_deferred("_set_focus_for_area", current_area)
		else:
			_set_focus_for_area(-1)

func _set_focus_for_area(area: int) -> void:
	"""Установить фокус для указанной области"""
	# Определяем начальный сектор на основе области камеры
	# area_1: секторы 1-2 → начинаем с сектора 2 (правый в области)
	# area_2: секторы 3-4 → начинаем с сектора 4 (правый в области)
	# area_3: секторы 5-6 → начинаем с сектора 6 (правый в области)
	# Если область не определена или общий план → начинаем с сектора 6
	
	match area:
		1:
			current_sector = 2  # Правый сектор в area_1
		2:
			current_sector = 4  # Правый сектор в area_2
		3:
			current_sector = 6  # Правый сектор в area_3
		_:
			current_sector = 6  # По умолчанию самый правый сектор
	
	# Всегда начинаем с Player
	current_bet_type = "Player"
	
	DebugLogger.log("📍 ChipNavigationManager: начальный фокус установлен (область камеры: %d, позиция: %s, сектор %d)" % [
		area, current_bet_type, current_sector
	])

func _is_chip_active(chip: ChipVisualManager.ChipInstance) -> bool:
	"""Проверить, активна ли фишка (не собрана и не оплачена)
	
	Args:
		chip: Фишка для проверки
		
	Returns:
		true если фишка активна, false если собрана/оплачена
	"""
	if not chip or not chip.node:
		return false
	
	# Проверяем видимость
	if not chip.node.visible:
		return false
	
	# Проверяем через bet_collection_manager
	if bet_collection_manager:
		# Проверяем, собрана ли ставка
		if bet_collection_manager.is_bet_collected(chip.bet_type, chip.position_index):
			return false
		
		# Проверяем, оплачена ли ставка (через payout_queue_manager)
		if bet_collection_manager.payout_queue_manager:
			var bet = bet_collection_manager.payout_queue_manager.get_bet_by_id(
				chip.bet_type, chip.position_index
			)
			if bet and bet.is_paid():
				return false
	
	return true

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КАМЕРОЙ
# ═══════════════════════════════════════════════════════════════════════════

func _update_camera_for_position() -> void:
	"""Обновить позицию камеры для текущей позиции"""
	var area = _get_area_from_sector(current_sector)
	
	if area > 0:
		EventBus.camera_zoom_requested.emit("area_%d" % area)
		DebugLogger.log("📷 ChipNavigationManager: камера → area_%d (сектор %d)" % [area, current_sector])

func _get_area_from_sector(sector: int) -> int:
	"""Определить область камеры по сектору
	
	Args:
		sector: Номер сектора (1-6)
		
	Returns:
		Номер области (1-3): 1-2 → area_1, 3-4 → area_2, 5-6 → area_3
	"""
	if sector <= 2:
		return 1
	elif sector <= 4:
		return 2
	else:
		return 3

# ═══════════════════════════════════════════════════════════════════════════
# ЛОГИКА НАВИГАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func move_focus(direction: String) -> void:
	"""Переместить фокус в указанном направлении
	
	Args:
		direction: "left", "right", "up", "down"
	"""
	if not is_active:
		return
	
	match direction:
		"left", "right":
			_move_horizontal(direction)
		"up", "down":
			_move_vertical(direction)
	
	# Обновляем рамку и камеру
	_update_frame_position()
	_update_camera_for_position()
	
	DebugLogger.log("⌨️ ChipNavigationManager: фокус перемещён (%s, сектор %d, направление: %s)" % [
		current_bet_type, current_sector, direction
	])

func _move_horizontal(direction: String) -> void:
	"""Перемещение по горизонтали (влево/вправо)"""
	# Для пар: последовательный обход всех секторов с чередованием PairBanker/PairPlayer
	# Порядок вправо: сектор1 PairBanker → PairPlayer → сектор2 PairBanker → PairPlayer → ...
	# Порядок влево: сектор6 PairPlayer → PairBanker → сектор5 PairPlayer → PairBanker → ...
	if current_bet_type == "PairPlayer" or current_bet_type == "PairBanker":
		if direction == "right":
			# Вправо: используем SECTOR_ORDER_REVERSE [1, 2, 3, 4, 5, 6]
			# PairBanker → PairPlayer (тот же сектор), PairPlayer → PairBanker (следующий сектор)
			if current_bet_type == "PairBanker":
				# PairBanker → PairPlayer (тот же сектор)
				current_bet_type = "PairPlayer"
			else:
				# PairPlayer → PairBanker (следующий сектор)
				var pairs_sector_order = SECTOR_ORDER_REVERSE
				var pairs_current_index = pairs_sector_order.find(current_sector)
				if pairs_current_index < 0:
					return
				
				var pairs_next_index = (pairs_current_index + 1) % pairs_sector_order.size()
				current_sector = pairs_sector_order[pairs_next_index]
				current_bet_type = "PairBanker"
		else:
			# Влево: используем SECTOR_ORDER [6, 5, 4, 3, 2, 1]
			# PairPlayer → PairBanker (тот же сектор), PairBanker → PairPlayer (следующий сектор в порядке влево)
			if current_bet_type == "PairPlayer":
				# PairPlayer → PairBanker (тот же сектор)
				current_bet_type = "PairBanker"
			else:
				# PairBanker → PairPlayer (следующий сектор в порядке влево)
				var pairs_sector_order_left = SECTOR_ORDER
				var pairs_current_index_left = pairs_sector_order_left.find(current_sector)
				if pairs_current_index_left < 0:
					return
				var pairs_next_index_left = (pairs_current_index_left + 1) % pairs_sector_order_left.size()
				current_sector = pairs_sector_order_left[pairs_next_index_left]
				current_bet_type = "PairPlayer"
		return
	
	# Для остальных уровней: переход между секторами
	var sector_order = SECTOR_ORDER if direction == "left" else SECTOR_ORDER_REVERSE
	var current_index = sector_order.find(current_sector)
	if current_index < 0:
		return
	
	var next_index = (current_index + 1) % sector_order.size()
	current_sector = sector_order[next_index]

func _move_vertical(direction: String) -> void:
	"""Перемещение по вертикали (вверх/вниз)"""
	# Определяем текущий уровень (для пар используем "Pairs")
	var current_level = _get_level_for_bet_type(current_bet_type)
	
	var level_order: Array[String] = []
	if direction == "down":
		for item in LEVEL_ORDER:
			level_order.append(item)
	else:
		for item in LEVEL_ORDER_REVERSE:
			level_order.append(item)
	
	var current_index = level_order.find(current_level)
	if current_index < 0:
		return
	
	var next_index = (current_index + 1) % level_order.size()
	var next_level = level_order[next_index]
	
	# Устанавливаем конкретный bet_type в зависимости от уровня
	match next_level:
		"Player":
			current_bet_type = "Player"
		"Banker":
			current_bet_type = "Banker"
		"Tie":
			current_bet_type = "Tie"
		"Pairs":
			# При переходе на уровень Pairs всегда начинаем с PairPlayer
			current_bet_type = "PairPlayer"

func _get_level_for_bet_type(bet_type: String) -> String:
	"""Получить уровень для типа ставки
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		Уровень: "Player", "Banker", "Tie" или "Pairs"
	"""
	if bet_type == "PairPlayer" or bet_type == "PairBanker":
		return "Pairs"
	return bet_type

func activate_current_chip() -> void:
	"""Активировать текущую фишку (если она есть в этой позиции)"""
	if not is_active:
		return
	
	# Проверяем, есть ли фишка в текущей позиции
	var chip = _get_chip_at_position(current_bet_type, current_sector)
	if not chip:
		# Пустая позиция - ничего не делаем
		DebugLogger.log("⌨️ ChipNavigationManager: позиция %s[сектор %d] пуста, активация пропущена" % [
			current_bet_type, current_sector
		])
		return
	
	if not _is_chip_active(chip):
		# Фишка уже обработана
		DebugLogger.log("⌨️ ChipNavigationManager: фишка %s[сектор %d] уже обработана" % [
			current_bet_type, current_sector
		])
		return
	
	if chip_click_handler:
		var position_index = GuestSectorMapper.get_position_index(current_sector, current_bet_type)
		chip_click_handler.handle_chip_click(current_bet_type, position_index)
		DebugLogger.log("⌨️ ChipNavigationManager: активирована фишка %s[сектор %d]" % [
			current_bet_type, current_sector
		])

func _get_chip_at_position(bet_type: String, sector: int) -> ChipVisualManager.ChipInstance:
	"""Получить фишку в указанной позиции (если есть)
	
	Args:
		bet_type: Тип ставки
		sector: Номер сектора (1-6)
		
	Returns:
		ChipInstance или null если фишки нет
	"""
	if not chip_visual_manager:
		return null
	
	var position_index = GuestSectorMapper.get_position_index(sector, bet_type)
	if position_index < 0:
		return null
	
	return chip_visual_manager.get_chip_instance(bet_type, position_index)

func _update_frame_position() -> void:
	"""Обновить позицию рамки на основе current_bet_type и current_sector"""
	if not navigation_frame:
		return
	
	# Получаем координаты позиции
	var position_index = GuestSectorMapper.get_position_index(current_sector, current_bet_type)
	if position_index < 0:
		DebugLogger.log_warning("⚠️ ChipNavigationManager: не найдена позиция для %s[сектор %d]" % [
			current_bet_type, current_sector
		])
		return
	
	if not ChipVisualManager.ALTERNATIVE_POSITIONS.has(current_bet_type):
		DebugLogger.log_warning("⚠️ ChipNavigationManager: тип ставки %s не найден в ALTERNATIVE_POSITIONS" % current_bet_type)
		return
	
	var positions = ChipVisualManager.ALTERNATIVE_POSITIONS[current_bet_type]
	if position_index >= positions.size():
		DebugLogger.log_warning("⚠️ ChipNavigationManager: position_index %d вне диапазона для %s" % [
			position_index, current_bet_type
		])
		return
	
	var coords = positions[position_index]
	
	# Показываем рамку на фиксированной позиции
	if navigation_frame.has_method("show_at_position"):
		navigation_frame.show_at_position(coords, current_bet_type)
	else:
		# Fallback: используем старый метод если доступен
		var chip = _get_chip_at_position(current_bet_type, current_sector)
		if chip:
			navigation_frame.show_at_chip(chip)
		else:
			# Показываем на фиксированных координатах
			_show_frame_at_coordinates(coords)

func _show_frame_at_coordinates(coords: Vector2) -> void:
	"""Показать рамку на указанных координатах (fallback метод)"""
	if not navigation_frame:
		return
	
	# Получаем размер фишки для этого типа (из оригинальной фишки)
	var chip_size = Vector2(100, 100)  # Размер по умолчанию
	if chip_visual_manager and chip_visual_manager.chip_nodes.has(current_bet_type):
		var chip_node = chip_visual_manager.chip_nodes[current_bet_type]
		if chip_node:
			chip_size = chip_node.size
	
	# Используем отступ из ChipNavigationFrame
	const FRAME_PADDING = 20
	var frame_pos = coords - Vector2(FRAME_PADDING, FRAME_PADDING)
	var frame_size = chip_size + Vector2(FRAME_PADDING * 2, FRAME_PADDING * 2)
	
	var parent = navigation_frame.get_parent()
	if parent is CanvasLayer:
		navigation_frame.global_position = frame_pos
	else:
		navigation_frame.position = frame_pos
	
	navigation_frame.size = frame_size
	navigation_frame.visible = true
	navigation_frame.modulate = Color.WHITE
	navigation_frame.modulate.a = 1.0

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА КЛАВИАТУРЫ
# ═══════════════════════════════════════════════════════════════════════════

func handle_keyboard_input(event: InputEventKey) -> bool:
	"""Обработать клавиатурный ввод
	
	Args:
		event: Событие клавиатуры
		
	Returns:
		true если событие обработано, false если нет
	"""
	if not is_active:
		return false
	
	if not event.pressed:
		return false
	
	match event.keycode:
		KEY_LEFT, KEY_A:
			move_focus("left")
			return true
		KEY_RIGHT, KEY_D:
			move_focus("right")
			return true
		KEY_UP, KEY_W:
			move_focus("up")
			return true
		KEY_DOWN, KEY_S:
			move_focus("down")
			return true
		KEY_ENTER, KEY_SPACE:
			# Активируем фишку в текущей позиции (если есть)
			activate_current_chip()
			return true
		KEY_ESCAPE:
			deactivate()
			return true
		_:
			return false

# ═══════════════════════════════════════════════════════════════════════════
# АВТОМАТИЧЕСКОЕ ПЕРЕМЕЩЕНИЕ ПОСЛЕ ДЕЙСТВИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _on_chip_collected(bet_type: String, position_index: int) -> void:
	"""Обработчик сбора фишки - фокус остаётся на текущей позиции"""
	if not is_active:
		return
	
	# Фокус остаётся на текущей позиции (навигация по фиксированной матрице)
	# Просто обновляем рамку
	_update_frame_position()
	DebugLogger.log("⌨️ ChipNavigationManager: фишка %s[%d] собрана, фокус остаётся на позиции %s[сектор %d]" % [
		bet_type, position_index, current_bet_type, current_sector
	])

func _on_chip_paid(bet_type: String, position_index: int) -> void:
	"""Обработчик оплаты фишки - фокус остаётся на текущей позиции"""
	if not is_active:
		return
	
	# Фокус остаётся на текущей позиции (навигация по фиксированной матрице)
	# Просто обновляем рамку
	_update_frame_position()
	DebugLogger.log("⌨️ ChipNavigationManager: фишка %s[%d] оплачена, фокус остаётся на позиции %s[сектор %d]" % [
		bet_type, position_index, current_bet_type, current_sector
	])

func _get_next_chip_for_collection(bet_type: String, _position_index: int) -> ChipVisualManager.ChipInstance:
	"""Получить следующую фишку для сбора после обработки текущей
	
	Использует последовательности из BetCollectionPhaseManager.
	После сбора фишки переходим влево (к следующей фишке того же типа).
	Если это последняя фишка группы - переходим на следующую группу.
	"""
	if not bet_collection_manager:
		return null
	
	# Используем последовательности сбора
	var group = bet_collection_manager.get_bet_group(bet_type)
	if not bet_collection_manager.collection_sequence.has(group):
		return null
	
	var sequence = bet_collection_manager.collection_sequence[group]
	var progress = bet_collection_manager.collection_progress.get(group, 0)
	
	# Проверяем, есть ли ещё фишки в текущей группе
	if progress < sequence.size():
		var next_bet = sequence[progress]
		if next_bet:
			# Ищем фишку по bet_type и position_index
			return _find_chip_by_bet(next_bet.get_bet_type(), next_bet.get_position_index())
	
	# Текущая группа закончена - переходим на следующую
	# Порядок: main → tie → pairs
	var group_order = ["main", "tie", "pairs"]
	var current_group_index = group_order.find(group)
	
	for i in range(current_group_index + 1, group_order.size()):
		var next_group = group_order[i]
		if bet_collection_manager.collection_sequence.has(next_group):
			var next_sequence = bet_collection_manager.collection_sequence[next_group]
			if next_sequence.size() > 0:
				var next_bet = next_sequence[0]
				if next_bet:
					return _find_chip_by_bet(next_bet.get_bet_type(), next_bet.get_position_index())
	
	return null

func _get_next_chip_for_payment(bet_type: String, _position_index: int) -> ChipVisualManager.ChipInstance:
	"""Получить следующую фишку для оплаты после обработки текущей
	
	Использует последовательности из BetCollectionPhaseManager.
	После оплаты фишки переходим влево (к следующей фишке того же типа).
	Если это последняя фишка группы - переходим на следующую группу.
	"""
	if not bet_collection_manager:
		return null
	
	# Используем последовательности оплаты
	var group = bet_collection_manager.get_bet_group(bet_type)
	if not bet_collection_manager.payment_sequence.has(group):
		return null
	
	var sequence = bet_collection_manager.payment_sequence[group]
	var progress = bet_collection_manager.payment_progress.get(group, 0)
	
	# Проверяем, есть ли ещё фишки в текущей группе
	if progress < sequence.size():
		var next_bet = sequence[progress]
		if next_bet:
			return _find_chip_by_bet(next_bet.get_bet_type(), next_bet.get_position_index())
	
	# Текущая группа закончена - переходим на следующую
	var group_order = ["main", "tie", "pairs"]
	var current_group_index = group_order.find(group)
	
	for i in range(current_group_index + 1, group_order.size()):
		var next_group = group_order[i]
		if bet_collection_manager.payment_sequence.has(next_group):
			var next_sequence = bet_collection_manager.payment_sequence[next_group]
			if next_sequence.size() > 0:
				var next_bet = next_sequence[0]
				if next_bet:
					return _find_chip_by_bet(next_bet.get_bet_type(), next_bet.get_position_index())
	
	return null

func _find_chip_by_bet(bet_type: String, position_index: int) -> ChipVisualManager.ChipInstance:
	"""Найти фишку по типу и индексу позиции
	
	Args:
		bet_type: Тип ставки
		position_index: Индекс позиции
		
	Returns:
		ChipInstance или null если не найдена
	"""
	if not chip_visual_manager:
		return null
	
	return chip_visual_manager.get_chip_instance(bet_type, position_index)
