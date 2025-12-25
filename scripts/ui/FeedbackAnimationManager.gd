# res://scripts/ui/FeedbackAnimationManager.gd
# Менеджер для показа всех всплывающих оповещений (терпение, чаевые, ошибки и т.д.)
# Работает поверх всех окон, поддерживает множественные оповещения одновременно

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var feedback_canvas: CanvasLayer = null
var feedback_container: Control = null
var active_feedbacks: Array = []  # Массив активных FeedbackItem

# Отслеживание предыдущих значений терпения (для определения увеличения)
var previous_patience: Dictionary = {}  # {guest_id: patience}

# Очередь оповещений для каскадного эффекта
var last_feedback_start_time: float = 0.0  # Время последнего старта оповещения
var pending_feedbacks: Array = []  # Очередь ожидающих оповещений: [{item: Control, message: String, color: Color, duration: float}]

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ АНИМАЦИИ (можно менять здесь)
# ═══════════════════════════════════════════════════════════════════════════

# Позиционирование
const START_Y: float = -230.0  # Начальная позиция Y относительно центра экрана (отрицательное = выше центра)
const END_Y_OFFSET: float = -40.0  # Смещение конечной позиции Y относительно начальной (отрицательное = выше)
const FEEDBACK_START_DELAY: float = 1.5  # Задержка между стартами оповещений (секунды) для каскадного эффекта

# Размер и стиль текста
const FONT_SIZE: int = 30   # Размер шрифта оповещений
const ITEM_MIN_WIDTH: float = 400.0  # Минимальная ширина контейнера оповещения
const ITEM_MIN_HEIGHT: float = 100.0  # Минимальная высота контейнера оповещения

# Скорость и длительность анимации
const MOVE_DURATION: float = 2.5  # Длительность движения вверх (секунды)
const FADE_DURATION: float = 1.9  # Длительность fade out (секунды) - должна быть меньше MOVE_DURATION
const TOTAL_DURATION: float = 3.0  # Общая длительность показа оповещения (секунды)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Инициализация с небольшой задержкой, чтобы дерево сцены было готово
	await get_tree().process_frame
	_setup_canvas()
	_connect_signals()
	print("✅ FeedbackAnimationManager готов")

func _setup_canvas():
	"""Создает CanvasLayer с высоким z-index для работы поверх всех окон"""
	feedback_canvas = CanvasLayer.new()
	feedback_canvas.name = "FeedbackCanvas"
	feedback_canvas.layer = 210  # Выше чем PayoutOverlay (обычно 200)
	
	# Создаем контейнер для всех оповещений
	feedback_container = Control.new()
	feedback_container.name = "FeedbackContainer"
	feedback_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Не блокируем клики
	
	feedback_canvas.add_child(feedback_container)
	
	# Добавляем в корень дерева сцены с отложенным вызовом
	var root = get_tree().root
	if root:
		root.add_child.call_deferred(feedback_canvas)
		# Ждем, пока CanvasLayer будет добавлен в дерево
		await get_tree().process_frame
		print("✅ FeedbackAnimationManager: CanvasLayer создан (layer=210)")

func _connect_signals():
	"""Подписываемся на события для автоматического показа оповещений"""
	# Терпение: подписываемся на изменение терпения гостя
	if GuestStatsManager:
		GuestStatsManager.guest_patience_changed.connect(_on_patience_changed)
		print("✅ FeedbackAnimationManager: подключен сигнал guest_patience_changed")
		# Инициализируем отслеживание терпения для всех гостей (начальное значение 100%)
		for guest_id in range(1, 7):
			previous_patience[guest_id] = GuestStatsManager.get_guest_patience(guest_id)
	else:
		push_error("FeedbackAnimationManager: GuestStatsManager не найден!")
	
	# Рестарт игры: сбрасываем отслеживание терпения
	if EventBus:
		EventBus.game_restarted.connect(_on_game_restarted)
		EventBus.payout_correct.connect(_on_payout_correct)
		EventBus.life_lost.connect(_on_life_lost)
		print("✅ FeedbackAnimationManager: подключены сигналы EventBus")
	else:
		push_error("FeedbackAnimationManager: EventBus не найден!")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ТИПИЗИРОВАННЫЕ ОПОВЕЩЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func show_tips(amount: int):
	"""Показать оповещение о чаевых"""
	var config = FeedbackTypes.CONFIGS[FeedbackTypes.Type.TIPS]
	show_feedback(
		config.format % amount,
		config.color,
		config.duration
	)

