# res://scripts/utils/CollectionModeHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК РЕЖИМОВ СБОРА И ОПЛАТЫ
# 
# Отвечает за:
# - Обработку переключения режимов сбора и оплаты ставок
# - Управление состоянием BetCollectionPhaseManager
# ═══════════════════════════════════════════════════════════════════════════

class_name CollectionModeHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var bet_collection_manager: BetCollectionPhaseManager

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(collection_mgr: BetCollectionPhaseManager) -> void:
	"""Инициализировать обработчик режимов
	
	Args:
		collection_mgr: Менеджер сбора ставок
	"""
	bet_collection_manager = collection_mgr

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func on_collect_mode_toggled(enabled: bool) -> void:
	"""Обработчик toggle кнопки 'Забрать'
	
	Args:
		enabled: Включен ли режим сбора ставок
	
	Устанавливает режим сбора в BetCollectionPhaseManager.
	"""
	if not bet_collection_manager:
		return
	
	if enabled:
		bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.COLLECT)
	else:
		# Если режим сбора был активен, отключаем
		if bet_collection_manager.is_collect_mode():
			bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.NONE)

func on_pay_mode_toggled(enabled: bool) -> void:
	"""Обработчик toggle кнопки 'Оплатить'
	
	Args:
		enabled: Включен ли режим оплаты ставок
	
	Устанавливает режим оплаты в BetCollectionPhaseManager.
	В режиме 2 (независимый) после оплаты НЕ переключает режим обратно на COLLECT.
	"""
	if not bet_collection_manager:
		return
	
	if enabled:
		bet_collection_manager.set_mode(BetCollectionPhaseManager.CollectionMode.PAY)
	else:
		# После оплаты НЕ переключаем режим обратно на COLLECT
		# Пользователь должен продолжать оплачивать
		DebugLogger.log("🔄 CollectionModeHandler: остаёмся в PAY после оплаты")
		# Режим остаётся активным - не переключаем обратно

