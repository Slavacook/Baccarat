# res://scripts/ui/GuestReturnCounterUI.gd
# ═══════════════════════════════════════════════════════════════════════════
# UI КОМПОНЕНТ ДЛЯ ОТОБРАЖЕНИЯ СЧЕТЧИКОВ ВОЗВРАТА ГОСТЕЙ
# 
# Отображает количество оставшихся раздач до возврата ушедших гостей
# Размещается рядом с основным счетчиком раздач
# ═══════════════════════════════════════════════════════════════════════════

class_name GuestReturnCounterUI
extends GridContainer

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Словарь счетчиков: {guest_id: Label}
var counter_labels: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Настраиваем GridContainer на 2 колонки
	columns = 2
	add_theme_constant_override("h_separation", 20)  # Отступ между колонками
	add_theme_constant_override("v_separation", 5)   # Отступ между рядами
	
	# Подписываемся на события
	if EventBus:
		EventBus.round_started.connect(_on_round_started)
		EventBus.game_restarted.connect(_on_game_restarted)
	
	# Подписываемся на уход гостей
	if GuestStatsManager:
		GuestStatsManager.guest_left.connect(_on_guest_left)
	
	# Подписываемся на возврат гостей
	if GuestReturnManager:
		GuestReturnManager.guest_returned.connect(_on_guest_returned)
	
	# Проверяем всех уже ушедших гостей и создаем для них счетчики
	_check_existing_left_guests()
	
	# Обновляем все счетчики при инициализации
	update_all_counters()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _check_existing_left_guests():
	"""Проверить всех уже ушедших гостей и создать для них счетчики"""
	if not GuestReturnManager:
		return
	
	# Проверяем всех гостей (1-6) на наличие в списке ушедших
	for guest_id in range(1, 7):
		if GuestReturnManager.is_guest_left(guest_id):
			_create_counter_for_guest(guest_id)
			print("👋 Обнаружен ушедший гость %d при инициализации UI" % guest_id)

func _on_guest_left(guest_id: int):
	"""Обработчик ухода гостя - создаем счетчик"""
	_create_counter_for_guest(guest_id)
	update_counter(guest_id)

func _on_guest_returned(guest_id: int):
	"""Обработчик возврата гостя - удаляем счетчик"""
	_remove_counter_for_guest(guest_id)

func _on_round_started():
	"""Обновить все счетчики при начале новой раздачи"""
	update_all_counters()

func _on_game_restarted():
	"""Сбросить все счетчики при рестарте"""
	_clear_all_counters()

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ СЧЕТЧИКАМИ
# ═══════════════════════════════════════════════════════════════════════════

func _create_counter_for_guest(guest_id: int):
	"""Создать Label для счетчика гостя"""
	if counter_labels.has(guest_id):
		return  # Уже существует
	
	# Удаляем сообщение "Нет ушедших гостей", если оно есть
	var no_guests_label = get_node_or_null("NoGuestsLabel")
	if no_guests_label:
		no_guests_label.queue_free()
		# Возвращаем 2 колонки
		columns = 2
	
	var label = Label.new()
	label.name = "Guest%dCounter" % guest_id
	label.text = "Гость %d: ..." % guest_id
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	counter_labels[guest_id] = label
	DebugLogger.log("👋 Создан счетчик для гостя %d" % guest_id)

func _remove_counter_for_guest(guest_id: int):
	"""Удалить счетчик гостя"""
	if not counter_labels.has(guest_id):
		return
	
	var label = counter_labels[guest_id]
	counter_labels.erase(guest_id)
	if is_instance_valid(label):
		label.queue_free()
	DebugLogger.log("👋 Удален счетчик для гостя %d" % guest_id)

func update_counter(guest_id: int):
	"""Обновить счетчик конкретного гостя"""
	if not counter_labels.has(guest_id):
		return
	
	if not GuestReturnManager:
		return
	
	var remaining = GuestReturnManager.get_remaining_rounds(guest_id)
	if remaining < 0:
		_remove_counter_for_guest(guest_id)
		return
	
	var label = counter_labels[guest_id]
	label.text = "Гость %d: %d раздач" % [guest_id, remaining]

func update_all_counters():
	"""Обновить все счетчики"""
	# Проверяем наличие сообщения "Нет ушедших гостей"
	var no_guests_label = get_node_or_null("NoGuestsLabel")
	
	# Если нет счетчиков, показываем сообщение "Нет ушедших гостей"
	if counter_labels.is_empty():
		if no_guests_label == null:
			# Временно меняем количество колонок на 1 для сообщения
			columns = 1
			var label = Label.new()
			label.name = "NoGuestsLabel"
			label.text = "Нет ушедших гостей"
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(label)
		return
	
	# Удаляем сообщение "Нет ушедших гостей", если счетчики появились
	if no_guests_label:
		no_guests_label.queue_free()
		# Возвращаем 2 колонки
		columns = 2
	
	for guest_id in counter_labels.keys().duplicate():
		update_counter(guest_id)

func _clear_all_counters():
	"""Очистить все счетчики"""
	for guest_id in counter_labels.keys().duplicate():
		_remove_counter_for_guest(guest_id)
	
	# После очистки показываем сообщение "Нет ушедших гостей"
	update_all_counters()
