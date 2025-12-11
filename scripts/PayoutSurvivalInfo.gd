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
const HEART_SIZE = 24  # ← Размер сердечек (уменьшен с 28 до 24)
const HEART_SEPARATION = 1  # ← Расстояние между сердечками (минимальное)

var heart_nodes: Array[TextureRect] = []
var heart_full: Texture2D
var heart_empty: Texture2D

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Загружаем текстуры сердечек (используем те же что и в SurvivalModeUI)
	heart_full = preload("res://assets/ui/heart.png")
	heart_empty = preload("res://assets/ui/heart_empty.png")

	# Устанавливаем минимальное расстояние между сердечками
	if lives_container:
		lives_container.add_theme_constant_override("separation", HEART_SEPARATION)

	# Создаём 7 сердечек в LivesContainer
	_create_hearts()

	# Начальное состояние (скрыто до первого update)
	lives_container.visible = false
	score_label.visible = false

# ═══════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ СЕРДЕЧЕК
# ═══════════════════════════════════════════════════════════════════════════

func _create_hearts():
	"""Создать 7 TextureRect сердечек"""
	for i in range(MAX_LIVES):
		var heart = TextureRect.new()
		heart.texture = heart_full
		heart.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
		heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lives_container.add_child(heart)
		heart_nodes.append(heart)

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
	if is_survival_mode:
		# Показываем сердечки, скрываем очки
		lives_container.visible = true
		score_label.visible = false
		_update_hearts(current_lives)
	else:
		# Показываем очки, скрываем сердечки
		lives_container.visible = false
		score_label.visible = true
		_update_score(score)

func _update_hearts(current_lives: int):
	"""Обновить визуальное состояние сердечек (как в SurvivalModeUI)

	Args:
		current_lives: Текущее количество жизней (0-7)
	"""
	var clamped_lives = clamp(current_lives, 0, MAX_LIVES)

	for i in range(MAX_LIVES):
		if i < clamped_lives:
			heart_nodes[i].texture = heart_full  # Красное сердечко
		else:
			heart_nodes[i].texture = heart_empty  # Черное сердечко

func _update_score(score: int):
	"""Обновить счёт в обычном режиме

	Args:
		score: Количество очков
	"""
	score_label.text = "Очки: %d" % score

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКА РАЗМЕРА СЕРДЕЧЕК
# ═══════════════════════════════════════════════════════════════════════════

func set_heart_size(size: int):
	"""Изменить размер сердечек

	Args:
		size: Новый размер в пикселях

	Примечание:
		Вызовите этот метод ПЕРЕД _ready() если хотите изменить размер.
		Или вызовите после _ready() для динамического изменения.
	"""
	for heart in heart_nodes:
		heart.custom_minimum_size = Vector2(size, size)

	print("♥️  Размер сердечек изменён на %d px" % size)
