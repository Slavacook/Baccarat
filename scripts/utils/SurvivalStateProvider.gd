# res://scripts/utils/SurvivalStateProvider.gd
# Провайдер состояния режима выживания
# Инкапсулирует логику выбора между HeartBar и SurvivalModeUI
# Устраняет дублирование кода "if heart_bar else survival_ui"

extends RefCounted
class_name SurvivalStateProvider

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var heart_bar: HeartBar = null
var survival_ui: Control = null  # SurvivalModeUI

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

const DEFAULT_LIVES: int = 7
const DEFAULT_ACTIVE: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(p_heart_bar: HeartBar = null, p_survival_ui: Control = null):
	heart_bar = p_heart_bar
	survival_ui = p_survival_ui


func _is_tournament_mode() -> bool:
	"""Проверить, запущен ли турнирный режим"""
	var session_manager: Variant = null
	if Engine.has_singleton("SessionManager"):
		session_manager = Engine.get_singleton("SessionManager")
	else:
		var tree := Engine.get_main_loop()
		if tree is SceneTree:
			session_manager = tree.root.get_node_or_null("SessionManager")
	if session_manager == null:
		return false
	return session_manager.get("current_mode") == session_manager.Mode.TOURNAMENT

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func get_lives() -> int:
	"""Получить текущее количество жизней"""
	if heart_bar:
		return heart_bar.get_lives()
	elif survival_ui and survival_ui.has_method("get_lives"):
		return survival_ui.get_lives()
	return DEFAULT_LIVES

func is_active_mode() -> bool:
	"""Проверить, активен ли режим выживания"""
	if heart_bar:
		return heart_bar.is_active_mode()
	elif survival_ui and "is_active" in survival_ui:
		return survival_ui.is_active
	return DEFAULT_ACTIVE

func set_lives(lives: int) -> void:
	"""Установить количество жизней"""
	if heart_bar:
		heart_bar.set_lives(lives)
	elif survival_ui and survival_ui.has_method("set_lives"):
		survival_ui.set_lives(lives)

func activate() -> void:
	"""Активировать режим выживания"""
	if _is_tournament_mode():
		if heart_bar:
			heart_bar.activate()
		if survival_ui:
			survival_ui.hide()
		return

	# Приоритет: survival_ui.activate() (он активирует heart_bar внутри себя и показывает UI)
	if survival_ui and survival_ui.has_method("activate"):
		survival_ui.activate()
	elif heart_bar:
		# Если нет survival_ui, но есть heart_bar, активируем напрямую
		heart_bar.activate()

func deactivate() -> void:
	"""Деактивировать режим выживания"""
	# Приоритет: survival_ui.deactivate() (он деактивирует heart_bar внутри себя и скрывает UI)
	if survival_ui and survival_ui.has_method("deactivate"):
		survival_ui.deactivate()
	elif heart_bar:
		# Если нет survival_ui, но есть heart_bar, деактивируем напрямую
		heart_bar.deactivate()

func reset() -> void:
	"""Сбросить состояние (для новой игры)"""
	if _is_tournament_mode():
		if heart_bar:
			heart_bar.set_lives(DEFAULT_LIVES)
			heart_bar.activate()
		elif survival_ui and survival_ui.has_method("set_lives"):
			survival_ui.set_lives(DEFAULT_LIVES)
		if survival_ui:
			survival_ui.hide()
		return

	# Приоритет: survival_ui.reset() (он сбрасывает heart_bar внутри себя и показывает UI)
	if survival_ui and survival_ui.has_method("reset"):
		survival_ui.reset()
		survival_ui.activate()  # Показываем и активируем после сброса
	elif heart_bar:
		# Если нет survival_ui, но есть heart_bar, сбрасываем напрямую
		heart_bar.set_lives(DEFAULT_LIVES)
		heart_bar.activate()

func show() -> void:
	"""Показать UI режима выживания"""
	if _is_tournament_mode():
		if survival_ui:
			survival_ui.hide()
		return
	if survival_ui:
		survival_ui.show()

func hide() -> void:
	"""Скрыть UI режима выживания"""
	if survival_ui:
		survival_ui.hide()

# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func has_heart_bar() -> bool:
	"""Проверить, доступен ли HeartBar"""
	return heart_bar != null

func has_survival_ui() -> bool:
	"""Проверить, доступен ли SurvivalModeUI"""
	return survival_ui != null
