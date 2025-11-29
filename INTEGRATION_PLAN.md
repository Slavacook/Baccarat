# 📋 ПЛАН ИНТЕГРАЦИИ НОВОГО ФУНКЦИОНАЛА

## 🎯 ЦЕЛИ

1. **Визуальные фишки на поле** - отображаются при включении toggles
2. **Ставки на пары** - проверка пар в первых 4 картах, рандомные ставки
3. **Toggleable маркеры** - можно включить/выключить маркер победителя
4. **Кнопка "Карты"** - проверяет выбор победителя (вместо автопроверки)
5. **Ручная оплата** - клик на фишку → PayoutScene, возврат на тот же экран
6. **Множественные выплаты** - оплачивать пары и основные ставки последовательно
7. **Проверка неоплаченных ставок** - ошибка при нажатии "Карты" с неоплаченными ставками

---

## 🏗️ АРХИТЕКТУРА

### Менеджеры (созданы):

1. **ChipVisualManager** - управление визуальными фишками
2. **WinnerSelectionManager** - toggleable маркеры победителей
3. **PayoutQueueManager** - очередь выплат
4. **PairBettingManager** - ставки на пары

### Последовательность действий в игре:

```
1. НАЧАЛО РАУНДА
   ├─ Включить toggles ставок (Player/Banker/Tie)
   ├─ Рандомизировать ставки на пары (PairPlayer/PairBanker)
   └─ Показать фишки на поле

2. РАЗДАЧА КАРТ
   ├─ Раздать первые 4 карты
   ├─ Проверить пары в первых 4 картах
   ├─ Добавить выигравшие пары в PayoutQueue
   └─ Продолжить раздачу (третьи карты по правилам)

3. ВЫБОР ПОБЕДИТЕЛЯ
   ├─ Дилер кликает на маркер (Player/Banker/Tie)
   ├─ Маркер подсвечивается (можно отменить повторным кликом)
   └─ Дилер готов → нажимает кнопку "Карты"

4. ПРОВЕРКА ПОБЕДИТЕЛЯ (кнопка "Карты")
   ├─ Проверить, выбран ли победитель
   ├─ Сравнить с реальным результатом
   ├─ Показать тост (правильно/ошибка)
   └─ Добавить основную ставку в PayoutQueue

5. ОПЛАТА СТАВОК
   ├─ Сделать все фишки кликабельными
   ├─ Дилер кликает на фишку → PayoutScene
   ├─ Оплата → возврат на экран с картами/фишками
   ├─ PayoutQueue.mark_as_paid(bet_type)
   └─ Повторять пока есть неоплаченные

6. ЗАВЕРШЕНИЕ РАУНДА
   ├─ Дилер нажимает "Карты"
   ├─ Проверка: все ставки оплачены?
   ├─ Если да → новый раунд
   └─ Если нет → ОШИБКА, минус балл
```

---

## 📝 ШАГ 1: ДОБАВИТЬ УЗЛЫ В СЦЕНУ Game.tscn

Открыть `scenes/Game.tscn` в Godot Editor и добавить:

### Фишки (TextureButton):

```
[node name="ChipPlayer" type="TextureButton" parent="."]
offset_left = 730.0
offset_top = 460.0
offset_right = 830.0
offset_bottom = 560.0
scale = Vector2(0.6, 0.6)
visible = false

[node name="ChipBanker" type="TextureButton" parent="."]
offset_left = 355.0
offset_top = 460.0
offset_right = 455.0
offset_bottom = 560.0
scale = Vector2(0.6, 0.6)
visible = false

[node name="ChipTie" type="TextureButton" parent="."]
offset_left = 538.0
offset_top = 460.0
offset_right = 638.0
offset_bottom = 560.0
scale = Vector2(0.6, 0.6)
visible = false

[node name="ChipPairPlayer" type="TextureButton" parent="."]
offset_left = 900.0
offset_top = 380.0
offset_right = 1000.0
offset_bottom = 480.0
scale = Vector2(0.4, 0.4)
visible = false

[node name="ChipPairBanker" type="TextureButton" parent="."]
offset_left = 190.0
offset_top = 380.0
offset_right = 290.0
offset_bottom = 480.0
scale = Vector2(0.4, 0.4)
visible = false
```

### Toggles для пар (уже есть для Player/Banker/Tie):

```
[node name="PayoutTogglePairPlayer" type="Button" parent="."]
offset_left = 1075.0
offset_top = 265.0
offset_right = 1180.0
offset_bottom = 296.0
text = "Пара Игрока"

[node name="PayoutTogglePairBanker" type="Button" parent="."]
offset_left = 1075.0
offset_top = 327.0
offset_right = 1190.0
offset_bottom = 358.0
text = "Пара Банкира"
```

