# res://tests/test_RoundCompletionCoordinator.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ RoundCompletionCoordinator
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var coordinator: RoundCompletionCoordinator

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	coordinator = RoundCompletionCoordinator.new()

func after_each():
	"""Очистка после каждого теста"""
	coordinator = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: can_complete_round
# ═══════════════════════════════════════════════════════════════════════════

func test_can_complete_round_no_managers():
	"""Проверка: нет менеджеров - должно быть можно завершить"""
	var result = coordinator.can_complete_round(null, null)
	assert_true(result.get("can_complete", false), "Должно быть можно завершить без менеджеров")
	assert_eq(result.get("error_key", ""), "", "Не должно быть ошибки")

func test_can_complete_round_no_payout_manager():
	"""Проверка: нет payout_queue_manager - должно быть можно завершить"""
	var result = coordinator.can_complete_round(null, null)
	assert_true(result.get("can_complete", false), "Должно быть можно завершить")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_completion_message
# ═══════════════════════════════════════════════════════════════════════════

func test_get_completion_message_no_manager():
	"""Проверка: нет payout_queue_manager - должно быть NO_ACTIVE_BETS"""
	var result = coordinator.get_completion_message(null)
	assert_eq(result.get("message_key", ""), "NO_ACTIVE_BETS", "Сообщение должно быть NO_ACTIVE_BETS")
	assert_false(result.get("has_bets", true), "Не должно быть ставок")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: get_completion_instructions
# ═══════════════════════════════════════════════════════════════════════════

func test_get_completion_instructions_with_heart_bet():
	"""Проверка: есть активный Heart Bet - должна быть инструкция resolve"""
	var instructions = coordinator.get_completion_instructions(true, false)
	assert_true(instructions.get("should_resolve_heart_bet", false), "Должна быть инструкция resolve Heart Bet")
	assert_false(instructions.get("should_reset_round", true), "Не должно быть сброса раунда")
	assert_false(instructions.get("should_show_message", true), "Не должно быть сообщения")

func test_get_completion_instructions_normal_mode():
	"""Проверка: обычный режим без Heart Bet"""
	var instructions = coordinator.get_completion_instructions(false, false)
	assert_false(instructions.get("should_resolve_heart_bet", true), "Не должно быть resolve Heart Bet")
	assert_true(instructions.get("should_reset_round", false), "Должен быть сброс раунда")
	assert_true(instructions.get("should_show_message", false), "Должно быть сообщение")
	assert_true(instructions.get("should_add_score", false), "Должны начисляться очки в обычном режиме")

func test_get_completion_instructions_survival_mode():
	"""Проверка: режим выживания без Heart Bet"""
	var instructions = coordinator.get_completion_instructions(false, true)
	assert_false(instructions.get("should_resolve_heart_bet", true), "Не должно быть resolve Heart Bet")
	assert_true(instructions.get("should_reset_round", false), "Должен быть сброс раунда")
	assert_false(instructions.get("should_add_score", true), "Не должны начисляться очки в режиме выживания")

func test_get_completion_instructions_all_actions():
	"""Проверка: все действия должны быть в инструкциях"""
	var instructions = coordinator.get_completion_instructions(false, false)
	assert_true(instructions.has("should_resolve_heart_bet"), "Должна быть инструкция should_resolve_heart_bet")
	assert_true(instructions.has("should_show_message"), "Должна быть инструкция should_show_message")
	assert_true(instructions.has("should_reset_round"), "Должна быть инструкция should_reset_round")
	assert_true(instructions.has("should_restore_chips"), "Должна быть инструкция should_restore_chips")
	assert_true(instructions.has("should_apply_filters"), "Должна быть инструкция should_apply_filters")
	assert_true(instructions.has("should_generate_guest_bets"), "Должна быть инструкция should_generate_guest_bets")
	assert_true(instructions.has("should_add_score"), "Должна быть инструкция should_add_score")
	assert_true(instructions.has("should_set_waiting_state"), "Должна быть инструкция should_set_waiting_state")

