# res://scripts/payout/PayoutHintHandler.gd
# Обработчик подсказок для PayoutOverlay
# Ответственность: проверка доступности, применение подсказки, сообщения

class_name PayoutHintHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются извне через методы)
# ═══════════════════════════════════════════════════════════════════════════

var stack_manager: ChipStackManager
var validator: PayoutValidator
var style_manager: PayoutOverlayStyleManager

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	stack_manager_ref: ChipStackManager,
	validator_ref: PayoutValidator,
	style_manager_ref: PayoutOverlayStyleManager
):
	"""Инициализация обработчика подсказок
	
	Args:
		stack_manager_ref: Менеджер стопок фишек
		validator_ref: Валидатор выплат (для расчета подсказки)
		style_manager_ref: Менеджер стилей (для обновления кнопки)
	"""
	stack_manager = stack_manager_ref
	validator = validator_ref
	style_manager = style_manager_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func check_availability(is_survival_mode: bool, current_lives: int) -> Dictionary:
	"""Проверяет, можно ли использовать подсказку
	
	Args:
		is_survival_mode: Режим выживания активен
		current_lives: Текущее количество жизней (для survival mode)
	
	Returns:
		Dictionary с полями:
		- can_use: bool - можно ли использовать
		- error_key: String - ключ сообщения об ошибке (если can_use = false)
	
	В режиме выживания: нужно минимум MIN_LIVES_FOR_HINT жизней
	В обычном режиме: нужно минимум HINT_COST_SCORE очков
	"""
	if is_survival_mode:
		# Режим выживания: проверяем жизни
		# Нужно минимум MIN_LIVES_FOR_HINT жизней (1 для использования, 1 чтобы не было геймовера)
		if current_lives < GameConstants.MIN_LIVES_FOR_HINT:
			return {"can_use": false, "error_key": "ERR_HINT_NO_HEARTS"}
		return {"can_use": true, "error_key": ""}
	else:
		# Обычный режим: проверяем очки
		var score: int = SaveManager.instance.score
		# Нужно минимум 6 очков (меньше 6 = недоступна, при 5 очках = геймовер)
		if score < 6:
			return {"can_use": false, "error_key": "ERR_HINT_NO_SCORE"}
		return {"can_use": true, "error_key": ""}

func apply_hint(expected_payout: float, chip_denominations: Array) -> void:
	"""Применить подсказку - очистить стопки и добавить правильные фишки
	
	Args:
		expected_payout: Ожидаемая выплата
		chip_denominations: Массив номиналов фишек
	"""
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

func purchase_hint() -> void:
	"""Покупает подсказку (отнимает ресурсы через EventBus)"""
	EventBus.hint_used.emit()

func update_button_style(purchased: bool) -> void:
	"""Обновить стиль кнопки подсказки
	
	Args:
		purchased: true если подсказка куплена (зеленая), false если не куплена (красная)
	"""
	style_manager.update_hint_button_style(purchased)

func show_error_message(error_key: String) -> void:
	"""Показать сообщение об ошибке при попытке использовать подсказку
	
	Args:
		error_key: Ключ сообщения для локализации
	"""
	var message = Localization.t(error_key)
	_show_feedback_message(message, Color(0.9, 0.2, 0.2), 2.0)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _show_feedback_message(message: String, color: Color, duration: float = 2.0):
	"""Показать красивое сообщение с анимацией (использует FeedbackAnimationManager)
	
	Args:
		message: Текст сообщения
		color: Цвет текста
		duration: Длительность показа в секундах
	"""
	# Используем новый FeedbackAnimationManager для всех оповещений
	if FeedbackAnimationManager:
		FeedbackAnimationManager.show_feedback(message, color, duration)
	else:
		# Fallback на overlay-уведомление
		if OverlayNotificationManager:
			if color == Color(0.9, 0.2, 0.2):  # Красный = ошибка
				OverlayNotificationManager.show_error(message, duration)
			else:  # Зелёный = успех
				OverlayNotificationManager.show_success(message, duration)

