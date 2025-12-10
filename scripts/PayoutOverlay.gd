# res://scripts/PayoutOverlay.gd
# Overlay для расчёта выплаты с использованием фишек
# Отображается поверх Game.tscn (CanvasLayer)
# Использует модульную архитектуру: ChipStack, ChipStackManager, PayoutValidator

extends Control

# ═══════════════════════════════════════════════════════════════════════════
# UI ЭЛЕМЕНТЫ (обновленные пути)
# ═══════════════════════════════════════════════════════════════════════════

@onready var result_label = $MarginContainer/VBoxContainer/HeaderHBox/ResultLabel
@onready var stake_label = $MarginContainer/VBoxContainer/HeaderHBox/StakeLabel
@onready var amount_panel = $MarginContainer/VBoxContainer/HeaderHBox/AmountPanel
@onready var collected_amount_label = $MarginContainer/VBoxContainer/HeaderHBox/AmountPanel/CollectedAmountLabel
@onready var payout_button: Button = $MarginContainer/VBoxContainer/FleetPanel/FleetMargin/FleetHBox/PayoutButton
@onready var hint_button = $MarginContainer/VBoxContainer/HeaderHBox/HintButton
@onready var score_label = %ScoreLabel
@onready var main_panel = %MainPanel
@onready var chip_stacks_container = %ChipStacksContainer
@onready var fleet_panel = %FleetPanel
@onready var chip_fleet_container = %ChipFleetContainer
@onready var feedback_label = %FeedbackLabel
@onready var feedback_container = $FeedbackContainer

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@warning_ignore("unused_signal")
signal payout_confirmed(is_correct: bool, collected: float, expected: float)
signal hint_used()

# Новый сигнал для overlay режима
# bet_type: тип ставки ("Player"/"Banker"/"Tie"/"PairPlayer"/"PairBanker")
signal payout_completed(bet_type: String, is_correct: bool, collected: float, expected: float)

# ═══════════════════════════════════════════════════════════════════════════
# МОДУЛИ
# ═══════════════════════════════════════════════════════════════════════════

var stack_manager: ChipStackManager  # Управление стопками фишек
var validator: PayoutValidator       # Валидация выплаты

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var chip_denominations: Array = []  # Номиналы фишек (из GameModeManager)
var current_stake: float = 0.0      # Текущая ставка
var current_winner: String = ""     # "Player", "Banker", "Tie"
var expected_payout: float = 0.0    # Ожидаемая выплата
var is_button_blocked: bool = false # Блокировка кнопки при ошибке

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Создаём модули
	stack_manager = ChipStackManager.new(chip_stacks_container)
	validator = PayoutValidator.new()

	# Подписываемся на события
	stack_manager.total_changed.connect(_on_total_changed)
	stack_manager.stack_added.connect(_on_stack_added)
	GameModeManager.mode_changed.connect(_on_mode_changed)

	# Получаем номиналы фишек
	_update_chip_denominations()

	# Настройка стилей
	_setup_styles()

	# Скрываем контейнер обратной связи по умолчанию
	feedback_container.visible = false

	# Создаём кнопки номиналов
	_create_chip_buttons()

	# Подключаем сигналы кнопок
	payout_button.pressed.connect(_on_payout_pressed)
	hint_button.pressed.connect(_on_hint_pressed)

	# Данные передаются через show_payout() из GameController
	# (НЕ загружаем из GameDataManager - overlay режим)

	# Настройка клавиатурной навигации
	_setup_keyboard_navigation()

	# Обновляем отображение очков
	_update_score_display()

func _unhandled_input(event: InputEvent):
	# Контекстная кнопка: CardsButton → Выплатить
	if event.is_action_pressed("CardsButton"):
		FocusManager.deactivate()
		payout_button.emit_signal("pressed")
		get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Инициализация сцены с результатом раунда
func setup_payout(winner: String, stake: float, payout: float):
	current_winner = winner
	current_stake = stake
	expected_payout = payout

	# Очищаем все стопки
	stack_manager.clear_all()

	# Устанавливаем заголовок и цвет
	_set_result_header(winner)

	# Ставка рядом с заголовком
	stake_label.text = Localization.t("PAYOUT_STAKE", [_format_amount(stake)])

	# Число в панели (начинаем с 0)
	collected_amount_label.text = "0"

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

