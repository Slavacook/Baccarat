# res://scripts/autoload/EventBus.gd
# Централизованная система событий для всех менеджеров
# Использование: EventBus.action_correct.emit("player_third")
extends Node

# ═══════════════════════════════════════════════════════════════════════════
# 🎮 ИГРОВОЙ ПРОЦЕСС
# ═══════════════════════════════════════════════════════════════════════════

## Первые 4 карты розданы
@warning_ignore("unused_signal")
signal cards_dealt(player_hand: Array[Card], banker_hand: Array[Card])

## Игрок получил третью карту
@warning_ignore("unused_signal")
signal player_third_drawn(card: Card)

## Банкир получил третью карту
@warning_ignore("unused_signal")
signal banker_third_drawn(card: Card)

## Все карты открыты, нужно выбрать победителя
@warning_ignore("unused_signal")
signal game_completed()

## Раунд сброшен, начинается новый
@warning_ignore("unused_signal")
signal round_reset()

## Первая раздача завершена (флаг is_first_deal сброшен)
@warning_ignore("unused_signal")
signal first_deal_completed()

## Стол подготовлен к новой игре (флаг is_table_prepared установлен)
@warning_ignore("unused_signal")
signal table_prepared_for_new_game()

# ═══════════════════════════════════════════════════════════════════════════
# 📷 КАМЕРА
# ═══════════════════════════════════════════════════════════════════════════

## Запрос на зум камеры (от GamePhaseManager)
## zoom_type: "in" (карты), "out" (общий план), "area_1/2/3" (области ставок)
## "next_area", "prev_area" - переключение между областями
@warning_ignore("unused_signal")
signal camera_zoom_requested(zoom_type: String)

## Показать/скрыть кнопки областей (для выбора области после определения победителя)
@warning_ignore("unused_signal")
signal area_buttons_visibility_changed(visible: bool)

## Показать/скрыть стрелки навигации (при зуме на область)
@warning_ignore("unused_signal")
signal navigation_arrows_visibility_changed(visible: bool)

## ═══════════════════════════════════════════════════════════════════════════
## 📷 КАМЕРА - ЗАПРОСЫ СОСТОЯНИЯ (для полной инкапсуляции)
## ═══════════════════════════════════════════════════════════════════════════

## Запрос текущей области камеры (0 = карты, 1-3 = области ставок)
## Ответ через camera_current_area_received
@warning_ignore("unused_signal")
signal camera_current_area_requested()

## Ответ на запрос текущей области
@warning_ignore("unused_signal")
signal camera_current_area_received(area: int)

## Запрос целевой области по направлению из текущего состояния
## direction: "left", "right", "up", "down"
## Ответ через camera_target_area_received
@warning_ignore("unused_signal")
signal camera_target_area_requested(direction: String)

## Ответ на запрос целевой области
@warning_ignore("unused_signal")
signal camera_target_area_received(direction: String, target_area: int)

## Запрос целевой области из указанной области
## area: исходная область (0 = карты, 1-3 = области ставок)
## direction: "left", "right", "up", "down"
## Ответ через camera_target_area_from_received
@warning_ignore("unused_signal")
signal camera_target_area_from_requested(area: int, direction: String)

## Ответ на запрос целевой области из указанной
@warning_ignore("unused_signal")
signal camera_target_area_from_received(area: int, direction: String, target_area: int)

## Запрос настроек камеры (позиция, зум)
## Ответ через camera_settings_received
@warning_ignore("unused_signal")
signal camera_settings_requested()

## Ответ на запрос настроек камеры
@warning_ignore("unused_signal")
signal camera_settings_received(position: Vector2, zoom: Vector2)

## Запрос на установку is_first_deal
@warning_ignore("unused_signal")
signal camera_first_deal_set_requested(value: bool)

# ═══════════════════════════════════════════════════════════════════════════
# ✅ ПРАВИЛЬНЫЕ ДЕЙСТВИЯ
# ═══════════════════════════════════════════════════════════════════════════

