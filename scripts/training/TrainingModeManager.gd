# res://scripts/training/TrainingModeManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# ГЛАВНЫЙ КООРДИНАТОР РЕЖИМА ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════
# Управляет этапами, прогрессом и проверкой ответов. Не содержит UI-логику —
# только состояние и сигналы. Показ/скрытие элементов делает GameController.
# ═══════════════════════════════════════════════════════════════════════════

class_name TrainingModeManager
extends Node

# ═══════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ
# ═══════════════════════════════════════════════════════════════════════════

## Текущий активный этап
var current_stage: TrainingStageBase = null

## Индекс текущего этапа в списке stages
var current_stage_index: int = -1

## Все зарегистрированные этапы (порядок важен)
var stages: Array[TrainingStageBase] = []

## Прогресс по этапам: stage_id -> 0.0..1.0 (только в памяти на сессию)
var stage_progress: Dictionary = {}

## Сценарий текущего раунда (карты, которые показаны). Используется при проверке ответа.
var current_scenario: Dictionary = {}

## Сид следующего раунда live (из WS); применяется перед новым сценарием, чтобы не ломать текущий ответ.
var _pending_live_deck_reseed_hex: String = ""

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

var deck: Deck
var card_manager: CardTextureManager
var ui_manager: UIManager

# ═══════════════════════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════════════════

## Этап начат (можно показывать инструкцию и карты)
signal stage_started(stage_id: String)

## Этап завершён (прогресс достиг 100%)
signal stage_completed(stage_id: String)

## Прогресс этапа изменился
signal progress_changed(stage_id: String, progress: float)

## Режим обучения включён
signal training_mode_activated()

## Режим обучения выключен
signal training_mode_deactivated()

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР
# ═══════════════════════════════════════════════════════════════════════════

func _init(deck_ref: Deck, card_manager_ref: CardTextureManager, ui_manager_ref: UIManager) -> void:
	deck = deck_ref
	card_manager = card_manager_ref
	ui_manager = ui_manager_ref

# ═══════════════════════════════════════════════════════════════════════════
# АКТИВАЦИЯ / ДЕАКТИВАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func queue_deck_reseed_from_server(seed_hex: String) -> void:
	var h: String = seed_hex.strip_edges()
	if h.is_empty():
		return
	_pending_live_deck_reseed_hex = h


func _apply_pending_deck_reseed() -> void:
	if deck == null:
		return
	var h: String = _pending_live_deck_reseed_hex.strip_edges()
	if h.is_empty():
		return
	deck.reseed_from_hex(h)
	_pending_live_deck_reseed_hex = ""


func activate_training_mode() -> void:
	training_mode_activated.emit()

func deactivate_training_mode() -> void:
	training_mode_deactivated.emit()

# ═══════════════════════════════════════════════════════════════════════════
# ЭТАПЫ И РАУНДЫ
# ═══════════════════════════════════════════════════════════════════════════

func start_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= stages.size():
		return
	current_stage_index = stage_index
	current_stage = stages[stage_index]
	current_scenario = {}
	if not stage_progress.has(current_stage.stage_id):
		stage_progress[current_stage.stage_id] = 0.0
	stage_started.emit(current_stage.stage_id)

## Генерирует сценарий для текущего этапа, сохраняет в current_scenario и возвращает его.
## Вызывать один раз на раунд перед показом карт; process_answer использует сохранённый сценарий.
func generate_current_scenario() -> Dictionary:
	if current_stage == null:
		return {}
	_apply_pending_deck_reseed()
	current_scenario = current_stage.generate_scenario()
	return current_scenario

## Обрабатывает ответ пользователя по сохранённому current_scenario.
## Returns: { is_correct: bool, explanation: String, progress_delta: float, current_progress: float }
func process_answer(user_answer: Variant) -> Dictionary:
	if current_stage == null:
		return {}
	if current_scenario.is_empty():
		return {}
	var is_correct: bool = current_stage.validate_answer(user_answer, current_scenario)
	var explanation: String = current_stage.get_explanation(user_answer, current_scenario, is_correct)
	var progress_delta: float = 0.05 if is_correct else -0.20
	var prev: float = stage_progress.get(current_stage.stage_id, 0.0)
	var new_progress: float = clamp(prev + progress_delta, 0.0, 1.0)
	stage_progress[current_stage.stage_id] = new_progress
	progress_changed.emit(current_stage.stage_id, new_progress)
	if new_progress >= 1.0:
		stage_completed.emit(current_stage.stage_id)
	return {
		"is_correct": is_correct,
		"explanation": explanation,
		"progress_delta": progress_delta,
		"current_progress": new_progress
	}

## Прогресс текущего этапа (0.0–1.0)
func get_current_progress() -> float:
	if current_stage == null:
		return 0.0
	return stage_progress.get(current_stage.stage_id, 0.0)

## Пройден ли текущий этап (100%)
func is_current_stage_complete() -> bool:
	return get_current_progress() >= 1.0

## Количество этапов
func get_stage_count() -> int:
	return stages.size()

## Есть ли следующий этап после текущего
func has_next_stage() -> bool:
	return current_stage_index >= 0 and current_stage_index + 1 < stages.size()

## Индекс следующего этапа или -1
func get_next_stage_index() -> int:
	if not has_next_stage():
		return -1
	return current_stage_index + 1
