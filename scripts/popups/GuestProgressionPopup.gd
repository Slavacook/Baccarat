# res://scripts/popups/GuestProgressionPopup.gd
# Попап для настройки порогов прогрессии гостей

extends PopupPanel

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@onready var title_label: Label = find_child("TitleLabel", true, false)
@onready var table_container: VBoxContainer = find_child("TableContainer", true, false)
@onready var auto_mode_checkbox: CheckBox = find_child("AutoModeCheckbox", true, false)
@onready var ok_button: Button = find_child("ButtonOk", true, false)

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Ссылки на SpinBox'ы для порогов {количество_гостей: SpinBox}
var threshold_spinboxes: Dictionary = {}

## Текущие пороги (копия для редактирования)
var current_thresholds: Dictionary = {}

## Текущее состояние автоматического режима
var current_auto_mode: bool = true

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	"""Инициализация попапа"""
	# Скрыть при старте
	hide()
	
	# Подписаться на изменение языка
	if EventBus:
		EventBus.language_changed.connect(_on_language_changed)
	
	# Инициализировать таблицу (найти существующие SpinBox'ы или создать)
	_initialize_table()
	
	# Подключить сигналы кнопок и SpinBox'ов (после инициализации таблицы)
	_connect_signals()
	
	# Обновить тексты
	_update_texts()

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func open_popup():
	"""Открыть попап настроек прогрессии"""
	if not GuestProgressionManager:
		push_error("GuestProgressionPopup: GuestProgressionManager не найден")
		return
	
	# Загрузить текущие пороги из GuestProgressionManager
	# Создаём копию словаря, чтобы можно было редактировать
	var loaded_thresholds = GuestProgressionManager.get_thresholds()
	current_thresholds = {}
	for key in loaded_thresholds.keys():
		current_thresholds[key] = loaded_thresholds[key]
	
	# Убеждаемся, что порог для 1 гостя всегда равен 0 (по умолчанию)
	if not current_thresholds.has(1):
		current_thresholds[1] = 0
	
	# Загрузить состояние режима
	current_auto_mode = GuestProgressionManager.is_auto_mode_enabled()
	
	# Обновить UI (таблица, чекбокс)
	_update_table()
	if auto_mode_checkbox:
		auto_mode_checkbox.button_pressed = current_auto_mode
	
	# Устанавливаем размер попапа перед открытием
	# Убеждаемся, что попап имеет правильный размер
	var popup_size = Vector2i(600, 500)
	size = popup_size
	
	# Ждём кадр, чтобы размер применился
	await get_tree().process_frame
	
	# Открываем попап по центру экрана с указанным размером
	popup_centered(popup_size)
	
	# Убеждаемся, что попап виден и правильно позиционирован
	if position.x < 0 or position.y < 0:
		# Если позиция некорректна, центрируем вручную
		var viewport_size = get_viewport().get_visible_rect().size
		position = (viewport_size - popup_size) / 2
	
	print("🎯 Попап прогрессии гостей открыт (размер: %s, позиция: %s)" % [size, position])

func close_popup():
	"""Закрыть попап"""
	hide()

# ═══════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ UI
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_table() -> void:
	"""Инициализировать таблицу порогов (найти существующие SpinBox'ы или создать)"""
	if not table_container:
		push_error("GuestProgressionPopup: TableContainer не найден")
		return
	
	# Ищем существующие SpinBox'ы в контейнере (если они созданы в сцене)
	_find_existing_spinboxes()
	
	# Если SpinBox'ы не найдены - создаём их программно
	if threshold_spinboxes.is_empty():
		_create_table_programmatically()

