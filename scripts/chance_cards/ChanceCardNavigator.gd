# res://scripts/chance_cards/ChanceCardNavigator.gd
# Навигатор для управления картами шансов с клавиатуры и геймпада

class_name ChanceCardNavigator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Активна ли навигация по картам
var is_active: bool = false

## Индекс текущей выбранной карты
var current_card_index: int = -1

## Ссылка на хранилище карт
var storage: ChanceCardStorage = null

## Ссылка на сцену полного экрана
var fullscreen_scene: BaseChanceCardScene = null

## Список доступных карт (card_id)
var available_cards: Array[String] = []

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(storage_ref: ChanceCardStorage, fullscreen_ref: BaseChanceCardScene):
	storage = storage_ref
	fullscreen_scene = fullscreen_ref
	
	# Подписываемся на закрытие карты
	if EventBus:
		EventBus.chance_card_popup_closed.connect(on_card_closed)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func activate():
	"""Активировать навигацию по картам"""
	if is_active:
		print("🎴 ChanceCardNavigator: уже активен")
		return
	
	is_active = true
	_update_available_cards()
	
	# Устанавливаем фокус на первую доступную карту
	if available_cards.size() > 0:
		current_card_index = 0
		_highlight_card(available_cards[current_card_index])
		print("🎴 ChanceCardNavigator: выделена первая карта: %s (индекс %d)" % [available_cards[current_card_index], current_card_index])
	else:
		current_card_index = -1
		print("⚠️ ChanceCardNavigator: нет доступных карт")
	
	# Устанавливаем контекст
	InputContextManager.set_context(InputContextManager.InputContext.CHANCE_CARDS_NAV)
	print("🎴 ChanceCardNavigator: навигация активирована (карт: %d)" % available_cards.size())

func deactivate():
	"""Деактивировать навигацию по картам"""
	if not is_active:
		return
	
	is_active = false
	current_card_index = -1
	_clear_highlight()
	
	# Возвращаем контекст игры
	InputContextManager.set_context(InputContextManager.InputContext.GAME)
	print("🎴 ChanceCardNavigator: навигация деактивирована")

func handle_input(event: InputEvent) -> bool:
	"""Обработать ввод. Возвращает true если событие обработано"""
	if not is_active:
		print("🎴 ChanceCardNavigator.handle_input: навигация не активна")
		return false
	
	# Проверяем блокировки
	if InputContextManager.is_blocked():
		print("🎴 ChanceCardNavigator.handle_input: ввод заблокирован")
		return false
	
	# Проверяем контекст
	var current_context = InputContextManager.get_context()
	if current_context != InputContextManager.InputContext.CHANCE_CARDS_NAV:
		print("🎴 ChanceCardNavigator.handle_input: неправильный контекст (текущий: %d, нужен: %d)" % [current_context, InputContextManager.InputContext.CHANCE_CARDS_NAV])
		return false
	
	# Получаем viewport через storage или fullscreen_scene
	var viewport = _get_viewport()
	if not viewport:
		return false
	
	# Переключение режима (C/кнопка 4)
	if event.is_action_pressed("chance_cards"):
		deactivate()
		viewport.set_input_as_handled()
		return true
	
	# Выход (ESC/кнопка 5)
	if event.is_action_pressed("exit"):
		# Если карта открыта - закрываем её
		if fullscreen_scene and fullscreen_scene.visible:
			fullscreen_scene.hide_card()
			# После закрытия карты остаёмся в режиме навигации
			viewport.set_input_as_handled()
			return true
		# Иначе выходим из режима навигации
		deactivate()
		viewport.set_input_as_handled()
		return true
	
	# Если карта открыта - обрабатываем управление картой
	# При открытой карте контекст остаётся CHANCE_CARDS_NAV, чтобы навигатор продолжал работать
	if fullscreen_scene and fullscreen_scene.visible:
		return _handle_card_input(event, viewport)
	
	# Навигация по картам в хранилище
	if event.is_action_pressed("left"):
		print("🎴 ChanceCardNavigator: получено событие left")
		_navigate_left()
		viewport.set_input_as_handled()
		return true
	elif event.is_action_pressed("right"):
		print("🎴 ChanceCardNavigator: получено событие right")
		_navigate_right()
		viewport.set_input_as_handled()
		return true
	elif event.is_action_pressed("action"):
		print("🎴 ChanceCardNavigator: получено событие action для открытия карты")
		_open_current_card()
		viewport.set_input_as_handled()
		return true
	
	print("🎴 ChanceCardNavigator: событие не обработано (is_active: %s, контекст: %s)" % [is_active, InputContextManager.get_context()])
	
	return false

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _update_available_cards():
	"""Обновить список доступных карт"""
	available_cards.clear()
	
	if not storage:
		print("⚠️ ChanceCardNavigator: storage не доступен")
		return
	
	# Получаем все карты из менеджера
	var all_cards = ChanceCardManager.get_all_cards()
	print("🎴 ChanceCardNavigator: получено %d карт из менеджера" % all_cards.size())
	print("🎴 ChanceCardNavigator: в хранилище %d миниатюр" % storage.card_miniatures.size())
	
	# Если миниатюры есть, используем их
	if storage.card_miniatures.size() > 0:
		# Используем карты из хранилища (более надёжно)
		for card_id in storage.card_miniatures.keys():
			available_cards.append(card_id)
			var card = ChanceCardManager.get_card(card_id)
			if card:
				print("  → Карта %s добавлена из хранилища (count: %d)" % [card_id, card.count])
			else:
				print("  → Карта %s добавлена из хранилища (но не найдена в менеджере)" % card_id)
	else:
		# Fallback: используем карты из менеджера
		print("⚠️ ChanceCardNavigator: миниатюры не найдены, используем карты из менеджера")
		for card in all_cards:
			available_cards.append(card.card_id)
			print("  → Карта %s добавлена из менеджера (count: %d)" % [card.card_id, card.count])
	
	print("🎴 ChanceCardNavigator: найдено %d доступных карт" % available_cards.size())

