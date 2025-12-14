# res://scripts/PayoutOverlay.gd
# Overlay для расчёта выплаты с использованием фишек
# Отображается поверх Game.tscn (CanvasLayer)
# Использует модульную архитектуру: ChipStack, ChipStackManager, PayoutValidator

extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════
# UI ЭЛЕМЕНТЫ (обновленные пути для CanvasLayer → ColorRect → ...)
# ═══════════════════════════════════════════════════════════════════════════

@onready var result_label = $ColorRect/MarginContainer/VBoxContainer/HeaderHBox/ResultLabel
@onready var stake_label = $ColorRect/MarginContainer/VBoxContainer/HeaderHBox/StakeLabel
@onready var amount_panel = $ColorRect/MarginContainer/VBoxContainer/HeaderHBox/AmountPanel
@onready var collected_amount_label = $ColorRect/MarginContainer/VBoxContainer/HeaderHBox/AmountPanel/CollectedAmountLabel
@onready var payout_button: Button = $ColorRect/MarginContainer/VBoxContainer/FleetPanel/FleetMargin/FleetHBox/PayoutButton
@onready var hint_button = $ColorRect/MarginContainer/VBoxContainer/HeaderHBox/HintButton
@onready var survival_info: PayoutSurvivalInfo = $ColorRect/MarginContainer/VBoxContainer/HeaderHBox/PayoutSurvivalInfo
@onready var main_panel = $ColorRect/MarginContainer/VBoxContainer/MainPanel
@onready var chip_stacks_container = $ColorRect/MarginContainer/VBoxContainer/MainPanel/MainMargin/ChipStacksContainer
@onready var fleet_panel = $ColorRect/MarginContainer/VBoxContainer/FleetPanel
@onready var chip_fleet_container = $ColorRect/MarginContainer/VBoxContainer/FleetPanel/FleetMargin/FleetHBox/ChipFleetContainer
# FeedbackContainer и FeedbackLabel для отображения оповещений "Верно!" и "Ошибка!"
@onready var feedback_label = $ColorRect/FeedbackContainer/FeedbackLabel
@onready var feedback_container = $ColorRect/FeedbackContainer
# PNG изображения для оповещений (настроены в редакторе)
@onready var success_image = $ColorRect/SuccessImage
@onready var error_image = $ColorRect/ErrorImage

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
var hint_purchased: bool = false   # Флаг покупки подсказки (для текущего окна выплат)

# ← Состояние игры (передаётся через show_payout(), без get_parent())
var is_survival_mode: bool = false  # Режим выживания
var current_lives: int = 7          # Текущее количество жизней (для survival mode)

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

	# Подписываемся на потерю жизни для обновления сердечек
	EventBus.payout_wrong.connect(_on_payout_wrong_event)
	EventBus.hint_used.connect(_on_hint_used_event)
	EventBus.life_lost.connect(_on_life_lost)

	# Получаем номиналы фишек
	_update_chip_denominations()

	# DEBUG: Проверяем что survival_info существует
	if survival_info:
		DebugLogger.log_init("PayoutOverlay: survival_info найден")
	else:
		push_error("❌ PayoutOverlay: survival_info НЕ НАЙДЕН!")

	# Настройка стилей
	_setup_styles()

	# Скрываем контейнер обратной связи по умолчанию (если есть)
	if feedback_container:
		feedback_container.visible = false
	
	# Скрываем PNG изображения оповещений по умолчанию
	if success_image:
		success_image.visible = false
		success_image.modulate.a = 0.0  # Начинаем с прозрачного
	if error_image:
		error_image.visible = false
		error_image.modulate.a = 0.0  # Начинаем с прозрачного

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

	var collected_total: float = stack_manager.get_total()

	var is_correct: bool = validator.validate(collected_total, expected_payout)

	if is_correct:
		# ← Правильная выплата
		# Показываем анимацию успеха, затем возвращаемся
		await _show_success_animation(is_correct, collected_total, expected_payout)
	else:
		# ← Неправильная выплата
		# ВАЖНО: Эмитим событие ДО анимации, чтобы обновить сердечки
		EventBus.payout_wrong.emit(collected_total, expected_payout)

		# Показываем анимацию ошибки (попап не закрывается)
		_show_error_animation(collected_total)

