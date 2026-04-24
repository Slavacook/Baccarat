# res://scripts/utils/UIEventHandler.gd
# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИК UI СОБЫТИЙ
# 
# Отвечает за:
# - Обработку событий от UI элементов (кнопки, переключатели)
# - Управление видимостью UI элементов игры
# - Обработку подтверждения выплат (старый метод)
# ═══════════════════════════════════════════════════════════════════════════

class_name UIEventHandler
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════

var ui_manager: UIManager
var phase_manager: GamePhaseManager
var crib_sheet_scene: CribSheetScene
var survival_state: SurvivalStateProvider
var owner_node: Node  # Узел для доступа к дочерним элементам
var _pay_button_was_visible_before_settings: bool = false
var _collect_button_was_visible_before_settings: bool = false

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _init(
	ui_mgr: UIManager,
	phase_mgr: GamePhaseManager,
	crib_sheet: CribSheetScene,
	survival: SurvivalStateProvider,
	owner: Node
) -> void:
	"""Инициализировать обработчик UI событий
	
	Args:
		ui_mgr: Менеджер UI
		phase_mgr: Менеджер фаз игры
		crib_sheet: Сцена шпаргалки
		survival: Провайдер состояния выживания
		owner: Узел-владелец для доступа к дочерним элементам
	"""
	ui_manager = ui_mgr
	phase_manager = phase_mgr
	crib_sheet_scene = crib_sheet
	survival_state = survival
	owner_node = owner

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

func on_help_button_pressed() -> void:
	"""Обработчик нажатия кнопки помощи - открывает шпаргалку
	
	Открывает CribSheetScene для отображения правил игры.
	Сбрасывает фокус с кнопки, чтобы пробел не активировал её повторно.
	"""
	# Открываем шпаргалку вместо старого help_popup
	if not crib_sheet_scene:
		push_error("CribSheetScene: шпаргалка не инициализирована")
		return
	
	# Проверяем, что сцена валидна
	if not is_instance_valid(crib_sheet_scene):
		push_error("CribSheetScene: сцена не валидна")
		return
	
	# Сбрасываем фокус с кнопки, чтобы пробел не активировал её
	if ui_manager and ui_manager.help_button:
		ui_manager.help_button.release_focus()
	# Также сбрасываем фокус со всего viewport
	if owner_node.get_viewport():
		owner_node.get_viewport().gui_release_focus()
	
	# Вызываем метод открытия
	crib_sheet_scene.show_cribsheet()

func on_lang_button_pressed() -> void:
	"""Обработчик нажатия кнопки переключения языка
	
	Переключает язык между русским и английским.
	Обновляет все UI элементы, включая кнопки и toggles третьих карт.
	"""
	var new_lang = GameConstants.LANG_EN if Localization.get_lang() == GameConstants.LANG_RU else GameConstants.LANG_RU
	Localization.set_lang(new_lang)
	if ui_manager:
		ui_manager.update_lang_button()
		ui_manager.update_action_button(Localization.t("ACTION_BUTTON_CARDS"))
		# Обновление toggles третьих карт (если видимы)
		if ui_manager.player_third_toggle.visible:
			var state = "!" if phase_manager.player_third_selected else "?"
			ui_manager.update_player_third_card_ui(state)
		if ui_manager.banker_third_toggle.visible:
			var state = "!" if phase_manager.banker_third_selected else "?"
			ui_manager.update_banker_third_card_ui(state)
		# Обновление текста кнопок collect/pay
		if ui_manager.button_ui:
			ui_manager.button_ui.update_collect_pay_buttons_text()

func on_payout_confirmed(is_correct: bool, collected: float, expected: float) -> void:
	"""Обработчик подтверждения выплаты (старый метод, для обратной совместимости)
	
	Args:
		is_correct: Правильно ли рассчитана выплата
		collected: Собранная сумма
		expected: Ожидаемая сумма
	
	Примечание: Для старого метода нет информации о bet_type/position_index.
	Передаются пустые значения - StatsManager пропустит такие случаи.
	"""
	if is_correct:
		# Для старого метода нет информации о bet_type/position_index
		# Передаем пустые значения - StatsManager пропустит такие случаи
		EventBus.payout_correct.emit(collected, expected, "", -1)
		DebugLogger.log("✅ Правильно! Выплата: %s" % expected)
		# ВАЖНО: Счетчик раздач НЕ увеличивается здесь - он увеличивается при открытии первых 4 карт
	else:
		# Для старого метода нет информации о bet_type/position_index
		EventBus.payout_wrong.emit(collected, expected, "", -1)
		DebugLogger.log("❌ Ошибка! Собрано: %s, ожидалось: %s" % [collected, expected])
		# ← Жизни отнимаются в PayoutScene, здесь ничего не делаем
	if is_correct and phase_manager:
		phase_manager.reset()

