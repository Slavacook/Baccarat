# res://scripts/ui/GuestPatienceIndicator.gd
# Индикатор терпения для одного гостя
# Отображает: терпение, таймер, процент урезания чая

extends Control

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@onready var panel: Panel = $Panel
@onready var patience_label: Label = $Panel/VBoxContainer/PatienceLabel
@onready var timer_label: Label = $Panel/VBoxContainer/TimerLabel
@onready var reduction_label: Label = $Panel/VBoxContainer/ReductionLabel

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var guest_id: int = 0  # ID гостя (1-6)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Скрываем по умолчанию
	visible = false
	# Убеждаемся, что узлы доступны
	if not panel:
		panel = $Panel
	if not patience_label:
		patience_label = $Panel/VBoxContainer/PatienceLabel
	if not timer_label:
		timer_label = $Panel/VBoxContainer/TimerLabel
	if not reduction_label:
		reduction_label = $Panel/VBoxContainer/ReductionLabel

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func setup(indicator_guest_id: int):
	"""Инициализация индикатора для конкретного гостя"""
	guest_id = indicator_guest_id

func update_display(patience: int, timer_remaining: int, reduction_percent: float):
	"""Обновить отображение индикатора
	
	Args:
		patience: Терпение гостя (0-100)
		timer_remaining: Оставшееся время таймера в секундах (0 если нет таймера)
		reduction_percent: Процент урезания чая (базовый - эффективный)
	"""
	if patience <= 0:
		# Нет терпения - скрываем индикатор
		visible = false
		return
	
	# Показываем индикатор
	visible = true
	
	# Обновляем терпение
	if patience_label:
		patience_label.text = "😤 Терпение: %d%%" % patience
		# Меняем цвет: от зеленого (0%) до красного (100%)
		var color_ratio = float(patience) / 100.0
		patience_label.modulate = Color(1.0, 1.0 - color_ratio * 0.7, 1.0 - color_ratio * 0.7)
	
	# Обновляем таймер
	if timer_label:
		if timer_remaining > 0 and PatienceTimerManager.has_active_timer(guest_id):
			timer_label.text = "⏱ %ds" % timer_remaining
			timer_label.visible = true
		else:
			timer_label.visible = false
	
	# Обновляем процент урезания
	if reduction_label:
		# Убираем эмодзи из текста, так как теперь используется отдельная иконка
		if reduction_percent > 0:
			reduction_label.text = "Чаевые -%.1f%%" % reduction_percent
			reduction_label.modulate = Color(1.0, 0.8, 0.8)  # Легкий красноватый оттенок
		else:
			reduction_label.text = "Полные чаевые"
			reduction_label.modulate = Color(0.8, 1.0, 0.8)  # Легкий зеленоватый оттенок

func set_world_position(pos: Vector2):
	"""Установить мировую позицию индикатора
	
	Args:
		pos: Координаты в мировых координатах стола
	"""
	global_position = pos

