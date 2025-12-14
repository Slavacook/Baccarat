#!/usr/bin/env python3
"""
Рефакторинг _check_payout_return() с Extract Method паттерном
Разбивает 208 строк на 10 helper методов
"""

def create_refactored_methods():
    """Создаёт рефакторенные методы"""

    # Главный метод с guard clauses
    main_method = '''func _check_payout_return():
\t"""Проверка возврата из PayoutScene (ручной или автоматический режим)"""
\t
\t# Guard Clause 1: Ручной режим через PayoutContextManager
\tif PayoutContextManager.has_context():
\t\tvar context = PayoutContextManager.get_context()
\t\tif context.get("manual_mode", false):
\t\t\t_handle_manual_mode_payout_return(context)
\t\t\treturn
\t
\t# Guard Clause 2: Автоматический режим через GameDataManager
\tif GameDataManager.payout_winner != "":
\t\t_handle_automatic_mode_payout_return()
\t\treturn


'''

    # Helper методы для ручного режима
    helper_manual = '''# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ РЕЖИМ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_manual_mode_payout_return(context: Dictionary) -> void:
\t"""Обработка возврата из PayoutScene в ручном режиме"""
\tDebugLogger.log_restore("⏮ Возврат из PayoutScene (ручной режим)")
\t
\t# Guard: проверка сохранённого состояния
\tif not TableStateManager.has_saved_state():
\t\tpush_error("❌ TableStateManager не содержит сохраненного состояния!")
\t\tPayoutContextManager.clear_context()
\t\tGameDataManager.clear()
\t\treturn
\t
\t# 1-3. Восстановление карт, UI и GameStateManager
\t_restore_table_state()
\t
\t# 4-6. Восстановление survival режима и очереди выплат
\t_restore_survival_and_queue()
\t
\t# 7. Обработка результата текущей выплаты
\t_process_manual_payout_result(context)
\t
\t# 8. Восстановление камеры и очистка контекстов
\t_restore_camera_and_cleanup()


func _restore_table_state() -> void:
\t"""Восстановление карт, UI карт и GameStateManager"""
\t# 1. Восстанавливаем карты
\tphase_manager.player_hand = TableStateManager.player_hand.duplicate()
\tphase_manager.banker_hand = TableStateManager.banker_hand.duplicate()
\tDebugLogger.log("♻️  Восстановлены карты: Player=%d, Banker=%d" % [
\t\tphase_manager.player_hand.size(),
\t\tphase_manager.banker_hand.size()
\t])
\t
\t# 2. Показываем карты на UI
\t_restore_cards_ui()
\t
\t# 3. Обновляем GameStateManager с восстановленными картами
\tvar player_third_card = phase_manager.player_hand[2] if phase_manager.player_hand.size() >= 3 else null
\tvar banker_third_card = phase_manager.banker_hand[2] if phase_manager.banker_hand.size() >= 3 else null
\tGameStateManager.determine_and_update_state(
\t\tfalse,  # cards_hidden = false (карты открыты)
\t\tphase_manager.player_hand,
\t\tphase_manager.banker_hand,
\t\tplayer_third_card,
\t\tbanker_third_card
\t)
\tDebugLogger.log("♻️  GameStateManager обновлен: состояние = %s" % GameStateManager.get_current_state())


func _restore_survival_and_queue() -> void:
\t"""Восстановление маркера победителя, survival режима и очереди выплат"""
\t# 1. Восстанавливаем маркер победителя
\tvar saved_winner = TableStateManager.selected_winner
\tif saved_winner != "" and winner_selection_manager:
\t\twinner_selection_manager.select_winner(saved_winner)
\t\tDebugLogger.log("🎯 Восстановлен маркер: %s" % saved_winner)
\t
\t# 2. Восстанавливаем survival режим
\tsurvival_rounds_completed = TableStateManager.survival_rounds
\tif survival_ui:
\t\tsurvival_ui.is_active = TableStateManager.survival_active
\t\tsurvival_ui.set_lives(GameDataManager.survival_lives)
\t\tDebugLogger.log("♻️  Survival режим восстановлен: жизней=%d, раундов=%d" % [
\t\t\tGameDataManager.survival_lives, survival_rounds_completed
\t\t])
\t
\t# 3. Восстанавливаем PayoutQueueManager из TableStateManager
\tpayout_queue_manager = PayoutQueueManager.new()
\tfor bet_state in TableStateManager.bets:
\t\tpayout_queue_manager.add_bet(
\t\t\tbet_state.bet_type,
\t\t\tbet_state.stake,
\t\t\tbet_state.payout,
\t\t\tbet_state.won,
\t\t\tbet_state.player_score,
\t\t\tbet_state.banker_score
\t\t)
\t\t# Восстанавливаем статус оплаты
\t\tif bet_state.is_paid:
\t\t\tpayout_queue_manager.mark_as_paid(bet_state.bet_type)
\t
\tDebugLogger.log("♻️  Восстановлен PayoutQueueManager: %d ставок" % TableStateManager.bets.size())
\t
\t# КРИТИЧНО: Обновляем ссылку в phase_manager после восстановления!
\tphase_manager.payout_queue_manager = payout_queue_manager
\tDebugLogger.log_restore("⏮ Ссылка phase_manager.payout_queue_manager обновлена")
\t
\t# Обновляем видимость фишек (показываем неоплаченные выигрыши)
\t_update_chip_visibility()


func _process_manual_payout_result(context: Dictionary) -> void:
\t"""Обработка результата текущей выплаты в ручном режиме"""
\tvar bet_type = context.get("bet_type", "")
\tvar is_correct = GameDataManager.payout_is_correct
\tvar collected = GameDataManager.payout_collected
\tvar expected = GameDataManager.payout_expected
\t
\tif is_correct:
\t\tEventBus.payout_correct.emit(collected, expected)
\t\tDebugLogger.log("✅ Правильная выплата для %s: %.1f" % [bet_type, expected])
\t\t
\t\t# Отмечаем ставку как оплаченную в обоих менеджерах
\t\tpayout_queue_manager.mark_as_paid(bet_type)
\t\tTableStateManager.mark_bet_as_paid(bet_type)
\t\t
\t\t# Обновляем видимость фишек
\t\t_update_chip_visibility()
\t\t
\t\tDebugLogger.log_init("Все выплаты оплачены! Можно начинать новый раунд")
\telse:
\t\tEventBus.payout_wrong.emit(collected, expected)
\t\tDebugLogger.log("❌ Неправильная выплата для %s: собрано=%.1f, ожидалось=%.1f" % [
\t\t\tbet_type, collected, expected
\t\t])


func _restore_camera_and_cleanup() -> void:
\t"""Восстановление камеры и очистка контекстов"""
\t# Восстанавливаем камеру на общий план
\tif camera_manager and camera_manager.camera:
\t\tvar general_settings = camera_manager.get_config().get_general_settings()
\t\tcamera_manager.camera.position = general_settings.position
\t\tcamera_manager.camera.zoom = general_settings.zoom
\t\tcamera_manager.set_is_first_deal(false)
\t\tDebugLogger.log("📷 Камера восстановлена: общий план")
\t
\t# Показываем кнопки областей для выбора следующей области
\tEventBus.area_buttons_visibility_changed.emit(true)
\t
\t# Очищаем контексты
\tPayoutContextManager.clear_context()
\tPayoutContextManager.clear_saved_state()
\tGameDataManager.clear()


'''

    # Helper методы для автоматического режима
    helper_automatic = '''# ═══════════════════════════════════════════════════════════════════════════
# АВТОМАТИЧЕСКИЙ РЕЖИМ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _handle_automatic_mode_payout_return() -> void:
\t"""Обработка возврата из PayoutScene в автоматическом режиме"""
\t# 1. Восстанавливаем состояние игры и камеру
\t_restore_automatic_mode_state()
\t
\t# 2. Проверка Game Over
\tif _check_and_handle_game_over():
\t\treturn  # Game Over произошёл, выходим
\t
\t# 3. Обрабатываем результат выплаты
\t_process_automatic_payout_result()
\t
\t# 4. Обрабатываем очередь выплат
\t_handle_payout_queue()


func _restore_automatic_mode_state() -> void:
\t"""Восстановление состояния игры, камеры и UI"""
\t# Восстанавливаем состояние survival режима
\tsurvival_rounds_completed = GameDataManager.survival_rounds
\tsurvival_ui.current_lives = GameDataManager.survival_lives
\tsurvival_ui.is_active = GameDataManager.is_survival_active
\t
\t# Восстанавливаем камеру на общий план (без анимации)
\tif camera_manager and camera_manager.camera:
\t\tvar general_settings = camera_manager.get_config().get_general_settings()
\t\tcamera_manager.camera.position = general_settings.position
\t\tcamera_manager.camera.zoom = general_settings.zoom
\t\tcamera_manager.set_is_first_deal(false)
\t\tDebugLogger.log("📷 Камера восстановлена: общий план")
\t
\t# Показываем кнопки областей
\tEventBus.area_buttons_visibility_changed.emit(true)
\t
\t# Обновляем визуальное отображение сердечек
\tif survival_ui.is_active:
\t\tsurvival_ui._update_hearts()
\t\tsurvival_ui.show()
\telse:
\t\tsurvival_ui.hide()
\t
\tDebugLogger.log("♻️  Состояние игры восстановлено: rounds=%d, lives=%d, active=%s" % [
\t\tsurvival_rounds_completed, survival_ui.current_lives, survival_ui.is_active
\t])


func _check_and_handle_game_over() -> bool:
\t"""Проверка Game Over в режиме выживания
\t
\tReturns:
\t\ttrue если Game Over произошёл, false если игра продолжается
\t"""
\tif survival_ui.is_active and survival_ui.current_lives <= 0:
\t\tDebugLogger.log_game_flow("GAME OVER! Закончились жизни (проверка после возврата из PayoutScene)")
\t\t_on_survival_game_over(survival_rounds_completed)
\t\tGameDataManager.clear()
\t\treturn true
\t
\treturn false


func _process_automatic_payout_result() -> void:
\t"""Обработка результата выплаты в автоматическом режиме"""
\tvar is_correct = GameDataManager.payout_is_correct
\tvar collected = GameDataManager.payout_collected
\tvar expected = GameDataManager.payout_expected
\t
\tif is_correct:
\t\tEventBus.payout_correct.emit(collected, expected)
\t\tDebugLogger.log("✅ Правильно! Выплата: %s" % expected)
\t\tif is_survival_mode:
\t\t\tsurvival_rounds_completed += 1
\telse:
\t\tEventBus.payout_wrong.emit(collected, expected)
\t\tDebugLogger.log("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])


func _handle_payout_queue() -> void:
\t"""Обработка очереди выплат (переход к следующей или сброс раунда)"""
\tif GameDataManager.has_more_payouts():
\t\t# Есть ещё выплаты в очереди → берём следующую
\t\tvar next_payout = GameDataManager.get_next_payout()
\t\t
\t\tDebugLogger.log("🔄 Следующая выплата: %s (осталось %d)" % [
\t\t\tnext_payout.bet_type, GameDataManager.get_queue_size()
\t\t])
\t\t
\t\t# Сохраняем данные для PayoutScene
\t\tGameDataManager.set_payout_data(
\t\t\tnext_payout.bet_type,
\t\t\tnext_payout.stake,
\t\t\tnext_payout.payout,
\t\t\tnext_payout.player_score,
\t\t\tnext_payout.banker_score
\t\t)
\t\t
\t\t# Переходим в PayoutScene для следующей выплаты
\t\tget_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
\telse:
\t\t# Очередь пуста → сбрасываем раунд
\t\tDebugLogger.log_init("Все выплаты обработаны, сброс раунда")
\t\tGameDataManager.clear()
\t\t
\t\t# Сброс раунда только если последняя выплата была правильной
\t\tvar is_correct = GameDataManager.payout_is_correct
\t\tif is_correct:
\t\t\tphase_manager.reset()


'''

    return main_method, helper_manual, helper_automatic


