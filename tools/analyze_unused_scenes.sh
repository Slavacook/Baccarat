#!/bin/bash
# Скрипт для поиска неиспользуемых .tscn файлов в проекте
# Использование: ./tools/analyze_unused_scenes.sh

echo "🎬 АНАЛИЗ НЕИСПОЛЬЗУЕМЫХ СЦЕН"
echo "=================================="
echo ""

PROJECT_DIR="/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat"
cd "$PROJECT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📁 Поиск всех .tscn файлов..."
echo ""

# Счётчики
TOTAL_SCENES=0
UNUSED_SCENES=0

# Найти все .tscn файлы (исключая .godot)
while IFS= read -r scene; do
    TOTAL_SCENES=$((TOTAL_SCENES + 1))

    # Получить имя файла без расширения
    filename=$(basename "$scene" .tscn)

    # Получить относительный путь для поиска
    scene_path=${scene#./}

    # Проверить, используется ли эта сцена в других местах
    # Ищем упоминания в .gd, .tscn, project.godot

    # Подсчёт упоминаний (исключая саму сцену и .godot)
    mentions=$(grep -r "$filename" \
        --include="*.gd" \
        --include="*.tscn" \
        --include="project.godot" \
        --exclude-dir=".godot" \
        --exclude-dir="addons" \
        . | grep -v "^$scene:" | wc -l)

    # Также проверим по пути
    path_mentions=$(grep -r "$scene_path" \
        --include="*.gd" \
        --include="*.tscn" \
        --include="project.godot" \
        --exclude-dir=".godot" \
        --exclude-dir="addons" \
        . | wc -l)

    total_mentions=$((mentions + path_mentions))

    # Особые случаи: главные сцены (Game.tscn) всегда нужны
    if [[ "$filename" == "Game" ]]; then
        echo -e "${GREEN}✅ ГЛАВНАЯ СЦЕНА:${NC} $scene"
        continue
    fi

    if [ "$total_mentions" -eq 0 ]; then
        echo -e "${RED}❌ НЕИСПОЛЬЗУЕМАЯ:${NC} $scene"
        UNUSED_SCENES=$((UNUSED_SCENES + 1))
    else
        echo -e "${GREEN}✅ ИСПОЛЬЗУЕТСЯ:${NC} $scene ${YELLOW}($total_mentions упоминаний)${NC}"
    fi

done < <(find scenes -name "*.tscn" -type f 2>/dev/null)

echo ""
echo "=================================="
echo "📊 ИТОГИ:"
echo "  Всего сцен: $TOTAL_SCENES"
echo -e "  ${GREEN}Используются: $((TOTAL_SCENES - UNUSED_SCENES))${NC}"
echo -e "  ${RED}Не используются: $UNUSED_SCENES${NC}"
echo "=================================="
