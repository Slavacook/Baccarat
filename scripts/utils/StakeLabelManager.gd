# res://scripts/utils/StakeLabelManager.gd
# Менеджер меток суммы ставки (Stake Labels)
# 
# Отвечает за:
# - Создание label для отображения суммы ставки
# - Форматирование суммы ставки
# - Обновление и удаление labels
# - Управление жизненным циклом labels

class_name StakeLabelManager

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func create_stake_label(chip_instance: ChipVisualManager.ChipInstance, scene_root: Node) -> Control:
	"""Создать label для отображения суммы ставки в стиле карточек гостя
	
	Args:
		chip_instance: Экземпляр фишки с информацией о ставке
		scene_root: Родительский узел для добавления label
		
	Returns:
		Control контейнер с label или null если не удалось создать
	"""
	if not chip_instance or not chip_instance.node or not scene_root:
		return null
	
	# Создаём контейнер для label
	var container = Control.new()
	container.name = "StakeLabel_%s_%d" % [chip_instance.bet_type, chip_instance.position_index]
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Игнорируем клики
	
	# Создаём Panel для фона
	var panel = Panel.new()
	panel.name = "Panel"
	panel.size = Vector2(100, 30)  # Компактный размер для суммы ставки
	container.add_child(panel)
	
	# Создаём Label для текста
	var label = Label.new()
	label.name = "Label"
	label.text = format_stake(chip_instance.stake)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)  # 14 * 1.5 = 21
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # Золотистый цвет текста
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)
	
	# Позиционируем label рядом с фишкой (справа и немного выше)
	var chip_pos = chip_instance.node.position
	# Получаем размер фишки из текстуры или используем дефолтный
	var chip_size = Vector2(64, 64)
	if chip_instance.node.texture_normal:
		chip_size = chip_instance.node.texture_normal.get_size() * chip_instance.node.scale
	container.position = chip_pos + Vector2(chip_size.x + -80, 50)
	
	# Добавляем в scene_root
	scene_root.add_child(container)
	
	return container


func format_stake(stake: float) -> String:
	"""Форматировать сумму ставки для отображения с разделителем тысяч через пробел
	
	Args:
		stake: Сумма ставки
		
	Returns:
		Отформатированная строка (например, "1 000 000")
	"""
	if stake <= 0:
		return "0"
	
	var amount = int(stake)
	var formatted = ""
	var count = 0
	
	# Обрабатываем число справа налево, добавляя пробелы каждые 3 цифры
	if amount == 0:
		return "0"
	
	while amount > 0:
		if count > 0 and count % 3 == 0:
			formatted = " " + formatted
		formatted = str(amount % 10) + formatted
		amount = int(floor(amount / 10.0))  # Целочисленное деление через floor с приведением к int
		count += 1
	
	return formatted


func update_stake_label(chip_instance: ChipVisualManager.ChipInstance) -> void:
	"""Обновить текст label суммы ставки
	
	Args:
		chip_instance: Экземпляр фишки с label
	"""
	if not chip_instance or not chip_instance.stake_label:
		return
	
	var label = chip_instance.stake_label.get_node_or_null("Panel/Label")
	if label:
		label.text = format_stake(chip_instance.stake)


func remove_stake_label(chip_instance: ChipVisualManager.ChipInstance) -> void:
	"""Удалить label суммы ставки
	
	Args:
		chip_instance: Экземпляр фишки с label
	"""
	if not chip_instance or not chip_instance.stake_label:
		return
	
	if is_instance_valid(chip_instance.stake_label):
		chip_instance.stake_label.queue_free()
	chip_instance.stake_label = null


func remove_all_stake_labels_for_type(active_chips: Array[ChipVisualManager.ChipInstance], bet_type: String) -> void:
	"""Удалить все labels для конкретного типа ставки
	
	Args:
		active_chips: Массив всех активных фишек
		bet_type: Тип ставки для удаления labels
	"""
	for chip in active_chips:
		if chip.bet_type == bet_type:
			remove_stake_label(chip)

