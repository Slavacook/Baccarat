# res://scripts/SoundManager.gd
# Менеджер звуков - подписан на события EventBus
extends Node

static var instance: SoundManager

# ═══════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ ГРОМКОСТИ
# ═══════════════════════════════════════════════════════════════════════════

const FOCUS_CHANGE_VOLUME: float = 0.3  # Громкость звука focus_change (30% от оригинала)
const MODE_SWITCH_VOLUME: float = 0.2  # Громкость звука mode_switch (20% от оригинала)
const PATIENCE_LOST_VOLUME: float = 0.5  # Громкость звука patience_lost (50% от оригинала)
const MAX_SFX_PLAYERS: int = 5  # Максимум одновременно играющих звуков

# ═══════════════════════════════════════════════════════════════════════════
# ЗВУКОВЫЕ ПОТОКИ
# ═══════════════════════════════════════════════════════════════════════════

# Звуки переворота карт (уже есть)
var flip_sounds: Array[AudioStream] = []

# Основные звуки игры
var game_over_sound: AudioStream
var focus_change_sound: AudioStream  # Переключение фокуса (карты/маркеры/фишки)
var focus_activate_sound: AudioStream  # Подтверждение выбора
var focus_activate_2_sound: AudioStream  # Деактивация выбора
var error_sound: AudioStream
var chip_collect_sound: AudioStream  # Забор проигрышных ставок
var mode_switch_sound: AudioStream  # Переключение режима сбора/оплаты
var hint_sound: AudioStream  # Подсказка/шпаргалка
var payout_correct_sound: AudioStream  # Верная выплата
var payout_wrong_sound: AudioStream  # Ошибочная выплата
var tip_received_sound: AudioStream  # Получение чаевых
var penalty_sound: AudioStream  # Получение штрафа
var patience_lost_sound: AudioStream  # Потеря терпения
var heart_sound: AudioStream  # Сердце (heart bet)
var bet_sounds: Array[AudioStream] = []  # Звуки ставок гостей (8 вариантов)

# AudioStreamPlayer узлы
var flip_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []  # Пул игроков для параллельного воспроизведения звуков

# Настройки громкости
var master_volume: float = 1.0
var sfx_volume: float = 1.0

# Флаги для отслеживания состояния
var last_patience_values: Dictionary = {}  # {guest_id: patience} для отслеживания потери терпения
var last_tips_value: int = 0  # Для отслеживания получения чаевых

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	# Создаём AudioStreamPlayer для звуков переворота карт
	flip_player = AudioStreamPlayer.new()
	add_child(flip_player)
	
	# Создаём пул AudioStreamPlayer для параллельного воспроизведения звуков
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		sfx_players.append(player)
	
	# Загружаем звуки
	_load_sounds()
	
	# Инициализируем отслеживание состояния
	_init_state_tracking()
	
	# Подписываемся на события EventBus
	_connect_events()
	
	print("🔊 SoundManager готов! Подписан на EventBus.")

