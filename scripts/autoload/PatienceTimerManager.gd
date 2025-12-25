# res://scripts/autoload/PatienceTimerManager.gd
# Autoload синглтон для управления таймерами терпения гостей
# Каждый гость имеет таймер: всегда 5 минут, восстанавливает терпение на 10 очков (увеличивает)

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal timer_expired(guest_id: int)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Активные таймеры для каждого гостя (1-6)
# Ключ: guest_id (int), Значение: {"started_at": int (msec), "duration": int (msec)}
var active_timers: Dictionary = {}

const TIMER_DURATION_MSEC: int = 300000  # 300 секунд = 5 минут

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	print("⏱️  PatienceTimerManager готов")
	
	# Подписываемся на событие рестарта игры для сброса всех таймеров
	EventBus.game_restarted.connect(_on_game_restarted)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Запустить таймер для гостя
## Отменяет старый таймер (если есть) и создает новый на 5 минут
func start_timer(guest_id: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("PatienceTimerManager: неверный guest_id %d" % guest_id)
		return
	
	# Проверяем текущее терпение гостя (GuestStatsManager - autoload singleton)
	if not GuestStatsManager:
		push_error("PatienceTimerManager: GuestStatsManager не найден!")
		return
	
	var current_patience = GuestStatsManager.get_guest_patience(guest_id)
	if current_patience >= 100:
		# Полное терпение - таймер не нужен
		stop_timer(guest_id)
		return
	
	# Отменяем старый таймер (если есть)
	# Это важно: если произошла новая ошибка, старый таймер не должен отнять 5
	if active_timers.has(guest_id):
		print("⏱️  Гость %d: отменен предыдущий таймер (новая ошибка)" % guest_id)
	
	# Создаем новый таймер на 5 минут
	var started_at = Time.get_ticks_msec()
	active_timers[guest_id] = {
		"started_at": started_at,
		"duration": TIMER_DURATION_MSEC
	}
	print("⏱️  Гость %d: запущен таймер терпения (5 минут, терпение=%d)" % [guest_id, current_patience])

## Остановить таймер гостя
func stop_timer(guest_id: int) -> void:
	if active_timers.has(guest_id):
		active_timers.erase(guest_id)
		print("⏱️  Гость %d: таймер остановлен" % guest_id)

## Получить оставшееся время таймера в секундах (для UI)
func get_remaining_time(guest_id: int) -> int:
	if not active_timers.has(guest_id):
		return 0
	
	var timer_data = active_timers[guest_id]
	var started_at = timer_data["started_at"]
	var duration = timer_data["duration"]
	var current_time = Time.get_ticks_msec()
	var elapsed = current_time - started_at
	var remaining_msec = max(duration - elapsed, 0)
	
	return int(ceil(remaining_msec / 1000.0))  # Конвертируем в секунды

## Проверить, есть ли активный таймер у гостя
func has_active_timer(guest_id: int) -> bool:
	return active_timers.has(guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ТАЙМЕРОВ
# ═══════════════════════════════════════════════════════════════════════════

var _last_check_second: int = -1  # Для проверки каждую секунду

func _process(_delta: float):
	# Проверяем таймеры каждую секунду
	var current_second = int(Time.get_ticks_msec() / 1000.0)
	
	if current_second == _last_check_second:
		return  # Еще не прошла секунда
	
	_last_check_second = current_second
	
	# Проверяем все активные таймеры
	var expired_timers: Array[int] = []
	
	for guest_id in active_timers.keys():
		if _is_timer_expired(guest_id):
			expired_timers.append(guest_id)
	
	# Обрабатываем истекшие таймеры
	for guest_id in expired_timers:
		_on_timer_expired(guest_id)

func _is_timer_expired(guest_id: int) -> bool:
	if not active_timers.has(guest_id):
		return false
	
	var timer_data = active_timers[guest_id]
	var started_at = timer_data["started_at"]
	var duration = timer_data["duration"]
	var current_time = Time.get_ticks_msec()
	var elapsed = current_time - started_at
	
	return elapsed >= duration

func _on_timer_expired(guest_id: int) -> void:
	# Удаляем истекший таймер
	active_timers.erase(guest_id)
	
	# Восстанавливаем терпение на 10 (увеличиваем)
	GuestStatsManager.add_patience(guest_id, 10)
	
	print("⏱️  Гость %d: таймер истек, терпение восстановлено на 10" % guest_id)
	
	# Проверяем, нужно ли запустить следующий таймер
	var current_patience = GuestStatsManager.get_guest_patience(guest_id)
	if current_patience < 100:
		# Запускаем следующий таймер (последовательная работа)
		start_timer(guest_id)
	else:
		print("⏱️  Гость %d: терпение = 100%, таймеры остановлены" % guest_id)
	
	# Эмитим сигнал для UI (если нужно)
	timer_expired.emit(guest_id)

## Сбросить все таймеры (при перезапуске игры)
func reset_all_timers() -> void:
	active_timers.clear()
	print("⏱️  Все таймеры терпения сброшены")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_game_restarted() -> void:
	"""Обработчик рестарта игры - сбрасываем все таймеры"""
	reset_all_timers()
