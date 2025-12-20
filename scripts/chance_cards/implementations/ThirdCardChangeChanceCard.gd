# res://scripts/chance_cards/implementations/ThirdCardChangeChanceCard.gd
# Карта шанса для смены третьих карт
# Наследует BaseChanceCard

extends BaseChanceCard

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init():
	card_id = "third_card_change"
	
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
	"""Проверка, можно ли использовать карту - всегда true если есть карты"""
	# Карта всегда доступна для использования если есть в наличии
	# Кнопка "Использовать" показывается всегда
	return count > 0

func on_use() -> void:
	"""Использовать карту - сменить третьи карты"""
	# Проверяем наличие карт
	if count <= 0:
		push_warning("⚠️ ThirdCardChangeChanceCard.on_use(): нет доступных карт")
		EventBus.show_toast_error.emit(Localization.t("CANNOT_USE_CHANCE"))
		return
	
	# TODO: Логика смены третьих карт будет добавлена позже
	print("🔄 ThirdCardChangeChanceCard: карта использована")
	EventBus.show_toast_info.emit("Смена третьих карт!")
	
	# Уменьшаем счётчик через метод базового класса
	# Обновление хранилища произойдет автоматически через ChanceCardManager._on_card_used()
	remove_count(1)

func get_card_name() -> String:
	"""Получить имя карты для локализации"""
	return "THIRD_CARD_CHANGE_CHANCE"

