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
const LEVEL_ORDER: Array[String] = ["Player", "Banker", "Tie", "Pairs"]  # Вниз
const LEVEL_ORDER_REVERSE: Array[String] = ["Player", "Pairs", "Tie", "Banker"]  # Вверх

# Порядок секторов для горизонтальной навигации (справа налево)
const SECTOR_ORDER: Array[int] = [6, 5, 4, 3, 2, 1]  # Справа налево
const SECTOR_ORDER_REVERSE: Array[int] = [1, 2, 3, 4, 5, 6]  # Слева направо

# Маппинг области камеры к правому сектору в области
const AREA_TO_RIGHT_SECTOR = {
	1: 2,  # area_1 → сектор 2
	2: 4,  # area_2 → сектор 4
	3: 6,  # area_3 → сектор 6
}
const DEFAULT_SECTOR = 6  # По умолчанию самый правый сектор

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
	current_sector = AREA_TO_RIGHT_SECTOR.get(area, DEFAULT_SECTOR)
	
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
	# Для пар: специальная логика последовательного обхода
	if _is_pairs_level():
		_move_horizontal_pairs(direction)
		return
	
	# Для остальных уровней: переход между секторами
	_move_horizontal_regular(direction)

func _is_pairs_level() -> bool:
	"""Проверить, находимся ли мы на уровне пар"""
	return current_bet_type == "PairPlayer" or current_bet_type == "PairBanker"

func _move_horizontal_pairs(direction: String) -> void:
	"""Перемещение по горизонтали для уровня пар
	Порядок вправо: сектор1 PairBanker → PairPlayer → сектор2 PairBanker → PairPlayer → ...
	Порядок влево: сектор6 PairPlayer → PairBanker → сектор5 PairPlayer → PairBanker → ...
	"""
	if direction == "right":
		_move_pairs_right()
	else:
		_move_pairs_left()

func _move_pairs_right() -> void:
	"""Перемещение вправо на уровне пар"""
	if current_bet_type == "PairBanker":
		# PairBanker → PairPlayer (тот же сектор)
		current_bet_type = "PairPlayer"
	else:
		# PairPlayer → PairBanker (следующий сектор)
		_move_to_next_sector_in_order(SECTOR_ORDER_REVERSE)
		current_bet_type = "PairBanker"

func _move_pairs_left() -> void:
	"""Перемещение влево на уровне пар"""
	if current_bet_type == "PairPlayer":
		# PairPlayer → PairBanker (тот же сектор)
		current_bet_type = "PairBanker"
	else:
		# PairBanker → PairPlayer (следующий сектор в порядке влево)
		_move_to_next_sector_in_order(SECTOR_ORDER)
		current_bet_type = "PairPlayer"

func _move_horizontal_regular(direction: String) -> void:
	"""Перемещение по горизонтали для обычных уровней"""
	var sector_order = SECTOR_ORDER if direction == "left" else SECTOR_ORDER_REVERSE
	_move_to_next_sector_in_order(sector_order)

func _move_to_next_sector_in_order(sector_order: Array) -> void:
	"""Переместить фокус на следующий сектор в указанном порядке
	
	Args:
		sector_order: Массив секторов в порядке навигации
	"""
	var current_index = sector_order.find(current_sector)
	if current_index < 0:
		return
	
	var next_index = (current_index + 1) % sector_order.size()
	current_sector = sector_order[next_index] as int

func _move_vertical(direction: String) -> void:
	"""Перемещение по вертикали (вверх/вниз)"""
	var current_level = _get_level_for_bet_type(current_bet_type)
	var level_order = LEVEL_ORDER if direction == "down" else LEVEL_ORDER_REVERSE
	
	var next_level = _get_next_level_in_order(level_order, current_level)
	if next_level.is_empty():
		return
	
	# Устанавливаем конкретный bet_type в зависимости от уровня
	current_bet_type = _get_bet_type_for_level(next_level)

func _get_next_level_in_order(level_order: Array, current_level: String) -> String:
	"""Получить следующий уровень в указанном порядке
	
	Args:
		level_order: Массив уровней в порядке навигации
		current_level: Текущий уровень
		
	Returns:
		Следующий уровень или пустая строка если не найден
	"""
	var current_index = level_order.find(current_level)
	if current_index < 0:
		return ""
	
	var next_index = (current_index + 1) % level_order.size()
	return level_order[next_index] as String

func _get_bet_type_for_level(level: String) -> String:
	"""Получить bet_type для указанного уровня"""
	match level:
		"Player":
			return "Player"
		"Banker":
			return "Banker"
		"Tie":
			return "Tie"
		"Pairs":
			# При переходе на уровень Pairs всегда начинаем с PairPlayer
			return "PairPlayer"
		_:
			return current_bet_type

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

func handle_input(event: InputEvent) -> bool:
	"""Обработать ввод (клавиатура или геймпад)
	
	Args:
		event: Событие ввода
		
	Returns:
		true если событие обработано, false если нет
	"""
	if not is_active:
		return false
	
	# Отладка: логируем события геймпада
	if event is InputEventJoypadButton:
		var joypad_event = event as InputEventJoypadButton
		if joypad_event.pressed:
			DebugLogger.log("🎮 ChipNavigationManager: геймпад кнопка %d нажата" % joypad_event.button_index)
	
	# Используем Input Actions для поддержки клавиатуры и геймпада
	# В handle_input() используем event.is_action_pressed() для проверки конкретного события
	if event.is_action_pressed("left"):
		move_focus("left")
		return true
	elif event.is_action_pressed("right"):
		move_focus("right")
		return true
	elif event.is_action_pressed("up"):
		move_focus("up")
		return true
	elif event.is_action_pressed("down"):
		move_focus("down")
		return true
	elif event.is_action_pressed("action"):
		# Активируем фишку в текущей позиции (если есть)
		activate_current_chip()
		return true
	elif event.is_action_pressed("exit"):
		deactivate()
		return true
	
	return false

# Обратная совместимость (deprecated)
func handle_keyboard_input(event: InputEventKey) -> bool:
	"""Обработать клавиатурный ввод (deprecated, используйте handle_input)
	
	Args:
		event: Событие клавиатуры
		
	Returns:
		true если событие обработано, false если нет
	"""
	return handle_input(event)

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
