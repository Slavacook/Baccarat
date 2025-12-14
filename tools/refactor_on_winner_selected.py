#!/usr/bin/env python3
"""
Рефакторинг _on_winner_selected() с Guard Clauses + Extract Method
Разбивает 106 строк на 7 helper методов
"""

def create_refactored_methods():
    """Создаёт рефакторенные методы"""

    # Главный метод с guard clauses
    main_method = '''func _on_winner_selected(chosen: String):
\t"""Обработка выбора победителя игроком
\t
\tРефакторенная версия с guard clauses + Extract Method.
\tБыло: 106 строк с глубокой вложенностью
\tСтало: ~15 строк главный метод + 7 helper методов
\t"""
\t# Guard 1: Проверка валидности выбора победителя
\tif not _is_winner_selection_valid():
\t\treturn
\t
\tvar actual = BaccaratRules.get_winner(phase_manager.player_hand, phase_manager.banker_hand)
\t
\t# Guard 2: Неправильный выбор победителя
\tif chosen != actual:
\t\t_handle_incorrect_winner_choice()
\t\treturn
\t
\t# Правильный выбор → обработка выплат
\tawait _handle_correct_winner_choice(actual)


'''

    # Helper методы
    helpers = '''# ═══════════════════════════════════════════════════════════════════════════
# ВЫБОР ПОБЕДИТЕЛЯ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _is_winner_selection_valid() -> bool:
\t"""Проверка валидности выбора победителя
\t
\tReturns:
\t\ttrue если выбор валиден, false если нет (с эмитом ошибки)
\t"""
\tif not GameStateManager.is_action_valid(GameStateManager.Action.SELECT_WINNER):
\t\tvar error_msg = GameStateManager.get_error_message(GameStateManager.Action.SELECT_WINNER)
\t\t
\t\t# Штраф только если не в состоянии WAITING (карты уже раздавались)
\t\tvar current_state = GameStateManager.get_current_state()
\t\tif current_state != GameStateManager.GameState.WAITING:
\t\t\tEventBus.action_error.emit("winner_early", error_msg)
\t\t
\t\tDebugLogger.log("🚫 [НОВАЯ СИСТЕМА] %s" % error_msg)
\t\treturn false
\t
\treturn true


func _handle_incorrect_winner_choice() -> void:
\t"""Обработка неправильного выбора победителя"""
\tEventBus.action_error.emit("winner_wrong", "")
\t# Жизнь отнимается автоматически через EventBus → SurvivalModeUI


func _handle_correct_winner_choice(actual: String) -> void:
\t"""Обработка правильного выбора победителя
\t
\tArgs:
\t\tactual: Фактический победитель (Player/Banker/Tie)
\t"""
\t# ✅ Правильный выбор победителя
\tEventBus.action_correct.emit("winner")
\t
\t# Блокируем маркеры, чтобы игрок не мог случайно изменить выбор во время выплат
\tif winner_selection_manager:
\t\twinner_selection_manager.lock_markers()
\t
\t# Пауза 1 секунда (карты остаются открытыми, маркер активен)
\tawait get_tree().create_timer(GameConstants.VICTORY_TOAST_DELAY).timeout
\t
\t# Создаём очередь выплат
\t_create_payout_queue(actual)
\t
\t# Обрабатываем очередь или сбрасываем раунд
\t_process_payout_queue_or_reset()


func _create_payout_queue(actual: String) -> void:
\t"""Создание очереди выплат (основная ставка + пары)
\t
\tArgs:
\t\tactual: Фактический победитель (Player/Banker/Tie)
\t"""
\tvar player_score = BaccaratRules.hand_value(phase_manager.player_hand)
\tvar banker_score = BaccaratRules.hand_value(phase_manager.banker_hand)
\t
\t# Очищаем очередь перед созданием новой
\tGameDataManager.clear_payout_queue()
\t
\t# 1. Добавляем основную ставку (если активна)
\t_add_main_bet_to_queue(actual, player_score, banker_score)
\t
\t# 2. Добавляем ставки на пары (если обнаружены)
\t_add_pair_bets_to_queue(player_score, banker_score)
\t
\t# Выводим статус очереди
\tGameDataManager.print_queue_status()


func _add_main_bet_to_queue(actual: String, player_score: int, banker_score: int) -> void:
\t"""Добавление основной ставки в очередь (Player/Banker/Tie)
\t
\tArgs:
\t\tactual: Фактический победитель
\t\tplayer_score: Очки игрока
\t\tbanker_score: Очки банкира
\t"""
\tif not PayoutSettingsManager.is_payout_enabled(actual):
\t\treturn
\t
\tvar stake: float = 0.0
\tvar payout: float = 0.0
\t
\tif actual == "Banker":
\t\tstake = limits_manager.generate_bet()
\t\tvar commission = GameModeManager.get_banker_commission()
\t\tif GameModeManager.get_mode_string() == "classic":
\t\t\tvar banker_value = BaccaratRules.hand_value(phase_manager.banker_hand)
\t\t\tif banker_value == 6:
\t\t\t\tcommission = 0.5
\t\tpayout = stake * commission
\telif actual == "Tie":
\t\tstake = limits_manager.generate_tie_bet()
\t\tpayout = stake * 8.0
\telse:  # Player
\t\tstake = limits_manager.generate_bet()
\t\tpayout = stake * 1.0
\t
\tGameDataManager.add_to_payout_queue(actual, stake, payout, player_score, banker_score)


func _add_pair_bets_to_queue(player_score: int, banker_score: int) -> void:
\t"""Добавление ставок на пары в очередь выплат
\t
\tArgs:
\t\tplayer_score: Очки игрока
\t\tbanker_score: Очки банкира
\t"""
\t# Пара игрока - если обнаружена И ставка была
\tif pair_betting_manager.player_pair_detected and pair_betting_manager.pair_player_bet_enabled:
\t\tvar stake = limits_manager.generate_pair_bet()
\t\tvar payout = pair_betting_manager.calculate_pair_payout(stake, "PairPlayer")
\t\tGameDataManager.add_to_payout_queue("PairPlayer", stake, payout, player_score, banker_score)
\t
\t# Пара банкира - если обнаружена И ставка была
\tif pair_betting_manager.banker_pair_detected and pair_betting_manager.pair_banker_bet_enabled:
\t\tvar stake = limits_manager.generate_pair_bet()
\t\tvar payout = pair_betting_manager.calculate_pair_payout(stake, "PairBanker")
\t\tGameDataManager.add_to_payout_queue("PairBanker", stake, payout, player_score, banker_score)


func _process_payout_queue_or_reset() -> void:
\t"""Обработка очереди выплат или сброс раунда (если очередь пуста)"""
\tif GameDataManager.has_more_payouts():
\t\t# Есть выплаты → берём первую и переходим в PayoutScene
\t\tvar next_payout = GameDataManager.get_next_payout()
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
\t\t# Сохраняем состояние игры (сердечки, раунды)
\t\tGameDataManager.set_game_state(
\t\t\tsurvival_rounds_completed,
\t\t\tsurvival_ui.current_lives,
\t\t\tsurvival_ui.is_active
\t\t)
\t\t
\t\tget_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
\telse:
\t\t# Нет выплат → сразу новый раунд
\t\tphase_manager.reset()


'''

    return main_method, helpers