def apply_refactoring(filepath):
    """Применяет рефакторинг к GameController.gd"""

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Находим начало и конец метода _check_payout_return()
    start_line = None
    end_line = None

    for i, line in enumerate(lines):
        if line.strip() == 'func _check_payout_return():':
            start_line = i
        if start_line is not None and i > start_line:
            # Ищем следующий метод (func) или секцию с комментарием
            if (line.startswith('func ') and '_check_payout_return' not in line) or \
               (line.strip().startswith('# ═══') and 'КАМЕРА' in line):
                end_line = i
                break

    if start_line is None:
        print("❌ Метод _check_payout_return() не найден!")
        return False

    if end_line is None:
        end_line = len(lines)

    print(f"✅ Найден метод _check_payout_return() (строки {start_line+1}-{end_line})")
    print(f"   Размер: {end_line - start_line} строк")

    # Создаём backup
    backup_path = filepath + '.check_payout_backup'
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f"✅ Создан backup: {backup_path}")

    # Получаем рефакторенные методы
    main_method, helper_manual, helper_automatic = create_refactored_methods()

    # Заменяем старый метод на новый + добавляем helper методы
    new_content = (
        main_method +
        helper_manual +
        helper_automatic +
        '\n'
    )

    new_lines = lines[:start_line] + [new_content] + lines[end_line:]

    # Сохраняем рефакторенный файл
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    old_method_lines = end_line - start_line
    print(f"\n✅ Рефакторинг применён!")
    print(f"   Было: {old_method_lines} строк в _check_payout_return()")
    print(f"   Стало: ~10 строк главный метод + 10 helper методов")
    print(f"   Вложенность: уменьшена через guard clauses")
    return True


if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Использование: python3 refactor_check_payout_return.py <filepath>")
        sys.exit(1)

    filepath = sys.argv[1]
    apply_refactoring(filepath)
