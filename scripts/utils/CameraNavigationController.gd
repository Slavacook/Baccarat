# res://scripts/utils/CameraNavigationController.gd
# ═══════════════════════════════════════════════════════════════════════════
# КОНТРОЛЛЕР НАВИГАЦИИ КАМЕРЫ
# 
# Отвечает за:
# - Управление зумом камеры (in, out, cards, area)
# - Навигацию по областям через стрелки
# - Обновление состояния стрелок навигации
# - Подсветку областей при зуме
# ═══════════════════════════════════════════════════════════════════════════

class_name CameraNavigationController
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var camera_manager: CameraManager
var owner_node: Node  # Узел для доступа к дочерним элементам (стрелки, подсветка)

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(camera_mgr: CameraManager, owner: Node) -> void:
	"""Инициализировать контроллер навигации камеры
	
	Args:
		camera_mgr: Менеджер камеры
		owner: Узел-владелец для доступа к дочерним элементам
	"""
	camera_manager = camera_mgr
	owner_node = owner
	
	# Скрываем все подсветки на старте
	update_area_highlights(0)
	
	# Подписываемся на завершение зума камеры
	if camera_manager:
		camera_manager.zoom_completed.connect(on_camera_zoom_completed)

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ ЗУМОМ КАМЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

func camera_zoom_in() -> void:
	"""Плавный зум на область карт (через EventBus)
	
	Использует EventBus для запроса зума, обеспечивая слабую связанность.
	"""
	EventBus.camera_zoom_requested.emit("in", false)

func camera_zoom_out() -> void:
	"""Возврат к общему плану (через EventBus)
	
	Использует EventBus для запроса зума, обеспечивая слабую связанность.
	"""
	EventBus.camera_zoom_requested.emit("out", false)

func camera_zoom_cards() -> void:
	"""Плавный зум на область карт (через EventBus)
	
	Использует EventBus для запроса зума, обеспечивая слабую связанность.
	"""
	EventBus.camera_zoom_requested.emit("cards", false)

func camera_zoom_area(area_index: int) -> void:
	"""Плавный зум на область ставок (через EventBus)
	
	Args:
		area_index: Индекс области (1-3)
	
	Использует EventBus для запроса зума, обеспечивая слабую связанность.
	"""
	EventBus.camera_zoom_requested.emit("area_%d" % area_index, false)

# ═══════════════════════════════════════════════════════════════════════════
# НАВИГАЦИЯ ПО ОБЛАСТЯМ (СТРЕЛКИ)
# ═══════════════════════════════════════════════════════════════════════════

func on_left_arrow_pressed() -> void:
	"""Обработчик нажатия левой стрелки (через EventBus)
	
	Запрашивает переход камеры в область слева от текущей.
	"""
	request_camera_target_area("left")

func on_right_arrow_pressed() -> void:
	"""Обработчик нажатия правой стрелки (через EventBus)
	
	Запрашивает переход камеры в область справа от текущей.
	"""
	request_camera_target_area("right")

func on_up_arrow_pressed() -> void:
	"""Обработчик нажатия стрелки вверх (через EventBus)
	
	Запрашивает переход камеры в область выше текущей.
	"""
	request_camera_target_area("up")

func on_down_arrow_pressed() -> void:
	"""Обработчик нажатия стрелки вниз (через EventBus)
	
	Запрашивает переход камеры в область ниже текущей.
	"""
	request_camera_target_area("down")

func request_camera_target_area(direction: String) -> void:
	"""Запросить целевую область через EventBus и выполнить зум
	
	Args:
		direction: "left", "right", "up", "down"
	"""
	# Создаём временную подписку на ответ (одноразово)
	var response_handler = func(dir: String, area: int):
		if dir == direction:
			if area > 0:
				EventBus.camera_zoom_requested.emit("area_%d" % area, false)
			elif area == -1:
				EventBus.camera_zoom_requested.emit("out", false)
			else:
				EventBus.camera_zoom_requested.emit("in", false)
			update_arrows_state()
			# CONNECT_ONE_SHOT автоматически отписывает после первого вызова
	
	EventBus.camera_target_area_received.connect(response_handler, CONNECT_ONE_SHOT)
	EventBus.camera_target_area_requested.emit(direction)

func on_arrows_visibility_changed(_should_show: bool) -> void:
	"""Обработчик изменения видимости стрелок
	
	Примечание: стрелки визуально всегда скрыты (visible = false),
	но сигнал используется для активации/деактивации навигации по полю.
	Параметр _should_show не используется, так как стрелки всегда скрыты.
	"""
	var left_arrow = owner_node.get_node_or_null("TopUI/LeftArrowButton")
	var right_arrow = owner_node.get_node_or_null("TopUI/RightArrowButton")
	var up_arrow = owner_node.get_node_or_null("TopUI/UpArrowButton")
	var down_arrow = owner_node.get_node_or_null("TopUI/DownArrowButton")

	# Стрелки визуально всегда скрыты (навигация через клавиатуру и свайп)
	if left_arrow:
		left_arrow.visible = false
	if right_arrow:
		right_arrow.visible = false
	if up_arrow:
		up_arrow.visible = false
	if down_arrow:
		down_arrow.visible = false

	# Обновление состояния стрелок не нужно - они всегда скрыты

