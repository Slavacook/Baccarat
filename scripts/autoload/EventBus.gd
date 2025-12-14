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
@warning_ignore("unused_signal")
signal payout_correct(collected: float, expected: float)

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
@warning_ignore("unused_signal")
signal life_lost()

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
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	print("🚌 EventBus готов! Все события централизованы.")
