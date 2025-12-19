# res://scripts/heart_bet/HeartBetManager.gd
# Главный менеджер системы "Ставка сердцем"
# Координирует триггеры, UI и результаты

class_name HeartBetManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

enum State {
	IDLE,       # Нет активного шанса
	AVAILABLE,  # Триггер сработал, шанс доступен (оверлей "Шанс!")
	PENDING,    # Сердца показаны, ожидание выбора
	SELECTED,   # Сердце выбрано, ожидание подтверждения
	ACTIVE,     # Ставка активна, идёт раздача
	RESOLVING   # Определение результата
}

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ НАГРАД (бонус ПОВЕРХ возврата залога!)
# ═══════════════════════════════════════════════════════════════════════════

## Бонус за угадывание Player или Banker (+1 жизнь бонус, итого +2 с возвратом залога)
const REWARD_PLAYER_BANKER: int = 1

## Бонус за угадывание Tie (+6 жизней бонус, итого +7 с возвратом залога)
const REWARD_TIE: int = 6

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Текущее состояние
var current_state: State = State.IDLE

## Выбранная цель ("Player", "Banker", "Tie")
var selected_target: String = ""

## Система триггеров
var trigger_system: HeartBetTriggerSystem

## Имя сработавшего триггера (для отладки)
var last_trigger_name: String = ""

## Счётчик накопленных шансов (НОВАЯ ЛОГИКА)
var chance_count: int = 0


func _init():
	trigger_system = HeartBetTriggerSystem.new()
	_connect_signals()
	print("❤️ HeartBetManager инициализирован")


func _connect_signals() -> void:
	"""Подписка на сигналы EventBus"""
	EventBus.heart_bet_selected.connect(_on_heart_selected)


# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Проверить триггеры после завершения раунда
## Возвращает true если какой-то триггер сработал
func check_triggers(winner: String, banker_score: int, player_score: int, is_natural: bool) -> bool:
	# #region agent log
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H9","location":"HeartBetManager.check_triggers","message":"checking triggers","data":{"current_state":"%s","winner":"%s","banker_score":%d,"player_score":%d,"is_natural":%s},"timestamp":%d}' % [State.keys()[current_state], winner, banker_score, player_score, str(is_natural).to_lower(), int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	# Можем накапливать шансы даже во время активной игры на жизнь
	# (но не во время RESOLVING)
	if current_state == State.RESOLVING:
		print("❤️ HeartBetManager: идёт разрешение ставки, пропускаем проверку триггеров")
		return false
	
	var triggered = trigger_system.check_all(winner, banker_score, player_score, is_natural)
	
	if triggered:
		# НОВАЯ ЛОГИКА: увеличиваем счётчик шансов
		chance_count += 1
		last_trigger_name = triggered.get_trigger_name()
		print("❤️ Триггер '%s' сработал! Шансов: %d" % [last_trigger_name, chance_count])
		EventBus.heart_bet_trigger_activated.emit(last_trigger_name)
		EventBus.chance_count_changed.emit(chance_count)
		return true
	
	return false


## Проверить, есть ли доступные шансы
func has_chances() -> bool:
	return chance_count > 0


## Получить количество шансов
func get_chance_count() -> int:
	return chance_count


## Использовать один шанс (вызывается при нажатии "Использовать")
## Возвращает true если шанс использован успешно
func use_chance() -> bool:
	# #region agent log
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H7","location":"HeartBetManager.use_chance","message":"use_chance called","data":{"chance_count":%d,"current_state":"%s"},"timestamp":%d}' % [chance_count, State.keys()[current_state], int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	if chance_count <= 0:
		print("❤️ HeartBetManager: нет доступных шансов")
		return false
	
	if current_state != State.IDLE:
		print("❤️ HeartBetManager: нельзя использовать шанс (state=%s)" % State.keys()[current_state])
		return false
	
	# Списываем шанс СРАЗУ
	chance_count -= 1
	print("❤️ Шанс использован! Осталось: %d" % chance_count)
	EventBus.chance_count_changed.emit(chance_count)
	
	# Переходим в фазу выбора
	current_state = State.PENDING
	selected_target = ""
	
	# Скрываем ставки гостей
	EventBus.guest_bets_hide_requested.emit()
	
	# Показываем сердца
	EventBus.heart_bet_show_ui.emit()
	
	# Блокируем карту шанса (чтобы нельзя было использовать вторую пока первая активна)
	EventBus.chance_count_changed.emit(chance_count)  # Это обновит UI
	
	return true


## Проверить, доступен ли шанс (УСТАРЕВШИЙ метод, используйте has_chances())
func is_available() -> bool:
	# Для обратной совместимости - проверяем счётчик
	return chance_count > 0 and current_state == State.IDLE


## Проверить, активна ли ставка (идёт раздача со ставкой)
func is_active() -> bool:
	return current_state == State.ACTIVE


## Проверить, выбрано ли сердце
func is_selected() -> bool:
	return current_state == State.SELECTED


## Проверить, ожидается ли выбор
func is_pending() -> bool:
	return current_state == State.PENDING


