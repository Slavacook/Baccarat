# res://scripts/ui/CribSheetScene.gd
# Сцена полного экрана для отображения шпаргалки
# Открывается с анимацией и затемнением фона, как карты шансов

class_name CribSheetScene
extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════
# УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@onready var background: ColorRect = $Background
@onready var image_texture: TextureRect = $ImageTexture
@onready var close_button: Button = $CloseButton
@onready var left_arrow: Button = $LeftArrow
@onready var right_arrow: Button = $RightArrow

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Пути к изображениям шпаргалки
const CRIB_IMAGES: Array[String] = [
	"res://assets/ui/cribs/cribs_1.png",
	"res://assets/ui/cribs/cribs_2.png"
]

## Текущий индекс изображения
var current_image_index: int = 0

## Включить анимацию
const USE_ANIMATION: bool = true

## Сохраняем исходные значения для восстановления после анимации
var original_image_scale: Vector2 = Vector2.ONE
var original_image_modulate: Color = Color.WHITE
var original_bg_modulate: Color = Color.WHITE
var original_image_position: Vector2 = Vector2.ZERO

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	layer = 200  # Поверх всего UI
	hide()
	# Добавляем в группу для поиска
	add_to_group("crib_sheet")
	
	# Сохраняем исходные значения
	if image_texture:
		original_image_scale = image_texture.scale
		original_image_modulate = image_texture.modulate
		original_image_position = image_texture.position
		# Устанавливаем pivot_offset в центр изображения для масштабирования из центра
		await get_tree().process_frame  # Ждём, пока размер установится
		var image_size = image_texture.size
		if image_size != Vector2.ZERO:
			image_texture.pivot_offset = image_size / 2.0
		original_image_position = image_texture.position
	if background:
		original_bg_modulate = background.modulate
	
	# Подключаем сигналы
	if background:
		background.gui_input.connect(_on_background_input)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if left_arrow:
		left_arrow.pressed.connect(_on_left_arrow_pressed)
	if right_arrow:
		right_arrow.pressed.connect(_on_right_arrow_pressed)
	
	# Загружаем первое изображение
	_load_image(0)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Показать шпаргалку на весь экран
