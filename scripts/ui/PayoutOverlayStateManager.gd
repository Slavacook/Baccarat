# res://scripts/ui/PayoutOverlayStateManager.gd
# Менеджер состояния для PayoutOverlay
# Инкапсулирует логику управления состоянием (номиналы, жизни, очки) и обновления UI

extends RefCounted
class_name PayoutOverlayStateManager

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var owner_node: Node  # Узел для создания таймеров
var survival_info: PayoutSurvivalInfo  # Компонент отображения жизней/очков

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ (передается извне через методы)
# ═══════════════════════════════════════════════════════════════════════════

var chip_denominations: Array = []  # Номиналы фишек
var is_survival_mode: bool = false  # Режим выживания
var current_lives: int = 7  # Текущее количество жизней

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	owner_node_ref: Node,
	survival_info_ref: PayoutSurvivalInfo
):
	"""Инициализация менеджера состояния
	
	Args:
		owner_node_ref: Узел для создания таймеров
		survival_info_ref: Компонент отображения жизней/очков
	"""
	owner_node = owner_node_ref
	survival_info = survival_info_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - УПРАВЛЕНИЕ СОСТОЯНИЕМ
# ═══════════════════════════════════════════════════════════════════════════

func update_chip_denominations() -> void:
	"""Обновить номиналы фишек из GameModeManager"""
	chip_denominations = GameModeManager.get_chip_denominations()
	DebugLogger.log("PayoutOverlayStateManager: Номиналы фишек обновлены: %s" % [chip_denominations])

func set_survival_state(is_survival: bool, lives: int) -> void:
	"""Установить состояние режима выживания
	
	Args:
		is_survival: Режим выживания активен
		lives: Текущее количество жизней
	"""
	is_survival_mode = is_survival
	current_lives = lives
	update_score_display()

func update_lives(new_lives: int) -> void:
	"""Обновить количество жизней
	
	Args:
		new_lives: Новое количество жизней
	"""
	current_lives = new_lives
	update_score_display()
	DebugLogger.log_init("PayoutOverlayStateManager: current_lives обновлён до %d" % current_lives)

func update_score_display() -> void:
	"""Обновить отображение жизней (survival mode) или очков (normal mode)"""
	DebugLogger.log("🔍 DEBUG: update_score_display() вызван")

	if not survival_info:
		push_error("❌ survival_info == null!")
		return

	DebugLogger.log("🔍 DEBUG: survival_info существует")

	# Используем сохранённые переменные
	var current_score: int = SaveManager.instance.score
	DebugLogger.log("🔍 DEBUG: вызываем survival_info.update_display(%s, %d, %d)" % [is_survival_mode, current_lives, current_score])

	# Обновляем компонент
	survival_info.update_display(is_survival_mode, current_lives, current_score)

	DebugLogger.log("✅ PayoutSurvivalInfo обновлен: survival=%s, lives=%d, score=%d" % [is_survival_mode, current_lives, current_score])

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ - ОБРАБОТКА СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func handle_payout_wrong_event(_collected: float, _expected: float, _bet_type: String, _position_index: int) -> void:
	"""Обработчик события неправильной выплаты
	
	Вызывается когда EventBus.payout_wrong эмитится.
	Обновляем отображение сердечек после потери жизни.
	"""
	DebugLogger.log("🔔 DEBUG: handle_payout_wrong_event вызван! collected=%.1f, expected=%.1f" % [_collected, _expected])

	# Небольшая задержка чтобы SurvivalUI/StatsManager успел обновить жизни/очки
	await owner_node.get_tree().create_timer(0.1).timeout
	DebugLogger.log("🔍 DEBUG: Прошло 0.1 сек, вызываем update_score_display()")

	# Обновляем отображение сердечек/очков
	update_score_display()

	DebugLogger.log_init("PayoutOverlayStateManager: сердечки обновлены после потери жизни")

func handle_life_lost(remaining_lives: int) -> void:
	"""Обработчик события потери жизни
	
	Вызывается когда EventBus.life_lost эмитится.
	Обновляем локальную переменную current_lives и отображение.
	
	Args:
		remaining_lives: Оставшееся количество жизней
	"""
	DebugLogger.log("💔 DEBUG: handle_life_lost вызван! remaining_lives=%d" % remaining_lives)

	# Обновляем количество жизней
	update_lives(remaining_lives)

