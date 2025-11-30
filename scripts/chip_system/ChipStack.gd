# res://scripts/chip_system/ChipStack.gd
# Класс для управления одной стопкой фишек в PayoutPopup
# Ответственность: визуализация стека, добавление/удаление фишек, расчёт суммы

class_name ChipStack
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal chip_added(new_count: int)      # Фишка добавлена в стек
signal chip_removed(new_count: int)    # Фишка удалена из стека
signal stack_empty()                   # Стек опустел
signal total_changed(new_total: float) # Сумма стека изменилась

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Базовая ширина стека в пикселях (размер одной фишки в текстуре)
const BASE_WIDTH = 96
# Отступ для label снизу стопки (чтобы не перекрывать фишки)
const LABEL_OFFSET = 25

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var denomination: float       # Номинал фишки (100, 50, 10, etc.)
var count: int = 0            # Количество фишек в стеке

# UI элементы
var container: PanelContainer # Кликабельный контейнер стопки
var texture_rect: TextureRect # Изображение стека
var count_label: Label        # Label с количеством фишек
var atlas_texture: AtlasTexture # Для показа части изображения стека

# Параметры визуализации
var full_stack_height: float = 120.0  # Высота полного стека (обновляется при загрузке)
var scale: float = 1.0                # Масштаб стека (1.0 для 6 слотов, 0.6 для 10)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(denom: float, stack_scale: float = 1.0):
	denomination = denom
	scale = stack_scale

	_create_container()
	_create_texture_rect()
	_create_count_label()
	_load_stack_texture()

# ← Создание кликабельного контейнера
func _create_container():
	container = PanelContainer.new()
	container.custom_minimum_size = Vector2(BASE_WIDTH * scale, GameConstants.CHIP_STACK_SLOT_HEIGHT * scale)
	container.size_flags_horizontal = Control.SIZE_FILL
	container.size_flags_vertical = Control.SIZE_FILL
	container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Полностью прозрачный фон
	var cell_style = StyleBoxFlat.new()
	cell_style.bg_color = Color(0, 0, 0, 0)
	cell_style.border_width_left = 0
	cell_style.border_width_top = 0
	cell_style.border_width_right = 0
	cell_style.border_width_bottom = 0
	container.add_theme_stylebox_override("panel", cell_style)

	# Control для абсолютного позиционирования
	var content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(content)

# ← Создание TextureRect для изображения стека
func _create_texture_rect():
	var content = container.get_child(0)

	texture_rect = TextureRect.new()
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.visible = false  # Скрыт изначально (0 фишек)

	# Якорь: НИЖНИЙ центр (растёт ВВЕРХ от низа)
	texture_rect.anchor_left = 0.5
	texture_rect.anchor_right = 0.5
	texture_rect.anchor_top = 1.0
	texture_rect.anchor_bottom = 1.0
	texture_rect.offset_bottom = -LABEL_OFFSET * scale
	texture_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH

	content.add_child(texture_rect)

# ← Создание Label с количеством фишек
func _create_count_label():
	var content = container.get_child(0)

	count_label = Label.new()
	count_label.text = "0"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", int(16 * scale))
	count_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Зелёный

	# Якорь: нижний центр (как TextureRect)
	count_label.anchor_left = 0.5
	count_label.anchor_right = 0.5
	count_label.anchor_top = 1.0
	count_label.anchor_bottom = 1.0
	count_label.offset_left = -LABEL_OFFSET * scale
	count_label.offset_right = LABEL_OFFSET * scale
	count_label.offset_top = -LABEL_OFFSET * scale

	content.add_child(count_label)

# ← Загрузка текстуры стека
func _load_stack_texture():
	# Форматируем номинал: целые без .0, дробные как есть
	var denom_str = str(int(denomination)) if denomination >= 1 else str(denomination)
	var stack_path = "res://assets/chips/stack_%s.png" % denom_str
	var full_texture = load(stack_path)

	if full_texture:
		# Создаём AtlasTexture для показа части изображения
		atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = full_texture
		full_stack_height = full_texture.get_height()

		# Изначально region пустой (0 фишек)
		atlas_texture.region = Rect2(0, full_stack_height, full_texture.get_width(), 0)
		texture_rect.texture = atlas_texture

		print("✓ ChipStack загружен: %s (размер: %dx%.0f)" % [stack_path, full_texture.get_width(), full_stack_height])
	else:
		push_warning("ChipStack: текстура не найдена: %s" % stack_path)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Добавить фишку в стопку
func add_chip() -> bool:
	if count >= GameConstants.CHIP_STACK_MAX_CHIPS:
		return false

	count += 1
	_update_visual()
	chip_added.emit(count)
	total_changed.emit(get_total())
	return true

# ← Удалить фишку из стопки
func remove_chip() -> bool:
	if count <= 0:
		return false

	count -= 1
	_update_visual()
	chip_removed.emit(count)
	total_changed.emit(get_total())

	if count == 0:
		stack_empty.emit()

	return true

# ← Получить общую сумму стопки
func get_total() -> float:
	return denomination * count

# ← Проверка, пуста ли стопка
func is_empty() -> bool:
	return count == 0

# ← Обновить масштаб стека (при переключении режимов 6↔10 слотов)
func update_scale(new_scale: float):
	scale = new_scale

	# Обновляем размер контейнера
	container.custom_minimum_size = Vector2(BASE_WIDTH * scale, GameConstants.CHIP_STACK_SLOT_HEIGHT * scale)

	# Обновляем offset для TextureRect и Label
	texture_rect.offset_bottom = -LABEL_OFFSET * scale

	count_label.add_theme_font_size_override("font_size", int(16 * scale))
	count_label.offset_left = -LABEL_OFFSET * scale
	count_label.offset_right = LABEL_OFFSET * scale
	count_label.offset_top = -LABEL_OFFSET * scale

	# Перерисовываем стек с новым масштабом
	_update_visual()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Обновить визуальное отображение стека
func _update_visual():
	count_label.text = str(count)

	if atlas_texture and count > 0:
		var full_width = atlas_texture.atlas.get_width()

		# Вычисляем высоту для текущего количества фишек
		# Стек растёт ВВЕРХ от низа, показываем НИЖНЮЮ часть изображения
		var display_height = (full_stack_height * count) / GameConstants.CHIP_STACK_MAX_CHIPS

		# Region показывает НИЖНЮЮ часть изображения (стек растет вверх!)
		var y_start = full_stack_height - display_height
		atlas_texture.region = Rect2(0, y_start, full_width, display_height)

		# Устанавливаем размер и позицию TextureRect (масштаб 2x * scale)
		var scaled_width = full_width * 2 * scale
		var scaled_height = display_height * 2 * scale

		# offset_left/right для центрирования по горизонтали
		texture_rect.offset_left = -scaled_width / 2
		texture_rect.offset_right = scaled_width / 2

		# offset_top РАСТЕТ ВВЕРХ от нижней границы!
		var label_height = LABEL_OFFSET * scale
		texture_rect.offset_top = -label_height - scaled_height

		texture_rect.visible = true

		print("  ↳ ChipStack %s: count=%d, height=%.0fpx (offset_top=%.0f)" % [denomination, count, scaled_height, texture_rect.offset_top])
	elif atlas_texture and count == 0:
		# При 0 фишек скрываем TextureRect
		texture_rect.visible = false