func hide_game_ui_elements() -> void:
	"""Скрыть UI элементы игры при открытии настроек"""
	DebugLogger.log("⚙️ Начинаем скрытие UI элементов...")
	
	# Кнопка действия (начать/подтвердить/завершить)
	if ui_manager and ui_manager.button_ui:
		if ui_manager.button_ui.action_button:
			ui_manager.button_ui.action_button.visible = false
			if ui_manager.button_ui.action_button_broken:
				ui_manager.button_ui.action_button_broken.visible = false
			DebugLogger.log("  ✅ action_button скрыта")
		if ui_manager.button_ui.pay_button:
			_pay_button_was_visible_before_settings = ui_manager.button_ui.pay_button.visible
			ui_manager.button_ui.pay_button.visible = false
			DebugLogger.log("  ✅ pay_button скрыта")
		else:
			_pay_button_was_visible_before_settings = false
		if ui_manager.button_ui.collect_button:
			_collect_button_was_visible_before_settings = ui_manager.button_ui.collect_button.visible
			ui_manager.button_ui.collect_button.visible = false
			DebugLogger.log("  ✅ collect_button скрыта")
		else:
			_collect_button_was_visible_before_settings = false
	
	# Кнопка подсказки - проверяем в TopUI и в корне
	var help_button = owner_node.get_node_or_null("TopUI/HelpButton")
	if not help_button:
		help_button = owner_node.get_node_or_null("HelpButton")
	if help_button:
		help_button.visible = false
		DebugLogger.log("  ✅ help_button скрыта")
	elif ui_manager and ui_manager.button_ui and ui_manager.button_ui.help_button:
		ui_manager.button_ui.help_button.visible = false
		DebugLogger.log("  ✅ help_button (из ui_manager) скрыта")

	# Кнопка настроек - проверяем в TopUI и в корне
	var settings_button = owner_node.get_node_or_null("TopUI/SettingsButton")
	if not settings_button:
		settings_button = owner_node.get_node_or_null("SettingsButton")
	if settings_button:
		settings_button.visible = false
		DebugLogger.log("  ✅ settings_button скрыта")
	elif owner_node.has("settings_button"):
		var top_settings_button = owner_node.get("settings_button")
		if top_settings_button:
			top_settings_button.visible = false
			DebugLogger.log("  ✅ settings_button (из owner_node) скрыта")
	
	# Сердца (SurvivalModeUI) - находится в TopUI
	var survival = owner_node.get_node_or_null("TopUI/SurvivalModeUI")
	if survival:
		survival.visible = false
		DebugLogger.log("  ✅ SurvivalModeUI скрыта")
	elif survival_state:
		survival_state.hide()
		DebugLogger.log("  ✅ survival_ui скрыта через SurvivalStateProvider")
	
	# Инвентарь с картами шансов
	var chance_storage = owner_node.get_node_or_null("TopUI/ChanceCardStorage")
	if chance_storage:
		chance_storage.visible = false
		DebugLogger.log("  ✅ ChanceCardStorage скрыт")
	
	# Счетчик раздач - проверяем в TopUI и в корне
	var rounds_label = owner_node.get_node_or_null("TopUI/RoundsCounterLabel")
	if not rounds_label:
		# Используем rounds_counter_label из owner_node если доступен
		rounds_label = owner_node.get("rounds_counter_label") if owner_node.has("rounds_counter_label") else null
	if rounds_label:
		rounds_label.visible = false
		DebugLogger.log("  ✅ rounds_counter_label скрыт")
	
	# Счетчик чаевых - проверяем в TopUI и в корне
	var stats_label = owner_node.get_node_or_null("TopUI/StatsLabel")
	if not stats_label:
		stats_label = ui_manager.stats_label if ui_manager else null
	if stats_label:
		stats_label.visible = false
		DebugLogger.log("  ✅ stats_label скрыт")
	
	DebugLogger.log("⚙️ UI элементы игры скрыты (настройки открыты)")

