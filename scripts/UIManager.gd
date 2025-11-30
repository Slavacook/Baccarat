# res://scripts/UIManager.gd

class_name UIManager
extends RefCounted

signal action_button_pressed()
signal player_third_toggled(selected: bool)
signal banker_third_toggled(selected: bool)
signal winner_selected(winner: String)
signal help_button_pressed()
signal lang_button_pressed()

var action_button: Button
var player_card1: TextureRect
var player_card2: TextureRect
var player_card3: TextureRect
var banker_card1: TextureRect
var banker_card2: TextureRect
var banker_card3: TextureRect
var player_third_toggle: TextureRect
var banker_third_toggle: TextureRect
var help_button: Button
var help_popup: Popup
var player_marker: Control
var banker_marker: Control
var tie_marker: Control
var stats_label: Label
var lang_button: Button
var bet_chip: TextureButton
var bet_popup: PopupPanel
var card_manager: CardTextureManager
var tie_chip: TextureButton
var flip_cards = []
var main_node = null

# Переключатели выплат
var payout_toggle_player: Button
var payout_toggle_banker: Button
var payout_toggle_tie: Button

func _init(scene: Node, cm: CardTextureManager):
	card_manager = cm

	action_button = scene.get_node("CardsButton")
	player_card1 = scene.get_node("PlayerZone/Card1")
	player_card2 = scene.get_node("PlayerZone/Card2")
	player_card3 = scene.get_node("PlayerZone/Card3")
	banker_card1 = scene.get_node("BankerZone/Card1")
	banker_card2 = scene.get_node("BankerZone/Card2")
	banker_card3 = scene.get_node("BankerZone/Card3")
	player_third_toggle = scene.get_node("PlayerZone/PlayerThirdCardToggle")
	banker_third_toggle = scene.get_node("BankerZone/BankerThirdCardToggle")
	help_button = scene.get_node("HelpButton")
	help_popup = scene.get_node("HelpPopup")
	player_marker = scene.get_node("PlayerMarker")
	banker_marker = scene.get_node("BankerMarker")
	tie_marker = scene.get_node("TieMarker")
	stats_label = scene.get_node("StatsLabel")

	if scene.has_node("LangButton"):
		lang_button = scene.get_node("LangButton")
		lang_button.pressed.connect(func(): lang_button_pressed.emit())



	action_button.pressed.connect(func(): action_button_pressed.emit())
	player_third_toggle.gui_input.connect(_on_player_toggle_input)
	banker_third_toggle.gui_input.connect(_on_banker_toggle_input)
	help_button.pressed.connect(func(): help_button_pressed.emit())

	connect_winner_button(player_marker, "Player")
	connect_winner_button(banker_marker, "Banker")
	connect_winner_button(tie_marker, "Tie")



	# Инициализация переключателей выплат (если они есть в сцене)
	if scene.has_node("PayoutTogglePlayer"):
		payout_toggle_player = scene.get_node("PayoutTogglePlayer")
		payout_toggle_player.toggle_mode = true
		payout_toggle_player.button_pressed = PayoutSettingsManager.player_payout_enabled
		payout_toggle_player.toggled.connect(_on_payout_player_toggled)
		_update_payout_toggle_style(payout_toggle_player, PayoutSettingsManager.player_payout_enabled, GameConstants.PAYOUT_TOGGLE_COLOR_PLAYER)

	if scene.has_node("PayoutToggleBanker"):
		payout_toggle_banker = scene.get_node("PayoutToggleBanker")
		payout_toggle_banker.toggle_mode = true
		payout_toggle_banker.button_pressed = PayoutSettingsManager.banker_payout_enabled
		payout_toggle_banker.toggled.connect(_on_payout_banker_toggled)
		_update_payout_toggle_style(payout_toggle_banker, PayoutSettingsManager.banker_payout_enabled, GameConstants.PAYOUT_TOGGLE_COLOR_BANKER)

	if scene.has_node("PayoutToggleTie"):
		payout_toggle_tie = scene.get_node("PayoutToggleTie")
		payout_toggle_tie.toggle_mode = true
		payout_toggle_tie.button_pressed = PayoutSettingsManager.tie_payout_enabled
		payout_toggle_tie.toggled.connect(_on_payout_tie_toggled)
		_update_payout_toggle_style(payout_toggle_tie, PayoutSettingsManager.tie_payout_enabled, GameConstants.PAYOUT_TOGGLE_COLOR_TIE)

func set_flip_cards(cards):
	flip_cards = cards

