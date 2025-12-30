# res://scripts/KeyboardFocusController.gd
# Контроллер клавиатурного управления фокусом в фазе раздачи карт
# 
# Управление:
#   Space - активация (если есть фокус → элемент, если нет → кнопка "Карты")
#   A/D   - горизонтальная навигация (банкир ← / → игрок)
#   W     - вверх (к маркерам / Игалите)
#   S     - вниз / выход из фокуса
#
# AUTOLOAD: добавляется в project.godot

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ENUM: Цели фокуса
# ═══════════════════════════════════════════════════════════════════════════

enum FocusTarget {
	NONE,           # Нет фокуса (Space = кнопка "Карты")
	BANKER_THIRD,   # Третья карта банкиру (A из NONE)
	PLAYER_THIRD,   # Третья карта игроку (D из NONE)
	BANKER_MARKER,  # Маркер банкира (W из BANKER_THIRD)
	PLAYER_MARKER,  # Маркер игрока (W из PLAYER_THIRD)
	TIE_MARKER      # Маркер Игалите (W из NONE, центр между маркерами)
}

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Текущий фокус
var current_focus: FocusTarget = FocusTarget.NONE

## Активен ли контроллер (только в фазе раздачи)
var is_active: bool = false

## Ссылка на FocusFrameUI для визуализации
var focus_frame: FocusFrameUI = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Подписываемся на изменение состояния игры
	if GameStateManager:
		GameStateManager.state_changed.connect(_on_game_state_changed)
	
	# Подписываемся на сигнал видимости навигации (фаза выплат)
	if EventBus:
		EventBus.navigation_arrows_visibility_changed.connect(_on_navigation_visibility_changed)
	
	print("⌨️ KeyboardFocusController инициализирован (новая логика навигации)")

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _is_crib_sheet_open() -> bool:
	"""Проверить, открыта ли шпаргалка"""
	# Ищем CribSheetScene в дереве сцены
	var scene_tree = get_tree()
	if not scene_tree:
		return false
	
	# Ищем узел CribSheetScene через группу
	var crib_sheets = get_tree().get_nodes_in_group("crib_sheet")
	if crib_sheets.size() > 0:
		var crib_sheet = crib_sheets[0]
		if crib_sheet and "visible" in crib_sheet:
			return crib_sheet.visible
	
	# Если не нашли через группу, ищем по имени
	var root = scene_tree.root
	if root:
		var crib_sheet = root.find_child("CribSheetScene", true, false)
		if crib_sheet and "visible" in crib_sheet:
			return crib_sheet.visible
	
	return false

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ВВОДА
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# Проверяем блокировки через InputContextManager
	if InputContextManager.is_blocked():
		return
	
	# Проверяем контекст (работаем только в контексте GAME)
	if not InputContextManager.can_handle(InputContextManager.InputContext.GAME):
		return
	
	# Space работает всегда (и в фазе раздачи, и в фазе выплат)
	# Но не работает, если шпаргалка открыта
	if event.is_action_pressed("action"):
		if _is_crib_sheet_open():
			get_viewport().set_input_as_handled()
			return
		_handle_space_press()
		get_viewport().set_input_as_handled()
		return
	
	# Остальные клавиши работают только когда контроллер активен
	if not is_active:
		return
	
	# В состоянии WAITING (карты не открыты) стрелки/WASD управляют камерой, а не картами
	if GameStateManager:
		var current_state = GameStateManager.get_current_state()
		if current_state == GameStateManager.GameState.WAITING:
			# Не обрабатываем стрелки/WASD, пусть их обрабатывает KeyboardNavigationController
			return
	
	# Используем Input Actions для поддержки клавиатуры и геймпада
	if event.is_action_pressed("left"):
		_handle_a_press()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		_handle_d_press()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("up"):
		_handle_w_press()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("down"):
		_handle_s_press()
		get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СОСТОЯНИЯ ТРЕТЬИХ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func _is_player_third_card_opened() -> bool:
	"""Проверить, открыта ли третья карта игрока"""
	var game_controller = _get_game_controller()
	if not game_controller:
		return false
	if not "hand_manager" in game_controller:
		return false
	var hand_manager = game_controller.hand_manager
	if not hand_manager:
		return false
	return hand_manager.has_player_third_card()

func _is_banker_third_card_opened() -> bool:
	"""Проверить, открыта ли третья карта банкира"""
	var game_controller = _get_game_controller()
	if not game_controller:
		return false
	if not "hand_manager" in game_controller:
		return false
	var hand_manager = game_controller.hand_manager
	if not hand_manager:
		return false
	return hand_manager.has_banker_third_card()

