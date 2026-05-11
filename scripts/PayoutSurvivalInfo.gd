# res://scripts/PayoutSurvivalInfo.gd
# Компонент для отображения денег и жизней в PayoutOverlay
# Формат: [ 💰 1250 ]  [ ♥ 7 ]
class_name PayoutSurvivalInfo
extends HBoxContainer

# ═══════════════════════════════════════════════════════════════════════════
# УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@onready var lives_container: HBoxContainer = $LivesContainer
@onready var score_label: Label = $ScoreLabel

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ И ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

const MAX_LIVES = 7
const HEART_SIZE = 24  # Размер одного сердечка

var single_heart: TextureRect  # Одно сердце
var lives_count_label: Label   # Label с количеством жизней
var heart_full: Texture2D

# Контейнер для денег
var money_container: HBoxContainer
var money_icon: TextureRect
var money_label: Label
var tournament_errors_badge: PanelContainer
var tournament_errors_margin: MarginContainer
var tournament_errors_label: Label

# ═══════════════════════════════════════════════════════════════════════════
# НОВАЯ СИСТЕМА: LabelHeartVisual
# ═══════════════════════════════════════════════════════════════════════════

## Визуализация для Label + TextureRect
var heart_visual: LabelHeartVisual = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Загружаем текстуру сердечка
	heart_full = preload("res://assets/ui/heart.png")

	# Устанавливаем минимальное расстояние между элементами
	add_theme_constant_override("separation", 16)  # Расстояние между деньгами и сердцами

	if lives_container:
		lives_container.add_theme_constant_override("separation", 4)

	# Создаём контейнер для денег (слева)
	_create_money_display()

	# Создаём одно сердце и Label с количеством жизней (справа)
	_create_single_heart_display()
	_create_tournament_errors_display()
	
	# Инициализируем LabelHeartVisual
	if lives_count_label and single_heart:
		heart_visual = LabelHeartVisual.new(
			lives_count_label,
			single_heart,
			heart_full
		)

	# Скрываем старый score_label (теперь используем money_label)
	if score_label:
		score_label.visible = false

	# Показываем оба контейнера
	if money_container:
		money_container.visible = true
	if lives_container:
		lives_container.visible = true
	if tournament_errors_label:
		tournament_errors_label.visible = false

# ═══════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ ОТОБРАЖЕНИЯ ДЕНЕГ
# ═══════════════════════════════════════════════════════════════════════════

func _create_money_display():
	"""Создать отображение денег: иконка + сумма"""
	money_container = HBoxContainer.new()
	money_container.add_theme_constant_override("separation", 4)
	
	# Вставляем в начало (перед lives_container)
	add_child(money_container)
	move_child(money_container, 0)
	
	# Лейбл чаевых
	money_label = Label.new()
	money_label.text = "Чаевые: 0"
	money_label.add_theme_font_size_override("font_size", 20)
	money_container.add_child(money_label)

# ═══════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ ОТОБРАЖЕНИЯ ЖИЗНЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func _create_single_heart_display():
	"""Создать одно сердце и Label с количеством жизней"""
	# Создаём одно сердце
	single_heart = TextureRect.new()
	single_heart.texture = heart_full
	single_heart.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
	single_heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	single_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lives_container.add_child(single_heart)

	# Создаём Label с количеством жизней
	lives_count_label = Label.new()
	lives_count_label.text = "7"
	lives_count_label.add_theme_font_size_override("font_size", 20)
	lives_container.add_child(lives_count_label)


func _create_tournament_errors_display():
	"""Создать badge для индикатора турнирных ошибок"""
	tournament_errors_badge = PanelContainer.new()
	tournament_errors_badge.visible = false
	tournament_errors_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.08, 0.19, 0.15, 0.94)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(0.79, 0.69, 0.45, 0.85)
	badge_style.corner_radius_top_left = 8
	badge_style.corner_radius_top_right = 8
	badge_style.corner_radius_bottom_right = 8
	badge_style.corner_radius_bottom_left = 8
	tournament_errors_badge.add_theme_stylebox_override("panel", badge_style)

	tournament_errors_margin = MarginContainer.new()
	tournament_errors_margin.add_theme_constant_override("margin_left", 10)
	tournament_errors_margin.add_theme_constant_override("margin_top", 5)
	tournament_errors_margin.add_theme_constant_override("margin_right", 10)
	tournament_errors_margin.add_theme_constant_override("margin_bottom", 5)
	tournament_errors_badge.add_child(tournament_errors_margin)

	tournament_errors_label = Label.new()
	tournament_errors_label.visible = false
	tournament_errors_label.text = ""
	tournament_errors_label.add_theme_font_size_override("font_size", 20)
	tournament_errors_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.8, 1.0))
	tournament_errors_margin.add_child(tournament_errors_label)
	add_child(tournament_errors_badge)

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ ОТОБРАЖЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func update_display(_is_survival_mode: bool, current_lives: int, money: int):
	"""Обновить отображение денег и жизней
	
	Args:
		_is_survival_mode: Игнорируется (теперь всегда показываем оба)
		current_lives: Текущее количество жизней
		money: Текущее количество денег
	"""
	# Всегда показываем оба элемента
	_show_survival_status()
	_update_money(money)
	_update_hearts(current_lives)


func show_tournament_errors(errors_total: int, max_errors: int, money: int) -> void:
	"""Показать турнирный индикатор ошибок вместо старого блока жизней"""
	_update_money(money)
	if lives_container:
		lives_container.visible = false
	if tournament_errors_badge:
		tournament_errors_badge.visible = true
	if tournament_errors_label:
		tournament_errors_label.text = "Ошибки: %d / %d" % [max(0, errors_total), max(0, max_errors)]
		tournament_errors_label.visible = true


func hide_status_block(money: int) -> void:
	"""Скрыть правый статусный блок, оставить только деньги"""
	_update_money(money)
	if lives_container:
		lives_container.visible = false
	if tournament_errors_badge:
		tournament_errors_badge.visible = false
	if tournament_errors_label:
		tournament_errors_label.visible = false


func _show_survival_status() -> void:
	"""Показать обычный survival статус"""
	if lives_container:
		lives_container.visible = true
	if tournament_errors_badge:
		tournament_errors_badge.visible = false
	if tournament_errors_label:
		tournament_errors_label.visible = false

func _update_money(money: int):
	"""Обновить отображение денег
	
	Args:
		money: Количество денег
	"""
	if money_label:
		money_label.text = "Чаевые: %d" % money

func _update_hearts(current_lives: int):
	"""Обновить отображение: одно сердце и количество жизней

	Args:
		current_lives: Текущее количество жизней (0-7)
	"""
	var clamped_lives = clamp(current_lives, 0, MAX_LIVES)

	# Используем LabelHeartVisual для обновления
	if heart_visual:
		heart_visual.update_visual(HeartState.State.FULL, clamped_lives)
	else:
		# Fallback на старый код для обратной совместимости
		if lives_count_label:
			lives_count_label.text = str(clamped_lives)
		if single_heart:
			single_heart.texture = heart_full

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКА РАЗМЕРА СЕРДЕЧКА
# ═══════════════════════════════════════════════════════════════════════════

func set_heart_size(pixel_size: int):
	"""Изменить размер сердечка

	Args:
		pixel_size: Новый размер в пикселях
	"""
	if single_heart:
		single_heart.custom_minimum_size = Vector2(pixel_size, pixel_size)