func update_arrows_state(target_area: int = -1) -> void:
	"""Обновить состояние стрелок (активность) в зависимости от текущей области
	
	Args:
		target_area: Целевая область для мгновенного обновления (если -1, запрашивается через EventBus)
	"""
	if target_area >= 0:
		# Если область передана, используем её напрямую
		update_arrows_for_area(target_area)
	else:
		# Запрашиваем текущую область через EventBus
		var response_handler = func(area: int):
			update_arrows_for_area(area)
			# CONNECT_ONE_SHOT автоматически отписывает после первого вызова
		
		EventBus.camera_current_area_received.connect(response_handler, CONNECT_ONE_SHOT)
		EventBus.camera_current_area_requested.emit()

func update_arrows_for_area(current_area: int) -> void:
	"""Обновить состояние стрелок для указанной области
	
	Args:
		current_area: Текущая область (0 = карты, 1-3 = области ставок)
	"""
	var left_arrow = owner_node.get_node_or_null("TopUI/LeftArrowButton")
	var right_arrow = owner_node.get_node_or_null("TopUI/RightArrowButton")
	var up_arrow = owner_node.get_node_or_null("TopUI/UpArrowButton")
	var down_arrow = owner_node.get_node_or_null("TopUI/DownArrowButton")
	
	# Счётчик ожидаемых ответов и словарь ответов (используем словарь для изменяемых значений)
	var state = {
		"pending": 4,
		"completed": false,
		"responses": {
			"left": null,
			"right": null,
			"up": null,
			"down": null
		}
	}
	
	# Обработчик ответов (не отписываемся вручную - просто игнорируем после завершения)
	var response_handler = func(area: int, dir: String, target: int):
		# Игнорируем, если уже завершено
		if state.completed:
			return
		# Проверяем, что ответ относится к текущему запросу
		if area == current_area and dir in state.responses and state.responses[dir] == null:
			state.responses[dir] = target
			state.pending -= 1
			if state.pending == 0:
				# Все ответы получены, обновляем стрелки
				state.completed = true
				apply_arrows_state(left_arrow, right_arrow, up_arrow, down_arrow, current_area, state.responses)
				# Не отписываемся - обработчик просто будет игнорировать дальнейшие вызовы
	
	EventBus.camera_target_area_from_received.connect(response_handler)
	
	# Запрашиваем целевые области для всех направлений
	EventBus.camera_target_area_from_requested.emit(current_area, "left")
	EventBus.camera_target_area_from_requested.emit(current_area, "right")
	EventBus.camera_target_area_from_requested.emit(current_area, "up")
	EventBus.camera_target_area_from_requested.emit(current_area, "down")

func apply_arrows_state(left_arrow: Node, right_arrow: Node, up_arrow: Node, down_arrow: Node, current_area: int, responses: Dictionary) -> void:
	"""Применить состояние стрелок на основе ответов
	
	Args:
		left_arrow, right_arrow, up_arrow, down_arrow: Узлы стрелок
		current_area: Текущая область
		responses: Словарь с целевыми областями {"left": int, "right": int, ...}
	"""
	# Левая стрелка
	if left_arrow and responses.has("left"):
		var target_left = responses["left"]
		var can_go_left = (target_left != current_area)
		left_arrow.disabled = not can_go_left
		left_arrow.modulate.a = 0.3 if not can_go_left else 1.0
	
	# Правая стрелка
	if right_arrow and responses.has("right"):
		var target_right = responses["right"]
		var can_go_right = (target_right != current_area)
		right_arrow.disabled = not can_go_right
		right_arrow.modulate.a = 0.3 if not can_go_right else 1.0
	
	# Стрелка вверх
	if up_arrow and responses.has("up"):
		var target_up = responses["up"]
		var can_go_up = (target_up != current_area)
		up_arrow.disabled = not can_go_up
		up_arrow.modulate.a = 0.3 if not can_go_up else 1.0
	
	# Стрелка вниз
	if down_arrow and responses.has("down"):
		var target_down = responses["down"]
		var can_go_down = (target_down != current_area)
		down_arrow.disabled = not can_go_down
		down_arrow.modulate.a = 0.3 if not can_go_down else 1.0

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА СОБЫТИЙ КАМЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

func on_camera_zoom_completed(_zoom_type: String) -> void:
	"""Обработка завершения зума камеры (синхронизация подсветки при необходимости)"""
	# Подсветка уже обновлена мгновенно в on_camera_zoom_requested
	# Обновляем состояние стрелок после завершения зума (current_area точно обновлён)
	update_arrows_state()

func on_camera_zoom_requested(zoom_type: String, _is_navigation: bool = false) -> void:
	"""Мгновенно подсвечиваем целевую область по запросу зума (до завершения анимации)"""
	var target_area := camera_manager.predict_target_area(zoom_type)
	update_area_highlights(target_area)
	
	# Мгновенно обновляем состояние стрелок на основе целевой области
	# (так же быстро, как меняется подсветка зон)
	update_arrows_state(target_area)
	
	# Скрываем кнопки областей если переходим в область через стрелки/клавиши
	# (они уже не нужны, так как зона выбрана)
	if zoom_type.begins_with("area_"):
		EventBus.area_buttons_visibility_changed.emit(false)

func update_area_highlights(area_idx: int) -> void:
	"""Показать подсветку выбранной области (1-3), 0 — скрыть все
	
	Args:
		area_idx: Индекс области (1-3) или 0 для скрытия всех
	"""
	for i in range(1, 4):
		var node_path = "AreaHighlight%d" % i
		var hl = owner_node.get_node_or_null(node_path)
		if hl:
			var active = (i == area_idx)
			hl.visible = active
			hl.modulate.a = 1.0 if active else 0.0

