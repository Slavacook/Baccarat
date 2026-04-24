# res://scripts/training/stages/NaturalWinStage.gd
# ═══════════════════════════════════════════════════════════════════════════
# ЭТАП 0: НАТУРАЛЬНАЯ ПОБЕДА (8–9 ОЧКОВ)
# ═══════════════════════════════════════════════════════════════════════════
# Правило: при 8 или 9 очков у игрока или банкира на первых двух картах
# третья карта никому не нужна. Вопрос: «Нужна ли третья карта?» → Нет.
# ═══════════════════════════════════════════════════════════════════════════

class_name NaturalWinStage
extends TrainingStageBase

var card_generator: TrainingCardGenerator

func _init(gen: TrainingCardGenerator) -> void:
	card_generator = gen
	stage_id = "natural_win"
	stage_name = "Натуральная победа"
	difficulty_level = 0
	instruction_text = "Если у игрока или банкира 8-9 очков на первых двух картах - это натуральная победа, третья карта никому не нужна"
	question_type = "binary"
	question_text = "Нужна ли третья карта?"

# ═══════════════════════════════════════════════════════════════════════════
# РЕАЛИЗАЦИЯ АБСТРАКТНЫХ МЕТОДОВ
# ═══════════════════════════════════════════════════════════════════════════

func generate_scenario() -> Dictionary:
	var scenario: Dictionary = card_generator.generate_natural_win()
	scenario["expected_answer"] = "no"
	return scenario

func validate_answer(user_answer: Variant, _scenario: Dictionary) -> bool:
	var answer: String = str(user_answer)
	return answer == "no" or answer == "Нет"

func get_answer_options(_scenario: Dictionary) -> Array:
	return ["Да", "Нет"]

func get_explanation(user_answer: Variant, _scenario: Dictionary, is_correct: bool) -> String:
	if is_correct:
		return "Верно! При натуральной победе (8-9 очков) третья карта не нужна."
	var chosen: String = str(user_answer)
	return "Ошибка! Вы выбрали «%s», но при натуральной победе (8-9 очков) третья карта не нужна." % chosen
