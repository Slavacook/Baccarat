# res://scripts/health_system/HeartBar.gd
# Главный менеджер системы жизней с State Pattern

class_name HeartBar
extends RefCounted

## Максимальное количество жизней
var max_lives: int = 7

## Текущее количество жизней
var current_lives: int = 7

## Активен ли режим выживания
var is_active: bool = false

## Массив сердец
var hearts: Array[Heart] = []

## Индекс сердца в залоге (-1 если нет залога)
var pledged_heart_index: int = -1

## Визуализация сердец
var visual: IHeartVisual = null

## Сигналы
signal lives_changed(new_lives: int)
signal game_over()
signal life_lost(remaining_lives: int)

## Конструктор
## Args:
##   max_lives_count: Максимальное количество жизней (по умолчанию 7)
func _init(max_lives_count: int = 7) -> void:
	max_lives = max_lives_count
	current_lives = max_lives_count
	_initialize_hearts()
	_connect_event_bus()

## Инициализировать массив сердец
func _initialize_hearts() -> void:
	hearts.clear()
	for i in range(max_lives):
		var heart = Heart.new()
		hearts.append(heart)

## Подписаться на события EventBus
func _connect_event_bus() -> void:
	if not EventBus:
		return
	
	EventBus.action_error.connect(_on_action_error)
	EventBus.payout_wrong.connect(_on_payout_wrong)
	EventBus.hint_used.connect(_on_hint_used)
	EventBus.heart_pledged.connect(_on_heart_pledged)
	EventBus.heart_returned.connect(_on_heart_returned)
	EventBus.heart_bet_won.connect(_on_heart_bet_won)
	EventBus.heart_bet_lost.connect(_on_heart_bet_lost)
	# Подписываемся на уход гостей из-за терпения
	EventBus.guest_left_due_to_patience.connect(_on_guest_left_due_to_patience)

## Установить визуализацию
func set_visual(heart_visual: IHeartVisual) -> void:
	visual = heart_visual
	_update_visual()

## Активировать режим выживания
func activate() -> void:
	if is_active:
		# Уже активен - НЕ сбрасываем жизни, просто обновляем визуализацию
		_update_visual()
		return
	
	is_active = true
	current_lives = max_lives
	pledged_heart_index = -1
	_reset_all_hearts()
	_update_visual()
	print("Режим выживания активирован! Жизней: ", current_lives)

## Деактивировать режим выживания
func deactivate() -> void:
	is_active = false
	pledged_heart_index = -1
	print("Режим выживания деактивирован")

## Потерять жизнь
func lose_life() -> void:
	if not is_active:
		return
	
	if current_lives <= 0:
		return
	
	current_lives -= 1
	print("Жизнь потеряна! Осталось: ", current_lives)
	
	# Обновляем состояние сердца
	if current_lives < hearts.size():
		hearts[current_lives].set_state(HeartState.State.EMPTY)
	
	_update_visual()
	lives_changed.emit(current_lives)
	life_lost.emit(current_lives)
	# Эмитим EventBus.life_lost для компонентов, которые подписаны на него (например, PayoutOverlay)
	if EventBus:
		EventBus.life_lost.emit(current_lives)
	
	if current_lives <= 0:
		_trigger_game_over()

## Добавить жизни
func add_life(count: int) -> void:
	if not is_active:
		return
	
	var old_lives = current_lives
	current_lives = min(current_lives + count, max_lives)
	var actually_added = current_lives - old_lives
	
	if actually_added > 0:
		print("❤️ +%d жизней! (запрошено: %d, добавлено: %d, итого: %d)" % [actually_added, count, actually_added, current_lives])
		
		# Обновляем состояния сердец
		for i in range(old_lives, current_lives):
			if i < hearts.size():
				hearts[i].set_state(HeartState.State.FULL)
		
		_update_visual()
		lives_changed.emit(current_lives)

## Взять сердце в залог
func pledge_heart() -> void:
	if not is_active or current_lives <= 0:
		return
	
	# Находим последнее видимое полное сердце (крайнее справа)
	pledged_heart_index = -1
	for i in range(hearts.size() - 1, -1, -1):
		if i < current_lives and hearts[i].is_full():
			pledged_heart_index = i
			break
	
	# Если не найдено полное сердце, используем fallback
	if pledged_heart_index < 0:
		pledged_heart_index = max(0, current_lives - 1)
	
	if pledged_heart_index < hearts.size():
		hearts[pledged_heart_index].set_state(HeartState.State.PLEDGED)
		_update_visual()
		print("❤️ Сердце #%d в залоге" % (pledged_heart_index + 1))

## Вернуть сердце из залога
func return_pledged_heart() -> void:
	if pledged_heart_index < 0:
		return
	
	var saved_index = pledged_heart_index  # Сохраняем индекс перед сбросом
	
	if saved_index < hearts.size():
		hearts[saved_index].set_state(HeartState.State.FULL)
		print("❤️ Сердце #%d возвращено из залога" % (saved_index + 1))
	
	# Сбрасываем индекс ДО обновления визуализации
	pledged_heart_index = -1
	
	# Обновляем визуализацию ПОСЛЕ сброса индекса (чтобы сердце отобразилось как FULL, а не PLEDGED)
	_update_visual()

