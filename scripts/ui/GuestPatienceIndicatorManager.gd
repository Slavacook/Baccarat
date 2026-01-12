# res://scripts/ui/GuestPatienceIndicatorManager.gd
# Менеджер для управления индикаторами терпения всех гостей
# Создает, позиционирует и обновляет 6 индикаторов на игровом столе

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Настройки индикаторов для каждого гостя (1-6)
# Все параметры в одном месте для удобства настройки
const INDICATOR_SETTINGS: Dictionary = {
	1: {
		"position": Vector2(-1020, 50),  # Положение (X, Y)
		"scale": Vector2(1.0, 1.0),      # Масштаб (ширина, высота)
		"rotation": 0.0,                 # Поворот в градусах
		"panel_size": Vector2(200, 120)  # Размер панели (ширина, высота)
	},
	2: {
		"position": Vector2(-600, -200),
		"scale": Vector2(1.0, 1.0),
		"rotation": 0.0,
		"panel_size": Vector2(200, 120)
	},
	3: {
		"position": Vector2(180, -230),
		"scale": Vector2(1.0, 1.0),
		"rotation": 0.0,
		"panel_size": Vector2(200, 120)
	},
	4: {
		"position": Vector2(700, -230),
		"scale": Vector2(1.0, 1.0),
		"rotation": 0.0,
		"panel_size": Vector2(200, 120)
	},
	5: {
		"position": Vector2(1305, -230),
		"scale": Vector2(1.0, 1.0),
		"rotation": 0.0,
		"panel_size": Vector2(200, 120)
	},
	6: {
		"position": Vector2(1860, 50),
		"scale": Vector2(1.0, 1.0),
		"rotation": 0.0,
		"panel_size": Vector2(200, 120)
	}
}

# Путь к сцене индикатора (если используем сцену) или создаем программно
const INDICATOR_SCENE_PATH = ""  # Пока создаем программно

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Ссылки на индикаторы для каждого гостя (1-6)
var indicators: Dictionary = {}  # {guest_id: GuestPatienceIndicator}

# Родительский узел для размещения индикаторов (обычно Game scene)
var parent_node: Node2D = null

# Ссылка на CameraManager для отслеживания позиции камеры
var camera_manager: CameraManager = null

# Предыдущая область камеры (для определения, нужно ли менять видимость)
var previous_area: int = -1

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(p_parent_node: Node2D, p_camera_manager: CameraManager = null):
	"""Инициализация менеджера
	
	Args:
		p_parent_node: Родительский узел (Game scene), где будут размещены индикаторы
		p_camera_manager: Менеджер камеры для отслеживания позиции
	"""
	parent_node = p_parent_node
	camera_manager = p_camera_manager
	
	# Создаем индикаторы для всех 6 гостей
	for guest_id in range(1, 7):
		_create_indicator(guest_id)
	
	# Подписываемся на события
	_connect_signals()
	
	# Обновляем все индикаторы для начального отображения
	refresh_all_indicators()
	
	# Инициализируем previous_area и показываем индикаторы
	if camera_manager:
		previous_area = camera_manager.current_area
		_show_all_indicators_animated()  # Показываем индикаторы сразу
	
	print("✅ GuestPatienceIndicatorManager: создано %d индикаторов" % indicators.size())

