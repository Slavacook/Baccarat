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
var ui_builder: PayoutOverlayUIBuilder          # Построитель UI элементов
var payment_handler: PayoutOverlayPaymentHandler  # Обработчик выплат
var state_manager: PayoutOverlayStateManager    # Менеджер состояния

# ENUM FocusLevel перенесен в PayoutKeyboardNavigator

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

var chip_denominations: Array = []  # Номиналы фишек (из GameModeManager) - управляется через state_manager
var current_stake: float = 0.0      # Текущая ставка
var current_winner: String = ""     # "Player", "Banker", "Tie"
var expected_payout: float = 0.0    # Ожидаемая выплата
var is_button_blocked: bool = false # Блокировка кнопки при ошибке
var hint_purchased: bool = false   # Флаг покупки подсказки (для текущего окна выплат)
# Состояние игры (is_survival_mode, current_lives) управляется через state_manager

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
	
	ui_builder = PayoutOverlayUIBuilder.new(
		chip_fleet_container,
		result_label
	)
	# Настраиваем callbacks для построителя UI
	ui_builder.on_chip_clicked_callback = _on_chip_clicked
	ui_builder.on_chip_button_input_callback = _on_chip_button_input
	
	payment_handler = PayoutOverlayPaymentHandler.new(
		self,  # owner_node
		stack_manager,
		validator,
		animation_controller,
		payout_button
	)
	# Настраиваем callbacks для обработчика выплат
	payment_handler.on_payment_success_callback = _return_to_game
	payment_handler.on_payment_error_callback = func(_collected: float): pass  # Пустой callback, логика уже в _show_error_animation
	payment_handler.is_button_blocked_callback = func(): return is_button_blocked
	payment_handler.set_button_blocked_callback = func(blocked: bool): is_button_blocked = blocked
	
	state_manager = PayoutOverlayStateManager.new(
		self,  # owner_node
		survival_info
	)

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
	EventBus.payout_wrong.connect(state_manager.handle_payout_wrong_event)
	EventBus.life_lost.connect(state_manager.handle_life_lost)

	# Сигналы кнопок
	payout_button.pressed.connect(_on_payout_pressed)
	hint_button.pressed.connect(_on_hint_pressed)

# ← Инициализация данных (номиналы фишек, проверка компонентов)
func _initialize_data():
	"""Инициализация данных и проверка наличия компонентов"""
	# Получаем номиналы фишек
	state_manager.update_chip_denominations()
	chip_denominations = state_manager.chip_denominations  # Синхронизируем с state_manager

	# DEBUG: Проверяем что survival_info существует
	if survival_info:
		DebugLogger.log_init("PayoutOverlay: survival_info найден")
	else:
		push_error("❌ PayoutOverlay: survival_info НЕ НАЙДЕН!")

	# Обновляем отображение очков
	state_manager.update_score_display()

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
	ui_builder.create_chip_buttons(chip_denominations)

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
	
	# Обработка навигации (клавиатура и геймпад через Input Actions)
	var direction: String = ""
	if event.is_action_pressed("left"):
		direction = "left"
	elif event.is_action_pressed("right"):
		direction = "right"
	elif event.is_action_pressed("up"):
		direction = "up"
	elif event.is_action_pressed("down"):
		direction = "down"
	
	if direction != "":
		get_viewport().set_input_as_handled()
		# Используем единый метод для клавиатуры и геймпада
		keyboard_navigator.handle_navigation_direction(direction)
		return
	
	# Обработка действия (Space/A на геймпаде)
	if event.is_action_pressed("action"):
		get_viewport().set_input_as_handled()
		
		# Проверяем состояние навигации
		# ВАЖНО: Проверяем напрямую, без промежуточных переменных, чтобы избежать race condition
		if keyboard_navigator.is_keyboard_active and keyboard_navigator.focus_index >= 0:
			# Есть активная навигация - выполняем действие на элементе в фокусе
			keyboard_navigator.handle_focus_action()
		else:
			# Нет активной навигации - выполняем выплату (поведение по умолчанию)
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
	ui_builder.set_result_header(winner)

	# Ставка рядом с заголовком
	stake_label.text = Localization.t("PAYOUT_STAKE", [PayoutOverlayUIBuilder.format_amount(stake)])

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
		# Проверяем, есть ли стек с таким номиналом перед удалением
		if stack_manager.has_stack(denomination):
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
	collected_amount_label.text = PayoutOverlayUIBuilder.format_amount(new_total)

# ← Обработка нажатия кнопки "Выплатить"
func _on_payout_pressed():
	payment_handler.process_payment(expected_payout)

# ← Обработка кнопки подсказки
func _on_hint_pressed():
	# Если подсказка еще не куплена, проверяем доступность и покупаем
	if not hint_purchased:
		var hint_check: Dictionary = hint_handler.check_availability(state_manager.is_survival_mode, state_manager.current_lives)
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
	
	# Если используется клавиатурная навигация, переводим фокус на кнопку выплаты
	if keyboard_navigator and keyboard_navigator.is_keyboard_active:
		await get_tree().process_frame  # Небольшая задержка для завершения обработки
		keyboard_navigator.set_focus_to_payout_button()

# ← Обработчик изменения режима игры
func _on_mode_changed(_mode: String):
	state_manager.update_chip_denominations()
	chip_denominations = state_manager.chip_denominations  # Синхронизируем с state_manager
	ui_builder.create_chip_buttons(chip_denominations)
	stack_manager.clear_all()
	collected_amount_label.text = "0"

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - НАСТРОЙКА UI
# ═══════════════════════════════════════════════════════════════════════════

# Методы создания UI элементов перенесены в PayoutOverlayUIBuilder

# Методы управления состоянием перенесены в PayoutOverlayStateManager

# Метод форматирования перенесен в PayoutOverlayUIBuilder.format_amount()

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

# Методы координации анимаций перенесены в PayoutOverlayPaymentHandler

# Обработчики событий перенесены в PayoutOverlayStateManager

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
	keyboard_navigator.chip_denominations = state_manager.chip_denominations
	
	# Сохраняем состояние игры (вместо get_parent())
	state_manager.set_survival_state(is_survival, lives)

	setup_payout(winner, stake, payout)

	# Сбрасываем состояние подсказки для нового окна выплат
	hint_purchased = false
	hint_handler.update_button_style(false)  # Красная кнопка (не куплена)
	
	# ВАЖНО: Сбрасываем блокировку кнопки для нового окна
	is_button_blocked = false
	payout_button.disabled = false

	# Обновляем отображение жизней/очков
	state_manager.update_score_display()

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