func _load_sounds():
	"""Загрузить все звуковые файлы"""
	# Загружаем звуки переворота карт
	for i in range(1, GameConstants.FLIP_CARD_SOUNDS_COUNT + 1):
		var sound_path = GameConstants.FLIP_CARD_SOUND_PATH_TEMPLATE % i
		var sound = load(sound_path)
		if sound:
			flip_sounds.append(sound)
		else:
			push_warning("SoundManager: звук не найден: %s" % sound_path)
	
	# Загружаем остальные звуки (если файлы существуют)
	# game_over.mp3 - Звук окончания игры (game over) - играется когда игрок теряет все жизни
	game_over_sound = _load_sound_safe("res://assets/sound/game_over.mp3")
	
	# focus_change.mp3 - Звук переключения фокуса - играется при:
	#   - Переключении между картами и маркерами (PlayerThird, BankerThird, PlayerMarker, BankerMarker, TieMarker)
	#   - Включении управления фокусом (focus_control_enabled)
	#   - Переключении между фишками в навигаторе (ChipNavigationManager)
	#   - Переключении между фишками в окне выплат (PayoutKeyboardNavigator)
	focus_change_sound = _load_sound_safe("res://assets/sound/focus_change.mp3")
	
	# focus_activate.mp3 - Звук подтверждения выбора - играется при:
	#   - Активации элемента в фокусе (двойное нажатие Space на карте/маркере)
	#   - Подтверждении выбора третьей карты или победителя
	#   - Клике на фишку в окне выплат (добавление фишки)
	#   ВАЖНО: Только для карт, маркеров и фишек в окне выплат
	focus_activate_sound = _load_sound_safe("res://assets/sound/focus_activate.mp3")
	
	# focus_activate_2.mp3 - Звук деактивации выбора - играется при:
	#   - Деактивации маркера (PlayerMarker, BankerMarker, TieMarker)
	#   - Отмене заказа третьей карты (PlayerThird, BankerThird)
	#   - Удалении фишки в окне выплат (правый клик или клик на стопку)
	focus_activate_2_sound = _load_sound_safe("res://assets/sound/focus_activate_2.mp3")
	
	# error.mp3 - Звук ошибки - играется при:
	#   - Неправильном действии игрока (action_error)
	#   - Потере жизни (life_lost)
	#   - Проигрыше в Heart Bet (heart_bet_lost)
	error_sound = _load_sound_safe("res://assets/sound/error.mp3")
	
	# chip_collect.mp3 - Звук забора проигрышных ставок - играется при:
	#   - Сборе проигрышной ставки (BetCollectionPhaseManager.collect_bet)
	#   - Клике на проигрышную фишку для её сбора
	chip_collect_sound = _load_sound_safe("res://assets/sound/chip_collect.mp3")
	
	# mode_switch.mp3 - Звук переключения режима - играется при:
	#   - Переключении режима сбора/оплаты (COLLECT ↔ PAY)
	#   - Включении режима "Забрать" или "Оплатить"
	mode_switch_sound = _load_sound_safe("res://assets/sound/mode_switch.mp3")
	
	# hint.mp3 - Звук подсказки/шпаргалки - играется при:
	#   - Использовании подсказки в окне выплат (hint_used)
	#   - Открытии шпаргалки (CribSheetScene.show_cribsheet)
	hint_sound = _load_sound_safe("res://assets/sound/hint.mp3")
	
	# payout_correct.mp3 - Звук верной выплаты - играется при:
	#   - Правильном расчёте выплаты в окне выплат (payout_correct)
	#   - Успешной оплате выигрышной ставки
	payout_correct_sound = _load_sound_safe("res://assets/sound/payout_correct.mp3")
	
	# payout_wrong.mp3 - Звук ошибочной выплаты - играется при:
	#   - Неправильном расчёте выплаты в окне выплат (payout_wrong)
	#   - Попытке выплатить неправильную сумму
	payout_wrong_sound = _load_sound_safe("res://assets/sound/payout_wrong.mp3")
	
	# tip_received.mp3 - Звук получения чаевых - играется при:
	#   - Получении чаевых от гостя после правильной выплаты
	#   - Увеличении счёта (чаевых) после оплаты выигрышной ставки
	tip_received_sound = _load_sound_safe("res://assets/sound/tip_received.mp3")
	
	# penalty.mp3 - Звук получения штрафа - играется при:
	#   - Штрафе за неоплаченные ставки (unpaid_bets_heart_penalty)
	#   - Потере чаевых из-за ошибок
	penalty_sound = _load_sound_safe("res://assets/sound/penalty.mp3")
	
	# patience_lost.mp3 - Звук потери терпения - играется при:
	#   - Уменьшении терпения гостя (guest_patience_changed, когда терпение уменьшилось)
	#   - Гость становится недовольным из-за задержек или ошибок
	patience_lost_sound = _load_sound_safe("res://assets/sound/patience_lost.mp3")
	
	# heart.mp3 - Звук сердца (Heart Bet) - играется при:
	#   - Выборе сердца для ставки (heart_bet_selected)
	#   - Выигрыше в Heart Bet (heart_bet_won)
	#   - Взятии сердца в залог (heart_pledged)
	heart_sound = _load_sound_safe("res://assets/sound/heart.mp3")
	
	# Звуки ставок гостей (8 вариантов) - играются при:
	#   - Размещении ставки гостем на столе (при показе ставок гостей)
	#   - Каждая ставка играет случайный звук из 8 вариантов
	for i in range(1, GameConstants.BET_SOUNDS_COUNT + 1):
		var sound_path = GameConstants.BET_SOUND_PATH_TEMPLATE % i
		var sound = _load_sound_safe(sound_path)
		if sound:
			bet_sounds.append(sound)

