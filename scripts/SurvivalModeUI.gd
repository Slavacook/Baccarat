# res://scripts/SurvivalModeUI.gd
extends Control

signal game_over(rounds_survived: int)

# TextureRect вместо Label!
@onready var hearts: Array[TextureRect] = [
	%Heart1, %Heart2, %Heart3, %Heart4, %Heart5, %Heart6, %Heart7
]

## Индикатор "Шанс" (слева от сердец) - теперь КНОПКА!
@onready var chance_indicator: TextureButton = %ChanceIndicator

## Счётчик шансов (рядом с картой)
@onready var chance_counter: Label = %ChanceCounter

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

## Текстура индикатора "Шанс"
var chance_texture: Texture2D = null

func _ready():
	hide()  # Скрыто по умолчанию
	
	# Пытаемся загрузить текстуру залога (если есть)
	if ResourceLoader.exists("res://assets/ui/heart_pledged.png"):
		heart_pledged = load("res://assets/ui/heart_pledged.png")
	else:
		# Заглушка - используем обычное сердце (визуально изменим через modulate)
		heart_pledged = null
		print("⚠️  SurvivalModeUI: heart_pledged.png не найден, используем заглушку")
	
	# Пытаемся загрузить текстуру "Шанс" (invitation_card)
	if ResourceLoader.exists("res://assets/ui/invitation_card.png"):
		chance_texture = load("res://assets/ui/invitation_card.png")
	else:
		# Заглушка - используем heart_focus
		if ResourceLoader.exists("res://assets/ui/heart_focus.png"):
			chance_texture = load("res://assets/ui/heart_focus.png")
		else:
			chance_texture = heart_full
		print("⚠️  SurvivalModeUI: invitation_card.png не найден, используем заглушку")
	
	# Настраиваем индикатор шанса (теперь это КНОПКА!)
	_setup_chance_card_button()
	
	# Настраиваем счётчик шансов
	if chance_counter:
		chance_counter.visible = false
		chance_counter.text = ""

	# Подписываемся на события ошибок для потери жизней
	EventBus.action_error.connect(_on_error)
	EventBus.payout_wrong.connect(_on_payout_wrong)
	EventBus.hint_used.connect(_on_hint_used)
	
	# Подписываемся на события Heart Bet
	EventBus.heart_pledged.connect(_on_heart_pledged)
	EventBus.heart_returned.connect(_on_heart_returned)
	EventBus.heart_bet_won.connect(_on_heart_bet_won)
	EventBus.heart_bet_lost.connect(_on_heart_bet_lost)
	EventBus.heart_bet_trigger_activated.connect(_on_heart_bet_trigger)
	EventBus.heart_bet_selected.connect(_on_heart_bet_selected)
	
	# Подписываемся на новые события счётчика шансов
	EventBus.chance_count_changed.connect(_on_chance_count_changed)
	EventBus.game_state_changed.connect(_on_game_state_changed)

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

## Финальная позиция и размер карты (сохраняются при старте)
var _chance_final_position: Vector2 = Vector2.ZERO
var _chance_final_scale: Vector2 = Vector2.ONE
var _chance_animation_tween: Tween = null

## Флаг: можно ли использовать карту (is_table_prepared)
var _can_use_chance: bool = true

## Масштаб для hover эффекта
const CHANCE_SCALE_NORMAL: Vector2 = Vector2(2, 2)
const CHANCE_SCALE_HOVER: Vector2 = Vector2(2.2, 2.2)


func _setup_chance_card_button() -> void:
	"""Настройка карты шанса как кликабельной кнопки"""
	if not chance_indicator:
		print("⚠️ ChanceIndicator не найден!")
		return
	
	# Сохраняем начальные параметры
	_chance_final_position = chance_indicator.position
	_chance_final_scale = chance_indicator.scale
	
	# Настраиваем текстуру
	chance_indicator.texture_normal = chance_texture
	
	# Настраиваем кликабельность
	chance_indicator.mouse_filter = Control.MOUSE_FILTER_STOP
	chance_indicator.disabled = false
	
	# Подключаем сигналы
	chance_indicator.pressed.connect(_on_chance_card_clicked)
	chance_indicator.mouse_entered.connect(_on_chance_card_hover.bind(true))
	chance_indicator.mouse_exited.connect(_on_chance_card_hover.bind(false))
	
	# Скрываем по умолчанию
	chance_indicator.visible = false
	
	# Устанавливаем pivot для масштабирования из центра
	chance_indicator.pivot_offset = chance_indicator.size / 2
	
	print("🎴 Карта шанса настроена как кнопка")


