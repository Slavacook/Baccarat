# res://scripts/chance_cards/ChanceCardManager.gd
# Менеджер коллекции карт шанса
# Autoload синглтон для управления всеми картами

extends Node

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Словарь зарегистрированных карт по card_id
var cards: Dictionary = {}

## Сцена полного экрана (создаётся динамически)
var fullscreen_scene = null  # BaseChanceCardScene (тип определяется динамически)

## Хранилище карт (находится в сцене Game)
var storage: ChanceCardStorage = null

## GamePhaseManager (передаётся из GameController для доступа к HeartBetManager)
var phase_manager: GamePhaseManager = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	print("🎴 ChanceCardManager инициализирован")
	
	# Загружаем сцену полного экрана (будет создана динамически при первом использовании)
	var scene_path = "res://scenes/chance_cards/BaseChanceCardScene.tscn"
	if ResourceLoader.exists(scene_path):
		print("🎴 BaseChanceCardScene.tscn найден, будет создана при первом использовании")
	else:
		push_error("⚠️ BaseChanceCardScene.tscn не найден: %s" % scene_path)
	
	# Подписываемся на события
	_setup_event_subscriptions()
	
	# Инициализируем карты (Heart Bet и другие)
	_initialize_cards()

# ═══════════════════════════════════════════════════════════════════════════
# ПОДПИСКИ НА СОБЫТИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _setup_event_subscriptions():
	"""Подписка на события EventBus"""
	# Триггеры Heart Bet
	EventBus.heart_bet_trigger_activated.connect(_on_heart_bet_trigger_activated)
	
	# Запросы показа карты
	EventBus.chance_card_fullscreen_requested.connect(_on_fullscreen_requested)
	EventBus.chance_card_storage_clicked.connect(_on_storage_clicked)
	
	# Изменение счётчика шансов
	EventBus.chance_count_changed.connect(_on_chance_count_changed)
	
	print("🎴 ChanceCardManager: подписки на события установлены")

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_cards():
	"""Инициализация всех типов карт"""
	# Heart Bet карта
	var heart_bet_card = load("res://scripts/chance_cards/implementations/HeartBetChanceCard.gd").new()
	register_card(heart_bet_card)
	
	print("🎴 Карты инициализированы")

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Зарегистрировать карту
func register_card(card: BaseChanceCard):
	if not card or card.card_id.is_empty():
		push_error("⚠️ ChanceCardManager: попытка зарегистрировать карту без card_id")
		return
	
	cards[card.card_id] = card
	
	# Подключаем сигналы карты
	card.card_triggered.connect(_on_card_triggered)
	card.card_used.connect(_on_card_used)
	card.card_closed.connect(_on_card_closed)
	
	# Добавляем в хранилище
	if storage:
		storage.add_card_miniature(card)
	
	EventBus.chance_card_registered.emit(card.card_id)
	print("🎴 Карта зарегистрирована: %s" % card.card_id)

## Активировать карту через триггер
func trigger_card(card_id: String):
	if not cards.has(card_id):
		push_warning("⚠️ ChanceCardManager: карта не найдена: %s" % card_id)
		return
	
	var card = cards[card_id] as BaseChanceCard
	# Триггерим только если есть доступные шансы
	if card.count > 0:
		card.trigger()
	# Показываем карту на весь экран ВСЕГДА (даже если count = 0)
	# Это позволяет игроку увидеть карту и понять почему её нельзя использовать
	_show_fullscreen(card)

## Получить карту по ID
func get_card(card_id: String) -> BaseChanceCard:
	return cards.get(card_id) as BaseChanceCard

## Получить все карты
func get_all_cards() -> Array[BaseChanceCard]:
	var result: Array[BaseChanceCard] = []
	for card in cards.values():
		result.append(card as BaseChanceCard)
	return result

## Установить хранилище (вызывается из GameController)
func set_storage(storage_node: ChanceCardStorage):
	storage = storage_node
	# Добавляем все существующие карты в хранилище
	for card in cards.values():
		storage.add_card_miniature(card as BaseChanceCard)
	print("🎴 Хранилище установлено")

## Установить GamePhaseManager (вызывается из GameController)
func set_phase_manager(pm: GamePhaseManager):
	phase_manager = pm
	print("🎴 GamePhaseManager установлен в ChanceCardManager")

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _show_fullscreen(card: BaseChanceCard):
	"""Показать карту на весь экран"""
	# Создаём сцену если её ещё нет
	if not fullscreen_scene:
		var scene_path = "res://scenes/chance_cards/BaseChanceCardScene.tscn"
		if ResourceLoader.exists(scene_path):
			var scene = load(scene_path) as PackedScene
			if scene:
				fullscreen_scene = scene.instantiate()
				# Добавляем в root для отображения поверх всего
				get_tree().root.add_child(fullscreen_scene)
				print("🎴 BaseChanceCardScene создана динамически")
			else:
				push_error("⚠️ Не удалось загрузить BaseChanceCardScene.tscn")
				return
		else:
			push_error("⚠️ BaseChanceCardScene.tscn не найден")
			return
	
	# Получаем позицию хранилища для анимации ухода
	var storage_pos = Vector2.ZERO
	if storage:
		storage_pos = storage.get_storage_position_for_card(card.card_id)
	
	fullscreen_scene.show_fullscreen(card, storage_pos)

func _on_card_triggered(card: BaseChanceCard):
	"""Карта активирована триггером"""
	print("🎴 Карта активирована: %s" % card.card_id)

func _on_card_used(card: BaseChanceCard):
	"""Карта использована"""
	print("🎴 Карта использована: %s" % card.card_id)
	# Счётчик уже уменьшён в HeartBetManager.use_chance()
	# Обновляем хранилище (счётчик обновится через EventBus.chance_count_changed)
	if storage:
		storage.update_card_count(card.card_id, card.count)

func _on_card_closed(card: BaseChanceCard):
	"""Карта закрыта без использования"""
	print("🎴 Карта закрыта: %s" % card.card_id)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_heart_bet_trigger_activated(_trigger_name: String):
	"""Триггер Heart Bet активирован"""
	# ПРОВЕРКА: Если Game Over - не показываем карту
	if not EventBus.is_game_active:
		print("🎴 ChanceCardManager: Game Over, карта не показывается")
		return
	
	trigger_card("heart_bet")

func _on_fullscreen_requested(card_id: String):
	"""Запрос показа карты на весь экран"""
	var card = get_card(card_id)
	if card:
		_show_fullscreen(card)

func _on_storage_clicked(card_id: String):
	"""Клик на миниатюру в хранилище"""
	_on_fullscreen_requested(card_id)

func _on_chance_count_changed(count: int):
	"""Счётчик шансов изменился (для Heart Bet)"""
	var card = get_card("heart_bet")
	if card:
		# Обновляем счётчик карты (без эмита события, чтобы избежать цикла)
		card.count = count
		if storage:
			storage.update_card_count("heart_bet", count)
		print("🎴 Счётчик Heart Bet карты обновлён: %d" % count)
