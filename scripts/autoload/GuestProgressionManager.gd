# res://scripts/autoload/GuestProgressionManager.gd
# Автоматическое добавление гостей в зависимости от накопленных чаевых

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

## Пороги по умолчанию (можно изменять в настройках)
const DEFAULT_THRESHOLDS: Dictionary = {
	1: 0,      # Начальное состояние - 1 гость
	2: 100,    # 2-й гость при 100 чаевых
	3: 300,    # 3-й гость при 300 чаевых
	4: 900,    # 4-й гость при 900 чаевых
	5: 2700,   # 5-й гость при 2700 чаевых
	6: 8100    # 6-й гость при 8100 чаевых
}

## Минимальный зазор между активациями новых гостей (в раундах)
const MIN_ROUNDS_BETWEEN_NEW_GUESTS: int = 3

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Текущие пороги (загружаются из сохранений или используются DEFAULT)
var thresholds: Dictionary = {}

## Автоматический режим включен/выключен
var auto_mode_enabled: bool = true

## Было ли выполнено начальное инициализирование
var initial_guest_initialized: bool = false

## Номер раунда последней активации нового гостя (0 = еще не было активаций)
var last_new_guest_activation_round: int = 0

## Текущий номер раунда (отслеживается через round_started)
var current_round: int = 0

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	"""Инициализация менеджера прогрессии гостей"""
	# Инициализируем генератор случайных чисел для случайного выбора гостей
	randomize()
	
	_load_settings()
	_connect_to_events()
	
	# Инициализируем начального гостя при первом запуске игры
	if not initial_guest_initialized:
		initialize_first_guest()
	
	# Проверяем текущее состояние гостей
	check_and_update_guests()
	
	print("🎯 GuestProgressionManager готов (авторежим: %s)" % ("вкл" if auto_mode_enabled else "выкл"))

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func initialize_first_guest() -> void:
	"""Инициализировать первого случайного гостя при первом запуске
	
	ВАЖНО: Если авторежим включен и чаевые = 0, принудительно сбрасываем всех гостей
	и создаём новых с правильными статусами (первый гость = POOR).
	Это нужно, чтобы избежать проблем, когда гость был включен вручную в настройках
	с неправильным статусом (например, RICH вместо POOR).
	"""
	if not GuestSettingsManager:
		return
	
	# Если авторежим включен - проверяем чаевые для определения правильного количества гостей
	if auto_mode_enabled:
		if not SaveManager or not SaveManager.instance:
			return
		
		var current_tips = SaveManager.instance.score
		var required_count = get_required_guest_count(current_tips)
		
		# Если чаевые = 0 (первый запуск) - принудительно пересоздаём гостей
		if current_tips == 0:
			var current_active_guests = GuestSettingsManager.get_active_guests()
			
			# Если уже есть активные гости, но это первый запуск (0 чаевых),
			# значит они были включены вручную или из старых сохранений
			# Нужно их отключить и создать правильных
			if current_active_guests.size() > 0:
				print("🎯 Первый запуск (0 чаевых), но найдены активные гости: %s" % str(current_active_guests))
				print("🎯 Отключаем всех для пересоздания с правильными статусами")
				
				# Отключаем всех активных гостей
				for guest_id in current_active_guests:
					GuestSettingsManager.set_guest_enabled(guest_id, false)
			
			# Активируем правильное количество гостей (с 0 чаевых должно быть 1)
			# activate_random_guests() выберет случайного гостя и установит ему статус POOR
			if required_count > 0:
				var activated = activate_random_guests(required_count)
				if activated.size() > 0:
					# Сохраняем номер раунда первой активации (если current_round еще 0, это нормально)
					last_new_guest_activation_round = current_round
					initial_guest_initialized = true
					print("🎯 Первый гость инициализирован: гость %d (статус: POOR)" % activated[0])
				else:
					push_error("GuestProgressionManager: не удалось активировать первого гостя")
			return
		else:
			# Чаевые > 0 - это не первый запуск, гости уже должны быть правильно настроены
			# Просто проверяем, что их количество соответствует чаевым
			initial_guest_initialized = true
			return
	
	# Если авторежим выключен - используем старую логику
	# Проверить, был ли первый запуск (все гости выключены)
	var active_guests_check = GuestSettingsManager.get_active_guests()
	if active_guests_check.size() > 0:
		# Уже есть активные гости - пропускаем
		initial_guest_initialized = true
		return
	
	# Если все гости выключены - активировать 1 случайного гостя
	var random_guest = get_random_inactive_guest()
	if random_guest > 0:
		if activate_guest(random_guest, false):  # Без toast при инициализации
			# Сохраняем номер раунда первой активации (если current_round еще 0, это нормально)
			last_new_guest_activation_round = current_round
		initial_guest_initialized = true
		print("🎯 Первый гость инициализирован: гость %d" % random_guest)

