# res://scripts/autoload/GameStateManager.gd
# Глобальный менеджер состояний игры
# Определяет текущее состояние игры на основе карт на столе
extends Node

# ========================================
# СИГНАЛЫ
# ========================================

signal state_changed(old_state: GameState, new_state: GameState)

# ========================================
# ENUM: Состояния игры
# ========================================

enum GameState {
	WAITING = 1,                    # Карты скрыты, ждём кнопку "Карты"
	CARD_TO_EACH = 2,               # Банкир 0-2, Игрок 0-5 → карта каждому
	CARD_TO_PLAYER = 3,             # Банкир 3-7, Игрок 0-5 → карта игроку
	CARD_TO_BANKER = 4,             # Банкир 0-5, Игрок 6-7 → карта банкиру
	CARD_TO_BANKER_AFTER_PLAYER = 5,# Банкир 3-6 после третьей игрока
	CHOOSE_WINNER = 6               # Все карты открыты, выбор победителя
}

# ========================================
# ENUM: Действия игрока
# ========================================

enum Action {
	DEAL_CARDS,        # Нажата кнопка "Карты"
	PLAYER_THIRD,      # Заказ третьей карты игроку
	BANKER_THIRD,      # Заказ третьей карты банкиру
	SELECT_WINNER      # Выбор победителя (Player/Banker/Tie)
}

# ========================================
# ПЕРЕМЕННЫЕ
# ========================================

var current_state: GameState = GameState.WAITING

# ← Кэширование для determine_state()
var _cache_state: GameState = GameState.WAITING  # Кэшированное состояние
var _cache_hash: int = -1  # Хэш параметров (для проверки валидности кэша)

# ========================================
# ФУНКЦИИ: Получение информации о состоянии
# ========================================

# Получить название состояния на русском
func get_state_name(state: GameState) -> String:
	match state:
		GameState.WAITING:
			return "Ожидание"
		GameState.CARD_TO_EACH:
			return "Карта каждому"
		GameState.CARD_TO_PLAYER:
			return "Карта игроку"
		GameState.CARD_TO_BANKER:
			return "Карта банкиру"
		GameState.CARD_TO_BANKER_AFTER_PLAYER:
			return "Карта банкиру после игрока"
		GameState.CHOOSE_WINNER:
			return "Выбор победителя"
		_:
			return "Неизвестное состояние"

# Получить название действия на русском
func get_action_name(action: Action) -> String:
	match action:
		Action.DEAL_CARDS:
			return "Раздать карты"
		Action.PLAYER_THIRD:
			return "Карта игроку"
		Action.BANKER_THIRD:
			return "Карта банкиру"
		Action.SELECT_WINNER:
			return "Выбрать победителя"
		_:
			return "Неизвестное действие"

# ========================================
# ФУНКЦИИ: Основная логика
# ========================================

# Генерировать хэш из параметров для кэширования
func _hash_params(
	cards_hidden: bool,
	player_hand: Array[Card],
	banker_hand: Array[Card],
	player_third: Card,
	banker_third: Card
) -> int:
	var h: int = 0

	# ← Хэш из булевого флага
	h = h * 2 + (1 if cards_hidden else 0)

	# ← Хэш из размеров рук
	h = h * 10 + player_hand.size()
	h = h * 10 + banker_hand.size()

	# ← Хэш из карт игрока (первые 2)
	for i in range(min(2, player_hand.size())):
		var card = player_hand[i]
		h = h * 13 + _card_hash(card)

	# ← Хэш из карт банкира (первые 2)
	for i in range(min(2, banker_hand.size())):
		var card = banker_hand[i]
		h = h * 13 + _card_hash(card)

	# ← Хэш из третьих карт
	h = h * 13 + (_card_hash(player_third) if player_third != null else 0)
	h = h * 13 + (_card_hash(banker_third) if banker_third != null else 0)

	return h

# Генерировать хэш из карты
func _card_hash(card) -> int:
	if card == null:
		return 0

	# Проверяем валидность объекта
	if not is_instance_valid(card):
		return 0

	# Проверяем наличие свойств rank и suit
	if not ("rank" in card and "suit" in card):
		return 0

	# Простой хэш: ранг (0-12) * 4 + масть (0-3)
	var rank_map = {"A": 0, "2": 1, "3": 2, "4": 3, "5": 4, "6": 5, "7": 6, "8": 7, "9": 8, "10": 9, "J": 10, "Q": 11, "K": 12}
	var suit_map = {"clubs": 0, "hearts": 1, "spades": 2, "diamonds": 3}

	var rank_idx = rank_map.get(card.rank, 0)
	var suit_idx = suit_map.get(card.suit, 0)

	return rank_idx * 4 + suit_idx

