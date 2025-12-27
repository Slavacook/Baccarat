# res://scripts/ui/GuestUIVisualState.gd
# Состояние видимости UI для одного гостя
# Value Object - инкапсулирует данные для рендеринга UI

extends RefCounted
class_name GuestUIVisualState

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ВИДИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var is_enabled: bool = false          # Гость включён
var is_selected: bool = false          # Гость выбран
var is_hovered: bool = false           # Наведён курсор мыши
var has_keyboard_focus: bool = false   # Есть фокус клавиатуры

# ═══════════════════════════════════════════════════════════════════════════
# ВЫЧИСЛЯЕМЫЕ СВОЙСТВА (для удобства использования)
# ═══════════════════════════════════════════════════════════════════════════

func should_show_ghost() -> bool:
	"""Призрак виден если гость выключен ИЛИ если гость включён и выбран (для эффекта свечения)"""
	return not is_enabled or (is_enabled and is_selected)

func get_ghost_alpha() -> float:
	"""Получить прозрачность призрака: 25% если выключен, 100% если выбран"""
	if not is_enabled:
		return 0.25
	elif is_enabled and is_selected:
		return 1.0
	return 0.25  # По умолчанию

func should_show_guest() -> bool:
	"""Материальный гость виден если гость включён"""
	return is_enabled

func should_show_hover_glow() -> bool:
	"""Hover свечение видно если наведён курсор ИЛИ есть фокус клавиатуры"""
	return is_hovered or has_keyboard_focus

func should_show_dossier() -> bool:
	"""Досье видно только для выбранного включённого гостя"""
	return is_enabled and is_selected

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	p_is_enabled: bool = false,
	p_is_selected: bool = false,
	p_is_hovered: bool = false,
	p_has_keyboard_focus: bool = false
):
	is_enabled = p_is_enabled
	is_selected = p_is_selected
	is_hovered = p_is_hovered
	has_keyboard_focus = p_has_keyboard_focus
