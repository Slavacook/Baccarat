# res://scripts/ui/GuestMenuTextUpdater.gd
# Обновление текстов для меню гостей
# Инкапсулирует логику локализации и обновления текстов UI-элементов

extends RefCounted
class_name GuestMenuTextUpdater

# ═══════════════════════════════════════════════════════════════════════════
# UI ЭЛЕМЕНТЫ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var ok_button: Button = null
var character_option: OptionButton = null
var wealth_option: OptionButton = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	p_ok_button: Button = null,
	p_character_option: OptionButton = null,
	p_wealth_option: OptionButton = null
):
	ok_button = p_ok_button
	character_option = p_character_option
	wealth_option = p_wealth_option

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func update_all_texts(selected_guest_id: int = 0):
	"""Обновить все тексты при смене языка"""
	_update_ok_button_text()
	_update_character_option_texts(selected_guest_id)
	_update_wealth_option_texts(selected_guest_id)

func initialize_option_buttons():
	"""Инициализировать общие OptionButton элементами (если они пустые)"""
	# OptionButton для характера
	if character_option and character_option.get_item_count() == 0:
		character_option.add_item(Localization.t("GUEST_CHARACTER_MODERATE"))
		character_option.add_item(Localization.t("GUEST_CHARACTER_CAUTIOUS"))
		character_option.add_item(Localization.t("GUEST_CHARACTER_GAMBLER"))
	
	# OptionButton для обеспеченности
	if wealth_option and wealth_option.get_item_count() == 0:
		wealth_option.add_item(Localization.t("GUEST_WEALTH_POOR"))
		wealth_option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
		wealth_option.add_item(Localization.t("GUEST_WEALTH_RICH"))

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _update_ok_button_text():
	"""Обновить текст кнопки ОК"""
	if ok_button:
		ok_button.text = Localization.t("CLOSE")

func _update_character_option_texts(selected_guest_id: int):
	"""Обновить тексты OptionButton для характера"""
	if not character_option:
		return
	
	# Сохраняем текущее выбранное значение
	var current_selected = character_option.selected
	
	# Очищаем и добавляем заново с новыми переводами
	character_option.clear()
	character_option.add_item(Localization.t("GUEST_CHARACTER_MODERATE"))
	character_option.add_item(Localization.t("GUEST_CHARACTER_CAUTIOUS"))
	character_option.add_item(Localization.t("GUEST_CHARACTER_GAMBLER"))
	
	# Восстанавливаем выбранное значение из выбранного гостя, если гость выбран
	if selected_guest_id > 0:
		var guest = GuestSettingsManager.get_guest(selected_guest_id)
		if guest:
			character_option.selected = guest.character
	else:
		# Иначе восстанавливаем предыдущее значение, если оно валидно
		if current_selected >= 0 and current_selected < character_option.get_item_count():
			character_option.selected = current_selected

func _update_wealth_option_texts(selected_guest_id: int):
	"""Обновить тексты OptionButton для обеспеченности"""
	if not wealth_option:
		return
	
	# Сохраняем текущее выбранное значение
	var current_selected = wealth_option.selected
	
	# Очищаем и добавляем заново с новыми переводами
	wealth_option.clear()
	wealth_option.add_item(Localization.t("GUEST_WEALTH_POOR"))
	wealth_option.add_item(Localization.t("GUEST_WEALTH_MEDIUM"))
	wealth_option.add_item(Localization.t("GUEST_WEALTH_RICH"))
	
	# Восстанавливаем выбранное значение из выбранного гостя, если гость выбран
	if selected_guest_id > 0:
		var guest = GuestSettingsManager.get_guest(selected_guest_id)
		if guest:
			wealth_option.selected = guest.wealth
	else:
		# Иначе восстанавливаем предыдущее значение, если оно валидно
		if current_selected >= 0 and current_selected < wealth_option.get_item_count():
			wealth_option.selected = current_selected
