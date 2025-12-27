# res://scripts/ui/GuestMenuBalanceRenderer.gd
# Рендерер балансов для меню гостей
# Инкапсулирует логику отображения балансов гостей

extends RefCounted
class_name GuestMenuBalanceRenderer

# ═══════════════════════════════════════════════════════════════════════════
# UI ЭЛЕМЕНТЫ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var balance_labels: Array[Label] = []

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(p_balance_labels: Array[Label]):
	balance_labels = p_balance_labels

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func update_all_balances():
	"""Обновить все балансы"""
	for guest_id in range(1, 7):
		update_balance(guest_id)

func update_balance(guest_id: int):
	"""Обновить баланс для одного гостя"""
	var index = guest_id - 1
	if index < 0 or index >= 6:
		return
	
	if index < balance_labels.size():
		var balance_label = balance_labels[index]
		if balance_label:
			balance_label.text = GuestStatsManager.get_balance_string(guest_id)
