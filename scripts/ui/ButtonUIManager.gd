# res://scripts/ui/ButtonUIManager.gd
# Специализированный менеджер для управления кнопками
# Часть декомпозиции UIManager (Phase 2)

class_name ButtonUIManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal action_button_pressed()
signal help_button_pressed()
signal lang_button_pressed()
signal tie_button_pressed()
signal collect_button_toggled(enabled: bool)
signal pay_button_toggled(enabled: bool)

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ КНОПОК
# ═══════════════════════════════════════════════════════════════════════════

var action_button: TextureButton  # Главная кнопка "Карты" / "Подтвердить" / "Завершить"
var action_button_broken: TextureButton  # Кнопка с broken текстурой (подмена при неоплаченных ставках)
var tie_button: Button            # Кнопка "Игалите" (появляется после раздачи)
var help_button: Button           # Кнопка помощи
var lang_button: Button           # Кнопка смены языка (опционально)

# Кнопки управления сбором/оплатой ставок
var collect_button: TextureButton  # Кнопка "Забрать" (toggle)
var pay_button: TextureButton      # Кнопка "Оплатить" (toggle)

# Текущее состояние action button
var current_button_state: String = "start"

# Состояние кнопок collect/pay (взаимоисключающие toggle)
var _collect_mode_active: bool = false
var _pay_mode_active: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(scene: Node):
	"""Инициализация менеджера кнопок

	Args:
		scene: Корневой узел сцены Game.tscn
	"""
	# Получаем ссылки на UI узлы кнопок
	action_button = scene.get_node("CardsButton")
	help_button = scene.get_node("HelpButton")
	
	# Получаем ссылку на broken кнопку (проверяем в разных местах иерархии)
	# Сначала проверяем в корневом узле
	if scene.has_node("CardsButtonBroken"):
		action_button_broken = scene.get_node("CardsButtonBroken")
	elif scene.has_node("TopUI/CardsButtonBroken"):
		action_button_broken = scene.get_node("TopUI/CardsButtonBroken")
	else:
		# Пробуем найти через поиск по имени
		action_button_broken = scene.find_child("CardsButtonBroken", true, false)
	
	if action_button_broken:
		# Если кнопки находятся в разных родительских узлах, перемещаем broken кнопку к основной
		# НО НЕ меняем её позицию и размер - они настроены отдельно в сцене!
		if action_button and action_button_broken.get_parent() != action_button.get_parent():
			var broken_parent = action_button_broken.get_parent()
			var target_parent = action_button.get_parent()
			# Сохраняем текущие параметры перед перемещением
			var saved_offset_left = action_button_broken.offset_left
			var saved_offset_top = action_button_broken.offset_top
			var saved_offset_right = action_button_broken.offset_right
			var saved_offset_bottom = action_button_broken.offset_bottom
			var saved_scale = action_button_broken.scale
			# Перемещаем в тот же родительский узел
			broken_parent.remove_child(action_button_broken)
			target_parent.add_child(action_button_broken)
			# Восстанавливаем сохраненные параметры (не синхронизируем с основной кнопкой!)
			action_button_broken.offset_left = saved_offset_left
			action_button_broken.offset_top = saved_offset_top
			action_button_broken.offset_right = saved_offset_right
			action_button_broken.offset_bottom = saved_offset_bottom
			action_button_broken.scale = saved_scale
			print("🔄 ButtonUIManager: CardsButtonBroken перемещена к тому же родителю что и CardsButton (параметры сохранены)")
		# Подключаем обработчик нажатия на broken кнопку
		action_button_broken.pressed.connect(_on_broken_button_pressed)
		print("✅ ButtonUIManager: CardsButtonBroken найдена и подключена (путь: %s)" % action_button_broken.get_path())
	else:
		print("⚠️  ButtonUIManager: CardsButtonBroken НЕ найдена в сцене!")

	# Tie button (появляется при раздаче, скрыта по умолчанию)
	if scene.has_node("TieButton"):
		tie_button = scene.get_node("TieButton")
		tie_button.pressed.connect(func(): tie_button_pressed.emit())
		tie_button.visible = false  # Скрыта до начала раздачи

	# Lang button опционально (может отсутствовать в некоторых сценах)
	if scene.has_node("LangButton"):
		lang_button = scene.get_node("LangButton")
		lang_button.pressed.connect(func(): lang_button_pressed.emit())

	# Подключаем обработчики
	action_button.pressed.connect(func(): action_button_pressed.emit())
	help_button.pressed.connect(func(): help_button_pressed.emit())

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ACTION BUTTON
# ═══════════════════════════════════════════════════════════════════════════

