# res://tests/test_PayoutOverlayStateManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ PayoutOverlayStateManager
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var state_manager: PayoutOverlayStateManager
var mock_owner_node: Node
var mock_survival_info: Control  # PayoutSurvivalInfo - это Control

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	mock_owner_node = Node.new()
	# Не добавляем в дерево, так как GutTest не является Node
	
	# Создаём мок для PayoutSurvivalInfo
	# PayoutSurvivalInfo extends HBoxContainer, но для тестов достаточно Control
	# Используем double для создания мока
	var survival_info_script = load("res://scripts/PayoutSurvivalInfo.gd")
	if survival_info_script:
		var doubled_class = double(survival_info_script)
		mock_survival_info = doubled_class.new()
	else:
		# Если скрипт не найден, создаем простой HBoxContainer
		mock_survival_info = HBoxContainer.new()
	
	state_manager = PayoutOverlayStateManager.new(mock_owner_node, mock_survival_info)

func after_each():
	"""Очистка после каждого теста"""
	if state_manager:
		state_manager = null
	if mock_survival_info:
		mock_survival_info.queue_free()
	if mock_owner_node:
		mock_owner_node.queue_free()

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: update_chip_denominations
# ═══════════════════════════════════════════════════════════════════════════

func test_update_chip_denominations():
	"""Проверка: обновление номиналов фишек"""
	# Этот тест требует GameModeManager, поэтому может быть сложным
	# Проверяем что метод вызывается без ошибок
	state_manager.update_chip_denominations()
	# Номиналы должны быть массивом (может быть пустым если GameModeManager не инициализирован)
	assert_not_null(state_manager.chip_denominations, "chip_denominations должен быть установлен")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: set_survival_state
# ═══════════════════════════════════════════════════════════════════════════

func test_set_survival_state_normal_mode():
	"""Проверка: установка состояния для обычного режима"""
	state_manager.set_survival_state(false, 0)
	assert_false(state_manager.is_survival_mode, "Режим выживания должен быть false")
	assert_eq(state_manager.current_lives, 0, "Жизни должны быть 0")

func test_set_survival_state_survival_mode():
	"""Проверка: установка состояния для режима выживания"""
	state_manager.set_survival_state(true, 7)
	assert_true(state_manager.is_survival_mode, "Режим выживания должен быть true")
	assert_eq(state_manager.current_lives, 7, "Жизни должны быть 7")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: update_lives
# ═══════════════════════════════════════════════════════════════════════════

func test_update_lives():
	"""Проверка: обновление количества жизней"""
	state_manager.set_survival_state(true, 7)
	state_manager.update_lives(5)
	assert_eq(state_manager.current_lives, 5, "Жизни должны быть обновлены до 5")

func test_update_lives_zero():
	"""Проверка: обновление жизней до нуля"""
	state_manager.set_survival_state(true, 7)
	state_manager.update_lives(0)
	assert_eq(state_manager.current_lives, 0, "Жизни должны быть обновлены до 0")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: update_score_display
# ═══════════════════════════════════════════════════════════════════════════

func test_update_score_display_with_survival_info():
	"""Проверка: обновление отображения с существующим survival_info"""
	# Если survival_info существует и имеет метод update_display, проверяем что он вызывается
	state_manager.set_survival_state(true, 7)
	# Метод должен выполниться без ошибок
	state_manager.update_score_display()
	# Проверяем что состояние не изменилось (метод не упал)
	assert_true(state_manager.is_survival_mode, "Режим выживания должен остаться true")
	assert_eq(state_manager.current_lives, 7, "Жизни должны остаться 7")

func test_update_score_display_without_survival_info():
	"""Проверка: обновление отображения без survival_info"""
	# Ожидаем ошибку (push_error), но продолжаем тест
	# GUT будет показывать ошибку как "Unexpected Error", но тест должен пройти
	# Ошибка в логе - это нормально для теста null значения
	state_manager.survival_info = null
	# Метод должен обработать null и не упасть
	state_manager.update_score_display()
	# Проверяем что состояние не изменилось (метод не упал)
	assert_true(state_manager.is_survival_mode, "Режим выживания должен остаться")
	# Тест проходит, даже если есть push_error в логе

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: handle_life_lost
# ═══════════════════════════════════════════════════════════════════════════

func test_handle_life_lost():
	"""Проверка: обработка события потери жизни"""
	state_manager.set_survival_state(true, 7)
	state_manager.handle_life_lost(5)
	assert_eq(state_manager.current_lives, 5, "Жизни должны быть обновлены")

func test_handle_life_lost_zero():
	"""Проверка: обработка потери всех жизней"""
	state_manager.set_survival_state(true, 7)
	state_manager.handle_life_lost(0)
	assert_eq(state_manager.current_lives, 0, "Жизни должны быть 0")
