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
	
	print("🎴 ChanceCardStorage готов (позиция: %s)" % storage_position)

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
	
	# Создаём контейнер для миниатюры
	var miniature_container = VBoxContainer.new()
	miniature_container.name = "Miniature_" + card.card_id
	
	# Кнопка с текстурой карты
	var button = TextureButton.new()
	button.name = "CardButton"
	button.custom_minimum_size = Vector2(80, 120)
	button.texture_normal = card.card_texture
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.pressed.connect(_on_miniature_clicked.bind(card.card_id))
	
	# Счётчик
	var counter_label = Label.new()
	counter_label.name = "Counter"
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_label.add_theme_font_size_override("font_size", 16)
	counter_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
	counter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	counter_label.add_theme_constant_override("outline_size", 2)
	
	# Добавляем в контейнер
	miniature_container.add_child(button)
	miniature_container.add_child(counter_label)
	cards_container.add_child(miniature_container)
	
	# Сохраняем ссылку
	card_miniatures[card.card_id] = {
		"container": miniature_container,
		"button": button,
		"counter": counter_label
	}
	
	# Обновляем счётчик
	update_card_count(card.card_id, card.count)
	
	print("🎴 Миниатюра добавлена: %s" % card.card_id)

## Обновить счётчик карты
func update_card_count(card_id: String, count: int):
	if not card_miniatures.has(card_id):
		return
	
	var miniature = card_miniatures[card_id]
	var counter = miniature["counter"] as Label
	var button = miniature["button"] as TextureButton
	
	if counter:
		if count > 1:
			counter.text = str(count)
			counter.visible = true
		else:
			counter.text = ""
			counter.visible = false
	
	# Обновляем видимость миниатюры
	if miniature["container"]:
		miniature["container"].visible = (count > 0)
	
	# Обновляем доступность кнопки
	if button:
		button.disabled = (count == 0)
		if count == 0:
			button.modulate = Color(0.5, 0.5, 0.5, 1.0)
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
	print("🎴 Миниатюра удалена: %s" % card_id)

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
	
	# Отладочная информация
	print("🎴 ChanceCardStorage.get_storage_position_for_card(%s):" % card_id)
	print("   base_pos: %s" % (result_pos - STORAGE_POSITION_OFFSET))
	print("   STORAGE_POSITION_OFFSET: %s" % STORAGE_POSITION_OFFSET)
	print("   final_pos: %s" % result_pos)
	
	return result_pos

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_miniature_clicked(card_id: String):
	"""Клик на миниатюру карты"""
	var card = ChanceCardManager.get_card(card_id)
	if not card:
		return
	
	# Проверяем доступность
	if card.count == 0:
		EventBus.show_toast_info.emit(Localization.t("NO_CHANCES_AVAILABLE"))
		return
	
	# Запрашиваем показ на весь экран
	EventBus.chance_card_storage_clicked.emit(card_id)
	print("🎴 Клик на миниатюру: %s" % card_id)