## Игрок сделал правильное действие
## type: "player_third", "banker_third", "both_third", "winner", "payout"
@warning_ignore("unused_signal")
signal action_correct(type: String)

## Победитель определён правильно
@warning_ignore("unused_signal")
signal winner_correct(winner: String, player_hand: Array[Card], banker_hand: Array[Card])

# ═══════════════════════════════════════════════════════════════════════════
# ❌ ОШИБКИ ИГРОКА
# ═══════════════════════════════════════════════════════════════════════════

## Игрок сделал ошибку
## type: "player_wrong", "banker_wrong", "natural_draw", "both_wrong", "winner_early", "winner_wrong", "payout_wrong"
@warning_ignore("unused_signal")
signal action_error(type: String, message: String)

# ═══════════════════════════════════════════════════════════════════════════
# 💰 ВЫПЛАТЫ И СТАВКИ
# ═══════════════════════════════════════════════════════════════════════════

## Победитель определён, нужно показать попап выплаты
@warning_ignore("unused_signal")
signal show_payout_popup(winner: String, stake: float, payout: float)

## Игрок правильно рассчитал выплату
## bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
## position_index: Индекс позиции ставки (для определения гостевых ставок, -1 если не гостевые)
@warning_ignore("unused_signal")
signal payout_correct(collected: float, expected: float, bet_type: String, position_index: int)

## Игрок неправильно рассчитал выплату
@warning_ignore("unused_signal")
signal payout_wrong(collected: float, expected: float)

## Использована подсказка (hint)
@warning_ignore("unused_signal")
signal hint_used()

## Запрос подготовки выплат вручную (вызывается из GamePhaseManager)
@warning_ignore("unused_signal")
signal manual_payout_requested(winner: String)

## Изменена настройка выплаты (включена/выключена ставка)
## bet_type: "Player", "Banker", "Tie", "PairPlayer", "PairBanker"
## enabled: true (включено) / false (выключено)
@warning_ignore("unused_signal")
signal payout_setting_changed(bet_type: String, enabled: bool)

# ═══════════════════════════════════════════════════════════════════════════
# 📢 УВЕДОМЛЕНИЯ (TOAST)
# ═══════════════════════════════════════════════════════════════════════════

## Показать информационное сообщение (серый toast)
@warning_ignore("unused_signal")
signal show_toast_info(message: String)

## Показать успех (зелёный toast)
@warning_ignore("unused_signal")
signal show_toast_success(message: String)

## Показать ошибку (красный toast)
@warning_ignore("unused_signal")
signal show_toast_error(message: String)

# ═══════════════════════════════════════════════════════════════════════════
# 🎬 OVERLAY-УВЕДОМЛЕНИЯ (БОЛЬШИЕ НАДПИСИ)
# ═══════════════════════════════════════════════════════════════════════════

## Показать успешное overlay-уведомление (зелёный, "Верно!")
@warning_ignore("unused_signal")
signal show_overlay_success(message: String, duration: float)

## Показать overlay-ошибку (красный, "Ошибка!")
@warning_ignore("unused_signal")
signal show_overlay_error(message: String, duration: float)

## Показать overlay-информацию (синий, game over, потеря жизни)
@warning_ignore("unused_signal")
signal show_overlay_info(message: String, duration: float)

# ═══════════════════════════════════════════════════════════════════════════
# ⚙️ НАСТРОЙКИ И РЕЖИМЫ
# ═══════════════════════════════════════════════════════════════════════════

## Режим игры изменён ("junket" или "classic")
@warning_ignore("unused_signal")
signal game_mode_changed(mode: String)

## Язык изменён ("ru" или "en")
@warning_ignore("unused_signal")
signal language_changed(lang: String)

## Режим выживания вкл/выкл
@warning_ignore("unused_signal")
signal survival_mode_changed(enabled: bool)

## Рубашка карт изменена ("tiger" или "leopard")
@warning_ignore("unused_signal")
signal card_back_style_changed(style: String)

