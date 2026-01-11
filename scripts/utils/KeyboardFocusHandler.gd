# res://scripts/utils/KeyboardFocusHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК КЛАВИАТУРНОГО ФОКУСА
# 
# Отвечает за:
# - Обработку активации элементов через клавиатурный фокус
# - Делегирование действий в соответствующие менеджеры
# ═══════════════════════════════════════════════════════════════════════════

class_name KeyboardFocusHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var phase_manager: GamePhaseManager
var winner_selection_manager: WinnerSelectionManager

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(phase_mgr: GamePhaseManager, winner_mgr: WinnerSelectionManager) -> void:
	"""Инициализировать обработчик клавиатурного фокуса
	
	Args:
		phase_mgr: Менеджер фаз игры
		winner_mgr: Менеджер выбора победителя
	"""
	phase_manager = phase_mgr
	winner_selection_manager = winner_mgr

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func on_focus_activated(target: String) -> void:
	"""Обработчик активации элемента через клавиатурный фокус
	
	Вызывается когда пользователь дважды нажал клавишу для активации элемента.
	
	Args:
		target: Имя активированного элемента:
			- "BankerThird" - третья карта банкиру
			- "PlayerThird" - третья карта игроку
			- "BankerMarker" - маркер банкира
			- "PlayerMarker" - маркер игрока  
			- "TieMarker" - маркер ничьи
	"""
	match target:
		"BankerThird":
			# Активируем toggle третьей карты банкира
			if phase_manager:
				phase_manager.on_banker_third_toggled(true)
				DebugLogger.log("⌨️ Активирован BankerThird через клавиатуру")
		
		"PlayerThird":
			# Активируем toggle третьей карты игрока
			if phase_manager:
				phase_manager.on_player_third_toggled(true)
				DebugLogger.log("⌨️ Активирован PlayerThird через клавиатуру")
		
		"BankerMarker":
			# Активируем маркер банкира
			if winner_selection_manager:
				winner_selection_manager.toggle_winner("Banker", true)  # true = через клавиатуру
				DebugLogger.log("⌨️ Активирован BankerMarker через клавиатуру")
		
		"PlayerMarker":
			# Активируем маркер игрока
			if winner_selection_manager:
				winner_selection_manager.toggle_winner("Player", true)  # true = через клавиатуру
				DebugLogger.log("⌨️ Активирован PlayerMarker через клавиатуру")
		
		"TieMarker":
			# Активируем маркер Tie (toggle как и другие маркеры)
			if winner_selection_manager:
				winner_selection_manager.toggle_winner("Tie", true)  # true = через клавиатуру
				DebugLogger.log("⌨️ Активирован TieMarker через клавиатуру")
		
		_:
			DebugLogger.log_warning("⚠️ Неизвестная цель фокуса: %s" % target)

