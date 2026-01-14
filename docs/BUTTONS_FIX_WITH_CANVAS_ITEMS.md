# Исправление кнопок с сохранением canvas_items режима

## Контекст

Пользователь откатил настройки к рабочему состоянию:
- `window/stretch/mode="canvas_items"` - растягивает canvas_items
- `window/stretch/aspect="expand"` - заполняет весь экран
- Графика не ломается, игра растягивается на весь экран

**Проблема:** Кнопки были с фиксированными координатами и смещались.

## Решение

Сохранили рабочие настройки растяжения и исправили позиционирование кнопок через якоря.

### 1. Исправлен SurvivalModeUI (сердечки)

**Было:**
```gdscript
[node name="SurvivalModeUI" parent="TopUI" instance=ExtResource("4_survival")]
offset_top = 600.0      # ❌ Фиксированная позиция
offset_bottom = 650.0
```

**Стало:**
```gdscript
[node name="SurvivalModeUI" parent="TopUI" instance=ExtResource("4_survival")]
anchors_preset = 5      # Центр по горизонтали
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 1.0       # Низ экрана
anchor_bottom = 1.0
offset_top = -50.0     # Отступ от низа
offset_bottom = 0.0
grow_horizontal = 2
grow_vertical = 0
```

### 2. Перемещена CardsButton (кнопка "Начать") в TopUI

**Было:**
- Кнопка в корне сцены (parent=".")
- Фиксированные координаты без якорей

**Стало:**
- Кнопка в TopUI (parent="TopUI")
- Использует якоря для позиционирования в правом нижнем углу

```gdscript
[node name="CardsButton" type="TextureButton" parent="TopUI"]
anchors_preset = 3      # Bottom Right
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -317.0   # Отступ от правого края
offset_top = -133.0    # Отступ от нижнего края
```

### 3. Обновлён connection для CardsButton

**Было:**
```gdscript
[connection signal="pressed" from="CardsButton" to="." method="_on_cards_button_pressed"]
```

**Стало:**
```gdscript
[connection signal="pressed" from="TopUI/CardsButton" to="." method="_on_cards_button_pressed"]
```

### 4. Обновлён ButtonUIManager.gd

Добавлен поиск CardsButton в TopUI:
```gdscript
# CardsButton теперь в TopUI (перемещена для адаптивности)
if scene.has_node("TopUI/CardsButton"):
    action_button = scene.get_node("TopUI/CardsButton")
elif scene.has_node("CardsButton"):
    action_button = scene.get_node("CardsButton")
else:
    action_button = scene.find_child("CardsButton", true, false)
```

## Сохранённые настройки

**НЕ изменялись (работают хорошо):**
```ini
[display]
window/stretch/mode="canvas_items"  # Растягивает canvas_items
window/stretch/aspect="expand"       # Заполняет весь экран
```

## Результат

- ✅ Игра растягивается на весь экран (canvas_items + expand)
- ✅ Графика не ломается
- ✅ Кнопки закреплены якорями и не смещаются
- ✅ SurvivalModeUI (сердечки) привязаны к низу по центру
- ✅ CardsButton (кнопка "Начать") привязана к правому нижнему углу

## Примечания

- `mode="canvas_items"` + `aspect="expand"` работает лучше для этой игры, чем `mode="viewport"` + `aspect="keep"`
- Якоря обеспечивают правильное позиционирование на всех экранах
- Все UI элементы теперь в TopUI (CanvasLayer), что защищает их от масштабирования камеры
