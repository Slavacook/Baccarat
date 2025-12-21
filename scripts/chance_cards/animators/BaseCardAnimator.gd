# res://scripts/chance_cards/animators/BaseCardAnimator.gd
# Базовый абстрактный класс для анимации карт шанса
# Наследуйте этот класс для создания новых типов анимаций

class_name BaseCardAnimator
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ
# ═══════════════════════════════════════════════════════════════════════════

## Длительность анимации открытия (секунды)
const OPEN_DURATION: float = 0.4

## Длительность анимации закрытия (секунды)
const CLOSE_DURATION: float = 0.2

## Длительность анимации фона (секунды)
const BACKGROUND_FADE_DURATION: float = 0.3

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ ДЛЯ СОХРАНЕНИЯ СОСТОЯНИЯ
# ═══════════════════════════════════════════════════════════════════════════

## Целевой масштаб карты (куда анимировать)
var target_scale: Vector2 = Vector2.ONE

## Целевая прозрачность карты
var target_modulate: Color = Color.WHITE

## Целевая прозрачность фона
var target_bg_modulate: Color = Color.WHITE

## Позиция хранилища (для анимации к/от хранилища)
var storage_pos: Vector2 = Vector2.ZERO

## Текущий tween для фона (чтобы можно было остановить при конфликте)
var _current_bg_tween: Tween = null

# ═══════════════════════════════════════════════════════════════════════════
# ВИРТУАЛЬНЫЕ МЕТОДЫ (должны быть переопределены в наследниках)
# ═══════════════════════════════════════════════════════════════════════════

## Подготовить карту и фон к анимации открытия
## Устанавливает начальное состояние (невидимое/маленькое)
func prepare_for_open(card_texture: TextureRect, background: ColorRect) -> void:
	assert(false, "BaseCardAnimator.prepare_for_open() must be overridden")
	# Заглушка для предупреждения компилятора
	if card_texture or background:
		pass

## Анимировать открытие карты
## card_texture: TextureRect карты
## background: ColorRect фона
func animate_open(card_texture: TextureRect, background: ColorRect) -> void:
	assert(false, "BaseCardAnimator.animate_open() must be overridden")
	if card_texture or background:
		pass

## Анимировать закрытие карты
## card_texture: TextureRect карты
## background: ColorRect фона
## on_complete: Callable для вызова после завершения анимации
func animate_close(card_texture: TextureRect, background: ColorRect, on_complete: Callable = Callable()) -> void:
	assert(false, "BaseCardAnimator.animate_close() must be overridden")
	if card_texture or background or on_complete.is_valid():
		pass

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Установить целевые значения анимации
func set_targets(scale: Vector2, modulate: Color, bg_modulate: Color) -> BaseCardAnimator:
	target_scale = scale
	target_modulate = modulate
	target_bg_modulate = bg_modulate
	return self  # Для цепочки вызовов

## Установить позицию хранилища
func set_storage_position(pos: Vector2) -> BaseCardAnimator:
	storage_pos = pos
	return self  # Для цепочки вызовов

# ═══════════════════════════════════════════════════════════════════════════
# ЗАЩИЩЁННЫЕ HELPER-МЕТОДЫ (для использования в наследниках)
# ═══════════════════════════════════════════════════════════════════════════

## Установить pivot_offset в центр карты для масштабирования из центра
func _setup_pivot(card_texture: TextureRect) -> void:
	var card_size = card_texture.size
	if card_size == Vector2.ZERO:
		# Если размер ещё не установлен, вычисляем из offset
		var width = card_texture.offset_right - card_texture.offset_left
		var height = card_texture.offset_bottom - card_texture.offset_top
		card_texture.pivot_offset = Vector2(width / 2.0, height / 2.0)
	else:
		card_texture.pivot_offset = card_size / 2.0

## Создать и настроить Tween для карты
func _create_tween(card_texture: TextureRect) -> Tween:
	var tween = card_texture.get_tree().create_tween()
	tween.set_parallel(true)
	return tween

## Анимировать появление фона
## ВАЖНО: Убиваем предыдущий tween чтобы избежать конфликтов
func _animate_background_in(background: ColorRect) -> Tween:
	# Останавливаем предыдущий tween если есть (избегаем конфликта двух tween на одно свойство)
	if _current_bg_tween and _current_bg_tween.is_valid():
		_current_bg_tween.kill()
	
	_current_bg_tween = background.get_tree().create_tween()
	_current_bg_tween.tween_property(background, "modulate:a", target_bg_modulate.a, BACKGROUND_FADE_DURATION)
	return _current_bg_tween

## Анимировать исчезновение фона
## ВАЖНО: Убиваем предыдущий tween чтобы избежать конфликтов
func _animate_background_out(background: ColorRect, duration: float = -1.0) -> Tween:
	# Останавливаем предыдущий tween если есть
	if _current_bg_tween and _current_bg_tween.is_valid():
		_current_bg_tween.kill()
	
	if duration < 0:
		duration = CLOSE_DURATION * 0.8
	_current_bg_tween = background.get_tree().create_tween()
	_current_bg_tween.tween_property(background, "modulate:a", 0.0, duration)
	return _current_bg_tween

## Подключить callback к завершению Tween
func _connect_on_complete(tween: Tween, on_complete: Callable) -> void:
	if on_complete.is_valid():
		var callback_func = func():
			if on_complete.is_valid():
				on_complete.call()
		tween.finished.connect(callback_func, CONNECT_ONE_SHOT)

