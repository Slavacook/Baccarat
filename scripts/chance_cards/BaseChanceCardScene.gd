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
var close_button: Button = null  # Получаем из сцены или создаём программно

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Текущая карта
var current_card: BaseChanceCard = null

## Включить анимацию (можно отключить для мгновенного показа)
const USE_ANIMATION: bool = true

## Аниматор для открытия карты (Strategy Pattern)
var open_animator: BaseCardAnimator = null

## Аниматор для закрытия карты (может отличаться от открытия)
var close_animator: BaseCardAnimator = null

## Флаг подписки на изменения состояния игры
var _is_state_subscribed: bool = false

## Сохраняем исходные значения для восстановления после анимации
var original_card_scale: Vector2 = Vector2.ONE
var original_card_modulate: Color = Color.WHITE
var original_bg_modulate: Color = Color.WHITE  # modulate фона (цвет затемнения задаётся в сцене)
var original_card_position: Vector2 = Vector2.ZERO  # ВАЖНО: позиция тоже должна восстанавливаться!

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	layer = 200  # Поверх всего UI
	hide()
	
	# Создаём аниматоры по умолчанию
	_setup_animators()
	
	# Сохраняем исходные значения
	if card_texture:
		original_card_scale = card_texture.scale
		original_card_modulate = card_texture.modulate
		original_card_position = card_texture.position  # ВАЖНО: сохраняем позицию!
		# Устанавливаем pivot_offset в центр карты для масштабирования из центра
		# pivot_offset работает в локальных координатах (от левого верхнего угла)
		await get_tree().process_frame  # Ждём, пока размер установится
		var card_size = card_texture.size
		if card_size != Vector2.ZERO:
			# Устанавливаем pivot в центр размера карты
			card_texture.pivot_offset = card_size / 2.0
		# Обновляем позицию после ожидания кадра (на случай если она изменилась)
		original_card_position = card_texture.position
	if background:
		original_bg_modulate = background.modulate
	
	# Получаем или создаём кнопку "Закрыть"
	close_button = get_node_or_null("CloseButton")
	if not close_button and use_button:
		# Создаём программно, используя use_button как шаблон
		close_button = Button.new()
		close_button.name = "CloseButton"
		add_child(close_button)
		# Копируем параметры из use_button
		close_button.anchors_preset = use_button.anchors_preset
		close_button.anchor_left = use_button.anchor_left
		close_button.anchor_top = use_button.anchor_top
		close_button.anchor_right = use_button.anchor_right
		close_button.anchor_bottom = use_button.anchor_bottom
		close_button.offset_left = use_button.offset_left
		close_button.offset_top = use_button.offset_top
		close_button.offset_right = use_button.offset_right
		close_button.offset_bottom = use_button.offset_bottom
		close_button.grow_horizontal = use_button.grow_horizontal
		close_button.grow_vertical = use_button.grow_vertical
		close_button.theme = use_button.theme
		if use_button.has_theme_font_size_override("font_size"):
			close_button.add_theme_font_size_override("font_size", use_button.get_theme_font_size("font_size"))
		close_button.text = "Закрыть"  # Исправлено: Localization.t() принимает массив, а не строку
		close_button.visible = false
	
	# Подключаем сигналы
	if background:
		background.gui_input.connect(_on_background_input)
	if use_button:
		use_button.pressed.connect(_on_use_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# Настраиваем кнопки
	if use_button:
		use_button.text = Localization.t("USE_BUTTON")

## Настроить аниматоры (можно переопределить в наследниках для другого поведения)
func _setup_animators() -> void:
	# По умолчанию: открытие с масштабом от 0
	open_animator = ScaleFromZeroAnimator.new()
	
	# По умолчанию: закрытие с улётом к хранилищу
	close_animator = ScaleFromStorageAnimator.new()

## Установить аниматор открытия
func set_open_animator(animator: BaseCardAnimator) -> void:
	open_animator = animator

## Установить аниматор закрытия
func set_close_animator(animator: BaseCardAnimator) -> void:
	close_animator = animator

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
	
	# Восстанавливаем позицию
	card_texture.position = original_card_position
	
	# ═══════════════════════════════════════════════════════════════════════
	# ПОДГОТОВКА К АНИМАЦИИ
	# ═══════════════════════════════════════════════════════════════════════
	if USE_ANIMATION and open_animator:
		# Настраиваем аниматор с целевыми значениями
		open_animator.set_targets(original_card_scale, original_card_modulate, original_bg_modulate)
		open_animator.set_storage_position(storage_pos)
		
		# Подготавливаем карту к анимации (устанавливает начальное состояние)
		open_animator.prepare_for_open(card_texture, background)
	else:
		# Если анимация выключена - показываем всё сразу
		card_texture.scale = original_card_scale
		card_texture.modulate = original_card_modulate
		background.modulate = original_bg_modulate
	
	# Обновляем видимость кнопки на основе возможности использования
	_update_use_button_visibility()
	
	# Подписываемся на изменения состояния игры для динамического обновления кнопки
	if not _is_state_subscribed:
		GameStateManager.state_changed.connect(_on_game_state_changed)
		_is_state_subscribed = true
	
	# Показываем - позиция и размер берутся ТОЛЬКО из сцены (Inspector)
	show()
	
	# Ждём один кадр, чтобы узел полностью инициализировался
	await get_tree().process_frame
	
	# Явно обновляем видимость кнопок после show(), чтобы они отображались сразу
	_update_use_button_visibility()
	
	# Устанавливаем фокус на кнопку после открытия
	await get_tree().process_frame
	var target_button: Button = null
	if use_button and use_button.visible:
		target_button = use_button
	elif close_button and close_button.visible:
		target_button = close_button
	
	if target_button:
		target_button.grab_focus()
		print("🎴 BaseChanceCardScene: фокус установлен на кнопку %s" % target_button.name)
	
	# Восстанавливаем input
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	if use_button:
		use_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if close_button:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# ═══════════════════════════════════════════════════════════════════════
	# АНИМАЦИЯ ОТКРЫТИЯ
	# ═══════════════════════════════════════════════════════════════════════
	if USE_ANIMATION and open_animator:
		# Анимация фона - напрямую здесь (ПОСЛЕ await), чтобы гарантировать правильное начальное значение
		background.modulate.a = 0.0  # Явно устанавливаем начальное значение
		var bg_tween = get_tree().create_tween()
		bg_tween.tween_property(background, "modulate:a", 1.0, 0.3)
		
		# Анимация карты через аниматор
		open_animator.animate_open(card_texture, background)

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
	if use_button:
		use_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if close_button:
		close_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# ═══════════════════════════════════════════════════════════════════════
	# АНИМАЦИЯ ЗАКРЫТИЯ
	# ═══════════════════════════════════════════════════════════════════════
	if USE_ANIMATION and close_animator:
		# Получаем позицию миниатюры (если нужно для анимации)
		var storage_pos = Vector2.ZERO
		if ChanceCardManager.storage:
			storage_pos = ChanceCardManager.storage.get_storage_position_for_card(current_card.card_id)
		
		# Настраиваем аниматор
		close_animator.set_storage_position(storage_pos)
		
		# ВАЖНО: карта должна оставаться видимой во время анимации!
		# Не вызываем hide() здесь - только после анимации в callback
		
		# Анимируем закрытие с callback для фактического скрытия
		close_animator.animate_close(
			card_texture,
			background,
			Callable(self, "_actually_hide_card")
		)
		return  # ВАЖНО: выходим, чтобы не вызывать _actually_hide_card() сразу
	else:
		# Без анимации - просто скрываем
		_actually_hide_card()

## Установить фокус на кнопку (для навигатора)
func _focus_button_for_navigator():
	"""Установить фокус на кнопку (вызывается из навигатора)"""
	var target_button: Button = null
	if use_button and use_button.visible:
		target_button = use_button
	elif close_button and close_button.visible:
		target_button = close_button
	
	if target_button:
		target_button.grab_focus()
		print("🎴 BaseChanceCardScene: фокус установлен на кнопку %s (из навигатора)" % target_button.name)

## Фактическое скрытие карты (вызывается после анимации или сразу)
func _actually_hide_card():
	# Отписываемся от изменений состояния игры
	if _is_state_subscribed:
		if GameStateManager.state_changed.is_connected(_on_game_state_changed):
			GameStateManager.state_changed.disconnect(_on_game_state_changed)
		_is_state_subscribed = false
	
	# Восстанавливаем исходные значения перед скрытием
	card_texture.position = original_card_position  # ВАЖНО: восстанавливаем позицию!
	card_texture.scale = original_card_scale
	card_texture.modulate = original_card_modulate
	background.modulate = original_bg_modulate
	
	# Эмитим сигнал закрытия ПЕРЕД скрытием
	if current_card:
		current_card.card_closed.emit(current_card)
		EventBus.chance_card_popup_closed.emit()
	
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
			# Проверяем что клик был НЕ на карте и НЕ на кнопке (если кнопка видима)
			var card_rect = card_texture.get_global_rect()
			var click_pos = mb.global_position
			
			# Проверяем клик на кнопках только если они видимы
			var clicked_on_button = false
			if use_button and use_button.visible:
				var button_rect = use_button.get_global_rect()
				clicked_on_button = button_rect.has_point(click_pos)
			if not clicked_on_button and close_button and close_button.visible:
				var button_rect = close_button.get_global_rect()
				clicked_on_button = button_rect.has_point(click_pos)
			
			if not card_rect.has_point(click_pos) and not clicked_on_button:
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

func _on_close_button_pressed():
	"""Нажата кнопка 'Закрыть'"""
	close_card()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ: Управление видимостью кнопки
# ═══════════════════════════════════════════════════════════════════════════

func _update_use_button_visibility() -> void:
	"""Обновить видимость кнопок 'Использовать' и 'Закрыть' на основе can_use()"""
	if not current_card:
		return
	
	var can_use_card = current_card.can_use()
	
	# Показываем кнопку "Использовать" только если карту можно использовать
	# Показываем кнопку "Закрыть" только если карту нельзя использовать
	if use_button:
		use_button.visible = can_use_card
		if can_use_card:
			use_button.modulate = Color.WHITE
	
	if close_button:
		close_button.visible = not can_use_card
		if not can_use_card:
			close_button.modulate = Color.WHITE

func _on_game_state_changed(_old_state, _new_state) -> void:
	"""Обработчик изменения состояния игры - обновляем видимость кнопки"""
	if current_card and visible:
		_update_use_button_visibility()
