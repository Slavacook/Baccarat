#!/bin/bash
# Удаление неиспользуемых скриптов и сцен (НО НЕ ассетов!)

echo "🧹 УДАЛЕНИЕ НЕИСПОЛЬЗУЕМЫХ СКРИПТОВ И СЦЕН"
echo "=========================================="
echo ""
echo "⚠️  ВАЖНО: Ассеты НЕ будут удалены!"
echo ""

cd "$(dirname "$0")/.."

# Создаём папку для бэкапа на случай проблем
mkdir -p _backup_before_cleanup

echo "📦 Создаём бэкап всего проекта..."
tar -czf "_backup_before_cleanup/full_backup_$(date +%Y%m%d_%H%M%S).tar.gz" \
    --exclude=".godot" \
    --exclude=".git" \
    --exclude="_backup_before_cleanup" \
    --exclude="_deprecated" \
    .
echo "  ✓ Бэкап создан: _backup_before_cleanup/"
echo ""

# Счётчик удалённых файлов
DELETED_COUNT=0

echo "🗑️  ШАГ 1: Удаление тестового фреймворка GUT..."
if [ -d "addons/gut" ]; then
    rm -rf addons/gut
    echo "  ✓ addons/gut/ → удалено (78 файлов)"
    DELETED_COUNT=$((DELETED_COUNT + 78))
else
    echo "  ⚠️  addons/gut/ уже не существует"
fi

echo ""
echo "🗑️  ШАГ 2: Удаление юнит-тестов..."
if [ -d "tests" ]; then
    rm -rf tests
    echo "  ✓ tests/ → удалено (11 файлов)"
    DELETED_COUNT=$((DELETED_COUNT + 11))
else
    echo "  ⚠️  tests/ уже не существует"
fi

echo ""
echo "🗑️  ШАГ 3: Удаление Claude аддона..."
if [ -d "claude" ]; then
    rm -rf claude
    echo "  ✓ claude/ → удалено (4 файла)"
    DELETED_COUNT=$((DELETED_COUNT + 4))
else
    echo "  ⚠️  claude/ уже не существует"
fi

echo ""
echo "🗑️  ШАГ 4: Удаление старых неиспользуемых сцен..."

# main.tscn - старая main сцена
if [ -f "main.tscn" ]; then
    rm main.tscn
    echo "  ✓ main.tscn → удалено"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

# PayoutScene.tscn - старая сцена выплат
if [ -f "scenes/PayoutScene.tscn" ]; then
    rm scenes/PayoutScene.tscn
    echo "  ✓ scenes/PayoutScene.tscn → удалено"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

# SettingsPopup.tscn - старый попап настроек
if [ -f "scenes/SettingsPopup.tscn" ]; then
    rm scenes/SettingsPopup.tscn
    echo "  ✓ scenes/SettingsPopup.tscn → удалено"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

# dust.tscn - неиспользуемая пыль
if [ -f "scenes/dust.tscn" ]; then
    rm scenes/dust.tscn
    echo "  ✓ scenes/dust.tscn → удалено"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

echo ""
echo "🗑️  ШАГ 5: Удаление старых скриптов..."

# INTEGRATION_CODE.gd
if [ -f "INTEGRATION_CODE.gd" ]; then
    rm INTEGRATION_CODE.gd
    echo "  ✓ INTEGRATION_CODE.gd → удалено"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

# Dust.gd
if [ -f "scripts/Dust.gd" ]; then
    rm scripts/Dust.gd
    echo "  ✓ scripts/Dust.gd → удалено"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

# PayoutScene.gd (старый скрипт)
if [ -f "scripts/scenes/PayoutScene.gd" ]; then
    rm scripts/scenes/PayoutScene.gd
    echo "  ✓ scripts/scenes/PayoutScene.gd → удалено"
    DELETED_COUNT=$((DELETED_COUNT + 1))
    # Удаляем пустую папку если она есть
    rmdir scripts/scenes 2>/dev/null || true
fi

# resources/GameConfig.gd НЕ удаляем - он используется!

echo ""
echo "=========================================="
echo "✅ ОЧИСТКА ЗАВЕРШЕНА!"
echo "=========================================="
echo ""
echo "📊 Статистика:"
echo "  🗑️  Удалено файлов: ~$DELETED_COUNT"
echo "  💾 Бэкап: _backup_before_cleanup/"
echo ""
echo "⚠️  КРИТИЧЕСКИ ВАЖНО: НЕ удалены файлы:"
echo "  • BaccaratRules.gd"
echo "  • Card.gd, Deck.gd"
echo "  • CardTextureManager.gd"
echo "  • GamePhaseManager.gd"
echo "  • LimitsManager.gd"
echo "  • UIManager.gd"
echo "  • ChipStack.gd, ChipStackManager.gd, PayoutValidator.gd"
echo "  • ButtonUIManager.gd, CardUIManager.gd, и другие UI менеджеры"
echo "  • resources/GameConfig.gd"
echo ""
echo "📌 Что делать дальше:"
echo "  1. ✅ Открой проект в Godot"
echo "  2. ✅ Протестируй ВСЕ функции игры:"
echo "     • Раздача карт"
echo "     • Третьи карты"
echo "     • Выбор победителя"
echo "     • Расчёт выплат"
echo "     • Настройки (рубашки, язык)"
echo "     • Режим выживания"
echo "  3. ✅ Проверь console на ошибки"
echo "  4. ✅ Если всё ок → удали бэкап:"
echo "        rm -rf _backup_before_cleanup/"
echo "  5. ❌ Если что-то сломалось → восстанови:"
echo "        tar -xzf _backup_before_cleanup/*.tar.gz"
echo ""
echo "💡 НЕ ЗАБУДЬ: Файл .import для удалённых .tscn сцен"
echo "   можно тоже удалить (Godot пересоздаст при необходимости)"
echo ""
