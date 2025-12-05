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

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ КНОПОК
# ═══════════════════════════════════════════════════════════════════════════

var action_button: TextureButton  # Главная кнопка "Карты" / "Подтвердить" / "Завершить"
var help_button: Button           # Кнопка помощи
var lang_button: Button           # Кнопка смены языка (опционально)

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

	print("🔘 Кнопка: %s" % state)


func enable_action_button():
	"""Включить action button (сделать кликабельной)"""
	if action_button:
		action_button.disabled = false


func disable_action_button():
	"""Отключить action button (сделать некликабельной)"""
	if action_button:
		action_button.disabled = true

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ LANG BUTTON
# ═══════════════════════════════════════════════════════════════════════════

func update_lang_button():
	"""Обновить текст кнопки языка (RU / EN)"""
	if lang_button:
		lang_button.text = Localization.get_lang().to_upper()
