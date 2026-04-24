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

# Флаг: было ли последнее переключение маркера через клавиатуру (пробел)
var was_last_toggle_by_keyboard: bool = false

# Флаг блокировки маркеров после подтверждения победителя
var _markers_locked: bool = false

# Текстуры маркеров (обычные и активированные)
const MARKER_TEXTURES = {
	"Player": {
		"normal": "res://assets/ui/player_marker.png",
		"active": "res://assets/ui/player_marker_wins.png"
	},
	"Banker": {
		"normal": "res://assets/ui/banker_marker.png",
		"active": "res://assets/ui/banker_marker_wins.png"
	},
	"Tie": {
		"normal": "res://assets/ui/Tie.png",
		"active": "res://assets/ui/Tie_win.png"
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(player_marker: TextureButton, banker_marker: TextureButton, tie_marker: TextureButton = null):
	"""Настройка ссылок на маркеры и подключение сигналов

	Параметры:
		player_marker: маркер игрока
		banker_marker: маркер банкира
		tie_marker: маркер ничьи (опционально)
	"""
	marker_nodes["Player"] = player_marker
	marker_nodes["Banker"] = banker_marker
	
	if tie_marker:
		marker_nodes["Tie"] = tie_marker

	# Подключаем сигналы к каждому маркеру
	for winner_type in marker_nodes.keys():
		var marker = marker_nodes[winner_type]
		# Отключаем автоматическое поведение TextureButton
		marker.pressed.connect(_on_marker_clicked.bind(winner_type))

	var marker_list = ", ".join(marker_nodes.keys())
	print("✅ WinnerSelectionManager: маркеры настроены (%s)" % marker_list)


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВЫБОРОМ
# ═══════════════════════════════════════════════════════════════════════════

func toggle_winner(winner: String, by_keyboard: bool = false) -> void:
	"""Переключить выбор победителя (select ↔ deselect)
	
	Args:
		winner: Выбранный победитель
		by_keyboard: true если нажатие было через клавиатуру (пробел), false если через мышь/сенсор
	"""
	if not marker_nodes.has(winner):
		push_error("WinnerSelectionManager: неизвестный победитель '%s'" % winner)
		return

	if _markers_locked:
		print("🔒 WinnerSelectionManager: игнорируем переключение %s, маркеры заблокированы" % winner)
		return

	# Сохраняем источник нажатия
	was_last_toggle_by_keyboard = by_keyboard

	if selected_winner == winner:
		# Уже выбран → снимаем выбор (пользователь напрямую деактивирует маркер)
		deselect_winner(false)  # Не играем звук здесь
		# Звук деактивации маркера играется здесь, так как это прямое действие пользователя
		if SoundManager:
			SoundManager.play_focus_deactivate_sound()
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
		# Звук деактивации предыдущего маркера
		if SoundManager:
			SoundManager.play_focus_deactivate_sound()

	# Устанавливаем новый выбор
	selected_winner = winner
	_set_marker_state(winner, true)

	# Звук активации маркера
	if SoundManager:
		SoundManager.play_sound(SoundManager.focus_activate_sound)

	winner_toggled.emit(winner, true)
	print("🎯 WinnerSelectionManager: выбран %s" % winner)


func deselect_winner(play_sound: bool = false) -> void:
	"""Снять выбор победителя (внутренний метод, не играет звук по умолчанию)
	
	Args:
		play_sound: Играть ли звук деактивации (по умолчанию false)
		           Используется только для автоматических сбросов через reset()
	"""
	if selected_winner == "":
		return

	var previous_winner = selected_winner
	_set_marker_state(selected_winner, false)
	selected_winner = ""

	# Звук деактивации маркера (только если явно запрошен)
	if play_sound and SoundManager:
		SoundManager.play_focus_deactivate_sound()

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
	# При сбросе не играем звук - это автоматическое действие
	deselect_winner(false)


func lock_markers() -> void:
	"""Заблокировать все маркеры (некликабельные)

	Используется во время выплат, чтобы игрок случайно не изменил выбор
	"""
	_markers_locked = true
	for winner_type in marker_nodes.keys():
		var marker = marker_nodes[winner_type]
		marker.disabled = true
		# Делаем полупрозрачными для визуальной индикации
		marker.modulate = Color(1.0, 1.0, 1.0, 1.0 if winner_type == selected_winner else 0.6)

	print("🔒 WinnerSelectionManager: маркеры заблокированы")


func unlock_markers() -> void:
	"""Разблокировать все маркеры (кликабельные)

	Используется при подготовке стола к новой игре
	"""
	_markers_locked = false
	for winner_type in marker_nodes.keys():
		var marker = marker_nodes[winner_type]
		marker.disabled = false
		# Возвращаем полную непрозрачность
		marker.modulate = Color(1.0, 1.0, 1.0, 1.0)

	print("🔓 WinnerSelectionManager: маркеры разблокированы")


# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА КЛИКОВ
# ═══════════════════════════════════════════════════════════════════════════

func _on_marker_clicked(winner: String) -> void:
	"""Обработка клика на маркер (мышь/сенсор)"""
	toggle_winner(winner, false)  # Мышь/сенсор - не клавиатура


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