func show_patience(guest_id: int):
	"""Показать оповещение о терпении"""
	var config = FeedbackTypes.CONFIGS[FeedbackTypes.Type.PATIENCE]
	show_feedback(
		config.format % guest_id,
		config.color,
		config.duration
	)

func show_heart():
	"""Показать оповещение о потере сердца"""
	var config = FeedbackTypes.CONFIGS[FeedbackTypes.Type.HEART]
	show_feedback(
		config.message,
		config.color,
		config.duration
	)

func show_penalty(amount: int):
	"""Показать оповещение о штрафе на чаевые"""
	var config = FeedbackTypes.CONFIGS[FeedbackTypes.Type.PENALTY]
	show_feedback(
		config.format % amount,
		config.color,
		config.duration
	)

# ═══════════════════════════════════════════════════════════════════════════
# БАЗОВЫЙ МЕТОД (используется типизированными методами выше)
# ═══════════════════════════════════════════════════════════════════════════

func show_feedback(message: String, color: Color, duration: float = 2.0):
	"""Показать оповещение с анимацией (каскадный эффект с задержкой 0.5 сек)
	
	Args:
		message: Текст сообщения
		color: Цвет текста (красный для ошибок/терпения, зеленый для успеха/чаевых)
		duration: Длительность показа в секундах (по умолчанию 2.0)
	"""
	print("🔔 FeedbackAnimationManager.show_feedback вызван: '%s'" % message)
	
	if not feedback_container or not is_instance_valid(feedback_container):
		push_error("FeedbackAnimationManager: контейнер не инициализирован")
		return
	
	if not feedback_container.is_inside_tree():
		push_warning("FeedbackAnimationManager: контейнер еще не в дереве сцены (is_inside_tree=false)")
		return
	
	# Создаем новый FeedbackItem
	var feedback_item = _create_feedback_item(message, color)
	
	# Все оповещения стартуют в одной позиции
	var viewport_size = get_viewport().get_visible_rect().size
	var center_y = viewport_size.y / 2.0
	var base_y = center_y + START_Y
	
	feedback_item.position.y = base_y
	feedback_item.modulate.a = 0.0  # Скрываем до старта
	feedback_item.visible = false  # Скрываем до старта
	
	# Добавляем в очередь для запуска с задержкой
	pending_feedbacks.append({
		"item": feedback_item,
		"message": message,
		"color": color,
		"duration": duration,
		"base_y": base_y
	})
	
	# Если это первое оповещение - стартуем сразу, иначе будет обработано в _process_next_feedback
	if pending_feedbacks.size() == 1:
		_process_next_feedback()

func _create_feedback_item(message: String, color: Color) -> Control:
	"""Создает новый элемент оповещения программно"""
	var container = Control.new()
	container.name = "FeedbackItem_%d" % Time.get_ticks_msec()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = Vector2(ITEM_MIN_WIDTH, ITEM_MIN_HEIGHT)
	# Позиционируем относительно центра по горизонтали (y будет установлен позже)
	var viewport_size = get_viewport().get_visible_rect().size
	container.position.x = (viewport_size.x - container.custom_minimum_size.x) / 2.0
	container.position.y = 0  # Временно, будет установлено в show_feedback
	
	var label = Label.new()
	label.name = "Label"
	label.text = message
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	container.add_child(label)
	feedback_container.add_child(container)
	
	# Начальное состояние
	container.modulate.a = 1.0
	container.visible = true
	
	# Позиция y будет установлена в show_feedback
	
	return container

func _animate_feedback_item(item: Control, start_y: float, end_y: float, duration: float):
	"""Анимирует оповещение (движение вверх + fade out)"""
	if not is_instance_valid(item):
		return
	
	# Создаем твин для анимации
	var tween: Tween = item.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	
	# Параллельные анимации: движение вверх + fade out
	tween.set_parallel(true)
	tween.tween_property(item, "position:y", end_y, MOVE_DURATION).from(start_y)
	tween.tween_property(item, "modulate:a", 0.0, FADE_DURATION).from(1.0)
	tween.set_parallel(false)
	
	# Ждем оставшееся время (если duration больше MOVE_DURATION)
	tween.tween_interval(max(0.0, duration - MOVE_DURATION))
	
	# После анимации - удаляем элемент
	tween.tween_callback(func():
		if is_instance_valid(item):
			_remove_feedback_item(item)
	)