func check_and_update_guests() -> void:
	"""Проверить текущие чаевые и обновить количество гостей при необходимости
	
	Вызывается при изменении чаевых (tip_received, penalty_applied)
	и при инициализации игры после game_restarted
	"""
	# Проверить, включен ли автоматический режим
	if not auto_mode_enabled:
		return
	
	# Получить текущие чаевые из SaveManager
	if not SaveManager or not SaveManager.instance:
		return
	
	var current_tips = SaveManager.instance.score
	
	# Определить необходимое количество гостей на основе порогов
	var required_count = get_required_guest_count(current_tips)
	
	# Получить текущих активных гостей
	if not GuestSettingsManager:
		return
	
	var active_guests = GuestSettingsManager.get_active_guests()
	var active_count = active_guests.size()
	
	# ВАЖНО: Учитываем временно отсутствующих гостей (которые скоро вернутся)
	# Это предотвращает активацию нового гостя, когда текущий просто временно ушел
	var temporarily_absent_count = 0
	if GuestReturnManager:
		temporarily_absent_count = GuestReturnManager.guests_left.size()
	
	# Текущее количество = активные + временно отсутствующие
	var current_count = active_count + temporarily_absent_count
	
	print("🎯 Проверка гостей: чаевые=%d, требуется гостей=%d, сейчас активно=%d, временно отсутствует=%d, всего=%d" % [
		current_tips, required_count, active_count, temporarily_absent_count, current_count
	])
	
	# Если нужно больше гостей - активируем недостающих
	if current_count < required_count:
		var needed = required_count - current_count
		
		# Проверяем, можно ли активировать нового гостя
		if not _can_activate_new_guest():
			print("🎯 Недостаточно гостей (требуется %d, активно %d), но активация отложена (зазор < %d раундов)" % [
				required_count, current_count, MIN_ROUNDS_BETWEEN_NEW_GUESTS
			])
			return
		
		# Активируем только ОДНОГО гостя, даже если нужно больше
		var activated = activate_random_guests(1)
		if activated.size() > 0:
			# Сохраняем номер раунда активации
			last_new_guest_activation_round = current_round
			print("🎯 Активирован 1 гость: %s (раунд %d, осталось активировать: %d)" % [
				activated, current_round, needed - 1
			])
		else:
			print("🎯 Не удалось активировать нового гостя (все гости уже активны или временно отсутствуют)")
	
	# Если активно больше гостей, чем нужно - деактивируем лишних
	# Это происходит при включении режима прогрессии или изменении порогов
	# Примечание: гости остаются активными, если чаевые упали ниже порога (не деактивируем при штрафах)
	elif current_count > required_count:
		var excess = current_count - required_count
		print("🎯 Найдено лишних гостей: %d (требуется %d, активно %d)" % [excess, required_count, current_count])
		
		# Создаём копию списка активных гостей для работы
		var guests_to_deactivate: Array[int] = []
		var active_guests_copy = active_guests.duplicate()
		active_guests_copy.shuffle()  # Перемешиваем для случайного выбора
		
		# Выбираем лишних гостей для отключения
		for i in range(excess):
			if active_guests_copy.size() > 0:
				var guest_to_disable = active_guests_copy.pop_back()
				guests_to_deactivate.append(guest_to_disable)
		
		# Отключаем лишних гостей
		for guest_id in guests_to_deactivate:
			if GuestSettingsManager:
				GuestSettingsManager.set_guest_enabled(guest_id, false)
				print("🎯 Деактивирован гость %d (лишний для текущих чаевых: %d)" % [guest_id, current_tips])