func show_cribsheet():
	if CRIB_IMAGES.is_empty():
		push_warning("CribSheetScene: нет изображений для загрузки")
		return
	
	# Загружаем текущее изображение
	_load_image(current_image_index)
	
	# Восстанавливаем позицию и масштаб
	if image_texture:
		image_texture.position = original_image_position
		image_texture.scale = original_image_scale
		image_texture.modulate = original_image_modulate
	if background:
		background.modulate = original_bg_modulate
	
	# Показываем
	show()
	
	# Звук открытия шпаргалки
	if SoundManager:
		SoundManager.play_crib_sheet_sound()
	
	# Проверяем, что get_tree() доступен перед await
	var tree = get_tree()
	if not tree:
		push_error("CribSheetScene: get_tree() вернул null, не могу продолжить")
		return
	
	# Ждём один кадр, чтобы узел полностью инициализировался
	await tree.process_frame
	
	# Восстанавливаем input
	if background:
		background.mouse_filter = Control.MOUSE_FILTER_STOP
	if close_button:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if left_arrow:
		left_arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	if right_arrow:
		right_arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# ═══════════════════════════════════════════════════════════════════════
	# АНИМАЦИЯ ОТКРЫТИЯ
	# ═══════════════════════════════════════════════════════════════════════
	if USE_ANIMATION:
		# Анимация фона - затемнение
		background.modulate.a = 0.0
		var bg_tween = get_tree().create_tween()
		bg_tween.tween_property(background, "modulate:a", 1.0, 0.3)
		
		# Анимация изображения - появление с масштабированием
		image_texture.modulate.a = 0.0
		image_texture.scale = Vector2(0.5, 0.5)
		var image_tween = get_tree().create_tween()
		image_tween.set_parallel(true)
		image_tween.tween_property(image_texture, "modulate:a", 1.0, 0.3)
		image_tween.tween_property(image_texture, "scale", original_image_scale, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Анимация кнопок
		if close_button:
			close_button.modulate.a = 0.0
			var close_tween = get_tree().create_tween()
			close_tween.tween_property(close_button, "modulate:a", 1.0, 0.3)
		if left_arrow:
			left_arrow.modulate.a = 0.0
			var left_tween = get_tree().create_tween()
			left_tween.tween_property(left_arrow, "modulate:a", 1.0, 0.3)
		if right_arrow:
			right_arrow.modulate.a = 0.0
			var right_tween = get_tree().create_tween()
			right_tween.tween_property(right_arrow, "modulate:a", 1.0, 0.3)
	
	DebugLogger.log("📋 Шпаргалка показана")

## Скрыть шпаргалку
func hide_cribsheet():
	# Проверяем, что шпаргалка видима
	if not visible:
		_actually_hide_cribsheet()
		return
	
	# Отключаем input
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if close_button:
		close_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if left_arrow:
		left_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right_arrow:
		right_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# ═══════════════════════════════════════════════════════════════════════
	# АНИМАЦИЯ ЗАКРЫТИЯ
	# ═══════════════════════════════════════════════════════════════════════
	if USE_ANIMATION:
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		
		# Анимация фона
		tween.tween_property(background, "modulate:a", 0.0, 0.2)
		
		# Анимация изображения
		tween.tween_property(image_texture, "modulate:a", 0.0, 0.2)
		tween.tween_property(image_texture, "scale", Vector2(0.5, 0.5), 0.2)
		
		# Анимация кнопок
		if close_button:
			tween.tween_property(close_button, "modulate:a", 0.0, 0.2)
		if left_arrow:
			tween.tween_property(left_arrow, "modulate:a", 0.0, 0.2)
		if right_arrow:
			tween.tween_property(right_arrow, "modulate:a", 0.0, 0.2)
		
		tween.set_parallel(false)
		tween.tween_callback(_actually_hide_cribsheet)
	else:
		_actually_hide_cribsheet()

## Фактическое скрытие шпаргалки
func _actually_hide_cribsheet():
	hide()
	DebugLogger.log("📋 Шпаргалка скрыта")

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _load_image(index: int):
	"""Загрузить изображение по индексу"""
	if index < 0 or index >= CRIB_IMAGES.size():
		return
	
	current_image_index = index
	var image_path = CRIB_IMAGES[index]
	
	if ResourceLoader.exists(image_path):
		var texture = load(image_path) as Texture2D
		if texture and image_texture:
			image_texture.texture = texture
			DebugLogger.log("📋 Загружено изображение шпаргалки: %s" % image_path)
		else:
			push_warning("CribSheetScene: не удалось загрузить текстуру из %s" % image_path)
	else:
		push_warning("CribSheetScene: файл не найден: %s" % image_path)

func _show_next_image():
	"""Показать следующее изображение (закольцованно)"""
	var next_index = (current_image_index + 1) % CRIB_IMAGES.size()
	_switch_image(next_index)

func _show_previous_image():
	"""Показать предыдущее изображение (закольцованно)"""
	var prev_index = (current_image_index - 1 + CRIB_IMAGES.size()) % CRIB_IMAGES.size()
	_switch_image(prev_index)

func _switch_image(new_index: int):
	"""Переключить изображение с анимацией"""
	if new_index == current_image_index or new_index < 0 or new_index >= CRIB_IMAGES.size():
		return
	
	# Анимация исчезновения текущего изображения
	var fade_out = get_tree().create_tween()
	fade_out.tween_property(image_texture, "modulate:a", 0.0, 0.15)
	await fade_out.finished
	
	# Загружаем новое изображение
	_load_image(new_index)
	
	# Анимация появления нового изображения
	image_texture.modulate.a = 0.0
	var fade_in = get_tree().create_tween()
	fade_in.tween_property(image_texture, "modulate:a", 1.0, 0.15)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_background_input(event: InputEvent):
	"""Обработка клика на фон (закрытие)"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_cribsheet()

func _on_close_button_pressed():
	"""Обработка нажатия кнопки закрытия"""
	hide_cribsheet()

func _on_left_arrow_pressed():
	"""Обработка нажатия стрелки влево"""
	_show_previous_image()

func _on_right_arrow_pressed():
	"""Обработка нажатия стрелки вправо"""
	_show_next_image()

func _unhandled_input(event: InputEvent):
	"""Обработка клавиатурного ввода для навигации"""
	if not visible:
		return
	
	# Проверяем, что это событие клавиатуры
	if not event is InputEventKey or not event.pressed:
		return
	
	# ESC или Enter для закрытия
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
		hide_cribsheet()
		get_viewport().set_input_as_handled()
		return
	
	# Стрелки влево/вправо или A/D для навигации
	if event.keycode == KEY_LEFT or event.keycode == KEY_A:
		_show_previous_image()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
		_show_next_image()
		get_viewport().set_input_as_handled()
	# Блокируем обработку вверх/вниз, чтобы они не управляли камерой
	elif event.keycode == KEY_UP or event.keycode == KEY_DOWN or event.keycode == KEY_W or event.keycode == KEY_S:
		get_viewport().set_input_as_handled()
		return