func _on_chance_card_clicked() -> void:
	"""Клик на маленькую карту шанса"""
	# #region agent log
	var _log_file = FileAccess.open("/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat/.cursor/debug.log", FileAccess.READ_WRITE)
	if _log_file: _log_file.seek_end(); _log_file.store_line('{"hypothesisId":"H6","location":"SurvivalModeUI._on_chance_card_clicked","message":"card clicked","data":{"_can_use_chance":%s,"is_active":%s},"timestamp":%d}' % [str(_can_use_chance).to_lower(), str(is_active).to_lower(), int(Time.get_unix_time_from_system() * 1000)]); _log_file.close()
	# #endregion
	
	if not _can_use_chance:
		# Карта недоступна (идёт раздача) - показываем toast
		print("🎴 Карта шанса: не время!")
		EventBus.show_toast_info.emit(Localization.t("NOT_TIME"))
		return
	
	print("🎴 Карта шанса нажата - открываем popup")
	EventBus.chance_card_pressed.emit()


func _on_chance_card_hover(is_hover: bool) -> void:
	"""Hover эффект на карте шанса"""
	if not chance_indicator or not chance_indicator.visible:
		return
	
	var target_scale = CHANCE_SCALE_HOVER if is_hover else _chance_final_scale
	
	var tween = create_tween()
	tween.tween_property(chance_indicator, "scale", target_scale, 0.1)


func _on_chance_count_changed(count: int) -> void:
	"""Счётчик шансов изменился"""
	print("🎴 Счётчик шансов: %d" % count)
	
	# Обновляем видимость карты
	if chance_indicator:
		chance_indicator.visible = (count > 0)
	
	# Обновляем счётчик
	if chance_counter:
		if count > 1:
			chance_counter.text = str(count)
			chance_counter.visible = true
		else:
			chance_counter.text = ""
			chance_counter.visible = false
	
	# Обновляем цвет карты (цветная / чёрно-белая)
	_update_chance_card_color()


func _on_game_state_changed(_old_state, new_state) -> void:
	"""Состояние игры изменилось - обновляем доступность карты"""
	# WAITING = можно использовать карту
	_can_use_chance = (new_state == GameStateManager.GameState.WAITING)
	_update_chance_card_color()


func _update_chance_card_color() -> void:
	"""Обновить цвет карты (цветная если доступна, чёрно-белая если нет)"""
	if not chance_indicator:
		return
	
	if _can_use_chance:
		# Цветная карта
		chance_indicator.modulate = Color.WHITE
	else:
		# Чёрно-белая карта (недоступна)
		chance_indicator.modulate = Color(0.5, 0.5, 0.5, 1.0)


## Показать карту шанса С АНИМАЦИЕЙ (при получении нового шанса)
func show_chance_indicator_animated() -> void:
	if not chance_indicator:
		return
	
	# Отменяем предыдущую анимацию если есть
	if _chance_animation_tween:
		_chance_animation_tween.kill()
	
	# Настраиваем текстуру
	chance_indicator.texture_normal = chance_texture
	
	# Начальное состояние: большая карта в центре экрана
	var viewport_size = get_viewport().get_visible_rect().size
	var center_position = Vector2(
		viewport_size.x / 2 - chance_indicator.size.x * 2,
		viewport_size.y / 2 - chance_indicator.size.y * 2
	)
	
	chance_indicator.position = center_position
	chance_indicator.scale = Vector2(4, 4)
	chance_indicator.modulate.a = 0.0
	chance_indicator.visible = true
	
	# Анимация
	_chance_animation_tween = create_tween()
	_chance_animation_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	
	# Фаза 1: Появление (0.3 сек)
	_chance_animation_tween.tween_property(chance_indicator, "modulate:a", 1.0, 0.3)
	
	# Фаза 2: Пауза на экране (1 секунда)
	_chance_animation_tween.tween_interval(1.0)
	
	# Фаза 3: Уменьшение и перемещение к сердцам (0.5 сек)
	_chance_animation_tween.set_parallel(true)
	_chance_animation_tween.tween_property(chance_indicator, "position", _chance_final_position, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_chance_animation_tween.tween_property(chance_indicator, "scale", _chance_final_scale, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Фаза 4: Обновляем цвет после анимации
	_chance_animation_tween.tween_callback(_update_chance_card_color)
	
	print("🎰 Анимация карты 'Шанс' запущена")


## Показать карту шанса (простой показ, без анимации)
func show_chance_indicator() -> void:
	if chance_indicator:
		chance_indicator.texture_normal = chance_texture
		chance_indicator.position = _chance_final_position
		chance_indicator.scale = _chance_final_scale
		chance_indicator.modulate.a = 1.0
		chance_indicator.visible = true
		_update_chance_card_color()
		print("🎰 Карта 'Шанс' показана")


## Скрыть карту шанса
func hide_chance_indicator() -> void:
	if chance_indicator:
		if _chance_animation_tween:
			_chance_animation_tween.kill()
			_chance_animation_tween = null
		chance_indicator.visible = false
		print("🎰 Карта 'Шанс' скрыта")
	
	if chance_counter:
		chance_counter.visible = false


## Обработчик триггера Heart Bet (показать карту с анимацией)
func _on_heart_bet_trigger(_trigger_name: String) -> void:
	show_chance_indicator_animated()


## Обработчик выбора сердца (карта уже скрыта при использовании шанса)
func _on_heart_bet_selected(_target: String) -> void:
	# Ничего не делаем - карта управляется через chance_count_changed
	pass
