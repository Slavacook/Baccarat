# res://tests/test_PhaseActionResolver.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ PhaseActionResolver
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var resolver: PhaseActionResolver

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	resolver = PhaseActionResolver.new()

func after_each():
	"""Очистка после каждого теста"""
	resolver = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Подготовка стола
# ═══════════════════════════════════════════════════════════════════════════

func test_resolve_table_prepared():
	"""Проверка: стол подготовлен - должно быть deal_first_four"""
	var result = resolver.resolve_action(true, GameStateManager.GameState.WAITING)
	assert_eq(result.get("action", ""), "deal_first_four", "Действие должно быть deal_first_four")
	assert_eq(result.get("phase", ""), "table_preparation", "Фаза должна быть table_preparation")

func test_resolve_table_prepared_any_state():
	"""Проверка: стол подготовлен - игнорирует состояние"""
	var result = resolver.resolve_action(true, GameStateManager.GameState.CHOOSE_WINNER)
	assert_eq(result.get("action", ""), "deal_first_four", "Действие должно быть deal_first_four даже в CHOOSE_WINNER")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Состояние WAITING
# ═══════════════════════════════════════════════════════════════════════════

func test_resolve_waiting_state():
	"""Проверка: состояние WAITING - должно быть deal_first_four"""
	var result = resolver.resolve_action(false, GameStateManager.GameState.WAITING)
	assert_eq(result.get("action", ""), "deal_first_four", "Действие должно быть deal_first_four")
	assert_eq(result.get("phase", ""), "waiting", "Фаза должна быть waiting")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Состояние CARD_TO_BANKER_AFTER_PLAYER
# ═══════════════════════════════════════════════════════════════════════════

func test_resolve_banker_after_player():
	"""Проверка: состояние CARD_TO_BANKER_AFTER_PLAYER - должно быть validate_banker_after_player"""
	var result = resolver.resolve_action(false, GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER)
	assert_eq(result.get("action", ""), "validate_banker_after_player", "Действие должно быть validate_banker_after_player")
	assert_eq(result.get("phase", ""), "banker_after_player", "Фаза должна быть banker_after_player")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Состояние CHOOSE_WINNER
# ═══════════════════════════════════════════════════════════════════════════

func test_resolve_choose_winner():
	"""Проверка: состояние CHOOSE_WINNER - должно быть handle_choose_winner"""
	var result = resolver.resolve_action(false, GameStateManager.GameState.CHOOSE_WINNER)
	assert_eq(result.get("action", ""), "handle_choose_winner", "Действие должно быть handle_choose_winner")
	assert_eq(result.get("phase", ""), "choose_winner", "Фаза должна быть choose_winner")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Fallback (третьи карты)
# ═══════════════════════════════════════════════════════════════════════════

func test_resolve_card_to_each_fallback():
	"""Проверка: состояние CARD_TO_EACH - должно быть validate_third_cards (fallback)"""
	var result = resolver.resolve_action(false, GameStateManager.GameState.CARD_TO_EACH)
	assert_eq(result.get("action", ""), "validate_third_cards", "Действие должно быть validate_third_cards")
	assert_eq(result.get("phase", ""), "third_cards", "Фаза должна быть third_cards")

func test_resolve_card_to_player_fallback():
	"""Проверка: состояние CARD_TO_PLAYER - должно быть validate_third_cards (fallback)"""
	var result = resolver.resolve_action(false, GameStateManager.GameState.CARD_TO_PLAYER)
	assert_eq(result.get("action", ""), "validate_third_cards", "Действие должно быть validate_third_cards")

func test_resolve_card_to_banker_fallback():
	"""Проверка: состояние CARD_TO_BANKER - должно быть validate_third_cards (fallback)"""
	var result = resolver.resolve_action(false, GameStateManager.GameState.CARD_TO_BANKER)
	assert_eq(result.get("action", ""), "validate_third_cards", "Действие должно быть validate_third_cards")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: Структура результата
# ═══════════════════════════════════════════════════════════════════════════

func test_result_has_all_fields():
	"""Проверка: результат содержит все необходимые поля"""
	var result = resolver.resolve_action(false, GameStateManager.GameState.WAITING)
	assert_true(result.has("action"), "Результат должен содержать поле action")
	assert_true(result.has("phase"), "Результат должен содержать поле phase")
	assert_true(result.has("reason"), "Результат должен содержать поле reason")
	assert_false(result.get("reason", "").is_empty(), "Причина не должна быть пустой")