func _create_indicator(guest_id: int):
	"""Создать индикатор для гостя"""
	
	# Получаем настройки для этого гостя один раз в начале функции
	var settings = INDICATOR_SETTINGS.get(guest_id, {})
	
	# Создаем Control как корневой узел
	var indicator = Control.new()
	indicator.name = "GuestPatienceIndicator_%d" % guest_id
	indicator.visible = false
	indicator.z_index = 100  # Выше фишек, но ниже других UI элементов
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Создаем Panel как фон с улучшенным стилем
	var panel = Panel.new()
	panel.name = "Panel"
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.85)  # Более темный фон с большей непрозрачностью
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	
	# Добавляем золотистую рамку
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1.0, 0.85, 0.3, 0.8)  # Золотистая рамка
	
	# Добавляем тень
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 4
	panel_style.shadow_offset = Vector2(2, 2)
	
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Получаем размер панели из настроек
	var panel_size = settings.get("panel_size", Vector2(200, 120))
	panel.size = panel_size
	
	indicator.add_child(panel)
	
	# Создаем VBoxContainer для содержимого с отступами
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	# Устанавливаем anchors для VBoxContainer
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Устанавливаем отступы через offset
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	
	# Контейнер для заголовка "Терпение" и таймера
	var patience_header_container = HBoxContainer.new()
	patience_header_container.name = "PatienceHeaderContainer"
	vbox.add_child(patience_header_container)
	
	# Заголовок "Терпение" (слева)
	var patience_header = Label.new()
	patience_header.name = "PatienceHeader"
	patience_header.text = "Терпение"
	patience_header.add_theme_font_size_override("font_size", 11)
	patience_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	patience_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))  # Светло-серый для заголовка
	patience_header_container.add_child(patience_header)
	
	# Таймер (справа)
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "⏱ 0s"
	timer_label.add_theme_font_size_override("font_size", 11)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Растягиваем, чтобы таймер был справа
	timer_label.visible = false  # Изначально скрыт
	patience_header_container.add_child(timer_label)
	
	# Создаем ProgressBar для терпения
	var patience_progress = ProgressBar.new()
	patience_progress.name = "PatienceProgress"
	patience_progress.min_value = 0
	patience_progress.max_value = 100
	patience_progress.value = 100
	patience_progress.custom_minimum_size = Vector2(0, 20)  # Высота прогресс-бара
	patience_progress.show_percentage = false
	
	# Стилизуем прогресс-бар
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Темный фон для прогресс-бара
	progress_bg.corner_radius_top_left = 4
	progress_bg.corner_radius_top_right = 4
	progress_bg.corner_radius_bottom_left = 4
	progress_bg.corner_radius_bottom_right = 4
	patience_progress.add_theme_stylebox_override("background", progress_bg)
	
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.2, 0.8, 0.2, 1.0)  # Зеленый цвет заполнения
	progress_fill.corner_radius_top_left = 4
	progress_fill.corner_radius_top_right = 4
	progress_fill.corner_radius_bottom_left = 4
	progress_fill.corner_radius_bottom_right = 4
	patience_progress.add_theme_stylebox_override("fill", progress_fill)
	
	vbox.add_child(patience_progress)
	
	# Разделитель 1
	var separator1 = HSeparator.new()
	separator1.name = "Separator1"
	vbox.add_child(separator1)
	
	# Создаем Label для процента урезания
	var reduction_label = Label.new()
	reduction_label.name = "ReductionLabel"
	reduction_label.text = "Чаевые: 0%"
	reduction_label.add_theme_font_size_override("font_size", 11)
	reduction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(reduction_label)
	
	# Разделитель 2
	var separator2 = HSeparator.new()
	separator2.name = "Separator2"
	vbox.add_child(separator2)
	
	# Контейнер для заголовка "Баланс" и суммы баланса
	var balance_header_container = HBoxContainer.new()
	balance_header_container.name = "BalanceHeaderContainer"
	vbox.add_child(balance_header_container)
	
	# Заголовок "Баланс" (слева)
	var balance_header = Label.new()
	balance_header.name = "BalanceHeader"
	balance_header.text = "Баланс"
	balance_header.add_theme_font_size_override("font_size", 11)
	balance_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	balance_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))  # Светло-серый для заголовка
	balance_header_container.add_child(balance_header)
	
	# Создаем Label для баланса (справа)
	var balance_label = Label.new()
	balance_label.name = "BalanceLabel"
	balance_label.text = "0"
	balance_label.add_theme_font_size_override("font_size", 13)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Растягиваем, чтобы баланс был справа
	balance_header_container.add_child(balance_label)
	
	# Разделитель 3
	var separator3 = HSeparator.new()
	separator3.name = "Separator3"
	vbox.add_child(separator3)
	
	# Контейнер для статуса богатства и характера
	var status_container = HBoxContainer.new()
	status_container.name = "StatusContainer"
	vbox.add_child(status_container)
	
	# Метка "Фин:"
	var wealth_label = Label.new()
	wealth_label.name = "WealthLabel"
	wealth_label.text = "Фин: 1"
	wealth_label.add_theme_font_size_override("font_size", 11)
	wealth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wealth_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_container.add_child(wealth_label)
	
	# Метка "Азарт:"
	var character_label = Label.new()
	character_label.name = "CharacterLabel"
	character_label.text = "Азарт: 1"
	character_label.add_theme_font_size_override("font_size", 11)
	character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	character_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Растягиваем, чтобы было справа
	character_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_container.add_child(character_label)
	
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
	
	# Применяем настройки из конфига (положение, масштаб, поворот)
	# Масштаб: увеличиваем в 1.5 раза
	var base_scale = settings.get("scale", Vector2(1.0, 1.0))
	indicator.scale = base_scale * 1.5  # Увеличенный масштаб для лучшей видимости
	
	# Поворот
	var rotation = settings.get("rotation", 0.0)
	indicator.rotation_degrees = rotation
	
	# Позиционируем индикатор
	_update_indicator_position(guest_id)
	
	# Изначально скрываем (покажем когда гость включен)
	indicator.visible = false
	
	print("  ✅ Создан индикатор для гостя %d (scale: %s)" % [guest_id, indicator.scale])

