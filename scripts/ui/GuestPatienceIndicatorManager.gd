# res://scripts/ui/GuestPatienceIndicatorManager.gd
# Менеджер для управления индикаторами терпения всех гостей
# Создает, позиционирует и обновляет 6 индикаторов на игровом столе

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Смещение индикатора относительно координат фишки
# Индикатор размещается выше фишки гостя
const INDICATOR_OFFSET = Vector2(0, -80)  # Смещение вверх на 80 пикселей

# Путь к сцене индикатора (если используем сцену) или создаем программно
const INDICATOR_SCENE_PATH = ""  # Пока создаем программно

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Ссылки на индикаторы для каждого гостя (1-6)
var indicators: Dictionary = {}  # {guest_id: GuestPatienceIndicator}

# Родительский узел для размещения индикаторов (обычно Game scene)
var parent_node: Node2D = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(p_parent_node: Node2D):
	"""Инициализация менеджера
	
	Args:
		p_parent_node: Родительский узел (Game scene), где будут размещены индикаторы
	"""
	parent_node = p_parent_node
	
	# Создаем индикаторы для всех 6 гостей
	for guest_id in range(1, 7):
		_create_indicator(guest_id)
	
	# Подписываемся на события
	_connect_signals()
	
	print("✅ GuestPatienceIndicatorManager: создано %d индикаторов" % indicators.size())

func _create_indicator(guest_id: int):
	"""Создать индикатор для гостя"""
	
	# Создаем Control как корневой узел
	var indicator = Control.new()
	indicator.name = "GuestPatienceIndicator_%d" % guest_id
	indicator.visible = false
	indicator.z_index = 100  # Выше фишек, но ниже других UI элементов
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Создаем Panel как фон
	var panel = Panel.new()
	panel.name = "Panel"
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.7)  # Полупрозрачный черный фон
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.size = Vector2(200, 90)  # Увеличили высоту для шкалы квадратиков
	indicator.add_child(panel)
	
	# Создаем VBoxContainer для содержимого
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Устанавливаем anchors для VBoxContainer
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	
	# Создаем контейнер для шкалы терпения (10 квадратиков)
	var patience_container = HBoxContainer.new()
	patience_container.name = "PatienceContainer"
	patience_container.add_theme_constant_override("separation", 2)
	patience_container.alignment = HBoxContainer.ALIGNMENT_CENTER
	vbox.add_child(patience_container)
	
	# Создаем 10 квадратиков для шкалы терпения
	for i in range(10):
		var square = ColorRect.new()
		square.name = "Square_%d" % i
		square.custom_minimum_size = Vector2(16, 16)  # Размер квадратика
		square.color = Color(0.2, 0.8, 0.2)  # Зеленый по умолчанию
		patience_container.add_child(square)
	
	# Создаем Label для таймера
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "⏱ 0s"
	timer_label.add_theme_font_size_override("font_size", 12)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(timer_label)
	
	# Создаем Label для процента урезания
	var reduction_label = Label.new()
	reduction_label.name = "ReductionLabel"
	reduction_label.text = "Чаевые: 0%"
	reduction_label.add_theme_font_size_override("font_size", 12)
	reduction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reduction_label)
	
	# НЕ добавляем скрипт - используем узлы напрямую
	# Создаем ссылки на узлы для прямого доступа
	# (скрипт GuestPatienceIndicator будет использоваться при необходимости)
	
	# Устанавливаем guest_id через custom property (можно добавить позже через metadata)
	# Пока используем name для идентификации
	
	# Добавляем в родительский узел
	if parent_node:
		parent_node.add_child(indicator)
	
	# Сохраняем ссылку
	indicators[guest_id] = indicator
	
	# Позиционируем индикатор
	_update_indicator_position(guest_id)
	
	# Изначально скрываем (покажем когда появится терпение)
	indicator.visible = false
	
	print("  ✅ Создан индикатор для гостя %d" % guest_id)

func _update_indicator_position(guest_id: int):
	"""Обновить позицию индикатора на основе координат сектора гостя"""
	if not indicators.has(guest_id):
		return
	
	var indicator = indicators[guest_id]
	
	# Получаем координаты первой позиции Player в секторе гостя
	var sector_coords = GuestSectorMapper.get_position_coordinates(guest_id, "Player")
	
	if sector_coords == Vector2.ZERO:
		# Если нет координат для Player, пробуем Banker
		sector_coords = GuestSectorMapper.get_position_coordinates(guest_id, "Banker")
	
	if sector_coords == Vector2.ZERO:
		# Если и Banker нет, пробуем Tie
		sector_coords = GuestSectorMapper.get_position_coordinates(guest_id, "Tie")
	
	if sector_coords != Vector2.ZERO:
		# Позиционируем индикатор выше фишки с учетом смещения
		var indicator_pos = sector_coords + INDICATOR_OFFSET
		indicator.global_position = indicator_pos
	else:
		push_error("GuestPatienceIndicatorManager: не удалось найти координаты для сектора %d" % guest_id)

