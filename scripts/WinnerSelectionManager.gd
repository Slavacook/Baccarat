# res://scripts/WinnerSelectionManager.gd
# Менеджер выбора победителя через toggleable маркеры

class_name WinnerSelectionManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal winner_toggled(winner: String, selected: bool)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Словарь маркеров: {"Player": TextureButton, "Banker": TextureButton}
var marker_nodes: Dictionary = {}

# Текущий выбранный победитель (или пустая строка если никто не выбран)
var selected_winner: String = ""

# Текстуры маркеров (обычные и активированные)
const MARKER_TEXTURES = {
	"Player": {
		"normal": "res://assets/ui/player_marker.png",
		"active": "res://assets/ui/player_marker_wins.png"
	},
	"Banker": {
		"normal": "res://assets/ui/banker_marker.png",
		"active": "res://assets/ui/banker_marker_wins.png"
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(player_marker: TextureButton, banker_marker: TextureButton):
	"""Настройка ссылок на маркеры и подключение сигналов

	Примечание: Маркер "Tie" удалён - теперь используется кнопка TieButton
	"""
	marker_nodes["Player"] = player_marker
	marker_nodes["Banker"] = banker_marker

	# Подключаем сигналы к каждому маркеру
	for winner_type in marker_nodes.keys():
		var marker = marker_nodes[winner_type]
		# Отключаем автоматическое поведение TextureButton
		marker.pressed.connect(_on_marker_clicked.bind(winner_type))

	print("✅ WinnerSelectionManager: маркеры настроены (Player, Banker)")


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВЫБОРОМ
# ═══════════════════════════════════════════════════════════════════════════

func toggle_winner(winner: String) -> void:
	"""Переключить выбор победителя (select ↔ deselect)"""
	if not marker_nodes.has(winner):
		push_error("WinnerSelectionManager: неизвестный победитель '%s'" % winner)
		return

	if selected_winner == winner:
		# Уже выбран → снимаем выбор
		deselect_winner()
	else:
		# Выбираем нового (автоматически снимает предыдущий)
		select_winner(winner)


func select_winner(winner: String) -> void:
	"""Выбрать победителя (снимает предыдущий выбор)"""
	if not marker_nodes.has(winner):
		push_error("WinnerSelectionManager: неизвестный победитель '%s'" % winner)
		return

	# Снимаем предыдущий выбор (если был)
	if selected_winner != "":
		_set_marker_state(selected_winner, false)

	# Устанавливаем новый выбор
	selected_winner = winner
	_set_marker_state(winner, true)

	winner_toggled.emit(winner, true)
	print("🎯 WinnerSelectionManager: выбран %s" % winner)


func deselect_winner() -> void:
	"""Снять выбор победителя"""
	if selected_winner == "":
		return

	var previous_winner = selected_winner
	_set_marker_state(selected_winner, false)
	selected_winner = ""

	winner_toggled.emit(previous_winner, false)
	print("🎯 WinnerSelectionManager: выбор снят")


func get_selected_winner() -> String:
	"""Получить текущий выбранный победитель"""
	return selected_winner


func is_winner_selected() -> bool:
	"""Проверить, выбран ли победитель"""
	return selected_winner != ""


func reset() -> void:
	"""Сбросить выбор (для новой игры)"""
	deselect_winner()


# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА КЛИКОВ
# ═══════════════════════════════════════════════════════════════════════════

func _on_marker_clicked(winner: String) -> void:
	"""Обработка клика на маркер"""
	toggle_winner(winner)


# ═══════════════════════════════════════════════════════════════════════════
# ВИЗУАЛЬНОЕ СОСТОЯНИЕ МАРКЕРОВ
# ═══════════════════════════════════════════════════════════════════════════

func _set_marker_state(winner: String, pressed: bool) -> void:
	"""Установить визуальное состояние маркера (нажат/не нажат)

	Меняет текстуру маркера на "активную" версию при выборе
	"""
	var marker = marker_nodes[winner]

	if pressed:
		# Активированный маркер → показываем "wins" текстуру
		var active_texture_path = MARKER_TEXTURES[winner]["active"]
		var texture = load(active_texture_path)
		if texture:
			marker.texture_normal = texture
			print("🎯 Маркер %s активирован (текстура: %s)" % [winner, active_texture_path.get_file()])
		else:
			push_error("WinnerSelectionManager: не удалось загрузить текстуру %s" % active_texture_path)
	else:
		# Обычное состояние → показываем обычную текстуру
		var normal_texture_path = MARKER_TEXTURES[winner]["normal"]
		var texture = load(normal_texture_path)
		if texture:
			marker.texture_normal = texture
			print("🎯 Маркер %s деактивирован (текстура: %s)" % [winner, normal_texture_path.get_file()])
		else:
			push_error("WinnerSelectionManager: не удалось загрузить текстуру %s" % normal_texture_path)
