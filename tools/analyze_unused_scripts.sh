#!/bin/bash
# Скрипт для поиска неиспользуемых .gd файлов в проекте
# Использование: ./tools/analyze_unused_scripts.sh

echo "🔍 АНАЛИЗ НЕИСПОЛЬЗУЕМЫХ СКРИПТОВ"
echo "=================================="
echo ""

PROJECT_DIR="/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat"
cd "$PROJECT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📁 Поиск всех .gd файлов (кроме addons)..."
echo ""

# Счётчики
TOTAL_SCRIPTS=0
UNUSED_SCRIPTS=0

# Найти все .gd файлы (исключая addons и .godot)
while IFS= read -r script; do
    TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))

    # Получить имя файла без расширения
    filename=$(basename "$script" .gd)

    # Проверить, используется ли этот скрипт в других местах
    # Ищем упоминания в .gd, .tscn, .tres, project.godot

    # Подсчёт упоминаний (исключая сам файл)
    mentions=$(grep -r "$filename" \
        --include="*.gd" \
        --include="*.tscn" \
        --include="*.tres" \
        --include="project.godot" \
        --exclude-dir=".godot" \
        --exclude-dir="addons" \
        . | grep -v "^$script:" | wc -l)

    if [ "$mentions" -eq 0 ]; then
        echo -e "${RED}❌ НЕИСПОЛЬЗУЕМЫЙ:${NC} $script"
        UNUSED_SCRIPTS=$((UNUSED_SCRIPTS + 1))
    else
        echo -e "${GREEN}✅ ИСПОЛЬЗУЕТСЯ:${NC} $script ${YELLOW}($mentions упоминаний)${NC}"
    fi

done < <(find scripts -name "*.gd" -type f 2>/dev/null)

echo ""
echo "=================================="
echo "📊 ИТОГИ:"
echo "  Всего скриптов: $TOTAL_SCRIPTS"
echo -e "  ${GREEN}Используются: $((TOTAL_SCRIPTS - UNUSED_SCRIPTS))${NC}"
echo -e "  ${RED}Не используются: $UNUSED_SCRIPTS${NC}"
echo "=================================="