## Начать фазу выбора (показать сердца)
## УСТАРЕВШИЙ метод - теперь используется use_chance()
func start_selection_phase() -> void:
	# Для обратной совместимости перенаправляем на use_chance()
	if current_state == State.IDLE and chance_count > 0:
		use_chance()
	elif current_state == State.PENDING:
		# Уже в фазе выбора
		print("❤️ HeartBetManager: уже в фазе выбора")
	else:
		print("❤️ HeartBetManager: нельзя начать фазу выбора (state=%s, chances=%d)" % [State.keys()[current_state], chance_count])


## Обработка выбора сердца (из HeartBetUI)
func _on_heart_selected(target: String) -> void:
	if current_state != State.PENDING and current_state != State.SELECTED:
		print("❤️ HeartBetManager: выбор сердца недоступен (state=%s)" % State.keys()[current_state])
		return
	
	var first_selection = (current_state == State.PENDING)
	
	selected_target = target
	current_state = State.SELECTED
	
	if first_selection:
		# Первый выбор - берём сердце в залог
		print("❤️ Первый выбор: %s - берём сердце в залог" % target)
		EventBus.heart_pledged.emit()
		# Ставки гостей уже скрыты в use_chance()
	else:
		# Перевыбор - просто меняем цель
		print("❤️ Перевыбор: %s" % target)


## Подтвердить ставку (нажата кнопка "Начать")
## Возвращает true если ставка подтверждена, false если отклонена
func confirm() -> bool:
	print("❤️ HeartBetManager.confirm() вызван, state=%s" % State.keys()[current_state])
	
	match current_state:
		State.SELECTED:
			# Есть выбор - подтверждаем ставку
			current_state = State.ACTIVE
			print("❤️ Ставка подтверждена: %s → state=ACTIVE" % selected_target)
			# ВАЖНО: heart_bet_confirmed скроет НЕ-выбранные сердца (в HeartBetUI)
			# НЕ вызываем heart_bet_hide_ui - оно скрыло бы ВСЁ включая выбранное!
			EventBus.heart_bet_confirmed.emit(selected_target)
			return true
		
		State.PENDING:
			# Нет выбора - отказ от шанса
			print("❤️ Нет выбора → отклоняем")
			_decline()
			return false
		
		_:
			print("❤️ HeartBetManager: нельзя подтвердить (state=%s)" % State.keys()[current_state])
			return false


## Отменить шанс (внутренний метод)
func _decline() -> void:
	print("❤️ Отказ от шанса")
	current_state = State.IDLE
	selected_target = ""
	last_trigger_name = ""
	EventBus.heart_bet_declined.emit()
	EventBus.heart_bet_hide_ui.emit()


## Определить результат ставки
## Вызывается после определения победителя раздачи
func resolve(actual_winner: String) -> void:
	# #region agent log
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H1","location":"HeartBetManager.resolve:entry","message":"resolve called","data":{"current_state":"%s","selected_target":"%s","actual_winner":"%s"},"timestamp":%d}' % [State.keys()[current_state], selected_target, actual_winner, int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	if current_state != State.ACTIVE:
		print("❤️ HeartBetManager: нет активной ставки для разрешения")
		return

	current_state = State.RESOLVING

	print("❤️ Разрешение ставки: выбрано '%s', победитель '%s'" % [selected_target, actual_winner])

	# #region agent log
	var _log_file2 = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	var _is_tie_draw = (selected_target != "Tie" and actual_winner == "Tie")
	if _log_file2: _log_file2.seek_end(); _log_file2.store_line('{"hypothesisId":"H5","location":"HeartBetManager.resolve:check","message":"checking conditions","data":{"selected_target":"%s","actual_winner":"%s","is_tie_draw":%s,"is_match":%s},"timestamp":%d}' % [selected_target, actual_winner, str(_is_tie_draw).to_lower(), str(selected_target == actual_winner).to_lower(), int(Time.get_unix_time_from_system() * 1000)]); _log_file2.close()
	# #endregion

	if selected_target == actual_winner:
		# Угадал!
		_handle_win()
		# _reset() вызывается ВНУТРИ _handle_win() перед эмитом сигнала
	elif actual_winner == "Tie" and selected_target in ["Player", "Banker"]:
		# Ставка на Player/Banker, но выпало Tie - это НИЧЬЯ, не проигрыш!
		_handle_tie_draw()
		# НЕ сбрасываем - даём новый шанс (состояние AVAILABLE)
	else:
		# Не угадал
		_handle_loss()
		# _reset() вызывается ВНУТРИ _handle_loss() перед эмитом сигнала