## Забрать заложенное сердце (проигрыш)
func forfeit_pledged_heart() -> void:
	if pledged_heart_index < 0:
		return
	
	if pledged_heart_index < hearts.size():
		hearts[pledged_heart_index].set_state(HeartState.State.EMPTY)
		current_lives -= 1
		_update_visual()
		print("❤️💔 Сердце #%d потеряно! Осталось: %d" % [pledged_heart_index + 1, current_lives])
	
	pledged_heart_index = -1
	lives_changed.emit(current_lives)
	life_lost.emit(current_lives)
	# Эмитим EventBus.life_lost для компонентов, которые подписаны на него (например, PayoutOverlay)
	if EventBus:
		EventBus.life_lost.emit(current_lives)
	
	if current_lives <= 0:
		_trigger_game_over()

## Получить количество жизней (инкапсуляция!)
func get_lives() -> int:
	return current_lives

## Проверить, активен ли режим
func is_active_mode() -> bool:
	return is_active

## Проверить, есть ли сердце в залоге
func has_pledged_heart() -> bool:
	return pledged_heart_index >= 0

## Установить количество жизней (для синхронизации)
func set_lives(lives: int) -> void:
	current_lives = clamp(lives, 0, max_lives)
	_reset_all_hearts()
	_update_visual()
	print("♻️  HeartBar: установлено жизней: %d" % current_lives)

## Сбросить все сердца
func _reset_all_hearts() -> void:
	for i in range(hearts.size()):
		if i < current_lives:
			hearts[i].set_state(HeartState.State.FULL)
		else:
			hearts[i].set_state(HeartState.State.EMPTY)
	pledged_heart_index = -1

## Обновить визуализацию
func _update_visual() -> void:
	if not visual:
		return
	
	if visual is TextureRectHeartVisual:
		# Для TextureRectHeartVisual обновляем все сердца
		var texture_visual = visual as TextureRectHeartVisual
		texture_visual.update_all_hearts(current_lives, pledged_heart_index)
	elif visual is LabelHeartVisual:
		# Для LabelHeartVisual обновляем только количество
		var label_visual = visual as LabelHeartVisual
		label_visual.update_visual(HeartState.State.FULL, current_lives)

## Триггер окончания игры
func _trigger_game_over() -> void:
	is_active = false
	print("GAME OVER! Режим выживания завершён")
	game_over.emit()

## Обработчики событий EventBus
func _on_action_error(_type: String = "", _message: String = "") -> void:
	"""Обработка ошибки действия
	
	Логика:
	- Если есть чаевые (>= 100) → штраф 100 чаевых + минус 20% терпения всех активных гостей
	- Если чаевых недостаточно → минус сердце
	"""
	if not is_active:
		return
	
	# Проверяем наличие чаевых
	var current_tips = SaveManager.instance.score if SaveManager.instance else 0
	var penalty_amount = 100
	
	if current_tips >= penalty_amount:
		# Чаевых достаточно - сначала уменьшаем терпение, потом штраф с задержкой
		print("💰 Ошибка: штраф %d чаевых (было %d)" % [penalty_amount, current_tips])
		
		# Уменьшаем терпение всех активных гостей на 20% (сразу, без задержки)
		if GuestSettingsManager and GuestStatsManager:
			var active_guests = GuestSettingsManager.get_active_guests()
			for guest_id in active_guests:
				GuestStatsManager.decrease_patience(guest_id, 20)
				print("😤 Гость %d: терпение уменьшено на 20%% из-за ошибки" % guest_id)
		
		# Применяем штраф на чаевые с задержкой 1 сек (со звуком)
		if StatsManager.instance:
			await StatsManager.instance.apply_penalty_with_delay(penalty_amount)
		
		# Событие penalty_applied уже эмитится в StatsManager.apply_penalty_with_delay()
		print("✅ Ошибка обработана: терпение уменьшено, штраф %d чаевых применен" % penalty_amount)
	else:
		# Чаевых недостаточно - отнимаем сердце и уменьшаем терпение
		print("❌ Ошибка: чаевых недостаточно (%d < %d) - отнимается сердце" % [current_tips, penalty_amount])
		
		# Уменьшаем терпение всех активных гостей на 20%
		if GuestSettingsManager and GuestStatsManager:
			var active_guests = GuestSettingsManager.get_active_guests()
			for guest_id in active_guests:
				GuestStatsManager.decrease_patience(guest_id, 20)
				print("😤 Гость %d: терпение уменьшено на 20%% из-за ошибки (отнято сердце)" % guest_id)
		
		# Отнимаем сердце
	lose_life()

func _on_payout_wrong(_collected: float, _expected: float, _bet_type: String, _position_index: int) -> void:
	lose_life()

func _on_hint_used() -> void:
	lose_life()

func _on_heart_pledged() -> void:
	pledge_heart()

func _on_heart_returned() -> void:
	return_pledged_heart()

func _on_heart_bet_won(_target: String, lives_gained: int) -> void:
	# Сначала возвращаем залог
	return_pledged_heart()
	# Затем добавляем выигрыш
	add_life(lives_gained)

func _on_heart_bet_lost(_target: String, _lives_remaining: int) -> void:
	# Залог сгорает
	forfeit_pledged_heart()

func _on_guest_left_due_to_patience(guest_id: int) -> void:
	"""Обработчик ухода гостя из-за терпения - отнимаем сердце
	
	Args:
		guest_id: ID гостя (1-6)
	"""
	if not is_active:
		return
	
	print("💔 Гость %d ушел из-за терпения - отнимается сердце" % guest_id)
	lose_life()