func get_required_guest_count(tips: int) -> int:
	"""Определить необходимое количество гостей на основе текущих чаевых
	
	Args:
		tips: Текущее количество чаевых
		
	Returns:
		Количество гостей, которое должно быть активно (1-6)
	"""
	# Используем текущие пороги (или DEFAULT если пусто)
	var active_thresholds = thresholds if not thresholds.is_empty() else DEFAULT_THRESHOLDS
	
	# Пройти по порогам от большего к меньшему (6 → 1)
	for guest_count in range(6, 0, -1):
		var threshold = active_thresholds.get(guest_count, 0)
		if tips >= threshold:
			return guest_count
	
	# Если tips < самого маленького порога - возвращаем 1
	return 1

func get_random_inactive_guest() -> int:
	"""Получить ID случайного неактивного гостя
	Исключает гостей, которые временно отсутствуют (ожидают возврата)
	
	Returns:
		guest_id (1-6) или -1 если все гости активны или временно отсутствуют
	"""
	if not GuestSettingsManager:
		return -1
	
	# Получить список активных гостей
	var active_guests = GuestSettingsManager.get_active_guests()
	
	# Получить список временно отсутствующих гостей (ожидают возврата)
	var temporarily_absent_guests: Array[int] = []
	if GuestReturnManager:
		for guest_id in GuestReturnManager.guests_left.keys():
			temporarily_absent_guests.append(guest_id)
	
	# Создать список всех гостей (1-6)
	var all_guests = []
	for i in range(1, 7):
		all_guests.append(i)
	
	# Удалить активных гостей из списка
	for active_id in active_guests:
		all_guests.erase(active_id)
	
	# Удалить временно отсутствующих гостей (они вернутся сами)
	for absent_id in temporarily_absent_guests:
		all_guests.erase(absent_id)
	
	# Если список пустой - все гости либо активны, либо временно отсутствуют
	if all_guests.is_empty():
		return -1
	
	# Перемешать и выбрать случайного
	all_guests.shuffle()
	return all_guests[0]

func activate_guest(guest_id: int, show_toast: bool = true) -> bool:
	"""Активировать конкретного гостя
	
	Определяет начальный статус богатства на основе порядка активации:
	- Первые 2 гостя → бедные
	- Следующие 2 гостя (3-й и 4-й) → средние
	- Последние 2 гостя (5-й и 6-й) → богатые
	
	Args:
		guest_id: ID гостя для активации (1-6)
		show_toast: Показывать ли Toast уведомление
		
	Returns:
		true если гость успешно активирован, false если ошибка
	"""
	# Проверить валидность guest_id (1-6)
	if guest_id < 1 or guest_id > 6:
		push_error("GuestProgressionManager: неверный guest_id %d" % guest_id)
		return false
	
	if not GuestSettingsManager:
		return false
	
	# Проверить, не активен ли уже гость
	if GuestSettingsManager.is_guest_enabled(guest_id):
		return false
	
	# Определяем начальный статус богатства на основе порядка активации
	# Получаем количество активных гостей ДО активации текущего
	var active_guests = GuestSettingsManager.get_active_guests()
	var active_count = active_guests.size()  # Количество ДО активации текущего
	
	var initial_wealth: GuestSettingsManager.GuestWealth
	if active_count < 2:
		# Первые 2 гостя → бедные
		initial_wealth = GuestSettingsManager.GuestWealth.POOR
	elif active_count < 4:
		# Следующие 2 гостя (3-й и 4-й) → средние
		initial_wealth = GuestSettingsManager.GuestWealth.MEDIUM
	else:
		# Последние 2 гостя (5-й и 6-й) → богатые
		initial_wealth = GuestSettingsManager.GuestWealth.RICH
	
	# Устанавливаем статус ПЕРЕД активацией (чтобы initialize_guest_balance использовал правильный статус)
	# preserve_balance = false, потому что это новая активация - баланс устанавливается из статуса
	# ВАЖНО: Если гость был включен из сохранений, его статус может быть неправильным (RICH вместо POOR)
	# Поэтому мы принудительно устанавливаем правильный статус и переинициализируем баланс
	GuestSettingsManager.set_guest_wealth(guest_id, initial_wealth, false)
	
	# Активировать гостя
	GuestSettingsManager.set_guest_enabled(guest_id, true)
	
	# ВАЖНО: Принудительно переинициализируем баланс после установки статуса
	# Это нужно, если гость был включен в сохранённых настройках и имел неправильный баланс
	if GuestStatsManager:
		GuestStatsManager.initialize_guest_balance(guest_id)
	
	# Регистрируем активацию гостя в GuestReturnManager (добавляем в список задействованных)
	if GuestReturnManager:
		GuestReturnManager.register_guest_activation(guest_id)
	
	# Логировать активацию
	print("🎯 Гость %d активирован (прогрессия, статус: %s)" % [
		guest_id, GuestSettingsManager.GuestWealth.keys()[initial_wealth]
	])
	
	# Если show_toast - показать Toast
	if show_toast and EventBus:
		EventBus.show_toast_success.emit(Localization.t("NEW_GUEST_ARRIVED") if Localization else "Пришел ещё один новый гость")
	
	# ВАЖНО: Принудительно устанавливаем видимость гостя, чтобы он не исчез при обновлении стола
	# Это гарантирует, что новый гость останется видимым сразу после активации
	if EventBus:
		EventBus.guest_force_visible.emit(guest_id)
		print("👥 Гость %d: принудительно установлена видимость после активации" % guest_id)
	
		# Автоматически переводим камеру на нового гостя
		EventBus.camera_zoom_requested.emit("guest_%d" % guest_id, false)
		print("📷 Камера автоматически переведена на гостя %d" % guest_id)
	
	return true

