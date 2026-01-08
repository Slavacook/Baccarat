# res://scripts/GameConstants.gd
# Централизованное хранилище констант игры
# Использование: GameConstants.FLIP_CARD_DELAY

class_name GameConstants

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИИ И ЗАДЕРЖКИ
# ═══════════════════════════════════════════════════════════════════════════

const FLIP_CARD_DELAY: float = 0.3           # Задержка между flip анимациями карт (секунды)
const TOAST_DURATION: float = 2.0            # Длительность показа toast (секунды)
const SUCCESS_ANIMATION_DURATION: float = 1.0  # Длительность анимации успеха (секунды)
const ERROR_ANIMATION_DURATION: float = 0.8    # Длительность анимации ошибки (секунды)

# ═══════════════════════════════════════════════════════════════════════════
# UI РАЗМЕРЫ И МАСШТАБЫ
# ═══════════════════════════════════════════════════════════════════════════

# PayoutPopup
const PAYOUT_POPUP_MIN_SIZE: Vector2 = Vector2(1000, 540)  # ← Уменьшили высоту с 600 до 540
const PAYOUT_POPUP_WIDTH_MULT: float = 0.9    # Множитель ширины от экрана
const PAYOUT_POPUP_HEIGHT_MULT: float = 0.75  # ← Уменьшили с 0.85 до 0.75
const PAYOUT_POPUP_MAX_WIDTH: int = 1100
const PAYOUT_POPUP_MAX_HEIGHT: int = 580      # ← Уменьшили с 650 до 580

# Шрифты PayoutPopup
const FONT_SIZE_RESULT_LABEL: int = 48
const FONT_SIZE_STAKE_LABEL: int = 28
const FONT_SIZE_COLLECTED_AMOUNT: int = 72
const FONT_SIZE_PAYOUT_BUTTON: int = 26
const FONT_SIZE_FEEDBACK_ERROR: int = 32

# Отступы
const PAYOUT_POPUP_MARGIN: int = 25
const PAYOUT_POPUP_MARGIN_TOP: int = 20
const PAYOUT_POPUP_MARGIN_BOTTOM: int = 20

# Цвета зон PayoutPopup
const MAIN_PANEL_BG_COLOR: Color = Color(0.051, 0.216, 0.051, 0.8)      # Черный полупрозрачный (фон средней зоны)
const MAIN_PANEL_BORDER_COLOR: Color = Color(0.7, 0.5, 0.2, 0.8)     # Золотистая рамка
const FLEET_PANEL_BG_COLOR: Color = Color(0.1, 0.1, 0.1, 0.7)        # Темно-серый (фон нижней зоны)
const FLEET_PANEL_BORDER_COLOR: Color = Color(0.5, 0.5, 0.5, 0.6)    # Серая рамка
const AMOUNT_PANEL_BG_COLOR: Color = Color(0.15, 0.15, 0.15, 0.9)    # Темный бокс (панель суммы)
const AMOUNT_PANEL_BORDER_COLOR: Color = Color(0.5, 0.5, 0.5, 0.6)   # Серая рамка

# ═══════════════════════════════════════════════════════════════════════════
# ФИШКИ (CHIPS)
# ═══════════════════════════════════════════════════════════════════════════

const CHIP_STACK_MAX_CHIPS: int = 20          # Максимум фишек в одной стопке
const CHIP_STACK_SLOT_COUNT_SMALL: int = 9    # Количество слотов (малый режим) ← Увеличили с 8 до 9
const CHIP_STACK_SLOT_COUNT_LARGE: int = 13   # Количество слотов (большой режим) ← Увеличили с 10 до 13
const CHIP_STACK_SCALE_SMALL: float = 0.75    # Масштаб фишек (малый режим) ← Средний размер (было 1.0)
const CHIP_STACK_SCALE_LARGE: float = 0.6     # Масштаб фишек (большой режим)
const CHIP_STACK_SLOT_HEIGHT: int = 240       # Фиксированная высота слота ← Уменьшили с 280 до 240
const CHIP_BUTTON_SIZE: Vector2 = Vector2(90, 90)  # Размер кнопки фишки в флоте

# ═══════════════════════════════════════════════════════════════════════════
# ЗВУКИ
# ═══════════════════════════════════════════════════════════════════════════

const FLIP_CARD_SOUNDS_COUNT: int = 8         # Количество вариантов звука flip
const FLIP_CARD_SOUND_PATH_TEMPLATE: String = "res://assets/sound/flip_card%d.wav"

# Новые звуки (все в формате MP3)
# game_over.mp3 - Звук окончания игры (game over) - когда игрок теряет все жизни
const GAME_OVER_SOUND_PATH: String = "res://assets/sound/game_over.mp3"

# focus_change.mp3 - Звук переключения фокуса - при переключении между картами/маркерами/фишками
const FOCUS_CHANGE_SOUND_PATH: String = "res://assets/sound/focus_change.mp3"

# focus_activate.mp3 - Звук подтверждения выбора - при активации элемента в фокусе
const FOCUS_ACTIVATE_SOUND_PATH: String = "res://assets/sound/focus_activate.mp3"

# focus_activate_2.mp3 - Звук деактивации выбора - при деактивации элемента
const FOCUS_ACTIVATE_2_SOUND_PATH: String = "res://assets/sound/focus_activate_2.mp3"

