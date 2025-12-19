# res://scripts/PayoutSurvivalInfo.gd
# Компонент для отображения жизней (survival mode) или очков (normal mode) в PayoutOverlay
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
const HEART_SIZE = 24  # ← Размер одного сердечка

var single_heart: TextureRect  # ← Одно сердце
var lives_count_label: Label   # ← Label с количеством жизней
var heart_full: Texture2D

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
	if lives_container:
		lives_container.add_theme_constant_override("separation", 4)

	# Создаём одно сердце и Label с количеством жизней
	_create_single_heart_display()
	
	# Инициализируем LabelHeartVisual
	if lives_count_label and single_heart:
		heart_visual = LabelHeartVisual.new(
			lives_count_label,
			single_heart,
			heart_full
		)

	# Начальное состояние (скрыто до первого update)
	lives_container.visible = false
	score_label.visible = false

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

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ ОТОБРАЖЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════

func update_display(is_survival_mode: bool, current_lives: int, score: int):
	"""Обновить отображение на основе текущего режима

	Args:
		is_survival_mode: Активен ли survival mode
		current_lives: Текущее количество жизней (для survival mode)
		score: Текущий счёт (для обычного режима)
	"""
	print("🔍 PayoutSurvivalInfo.update_display вызван: survival=%s, lives=%d, score=%d" % [is_survival_mode, current_lives, score])

	if is_survival_mode:
		# Показываем сердечки, скрываем очки
		print("  → Показываем сердечки")
		lives_container.visible = true
		score_label.visible = false
		_update_hearts(current_lives)
	else:
		# Показываем очки, скрываем сердечки
		print("  → Показываем очки")
		lives_container.visible = false
		score_label.visible = true
		_update_score(score)

func _update_hearts(current_lives: int):
	"""Обновить отображение: одно сердце и количество жизней

	Args:
		current_lives: Текущее количество жизней (0-7)
	"""
	var clamped_lives = clamp(current_lives, 0, MAX_LIVES)
	print("  → _update_hearts: current_lives=%d, clamped=%d" % [current_lives, clamped_lives])

	# Используем LabelHeartVisual для обновления
	if heart_visual:
		heart_visual.update_visual(HeartState.State.FULL, clamped_lives)
	else:
		# Fallback на старый код для обратной совместимости
		if lives_count_label:
			lives_count_label.text = str(clamped_lives)
		if single_heart:
			single_heart.texture = heart_full

	print("  ✅ Отображение жизней обновлено: ♥ %d" % clamped_lives)

func _update_score(score: int):
	"""Обновить счёт в обычном режиме

	Args:
		score: Количество очков
	"""
	score_label.text = "Очки: %d" % score

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКА РАЗМЕРА СЕРДЕЧКА
# ═══════════════════════════════════════════════════════════════════════════

func set_heart_size(pixel_size: int):
	"""Изменить размер сердечка

	Args:
		pixel_size: Новый размер в пикселях

	Примечание:
		Вызовите этот метод ПЕРЕД _ready() если хотите изменить размер.
		Или вызовите после _ready() для динамического изменения.
	"""
	if single_heart:
		single_heart.custom_minimum_size = Vector2(pixel_size, pixel_size)

	print("♥️  Размер сердечка изменён на %d px" % pixel_size)
