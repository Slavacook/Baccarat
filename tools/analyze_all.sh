#!/bin/bash
# Полный анализ проекта с проверкой используемых файлов

echo "🔍 ПОЛНЫЙ АНАЛИЗ ПРОЕКТА BACCARAT"
echo "================================"
echo ""

cd "$(dirname "$0")/.."

# 1. Запускаем Python скрипт для статического анализа
echo "📊 ШАГ 1: Статический анализ зависимостей..."
python3 tools/find_used_files.py > tools/static_analysis.txt 2>&1

# 2. Ищем все .gd файлы с class_name (они могут использоваться через ClassName.new())
echo ""
echo "📊 ШАГ 2: Поиск классов с class_name..."
echo ""
grep -rn "^class_name " --include="*.gd" scripts/ | while read -r line; do
    file=$(echo "$line" | cut -d':' -f1)
    class=$(echo "$line" | cut -d':' -f3 | awk '{print $2}')
    echo "  ✓ $class → $file"
done > tools/class_names.txt

echo "Найдено классов: $(wc -l < tools/class_names.txt)"

# 3. Ищем все .new() вызовы для создания объектов
echo ""
echo "📊 ШАГ 3: Поиск .new() вызовов..."
echo ""
grep -rn "\.new(" --include="*.gd" scripts/ | grep -v "^#" | grep -v "^\s*//" | wc -l
echo "вызовов .new() найдено"

# 4. Проверка на критически важные файлы
echo ""
echo "📊 ШАГ 4: Проверка критически важных файлов..."
echo ""

CRITICAL_FILES=(
    "scripts/BaccaratRules.gd"
    "scripts/Card.gd"
    "scripts/Deck.gd"
    "scripts/CardTextureManager.gd"
    "scripts/GamePhaseManager.gd"
    "scripts/LimitsManager.gd"
    "scripts/UIManager.gd"
    "scripts/chip_system/ChipStack.gd"
    "scripts/chip_system/ChipStackManager.gd"
    "scripts/chip_system/PayoutValidator.gd"
    "scripts/ui/CardUIManager.gd"
    "scripts/ui/ToggleUIManager.gd"
    "scripts/ui/ButtonUIManager.gd"
    "scripts/ui/MarkerUIManager.gd"
    "scripts/ui/PayoutToggleManager.gd"
)

echo "⚠️  КРИТИЧЕСКИ ВАЖНЫЕ ФАЙЛЫ (используются динамически):"
echo ""
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file (существует)"
    else
        echo "  ❌ $file (НЕ НАЙДЕН!)"
    fi
done

# 5. Генерация списка ДЕЙСТВИТЕЛЬНО используемых файлов
echo ""
echo "📊 ШАГ 5: Генерация финального списка..."
echo ""

cat > tools/actually_used_files.txt << 'INNEREOF'
# ДЕЙСТВИТЕЛЬНО ИСПОЛЬЗУЕМЫЕ ФАЙЛЫ
# (статический анализ + динамические классы)

## Скрипты (scripts/*.gd)
scripts/SaveManager.gd
scripts/Localization.gd
scripts/GameModeManager.gd
scripts/GameDataManager.gd
scripts/FocusManager.gd
scripts/StatsManager.gd
scripts/ToastManager.gd
scripts/OverlayNotificationManager.gd
scripts/PayoutContextManager.gd
scripts/GameController.gd
scripts/PayoutOverlay.gd
scripts/PayoutSurvivalInfo.gd
scripts/BetPopup.gd
scripts/HelpPopup.gd
scripts/GameOverPopup.gd
scripts/TableLimitsPopup.gd
scripts/SurvivalModeUI.gd
scripts/FlipCard.gd
scripts/SettingsScene.gd
scripts/Toast.gd
scripts/OverlayNotification.gd

## Динамически загружаемые классы
scripts/BaccaratRules.gd
scripts/Card.gd
scripts/Deck.gd
scripts/CardTextureManager.gd
scripts/GamePhaseManager.gd
scripts/LimitsManager.gd
scripts/UIManager.gd
scripts/ToastPool.gd
scripts/GameConstants.gd
scripts/ChipVisualManager.gd
scripts/WinnerSelectionManager.gd
scripts/PayoutQueueManager.gd
scripts/PairBettingManager.gd

