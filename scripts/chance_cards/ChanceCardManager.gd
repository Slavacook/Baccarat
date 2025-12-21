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

## HeartBar (передаётся из GameController для доступа к жизням)
var heart_bar: HeartBar = null

## Очередь карт для последовательного показа (когда несколько триггеров срабатывают одновременно)
var _card_queue: Array[BaseChanceCard] = []

## Флаг: карта сейчас показывается на экране
var _is_showing_card: bool = false

## Флаг: блокировка очереди (при закрытии через клавиатуру)
var _queue_blocked: bool = false

## Карты, уже показанные в текущем раунде (чтобы не показывать повторно)
var _shown_this_round: Dictionary = {}  # card_id -> true

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
	# Триггеры карт шанса
	EventBus.heart_card_triggered.connect(_on_heart_card_triggered)           # Банкир выиграл с 6
	EventBus.heart_bet_card_triggered.connect(_on_heart_bet_card_triggered)   # Tie (игалите)
	EventBus.mystery_card_triggered.connect(_on_mystery_card_triggered)       # Пара тузов
	EventBus.revolver_card_triggered.connect(_on_revolver_card_triggered)     # Все 6 карт по 0 очков
	EventBus.third_card_change_triggered.connect(_on_third_card_change_triggered)  # Две пары
	
	# Старый триггер Heart Bet (для обратной совместимости)
	EventBus.heart_bet_trigger_activated.connect(_on_heart_bet_trigger_activated)
	
	# Запросы показа карты
	EventBus.chance_card_fullscreen_requested.connect(_on_fullscreen_requested)
	EventBus.chance_card_storage_clicked.connect(_on_storage_clicked)
	
	# Изменение счётчика шансов
	EventBus.chance_count_changed.connect(_on_chance_count_changed)
	
	# Закрытие popup карты - для показа следующей из очереди
	EventBus.chance_card_popup_closed.connect(_on_popup_closed)
	
	print("🎴 ChanceCardManager: подписки на события установлены")

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_cards():
	"""Инициализация всех типов карт"""
	# Heart Bet карта (ставка сердцем)
	var heart_bet_card = load("res://scripts/chance_cards/implementations/HeartBetChanceCard.gd").new()
	register_card(heart_bet_card)
	
	# Heart Card карта (дополнительное сердце)
	var heart_card = load("res://scripts/chance_cards/implementations/HeartCardChanceCard.gd").new()
	register_card(heart_card)
	
	# Third Card Change карта (смена третьих карт)
	var third_card_change = load("res://scripts/chance_cards/implementations/ThirdCardChangeChanceCard.gd").new()
	register_card(third_card_change)
	
	# Revolver карта
	var revolver_card = load("res://scripts/chance_cards/implementations/RevolverCardChanceCard.gd").new()
	register_card(revolver_card)
	
	# Mystery карта (загадочная карта)
	var mystery_card = load("res://scripts/chance_cards/implementations/MysteryCardChanceCard.gd").new()
	register_card(mystery_card)
	
	print("🎴 Карты инициализированы (%d шт.)" % cards.size())

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

## Установить HeartBar (вызывается из GameController)
func set_heart_bar(hb: HeartBar):
	heart_bar = hb
	print("🎴 HeartBar установлен в ChanceCardManager")

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _show_fullscreen(card: BaseChanceCard, force: bool = false):
	"""Показать карту на весь экран (или добавить в очередь)
	
	Args:
		card: Карта для показа
		force: Принудительный показ (из инвентаря), игнорирует проверку "уже показана"
	"""
	# Блокировка очереди активна - игнорируем запрос (закрытие через клавиатуру)
	if _queue_blocked:
		print("🎴 Карта %s игнорируется (очередь заблокирована)" % card.card_id)
		return
	
	# Карта уже показывалась в этом раунде - не показываем повторно (если не force)
	if not force and _shown_this_round.has(card.card_id):
		print("🎴 Карта %s уже показывалась в этом раунде" % card.card_id)
		return
	
	# Если уже показывается карта - добавляем в очередь
	if _is_showing_card:
		_card_queue.append(card)
		print("🎴 Карта %s добавлена в очередь (всего в очереди: %d)" % [card.card_id, _card_queue.size()])
		return
	
	_actually_show_fullscreen(card)

func _actually_show_fullscreen(card: BaseChanceCard):
	"""Фактически показать карту на весь экран"""
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
	
	# Устанавливаем флаг показа
	_is_showing_card = true
	
	# Отмечаем что карта показана в этом раунде
	_shown_this_round[card.card_id] = true
	
	# Получаем позицию хранилища для анимации ухода
	var storage_pos = Vector2.ZERO
	if storage:
		storage_pos = storage.get_storage_position_for_card(card.card_id)
	
	fullscreen_scene.show_fullscreen(card, storage_pos)

func _on_popup_closed():
	"""Popup карты закрыт - показываем следующую из очереди"""
	_is_showing_card = false
	
	# Если очередь заблокирована - сбрасываем и не показываем следующую
	if _queue_blocked:
		_queue_blocked = false
		_card_queue.clear()  # Очищаем очередь
		print("🎴 Очередь разблокирована и очищена")
		return
	
	# Показываем следующую карту из очереди если есть
	if _card_queue.size() > 0:
		var next_card = _card_queue.pop_front()
		print("🎴 Показываем следующую карту из очереди: %s (осталось: %d)" % [next_card.card_id, _card_queue.size()])
		# Небольшая задержка для плавности
		await get_tree().create_timer(0.3).timeout
		_actually_show_fullscreen(next_card)

