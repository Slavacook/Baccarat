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