func activate_random_guests(count: int) -> Array[int]:
	"""Активировать случайных неактивных гостей
	Исключает гостей, которые временно отсутствуют (ожидают возврата)
	
	Args:
		count: Количество гостей для активации
		
	Returns:
		Массив ID активированных гостей
	"""
	var activated: Array[int] = []
	
	# Получить список активных гостей
	if not GuestSettingsManager:
		return activated
	
	var active_guests = GuestSettingsManager.get_active_guests()
	
	# Получить список временно отсутствующих гостей (ожидают возврата)
	var temporarily_absent_guests: Array[int] = []
	if GuestReturnManager:
		for guest_id in GuestReturnManager.guests_left.keys():
			temporarily_absent_guests.append(guest_id)
	
	# Создать список всех гостей (1-6)
	var all_guests = []
	for i in range(1, 7):
		all_guests.append(i)
	
	# Удалить активных гостей
	for active_id in active_guests:
		all_guests.erase(active_id)
	
	# Удалить временно отсутствующих гостей (они вернутся сами)
	for absent_id in temporarily_absent_guests:
		all_guests.erase(absent_id)
	
	# Перемешать оставшихся
	all_guests.shuffle()
	
	# Взять первые count гостей
	var to_activate = all_guests.slice(0, min(count, all_guests.size()))
	
	# Активировать каждого
	for guest_id in to_activate:
		if activate_guest(guest_id, true):  # show_toast = true для каждого нового гостя
			activated.append(guest_id)
	
	return activated

func set_thresholds(new_thresholds: Dictionary) -> void:
	"""Установить новые пороги (вызывается из попапа настроек)
	
	Args:
		new_thresholds: Словарь {количество_гостей: порог_чаевых}
		Может содержать только ключи 2-6, порог для 1 гостя всегда 0
	"""
	# Валидировать new_thresholds (должны быть ключи 2-6, значения >= 0)
	for key in range(2, 7):  # Проверяем только 2-6
		if not new_thresholds.has(key):
			push_error("GuestProgressionManager: отсутствует порог для %d гостей" % key)
			return
		var threshold = new_thresholds[key]
		if not (threshold is int) or threshold < 0:
			push_error("GuestProgressionManager: неверный порог для %d гостей: %s" % [key, threshold])
			return
	
	# Сохранить в thresholds (включая порог для 1 гостя = 0)
	thresholds = {}
	thresholds[1] = 0  # Всегда 0 для 1 гостя
	for key in range(2, 7):
		thresholds[key] = new_thresholds[key]
	
	# Сохранить через SaveManager
	_save_thresholds()
	
	# Перепроверить текущее состояние гостей
	if auto_mode_enabled:
		check_and_update_guests()