# ← Обработка кнопки подсказки
func _on_hint_pressed():
	# Если подсказка еще не куплена, проверяем доступность и покупаем
	if not hint_purchased:
		var hint_check: Dictionary = _check_hint_availability()
		if not hint_check.can_use:
			# Показываем сообщение об ошибке внутри окна выплат
			_show_hint_error_message(Localization.t(hint_check.error_key))
			DebugLogger.log("❌ Нельзя использовать подсказку: %s" % hint_check.error_key)
			return
		
		# Покупаем подсказку: отнимаем ресурсы
		EventBus.hint_used.emit()
		
		# Показываем сообщение о покупке подсказки
		_show_hint_success_message()
		
		# Меняем состояние и цвет кнопки
		hint_purchased = true
		_update_hint_button_style(true)  # Зеленая кнопка
	
	# Формируем выплату (покупка уже сделана или была куплена ранее)
	_apply_hint()
	
	DebugLogger.log("💡 Подсказка применена! Ожидаемая выплата: %s" % expected_payout)

# ← Применить подсказку (сформировать выплату)
func _apply_hint():
	"""Применить подсказку - очистить стопки и добавить правильные фишки"""
	# Очищаем текущие стопки
	stack_manager.clear_all()

	# Рассчитываем оптимальное распределение фишек
	var hint: Array = validator.calculate_hint(expected_payout, chip_denominations)

	# Добавляем фишки согласно подсказке
	for item in hint:
		var denomination: float = item["denomination"]
		var count: int = item["count"]

		for i in range(count):
			stack_manager.add_chip(denomination)
	
	# Отправляем сигнал
	hint_used.emit()

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
	var amount_style: StyleBoxFlat = StyleBoxFlat.new()
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

	var payout_style_normal: StyleBoxFlat = StyleBoxFlat.new()
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

	var payout_style_hover: StyleBoxFlat = StyleBoxFlat.new()
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
	
	# Устанавливаем начальный стиль (красная кнопка - не куплена)
	_update_hint_button_style(false)

