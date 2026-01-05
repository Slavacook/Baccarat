#!/bin/bash
# Скрипт для анализа зависимостей перед рефакторингом
# Использование: ./tools/analyze_dependencies.sh [файл]

echo "🔍 АНАЛИЗ ЗАВИСИМОСТЕЙ"
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

TARGET_FILE="${1:-scripts/GameController.gd}"

if [ ! -f "$TARGET_FILE" ]; then
    echo -e "${RED}❌ Файл не найден: $TARGET_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Анализ файла: $TARGET_FILE${NC}"
echo ""

# ========================================
# 1. Найти все использования классов
# ========================================
echo -e "${BLUE}1. Используемые классы:${NC}"

# Ищем использования классов
grep -oE "[A-Z][a-zA-Z0-9]*\." "$TARGET_FILE" | sed 's/\.$//' | sort -u | while read class; do
    # Проверяем, что это не встроенный класс Godot
    if [[ ! "$class" =~ ^(Node|RefCounted|Control|CanvasLayer|TextureRect|Button|Label)$ ]]; then
        echo -e "  ${GREEN}→ $class${NC}"
    fi
done

echo ""

# ========================================
# 2. Найти все вызовы EventBus
# ========================================
echo -e "${BLUE}2. Использование EventBus:${NC}"

EVENTBUS_CALLS=$(grep -o "EventBus\.[a-z_]*" "$TARGET_FILE" | sort -u)

if [ -z "$EVENTBUS_CALLS" ]; then
    echo -e "${YELLOW}⚠️  EventBus не используется${NC}"
else
    echo "$EVENTBUS_CALLS" | while read call; do
        echo -e "  ${GREEN}→ $call${NC}"
    done
fi

echo ""

# ========================================
# 3. Найти все методы класса
# ========================================
echo -e "${BLUE}3. Методы класса:${NC}"

METHODS=$(grep -E "^func |^static func " "$TARGET_FILE" | sed 's/func //' | sed 's/static func //' | sed 's/(.*$//' | sort)

METHOD_COUNT=$(echo "$METHODS" | wc -l)
echo -e "  Всего методов: ${BLUE}$METHOD_COUNT${NC}"
echo ""

# Показываем первые 10 методов
echo "Первые 10 методов:"
echo "$METHODS" | head -10 | while read method; do
    echo -e "  ${GREEN}→ $method${NC}"
done

if [ "$METHOD_COUNT" -gt 10 ]; then
    echo -e "  ${YELLOW}... и ещё $((METHOD_COUNT - 10)) методов${NC}"
fi

echo ""

# ========================================
# 4. Найти большие методы (>50 строк)
# ========================================
echo -e "${BLUE}4. Большие методы (>50 строк):${NC}"

# Это упрощенная проверка - считаем строки между функциями
LARGE_METHODS=$(awk '/^func / {start=NR; name=$2} /^func |^class_name |^extends / && NR>start+50 {if(name) print name " (" (NR-start) " строк)"; start=NR; name=$2}' "$TARGET_FILE" 2>/dev/null)

if [ -z "$LARGE_METHODS" ]; then
    echo -e "${GREEN}✅ Больших методов не найдено${NC}"
else
    echo "$LARGE_METHODS" | while read method; do
        echo -e "${YELLOW}⚠️  $method${NC}"
    done
fi

echo ""

# ========================================
# 5. Статистика файла
# ========================================
echo -e "${BLUE}5. Статистика файла:${NC}"

LINES=$(wc -l < "$TARGET_FILE")
VARS=$(grep -E "^var |^@export var " "$TARGET_FILE" | wc -l)
CONSTS=$(grep -E "^const " "$TARGET_FILE" | wc -l)

echo -e "  Строк кода: ${BLUE}$LINES${NC}"
echo -e "  Переменных: ${BLUE}$VARS${NC}"
echo -e "  Констант: ${BLUE}$CONSTS${NC}"
echo -e "  Методов: ${BLUE}$METHOD_COUNT${NC}"

if [ "$LINES" -gt 1000 ]; then
    echo -e "  ${YELLOW}⚠️  Файл очень большой (>1000 строк)${NC}"
fi

echo ""
echo "=================================="
echo -e "${GREEN}✅ Анализ завершён${NC}"

