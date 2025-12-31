# res://scripts/autoload/InputContextManager.gd
# Централизованный менеджер контекстов и блокировок ввода
# Управляет тем, какой контекст активен и какие блокировки применены
#
# AUTOLOAD: добавляется в project.godot

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ENUM: Контексты ввода
# ═══════════════════════════════════════════════════════════════════════════

enum InputContext {
	GAME,           # Основная игра
	MENU_GUEST,     # Меню гостей
	MENU_SETTINGS,  # Меню настроек
	PAYOUT,         # Фаза выплат
	GAME_OVER,      # Game Over
	CHANCE_CARD,    # Карта шанса открыта
	CHANCE_CARDS_NAV  # Навигация по картам шансов
}

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Текущий активный контекст
var current_context: InputContext = InputContext.GAME

## Блокировка ввода (настройки открыты)
var settings_blocked: bool = false

## Глобальная блокировка ввода (для критических операций)
var global_blocked: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Подписываемся на события блокировок через EventBus
	if EventBus:
		EventBus.settings_opened.connect(_on_settings_opened)
		EventBus.settings_closed.connect(_on_settings_closed)
	
	print("🎮 InputContextManager инициализирован (контекст: GAME)")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КОНТЕКСТОМ
# ═══════════════════════════════════════════════════════════════════════════

func set_context(context: InputContext) -> void:
	"""Установить активный контекст ввода"""
	if current_context == context:
		return
	
	var old_context = current_context
	current_context = context
	
	var context_name = _get_context_name(context)
	print("🎮 Контекст изменён: %s → %s" % [_get_context_name(old_context), context_name])

func get_context() -> InputContext:
	"""Получить текущий контекст"""
	return current_context

func _get_context_name(context: InputContext) -> String:
	"""Получить строковое имя контекста"""
	match context:
		InputContext.GAME:
			return "GAME"
		InputContext.MENU_GUEST:
			return "MENU_GUEST"
		InputContext.MENU_SETTINGS:
			return "MENU_SETTINGS"
		InputContext.PAYOUT:
			return "PAYOUT"
		InputContext.GAME_OVER:
			return "GAME_OVER"
		InputContext.CHANCE_CARD:
			return "CHANCE_CARD"
		InputContext.CHANCE_CARDS_NAV:
			return "CHANCE_CARDS_NAV"
		_:
			return "UNKNOWN"

# ═══════════════════════════════════════════════════════════════════════════
# БЛОКИРОВКИ
# ═══════════════════════════════════════════════════════════════════════════

func is_blocked() -> bool:
	"""Проверить, заблокирован ли ввод"""
	return settings_blocked or global_blocked

func set_global_block(blocked: bool) -> void:
	"""Установить глобальную блокировку (для критических операций)"""
	global_blocked = blocked
	if blocked:
		print("🎮 Глобальная блокировка ввода АКТИВНА")
	else:
		print("🎮 Глобальная блокировка ввода СНЯТА")

func can_handle(context: InputContext) -> bool:
	"""Проверить, может ли указанный контекст обрабатывать ввод"""
	if is_blocked():
		return false
	return current_context == context

# ═══════════════════════════════════════════════════════════════════════════
# УТИЛИТЫ ДЛЯ ПРОВЕРКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func is_valid_key_event(event: InputEvent) -> bool:
	"""Проверить, является ли событие валидным нажатием клавиши
	
	Args:
		event: Событие ввода
		
	Returns:
		true если событие - нажатие клавиши (не echo)
	"""
	if not event is InputEventKey:
		return false
	var key_event = event as InputEventKey
	return key_event.pressed and not key_event.echo

func is_valid_action_event(event: InputEvent, action: String) -> bool:
	"""Проверить, является ли событие валидным действием
	
	Args:
		event: Событие ввода
		action: Имя действия
		
	Returns:
		true если событие соответствует действию и не является echo
	"""
	return event.is_action_pressed(action) and not event.is_echo()

func is_action_just_pressed(action: String) -> bool:
	"""Проверить, нажато ли действие (работает для клавиатуры и геймпада)
	
	Args:
		action: Имя действия
		
	Returns:
		true если действие только что нажато
	"""
	return Input.is_action_just_pressed(action)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_settings_opened() -> void:
	"""Обработчик открытия настроек"""
	settings_blocked = true
	print("🎮 InputContextManager: ввод заблокирован (настройки открыты)")

func _on_settings_closed() -> void:
	"""Обработчик закрытия настроек"""
	settings_blocked = false
	print("🎮 InputContextManager: ввод разблокирован (настройки закрыты)")