# ← Обновить стиль кнопки подсказки
func _update_hint_button_style(purchased: bool):
	"""Обновить стиль кнопки подсказки в зависимости от состояния покупки
	
	Args:
		purchased: true если подсказка куплена (зеленая), false если не куплена (красная)
	"""
	if not hint_button:
		return

	var hint_style_normal: StyleBoxFlat = StyleBoxFlat.new()
	var hint_style_hover: StyleBoxFlat = StyleBoxFlat.new()
	
	if purchased:
		# Зеленая кнопка (куплена)
		hint_style_normal.bg_color = Color(0.2, 0.6, 0.3)  # Зелёный
		hint_style_hover.bg_color = Color(0.3, 0.7, 0.4)   # Светло-зелёный
	else:
		# Красная кнопка (не куплена)
		hint_style_normal.bg_color = Color(0.6, 0.2, 0.2)  # Красный
		hint_style_hover.bg_color = Color(0.7, 0.3, 0.3)   # Светло-красный
	
	# Общие настройки для обоих стилей
	hint_style_normal.border_width_left = 2
	hint_style_normal.border_width_top = 2
	hint_style_normal.border_width_right = 2
	hint_style_normal.border_width_bottom = 2
	hint_style_normal.border_color = Color(0.7, 0.5, 0.2)
	hint_style_normal.corner_radius_top_left = 8
	hint_style_normal.corner_radius_top_right = 8
	hint_style_normal.corner_radius_bottom_left = 8
	hint_style_normal.corner_radius_bottom_right = 8
	
	hint_style_hover.border_width_left = 2
	hint_style_hover.border_width_top = 2
	hint_style_hover.border_width_right = 2
	hint_style_hover.border_width_bottom = 2
	hint_style_hover.border_color = Color(0.8, 0.6, 0.3)
	hint_style_hover.corner_radius_top_left = 8
	hint_style_hover.corner_radius_top_right = 8
	hint_style_hover.corner_radius_bottom_left = 8
	hint_style_hover.corner_radius_bottom_right = 8
	
	hint_button.add_theme_stylebox_override("normal", hint_style_normal)
	hint_button.add_theme_stylebox_override("hover", hint_style_hover)
	hint_button.add_theme_color_override("font_color", Color(1, 1, 1))

	# === ГЛАВНАЯ ПАНЕЛЬ (MainPanel - стопки фишек) ===
	var main_style: StyleBoxFlat = StyleBoxFlat.new()
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
	var fleet_style: StyleBoxFlat = StyleBoxFlat.new()
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
		var button: TextureButton = TextureButton.new()
		button.custom_minimum_size = GameConstants.CHIP_BUTTON_SIZE
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		# Загружаем текстуру фишки
		var denom_str: String = str(int(denomination)) if denomination >= 1 else str(denomination)
		var chip_path: String = GameConstants.CHIP_TEXTURE_PATH_TEMPLATE % denom_str
		var texture: Texture2D = load(chip_path)
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
			result_label.text = Localization.t("PAIR_PLAYER_TITLE")  # "Пара Игрока"
			result_label.add_theme_color_override("font_color", Color(0.2, 0.4, 0.9))  # Синий (как Player)
		"PairBanker":
			result_label.text = Localization.t("PAIR_BANKER_TITLE")  # "Пара Банкира"
			result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))  # Красный (как Banker)

# ← Обновить номиналы фишек из GameModeManager
func _update_chip_denominations():
	chip_denominations = GameModeManager.get_chip_denominations()
	DebugLogger.log("PayoutPopupNew: Номиналы фишек обновлены: %s" % [chip_denominations])

# ← Обновление отображения survival info (жизни или очки)
func _update_score_display():
	"""Обновить отображение жизней (survival mode) или очков (normal mode)"""
	DebugLogger.log("🔍 DEBUG: _update_score_display() вызван")

	if not survival_info:
		push_error("❌ survival_info == null!")
		return

	DebugLogger.log("🔍 DEBUG: survival_info существует")

	# Используем сохранённые переменные вместо get_parent()
	var current_score: int = SaveManager.instance.score
	DebugLogger.log("🔍 DEBUG: вызываем survival_info.update_display(%s, %d, %d)" % [is_survival_mode, current_lives, current_score])

	# Обновляем компонент
	survival_info.update_display(is_survival_mode, current_lives, current_score)

	DebugLogger.log("✅ PayoutSurvivalInfo обновлен: survival=%s, lives=%d, score=%d" % [is_survival_mode, current_lives, current_score])

func _format_amount(amount: float) -> String:
	if amount == floor(amount):
		return str(int(amount))
	else:
		return str(amount)

# ← Показать сообщение об ошибке подсказки
func _show_hint_error_message(message: String):
	"""Показать сообщение об ошибке при попытке использовать подсказку"""
	_show_feedback_message(message, Color(0.9, 0.2, 0.2), 2.0)

# ← Показать сообщение об успешном использовании подсказки
func _show_hint_success_message():
	"""Показать сообщение об успешном использовании подсказки"""
	# Используем сохранённую переменную вместо get_parent()
	var message: String

	if is_survival_mode:
		# Режим выживания: показываем "-1 Сердце"
		message = Localization.t("HINT_USED_HEART")
	else:
		# Обычный режим: показываем стоимость подсказки
		message = Localization.t("HINT_USED_SCORE", [GameConstants.HINT_COST_SCORE])

	# Показываем сообщение зеленым цветом
	_show_feedback_message(message, Color(0.2, 0.9, 0.2), 2.0)

