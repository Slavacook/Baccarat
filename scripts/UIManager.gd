# res://scripts/UIManager.gd
# Фасад-агрегатор для управления всеми UI элементами
# Делегирует работу специализированным менеджерам (Phase 2 Refactoring)

class_name UIManager
extends RefCounted

const HandScoreHintPresenterScript = preload("res://scripts/ui/HandScoreHintPresenter.gd")
const HandDecisionScalePresenterScript = preload("res://scripts/ui/HandDecisionScalePresenter.gd")
const InspectorHintPresenterScript = preload("res://scripts/ui/InspectorHintPresenter.gd")

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
signal first_four_reveal_completed()
signal player_third_reveal_completed()
signal banker_third_reveal_completed()
# TieMarker теперь обрабатывается через WinnerSelectionManager

# ═══════════════════════════════════════════════════════════════════════════
# СПЕЦИАЛИЗИРОВАННЫЕ МЕНЕДЖЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

var card_manager: CardTextureManager    # Менеджер текстур карт (для update_all_card_backs)
var card_ui: CardUIManager              # Управление картами и анимациями
var toggle_ui: ToggleUIManager          # Управление toggles третьих карт
var button_ui: ButtonUIManager          # Управление кнопками
var marker_ui: MarkerUIManager          # Управление маркерами победителя
var payout_toggle_ui: PayoutToggleManager  # Управление переключателями выплат
var hand_score_hint_presenter: RefCounted   # Минимальный presenter сумм под руками
var hand_decision_scale_presenter: RefCounted  # Визуальные шкалы решений 0-9
var inspector_hint_presenter: RefCounted    # Постоянная верхняя строка инспектора
var training_hints_enabled: bool = true     # Глобальный флаг показа учебных подсказок

# ═══════════════════════════════════════════════════════════════════════════
# ПРЯМЫЕ ССЫЛКИ НА UI УЗЛЫ (для обратной совместимости)
# ═══════════════════════════════════════════════════════════════════════════

# Эти узлы используются напрямую другими классами (StatsManager, popups, etc.)
var stats_label: Label
var help_popup: Popup
var bet_chip: TextureButton
var tie_chip: TextureButton

