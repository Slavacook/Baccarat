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

var stack_manager: ChipStackManager             # Управление стопками фишек
var validator: PayoutValidator                  # Валидация выплаты
var style_manager: PayoutOverlayStyleManager    # Управление стилями UI
var animation_controller: PayoutAnimationController  # Управление анимациями
var hint_handler: PayoutHintHandler             # Обработка подсказок
var keyboard_navigator: PayoutKeyboardNavigator # Клавиатурная навигация

# ENUM FocusLevel перенесен в PayoutKeyboardNavigator

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
	# Инициализация по шагам (Template Method pattern)
	_initialize_modules()
	_connect_signals()
	_initialize_data()
	_setup_ui()
	_initialize_subcomponents()

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ ИНИЦИАЛИЗАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

# ← Инициализация модулей (ChipStackManager, PayoutValidator, StyleManager, AnimationController, HintHandler)
func _initialize_modules():
	"""Создание и инициализация основных модулей"""
	stack_manager = ChipStackManager.new(chip_stacks_container)
	validator = PayoutValidator.new()
	style_manager = PayoutOverlayStyleManager.new(
		result_label,
		stake_label,
		amount_panel,
		collected_amount_label,
		payout_button,
		hint_button,
		main_panel,
		chip_stacks_container,
		fleet_panel,
		chip_fleet_container
	)
	animation_controller = PayoutAnimationController.new(
		self,  # owner_node для создания Tween
		success_image,
		error_image,
		payout_button
	)
	hint_handler = PayoutHintHandler.new(
		stack_manager,
		validator,
		style_manager
	)
	keyboard_navigator = PayoutKeyboardNavigator.new(
		self,  # owner_node
		chip_denominations,
		chip_fleet_container,
		payout_button,
		hint_button,
		stack_manager
	)
	# Настраиваем callbacks для навигатора
	keyboard_navigator.on_payout_pressed_callback = _on_payout_pressed
	keyboard_navigator.on_hint_pressed_callback = _on_hint_pressed
	keyboard_navigator.on_chip_added_callback = _on_chip_added_by_keyboard  # Отдельный метод без сброса фокуса
	keyboard_navigator.is_button_blocked_callback = func(): return is_button_blocked

# ← Подключение сигналов (от модулей, EventBus, кнопок)
func _connect_signals():
	"""Подключение всех сигналов"""
	# Сигналы от модулей
	stack_manager.total_changed.connect(_on_total_changed)
	stack_manager.stack_added.connect(_on_stack_added)
	GameModeManager.mode_changed.connect(_on_mode_changed)

	# Сигналы от EventBus
	# HeartBar - единственный источник истины для жизней
	# Все обновления идут через EventBus.life_lost
	EventBus.payout_wrong.connect(_on_payout_wrong_event)
	EventBus.life_lost.connect(_on_life_lost)

	# Сигналы кнопок
	payout_button.pressed.connect(_on_payout_pressed)
	hint_button.pressed.connect(_on_hint_pressed)

# ← Инициализация данных (номиналы фишек, проверка компонентов)
func _initialize_data():
	"""Инициализация данных и проверка наличия компонентов"""
	# Получаем номиналы фишек
	_update_chip_denominations()

	# DEBUG: Проверяем что survival_info существует
	if survival_info:
		DebugLogger.log_init("PayoutOverlay: survival_info найден")
	else:
		push_error("❌ PayoutOverlay: survival_info НЕ НАЙДЕН!")

	# Обновляем отображение очков
	_update_score_display()

# ← Настройка UI (стили, видимость, создание элементов)
func _setup_ui():
	"""Настройка интерфейса: стили, видимость элементов, создание кнопок"""
	# Настройка стилей через StyleManager
	style_manager.setup_all_styles()

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

	# Данные передаются через show_payout() из GameController
	# (НЕ загружаем из GameDataManager - overlay режим)

