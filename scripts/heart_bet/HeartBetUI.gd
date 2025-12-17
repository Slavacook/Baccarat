# res://scripts/heart_bet/HeartBetUI.gd
# UI компонент для ставки сердцем
# Отображает 3 сердца на столе (Player/Banker/Tie)

extends Control

## Текстуры сердец
var heart_texture: Texture2D = preload("res://assets/ui/heart.png")
var heart_focus_texture: Texture2D = preload("res://assets/ui/heart_focus.png")

## Ссылки на кнопки сердец
@onready var heart_player: TextureButton = %HeartPlayer
@onready var heart_banker: TextureButton = %HeartBanker
@onready var heart_tie: TextureButton = %HeartTie

## Текущее выбранное сердце (или пустая строка если не выбрано)
var selected_target: String = ""

## Прозрачность для разных состояний
const OPACITY_UNSELECTED: float = 0.4
const OPACITY_HOVER: float = 0.7
const OPACITY_SELECTED: float = 1.0

## ═══════════════════════════════════════════════════════════════════════════
## НАСТРОЙКИ РАЗМЕРОВ И АНИМАЦИИ (меняйте здесь!)
## ═══════════════════════════════════════════════════════════════════════════

## Начальный масштаб сердец (1.0 = 100%)
const SCALE_NORMAL: Vector2 = Vector2(0.5, 0.5)

## Масштаб при наведении мышки
const SCALE_HOVER: Vector2 = Vector2(0.6, 0.6)

## Масштаб выбранного сердца
const SCALE_SELECTED: Vector2 = Vector2(0.65, 0.65)

## Скорость анимации масштабирования (секунды)
const SCALE_ANIMATION_DURATION: float = 0.1


func _ready():
	# Скрываем по умолчанию
	hide()
	
	# Настраиваем текстуры и кликабельность
	_setup_hearts()
	
	# Подключаем сигналы кнопок (pressed)
	heart_player.pressed.connect(_on_heart_pressed.bind("Player"))
	heart_banker.pressed.connect(_on_heart_pressed.bind("Banker"))
	heart_tie.pressed.connect(_on_heart_pressed.bind("Tie"))
	
	# Подключаем hover сигналы (mouse_entered/mouse_exited)
	heart_player.mouse_entered.connect(_on_heart_hover.bind("Player", true))
	heart_player.mouse_exited.connect(_on_heart_hover.bind("Player", false))
	heart_banker.mouse_entered.connect(_on_heart_hover.bind("Banker", true))
	heart_banker.mouse_exited.connect(_on_heart_hover.bind("Banker", false))
	heart_tie.mouse_entered.connect(_on_heart_hover.bind("Tie", true))
	heart_tie.mouse_exited.connect(_on_heart_hover.bind("Tie", false))
	
	# Подключаем gui_input для отладки
	heart_player.gui_input.connect(_on_gui_input.bind("Player"))
	heart_banker.gui_input.connect(_on_gui_input.bind("Banker"))
	heart_tie.gui_input.connect(_on_gui_input.bind("Tie"))
	
	# Подписываемся на события EventBus
	EventBus.heart_bet_show_ui.connect(_on_show_ui)
	EventBus.heart_bet_hide_ui.connect(_on_hide_ui)
	EventBus.heart_bet_declined.connect(_on_declined)
	EventBus.heart_bet_confirmed.connect(_on_confirmed)
	EventBus.heart_bet_hide_selected.connect(_on_hide_selected)
	
	print("❤️ HeartBetUI готов")


func _on_gui_input(event: InputEvent, target: String) -> void:
	"""Отладка: любой ввод на сердце"""
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			print("❤️ GUI INPUT: клик на %s!" % target)


func _setup_hearts() -> void:
	"""Настройка начального состояния сердец"""
	# Устанавливаем текстуры (обычная и hover)
	heart_player.texture_normal = heart_texture
	heart_banker.texture_normal = heart_texture
	heart_tie.texture_normal = heart_texture
	
	# Текстура при наведении (светящееся сердце)
	heart_player.texture_hover = heart_focus_texture
	heart_banker.texture_hover = heart_focus_texture
	heart_tie.texture_hover = heart_focus_texture
	
	# Устанавливаем прозрачность (полупрозрачные)
	heart_player.modulate.a = OPACITY_UNSELECTED
	heart_banker.modulate.a = OPACITY_UNSELECTED
	heart_tie.modulate.a = OPACITY_UNSELECTED
	
	# ═══════════════════════════════════════════════════════════════════
	# ВАЖНО: Настраиваем кликабельность!
	# ═══════════════════════════════════════════════════════════════════
	heart_player.mouse_filter = Control.MOUSE_FILTER_STOP
	heart_banker.mouse_filter = Control.MOUSE_FILTER_STOP
	heart_tie.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Убеждаемся что кнопки не заблокированы
	heart_player.disabled = false
	heart_banker.disabled = false
	heart_tie.disabled = false
	
	# Родительский Control должен игнорировать клики (IGNORE), чтобы дети получали их
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# ═══════════════════════════════════════════════════════════════════
	# ВАЖНО: Устанавливаем pivot_offset на центр для масштабирования из центра
	# ═══════════════════════════════════════════════════════════════════
	_set_pivot_to_center(heart_player)
	_set_pivot_to_center(heart_banker)
	_set_pivot_to_center(heart_tie)
	
	# Устанавливаем начальный масштаб
	heart_player.scale = SCALE_NORMAL
	heart_banker.scale = SCALE_NORMAL
	heart_tie.scale = SCALE_NORMAL
	
	print("❤️ Сердца настроены: Player=%s, Banker=%s, Tie=%s" % [
		heart_player.texture_normal != null,
		heart_banker.texture_normal != null,
		heart_tie.texture_normal != null
	])


