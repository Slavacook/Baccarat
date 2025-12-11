#!/bin/bash
# Безопасная очистка проекта
# Перемещает неиспользуемые файлы в _deprecated/ вместо удаления

echo "🧹 Начинаем безопасную очистку проекта..."
echo ""

# Переходим в корень проекта
cd "$(dirname "$0")/.."

# Создаём папку для устаревших файлов
mkdir -p _deprecated/{scripts,scenes,assets}

# Файлы которые ТОЧНО можно переместить:

echo "📦 Перемещаем addons/gut (тестовый фреймворк не нужен в финальной сборке)..."
if [ -d "addons/gut" ]; then
    mv addons/gut _deprecated/
    echo "  ✓ addons/gut → _deprecated/"
fi

echo ""
echo "📦 Перемещаем claude/ (Claude аддон не нужен в финальной сборке)..."
if [ -d "claude" ]; then
    mv claude _deprecated/
    echo "  ✓ claude/ → _deprecated/"
fi

echo ""
echo "📦 Перемещаем тесты (они не нужны в продакшене)..."
if [ -d "tests" ]; then
    mv tests _deprecated/
    echo "  ✓ tests/ → _deprecated/"
fi

echo ""
echo "📦 Перемещаем неиспользуемые сцены..."

# main.tscn - старая main сцена
if [ -f "main.tscn" ]; then
    mv main.tscn _deprecated/scenes/
    echo "  ✓ main.tscn → _deprecated/scenes/"
fi

# PayoutScene.tscn - старая сцена выплат
if [ -f "scenes/PayoutScene.tscn" ]; then
    mv scenes/PayoutScene.tscn _deprecated/scenes/
    echo "  ✓ scenes/PayoutScene.tscn → _deprecated/scenes/"
fi

# SettingsPopup.tscn - старый попап настроек
if [ -f "scenes/SettingsPopup.tscn" ]; then
    mv scenes/SettingsPopup.tscn _deprecated/scenes/
    echo "  ✓ scenes/SettingsPopup.tscn → _deprecated/scenes/"
fi

# dust.tscn - неиспользуемая пыль
if [ -f "scenes/dust.tscn" ]; then
    mv scenes/dust.tscn _deprecated/scenes/
    echo "  ✓ scenes/dust.tscn → _deprecated/scenes/"
fi

echo ""
echo "📦 Перемещаем неиспользуемые скрипты..."

# INTEGRATION_CODE.gd - какой-то интеграционный код
if [ -f "INTEGRATION_CODE.gd" ]; then
    mv INTEGRATION_CODE.gd _deprecated/scripts/
    echo "  ✓ INTEGRATION_CODE.gd → _deprecated/scripts/"
fi

# Dust.gd - скрипт для пыли
if [ -f "scripts/Dust.gd" ]; then
    mv scripts/Dust.gd _deprecated/scripts/
    echo "  ✓ scripts/Dust.gd → _deprecated/scripts/"
fi

# PayoutScene.gd - старый скрипт сцены выплат
if [ -f "scripts/scenes/PayoutScene.gd" ]; then
    mv scripts/scenes/PayoutScene.gd _deprecated/scripts/
    echo "  ✓ scripts/scenes/PayoutScene.gd → _deprecated/scripts/"
fi

echo ""
echo "📦 Перемещаем неиспользуемые ассеты..."

# open_card_11.png - лишний кадр анимации
if [ -f "assets/animation/animation_open_card/open_card_11.png" ]; then
    mv assets/animation/animation_open_card/open_card_11.png _deprecated/assets/
    echo "  ✓ open_card_11.png → _deprecated/assets/"
fi

# icon.svg - дефолтная иконка Godot
if [ -f "icon.svg" ]; then
    mv icon.svg _deprecated/
    echo "  ✓ icon.svg → _deprecated/"
fi

echo ""
echo "✅ Очистка завершена!"
echo ""
echo "📌 Что делать дальше:"
echo "  1. Открой проект в Godot"
echo "  2. Протестируй ВСЕ функции игры"
echo "  3. Если всё работает → можно удалить _deprecated/"
echo "  4. Если что-то сломалось → верни файлы из _deprecated/"
echo ""
echo "💡 Чтобы вернуть файлы обратно:"
echo "   cp -r _deprecated/* ."
echo ""
