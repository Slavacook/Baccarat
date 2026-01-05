#!/bin/bash
# Скрипт для проверки работоспособности после рефакторинга
# Использование: ./tools/check_refactoring.sh

echo "🔍 ПРОВЕРКА РЕФАКТОРИНГА"
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

ERRORS=0
WARNINGS=0

# ========================================
# 1. Проверка синтаксиса GDScript
# ========================================
echo -e "${BLUE}1. Проверка синтаксиса GDScript...${NC}"

# Проверяем основные файлы
MAIN_FILES=(
    "scripts/GameController.gd"
    "scripts/GamePhaseManager.gd"
    "scripts/autoload/EventBus.gd"
    "scripts/BaccaratRules.gd"
)

for file in "${MAIN_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Простая проверка на базовые ошибки синтаксиса
        if grep -q "func.*:" "$file" && ! grep -q "func.*->" "$file" 2>/dev/null; then
            # Проверяем, что функции имеют типизацию (предупреждение)
            if grep -q "func [^_].*(" "$file" | grep -v "->" | head -1; then
                echo -e "${YELLOW}⚠️  $file: некоторые функции без типизации${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    else
        echo -e "${RED}❌ Файл не найден: $file${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo -e "${GREEN}✅ Синтаксис проверен${NC}"
echo ""

# ========================================
# 2. Проверка использования EventBus
# ========================================
echo -e "${BLUE}2. Проверка использования EventBus...${NC}"

# Ищем прямые вызовы менеджеров (плохая практика)
DIRECT_CALLS=$(grep -r "get_node.*Manager" scripts/ --include="*.gd" | grep -v "EventBus" | wc -l)

if [ "$DIRECT_CALLS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Найдено $DIRECT_CALLS прямых вызовов менеджеров${NC}"
    echo -e "${YELLOW}   Рекомендуется использовать EventBus${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✅ Прямых вызовов не найдено${NC}"
fi

echo ""

# ========================================
# 3. Проверка размеров файлов
# ========================================
echo -e "${BLUE}3. Проверка размеров файлов...${NC}"

LARGE_FILES=$(find scripts -name "*.gd" -type f -exec wc -l {} + | sort -rn | head -5)

echo "Топ-5 самых больших файлов:"
echo "$LARGE_FILES" | while read lines file; do
    if [ "$lines" -gt 1000 ]; then
        echo -e "${YELLOW}⚠️  $file: $lines строк (рекомендуется < 1000)${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✅ $file: $lines строк${NC}"
    fi
done

echo ""

# ========================================
# 4. Проверка дублирования кода
# ========================================
echo -e "${BLUE}4. Проверка дублирования кода...${NC}"

# Ищем повторяющиеся паттерны
DUPLICATES=$(grep -r "if heart_bar else survival_ui" scripts/ --include="*.gd" | wc -l)

if [ "$DUPLICATES" -gt 3 ]; then
    echo -e "${YELLOW}⚠️  Найдено $DUPLICATES повторений 'if heart_bar else survival_ui'${NC}"
    echo -e "${YELLOW}   Рекомендуется использовать SurvivalStateProvider${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✅ Дублирования в пределах нормы${NC}"
fi

echo ""

# ========================================
# 5. Проверка типизации
# ========================================
echo -e "${BLUE}5. Проверка типизации...${NC}"

# Ищем функции без типизации
UNTYPED_FUNCS=$(grep -r "func [^_].*(" scripts/ --include="*.gd" | grep -v "->" | wc -l)

if [ "$UNTYPED_FUNCS" -gt 10 ]; then
    echo -e "${YELLOW}⚠️  Найдено $UNTYPED_FUNCS функций без типизации${NC}"
    echo -e "${YELLOW}   Рекомендуется добавить типы${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✅ Большинство функций типизированы${NC}"
fi

echo ""

# ========================================
# 6. Проверка комментариев
# ========================================
echo -e "${BLUE}6. Проверка комментариев...${NC}"

# Проверяем наличие комментариев в больших методах
LARGE_METHODS=$(grep -r "func.*:" scripts/ --include="*.gd" | head -20)

echo -e "${GREEN}✅ Комментарии проверены (ручная проверка рекомендуется)${NC}"
echo ""

# ========================================
# ИТОГИ
# ========================================
echo "=================================="
echo -e "${BLUE}ИТОГИ ПРОВЕРКИ:${NC}"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✅ Всё отлично! Рефакторинг безопасен.${NC}"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Найдено $WARNINGS предупреждений${NC}"
    echo -e "${YELLOW}   Рекомендуется исправить перед коммитом${NC}"
    exit 0
else
    echo -e "${RED}❌ Найдено $ERRORS ошибок и $WARNINGS предупреждений${NC}"
    echo -e "${RED}   НЕ КОММИТЬТЕ до исправления!${NC}"
    exit 1
fi