func _navigate_left():
	"""Перейти к предыдущей карте"""
	if available_cards.is_empty():
		print("⚠️ ChanceCardNavigator: нет карт для навигации")
		return
	
	if current_card_index < 0:
		current_card_index = 0
	
	current_card_index = (current_card_index - 1 + available_cards.size()) % available_cards.size()
	print("🎴 ChanceCardNavigator: навигация влево, индекс: %d, карта: %s" % [current_card_index, available_cards[current_card_index]])
	_highlight_card(available_cards[current_card_index])

func _navigate_right():
	"""Перейти к следующей карте"""
	if available_cards.is_empty():
		print("⚠️ ChanceCardNavigator: нет карт для навигации")
		return
	
	if current_card_index < 0:
		current_card_index = 0
	
	current_card_index = (current_card_index + 1) % available_cards.size()
	print("🎴 ChanceCardNavigator: навигация вправо, индекс: %d, карта: %s" % [current_card_index, available_cards[current_card_index]])
	_highlight_card(available_cards[current_card_index])

func _highlight_card(card_id: String):
	"""Подсветить карту в хранилище"""
	_clear_highlight()
	
	if not storage:
		print("⚠️ ChanceCardNavigator._highlight_card: storage не доступен")
		return
	
	if not storage.card_miniatures.has(card_id):
		print("⚠️ ChanceCardNavigator._highlight_card: карта %s не найдена в хранилище (доступно: %s)" % [card_id, storage.card_miniatures.keys()])
		return
	
	var miniature = storage.card_miniatures[card_id]
	var button = miniature["button"] as TextureButton
	if button:
		# Добавляем визуальную подсветку (можно настроить)
		button.modulate = Color(1.2, 1.2, 1.0, 1.0)  # Немного ярче и желтее
		print("🎴 ChanceCardNavigator: выделена карта %s" % card_id)
	else:
		print("⚠️ ChanceCardNavigator._highlight_card: кнопка не найдена для карты %s" % card_id)

func _clear_highlight():
	"""Убрать подсветку со всех карт"""
	if not storage:
		return
	
	for card_id in storage.card_miniatures:
		var miniature = storage.card_miniatures[card_id]
		var button = miniature["button"] as TextureButton
		if button:
			# Восстанавливаем нормальный цвет
			var card = ChanceCardManager.get_card(card_id)
			if card and card.count > 0:
				button.modulate = Color.WHITE
			else:
				button.modulate = Color(0.4, 0.4, 0.4, 0.7)

