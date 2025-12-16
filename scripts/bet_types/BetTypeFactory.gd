# res://scripts/bet_types/BetTypeFactory.gd
# Фабрика для создания типов ставок (Factory Pattern + OCP)

class_name BetTypeFactory
extends RefCounted

## Создать объект типа ставки по строковому имени
static func create(bet_type_name: String) -> IBetType:
	match bet_type_name:
		"Player":
			return MainBetType.new("Player")
		"Banker":
			return MainBetType.new("Banker")
		"Tie":
			return TieBetType.new()
		"PairPlayer":
			return PairBetType.new("PairPlayer")
		"PairBanker":
			return PairBetType.new("PairBanker")
		_:
			push_error("Неизвестный тип ставки: %s" % bet_type_name)
			return null

## Получить все доступные типы ставок
static func get_all_types() -> Array[String]:
	return ["Player", "Banker", "Tie", "PairPlayer", "PairBanker"]

## Получить типы ставок по группе
static func get_types_by_group(group: String) -> Array[String]:
	match group:
		"main":
			return ["Player", "Banker"]
		"tie":
			return ["Tie"]
		"pairs":
			return ["PairPlayer", "PairBanker"]
		_:
			return []