# ← Универсальная функция для показа красивого сообщения
func _show_feedback_message(message: String, color: Color, duration: float = 2.0):
	"""Показать красивое сообщение с анимацией
	
	Args:
		message: Текст сообщения
		color: Цвет текста
		duration: Длительность показа в секундах
	"""
	if not feedback_container or not feedback_label:
		# Fallback на overlay-уведомление
		if OverlayNotificationManager:
			if color == Color(0.9, 0.2, 0.2):  # Красный = ошибка
				OverlayNotificationManager.show_error(message, duration)
			else:  # Зелёный = успех
				OverlayNotificationManager.show_success(message, duration)
		return
	
	# Настраиваем стиль сообщения
	feedback_label.text = message
	feedback_label.add_theme_font_size_override("font_size", 42)  # Увеличиваем в 1.5 раза (28 * 1.5)
	feedback_label.add_theme_color_override("font_color", color)
	feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	feedback_label.add_theme_constant_override("outline_size", 6)
	
	# Настраиваем позицию контейнера
	# Начальная позиция: ниже (будет двигаться вверх)
	var start_y: float = -100.0
	var end_y: float = -180.0  # Конечная позиция выше
	
	# Начальное состояние: резко появляется (сразу видимая) и в начальной позиции
	feedback_container.modulate.a = 1.0  # Резко появляется, без fade in
	feedback_container.position.y = start_y
	
	# Показываем контейнер
	feedback_container.visible = true

	# Создаём плавную анимацию (вся анимация 1 секунда)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	
	# Движение вверх на протяжении всей анимации (1 сек)
	tween.tween_property(feedback_container, "position:y", end_y, 1.0).from(start_y)
	
	# Fade out: начинается с 0.0 сек, длится до 0.9 сек (0.9 секунды)
	tween.tween_property(feedback_container, "modulate:a", 0.0, 0.9).from(1.0)
	
	# Скрываем после анимации
	tween.set_parallel(false)
	tween.tween_callback(func():
		if is_instance_valid(feedback_container):
			feedback_container.visible = false
			feedback_label.text = ""
	)

# ← Проверка доступности подсказки
func _check_hint_availability() -> Dictionary:
	"""Проверяет, можно ли использовать подсказку

	Возвращает словарь с полями:
	- can_use: bool - можно ли использовать
	- error_key: String - ключ сообщения об ошибке (если can_use = false)

	В режиме выживания: нужно минимум MIN_LIVES_FOR_HINT жизней
	В обычном режиме: нужно минимум HINT_COST_SCORE очков
	"""
	# Используем сохранённые переменные вместо get_parent()
	if is_survival_mode:
		# Режим выживания: проверяем жизни
		# Нужно минимум MIN_LIVES_FOR_HINT жизней (1 для использования, 1 чтобы не было геймовера)
		if current_lives < GameConstants.MIN_LIVES_FOR_HINT:
			return {"can_use": false, "error_key": "ERR_HINT_NO_HEARTS"}
		return {"can_use": true, "error_key": ""}
	else:
		# Обычный режим: проверяем очки
		var score: int = SaveManager.instance.score
		# Нужно минимум HINT_COST_SCORE очков
		if score < GameConstants.HINT_COST_SCORE:
			return {"can_use": false, "error_key": "ERR_HINT_NO_SCORE"}
		return {"can_use": true, "error_key": ""}

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func _show_success_animation(is_correct: bool, collected: float, expected: float):
	# Показываем изображение "Верно!"
	_show_success_image()
	
	# Ждем время показа
	await get_tree().create_timer(GameConstants.SUCCESS_ANIMATION_DURATION).timeout
	
	# Скрываем изображение
	_hide_success_image()
	
	# Возвращаемся к игре с результатом
	_return_to_game(is_correct, collected, expected)

