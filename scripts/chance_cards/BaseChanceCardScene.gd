# res://scripts/chance_cards/BaseChanceCardScene.gd
# Сцена полного экрана для отображения карты шанса

class_name BaseChanceCardScene
extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════
# УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@onready var background: ColorRect = $Background
@onready var card_texture: TextureRect = $CardTexture
@onready var use_button: Button = $UseButton

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Текущая карта
var current_card: BaseChanceCard = null

## Включить анимацию (можно отключить, закомментировав вызовы анимации)
const USE_ANIMATION: bool = true

## Сохраняем исходные значения для восстановления после анимации
var original_card_scale: Vector2 = Vector2.ONE
var original_card_modulate: Color = Color.WHITE
var original_bg_modulate: Color = Color(1, 1, 1, 0.7)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	layer = 200  # Поверх всего UI
	hide()
	
	# Сохраняем исходные значения
	if card_texture:
		original_card_scale = card_texture.scale
		original_card_modulate = card_texture.modulate
		# Устанавливаем pivot_offset в центр карты для масштабирования из центра
		# pivot_offset работает в локальных координатах (от левого верхнего угла)
		await get_tree().process_frame  # Ждём, пока размер установится
		var card_size = card_texture.size
		if card_size != Vector2.ZERO:
			# Устанавливаем pivot в центр размера карты
			card_texture.pivot_offset = card_size / 2.0
	if background:
		original_bg_modulate = background.modulate
	
	# Подключаем сигналы
	if background:
		background.gui_input.connect(_on_background_input)
	if use_button:
		use_button.pressed.connect(_on_use_button_pressed)
	
	# Настраиваем кнопку
	if use_button:
		use_button.text = Localization.t("USE_BUTTON")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Показать карту на весь экран
func show_fullscreen(card: BaseChanceCard, storage_pos: Vector2 = Vector2.ZERO):
	current_card = card
	
	if not card or not card.card_texture:
		push_warning("BaseChanceCardScene: нет карты или текстуры")
		return
	
	# Настраиваем карту
	card_texture.texture = card.card_texture
	
	# Восстанавливаем исходные значения (на случай если они были изменены анимацией)
	card_texture.scale = original_card_scale
	card_texture.modulate = original_card_modulate
	background.modulate = original_bg_modulate
	
	# Показываем - позиция и размер берутся ТОЛЬКО из сцены (Inspector)
	show()
	
	# Восстанавливаем input
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	use_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# ═══════════════════════════════════════════════════════════════════════
	# АНИМАЦИЯ ОТКРЫТИЯ (можно закомментировать для отключения)
	# ═══════════════════════════════════════════════════════════════════════
	if USE_ANIMATION:
		ChanceCardAnimation.animate_open(
			card_texture,
			background,
			ChanceCardAnimation.OpenType.SCALE_FROM_ZERO,  # Изменить тип здесь
			storage_pos
		)

## Скрыть карту
func hide_card():
	if not current_card:
		return
	
	# Проверяем, что карта видима (иначе анимация не нужна)
	if not visible:
		_actually_hide_card()
		return
	
	# Отключаем input
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# ═══════════════════════════════════════════════════════════════════════
	# АНИМАЦИЯ ЗАКРЫТИЯ (можно закомментировать для отключения)
	# ═══════════════════════════════════════════════════════════════════════
	if USE_ANIMATION and ChanceCardAnimation.USE_ANIMATION:
		# Получаем позицию миниатюры (если нужно для анимации)
		var storage_pos = Vector2.ZERO
		if ChanceCardManager.storage:
			storage_pos = ChanceCardManager.storage.get_storage_position_for_card(current_card.card_id)
		
		# ВАЖНО: карта должна оставаться видимой во время анимации!
		# Не вызываем hide() здесь - только после анимации в callback
		
		# Анимируем закрытие с callback для фактического скрытия
		ChanceCardAnimation.animate_close(
			card_texture,
			background,
			ChanceCardAnimation.CloseType.SCALE_TO_ZERO,  # Изменить тип здесь
			storage_pos,
			Callable(self, "_actually_hide_card")  # Правильный способ передачи метода
		)
		return  # ВАЖНО: выходим, чтобы не вызывать _actually_hide_card() сразу
	else:
		# Без анимации - просто скрываем
		_actually_hide_card()

## Фактическое скрытие карты (вызывается после анимации или сразу)
func _actually_hide_card():
	# Восстанавливаем исходные значения перед скрытием
	card_texture.scale = original_card_scale
	card_texture.modulate = original_card_modulate
	background.modulate = original_bg_modulate
	
	# Эмитим сигнал закрытия ПЕРЕД скрытием
	if current_card:
		current_card.card_closed.emit(current_card)
		EventBus.chance_card_popup_closed.emit()
	
	var card_to_clear = current_card
	current_card = null
	
	# Скрываем в конце
	hide()

## Закрыть карту без использования
func close_card():
	hide_card()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_background_input(event: InputEvent):
	"""Клик на фон = закрыть карту (если клик не на самой карте)"""
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# Проверяем что клик был НЕ на карте и НЕ на кнопке
			var card_rect = card_texture.get_global_rect()
			var button_rect = use_button.get_global_rect()
			var click_pos = mb.global_position
			
			if not card_rect.has_point(click_pos) and not button_rect.has_point(click_pos):
				close_card()

func _on_use_button_pressed():
	"""Нажата кнопка 'Использовать'"""
	if not current_card:
		return
	
	# Проверяем доступность
	if not current_card.can_use():
		EventBus.show_toast_error.emit(Localization.t("CARD_CANNOT_USE"))
		return
	
	# Используем карту
	current_card.on_use()
	current_card.card_used.emit(current_card)
	EventBus.chance_card_use_requested.emit()
	
	# Скрываем карту
	hide_card()
