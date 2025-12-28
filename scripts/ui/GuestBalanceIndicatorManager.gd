# res://scripts/ui/GuestBalanceIndicatorManager.gd
# Менеджер для управления индикаторами баланса всех гостей
# Создает, позиционирует и обновляет 6 индикаторов баланса на игровом столе

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Смещение индикатора баланса относительно координат фишки
# Размещается слева от индикатора терпения (терпение на -80 по Y, баланс на -220 по X и -80 по Y)
const BALANCE_OFFSET = Vector2(-220, -80)  # Смещение влево на 220 пикселей и вверх на 80

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Ссылки на индикаторы для каждого гостя (1-6)
var indicators: Dictionary = {}  # {guest_id: Control}

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
	
	# Обновляем все индикаторы для начального отображения
	refresh_all_indicators()
	
	print("✅ GuestBalanceIndicatorManager: создано %d индикаторов" % indicators.size())

func _create_indicator(guest_id: int):
	"""Создать индикатор баланса для гостя"""
	
	# Создаем Control как корневой узел
	var indicator = Control.new()
	indicator.name = "GuestBalanceIndicator_%d" % guest_id
	indicator.visible = false
	indicator.z_index = 100  # Выше фишек, но ниже других UI элементов
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Создаем Panel как фон (такой же стиль как у терпения)
	var panel = Panel.new()
	panel.name = "Panel"
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.7)  # Полупрозрачный черный фон
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.size = Vector2(200, 50)  # Размер панели для баланса
	indicator.add_child(panel)
	
	# Создаем VBoxContainer для содержимого
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Устанавливаем anchors для VBoxContainer
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Создаем Label для текста "Баланс"
	var balance_label = Label.new()
	balance_label.name = "BalanceLabel"
	balance_label.text = "Баланс"
	balance_label.add_theme_font_size_override("font_size", 12)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(balance_label)
	
	# Создаем Label для суммы баланса
	var amount_label = Label.new()
	amount_label.name = "AmountLabel"
	amount_label.text = "0"
	amount_label.add_theme_font_size_override("font_size", 14)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Цвет зависит от знака (зеленый для положительного, красный для отрицательного)
	amount_label.modulate = Color(1.0, 1.0, 1.0)  # По умолчанию белый
	vbox.add_child(amount_label)
	
	# Добавляем в родительский узел
	if parent_node:
		parent_node.add_child(indicator)
	
	# Сохраняем ссылку
	indicators[guest_id] = indicator
	
	# Позиционируем индикатор
	_update_indicator_position(guest_id)
	
	# Изначально скрываем (покажем если гость включен)
	indicator.visible = false
	
	print("  ✅ Создан индикатор баланса для гостя %d" % guest_id)

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
		var indicator_pos = sector_coords + BALANCE_OFFSET
		indicator.global_position = indicator_pos
	else:
		push_error("GuestBalanceIndicatorManager: не удалось найти координаты для сектора %d" % guest_id)

func _connect_signals():
	"""Подписаться на события баланса и настроек гостей"""
	if GuestStatsManager:
		GuestStatsManager.guest_balance_changed.connect(_on_balance_changed)
	
	if GuestSettingsManager:
		GuestSettingsManager.guest_settings_changed.connect(_on_guest_settings_changed)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_balance_changed(changed_guest_id: int, _new_balance: float):
	"""Обработчик изменения баланса гостя"""
	_update_indicator(changed_guest_id)

func _on_guest_settings_changed(guest_id: int):
	"""Обработчик изменения настроек гостя (включение/выключение)"""
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
	
	# Показываем индикатор
	indicator_control.visible = true
	
	# Получаем узлы
	var panel = indicator_control.get_node_or_null("Panel")
	if not panel:
		return
	
	var vbox = panel.get_node_or_null("VBoxContainer")
	if not vbox:
		return
	
	var amount_label = vbox.get_node_or_null("AmountLabel")
	
	# Получаем баланс гостя
	var balance = GuestStatsManager.get_guest_balance(guest_id)
	
	# Обновляем сумму баланса
	if amount_label:
		# Форматируем баланс
		var balance_text: String
		if balance >= 0:
			balance_text = "+%.0f" % balance
			# Зеленый цвет для положительного баланса
			amount_label.modulate = Color(0.5, 1.0, 0.5)
		else:
			balance_text = "%.0f" % balance
			# Красный цвет для отрицательного баланса
			amount_label.modulate = Color(1.0, 0.5, 0.5)
		
		amount_label.text = balance_text
	
	# Текст "Баланс" всегда один и тот же, не обновляем

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func refresh_all_indicators():
	"""Обновить все индикаторы (вызывать при необходимости)"""
	for guest_id in range(1, 7):
		_update_indicator(guest_id)
