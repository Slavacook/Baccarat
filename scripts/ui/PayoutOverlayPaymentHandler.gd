# res://scripts/ui/PayoutOverlayPaymentHandler.gd
# Обработчик выплат для PayoutOverlay
# Инкапсулирует логику обработки выплаты, валидации и координации анимаций

extends RefCounted
class_name PayoutOverlayPaymentHandler

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var owner_node: Node  # Узел для создания таймеров
var stack_manager: ChipStackManager  # Менеджер стопок
var validator: PayoutValidator  # Валидатор выплаты
var animation_controller: PayoutAnimationController  # Контроллер анимаций
var payout_button: Button  # Кнопка выплаты

# ═══════════════════════════════════════════════════════════════════════════
# CALLBACK-ИНТЕРФЕЙС (функции, которые должен предоставить владелец)
# ═══════════════════════════════════════════════════════════════════════════

var on_payment_success_callback: Callable  # Вызывается при успешной выплате (is_correct: bool, collected: float, expected: float)
var on_payment_error_callback: Callable  # Вызывается при ошибке выплаты (collected: float)
var is_button_blocked_callback: Callable  # Проверка блокировки кнопки -> bool
var set_button_blocked_callback: Callable  # Установка блокировки кнопки (blocked: bool)

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	owner_node_ref: Node,
	stack_manager_ref: ChipStackManager,
	validator_ref: PayoutValidator,
	animation_controller_ref: PayoutAnimationController,
	payout_button_ref: Button
):
	"""Инициализация обработчика выплат
	
	Args:
		owner_node_ref: Узел для создания таймеров
		stack_manager_ref: Менеджер стопок
		validator_ref: Валидатор выплаты
		animation_controller_ref: Контроллер анимаций
		payout_button_ref: Кнопка выплаты
	"""
	owner_node = owner_node_ref
	stack_manager = stack_manager_ref
	validator = validator_ref
	animation_controller = animation_controller_ref
	payout_button = payout_button_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ОБРАБОТКА ВЫПЛАТЫ
# ═══════════════════════════════════════════════════════════════════════════

func process_payment(expected_payout: float) -> void:
	"""Обработать выплату
	
	Args:
		expected_payout: Ожидаемая выплата
	"""
	# ЗАЩИТА: Блокируем СРАЗУ, до любых вычислений (защита от двойного нажатия)
	var is_blocked = false
	if is_button_blocked_callback.is_valid():
		is_blocked = is_button_blocked_callback.call()
	if is_blocked:
		return
	
	# Блокируем кнопку
	if set_button_blocked_callback.is_valid():
		set_button_blocked_callback.call(true)
	payout_button.disabled = true

	var collected_total: float = stack_manager.get_total()
	var is_correct: bool = validator.validate(collected_total, expected_payout)

	if is_correct:
		# ← Правильная выплата
		await _show_success_animation(is_correct, collected_total, expected_payout)
	else:
		# ← Неправильная выплата
		# ВАЖНО: Эмитим событие ДО анимации, чтобы обновить сердечки
		# В PayoutOverlay нет информации о bet_type/position_index
		EventBus.payout_wrong.emit(collected_total, expected_payout, "", -1)

		# Показываем анимацию ошибки (попап не закрывается)
		await _show_error_animation(collected_total)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ - КООРДИНАЦИЯ АНИМАЦИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _show_success_animation(is_correct: bool, collected: float, expected: float) -> void:
	"""Показать анимацию успеха и вернуться к игре"""
	# Показываем изображение "Верно!"
	animation_controller.show_success_animation()
	
	# Ждем время показа
	await owner_node.get_tree().create_timer(GameConstants.SUCCESS_ANIMATION_DURATION).timeout
	
	# Скрываем изображение
	await animation_controller.hide_success_animation()
	
	# Возвращаемся к игре с результатом
	if on_payment_success_callback.is_valid():
		on_payment_success_callback.call(is_correct, collected, expected)

func _show_error_animation(_collected: float) -> void:
	"""Показать анимацию ошибки и разблокировать кнопку
	
	ВАЖНО: Этот метод НЕ должен менять режим PayButton (COLLECT/PAY).
	Режим должен оставаться в PAY, чтобы игрок мог попробовать снова.
	"""
	# Блокируем кнопку
	if set_button_blocked_callback.is_valid():
		set_button_blocked_callback.call(true)
	payout_button.disabled = true

	# ← СРАЗУ очищаем фишки, чтобы можно было начать вводить новую выплату
	stack_manager.clear_all()

	# Показываем изображение "Ошибка!" и тряску кнопки
	animation_controller.show_error_animation()

	await owner_node.get_tree().create_timer(GameConstants.ERROR_ANIMATION_DURATION).timeout
	
	# Разблокируем кнопку
	if set_button_blocked_callback.is_valid():
		set_button_blocked_callback.call(false)
	payout_button.disabled = false

	# Скрываем изображение
	await animation_controller.hide_error_animation()

	# Вызываем callback для обработки ошибки (если нужен)
	# ВАЖНО: Callback не должен менять режим PayButton
	if on_payment_error_callback.is_valid():
		on_payment_error_callback.call(_collected)

	# НЕ возвращаемся к игре - даём игроку попробовать снова
	# Режим PayButton остается в PAY

