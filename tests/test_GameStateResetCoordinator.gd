# res://tests/test_GameStateResetCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ GameStateResetCoordinator
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var coordinator: GameStateResetCoordinator

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	coordinator = GameStateResetCoordinator.new()

func after_each():
	"""Очистка после каждого теста"""
	coordinator = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_reset_instructions
# ═══════════════════════════════════════════════════════════════════════════

func test_get_reset_instructions_default():
	"""Проверка: инструкции по умолчанию (update_state=true, keep_guest_bets=false)"""
	var instructions = coordinator.get_reset_instructions()
	assert_true(instructions.get("should_reset_hands", false), "Должен быть сброс рук")
	assert_true(instructions.get("should_reset_ui", false), "Должен быть сброс UI")
	assert_true(instructions.get("should_clear_chips", false), "Должна быть очистка фишек")
	assert_true(instructions.get("should_clear_guest_bets", false), "Должна быть очистка ставок гостей")
	assert_true(instructions.get("should_update_state", false), "Должно быть обновление состояния")
	assert_true(instructions.get("should_invalidate_cache", false), "Должна быть инвалидация кэша")

func test_get_reset_instructions_keep_guest_bets():
	"""Проверка: инструкции с keep_guest_bets=true"""
	var instructions = coordinator.get_reset_instructions(true, true)
	assert_true(instructions.get("should_reset_hands", false), "Должен быть сброс рук")
	assert_false(instructions.get("should_clear_chips", true), "Не должна быть очистка фишек при keep_guest_bets")
	assert_false(instructions.get("should_clear_guest_bets", true), "Не должна быть очистка ставок гостей при keep_guest_bets")

func test_get_reset_instructions_no_update_state():
	"""Проверка: инструкции с update_state=false"""
	var instructions = coordinator.get_reset_instructions(false, false)
	assert_false(instructions.get("should_update_state", true), "Не должно быть обновление состояния")
	assert_true(instructions.get("should_invalidate_cache", false), "Должна быть инвалидация кэша даже при update_state=false")

func test_get_reset_instructions_all_fields():
	"""Проверка: все поля присутствуют в инструкциях"""
	var instructions = coordinator.get_reset_instructions()
	assert_true(instructions.has("should_reset_hands"), "Должно быть поле should_reset_hands")
	assert_true(instructions.has("should_reset_ui"), "Должно быть поле should_reset_ui")
	assert_true(instructions.has("should_clear_chips"), "Должно быть поле should_clear_chips")
	assert_true(instructions.has("should_clear_guest_bets"), "Должно быть поле should_clear_guest_bets")
	assert_true(instructions.has("should_update_state"), "Должно быть поле should_update_state")
	assert_true(instructions.has("should_invalidate_cache"), "Должно быть поле should_invalidate_cache")
	assert_true(instructions.has("should_reset_managers"), "Должно быть поле should_reset_managers")
	assert_true(instructions.has("should_hide_ui_elements"), "Должно быть поле should_hide_ui_elements")

