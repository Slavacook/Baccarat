# res://scripts/SurvivalModeUI.gd
extends Control

signal game_over(rounds_survived: int)

# TextureRect вместо Label!
@onready var hearts: Array[TextureRect] = [
	%Heart1, %Heart2, %Heart3, %Heart4, %Heart5, %Heart6, %Heart7
]

# Карта "Шанс" теперь управляется через GameController.chance_card_ui

const MAX_LIVES = 7
var current_lives: int = MAX_LIVES
var is_active: bool = false

## Индекс сердца в залоге (-1 если нет залога)
var pledged_heart_index: int = -1

var heart_full = preload("res://assets/ui/heart.png")
var heart_empty = preload("res://assets/ui/heart_empty.png")

## Текстура для сердца в залоге (пользователь может заменить на свою)
## Пока используем полупрозрачное сердце как заглушку
var heart_pledged: Texture2D = null  # Будет установлено при наличии файла

func _ready():
	hide()  # Скрыто по умолчанию
	
	# Пытаемся загрузить текстуру залога (если есть)
	if ResourceLoader.exists("res://assets/ui/heart_pledged.png"):
		heart_pledged = load("res://assets/ui/heart_pledged.png")
	else:
		# Заглушка - используем обычное сердце (визуально изменим через modulate)
		heart_pledged = null
		print("⚠️  SurvivalModeUI: heart_pledged.png не найден, используем заглушку")
	
	# Подписываемся на события ошибок для потери жизней
	EventBus.action_error.connect(_on_error)
	EventBus.payout_wrong.connect(_on_payout_wrong)
	EventBus.hint_used.connect(_on_hint_used)
	
	# Подписываемся на события Heart Bet
	EventBus.heart_pledged.connect(_on_heart_pledged)
	EventBus.heart_returned.connect(_on_heart_returned)
	EventBus.heart_bet_won.connect(_on_heart_bet_won)
	EventBus.heart_bet_lost.connect(_on_heart_bet_lost)
	
	# Примечание: heart_bet_trigger_activated и heart_bet_selected теперь обрабатываются в GameController
	# для управления картой "Шанс"

func _on_error(_type: String = "", _message: String = ""):
	"""Обработчик ошибок действий (третья карта, выбор победителя)"""
	lose_life()

func _on_payout_wrong(_collected: float, _expected: float):
	"""Обработчик неправильной выплаты"""
	lose_life()

func _on_hint_used():
	"""Обработчик использования подсказки (штраф)"""
	lose_life()

# ← Активировать режим выживания
func activate():
	if is_active:
		# Уже активен - НЕ сбрасываем жизни, просто показываем
		show()
		print("♻️  Режим выживания уже активен, жизней: ", current_lives)
		return

	is_active = true
	current_lives = MAX_LIVES
	_update_hearts()
	show()
	print("Режим выживания активирован! Жизней: ", current_lives)

# ← Деактивировать режим выживания
func deactivate():
	is_active = false
	hide()
	print("Режим выживания деактивирован")

# ← Потерять жизнь при ошибке
func lose_life():
	if not is_active:
		return

	current_lives -= 1
	print("Жизнь потеряна! Осталось: ", current_lives)

	# Эмитим событие с оставшимся количеством жизней
	EventBus.life_lost.emit(current_lives)

	_update_hearts()
	_play_damage_animation()

	if current_lives <= 0:
		_trigger_game_over()

# ← Обновить визуальное отображение сердечек
func _update_hearts():
	for i in range(MAX_LIVES):
		if i < current_lives:
			hearts[i].texture = heart_full  # Полное сердечко
		else:
			hearts[i].texture = heart_empty  # Пустое сердечко

# ← Анимация потери жизни
func _play_damage_animation():
	var tween = create_tween()
	tween.set_parallel(true)

	# Все сердечки мигают
	for heart in hearts:
		tween.tween_property(heart, "modulate", Color(1, 0.3, 0.3), 0.1)

	tween.chain().set_parallel(true)
	for heart in hearts:
		tween.tween_property(heart, "modulate", Color.WHITE, 0.1)

# ← Триггер окончания игры
func _trigger_game_over():
	is_active = false
	print("GAME OVER! Режим выживания завершён")
	game_over.emit(0)  # 0 пока, GameController передаст реальное значение

# ← Сбросить жизни (для начала новой игры)
func reset():
	current_lives = MAX_LIVES
	_update_hearts()

# ← Установить количество жизней (для синхронизации из PayoutScene)
func set_lives(lives: int):
	current_lives = clamp(lives, 0, MAX_LIVES)
	_update_hearts()
	print("♻️  SurvivalModeUI: установлено жизней: %d" % current_lives)


# ═══════════════════════════════════════════════════════════════════════════
# ❤️ HEART BET - СТАВКА СЕРДЦЕМ
# ═══════════════════════════════════════════════════════════════════════════