---

## 📝 ШАГ 2: ИНТЕГРАЦИЯ В GameController.gd

### 2.1. Объявить менеджеры (в начале файла):

```gdscript
# ═══════════════════════════════════════════════════════════════════════════
# МЕНЕДЖЕРЫ
# ═══════════════════════════════════════════════════════════════════════════

var chip_visual_manager: ChipVisualManager
var winner_selection_manager: WinnerSelectionManager
var payout_queue_manager: PayoutQueueManager
var pair_betting_manager: PairBettingManager
```

### 2.2. Инициализация в _ready():

```gdscript
func _ready():
	# ... существующий код ...

	_setup_managers()
	_setup_payout_toggles()
	_setup_pair_toggles()
```

### 2.3. Метод _setup_managers():

```gdscript
func _setup_managers():
	"""Инициализация всех менеджеров"""

	# ChipVisualManager
	chip_visual_manager = ChipVisualManager.new()
	var chip_player = get_node("ChipPlayer")
	var chip_banker = get_node("ChipBanker")
	var chip_tie = get_node("ChipTie")
	var chip_pair_player = get_node_or_null("ChipPairPlayer")
	var chip_pair_banker = get_node_or_null("ChipPairBanker")
	chip_visual_manager.setup(chip_player, chip_banker, chip_tie, chip_pair_player, chip_pair_banker)
	chip_visual_manager.chip_clicked.connect(_on_chip_clicked)

	# WinnerSelectionManager
	winner_selection_manager = WinnerSelectionManager.new()
	var player_marker = get_node("PlayerMarker")
	var banker_marker = get_node("BankerMarker")
	var tie_marker = get_node("TieMarker")
	winner_selection_manager.setup(player_marker, banker_marker, tie_marker)
	winner_selection_manager.winner_toggled.connect(_on_winner_toggled)

	# PayoutQueueManager
	payout_queue_manager = PayoutQueueManager.new()

	# PairBettingManager
	pair_betting_manager = PairBettingManager.new()
	pair_betting_manager.pair_detected.connect(_on_pair_detected)
	pair_betting_manager.pair_bet_placed.connect(_on_pair_bet_placed)

	print("✅ Все менеджеры инициализированы")
```

### 2.4. Метод _setup_payout_toggles():

```gdscript
func _setup_payout_toggles():
	"""Настройка toggles для основных ставок"""

	var player_toggle = get_node_or_null("PayoutTogglePlayer")
	var banker_toggle = get_node_or_null("PayoutToggleBanker")
	var tie_toggle = get_node_or_null("PayoutToggleTie")

	if not player_toggle or not banker_toggle or not tie_toggle:
		push_warning("PayoutToggle кнопки не найдены!")
		return

	# Включаем toggle mode
	player_toggle.toggle_mode = true
	banker_toggle.toggle_mode = true
	tie_toggle.toggle_mode = true

	# Устанавливаем начальное состояние
	player_toggle.button_pressed = PayoutSettingsManager.player_payout_enabled
	banker_toggle.button_pressed = PayoutSettingsManager.banker_payout_enabled
	tie_toggle.button_pressed = PayoutSettingsManager.tie_payout_enabled

	# Показываем фишки если включено
	if player_toggle.button_pressed:
		chip_visual_manager.show_chip("Player")
	if banker_toggle.button_pressed:
		chip_visual_manager.show_chip("Banker")
	if tie_toggle.button_pressed:
		chip_visual_manager.show_chip("Tie")

	# Подключаем сигналы
	player_toggle.toggled.connect(_on_payout_toggle_player)
	banker_toggle.toggled.connect(_on_payout_toggle_banker)
	tie_toggle.toggled.connect(_on_payout_toggle_tie)

	print("✅ Toggles основных ставок настроены")
```

### 2.5. Метод _setup_pair_toggles():

```gdscript
func _setup_pair_toggles():
	"""Настройка toggles для ставок на пары"""

	var pair_player_toggle = get_node_or_null("PayoutTogglePairPlayer")
	var pair_banker_toggle = get_node_or_null("PayoutTogglePairBanker")

	if not pair_player_toggle or not pair_banker_toggle:
		print("⚠️  Toggles для пар не найдены (опционально)")
		return

	# Включаем toggle mode
	pair_player_toggle.toggle_mode = true
	pair_banker_toggle.toggle_mode = true

	# Подключаем сигналы
	pair_player_toggle.toggled.connect(_on_payout_toggle_pair_player)
	pair_banker_toggle.toggled.connect(_on_payout_toggle_pair_banker)

	print("✅ Toggles пар настроены")
```

### 2.6. Обработчики toggles:

