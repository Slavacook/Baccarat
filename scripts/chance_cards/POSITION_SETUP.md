# 🎴 Настройка позиций и анимации карт шанса

## 📍 Где настраивать позиции

### 1. **Миниатюра в хранилище** (ChanceCardStorage)

**Файл:** `scenes/Game.tscn` → узел `TopUI/ChanceCardStorage`

**В редакторе Godot:**

- Выберите узел `ChanceCardStorage` в дереве сцены
- В Inspector найдите секцию **Layout**
- Измените **Offset** (Left, Top, Right, Bottom) для позиции
- Измените **Scale** для размера миниатюры

**Или в коде:**

- `scripts/chance_cards/ChanceCardStorage.gd` → константа `STORAGE_POSITION_OFFSET`

---

### 2. **Карта на весь экран** (BaseChanceCardScene)

#### Способ 1: В сцене (рекомендуется)

**Файл:** `scenes/chance_cards/BaseChanceCardScene.tscn`

**В редакторе Godot:**

1. Откройте сцену `BaseChanceCardScene.tscn`
2. Выберите узел `CardTexture`
3. В Inspector → **Layout** → **Offset**:
   - `offset_left = -400.0` (левая граница)
   - `offset_top = -200.0` (верхняя граница)
   - `offset_right = 400.0` (правая граница)
   - `offset_bottom = 200.0` (нижняя граница)

**Размер карты:**

- Ширина = `offset_right - offset_left` = 400 - (-400) = **800 пикселей**
- Высота = `offset_bottom - offset_top` = 200 - (-200) = **400 пикселей**

**Смещение карты:**

- Чтобы сдвинуть вправо: увеличьте `offset_left` и `offset_right` на одинаковое значение
- Чтобы сдвинуть влево: уменьшите оба значения
- Чтобы сдвинуть вниз: увеличьте `offset_top` и `offset_bottom`
- Чтобы сдвинуть вверх: уменьшите оба значения

#### Способ 2: Через константу (для точной настройки)

**Файл:** `scripts/chance_cards/BaseChanceCardScene.gd` → строка 28

```gdscript
const FULLSCREEN_POSITION_OFFSET: Vector2 = Vector2(100, 0)
```

**Важно:** Эта константа применяется **дополнительно** к настройкам из сцены. Используйте её для небольшой корректировки позиции после настройки в редакторе.

**Примеры:**

- `Vector2(50, 0)` — сдвиг вправо на 50
- `Vector2(-30, 0)` — сдвиг влево на 30
- `Vector2(0, -20)` — сдвиг вверх на 20
- `Vector2(0, 30)` — сдвиг вниз на 30
- `Vector2(20, -10)` — вправо на 20, вверх на 10

**Примечание:** Автоматическая коррекция позиции отключена. Позиция карты полностью определяется настройками из сцены + `FULLSCREEN_POSITION_OFFSET`.

---

### 3. **Анимация появления карты**

**Файл:** `scripts/chance_cards/BaseChanceCardScene.gd` → строка 137-145

**Настройки:**

- Начальный scale: `Vector2(0.5, 0.5)` (50% размера)
- Конечный scale: `Vector2(1.0, 1.0)` (100% размера)
- Длительность: `0.3` секунды
- Easing: `Tween.EASE_OUT`
- Transition: `Tween.TRANS_BACK` (эффект "отскока")

**Чтобы изменить:**

```gdscript
# В методе show_fullscreen(), строка ~137
_tween.tween_property(card_texture, "scale", Vector2(1.0, 1.0), 0.3)
#                                                      ↑      ↑
#                                                  размер  длительность
```

---

### 4. **Анимация ухода в хранилище**

**Файл:** `scripts/chance_cards/BaseChanceCardScene.gd` → константы (строки 19-31)

**Константы:**