func show_game_ui_elements() -> void:
	"""Показать UI элементы игры при закрытии настроек"""
	DebugLogger.log("⚙️ Начинаем показ UI элементов...")
	
	# Кнопка действия (начать/подтвердить/завершить)
	if ui_manager and ui_manager.button_ui:
		if ui_manager.button_ui.action_button:
			# Показываем action_button, если он не disabled
			# Если disabled, то broken версия будет показана через disable_action_button
			if not ui_manager.button_ui.action_button.disabled:
				ui_manager.button_ui.action_button.visible = true
				if ui_manager.button_ui.action_button_broken:
					ui_manager.button_ui.action_button_broken.visible = false
				DebugLogger.log("  ✅ action_button показана")
			else:
				# Если disabled, то broken версия должна быть видна
				ui_manager.button_ui.action_button.visible = false
				if ui_manager.button_ui.action_button_broken:
					ui_manager.button_ui.action_button_broken.visible = true
				DebugLogger.log("  ✅ action_button_broken показана (action_button disabled)")
		if ui_manager.button_ui.pay_button:
			ui_manager.button_ui.pay_button.visible = _pay_button_was_visible_before_settings
			DebugLogger.log("  ✅ pay_button: %s" % ("показана" if _pay_button_was_visible_before_settings else "оставлена скрытой"))
		if ui_manager.button_ui.collect_button:
			ui_manager.button_ui.collect_button.visible = _collect_button_was_visible_before_settings
			DebugLogger.log("  ✅ collect_button: %s" % ("показана" if _collect_button_was_visible_before_settings else "оставлена скрытой"))
	
	# Кнопка подсказки - проверяем в TopUI и в корне
	var help_button = owner_node.get_node_or_null("TopUI/HelpButton")
	if not help_button:
		help_button = owner_node.get_node_or_null("HelpButton")
	if help_button:
		help_button.visible = true
		DebugLogger.log("  ✅ help_button показана")
	elif ui_manager and ui_manager.button_ui and ui_manager.button_ui.help_button:
		ui_manager.button_ui.help_button.visible = true
		DebugLogger.log("  ✅ help_button (из ui_manager) показана")

	# Кнопка настроек - проверяем в TopUI и в корне
	var settings_button = owner_node.get_node_or_null("TopUI/SettingsButton")
	if not settings_button:
		settings_button = owner_node.get_node_or_null("SettingsButton")
	if settings_button:
		settings_button.visible = true
		DebugLogger.log("  ✅ settings_button показана")
	elif owner_node.has("settings_button"):
		var top_settings_button = owner_node.get("settings_button")
		if top_settings_button:
			top_settings_button.visible = true
			DebugLogger.log("  ✅ settings_button (из owner_node) показана")
	
	# Сердца (SurvivalModeUI) - находится в TopUI
	var survival = owner_node.get_node_or_null("TopUI/SurvivalModeUI")
	if survival:
		survival.visible = true
		DebugLogger.log("  ✅ SurvivalModeUI показана")
	elif survival_state:
		survival_state.show()
		DebugLogger.log("  ✅ survival_ui показана через SurvivalStateProvider")
	
	# Инвентарь с картами шансов (показываем только если включены)
	var chance_storage = owner_node.get_node_or_null("TopUI/ChanceCardStorage")
	if chance_storage:
		var chance_cards_enabled = SaveManager.instance.load_chance_cards_enabled()
		chance_storage.visible = chance_cards_enabled
		DebugLogger.log("  ✅ ChanceCardStorage: %s" % ("показан" if chance_cards_enabled else "скрыт (отключен в настройках)"))
	
	# Счетчик раздач - проверяем в TopUI и в корне
	var rounds_label = owner_node.get_node_or_null("TopUI/RoundsCounterLabel")
	if not rounds_label:
		rounds_label = owner_node.get("rounds_counter_label") if owner_node.has("rounds_counter_label") else null
	if rounds_label:
		rounds_label.visible = true
		DebugLogger.log("  ✅ rounds_counter_label показан")
	
	# Счетчик чаевых - проверяем в TopUI и в корне
	var stats_label = owner_node.get_node_or_null("TopUI/StatsLabel")
	if not stats_label:
		stats_label = ui_manager.stats_label if ui_manager else null
	if stats_label:
		stats_label.visible = true
		DebugLogger.log("  ✅ stats_label показан")
	
	DebugLogger.log("⚙️ UI элементы игры показаны (настройки закрыты)")
