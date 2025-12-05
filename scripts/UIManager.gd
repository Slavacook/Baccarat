# res://scripts/UIManager.gd
# Фасад-агрегатор для управления всеми UI элементами
# Делегирует работу специализированным менеджерам (Phase 2 Refactoring)

class_name UIManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ (Публичный API - проброс от дочерних менеджеров)
# ═══════════════════════════════════════════════════════════════════════════

signal action_button_pressed()
signal player_third_toggled(selected: bool)
signal banker_third_toggled(selected: bool)
@warning_ignore("unused_signal")
signal winner_selected(winner: String)
signal help_button_pressed()
signal lang_button_pressed()

# ═══════════════════════════════════════════════════════════════════════════
# СПЕЦИАЛИЗИРОВАННЫЕ МЕНЕДЖЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

var card_ui: CardUIManager              # Управление картами и анимациями
var toggle_ui: ToggleUIManager          # Управление toggles третьих карт
var button_ui: ButtonUIManager          # Управление кнопками
var marker_ui: MarkerUIManager          # Управление маркерами победителя
var payout_toggle_ui: PayoutToggleManager  # Управление переключателями выплат

# ═══════════════════════════════════════════════════════════════════════════
# ПРЯМЫЕ ССЫЛКИ НА UI УЗЛЫ (для обратной совместимости)
# ═══════════════════════════════════════════════════════════════════════════

# Эти узлы используются напрямую другими классами (StatsManager, popups, etc.)
var stats_label: Label
var help_popup: Popup
var bet_chip: TextureButton
var bet_popup: PopupPanel
var tie_chip: TextureButton

# ← Эти ссылки сохранены для внешнего доступа (GameController, GamePhaseManager)
var action_button: TextureButton
var help_button: Button
var player_third_toggle: TextureRect
var banker_third_toggle: TextureRect

# ← Узлы карт (для прямого доступа в _restore_cards_ui)
var player_card1: TextureRect
var player_card2: TextureRect
var player_card3: TextureRect
var banker_card1: TextureRect
var banker_card2: TextureRect
var banker_card3: TextureRect

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(scene: Node, card_manager: CardTextureManager):
	"""Инициализация UIManager и всех дочерних менеджеров

	Создаёт специализированные менеджеры и пробрасывает их сигналы.

	Args:
		scene: Корневой узел сцены Game.tscn
		card_manager: CardTextureManager для загрузки текстур карт
	"""
	# ═══════════════════════════════════════════════════════════════════
	# ШАГ 1: Создание специализированных менеджеров
	# ═══════════════════════════════════════════════════════════════════

	card_ui = CardUIManager.new(scene, card_manager)
	toggle_ui = ToggleUIManager.new(scene, card_manager)
	button_ui = ButtonUIManager.new(scene)
	marker_ui = MarkerUIManager.new(scene)
	payout_toggle_ui = PayoutToggleManager.new(scene)

	# ═══════════════════════════════════════════════════════════════════
	# ШАГ 2: Получение прямых ссылок (для обратной совместимости)
	# ═══════════════════════════════════════════════════════════════════

	stats_label = scene.get_node("StatsLabel")
	help_popup = scene.get_node("HelpPopup")

	# Эти ссылки используются для прямого доступа извне
	action_button = button_ui.action_button
	help_button = button_ui.help_button
	player_third_toggle = toggle_ui.player_third_toggle
	banker_third_toggle = toggle_ui.banker_third_toggle

	# Узлы карт (для _restore_cards_ui в GameController)
	player_card1 = card_ui.player_card1
	player_card2 = card_ui.player_card2
	player_card3 = card_ui.player_card3
	banker_card1 = card_ui.banker_card1
	banker_card2 = card_ui.banker_card2
	banker_card3 = card_ui.banker_card3

	# ═══════════════════════════════════════════════════════════════════
	# ШАГ 3: Проброс сигналов от дочерних менеджеров
	# ═══════════════════════════════════════════════════════════════════

	# От ButtonUIManager
	button_ui.action_button_pressed.connect(
		func(): action_button_pressed.emit()
	)
	button_ui.help_button_pressed.connect(
		func(): help_button_pressed.emit()
	)
	button_ui.lang_button_pressed.connect(
		func(): lang_button_pressed.emit()
	)

	# От ToggleUIManager
	toggle_ui.player_third_toggled.connect(
		func(selected): player_third_toggled.emit(selected)
	)
	toggle_ui.banker_third_toggled.connect(
		func(selected): banker_third_toggled.emit(selected)
	)

	# От MarkerUIManager (в текущей архитектуре не используется, но оставляем для совместимости)
	# winner_selected эмитится через WinnerSelectionManager

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ-ДЕЛЕГАТЫ: УПРАВЛЕНИЕ КАРТАМИ (→ CardUIManager)
# ═══════════════════════════════════════════════════════════════════════════