```gdscript
func _on_payout_toggle_player(enabled: bool):
	"""Переключатель ставки на игрока"""
	PayoutSettingsManager.toggle_player(enabled)
	if enabled:
		chip_visual_manager.show_chip("Player")
	else:
		chip_visual_manager.hide_chip("Player")


func _on_payout_toggle_banker(enabled: bool):
	"""Переключатель ставки на банкира"""
	PayoutSettingsManager.toggle_banker(enabled)
	if enabled:
		chip_visual_manager.show_chip("Banker")
	else:
		chip_visual_manager.hide_chip("Banker")


func _on_payout_toggle_tie(enabled: bool):
	"""Переключатель ставки на ничью"""
	PayoutSettingsManager.toggle_tie(enabled)
	if enabled:
		chip_visual_manager.show_chip("Tie")
	else:
		chip_visual_manager.hide_chip("Tie")


func _on_payout_toggle_pair_player(enabled: bool):
	"""Переключатель ставки на пару игрока"""
	pair_betting_manager.toggle_pair_player_bet(enabled)
	if enabled:
		chip_visual_manager.show_chip("PairPlayer")
	else:
		chip_visual_manager.hide_chip("PairPlayer")


func _on_payout_toggle_pair_banker(enabled: bool):
	"""Переключатель ставки на пару банкира"""
	pair_betting_manager.toggle_pair_banker_bet(enabled)
	if enabled:
		chip_visual_manager.show_chip("PairBanker")
	else:
		chip_visual_manager.hide_chip("PairBanker")
```

---

## 📝 ШАГ 3: ИЗМЕНИТЬ ЛОГИКУ РАЗДАЧИ КАРТ

В методе раздачи первых 4 карт добавить проверку пар:

```gdscript
func _after_first_four_cards_dealt():
	"""После раздачи первых 4 карт - проверяем пары"""

	# Получаем карты
	var player_card1 = player_cards[0]
	var player_card2 = player_cards[1]
	var banker_card1 = banker_cards[0]
	var banker_card2 = banker_cards[1]

	# Проверяем пары
	var pair_results = pair_betting_manager.check_pairs(
		player_card1, player_card2, banker_card1, banker_card2
	)

	# Если есть пары - добавляем в очередь выплат
	for pair_type in pair_betting_manager.get_winning_pairs():
		var stake = 100.0  # Или получить из настроек
		var payout = pair_betting_manager.calculate_pair_payout(stake, pair_type)
		payout_queue_manager.add_bet(pair_type, stake, payout, true)

	# Продолжаем раздачу третьих карт...
```

---

## 📝 ШАГ 4: ИЗМЕНИТЬ ЛОГИКУ КНОПКИ "КАРТЫ"

Старая логика маркеров удалена. Теперь:

```gdscript
func _on_cards_button_pressed():
	"""Нажатие на кнопку Карты - проверка победителя"""

	# Проверка 1: Если раунд не завершен - начинаем раздачу
	if game_state == GameState.WAITING_FOR_CARDS:
		_start_dealing()
		return

	# Проверка 2: Если есть неоплаченные ставки - ОШИБКА
	if payout_queue_manager.has_unpaid_winning_bets():
		_handle_error("Сначала оплатите все ставки!")
		return

	# Проверка 3: Если раунд завершен и все оплачено - новый раунд
	if game_state == GameState.ROUND_FINISHED:
		_start_new_round()
		return

	# Проверка 4: Проверяем выбор победителя
	if game_state == GameState.WAITING_FOR_WINNER_SELECTION:
		_validate_winner_selection()
```

```gdscript
func _validate_winner_selection():
	"""Проверить выбор победителя"""

	# Проверяем, выбран ли победитель
	if not winner_selection_manager.is_winner_selected():
		show_toast("❌ Выберите победителя!", 2.0)
		return

	var selected_winner = winner_selection_manager.get_selected_winner()
	var actual_winner = _calculate_actual_winner()

	# Проверяем правильность
	if selected_winner == actual_winner:
		# ПРАВИЛЬНО
		show_toast("✅ Правильно! Выиграл %s" % actual_winner, 3.0)
		GameStateManager.increment_correct()

		# Добавляем основную ставку в очередь
		_add_main_bet_to_queue(actual_winner)

		# Делаем фишки кликабельными для оплаты
		chip_visual_manager.make_all_chips_clickable(true)

		# Меняем состояние
		game_state = GameState.WAITING_FOR_PAYOUT

	else:
		# ОШИБКА
		show_toast("❌ Ошибка! Выиграл %s, а не %s" % [actual_winner, selected_winner], 3.0)
		GameStateManager.increment_errors()
		_start_new_round()
```

---

## 📝 ШАГ 5: РЕАЛИЗОВАТЬ КЛИК НА ФИШКУ

