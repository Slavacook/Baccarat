# res://scripts/ChanceCardPopup.gd
# Popup с большой картой шанса и кнопкой "Использовать"

extends CanvasLayer

signal use_pressed()
signal closed()

@onready var background: ColorRect = $Background
@onready var card_texture: TextureRect = $CardTexture
@onready var use_button: Button = $UseButton

## Текстура карты
var card_image: Texture2D = null

## Анимация
var _tween: Tween = null


func _ready():
	# Скрываем по умолчанию
	hide()
	layer = 150  # Поверх большинства UI
	
	# Загружаем текстуру карты
	if ResourceLoader.exists("res://assets/ui/invitation_card.png"):
		card_image = load("res://assets/ui/invitation_card.png")
	
	# Подключаем сигналы
	if background:
		background.gui_input.connect(_on_background_input)
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
	
	# Подписываемся на EventBus
	EventBus.chance_card_pressed.connect(_on_chance_card_pressed)
	
	print("🎴 ChanceCardPopup готов")


func _on_chance_card_pressed():
	"""Открыть popup с большой картой"""
	show_popup()


func show_popup():
	"""Показать popup с анимацией"""
	if _tween:
		_tween.kill()
	
	# Настраиваем карту
	if card_texture and card_image:
		card_texture.texture = card_image
	
	# Начальное состояние (применяем к background и card_texture)
	if background:
		background.modulate.a = 0.0
	if card_texture:
		card_texture.modulate.a = 0.0
		card_texture.scale = Vector2(0.5, 0.5)
	if use_button:
		use_button.modulate.a = 0.0
	
	show()
	
	# Анимация появления
	_tween = create_tween()
	_tween.set_parallel(true)
	if background:
		_tween.tween_property(background, "modulate:a", 1.0, 0.3)
	if card_texture:
		_tween.tween_property(card_texture, "modulate:a", 1.0, 0.3)
		_tween.tween_property(card_texture, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if use_button:
		_tween.tween_property(use_button, "modulate:a", 1.0, 0.3)
	
	print("🎴 Popup карты показан")


func hide_popup():
	"""Скрыть popup с анимацией"""
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_parallel(true)
	if background:
		_tween.tween_property(background, "modulate:a", 0.0, 0.2)
	if card_texture:
		_tween.tween_property(card_texture, "modulate:a", 0.0, 0.2)
	if use_button:
		_tween.tween_property(use_button, "modulate:a", 0.0, 0.2)
	_tween.set_parallel(false)
	_tween.tween_callback(hide)
	
	print("🎴 Popup карты скрыт")


func _on_background_input(event: InputEvent):
	"""Клик на фон = закрыть popup"""
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# Проверяем что клик был НЕ на карте
			if card_texture:
				var card_rect = card_texture.get_global_rect()
				if not card_rect.has_point(mb.global_position):
					hide_popup()
					closed.emit()
					EventBus.chance_card_popup_closed.emit()


func _on_use_pressed():
	"""Нажата кнопка "Использовать" """
	print("🎴 Нажата кнопка 'Использовать'")
	hide_popup()
	use_pressed.emit()
	EventBus.chance_card_use_requested.emit()