func show_first_four_cards(player_hand: Array[Card], banker_hand: Array[Card]):
	"""Анимация раздачи первых четырёх карт"""
	card_ui.show_first_four_cards(player_hand, banker_hand)


func show_player_third_card(card: Card):
	"""Анимация раздачи третьей карты игроку"""
	card_ui.show_player_third_card(card)


func show_banker_third_card(card: Card):
	"""Анимация раздачи третьей карты банкиру"""
	card_ui.show_banker_third_card(card)


func set_flip_cards(cards):
	"""Установить массив анимаций переворота карт"""
	card_ui.set_flip_cards(cards)


func set_main_node(node):
	"""Установить главный узел для await"""
	card_ui.set_main_node(node)

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ-ДЕЛЕГАТЫ: УПРАВЛЕНИЕ TOGGLES (→ ToggleUIManager)
# ═══════════════════════════════════════════════════════════════════════════

func update_player_third_card_ui(state: String, card: Card = null):
	"""Обновление UI переключателя третьей карты игрока"""
	toggle_ui.update_player_third_card_ui(state, card)


func update_banker_third_card_ui(state: String, card: Card = null):
	"""Обновление UI переключателя третьей карты банкира"""
	toggle_ui.update_banker_third_card_ui(state, card)

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ-ДЕЛЕГАТЫ: УПРАВЛЕНИЕ КНОПКАМИ (→ ButtonUIManager)
# ═══════════════════════════════════════════════════════════════════════════

func update_action_button(text: String):
	"""Обновление текста action button (legacy для совместимости)"""
	button_ui.update_action_button(text)


func set_action_button_state(state: String):
	"""Установить состояние action button (start/confirm/complete)"""
	button_ui.set_action_button_state(state)


func get_action_button_state() -> String:
	"""Получить текущее состояние action button"""
	return button_ui.get_action_button_state()


func enable_action_button():
	"""Включить action button"""
	button_ui.enable_action_button()


func disable_action_button():
	"""Отключить action button"""
	button_ui.disable_action_button()


func update_lang_button():
	"""Обновить текст кнопки языка"""
	button_ui.update_lang_button()

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ-ДЕЛЕГАТЫ: УПРАВЛЕНИЕ МАРКЕРАМИ (→ MarkerUIManager)
# ═══════════════════════════════════════════════════════════════════════════

func connect_winner_button(button: Control, winner: String):
	"""Подключить обработчик клика к маркеру (DEPRECATED)"""
	marker_ui.connect_winner_button(button, winner)

# ═══════════════════════════════════════════════════════════════════════════
# СБРОС UI К НАЧАЛЬНОМУ СОСТОЯНИЮ
# ═══════════════════════════════════════════════════════════════════════════

func reset_ui():
	"""Сброс всех UI элементов к начальному состоянию

	Вызывается при старте нового раунда.
	Координирует сброс всех дочерних менеджеров.
	"""
	# Сброс карт
	card_ui.reset_cards()

	# Сброс toggles третьих карт
	toggle_ui.reset_toggles()

	# Сброс кнопки действия
	button_ui.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	button_ui.enable_action_button()
