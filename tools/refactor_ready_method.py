#!/usr/bin/env python3
"""
Рефакторинг _ready() с Extract Method паттерном
Разбивает 198 строк на 10 helper методов
"""

def create_refactored_ready():
    """Создаёт рефакторенный метод _ready и helper методы"""

    # Главный метод-координатор
    main_method = '''func _ready():
\t"""Инициализация GameController
\t
\tРефакторенная версия с Extract Method паттерном.
\tБыло: 198 строк монолитной инициализации
\tСтало: ~35 строк координатор + 10 helper методов
\t"""
\t_initialize_core_managers()
\t_setup_settings_and_mode()
\t_setup_phase_manager()
\t_connect_ui_signals()
\t_setup_bet_collection()
\t
\tvar is_payout_return = _handle_payout_scene_return_or_reset()
\t_initialize_chips_visibility(is_payout_return)
\t_setup_event_subscriptions()
\t_finalize_setup()
\t
\t# Проверяем возврат из PayoutScene
\t_check_payout_return()


'''

    # Helper методы
    helpers = '''# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ - HELPER МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_core_managers() -> void:
\t"""Инициализация базовых менеджеров и компонентов"""
\tLocalization.set_lang("ru")
\tdeck = Deck.new()
\tif not config:
\t\tconfig = GameConfig.new()
\tcard_manager = CardTextureManager.new(config)
\tui_manager = UIManager.new(self, card_manager)
\tui_manager.set_main_node(self)
\tui_manager.set_flip_cards(flip_cards)
\tStatsManager.instance.set_label(ui_manager.stats_label)
\tlimits_manager = LimitsManager.new(config)
\tsurvival_ui = get_node("TopUI/SurvivalModeUI")
\tsurvival_ui.game_over.connect(_on_survival_game_over)
\tgame_over_popup = get_node("GameOverScene")
\t
\t# Подписываемся на Game Over по очкам
\tSaveManager.instance.score_game_over.connect(_on_score_game_over)


func _setup_settings_and_mode() -> void:
\t"""Настройка SettingsScene и загрузка режима игры"""
\t# Настройка SettingsScene
\tif has_node("SettingsScene"):
\t\tDebugLogger.log_init("SettingsScene найден в сцене!")
\t\tsettings_scene = get_node("SettingsScene")
\t\tsettings_scene.mode_changed.connect(_on_mode_changed)
\t\tsettings_scene.language_changed.connect(_on_language_changed)
\t\tsettings_scene.survival_mode_changed.connect(_on_survival_mode_changed)
\t\tDebugLogger.log_init("SettingsScene подключен к GameController")
\telse:
\t\tDebugLogger.log_error("SettingsScene НЕ НАЙДЕН в сцене Game.tscn!")
\t
\t# Настройка кнопки настроек
\tif has_node("SettingsButton"):
\t\tsettings_button = get_node("SettingsButton")
\t\tsettings_button.pressed.connect(_on_settings_button_pressed)
\t
\t# Загрузка режима игры
\tGameModeManager.load_saved_mode()
\t_load_survival_mode_setting()


func _setup_phase_manager() -> void:
\t"""Создание GamePhaseManager и вспомогательных менеджеров (Dependency Injection)"""
\t# Создаем все менеджеры ПЕРЕД phase_manager
\t_setup_chip_visual_manager()
\t_setup_winner_selection_manager()
\t_setup_pair_betting_manager()
\t
\t# Создаем phase_manager с передачей всех зависимостей
\tphase_manager = GamePhaseManager.new(
\t\tdeck,
\t\tcard_manager,
\t\tui_manager,
\t\tpayout_queue_manager,
\t\tchip_visual_manager,
\t\twinner_selection_manager,
\t\tpair_betting_manager
\t)


func _connect_ui_signals() -> void:
\t"""Подключение сигналов UIManager к обработчикам"""
\tui_manager.action_button_pressed.connect(phase_manager.on_action_pressed)
\tui_manager.player_third_toggled.connect(phase_manager.on_player_third_toggled)
\tui_manager.banker_third_toggled.connect(phase_manager.on_banker_third_toggled)
\tui_manager.tie_button_pressed.connect(phase_manager.on_tie_button_pressed)
\tui_manager.help_button_pressed.connect(_on_help_button_pressed)
\tui_manager.lang_button_pressed.connect(_on_lang_button_pressed)


func _setup_bet_collection() -> void:
\t"""Настройка менеджера фазы сбора/оплаты ставок"""
\tbet_collection_manager = BetCollectionPhaseManager.new()
\tphase_manager.bet_collection_manager = bet_collection_manager
\t
\t# Настраиваем кнопки collect/pay
\tui_manager.button_ui.setup_collect_pay_buttons(self)
\tui_manager.button_ui.collect_button_toggled.connect(_on_collect_mode_toggled)
\tui_manager.button_ui.pay_button_toggled.connect(_on_pay_mode_toggled)


func _handle_payout_scene_return_or_reset() -> bool:
\t"""Обработка возврата из PayoutScene или стандартный reset
\t
\tReturns:
\t\ttrue если возвращаемся из PayoutScene, false если обычная загрузка
\t"""
\tvar is_payout_return = PayoutContextManager.has_context() and PayoutContextManager.get_context().get("manual_mode", false)
\t
\tif not is_payout_return:
\t\t# Только если НЕ возвращаемся из PayoutScene - делаем reset
\t\tphase_manager.reset()
\t\tGameStateManager.reset()
\t\t
\t\t# Разблокируем маркеры для начала новой игры
\t\tif winner_selection_manager:
\t\t\twinner_selection_manager.unlock_markers()
\telse:
\t\tDebugLogger.log_restore("⏮ Пропускаем GameStateManager.reset() при возврате из PayoutScene")
\t
\tui_manager.help_popup.hide()
\tui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
\t
\treturn is_payout_return


func _initialize_chips_visibility(is_payout_return: bool) -> void:
\t"""Инициализация видимости фишек (восстановление или стандартная)
\t
\tArgs:
\t\tis_payout_return: true если возвращаемся из PayoutScene
\t"""
\tif is_payout_return:
\t\t# При возврате - восстанавливаем полный snapshot стола
\t\t_restore_chips_from_table_state()
\t\tDebugLogger.log_restore("⏮ Восстановлено состояние из TableStateManager snapshot")
\t\t
\t\t# Синхронизируем сердечки из GameDataManager
\t\tif is_survival_mode and survival_ui:
\t\t\tvar lives_from_payout = GameDataManager.survival_lives
\t\t\tsurvival_ui.set_lives(lives_from_payout)
\t\t\tDebugLogger.log("♻️  Синхронизированы сердечки: %d (из PayoutScene)" % lives_from_payout)
\t\t
\t\t# Восстанавливаем состояние кнопки
\t\tif ui_manager:
\t\t\tui_manager.set_action_button_state(TableStateManager.action_button_state)
\t\t\tui_manager.enable_action_button()
\t\t\tDebugLogger.log("♻️  Восстановлено состояние кнопки: %s" % TableStateManager.action_button_state)
\t\t\t
\t\t\t# Показываем кнопки Collect/Pay если мы в фазе выплат
\t\t\tif TableStateManager.action_button_state == "complete":
\t\t\t\tui_manager.button_ui.show_collect_pay_buttons()
\t\t\t\tDebugLogger.log_restore("⏮ Показаны кнопки Collect/Pay")
\telse:
\t\t# При обычной загрузке - показываем фишки на основе настроек
\t\t_show_chips_by_settings()


func _show_chips_by_settings() -> void:
\t"""Показ фишек на основе настроек PayoutSettingsManager"""
\tif not chip_visual_manager:
\t\treturn
\t
\tvar is_realistic = PayoutSettingsManager.is_realistic_mode_enabled()
\t
\tif is_realistic:
\t\t# REALISTIC режим - случайное количество фишек
\t\tif PayoutSettingsManager.player_payout_enabled:
\t\t\tchip_visual_manager.show_chips_realistic("Player")
\t\tif PayoutSettingsManager.banker_payout_enabled:
\t\t\tchip_visual_manager.show_chips_realistic("Banker")
\t\tif PayoutSettingsManager.tie_payout_enabled:
\t\t\tchip_visual_manager.show_chips_realistic("Tie")
\t\tif PayoutSettingsManager.player_pair_payout_enabled:
\t\t\tchip_visual_manager.show_chips_realistic("PairPlayer")
\t\t\tif pair_betting_manager:
\t\t\t\tpair_betting_manager.toggle_pair_player_bet(true)
\t\tif PayoutSettingsManager.banker_pair_payout_enabled:
\t\t\tchip_visual_manager.show_chips_realistic("PairBanker")
\t\t\tif pair_betting_manager:
\t\t\t\tpair_betting_manager.toggle_pair_banker_bet(true)
\t\tDebugLogger.log_init("Фишки синхронизированы (REALISTIC режим)")
\telse:
\t\t# Стандартный режим (DEFAULT, RANDOM, MAX)
\t\tif PayoutSettingsManager.player_payout_enabled:
\t\t\tchip_visual_manager.show_chip("Player")
\t\tif PayoutSettingsManager.banker_payout_enabled:
\t\t\tchip_visual_manager.show_chip("Banker")
\t\tif PayoutSettingsManager.tie_payout_enabled:
\t\t\tchip_visual_manager.show_chip("Tie")
\t\tif PayoutSettingsManager.player_pair_payout_enabled:
\t\t\tchip_visual_manager.show_chip("PairPlayer")
\t\t\tif pair_betting_manager:
\t\t\t\tpair_betting_manager.toggle_pair_player_bet(true)
\t\tif PayoutSettingsManager.banker_pair_payout_enabled:
\t\t\tchip_visual_manager.show_chip("PairBanker")
\t\t\tif pair_betting_manager:
\t\t\t\tpair_betting_manager.toggle_pair_banker_bet(true)
\t\tDebugLogger.log_init("Фишки синхронизированы с настройками")


func _setup_event_subscriptions() -> void:
\t"""Подписка на события EventBus"""
\tGameStateManager.state_changed.connect(_on_game_state_changed)
\tDebugLogger.log_game_flow("GameStateManager инициализирован")
\t
\t# Подписки на новые события EventBus
\tEventBus.manual_payout_requested.connect(_on_manual_payout_requested)
\tEventBus.table_prepared_for_new_game.connect(_on_table_prepared)
\tEventBus.payout_setting_changed.connect(_on_payout_setting_changed)
\tEventBus.card_back_style_changed.connect(_on_card_back_style_changed)
\tEventBus.position_mode_changed.connect(_on_position_mode_changed)
\tDebugLogger.log_init("Подписки на EventBus события установлены (payouts, flags, settings, card backs, position mode)")


func _finalize_setup() -> void:
\t"""Финальная настройка: limits, stats, camera, UI, keyboard, overlay"""
\t# Установка лимитов
\tvar cfg = GameModeManager.get_config()
\tlimits_manager.set_limits(
\t\tcfg["main_min"], cfg["main_max"], cfg["main_step"],
\t\tcfg["tie_min"], cfg["tie_max"], cfg["tie_step"],
\t\tcfg["pairs_min"], cfg["pairs_max"], cfg["pairs_step"],
\t\tfalse  # не показываем toast при инициализации
\t)
\t
\tStatsManager.instance.update_stats()
\t
\t# Настройка камеры
\t_setup_camera()
\t
\t# Перемещаем UI кнопки в TopUI для защиты от зума камеры
\t_setup_fixed_ui()
\t
\t# Настройка кнопок областей и стрелок навигации
\t_setup_area_buttons()
\t_setup_navigation_arrows()
\t
\t# Настройка клавиатурной навигации
\t_setup_keyboard_navigation()
\t
\t# Подключаем PayoutOverlay (новый способ выплат)
\tif has_node("PayoutOverlay"):
\t\tpayout_overlay = get_node("PayoutOverlay")
\t\tpayout_overlay.payout_completed.connect(_on_payout_overlay_completed)
\t\tpayout_overlay.hide()
\t\tDebugLogger.log_init("PayoutOverlay подключен к GameController (overlay режим)")
\telse:
\t\tif USE_OVERLAY_PAYOUT:
\t\t\tDebugLogger.log_warning("⚠️ PayoutOverlay НЕ НАЙДЕН в Game.tscn (но USE_OVERLAY_PAYOUT=true)")


'''

    return main_method, helpers