func _connect_signals():
	"""Подписаться на события терпения и таймеров"""
	if GuestStatsManager:
		GuestStatsManager.guest_patience_changed.connect(_on_patience_changed)
	
	# Таймер обновления (каждую секунду для обновления таймера)
	# Используем _process для обновления каждую секунду

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_patience_changed(changed_guest_id: int, _new_patience: int):
	"""Обработчик изменения терпения гостя"""
	_update_indicator(changed_guest_id)

func _process(_delta: float):
	"""Обновление индикаторов каждую секунду (для таймера)"""
	# Обновляем все индикаторы, у которых есть активные таймеры или терпение > 0
	for guest_id in range(1, 7):
		var patience = GuestStatsManager.get_guest_patience(guest_id)
		if patience > 0 or PatienceTimerManager.has_active_timer(guest_id):
			_update_indicator(guest_id)

func _update_indicator(guest_id: int):
	"""Обновить данные индикатора для гостя"""
	if not indicators.has(guest_id):
		return
	
	var indicator_control = indicators[guest_id]
	if not is_instance_valid(indicator_control):
		return
	
	var patience = GuestStatsManager.get_guest_patience(guest_id)
	
	# Если терпение = 0, скрываем индикатор
	if patience <= 0:
		indicator_control.visible = false
		return
	
	# Показываем индикатор
	indicator_control.visible = true
	
	# Получаем узлы
	var panel = indicator_control.get_node_or_null("Panel")
	if not panel:
		return
	
	var vbox = panel.get_node_or_null("VBoxContainer")
	if not vbox:
		return
	
	var patience_container = vbox.get_node_or_null("PatienceContainer")
	var timer_label = vbox.get_node_or_null("TimerLabel")
	var reduction_label = vbox.get_node_or_null("ReductionLabel")
	
	# Обновляем шкалу терпения (10 квадратиков)
	if patience_container:
		# Вычисляем количество красных квадратиков (справа налево)
		var red_squares_count = int(float(patience) / 10.0)  # Каждые 10% = 1 красный квадрат
		
		# Обновляем цвета квадратиков (справа налево)
		var squares = patience_container.get_children()
		for i in range(squares.size()):
			var square = squares[i]
			if not square:
				continue
			
			# Индекс с конца (0 = самый правый, 9 = самый левый)
			var index_from_right = squares.size() - 1 - i
			
			# Если индекс меньше количества красных квадратов - делаем красным
			if index_from_right < red_squares_count:
				square.color = Color(0.8, 0.2, 0.2)  # Красный
			else:
				square.color = Color(0.2, 0.8, 0.2)  # Зеленый
	
	# Обновляем таймер
	if timer_label:
		var timer_remaining = 0
		if PatienceTimerManager.has_active_timer(guest_id):
			timer_remaining = PatienceTimerManager.get_remaining_time(guest_id)
			# Форматируем время: минуты и секунды для таймера 5 минут
			var minutes = int(float(timer_remaining) / 60.0)
			var seconds = timer_remaining % 60
			if minutes > 0:
				timer_label.text = "⏱ %d:%02d" % [minutes, seconds]
			else:
				timer_label.text = "⏱ %ds" % timer_remaining
			timer_label.visible = true
		else:
			timer_label.visible = false
	
	# Обновляем процент чаевых (100 - терпение)%
	if reduction_label:
		var tips_percentage = 100 - patience  # Процент чаевых
		
		if tips_percentage >= 100:
			reduction_label.text = "💰 Чаевые: 100%%"
			reduction_label.modulate = Color(0.8, 1.0, 0.8)  # Зеленый
		elif tips_percentage > 0:
			reduction_label.text = "💰 Чаевые: %d%%" % tips_percentage
			# Цвет от зеленого (100%) к красному (0%)
			var color_ratio = float(tips_percentage) / 100.0
			reduction_label.modulate = Color(
				0.8 + (1.0 - color_ratio) * 0.2,  # R: от 0.8 до 1.0
				1.0 - (1.0 - color_ratio) * 0.2,  # G: от 1.0 до 0.8
				0.8 + (1.0 - color_ratio) * 0.2   # B: от 0.8 до 1.0
			)
		else:
			reduction_label.text = "💰 Чаевые: 0%%"
			reduction_label.modulate = Color(1.0, 0.8, 0.8)  # Красный

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func refresh_all_indicators():
	"""Обновить все индикаторы (вызывать при необходимости)"""
	for guest_id in range(1, 7):
		_update_indicator(guest_id)
