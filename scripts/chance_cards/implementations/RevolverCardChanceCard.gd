# res://scripts/chance_cards/implementations/RevolverCardChanceCard.gd
# Карта шанса "Револьвер"
# Наследует BaseChanceCard

extends BaseChanceCard

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init():
	card_id = "revolver_card"
	
	# Загружаем текстуру карты
	if ResourceLoader.exists("res://assets/ui/chance_card/revolver_card.png"):
		card_texture = load("res://assets/ui/chance_card/revolver_card.png")
	else:
		# Заглушка
		if ResourceLoader.exists("res://assets/ui/heart.png"):
			card_texture = preload("res://assets/ui/heart.png")
		print("⚠️ RevolverCardChanceCard: revolver_card.png не найден, используем заглушку")
	
	# Инициализируем счётчик
	count = 0
	
	print("🔫 RevolverCardChanceCard инициализирована")

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕОПРЕДЕЛЕНИЕ ВИРТУАЛЬНЫХ МЕТОДОВ
# ═══════════════════════════════════════════════════════════════════════════

func can_use() -> bool:
	"""Проверка, можно ли использовать карту - всегда true если есть карты"""
	# Карта всегда доступна для использования если есть в наличии
	# Кнопка "Использовать" показывается всегда
	return count > 0

func on_use() -> void:
	"""Использовать карту - эффект револьвера"""
	# Проверяем наличие карт
	if count <= 0:
		push_warning("⚠️ RevolverCardChanceCard.on_use(): нет доступных карт")
		EventBus.show_toast_error.emit(Localization.t("CANNOT_USE_CHANCE"))
		return
	
	# TODO: Логика револьвера будет добавлена позже
	print("🔫 RevolverCardChanceCard: карта использована")
	EventBus.show_toast_info.emit("Револьвер!")
	
	# Уменьшаем счётчик через метод базового класса
	# Обновление хранилища произойдет автоматически через ChanceCardManager._on_card_used()
	remove_count(1)

func get_card_name() -> String:
	"""Получить имя карты для локализации"""
	return "REVOLVER_CARD_CHANCE"