# ← Обработка клика на номинал фишки (добавление)
func _on_chip_clicked(denomination: float):
	stack_manager.add_chip(denomination)

# ← Обработка правого клика по кнопке фишки (удаление)
func _on_chip_button_input(event: InputEvent, denomination: float):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		stack_manager.remove_chip(denomination)

# ← Обработчик добавления новой стопки (подключаем обработчик кликов)
func _on_stack_added(stack: ChipStack, _index: int):
	# Подключаем обработчик кликов к контейнеру стопки
	stack.container.gui_input.connect(_on_stack_clicked.bind(stack))

# ← Обработка клика на стопку (удаление из последнего стека)
func _on_stack_clicked(event: InputEvent, stack: ChipStack):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		stack_manager.remove_chip(stack.denomination)

# ← Обновление суммы при изменении стопок
func _on_total_changed(new_total: float):
	collected_amount_label.text = _format_amount(new_total)

# ← Обработка нажатия кнопки "Выплатить"
func _on_payout_pressed():
	if is_button_blocked:
		return

	var collected_total = stack_manager.get_total()

	var is_correct = validator.validate(collected_total, expected_payout)

	if is_correct:
		# ← Правильная выплата
		# Показываем анимацию успеха, затем возвращаемся
		_show_success_animation(is_correct, collected_total, expected_payout)
	else:
		# ← Неправильная выплата
		# Показываем анимацию ошибки (попап не закрывается)
		_show_error_animation(collected_total)

# ← Обработка кнопки подсказки
func _on_hint_pressed():
	# Эмитим событие использования подсказки
	# (GameController обработает штраф - очки/жизни)
	EventBus.hint_used.emit()

	# Очищаем текущие стопки
	stack_manager.clear_all()

	# Рассчитываем оптимальное распределение фишек
	var hint = validator.calculate_hint(expected_payout, chip_denominations)

	# Добавляем фишки согласно подсказке
	for item in hint:
		var denomination = item["denomination"]
		var count = item["count"]

		for i in range(count):
			stack_manager.add_chip(denomination)

	# Отправляем сигнал
	hint_used.emit()
	print("💡 Подсказка использована! Ожидаемая выплата: %s" % expected_payout)

# ← Обработчик изменения режима игры
func _on_mode_changed(_mode: String):
	_update_chip_denominations()
	_create_chip_buttons()
	stack_manager.clear_all()
	collected_amount_label.text = "0"

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - НАСТРОЙКА UI
# ═══════════════════════════════════════════════════════════════════════════

