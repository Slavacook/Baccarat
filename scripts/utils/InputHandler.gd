# res://scripts/utils/InputHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК ВВОДА
# 
# Отвечает за:
# - Обработку ввода клавиатуры и геймпада
# - Переключение режимов навигации
# - Обработку специальных действий (Escape, Space при Game Over, etc.)
# ═══════════════════════════════════════════════════════════════════════════

class_name InputHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var chance_card_navigator: ChanceCardNavigator
var chip_navigation_manager: ChipNavigationManager
var game_state_controller: GameStateController
var ui_manager: UIManager
var settings_scene: SettingsScene
var owner_node: Node  # Узел для доступа к дочерним элементам и viewport

# Callbacks для действий
var on_restart_game_callback: Callable
var get_viewport_callback: Callable

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	chance_navigator: ChanceCardNavigator,
	chip_nav_manager: ChipNavigationManager,
	game_state: GameStateController,
	ui_mgr: UIManager,
	settings: SettingsScene,
	owner: Node,
	restart_cb: Callable,
	get_viewport_cb: Callable
) -> void:
	"""Инициализировать обработчик ввода
	
	Args:
		chance_navigator: Навигатор карт шанса
		chip_nav_manager: Менеджер навигации по ставкам
		game_state: Контроллер состояния игры
		ui_mgr: Менеджер UI
		settings: Сцена настроек
		owner: Узел-владелец для доступа к дочерним элементам и viewport
		restart_cb: Callback для рестарта игры
		get_viewport_cb: Callback для получения viewport
	"""
	chance_card_navigator = chance_navigator
	chip_navigation_manager = chip_nav_manager
	game_state_controller = game_state
	ui_manager = ui_mgr
	settings_scene = settings
	owner_node = owner
	on_restart_game_callback = restart_cb
	get_viewport_callback = get_viewport_cb

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func handle_input(event: InputEvent) -> bool:
	"""Обработка ввода (клавиатура и геймпад) - используем _input для перехвата раньше
	
	Args:
		event: Событие ввода
		
	Returns:
		true если событие было обработано и нужно вызвать set_input_as_handled()
	"""
	# Переключение режима навигации по картам (C/кнопка 4) - обрабатываем в _input для раннего перехвата
	if event.is_action_pressed("chance_cards"):
		# Проверяем блокировки
		if InputContextManager.is_blocked():
			return false
		# Проверяем контекст GAME или CHANCE_CARDS_NAV для переключения режима
		var current_context = InputContextManager.get_context()
		if current_context == InputContextManager.InputContext.GAME or \
		   current_context == InputContextManager.InputContext.CHANCE_CARDS_NAV:
			if chance_card_navigator:
				if chance_card_navigator.is_active:
					chance_card_navigator.deactivate()
				else:
					chance_card_navigator.activate()
				return true
	
	# Обработка навигации по картам - обрабатываем в _input для раннего перехвата
	if chance_card_navigator and chance_card_navigator.is_active:
		# Проверяем контекст для навигации по картам
		if not InputContextManager.is_blocked():
			var current_context = InputContextManager.get_context()
			if current_context == InputContextManager.InputContext.CHANCE_CARDS_NAV:
				if chance_card_navigator.handle_input(event):
					return true
	
	# Обрабатываем только toggle_navigation здесь, остальное в _unhandled_input
	# В _input() используем event.is_action_pressed() для проверки конкретного события
	if event.is_action_pressed("toggle_navigation"):
		# Проверяем блокировки
		if InputContextManager.is_blocked():
			return false
		if not InputContextManager.can_handle(InputContextManager.InputContext.GAME):
			return false
		
		# toggle_navigation → включить/выключить навигацию по ставкам
		if chip_navigation_manager:
			if chip_navigation_manager.is_active:
				chip_navigation_manager.deactivate()
			else:
				chip_navigation_manager.activate()
			return true
		else:
			DebugLogger.log_error("❌ chip_navigation_manager не инициализирован!")
			return true
	
	return false

func handle_unhandled_input(event: InputEvent) -> bool:
	"""Обработка необработанного ввода (клавиатура и геймпад)
	
	Args:
		event: Событие ввода
		
	Returns:
		true если событие было обработано и нужно вызвать set_input_as_handled()
	"""
	# Проверяем блокировки через InputContextManager
	if InputContextManager.is_blocked():
		return false
	
	# Обработка навигации по картам уже обработана в _input() для раннего перехвата
	# Здесь не обрабатываем, чтобы избежать дублирования
	
	# Проверяем контекст (работаем только в контексте GAME для остальных действий)
	if not InputContextManager.can_handle(InputContextManager.InputContext.GAME):
		return false
	
	# Space при Game Over → рестарт игры
	if event.is_action_pressed("action"):
		if game_state_controller and not game_state_controller.is_game_active():
			# Game Over - рестарт игры
			if on_restart_game_callback.is_valid():
				on_restart_game_callback.call()
			# Скрываем Game Over overlay
			var game_over_popup = owner_node.get("game_over_popup") if owner_node.has("game_over_popup") else null
			if game_over_popup and game_over_popup.visible:
				game_over_popup.hide()
			return true
	
	# Если навигация по ставкам активна - обрабатываем ввод там
	if chip_navigation_manager and chip_navigation_manager.is_active:
		if chip_navigation_manager.handle_input(event):
			return true
	
	# Переключение режима сбора/выплаты ставок через клавишу F (только в основном окне)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		# Проверяем, что мы в основном окне игры (не в окне выплат, не в меню настроек)
		if not InputContextManager.can_handle(InputContextManager.InputContext.GAME):
			return false  # Не обрабатываем в других контекстах
		
		# Проверяем, что кнопка PayButton видима (режим сбора/выплаты активен)
		if ui_manager and ui_manager.button_ui:
			var pay_button = ui_manager.button_ui.pay_button
			if pay_button and pay_button.visible:
				# Переключаем состояние PayButton
				if pay_button.has_method("toggle_state"):
					pay_button.toggle_state()
					return true
				else:
					# Fallback: вызываем напрямую _on_pressed, если метод не найден
					pay_button._on_pressed()
					return true
		return false
	
	# Escape во время игры → открыть/закрыть меню
	if event.is_action_pressed("exit"):
		# Проверяем, не открыто ли меню гостей (приоритет выше)
		var guest_menu = owner_node.get_node_or_null("GuestMenuScene")
		if guest_menu and guest_menu.visible:
			# Если меню гостей открыто, закрываем его
			guest_menu.close_menu()
			return true
		
		# Проверяем, не открыто ли меню настроек
		# Если меню настроек видно, оно само обработает ESC (кнопка "Назад")
		# Поэтому мы не обрабатываем ESC здесь, если меню видно
		if settings_scene and settings_scene.visible:
			# Меню настроек само обработает ESC через SettingsScene._input()
			# Не обрабатываем здесь, чтобы избежать конфликта
			return false
		else:
			# Если меню закрыто, открываем его
			if settings_scene:
				settings_scene.open_settings()
				# UI элементы будут скрыты через сигнал EventBus.settings_opened в _on_settings_opened()
		return true
	
	return false
