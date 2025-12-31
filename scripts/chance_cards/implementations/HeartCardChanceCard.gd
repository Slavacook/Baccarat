# res://scripts/chance_cards/implementations/HeartCardChanceCard.gd
# Карта шанса для получения дополнительного сердца
# Наследует BaseChanceCard и реализует логику добавления жизни

extends BaseChanceCard

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init():
	card_id = "heart_card"
	
	# Загружаем текстуру карты
	if ResourceLoader.exists("res://assets/ui/chance_card/heart_card.png"):
		card_texture = load("res://assets/ui/chance_card/heart_card.png")
	else:
		# Заглушка
		if ResourceLoader.exists("res://assets/ui/heart_focus.png"):
			card_texture = load("res://assets/ui/heart_focus.png")
		else:
			card_texture = preload("res://assets/ui/heart.png")
		print("⚠️ HeartCardChanceCard: heart_card.png не найден, используем заглушку")
	
	# Инициализируем счётчик
	count = 0
	
	print("❤️ HeartCardChanceCard инициализирована")

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕОПРЕДЕЛЕНИЕ ВИРТУАЛЬНЫХ МЕТОДОВ
# ═══════════════════════════════════════════════════════════════════════════

func can_use() -> bool:
	"""Проверка, можно ли использовать карту - проверяем наличие карт и максимум жизней"""
	# Проверяем наличие карт
	if count <= 0:
		return false
	
	# Получаем HeartBar через ChanceCardManager
	var heart_bar = _get_heart_bar()
	if not heart_bar:
		return false
	
	# Проверяем, не достигнут ли максимум жизней
	# Если жизни на максимуме - карту нельзя использовать
	if heart_bar.get_lives() >= heart_bar.max_lives:
		return false
	
	return true

func on_use() -> void:
	"""Использовать карту - добавить +1 жизнь"""
	# Проверяем наличие карт
	if count <= 0:
		push_warning("⚠️ HeartCardChanceCard.on_use(): нет доступных карт")
		EventBus.show_toast_error.emit(Localization.t("CANNOT_USE_CHANCE"))
		return
	
	# Получаем HeartBar через ChanceCardManager
	var heart_bar = _get_heart_bar()
	if not heart_bar:
		push_error("⚠️ HeartCardChanceCard: HeartBar не найден")
		EventBus.show_toast_error.emit(Localization.t("CANNOT_USE_CHANCE"))
		return
	
	# Проверяем, не достигнут ли максимум жизней
	# Эта проверка уже выполнена в can_use(), но на всякий случай проверяем ещё раз
	if heart_bar.get_lives() >= heart_bar.max_lives:
		print("⚠️ HeartCardChanceCard: достигнут максимум жизней, карта не может быть использована")
		EventBus.show_toast_error.emit("Максимум жизней!")
		return  # Не используем карту и не уменьшаем счётчик
	
	# Добавляем жизнь
	heart_bar.add_life(1)
	print("❤️ HeartCardChanceCard: добавлена 1 жизнь")
	
	# Уменьшаем счётчик через метод базового класса
	# Обновление хранилища произойдет автоматически через ChanceCardManager._on_card_used()
	remove_count(1)

func get_card_name() -> String:
	"""Получить имя карты для локализации"""
	return "HEART_CARD_CHANCE"

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _get_heart_bar():
	"""Получить HeartBar через ChanceCardManager"""
	return ChanceCardManager.heart_bar
