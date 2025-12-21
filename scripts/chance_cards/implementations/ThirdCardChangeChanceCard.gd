# res://scripts/chance_cards/implementations/ThirdCardChangeChanceCard.gd
# Карта шанса для смены третьих карт
# Наследует BaseChanceCard

extends BaseChanceCard

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init():
	card_id = "third_card_change"
	
	# Высокий приоритет — показывается первой (чтобы можно было убрать третьи карты)
	priority = 100
	
	# Загружаем текстуру карты
	if ResourceLoader.exists("res://assets/ui/chance_card/change_3card.png"):
		card_texture = load("res://assets/ui/chance_card/change_3card.png")
	else:
		# Заглушка
		if ResourceLoader.exists("res://assets/ui/heart.png"):
			card_texture = preload("res://assets/ui/heart.png")
		print("⚠️ ThirdCardChangeChanceCard: change_3card.png не найден, используем заглушку")
	
	# Инициализируем счётчик
	count = 0
	
	print("🔄 ThirdCardChangeChanceCard инициализирована")

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕОПРЕДЕЛЕНИЕ ВИРТУАЛЬНЫХ МЕТОДОВ
# ═══════════════════════════════════════════════════════════════════════════

func can_use() -> bool:
	"""Проверка, можно ли использовать карту
	
	Можно использовать когда:
	1. Есть хотя бы одна карта в наличии (count > 0)
	2. На столе есть хотя бы одна третья карта (у игрока или банкира)
	"""
	if count <= 0:
		return false
	
	# Получаем hand_manager через ChanceCardManager → GamePhaseManager
	var phase_manager = ChanceCardManager.phase_manager
	if not phase_manager or not phase_manager.hand_manager:
		return false
	
	# Проверяем есть ли третьи карты на столе
	var hm = phase_manager.hand_manager
	return hm.has_player_third_card() or hm.has_banker_third_card()

func on_use() -> void:
	"""Использовать карту - убрать третьи карты и пересчитать состояние
	
	При использовании:
	1. Убираем ВСЕ третьи карты (и у игрока, и у банкира)
	2. Скрываем их в UI
	3. Возвращаемся к фазе заказа третьих карт
	4. Игрок заново заказывает третьи карты по правилам баккары
	"""
	# Проверяем наличие карт
	if count <= 0:
		push_warning("⚠️ ThirdCardChangeChanceCard.on_use(): нет доступных карт")
		EventBus.show_toast_error.emit(Localization.t("CANNOT_USE_CHANCE"))
		return
	
	# Получаем GamePhaseManager
	var phase_manager = ChanceCardManager.phase_manager
	if not phase_manager:
		push_error("⚠️ ThirdCardChangeChanceCard: GamePhaseManager не найден")
		EventBus.show_toast_error.emit(Localization.t("CANNOT_USE_CHANCE"))
		return
	
	# Убираем третьи карты и пересчитываем состояние
	phase_manager.remove_third_cards_and_recalculate()
	
	print("🔄 ThirdCardChangeChanceCard: карта использована успешно")
	
	# Уменьшаем счётчик через метод базового класса
	# Обновление хранилища произойдет автоматически через ChanceCardManager._on_card_used()
	remove_count(1)

func get_card_name() -> String:
	"""Получить имя карты для локализации"""
	return "THIRD_CARD_CHANGE_CHANCE"

