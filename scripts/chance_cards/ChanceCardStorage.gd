# res://scripts/chance_cards/ChanceCardStorage.gd
# UI хранилища карт шанса с миниатюрами

class_name ChanceCardStorage
extends Control

# ═══════════════════════════════════════════════════════════════════════════
# УЗЛЫ
# ═══════════════════════════════════════════════════════════════════════════

@onready var cards_container: HBoxContainer = $CardsContainer

# ═══════════════════════════════════════════════════════════════════════════
# ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

## Словарь миниатюр карт по card_id
var card_miniatures: Dictionary = {}

## Позиция хранилища (для анимации)
var storage_position: Vector2 = Vector2.ZERO

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	if not cards_container:
		# Создаём контейнер если его нет
		cards_container = HBoxContainer.new()
		cards_container.name = "CardsContainer"
		add_child(cards_container)
	
	# Вычисляем позицию хранилища
	await get_tree().process_frame
	storage_position = global_position + size / 2

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Добавить миниатюру карты
func add_card_miniature(card: BaseChanceCard):
	if not card:
		return
	
	# Проверяем, не добавлена ли уже
	if card_miniatures.has(card.card_id):
		update_card_count(card.card_id, card.count)
		return
	
	var miniature_container: Control = null
	var button: TextureButton = null
	var counter_label: Label = null
	
	# Пытаемся найти узел в сцене (для heart_bet)
	var existing_miniature = cards_container.get_node_or_null("Miniature_" + card.card_id)
	if existing_miniature:
		# Используем узел из сцены
		miniature_container = existing_miniature as Control
		button = miniature_container.get_node_or_null("CardButton") as TextureButton
		counter_label = miniature_container.get_node_or_null("Counter") as Label
		
		if not button:
			push_warning("⚠️ ChanceCardStorage: CardButton не найден в сцене для %s" % card.card_id)
			return
		if not counter_label:
			push_warning("⚠️ ChanceCardStorage: Counter не найден в сцене для %s" % card.card_id)
			return
	else:
		# Создаём динамически для других карт
		miniature_container = Control.new()
		miniature_container.name = "Miniature_" + card.card_id
		miniature_container.custom_minimum_size = Vector2(50, 75)
		
		button = TextureButton.new()
		button.name = "CardButton"
		button.custom_minimum_size = Vector2(50, 75)
		button.size = Vector2(50, 75)  # Фиксированный размер
		button.ignore_texture_size = true  # ВАЖНО: игнорировать размер текстуры
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		# Не растягиваем кнопку - используем фиксированный размер
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		counter_label = Label.new()
		counter_label.name = "Counter"
		counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		counter_label.add_theme_font_size_override("font_size", 14)
		counter_label.add_theme_color_override("font_color", Color(1, 0.9, 0))
		counter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		counter_label.add_theme_constant_override("outline_size", 3)
		# Позиционируем счётчик внизу карты
		counter_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
		counter_label.offset_top = -18
		counter_label.offset_bottom = 0
		counter_label.offset_left = -10
		counter_label.offset_right = 10
		
		miniature_container.add_child(button)
		miniature_container.add_child(counter_label)
		cards_container.add_child(miniature_container)
	
	# Настраиваем кнопку
	button.texture_normal = card.card_texture
	if not button.pressed.is_connected(_on_miniature_clicked):
		button.pressed.connect(_on_miniature_clicked.bind(card.card_id))
	
	# Сохраняем ссылку
	card_miniatures[card.card_id] = {
		"container": miniature_container,
		"button": button,
		"counter": counter_label
	}
	
	# Обновляем счётчик
	update_card_count(card.card_id, card.count)

## Обновить счётчик карты
func update_card_count(card_id: String, count: int):
	if not card_miniatures.has(card_id):
		return
	
	var miniature = card_miniatures[card_id]
	var counter = miniature["counter"] as Label
	var button = miniature["button"] as TextureButton
	
	if counter:
		if count >= 1:
			counter.text = str(count)
			counter.visible = true
		else:
			counter.text = "0"
			counter.visible = true  # Счётчик всегда виден
	
	# Миниатюра ВСЕГДА видна (инвентарь)
	if miniature["container"]:
		miniature["container"].visible = true
	
	# Обновляем визуальное состояние кнопки
	if button:
		button.disabled = (count == 0)
		if count == 0:
			button.modulate = Color(0.4, 0.4, 0.4, 0.7)  # Затемнённая и полупрозрачная
		else:
			button.modulate = Color.WHITE

## Удалить миниатюру карты
func remove_card_miniature(card_id: String):
	if not card_miniatures.has(card_id):
		return
	
	var miniature = card_miniatures[card_id]
	if miniature["container"]:
		miniature["container"].queue_free()
	
	card_miniatures.erase(card_id)

## Получить позицию хранилища для карты (для анимации)
## Можно добавить смещение для точной настройки позиции
const STORAGE_POSITION_OFFSET: Vector2 = Vector2.ZERO

func get_storage_position_for_card(card_id: String) -> Vector2:
	var result_pos: Vector2 = Vector2.ZERO
	
	if not card_miniatures.has(card_id):
		# Если миниатюра ещё не создана, возвращаем центр хранилища
		result_pos = global_position + size / 2
	else:
		var miniature = card_miniatures[card_id]
		var container = miniature["container"] as Control
		if container:
			# Возвращаем центр миниатюры в глобальных координатах
			var button = miniature["button"] as TextureButton
			if button:
				result_pos = button.global_position + button.size / 2
			else:
				result_pos = container.global_position + container.size / 2
		else:
			# Fallback: центр хранилища
			result_pos = global_position + size / 2
	
	# Применяем смещение для настройки
	result_pos += STORAGE_POSITION_OFFSET
	
	return result_pos

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_miniature_clicked(card_id: String):
	"""Клик на миниатюру карты"""
	var card = ChanceCardManager.get_card(card_id)
	if not card:
		return
	
	# ВАЖНО: Разделяем логику "показать карту" и "использовать карту"
	# Показ карты всегда доступен - игрок должен видеть карту даже если её нельзя использовать
	# Использование будет заблокировано кнопкой "Использовать" если can_use() == false
	
	# Показываем информационное сообщение если нет доступных шансов, но всё равно показываем карту
	if card.count == 0:
		EventBus.show_toast_info.emit(Localization.t("NO_CHANCES_AVAILABLE"))
	
	# Запрашиваем показ на весь экран (всегда, независимо от can_use())
	# Кнопка "Использовать" будет скрыта если can_use() == false, а кнопка "Закрыть" будет показана
	EventBus.chance_card_storage_clicked.emit(card_id)
