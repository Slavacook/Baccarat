#!/usr/bin/env python3
"""
Скрипт для применения рефакторинга on_action_pressed()
Заменяет метод на версию с guard clauses и добавляет helper методы
"""
import re

def apply_refactoring(filepath):
    """Применяет рефакторинг к GamePhaseManager.gd"""

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Находим начало и конец метода on_action_pressed()
    start_line = None
    end_line = None

    for i, line in enumerate(lines):
        if line.strip() == 'func on_action_pressed():':
            start_line = i
        if start_line is not None and i > start_line:
            # Ищем следующий метод (func) или конец файла
            if line.startswith('func ') and 'on_action_pressed' not in line:
                end_line = i
                break

    if start_line is None:
        print("❌ Метод on_action_pressed() не найден!")
        return False

    if end_line is None:
        # Метод последний в файле
        end_line = len(lines)

    print(f"✅ Найден метод on_action_pressed() (строки {start_line+1}-{end_line})")

    # Новый рефакторенный метод
    refactored_method = '''func on_action_pressed():
	DebugLogger.log_separator()
	DebugLogger.log_game_flow("on_action_pressed() вызван")
	DebugLogger.log("  → is_table_prepared = %s" % is_table_prepared)

	# ═══════════════════════════════════════════════════════════════════
	# GUARD CLAUSE 1: Подготовка к новой игре
	# ═══════════════════════════════════════════════════════════════════
	if is_table_prepared:
		DebugLogger.log_separator("ФЛАГ УСТАНОВЛЕН → вызываем deal_first_four()")
		deal_first_four()
		return

	DebugLogger.log("  → Флаг НЕ установлен, продолжаем обычную логику")
	var state = GameStateManager.get_current_state()
	DebugLogger.log("  → Текущее состояние: %s" % state)

	# ═══════════════════════════════════════════════════════════════════
	# GUARD CLAUSE 2: Начало игры
	# ═══════════════════════════════════════════════════════════════════
	if state == GameStateManager.GameState.WAITING:
		deal_first_four()
		return

	# ═══════════════════════════════════════════════════════════════════
	# GUARD CLAUSE 3: Валидация банкира после третьей игрока
	# ═══════════════════════════════════════════════════════════════════
	if state == GameStateManager.GameState.CARD_TO_BANKER_AFTER_PLAYER:
		_validate_banker_after_player()
		return

	# ═══════════════════════════════════════════════════════════════════
	# CHOOSE_WINNER: Основная логика выбора победителя и завершения
	# ═══════════════════════════════════════════════════════════════════
	if state == GameStateManager.GameState.CHOOSE_WINNER:
		_handle_choose_winner_state()
		return

	# ═══════════════════════════════════════════════════════════════════
	# FALLBACK: Валидация и раздача третьих карт
	# ═══════════════════════════════════════════════════════════════════
	_validate_and_execute_third_cards()


'''

    # Заменяем старый метод на новый
    new_lines = lines[:start_line] + [refactored_method] + lines[end_line:]

    # Находим конец класса для добавления helper методов
    # Ищем последний метод класса
    class_end = len(new_lines) - 1
    for i in range(len(new_lines) - 1, -1, -1):
        if new_lines[i].strip() and not new_lines[i].strip().startswith('#'):
            class_end = i + 1
            break

    # Helper методы
    helper_methods = '''
# ═══════════════════════════════════════════════════════════════════════════
# РЕФАКТОРЕННЫЕ HELPER МЕТОДЫ (из on_action_pressed)
# ═══════════════════════════════════════════════════════════════════════════

func _handle_choose_winner_state() -> void:
	"""Обработка состояния CHOOSE_WINNER (выбор победителя и завершение раунда)

	Рефакторенная версия с guard clauses для уменьшения вложенности.
	Было: 6+ уровней вложенности, 134 строки
	Стало: 2-3 уровня вложенности, разбито на методы
	"""

	# GUARD 1: Ошибочная попытка заказать карты в финале
	if player_third_selected or banker_third_selected:
		_handle_invalid_card_selection_in_final()
		return

	# GUARD 2: Первое нажатие - выбор победителя
	var button_state = ui.get_action_button_state()
	if button_state != "complete":
		_validate_winner_selection()
		return

	# GUARD 3: Проверка завершения раунда (неоплаченные ставки)
	if not _can_complete_round():
		return  # Сообщение об ошибке показано в _can_complete_round()

	# Все проверки пройдены → завершаем раунд
	_complete_round_and_prepare_new_game()


func _handle_invalid_card_selection_in_final() -> void:
	"""Обработка ошибочной попытки заказать карты когда все карты открыты"""

	var player_first_two = BaccaratRules.hand_value([player_hand[0], player_hand[1]])
	var banker_first_two = BaccaratRules.hand_value([banker_hand[0], banker_hand[1]])
	var is_natural = player_first_two >= 8 or banker_first_two >= 8

	var error_message = Localization.t("ERR_NATURAL_NO_DRAW") if is_natural else Localization.t("INFO_ALL_OPENED_CHOOSE_WINNER")
	EventBus.show_toast_error.emit(error_message)
	EventBus.action_error.emit("final_card_error", "")

	# Сбрасываем галочки
	player_third_selected = false
	banker_third_selected = false
	ui.update_player_third_card_ui("?")
	ui.update_banker_third_card_ui("?")


func _can_complete_round() -> bool:
	"""Проверка возможности завершения раунда (нет неоплаченных ставок)

	Returns:
		true если раунд можно завершить, false если есть неоплаченные ставки
	"""

	# Проверка через BetCollectionPhaseManager (приоритет)
	if bet_collection_manager:
		var completion_check = bet_collection_manager.can_complete_round()
		if not completion_check.can:
			var error_key = completion_check.error_key
			EventBus.show_toast_error.emit(Localization.t(error_key))
			EventBus.action_error.emit("incomplete_bets", error_key)
			ui.disable_action_button()
			DebugLogger.log("🔒 Кнопка 'Завершить' дезактивирована (причины: %s)" % str(completion_check.reasons))
			return false
		return true

	# Fallback: старая логика без bet_collection_manager
	if payout_queue_manager and payout_queue_manager.has_unpaid_winnings():
		var unpaid_count = payout_queue_manager.get_unpaid_count()
		EventBus.show_toast_error.emit(Localization.t("ERR_UNPAID_BETS"))
		EventBus.action_error.emit("unpaid_bets", "")
		ui.disable_action_button()
		DebugLogger.log("🔒 Кнопка 'Завершить' дезактивирована (неоплаченных ставок: %d)" % unpaid_count)
		return false

	return true


func _complete_round_and_prepare_new_game() -> void:
	"""Завершение раунда и подготовка к новой игре

	Выполняет:
	1. Показ сообщения о завершении (зависит от результата ставок)
	2. Зум камеры на общий план
	3. Начисление очков
	4. Сброс раунда
	5. Восстановление фишек
	6. Установка флага подготовки
	"""

	# Показываем сообщение о завершении
	_show_round_completion_message()

	DebugLogger.log_separator("ВСЕ ВЫПЛАТЫ ОПЛАЧЕНЫ → ПОДГОТОВКА К НОВОЙ ИГРЕ")

	# Зумаут камеры на общий план
	EventBus.camera_zoom_requested.emit("out")
	EventBus.area_buttons_visibility_changed.emit(false)
	EventBus.navigation_arrows_visibility_changed.emit(false)
	DebugLogger.log("  → ✅ Камера отзумлена, кнопки областей скрыты")

	# Начисляем +1 очко (только в режиме без сердечек)
	if not SaveManager.instance.load_survival_mode():
		SaveManager.instance.add_score(1)
		if StatsManager.instance:
			StatsManager.instance.update_stats()
		DebugLogger.log("  → ✅ +1 очко за завершение игры")

	# Сброс раунда БЕЗ обновления GameStateManager
	reset(false)
	DebugLogger.log("  → ✅ Сброс выполнен, карты показаны рубашками")

	# Восстанавливаем видимость активных фишек
	if chip_visual_manager:
		_restore_active_bet_chips()
		DebugLogger.log("  → ✅ Активные фишки восстановлены")

	# Устанавливаем флаг подготовки к новой игре
	is_table_prepared = true
	DebugLogger.log_separator("ПОДГОТОВКА ЗАВЕРШЕНА. Нажмите 'Карты' для новой раздачи")


func _show_round_completion_message() -> void:
	"""Показ сообщения о завершении раунда (зависит от результата ставок)"""

	DebugLogger.log_separator("Проверка завершения раунда")

	# Нет payout_queue_manager
	if not payout_queue_manager:
		DebugLogger.log_init("НЕТ АКТИВНЫХ СТАВОК → ЗАВЕРШАЕМ РАУНД")
		EventBus.show_toast_info.emit(Localization.t("NO_ACTIVE_BETS"))
		return

	# Нет ставок вообще
	if not payout_queue_manager.has_any_payouts():
		DebugLogger.log_init("НЕТ АКТИВНЫХ СТАВОК → ЗАВЕРШАЕМ РАУНД")
		EventBus.show_toast_info.emit(Localization.t("NO_ACTIVE_BETS"))
		return

	# Есть ставки - проверяем результат
	if payout_queue_manager.has_unpaid_winnings():
		DebugLogger.log_warning("⚠️ ЕСТЬ НЕОПЛАЧЕННЫЕ ВЫПЛАТЫ → НЕ ЗАВЕРШАЕМ РАУНД")
		return

	# Все выплаты оплачены
	var has_winning = payout_queue_manager.has_any_winning_bets()
	if has_winning:
		DebugLogger.log_init("ВСЕ СТАВКИ ОПЛАЧЕНЫ → ЗАВЕРШАЕМ РАУНД")
		EventBus.show_toast_info.emit(Localization.t("ALL_BETS_PAID"))
	else:
		DebugLogger.log_init("НЕТ ВЫИГРЫШНЫХ СТАВОК → ЗАВЕРШАЕМ РАУНД")
		EventBus.show_toast_info.emit(Localization.t("NO_WINNING_BETS"))

'''

    # Вставляем helper методы перед концом файла
    new_lines.insert(class_end, helper_methods)

    # Создаем еще один backup
    backup_path = filepath + '.refactored.backup'
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f"✅ Создан backup перед рефакторингом: {backup_path}")

    # Сохраняем рефакторенный файл
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    old_method_lines = end_line - start_line
    print(f"✅ Рефакторинг применён!")
    print(f"   Было: {old_method_lines} строк в on_action_pressed()")
    print(f"   Стало: ~50 строк + 5 helper методов")
    print(f"   Вложенность: 6+ уровней → 2-3 уровня")
    return True

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Использование: python3 apply_refactoring.py <filepath>")
        sys.exit(1)

    filepath = sys.argv[1]
    apply_refactoring(filepath)