## Режим случайных позиций фишек изменён (вкл/выкл) - для обратной совместимости
@warning_ignore("unused_signal")
signal random_positions_changed(enabled: bool)

## Режим позиций фишек изменён (DEFAULT=0, RANDOM=1, MAX=2)
@warning_ignore("unused_signal")
signal position_mode_changed(mode: int)

## Лимиты стола изменены
@warning_ignore("unused_signal")
signal table_limits_changed(min_bet: int, max_bet: int, step: int, tie_min: int, tie_max: int, tie_step: int)

# ═══════════════════════════════════════════════════════════════════════════
# 💔 РЕЖИМ ВЫЖИВАНИЯ
# ═══════════════════════════════════════════════════════════════════════════

## Запрос на потерю жизни (от GamePhaseManager)
@warning_ignore("unused_signal")
signal life_loss_requested()

## Игрок потерял жизнь
## Args: remaining_lives - оставшееся количество жизней
@warning_ignore("unused_signal")
signal life_lost(remaining_lives: int)

## Игра окончена (game over)
@warning_ignore("unused_signal")
signal game_over(rounds_survived: int)

## Игра перезапущена (restart)
@warning_ignore("unused_signal")
signal game_restarted()

# ═══════════════════════════════════════════════════════════════════════════
# 📊 СОСТОЯНИЯ ИГРЫ
# ═══════════════════════════════════════════════════════════════════════════

## Состояние игры изменилось
@warning_ignore("unused_signal")
signal game_state_changed(old_state: int, new_state: int)

# ═══════════════════════════════════════════════════════════════════════════
# ❤️ СТАВКА СЕРДЦЕМ (HEART BET)
# ═══════════════════════════════════════════════════════════════════════════

## Триггер сработал - шанс доступен
## trigger_name: имя сработавшего триггера ("BankerSix", "NaturalWin")
@warning_ignore("unused_signal")
signal heart_bet_trigger_activated(trigger_name: String)

## Показать UI с сердцами (начало фазы выбора)
@warning_ignore("unused_signal")
signal heart_bet_show_ui()

## Скрыть UI с сердцами
@warning_ignore("unused_signal")
signal heart_bet_hide_ui()

## Сердце выбрано (Player/Banker/Tie)
@warning_ignore("unused_signal")
signal heart_bet_selected(target: String)

## Ставка отменена (нажали "Начать" без выбора)
@warning_ignore("unused_signal")
signal heart_bet_declined()

## Ставка подтверждена (нажали "Начать" с выбором)
@warning_ignore("unused_signal")
signal heart_bet_confirmed(target: String)

## Результат ставки - выигрыш
## target: на что ставили ("Player", "Banker", "Tie")
## lives_gained: сколько жизней получено (1 для Player/Banker, 6 для Tie)
@warning_ignore("unused_signal")
signal heart_bet_won(target: String, lives_gained: int)

## Результат ставки - проигрыш
## target: на что ставили
## lives_remaining: сколько жизней осталось после проигрыша
@warning_ignore("unused_signal")
signal heart_bet_lost(target: String, lives_remaining: int)

## Сердце взято в залог (визуальное изменение в UI жизней)
@warning_ignore("unused_signal")
signal heart_pledged()

## Сердце возвращено из залога
@warning_ignore("unused_signal")
signal heart_returned()

## Жизни добавлены (после выигрыша heart bet)
## lives_added: количество добавленных жизней
## total_lives: итоговое количество жизней
@warning_ignore("unused_signal")
signal lives_added(lives_added: int, total_lives: int)

## Скрыть ставки гостей (при выборе сердца для Heart Bet)
@warning_ignore("unused_signal")
signal guest_bets_hide_requested()

## Показать ставки гостей (после завершения Heart Bet раздачи)
@warning_ignore("unused_signal")
signal guest_bets_show_requested()

## Скрыть выбранное сердце со стола (после определения результата)
@warning_ignore("unused_signal")
signal heart_bet_hide_selected()

