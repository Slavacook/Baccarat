# res://scripts/ui/FocusFrameUI.gd
# Визуализация рамки фокуса для клавиатурного управления
# Простая цветная обводка вокруг элемента в фокусе
#
# ВАЖНО: Этот узел должен быть на том же уровне что и стол (основная сцена),
# чтобы рамка двигалась вместе с камерой.
# 
# Для настройки в редакторе Godot:
#   1. Добавьте узел FocusFrame (Control) в сцену Game.tscn
#   2. Прикрепите этот скрипт
#   3. Настройте параметры в Inspector: цвет, толщина, отступ

class_name FocusFrameUI
extends Control

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ РАМКИ (настраиваются в Inspector)
# ═══════════════════════════════════════════════════════════════════════════

@export_group("Внешний вид")

## Цвет рамки фокуса
@export var frame_color: Color = Color(1.0, 0.85, 0.0, 0.9)  # Золотистый

## Толщина линии рамки (пиксели)
@export_range(1.0, 20.0, 0.5) var frame_thickness: float = 4.0

@export_group("Позиционирование")

## Отступ от края элемента (пиксели)
@export_range(0.0, 50.0, 1.0) var frame_padding: float = 6.0

## Дополнительное смещение по X (для тонкой настройки)
@export var offset_x: float = 0.0

## Дополнительное смещение по Y (для тонкой настройки)
@export var offset_y: float = 0.0

@export_group("Анимация")

## Скорость анимации появления/исчезновения
@export_range(1.0, 20.0, 0.5) var fade_speed: float = 8.0

# ═══════════════════════════════════════════════════════════════════════════
# ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var target_node: Control = null
var target_alpha: float = 0.0
var current_alpha: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Рамка должна быть поверх элементов стола
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Подписываемся на изменение фокуса
	if EventBus:
		EventBus.focus_changed.connect(_on_focus_changed)
	
	# Начинаем невидимой
	modulate.a = 0.0
	visible = false
	
	print("🔲 FocusFrameUI инициализирована (двигается с камерой)")


func _process(delta: float) -> void:
	# Плавная анимация прозрачности
	if current_alpha != target_alpha:
		current_alpha = move_toward(current_alpha, target_alpha, delta * fade_speed)
		modulate.a = current_alpha
		
		if current_alpha <= 0.01:
			visible = false
		else:
			visible = true
	
	# Следуем за целевым элементом
	if target_node and is_instance_valid(target_node) and target_node.visible:
		_update_frame_position()
	elif target_alpha > 0:
		# Элемент стал невидимым - скрываем рамку
		target_alpha = 0.0


func _draw() -> void:
	if current_alpha <= 0.01:
		return
	
	var rect = Rect2(Vector2.ZERO, size)
	
	# Рисуем рамку (4 линии по периметру)
	var color = frame_color
	color.a = current_alpha
	
	# Верхняя линия
	draw_rect(Rect2(0, 0, rect.size.x, frame_thickness), color)
	# Нижняя линия
	draw_rect(Rect2(0, rect.size.y - frame_thickness, rect.size.x, frame_thickness), color)
	# Левая линия
	draw_rect(Rect2(0, 0, frame_thickness, rect.size.y), color)
	# Правая линия
	draw_rect(Rect2(rect.size.x - frame_thickness, 0, frame_thickness, rect.size.y), color)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func show_on_node(node: Control) -> void:
	"""Показать рамку вокруг указанного узла"""
	if not node or not is_instance_valid(node):
		hide_frame()
		return
	
	target_node = node
	target_alpha = 1.0
	visible = true
	_update_frame_position()
	queue_redraw()
	
	print("🔲 Фокус на: %s" % node.name)


func hide_frame() -> void:
	"""Скрыть рамку"""
	target_node = null
	target_alpha = 0.0


func set_frame_color(color: Color) -> void:
	"""Установить цвет рамки"""
	frame_color = color
	queue_redraw()

# ═══════════════════════════════════════════════════════════════════════════
# ВНУТРЕННИЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _update_frame_position() -> void:
	"""Обновить позицию и размер рамки под целевой элемент
	
	Использует позицию в координатах общего родителя (основной сцены),
	чтобы рамка корректно отображалась при движении камеры.
	"""
	if not target_node or not is_instance_valid(target_node):
		return
	
	# Получаем позицию и размер целевого элемента
	# Используем global_position который работает в мировых координатах
	var target_pos = target_node.global_position
	var target_size = target_node.size
	
	# Для Control элементов учитываем scale
	if target_node.scale != Vector2.ONE:
		target_size = target_size * target_node.scale
	
	# Добавляем отступ и смещение
	var final_pos = target_pos - Vector2(frame_padding, frame_padding) + Vector2(offset_x, offset_y)
	var final_size = target_size + Vector2(frame_padding * 2, frame_padding * 2)
	
	# Устанавливаем позицию и размер
	global_position = final_pos
	size = final_size
	
	queue_redraw()


func _on_focus_changed(target: String) -> void:
	"""Обработчик изменения фокуса"""
	if target == "None" or target.is_empty():
		hide_frame()
	# Узел будет установлен извне через show_on_node()