func _process_next_feedback():
	"""Обрабатывает следующее оповещение из очереди с задержкой"""
	if pending_feedbacks.is_empty():
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var delay_needed = 0.0
	
	# Если уже был старт - вычисляем задержку до следующего
	if last_feedback_start_time > 0.0:
		var time_since_last = current_time - last_feedback_start_time
		if time_since_last < FEEDBACK_START_DELAY:
			delay_needed = FEEDBACK_START_DELAY - time_since_last
	
	# Если нужна задержка - ждем, иначе стартуем сразу
	if delay_needed > 0.0:
		await get_tree().create_timer(delay_needed).timeout
	
	# Берем первое из очереди
	var feedback_data = pending_feedbacks.pop_front()
	var feedback_item = feedback_data.item
	
	if not is_instance_valid(feedback_item):
		# Если элемент уже удален - пропускаем и обрабатываем следующее
		_process_next_feedback()
		return
	
	# Обновляем время последнего старта
	last_feedback_start_time = Time.get_ticks_msec() / 1000.0
	
	# Добавляем в список активных
	active_feedbacks.append(feedback_item)
	
	# Показываем и запускаем анимацию
	feedback_item.modulate.a = 1.0
	feedback_item.visible = true
	var base_y = feedback_data.base_y
	var end_y = base_y + END_Y_OFFSET
	_animate_feedback_item(feedback_item, base_y, end_y, feedback_data.duration)
	
	print("🔔 FeedbackAnimationManager: оповещение стартовало: '%s' (y=%f)" % [feedback_data.message, base_y])
	
	# Обрабатываем следующее из очереди (если есть)
	if not pending_feedbacks.is_empty():
		_process_next_feedback()

func _remove_feedback_item(item: Control):
	"""Удаляет оповещение из списка и с экрана"""
	if not is_instance_valid(item):
		return
	
	# Удаляем из списка активных
	var index = active_feedbacks.find(item)
	if index >= 0:
		active_feedbacks.remove_at(index)
	
	# Удаляем из дерева
	if is_instance_valid(item) and item.get_parent():
		item.queue_free()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_patience_changed(guest_id: int, new_patience: int):
	"""Обработчик изменения терпения гостя - показываем оповещение только при уменьшении"""
	# Получаем предыдущее значение терпения (по умолчанию 100% = полное терпение)
	var old_patience = previous_patience.get(guest_id, 100)
	
	# Сохраняем новое значение для следующего раза
	previous_patience[guest_id] = new_patience
	
	# Если терпение уменьшилось - показываем оповещение
	if new_patience < old_patience:
		print("🔔 FeedbackAnimationManager: показываю оповещение о терпении для гостя %d (%d%% -> %d%%)" % [guest_id, old_patience, new_patience])
		show_patience(guest_id)

func _on_game_restarted():
	"""Обработчик рестарта игры - сбрасываем отслеживание терпения"""
	previous_patience.clear()
	# Инициализируем отслеживание терпения для всех гостей (все должны быть 100% после рестарта)
	for guest_id in range(1, 7):
		previous_patience[guest_id] = 100

func _on_life_lost(_remaining_lives: int):
	"""Обработчик потери жизни - показываем оповещение"""
	show_heart()

func _on_payout_correct(_collected: float, expected: float, bet_type: String, position_index: int):
	"""Обработчик правильной выплаты - показываем оповещение о чаевых"""
	# Проверяем, является ли ставка гостевой
	if bet_type.is_empty() or position_index < 0:
		return
	
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	if sector < 1 or sector > 6:
		return
	
	# Это гостевая ставка и есть выигрыш - показываем чаевые
	if expected > 0:
		var guest_id = sector
		var tip_amount = TipCalculator.calculate_tip(expected, bet_type, guest_id)
		
		if tip_amount > 0:
			print("🔔 FeedbackAnimationManager: показываю оповещение о чаевых: +%d" % tip_amount)
			show_tips(tip_amount)