func _setup_styles():

	# === ЗАГОЛОВОК (ResultLabel) ===
	result_label.add_theme_font_size_override("font_size", GameConstants.FONT_SIZE_RESULT_LABEL)
	result_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	result_label.add_theme_constant_override("outline_size", 3)

	# === СТАВКА (StakeLabel) ===
	stake_label.add_theme_font_size_override("font_size", GameConstants.FONT_SIZE_STAKE_LABEL)
	stake_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))  # Золотистый

	# === ПАНЕЛЬ СУММЫ (AmountPanel) ===
	var amount_style = StyleBoxFlat.new()
	amount_style.bg_color = GameConstants.AMOUNT_PANEL_BG_COLOR
	amount_style.border_width_left = 2
	amount_style.border_width_top = 2
	amount_style.border_width_right = 2
	amount_style.border_width_bottom = 2
	amount_style.border_color = GameConstants.AMOUNT_PANEL_BORDER_COLOR
	amount_style.corner_radius_top_left = 6
	amount_style.corner_radius_top_right = 6
	amount_style.corner_radius_bottom_left = 6
	amount_style.corner_radius_bottom_right = 6
	amount_panel.add_theme_stylebox_override("panel", amount_style)

	# Число (сумма выплаты)
	collected_amount_label.add_theme_font_size_override("font_size", 36)
	collected_amount_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

	# === КНОПКА "ВЫПЛАТИТЬ" (зеленая, яркая) ===
	payout_button.text = "Выплатить"
	payout_button.add_theme_font_size_override("font_size", GameConstants.FONT_SIZE_PAYOUT_BUTTON)

	var payout_style_normal = StyleBoxFlat.new()
	payout_style_normal.bg_color = Color(0.15, 0.6, 0.3)  # Зелёная
	payout_style_normal.border_width_left = 3
	payout_style_normal.border_width_top = 3
	payout_style_normal.border_width_right = 3
	payout_style_normal.border_width_bottom = 3
	payout_style_normal.border_color = Color(0.7, 0.5, 0.2)  # Золотистая рамка
	payout_style_normal.corner_radius_top_left = 8
	payout_style_normal.corner_radius_top_right = 8
	payout_style_normal.corner_radius_bottom_left = 8
	payout_style_normal.corner_radius_bottom_right = 8
	payout_button.add_theme_stylebox_override("normal", payout_style_normal)

	var payout_style_hover = StyleBoxFlat.new()
	payout_style_hover.bg_color = Color(0.2, 0.7, 0.4)
	payout_style_hover.border_width_left = 3
	payout_style_hover.border_width_top = 3
	payout_style_hover.border_width_right = 3
	payout_style_hover.border_width_bottom = 3
	payout_style_hover.border_color = Color(0.8, 0.6, 0.3)
	payout_style_hover.corner_radius_top_left = 8
	payout_style_hover.corner_radius_top_right = 8
	payout_style_hover.corner_radius_bottom_left = 8
	payout_style_hover.corner_radius_bottom_right = 8
	payout_button.add_theme_stylebox_override("hover", payout_style_hover)

	payout_button.add_theme_color_override("font_color", Color(1, 1, 1))

	# === КНОПКА "?" (подсказка) ===
	hint_button.text = "?"
	hint_button.add_theme_font_size_override("font_size", 28)

	var hint_style_normal = StyleBoxFlat.new()
	hint_style_normal.bg_color = Color(0.4, 0.3, 0.6)  # Фиолетовый
	hint_style_normal.border_width_left = 2
	hint_style_normal.border_width_top = 2
	hint_style_normal.border_width_right = 2
	hint_style_normal.border_width_bottom = 2
	hint_style_normal.border_color = Color(0.7, 0.5, 0.2)
	hint_style_normal.corner_radius_top_left = 8
	hint_style_normal.corner_radius_top_right = 8
	hint_style_normal.corner_radius_bottom_left = 8
	hint_style_normal.corner_radius_bottom_right = 8
	hint_button.add_theme_stylebox_override("normal", hint_style_normal)

	var hint_style_hover = StyleBoxFlat.new()
	hint_style_hover.bg_color = Color(0.5, 0.4, 0.7)
	hint_style_hover.border_width_left = 2
	hint_style_hover.border_width_top = 2
	hint_style_hover.border_width_right = 2
	hint_style_hover.border_width_bottom = 2
	hint_style_hover.border_color = Color(0.8, 0.6, 0.3)
	hint_style_hover.corner_radius_top_left = 8
	hint_style_hover.corner_radius_top_right = 8
	hint_style_hover.corner_radius_bottom_left = 8
	hint_style_hover.corner_radius_bottom_right = 8
	hint_button.add_theme_stylebox_override("hover", hint_style_hover)

	hint_button.add_theme_color_override("font_color", Color(1, 1, 1))

	# === ГЛАВНАЯ ПАНЕЛЬ (MainPanel - стопки фишек) ===
	var main_style = StyleBoxFlat.new()
	main_style.bg_color = GameConstants.MAIN_PANEL_BG_COLOR
	main_style.border_width_left = 2
	main_style.border_width_top = 2
	main_style.border_width_right = 2
	main_style.border_width_bottom = 2
	main_style.border_color = GameConstants.MAIN_PANEL_BORDER_COLOR
	main_style.corner_radius_top_left = 8
	main_style.corner_radius_top_right = 8
	main_style.corner_radius_bottom_left = 8
	main_style.corner_radius_bottom_right = 8
	main_panel.add_theme_stylebox_override("panel", main_style)

	# Размеры контейнера стопок
	chip_stacks_container.custom_minimum_size = Vector2(0, 240)  # ← Уменьшили высоту с 280 до 240
	chip_stacks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_stacks_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # ← Выравнивание по верху
	chip_stacks_container.add_theme_constant_override("separation", 5)  # ← Уменьшили с 10 до 5

	# === ПАНЕЛЬ ФЛОТА (FleetPanel - кнопки фишек) ===
	var fleet_style = StyleBoxFlat.new()
	fleet_style.bg_color = GameConstants.FLEET_PANEL_BG_COLOR
	fleet_style.border_width_left = 2
	fleet_style.border_width_top = 2
	fleet_style.border_width_right = 2
	fleet_style.border_width_bottom = 2
	fleet_style.border_color = GameConstants.FLEET_PANEL_BORDER_COLOR
	fleet_style.corner_radius_top_left = 8
	fleet_style.corner_radius_top_right = 8
	fleet_style.corner_radius_bottom_left = 8
	fleet_style.corner_radius_bottom_right = 8
	fleet_panel.add_theme_stylebox_override("panel", fleet_style)

	# Размеры контейнера флота
	chip_fleet_container.add_theme_constant_override("separation", 10)