func _get_game_controller() -> Node:
	"""Получить GameController из текущей сцены"""
	var tree = get_tree()
	if not tree:
		return null
	return tree.current_scene

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ КЛАВИШ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_space_press() -> void:
	"""Space - универсальная активация
	
	Приоритет:
	1. Если открыта карта шанса → закрыть её
	2. Если есть фокус → активирует элемент в фокусе
	3. Если нет фокуса → нажимает кнопку 'Карты'
	"""
	# Проверяем, открыта ли карта шанса
	if ChanceCardManager and ChanceCardManager.is_card_showing():
		ChanceCardManager.close_current_card()
		print("⌨️ Space → Закрыта карта шанса")
		return
	
	# Обычная логика
	if current_focus == FocusTarget.NONE:
		# Нет фокуса → кнопка "Карты"
		EventBus.keyboard_action_requested.emit()
		print("⌨️ Space → Кнопка 'Карты'")
	else:
		# Есть фокус → активируем элемент
		_activate_current_focus()


func _handle_a_press() -> void:
	"""A - навигация влево (к банкиру)
	
	Логика зависит от состояния третьих карт:
	- Если обе карты открыты → сразу на маркеры
	- Если открыта только карта игрока → на кнопку заказа третьей карты банкира
	- Если открыта только карта банкира → сразу на маркер банкира
	- Если обе карты не открыты → на кнопку заказа третьей карты банкира
	"""
	var player_opened = _is_player_third_card_opened()
	var banker_opened = _is_banker_third_card_opened()
	
	match current_focus:
		FocusTarget.NONE:
			# Если обе карты открыты → сразу на маркер банкира
			if player_opened and banker_opened:
				_set_focus(FocusTarget.BANKER_MARKER)
			# Если открыта только карта банкира → сразу на маркер банкира (пропускаем кнопку)
			elif banker_opened and not player_opened:
				_set_focus(FocusTarget.BANKER_MARKER)
			else:
				_set_focus(FocusTarget.BANKER_THIRD)
		
		FocusTarget.PLAYER_THIRD:
			# Если обе карты открыты → сразу на маркер банкира
			if player_opened and banker_opened:
				_set_focus(FocusTarget.BANKER_MARKER)
			# Если открыта только карта игрока → на кнопку заказа третьей карты банкира
			elif player_opened and not banker_opened:
				_set_focus(FocusTarget.BANKER_THIRD)
			# Если открыта только карта банкира → сразу на маркер банкира (пропускаем кнопку)
			elif banker_opened and not player_opened:
				_set_focus(FocusTarget.BANKER_MARKER)
			# Если карта игрока не открыта → на кнопку заказа третьей карты банкира
			else:
				_set_focus(FocusTarget.BANKER_THIRD)
		
		FocusTarget.PLAYER_MARKER:
			_set_focus(FocusTarget.TIE_MARKER)
		
		FocusTarget.TIE_MARKER:
			_set_focus(FocusTarget.BANKER_MARKER)
		
		FocusTarget.BANKER_MARKER:
			# Если карта банкира не открыта → на кнопку заказа третьей карты банкира
			if not banker_opened:
				_set_focus(FocusTarget.BANKER_THIRD)
			# Иначе остаемся на месте
		
		FocusTarget.BANKER_THIRD:
			# Если обе карты открыты → сразу на маркер банкира
			if player_opened and banker_opened:
				_set_focus(FocusTarget.BANKER_MARKER)
			# Если открыта только карта банкира → сразу на маркер банкира (кнопка уже не нужна)
			elif banker_opened and not player_opened:
				_set_focus(FocusTarget.BANKER_MARKER)
			# Если карта банкира не открыта → остаемся на месте