## Обработка выигрыша
func _handle_win() -> void:
	var reward = REWARD_TIE if selected_target == "Tie" else REWARD_PLAYER_BANKER
	print("❤️🎉 ВЫИГРЫШ! +%d жизней (бонус), +1 (возврат залога)" % reward)
	
	# Показываем оверлей поздравления (4 секунды чтобы успеть прочитать)
	var message_key = "HEART_BET_WON_TIE" if selected_target == "Tie" else "HEART_BET_WON_" + selected_target.to_upper()
	EventBus.show_overlay_success.emit(Localization.t(message_key), 4.0)
	
	# Сначала возвращаем залог, потом добавляем награду
	# (SurvivalModeUI обработает через EventBus)
	EventBus.heart_bet_won.emit(selected_target, reward)
	
	# Скрываем выбранное сердце со стола
	EventBus.heart_bet_hide_selected.emit()
	
	# ВАЖНО: Сбрасываем состояние в IDLE ДО эмита heart_bet_round_complete
	# чтобы проверка триггеров в _on_heart_bet_round_complete могла сработать
	_reset()
	
	# Сигнализируем о завершении Heart Bet раздачи
	EventBus.heart_bet_round_complete.emit()


## Обработка проигрыша
func _handle_loss() -> void:
	print("❤️💔 ПРОИГРЫШ! Залог сгорает")
	
	# Показываем оверлей проигрыша (4 секунды чтобы успеть прочитать)
	EventBus.show_overlay_error.emit(Localization.t("HEART_BET_LOST"), 4.0)
	
	# SurvivalModeUI обработает через EventBus
	EventBus.heart_bet_lost.emit(selected_target, 0)
	
	# Скрываем выбранное сердце со стола
	EventBus.heart_bet_hide_selected.emit()
	
	# ВАЖНО: Сбрасываем состояние в IDLE ДО эмита heart_bet_round_complete
	# чтобы проверка триггеров в _on_heart_bet_round_complete могла сработать
	_reset()
	
	# Сигнализируем о завершении Heart Bet раздачи
	EventBus.heart_bet_round_complete.emit()


## Обработка ничьей (Tie при ставке на Player/Banker)
func _handle_tie_draw() -> void:
	# #region agent log
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H2","location":"HeartBetManager._handle_tie_draw","message":"tie draw handling started","data":{"selected_target":"%s","chance_count":%d},"timestamp":%d}' % [selected_target, chance_count, int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	print("❤️🔄 НИЧЬЯ (Tie)! Карта сгорела, залог возвращается, игра завершается")

	# Показываем оверлей (4 секунды чтобы успеть прочитать)
	EventBus.show_overlay_info.emit(Localization.t("HEART_BET_TIE_DRAW"), 4.0)
	
	# Возвращаем залог
	EventBus.heart_returned.emit()
	
	# Скрываем выбранное сердце со стола
	EventBus.heart_bet_hide_selected.emit()
	# Карта сгорела (уже была списана при использовании в use_chance())
	# НЕ обнуляем chance_count - остальные карты должны остаться
	print("❤️ Карта сгорела! Осталось шансов: %d" % chance_count)
	# НЕ эмитим chance_count_changed - счётчик не изменился (карта уже была списана)
	
	# Сбрасываем состояние в IDLE
	current_state = State.IDLE
	selected_target = ""
	
	# Сигнализируем о завершении Heart Bet раздачи (сброс без выплат)
	# ВАЖНО: НЕ показываем ставки гостей и НЕ активируем триггер снова
	# Игра просто завершается и переходит к новой раздаче
	EventBus.heart_bet_round_complete.emit()
	
	


## Сбросить состояние
func _reset() -> void:
	# #region agent log
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H8","location":"HeartBetManager._reset","message":"resetting state","data":{"old_state":"%s","chance_count":%d},"timestamp":%d}' % [State.keys()[current_state], chance_count, int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	current_state = State.IDLE
	selected_target = ""
	last_trigger_name = ""


## Принудительный сброс (например, при game over)
func force_reset() -> void:
	print("❤️ Принудительный сброс HeartBetManager")
	if current_state == State.PENDING or current_state == State.SELECTED:
		EventBus.heart_bet_hide_ui.emit()
	_reset()
	# Сбрасываем счётчик шансов при game over
	chance_count = 0
	EventBus.chance_count_changed.emit(0)


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ТРИГГЕРАМИ
# ═══════════════════════════════════════════════════════════════════════════

## Включить триггер по имени
func enable_trigger(trigger_name: String) -> bool:
	return trigger_system.enable_trigger(trigger_name)


## Отключить триггер по имени
func disable_trigger(trigger_name: String) -> bool:
	return trigger_system.disable_trigger(trigger_name)


## Проверить, включён ли триггер
func is_trigger_enabled(trigger_name: String) -> bool:
	return trigger_system.is_trigger_enabled(trigger_name)


## Получить список всех триггеров
func get_all_triggers() -> Array[HeartBetBaseTrigger]:
	return trigger_system.get_all_triggers()


# ═══════════════════════════════════════════════════════════════════════════
# ОТЛАДКА
# ═══════════════════════════════════════════════════════════════════════════

## Получить имя текущего состояния
func get_state_name() -> String:
	return State.keys()[current_state]


## Вывести статус в консоль
func print_status() -> void:
	print("═══ HeartBetManager Status ═══")
	print("  State: %s" % get_state_name())
	print("  Selected: %s" % (selected_target if not selected_target.is_empty() else "none"))
	print("  Last trigger: %s" % (last_trigger_name if not last_trigger_name.is_empty() else "none"))
	print("  Triggers enabled: %d" % trigger_system.get_enabled_triggers().size())
	print("═══════════════════════════════")
