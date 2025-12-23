# res://scripts/BankerAfterPlayerHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК РЕШЕНИЯ БАНКИРА ПОСЛЕ ИГРОКА
# Обрабатывает логику определения, должен ли банкир взять третью карту
# после того, как игрок взял свою третью карту
# ═══════════════════════════════════════════════════════════════════════════

class_name BankerAfterPlayerHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var hand_manager: HandManager = null
var third_card_validator: ThirdCardActionValidator = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	hand_manager_ref: HandManager = null,
	third_card_validator_ref: ThirdCardActionValidator = null
):
	hand_manager = hand_manager_ref
	third_card_validator = third_card_validator_ref

# ═══════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА НЕОБХОДИМОСТИ РАЗДАЧИ БАНКИРУ
# ═══════════════════════════════════════════════════════════════════════════

func should_banker_draw() -> bool:
	"""Проверить, должен ли банкир взять третью карту
	
	Returns:
		true если банкир должен взять карту, false если нет
	"""
	if not hand_manager:
		return false
	
	return BaccaratRules.banker_should_draw(
		[hand_manager.get_banker_card(0), hand_manager.get_banker_card(1)],
		hand_manager.has_player_third_card(),
		hand_manager.get_player_third_card()
	)

# ═══════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ ВЫБОРА БАНКИРА
# ═══════════════════════════════════════════════════════════════════════════

func get_validation_instructions(banker_third_selected: bool) -> Dictionary:
	"""Получить инструкции для валидации выбора банкира
	
	Args:
		banker_third_selected: Выбрал ли игрок третью карту для банкира
		
	Returns:
		Dictionary с инструкциями:
		{
			"should_validate": bool,  # Нужно ли валидировать
			"validation_result": Dictionary,  # Результат валидации (если should_validate)
			"banker_score": int,  # Очки банкира
			"should_draw": bool,  # Должен ли банкир взять карту
			"should_complete": bool  # Нужно ли завершить игру
		}
	"""
	if not hand_manager or not third_card_validator:
		return {
			"should_validate": false,
			"validation_result": {},
			"banker_score": 0,
			"should_draw": false,
			"should_complete": true
		}
	
	var banker_score = hand_manager.get_banker_initial_score()
	var has_player_third = hand_manager.has_player_third_card()
	var player_third_card = hand_manager.get_player_third_card()
	
	var validation_result = third_card_validator.validate_banker_after_player(
		banker_score, banker_third_selected, has_player_third, player_third_card
	)
	
	var should_draw = should_banker_draw()
	
	return {
		"should_validate": true,
		"validation_result": validation_result,
		"banker_score": banker_score,
		"should_draw": should_draw,
		"should_complete": not should_draw
	}