func _load_sound_safe(path: String) -> AudioStream:
	"""Безопасная загрузка звука (не выдаёт ошибку если файл не найден или не импортирован)
	
	Примечание: Если файл существует, но не импортирован в Godot, будут ошибки в консоли.
	Это нормально - после импорта файла ошибки исчезнут.
	"""
	# Проверяем существование файла
	if not ResourceLoader.exists(path):
		# Файл не существует - это нормально, можно добавить позже
		return null
	
	# Проверяем, есть ли .import файл (файл импортирован)
	var import_path = path + ".import"
	# Проверяем через ResourceLoader.exists для .import файла
	if not ResourceLoader.exists(import_path) and not FileAccess.file_exists(import_path):
		# Файл существует, но не импортирован - это нормально
		# НЕ пытаемся загружать, чтобы не было ошибок в консоли
		# Ошибки в консоли от Godot при попытке load() неимпортированного файла
		# это нормально, они исчезнут после импорта файла
		return null
	
	# Пробуем загрузить звук (теперь файл должен быть импортирован)
	# Используем прямой load() - если файл импортирован, это должно работать
	# Если файл не импортирован, Godot выдаст ошибку в консоли, но это нормально
	var sound = load(path)
	
	# Проверяем, что загруженный ресурс является AudioStream
	if sound and sound is AudioStream:
		return sound as AudioStream
	
	# Если не получилось, возвращаем null
	# Ошибки в консоли от Godot - это нормально для неимпортированных файлов
	return null

func _init_state_tracking():
	"""Инициализация отслеживания состояния для звуков"""
	# Инициализируем значения терпения для всех гостей
	if GuestStatsManager:
		for i in range(1, 7):
			last_patience_values[i] = 100
	
	# Инициализируем значение чаевых
	if SaveManager:
		last_tips_value = SaveManager.instance.score

func _connect_events():
	"""Подписаться на все события EventBus"""
	# Игровой процесс
	EventBus.player_third_drawn.connect(_on_player_third_drawn)
	EventBus.banker_third_drawn.connect(_on_banker_third_drawn)
	EventBus.game_over.connect(_on_game_over)
	
	# Фокус
	EventBus.focus_changed.connect(_on_focus_changed)
	EventBus.focus_activated.connect(_on_focus_activated)
	EventBus.focus_control_enabled.connect(_on_focus_control_enabled)
	
	# Правильные действия и ошибки
	EventBus.action_correct.connect(_on_action_correct)
	EventBus.action_error.connect(_on_action_error)
	
	# Выплаты
	EventBus.payout_correct.connect(_on_payout_correct)
	EventBus.payout_wrong.connect(_on_payout_wrong)
	EventBus.hint_used.connect(_on_hint_used)
	EventBus.tip_received.connect(_on_tip_received)
	EventBus.penalty_applied.connect(_on_penalty_applied)
	
	# Режим выживания
	EventBus.life_lost.connect(_on_life_lost)
	
	# Heart Bet
	EventBus.heart_bet_selected.connect(_on_heart_bet_selected)
	EventBus.heart_bet_won.connect(_on_heart_bet_won)
	EventBus.heart_bet_lost.connect(_on_heart_bet_lost)
	EventBus.heart_pledged.connect(_on_heart_pledged)
	
	# Терпение (если GuestStatsManager доступен)
	if GuestStatsManager:
		GuestStatsManager.guest_patience_changed.connect(_on_patience_changed)
	
	# Навигация по фишкам (chip navigation) - нужно подписаться через BetCollectionPhaseManager
	# Это будет сделано через прямое подключение в GameController

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ СОБЫТИЙ EventBus
# ═══════════════════════════════════════════════════════════════════════════