## Добавить жизни (после выигрыша Heart Bet)
func add_lives(count: int) -> void:
	if not is_active:
		return
	
	var old_lives = current_lives
	current_lives = min(current_lives + count, MAX_LIVES)
	var actually_added = current_lives - old_lives
	
	print("❤️ +%d жизней! (запрошено: %d, добавлено: %d, итого: %d)" % [actually_added, count, actually_added, current_lives])
	
	_update_hearts()
	_play_heal_animation()
	
	EventBus.lives_added.emit(actually_added, current_lives)


## Взять сердце в залог (визуальное изменение последнего сердца)
func pledge_heart() -> void:
	if not is_active or current_lives <= 0:
		return
	
	# Последнее активное сердце становится "в залоге"
	pledged_heart_index = current_lives - 1
	
	if heart_pledged:
		# Используем специальную текстуру
		hearts[pledged_heart_index].texture = heart_pledged
	else:
		# Заглушка - полупрозрачное сердце с оттенком
		hearts[pledged_heart_index].modulate = Color(1.0, 0.7, 0.3, 0.8)  # Оранжевый оттенок
	
	print("❤️ Сердце #%d в залоге" % (pledged_heart_index + 1))


## Вернуть сердце из залога
func return_pledged_heart() -> void:
	if pledged_heart_index < 0:
		return
	
	# Восстанавливаем текстуру
	hearts[pledged_heart_index].texture = heart_full
	hearts[pledged_heart_index].modulate = Color.WHITE
	
	print("❤️ Сердце #%d возвращено из залога" % (pledged_heart_index + 1))
	pledged_heart_index = -1


## Забрать заложенное сердце (проигрыш)
func forfeit_pledged_heart() -> void:
	if pledged_heart_index < 0:
		return
	
	# Сердце сгорает
	hearts[pledged_heart_index].texture = heart_empty
	hearts[pledged_heart_index].modulate = Color.WHITE
	current_lives -= 1
	
	print("❤️💔 Сердце #%d потеряно! Осталось: %d" % [pledged_heart_index + 1, current_lives])
	pledged_heart_index = -1
	
	EventBus.life_lost.emit(current_lives)
	
	if current_lives <= 0:
		_trigger_game_over()


## Анимация получения жизни
func _play_heal_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Все сердечки мигают зелёным
	for heart in hearts:
		tween.tween_property(heart, "modulate", Color(0.3, 1, 0.3), 0.15)
	
	tween.chain().set_parallel(true)
	for heart in hearts:
		tween.tween_property(heart, "modulate", Color.WHITE, 0.15)


## Обработчик события "сердце в залог"
func _on_heart_pledged() -> void:
	print("❤️ SurvivalModeUI: _on_heart_pledged() is_active=%s" % is_active)
	if not is_active:
		print("⚠️ SurvivalModeUI не активен, пропускаем pledge_heart")
		return
	pledge_heart()


## Обработчик события "сердце возвращено"
func _on_heart_returned() -> void:
	# #region agent log
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H3","location":"SurvivalModeUI._on_heart_returned","message":"heart_returned received","data":{"is_active":%s,"pledged_heart_index":%d},"timestamp":%d}' % [str(is_active).to_lower(), pledged_heart_index, int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	print("❤️ SurvivalModeUI: _on_heart_returned() is_active=%s" % is_active)
	if not is_active:
		print("⚠️ SurvivalModeUI не активен, пропускаем return_pledged_heart")
		return
	return_pledged_heart()


## Обработчик выигрыша Heart Bet
func _on_heart_bet_won(target: String, lives_gained: int) -> void:
	print("❤️ SurvivalModeUI: _on_heart_bet_won(%s, %d) is_active=%s" % [target, lives_gained, is_active])
	if not is_active:
		print("⚠️ SurvivalModeUI не активен, пропускаем")
		return
	# Сначала возвращаем залог
	return_pledged_heart()
	# Затем добавляем выигрыш
	add_lives(lives_gained)


## Обработчик проигрыша Heart Bet
func _on_heart_bet_lost(target: String, _lives_remaining: int) -> void:
	print("❤️ SurvivalModeUI: _on_heart_bet_lost(%s) is_active=%s" % [target, is_active])
	if not is_active:
		print("⚠️ SurvivalModeUI не активен, пропускаем")
		return
	# Залог сгорает
	forfeit_pledged_heart()


## Получить текущее количество жизней
func get_lives() -> int:
	return current_lives


## Проверить, есть ли сердце в залоге
func has_pledged_heart() -> bool:
	return pledged_heart_index >= 0


# ═══════════════════════════════════════════════════════════════════════════
# 🎰 КАРТА ШАНСА (КЛИКАБЕЛЬНАЯ КНОПКА)
# ═══════════════════════════════════════════════════════════════════════════

func _on_game_state_changed(_old_state, _new_state) -> void:
	"""Состояние игры изменилось (для других целей, не для карты)"""
	pass