func _handle_d_press() -> void:
	"""D - навигация вправо (к игроку)
	
	Логика зависит от состояния третьих карт:
	- Если обе карты открыты → сразу на маркеры
	- Если открыта только карта банкира → на кнопку заказа третьей карты игрока
	- Если открыта только карта игрока → сразу на маркер игрока
	- Если обе карты не открыты → на кнопку заказа третьей карты игрока
	"""
	var player_opened = _is_player_third_card_opened()
	var banker_opened = _is_banker_third_card_opened()
	
	match current_focus:
		FocusTarget.NONE:
			# Если обе карты открыты → сразу на маркер игрока
			if player_opened and banker_opened:
				_set_focus(FocusTarget.PLAYER_MARKER)
			# Если открыта только карта игрока → сразу на маркер игрока (пропускаем кнопку)
			elif player_opened and not banker_opened:
				_set_focus(FocusTarget.PLAYER_MARKER)
			else:
				_set_focus(FocusTarget.PLAYER_THIRD)
		
		FocusTarget.BANKER_THIRD:
			# Если обе карты открыты → сразу на маркер игрока
			if player_opened and banker_opened:
				_set_focus(FocusTarget.PLAYER_MARKER)
			# Если открыта только карта банкира → на кнопку заказа третьей карты игрока
			elif banker_opened and not player_opened:
				_set_focus(FocusTarget.PLAYER_THIRD)
			# Если открыта только карта игрока → сразу на маркер игрока (пропускаем кнопку)
			elif player_opened and not banker_opened:
				_set_focus(FocusTarget.PLAYER_MARKER)
			# Если карта банкира не открыта → на кнопку заказа третьей карты игрока
			else:
				_set_focus(FocusTarget.PLAYER_THIRD)
		
		FocusTarget.BANKER_MARKER:
			_set_focus(FocusTarget.TIE_MARKER)
		
		FocusTarget.TIE_MARKER:
			_set_focus(FocusTarget.PLAYER_MARKER)
		
		FocusTarget.PLAYER_MARKER:
			# Если карта игрока не открыта → на кнопку заказа третьей карты игрока
			if not player_opened:
				_set_focus(FocusTarget.PLAYER_THIRD)
			# Иначе остаемся на месте
		
		FocusTarget.PLAYER_THIRD:
			# Если обе карты открыты → сразу на маркер игрока
			if player_opened and banker_opened:
				_set_focus(FocusTarget.PLAYER_MARKER)
			# Если открыта только карта игрока → сразу на маркер игрока (кнопка уже не нужна)
			elif player_opened and not banker_opened:
				_set_focus(FocusTarget.PLAYER_MARKER)
			# Если карта игрока не открыта → остаемся на месте


func _handle_w_press() -> void:
	"""W - навигация вверх (к маркерам / Игалите)
	
	Таблица переходов:
	  NONE → TIE_MARKER
	  BANKER_THIRD → BANKER_MARKER
	  PLAYER_THIRD → PLAYER_MARKER
	  Остальные → без изменений
	"""
	match current_focus:
		FocusTarget.NONE:
			_set_focus(FocusTarget.TIE_MARKER)
		FocusTarget.BANKER_THIRD:
			_set_focus(FocusTarget.BANKER_MARKER)
		FocusTarget.PLAYER_THIRD:
			_set_focus(FocusTarget.PLAYER_MARKER)
		# BANKER_MARKER, PLAYER_MARKER, TIE_MARKER → остаются на месте


func _handle_s_press() -> void:
	"""S - навигация вниз / выход из фокуса
	
	Таблица переходов:
	  BANKER_MARKER → BANKER_THIRD (если карта не открыта) или NONE (если обе карты открыты)
	  PLAYER_MARKER → PLAYER_THIRD (если карта не открыта) или NONE (если обе карты открыты)
	  BANKER_THIRD → NONE
	  PLAYER_THIRD → NONE
	  TIE_MARKER → NONE
	  NONE → без изменений
	"""
	var player_opened = _is_player_third_card_opened()
	var banker_opened = _is_banker_third_card_opened()
	
	match current_focus:
		FocusTarget.BANKER_MARKER:
			# Если карта банкира открыта → выход из фокуса (пропускаем кнопку заказа)
			if banker_opened:
				_clear_focus()
			# Если карта банкира не открыта → на кнопку заказа третьей карты банкира
			else:
				_set_focus(FocusTarget.BANKER_THIRD)
		
		FocusTarget.PLAYER_MARKER:
			# Если карта игрока открыта → выход из фокуса (пропускаем кнопку заказа)
			if player_opened:
				_clear_focus()
			# Если карта игрока не открыта → на кнопку заказа третьей карты игрока
			else:
				_set_focus(FocusTarget.PLAYER_THIRD)
		
		FocusTarget.BANKER_THIRD, FocusTarget.PLAYER_THIRD, FocusTarget.TIE_MARKER:
			_clear_focus()
		# NONE → без изменений

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ФОКУСОМ
# ═══════════════════════════════════════════════════════════════════════════

func _set_focus(target: FocusTarget) -> void:
	"""Установить фокус на элемент"""
	if current_focus == target:
		return  # Уже в фокусе
	
	current_focus = target
	
	var target_name = _get_target_name(target)
	EventBus.focus_changed.emit(target_name)
	
	# Обновляем визуализацию рамки
	_update_focus_frame()
	
	print("⌨️ Фокус → %s" % target_name)


