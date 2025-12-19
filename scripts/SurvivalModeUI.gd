# res://scripts/SurvivalModeUI.gd
extends Control

signal game_over(rounds_survived: int)

# TextureRect вместо Label!
@onready var hearts: Array[TextureRect] = [
	%Heart1, %Heart2, %Heart3, %Heart4, %Heart5, %Heart6, %Heart7
]

# Карта "Шанс" теперь управляется через GameController.chance_card_ui

const MAX_LIVES = 7

# ═══════════════════════════════════════════════════════════════════════════
# НОВАЯ СИСТЕМА: HeartBar с State Pattern
# ═══════════════════════════════════════════════════════════════════════════

## HeartBar - главный менеджер жизней
var heart_bar: HeartBar

## Визуализация сердец
var heart_visual: TextureRectHeartVisual

## Текстуры для визуализации
var heart_full = preload("res://assets/ui/heart.png")
var heart_empty = preload("res://assets/ui/heart_empty.png")
var heart_pledged: Texture2D = null

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАТНАЯ СОВМЕСТИМОСТЬ: Публичные свойства для старого кода
# ═══════════════════════════════════════════════════════════════════════════

## Текущее количество жизней (для обратной совместимости)
var current_lives: int:
	get:
		return heart_bar.get_lives() if heart_bar else MAX_LIVES
	set(value):
		if heart_bar:
			heart_bar.set_lives(value)

## Активен ли режим (для обратной совместимости)
var is_active: bool:
	get:
		return heart_bar.is_active_mode() if heart_bar else false
	set(_value):
		# Нельзя устанавливать напрямую, используйте activate()/deactivate()
		pass

## Индекс сердца в залоге (для обратной совместимости)
var pledged_heart_index: int:
	get:
		return heart_bar.pledged_heart_index if heart_bar else -1

func _ready():
	hide()  # Скрыто по умолчанию
	
	# Пытаемся загрузить текстуру залога (если есть)
	if ResourceLoader.exists("res://assets/ui/heart_pledged.png"):
		heart_pledged = load("res://assets/ui/heart_pledged.png")
	else:
		# Заглушка - используем обычное сердце (визуально изменим через modulate)
		heart_pledged = null
		print("⚠️  SurvivalModeUI: heart_pledged.png не найден, используем заглушку")
	
	# Инициализируем HeartBar
	heart_bar = HeartBar.new(MAX_LIVES)
	
	# Создаём визуализацию
	heart_visual = TextureRectHeartVisual.new(
		hearts,
		heart_full,
		heart_empty,
		heart_pledged
	)
	heart_bar.set_visual(heart_visual)
	
	# Подписываемся на сигналы HeartBar
	heart_bar.lives_changed.connect(_on_lives_changed)
	heart_bar.game_over.connect(_on_game_over)
	heart_bar.life_lost.connect(_on_life_lost)
	
	# Примечание: HeartBar уже подписан на EventBus события внутри себя
	# (action_error, payout_wrong, hint_used, heart_pledged, heart_returned, heart_bet_won, heart_bet_lost)

# ← Активировать режим выживания
func activate():
	if not heart_bar:
		return
	
	heart_bar.activate()
	show()
	
	# Если уже был активен, HeartBar не сбросит жизни
	if heart_bar.is_active_mode():
		print("♻️  Режим выживания уже активен, жизней: ", heart_bar.get_lives())
	else:
		print("Режим выживания активирован! Жизней: ", heart_bar.get_lives())

# ← Деактивировать режим выживания
func deactivate():
	if not heart_bar:
		return
	
	heart_bar.deactivate()
	hide()
	print("Режим выживания деактивирован")

# ← Потерять жизнь при ошибке (для обратной совместимости)
func lose_life():
	if not heart_bar:
		return
	heart_bar.lose_life()
	_play_damage_animation()

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

# ← Обработчик изменения жизней от HeartBar
func _on_lives_changed(_new_lives: int):
	# Визуализация обновляется автоматически через HeartBar
	pass

# ← Обработчик потери жизни от HeartBar
func _on_life_lost(_remaining_lives: int):
	_play_damage_animation()

# ← Обработчик game over от HeartBar
func _on_game_over():
	print("GAME OVER! Режим выживания завершён")
	game_over.emit(0)  # 0 пока, GameController передаст реальное значение

# ← Сбросить жизни (для начала новой игры)
func reset():
	if not heart_bar:
		return
	heart_bar.activate()  # Активация сбрасывает жизни на MAX_LIVES

# ← Установить количество жизней (для синхронизации из PayoutScene)
func set_lives(lives: int):
	if not heart_bar:
		return
	heart_bar.set_lives(lives)
	print("♻️  SurvivalModeUI: установлено жизней: %d" % heart_bar.get_lives())


# ═══════════════════════════════════════════════════════════════════════════
# ❤️ HEART BET - СТАВКА СЕРДЦЕМ
# ═══════════════════════════════════════════════════════════════════════════

## Добавить жизни (после выигрыша Heart Bet)
func add_lives(count: int) -> void:
	if not heart_bar:
		return
	heart_bar.add_life(count)
	_play_heal_animation()

## Взять сердце в залог (визуальное изменение последнего сердца)
func pledge_heart() -> void:
	if not heart_bar:
		return
	heart_bar.pledge_heart()

## Вернуть сердце из залога
func return_pledged_heart() -> void:
	if not heart_bar:
		return
	heart_bar.return_pledged_heart()

## Забрать заложенное сердце (проигрыш)
func forfeit_pledged_heart() -> void:
	if not heart_bar:
		return
	heart_bar.forfeit_pledged_heart()
	_play_damage_animation()

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

## Обработчик события "сердце в залог" (HeartBar обрабатывает сам через EventBus)
func _on_heart_pledged() -> void:
	# HeartBar уже обработал через EventBus, здесь только для совместимости
	pass

## Обработчик события "сердце возвращено" (HeartBar обрабатывает сам через EventBus)
func _on_heart_returned() -> void:
	# HeartBar уже обработал через EventBus, здесь только для совместимости
	pass

## Обработчик выигрыша Heart Bet (HeartBar обрабатывает сам через EventBus)
func _on_heart_bet_won(_target: String, _lives_gained: int) -> void:
	# HeartBar уже обработал через EventBus, здесь только для совместимости
	_play_heal_animation()

## Обработчик проигрыша Heart Bet (HeartBar обрабатывает сам через EventBus)
func _on_heart_bet_lost(_target: String, _lives_remaining: int) -> void:
	# HeartBar уже обработал через EventBus, здесь только для совместимости
	_play_damage_animation()


## Получить текущее количество жизней
func get_lives() -> int:
	if not heart_bar:
		return MAX_LIVES
	return heart_bar.get_lives()

## Проверить, есть ли сердце в залоге
func has_pledged_heart() -> bool:
	if not heart_bar:
		return false
	return heart_bar.has_pledged_heart()


# ═══════════════════════════════════════════════════════════════════════════
# 🎰 КАРТА ШАНСА (КЛИКАБЕЛЬНАЯ КНОПКА)
# ═══════════════════════════════════════════════════════════════════════════

func _on_game_state_changed(_old_state, _new_state) -> void:
	"""Состояние игры изменилось (для других целей, не для карты)"""
	pass
