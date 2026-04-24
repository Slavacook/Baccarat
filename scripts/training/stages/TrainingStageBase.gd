# res://scripts/training/stages/TrainingStageBase.gd
# ═══════════════════════════════════════════════════════════════════════════
# БАЗОВЫЙ КЛАСС ЭТАПА ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════
# Используется Strategy Pattern: каждый этап — отдельный класс, наследник
# этого базового. Добавление нового этапа = новый класс без изменения ядра.
#
# Дочерние классы обязаны реализовать:
#   - generate_scenario()  — генерация карт и правильного ответа
#   - validate_answer()    — проверка ответа пользователя
#   - get_answer_options() — варианты ответов для UI
#   - get_explanation()    — текст обратной связи (верно/ошибка)
# ═══════════════════════════════════════════════════════════════════════════

class_name TrainingStageBase
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# СВОЙСТВА ЭТАПА
# ═══════════════════════════════════════════════════════════════════════════

## Уникальный идентификатор этапа (например "natural_win")
var stage_id: String = ""

## Отображаемое название этапа
var stage_name: String = ""

## Уровень сложности: 0 — простое правило, 1–3 — нарастающая сложность
var difficulty_level: int = 0

## Текст инструкции, показываемый перед началом этапа
var instruction_text: String = ""

## Тип вопроса для UI: "binary" (Да/Нет), "action_choice" (3 варианта), "double_binary" (2 вопроса)
var question_type: String = "binary"

## Текст вопроса в попапе (например «Нужна ли третья карта?»)
var question_text: String = ""

# ═══════════════════════════════════════════════════════════════════════════
# АБСТРАКТНЫЕ МЕТОДЫ (должны быть переопределены в дочерних классах)
# ═══════════════════════════════════════════════════════════════════════════

## Генерирует сценарий для этапа: карты и правильный ответ.
## Returns: Dictionary с ключами player_hand, banker_hand, expected_answer и др. по необходимости
func generate_scenario() -> Dictionary:
	push_error("TrainingStageBase.generate_scenario() должен быть переопределен в %s" % stage_id)
	return {}

## Проверяет правильность ответа пользователя.
## user_answer — значение, выбранное пользователем (строка или тип по этапу).
## scenario — сценарий, возвращённый generate_scenario().
## Returns: true если ответ верный, иначе false
func validate_answer(_user_answer: Variant, _scenario: Dictionary) -> bool:
	push_error("TrainingStageBase.validate_answer() должен быть переопределен в %s" % stage_id)
	return false

## Возвращает варианты ответов для отображения в UI (кнопки и т.п.).
## scenario — текущий сценарий (можно использовать для подсказок в вариантах).
## Returns: Array строк, например ["Да", "Нет"] или ["Карта игроку", "Карта банкиру", "Карта каждому"]
func get_answer_options(_scenario: Dictionary) -> Array:
	push_error("TrainingStageBase.get_answer_options() должен быть переопределен в %s" % stage_id)
	return []

## Формирует текст объяснения после ответа.
## user_answer — ответ пользователя; scenario — сценарий; is_correct — результат проверки.
## Returns: строка для показа в попапе (верно/ошибка + пояснение)
func get_explanation(_user_answer: Variant, _scenario: Dictionary, _is_correct: bool) -> String:
	push_error("TrainingStageBase.get_explanation() должен быть переопределен в %s" % stage_id)
	return ""
