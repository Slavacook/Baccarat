# res://scripts/ui/MarkerUIManager.gd
# Специализированный менеджер для управления маркерами победителя
# Часть декомпозиции UIManager (Phase 2)
#
# ПРИМЕЧАНИЕ:
# В текущей версии игры маркеры управляются через WinnerSelectionManager.
# Этот менеджер - тонкая обёртка для сохранения единообразной архитектуры.

class_name MarkerUIManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal winner_selected(winner: String)

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ МАРКЕРОВ
# ═══════════════════════════════════════════════════════════════════════════

var player_marker: Control
var banker_marker: Control
var tie_marker: Control

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(scene: Node):
	"""Инициализация менеджера маркеров

	Args:
		scene: Корневой узел сцены Game.tscn
	"""
	# Получаем ссылки на UI узлы маркеров
	player_marker = scene.get_node("PlayerMarker")
	banker_marker = scene.get_node("BankerMarker")
	tie_marker = scene.get_node("TieMarker")

	# ПРИМЕЧАНИЕ:
	# Подключение сигналов НЕ делается здесь, так как маркеры
	# управляются через WinnerSelectionManager (GameController)
	# Для совместимости сохранён метод connect_winner_button()

# ═══════════════════════════════════════════════════════════════════════════
# ПОДКЛЮЧЕНИЕ КНОПОК (DEPRECATED)
# ═══════════════════════════════════════════════════════════════════════════

func connect_winner_button(button: Control, winner: String):
	"""Подключить обработчик клика к маркеру (DEPRECATED)

	ПРИМЕЧАНИЕ:
		Этот метод сохранён для обратной совместимости, но не используется
		в текущей версии. Маркеры управляются через WinnerSelectionManager.

	Args:
		button: UI узел маркера (PlayerMarker / BankerMarker / TieMarker)
		winner: Строка победителя ("Player" / "Banker" / "Tie")
	"""
	# В текущей архитектуре это не используется
	# WinnerSelectionManager обрабатывает клики сам
	pass

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ (для будущего расширения)
# ═══════════════════════════════════════════════════════════════════════════

func get_player_marker() -> Control:
	"""Получить узел маркера игрока"""
	return player_marker


func get_banker_marker() -> Control:
	"""Получить узел маркера банкира"""
	return banker_marker


func get_tie_marker() -> Control:
	"""Получить узел маркера ничьи"""
	return tie_marker
