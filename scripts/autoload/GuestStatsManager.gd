# res://scripts/autoload/GuestStatsManager.gd
# Autoload синглтон для управления статистикой гостей
# Хранит баланс каждого гостя (может быть отрицательным)

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

signal guest_balance_changed(guest_id: int, new_balance: float)
signal guest_patience_changed(guest_id: int, new_patience: int)
signal guest_left(guest_id: int)

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

# Диапазоны начальных балансов по статусу богатства (рандомные значения)
const POOR_BALANCE_MIN: float = 30000.0
const POOR_BALANCE_MAX: float = 60000.0
const MEDIUM_BALANCE_MIN: float = 100000.0
const MEDIUM_BALANCE_MAX: float = 130000.0
const RICH_BALANCE_MIN: float = 200000.0
const RICH_BALANCE_MAX: float = 270000.0
const MIN_BALANCE_TO_CONTINUE: float = 100.0

# Пороги для изменения статуса богатства (динамическое обновление)
const WEALTH_THRESHOLD_POOR_TO_MEDIUM: float = 100000.0   # Бедный → Средний
const WEALTH_THRESHOLD_MEDIUM_TO_RICH: float = 200000.0  # Средний → Богатый
const WEALTH_THRESHOLD_RICH_TO_MEDIUM: float = 200000.0  # Богатый → Средний
const WEALTH_THRESHOLD_MEDIUM_TO_POOR: float = 100000.0   # Средний → Бедный
const WEALTH_THRESHOLD_RICH_TO_POOR: float = 100000.0     # Богатый → Бедный (прямой переход)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Баланс 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Баланс может быть отрицательным (проигрыш) или положительным (выигрыш)
var guest_balances: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# Начальные балансы 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Используется для расчета изменения баланса
var guest_initial_balances: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# Терпение 6 гостей (индекс 0-5 соответствует гостю 1-6)
# Терпение 0-100 (100 = полное терпение/спокоен, 0 = нет терпения/раздражен)
# НЕ сохраняется между сеансами (сбрасывается при перезапуске)
var guest_patience: Array[int] = [100, 100, 100, 100, 100, 100]

# Балансы гостей на момент генерации ставок (для анализа результата раунда)
# Индекс 0-5 соответствует гостю 1-6
# Значение 0.0 означает, что баланс еще не был сохранен (первый раунд)
var guest_balances_at_bet_generation: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	# Загружаем сохранённые балансы
	_load_stats()
	
	# Инициализируем балансы всех включенных гостей
	_initialize_all_enabled_guests()
	
	print("💰 GuestStatsManager загружен: балансы %d гостей" % guest_balances.size())
	
	# Подписываемся на событие рестарта игры для сброса терпения
	EventBus.game_restarted.connect(_on_game_restarted)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ← Получить баланс гостя (guest_id: 1-6)
func get_guest_balance(guest_id: int) -> float:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0.0
	return guest_balances[guest_id - 1]

# ← Установить баланс гостя
func set_guest_balance(guest_id: int, balance: float) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	guest_balances[guest_id - 1] = balance
	_save_stats()
	guest_balance_changed.emit(guest_id, balance)
	print("💰 Гость %d: баланс = %.2f" % [guest_id, balance])

# ← Добавить к балансу гостя (выигрыш)
func add_to_balance(guest_id: int, amount: float) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var new_balance = guest_balances[guest_id - 1] + amount
	set_guest_balance(guest_id, new_balance)

# ← Вычесть из баланса гостя (проигрыш)
func subtract_from_balance(guest_id: int, amount: float) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var new_balance = guest_balances[guest_id - 1] - amount
	set_guest_balance(guest_id, new_balance)

# ← Сбросить баланс гостя
func reset_guest_balance(guest_id: int) -> void:
	set_guest_balance(guest_id, 0.0)

# ← Сбросить балансы всех гостей до начальных значений (в зависимости от статуса богатства)
func reset_all_balances() -> void:
	"""Сбрасывает балансы всех гостей до начальных значений в зависимости от их статуса богатства"""
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	# Сбрасываем балансы всех гостей (1-6) до начальных значений
	for guest_id in range(1, 7):
		var wealth = GuestSettingsManager.get_guest_wealth(guest_id)
		var initial_balance = generate_random_balance(wealth)
		
		# Устанавливаем начальный баланс
		guest_initial_balances[guest_id - 1] = initial_balance
		set_guest_balance(guest_id, initial_balance)
		
		# Сбрасываем сохраненный баланс
		reset_saved_balance(guest_id)
	
	_save_stats()
	print("💰 Все балансы гостей сброшены до начальных значений (в зависимости от статуса богатства)")

