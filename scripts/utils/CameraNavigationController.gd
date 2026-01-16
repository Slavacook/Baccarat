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
	
	Примечание: кнопки стрелок удалены из сцены.
	Сигнал используется для активации/деактивации навигации по полю (клавиатура и свайп).
	Параметр _should_show не используется, так как кнопок больше нет.
	"""
	# Кнопки стрелок удалены - навигация только через клавиатуру и свайп
	pass

func update_arrows_state(_target_area: int = -1) -> void:
	"""Обновить состояние стрелок (активность) в зависимости от текущей области
	
	Примечание: кнопки стрелок удалены из сцены.
	Метод оставлен для совместимости, но ничего не делает.
	
	Args:
		_target_area: Целевая область для мгновенного обновления (если -1, запрашивается через EventBus)
	"""
	# Кнопки стрелок удалены - навигация только через клавиатуру и свайп
	pass

func update_arrows_for_area(_current_area: int) -> void:
	"""Обновить состояние стрелок для указанной области
	
	Примечание: кнопки стрелок удалены из сцены.
	Метод оставлен для совместимости, но ничего не делает.
	
	Args:
		_current_area: Текущая область (0 = карты, 1-3 = области ставок)
	"""
	# Кнопки стрелок удалены - навигация только через клавиатуру и свайп
	pass

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
	# Проверяем, что owner_node не освобожден
	if not is_instance_valid(owner_node):
		return
	
	for i in range(1, 4):
		var node_path = "AreaHighlight%d" % i
		var hl = owner_node.get_node_or_null(node_path)
		if hl:
			var active = (i == area_idx)
			hl.visible = active
			hl.modulate.a = 1.0 if active else 0.0