func _set_pivot_to_center(btn: TextureButton) -> void:
	"""Устанавливает точку поворота/масштабирования в центр кнопки"""
	# pivot_offset = половина размера кнопки
	btn.pivot_offset = btn.size / 2


func _on_heart_hover(target: String, is_hover: bool) -> void:
	"""Обработка наведения на сердце"""
	# Если это сердце уже выбрано - не меняем
	if target == selected_target:
		return
	
	var heart_btn = _get_heart_button(target)
	if heart_btn:
		var tween = create_tween()
		if is_hover:
			# Наведение - увеличиваем прозрачность и масштаб
			heart_btn.modulate.a = OPACITY_HOVER
			tween.tween_property(heart_btn, "scale", SCALE_HOVER, SCALE_ANIMATION_DURATION)
		else:
			# Убираем наведение - возвращаем базовую прозрачность и масштаб
			heart_btn.modulate.a = OPACITY_UNSELECTED
			tween.tween_property(heart_btn, "scale", SCALE_NORMAL, SCALE_ANIMATION_DURATION)


func _get_heart_button(target: String) -> TextureButton:
	"""Получить кнопку сердца по имени"""
	match target:
		"Player":
			return heart_player
		"Banker":
			return heart_banker
		"Tie":
			return heart_tie
	return null


func _on_heart_pressed(target: String) -> void:
	"""Обработка нажатия на сердце"""
	print("❤️ Нажато сердце: %s" % target)
	
	# Если уже выбрано это же сердце - ничего не делаем
	if selected_target == target:
		return
	
	# Запоминаем выбор
	selected_target = target
	
	# Обновляем визуал
	_update_visual()
	
	# Эмитим событие выбора
	EventBus.heart_bet_selected.emit(target)


func _update_visual() -> void:
	"""Обновить визуальное состояние сердец"""
	# Все сердца полупрозрачные и обычного размера
	heart_player.modulate.a = OPACITY_UNSELECTED
	heart_banker.modulate.a = OPACITY_UNSELECTED
	heart_tie.modulate.a = OPACITY_UNSELECTED
	
	heart_player.scale = SCALE_NORMAL
	heart_banker.scale = SCALE_NORMAL
	heart_tie.scale = SCALE_NORMAL
	
	# Выбранное сердце - непрозрачное и увеличенное
	match selected_target:
		"Player":
			heart_player.modulate.a = OPACITY_SELECTED
			heart_player.scale = SCALE_SELECTED
		"Banker":
			heart_banker.modulate.a = OPACITY_SELECTED
			heart_banker.scale = SCALE_SELECTED
		"Tie":
			heart_tie.modulate.a = OPACITY_SELECTED
			heart_tie.scale = SCALE_SELECTED


func _on_show_ui() -> void:
	"""Показать UI с сердцами"""
	print("❤️ Показываем сердца для ставки")
	selected_target = ""
	_setup_hearts()
	show()
	
	# Принудительно обновляем mouse_filter после показа
	await get_tree().process_frame
	heart_player.mouse_filter = Control.MOUSE_FILTER_STOP
	heart_banker.mouse_filter = Control.MOUSE_FILTER_STOP
	heart_tie.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_hide_ui() -> void:
	"""Скрыть UI с сердцами"""
	print("❤️ Скрываем сердца")
	hide()
	selected_target = ""


func _on_declined() -> void:
	"""Ставка отменена - скрываем всё"""
	hide()
	selected_target = ""


func _on_confirmed(target: String) -> void:
	"""Ставка подтверждена - скрываем не-выбранные сердца, выбранное остаётся"""
	print("❤️ Ставка подтверждена на %s - скрываем остальные сердца" % target)
	
	# Скрываем не-выбранные сердца
	if target != "Player":
		heart_player.visible = false
	if target != "Banker":
		heart_banker.visible = false
	if target != "Tie":
		heart_tie.visible = false
	
	# Выбранное сердце остаётся видимым и непрозрачным
	var selected_btn = _get_heart_button(target)
	if selected_btn:
		selected_btn.visible = true
		selected_btn.modulate.a = OPACITY_SELECTED
		selected_btn.scale = SCALE_SELECTED


func _on_hide_selected() -> void:
	"""Скрыть выбранное сердце (после определения результата Heart Bet)"""
	print("❤️ Скрываем выбранное сердце после результата")
	hide_selected_heart()


## Скрыть выбранное сердце (после определения победителя)
func hide_selected_heart() -> void:
	"""Полностью скрыть выбранное сердце"""
	var selected_btn = _get_heart_button(selected_target)
	if selected_btn:
		selected_btn.visible = false
	hide()
	print("❤️ Выбранное сердце скрыто")


## Проверить, выбрано ли сердце
func is_heart_selected() -> bool:
	return not selected_target.is_empty()


## Получить выбранную цель
func get_selected_target() -> String:
	return selected_target


## Сбросить выбор
func reset() -> void:
	selected_target = ""
	# Показываем все сердца снова
	heart_player.visible = true
	heart_banker.visible = true
	heart_tie.visible = true
	_setup_hearts()
	hide()