func _on_player_third_drawn(_card):
	play_flip_sound()

func _on_banker_third_drawn(_card):
	play_flip_sound()

func _on_game_over(_rounds_survived: int):
	play_sound(game_over_sound)

func _on_focus_changed(target: String):
	"""Обработчик изменения фокуса (карты/маркеры/фишки)"""
	# Игнорируем "None" - это сброс фокуса, не переключение
	if target != "None":
		play_sound(focus_change_sound, FOCUS_CHANGE_VOLUME)

func _on_focus_activated(target: String):
	"""Обработчик активации фокуса (подтверждение выбора карт/маркеров)
	
	ВАЖНО: 
	- Для третьих карт (PlayerThird, BankerThird) звук играется в 
	  GamePhaseManager.on_player_third_toggled() / on_banker_third_toggled()
	- Для маркеров (PlayerMarker, BankerMarker, TieMarker) звук играется здесь,
	  так как они активируются напрямую через toggle_winner()
	
	Для фишек в окне выплат звук focus_activate играется напрямую в PayoutOverlay.
	"""
	# Играем звук только для маркеров
	# Третьи карты обрабатывают звук сами в своих обработчиках
	var marker_targets = ["PlayerMarker", "BankerMarker", "TieMarker"]
	if target in marker_targets:
		play_sound(focus_activate_sound)
	# Игнорируем третьи карты - они обрабатывают звук сами
	# Игнорируем все остальные цели

func _on_focus_control_enabled(_enabled: bool):
	"""Обработчик включения/выключения управления фокусом"""
	# Звук убран - управление фокусом активируется автоматически при старте,
	# звук должен играться только при реальных действиях пользователя
	pass

func _on_action_correct(_type: String):
	# Звук успеха уже обрабатывается через другие события
	pass

func _on_action_error(type: String, _message: String):
	"""Обработчик ошибки"""
	# Звук штрафа теперь воспроизводится через событие penalty_applied
	# с задержкой 1.5 сек после применения штрафа
	# Здесь только общие ошибки
	if type != "unpaid_bets_heart_penalty":
		play_sound(error_sound)

func _on_payout_correct(_collected: float, _expected: float, _bet_type: String, _position_index: int):
	"""Обработчик правильной выплаты"""
	play_sound(payout_correct_sound)
	
	# Звук чаевых теперь воспроизводится через событие tip_received
	# с задержкой 0.5 сек после правильной выплаты

func _on_payout_wrong(_collected: float, _expected: float, _bet_type: String, _position_index: int):
	play_sound(payout_wrong_sound)

func _on_hint_used():
	play_sound(hint_sound)

func _on_life_lost(_remaining_lives: int):
	play_sound(error_sound)

func _on_heart_bet_selected(_target: String):
	play_sound(heart_sound)

func _on_heart_bet_won(_target: String, _lives_gained: int):
	play_sound(heart_sound)

func _on_heart_bet_lost(_target: String, _lives_remaining: int):
	play_sound(error_sound)

func _on_heart_pledged():
	play_sound(heart_sound)

func _on_patience_changed(guest_id: int, new_patience: int):
	"""Обработчик изменения терпения гостя"""
	if not last_patience_values.has(guest_id):
		last_patience_values[guest_id] = 100
	
	var old_patience = last_patience_values[guest_id]
	last_patience_values[guest_id] = new_patience
	
	# Если терпение уменьшилось - играем звук
	if new_patience < old_patience:
		play_sound(patience_lost_sound, PATIENCE_LOST_VOLUME)

