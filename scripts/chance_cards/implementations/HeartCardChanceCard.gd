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
	"""Проверка, можно ли использовать карту - всегда true если есть карты"""
	# Карта всегда доступна для использования если есть в наличии
	# Кнопка "Использовать" показывается всегда
	return count > 0

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
	if heart_bar.get_lives() >= heart_bar.max_lives:
		print("⚠️ HeartCardChanceCard: достигнут максимум жизней, но карта всё равно используется")
		EventBus.show_toast_info.emit("Максимум жизней!")
	else:
		# Добавляем жизнь только если не на максимуме
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