## Heart Bet раздача завершена - сбросить раунд без выплат
@warning_ignore("unused_signal")
signal heart_bet_round_complete()

## Карта шанса нажата (маленькая) - DEPRECATED, используйте chance_card_storage_clicked
@warning_ignore("unused_signal")
signal chance_card_pressed()

## Запрос использования шанса (нажата кнопка "Использовать") - DEPRECATED, используйте chance_card_used
@warning_ignore("unused_signal")
signal chance_card_use_requested()

## Popup карты закрыт (без использования) - DEPRECATED
@warning_ignore("unused_signal")
signal chance_card_popup_closed()

## Счётчик шансов изменился
@warning_ignore("unused_signal")
signal chance_count_changed(count: int)

# ═══════════════════════════════════════════════════════════════════════════
# 🎴 НОВАЯ СИСТЕМА КАРТ ШАНСА
# ═══════════════════════════════════════════════════════════════════════════

## Карта зарегистрирована в ChanceCardManager
@warning_ignore("unused_signal")
signal chance_card_registered(card_id: String)

## Карта активирована триггером
@warning_ignore("unused_signal")
signal chance_card_triggered(card_id: String)

## Запрос показа карты на весь экран
@warning_ignore("unused_signal")
signal chance_card_fullscreen_requested(card_id: String)

## Клик на миниатюру карты в хранилище
@warning_ignore("unused_signal")
signal chance_card_storage_clicked(card_id: String)

## Анимация карты завершена (уход в хранилище)
@warning_ignore("unused_signal")
signal chance_card_animation_complete(card_id: String)

## Триггер карты Heart Card (срабатывает при победе банкира с 6)
@warning_ignore("unused_signal")
signal heart_card_triggered()

## Триггер карты Heart Bet (шанс сыграть на жизнь - срабатывает при Tie)
@warning_ignore("unused_signal")
signal heart_bet_card_triggered()

## Триггер карты Mystery (срабатывает при натуральной победе)
@warning_ignore("unused_signal")
signal mystery_card_triggered()

## Триггер карты Revolver (срабатывает при двух парах одновременно)
@warning_ignore("unused_signal")
signal revolver_card_triggered()

## Триггер карты Third Card Change (срабатывает когда все 6 карт - картинки)
@warning_ignore("unused_signal")
signal third_card_change_triggered()

# ═══════════════════════════════════════════════════════════════════════════
# ⌨️ КЛАВИАТУРНОЕ УПРАВЛЕНИЕ И ФОКУС
# ═══════════════════════════════════════════════════════════════════════════

## Фокус изменился на другой элемент
## target: "BankerThird", "PlayerThird", "BankerMarker", "PlayerMarker", "TieMarker", "None"
@warning_ignore("unused_signal")
signal focus_changed(target: String)

## Элемент в фокусе активирован (двойное нажатие)
## target: "BankerThird", "PlayerThird", "BankerMarker", "PlayerMarker", "TieMarker"
@warning_ignore("unused_signal")
signal focus_activated(target: String)

## Запрос нажатия кнопки Action (Space)
@warning_ignore("unused_signal")
signal keyboard_action_requested()

## Управление фокусом активировано/деактивировано
## enabled: true = фаза раздачи карт, false = фаза сбора фишек
@warning_ignore("unused_signal")
signal focus_control_enabled(enabled: bool)

# ═══════════════════════════════════════════════════════════════════════════
# 🔧 НАСТРОЙКИ
# ═══════════════════════════════════════════════════════════════════════════

## Окно настроек открыто (для блокировки ввода)
@warning_ignore("unused_signal")
signal settings_opened()

## Окно настроек закрыто (для включения action_button обратно)
@warning_ignore("unused_signal")
signal settings_closed()

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ ИГРЫ (для проверки из RefCounted классов)
# ═══════════════════════════════════════════════════════════════════════════

## Флаг активности игры (обновляется из GameController)
var is_game_active: bool = true

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	print("🚌 EventBus готов! Все события централизованы.")