func _find_existing_spinboxes() -> void:
	"""Найти существующие SpinBox'ы в table_container (созданные в сцене)"""
	threshold_spinboxes.clear()
	
	# Ищем SpinBox'ы для гостей 2-6 (пропускаем 1 гость - это по умолчанию)
	for i in range(2, 7):  # 2, 3, 4, 5, 6
		# Попробуем разные варианты имён
		var spinbox = table_container.find_child("SpinBox%d" % i, true, false) as SpinBox
		if not spinbox:
			spinbox = table_container.find_child("ThresholdSpinBox%d" % i, true, false) as SpinBox
		if not spinbox:
			spinbox = table_container.find_child("Guest%dSpinBox" % i, true, false) as SpinBox
		
		if spinbox:
			# Сохраняем guest_count в метаданных для последующей идентификации
			spinbox.set_meta("guest_count", i)
			threshold_spinboxes[i] = spinbox
			print("🎯 Найден SpinBox для гостя %d" % i)

func _create_table_programmatically() -> void:
	"""Создать таблицу порогов программно (если не создана в сцене)"""
	if not table_container:
		return
	
	# Очищаем контейнер
	for child in table_container.get_children():
		child.queue_free()
	
	# Создаём заголовок таблицы
	var header_row = HBoxContainer.new()
	header_row.name = "HeaderRow"
	table_container.add_child(header_row)
	
	var header_count_label = Label.new()
	header_count_label.name = "HeaderCountLabel"
	header_count_label.text = Localization.t("GUEST_COUNT_COLUMN") if Localization else "Количество гостей"
	header_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_count_label)
	
	var header_tips_label = Label.new()
	header_tips_label.name = "HeaderTipsLabel"
	header_tips_label.text = Localization.t("TIPS_THRESHOLD_COLUMN") if Localization else "Чаевые"
	header_tips_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_tips_label)
	
	# Создаём строки только для порогов 2-6 (5 строк)
	# Порог для 1 гостя (0 чаевых) не показываем - это по умолчанию
	for guest_count in range(2, 7):  # 2, 3, 4, 5, 6
		var row = HBoxContainer.new()
		row.name = "Row%d" % guest_count
		table_container.add_child(row)
		
		# Label с количеством гостей
		var count_label = Label.new()
		count_label.name = "CountLabel%d" % guest_count
		count_label.text = str(guest_count)
		count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(count_label)
		
		# SpinBox для порога
		var spinbox = SpinBox.new()
		spinbox.name = "SpinBox%d" % guest_count
		spinbox.min_value = 0
		spinbox.max_value = 999999
		spinbox.step = 10
		spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spinbox.set_meta("guest_count", guest_count)  # Сохраняем guest_count в метаданных
		row.add_child(spinbox)
		
		threshold_spinboxes[guest_count] = spinbox
		print("🎯 Создан SpinBox для гостя %d" % guest_count)

func _update_table() -> void:
	"""Обновить значения в таблице на основе current_thresholds"""
	# Обновляем только строки для гостей 2-6 (пропускаем 1 гость)
	for guest_count in range(2, 7):  # 2, 3, 4, 5, 6
		if threshold_spinboxes.has(guest_count):
			var spinbox = threshold_spinboxes[guest_count]
			if spinbox:
				# Временно отключаем все подключённые сигналы для этого SpinBox
				if spinbox.value_changed.get_connections().size() > 0:
					# Получаем список подключений и отключаем все
					var connections = spinbox.value_changed.get_connections()
					for connection in connections:
						if connection.callable.is_valid():
							spinbox.value_changed.disconnect(connection.callable)
				
				var threshold = current_thresholds.get(guest_count, 0)
				spinbox.value = threshold
				
				# Подключаем сигнал - guest_count будет определен по самому SpinBox
				spinbox.value_changed.connect(_on_threshold_changed)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	"""Подключить сигналы кнопок и SpinBox'ов"""
	# Кнопка ОК
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	
	# Чекбокс автоматического режима
	if auto_mode_checkbox:
		auto_mode_checkbox.toggled.connect(_on_auto_mode_toggled)
	
	# SpinBox'ы для порогов (подключаем сигналы для автосохранения)
	# Подключаем только для гостей 2-6
	for guest_count in range(2, 7):  # 2, 3, 4, 5, 6
		if threshold_spinboxes.has(guest_count):
			var spinbox = threshold_spinboxes[guest_count]
			if spinbox:
				# Проверяем, подключён ли уже сигнал
				if spinbox.value_changed.get_connections().size() == 0:
					spinbox.value_changed.connect(_on_threshold_changed)