# error.mp3 - Звук ошибки - при неправильном действии или потере жизни
const ERROR_SOUND_PATH: String = "res://assets/sound/error.mp3"

# chip_collect.mp3 - Звук забора проигрышных ставок - при сборе проигрышной фишки
const CHIP_COLLECT_SOUND_PATH: String = "res://assets/sound/chip_collect.mp3"

# mode_switch.mp3 - Звук переключения режима - при переключении между "Забрать" и "Оплатить"
const MODE_SWITCH_SOUND_PATH: String = "res://assets/sound/mode_switch.mp3"

# hint.mp3 - Звук подсказки/шпаргалки - при использовании подсказки или открытии шпаргалки
const HINT_SOUND_PATH: String = "res://assets/sound/hint.mp3"

# payout_correct.mp3 - Звук верной выплаты - при правильном расчёте выплаты
const PAYOUT_CORRECT_SOUND_PATH: String = "res://assets/sound/payout_correct.mp3"

# payout_wrong.mp3 - Звук ошибочной выплаты - при неправильном расчёте выплаты
const PAYOUT_WRONG_SOUND_PATH: String = "res://assets/sound/payout_wrong.mp3"

# tip_received.mp3 - Звук получения чаевых - при получении чаевых от гостя
const TIP_RECEIVED_SOUND_PATH: String = "res://assets/sound/tip_received.mp3"

# penalty.mp3 - Звук получения штрафа - при штрафе за неоплаченные ставки
const PENALTY_SOUND_PATH: String = "res://assets/sound/penalty.mp3"

# patience_lost.mp3 - Звук потери терпения - при уменьшении терпения гостя
const PATIENCE_LOST_SOUND_PATH: String = "res://assets/sound/patience_lost.mp3"

# heart.mp3 - Звук сердца (Heart Bet) - при выборе/выигрыше в Heart Bet
const HEART_SOUND_PATH: String = "res://assets/sound/heart.mp3"

# Звуки ставок гостей (8 вариантов)
const BET_SOUNDS_COUNT: int = 8
const BET_SOUND_PATH_TEMPLATE: String = "res://assets/sound/bet_sounds/bet_%d.mp3"

# ═══════════════════════════════════════════════════════════════════════════
# ПУТИ К РЕСУРСАМ
# ═══════════════════════════════════════════════════════════════════════════

const CHIP_TEXTURE_PATH_TEMPLATE: String = "res://assets/chips/chip_%s.png"

# ═══════════════════════════════════════════════════════════════════════════
# АНИМАЦИИ UI
# ═══════════════════════════════════════════════════════════════════════════

const SHAKE_OFFSET: float = 10.0              # Амплитуда тряски кнопки при ошибке
const SHAKE_DURATION: float = 0.05            # Длительность одного шага тряски
const VICTORY_TOAST_DELAY: float = 1.0        # Задержка после победы (показ тоста перед PayoutPopup)

# ═══════════════════════════════════════════════════════════════════════════
# ЦВЕТА ПЕРЕКЛЮЧАТЕЛЕЙ ВЫПЛАТ
# ═══════════════════════════════════════════════════════════════════════════

const PAYOUT_TOGGLE_COLOR_PLAYER: Color = Color(0.2, 0.4, 0.9, 1.0)   # Синий (Player)
const PAYOUT_TOGGLE_COLOR_BANKER: Color = Color(0.9, 0.2, 0.2, 1.0)   # Красный (Banker)
const PAYOUT_TOGGLE_COLOR_TIE: Color = Color(0.2, 0.9, 0.4, 1.0)      # Зелёный (Tie)
const PAYOUT_TOGGLE_DISABLED_ALPHA: float = 0.4                        # Прозрачность выключенного toggle

# ═══════════════════════════════════════════════════════════════════════════
# ПОДСКАЗКА (HINT SYSTEM)
# ═══════════════════════════════════════════════════════════════════════════

const MIN_LIVES_FOR_HINT: int = 2        # Минимум жизней для использования подсказки (survival mode)
const HINT_COST_SCORE: int = 5           # Стоимость подсказки в очках (normal mode)

# ═══════════════════════════════════════════════════════════════════════════
# ИМЕНА ГРУПП И СВОЙСТВ
# ═══════════════════════════════════════════════════════════════════════════

const GROUP_GAME_CONTROLLER: String = "game_controller"  # Имя группы для GameController
const PROPERTY_HEART_BAR: String = "heart_bar"           # Имя свойства heart_bar в survival_ui
const BET_GROUP_PAIRS: String = "pairs"                 # Группа ставок "pairs"

# ═══════════════════════════════════════════════════════════════════════════
# РЕЖИМЫ ИГРЫ
# ═══════════════════════════════════════════════════════════════════════════

const MODE_JUNKET: String = "junket"     # Режим игры Junket
const MODE_CLASSIC: String = "classic"   # Режим игры Classic
const MODE_EMPTY: String = ""            # Пустая строка (нет отложенной смены режима)

# ═══════════════════════════════════════════════════════════════════════════
# ЯЗЫКИ
# ═══════════════════════════════════════════════════════════════════════════

const LANG_RU: String = "ru"            # Русский язык
const LANG_EN: String = "en"            # Английский язык