# Определить состояние игры на основе карт на столе
# Параметры:
#   cards_hidden: bool - карты скрыты?
#   player_hand: Array[Card] - рука игрока (2 карты)
#   banker_hand: Array[Card] - рука банкира (2 карты)
#   player_third: Card или null - третья карта игрока
#   banker_third: Card или null - третья карта банкира
func determine_state(
	cards_hidden: bool,
	player_hand: Array[Card],
	banker_hand: Array[Card],
	player_third: Card = null,
	banker_third: Card = null
) -> GameState:

	# ← Кэширование: вычисляем хэш параметров
	var params_hash = _hash_params(cards_hidden, player_hand, banker_hand, player_third, banker_third)

	# ← Если хэш совпадает - возвращаем кэш
	if params_hash == _cache_hash:
		return _cache_state

	# ← Вспомогательная функция для сохранения в кэш и возврата
	var _save_and_return = func(state: GameState) -> GameState:
		_cache_hash = params_hash
		_cache_state = state
		return state

	# ========================================
	# State 1: Карты скрыты
	# ========================================
	if cards_hidden or player_hand.size() < 2 or banker_hand.size() < 2:
		return _save_and_return.call(GameState.WAITING)

	# Вычисляем значения рук (первые 2 карты)
	var player_value = BaccaratRules.hand_value(player_hand.slice(0, 2))
	var banker_value = BaccaratRules.hand_value(banker_hand.slice(0, 2))

	# ========================================
	# State 6: Натуральные 8-9
	# ========================================
	if player_value >= 8 or banker_value >= 8:
		return _save_and_return.call(GameState.CHOOSE_WINNER)

	# ========================================
	# State 6: Особые комбинации (6v7, 7v6, 7v7, 6v6)
	# ========================================
	if _is_special_combination(player_value, banker_value):
		return _save_and_return.call(GameState.CHOOSE_WINNER)

	# ========================================
	# Если игрок НЕ взял третью карту
	# ========================================
	if player_third == null:
		# ← ВАЖНО: Если банкир УЖЕ взял третью → выбор победителя
		if banker_third != null:
			return _save_and_return.call(GameState.CHOOSE_WINNER)

		# Игрок должен брать карту (0-5)
		if player_value in [0, 1, 2, 3, 4, 5]:
			# Банкир 0-2 → обоим нужна третья карта
			if banker_value in [0, 1, 2]:
				return _save_and_return.call(GameState.CARD_TO_EACH)
			# Банкир 3-7 → только игроку нужна третья карта
			else:  # banker_value in [3, 4, 5, 6, 7]
				return _save_and_return.call(GameState.CARD_TO_PLAYER)

		# Игрок стоит (6-7)
		else:  # player_value in [6, 7]
			# Банкир 0-5 → только банкиру нужна третья карта
			if banker_value in [0, 1, 2, 3, 4, 5]:
				return _save_and_return.call(GameState.CARD_TO_BANKER)
			# Банкир 6-7 → оба стоят, выбор победителя
			else:  # banker_value in [6, 7]
				return _save_and_return.call(GameState.CHOOSE_WINNER)

	# ========================================
	# Если игрок УЖЕ взял третью карту
	# ========================================
	else:
		# Банкир уже взял третью → выбор победителя
		if banker_third != null:
			return _save_and_return.call(GameState.CHOOSE_WINNER)

		# Банкир с 7 всегда стоит
		if banker_value == 7:
			return _save_and_return.call(GameState.CHOOSE_WINNER)

		# Банкир 0-2 всегда берёт (но это уже обработано в CARD_TO_EACH)
		# Банкир 3-6 → проверяем по сложным правилам
		if banker_value in [3, 4, 5, 6]:
			# Используем правила из BaccaratRules
			var player_drew = true
			if BaccaratRules.banker_should_draw(banker_hand.slice(0, 2), player_drew, player_third):
				return _save_and_return.call(GameState.CARD_TO_BANKER_AFTER_PLAYER)
			else:
				return _save_and_return.call(GameState.CHOOSE_WINNER)

	# ========================================
	# Fallback: все карты открыты
	# ========================================
	return _save_and_return.call(GameState.CHOOSE_WINNER)

# Проверка особых комбинаций (6v7, 7v6, 7v7, 6v6)
func _is_special_combination(player_value: int, banker_value: int) -> bool:
	# Обе руки должны быть 6 или 7
	if player_value not in [6, 7] or banker_value not in [6, 7]:
		return false

	# 6v7, 7v6, 7v7, 6v6
	return true

# Обновить текущее состояние игры
func update_state(new_state: GameState):
	if new_state != current_state:
		var old = current_state
		current_state = new_state
		state_changed.emit(old, new_state)
		print("🎮 Состояние изменилось: %s → %s" % [get_state_name(old), get_state_name(new_state)])

# Получить текущее состояние
func get_current_state() -> GameState:
	return current_state

# Сбросить состояние в начальное
func reset():
	update_state(GameState.WAITING)

	# ← Инвалидируем кэш при сбросе
	_cache_hash = -1
	_cache_state = GameState.WAITING

	print("🔄 Состояние сброшено в WAITING")

