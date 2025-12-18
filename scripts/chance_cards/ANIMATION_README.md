# Анимация карт шанса

## 📁 Файлы

- **`ChanceCardAnimation.gd`** - отдельный файл с логикой анимации
- **`BaseChanceCardScene.gd`** - использует анимацию через вызовы методов

## 🎬 Типы анимации

### Открытие карты:

1. **`SCALE_FROM_ZERO`** (по умолчанию) - карта появляется с масштаба 0, плавно увеличивается с эффектом "отскока"
2. **`SCALE_FROM_STORAGE`** - карта "вылетает" из позиции миниатюры к центру экрана
3. **`FADE_IN`** - простое появление с прозрачности

### Закрытие карты:

1. **`SCALE_TO_ZERO`** (по умолчанию) - карта уменьшается до 0 и исчезает
2. **`SCALE_TO_STORAGE`** - карта "улетает" обратно к миниатюре
3. **`FADE_OUT`** - простое исчезновение

## ⚙️ Настройка

### Изменить тип анимации:

В файле `BaseChanceCardScene.gd`, строки ~70 и ~95:

```gdscript
# Для открытия:
ChanceCardAnimation.animate_open(
    card_texture,
    background,
    ChanceCardAnimation.OpenType.SCALE_FROM_STORAGE,  # ← Изменить здесь
    storage_pos
)

# Для закрытия:
ChanceCardAnimation.animate_close(
    card_texture,
    background,
    ChanceCardAnimation.CloseType.SCALE_TO_STORAGE,  # ← Изменить здесь
    storage_pos,
    func(): _actually_hide_card()
)
```

### Изменить длительность:

В файле `ChanceCardAnimation.gd`, строки 14-17:

```gdscript
const OPEN_DURATION: float = 0.4   # Длительность открытия (секунды)
const CLOSE_DURATION: float = 0.3  # Длительность закрытия (секунды)
```

## 🚫 Отключение анимации

### Способ 1: Флаг в `BaseChanceCardScene.gd`

```gdscript
const USE_ANIMATION: bool = false  # ← Изменить на false
```

### Способ 2: Закомментировать вызовы

В `BaseChanceCardScene.gd`, строки ~70-75 и ~95-100:

```gdscript
# if USE_ANIMATION:
#     ChanceCardAnimation.animate_open(...)
```

### Способ 3: Удалить файл

Просто удалите `ChanceCardAnimation.gd` и закомментируйте вызовы в `BaseChanceCardScene.gd`.

## 📝 Примечания

- Анимация полностью отделена от основной логики
- Все позиции и размеры карты настраиваются через Inspector в сцене
- Анимация не влияет на финальную позицию карты (она всегда возвращается к исходным значениям)
