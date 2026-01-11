# res://scripts/MainMenuScene.gd
# Главное меню - стартовый экран с вводом имени
# Загружает Game.tscn в фоне для быстрого перехода

extends Control
class_name MainMenuScene

## Путь к игровой сцене
const GAME_SCENE_PATH = "res://scenes/Game.tscn"

## Загружена ли игровая сцена
var game_scene_loaded: bool = false
var game_scene: PackedScene = null

## UI элементы
@onready var name_line_edit: LineEdit = find_child("NameLineEdit", true, false)
@onready var start_button: Button = find_child("StartButton", true, false)
@onready var loading_label: Label = find_child("LoadingLabel", true, false)

## Стили для кнопки (загружаем из сцены)
var start_button_active_style: StyleBoxFlat
var start_button_active_hover_style: StyleBoxFlat

func _ready() -> void:
	"""Инициализация главного меню"""
	# Загружаем язык
	var saved_lang = SaveManager.load_language()
	if Localization:
		Localization.set_lang(saved_lang)
	
	# Настраиваем UI
	if loading_label:
		# Фиксируем минимальную высоту, чтобы UI не съезжал
		loading_label.custom_minimum_size = Vector2(0, 30)
		# Используем modulate для скрытия, чтобы место оставалось зарезервированным
		loading_label.modulate.a = 0.0
	
	# Загружаем стили для активной кнопки
	_load_button_styles()
	
	if start_button:
		start_button.disabled = true  # Отключаем пока загружается
		start_button.pressed.connect(_on_start_pressed)
	
	if name_line_edit:
		# Загружаем сохранённое имя (если есть)
		var saved_name = _load_player_name()
		if saved_name:
			name_line_edit.text = saved_name
		# Подключаем Enter для быстрого старта
		name_line_edit.text_submitted.connect(_on_name_entered)
	
	# Начинаем загрузку игры в фоне
	_preload_game_scene()
	
	# Обновляем тексты (локализация)
	_update_texts()
	
	# Подписываемся на изменение языка
	if EventBus:
		EventBus.language_changed.connect(_on_language_changed)
	
	print("🎮 MainMenuScene готов")

func _update_texts() -> void:
	"""Обновить все тексты (локализация)"""
	if not Localization:
		return
	
	if start_button:
		start_button.text = Localization.t("MENU_START")
	if name_line_edit:
		name_line_edit.placeholder_text = Localization.t("MENU_ENTER_NAME")

func _preload_game_scene() -> void:
	"""Начинает фоновую загрузку игровой сцены"""
	print("⏳ Начинаем загрузку игры в фоне...")
	
	# Загружаем сцену в фоне (threaded loading)
	ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
	
	# Проверяем прогресс загрузки
	_check_loading_progress()

func _check_loading_progress() -> void:
	"""Проверяет прогресс загрузки игровой сцены"""
	var progress: Array[float] = []
	var status = ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			# Загрузка завершена
			game_scene = ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
			if game_scene:
				game_scene_loaded = true
				if start_button:
					start_button.disabled = false
					# Меняем стиль кнопки на жёлтый (активный)
					_activate_start_button()
				if loading_label:
					# Скрываем через modulate, чтобы место оставалось зарезервированным
					loading_label.modulate.a = 0.0
				print("✅ Игра загружена, можно начинать!")
			else:
				push_error("❌ Не удалось загрузить игровую сцену")
		
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Загрузка в процессе
			var progress_percent = progress[0] * 100.0
			if loading_label and Localization:
				loading_label.text = Localization.t("MENU_LOADING_PERCENT") % int(progress_percent)
				# Показываем через modulate
				loading_label.modulate.a = 1.0
			
			# Повторяем проверку через кадр
			await get_tree().process_frame
			_check_loading_progress()
		
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("❌ Неверный путь к игровой сцене: %s" % GAME_SCENE_PATH)
		
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("❌ Ошибка загрузки игровой сцены: %s" % GAME_SCENE_PATH)