func _on_card_triggered(card: BaseChanceCard):
	"""Карта активирована триггером"""
	print("🎴 Карта активирована: %s" % card.card_id)

func _on_card_used(card: BaseChanceCard):
	"""Карта использована"""
	print("🎴 Карта использована: %s" % card.card_id)
	# Счётчик уже уменьшён в on_use() карты
	# Обновляем хранилище
	if storage:
		storage.update_card_count(card.card_id, card.count)

func _on_card_closed(card: BaseChanceCard):
	"""Карта закрыта без использования"""
	print("🎴 Карта закрыта: %s" % card.card_id)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ ВНЕШНЕГО ДОСТУПА
# ═══════════════════════════════════════════════════════════════════════════

func is_card_showing() -> bool:
	"""Проверить, открыта ли карта шанса на экране"""
	return _is_showing_card and fullscreen_scene != null and fullscreen_scene.visible


func close_current_card() -> void:
	"""Закрыть текущую открытую карту шанса (если открыта, через клавиатуру)
	
	Блокирует очередь, чтобы карта не показывалась снова после закрытия.
	"""
	if is_card_showing() and fullscreen_scene:
		_queue_blocked = true  # Блокируем очередь до завершения закрытия
		fullscreen_scene.close_card()


func reset_shown_cards() -> void:
	"""Сбросить список показанных карт (вызывается при начале нового раунда)
	
	После сброса карты снова смогут показываться при срабатывании триггеров.
	"""
	_shown_this_round.clear()
	print("🎴 Список показанных карт сброшен (новый раунд)")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ
# ═══════════════════════════════════════════════════════════════════════════

func _on_heart_bet_trigger_activated(_trigger_name: String):
	"""Триггер Heart Bet активирован (старый, для обратной совместимости)"""
	# ПРОВЕРКА: Если Game Over - не показываем карту
	if not EventBus.is_game_active:
		print("🎴 ChanceCardManager: Game Over, карта не показывается")
		return
	
	trigger_card("heart_bet")

func _on_heart_card_triggered():
	"""Триггер Heart Card активирован (победа банкира с 6)"""
	_trigger_chance_card("heart_card", "❤️ Heart Card")

func _on_heart_bet_card_triggered():
	"""Триггер Heart Bet Card активирован (Tie - шанс сыграть на жизнь)"""
	_trigger_chance_card("heart_bet", "🎰 Heart Bet Card")
	
	# ВАЖНО: Синхронизируем счётчик с HeartBetManager
	# (он проверяет свой chance_count в use_chance())
	if phase_manager and phase_manager.heart_bet_manager:
		phase_manager.heart_bet_manager.chance_count += 1
		print("🎰 HeartBetManager.chance_count синхронизирован: %d" % phase_manager.heart_bet_manager.chance_count)

func _on_mystery_card_triggered():
	"""Триггер Mystery Card активирован (пара тузов)"""
	_trigger_chance_card("mystery_card", "❓ Mystery Card")

func _on_revolver_card_triggered():
	"""Триггер Revolver Card активирован (все 6 карт по 0 очков)"""
	_trigger_chance_card("revolver_card", "🔫 Revolver Card")

func _on_third_card_change_triggered():
	"""Триггер Third Card Change активирован (две пары одновременно)"""
	_trigger_chance_card("third_card_change", "🔄 Third Card Change")

func _trigger_chance_card(card_id: String, log_prefix: String):
	"""Универсальный обработчик триггера карты шанса"""
	# ПРОВЕРКА: Если Game Over - не показываем карту
	if not EventBus.is_game_active:
		print("🎴 ChanceCardManager: Game Over, карта не показывается")
		return
	
	var card = get_card(card_id)
	if not card:
		push_warning("⚠️ ChanceCardManager: карта %s не найдена" % card_id)
		return
	
	# Увеличиваем счётчик
	card.count += 1
	print("%s: счётчик увеличен до %d" % [log_prefix, card.count])
	
	# Обновляем хранилище
	if storage:
		storage.update_card_count(card_id, card.count)
	
	# Показываем карту на весь экран
	_show_fullscreen(card)

func _on_fullscreen_requested(card_id: String):
	"""Запрос показа карты на весь экран"""
	var card = get_card(card_id)
	if card:
		_show_fullscreen(card)

func _on_storage_clicked(card_id: String):
	"""Клик на миниатюру в хранилище - показать принудительно (из инвентаря)"""
	var card = get_card(card_id)
	if card:
		_show_fullscreen(card, true)  # force=true - из инвентаря всегда показываем

func _on_chance_count_changed(count: int):
	"""Счётчик шансов изменился (для Heart Bet)"""
	var card = get_card("heart_bet")
	if card:
		# Обновляем счётчик карты (без эмита события, чтобы избежать цикла)
		card.count = count
		if storage:
			storage.update_card_count("heart_bet", count)
		print("🎴 Счётчик Heart Bet карты обновлён: %d" % count)
