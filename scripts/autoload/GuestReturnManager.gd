# res://scripts/autoload/GuestReturnManager.gd
# Autoload синглтон для управления возвратом ушедших гостей
# Отслеживает гостей, ушедших в минус, и возвращает их через 10 раундов

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal guest_returned(guest_id: int)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Словарь ушедших гостей: {guest_id: round_when_left}
# Гость вернется через 10 раундов после ухода
var guests_left: Dictionary = {}  # {guest_id: int (номер раунда)}

# Текущий номер раунда (отслеживается через round_started)
var current_round: int = 0

# Количество раундов до возврата
const ROUNDS_UNTIL_RETURN: int = 10

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Подписываемся на событие начала раунда
	EventBus.round_started.connect(_on_round_started)
	
	# Подписываемся на рестарт игры для сброса
	EventBus.game_restarted.connect(_on_game_restarted)
	
	print("🔄 GuestReturnManager готов")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Отметить гостя как ушедшего
func mark_guest_left(guest_id: int, round_number: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestReturnManager: неверный guest_id %d" % guest_id)
		return
	
	guests_left[guest_id] = round_number
	print("👋 Гость %d ушел в раунде %d (вернется в раунде %d)" % [guest_id, round_number, round_number + ROUNDS_UNTIL_RETURN])

## Вернуть гостя с начальным балансом
func return_guest(guest_id: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestReturnManager: неверный guest_id %d" % guest_id)
		return
	
	# Удаляем из списка ушедших
	guests_left.erase(guest_id)
	
	# Инициализируем начальный баланс
	if GuestStatsManager:
		GuestStatsManager.initialize_guest_balance(guest_id)
	
	# Включаем гостя обратно
	if GuestSettingsManager:
		GuestSettingsManager.set_guest_enabled(guest_id, true)
	
	# Эмитим сигнал
	guest_returned.emit(guest_id)
	print("👋 Гость %d вернулся с начальным балансом" % guest_id)

## Получить текущий номер раунда
func get_current_round() -> int:
	# Пытаемся получить из TableStateManager (если доступен)
	if TableStateManager:
		var table_rounds = TableStateManager.get_survival_rounds()
		if table_rounds > 0:
			return table_rounds
	
	# Fallback на собственный счетчик
	return current_round

## Проверить, ушел ли гость
func is_guest_left(guest_id: int) -> bool:
	return guests_left.has(guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_round_started() -> void:
	"""Обработчик начала нового раунда - проверяем возврат гостей"""
	# Синхронизируем счетчик с TableStateManager (если доступен)
	if TableStateManager:
		current_round = TableStateManager.get_survival_rounds()
	else:
		current_round += 1
	
	# Проверяем всех ушедших гостей
	var guests_to_return: Array[int] = []
	
	for guest_id in guests_left.keys():
		var round_when_left = guests_left[guest_id]
		var rounds_passed = current_round - round_when_left
		
		if rounds_passed >= ROUNDS_UNTIL_RETURN:
			guests_to_return.append(guest_id)
	
	# Возвращаем гостей, которые должны вернуться
	for guest_id in guests_to_return:
		return_guest(guest_id)

func _on_game_restarted() -> void:
	"""Обработчик рестарта игры - сбрасываем все"""
	guests_left.clear()
	current_round = 0
	print("🔄 GuestReturnManager: все данные сброшены при рестарте")