def apply_refactoring(filepath):
    """Применяет рефакторинг к GameController.gd"""

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Находим начало и конец метода _ready()
    start_line = None
    end_line = None

    for i, line in enumerate(lines):
        if line.strip() == 'func _ready():':
            start_line = i
        if start_line is not None and i > start_line:
            # Ищем следующий метод
            if line.startswith('func ') and '_ready' not in line:
                end_line = i
                break

    if start_line is None:
        print("❌ Метод _ready() не найден!")
        return False

    if end_line is None:
        end_line = len(lines)

    print(f"✅ Найден метод _ready() (строки {start_line+1}-{end_line})")
    print(f"   Размер: {end_line - start_line} строк")

    # Создаём backup
    backup_path = filepath + '.ready_backup'
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f"✅ Создан backup: {backup_path}")

    # Получаем рефакторенные методы
    main_method, helpers = create_refactored_ready()

    # Заменяем старый метод на новый + добавляем helper методы
    new_content = main_method + helpers + '\n'

    new_lines = lines[:start_line] + [new_content] + lines[end_line:]

    # Сохраняем рефакторенный файл
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    old_method_lines = end_line - start_line
    print(f"\n✅ Рефакторинг применён!")
    print(f"   Было: {old_method_lines} строк в _ready()")
    print(f"   Стало: ~20 строк главный метод + 10 helper методов")
    print(f"   Читаемость: значительно улучшена через группировку по зонам")
    return True


if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Использование: python3 refactor_ready_method.py <filepath>")
        sys.exit(1)

    filepath = sys.argv[1]
    apply_refactoring(filepath)
