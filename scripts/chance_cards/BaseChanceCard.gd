# res://scripts/chance_cards/BaseChanceCard.gd
# Базовый абстрактный класс для карт шанса
# Наследуйте этот класс для создания новых типов карт

class_name BaseChanceCard
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

## Карта активирована триггером
signal card_triggered(card: BaseChanceCard)

## Карта использована
@warning_ignore("unused_signal")
signal card_used(card: BaseChanceCard)

## Карта закрыта без использования
@warning_ignore("unused_signal")
signal card_closed(card: BaseChanceCard)

# ═══════════════════════════════════════════════════════════════════════════
# СВОЙСТВА
# ═══════════════════════════════════════════════════════════════════════════

## Уникальный идентификатор карты
var card_id: String

## Текстура карты
var card_texture: Texture2D

## Количество карт этого типа
var count: int = 0

# ═══════════════════════════════════════════════════════════════════════════
# ВИРТУАЛЬНЫЕ МЕТОДЫ (должны быть переопределены в наследниках)
# ═══════════════════════════════════════════════════════════════════════════

## Проверить, можно ли использовать карту
func can_use() -> bool:
	assert(false, "BaseChanceCard.can_use() must be overridden")
	return false

## Использовать карту (вызывается при нажатии "Использовать")
func on_use() -> void:
	assert(false, "BaseChanceCard.on_use() must be overridden")

## Получить имя карты (для локализации)
func get_card_name() -> String:
	assert(false, "BaseChanceCard.get_card_name() must be overridden")
	return ""

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Увеличить количество карт
func add_count(amount: int = 1) -> void:
	count += amount
	_update_ui()

## Уменьшить количество карт
func remove_count(amount: int = 1) -> void:
	count = max(0, count - amount)
	_update_ui()

## Установить количество карт
func set_count(new_count: int) -> void:
	count = max(0, new_count)
	_update_ui()

## Активировать карту через триггер
func trigger() -> void:
	if count > 0:
		card_triggered.emit(self)
		EventBus.chance_card_triggered.emit(card_id)

## Обновить UI (вызывается при изменении count)
## ВАЖНО: не вызывать напрямую для Heart Bet - счётчик обновляется через EventBus.chance_count_changed
func _update_ui() -> void:
	# Для других типов карт можно эмитить событие
	# EventBus.chance_count_changed.emit(count)
	pass
