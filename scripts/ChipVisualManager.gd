# res://scripts/ChipVisualManager.gd
# Менеджер визуальных фишек на игровом поле

class_name ChipVisualManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ - ТЕКСТУРЫ ФИШЕК (делегировано в ChipTextureManager)
# ═══════════════════════════════════════════════════════════════════════════

# Для обратной совместимости
const CHIP_TEXTURES = ChipTextureManager.CHIP_TEXTURES

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ - АЛЬТЕРНАТИВНЫЕ ПОЗИЦИИ ФИШЕК (делегировано в ChipPositionManager)
# ═══════════════════════════════════════════════════════════════════════════

# Для обратной совместимости (используется в других классах)
const ALTERNATIVE_POSITIONS = ChipPositionManager.ALTERNATIVE_POSITIONS

# ═══════════════════════════════════════════════════════════════════════════
# КЛАСС CHIPINSTANCE - ДАННЫЕ ОБ ИНДИВИДУАЛЬНОЙ ФИШКЕ
# ═══════════════════════════════════════════════════════════════════════════

class ChipInstance:
	var bet_type: String        # "Player", "Banker", etc.
	var position_index: int     # Индекс позиции (0, 1, 2...)
	var node: TextureButton     # UI узел
	var stake: float            # Размер ставки
	var is_collected: bool      # Собрана ли (для проигрышных)
	var is_paid: bool           # Оплачена ли (для выигрышных)
	var is_original: bool       # Основная фишка (из сцены) или копия
	var stake_label: Control    # Label для отображения суммы ставки
	
	func _init(type: String, idx: int, chip_node: TextureButton, is_orig: bool = false):
		bet_type = type
		position_index = idx
		node = chip_node
		stake = 0.0
		is_collected = false
		is_paid = false
		is_original = is_orig
		stake_label = null
	
	func get_id() -> String:
		"""Уникальный идентификатор фишки"""
		return "%s_%d" % [bet_type, position_index]

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ - ВЕРОЯТНОСТИ ДЛЯ REALISTIC РЕЖИМА (делегировано в RealisticChipGenerator)
# ═══════════════════════════════════════════════════════════════════════════

# Для обратной совместимости
const PROBABILITY_WEIGHTS = RealisticChipGenerator.PROBABILITY_WEIGHTS
const RANGES_6 = RealisticChipGenerator.RANGES_6

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Словарь узлов фишек: {"Player": TextureButton, "Banker": TextureButton, ...}
var chip_nodes: Dictionary = {}

# Менеджер текстур фишек
var texture_manager: ChipTextureManager = ChipTextureManager.new()

# Менеджер позиций фишек
var position_manager: ChipPositionManager = ChipPositionManager.new()

# Менеджер меток суммы ставки
var stake_label_manager: StakeLabelManager = StakeLabelManager.new()

# Генератор реалистичных фишек
var realistic_generator: RealisticChipGenerator = RealisticChipGenerator.new()

# Свойство для обратной совместимости (делегирует в texture_manager)
var current_textures: Dictionary:
	get: return texture_manager.current_textures

# Основные позиции фишек (сохраняются при setup из сцены)
var default_positions: Dictionary = {}

# Режим позиций: GUEST (гости ставят в своих секторах)
enum PositionMode { GUEST }
var current_mode: PositionMode = PositionMode.GUEST

# Для обратной совместимости (deprecated, всегда false)
var random_positions_enabled: bool:
	get:
		return false

# Дополнительные фишки для MAX режима (копии) - устаревшее, используется для совместимости
# {"Player": [TextureButton, TextureButton, ...], ...}
var extra_chips: Dictionary = {}

# ВСЕ активные фишки (для MAX и REALISTIC режимов)
# Список всех ChipInstance
var active_chips: Array[ChipInstance] = []

# Родительский узел для добавления копий фишек
var scene_root: Node = null

