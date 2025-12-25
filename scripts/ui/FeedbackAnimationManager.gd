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

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ АНИМАЦИИ (можно менять здесь)
# ═══════════════════════════════════════════════════════════════════════════

# Позиционирование
const START_Y: float = -230.0  # Начальная позиция Y относительно центра экрана (отрицательное = выше центра)
const END_Y_OFFSET: float = -40.0  # Смещение конечной позиции Y относительно начальной (отрицательное = выше)
const VERTICAL_SPACING: float = 90.0  # Расстояние между оповещениями при множественном показе

# Размер и стиль текста
const FONT_SIZE: int = 30   # Размер шрифта оповещений
const ITEM_MIN_WIDTH: float = 400.0  # Минимальная ширина контейнера оповещения
const ITEM_MIN_HEIGHT: float = 100.0  # Минимальная высота контейнера оповещения

# Скорость и длительность анимации
const MOVE_DURATION: float = 2.0  # Длительность движения вверх (секунды)
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
		# Инициализируем отслеживание терпения для всех гостей
		for guest_id in range(1, 7):
			previous_patience[guest_id] = GuestStatsManager.get_guest_patience(guest_id)
	else:
		push_error("FeedbackAnimationManager: GuestStatsManager не найден!")
	
	# Рестарт игры: сбрасываем отслеживание терпения
	if EventBus:
		EventBus.game_restarted.connect(_on_game_restarted)
		EventBus.payout_correct.connect(_on_payout_correct)
		print("✅ FeedbackAnimationManager: подключены сигналы EventBus")
	else:
		push_error("FeedbackAnimationManager: EventBus не найден!")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func show_feedback(message: String, color: Color, duration: float = 2.0):
	"""Показать оповещение с анимацией
	
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
	
	# Добавляем в список активных
	active_feedbacks.append(feedback_item)
	
	# Позиционируем (первое оповещение вверху, следующие ниже)
	# Получаем размер viewport для правильного позиционирования
	var viewport_size = get_viewport().get_visible_rect().size
	var center_y = viewport_size.y / 2.0
	
	var index = active_feedbacks.size() - 1
	var base_y = center_y + START_Y - (index * VERTICAL_SPACING)
	
	feedback_item.position.y = base_y
	print("🔔 FeedbackAnimationManager: позиция установлена y=%f (viewport_height=%f, center_y=%f)" % [base_y, viewport_size.y, center_y])
	
	# Анимируем
	var end_y = base_y + END_Y_OFFSET
	_animate_feedback_item(feedback_item, base_y, end_y, duration)

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

func _remove_feedback_item(item: Control):
	"""Удаляет оповещение из списка и с экрана"""
	if not is_instance_valid(item):
		return
	
	# Удаляем из списка активных
	var index = active_feedbacks.find(item)
	if index >= 0:
		active_feedbacks.remove_at(index)
	
	# Обновляем позиции оставшихся оповещений
	_update_feedback_positions()
	
	# Удаляем из дерева
	if is_instance_valid(item) and item.get_parent():
		item.queue_free()

func _update_feedback_positions():
	"""Обновляет позиции всех активных оповещений после удаления одного"""
	for i in range(active_feedbacks.size()):
		var item = active_feedbacks[i]
		if not is_instance_valid(item):
			continue
		
		var viewport_size = get_viewport().get_visible_rect().size
		var center_y = viewport_size.y / 2.0
		var target_y = center_y + START_Y - (i * VERTICAL_SPACING)
		
		# Плавно перемещаем к новой позиции
		if abs(item.position.y - target_y) > 1.0:
			var tween: Tween = item.create_tween()
			tween.tween_property(item, "position:y", target_y, 0.3)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_patience_changed(guest_id: int, new_patience: int):
	"""Обработчик изменения терпения гостя - показываем оповещение только при увеличении"""
	# Получаем предыдущее значение терпения
	var old_patience = previous_patience.get(guest_id, 0)
	
	# Сохраняем новое значение для следующего раза
	previous_patience[guest_id] = new_patience
	
	# Если терпение увеличилось - показываем оповещение
	if new_patience > old_patience:
		print("🔔 FeedbackAnimationManager: показываю оповещение о терпении для гостя %d (%d -> %d)" % [guest_id, old_patience, new_patience])
		show_feedback(
			"-5%% Терпение. Гость %d" % guest_id,
			Color(0.9, 0.2, 0.2),  # Красный
			2.0
		)

func _on_game_restarted():
	"""Обработчик рестарта игры - сбрасываем отслеживание терпения"""
	previous_patience.clear()
	# Инициализируем отслеживание терпения для всех гостей (все должны быть 0 после рестарта)
	for guest_id in range(1, 7):
		previous_patience[guest_id] = 0

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
			show_feedback(
				"+%d ЧАЕВЫЕ" % tip_amount,
				Color(0.2, 0.9, 0.2),  # Зеленый
				2.0
			)
