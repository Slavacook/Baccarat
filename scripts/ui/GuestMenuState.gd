# res://scripts/ui/GuestMenuState.gd
# Состояние меню гостей
# Инкапсулирует состояние выбранного гостя и hover эффектов

extends RefCounted
class_name GuestMenuState

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ
# ═══════════════════════════════════════════════════════════════════════════

var selected_guest_id: int = 0  # Текущий выбранный гость (0 = никто не выбран, 1-6 = выбранный гость)
var hovered_guest_id: int = 0    # Текущий гость под курсором (для hover эффекта)

# ═══════════════════════════════════════════════════════════════════════════
# CALLBACK-ИНТЕРФЕЙС
# ═══════════════════════════════════════════════════════════════════════════

# Callback для обновления видимости UI при изменении состояния
var state_changed_callback: Callable

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func reset():
	"""Сбросить состояние (без уведомления, т.к. обычно вызывается перед обновлением UI)"""
	selected_guest_id = 0
	hovered_guest_id = 0
	# Не вызываем _notify_state_changed(), т.к. reset обычно вызывается
	# перед явным обновлением UI (например, в open_menu())

func set_selected_guest(guest_id: int):
	"""Установить выбранного гостя (0-6, где 0 = никто не выбран)"""
	if guest_id < 0 or guest_id > 6:
		push_warning("GuestMenuState: неверный guest_id %d (должен быть 0-6)" % guest_id)
		return
	
	if selected_guest_id == guest_id:
		return
	
	selected_guest_id = guest_id
	_notify_state_changed()

func get_selected_guest() -> int:
	"""Получить ID выбранного гостя"""
	return selected_guest_id

func has_selected_guest() -> bool:
	"""Проверить, выбран ли какой-либо гость"""
	return selected_guest_id > 0

func set_hovered_guest(guest_id: int):
	"""Установить гостя под курсором (0-6, где 0 = нет hover)"""
	if guest_id < 0 or guest_id > 6:
		push_warning("GuestMenuState: неверный guest_id %d (должен быть 0-6)" % guest_id)
		return
	
	if hovered_guest_id == guest_id:
		return
	
	hovered_guest_id = guest_id
	_notify_state_changed()

func get_hovered_guest() -> int:
	"""Получить ID гостя под курсором"""
	return hovered_guest_id

func clear_hover():
	"""Очистить hover (установить в 0)"""
	set_hovered_guest(0)

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _notify_state_changed():
	"""Уведомить о изменении состояния"""
	if state_changed_callback.is_valid():
		state_changed_callback.call()