@warning_ignore("unused_parameter")
func update_action_button(text: String):
	"""Обновление текста action button (legacy метод для совместимости)

	Примечание:
		TextureButton не использует text, текстуры устанавливаются через set_action_button_state()
	"""
	pass  # TextureButton не имеет текста, используем текстуры


func set_action_button_state(state: String):
	"""Установить состояние кнопки с текстурами

	States:
		- "start": Начать игру (карты скрыты)
		- "confirm": Подтвердить действие (карты открыты)
		- "complete": Завершить/Новая игра (раздача закончена)

	Args:
		state: Название состояния ("start", "confirm", "complete")
	"""
	const TEXTURES = {
		"start": {
			"normal": "res://assets/ui/buttons/start_button.png",
			"pressed": "res://assets/ui/buttons/start_button_pressed.png"
		},
		"confirm": {
			"normal": "res://assets/ui/buttons/confirm_button.png",
			"pressed": "res://assets/ui/buttons/confirm_button_pressed.png"
		},
		"complete": {
			"normal": "res://assets/ui/buttons/complete_button.png",
			"pressed": "res://assets/ui/buttons/complete_pressed_button.png"
		}
	}

	if not TEXTURES.has(state):
		push_error("ButtonUIManager: неизвестное состояние кнопки '%s'" % state)
		return

	# Проверяем что кнопка существует (в тестах её может не быть)
	if not action_button:
		return

	var tex_data = TEXTURES[state]
	var normal_tex = load(tex_data["normal"])
	var pressed_tex = load(tex_data["pressed"])

	if normal_tex:
		action_button.texture_normal = normal_tex
	if pressed_tex:
		action_button.texture_pressed = pressed_tex

	# Сохраняем текущее состояние
	current_button_state = state
	print("🔘 Кнопка: %s" % state)


func get_action_button_state() -> String:
	"""Получить текущее состояние кнопки

	Returns:
		Текущее состояние: "start", "confirm", или "complete"
	"""
	return current_button_state


func enable_action_button():
	"""Включить action button (сделать кликабельной)"""
	if action_button:
		action_button.disabled = false
		# Если кнопка в состоянии "complete", скрываем broken кнопку и показываем основную
		if current_button_state == "complete":
			if action_button_broken:
				action_button_broken.visible = false
			action_button.visible = true
			print("🔓 Кнопка 'Завершить' активирована")


func disable_action_button():
	"""Отключить action button (сделать некликабельной)"""
	if action_button and current_button_state == "complete":
		action_button.disabled = true
		# Скрываем основную кнопку и показываем broken версию
		action_button.visible = false
		if action_button_broken:
			# НЕ меняем позицию и размер - они настроены отдельно в сцене!
			# Только синхронизируем modulate для единообразия
			action_button_broken.modulate = action_button.modulate
			# Убеждаемся что кнопка активна и видна
			action_button_broken.disabled = false
			action_button_broken.visible = true
			# Принудительно обновляем дерево сцены
			action_button_broken.queue_redraw()
			print("🔒 Кнопка 'Завершить' дезактивирована (подменена на broken версию)")
			print("   Основная кнопка visible=%s, Broken кнопка visible=%s" % [action_button.visible, action_button_broken.visible])
			print("   Broken кнопка позиция: offset_left=%s, offset_top=%s, scale=%s" % [action_button_broken.offset_left, action_button_broken.offset_top, action_button_broken.scale])
			print("   Broken кнопка путь: %s" % action_button_broken.get_path())
		else:
			print("❌ ОШИБКА: action_button_broken == null! Кнопка не может быть подменена!")

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ LANG BUTTON
# ═══════════════════════════════════════════════════════════════════════════

func update_lang_button():
	"""Обновить текст кнопки языка (RU / EN)"""
	if lang_button:
		lang_button.text = Localization.get_lang().to_upper()

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ TIE BUTTON
# ═══════════════════════════════════════════════════════════════════════════

func show_tie_button():
	"""Показать кнопку Игалите (при раздаче карт)"""
	if tie_button:
		tie_button.visible = true
		# Обновляем текст при показе (на случай смены языка)
		tie_button.text = Localization.t("TIE_BUTTON")


func hide_tie_button():
	"""Скрыть кнопку Игалите (после завершения раундa)"""
	if tie_button:
		tie_button.visible = false


func enable_tie_button():
	"""Активировать кнопку Игалите (когда маркеры Player/Banker не выбраны)"""
	if tie_button:
		tie_button.visible = true   # при активации возвращаем на экран
		tie_button.disabled = false


func disable_tie_button():
	"""Деактивировать кнопку Игалите (когда выбран маркер Player или Banker)"""
	if tie_button:
		tie_button.disabled = true
		tie_button.visible = false  # скрываем полностью, а не просто делаем полупрозрачной


# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА BROKEN КНОПКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_broken_button_pressed():
	"""Обработчик нажатия на broken кнопку"""
	EventBus.show_toast_error.emit(Localization.t("PAY_FIRST"))
	print("🔒 Попытка завершить при неоплаченных ставках: 'Сначала оплати!'")


func is_action_button_broken() -> bool:
	"""Проверить, находится ли кнопка действия в broken состоянии"""
	if action_button_broken:
		return action_button_broken.visible and not action_button.visible
	return false

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КНОПКАМИ COLLECT/PAY
# ═══════════════════════════════════════════════════════════════════════════

func setup_collect_pay_buttons(scene: Node) -> void:
	"""Настроить кнопки сбора/оплаты ставок
	
	Args:
		scene: Корневой узел сцены Game.tscn
	
	Новая логика:
		- Кнопки работают как переключатели (не toggle)
		- При определении победителя показывается только CollectButton
		- Нажатие на кнопку переключает на другую кнопку и режим
	"""
	# Ищем кнопки в TopUI (CanvasLayer)
	var top_ui = scene.get_node_or_null("TopUI")
	if top_ui:
		collect_button = top_ui.get_node_or_null("CollectButton")
		pay_button = top_ui.get_node_or_null("PayButton")
	else:
		collect_button = scene.find_child("CollectButton", true, false)
		pay_button = scene.find_child("PayButton", true, false)
	
	# Настраиваем кнопки как обычные (не toggle)
	if collect_button:
		collect_button.toggle_mode = false
		collect_button.pressed.connect(_on_collect_button_pressed)
		collect_button.visible = false  # Скрываем до определения победителя
		print("✅ ButtonUIManager: CollectButton настроена (режим переключения)")
	else:
		print("⚠️  ButtonUIManager: CollectButton НЕ найдена!")
	
	if pay_button:
		# Проверяем, есть ли у PayButton свой скрипт (PayButton.gd)
		if pay_button.has_method("set_state_take") and pay_button.has_method("set_state_pay"):
			# PayButton имеет свой скрипт - подключаемся к его сигналу state_changed
			# НЕ подключаем pressed, так как PayButton сам управляет переключением
			if pay_button.has_signal("state_changed"):
				pay_button.state_changed.connect(_on_pay_button_state_changed)
			pay_button.visible = false  # Скрываем до определения победителя
			print("✅ ButtonUIManager: PayButton настроена (с кастомным скриптом, слушаем state_changed)")
		else:
			# Старая логика для кнопки без скрипта
			pay_button.toggle_mode = false
			pay_button.pressed.connect(_on_pay_button_pressed)
			pay_button.visible = false  # Скрываем до определения победителя
			print("✅ ButtonUIManager: PayButton настроена (режим переключения)")
	else:
		print("⚠️  ButtonUIManager: PayButton НЕ найдена!")


func _on_collect_button_pressed() -> void:
	"""Обработчик нажатия кнопки 'Забрать'
	
	Переключает на режим 'Оплатить':
	- Скрывает кнопку 'Забрать'
	- Показывает кнопку 'Оплатить'
	- Активирует режим PAY
	"""
	# Скрываем CollectButton, показываем PayButton
	if collect_button:
		collect_button.visible = false
	if pay_button:
		pay_button.visible = true
	
	# Переключаем режимы
	_collect_mode_active = false
	_pay_mode_active = true
	
	print("🔄 Переключение: COLLECT → PAY")
	
	# Эмитим сигналы для GameController
	collect_button_toggled.emit(false)
	pay_button_toggled.emit(true)


func _on_pay_button_state_changed(is_pay_mode: bool) -> void:
	"""Обработчик изменения состояния PayButton (сигнал от PayButton.gd)
	
	Args:
		is_pay_mode: true = режим PAY (Оплатить), false = режим COLLECT (Забрать)
	"""
	# Обновляем внутренние флаги
	_pay_mode_active = is_pay_mode
	_collect_mode_active = not is_pay_mode
	
	var mode_name = "PAY" if is_pay_mode else "COLLECT"
	print("🔄 PayButton изменил состояние: режим %s" % mode_name)
	
	# Эмитим сигналы для GameController
	pay_button_toggled.emit(is_pay_mode)
	collect_button_toggled.emit(not is_pay_mode)


func _on_pay_button_pressed() -> void:
	"""Обработчик нажатия кнопки 'Оплатить' (старая логика для кнопки без скрипта)
	
	Используется только если PayButton не имеет кастомного скрипта.
	"""
	# Старая логика: скрываем PayButton, показываем CollectButton
	if pay_button:
		pay_button.visible = false
	if collect_button:
		collect_button.visible = true
	
	# Переключаем режимы
	_pay_mode_active = false
	_collect_mode_active = true
	
	print("🔄 Переключение: PAY → COLLECT (старая логика)")
	
	# Эмитим сигналы для GameController
	pay_button_toggled.emit(false)
	collect_button_toggled.emit(true)


