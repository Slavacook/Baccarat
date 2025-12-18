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

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	layer = 200  # Поверх всего UI
	hide()
	
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
	
	# Показываем - позиция и размер берутся ТОЛЬКО из сцены (Inspector)
	show()
	
	# Восстанавливаем input
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	use_button.mouse_filter = Control.MOUSE_FILTER_STOP

## Скрыть карту
func hide_card():
	if not current_card:
		return
	
	# Отключаем input
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Просто скрываем
	hide()
	
	# Эмитим сигнал закрытия
	if current_card:
		current_card.card_closed.emit(current_card)
		EventBus.chance_card_popup_closed.emit()
	
	current_card = null

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