# ← Инициализация подсистем (клавиатурная навигация, обработчики мыши)
func _initialize_subcomponents():
	"""Инициализация подсистем: навигация, обработчики мыши"""
	# Инициализируем систему навигации
	keyboard_navigator.initialize()
	
	# Подключаем обработчики мыши для сброса фокуса
	keyboard_navigator.connect_mouse_handlers()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА КЛАВИАТУРЫ
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# Проверяем контекст (работаем только в контексте PAYOUT)
	if not InputContextManager.can_handle(InputContextManager.InputContext.PAYOUT):
		return
	
	# Обрабатываем только когда overlay видим
	if not visible:
		return
	
	if not InputContextManager.is_valid_key_event(event):
		return
	
	var key_event = event as InputEventKey
	
	# Обработка клавиш навигации
	if key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]:
		keyboard_navigator.handle_navigation_input(key_event)
		get_viewport().set_input_as_handled()
		return
	
	# Обработка пробела
	if key_event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		
		# Проверяем состояние навигации
		# ВАЖНО: Проверяем напрямую, без промежуточных переменных, чтобы избежать race condition
		if keyboard_navigator.is_keyboard_active and keyboard_navigator.focus_index >= 0:
			# Есть активная навигация - выполняем действие на элементе в фокусе
			print("⌨️ PayoutOverlay: Пробел при активной навигации (active=%s, index=%d)" % [keyboard_navigator.is_keyboard_active, keyboard_navigator.focus_index])
			keyboard_navigator.handle_focus_action()
		else:
			# Нет активной навигации - выполняем выплату (поведение по умолчанию)
			print("⌨️ PayoutOverlay: Пробел без активной навигации - выполняем выплату")
			if not is_button_blocked and not payout_button.disabled:
				_on_payout_pressed()

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

# ← Обработка клика на номинал фишки (добавление через мышь)
func _on_chip_clicked(denomination: float):
	# Сбрасываем клавиатурную навигацию при клике мышью
	keyboard_navigator.clear_focus()
	stack_manager.add_chip(denomination)

# ← Обработка добавления фишки через клавиатуру (без сброса фокуса)
func _on_chip_added_by_keyboard(denomination: float):
	# НЕ сбрасываем фокус - продолжаем навигацию
	stack_manager.add_chip(denomination)

# ← Обработка правого клика по кнопке фишки (удаление)
func _on_chip_button_input(event: InputEvent, denomination: float):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Сбрасываем клавиатурную навигацию при клике мышью
		keyboard_navigator.clear_focus()
		stack_manager.remove_chip(denomination)

# ← Обработчик добавления новой стопки (подключаем обработчик кликов)
func _on_stack_added(stack: ChipStack, _index: int):
	# Подключаем обработчик кликов к контейнеру стопки
	stack.container.gui_input.connect(_on_stack_clicked.bind(stack))

# ← Обработка клика на стопку (удаление из последнего стека)
func _on_stack_clicked(event: InputEvent, stack: ChipStack):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Сбрасываем клавиатурную навигацию при клике мышью
		keyboard_navigator.clear_focus()
		stack_manager.remove_chip(stack.denomination)

# ← Обновление суммы при изменении стопок
func _on_total_changed(new_total: float):
	collected_amount_label.text = _format_amount(new_total)

# ← Обработка нажатия кнопки "Выплатить"
func _on_payout_pressed():
	# ЗАЩИТА: Блокируем СРАЗУ, до любых вычислений (защита от двойного нажатия)
	if is_button_blocked:
		return
	
	is_button_blocked = true
	payout_button.disabled = true

	var collected_total: float = stack_manager.get_total()
	var is_correct: bool = validator.validate(collected_total, expected_payout)

	if is_correct:
		# ← Правильная выплата
		# Показываем анимацию успеха, затем возвращаемся
		await _show_success_animation(is_correct, collected_total, expected_payout)
	else:
		# ← Неправильная выплата
		# ВАЖНО: Эмитим событие ДО анимации, чтобы обновить сердечки
		# В PayoutOverlay нет информации о bet_type/position_index
		EventBus.payout_wrong.emit(collected_total, expected_payout, "", -1)

		# Показываем анимацию ошибки (попап не закрывается)
		# После анимации ошибки блокировка снимется внутри _show_error_animation
		_show_error_animation(collected_total)

# ← Обработка кнопки подсказки
func _on_hint_pressed():
	# Если подсказка еще не куплена, проверяем доступность и покупаем
	if not hint_purchased:
		var hint_check: Dictionary = hint_handler.check_availability(is_survival_mode, current_lives)
		if not hint_check.can_use:
			# Показываем сообщение об ошибке
			hint_handler.show_error_message(hint_check.error_key)
			DebugLogger.log("❌ Нельзя использовать подсказку: %s" % hint_check.error_key)
			return
		
		# Покупаем подсказку: отнимаем ресурсы
		hint_handler.purchase_hint()
		# Оповещение о потере сердца показывается автоматически через FeedbackAnimationManager._on_life_lost()
		# поэтому здесь не показываем сообщение
		
		# Меняем состояние и цвет кнопки
		hint_purchased = true
		hint_handler.update_button_style(true)  # Зеленая кнопка
	
	# Формируем выплату (покупка уже сделана или была куплена ранее)
	hint_handler.apply_hint(expected_payout, chip_denominations)
	
	# Отправляем сигнал
	hint_used.emit()
	
	DebugLogger.log("💡 Подсказка применена! Ожидаемая выплата: %s" % expected_payout)

