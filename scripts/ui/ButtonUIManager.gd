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

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ КНОПОК
# ═══════════════════════════════════════════════════════════════════════════

var action_button: TextureButton  # Главная кнопка "Карты" / "Подтвердить" / "Завершить"
var action_button_broken: TextureButton  # Кнопка с broken текстурой (подмена при неоплаченных ставках)
var tie_button: Button            # Кнопка "Игалите" (появляется после раздачи)
var help_button: Button           # Кнопка помощи
var lang_button: Button           # Кнопка смены языка (опционально)

# Текущее состояние action button
var current_button_state: String = "start"

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