# ← Создание кнопок для каждого номинала фишки
func _create_chip_buttons():
	# Очищаем контейнер
	for child in chip_fleet_container.get_children():
		child.queue_free()

	for denomination in chip_denominations:
		var button = TextureButton.new()
		button.custom_minimum_size = GameConstants.CHIP_BUTTON_SIZE
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		# Загружаем текстуру фишки
		var denom_str = str(int(denomination)) if denomination >= 1 else str(denomination)
		var chip_path = GameConstants.CHIP_TEXTURE_PATH_TEMPLATE % denom_str
		var texture = load(chip_path)
		if texture:
			button.texture_normal = texture
		else:
			push_warning("PayoutPopupNew: текстура не найдена: %s" % chip_path)

		# Подключаем сигналы
		button.pressed.connect(_on_chip_clicked.bind(denomination))
		button.gui_input.connect(_on_chip_button_input.bind(denomination))

		chip_fleet_container.add_child(button)

# ← Установка заголовка с цветом
func _set_result_header(winner: String):
	match winner:
		"Banker":
			result_label.text = Localization.t("WIN_BANKER")
			result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))  # Красный
		"Player":
			result_label.text = Localization.t("WIN_PLAYER")
			result_label.add_theme_color_override("font_color", Color(0.2, 0.4, 0.9))  # Синий
		"Tie":
			result_label.text = Localization.t("WIN_TIE")
			result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))  # Зелёный
		"PairPlayer":
			result_label.text = Localization.t("PAIR_PLAYER_TITLE")  # "Пара Игрока 11:1"
			result_label.add_theme_color_override("font_color", Color(0.2, 0.4, 0.9))  # Синий (как Player)
		"PairBanker":
			result_label.text = Localization.t("PAIR_BANKER_TITLE")  # "Пара Банкира 11:1"
			result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))  # Красный (как Banker)

# ← Обновить номиналы фишек из GameModeManager
func _update_chip_denominations():
	chip_denominations = GameModeManager.get_chip_denominations()
	print("PayoutPopupNew: Номиналы фишек обновлены: ", chip_denominations)

# ← Форматирование числа
func _update_score_display():
	# Обновляем отображение очков из SaveManager
	# (Survival mode UI теперь в Game.tscn, не здесь)
	score_label.visible = true
	var current_score = SaveManager.instance.score
	score_label.text = "Очки: %d" % current_score

func _format_amount(amount: float) -> String:
	if amount == floor(amount):
		return str(int(amount))
	else:
		return str(amount)

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func _show_success_animation(is_correct: bool, collected: float, expected: float):
	# Показываем локальный overlay внутри сцены
	feedback_container.visible = true
	feedback_label.text = "Верно!"
	feedback_label.add_theme_font_size_override("font_size", GameConstants.FONT_SIZE_RESULT_LABEL * 2)
	feedback_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	feedback_label.add_theme_constant_override("outline_size", 5)

	await get_tree().create_timer(GameConstants.SUCCESS_ANIMATION_DURATION).timeout
	feedback_container.visible = false
	feedback_label.text = ""

	# Возвращаемся к игре с результатом
	_return_to_game(is_correct, collected, expected)

