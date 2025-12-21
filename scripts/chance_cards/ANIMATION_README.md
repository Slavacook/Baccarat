# Анимация карт шанса

## 📁 Структура файлов

```
scripts/chance_cards/
├── animators/
│   ├── BaseCardAnimator.gd          # Базовый абстрактный класс
│   ├── ScaleFromZeroAnimator.gd     # Масштаб от 0 до 1
│   ├── ScaleFromStorageAnimator.gd  # Вылет из хранилища
│   └── FadeAnimator.gd              # Простой fade in/out
└── BaseChanceCardScene.gd           # Использует аниматоры
```

## 🎬 Типы анимации (Аниматоры)

### `ScaleFromZeroAnimator` (по умолчанию для открытия)
- Карта появляется с масштаба 0
- Плавно увеличивается с эффектом "отскока"
- Фон появляется плавно

### `ScaleFromStorageAnimator` (по умолчанию для закрытия)
- Карта "вылетает" из позиции миниатюры к центру экрана
- При закрытии "улетает" обратно к миниатюре
- Если позиция хранилища не задана, работает как `ScaleFromZero`

### `FadeAnimator`
- Простое появление/исчезновение
- Без масштабирования, только прозрачность

## ⚙️ Настройка

### Изменить аниматор:

В файле `BaseChanceCardScene.gd`, метод `_setup_animators()`:

```gdscript
func _setup_animators() -> void:
    # Можно заменить на любой аниматор:
    open_animator = FadeAnimator.new()           # Открытие с fade
    close_animator = ScaleFromZeroAnimator.new() # Закрытие с масштабом
```

### Установить аниматор программно:

```gdscript
# В любом месте после создания сцены
var scene = BaseChanceCardScene.new()
scene.set_open_animator(FadeAnimator.new())
scene.set_close_animator(ScaleFromStorageAnimator.new())
```

### Изменить длительность:

В файле `BaseCardAnimator.gd`:

```gdscript
const OPEN_DURATION: float = 0.4           # Длительность открытия
const CLOSE_DURATION: float = 0.2          # Длительность закрытия
const BACKGROUND_FADE_DURATION: float = 0.3 # Длительность появления фона
```

## 🚫 Отключение анимации

В файле `BaseChanceCardScene.gd`:

```gdscript
const USE_ANIMATION: bool = false  # ← Изменить на false
```

## 🆕 Создание нового аниматора

1. Создайте файл в `animators/`, например `MyCustomAnimator.gd`
2. Наследуйте от `BaseCardAnimator`
3. Переопределите методы:

```gdscript
class_name MyCustomAnimator
extends BaseCardAnimator

func prepare_for_open(card_texture: TextureRect, background: ColorRect) -> void:
    # Установить начальное состояние карты
    pass

func animate_open(card_texture: TextureRect, background: ColorRect) -> void:
    # Анимация открытия
    pass

func animate_close(card_texture: TextureRect, background: ColorRect, on_complete: Callable = Callable()) -> void:
    # Анимация закрытия
    # ВАЖНО: вызвать _connect_on_complete(tween, on_complete) в конце!
    pass
```

## 📝 Примечания

- **Strategy Pattern**: Каждый тип анимации - отдельный класс, легко расширять
- **Open/Closed Principle**: Новые аниматоры не требуют изменения существующего кода
- Все позиции и размеры карты настраиваются через Inspector в сцене
- Анимация не влияет на финальную позицию карты (восстанавливается к исходным значениям)