```gdscript
func _on_chip_clicked(bet_type: String):
	"""Обработка клика на фишку - переход в PayoutScene"""

	# Проверяем, что это выигравшая и неоплаченная ставка
	var bet = payout_queue_manager.get_bet_by_type(bet_type)
	if not bet:
		show_toast("❌ Нет ставки %s" % bet_type, 2.0)
		return

	if not bet.won:
		show_toast("❌ Эта ставка не выиграла" % bet_type, 2.0)
		return

	if bet.is_paid:
		show_toast("✅ Эта ставка уже оплачена", 2.0)
		return

	# Сохраняем текущее состояние
	_save_game_state_for_return()

	# Переходим в PayoutScene
	_open_payout_scene(bet_type, bet.stake, bet.payout)
```

```gdscript
func _open_payout_scene(bet_type: String, stake: float, expected_payout: float):
	"""Открыть сцену выплаты"""

	# Сохраняем контекст
	PayoutContextManager.set_context({
		"bet_type": bet_type,
		"stake": stake,
		"expected_payout": expected_payout,
		"return_to_game": true
	})

	# Переходим в PayoutScene
	get_tree().change_scene_to_file("res://scenes/PayoutScene.tscn")
```

---

## 📝 ШАГ 6: ВОЗВРАТ ИЗ PayoutScene

В PayoutScene после правильной оплаты:

```gdscript
func _on_payout_validated_correctly():
	"""После правильной оплаты"""

	var context = PayoutContextManager.get_context()

	if context.return_to_game:
		# Отмечаем ставку как оплаченную
		EventBus.payout_completed.emit(context.bet_type)

		# Возвращаемся в Game
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
```

В GameController.gd подключаем сигнал:

```gdscript
func _ready():
	# ...
	EventBus.payout_completed.connect(_on_payout_completed)


func _on_payout_completed(bet_type: String):
	"""Обработка завершения оплаты"""

	# Отмечаем как оплаченную
	payout_queue_manager.mark_as_paid(bet_type)

	# Скрываем фишку
	chip_visual_manager.hide_chip(bet_type)

	# Проверяем, все ли оплачено
	if payout_queue_manager.is_all_paid():
		show_toast("✅ Все ставки оплачены! Нажмите Карты", 3.0)
		game_state = GameState.ROUND_FINISHED
```

---

## 📝 ШАГ 7: НОВЫЙ РАУНД

```gdscript
func _start_new_round():
	"""Начать новый раунд"""

	# Очищаем менеджеры
	payout_queue_manager.clear()
	pair_betting_manager.reset_round()
	winner_selection_manager.reset()
	chip_visual_manager.hide_all_chips()

	# Рандомизируем ставки на пары (если нужно)
	# pair_betting_manager.randomize_pair_bets()

	# Показываем фишки согласно toggles
	_refresh_chips_visibility()

	# Сброс карт и состояния
	# ...

	game_state = GameState.WAITING_FOR_CARDS
```

---

## ✅ ИТОГО

### Создано:
- ✅ ChipVisualManager.gd
- ✅ WinnerSelectionManager.gd
- ✅ PayoutQueueManager.gd
- ✅ PairBettingManager.gd

### Нужно добавить в GameController.gd:
1. Объявление менеджеров
2. _setup_managers()
3. _setup_payout_toggles()
4. _setup_pair_toggles()
5. Обработчики toggles
6. Проверка пар после первых 4 карт
7. Новая логика кнопки "Карты"
8. _on_chip_clicked()
9. _on_payout_completed()
10. Обновленный _start_new_round()

### Нужно добавить в Game.tscn:
1. 5 узлов TextureButton для фишек
2. 2 узла Button для toggles пар

### Нужно создать:
- PayoutContextManager (singleton для передачи контекста между сценами)

---

## 🔄 ПОСЛЕДОВАТЕЛЬНОСТЬ ТЕСТИРОВАНИЯ

1. Запустить игру
2. Включить toggles (Player, Banker, Tie) - фишки должны появиться
3. Нажать "Карты" - начнется раздача
4. После раздачи - кликнуть на маркер победителя
5. Нажать "Карты" - проверка правильности
6. Кликнуть на фишку - переход в PayoutScene
7. Оплатить - возврат в игру, фишка исчезла
8. Если есть еще ставки - повторить 6-7
9. Нажать "Карты" - новый раунд

---

## 🎓 СЛЕДУЮЩИЕ ШАГИ

1. Создать PayoutContextManager.gd (singleton)
2. Добавить код в GameController.gd согласно плану
3. Добавить узлы в Game.tscn
4. Протестировать
5. Отладить
6. Добавить рандомизацию ставок на пары (опционально)