func _on_ok_pressed() -> void:
	"""Обработчик нажатия кнопки "ОК" - просто закрывает попап"""
	close_popup()

func _on_auto_mode_toggled(pressed: bool) -> void:
	"""Обработчик переключения автоматического режима (с автосохранением)"""
	current_auto_mode = pressed
	
	# Сохраняем состояние автоматического режима сразу
	if GuestProgressionManager:
		GuestProgressionManager.set_auto_mode(pressed)
	
	# (Опционально) делаем SpinBox'ы доступными/недоступными
	_update_spinboxes_editable(pressed)

func _on_threshold_changed(value: float) -> void:
	"""Обработчик изменения порога в SpinBox (с автосохранением)
	
	Args:
		value: Новое значение порога
	"""
	# Определяем, какой SpinBox вызвал сигнал, используя метаданные
	# Проходим по SpinBox'ам для гостей 2-6 (только эти в таблице)
	var changed_guest_count = -1
	for guest_count in range(2, 7):  # 2, 3, 4, 5, 6
		if threshold_spinboxes.has(guest_count):
			var spinbox = threshold_spinboxes[guest_count]
			if spinbox and abs(spinbox.value - value) < 0.01:  # Учитываем погрешность float
				# Дополнительно проверяем метаданные для уверенности
				if spinbox.has_meta("guest_count"):
					var meta_count = spinbox.get_meta("guest_count")
					if meta_count == guest_count:
						changed_guest_count = guest_count
						break
	
	# Если не удалось определить точно, используем SpinBox с фокусом
	if changed_guest_count == -1:
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused.has_meta("guest_count"):
			changed_guest_count = focused.get_meta("guest_count")
	
	if changed_guest_count > 0:
		# Обновляем текущие пороги
		current_thresholds[changed_guest_count] = int(value)
		
		# Убеждаемся, что порог для 1 гостя всегда равен 0
		if not current_thresholds.has(1):
			current_thresholds[1] = 0
		
		# Создаём словарь только с порогами для 2-6 для сохранения
		var thresholds_to_save = {}
		for key in range(2, 7):
			if current_thresholds.has(key):
				thresholds_to_save[key] = current_thresholds[key]
		
		# Сохраняем пороги сразу
		if GuestProgressionManager:
			GuestProgressionManager.set_thresholds(thresholds_to_save)
		
		print("🎯 Порог для %d гостей изменён на %d" % [changed_guest_count, int(value)])

func _update_spinboxes_editable(enabled: bool) -> void:
	"""Обновить доступность редактирования SpinBox'ов"""
	for guest_count in threshold_spinboxes.keys():
		var spinbox = threshold_spinboxes[guest_count]
		if spinbox:
			spinbox.editable = enabled

func _on_language_changed(_lang: String) -> void:
	"""Обработчик изменения языка"""
	_update_texts()

# ═══════════════════════════════════════════════════════════════════════════
# ЛОКАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _update_texts() -> void:
	"""Обновить тексты UI элементов"""
	if not Localization:
		return
	
	# Заголовок
	if title_label:
		title_label.text = Localization.t("GUEST_PROGRESSION_TITLE")
	
	# Чекбокс автоматического режима
	if auto_mode_checkbox:
		auto_mode_checkbox.text = Localization.t("GUEST_PROGRESSION_AUTO_MODE")
	
	# Кнопка ОК
	if ok_button:
		ok_button.text = Localization.t("CLOSE")