# ← Эти ссылки сохранены для внешнего доступа (GameController, GamePhaseManager)
var action_button: TextureButton
# TieMarker теперь управляется через WinnerSelectionManager
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
var player_score_hint_label: Label
var banker_score_hint_label: Label
var player_decision_scale_container: Control
var banker_decision_scale_container: Control
var inspector_hint_panel: Control
var inspector_hint_label: Label

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(scene: Node, card_manager_ref: CardTextureManager):
	"""Инициализация UIManager и всех дочерних менеджеров

	Создаёт специализированные менеджеры и пробрасывает их сигналы.

	Args:
		scene: Корневой узел сцены Game.tscn
		card_manager_ref: CardTextureManager для загрузки текстур карт
	"""
	# Сохраняем ссылку на CardTextureManager
	card_manager = card_manager_ref

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
	# TieMarker теперь в WinnerSelectionManager
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
	player_score_hint_label = scene.get_node_or_null("PlayerZone/ScoreHintLabel")
	banker_score_hint_label = scene.get_node_or_null("BankerZone/ScoreHintLabel")
	player_decision_scale_container = scene.get_node_or_null("PlayerZone/DecisionScaleContainer")
	banker_decision_scale_container = scene.get_node_or_null("BankerZone/DecisionScaleContainer")
	inspector_hint_panel = scene.get_node_or_null("TopUI/InspectorHintPanel")
	inspector_hint_label = scene.get_node_or_null("TopUI/InspectorHintPanel/MarginContainer/InspectorHintLabel")

	# Минимальный presenter для текста сумм под руками
	hand_score_hint_presenter = HandScoreHintPresenterScript.new()
	if hand_score_hint_presenter:
		hand_score_hint_presenter.setup(player_score_hint_label, banker_score_hint_label)

	# Визуальные шкалы решения 0-9
	hand_decision_scale_presenter = HandDecisionScalePresenterScript.new()
	if hand_decision_scale_presenter:
		hand_decision_scale_presenter.setup(player_decision_scale_container, banker_decision_scale_container)

	# Постоянная верхняя строка инспектора
	inspector_hint_presenter = InspectorHintPresenterScript.new()
	if inspector_hint_presenter:
		inspector_hint_presenter.setup(inspector_hint_panel, inspector_hint_label)

	# ═══════════════════════════════════════════════════════════════════
	# ШАГ 3: Проброс сигналов от дочерних менеджеров
	# ═══════════════════════════════════════════════════════════════════

	# От ButtonUIManager
	button_ui.action_button_pressed.connect(
		func(): action_button_pressed.emit()
	)
	# TieMarker теперь обрабатывается через WinnerSelectionManager
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

	# От CardUIManager
	card_ui.first_four_reveal_completed.connect(
		func(): first_four_reveal_completed.emit()
	)
	card_ui.player_third_reveal_completed.connect(
		func(): player_third_reveal_completed.emit()
	)
	card_ui.banker_third_reveal_completed.connect(
		func(): banker_third_reveal_completed.emit()
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


func hide_third_cards():
	"""Скрыть третьи карты (для Third Card Change)"""
	card_ui.hide_third_cards()

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ-ДЕЛЕГАТЫ: УПРАВЛЕНИЕ TOGGLES (→ ToggleUIManager)
# ═══════════════════════════════════════════════════════════════════════════

func update_player_third_card_ui(state: String, card: Card = null):
	"""Обновление UI переключателя третьей карты игрока"""
	toggle_ui.update_player_third_card_ui(state, card)


func update_banker_third_card_ui(state: String, card: Card = null):
	"""Обновление UI переключателя третьей карты банкира"""
	toggle_ui.update_banker_third_card_ui(state, card)

func update_hand_score_hints(payload: Dictionary):
	"""Обновить минимальные подписи сумм под руками из готового hint payload"""
	if not training_hints_enabled:
		reset_hand_score_hints()
		return
	if hand_score_hint_presenter:
		hand_score_hint_presenter.update_from_hint_payload(payload)

func reset_hand_score_hints():
	"""Сбросить подписи сумм под руками в пустое состояние"""
	if hand_score_hint_presenter:
		hand_score_hint_presenter.reset()

func update_hand_decision_scales(payload: Dictionary):
	"""Обновить визуальные шкалы решения под руками из готового hint payload"""
	if not training_hints_enabled:
		reset_hand_decision_scales()
		return
	if hand_decision_scale_presenter:
		hand_decision_scale_presenter.update_from_hint_payload(payload)

func reset_hand_decision_scales():
	"""Скрыть визуальные шкалы решения и сбросить подсветку"""
	if hand_decision_scale_presenter:
		hand_decision_scale_presenter.reset()

func update_inspector_hint(payload: Dictionary):
	"""Обновить постоянную верхнюю строку инспектора из готового hint payload"""
	if not training_hints_enabled:
		reset_inspector_hint()
		return
	if inspector_hint_presenter:
		inspector_hint_presenter.update_from_hint_payload(payload)

func reset_inspector_hint():
	"""Скрыть строку инспектора и очистить текст"""
	if inspector_hint_presenter:
		inspector_hint_presenter.reset()

func set_training_hints_enabled(enabled: bool) -> void:
	"""Включить или выключить все учебные подсказки дилера"""
	training_hints_enabled = enabled
	if not enabled:
		reset_hand_score_hints()
		reset_hand_decision_scales()
		reset_inspector_hint()

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
# TieMarker теперь управляется через WinnerSelectionManager
# (show/hide/enable/disable методы удалены)
# ═══════════════════════════════════════════════════════════════════════════


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

	# Сброс подписей сумм под руками
	reset_hand_score_hints()

	# Сброс визуальных шкал решений
	reset_hand_decision_scales()

	# Сброс строки инспектора
	reset_inspector_hint()

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ РУБАШЕК КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func update_all_card_backs():
	"""Обновить текстуры всех рубашек карт при смене стиля

	Вызывается при изменении настройки рубашки (Тигр/Леопард).
	Обновляет ВСЕ карты и toggles которые показывают рубашку.
	"""
	# Получаем новую текстуру рубашки из CardTextureManager
	var new_back_texture = card_manager.get_back_texture()

	# Обновляем ВСЕ карты через единый метод
	_update_single_card_back(player_card1, new_back_texture)
	_update_single_card_back(player_card2, new_back_texture)
	_update_single_card_back(player_card3, new_back_texture)
	_update_single_card_back(banker_card1, new_back_texture)
	_update_single_card_back(banker_card2, new_back_texture)
	_update_single_card_back(banker_card3, new_back_texture)

	# Обновляем toggles третьих карт
	if player_third_toggle:
		_update_single_card_back(player_third_toggle, new_back_texture)
	if banker_third_toggle:
		_update_single_card_back(banker_third_toggle, new_back_texture)

	print("🎴 Рубашки всех карт обновлены")

func _update_single_card_back(card: TextureRect, new_back: Texture2D):
	"""Обновить одну карту если она показывает рубашку"""
	if not card or not card.texture:
		return

	# Загружаем ОБЕ возможные рубашки (тигр и леопард)
	var tiger_back = load("res://assets/cards/back/card_back.png")
	var leopard_back = load("res://assets/cards/back/card_back_2.png")
	var question = card_manager.get_back_question_texture()
	var exclamation = card_manager.get_back_exclamation_texture()

	# Проверяем показывает ли карта рубашку (любую: тигр, леопард, ?, !)
	if card.texture == tiger_back or card.texture == leopard_back:
		# Обычная рубашка → меняем на новую
		card.texture = new_back
	elif card.texture == question:
		# ? рубашка → обновляем (могла измениться)
		card.texture = card_manager.get_back_question_texture()
	elif card.texture == exclamation:
		# ! рубашка → обновляем (могла измениться)
		card.texture = card_manager.get_back_exclamation_texture()
