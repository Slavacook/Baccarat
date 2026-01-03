# res://scripts/ui/GuestMenuBalanceRenderer.gd
# Рендерер балансов для меню гостей
# Инкапсулирует логику отображения балансов гостей

extends RefCounted
class_name GuestMenuBalanceRenderer

# ═══════════════════════════════════════════════════════════════════════════
# UI ЭЛЕМЕНТЫ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var balance_labels: Array[Label] = []
var change_labels: Array[Label] = []

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(p_balance_labels: Array[Label], p_change_labels: Array[Label] = []):
	balance_labels = p_balance_labels
	change_labels = p_change_labels

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
	
	# Обновляем абсолютное значение баланса
	if index < balance_labels.size():
		var balance_label = balance_labels[index]
		if balance_label:
			var balance = GuestStatsManager.get_guest_balance(guest_id)
			balance_label.text = "Баланс: %.0f" % balance
	
	# Обновляем изменение баланса
	if index < change_labels.size():
		var change_label = change_labels[index]
		if change_label:
			var balance_change = GuestStatsManager.get_balance_change(guest_id)
			var change_text: String
			if balance_change >= 0:
				change_text = "Изменение: +%.0f" % balance_change
				change_label.modulate = Color(0.5, 1.0, 0.5)  # Зеленый
			else:
				change_text = "Изменение: %.0f" % balance_change
				change_label.modulate = Color(1.0, 0.5, 0.5)  # Красный
			change_label.text = change_text