# Определить и обновить состояние на основе карт
# Удобный метод для вызова из GameController
func determine_and_update_state(
	cards_hidden: bool,
	player_hand: Array[Card],
	banker_hand: Array[Card],
	player_third: Card = null,
	banker_third: Card = null
) -> void:
	var new_state = determine_state(cards_hidden, player_hand, banker_hand, player_third, banker_third)
	update_state(new_state)

# ========================================
# ФУНКЦИИ: Валидация действий
# ========================================

# Проверить допустимость действия в текущем состоянии
func is_action_valid(action: Action, state: GameState = current_state) -> bool:
	match state:
		GameState.WAITING:
			# В ожидании можно только раздать карты
			return action == Action.DEAL_CARDS

		GameState.CARD_TO_EACH:
			# Нужна карта каждому (но проверяем отдельно player и banker)
			# Это специальный случай - оба должны быть заказаны
			return action in [Action.PLAYER_THIRD, Action.BANKER_THIRD]

		GameState.CARD_TO_PLAYER:
			# Только карта игроку
			return action == Action.PLAYER_THIRD

		GameState.CARD_TO_BANKER, GameState.CARD_TO_BANKER_AFTER_PLAYER:
			# Только карта банкиру
			return action == Action.BANKER_THIRD

		GameState.CHOOSE_WINNER:
			# Можно выбрать победителя или нажать "Карты" (не ошибка, просто ничего не делает)
			return action in [Action.SELECT_WINNER, Action.DEAL_CARDS]

		_:
			return false

# Получить список допустимых действий для состояния
func get_valid_actions(state: GameState = current_state) -> Array:
	var actions: Array = []

	match state:
		GameState.WAITING:
			actions = [Action.DEAL_CARDS]
		GameState.CARD_TO_EACH:
			actions = [Action.PLAYER_THIRD, Action.BANKER_THIRD]  # Оба!
		GameState.CARD_TO_PLAYER:
			actions = [Action.PLAYER_THIRD]
		GameState.CARD_TO_BANKER, GameState.CARD_TO_BANKER_AFTER_PLAYER:
			actions = [Action.BANKER_THIRD]
		GameState.CHOOSE_WINNER:
			actions = [Action.SELECT_WINNER]

	return actions

# Получить сообщение об ошибке для недопустимого действия
func get_error_message(action: Action, state: GameState = current_state) -> String:
	# Если действие допустимо, нет ошибки
	if is_action_valid(action, state):
		return ""

	# Генерируем сообщение об ошибке
	match state:
		GameState.WAITING:
			match action:
				Action.PLAYER_THIRD, Action.BANKER_THIRD:
					return "Сначала нажмите кнопку \"Карты\""
				Action.SELECT_WINNER:
					return "Игра ещё не началась"
				_:
					return "Недопустимое действие"

		GameState.CARD_TO_EACH:
			match action:
				Action.SELECT_WINNER:
					return "Сначала закажите карты каждому (игроку И банкиру)"
				Action.DEAL_CARDS:
					return "Закажите третьи карты игроку И банкиру"
				_:
					return "Недопустимое действие"

		GameState.CARD_TO_PLAYER:
			match action:
				Action.BANKER_THIRD:
					return "Банкиру карта не нужна! Только игроку"
				Action.SELECT_WINNER:
					return "Сначала откройте карты"
				Action.DEAL_CARDS:
					return "Закажите третью карту игроку"
				_:
					return "Недопустимое действие"

		GameState.CARD_TO_BANKER, GameState.CARD_TO_BANKER_AFTER_PLAYER:
			match action:
				Action.PLAYER_THIRD:
					return "Игроку карта не нужна! Только банкиру"
				Action.SELECT_WINNER:
					return "Сначала откройте карты"
				Action.DEAL_CARDS:
					return "Закажите третью карту банкиру"
				_:
					return "Недопустимое действие"

		GameState.CHOOSE_WINNER:
			match action:
				Action.PLAYER_THIRD, Action.BANKER_THIRD:
					return "Все карты уже открыты. Выберите победителя"
				_:
					return "Выберите победителя"

		_:
			return "Неизвестная ошибка"

# Проверка специального случая State 2: обе карты должны быть заказаны
func is_both_third_cards_selected(player_selected: bool, banker_selected: bool, state: GameState = current_state) -> bool:
	if state != GameState.CARD_TO_EACH:
		return true  # Не применимо для других состояний

	return player_selected and banker_selected

# ========================================
# ФУНКЦИИ: Блокировка настроек
# ========================================

# Можно ли менять настройки (режим игры, лимиты)?
# Настройки можно менять только в состояниях WAITING и CHOOSE_WINNER
func can_change_settings(state: GameState = current_state) -> bool:
	return state in [GameState.WAITING, GameState.CHOOSE_WINNER]

# Сообщение почему нельзя менять настройки
func get_settings_lock_message(state: GameState = current_state) -> String:
	if can_change_settings(state):
		return ""  # Нет блокировки

	return "Нельзя менять настройки во время раздачи! Завершите раунд."
