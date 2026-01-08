# res://scripts/utils/ChipNavigationCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# КООРДИНАТОР НАВИГАЦИИ ПО СТАВКАМ
# 
# Отвечает за:
# - Активацию навигации по ставкам
# - Автоматическое переключение режимов
# - Проверку наличия ставок для обработки
# ═══════════════════════════════════════════════════════════════════════════

class_name ChipNavigationCoordinator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var chip_navigation_manager: ChipNavigationManager
var bet_collection_manager: BetCollectionPhaseManager
var ui_manager: UIManager
var deferred_activation_callback: Callable  # Callback для call_deferred

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	navigation_mgr: ChipNavigationManager,
	collection_mgr: BetCollectionPhaseManager,
	ui_mgr: UIManager,
	deferred_callback: Callable
) -> void:
	"""Инициализировать координатор навигации по ставкам
	
	Args:
		navigation_mgr: Менеджер навигации по ставкам
		collection_mgr: Менеджер сбора ставок
		ui_mgr: Менеджер UI
		deferred_callback: Callback для отложенной активации (call_deferred)
	"""
	chip_navigation_manager = navigation_mgr
	bet_collection_manager = collection_mgr
	ui_manager = ui_mgr
	deferred_activation_callback = deferred_callback

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func on_chip_navigation_activation_requested(_camera_linked: bool) -> void:
	"""Обработка запроса активации chip navigation через EventBus
	
	Args:
		_camera_linked: Устаревший параметр (оставлен для совместимости с EventBus)
	"""
	if not chip_navigation_manager:
		DebugLogger.log_error("❌ chip_navigation_manager не инициализирован!")
		return
	
	# Откладываем активацию до следующего кадра, чтобы payout_queue_manager был готов
	# Используем call_deferred через callback
	if deferred_activation_callback.is_valid():
		deferred_activation_callback.call()
	else:
		# Fallback: активируем сразу
		activate_chip_navigation_deferred()

func activate_chip_navigation_deferred() -> void:
	"""Отложенная активация chip navigation (после подготовки payout_queue_manager)"""
	if not chip_navigation_manager:
		return
	
	# Проверяем есть ли ставки для обработки
	if not has_bets_to_process():
		DebugLogger.log("⌨️ ChipNavigationManager: навигация не активирована (нет ставок для обработки)")
		return
	
	chip_navigation_manager.activate()
	DebugLogger.log("⌨️ ChipNavigationManager: активирован через EventBus")

func has_bets_to_process() -> bool:
	"""Проверить, есть ли ставки для обработки (проигрышные или выигрышные)
	
	Returns:
		true если есть ставки для обработки, false иначе
	"""
	if not bet_collection_manager or not bet_collection_manager.payout_queue_manager:
		return false
	
	var queue_manager = bet_collection_manager.payout_queue_manager
	if not queue_manager.has_any_payouts():
		return false
	
	# Проверяем есть ли проигрышные ставки (не собранные)
	if bet_collection_manager.has_uncollected_losing_bets():
		return true
	
	# Проверяем есть ли выигрышные ставки (не оплаченные)
	if bet_collection_manager.has_unpaid_winnings():
		return true
	
	# Нет ставок для обработки
	return false

func on_auto_switch_to_pay_mode_requested() -> void:
	"""Обработка запроса автоматического переключения на режим оплаты (режим 2)"""
	if bet_collection_manager and ui_manager and ui_manager.button_ui:
		# Переключаем режим в BetCollectionPhaseManager
		# play_sound=false - не играть звук при автоматическом переключении
		bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.PAY, false)
		# Обновляем UI кнопки
		ui_manager.button_ui.set_pay_mode(true)
		DebugLogger.log("🔄 GameController: автоматически переключено COLLECT → PAY (режим 2)")