# Сигналы для обработки кликов
signal chip_clicked(bet_type: String)
# Новый сигнал с идентификатором конкретной фишки
signal chip_instance_clicked(bet_type: String, position_index: int)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func setup(player_chip: TextureButton, banker_chip: TextureButton, tie_chip: TextureButton,
		   pair_player_chip: TextureButton = null, pair_banker_chip: TextureButton = null,
		   root_node: Node = null) -> void:
	"""Настройка ссылок на узлы фишек
	
	Инициализирует менеджер, сохраняет ссылки на узлы фишек из сцены,
	сохраняет начальные позиции и скрывает все фишки при старте.
	
	Args:
		player_chip: Узел фишки Player
		banker_chip: Узел фишки Banker
		tie_chip: Узел фишки Tie
		pair_player_chip: Узел фишки PairPlayer (опционально)
		pair_banker_chip: Узел фишки PairBanker (опционально)
		root_node: Корневой узел сцены для создания копий фишек (опционально)
	"""
	chip_nodes["Player"] = player_chip
	chip_nodes["Banker"] = banker_chip
	chip_nodes["Tie"] = tie_chip

	if pair_player_chip:
		chip_nodes["PairPlayer"] = pair_player_chip
	if pair_banker_chip:
		chip_nodes["PairBanker"] = pair_banker_chip

	# Сохраняем родительский узел для создания копий в MAX режиме
	if root_node:
		scene_root = root_node
	elif player_chip:
		scene_root = player_chip.get_parent()

	# Сохраняем начальные позиции фишек (из сцены)
	_save_default_positions()
	
	# Инициализируем словарь для дополнительных фишек
	for bet_type in chip_nodes.keys():
		extra_chips[bet_type] = []

	# Скрываем все фишки при старте
	for chip in chip_nodes.values():
		chip.visible = false
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.focus_mode = Control.FOCUS_NONE  # Отключаем фокус чтобы Space не активировал фишки

	print("✅ ChipVisualManager: настроено %d фишек" % chip_nodes.size())


func _save_default_positions() -> void:
	"""Сохранить начальные позиции фишек из сцены"""
	for bet_type in chip_nodes.keys():
		var chip = chip_nodes[bet_type]
		default_positions[bet_type] = Vector2(chip.position.x, chip.position.y)
	print("📍 Сохранены позиции фишек: %s" % default_positions)


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ВИДИМОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func show_chip(bet_type: String) -> void:
	"""Показать фишку с текстурой и позицией
	
	В режиме GUEST:
	- Фишки гостей создаются через _show_guest_bets() на правильных позициях
	- Этот метод только устанавливает текстуру для оригинальной фишки (шаблона)
	- Оригинальная фишка НЕ показывается на дефолтной позиции (чтобы не конфликтовать с фабрикой ставок)
	
	В других режимах (если будут):
	- Показывает фишку на дефолтной позиции
	"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	var chip = chip_nodes[bet_type]
	
	# Случайная текстура
	var texture_path = texture_manager.get_random_texture(bet_type)
	if texture_path.is_empty():
		push_error("ChipVisualManager: нет текстур для типа '%s'" % bet_type)
		return

	# Загружаем текстуру
	var texture = load(texture_path)
	if not texture:
		push_error("ChipVisualManager: не удалось загрузить текстуру '%s'" % texture_path)
		return

	# Устанавливаем текстуру (нужна для создания копий)
	chip.texture_normal = texture
	texture_manager.set_current_texture(bet_type, texture_path)

	# В режиме GUEST: НЕ показываем оригинальную фишку на дефолтной позиции
	# Фишки гостей создаются через _show_guest_bets() на правильных позициях
	if current_mode == PositionMode.GUEST:
		# Только устанавливаем текстуру, НЕ показываем фишку
		chip.visible = false
		_remove_extra_chips(bet_type)
		print("💰 ChipVisualManager: установлена текстура для %s (%s) mode=GUEST (фишка скрыта)" % [bet_type, texture_path.get_file()])
	else:
		# В других режимах (если будут) - показываем на дефолтной позиции
		chip.visible = true
		_reset_to_default_position(bet_type)
		_remove_extra_chips(bet_type)
		print("💰 ChipVisualManager: показана фишка %s (%s)" % [bet_type, texture_path.get_file()])


func set_chip_texture(bet_type: String, texture_path: String) -> void:
	"""Установить конкретную текстуру фишки (без рандомизации)"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	if texture_path.is_empty():
		push_warning("ChipVisualManager: пустой путь к текстуре для %s, используем рандомную" % bet_type)
		show_chip(bet_type)
		return

	var chip = chip_nodes[bet_type]
	var texture = load(texture_path)
	if not texture:
		push_error("ChipVisualManager: не удалось загрузить текстуру '%s'" % texture_path)
		return

	chip.texture_normal = texture
	chip.visible = true
	texture_manager.set_current_texture(bet_type, texture_path)

	print("💰 ChipVisualManager: установлена текстура фишки %s (%s)" % [bet_type, texture_path.get_file()])


func make_chip_visible(bet_type: String) -> void:
	"""Просто показать фишку БЕЗ изменения текстуры"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	# Проверяем что узел существует и не удалён
	if chip_nodes[bet_type] and is_instance_valid(chip_nodes[bet_type]):
		chip_nodes[bet_type].visible = true
		print("👁️ ChipVisualManager: фишка %s сделана видимой" % bet_type)
	else:
		print("⚠️ ChipVisualManager: узел %s уже удалён" % bet_type)


func hide_chip(bet_type: String) -> void:
	"""Скрыть фишку и удалить копии"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	# Проверяем что узел существует и не удалён
	if chip_nodes[bet_type] and is_instance_valid(chip_nodes[bet_type]):
		chip_nodes[bet_type].visible = false
	else:
		print("⚠️ ChipVisualManager: узел %s уже удалён" % bet_type)
		return
	# НЕ стираем current_textures - сохраняем текстуру для восстановления
	
	# Удаляем дополнительные фишки (если были в MAX режиме)
	_remove_extra_chips(bet_type)
	
	# Удаляем все labels для этого типа ставки
	remove_all_stake_labels_for_type(bet_type)

	print("🚫 ChipVisualManager: скрыта фишка %s" % bet_type)