def apply_refactoring(filepath):
    """Применяет рефакторинг к GameController.gd"""

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Находим начало и конец метода _on_winner_selected()
    start_line = None
    end_line = None

    for i, line in enumerate(lines):
        if line.strip().startswith('func _on_winner_selected('):
            start_line = i
        if start_line is not None and i > start_line:
            # Ищем следующий метод
            if line.startswith('func ') and '_on_winner_selected' not in line:
                end_line = i
                break

    if start_line is None:
        print("❌ Метод _on_winner_selected() не найден!")
        return False

    if end_line is None:
        end_line = len(lines)

    print(f"✅ Найден метод _on_winner_selected() (строки {start_line+1}-{end_line})")
    print(f"   Размер: {end_line - start_line} строк")

    # Создаём backup
    backup_path = filepath + '.winner_selected_backup'
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f"✅ Создан backup: {backup_path}")

    # Получаем рефакторенные методы
    main_method, helpers = create_refactored_methods()

    # Заменяем старый метод на новый + добавляем helper методы
    new_content = main_method + helpers + '\n'

    new_lines = lines[:start_line] + [new_content] + lines[end_line:]

    # Сохраняем рефакторенный файл
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    old_method_lines = end_line - start_line
    print(f"\n✅ Рефакторинг применён!")
    print(f"   Было: {old_method_lines} строк в _on_winner_selected()")
    print(f"   Стало: ~15 строк главный метод + 7 helper методов")
    print(f"   Паттерны: Guard Clauses + Extract Method")
    return True


if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Использование: python3 refactor_on_winner_selected.py <filepath>")
        sys.exit(1)

    filepath = sys.argv[1]
    apply_refactoring(filepath)