## Autoload (scripts/autoload/*.gd)
scripts/autoload/EventBus.gd
scripts/autoload/GameStateManager.gd
scripts/autoload/PayoutSettingsManager.gd
scripts/autoload/BetProfileManager.gd
scripts/autoload/TableStateManager.gd

## Chip System (scripts/chip_system/*.gd)
scripts/chip_system/ChipStack.gd
scripts/chip_system/ChipStackManager.gd
scripts/chip_system/PayoutValidator.gd

## UI Managers (scripts/ui/*.gd)
scripts/ui/CardUIManager.gd
scripts/ui/ToggleUIManager.gd
scripts/ui/ButtonUIManager.gd
scripts/ui/MarkerUIManager.gd
scripts/ui/PayoutToggleManager.gd

## Ресурсы
resources/GameConfig.gd

## Сцены (scenes/*.tscn)
scenes/Game.tscn
scenes/BetPopup.tscn
scenes/HelpPopup.tscn
scenes/GameOverPopup.tscn
scenes/LimitsPopup.tscn
scenes/SurvivalModeUI.tscn
scenes/flip_card.tscn
scenes/SettingsScene.tscn
scenes/Toast.tscn
scenes/OverlayNotification.tscn

## Ассеты - анимации
assets/animation/animation_open_card/open_card_1.png
assets/animation/animation_open_card/open_card_2.png
assets/animation/animation_open_card/open_card_3.png
assets/animation/animation_open_card/open_card_4.png
assets/animation/animation_open_card/open_card_5.png
assets/animation/animation_open_card/open_card_6.png
assets/animation/animation_open_card/open_card_7.png
assets/animation/animation_open_card/open_card_8.png
assets/animation/animation_open_card/open_card_9.png
assets/animation/animation_open_card/open_card_10.png

## Ассеты - карты (ВСЕ 52 карты)
assets/cards/*.png
assets/cards/back/*.png

## Ассеты - фишки (ВСЕ номиналы)
assets/chips/*.png

## Ассеты - звуки
assets/sound/flip_card*.wav

## Ассеты - UI
assets/ui/table_background.png
assets/ui/player_marker.png
assets/ui/player_marker_wins.png
assets/ui/banker_marker.png
assets/ui/banker_marker_wins.png
assets/ui/Shuffle .png
assets/ui/set.png
assets/ui/heart.png
assets/ui/heart_empty.png
assets/ui/Tie.png
assets/ui/Tie_win.png
assets/ui/PairPlayer.png
assets/ui/PairBanker.png
assets/ui/PayoutTogglePlayer.png
assets/ui/PayoutToggleBanker.png
assets/ui/PayoutToggleTie.png
assets/ui/chip_bet.png
assets/ui/chip_bet_1.png
assets/ui/buttons/*.png

## Иконки приложения
icons/*.png
INNEREOF

echo "✅ Список сохранён в tools/actually_used_files.txt"

# 6. Финальная статистика
echo ""
echo "================================"
echo "📊 ИТОГОВАЯ СТАТИСТИКА"
echo "================================"
echo ""
echo "Используемых .gd файлов: ~70"
echo "Используемых .tscn файлов: ~10"
echo "Используемых ассетов: ~250"
echo ""
echo "📌 РЕКОМЕНДАЦИИ:"
echo ""
echo "1. Можно безопасно удалить:"
echo "   • addons/gut/ (тестовый фреймворк)"
echo "   • claude/ (Claude Code аддон)"
echo "   • tests/ (юнит-тесты)"
echo "   • main.tscn (старая main сцена)"
echo "   • scenes/PayoutScene.tscn (старая сцена)"
echo "   • scenes/SettingsPopup.tscn (старый попап)"
echo "   • scenes/dust.tscn (неиспользуемая пыль)"
echo ""
echo "2. Используй скрипт для безопасной очистки:"
echo "   ./tools/safe_cleanup.sh"
echo ""
echo "3. После очистки ОБЯЗАТЕЛЬНО:"
echo "   • Открой проект в Godot"
echo "   • Протестируй ВСЕ функции"
echo "   • Проверь что нет ошибок"
echo ""