func _show_error_animation(_collected: float):
	is_button_blocked = true
	payout_button.disabled = true

	# ← СРАЗУ очищаем фишки (до показа надписи), чтобы можно было начать вводить новую выплату
	stack_manager.clear_all()

	# Показываем локальный overlay внутри попапа
	feedback_container.visible = true
	feedback_label.text = "Ошибка!"
	feedback_label.add_theme_font_size_override("font_size", GameConstants.FONT_SIZE_RESULT_LABEL * 2)
	feedback_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	feedback_label.add_theme_constant_override("outline_size", 5)

	# Анимация тряски кнопки
	var tween = create_tween()
	var original_pos = payout_button.position
	var shake = GameConstants.SHAKE_OFFSET
	var dur = GameConstants.SHAKE_DURATION
	tween.tween_property(payout_button, "position:x", original_pos.x + shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x - shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x + shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x - shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x, dur)

	await get_tree().create_timer(GameConstants.ERROR_ANIMATION_DURATION).timeout
	is_button_blocked = false
	payout_button.disabled = false
	feedback_container.visible = false
	feedback_label.text = ""

	# НЕ возвращаемся к игре - даём игроку попробовать снова

# ═══════════════════════════════════════════════════════════════════════════
# OVERLAY УПРАВЛЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════

func show_payout(winner: String, stake: float, payout: float):
	"""Показать overlay с параметрами выплаты

	Вызывается из GameController вместо scene transition
	"""
	setup_payout(winner, stake, payout)
	show()  # Показать CanvasLayer

	# Установить фокус на первую кнопку флота
	if chip_fleet_container and chip_fleet_container.get_child_count() > 0:
		var first_chip_button = chip_fleet_container.get_child(0)
		if first_chip_button:
			first_chip_button.grab_focus()

	print("💰 PayoutOverlay показан: %s, stake=%.1f, payout=%.1f" % [winner, stake, payout])


func _return_to_game(is_correct: bool, collected: float, expected: float):
	"""Возврат к игре (overlay режим)

	Эмитит сигнал payout_completed и скрывает overlay
	"""
	# Эмитим сигнал с результатом (включая тип ставки)
	payout_completed.emit(current_winner, is_correct, collected, expected)

	# Скрываем overlay
	hide()

	print("💰 PayoutOverlay скрыт: bet_type=%s, correct=%s, collected=%.1f, expected=%.1f" % [current_winner, is_correct, collected, expected])

# ═══════════════════════════════════════════════════════════════════════════
# КЛАВИАТУРНАЯ НАВИГАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _setup_keyboard_navigation():
	# Добавляем рамку в сцену
	FocusManager.attach_highlight_to_scene(self)

	# Уровень 1 (нижний): Флот фишек
	var level1_elements = []
	for child in chip_fleet_container.get_children():
		if child is TextureButton:
			level1_elements.append(child)

	# Уровень 2: Стопки фишек (будут добавляться динамически)
	var level2_elements = []
	# Проходим по слотам и берем контейнеры стопок (если есть)
	for slot in chip_stacks_container.get_children():
		if slot is VBoxContainer and slot.get_child_count() > 0:
			var stack_container = slot.get_child(0)
			if stack_container is PanelContainer:
				level2_elements.append(stack_container)

	# Уровень 3 (верхний): Выплатить, Подсказка
	var level3_elements = [
		payout_button,
		hint_button
	]

	# Регистрируем уровни (is_payout=true для PayoutScene)
	FocusManager.register_level(1, level1_elements, true)
	FocusManager.register_level(2, level2_elements, true)
	FocusManager.register_level(3, level3_elements, true)

	# Подписываемся на добавление/удаление стопок
	stack_manager.stack_added.connect(_on_stack_added_for_navigation)
	stack_manager.stack_removed.connect(_on_stack_removed_for_navigation)


func _on_stack_added_for_navigation(_stack: ChipStack, _index: int):
	# Обновляем уровень 2 при добавлении стопки
	_update_navigation_level2()


func _on_stack_removed_for_navigation(_stack: ChipStack, _index: int):
	# Обновляем уровень 2 при удалении стопки
	_update_navigation_level2()


func _update_navigation_level2():
	# Обновляем список стопок для навигации
	var level2_elements = []
	# Проходим по слотам (VBoxContainer) и берем контейнеры стопок (PanelContainer)
	for slot in chip_stacks_container.get_children():
		if slot is VBoxContainer and slot.get_child_count() > 0:
			# В каждом слоте может быть стопка (stack.container)
			var stack_container = slot.get_child(0)
			if stack_container is PanelContainer:
				level2_elements.append(stack_container)
	FocusManager.register_level(2, level2_elements, true)
