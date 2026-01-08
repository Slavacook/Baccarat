# res://scripts/utils/GameStateController.gd
# Контроллер состояния игры
# Инкапсулирует логику Game Over и рестарта игры
# Extract Class - извлечено из GameController

extends RefCounted
class_name GameStateController

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются через dependency injection)
# ═══════════════════════════════════════════════════════════════════════════

var phase_manager: GamePhaseManager = null
var game_over_popup: CanvasLayer = null
var payout_overlay: CanvasLayer = null
var survival_state: SurvivalStateProvider = null
var winner_selection_manager: WinnerSelectionManager = null

# Callback для зума камеры (делегируется в GameController)
var camera_zoom_out_callback: Callable = Callable()

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ
# ═══════════════════════════════════════════════════════════════════════════

var is_game_over: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	p_phase_manager: GamePhaseManager = null,
	p_game_over_popup: CanvasLayer = null,
	p_payout_overlay: CanvasLayer = null,
	p_survival_state: SurvivalStateProvider = null,
	p_winner_selection_manager: WinnerSelectionManager = null
):
	phase_manager = p_phase_manager
	game_over_popup = p_game_over_popup
	payout_overlay = p_payout_overlay
	survival_state = p_survival_state
	winner_selection_manager = p_winner_selection_manager

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func is_game_active() -> bool:
	"""Проверка, активна ли игра (не в Game Over)"""
	return not is_game_over

func handle_game_over(survival_rounds_completed: int) -> void:
	"""Обработать Game Over
	
	Args:
		survival_rounds_completed: Количество пройденных раундов
	"""
	if is_game_over:
		return  # Уже в Game Over, игнорируем повторные вызовы
	
	is_game_over = true
	EventBus.is_game_active = false  # Синхронизируем с EventBus
	DebugLogger.log("🎮 GAME OVER! Раундов выжито: %d" % survival_rounds_completed)
	
	# 1. Сбрасываем шансы (чтобы не переходили в новую игру)
	if phase_manager and phase_manager.heart_bet_manager:
		phase_manager.heart_bet_manager.force_reset()
		DebugLogger.log("❤️ Шансы сброшены при Game Over")
	
	# 1.1. Обнуляем карты шансов (чтобы не переходили в новую игру)
	ChanceCardManager.reset_all_cards()
	
	# 1.2. Сбрасываем балансы всех гостей при Game Over
	if GuestStatsManager:
		GuestStatsManager.reset_all_balances()
		DebugLogger.log("💰 Все балансы гостей сброшены при Game Over")
	
	# 1.3. Возвращаем всех ушедших гостей после геймовера (если есть отсчет раздач)
	if GuestReturnManager:
		GuestReturnManager.return_all_guests_after_game_over()
		DebugLogger.log("👋 Все ушедшие гости возвращены после геймовера")
	
	# 2. Закрываем окно выплат, если оно открыто
	if payout_overlay and payout_overlay.visible:
		payout_overlay.hide()
		DebugLogger.log_payout("PayoutOverlay закрыт при Game Over")
	
	# 3. Зум аут до общего плана при Game Over
	if camera_zoom_out_callback.is_valid():
		camera_zoom_out_callback.call()
	EventBus.camera_first_deal_set_requested.emit(true)  # Следующая раздача будет первой (с зумом)
	
	# 4. Уведомляем все системы через EventBus
	EventBus.game_over.emit(survival_rounds_completed)
	
	# 5. Показываем UI
	if game_over_popup:
		game_over_popup.show_game_over(survival_rounds_completed)

func restart_game() -> void:
	"""Рестарт игры (сброс всех состояний)"""
	# Сбрасываем флаг Game Over
	is_game_over = false
	EventBus.is_game_active = true  # Синхронизируем с EventBus
	
	# Сбрасываем состояние survival режима
	if survival_state:
		survival_state.reset()
		survival_state.activate()
	
	# Разблокируем маркеры для новой игры
	if winner_selection_manager:
		winner_selection_manager.unlock_markers()
	
	# Сбрасываем шансы (на всякий случай)
	if phase_manager and phase_manager.heart_bet_manager:
		phase_manager.heart_bet_manager.force_reset()
		DebugLogger.log("❤️ Шансы сброшены при рестарте")
	
	# Обнуляем карты шансов (на всякий случай)
	ChanceCardManager.reset_all_cards()
	
	# Сбрасываем phase_manager
	if phase_manager:
		phase_manager.reset()
	
	# Уведомляем все системы о рестарте
	EventBus.game_restarted.emit()
	
	DebugLogger.log("🔄 Игра перезапущена, все системы сброшены")

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func set_camera_zoom_out_callback(callback: Callable) -> void:
	"""Установить callback для зума камеры"""
	camera_zoom_out_callback = callback

func get_is_game_over() -> bool:
	"""Получить состояние Game Over"""
	return is_game_over

func set_is_game_over(value: bool) -> void:
	"""Установить состояние Game Over (для синхронизации)"""
	is_game_over = value
	if is_game_over:
		EventBus.is_game_active = false
	else:
		EventBus.is_game_active = true

func check_and_handle_game_over(survival_rounds_completed: int) -> bool:
	"""Проверить Game Over в режиме выживания и обработать, если нужно
	
	Args:
		survival_rounds_completed: Количество пройденных раундов
	
	Returns:
		true если Game Over произошёл, false если игра продолжается
	"""
	if is_game_over:
		return true  # Уже в Game Over
	
	var is_active = survival_state.is_active_mode() if survival_state else false
	var lives = survival_state.get_lives() if survival_state else 7
	
	if is_active and lives <= 0:
		DebugLogger.log_game_flow("GAME OVER! Закончились жизни (проверка после возврата из PayoutScene)")
		handle_game_over(survival_rounds_completed)
		return true
	
	return false