func _update_indicator_position(guest_id: int):
	"""Обновить позицию индикатора на основе настроек"""
	if not indicators.has(guest_id):
		return
	
	var indicator = indicators[guest_id]
	
	# Получаем настройки для этого гостя
	var settings = INDICATOR_SETTINGS.get(guest_id, {})
	var position = settings.get("position", Vector2.ZERO)
	
	if position != Vector2.ZERO:
		# Устанавливаем абсолютную позицию индикатора
		indicator.global_position = position
	else:
		push_warning("GuestPatienceIndicatorManager: не задана позиция для гостя %d" % guest_id)

func _connect_signals():
	"""Подписаться на события терпения, баланса и таймеров"""
	if GuestStatsManager:
		GuestStatsManager.guest_patience_changed.connect(_on_patience_changed)
		GuestStatsManager.guest_balance_changed.connect(_on_balance_changed)
	
	if GuestSettingsManager:
		GuestSettingsManager.guest_settings_changed.connect(_on_guest_settings_changed)
	
	# Подписываемся на события камеры для управления видимостью
	if camera_manager:
		camera_manager.zoom_completed.connect(_on_camera_zoom_completed)
	
	# Таймер обновления (каждую секунду для обновления таймера)
	# Используем _process для обновления каждую секунду

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_patience_changed(changed_guest_id: int, _new_patience: int):
	"""Обработчик изменения терпения гостя"""
	_update_indicator(changed_guest_id)

func _on_balance_changed(changed_guest_id: int, _new_balance: float):
	"""Обработчик изменения баланса гостя"""
	_update_indicator(changed_guest_id)

func _on_guest_settings_changed(guest_id: int):
	"""Обработчик изменения настроек гостя (включение/выключение)"""
	_update_indicator(guest_id)
	
	# Если гость включен, нужно явно показать индикатор (если он скрыт)
	# Видимость управляется через _on_camera_zoom_completed, но при включении
	# нового гостя это событие может не вызываться сразу
	if GuestSettingsManager and GuestSettingsManager.is_guest_enabled(guest_id):
		if indicators.has(guest_id):
			var indicator = indicators[guest_id]
			if is_instance_valid(indicator):
				# Если индикатор скрыт или прозрачный - показываем его с анимацией
				if not indicator.visible or indicator.modulate.a < 0.99:
					indicator.modulate.a = 0.0
					indicator.visible = true
					var tween = create_tween()
					tween.tween_property(indicator, "modulate:a", 1.0, 0.5)

func _on_camera_zoom_completed(_zoom_type: String):
	"""Обработчик завершения зума камеры"""
	if not camera_manager:
		return
	
	var area = camera_manager.current_area
	
	# Индикаторы всегда видны (если гость за столом)
	# Показываем только если они еще не видны, чтобы избежать мигания
	_show_all_indicators_if_hidden()
	previous_area = area

func _process(_delta: float):
	"""Обновление индикаторов каждую секунду (для таймера)"""
	# Обновляем все индикаторы включенных гостей
	for guest_id in range(1, 7):
		if GuestSettingsManager.is_guest_enabled(guest_id):
			_update_indicator(guest_id)

