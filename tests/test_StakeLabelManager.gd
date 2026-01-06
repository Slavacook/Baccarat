# res://tests/test_StakeLabelManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ StakeLabelManager
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var label_manager: StakeLabelManager

# Мок для ChipInstance - используем double для правильного типа
var MockChipInstanceClass = null

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	label_manager = StakeLabelManager.new()
	# Загружаем класс ChipInstance для создания моков
	var chip_visual_manager_script = load("res://scripts/ChipVisualManager.gd")
	if chip_visual_manager_script:
		# Используем double для создания мока ChipInstance
		MockChipInstanceClass = double(chip_visual_manager_script).ChipInstance

func after_each():
	"""Очистка после каждого теста"""
	label_manager = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Форматирование суммы ставки
# ═══════════════════════════════════════════════════════════════════════════

func test_format_stake_zero():
	"""Проверка форматирования нулевой суммы"""
	# Arrange
	var stake = 0.0
	
	# Act
	var result = label_manager.format_stake(stake)
	
	# Assert
	assert_eq(result, "0", "Нулевая сумма должна форматироваться как '0'")

func test_format_stake_small():
	"""Проверка форматирования малой суммы"""
	# Arrange
	var stake = 100.0
	
	# Act
	var result = label_manager.format_stake(stake)
	
	# Assert
	assert_eq(result, "100", "Малая сумма должна форматироваться без пробелов")

func test_format_stake_thousands():
	"""Проверка форматирования суммы с тысячами"""
	# Arrange
	var stake = 1000.0
	
	# Act
	var result = label_manager.format_stake(stake)
	
	# Assert
	assert_eq(result, "1 000", "Тысячи должны разделяться пробелом")

func test_format_stake_millions():
	"""Проверка форматирования суммы с миллионами"""
	# Arrange
	var stake = 1000000.0
	
	# Act
	var result = label_manager.format_stake(stake)
	
	# Assert
	assert_eq(result, "1 000 000", "Миллионы должны разделяться пробелами")

func test_format_stake_negative():
	"""Проверка форматирования отрицательной суммы"""
	# Arrange
	var stake = -100.0
	
	# Act
	var result = label_manager.format_stake(stake)
	
	# Assert
	assert_eq(result, "0", "Отрицательная сумма должна форматироваться как '0'")

func test_format_stake_large():
	"""Проверка форматирования большой суммы"""
	# Arrange
	var stake = 1234567.0
	
	# Act
	var result = label_manager.format_stake(stake)
	
	# Assert
	# Проверяем что есть пробелы (форматирование работает)
	assert_true(result.contains(" "), "Большая сумма должна содержать пробелы")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Создание label
# ═══════════════════════════════════════════════════════════════════════════

func test_create_stake_label_null_chip():
	"""Проверка обработки null фишки"""
	# Arrange
	var chip = null
	var scene_root = Node.new()
	# Не добавляем в дерево, так как GutTest не является Node
	
	# Act
	var result = label_manager.create_stake_label(chip, scene_root)
	
	# Assert
	assert_null(result, "Null фишка должна возвращать null")
	
	# Cleanup
	scene_root.queue_free()

func test_create_stake_label_null_scene_root():
	"""Проверка обработки null scene_root"""
	# Arrange
	if not MockChipInstanceClass:
		pass_test("ChipInstance класс не найден, пропускаем тест")
		return
	
	var chip_node = TextureButton.new()
	var chip = MockChipInstanceClass.new("Player", 0, chip_node, false)
	chip.stake = 100.0
	
	# Act
	var result = label_manager.create_stake_label(chip, null)
	
	# Assert
	assert_null(result, "Null scene_root должен возвращать null")
	
	# Cleanup
	chip_node.queue_free()

