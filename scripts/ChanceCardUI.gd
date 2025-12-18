# res://scripts/ChanceCardUI.gd
# Отдельный компонент для карты "Шанс" и счётчика
class_name ChanceCardUI
extends Control

# ═══════════════════════════════════════════════════════════════════════════
# УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@onready var chance_indicator: TextureButton = %ChanceIndicator
@onready var chance_counter: Label = %ChanceCounter

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal card_clicked()
signal card_hovered(is_hover: bool)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Финальная позиция и размер карты (сохраняются при старте)
var _final_position: Vector2 = Vector2.ZERO
var _final_scale: Vector2 = Vector2.ONE
var _animation_tween: Tween = null

## Текстура карты
var card_texture: Texture2D = null

## Масштаб для hover эффекта
const SCALE_NORMAL: Vector2 = Vector2(1.3, 1.3)
const SCALE_HOVER: Vector2 = Vector2(1.43, 1.43)  # 1.3 * 1.1

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Загружаем текстуру карты
	_load_card_texture()
	
	# Настраиваем кнопку
	_setup_button()
	
	# Скрываем по умолчанию
	hide_card()

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКА
# ═══════════════════════════════════════════════════════════════════════════

func _load_card_texture() -> void:
	"""Загрузить текстуру карты"""
	if ResourceLoader.exists("res://assets/ui/invitation_card.png"):
		card_texture = load("res://assets/ui/invitation_card.png")
	else:
		# Заглушка
		if ResourceLoader.exists("res://assets/ui/heart_focus.png"):
			card_texture = load("res://assets/ui/heart_focus.png")
		else:
			card_texture = preload("res://assets/ui/heart.png")
		print("⚠️  ChanceCardUI: invitation_card.png не найден, используем заглушку")

func _setup_button() -> void:
	"""Настройка кнопки карты"""
	if not chance_indicator:
		print("⚠️ ChanceCardUI: ChanceIndicator не найден!")
		return
	
	# Сохраняем начальные параметры
	await get_tree().process_frame  # Ждём один кадр для правильного размера
	_final_position = position
	_final_scale = chance_indicator.scale
	
	# Настраиваем текстуру
	if card_texture:
		chance_indicator.texture_normal = card_texture
	
	# Настраиваем кликабельность
	chance_indicator.mouse_filter = Control.MOUSE_FILTER_STOP
	chance_indicator.disabled = false
	
	# Подключаем сигналы
	chance_indicator.pressed.connect(_on_card_clicked)
	chance_indicator.mouse_entered.connect(_on_card_hover.bind(true))
	chance_indicator.mouse_exited.connect(_on_card_hover.bind(false))
	
	# Устанавливаем pivot для масштабирования из центра
	if chance_indicator.size != Vector2.ZERO:
		chance_indicator.pivot_offset = chance_indicator.size / 2
	
	print("🎴 ChanceCardUI: карта настроена")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СИГНАЛОВ
# ═══════════════════════════════════════════════════════════════════════════

func _on_card_clicked() -> void:
	"""Клик на карту"""
	card_clicked.emit()

func _on_card_hover(is_hover: bool) -> void:
	"""Hover эффект на карте"""
	if not chance_indicator or not chance_indicator.visible:
		return
	
	var target_scale = SCALE_HOVER if is_hover else _final_scale
	
	var tween = create_tween()
	tween.tween_property(chance_indicator, "scale", target_scale, 0.1)
	
	card_hovered.emit(is_hover)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func show_card_animated() -> void:
	"""Показать карту с анимацией (при получении нового шанса)"""
	if not chance_indicator:
		return
	
	# Отменяем предыдущую анимацию если есть
	if _animation_tween:
		_animation_tween.kill()
	
	# Настраиваем текстуру
	if card_texture:
		chance_indicator.texture_normal = card_texture
	
	# Начальное состояние: большая карта в центре экрана
	# Позиция вычисляется относительно viewport, но применяется к родителю
	var viewport_size = get_viewport().get_visible_rect().size
	var global_center = Vector2(viewport_size.x / 2, viewport_size.y / 2)
	var parent_global_pos = get_global_position()
	var local_center = global_center - parent_global_pos
	
	# Временно перемещаем карту в центр экрана
	var start_position = local_center - Vector2(size.x / 2, size.y / 2)
	position = start_position
	
	chance_indicator.position = Vector2.ZERO  # Относительно родителя
	chance_indicator.scale = Vector2(4, 4)
	chance_indicator.modulate.a = 0.0
	chance_indicator.visible = true
	
	# Анимация
	_animation_tween = create_tween()
	_animation_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	
	# Фаза 1: Появление (0.3 сек)
	_animation_tween.tween_property(chance_indicator, "modulate:a", 1.0, 0.3)
	
	# Фаза 2: Пауза на экране (1 секунда)
	_animation_tween.tween_interval(1.0)
	
	# Фаза 3: Уменьшение и перемещение к финальной позиции (0.5 сек)
	_animation_tween.set_parallel(true)
	_animation_tween.tween_property(self, "position", _final_position, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_animation_tween.tween_property(chance_indicator, "scale", _final_scale, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	print("🎰 ChanceCardUI: анимация карты запущена")

func show_card() -> void:
	"""Показать карту (простой показ, без анимации)"""
	if chance_indicator:
		if card_texture:
			chance_indicator.texture_normal = card_texture
		chance_indicator.position = Vector2.ZERO
		chance_indicator.scale = _final_scale
		chance_indicator.modulate.a = 1.0
		chance_indicator.visible = true
		print("🎰 ChanceCardUI: карта показана")

func hide_card() -> void:
	"""Скрыть карту"""
	if chance_indicator:
		if _animation_tween:
			_animation_tween.kill()
			_animation_tween = null
		chance_indicator.visible = false
	
	if chance_counter:
		chance_counter.visible = false
	
	print("🎰 ChanceCardUI: карта скрыта")

func update_counter(count: int) -> void:
	"""Обновить счётчик шансов"""
	if chance_counter:
		if count > 1:
			chance_counter.text = str(count)
			chance_counter.visible = true
		else:
			chance_counter.text = ""
			chance_counter.visible = false

func set_card_enabled(enabled: bool) -> void:
	"""Установить доступность карты (цветная / чёрно-белая)"""
	if not chance_indicator:
		return
	
	if enabled:
		# Цветная карта
		chance_indicator.modulate = Color.WHITE
	else:
		# Чёрно-белая карта (недоступна)
		chance_indicator.modulate = Color(0.5, 0.5, 0.5, 1.0)

func set_card_visible(should_show: bool) -> void:
	"""Установить видимость карты"""
	if chance_indicator:
		chance_indicator.visible = should_show

func get_card_visible() -> bool:
	"""Получить видимость карты"""
	if chance_indicator:
		return chance_indicator.visible
	return false