```gdscript
## Масштаб карты в хранилище (0.2 = 20% от исходного размера)
const STORAGE_SCALE: Vector2 = Vector2(0.2, 0.2)

## Длительность анимации ухода в хранилище (секунды)
const ANIMATION_DURATION: float = 0.5

## Смещение позиции для анимации ухода (для корректировки)
const POSITION_OFFSET: Vector2 = Vector2(0, 0)
```

**Настройки:**

- `STORAGE_SCALE` — размер карты в хранилище (0.2 = 20%)
- `ANIMATION_DURATION` — длительность анимации (0.5 сек)
- `POSITION_OFFSET` — смещение конечной позиции (для точной настройки)

---

## 🎯 Быстрая настройка (пошагово)

### Настроить позицию карты на весь экран:

1. **Откройте сцену:** `scenes/chance_cards/BaseChanceCardScene.tscn`
2. **Выберите узел:** `CardTexture`
3. **В Inspector → Layout → Offset:**
   - Измените `offset_left`, `offset_top`, `offset_right`, `offset_bottom`
   - Карта центрирована (anchor 0.5, 0.5), поэтому offset относительно центра
   - **Важно:** Эти настройки теперь не перебиваются кодом - они применяются напрямую
4. **Запустите игру** и проверьте позицию
5. **Если нужно точнее:** измените `FULLSCREEN_POSITION_OFFSET` в коде (дополнительная корректировка)

### Настроить размер карты:

1. В той же сцене `BaseChanceCardScene.tscn`
2. Узел `CardTexture` → Inspector → Layout → Offset
3. Измените разницу между `offset_right - offset_left` (ширина)
4. Измените разницу между `offset_bottom - offset_top` (высота)

### Настроить анимацию:

1. Откройте `scripts/chance_cards/BaseChanceCardScene.gd`
2. Найдите константы (строки 19-31)
3. Измените значения:
   - `STORAGE_SCALE` — размер в хранилище
   - `ANIMATION_DURATION` — скорость анимации
   - `FULLSCREEN_POSITION_OFFSET` — смещение позиции

---

## 📝 Примеры настроек

### Карта по центру экрана (текущая):

```gdscript
# BaseChanceCardScene.tscn
offset_left = -400.0
offset_top = -200.0
offset_right = 400.0
offset_bottom = 200.0
# Размер: 800×400 пикселей
```

### Карта смещена вправо:

```gdscript
# BaseChanceCardScene.tscn
offset_left = -300.0  # было -400
offset_top = -200.0
offset_right = 500.0  # было 400
offset_bottom = 200.0
# Или через константу:
const FULLSCREEN_POSITION_OFFSET: Vector2 = Vector2(100, 0)
```

### Карта большего размера:

```gdscript
# BaseChanceCardScene.tscn
offset_left = -500.0  # было -400
offset_top = -300.0    # было -200
offset_right = 500.0   # было 400
offset_bottom = 300.0  # было 200
# Размер: 1000×600 пикселей
```

---

## ⚙️ Все места настройки (чеклист)

- [ ] `scenes/chance_cards/BaseChanceCardScene.tscn` — размер и позиция карты на весь экран
- [ ] `scripts/chance_cards/BaseChanceCardScene.gd` → `FULLSCREEN_POSITION_OFFSET` — точная настройка позиции
- [ ] `scripts/chance_cards/BaseChanceCardScene.gd` → `STORAGE_SCALE` — размер в хранилище
- [ ] `scripts/chance_cards/BaseChanceCardScene.gd` → `ANIMATION_DURATION` — скорость анимации
- [ ] `scripts/chance_cards/BaseChanceCardScene.gd` → `POSITION_OFFSET` — смещение анимации ухода
- [ ] `scenes/Game.tscn` → `TopUI/ChanceCardStorage` — позиция миниатюры
- [ ] `scripts/chance_cards/ChanceCardStorage.gd` → `STORAGE_POSITION_OFFSET` — точная настройка миниатюры