func _update_indicator(guest_id: int):
	"""Обновить данные индикатора для гостя"""
	if not indicators.has(guest_id):
		return
	
	var indicator_control = indicators[guest_id]
	if not is_instance_valid(indicator_control):
		return
	
	# Проверяем, включен ли гость
	var is_enabled = GuestSettingsManager.is_guest_enabled(guest_id)
	
	# Если гость не включен, скрываем индикатор
	if not is_enabled:
		indicator_control.visible = false
		return
	
	# ВАЖНО: Не меняем видимость здесь - это делается в _on_camera_zoom_completed
	# Обновляем данные всегда, даже если карточка скрыта (для актуальности при появлении)

	var patience = GuestStatsManager.get_guest_patience(guest_id)
	
	# Получаем узлы
	var panel = indicator_control.get_node_or_null("Panel")
	if not panel:
		return
	
	var vbox = panel.get_node_or_null("VBoxContainer")
	if not vbox:
		return
	
	var patience_progress = vbox.get_node_or_null("PatienceProgress")
	var patience_header_container = vbox.get_node_or_null("PatienceHeaderContainer")
	var timer_label = null
	if patience_header_container:
		timer_label = patience_header_container.get_node_or_null("TimerLabel")
	var reduction_label = vbox.get_node_or_null("ReductionLabel")
	var balance_header_container = vbox.get_node_or_null("BalanceHeaderContainer")
	var balance_label = null
	if balance_header_container:
		balance_label = balance_header_container.get_node_or_null("BalanceLabel")
	var status_container = vbox.get_node_or_null("StatusContainer")
	var wealth_label = null
	var character_label = null
	if status_container:
		wealth_label = status_container.get_node_or_null("WealthLabel")
		character_label = status_container.get_node_or_null("CharacterLabel")
	
	# Обновляем прогресс-бар терпения
	if patience_progress:
		patience_progress.value = patience
		
		# Меняем цвет заполнения в зависимости от уровня терпения
		# От зеленого (100%) к красному (0%)
		var color_ratio = float(patience) / 100.0
		var fill_color = Color(
			0.2 + (1.0 - color_ratio) * 0.8,  # R: от 0.2 до 1.0
			0.8 - (1.0 - color_ratio) * 0.6,  # G: от 0.8 до 0.2
			0.2  # B: всегда 0.2
		)
		
		var progress_fill = StyleBoxFlat.new()
		progress_fill.bg_color = fill_color
		progress_fill.corner_radius_top_left = 4
		progress_fill.corner_radius_top_right = 4
		progress_fill.corner_radius_bottom_left = 4
		progress_fill.corner_radius_bottom_right = 4
		patience_progress.add_theme_stylebox_override("fill", progress_fill)
	
	# Обновляем таймер
	if timer_label:
		var timer_remaining = 0
		if PatienceTimerManager.has_active_timer(guest_id):
			timer_remaining = PatienceTimerManager.get_remaining_time(guest_id)
			# Форматируем время: минуты и секунды для таймера 10 минут
			var minutes = int(float(timer_remaining) / 60.0)
			var seconds = timer_remaining % 60
			if minutes > 0:
				timer_label.text = "⏱ %d:%02d" % [minutes, seconds]
			else:
				timer_label.text = "⏱ %ds" % timer_remaining
			timer_label.visible = true
		else:
			timer_label.visible = false
	
	# Обновляем процент чаевых (равен терпению)
	if reduction_label:
		var tips_percentage = patience  # Процент чаевых равен терпению
		
		if tips_percentage >= 100:
			reduction_label.text = "💰 Чаевые: 100%"
			reduction_label.modulate = Color(1.0, 1.0, 1.0)  # Белый
		elif tips_percentage > 0:
			reduction_label.text = "💰 Чаевые: %d%%" % tips_percentage
			# Цвет от белого (100%) к красному (0%)
			var color_ratio = float(100 - tips_percentage) / 100.0  # Инвертируем: 0% чаевых = красный
			reduction_label.modulate = Color(
				1.0,  # R: всегда 1.0
				1.0 - color_ratio * 0.5,  # G: от 1.0 до 0.5
				1.0 - color_ratio * 0.5   # B: от 1.0 до 0.5
			)
		else:
			reduction_label.text = "💰 Чаевые: 0%"
			reduction_label.modulate = Color(1.0, 0.5, 0.5)  # Красный
	
	# Обновляем баланс
	if balance_label:
		var balance = GuestStatsManager.get_guest_balance(guest_id)
		var balance_text: String
		if balance >= 0:
			balance_text = "+%.0f" % balance
			# Зеленый цвет для положительного баланса
			balance_label.modulate = Color(0.5, 1.0, 0.5)
		else:
			balance_text = "%.0f" % balance
			# Красный цвет для отрицательного баланса
			balance_label.modulate = Color(1.0, 0.5, 0.5)
		balance_text = "%.0f" % balance
		balance_label.text = balance_text
	
	# Обновляем статус богатства (1=POOR, 2=MEDIUM, 3=RICH)
	if wealth_label and GuestSettingsManager:
		var wealth = GuestSettingsManager.get_guest_wealth(guest_id)
		var wealth_number: int
		match wealth:
			GuestSettingsManager.GuestWealth.POOR:
				wealth_number = 1
			GuestSettingsManager.GuestWealth.MEDIUM:
				wealth_number = 2
			GuestSettingsManager.GuestWealth.RICH:
				wealth_number = 3
			_:
				wealth_number = 1
		wealth_label.text = "Фин: %d" % wealth_number
	
	# Обновляем характер (1=CAUTIOUS, 2=MODERATE, 3=GAMBLER)
	if character_label and GuestSettingsManager:
		var character = GuestSettingsManager.get_guest_character(guest_id)
		var character_number: int
		match character:
			GuestSettingsManager.GuestCharacter.CAUTIOUS:
				character_number = 1
			GuestSettingsManager.GuestCharacter.MODERATE:
				character_number = 2
			GuestSettingsManager.GuestCharacter.GAMBLER:
				character_number = 3
			_:
				character_number = 2
		character_label.text = "Азарт: %d" % character_number

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func refresh_all_indicators():
	"""Обновить все индикаторы (вызывать при необходимости)"""
	for guest_id in range(1, 7):
		if GuestSettingsManager.is_guest_enabled(guest_id):
			_update_indicator(guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ С АНИМАЦИЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func _show_all_indicators_animated():
	"""Показать все индикаторы с fade-in анимацией (0.5 сек)"""
	for guest_id in range(1, 7):
		if not indicators.has(guest_id):
			continue
		
		var indicator = indicators[guest_id]
		if not is_instance_valid(indicator):
			continue
		
		# Показываем только если гость включен
		if not GuestSettingsManager.is_guest_enabled(guest_id):
			continue
		
		# Устанавливаем начальное состояние (прозрачный)
		indicator.modulate.a = 0.0
		indicator.visible = true
		
		# Анимация fade-in
		var tween = create_tween()
		tween.tween_property(indicator, "modulate:a", 1.0, 0.5)

func _show_all_indicators_if_hidden():
	"""Показать все индикаторы, но только если они скрыты (без мигания)"""
	for guest_id in range(1, 7):
		if not indicators.has(guest_id):
			continue
		
		var indicator = indicators[guest_id]
		if not is_instance_valid(indicator):
			continue
		
		# Показываем только если гость включен
		if not GuestSettingsManager.is_guest_enabled(guest_id):
			continue
		
		# Если индикатор уже видим и непрозрачен - пропускаем (избегаем мигания)
		if indicator.visible and indicator.modulate.a >= 0.99:
			continue
		
		# Если индикатор скрыт - показываем с анимацией
		if not indicator.visible:
			indicator.modulate.a = 0.0
			indicator.visible = true
			var tween = create_tween()
			tween.tween_property(indicator, "modulate:a", 1.0, 0.5)
		# Если индикатор видим, но прозрачный - просто делаем непрозрачным без анимации
		elif indicator.modulate.a < 0.99:
			indicator.modulate.a = 1.0

func _hide_all_indicators_animated(use_animation: bool = true):
	"""Скрыть все индикаторы с fade-out анимацией (0.5 сек) или мгновенно"""
	for guest_id in range(1, 7):
		if not indicators.has(guest_id):
			continue
		
		var indicator = indicators[guest_id]
		if not is_instance_valid(indicator):
			continue
		
		if not indicator.visible:
			continue  # Уже скрыт
		
		if use_animation:
			# Анимация fade-out
			var tween = create_tween()
			tween.tween_property(indicator, "modulate:a", 0.0, 0.5)
			tween.tween_callback(func(): indicator.visible = false)
		else:
			# Мгновенное скрытие (для инициализации)
			indicator.modulate.a = 0.0
			indicator.visible = false
