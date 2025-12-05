# res://scripts/ui/PayoutToggleManager.gd
# Специализированный менеджер для управления переключателями выплат
# Часть декомпозиции UIManager (Phase 2)

class_name PayoutToggleManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ ПЕРЕКЛЮЧАТЕЛЕЙ
# ═══════════════════════════════════════════════════════════════════════════

var payout_toggle_player: Button
var payout_toggle_banker: Button
var payout_toggle_tie: Button
var payout_toggle_player_pair: Button
var payout_toggle_banker_pair: Button

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(scene: Node):
	"""Инициализация менеджера переключателей выплат

	Args:
		scene: Корневой узел сцены Game.tscn
	"""
	# Переключатели выплат опциональны (могут отсутствовать в сцене)
	if scene.has_node("PayoutTogglePlayer"):
		payout_toggle_player = scene.get_node("PayoutTogglePlayer")
		payout_toggle_player.toggle_mode = true
		payout_toggle_player.button_pressed = PayoutSettingsManager.player_payout_enabled
		payout_toggle_player.toggled.connect(_on_payout_player_toggled)
		_update_payout_toggle_style(
			payout_toggle_player,
			PayoutSettingsManager.player_payout_enabled,
			GameConstants.PAYOUT_TOGGLE_COLOR_PLAYER
		)

	if scene.has_node("PayoutToggleBanker"):
		payout_toggle_banker = scene.get_node("PayoutToggleBanker")
		payout_toggle_banker.toggle_mode = true
		payout_toggle_banker.button_pressed = PayoutSettingsManager.banker_payout_enabled
		payout_toggle_banker.toggled.connect(_on_payout_banker_toggled)
		_update_payout_toggle_style(
			payout_toggle_banker,
			PayoutSettingsManager.banker_payout_enabled,
			GameConstants.PAYOUT_TOGGLE_COLOR_BANKER
		)

	if scene.has_node("PayoutToggleTie"):
		payout_toggle_tie = scene.get_node("PayoutToggleTie")
		payout_toggle_tie.toggle_mode = true
		payout_toggle_tie.button_pressed = PayoutSettingsManager.tie_payout_enabled
		payout_toggle_tie.toggled.connect(_on_payout_tie_toggled)
		_update_payout_toggle_style(
			payout_toggle_tie,
			PayoutSettingsManager.tie_payout_enabled,
			GameConstants.PAYOUT_TOGGLE_COLOR_TIE
		)

	if scene.has_node("PayoutTogglePairPlayer"):
		payout_toggle_player_pair = scene.get_node("PayoutTogglePairPlayer")
		payout_toggle_player_pair.toggle_mode = true
		payout_toggle_player_pair.button_pressed = PayoutSettingsManager.player_pair_payout_enabled
		payout_toggle_player_pair.toggled.connect(_on_payout_player_pair_toggled)
		_update_payout_toggle_style(
			payout_toggle_player_pair,
			PayoutSettingsManager.player_pair_payout_enabled,
			GameConstants.PAYOUT_TOGGLE_COLOR_PLAYER
		)

	if scene.has_node("PayoutTogglePairBanker"):
		payout_toggle_banker_pair = scene.get_node("PayoutTogglePairBanker")
		payout_toggle_banker_pair.toggle_mode = true
		payout_toggle_banker_pair.button_pressed = PayoutSettingsManager.banker_pair_payout_enabled
		payout_toggle_banker_pair.toggled.connect(_on_payout_banker_pair_toggled)
		_update_payout_toggle_style(
			payout_toggle_banker_pair,
			PayoutSettingsManager.banker_pair_payout_enabled,
			GameConstants.PAYOUT_TOGGLE_COLOR_BANKER
		)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ ПЕРЕКЛЮЧАТЕЛЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_payout_player_toggled(enabled: bool):
	"""Обработка переключателя выплаты Player"""
	PayoutSettingsManager.toggle_player(enabled)
	_update_payout_toggle_style(
		payout_toggle_player,
		enabled,
		GameConstants.PAYOUT_TOGGLE_COLOR_PLAYER
	)


func _on_payout_banker_toggled(enabled: bool):
	"""Обработка переключателя выплаты Banker"""
	PayoutSettingsManager.toggle_banker(enabled)
	_update_payout_toggle_style(
		payout_toggle_banker,
		enabled,
		GameConstants.PAYOUT_TOGGLE_COLOR_BANKER
	)


func _on_payout_tie_toggled(enabled: bool):
	"""Обработка переключателя выплаты Tie"""
	PayoutSettingsManager.toggle_tie(enabled)
	_update_payout_toggle_style(
		payout_toggle_tie,
		enabled,
		GameConstants.PAYOUT_TOGGLE_COLOR_TIE
	)


func _on_payout_player_pair_toggled(enabled: bool):
	"""Обработка переключателя выплаты Player Pair"""
	PayoutSettingsManager.toggle_player_pair(enabled)
	_update_payout_toggle_style(
		payout_toggle_player_pair,
		enabled,
		GameConstants.PAYOUT_TOGGLE_COLOR_PLAYER
	)


func _on_payout_banker_pair_toggled(enabled: bool):
	"""Обработка переключателя выплаты Banker Pair"""
	PayoutSettingsManager.toggle_banker_pair(enabled)
	_update_payout_toggle_style(
		payout_toggle_banker_pair,
		enabled,
		GameConstants.PAYOUT_TOGGLE_COLOR_BANKER
	)

# ═══════════════════════════════════════════════════════════════════════════
# ОБНОВЛЕНИЕ ВИЗУАЛЬНОГО СТИЛЯ
# ═══════════════════════════════════════════════════════════════════════════

func _update_payout_toggle_style(button: Button, enabled: bool, color: Color):
	"""Обновление визуального стиля переключателя

	Создает StyleBoxFlat с закругленными углами и рамкой.
	Цвет рамки: белый (enabled) / серый полупрозрачный (disabled).

	Args:
		button: Узел кнопки-переключателя
		enabled: Включен ли переключатель
		color: Цвет фона кнопки (из GameConstants)
	"""
	if not button:
		return

	# Создаём StyleBoxFlat для кнопки
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
