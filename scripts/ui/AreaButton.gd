# res://scripts/ui/AreaButton.gd
# Кнопка области ставок - прозрачная, видна при наведении мыши
# Используется для выбора области для работы со ставками

extends TextureButton
class_name AreaButton

# ═══════════════════════════════════════════════════════════════════════════
# ЭКСПОРТНЫЕ ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Индекс области (1, 2 или 3)
@export var area_index: int = 1

## Прозрачность в обычном состоянии (0.0 = полностью прозрачная)
@export var normal_alpha: float = 0.0

## Прозрачность при наведении (1.0 = полностью видимая)
@export var hover_alpha: float = 0.7

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Устанавливаем начальную прозрачность
	modulate.a = normal_alpha
	
	# Подключаем сигналы мыши
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	
	# Подключаемся к EventBus для управления видимостью
	if EventBus:
		EventBus.area_buttons_visibility_changed.connect(_on_visibility_changed)
	
	print("🔘 AreaButton %d инициализирован" % area_index)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_mouse_entered() -> void:
	"""Показать кнопку при наведении мыши"""
	modulate.a = hover_alpha

func _on_mouse_exited() -> void:
	"""Скрыть кнопку при уходе мыши"""
	modulate.a = normal_alpha

func _on_pressed() -> void:
	"""Обработка нажатия - переключить камеру на эту область"""
	print("🔘 Нажата кнопка области %d" % area_index)
	
	# Запрашиваем зум на эту область через EventBus
	EventBus.camera_zoom_requested.emit("area_%d" % area_index, false)
	
	# Скрываем кнопки областей (они больше не нужны после выбора)
	EventBus.area_buttons_visibility_changed.emit(false)
	
	# Активируем навигацию по полю (стрелки визуально скрыты, но навигация работает)
	EventBus.navigation_arrows_visibility_changed.emit(true)

func _on_visibility_changed(should_show: bool) -> void:
	"""Обработка изменения видимости всех кнопок областей"""
	visible = should_show
	if not should_show:
		# Сбрасываем прозрачность при скрытии
		modulate.a = normal_alpha