func _show_error_animation(_collected: float):
	is_button_blocked = true
	payout_button.disabled = true

	# ← СРАЗУ очищаем фишки, чтобы можно было начать вводить новую выплату
	stack_manager.clear_all()

	# Показываем изображение "Ошибка!"
	_show_error_image()

	# Анимация тряски кнопки
	var tween: Tween = create_tween()
	var original_pos: Vector2 = payout_button.position
	var shake: float = GameConstants.SHAKE_OFFSET
	var dur: float = GameConstants.SHAKE_DURATION
	tween.tween_property(payout_button, "position:x", original_pos.x + shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x - shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x + shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x - shake, dur)
	tween.tween_property(payout_button, "position:x", original_pos.x, dur)

	await get_tree().create_timer(GameConstants.ERROR_ANIMATION_DURATION).timeout
	is_button_blocked = false
	payout_button.disabled = false

	# Скрываем изображение
	_hide_error_image()

	# НЕ возвращаемся к игре - даём игроку попробовать снова

# ═══════════════════════════════════════════════════════════════════════════
# ПОКАЗ/СКРЫТИЕ PNG ИЗОБРАЖЕНИЙ ОПОВЕЩЕНИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _show_success_image():
	"""Показать изображение 'Верно!' с анимацией fade in"""
	if not success_image:
		return
	
	# Сбрасываем состояние перед показом
	success_image.modulate = Color(1, 1, 1, 0.0)  # Начинаем с прозрачного
	success_image.visible = true
	
	# Анимация fade in (без зума)
	var tween: Tween = create_tween()
	tween.tween_property(success_image, "modulate:a", 1.0, 0.3)

func _hide_success_image():
	"""Скрыть изображение 'Верно!' с анимацией fade out и движением вверх"""
	if not success_image:
		return
	
	# Сохраняем оригинальную позицию
	var original_position: Vector2 = success_image.position

	# Анимация fade out с движением вверх
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(success_image, "modulate:a", 0.0, 0.2)
	tween.tween_property(success_image, "position:y", original_position.y - 30.0, 0.2)
	await tween.finished
	
	# Возвращаем позицию на место
	success_image.position = original_position
	success_image.visible = false

func _show_error_image():
	"""Показать изображение 'Ошибка!' с анимацией fade in"""
	if not error_image:
		return
	
	# Сбрасываем состояние перед показом
	error_image.modulate = Color(1, 1, 1, 0.0)  # Начинаем с прозрачного
	error_image.visible = true
	
	# Анимация fade in (без зума)
	var tween: Tween = create_tween()
	tween.tween_property(error_image, "modulate:a", 1.0, 0.3)

func _hide_error_image():
	"""Скрыть изображение 'Ошибка!' с анимацией fade out и движением вверх"""
	if not error_image:
		return
	
	# Сохраняем оригинальную позицию
	var original_position: Vector2 = error_image.position

	# Анимация fade out с движением вверх
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(error_image, "modulate:a", 0.0, 0.2)
	tween.tween_property(error_image, "position:y", original_position.y - 30.0, 0.2)
	await tween.finished
	
	# Возвращаем позицию на место
	error_image.position = original_position
	error_image.visible = false

func _on_payout_wrong_event(_collected: float, _expected: float):
	"""Обработчик события неправильной выплаты

	Вызывается когда EventBus.payout_wrong эмитится.
	Обновляем отображение сердечек после потери жизни.
	"""
	DebugLogger.log("🔔 DEBUG: _on_payout_wrong_event вызван! collected=%.1f, expected=%.1f" % [_collected, _expected])

	# Небольшая задержка чтобы SurvivalUI/StatsManager успел обновить жизни/очки
	await get_tree().create_timer(0.1).timeout
	DebugLogger.log("🔍 DEBUG: Прошло 0.1 сек, вызываем _update_score_display()")

	# Обновляем отображение сердечек/очков
	_update_score_display()

	DebugLogger.log_init("PayoutOverlay: сердечки обновлены после потери жизни")

