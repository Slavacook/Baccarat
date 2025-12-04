# res://scripts/ui/ToggleUIManager.gd
# Специализированный менеджер для управления переключателями третьих карт
# Часть декомпозиции UIManager (Phase 2)

class_name ToggleUIManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal player_third_toggled(selected: bool)
signal banker_third_toggled(selected: bool)

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ TOGGLES
# ═══════════════════════════════════════════════════════════════════════════

var player_third_toggle: TextureRect
var banker_third_toggle: TextureRect

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var card_manager: CardTextureManager  # Для текстур ?, !, рубашка

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(scene: Node, cm: CardTextureManager):
	"""Инициализация менеджера переключателей

	Args:
		scene: Корневой узел сцены Game.tscn
		cm: CardTextureManager для загрузки текстур
	"""
	card_manager = cm

	# Получаем ссылки на UI узлы toggles
	player_third_toggle = scene.get_node("PlayerZone/PlayerThirdCardToggle")
	banker_third_toggle = scene.get_node("BankerZone/BankerThirdCardToggle")

	# Подключаем обработчики кликов
	player_third_toggle.gui_input.connect(_on_player_toggle_input)
	banker_third_toggle.gui_input.connect(_on_banker_toggle_input)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ КЛИКОВ
# ═══════════════════════════════════════════════════════════════════════════

func _on_player_toggle_input(event):
	"""Обработка клика по переключателю третьей карты игрока"""
	if event is InputEventMouseButton and event.pressed:
		player_third_toggled.emit(true)  # Эмитим событие (логику выбора обработает GamePhaseManager)


func _on_banker_toggle_input(event):
	"""Обработка клика по переключателю третьей карты банкира"""
	if event is InputEventMouseButton and event.pressed:
		banker_third_toggled.emit(true)

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ СОСТОЯНИЕМ TOGGLES
# ═══════════════════════════════════════════════════════════════════════════

func update_player_third_card_ui(state: String, card: Card = null):
	"""Обновление UI переключателя третьей карты игрока

	Состояния:
		- "hidden": toggle скрыт (карта не нужна или уже открыта)
		- "?": toggle показан с текстурой ? (можно заказать карту)
		- "!": toggle показан с текстурой ! (карта заказана, ожидает подтверждения)
		- "card": toggle скрыт, карта открыта (card != null)

	Args:
		state: Состояние toggle ("hidden", "?", "!", "card")
		card: Карта для отображения (если state == "card")
	"""
	if state == "hidden":
		player_third_toggle.visible = false
	elif state == "?":
		player_third_toggle.visible = true
		player_third_toggle.texture = card_manager.get_back_question_texture()
		player_third_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	elif state == "!":
		player_third_toggle.visible = true
		player_third_toggle.texture = card_manager.get_back_exclamation_texture()
		player_third_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	elif state == "card" and card != null:
		player_third_toggle.visible = false  # Как только карта открыта — тумблер полностью исчезает!


func update_banker_third_card_ui(state: String, card: Card = null):
	"""Обновление UI переключателя третьей карты банкира

	Состояния:
		- "hidden": toggle скрыт (карта не нужна или уже открыта)
		- "?": toggle показан с текстурой ? (можно заказать карту)
		- "!": toggle показан с текстурой ! (карта заказана, ожидает подтверждения)
		- "card": toggle скрыт, карта открыта (card != null)

	Args:
		state: Состояние toggle ("hidden", "?", "!", "card")
		card: Карта для отображения (если state == "card")
	"""
	if state == "hidden":
		banker_third_toggle.visible = false
	elif state == "?":
		banker_third_toggle.visible = true
		banker_third_toggle.texture = card_manager.get_back_question_texture()
		banker_third_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	elif state == "!":
		banker_third_toggle.visible = true
		banker_third_toggle.texture = card_manager.get_back_exclamation_texture()
		banker_third_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	elif state == "card" and card != null:
		banker_third_toggle.visible = false

# ═══════════════════════════════════════════════════════════════════════════
# СБРОС TOGGLES
# ═══════════════════════════════════════════════════════════════════════════

func reset_toggles():
	"""Сброс toggles к начальному состоянию (видимые, с текстурой ?)"""
	player_third_toggle.visible = true
	banker_third_toggle.visible = true
	update_player_third_card_ui("?")
	update_banker_third_card_ui("?")