func get_thresholds() -> Dictionary:
	"""Получить текущие пороги
	
	Returns:
		Словарь {количество_гостей: порог_чаевых}
		Всегда включает порог для 1 гостя = 0
	"""
	if thresholds.is_empty():
		return DEFAULT_THRESHOLDS
	
	# Убеждаемся, что порог для 1 гостя всегда равен 0
	var result = thresholds.duplicate()
	if not result.has(1):
		result[1] = 0
	
	return result

func get_default_thresholds() -> Dictionary:
	"""Получить пороги по умолчанию
	
	Returns:
		Словарь с порогами по умолчанию {количество_гостей: порог_чаевых}
	"""
	return DEFAULT_THRESHOLDS.duplicate()

func set_auto_mode(enabled: bool) -> void:
	"""Включить/выключить автоматический режим
	
	Args:
		enabled: true = автоматический режим включен
	"""
	var was_enabled = auto_mode_enabled
	auto_mode_enabled = enabled
	
	# Сохранить через SaveManager
	_save_auto_mode()
	
	# Если режим включен - проверить и обновить гостей на основе текущих чаевых
	if enabled and not was_enabled:
		# Режим только что включили - нужно пересчитать гостей
		print("🎯 Режим прогрессии включен - пересчитываем гостей")
		check_and_update_guests()

func is_auto_mode_enabled() -> bool:
	"""Проверить, включен ли автоматический режим
	
	Returns:
		true если автоматический режим включен
	"""
	return auto_mode_enabled

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _on_tip_received(_tip_amount: int) -> void:
	"""Обработчик получения чаевых (подписан на EventBus.tip_received)"""
	check_and_update_guests()

func _on_penalty_applied(_penalty_amount: int) -> void:
	"""Обработчик применения штрафа (подписан на EventBus.penalty_applied)
	
	Примечание: Гости остаются активными даже если чаевые упали ниже порога
	"""
	# TODO: НЕ вызывать check_and_update_guests() (гости остаются)
	pass

func _can_activate_new_guest() -> bool:
	"""Проверить, можно ли активировать нового гостя
	
	Returns:
		true если прошло минимум MIN_ROUNDS_BETWEEN_NEW_GUESTS раундов
		с последней активации, или если это первая активация
	"""
	# Если еще не было активаций - можно активировать
	if last_new_guest_activation_round == 0:
		return true
	
	# Вычисляем количество раундов с последней активации
	var rounds_since_last_activation = current_round - last_new_guest_activation_round
	
	# Можно активировать, если прошло минимум MIN_ROUNDS_BETWEEN_NEW_GUESTS раундов
	var can_activate = rounds_since_last_activation >= MIN_ROUNDS_BETWEEN_NEW_GUESTS
	
	if not can_activate:
		print("🎯 Активирование нового гостя отложено: прошло %d раундов, требуется %d" % [
			rounds_since_last_activation, MIN_ROUNDS_BETWEEN_NEW_GUESTS
		])
	
	return can_activate

func _on_round_started() -> void:
	"""Обработчик начала нового раунда - увеличиваем счетчик"""
	current_round += 1
	print("🎯 GuestProgressionManager: текущий раунд = %d" % current_round)
	# Примечание: проверка активации гостей теперь происходит через all_bets_processed
	# Это обеспечивает активацию за шаг до начала новой раздачи

func _on_all_bets_processed() -> void:
	"""Обработчик завершения обработки всех ставок
	
	Вызывается когда:
	- Оплачена последняя выигрышная ставка (если были выигрышные)
	- Забрана последняя проигрышная ставка (если не было выигрышных, но были проигрышные)
	- Сразу после выяснения победителя (если не было ни выигрышных, ни проигрышных ставок)
	
	Это момент, когда можно активировать нового гостя (за шаг до начала новой раздачи).
	"""
	if auto_mode_enabled:
		check_and_update_guests()