# ← Получить форматированную строку баланса (для UI)
func get_balance_string(guest_id: int) -> String:
	var balance = get_guest_balance(guest_id)
	if balance >= 0:
		return "+%.0f" % balance
	else:
		return "%.0f" % balance

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ РАБОТЫ С НАЧАЛЬНЫМИ БАЛАНСАМИ
# ═══════════════════════════════════════════════════════════════════════════

# ← Генерировать рандомный баланс по статусу богатства
func generate_random_balance(wealth: GuestSettingsManager.GuestWealth) -> float:
	"""Генерирует рандомный баланс в диапазоне для указанного статуса богатства (кратно 500)"""
	const STEP: int = 500
	
	match wealth:
		GuestSettingsManager.GuestWealth.POOR:
			var min_steps = int(POOR_BALANCE_MIN / STEP)
			var max_steps = int(POOR_BALANCE_MAX / STEP)
			return randi_range(min_steps, max_steps) * STEP
		GuestSettingsManager.GuestWealth.MEDIUM:
			var min_steps = int(MEDIUM_BALANCE_MIN / STEP)
			var max_steps = int(MEDIUM_BALANCE_MAX / STEP)
			return randi_range(min_steps, max_steps) * STEP
		GuestSettingsManager.GuestWealth.RICH:
			var min_steps = int(RICH_BALANCE_MIN / STEP)
			var max_steps = int(RICH_BALANCE_MAX / STEP)
			return randi_range(min_steps, max_steps) * STEP
		_:
			var min_steps = int(MEDIUM_BALANCE_MIN / STEP)
			var max_steps = int(MEDIUM_BALANCE_MAX / STEP)
			return randi_range(min_steps, max_steps) * STEP

