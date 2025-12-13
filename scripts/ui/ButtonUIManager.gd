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
var collect_button: Button        # Кнопка "Забрать" (toggle)
var pay_button: Button            # Кнопка "Оплатить" (toggle)

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
		tie_button.disabled = false


func disable_tie_button():
	"""Деактивировать кнопку Игалите (когда выбран маркер Player или Banker)"""
	if tie_button:
		tie_button.disabled = true


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
	"""
	print("🔧 setup_collect_pay_buttons() вызван")
	print("   scene: %s" % (scene.name if scene else "null"))
	
	# Ищем кнопки в TopUI (CanvasLayer)
	var top_ui = scene.get_node_or_null("TopUI")
	if top_ui:
		print("   → TopUI найден: %s" % top_ui)
		collect_button = top_ui.get_node_or_null("CollectButton")
		pay_button = top_ui.get_node_or_null("PayButton")
		print("   → collect_button: %s" % collect_button)
		print("   → pay_button: %s" % pay_button)
	else:
		print("   → TopUI НЕ найден, ищем через find_child")
		collect_button = scene.find_child("CollectButton", true, false)
		pay_button = scene.find_child("PayButton", true, false)
		print("   → collect_button (find_child): %s" % collect_button)
		print("   → pay_button (find_child): %s" % pay_button)
	
	# Настраиваем кнопки как toggle
	if collect_button:
		collect_button.toggle_mode = true
		collect_button.toggled.connect(_on_collect_button_toggled)
		collect_button.button_pressed = false
		collect_button.visible = false  # Скрываем до определения победителя
		print("✅ ButtonUIManager: CollectButton найдена и настроена (скрыта)")
	else:
		print("⚠️  ButtonUIManager: CollectButton НЕ найдена в сцене!")
	
	if pay_button:
		pay_button.toggle_mode = true
		pay_button.toggled.connect(_on_pay_button_toggled)
		pay_button.button_pressed = false
		pay_button.visible = false  # Скрываем до определения победителя
		print("✅ ButtonUIManager: PayButton найдена и настроена (скрыта)")
	else:
		print("⚠️  ButtonUIManager: PayButton НЕ найдена в сцене!")


func _on_collect_button_toggled(pressed: bool) -> void:
	"""Обработчик toggle кнопки 'Забрать'"""
	if pressed:
		# При включении отключаем другую кнопку
		_collect_mode_active = true
		if pay_button and pay_button.button_pressed:
			pay_button.set_pressed_no_signal(false)
			_pay_mode_active = false
		print("🔄 Режим COLLECT включен")
	else:
		_collect_mode_active = false
		print("🔄 Режим COLLECT выключен")
	
	collect_button_toggled.emit(pressed)


func _on_pay_button_toggled(pressed: bool) -> void:
	"""Обработчик toggle кнопки 'Оплатить'"""
	if pressed:
		# При включении отключаем другую кнопку
		_pay_mode_active = true
		if collect_button and collect_button.button_pressed:
			collect_button.set_pressed_no_signal(false)
			_collect_mode_active = false
		print("🔄 Режим PAY включен")
	else:
		_pay_mode_active = false
		print("🔄 Режим PAY выключен")
	
	pay_button_toggled.emit(pressed)


func get_collect_mode() -> bool:
	"""Проверить, активен ли режим сбора"""
	return _collect_mode_active


func get_pay_mode() -> bool:
	"""Проверить, активен ли режим оплаты"""
	return _pay_mode_active


func set_collect_mode(enabled: bool) -> void:
	"""Установить состояние режима сбора
	
	При включении автоматически отключает режим оплаты.
	"""
	if collect_button:
		collect_button.button_pressed = enabled
		# Обработчик toggled вызовется автоматически


func set_pay_mode(enabled: bool) -> void:
	"""Установить состояние режима оплаты
	
	При включении автоматически отключает режим сбора.
	"""
	if pay_button:
		pay_button.button_pressed = enabled
		# Обработчик toggled вызовется автоматически


func reset_collect_pay_buttons() -> void:
	"""Сбросить обе кнопки (деактивировать и скрыть)"""
	if collect_button:
		collect_button.set_pressed_no_signal(false)
		collect_button.visible = false
	if pay_button:
		pay_button.set_pressed_no_signal(false)
		pay_button.visible = false
	_collect_mode_active = false
	_pay_mode_active = false
	print("🔄 Кнопки Collect/Pay сброшены и скрыты")


func show_collect_pay_buttons() -> void:
	"""Показать кнопки сбора/оплаты (после определения победителя)"""
	print("👁️ show_collect_pay_buttons() вызван")
	print("   collect_button: %s" % (collect_button != null))
	print("   pay_button: %s" % (pay_button != null))
	if collect_button:
		collect_button.visible = true
		print("   → CollectButton.visible = true")
	else:
		print("   ⚠️ collect_button is null!")
	if pay_button:
		pay_button.visible = true
		print("   → PayButton.visible = true")
	else:
		print("   ⚠️ pay_button is null!")
	print("👁️ Кнопки Collect/Pay показаны")


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
	"""Обновить текст кнопок collect/pay (при смене языка)"""
	if collect_button:
		collect_button.text = Localization.t("COLLECT_BUTTON")
	if pay_button:
		pay_button.text = Localization.t("PAY_BUTTON")