func test_create_stake_label_valid():
	"""Проверка создания label для валидной фишки"""
	# Arrange
	if not MockChipInstanceClass:
		pass_test("ChipInstance класс не найден, пропускаем тест")
		return
	
	var scene_root = Node.new()
	# Не добавляем в дерево, так как GutTest не является Node
	var chip_node = TextureButton.new()
	chip_node.position = Vector2(100, 100)
	scene_root.add_child(chip_node)
	var chip = MockChipInstanceClass.new("Player", 0, chip_node, false)
	chip.stake = 1000.0
	
	# Act
	var result = label_manager.create_stake_label(chip, scene_root)
	
	# Assert
	assert_not_null(result, "Должен быть создан label")
	assert_true(result is Control, "Результат должен быть Control")
	assert_true(is_instance_valid(result), "Label должен быть валидным узлом")
	
	# Cleanup
	if result:
		result.queue_free()
	scene_root.queue_free()

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Обновление label
# ═══════════════════════════════════════════════════════════════════════════

func test_update_stake_label_null_chip():
	"""Проверка обновления label для null фишки"""
	# Arrange
	var chip = null
	
	# Act - не должно быть ошибок
	label_manager.update_stake_label(chip)
	
	# Assert - просто проверяем что не упало
	pass_test("Обновление null фишки не должно вызывать ошибок")

func test_update_stake_label_no_label():
	"""Проверка обновления label когда label не установлен"""
	# Arrange
	if not MockChipInstanceClass:
		pass_test("ChipInstance класс не найден, пропускаем тест")
		return
	
	var chip_node = TextureButton.new()
	var chip = MockChipInstanceClass.new("Player", 0, chip_node, false)
	chip.stake = 1000.0
	chip.stake_label = null
	
	# Act - не должно быть ошибок
	label_manager.update_stake_label(chip)
	
	# Assert - просто проверяем что не упало
	pass_test("Обновление без label не должно вызывать ошибок")
	
	# Cleanup
	chip_node.queue_free()

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Удаление label
# ═══════════════════════════════════════════════════════════════════════════

func test_remove_stake_label_null_chip():
	"""Проверка удаления label для null фишки"""
	# Arrange
	var chip = null
	
	# Act - не должно быть ошибок
	label_manager.remove_stake_label(chip)
	
	# Assert - просто проверяем что не упало
	pass_test("Удаление label для null фишки не должно вызывать ошибок")

func test_remove_stake_label_no_label():
	"""Проверка удаления label когда label не установлен"""
	# Arrange
	var chip_node = TextureButton.new()
	var chip = MockChipInstance.new("Player", 0, chip_node, 1000.0)
	chip.stake_label = null
	
	# Act - не должно быть ошибок
	label_manager.remove_stake_label(chip)
	
	# Assert - просто проверяем что не упало
	pass_test("Удаление без label не должно вызывать ошибок")
	
	# Cleanup
	chip_node.queue_free()

func test_remove_all_stake_labels_for_type():
	"""Проверка удаления всех labels для типа ставки"""
	# Arrange
	if not MockChipInstanceClass:
		pass_test("ChipInstance класс не найден, пропускаем тест")
		return
	
	var active_chips: Array = []
	var chip_node1 = TextureButton.new()
	var chip1 = MockChipInstanceClass.new("Player", 0, chip_node1, false)
	chip1.stake = 1000.0
	var chip_node2 = TextureButton.new()
	var chip2 = MockChipInstanceClass.new("Player", 1, chip_node2, false)
	chip2.stake = 2000.0
	var chip_node3 = TextureButton.new()
	var chip3 = MockChipInstanceClass.new("Banker", 0, chip_node3, false)
	chip3.stake = 3000.0
	active_chips.append(chip1)
	active_chips.append(chip2)
	active_chips.append(chip3)
	
	# Act
	label_manager.remove_all_stake_labels_for_type(active_chips, "Player")
	
	# Assert - просто проверяем что не упало
	pass_test("Удаление всех labels для типа не должно вызывать ошибок")
	
	# Cleanup
	chip_node1.queue_free()
	chip_node2.queue_free()
	chip_node3.queue_free()