# ← Инициализировать баланс гостя по статусу богатства
func initialize_guest_balance(guest_id: int) -> void:
	"""Инициализирует баланс гостя на основе его текущего статуса богатства
	
	ВАЖНО: Эта функция ПРИНУДИТЕЛЬНО устанавливает баланс согласно статусу.
	Используется при активации нового гостя или при изменении статуса богатства.
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	# Получаем статус богатства гостя
	var wealth = GuestSettingsManager.get_guest_wealth(guest_id)
	var initial_balance = generate_random_balance(wealth)
	
	# Устанавливаем начальный баланс ПРИНУДИТЕЛЬНО (перезаписываем текущий баланс)
	guest_initial_balances[guest_id - 1] = initial_balance
	set_guest_balance(guest_id, initial_balance)
	
	# Сбрасываем сохраненный баланс при инициализации
	reset_saved_balance(guest_id)
	
	print("💰 Гость %d: начальный баланс установлен = %.0f (статус: %s)" % [guest_id, initial_balance, GuestSettingsManager.GuestWealth.keys()[wealth]])

# ← Получить начальный баланс гостя
func get_initial_balance(guest_id: int) -> float:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0.0
	return guest_initial_balances[guest_id - 1]

# ← Получить изменение баланса (текущий - начальный)
func get_balance_change(guest_id: int) -> float:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0.0
	
	var current_balance = get_guest_balance(guest_id)
	var initial_balance = get_initial_balance(guest_id)
	return current_balance - initial_balance

# ← Сохранить баланс гостя перед генерацией ставок
func save_balance_before_bet_generation(guest_id: int) -> void:
	"""Сохранить текущий баланс гостя перед генерацией ставок"""
	if guest_id < 1 or guest_id > 6:
		return
	var current_balance = get_guest_balance(guest_id)
	guest_balances_at_bet_generation[guest_id - 1] = current_balance
	print("💰 Гость %d: баланс сохранен для анализа = %.0f" % [guest_id, current_balance])

# ← Сбросить сохраненный баланс гостя
func reset_saved_balance(guest_id: int) -> void:
	"""Сбросить сохраненный баланс гостя (при возврате за стол)"""
	if guest_id < 1 or guest_id > 6:
		return
	guest_balances_at_bet_generation[guest_id - 1] = 0.0

# ← Проверить балансы всех гостей в конце раунда
func check_guests_balance_at_round_end() -> void:
	"""Проверяет всех включенных гостей и выключает тех, у кого баланс слишком низкий"""
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	if not GuestReturnManager:
		push_error("GuestStatsManager: GuestReturnManager не найден!")
		return
	
	# Получаем текущий номер раунда
	var current_round = GuestReturnManager.get_current_round()
	
	# Проверяем всех включенных гостей
	for guest_id in range(1, 7):
		if not GuestSettingsManager.is_guest_enabled(guest_id):
			continue  # Пропускаем выключенных гостей
		
		var balance = get_guest_balance(guest_id)
		
		# Если баланс меньше или равен порогу - выключаем гостя и отмечаем уход
		if balance <= MIN_BALANCE_TO_CONTINUE:
			# Определяем, последний ли это активный гость за столом
			# ВАЖНО: проверка ДО выключения гостя, чтобы увидеть реальное количество активных
			var is_single_in_list = false
			if GuestSettingsManager:
				var active_guests = GuestSettingsManager.get_active_guests()
				# Проверяем, что активных гостей сейчас 1 (этот гость еще активен, но мы его выключаем)
				is_single_in_list = active_guests.size() == 1
			
			# Выключаем гостя
			GuestSettingsManager.set_guest_enabled(guest_id, false)
			
			# Отмечаем в GuestReturnManager (причина ухода: банкротство)
			GuestReturnManager.mark_guest_left(guest_id, current_round, GuestReturnManager.LeaveReason.BANKRUPTCY, is_single_in_list)
			
			# Эмитим сигнал с причиной ухода
			guest_left.emit(guest_id)
			EventBus.guest_left_due_to_bankruptcy.emit(guest_id)
			
			print("👋 Гость %d ушел из-за низкого баланса (баланс: %.0f, порог: %.0f)" % [guest_id, balance, MIN_BALANCE_TO_CONTINUE])

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА И ОБНОВЛЕНИЕ СТАТУСА БОГАТСТВА
# ═══════════════════════════════════════════════════════════════════════════

func check_and_update_guest_wealth(guest_id: int) -> void:
	"""Проверяет баланс гостя и обновляет статус богатства при необходимости
	
	Логика переходов:
	- Бедный: 0 - 99,500
	- Средний: 100,000 - 199,500
	- Богатый: 200,000+
	- Бедный → Средний: если баланс >= 100,000
	- Средний → Богатый: если баланс >= 200,000
	- Богатый → Средний: если баланс < 200,000
	- Средний → Бедный: если баланс < 100,000
	- Богатый → Бедный: если баланс < 100,000 (прямой переход)
	
	ВАЖНО: Текущий баланс НЕ меняется, меняется только статус (влияет на размер будущих ставок)
	"""
	if guest_id < 1 or guest_id > 6:
		return
	
	if not GuestSettingsManager:
		return
	
	var current_balance = get_guest_balance(guest_id)
	var current_wealth = GuestSettingsManager.get_guest_wealth(guest_id)
	var new_wealth: GuestSettingsManager.GuestWealth = current_wealth
	
	# Логика перехода между статусами
	match current_wealth:
		GuestSettingsManager.GuestWealth.POOR:
			# Бедный → Средний
			if current_balance >= WEALTH_THRESHOLD_POOR_TO_MEDIUM:
				new_wealth = GuestSettingsManager.GuestWealth.MEDIUM
		
		GuestSettingsManager.GuestWealth.MEDIUM:
			# Средний → Богатый
			if current_balance >= WEALTH_THRESHOLD_MEDIUM_TO_RICH:
				new_wealth = GuestSettingsManager.GuestWealth.RICH
			# Средний → Бедный
			elif current_balance < WEALTH_THRESHOLD_MEDIUM_TO_POOR:
				new_wealth = GuestSettingsManager.GuestWealth.POOR
		
		GuestSettingsManager.GuestWealth.RICH:
			# Богатый → Бедный (прямой переход при большой проигрышной ставке)
			if current_balance < WEALTH_THRESHOLD_RICH_TO_POOR:
				new_wealth = GuestSettingsManager.GuestWealth.POOR
			# Богатый → Средний
			elif current_balance < WEALTH_THRESHOLD_RICH_TO_MEDIUM:
				new_wealth = GuestSettingsManager.GuestWealth.MEDIUM
	
	# Обновляем статус, если он изменился
	if new_wealth != current_wealth:
		var old_wealth_name = GuestSettingsManager.GuestWealth.keys()[current_wealth]
		var new_wealth_name = GuestSettingsManager.GuestWealth.keys()[new_wealth]
		
		# ВАЖНО: Изменяем статус с preserve_balance = true, чтобы не сбросить баланс
		GuestSettingsManager.set_guest_wealth(guest_id, new_wealth, true)
		
		print("💼 Гость %d: статус изменился %s → %s (баланс: %.0f)" % [
			guest_id, old_wealth_name, new_wealth_name, current_balance
		])

func check_all_guests_wealth_at_round_end() -> void:
	"""Проверяет всех активных гостей и обновляет их статус богатства и характер при необходимости
	
	Вызывается в конце раунда после всех выплат (в _complete_round_and_prepare_new_game)
	ВАЖНО: Вызывается ПЕРЕД генерацией новых ставок, чтобы характер учитывался при генерации
	"""
	if not GuestSettingsManager:
		return
	
	for guest_id in range(1, 7):
		if GuestSettingsManager.is_guest_enabled(guest_id):
			# 1. Сначала проверяем и обновляем статус богатства
			check_and_update_guest_wealth(guest_id)
			# 2. Затем проверяем и обновляем характер (после обновления статуса)
			check_and_update_guest_character(guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА И ОБНОВЛЕНИЕ ХАРАКТЕРА ГОСТЯ
# ═══════════════════════════════════════════════════════════════════════════

func check_and_update_guest_character(guest_id: int) -> void:
	"""Проверяет результат раунда и обновляет характер гостя
	
	Логика переключения (универсальная для всех статусов):
	- Умеренный: в плюсе → Азартный, в минусе → Осторожный
	- Азартный: в плюсе → Азартный, в минусе → Умеренный
	- Осторожный: в плюсе → Умеренный, в минусе → Осторожный
	
	Если сохраненный баланс = 0, значит первый раунд - не меняем характер
	"""
	if guest_id < 1 or guest_id > 6:
		return
	
	if not GuestSettingsManager:
		return
	
	var saved_balance = guest_balances_at_bet_generation[guest_id - 1]
	var current_balance = get_guest_balance(guest_id)
	
	# Если сохраненный баланс = 0, значит первый раунд - сохраняем баланс и не меняем характер
	if saved_balance == 0.0:
		guest_balances_at_bet_generation[guest_id - 1] = current_balance
		print("💰 Гость %d: первый раунд, баланс сохранен = %.0f (характер не меняется)" % [guest_id, current_balance])
		return
	
	# Анализируем результат раунда
	var delta = current_balance - saved_balance
	var current_character = GuestSettingsManager.get_guest_character(guest_id)
	var new_character = current_character
	
	if delta > 0:
		# В плюсе - характер становится более азартным
		match current_character:
			GuestSettingsManager.GuestCharacter.MODERATE:
				new_character = GuestSettingsManager.GuestCharacter.GAMBLER
			GuestSettingsManager.GuestCharacter.CAUTIOUS:
				new_character = GuestSettingsManager.GuestCharacter.MODERATE
			GuestSettingsManager.GuestCharacter.GAMBLER:
				new_character = GuestSettingsManager.GuestCharacter.GAMBLER  # Остается
	elif delta < 0:
		# В минусе - характер становится менее азартным
		match current_character:
			GuestSettingsManager.GuestCharacter.MODERATE:
				new_character = GuestSettingsManager.GuestCharacter.CAUTIOUS
			GuestSettingsManager.GuestCharacter.GAMBLER:
				new_character = GuestSettingsManager.GuestCharacter.MODERATE
			GuestSettingsManager.GuestCharacter.CAUTIOUS:
				new_character = GuestSettingsManager.GuestCharacter.CAUTIOUS  # Остается
	# Если delta == 0, характер не меняется
	
	# Обновляем характер, если изменился
	if new_character != current_character:
		var old_character_name = GuestSettingsManager.GuestCharacter.keys()[current_character]
		var new_character_name = GuestSettingsManager.GuestCharacter.keys()[new_character]
		
		GuestSettingsManager.set_guest_character(guest_id, new_character)
		
		print("🎭 Гость %d: характер изменился %s → %s (баланс: %.0f → %.0f, delta: %+.0f)" % [
			guest_id, old_character_name, new_character_name, saved_balance, current_balance, delta
		])
	
	# Сохраняем текущий баланс для следующего раунда
	guest_balances_at_bet_generation[guest_id - 1] = current_balance

# ← Обработать уход гостя из-за терпения (терпение достигло 0)
func _handle_guest_left_due_to_patience(guest_id: int) -> void:
	"""Обработать уход гостя из-за терпения (терпение достигло 0)
	
	Выключает гостя, отмечает в GuestReturnManager и эмитит события.
	Аналогично уходу при банкротстве, но с дополнительным событием для отнятия сердца.
	"""
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	if not GuestSettingsManager.is_guest_enabled(guest_id):
		return  # Гость уже выключен
	
	if not GuestReturnManager:
		push_error("GuestStatsManager: GuestReturnManager не найден!")
		return
	
	# Получаем текущий номер раунда
	var current_round = GuestReturnManager.get_current_round()
	
	# Определяем, последний ли это активный гость за столом
	# ВАЖНО: проверка ДО выключения гостя, чтобы увидеть реальное количество активных
	var is_single_in_list = false
	if GuestSettingsManager:
		var active_guests = GuestSettingsManager.get_active_guests()
		# Проверяем, что активных гостей сейчас 1 (этот гость еще активен, но мы его выключаем)
		is_single_in_list = active_guests.size() == 1
	
	# Выключаем гостя
	GuestSettingsManager.set_guest_enabled(guest_id, false)
	
	# Отмечаем в GuestReturnManager (причина ухода: потеря терпения)
	GuestReturnManager.mark_guest_left(guest_id, current_round, GuestReturnManager.LeaveReason.PATIENCE, is_single_in_list)
	
	# Эмитим стандартный сигнал ухода (для совместимости)
	guest_left.emit(guest_id)
	
	# Эмитим специальное событие для отнятия сердца
	if EventBus:
		EventBus.guest_left_due_to_patience.emit(guest_id)
	
	print("👋 Гость %d ушел из-за терпения (терпение = 0%%)" % guest_id)

# ← Инициализировать балансы всех включенных гостей
func _initialize_all_enabled_guests() -> void:
	"""Инициализирует балансы всех включенных гостей при загрузке"""
	if not GuestSettingsManager:
		push_error("GuestStatsManager: GuestSettingsManager не найден!")
		return
	
	for guest_id in range(1, 7):
		if GuestSettingsManager.is_guest_enabled(guest_id):
			# Проверяем, был ли баланс уже инициализирован
			# Если начальный баланс = 0, значит еще не инициализирован
			if get_initial_balance(guest_id) == 0.0:
				initialize_guest_balance(guest_id)

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ РАБОТЫ С ТЕРПЕНИЕМ
# ═══════════════════════════════════════════════════════════════════════════

# ← Получить терпение гостя (guest_id: 1-6)
func get_guest_patience(guest_id: int) -> int:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d (должен быть 1-6)" % guest_id)
		return 0
	return guest_patience[guest_id - 1]

# ← Увеличить терпение гостя (+10 при восстановлении через таймер)
func add_patience(guest_id: int, amount: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var current_patience = guest_patience[guest_id - 1]
	var new_patience = min(current_patience + amount, 100)  # Максимум 100
	
	if new_patience != current_patience:
		guest_patience[guest_id - 1] = new_patience
		guest_patience_changed.emit(guest_id, new_patience)
		print("😌 Гость %d: терпение %d -> %d (+%d)" % [guest_id, current_patience, new_patience, amount])

# ← Уменьшить терпение гостя (-10 при ошибке или истечении таймера)
func decrease_patience(guest_id: int, amount: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var current_patience = guest_patience[guest_id - 1]
	var new_patience = max(current_patience - amount, 0)  # Минимум 0
	
	# Обновляем терпение всегда, даже если оно уже 0 (чтобы сработала проверка на уход)
	guest_patience[guest_id - 1] = new_patience
	
	if new_patience != current_patience:
		guest_patience_changed.emit(guest_id, new_patience)
		print("😤 Гость %d: терпение %d -> %d (-%d)" % [guest_id, current_patience, new_patience, amount])
	else:
		# Терпение уже было 0, но нужно проверить уход (для возвращенных гостей)
		if current_patience == 0 and new_patience == 0:
			print("😤 Гость %d: терпение уже 0%%, проверяем уход" % guest_id)
	
	# Проверяем, достигло ли терпение 0 (после обновления)
	if new_patience == 0:
		# Терпение закончилось - гость уходит (если он еще активен)
		if GuestSettingsManager and GuestSettingsManager.is_guest_enabled(guest_id):
			_handle_guest_left_due_to_patience(guest_id)
	elif current_patience != new_patience:
		# Терпение уменьшилось, но не стало 0 - запускаем таймер терпения (если PatienceTimerManager доступен)
		# Таймер будет восстанавливать терпение обратно
		if PatienceTimerManager and new_patience < 100:
			PatienceTimerManager.start_timer(guest_id)

# ← Установить терпение гостя (произвольное значение от 0 до 100)
func set_guest_patience(guest_id: int, patience: int) -> void:
	"""Установить терпение гостя
	
	Args:
		guest_id: ID гостя (1-6)
		patience: Значение терпения (0-100)
	"""
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	var clamped_patience = clamp(patience, 0, 100)
	var current_patience = guest_patience[guest_id - 1]
	
	if clamped_patience != current_patience:
		guest_patience[guest_id - 1] = clamped_patience
		guest_patience_changed.emit(guest_id, clamped_patience)
		print("😌 Гость %d: терпение установлено до %d%%" % [guest_id, clamped_patience])

# ← Сбросить терпение гостя
func reset_guest_patience(guest_id: int) -> void:
	if guest_id < 1 or guest_id > 6:
		push_error("GuestStatsManager: неверный guest_id %d" % guest_id)
		return
	
	guest_patience[guest_id - 1] = 100
	guest_patience_changed.emit(guest_id, 100)

# ← Сбросить терпение всех гостей (при перезапуске игры)
func reset_all_patience() -> void:
	for i in range(6):
		guest_patience[i] = 100
	print("😌 Все терпения гостей сброшены (восстановлено до 100%)")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_payout_wrong(payload: Dictionary) -> void:
	"""Обработчик неправильной выплаты - уменьшаем терпение гостя
	
	Терпение уменьшается когда:
	- Дилер пытается забрать не проигравшую ставку гостя
	- Дилер нажал неправильную выплату для ставки гостя
	"""
	var expected_data: Dictionary = payload.get("expected", {})
	var bet_type: String = str(expected_data.get("bet_type", ""))
	var position_index: int = int(expected_data.get("position_index", -1))
	
	# Проверяем, является ли ставка гостевой
	if bet_type.is_empty() or position_index < 0:
		# Нет информации о ставке - пропускаем
		return
	
	var sector = GuestSectorMapper.get_sector_from_position(bet_type, position_index)
	if sector < 1 or sector > 6:
		# Не гостевые ставки - терпение не уменьшаем
		return
	
	var guest_id = sector
	decrease_patience(guest_id, 10)
	print("😤 Гость %d: терпение уменьшено на 10 из-за неправильной выплаты %s[%d]" % [guest_id, bet_type, position_index])

func _on_game_restarted() -> void:
	"""Обработчик рестарта игры - сбрасываем все терпения и балансы"""
	# 1. Сбрасываем терпение всех гостей до 100%
	reset_all_patience()
	
	# 2. Сбрасываем таймеры терпения
	if PatienceTimerManager:
		PatienceTimerManager.reset_all_timers()
	
	# 3. Сбрасываем все балансы гостей на 0 (не используем reset_all_balances, т.к. она устанавливает начальные значения)
	for i in range(6):
		guest_balances[i] = 0.0
		guest_initial_balances[i] = 0.0
	
	# 4. Переинициализируем включенных гостей (установим начальные балансы согласно их статусу богатства)
	_initialize_all_enabled_guests()
	
	print("🔄 GuestStatsManager: все данные сброшены при рестарте (терпение=100%, балансы=0)")

# ═══════════════════════════════════════════════════════════════════════════
# СОХРАНЕНИЕ/ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════════════════════

func _save_stats() -> void:
	var data: Dictionary = {}
	for i in range(6):
		data["guest_%d" % (i + 1)] = guest_balances[i]
	SaveManager.save_guest_stats(data)

func _load_stats() -> void:
	var data = SaveManager.load_guest_stats()
	if data.is_empty():
		# Нет сохранённых данных - используем нули
		return
	
	for i in range(6):
		var key = "guest_%d" % (i + 1)
		if data.has(key):
			guest_balances[i] = data[key] as float
		else:
			guest_balances[i] = 0.0