func _on_start_pressed() -> void:
	"""Обработка нажатия кнопки 'Начать'"""
	if not game_scene_loaded:
		return  # Игра ещё не загружена
	
	# Сохраняем имя игрока (если введено)
	var player_name = name_line_edit.text.strip_edges()
	if not player_name.is_empty():
		_save_player_name(player_name)
	
	# Загружаем игру
	_load_game()

func _on_name_entered(_text: String) -> void:
	"""Обработка нажатия Enter в поле имени"""
	if start_button and not start_button.disabled:
		_on_start_pressed()

func _on_language_changed(_lang: String) -> void:
	"""Обработка изменения языка"""
	_update_texts()

func _load_game() -> void:
	"""Загрузить игровую сцену"""
	if game_scene_loaded and game_scene:
		# Переключаемся на уже загруженную сцену (быстро!)
		print("🎮 Переход в игру...")
		get_tree().change_scene_to_packed(game_scene)
	else:
		# Фолбэк: загрузка синхронно (если что-то пошло не так)
		print("⚠️ Загрузка синхронно...")
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

# ═══════════════════════════════════════════════════════════════════════════
# СОХРАНЕНИЕ ИМЕНИ ИГРОКА
# ═══════════════════════════════════════════════════════════════════════════

func _save_player_name(player_name: String) -> void:
	"""Сохранить имя игрока"""
	var file = FileAccess.open("user://player_name.save", FileAccess.WRITE)
	if file:
		file.store_string(player_name)
		file.close()
		print("💾 Имя игрока сохранено: %s" % player_name)

func _load_player_name() -> String:
	"""Загрузить имя игрока"""
	if FileAccess.file_exists("user://player_name.save"):
		var file = FileAccess.open("user://player_name.save", FileAccess.READ)
		if file:
			var player_name = file.get_as_text().strip_edges()
			file.close()
			return player_name
	return ""

func _load_button_styles() -> void:
	"""Загрузить стили для активной кнопки"""
	# Создаём стили программно (желтые, как guest_button)
	start_button_active_style = StyleBoxFlat.new()
	start_button_active_style.bg_color = Color(0.4, 0.3, 0.15, 1)
	start_button_active_style.border_width_left = 3
	start_button_active_style.border_width_top = 3
	start_button_active_style.border_width_right = 3
	start_button_active_style.border_width_bottom = 3
	start_button_active_style.border_color = Color(0.8, 0.65, 0.3, 1)
	start_button_active_style.corner_radius_top_left = 10
	start_button_active_style.corner_radius_top_right = 10
	start_button_active_style.corner_radius_bottom_right = 10
	start_button_active_style.corner_radius_bottom_left = 10
	start_button_active_style.shadow_color = Color(0.6, 0.5, 0.2, 0.6)
	start_button_active_style.shadow_size = 6
	start_button_active_style.shadow_offset = Vector2(0, 3)
	
	start_button_active_hover_style = StyleBoxFlat.new()
	start_button_active_hover_style.bg_color = Color(0.5, 0.4, 0.2, 1)
	start_button_active_hover_style.border_width_left = 3
	start_button_active_hover_style.border_width_top = 3
	start_button_active_hover_style.border_width_right = 3
	start_button_active_hover_style.border_width_bottom = 3
	start_button_active_hover_style.border_color = Color(1, 0.8, 0.4, 1)
	start_button_active_hover_style.corner_radius_top_left = 10
	start_button_active_hover_style.corner_radius_top_right = 10
	start_button_active_hover_style.corner_radius_bottom_right = 10
	start_button_active_hover_style.corner_radius_bottom_left = 10
	start_button_active_hover_style.shadow_color = Color(0.8, 0.65, 0.3, 0.8)
	start_button_active_hover_style.shadow_size = 8
	start_button_active_hover_style.shadow_offset = Vector2(0, 4)

func _activate_start_button() -> void:
	"""Активировать кнопку (сделать жёлтой)"""
	if start_button and start_button_active_style and start_button_active_hover_style:
		start_button.add_theme_stylebox_override("normal", start_button_active_style)
		start_button.add_theme_stylebox_override("hover", start_button_active_hover_style)
		start_button.add_theme_stylebox_override("pressed", start_button_active_style)