func _on_hint_used_event():
	"""Обработчик события использования подсказки

	Вызывается когда EventBus.hint_used эмитится.
	Обновляем отображение сердечек после потери жизни за подсказку.
	"""
	DebugLogger.log("💡 DEBUG: _on_hint_used_event вызван!")

	# Небольшая задержка чтобы SurvivalUI/StatsManager успел обновить жизни/очки
	await get_tree().create_timer(0.1).timeout
	DebugLogger.log("🔍 DEBUG: Прошло 0.1 сек, вызываем _update_score_display()")

	# Обновляем отображение сердечек/очков
	_update_score_display()

	DebugLogger.log_init("PayoutOverlay: сердечки обновлены после использования подсказки")

func _on_life_lost(remaining_lives: int):
	"""Обработчик события потери жизни

	Вызывается когда EventBus.life_lost эмитится.
	Обновляем локальную переменную current_lives и отображение.

	Args:
		remaining_lives: Оставшееся количество жизней
	"""
	DebugLogger.log("💔 DEBUG: _on_life_lost вызван! remaining_lives=%d" % remaining_lives)

	# Обновляем локальную переменную
	current_lives = remaining_lives

	# Обновляем отображение
	_update_score_display()

	DebugLogger.log_init("PayoutOverlay: current_lives обновлён до %d" % current_lives)

# ═══════════════════════════════════════════════════════════════════════════
# OVERLAY УПРАВЛЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════

func show_payout(winner: String, stake: float, payout: float, is_survival: bool, lives: int):
	"""Показать overlay с параметрами выплаты

	Вызывается из GameController вместо scene transition

	Args:
		winner: Победитель ("Player"/"Banker"/"Tie"/"PairPlayer"/"PairBanker")
		stake: Размер ставки
		payout: Ожидаемая выплата
		is_survival: Режим выживания активен
		lives: Текущее количество жизней (для survival mode)
	"""
	# Сохраняем состояние игры (вместо get_parent())
	is_survival_mode = is_survival
	current_lives = lives

	setup_payout(winner, stake, payout)

	# Сбрасываем состояние подсказки для нового окна выплат
	hint_purchased = false
	_update_hint_button_style(false)  # Красная кнопка (не куплена)

	# Обновляем отображение жизней/очков
	_update_score_display()

	show()  # Показать CanvasLayer

	# Установить фокус на первую кнопку флота
	if chip_fleet_container and chip_fleet_container.get_child_count() > 0:
		var first_chip_button = chip_fleet_container.get_child(0)
		if first_chip_button:
			first_chip_button.grab_focus()

	DebugLogger.log("💰 PayoutOverlay показан: %s, stake=%.1f, payout=%.1f" % [winner, stake, payout])


func _return_to_game(is_correct: bool, collected: float, expected: float):
	"""Возврат к игре (overlay режим)

	Эмитит сигнал payout_completed и скрывает overlay
	ВАЖНО: Вызывается ПОСЛЕ того, как все анимации оповещений завершены
	"""
	# ВАЖНО: Убеждаемся, что FeedbackContainer уже скрыт перед эмитом сигнала
	if feedback_container:
		feedback_container.visible = false
	
	# Эмитим сигнал с результатом (включая тип ставки)
	payout_completed.emit(current_winner, is_correct, collected, expected)

	# Небольшая задержка перед скрытием overlay, чтобы убедиться, что все анимации завершены
	await get_tree().process_frame
	await get_tree().process_frame  # Дополнительный кадр для гарантии
	
	# Скрываем overlay
	hide()

	DebugLogger.log("💰 PayoutOverlay скрыт: bet_type=%s, correct=%s, collected=%.1f, expected=%.1f" % [current_winner, is_correct, collected, expected])

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
