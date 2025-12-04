# res://scripts/ui/CardUIManager.gd
# Специализированный менеджер для управления картами и их анимациями
# Часть декомпозиции UIManager (Phase 2)

class_name CardUIManager
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

var player_card1: TextureRect
var player_card2: TextureRect
var player_card3: TextureRect
var banker_card1: TextureRect
var banker_card2: TextureRect
var banker_card3: TextureRect

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

var flip_cards = []  # Массив анимаций FlipCard
var main_node = null  # Node для await tree.create_timer()

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var card_manager: CardTextureManager  # Для получения текстур карт

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТРУКТОР (Dependency Injection)
# ═══════════════════════════════════════════════════════════════════════════

func _init(scene: Node, cm: CardTextureManager):
	"""Инициализация менеджера карт

	Args:
		scene: Корневой узел сцены Game.tscn
		cm: CardTextureManager для загрузки текстур
	"""
	card_manager = cm

	# Получаем ссылки на UI узлы карт
	player_card1 = scene.get_node("PlayerZone/Card1")
	player_card2 = scene.get_node("PlayerZone/Card2")
	player_card3 = scene.get_node("PlayerZone/Card3")
	banker_card1 = scene.get_node("BankerZone/Card1")
	banker_card2 = scene.get_node("BankerZone/Card2")
	banker_card3 = scene.get_node("BankerZone/Card3")

# ═══════════════════════════════════════════════════════════════════════════
# СЕТТЕРЫ ДЛЯ ЗАВИСИМОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func set_flip_cards(cards):
	"""Установить массив анимаций переворота карт"""
	flip_cards = cards

func set_main_node(node):
	"""Установить главный узел для await"""
	main_node = node

# ═══════════════════════════════════════════════════════════════════════════
# РАЗДАЧА КАРТ С АНИМАЦИЕЙ
# ═══════════════════════════════════════════════════════════════════════════

func show_first_four_cards(player_hand: Array[Card], banker_hand: Array[Card]):
	"""Анимация раздачи первых четырёх карт (2 игроку, 2 банкиру)

	Последовательность:
	1. Player Card 1 → flip animation → show card
	2. Player Card 2 → flip animation → show card
	3. Banker Card 1 → flip animation → show card
	4. Banker Card 2 → flip animation → show card

	Задержка между картами: GameConstants.FLIP_CARD_DELAY
	"""
	# ← Карта 1 игрока
	player_card1.visible = false
	flip_cards[0].visible = true
	flip_cards[0].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	player_card1.texture = player_hand[0].get_texture(card_manager)
	player_card1.visible = true
	flip_cards[0].visible = false

	# ← Карта 2 игрока
	player_card2.visible = false
	flip_cards[1].visible = true
	flip_cards[1].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	player_card2.texture = player_hand[1].get_texture(card_manager)
	player_card2.visible = true
	flip_cards[1].visible = false

	# ← Карта 1 банкира
	banker_card1.visible = false
	flip_cards[2].visible = true
	flip_cards[2].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	banker_card1.texture = banker_hand[0].get_texture(card_manager)
	banker_card1.visible = true
	flip_cards[2].visible = false

	# ← Карта 2 банкира
	banker_card2.visible = false
	flip_cards[3].visible = true
	flip_cards[3].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	banker_card2.texture = banker_hand[1].get_texture(card_manager)
	banker_card2.visible = true
	flip_cards[3].visible = false


func show_player_third_card(card: Card):
	"""Анимация раздачи третьей карты игроку"""
	player_card3.visible = false
	flip_cards[4].visible = true
	flip_cards[4].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	player_card3.texture = card.get_texture(card_manager)
	player_card3.visible = true
	flip_cards[4].visible = false


func show_banker_third_card(card: Card):
	"""Анимация раздачи третьей карты банкиру"""
	banker_card3.visible = false
	flip_cards[5].visible = true
	flip_cards[5].play_flip()
	await main_node.get_tree().create_timer(GameConstants.FLIP_CARD_DELAY).timeout
	banker_card3.texture = card.get_texture(card_manager)
	banker_card3.visible = true
	flip_cards[5].visible = false

# ═══════════════════════════════════════════════════════════════════════════
# СБРОС И ИНИЦИАЛИЗАЦИЯ КАРТ
# ═══════════════════════════════════════════════════════════════════════════

func reset_cards():
	"""Сброс карт к начальному состоянию (рубашки)"""
	_hide_all_cards()
	_show_initial_backs()


func _hide_all_cards():
	"""Скрыть все карты (включая третьи)"""
	player_card1.visible = false
	player_card2.visible = false
	player_card3.visible = false
	banker_card1.visible = false
	banker_card2.visible = false
	banker_card3.visible = false


func _show_initial_backs():
	"""Показать рубашки для первых четырёх карт"""
	var back = card_manager.get_back_texture()
	player_card1.texture = back
	player_card2.texture = back
	banker_card1.texture = back
	banker_card2.texture = back
	player_card1.visible = true
	player_card2.visible = true
	banker_card1.visible = true
	banker_card2.visible = true
