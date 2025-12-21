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
	TIE_BUTTON      # Кнопка Игалите (W из NONE, центр между маркерами)
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
# ОБРАБОТКА ВВОДА
# ═══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	if not event.pressed or event.echo:
		return
	
	# Space работает всегда (и в фазе раздачи, и в фазе выплат)
	if event.keycode == KEY_SPACE:
		_handle_space_press()
		get_viewport().set_input_as_handled()
		return
	
	# Остальные клавиши работают только когда контроллер активен
	if not is_active:
		return
	
	match event.keycode:
		KEY_A:
			_handle_a_press()
			get_viewport().set_input_as_handled()
		
		KEY_D:
			_handle_d_press()
			get_viewport().set_input_as_handled()
		
		KEY_W:
			_handle_w_press()
			get_viewport().set_input_as_handled()
		
		KEY_S:
			_handle_s_press()
			get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ КЛАВИШ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_space_press() -> void:
	"""Space - универсальная активация
	
	Если есть фокус → активирует элемент в фокусе
	Если нет фокуса → нажимает кнопку 'Карты'
	"""
	if current_focus == FocusTarget.NONE:
		# Нет фокуса → кнопка "Карты"
		EventBus.keyboard_action_requested.emit()
		print("⌨️ Space → Кнопка 'Карты'")
	else:
		# Есть фокус → активируем элемент
		_activate_current_focus()


func _handle_a_press() -> void:
	"""A - навигация влево (к банкиру)
	
	Таблица переходов:
	  NONE → BANKER_THIRD
	  PLAYER_THIRD → BANKER_THIRD
	  PLAYER_MARKER → TIE_BUTTON
	  TIE_BUTTON → BANKER_MARKER
	  Остальные → без изменений
	"""
	match current_focus:
		FocusTarget.NONE:
			_set_focus(FocusTarget.BANKER_THIRD)
		FocusTarget.PLAYER_THIRD:
			_set_focus(FocusTarget.BANKER_THIRD)
		FocusTarget.PLAYER_MARKER:
			_set_focus(FocusTarget.TIE_BUTTON)
		FocusTarget.TIE_BUTTON:
			_set_focus(FocusTarget.BANKER_MARKER)
		# BANKER_THIRD, BANKER_MARKER → остаются на месте


func _handle_d_press() -> void:
	"""D - навигация вправо (к игроку)
	
	Таблица переходов:
	  NONE → PLAYER_THIRD
	  BANKER_THIRD → PLAYER_THIRD
	  BANKER_MARKER → TIE_BUTTON
	  TIE_BUTTON → PLAYER_MARKER
	  Остальные → без изменений
	"""
	match current_focus:
		FocusTarget.NONE:
			_set_focus(FocusTarget.PLAYER_THIRD)
		FocusTarget.BANKER_THIRD:
			_set_focus(FocusTarget.PLAYER_THIRD)
		FocusTarget.BANKER_MARKER:
			_set_focus(FocusTarget.TIE_BUTTON)
		FocusTarget.TIE_BUTTON:
			_set_focus(FocusTarget.PLAYER_MARKER)
		# PLAYER_THIRD, PLAYER_MARKER → остаются на месте


func _handle_w_press() -> void:
	"""W - навигация вверх (к маркерам / Игалите)
	
	Таблица переходов:
	  NONE → TIE_BUTTON
	  BANKER_THIRD → BANKER_MARKER
	  PLAYER_THIRD → PLAYER_MARKER
	  Остальные → без изменений
	"""
	match current_focus:
		FocusTarget.NONE:
			_set_focus(FocusTarget.TIE_BUTTON)
		FocusTarget.BANKER_THIRD:
			_set_focus(FocusTarget.BANKER_MARKER)
		FocusTarget.PLAYER_THIRD:
			_set_focus(FocusTarget.PLAYER_MARKER)
		# BANKER_MARKER, PLAYER_MARKER, TIE_BUTTON → остаются на месте


func _handle_s_press() -> void:
	"""S - навигация вниз / выход из фокуса
	
	Таблица переходов:
	  BANKER_MARKER → BANKER_THIRD
	  PLAYER_MARKER → PLAYER_THIRD
	  BANKER_THIRD → NONE
	  PLAYER_THIRD → NONE
	  TIE_BUTTON → NONE
	  NONE → без изменений
	"""
	match current_focus:
		FocusTarget.BANKER_MARKER:
			_set_focus(FocusTarget.BANKER_THIRD)
		FocusTarget.PLAYER_MARKER:
			_set_focus(FocusTarget.PLAYER_THIRD)
		FocusTarget.BANKER_THIRD, FocusTarget.PLAYER_THIRD, FocusTarget.TIE_BUTTON:
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
	"""Активировать элемент в текущем фокусе"""
	if current_focus == FocusTarget.NONE:
		return
	
	var target_name = _get_target_name(current_focus)
	EventBus.focus_activated.emit(target_name)
	
	print("⌨️ Активация: %s" % target_name)


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
		FocusTarget.TIE_BUTTON:
			return "TieButton"
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
		
		FocusTarget.TIE_BUTTON:
			return root.find_child("TieButton", true, false)
		
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