func get_collect_mode() -> bool:
	"""Проверить, активен ли режим сбора"""
	return _collect_mode_active


func get_pay_mode() -> bool:
	"""Проверить, активен ли режим оплаты"""
	return _pay_mode_active


func set_collect_mode(enabled: bool) -> void:
	"""Установить состояние режима сбора
	
	При включении автоматически отключает режим оплаты.
	Управляет видимостью кнопок в соответствии с новой логикой.
	"""
	if enabled:
		# Проверяем, есть ли у PayButton кастомный скрипт
		if pay_button and pay_button.has_method("set_state_take"):
			# PayButton имеет свой скрипт - используем его
			pay_button.visible = true
			pay_button.set_state_take()
		else:
			# Старая логика: показываем CollectButton, скрываем PayButton
			if collect_button:
				collect_button.visible = true
			if pay_button:
				pay_button.visible = false
		_collect_mode_active = true
		_pay_mode_active = false
		collect_button_toggled.emit(true)
		pay_button_toggled.emit(false)
	else:
		_collect_mode_active = false
		collect_button_toggled.emit(false)


func set_pay_mode(enabled: bool) -> void:
	"""Установить состояние режима оплаты
	
	При включении автоматически отключает режим сбора.
	Управляет видимостью кнопок в соответствии с новой логикой.
	"""
	if enabled:
		# Проверяем, есть ли у PayButton кастомный скрипт
		if pay_button and pay_button.has_method("set_state_pay"):
			# PayButton имеет свой скрипт - используем его
			pay_button.visible = true
			pay_button.set_state_pay()
		else:
			# Старая логика: показываем PayButton, скрываем CollectButton
			if pay_button:
				pay_button.visible = true
			if collect_button:
				collect_button.visible = false
		_pay_mode_active = true
		_collect_mode_active = false
		pay_button_toggled.emit(true)
		collect_button_toggled.emit(false)
	else:
		_pay_mode_active = false
		pay_button_toggled.emit(false)


func reset_collect_pay_buttons() -> void:
	"""Сбросить обе кнопки (скрыть и деактивировать режимы)"""
	if collect_button:
		collect_button.visible = false
	if pay_button:
		pay_button.visible = false
	_collect_mode_active = false
	_pay_mode_active = false
	print("🔄 Кнопки Collect/Pay сброшены и скрыты")


func show_collect_pay_buttons() -> void:
	"""Показать кнопку сбора и активировать режим COLLECT (после определения победителя)
	
	Новая логика:
		- Если PayButton имеет свой скрипт - используем его
		- Иначе показываем только CollectButton
		- Режим COLLECT активирован по умолчанию
	"""
	# Проверяем, есть ли у PayButton кастомный скрипт
	if pay_button and pay_button.has_method("set_state_take"):
		# PayButton имеет свой скрипт - используем его
		
		# Убеждаемся, что кнопка инициализирована
		if pay_button.has_method("ensure_initialized"):
			pay_button.ensure_initialized()
		
		pay_button.visible = true
		pay_button.set_state_take()  # Устанавливаем состояние "Забрать"
		
		# Синхронизируем состояние (эмитим сигнал для обновления флагов)
		if pay_button.has_method("sync_state"):
			pay_button.sync_state()
		else:
			# Если метода нет, обновляем вручную
			_collect_mode_active = true
			_pay_mode_active = false
			collect_button_toggled.emit(true)
		
		print("👁️ PayButton показана в состоянии 'Забрать', режим COLLECT активен")
	else:
		# Старая логика: показываем только CollectButton
		if collect_button:
			collect_button.visible = true
		if pay_button:
			pay_button.visible = false
		
		# Активируем режим COLLECT по умолчанию
		_collect_mode_active = true
		_pay_mode_active = false
		
		# Эмитим сигнал для GameController
		collect_button_toggled.emit(true)
		
		print("👁️ Кнопка 'Забрать' показана, режим COLLECT активен")


func hide_collect_pay_buttons() -> void:
	"""Скрыть кнопки сбора/оплаты"""
	if collect_button:
		collect_button.visible = false
	if pay_button:
		pay_button.visible = false
	print("🙈 Кнопки Collect/Pay скрыты")


func get_collect_pay_state() -> Dictionary:
	"""Получить состояние кнопок collect/pay"""
	return {
		"collect": _collect_mode_active,
		"pay": _pay_mode_active
	}


func update_collect_pay_buttons_text() -> void:
	"""Обновить текст кнопок collect/pay (при смене языка)
	
	Примечание: TextureButton не имеет текста, метод оставлен для совместимости
	"""
	pass  # TextureButton использует текстуры вместо текста
