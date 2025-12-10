#!/bin/bash
# Скрипт для проверки использования autoload синглтонов
# Использование: ./tools/analyze_autoloads.sh

echo "🔧 АНАЛИЗ AUTOLOAD СИНГЛТОНОВ"
echo "=================================="
echo ""

PROJECT_DIR="/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat"
cd "$PROJECT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "📁 Чтение autoload из project.godot..."
echo ""

# Извлечь все autoload из project.godot
autoloads=$(grep -A 1 "^\[autoload\]" project.godot | tail -n +2 | grep "=" | cut -d'=' -f1)

if [ -z "$autoloads" ]; then
    echo -e "${RED}❌ Autoload секция не найдена в project.godot${NC}"
    exit 1
fi

TOTAL_AUTOLOADS=0
UNUSED_AUTOLOADS=0

# Проверить каждый autoload
while IFS= read -r autoload; do
    TOTAL_AUTOLOADS=$((TOTAL_AUTOLOADS + 1))

    echo -e "${BLUE}🔍 Проверяю: ${NC}$autoload"

    # Подсчитать упоминания в .gd файлах (исключая сам autoload)
    mentions=$(grep -r "$autoload\." \
        --include="*.gd" \
        --exclude-dir=".godot" \
        --exclude-dir="addons" \
        scripts/ | wc -l)

    if [ "$mentions" -eq 0 ]; then
        echo -e "${RED}  ❌ НЕ ИСПОЛЬЗУЕТСЯ${NC} (0 упоминаний)"
        UNUSED_AUTOLOADS=$((UNUSED_AUTOLOADS + 1))
    else
        echo -e "${GREEN}  ✅ Используется${NC} ${YELLOW}($mentions упоминаний)${NC}"

        # Показать примеры использования (первые 3)
        echo -e "  ${YELLOW}Примеры:${NC}"
        grep -r "$autoload\." \
            --include="*.gd" \
            --exclude-dir=".godot" \
            --exclude-dir="addons" \
            scripts/ | head -n 3 | while IFS= read -r line; do
                file=$(echo "$line" | cut -d':' -f1)
                code=$(echo "$line" | cut -d':' -f2- | xargs)
                echo -e "    ${file}: ${code:0:60}..."
            done
    fi

    echo ""

done <<< "$autoloads"

echo "=================================="
echo "📊 ИТОГИ:"
echo "  Всего autoload: $TOTAL_AUTOLOADS"
echo -e "  ${GREEN}Используются: $((TOTAL_AUTOLOADS - UNUSED_AUTOLOADS))${NC}"
echo -e "  ${RED}Не используются: $UNUSED_AUTOLOADS${NC}"
echo "=================================="
