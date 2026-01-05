# res://scripts/utils/CardController.gd
# Контроллер для управления отображением карт
# Инкапсулирует работу с flip_cards и card_nodes
# Extract Class - извлечено из GameController

extends RefCounted
class_name CardController

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ (передаются извне)
# ═══════════════════════════════════════════════════════════════════════════

var flip_cards: Array = []  # Массив FlipCard для анимаций переворота
var card_nodes: Array = []  # Массив TextureRect для отображения карт
var scene_tree: SceneTree  # Для await create_timer

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(p_flip_cards: Array = [], p_card_nodes: Array = [], p_scene_tree: SceneTree = null):
	flip_cards = p_flip_cards
	card_nodes = p_card_nodes
	scene_tree = p_scene_tree

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКА
# ═══════════════════════════════════════════════════════════════════════════

func set_flip_cards(cards: Array) -> void:
	"""Установить массив анимаций переворота карт"""
	flip_cards = cards

func set_card_nodes(nodes: Array) -> void:
	"""Установить массив узлов для отображения карт"""
	card_nodes = nodes

func set_scene_tree(tree: SceneTree) -> void:
	"""Установить SceneTree для await create_timer"""
	scene_tree = tree

# ═══════════════════════════════════════════════════════════════════════════
# УПРАВЛЕНИЕ КАРТАМИ
# ═══════════════════════════════════════════════════════════════════════════

func show_all_backs(back_texture: Texture2D) -> void:
	"""Показать рубашки всех карт"""
	for card in flip_cards:
		if card and card.has_method("show_back"):
			card.show_back(back_texture)

func open_all_cards(face_textures: Array, delay: float = GameConstants.FLIP_CARD_DELAY) -> void:
	"""Открыть все карты с задержкой
	
	Args:
		face_textures: Массив текстур карт для отображения
		delay: Задержка между открытием карт (по умолчанию из GameConstants)
	"""
	if not scene_tree:
		print("⚠️  CardController: scene_tree не установлен, нельзя использовать await")
		return
	
	for i in range(min(face_textures.size(), flip_cards.size())):
		await scene_tree.create_timer(i * delay).timeout
		if flip_cards[i] and flip_cards[i].has_method("open_card"):
			flip_cards[i].open_card(face_textures[i])

func open_all_cards_with_flip(face_textures: Array, delay: float = GameConstants.FLIP_CARD_DELAY) -> void:
	"""Открыть все карты с flip-анимацией
	
	Args:
		face_textures: Массив текстур карт для отображения
		delay: Задержка между картами (по умолчанию из GameConstants)
	"""
	if not scene_tree:
		print("⚠️  CardController: scene_tree не установлен, нельзя использовать await")
		return
	
	for i in range(min(face_textures.size(), flip_cards.size(), card_nodes.size())):
		# Запустить анимацию flip
		if flip_cards[i] and flip_cards[i].has_method("play_flip"):
			flip_cards[i].play_flip()
		
		# Подождать, пока проиграется flip
		await scene_tree.create_timer(delay).timeout
		
		# Показать открытую карту
		if card_nodes[i]:
			card_nodes[i].texture = face_textures[i]

func open_two_third_cards(texture1: Texture2D, texture2: Texture2D) -> void:
	"""Открыть две третьи карты (Player и Banker)
	
	Args:
		texture1: Текстура первой третьей карты (индекс 4)
		texture2: Текстура второй третьей карты (индекс 5)
	"""
	if flip_cards.size() > 4 and flip_cards[4] and flip_cards[4].has_method("open_card"):
		flip_cards[4].open_card(texture1)
	if flip_cards.size() > 5 and flip_cards[5] and flip_cards[5].has_method("open_card"):
		flip_cards[5].open_card(texture2)

func reset_cards(back_texture: Texture2D) -> void:
	"""Сбросить все карты (показать рубашки)
	
	Args:
		back_texture: Текстура рубашки карты
	"""
	show_all_backs(back_texture)

