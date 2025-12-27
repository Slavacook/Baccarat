# res://scripts/ui/GuestMenuUIRenderer.gd
# Рендерер UI для меню гостей
# Инкапсулирует логику отображения UI-элементов (видимость, прозрачность)

extends RefCounted
class_name GuestMenuUIRenderer

# ═══════════════════════════════════════════════════════════════════════════
# UI УЗЛЫ (передаются извне при инициализации)
# ═══════════════════════════════════════════════════════════════════════════

var ghost_textures: Array[TextureRect] = []
var guest_textures: Array[TextureRect] = []
var hover_glow_textures: Array[TextureRect] = []
var dossier_textures: Array[TextureRect] = []

# Общие кнопки для настройки выбранного гостя
var character_option: OptionButton = null
var wealth_option: OptionButton = null

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	p_ghost_textures: Array[TextureRect],
	p_guest_textures: Array[TextureRect],
	p_hover_glow_textures: Array[TextureRect],
	p_dossier_textures: Array[TextureRect],
	p_character_option: OptionButton = null,
	p_wealth_option: OptionButton = null
):
	ghost_textures = p_ghost_textures
	guest_textures = p_guest_textures
	hover_glow_textures = p_hover_glow_textures
	dossier_textures = p_dossier_textures
	character_option = p_character_option
	wealth_option = p_wealth_option

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func update_guest_visibility(guest_id: int, visual_state: GuestUIVisualState) -> void:
	"""Обновить видимость одного гостя на основе визуального состояния"""
	var index = guest_id - 1
	if index < 0 or index >= 6:
		return
	
	_update_ghost_visibility(index, visual_state)
	_update_guest_texture_visibility(index, visual_state)
	_update_hover_glow_visibility(index, visual_state)
	_update_dossier_visibility(index, visual_state)

func update_all_guests_visibility(visual_states: Array[GuestUIVisualState]) -> void:
	"""Обновить видимость всех гостей"""
	for guest_id in range(1, 7):
		var index = guest_id - 1
		if index < visual_states.size():
			update_guest_visibility(guest_id, visual_states[index])

func update_common_buttons_visibility(has_selected_enabled_guest: bool) -> void:
	"""Обновить видимость общих кнопок (видны только если есть выбранный включённый гость)"""
	if character_option:
		character_option.visible = has_selected_enabled_guest
	
	if wealth_option:
		wealth_option.visible = has_selected_enabled_guest

# ═══════════════════════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func _update_ghost_visibility(index: int, visual_state: GuestUIVisualState) -> void:
	"""Обновить видимость и прозрачность призрака"""
	if index < 0 or index >= ghost_textures.size():
		return
	
	var ghost_texture = ghost_textures[index]
	if not ghost_texture:
		return
	
	# Призрак: виден если гость выключен ИЛИ если гость включён и выбран (для эффекта свечения)
	ghost_texture.visible = visual_state.should_show_ghost()
	
	# Прозрачность: 25% если выключен, 100% если выбран (для эффекта свечения)
	ghost_texture.modulate.a = visual_state.get_ghost_alpha()

func _update_guest_texture_visibility(index: int, visual_state: GuestUIVisualState) -> void:
	"""Обновить видимость материального гостя"""
	if index < 0 or index >= guest_textures.size():
		return
	
	var guest_texture = guest_textures[index]
	if not guest_texture:
		return
	
	# Материальный гость: виден если гость включён
	guest_texture.visible = visual_state.should_show_guest()

func _update_hover_glow_visibility(index: int, visual_state: GuestUIVisualState) -> void:
	"""Обновить видимость hover свечения"""
	if index < 0 or index >= hover_glow_textures.size():
		return
	
	var hover_glow_texture = hover_glow_textures[index]
	if not hover_glow_texture:
		return
	
	# Hover свечение: видно если наведён курсор ИЛИ есть фокус клавиатуры
	hover_glow_texture.visible = visual_state.should_show_hover_glow()

func _update_dossier_visibility(index: int, visual_state: GuestUIVisualState) -> void:
	"""Обновить видимость досье"""
	if index < 0 or index >= dossier_textures.size():
		return
	
	var dossier_texture = dossier_textures[index]
	if not dossier_texture:
		return
	
	# Досье: видно только для выбранного включённого гостя
	dossier_texture.visible = visual_state.should_show_dossier()
