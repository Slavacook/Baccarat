# res://scripts/ToastManager.gd
# Менеджер всплывающих уведомлений - подписан на события EventBus
extends Node

const TOAST_SCENE = preload("res://scenes/Toast.tscn")

static var instance: ToastManager

var container: VBoxContainer
var toast_pool: ToastPool  # ← Пул Toast узлов для переиспользования

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	# ВАЖНО: Подписываемся на события ПЕРВЫМ ДЕЛОМ, независимо от наличия контейнера
	# Контейнер может быть найден позже, но подписки должны работать всегда
	EventBus.show_toast_info.connect(_on_show_toast_info)
	EventBus.show_toast_success.connect(_on_show_toast_success)
	EventBus.show_toast_error.connect(_on_show_toast_error)
	
	# Подписываемся на события гостей
	if EventBus:
		EventBus.guest_left_due_to_patience.connect(_on_guest_left_due_to_patience)
		EventBus.guest_left_due_to_bankruptcy.connect(_on_guest_left_due_to_bankruptcy)
	
	if GuestReturnManager:
		GuestReturnManager.guest_returned.connect(_on_guest_returned)
	
	# Теперь ищем контейнер (может быть не найден сразу, но это нормально)
	var current_scene = get_tree().current_scene
	if current_scene:
		# Ищем ToastLayer (новое расположение, поверх PayoutOverlay)
		var toast_layer = current_scene.get_node_or_null("ToastLayer")
		if toast_layer:
			container = toast_layer.get_node_or_null("ToastContainer")
		
		# Если не нашли, пробуем старый путь (UI) для обратной совместимости
		if not container:
			var canvas_layer = current_scene.get_node_or_null("UI")
			if canvas_layer:
				container = canvas_layer.get_node_or_null("ToastContainer")

	if container:
		# Контейнер найден - инициализируем пул
		toast_pool = ToastPool.new(container)
		print("🍞 ToastManager готов! Подписан на EventBus. Пул: %d узлов." % ToastPool.POOL_SIZE)
	else:
		# Контейнер не найден - это нормально, он будет найден при первом показе тоста
		print("🍞 ToastManager: контейнер не найден при инициализации, будет найден при первом показе тоста")

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ EventBus
# ═══════════════════════════════════════════════════════════════════════════

func _on_show_toast_info(message: String):
	show_info(message)

func _on_show_toast_success(message: String):
	show_success(message)

func _on_show_toast_error(message: String):
	show_error(message)

func _on_guest_left_due_to_patience(guest_id: int):
	"""Обработчик ухода гостя из-за терпения - показываем тост"""
	var message = Localization.t("GUEST_LEFT_PATIENCE") % guest_id
	show_error(message, 3.0)

func _on_guest_left_due_to_bankruptcy(guest_id: int):
	"""Обработчик ухода гостя из-за банкротства - показываем тост"""
	var message = Localization.t("GUEST_LEFT_BANKRUPTCY") % guest_id
	show_info(message, 3.0)

func _on_guest_returned(guest_id: int):
	"""Обработчик возврата гостя - показываем тост"""
	var message = Localization.t("GUEST_RETURNED") % guest_id
	show_success(message, 3.0)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ (для прямых вызовов, если нужно)
# ═══════════════════════════════════════════════════════════════════════════

func show_message(text: String, type: String = "info", duration: float = 2.5):
	# ← Проверяем валидность контейнера, переинициализируем если нужно
	if not is_instance_valid(container) or not container.is_inside_tree():
		_reinitialize_container()
	
	# Если контейнер все еще не найден - пытаемся найти еще раз
	if not container:
		_reinitialize_container()

	if not container or not toast_pool:
		# Если контейнер все еще не найден - просто выходим (не критично)
		print("⚠️ ToastManager: не удалось показать тост '%s' - контейнер не найден" % text)
		return

	# ← Берём Toast из пула (переиспользование)
	var toast = toast_pool.get_toast()
	var label_node = toast.get_node("MarginContainer/Label")
	if label_node:
		label_node.text = text
		label_node.add_theme_color_override("font_color", _get_color(type))

	# ← Передаём callback для возврата в пул после анимации
	var return_callback = func(): toast_pool.return_toast(toast)
	toast.show_message(text, duration, return_callback)

func show_error(text: String, duration: float = 3.0):
	show_message(text, "error", duration)

func show_info(text: String, duration: float = 2.5):
	show_message(text, "info", duration)

func show_success(text: String, duration: float = 2.5):
	show_message(text, "success", duration)

func _get_color(type: String) -> Color:
	match type:
		"error": return Color(1, 0.3, 0.3)
		"success": return Color(0.3, 1, 0.3)
		"info": return Color(0.8, 0.8, 1)
		_: return Color.WHITE

# ← Переинициализация контейнера после смены сцены
func _reinitialize_container():
	var current_scene = get_tree().current_scene
	if not current_scene:
		# Сцена еще не загружена - это нормально
		return
	
	# Ищем ToastLayer (новое расположение, поверх PayoutOverlay)
	var toast_layer = current_scene.get_node_or_null("ToastLayer")
	if toast_layer:
		container = toast_layer.get_node_or_null("ToastContainer")
	
	# Если не нашли, пробуем старый путь (UI) для обратной совместимости
	if not container:
		var canvas_layer = current_scene.get_node_or_null("UI")
		if canvas_layer:
			container = canvas_layer.get_node_or_null("ToastContainer")

	if not container:
		# Контейнер не найден - это нормально, попробуем позже
		return

	# Пересоздаём пул с новым контейнером
	toast_pool = ToastPool.new(container)
	print("🍞 ToastManager: контейнер переинициализирован для новой сцены")