# ← Обработчик изменения режима игры
func _on_mode_changed(_mode: String):
	_update_chip_denominations()
	_create_chip_buttons()
	stack_manager.clear_all()
	collected_amount_label.text = "0"

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - НАСТРОЙКА UI
# ═══════════════════════════════════════════════════════════════════════════

# ← Создание кнопок для каждого номинала фишки
func _create_chip_buttons():
	# Очищаем контейнер
	for child in chip_fleet_container.get_children():
		child.queue_free()

	for denomination in chip_denominations:
		var button: TextureButton = TextureButton.new()
		button.custom_minimum_size = GameConstants.CHIP_BUTTON_SIZE
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.focus_mode = Control.FOCUS_NONE  # Не получает фокус (Space не активирует)

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

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

func _show_success_animation(is_correct: bool, collected: float, expected: float):
	# Показываем изображение "Верно!"
	animation_controller.show_success_animation()
	
	# Ждем время показа
	await get_tree().create_timer(GameConstants.SUCCESS_ANIMATION_DURATION).timeout
	
	# Скрываем изображение
	await animation_controller.hide_success_animation()
	
	# Возвращаемся к игре с результатом
	_return_to_game(is_correct, collected, expected)

func _show_error_animation(_collected: float):
	is_button_blocked = true
	payout_button.disabled = true

	# ← СРАЗУ очищаем фишки, чтобы можно было начать вводить новую выплату
	stack_manager.clear_all()

	# Показываем изображение "Ошибка!" и тряску кнопки
	animation_controller.show_error_animation()

	await get_tree().create_timer(GameConstants.ERROR_ANIMATION_DURATION).timeout
	is_button_blocked = false
	payout_button.disabled = false

	# Скрываем изображение
	await animation_controller.hide_error_animation()

	# НЕ возвращаемся к игре - даём игроку попробовать снова

func _on_payout_wrong_event(_collected: float, _expected: float, _bet_type: String, _position_index: int):
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
	# Устанавливаем контекст выплат
	InputContextManager.set_context(InputContextManager.InputContext.PAYOUT)
	
	# Сбрасываем клавиатурную навигацию при открытии окна
	keyboard_navigator.clear_focus()
	
	# Обновляем номиналы в навигаторе (могут измениться)
	keyboard_navigator.chip_denominations = chip_denominations
	
	# Сохраняем состояние игры (вместо get_parent())
	is_survival_mode = is_survival
	current_lives = lives

	setup_payout(winner, stake, payout)

	# Сбрасываем состояние подсказки для нового окна выплат
	hint_purchased = false
	hint_handler.update_button_style(false)  # Красная кнопка (не куплена)
	
	# ВАЖНО: Сбрасываем блокировку кнопки для нового окна
	is_button_blocked = false
	payout_button.disabled = false

	# Обновляем отображение жизней/очков
	_update_score_display()

	show()  # Показать CanvasLayer

	# Установить фокус на первую кнопку флота
	if chip_fleet_container and chip_fleet_container.get_child_count() > 0:
		var first_chip_button = chip_fleet_container.get_child(0)
		if first_chip_button and first_chip_button.focus_mode != Control.FOCUS_NONE:
			first_chip_button.grab_focus()

	DebugLogger.log("💰 PayoutOverlay показан: %s, stake=%.1f, payout=%.1f" % [winner, stake, payout])


func _return_to_game(is_correct: bool, collected: float, expected: float):
	"""Возврат к игре (overlay режим)

	Эмитит сигнал payout_completed и скрывает overlay
	ВАЖНО: Вызывается ПОСЛЕ того, как все анимации оповещений завершены
	"""
	# Возвращаем контекст игры
	InputContextManager.set_context(InputContextManager.InputContext.GAME)
	
	# Сбрасываем фокус чтобы следующий Space не активировал последнюю кнопку
	if get_viewport():
		get_viewport().gui_release_focus()
	
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
	
	# Сбрасываем клавиатурную навигацию при закрытии
	keyboard_navigator.clear_focus()

	DebugLogger.log("💰 PayoutOverlay скрыт: bet_type=%s, correct=%s, collected=%.1f, expected=%.1f" % [current_winner, is_correct, collected, expected])

# Клавиатурная навигация теперь управляется через keyboard_navigator