func set_main_node(node):
	main_node = node

func _on_player_toggle_input(event):
	if event is InputEventMouseButton and event.pressed:
		player_third_toggled.emit(true)  # логика выбора через GamePhaseManager

func _on_banker_toggle_input(event):
	if event is InputEventMouseButton and event.pressed:
		banker_third_toggled.emit(true)

func connect_winner_button(button: Control, winner: String):
	button.pressed.connect(func(): winner_selected.emit(winner))

func show_first_four_cards(player_hand: Array[Card], banker_hand: Array[Card]):
	player_card1.visible = false
	flip_cards[0].visible = true
	flip_cards[0].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	player_card1.texture = player_hand[0].get_texture(card_manager)
	player_card1.visible = true
	flip_cards[0].visible = false

	player_card2.visible = false
	flip_cards[1].visible = true
	flip_cards[1].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	player_card2.texture = player_hand[1].get_texture(card_manager)
	player_card2.visible = true
	flip_cards[1].visible = false

	banker_card1.visible = false
	flip_cards[2].visible = true
	flip_cards[2].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	banker_card1.texture = banker_hand[0].get_texture(card_manager)
	banker_card1.visible = true
	flip_cards[2].visible = false

	banker_card2.visible = false
	flip_cards[3].visible = true
	flip_cards[3].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	banker_card2.texture = banker_hand[1].get_texture(card_manager)
	banker_card2.visible = true
	flip_cards[3].visible = false

func show_player_third_card(card: Card):
	player_card3.visible = false
	flip_cards[4].visible = true
	flip_cards[4].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	player_card3.texture = card.get_texture(card_manager)
	player_card3.visible = true
	flip_cards[4].visible = false

func show_banker_third_card(card: Card):
	banker_card3.visible = false
	flip_cards[5].visible = true
	flip_cards[5].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	banker_card3.texture = card.get_texture(card_manager)
	banker_card3.visible = true
	flip_cards[5].visible = false

func reset_ui():
	_hide_all_cards()
	_show_initial_backs()
	player_third_toggle.visible = true
	banker_third_toggle.visible = true
	update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
	action_button.disabled = false

func _hide_all_cards():
	player_card1.visible = false
	player_card2.visible = false
	player_card3.visible = false
	banker_card1.visible = false
	banker_card2.visible = false
	banker_card3.visible = false

func _show_initial_backs():
	var back = card_manager.get_back_texture()
	player_card1.texture = back
	player_card2.texture = back
	banker_card1.texture = back
	banker_card2.texture = back
	player_card1.visible = true
	player_card2.visible = true
	banker_card1.visible = true
	banker_card2.visible = true

# Универсальные функции для управления состоянием тумблера заказа третьей карты (ТЕПЕРЬ БЕЗ ПРОЗРАЧНОСТИ!)
func update_player_third_card_ui(state: String, card: Card = null):
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
	

func update_action_button(text: String):
	action_button.text = text

func enable_action_button():
	action_button.disabled = false

func disable_action_button():
	action_button.disabled = true

func update_lang_button():
	if lang_button:
		lang_button.text = Localization.get_lang().to_upper()

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕКЛЮЧАТЕЛИ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

# ← Обработчик переключателя Player
func _on_payout_player_toggled(enabled: bool):
	PayoutSettingsManager.toggle_player(enabled)
	_update_payout_toggle_style(payout_toggle_player, enabled, GameConstants.PAYOUT_TOGGLE_COLOR_PLAYER)

# ← Обработчик переключателя Banker
func _on_payout_banker_toggled(enabled: bool):
	PayoutSettingsManager.toggle_banker(enabled)
	_update_payout_toggle_style(payout_toggle_banker, enabled, GameConstants.PAYOUT_TOGGLE_COLOR_BANKER)

# ← Обработчик переключателя Tie
func _on_payout_tie_toggled(enabled: bool):
	PayoutSettingsManager.toggle_tie(enabled)
	_update_payout_toggle_style(payout_toggle_tie, enabled, GameConstants.PAYOUT_TOGGLE_COLOR_TIE)

# ← Обновление визуального стиля переключателя
func _update_payout_toggle_style(button: Button, enabled: bool, color: Color):
	if not button:
		return

	# Создаём или обновляем StyleBox
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 0.5)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("pressed", style_normal)

	# Прозрачность кнопки
	button.modulate.a = 1.0 if enabled else GameConstants.PAYOUT_TOGGLE_DISABLED_ALPHA