func _activate_current_focus() -> void:
	"""Активировать элемент в текущем фокусе и сбросить фокус"""
	if current_focus == FocusTarget.NONE:
		return
	
	var target_name = _get_target_name(current_focus)
	EventBus.focus_activated.emit(target_name)
	
	print("⌨️ Активация: %s" % target_name)
	
	# Сбрасываем фокус после активации (следующий Space = кнопка "Карты")
	_clear_focus()


func _clear_focus() -> void:
	"""Сбросить фокус"""
	current_focus = FocusTarget.NONE
	
	EventBus.focus_changed.emit("None")
	
	# Скрываем рамку
	if focus_frame:
		focus_frame.hide_frame()
	
	print("⌨️ Фокус сброшен")


func _get_target_name(target: FocusTarget) -> String:
	"""Получить строковое имя цели фокуса"""
	match target:
		FocusTarget.BANKER_THIRD:
			return "BankerThird"
		FocusTarget.PLAYER_THIRD:
			return "PlayerThird"
		FocusTarget.BANKER_MARKER:
			return "BankerMarker"
		FocusTarget.PLAYER_MARKER:
			return "PlayerMarker"
		FocusTarget.TIE_MARKER:
			return "TieMarker"
		_:
			return "None"

# ═══════════════════════════════════════════════════════════════════════════
# ВИЗУАЛИЗАЦИЯ РАМКИ
# ═══════════════════════════════════════════════════════════════════════════

func _update_focus_frame() -> void:
	"""Обновить позицию рамки фокуса"""
	if not focus_frame:
		_find_focus_frame()
	
	if not focus_frame:
		return
	
	var node = _get_node_for_focus(current_focus)
	if node:
		focus_frame.show_on_node(node)
	else:
		focus_frame.hide_frame()


func _find_focus_frame() -> void:
	"""Найти FocusFrameUI в сцене"""
	var tree = get_tree()
	if not tree:
		return
	
	var root = tree.current_scene
	if not root:
		return
	
	focus_frame = root.find_child("FocusFrame", true, false) as FocusFrameUI


func _get_node_for_focus(target: FocusTarget) -> Control:
	"""Получить узел для указанной цели фокуса"""
	var tree = get_tree()
	if not tree:
		return null
	
	var root = tree.current_scene
	if not root:
		return null
	
	match target:
		FocusTarget.BANKER_THIRD:
			return root.get_node_or_null("BankerZone/BankerThirdCardToggle")
		
		FocusTarget.PLAYER_THIRD:
			return root.get_node_or_null("PlayerZone/PlayerThirdCardToggle")
		
		FocusTarget.BANKER_MARKER:
			var marker = root.find_child("BankerMarker", true, false)
			if marker:
				return marker
			return root.get_node_or_null("BankerZone/BankerMarker")
		
		FocusTarget.PLAYER_MARKER:
			var marker = root.find_child("PlayerMarker", true, false)
			if marker:
				return marker
			return root.get_node_or_null("PlayerZone/PlayerMarker")
		
		FocusTarget.TIE_MARKER:
			return root.find_child("TieMarker", true, false)
		
		_:
			return null

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ АКТИВНОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func enable() -> void:
	"""Включить управление фокусом (фаза раздачи)"""
	if is_active:
		return
	
	is_active = true
	EventBus.focus_control_enabled.emit(true)
	print("⌨️ KeyboardFocusController АКТИВЕН (фаза раздачи)")


func disable() -> void:
	"""Отключить управление фокусом (фаза выплат)"""
	if not is_active:
		return
	
	is_active = false
	_clear_focus()
	EventBus.focus_control_enabled.emit(false)
	print("⌨️ KeyboardFocusController НЕАКТИВЕН (фаза выплат)")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_game_state_changed(_old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	"""Обработка изменения состояния игры"""
	var active_states = [
		GameStateManager.GameState.WAITING,
		GameStateManager.GameState.CARD_TO_EACH,
		GameStateManager.GameState.CARD_TO_PLAYER,
		GameStateManager.GameState.CARD_TO_BANKER,
		GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER,
		GameStateManager.GameState.CHOOSE_WINNER
	]
	
	if new_state in active_states:
		enable()


func _on_navigation_visibility_changed(visible: bool) -> void:
	"""Обработка показа/скрытия стрелок навигации
	
	Стрелки показаны = победитель определён = фаза выплат
	"""
	if visible:
		disable()
	else:
		var state = GameStateManager.get_current_state()
		if state == GameStateManager.GameState.WAITING:
			enable()
