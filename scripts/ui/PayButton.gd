# res://scripts/ui/PayButton.gd
# Скрипт для кнопки PayButton с переключением между двумя состояниями
# Состояние 1: Забрать (take_button_4.png) - режим COLLECT
# Состояние 2: Оплатить (pay_button_4.png) - режим PAY
# При наведении мыши показывает текстуру следующего состояния
# Использует дочерние узлы: TakeContainer и PayContainer (созданные в редакторе)

extends TextureButton

# Сигналы для уведомления ButtonUIManager о переключении режимов
signal state_changed(is_pay_mode: bool)  # true = PAY, false = COLLECT

# ═══════════════════════════════════════════════════════════════════════════
# ССЫЛКИ НА ДОЧЕРНИЕ УЗЛЫ (находятся в редакторе)
# ═══════════════════════════════════════════════════════════════════════════

# Контейнеры для каждой текстуры (созданы в редакторе)
var take_container: Control  # TakeContainer - контейнер для "Забрать"
var pay_container: Control   # PayContainer - контейнер для "Оплатить"

# Текущее состояние (false = Забрать/COLLECT, true = Оплатить/PAY)
var is_pay_state: bool = false

# Флаг наведения мыши
var is_hovering: bool = false

func _ready():
	# Скрываем стандартную текстуру кнопки (используем дочерние узлы)
	texture_normal = null
	
	# Отключаем toggle_mode (будем управлять вручную)
	toggle_mode = false
	
	# Убеждаемся, что кнопка активна
	disabled = false
	
	# Подключаем сигналы для hover эффекта
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	
	# Находим дочерние узлы с задержкой (после полной загрузки дерева сцены)
	call_deferred("_find_child_nodes")
	
	print("✅ PayButton инициализирована: начальное состояние = Забрать")
	print("   - Кнопка видима: %s" % visible)
	print("   - Кнопка активна: %s" % (not disabled))
	print("   - Размер кнопки: %s" % size)


func _find_child_nodes():
	"""Находит дочерние узлы, созданные в редакторе и настраивает их"""
	# Ищем контейнеры по имени
	take_container = get_node_or_null("TakeContainer")
	pay_container = get_node_or_null("PayContainer")
	
	# Проверяем, что узлы найдены
	if not take_container:
		push_error("❌ PayButton: TakeContainer не найден! Убедитесь, что узел создан в редакторе.")
		return
	
	if not pay_container:
		push_error("❌ PayButton: PayContainer не найден! Убедитесь, что узел создан в редакторе.")
		return
	
	# Настраиваем контейнеры чтобы они заполняли всю кнопку
	_setup_container(take_container)
	_setup_container(pay_container)
	
	# Устанавливаем начальное состояние (Забрать)
	is_pay_state = false
	_update_texture()
	
	print("✅ PayButton: найдены и настроены дочерние узлы:")
	print("   - TakeContainer: %s (visible=%s, position=%s, size=%s)" % [
		take_container.get_path(), 
		take_container.visible, 
		take_container.position,
		take_container.size
	])
	print("   - PayContainer: %s (visible=%s, position=%s, size=%s)" % [
		pay_container.get_path(), 
		pay_container.visible, 
		pay_container.position,
		pay_container.size
	])
	print("   - Размер кнопки: %s" % size)


func _setup_container(container: Control):
	"""Настраивает контейнер - только устанавливает mouse_filter, не меняет позицию/размер"""
	if not container:
		return
	
	# ВАЖНО: контейнер должен ПРОПУСКАТЬ события мыши к кнопке
	# MOUSE_FILTER_IGNORE = события проходят через контейнер к кнопке
	# НЕ меняем позицию, размер или масштаб - они настроены в редакторе!
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Настраиваем TextureRect внутри контейнера - только mouse_filter
	var texture_rect = container.get_child(0) if container.get_child_count() > 0 else null
	if texture_rect and texture_rect is TextureRect:
		# TextureRect тоже должен пропускать события к кнопке
		# НЕ меняем позицию, размер, expand_mode или stretch_mode - они настроены в редакторе!
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("   ✅ Настроен TextureRect: %s (mouse_filter=IGNORE)" % texture_rect.name)
	else:
		print("   ⚠️  TextureRect не найден в контейнере %s" % container.name)


func _on_mouse_entered():
	"""Обработчик наведения мыши - показываем текстуру следующего состояния"""
	print("🖱️  [DEBUG] mouse_entered вызван")
	is_hovering = true
	_update_texture()
	print("🖱️  Hover: показываем следующее состояние")


func _on_mouse_exited():
	"""Обработчик ухода мыши - возвращаем текущую текстуру"""
	print("🖱️  [DEBUG] mouse_exited вызван")
	is_hovering = false
	_update_texture()
	print("🖱️  Hover убран: возвращаем текущее состояние")


