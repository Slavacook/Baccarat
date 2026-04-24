# res://scripts/training/TrainingStageManager.gd
# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ РЕГИСТРАЦИЕЙ И ПРОХОЖДЕНИЕМ ЭТАПОВ
# ═══════════════════════════════════════════════════════════════════════════
# Хранит список этапов и отметки о пройденных. Не зависит от UI.
# Следующий этап доступен только после завершения предыдущего (100%).
# ═══════════════════════════════════════════════════════════════════════════

class_name TrainingStageManager
extends RefCounted

## Зарегистрированные этапы (порядок = последовательность прохождения)
var registered_stages: Array[TrainingStageBase] = []

## stage_id этапов, которые уже пройдены (прогресс 100%)
var completed_stages: Array[String] = []

# ═══════════════════════════════════════════════════════════════════════════
# РЕГИСТРАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func register_stage(stage: TrainingStageBase) -> void:
	registered_stages.append(stage)

# ═══════════════════════════════════════════════════════════════════════════
# ПОИСК И СТАТУС
# ═══════════════════════════════════════════════════════════════════════════

func get_stage_by_id(stage_id: String) -> TrainingStageBase:
	for stage in registered_stages:
		if stage.stage_id == stage_id:
			return stage
	return null

func is_stage_completed(stage_id: String) -> bool:
	return stage_id in completed_stages

## Отметить этап как пройденный (вызывать при достижении 100% прогресса).
func mark_stage_completed(stage_id: String) -> void:
	if stage_id in completed_stages:
		return
	completed_stages.append(stage_id)

## Индекс первого непройденного этапа. -1 если все пройдены.
func get_next_available_stage_index() -> int:
	for i in range(registered_stages.size()):
		if not is_stage_completed(registered_stages[i].stage_id):
			return i
	return -1

## Количество зарегистрированных этапов
func get_stage_count() -> int:
	return registered_stages.size()

## Можно ли выбрать этап для повторного прохождения (уже пройден).
func can_replay_stage(stage_id: String) -> bool:
	return is_stage_completed(stage_id)