func _open_current_card():
	"""Открыть текущую выбранную карту"""
	if current_card_index < 0 or current_card_index >= available_cards.size():
		return
	
	var card_id = available_cards[current_card_index]
	var card = ChanceCardManager.get_card(card_id)
	if not card:
		return
	
	# Показываем карту на весь экран
	if fullscreen_scene:
		var storage_pos = Vector2.ZERO
		if storage:
			storage_pos = storage.get_storage_position_for_card(card_id)
		fullscreen_scene.show_fullscreen(card, storage_pos)
		
		# Фокус устанавливается автоматически в BaseChanceCardScene.show_fullscreen()
		# Но устанавливаем ещё раз после небольшой задержки для надёжности
		_focus_card_button_delayed()
	
	print("🎴 ChanceCardNavigator: открыта карта %s" % card_id)

func _focus_card_button_delayed():
	"""Установить фокус на кнопку с задержкой"""
	# Используем call_deferred для установки фокуса после следующего кадра
	if fullscreen_scene:
		fullscreen_scene.call_deferred("_focus_button_for_navigator")

func _focus_card_button():
	"""Установить фокус на кнопку "Использовать/Закрыть" в открытой карте"""
	if not fullscreen_scene or not fullscreen_scene.visible:
		return
	
	# Определяем, какая кнопка видна
	var target_button: Button = null
	if fullscreen_scene.use_button and fullscreen_scene.use_button.visible:
		target_button = fullscreen_scene.use_button
	elif fullscreen_scene.close_button and fullscreen_scene.close_button.visible:
		target_button = fullscreen_scene.close_button
	
	if target_button:
		target_button.grab_focus()
		print("🎴 ChanceCardNavigator: фокус установлен на кнопку карты")

func _handle_card_input(event: InputEvent, viewport: Viewport) -> bool:
	"""Обработать ввод когда карта открыта"""
	if not fullscreen_scene or not fullscreen_scene.visible:
		return false
	
	# Action - активировать кнопку
	if event.is_action_pressed("action"):
		var focused = viewport.gui_get_focus_owner()
		if focused:
			if focused == fullscreen_scene.use_button or focused == fullscreen_scene.close_button:
				# Нажимаем кнопку
				if focused is Button:
					var button = focused as Button
					button.pressed.emit()
					viewport.set_input_as_handled()
					return true
		else:
			# Если фокус не установлен, устанавливаем его на кнопку
			_focus_card_button()
			viewport.set_input_as_handled()
			return true
	
	return false

func _get_viewport() -> Viewport:
	"""Получить viewport через storage или fullscreen_scene"""
	if storage:
		return storage.get_viewport()
	elif fullscreen_scene:
		return fullscreen_scene.get_viewport()
	return null

func on_card_closed():
	"""Вызывается когда карта закрыта - возвращаемся к навигации по хранилищу"""
	# ВАЖНО: Проверяем, что навигатор всё ещё активен
	# Если навигатор был деактивирован (например, пользователь нажал C/кнопку 4),
	# то не нужно возвращаться к навигации
	if not is_active:
		print("🎴 ChanceCardNavigator: карта закрыта, но навигатор не активен - не возвращаемся к навигации")
		return
	
	# Обновляем список карт (на случай если счётчик изменился)
	_update_available_cards()
	
	# Проверяем, что текущий индекс всё ещё валиден
	if current_card_index >= available_cards.size():
		# Если индекс вышел за границы, устанавливаем на последнюю карту
		if available_cards.size() > 0:
			current_card_index = available_cards.size() - 1
		else:
			current_card_index = -1
	
	# Если после обновления списка карт текущий индекс стал невалидным,
	# устанавливаем на первую доступную карту
	if current_card_index < 0 and available_cards.size() > 0:
		current_card_index = 0
	
	# Устанавливаем фокус на текущую карту
	if current_card_index >= 0 and current_card_index < available_cards.size():
		_highlight_card(available_cards[current_card_index])
	
	# ВАЖНО: Устанавливаем контекст обратно в CHANCE_CARDS_NAV
	# (на случай если он был изменён где-то ещё)
	InputContextManager.set_context(InputContextManager.InputContext.CHANCE_CARDS_NAV)
	
	print("🎴 ChanceCardNavigator: карта закрыта, возвращаемся к навигации (контекст: CHANCE_CARDS_NAV, карт: %d, индекс: %d)" % [available_cards.size(), current_card_index])
