# Правила работы с отступами в GDScript

## ⚠️ Критически важно

**GDScript требует строгого соблюдения отступов!** Неправильные отступы ломают парсер и делают файл непригодным для использования.

## 📋 Основные правила

### 1. Используйте ТАБЫ (не пробелы) для отступов

```gdscript
# ✅ ПРАВИЛЬНО
if condition:
	var variable = value
	do_something()

# ❌ НЕПРАВИЛЬНО (пробелы вместо табов)
if condition:
    var variable = value
    do_something()
```

### 2. Всегда добавляйте отступ после двоеточия

После `if`, `for`, `while`, `else`, `elif`, `match`, `func`, `class` следующая строка **ОБЯЗАТЕЛЬНО** должна начинаться с табуляции:

```gdscript
# ✅ ПРАВИЛЬНО
if condition:
	var result = calculate()
	return result

# ❌ НЕПРАВИЛЬНО - отсутствует отступ
if condition:
var result = calculate()  # ← ОШИБКА! Парсер не поймёт это как тело if
return result

# ❌ НЕПРАВИЛЬНО - неправильный отступ
if condition:
    var result = calculate()  # ← Пробелы вместо таба
    return result
```

### 3. Многострочные условия

При переносе условий на новую строку тело блока всё равно должно иметь отступ:

```gdscript
# ✅ ПРАВИЛЬНО
if (long_condition_1 and
	long_condition_2 and
	long_condition_3):
	var result = process()
	return result
```

### 4. Вложенные блоки

Каждый вложенный блок увеличивает отступ на один таб:

```gdscript
# ✅ ПРАВИЛЬНО
if outer_condition:
	if inner_condition:
		var value = get_value()
		process(value)
	else:
		do_alternative()
```

### 5. Match statements

```gdscript
# ✅ ПРАВИЛЬНО
match value:
	1:
		do_one()
	2:
		do_two()
	_:
		do_default()
```

## 🔧 Как избежать проблем

### 1. Настройки редактора

**Visual Studio Code / Cursor:**
- Включите "Editor: Insert Spaces" → **false**
- Включите "Editor: Detect Indentation" → **false**
- Используйте табы для отступов в `.gd` файлах

**Godot Editor:**
- Отступы настраиваются автоматически
- Используйте автоформатирование: `Ctrl+Alt+F` (или `Cmd+Alt+F` на Mac)

### 2. Визуализация отступов

Включите отображение пробелов и табов:
- VS Code/Cursor: View → Render Whitespace
- Это поможет увидеть разницу между табами и пробелами

### 3. Автоматическая проверка

Используйте скрипт проверки синтаксиса перед коммитом:

```bash
./tools/check_gdscript_syntax.sh scripts/GamePhaseManager.gd
```

Или проверьте все файлы:

```bash
./tools/check_gdscript_syntax.sh
```

### 4. Git pre-commit hook

Создайте `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Проверка синтаксиса GDScript перед коммитом

./tools/check_gdscript_syntax.sh

if [ $? -ne 0 ]; then
    echo "❌ Обнаружены ошибки синтаксиса! Исправьте их перед коммитом."
    exit 1
fi
```

## 🚨 Частые ошибки

### Ошибка #1: Отсутствие отступа после условия

**Причина:** Копирование-вставка, ручное редактирование без внимания к отступам

```gdscript
# ❌ ОШИБКА
if condition:
var result = value  # ← нет отступа!

# ✅ ИСПРАВЛЕНО
if condition:
	var result = value  # ← есть отступ (таб)
```

### Ошибка #2: Смешанные табы и пробелы

**Причина:** Редактирование в разных редакторах, копирование из интернета

```gdscript
# ❌ ОШИБКА
if condition:
	var a = 1
    var b = 2  # ← пробелы вместо таба!

# ✅ ИСПРАВЛЕНО
if condition:
	var a = 1
	var b = 2  # ← табы везде
```

### Ошибка #3: Неправильный отступ в многострочных выражениях

```gdscript
# ❌ ОШИБКА
if condition:
var result = function_call(
param1,  # ← неправильный отступ
param2
)

# ✅ ИСПРАВЛЕНО
if condition:
	var result = function_call(
		param1,  # ← правильный отступ
		param2
	)
```

## ✅ Чеклист перед коммитом

- [ ] Запущен `./tools/check_gdscript_syntax.sh`
- [ ] Нет ошибок синтаксиса
- [ ] Все отступы - табы (не пробелы)
- [ ] Все блоки после `:` имеют отступ
- [ ] Файл открывается в Godot без ошибок парсера

## 🔍 Как найти проблему

1. **Проверьте ошибку парсера в Godot:**
   ```
   Пarser Error: Could not parse global class "ClassName" from "res://path/to/file.gd"
   ```
   
2. **Найдите проблемную строку:**
   - Ошибка обычно указывает на строку, где парсер сбился
   - Проверьте отступы **перед** этой строкой

3. **Используйте скрипт проверки:**
   ```bash
   ./tools/check_gdscript_syntax.sh path/to/file.gd
   ```

4. **Проверьте визуально:**
   - Включите отображение пробелов/табов
   - Убедитесь, что все блоки правильно выровнены

## 📚 Дополнительные ресурсы

- [Официальная документация GDScript](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_basics.html)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

## 🛠️ Инструменты

- `tools/check_gdscript_syntax.sh` - автоматическая проверка синтаксиса
- Godot Editor - встроенная проверка синтаксиса (автоматическая)

---

**Помните:** Один неправильный отступ может сломать весь файл. Всегда проверяйте синтаксис перед коммитом!