func _on_tip_received(tip_amount: int):
	"""Обработчик получения чаевых - играем звук синхронно с начислением"""
	if tip_amount > 0:
		play_sound(tip_received_sound)
		# Обновляем отслеживание для совместимости
		if SaveManager:
			last_tips_value = SaveManager.instance.score

func _on_penalty_applied(penalty_amount: int):
	"""Обработчик применения штрафа - играем звук синхронно с вычитанием"""
	if penalty_amount > 0:
		play_sound(penalty_sound)
		# Обновляем отслеживание для совместимости
		if SaveManager:
			last_tips_value = SaveManager.instance.score

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ ВОСПРОИЗВЕДЕНИЯ ЗВУКОВ
# ═══════════════════════════════════════════════════════════════════════════

func play_flip_sound():
	"""Воспроизводит случайный звук переворота карты"""
	if flip_sounds.is_empty():
		return
	
	var random_sound = flip_sounds[randi() % flip_sounds.size()]
	flip_player.stream = random_sound
	flip_player.volume_db = linear_to_db(sfx_volume * master_volume)
	flip_player.play()

func play_sound(sound: AudioStream, volume: float = 1.0):
	"""Универсальный метод для воспроизведения любого звука
	
	Использует пул AudioStreamPlayer для параллельного воспроизведения звуков.
	Если все игроки заняты, использует первый (прервёт текущий звук).
	"""
	if not sound:
		# Звук не загружен (файл не существует или не импортирован) - это нормально
		return
	
	# Ищем свободный AudioStreamPlayer
	var player = _get_free_player()
	if not player:
		# Все заняты - используем первый (прервёт текущий звук)
		player = sfx_players[0] if sfx_players.size() > 0 else null
	
	if not player:
		return
	
	player.stream = sound
	player.volume_db = linear_to_db(volume * sfx_volume * master_volume)
	player.play()

func _get_free_player() -> AudioStreamPlayer:
	"""Найти свободный AudioStreamPlayer (не играющий)
	
	Returns:
		Свободный AudioStreamPlayer или null, если все заняты
	"""
	for player in sfx_players:
		if not player.playing:
			return player
	return null  # Все заняты

# ═══════════════════════════════════════════════════════════════════════════
# МЕТОДЫ ДЛЯ ВНЕШНИХ ВЫЗОВОВ (для событий без EventBus)
# ═══════════════════════════════════════════════════════════════════════════

func play_chip_collect_sound():
	"""Звук забора проигрышных ставок"""
	play_sound(chip_collect_sound)

func play_mode_switch_sound():
	"""Звук переключения режима сбора/оплаты"""
	play_sound(mode_switch_sound, MODE_SWITCH_VOLUME)

func play_chip_navigation_sound():
	"""Звук переключения между фишками в навигаторе"""
	play_sound(focus_change_sound, FOCUS_CHANGE_VOLUME)

func play_payout_chip_navigation_sound():
	"""Звук переключения между фишками в окне выплат"""
	play_sound(focus_change_sound, FOCUS_CHANGE_VOLUME)

func play_crib_sheet_sound():
	"""Звук открытия шпаргалки"""
	play_sound(hint_sound)

func play_focus_deactivate_sound():
	"""Звук деактивации выбора (маркеры, карты, фишки)"""
	if focus_activate_2_sound:
		play_sound(focus_activate_2_sound)

func play_bet_sound():
	"""Звук размещения ставки гостем (случайный из 8 вариантов)"""
	if bet_sounds.is_empty():
		return
	
	var random_index = randi() % bet_sounds.size()
	play_sound(bet_sounds[random_index])

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ ГРОМКОСТИ
# ═══════════════════════════════════════════════════════════════════════════

func set_master_volume(volume: float):
	"""Устанавливает общую громкость (0.0 - 1.0)"""
	master_volume = clamp(volume, 0.0, 1.0)

func set_sfx_volume(volume: float):
	"""Устанавливает громкость звуковых эффектов (0.0 - 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
