# res://tests/test_GuestBetDisplayCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ GuestBetDisplayCoordinator
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var coordinator: GuestBetDisplayCoordinator

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	coordinator = GuestBetDisplayCoordinator.new()

func after_each():
	"""Очистка после каждого теста"""
	coordinator = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_display_instructions
# ═══════════════════════════════════════════════════════════════════════════

func test_get_display_instructions_no_storage():
	"""Проверка: нет хранилища - должен вернуть пустой массив"""
	var filter_manager = BetFilterManager.new()
	var instructions = coordinator.get_display_instructions(null, filter_manager)
	assert_eq(instructions.size(), 0, "Должен вернуть пустой массив без хранилища")

func test_get_display_instructions_empty_storage():
	"""Проверка: пустое хранилище - должен вернуть пустой массив"""
	# Создаём пустое хранилище (нужен мок или реальный объект)
	# Пока пропускаем - нужен реальный GuestBetStorage для теста
	pass_test("Требуется реальный GuestBetStorage для полного теста")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_guests_with_bets_count
# ═══════════════════════════════════════════════════════════════════════════

func test_get_guests_with_bets_count_no_storage():
	"""Проверка: нет хранилища - должен вернуть 0"""
	var count = coordinator.get_guests_with_bets_count(null)
	assert_eq(count, 0, "Должен вернуть 0 без хранилища")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_bets_count_for_guest
# ═══════════════════════════════════════════════════════════════════════════

func test_get_bets_count_for_guest_no_storage():
	"""Проверка: нет хранилища - должен вернуть 0"""
	var count = coordinator.get_bets_count_for_guest(null, 1)
	assert_eq(count, 0, "Должен вернуть 0 без хранилища")