func _on_pressed():
	"""Обработчик нажатия - переключаем состояние и уведомляем систему"""
	print("🖱️  [DEBUG] pressed вызван!")
	
	# Переключаем состояние
	is_pay_state = !is_pay_state
	
	# Сбрасываем hover при нажатии (мышь может быть еще на кнопке)
	is_hovering = false
	
	# Обновляем видимость контейнеров
	_update_texture()
	
	var state_name = "Оплатить" if is_pay_state else "Забрать"
	var mode_name = "PAY" if is_pay_state else "COLLECT"
	print("🔄 PayButton переключена: %s (режим %s)" % [state_name, mode_name])
	
	# Эмитим сигнал для ButtonUIManager
	state_changed.emit(is_pay_state)


func _update_texture():
	"""Обновляет видимость контейнеров в зависимости от состояния и hover"""
	if not take_container or not pay_container:
		print("⚠️  PayButton._update_texture: контейнеры не найдены!")
		return
	
	# НЕ меняем позицию, размер или масштаб - они настроены в редакторе!
	# Только управляем видимостью
	
	if is_hovering:
		# При наведении показываем текстуру следующего состояния
		if is_pay_state:
			# Сейчас Оплатить → показываем Забрать (на что переключимся)
			take_container.visible = true
			pay_container.visible = false
			print("   [DEBUG] Hover: показываем TakeContainer")
		else:
			# Сейчас Забрать → показываем Оплатить (на что переключимся)
			take_container.visible = false
			pay_container.visible = true
			print("   [DEBUG] Hover: показываем PayContainer")
	else:
		# Без наведения показываем текущее состояние
		if is_pay_state:
			# Режим PAY - показываем "Оплатить"
			take_container.visible = false
			pay_container.visible = true
			print("   [DEBUG] Нет hover: показываем PayContainer (PAY)")
		else:
			# Режим COLLECT - показываем "Забрать"
			take_container.visible = true
			pay_container.visible = false
			print("   [DEBUG] Нет hover: показываем TakeContainer (COLLECT)")


func set_state_take():
	"""Установить состояние 'Забрать' (режим COLLECT)"""
	var old_state = is_pay_state
	is_pay_state = false
	is_hovering = false
	_update_texture()
	
	# Эмитим сигнал только если состояние действительно изменилось
	if old_state != false:
		state_changed.emit(false)
		print("🔄 PayButton установлена в состояние: Забрать (COLLECT)")
	else:
		print("ℹ️  PayButton уже в состоянии: Забрать (COLLECT)")


func set_state_pay():
	"""Установить состояние 'Оплатить' (режим PAY)"""
	var old_state = is_pay_state
	is_pay_state = true
	is_hovering = false
	_update_texture()
	
	# Эмитим сигнал только если состояние действительно изменилось
	if old_state != true:
		state_changed.emit(true)
		print("🔄 PayButton установлена в состояние: Оплатить (PAY)")
	else:
		print("ℹ️  PayButton уже в состоянии: Оплатить (PAY)")


func get_current_state() -> String:
	"""Получить текущее состояние кнопки"""
	return "Оплатить" if is_pay_state else "Забрать"


func is_pay_mode() -> bool:
	"""Проверить, находится ли кнопка в режиме 'Оплатить'"""
	return is_pay_state


func is_take_mode() -> bool:
	"""Проверить, находится ли кнопка в режиме 'Забрать'"""
	return not is_pay_state


func sync_state():
	"""Принудительно синхронизировать состояние с системой (эмитить сигнал)"""
	# Эмитим сигнал с текущим состоянием для синхронизации
	state_changed.emit(is_pay_state)
	print("🔄 PayButton: синхронизация состояния (режим %s)" % ("PAY" if is_pay_state else "COLLECT"))




func ensure_initialized():
	"""Убедиться, что кнопка инициализирована (вызывается при показе кнопки)"""
	print("🔍 PayButton.ensure_initialized() вызван")
	
	if not take_container or not pay_container:
		print("⚠️  PayButton: контейнеры не найдены, пытаемся найти снова...")
		_find_child_nodes()
	
	# Убеждаемся, что контейнеры правильно настроены (только mouse_filter)
	if take_container:
		_setup_container(take_container)
	if pay_container:
		_setup_container(pay_container)
	
	# Обновляем видимость контейнеров
	_update_texture()
	
	print("✅ PayButton: проверка инициализации завершена")
	print("   - take_container: %s (visible=%s, position=%s, size=%s)" % [
		"найден" if take_container else "НЕ найден",
		take_container.visible if take_container else false,
		take_container.position if take_container else Vector2.ZERO,
		take_container.size if take_container else Vector2.ZERO
	])
	print("   - pay_container: %s (visible=%s, position=%s, size=%s)" % [
		"найден" if pay_container else "НЕ найден",
		pay_container.visible if pay_container else false,
		pay_container.position if pay_container else Vector2.ZERO,
		pay_container.size if pay_container else Vector2.ZERO
	])
	print("   - Текущее состояние: %s" % ("PAY" if is_pay_state else "COLLECT"))
	print("   - Кнопка видима: %s" % visible)
	print("   - Кнопка активна: %s" % (not disabled))
