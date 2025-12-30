# res://scripts/ui/ChipNavigationFrame.gd
# Визуальная рамка для выделения выбранной фишки при навигации
# Следует за фокусом и отображает текущую выбранную фишку

extends ColorRect
class_name ChipNavigationFrame

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Отступ рамки от краёв фишки (в пикселях)
const FRAME_PADDING: int = 20

# Цвет рамки (жёлтый с прозрачностью)
const FRAME_COLOR: Color = Color(1.0, 0.84, 0.0, 0.7)  # Жёлтый, 70% прозрачности

# Толщина рамки
const FRAME_BORDER_WIDTH: int = 3

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var current_chip: ChipVisualManager.ChipInstance = null
var tween: Tween = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Инициализация рамки"""
	# Настройка внешнего вида - делаем рамку более заметной
	# Используем полупрозрачный жёлтый фон для лучшей видимости
	color = Color(1.0, 0.84, 0.0, 0.3)  # Жёлтый фон с прозрачностью
	
	# Используем StyleBox для рамки
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(1.0, 0.84, 0.0, 0.2)  # Полупрозрачный жёлтый фон
	style_box.border_color = FRAME_COLOR
	style_box.border_width_left = FRAME_BORDER_WIDTH
	style_box.border_width_right = FRAME_BORDER_WIDTH
	style_box.border_width_top = FRAME_BORDER_WIDTH
	style_box.border_width_bottom = FRAME_BORDER_WIDTH
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	# Устанавливаем стиль
	add_theme_stylebox_override("panel", style_box)
	
	# Изначально скрыта
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Игнорируем клики
	
	# Устанавливаем минимальный размер для видимости
	size = Vector2(100, 100)
	
	# Убеждаемся, что рамка будет видна поверх других элементов
	z_index = 1000
	z_as_relative = false
	
	# Устанавливаем anchor для правильного позиционирования
	set_anchors_preset(Control.PRESET_TOP_LEFT)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func show_at_chip(chip: ChipVisualManager.ChipInstance) -> void:
	"""Показать рамку у указанной фишки (для обратной совместимости)
	
	Args:
		chip: Фишка, которую нужно выделить
	"""
	if not chip or not chip.node:
		hide_frame()
		return
	
	if not is_instance_valid(chip.node):
		hide_frame()
		return
	
	current_chip = chip
	
	# Обновляем позицию и размер
	_update_position_and_size()
	
	# Показываем рамку
	visible = true
	modulate = Color.WHITE  # Полная непрозрачность
	modulate.a = 1.0
	
	# Убеждаемся, что рамка видна
	z_index = 1000
	z_as_relative = false
	
	DebugLogger.log("📦 ChipNavigationFrame: показана у фишки %s[%d] (visible=%s, position=%s, size=%s)" % [
		chip.bet_type, chip.position_index, visible, position, size
	])

func show_at_position(coords: Vector2, bet_type: String) -> void:
	"""Показать рамку на указанных координатах (фиксированная позиция)
	
	Args:
		coords: Координаты позиции (Vector2)
		bet_type: Тип ставки (для определения размера)
	"""
	current_chip = null  # Очищаем ссылку на фишку
	
	# Получаем размер фишки для этого типа
	var chip_size = Vector2(100, 100)  # Размер по умолчанию
	if ChipVisualManager.ALTERNATIVE_POSITIONS.has(bet_type):
		# Используем размер из оригинальной фишки, если доступен
		# TODO: можно получить реальный размер из chip_visual_manager
		pass
	
	# Вычисляем позицию и размер рамки
	var frame_pos = coords - Vector2(FRAME_PADDING, FRAME_PADDING)
	var frame_size = chip_size + Vector2(FRAME_PADDING * 2, FRAME_PADDING * 2)
	
	# Устанавливаем позицию
	var parent = get_parent()
	if parent is CanvasLayer:
		global_position = frame_pos
	else:
		position = frame_pos
	
	size = frame_size
	visible = true
	modulate = Color.WHITE
	modulate.a = 1.0
	z_index = 1000
	z_as_relative = false
	
	DebugLogger.log("📦 ChipNavigationFrame: показана на позиции %s (bet_type=%s, size=%s)" % [
		str(coords), bet_type, str(frame_size)
	])

func hide_frame() -> void:
	"""Скрыть рамку"""
	current_chip = null
	visible = false
	if tween:
		tween.kill()
		tween = null

func update_position() -> void:
	"""Обновить позицию рамки (вызывается при изменении фокуса)"""
	if current_chip and current_chip.node:
		_update_position_and_size()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _update_position_and_size() -> void:
	"""Обновить позицию и размер рамки относительно фишки"""
	if not current_chip or not current_chip.node:
		return
	
	var chip_node = current_chip.node
	if not is_instance_valid(chip_node):
		return
	
	# Получаем позицию и размер фишки
	var chip_pos = chip_node.position  # Local position относительно родителя
	var chip_size = chip_node.size
	
	# Вычисляем позицию и размер рамки с отступом
	var frame_pos = chip_pos - Vector2(FRAME_PADDING, FRAME_PADDING)
	var frame_size = chip_size + Vector2(FRAME_PADDING * 2, FRAME_PADDING * 2)
	
	# Если рамка в том же родителе, что и фишка - используем local position
	var parent = get_parent()
	if parent is CanvasLayer:
		# CanvasLayer - используем global_position
		var chip_global_pos = chip_node.global_position
		global_position = chip_global_pos - Vector2(FRAME_PADDING, FRAME_PADDING)
	else:
		# Обычный узел (тот же родитель, что и фишка) - используем position
		position = frame_pos
	
	size = frame_size
	
	# Убеждаемся, что рамка видна
	visible = true
	modulate = Color.WHITE
	modulate.a = 1.0
	
	# Отладочная информация
	var parent_name: String = "null"
	if get_parent():
		parent_name = get_parent().name
	DebugLogger.log("📦 ChipNavigationFrame: позиция обновлена (chip_pos=%s, frame_pos=%s, size=%s, visible=%s, parent=%s)" % [
		str(chip_pos), str(position), str(frame_size), visible, parent_name
	])

func _process(_delta: float) -> void:
	"""Обновление позиции каждый кадр (на случай если фишка движется)"""
	if visible and current_chip and current_chip.node:
		_update_position_and_size()