func _on_game_restarted() -> void:
	"""Обработчик рестарта игры (подписан на EventBus.game_restarted)
	
	При рестарте чаевые сбрасываются, нужно пересчитать гостей.
	ВАЖНО: Принудительно отключаем всех гостей, затем активируем только необходимое количество.
	"""
	initial_guest_initialized = false
	
	# Сбрасываем отслеживание активаций
	last_new_guest_activation_round = 0
	current_round = 0
	
	# Если авторежим включен - пересчитываем гостей на основе 0 чаевых
	if auto_mode_enabled:
		# Получаем текущие чаевые (должны быть 0 после рестарта)
		if not SaveManager or not SaveManager.instance:
			push_error("GuestProgressionManager: SaveManager не найден при рестарте")
			return
		
		var current_tips = SaveManager.instance.score
		
		# Убеждаемся, что пороги загружены (могут быть сброшены при рестарте)
		if thresholds.is_empty():
			_load_settings()
		
		var required_count = get_required_guest_count(current_tips)
		
		print("🎯 Рестарт игры: чаевые=%d, пороги=%s, требуется гостей=%d" % [current_tips, thresholds, required_count])
		
		# Принудительно отключаем всех активных гостей
		if GuestSettingsManager:
			var active_guests = GuestSettingsManager.get_active_guests()
			print("🎯 Рестарт: найдено %d активных гостей: %s" % [active_guests.size(), active_guests])
			
			for guest_id in active_guests:
				GuestSettingsManager.set_guest_enabled(guest_id, false)
				print("🎯 Рестарт: отключён гость %d" % guest_id)
		
		# Проверяем, что все гости отключены
		if GuestSettingsManager:
			var remaining_active = GuestSettingsManager.get_active_guests()
			if remaining_active.size() > 0:
				push_error("GuestProgressionManager: после отключения осталось %d активных гостей: %s" % [remaining_active.size(), remaining_active])
				# Принудительно отключаем оставшихся
				for guest_id in remaining_active:
					GuestSettingsManager.set_guest_enabled(guest_id, false)
		
		# Активируем только необходимое количество гостей (с 0 чаевых должно быть 1)
		if required_count > 0:
			var activated = activate_random_guests(required_count)
			if activated.size() > 0:
				print("🎯 Рестарт: активировано %d гостей: %s" % [activated.size(), activated])
			else:
				push_error("GuestProgressionManager: не удалось активировать ни одного гостя (требовалось %d)" % required_count)
		
		# Устанавливаем флаг инициализации первого гостя
		if required_count >= 1:
			initial_guest_initialized = true
	else:
		# Авторежим выключен - просто вызываем стандартную проверку
		print("🎯 Рестарт: авторежим выключен, стандартная проверка гостей")
		check_and_update_guests()

func _connect_to_events() -> void:
	"""Подписаться на события EventBus"""
	if EventBus:
		EventBus.tip_received.connect(_on_tip_received)
		# НЕ подписываемся на penalty_applied - гости остаются даже при снижении чаевых
		EventBus.game_restarted.connect(_on_game_restarted)
		EventBus.round_started.connect(_on_round_started)
		EventBus.all_bets_processed.connect(_on_all_bets_processed)

func _load_settings() -> void:
	"""Загрузить сохранённые настройки из SaveManager"""
	# Загрузить пороги
	var loaded_thresholds = SaveManager.load_guest_progression_thresholds()
	if not loaded_thresholds.is_empty():
		thresholds = loaded_thresholds
		# Убеждаемся, что порог для 1 гостя всегда равен 0
		if not thresholds.has(1):
			thresholds[1] = 0
	else:
		# Если порогов нет, используем дефолтные значения
		thresholds = DEFAULT_THRESHOLDS.duplicate()
	
	# Загрузить состояние режима
	auto_mode_enabled = SaveManager.load_guest_progression_auto_mode()

func _save_thresholds() -> void:
	"""Сохранить текущие пороги в SaveManager"""
	SaveManager.save_guest_progression_thresholds(thresholds)

func _save_auto_mode() -> void:
	"""Сохранить состояние автоматического режима в SaveManager"""
	SaveManager.save_guest_progression_auto_mode(auto_mode_enabled)
