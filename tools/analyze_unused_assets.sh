#!/bin/bash
# Скрипт для поиска неиспользуемых ресурсов (текстуры, etc)
# Использование: ./tools/analyze_unused_assets.sh

echo "🖼️  АНАЛИЗ НЕИСПОЛЬЗУЕМЫХ РЕСУРСОВ"
echo "=================================="
echo ""

PROJECT_DIR="/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat"
cd "$PROJECT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📁 Поиск ресурсов в assets/..."
echo ""

# Счётчики
TOTAL_ASSETS=0
UNUSED_ASSETS=0

# Расширения для проверки
extensions=("png" "jpg" "jpeg" "svg" "tres")

for ext in "${extensions[@]}"; do
    echo -e "${YELLOW}🔍 Проверяю .$ext файлы...${NC}"
    echo ""

    # Найти все файлы с этим расширением
    while IFS= read -r asset; do
        if [ -z "$asset" ]; then
            continue
        fi

        TOTAL_ASSETS=$((TOTAL_ASSETS + 1))

        # Получить имя файла без расширения
        filename=$(basename "$asset" ".$ext")

        # Проверить упоминания в коде
        mentions=$(grep -r "$filename" \
            --include="*.gd" \
            --include="*.tscn" \
            --include="*.tres" \
            --exclude-dir=".godot" \
            --exclude-dir="addons" \
            . | wc -l)

        if [ "$mentions" -eq 0 ]; then
            echo -e "${RED}  ❌ НЕИСПОЛЬЗУЕМЫЙ:${NC} $asset"
            UNUSED_ASSETS=$((UNUSED_ASSETS + 1))
        else
            echo -e "${GREEN}  ✅ Используется:${NC} $asset ${YELLOW}($mentions упоминаний)${NC}"
        fi

    done < <(find assets -name "*.$ext" -type f 2>/dev/null)

    echo ""
done

echo "=================================="
echo "📊 ИТОГИ:"
echo "  Всего ресурсов: $TOTAL_ASSETS"
echo -e "  ${GREEN}Используются: $((TOTAL_ASSETS - UNUSED_ASSETS))${NC}"
echo -e "  ${RED}Не используются: $UNUSED_ASSETS${NC}"
echo "=================================="
echo ""
echo "⚠️  ВНИМАНИЕ: Некоторые ресурсы могут загружаться динамически через load()."
echo "   Проверьте вручную перед удалением!"
