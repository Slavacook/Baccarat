# res://tests/test_BetFilterManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ BetFilterManager
# ═══════════════════════════════════════════════════════════════════════════

extends GutTest

var filter_manager: BetFilterManager

# ═══════════════════════════════════════════════════════════════════════════
# SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════

func before_each():
	"""Инициализация перед каждым тестом"""
	filter_manager = BetFilterManager.new()

func after_each():
	"""Очистка после каждого теста"""
	filter_manager = null

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: is_bet_type_enabled_in_settings
# ═══════════════════════════════════════════════════════════════════════════

func test_is_bet_type_enabled_no_managers():
	"""Проверка: нет менеджеров - должно быть true для основных типов"""
	var result = filter_manager.is_bet_type_enabled_in_settings("Player", null, null)
	assert_true(result, "Должно быть true без менеджеров")

func test_is_bet_type_enabled_unknown_type():
	"""Проверка: неизвестный тип - должно быть true"""
	var result = filter_manager.is_bet_type_enabled_in_settings("Unknown", null, null)
	assert_true(result, "Неизвестный тип должен возвращать true")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: is_bet_type_enabled_in_snapshot
# ═══════════════════════════════════════════════════════════════════════════

func test_is_bet_type_enabled_in_snapshot_empty():
	"""Проверка: пустой snapshot - должно использовать настройки"""
	var result = filter_manager.is_bet_type_enabled_in_snapshot("Player", null, null)
	assert_true(result, "Пустой snapshot должен использовать настройки (fallback)")

func test_is_bet_type_enabled_in_snapshot_with_snapshot():
	"""Проверка: есть snapshot - должно использовать snapshot"""
	filter_manager.filter_snapshot["Player"] = false
	var result = filter_manager.is_bet_type_enabled_in_snapshot("Player", null, null)
	assert_false(result, "Должно использовать значение из snapshot")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: save_filter_snapshot
# ═══════════════════════════════════════════════════════════════════════════

func test_save_filter_snapshot_no_managers():
	"""Проверка: сохранение snapshot без менеджеров"""
	filter_manager.save_filter_snapshot(null, null)
	assert_false(filter_manager.has_filter_snapshot(), "Snapshot должен быть пустым без менеджеров")

func test_clear_filter_snapshot():
	"""Проверка: очистка snapshot"""
	filter_manager.filter_snapshot["Player"] = true
	filter_manager.clear_filter_snapshot()
	assert_false(filter_manager.has_filter_snapshot(), "Snapshot должен быть очищен")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: pending_filter_changes
# ═══════════════════════════════════════════════════════════════════════════

func test_add_pending_filter_change():
	"""Проверка: добавление изменения в очередь"""
	filter_manager.add_pending_filter_change("Player", false)
	assert_true(filter_manager.has_pending_filter_changes(), "Должны быть pending changes")
	assert_eq(filter_manager.get_pending_filter_changes().get("Player", true), false, "Значение должно быть false")

func test_clear_pending_filter_changes():
	"""Проверка: очистка pending changes"""
	filter_manager.add_pending_filter_change("Player", false)
	filter_manager.clear_pending_filter_changes()
	assert_false(filter_manager.has_pending_filter_changes(), "Pending changes должны быть очищены")

func test_get_pending_filter_changes():
	"""Проверка: получение pending changes"""
	filter_manager.add_pending_filter_change("Player", true)
	filter_manager.add_pending_filter_change("Banker", false)
	var changes = filter_manager.get_pending_filter_changes()
	assert_eq(changes.size(), 2, "Должно быть 2 изменения")
	assert_eq(changes.get("Player", false), true, "Player должен быть true")
	assert_eq(changes.get("Banker", true), false, "Banker должен быть false")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ: apply_pending_filter_changes
# ═══════════════════════════════════════════════════════════════════════════

func test_apply_pending_filter_changes_empty():
	"""Проверка: применение пустых изменений"""
	var result = filter_manager.apply_pending_filter_changes(null, null)
	assert_false(result.get("applied", true), "Не должно быть применено")
	assert_eq(result.get("changes", {}).size(), 0, "Не должно быть изменений")