func hide_all_chips() -> void:
	"""Скрыть все фишки и удалить все копии"""
	for bet_type in chip_nodes.keys():
		hide_chip(bet_type)
	_remove_all_extra_chips()


func is_chip_visible(bet_type: String) -> bool:
	"""Проверить, видна ли фишка
	
	Args:
		bet_type: Тип ставки ("Player", "Banker", "Tie", "PairPlayer", "PairBanker")
		
	Returns:
		true если фишка видна, false если скрыта или не существует
	"""
	if not chip_nodes.has(bet_type):
		return false
	return chip_nodes[bet_type].visible


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КЛИКАБЕЛЬНОСТЬЮ
# ═══════════════════════════════════════════════════════════════════════════

func make_chip_clickable(bet_type: String, clickable: bool) -> void:
	"""Сделать фишку кликабельной/некликабельной
	
	При включении кликабельности подключает обработчик _on_chip_pressed.
	При выключении отключает все обработчики.
	
	Args:
		bet_type: Тип ставки
		clickable: true для включения кликабельности, false для выключения
	"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return

	var chip = chip_nodes[bet_type]
	chip.disabled = not clickable

	if clickable:
		# Сначала отключаем все старые обработчики _on_chip_pressed
		# ВАЖНО: is_connected() не работает с bind(), нужно перебрать все подключения
		var connections = chip.pressed.get_connections()
		for conn in connections:
			var callable: Callable = conn["callable"]
			if callable.get_method() == "_on_chip_pressed":
				chip.pressed.disconnect(callable)
		# Подключаем новый обработчик
		chip.pressed.connect(_on_chip_pressed.bind(bet_type))
	else:
		# Отключаем ВСЕ обработчики _on_chip_pressed
		var connections = chip.pressed.get_connections()
		for conn in connections:
			var callable: Callable = conn["callable"]
			if callable.get_method() == "_on_chip_pressed":
				chip.pressed.disconnect(callable)


func make_all_chips_clickable(clickable: bool) -> void:
	"""Сделать все видимые фишки кликабельными/некликабельными
	
	Применяет make_chip_clickable ко всем видимым фишкам.
	
	Args:
		clickable: true для включения кликабельности, false для выключения
	"""
	for bet_type in chip_nodes.keys():
		if is_chip_visible(bet_type):
			make_chip_clickable(bet_type, clickable)


func _on_chip_pressed(bet_type: String) -> void:
	"""Обработка нажатия на фишку
	
	Эмитит сигнал chip_clicked с типом ставки.
	
	Args:
		bet_type: Тип ставки, на которую кликнули
	"""
	# Снимаем фокус с фишки после клика мышкой, чтобы избежать двойного срабатывания при нажатии пробела
	var chip = chip_nodes.get(bet_type)
	if chip:
		chip.release_focus()
		# Также снимаем фокус с viewport на случай, если фокус остался
		if chip.get_viewport():
			chip.get_viewport().gui_release_focus()
	
	print("🖱️  ChipVisualManager: клик на фишку %s" % bet_type)
	chip_clicked.emit(bet_type)


# ═══════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ТЕКСТУРАМИ (делегировано в ChipTextureManager)
# ═══════════════════════════════════════════════════════════════════════════

func get_random_texture(bet_type: String) -> String:
	"""Публичный метод для получения случайной текстуры БЕЗ показа фишки
	
	Делегирует в ChipTextureManager.
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		Путь к случайной текстуре или пустая строка если текстуры не найдены
	"""
	return texture_manager.get_random_texture(bet_type)

func get_current_texture(bet_type: String) -> String:
	"""Получить текущую текстуру фишки
	
	Делегирует в ChipTextureManager.
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		Путь к текущей текстуре или пустая строка если текстура не установлена
	"""
	return texture_manager.get_current_texture(bet_type)

func set_current_texture(bet_type: String, texture_path: String) -> void:
	"""Установить текущую текстуру фишки (без показа фишки)
	
	Делегирует в ChipTextureManager.
	Сохраняет путь к текстуре, но не применяет её к узлу фишки.
	
	Args:
		bet_type: Тип ставки
		texture_path: Путь к текстуре
	"""
	texture_manager.set_current_texture(bet_type, texture_path)


func get_visible_chips() -> Array:
	"""Получить список видимых фишек
	
	Returns:
		Массив типов ставок, которые в данный момент видимы
	"""
	var visible_chips = []
	for bet_type in chip_nodes.keys():
		if is_chip_visible(bet_type):
			visible_chips.append(bet_type)
	return visible_chips


# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ПОЗИЦИЯМИ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func set_random_mode(_enabled: bool) -> void:
	"""Включить/выключить режим случайных позиций (deprecated, всегда GUEST)"""
	set_position_mode(PositionMode.GUEST)


func set_position_mode(_mode: PositionMode) -> void:
	"""Установить режим позиций фишек (всегда GUEST)"""
	current_mode = PositionMode.GUEST  # Всегда GUEST
	print("🎲 ChipVisualManager: режим позиций = GUEST")
	
	# Очищаем активные фишки при смене режима
	clear_all_active_chips()
	
	# В режиме GUEST фишки создаются через _show_guest_bets() в GamePhaseManager
	# Здесь просто сбрасываем позиции на основные
	for bet_type in chip_nodes.keys():
		if is_chip_visible(bet_type):
			_reset_to_default_position(bet_type)


func _apply_random_position(bet_type: String) -> void:
	"""Применить случайную позицию для фишки из списка альтернатив
	
	Делегирует в ChipPositionManager.
	"""
	if not chip_nodes.has(bet_type):
		return
	
	var new_position = position_manager.get_random_position(bet_type)
	if new_position == Vector2.ZERO:
		return
	
	chip_nodes[bet_type].position = new_position
	print("📍 Фишка %s перемещена в случайную позицию: %s" % [bet_type, new_position])


func _reset_to_default_position(bet_type: String) -> void:
	"""Вернуть фишку на основную позицию"""
	if not chip_nodes.has(bet_type):
		return
	
	if not default_positions.has(bet_type):
		push_warning("ChipVisualManager: нет сохранённой позиции для '%s'" % bet_type)
		return
	
	chip_nodes[bet_type].position = default_positions[bet_type]


func reset_all_positions() -> void:
	"""Сбросить все фишки на основные позиции"""
	for bet_type in chip_nodes.keys():
		_reset_to_default_position(bet_type)
	print("📍 Все фишки возвращены на основные позиции")


func randomize_all_positions() -> void:
	"""Применить случайные позиции для всех видимых фишек"""
	for bet_type in chip_nodes.keys():
		if is_chip_visible(bet_type):
			_apply_random_position(bet_type)
	print("🎲 Все видимые фишки перемещены в случайные позиции")


func get_alternative_positions(bet_type: String) -> Array:
	"""Получить список альтернативных позиций для типа ставки
	
	Делегирует в ChipPositionManager.
	
	Args:
		bet_type: Тип ставки
		
	Returns:
		Массив Vector2 с альтернативными позициями или пустой массив если позиции не найдены
	"""
	return position_manager.get_alternative_positions(bet_type)


func is_random_mode_enabled() -> bool:
	"""Проверить, включён ли режим случайных позиций (deprecated, всегда false)"""
	return false


func get_position_mode() -> PositionMode:
	"""Получить текущий режим позиций
	
	Returns:
		Текущий режим позиций (всегда PositionMode.GUEST)
	"""
	return current_mode


# ═══════════════════════════════════════════════════════════════════════════
# MAX РЕЖИМ - СОЗДАНИЕ И УДАЛЕНИЕ КОПИЙ ФИШЕК
# ═══════════════════════════════════════════════════════════════════════════

func _create_extra_chips_max(bet_type: String, texture: Texture2D) -> void:
	"""Создать фишки для всех альтернативных позиций (MAX режим)
	
	Создаёт ChipInstance для всех позиций и добавляет их в active_chips,
	чтобы hide_chip_instance работал правильно.
	"""
	if not scene_root:
		push_warning("ChipVisualManager: scene_root не задан, не могу создать копии")
		return
	
	if not position_manager.has_positions(bet_type):
		return
	
	# Удаляем старые ChipInstance этого типа из active_chips
	var chips_to_remove = []
	for chip in active_chips:
		if chip.bet_type == bet_type:
			chips_to_remove.append(chip)
	for chip in chips_to_remove:
		if chip.node and not chip.is_original:
			chip.node.queue_free()
		active_chips.erase(chip)
	
	# Удаляем старые копии из extra_chips
	_remove_extra_chips(bet_type)
	
	var positions = position_manager.get_alternative_positions(bet_type)
	var original_chip = chip_nodes[bet_type]
	
	# Подключаем оригинальную фишку к правильному обработчику с position_index = 0
	# ВАЖНО: отключаем ВСЕ старые обработчики (bind() создаёт разные Callable!)
	var connections = original_chip.pressed.get_connections()
	for conn in connections:
		var callable: Callable = conn["callable"]
		var method_name = callable.get_method()
		if method_name == "_on_chip_pressed" or method_name == "_on_chip_instance_pressed":
			original_chip.pressed.disconnect(callable)
	original_chip.pressed.connect(_on_chip_instance_pressed.bind(bet_type, 0))
	
	# Устанавливаем оригинальную фишку на позицию 0
	if positions.size() > 0:
		original_chip.position = positions[0]
		original_chip.visible = true
	
	# Создаём ChipInstance для оригинальной фишки (position_index = 0)
	var original_instance = ChipInstance.new(bet_type, 0, original_chip, true)
	active_chips.append(original_instance)
	
	# Создаём ChipInstance для всех остальных позиций
	for i in range(1, positions.size()):
		var new_chip = TextureButton.new()
		new_chip.texture_normal = texture
		new_chip.position = positions[i]
		new_chip.scale = original_chip.scale
		new_chip.modulate = original_chip.modulate
		new_chip.mouse_filter = Control.MOUSE_FILTER_STOP
		new_chip.focus_mode = Control.FOCUS_NONE  # Отключаем фокус чтобы Space не активировал фишки
		new_chip.visible = true
		
		# Подключаем сигнал клика с position_index
		new_chip.pressed.connect(_on_chip_instance_pressed.bind(bet_type, i))
		
		scene_root.add_child(new_chip)
		
		# Добавляем в extra_chips для совместимости
		if not extra_chips.has(bet_type):
			extra_chips[bet_type] = []
		extra_chips[bet_type].append(new_chip)
		
		# Создаём ChipInstance и добавляем в active_chips
		var chip_instance = ChipInstance.new(bet_type, i, new_chip, false)
		active_chips.append(chip_instance)
	
	print("📍 MAX: создано %d фишек %s (всего позиций: %d)" % [positions.size(), bet_type, positions.size()])


func _remove_extra_chips(bet_type: String) -> void:
	"""Удалить дополнительные фишки для типа ставки"""
	# Удаляем ChipInstance из active_chips
	var chips_to_remove = []
	for chip in active_chips:
		if chip.bet_type == bet_type and not chip.is_original:
			chips_to_remove.append(chip)
	for chip in chips_to_remove:
		# Удаляем label суммы ставки
		_remove_stake_label(chip)
		if chip.node:
			chip.node.queue_free()
		active_chips.erase(chip)
	
	# Удаляем узлы из extra_chips
	if not extra_chips.has(bet_type):
		return
	
	for chip in extra_chips[bet_type]:
		if is_instance_valid(chip):
			chip.queue_free()
	
	extra_chips[bet_type].clear()


func _remove_all_extra_chips() -> void:
	"""Удалить все дополнительные фишки"""
	for bet_type in extra_chips.keys():
		_remove_extra_chips(bet_type)
	print("📍 Все дополнительные фишки удалены")


func _on_extra_chip_pressed(bet_type: String, position_index: int = 0) -> void:
	"""Обработка клика на дополнительную фишку (MAX режим)"""
	print("🖱️  ChipVisualManager: клик на копию фишки %s[%d]" % [bet_type, position_index])
	chip_instance_clicked.emit(bet_type, position_index)


# ═══════════════════════════════════════════════════════════════════════════
# REALISTIC РЕЖИМ - ГЕНЕРАЦИЯ СЛУЧАЙНОГО КОЛИЧЕСТВА
# ═══════════════════════════════════════════════════════════════════════════

func _get_ranges_for_bet_type(_bet_type: String) -> Array:
	"""Получить диапазоны количества для типа ставки
	
	Делегирует в RealisticChipGenerator.
	"""
	return realistic_generator.get_ranges_for_bet_type(_bet_type)


func _generate_random_count(bet_type: String) -> int:
	"""Генерировать случайное количество ставок с весовым распределением
	
	Делегирует в RealisticChipGenerator.
	"""
	return realistic_generator.generate_random_count(bet_type, position_manager)


func _select_random_positions(bet_type: String, count: int) -> Array[int]:
	"""Выбрать случайные позиции для ставок
	
	Делегирует в RealisticChipGenerator.
	"""
	return realistic_generator.select_random_positions(bet_type, count, position_manager)


func show_chips_realistic(bet_type: String, stakes: Array[float] = []) -> Array[ChipInstance]:
	"""Показать фишки в REALISTIC режиме со случайным количеством
	
	Args:
		bet_type: Тип ставки
		stakes: Массив размеров ставок (если пустой - генерируются автоматически)
	
	Returns:
		Массив созданных ChipInstance
	"""
	if not chip_nodes.has(bet_type):
		push_error("ChipVisualManager: неизвестный тип ставки '%s'" % bet_type)
		return []
	
	# Генерируем количество
	var count = _generate_random_count(bet_type)
	print("🎲 REALISTIC: %s = %d ставок" % [bet_type, count])
	
	if count == 0:
		# Скрываем основную фишку
		chip_nodes[bet_type].visible = false
		return []
	
	# Выбираем позиции
	var selected_positions = _select_random_positions(bet_type, count)
	
	# Создаём фишки
	var created_chips: Array[ChipInstance] = []
	var texture_path = texture_manager.get_random_texture(bet_type)
	var texture = load(texture_path)
	
	for i in range(selected_positions.size()):
		var pos_idx = selected_positions[i]
		var stake = stakes[i] if i < stakes.size() else 0.0
		
		var chip_instance: ChipInstance
		
		if i == 0:
			# Первая фишка - используем основную из сцены
			var original_chip = chip_nodes[bet_type]
			original_chip.texture_normal = texture
			original_chip.position = position_manager.get_position_at_index(bet_type, pos_idx)
			original_chip.visible = true
			original_chip.focus_mode = Control.FOCUS_NONE  # Отключаем фокус чтобы Space не активировал фишки
			
			chip_instance = ChipInstance.new(bet_type, pos_idx, original_chip, true)
			chip_instance.stake = stake
			
			# Отключаем ВСЕ старые обработчики (bind() создаёт разные Callable!)
			var orig_connections = original_chip.pressed.get_connections()
			for conn in orig_connections:
				var callable: Callable = conn["callable"]
				var method_name = callable.get_method()
				if method_name == "_on_chip_pressed" or method_name == "_on_chip_instance_pressed":
					original_chip.pressed.disconnect(callable)
			
			# Подключаем сигнал с индексом
			original_chip.pressed.connect(_on_chip_instance_pressed.bind(bet_type, pos_idx))
		else:
			# Остальные - создаём копии
			var new_chip = _create_chip_copy(bet_type, pos_idx, texture)
			chip_instance = ChipInstance.new(bet_type, pos_idx, new_chip, false)
			chip_instance.stake = stake
		
		# Создаём label для суммы ставки (если stake > 0)
		if chip_instance.stake > 0:
			chip_instance.stake_label = create_stake_label(chip_instance)
		
		active_chips.append(chip_instance)
		created_chips.append(chip_instance)
	
	texture_manager.set_current_texture(bet_type, texture_path)
	print("📍 REALISTIC: создано %d фишек %s на позициях %s" % [created_chips.size(), bet_type, selected_positions])
	
	return created_chips


func _create_chip_copy(bet_type: String, position_index: int, texture: Texture2D) -> TextureButton:
	"""Создать копию фишки"""
	if not scene_root:
		push_warning("ChipVisualManager: scene_root не задан")
		return null
	
	var original_chip = chip_nodes[bet_type]
	var positions = position_manager.get_alternative_positions(bet_type)
	
	if position_index >= positions.size():
		push_error("ChipVisualManager: индекс позиции %d вне диапазона для %s" % [position_index, bet_type])
		return null
	
	var new_chip = TextureButton.new()
	new_chip.texture_normal = texture
	new_chip.position = positions[position_index]
	new_chip.scale = original_chip.scale
	new_chip.modulate = original_chip.modulate
	new_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	new_chip.focus_mode = Control.FOCUS_NONE  # Отключаем фокус чтобы Space не активировал фишки
	new_chip.visible = true
	
	# Подключаем сигнал с индексом
	new_chip.pressed.connect(_on_chip_instance_pressed.bind(bet_type, position_index))
	
	scene_root.add_child(new_chip)
	
	# Добавляем в extra_chips для совместимости
	if not extra_chips.has(bet_type):
		extra_chips[bet_type] = []
	extra_chips[bet_type].append(new_chip)
	
	return new_chip

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ LABEL СУММЫ СТАВКИ
# ═══════════════════════════════════════════════════════════════════════════

func create_stake_label(chip_instance: ChipInstance) -> Control:
	"""Создать label для отображения суммы ставки в стиле карточек гостя
	
	Делегирует в StakeLabelManager.
	
	Args:
		chip_instance: Экземпляр фишки
	
	Returns:
		Control с label суммы ставки
	"""
	return stake_label_manager.create_stake_label(chip_instance, scene_root)


func _format_stake(stake: float) -> String:
	"""Форматировать сумму ставки для отображения с разделителем тысяч через пробел
	
	Делегирует в StakeLabelManager.
	"""
	return stake_label_manager.format_stake(stake)


func _update_stake_label(chip_instance: ChipInstance) -> void:
	"""Обновить текст label суммы ставки
	
	Делегирует в StakeLabelManager.
	"""
	stake_label_manager.update_stake_label(chip_instance)


func _remove_stake_label(chip_instance: ChipInstance) -> void:
	"""Удалить label суммы ставки
	
	Делегирует в StakeLabelManager.
	"""
	stake_label_manager.remove_stake_label(chip_instance)


func remove_all_stake_labels_for_type(bet_type: String) -> void:
	"""Удалить все labels для конкретного типа ставки (публичный метод)
	
	Делегирует в StakeLabelManager.
	"""
	stake_label_manager.remove_all_stake_labels_for_type(active_chips, bet_type)


func _on_chip_instance_pressed(bet_type: String, position_index: int) -> void:
	"""Обработка клика на конкретную фишку"""
	# Снимаем фокус с фишки после клика мышкой, чтобы избежать двойного срабатывания при нажатии пробела
	var chip = get_chip_instance(bet_type, position_index)
	if chip and chip.node:
		chip.node.release_focus()
		# Также снимаем фокус с viewport на случай, если фокус остался
		if chip.node.get_viewport():
			chip.node.get_viewport().gui_release_focus()
	
	print("🖱️  ChipVisualManager: клик на фишку %s[%d]" % [bet_type, position_index])
	print("🔵 ChipVisualManager: эмитим сигнал chip_instance_clicked для %s[%d]" % [bet_type, position_index])
	chip_instance_clicked.emit(bet_type, position_index)
	print("🔵 ChipVisualManager: сигнал chip_instance_clicked эмиттирован")
	# НЕ эмитим chip_clicked - это вызовет двойную обработку в GameController!


func get_chip_instance(bet_type: String, position_index: int) -> ChipInstance:
	"""Получить ChipInstance по типу и индексу"""
	for chip in active_chips:
		if chip.bet_type == bet_type and chip.position_index == position_index:
			return chip
	return null


func get_active_chips_by_type(bet_type: String) -> Array[ChipInstance]:
	"""Получить все активные фишки определённого типа"""
	var result: Array[ChipInstance] = []
	for chip in active_chips:
		if chip.bet_type == bet_type:
			result.append(chip)
	return result


func get_all_active_chips() -> Array[ChipInstance]:
	"""Получить все активные фишки"""
	return active_chips


func hide_chip_instance(bet_type: String, position_index: int) -> bool:
	"""Скрыть конкретную фишку по типу и индексу"""
	var chip = get_chip_instance(bet_type, position_index)
	if not chip:
		print("⚠️  hide_chip_instance: фишка %s[%d] не найдена в active_chips" % [bet_type, position_index])
		return false

	# Удаляем label суммы ставки
	_remove_stake_label(chip)
	
	if chip.node:
		# Отключаем ВСЕ обработчики _on_chip_instance_pressed
		# ВАЖНО: is_connected() не работает с bind(), нужно перебрать все подключения
		var connections = chip.node.pressed.get_connections()
		for conn in connections:
			var callable: Callable = conn["callable"]
			if callable.get_method() == "_on_chip_instance_pressed":
				chip.node.pressed.disconnect(callable)
		
		chip.node.visible = false
		
		# Если это копия - удаляем узел полностью
		if not chip.is_original:
			chip.node.queue_free()
			# Удаляем из extra_chips
			if extra_chips.has(bet_type):
				extra_chips[bet_type].erase(chip.node)

	# Удаляем из active_chips
	active_chips.erase(chip)

	print("🚫 Скрыта фишка %s[%d]" % [bet_type, position_index])
	return true


func clear_all_active_chips() -> void:
	"""Удалить все активные фишки"""
	for chip in active_chips:
		# Удаляем label суммы ставки
		_remove_stake_label(chip)
		
		if chip.node:
			# Отключаем ВСЕ обработчики _on_chip_instance_pressed
			# ВАЖНО: is_connected(_on_chip_instance_pressed) НЕ работает с bind()!
			# Нужно перебрать все подключения и отключить по имени метода
			var connections = chip.node.pressed.get_connections()
			for conn in connections:
				var callable: Callable = conn["callable"]
				if callable.get_method() == "_on_chip_instance_pressed":
					chip.node.pressed.disconnect(callable)
			
			# Удаляем копии (не оригинальные)
			if not chip.is_original:
				chip.node.queue_free()
	active_chips.clear()
	_remove_all_extra_chips()
	print("🗑️  Все активные фишки очищены")


func get_active_chips_count_by_type(bet_type: String) -> int:
	"""Количество активных фишек определённого типа"""
	var count = 0
	for chip in active_chips:
		if chip.bet_type == bet_type:
			count += 1
	return count


# ═══════════════════════════════════════════════════════════════════════════
# ИНФОРМАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func print_status() -> void:
	"""Вывести текущий статус фишек"""
	print("═══ ChipVisualManager Status ═══")
	print("Режим: %s" % PositionMode.keys()[current_mode])
	print("Активных фишек: %d" % active_chips.size())
	for bet_type in chip_nodes.keys():
		var chip = chip_nodes[bet_type]
		var status = "✅ Видна" if chip.visible else "❌ Скрыта"
		var texture = texture_manager.get_current_texture(bet_type)
		if texture.is_empty():
			texture = "нет"
		var active_count = get_active_chips_count_by_type(bet_type)
		print("  %s: %s | Текстура: %s | Активных: %d" % [bet_type, status, texture, active_count])
	print("═══════════════════════════════")


# ═══════════════════════════════════════════════════════════════════════════
# ❤️ HEART BET - СКРЫТИЕ/ПОКАЗ СТАВОК ГОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════

## Сохранённое состояние видимости фишек (для восстановления после Heart Bet)
var _saved_visibility: Dictionary = {}


func hide_all_guest_chips() -> void:
	"""Скрыть все ставки гостей (при выборе сердца для Heart Bet)
	
	Сохраняет текущее состояние видимости для восстановления.
	"""
	_saved_visibility.clear()
	
	# Удаляем все labels перед скрытием фишек
	for chip in active_chips:
		_remove_stake_label(chip)
	
	# Сохраняем и скрываем активные фишки (ChipInstance)
	for chip in active_chips:
		if chip.node and is_instance_valid(chip.node):
			_saved_visibility["%s_%d" % [chip.bet_type, chip.position_index]] = chip.node.visible
			chip.node.visible = false
	
	# Сохраняем и скрываем основные фишки
	for bet_type in chip_nodes.keys():
		if chip_nodes[bet_type] and is_instance_valid(chip_nodes[bet_type]):
			_saved_visibility[bet_type] = chip_nodes[bet_type].visible
			chip_nodes[bet_type].visible = false
	
	print("❤️ Ставки гостей скрыты (сохранено %d состояний)" % _saved_visibility.size())


func show_all_guest_chips() -> void:
	"""Показать все ставки гостей (после завершения Heart Bet раздачи)

	Восстанавливает сохранённое состояние видимости и создаёт labels для сумм ставок.
	"""
	if _saved_visibility.is_empty():
		print("⚠️ Нет сохранённых состояний видимости для восстановления")
		return

	# Восстанавливаем видимость активных фишек (ChipInstance)
	for chip in active_chips:
		# Проверяем что узел существует и не удалён
		if chip.node and is_instance_valid(chip.node):
			var key = "%s_%d" % [chip.bet_type, chip.position_index]
			if _saved_visibility.has(key):
				chip.node.visible = _saved_visibility[key]
				# Создаём или обновляем label для суммы ставки
				if chip.node.visible and chip.stake > 0:
					if chip.stake_label:
						# Обновляем существующий label
						_update_stake_label(chip)
					else:
						# Создаём новый label
						chip.stake_label = create_stake_label(chip)

	# Восстанавливаем видимость основных фишек
	for bet_type in chip_nodes.keys():
		if _saved_visibility.has(bet_type):
			if chip_nodes[bet_type] and is_instance_valid(chip_nodes[bet_type]):
				chip_nodes[bet_type].visible = _saved_visibility[bet_type]

	print("❤️ Ставки гостей восстановлены")
	_saved_visibility.clear()


func clear_guest_chips_for_sector(guest_id: int) -> void:
	"""Удалить фишки конкретного гостя (при отключении гостя)
	
	guest_id: 1-6 (соответствует сектору)
	"""
	var removed_count = 0
	
	print("👥 clear_guest_chips_for_sector(%d): active_chips.size=%d" % [guest_id, active_chips.size()])
	
	# Удаляем активные фишки из этого сектора
	var chips_to_remove: Array = []
	for chip in active_chips:
		# Используем GuestSectorMapper для определения сектора
		var sector = GuestSectorMapper.get_sector_from_position(chip.bet_type, chip.position_index)
		print("👥   - chip %s[%d] → sector %d (target: %d), is_original=%s" % [chip.bet_type, chip.position_index, sector, guest_id, chip.is_original])
		if sector == guest_id:
			chips_to_remove.append(chip)
	
	for chip in chips_to_remove:
		# Удаляем label суммы ставки
		_remove_stake_label(chip)
		
		# НЕ удаляем оригинальные фишки (они часть сцены), только скрываем
		if chip.is_original:
			if chip.node and is_instance_valid(chip.node):
				chip.node.visible = false
			# НЕ удаляем из active_chips - оригинальные фишки нужны для следующих раундов
			print("👥   → оригинальная фишка %s скрыта (не удалена)" % chip.bet_type)
		else:
			# Удаляем только копии
			if chip.node and is_instance_valid(chip.node):
				chip.node.queue_free()
			active_chips.erase(chip)
			removed_count += 1
	
	print("👥 Удалено %d копий фишек гостя %d" % [removed_count, guest_id])
