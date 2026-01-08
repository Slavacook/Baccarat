# res://scripts/ui/GuestReturnCounterUI.gd
# ═══════════════════════════════════════════════════════════════════════════
# UI КОМПОНЕНТ ДЛЯ ОТОБРАЖЕНИЯ СЧЕТЧИКОВ ВОЗВРАТА ГОСТЕЙ
# 
# Отображает количество оставшихся раздач до возврата ушедших гостей
# Размещается рядом с основным счетчиком раздач
# ═══════════════════════════════════════════════════════════════════════════

class_name GuestReturnCounterUI
extends VBoxContainer

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Словарь счетчиков: {guest_id: Label}
var counter_labels: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
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
	
	# Обновляем все счетчики при инициализации
	update_all_counters()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

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
	for guest_id in counter_labels.keys().duplicate():
		update_counter(guest_id)

func _clear_all_counters():
	"""Очистить все счетчики"""
	for guest_id in counter_labels.keys().duplicate():
		_remove_counter_for_guest(guest_id)
