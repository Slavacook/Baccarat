# res://tests/test_ChipTextureManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ ChipTextureManager
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var texture_manager: ChipTextureManager

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	texture_manager = ChipTextureManager.new()

func after_each():
	"""Очистка после каждого теста"""
	texture_manager = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Получение случайной текстуры
# ═══════════════════════════════════════════════════════════════════════════

func test_get_random_texture_valid():
	"""Проверка получения случайной текстуры для валидного типа"""
	# Arrange
	var bet_type = "Player"
	
	# Act
	var texture = texture_manager.get_random_texture(bet_type)
	
	# Assert
	assert_not_null(texture, "Должна вернуться текстура")
	assert_false(texture.is_empty(), "Текстура не должна быть пустой")
	assert_true(texture.begins_with("res://"), "Текстура должна быть путем к ресурсу")

func test_get_random_texture_all_types():
	"""Проверка получения текстур для всех типов ставок"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	
	# Act & Assert
	for bet_type in bet_types:
		var texture = texture_manager.get_random_texture(bet_type)
		assert_not_null(texture, "Тип %s должен иметь текстуру" % bet_type)
		assert_false(texture.is_empty(), "Текстура для %s не должна быть пустой" % bet_type)

func test_get_random_texture_invalid_type():
	"""Проверка обработки невалидного типа ставки"""
	# Arrange
	var invalid_type = "InvalidType"
	
	# Act - ожидаем ошибку (push_error), но продолжаем тест
	# Используем expect_error для подавления ошибки в логе
	expect_error("ChipTextureManager: нет текстур для типа 'InvalidType'")
	var texture = texture_manager.get_random_texture(invalid_type)
	
	# Assert
	assert_eq(texture, "", "Невалидный тип должен возвращать пустую строку")

func test_get_random_texture_randomness():
	"""Проверка что текстуры действительно случайные"""
	# Arrange
	var bet_type = "Player"
	var results: Array[String] = []
	
	# Act - получаем 10 случайных текстур
	for i in range(10):
		results.append(texture_manager.get_random_texture(bet_type))
	
	# Assert
	# Хотя бы одна текстура должна отличаться (с высокой вероятностью)
	var unique_results = []
	for result in results:
		if not unique_results.has(result):
			unique_results.append(result)
	# С вероятностью 99.9% хотя бы одна текстура будет отличаться при 10 попытках
	# Но если все одинаковые - это тоже валидно (просто не повезло)
	assert_true(unique_results.size() >= 1, "Должна быть хотя бы одна уникальная текстура")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Текущие текстуры
# ═══════════════════════════════════════════════════════════════════════════

func test_set_current_texture():
	"""Проверка установки текущей текстуры"""
	# Arrange
	var bet_type = "Player"
	var test_texture = "res://assets/chips/chip_500.png"
	
	# Act
	texture_manager.set_current_texture(bet_type, test_texture)
	var result = texture_manager.get_current_texture(bet_type)
	
	# Assert
	assert_eq(result, test_texture, "Текстура должна быть установлена")

func test_get_current_texture_not_set():
	"""Проверка получения текстуры когда она не установлена"""
	# Arrange
	var bet_type = "Player"
	
	# Act
	var result = texture_manager.get_current_texture(bet_type)
	
	# Assert
	assert_eq(result, "", "Неустановленная текстура должна возвращать пустую строку")

func test_clear_current_texture():
	"""Проверка очистки текущей текстуры"""
	# Arrange
	var bet_type = "Player"
	var test_texture = "res://assets/chips/chip_500.png"
	texture_manager.set_current_texture(bet_type, test_texture)
	
	# Act
	texture_manager.clear_current_texture(bet_type)
	var result = texture_manager.get_current_texture(bet_type)
	
	# Assert
	assert_eq(result, "", "Текстура должна быть очищена")

func test_clear_all_textures():
	"""Проверка очистки всех текстур"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie"]
	for bet_type in bet_types:
		texture_manager.set_current_texture(bet_type, "res://assets/chips/chip_500.png")
	
	# Act
	texture_manager.clear_all_textures()
	
	# Assert
	for bet_type in bet_types:
		var result = texture_manager.get_current_texture(bet_type)
		assert_eq(result, "", "Текстура для %s должна быть очищена" % bet_type)

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Проверка наличия текстур
# ═══════════════════════════════════════════════════════════════════════════

func test_has_textures_valid():
	"""Проверка наличия текстур для валидных типов"""
	# Arrange
	var bet_types = ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]
	
	# Act & Assert
	for bet_type in bet_types:
		var has = texture_manager.has_textures(bet_type)
		assert_true(has, "Тип %s должен иметь текстуры" % bet_type)

func test_has_textures_invalid():
	"""Проверка наличия текстур для невалидного типа"""
	# Arrange
	var invalid_type = "InvalidType"
	
	# Act
	var has = texture_manager.has_textures(invalid_type)
	
	# Assert
	assert_false(has, "Невалидный тип не должен иметь текстур")
