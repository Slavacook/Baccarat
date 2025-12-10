#!/bin/bash
# Безопасный скрипт для удаления неиспользуемых ресурсов
# Использование: ./tools/safe_cleanup.sh

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🧹 БЕЗОПАСНАЯ ОЧИСТКА ПРОЕКТА BACCARAT                   ║"
echo "║  Удаление неиспользуемых ресурсов                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_DIR="/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat"
cd "$PROJECT_DIR" || exit 1

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Счетчики
TOTAL_FILES=0
TOTAL_SIZE=0

echo -e "${CYAN}📋 План удаления:${NC}"
echo ""
echo "1. Стеки фишек (stack_*.png) - ~1.5 MB"
echo "2. Устаревшие UI элементы - ~0.2 MB"
echo "3. Лишний кадр анимации - ~0.05 MB"
echo ""
echo -e "${YELLOW}⚠️  ВНИМАНИЕ:${NC}"
echo "   - Карты (assets/cards/*.png) НЕ будут удалены (нужны!)"
echo "   - Атлас stacks.png НЕ будет удален (нужен!)"
echo "   - Неиспользуемые фишки НЕ будут удалены (требуют проверки)"
echo ""

# Спросить подтверждение
read -p "Продолжить? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Отменено${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}🔍 Проверка git статуса...${NC}"
echo ""

# Проверить, что проект под git
if [ ! -d .git ]; then
    echo -e "${RED}❌ ОШИБКА: Проект не находится под git!${NC}"
    echo "   Сначала инициализируйте git: git init && git add . && git commit -m 'Initial commit'"
    exit 1
fi

# Проверить, что нет незакомиченных изменений
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Есть незакомиченные изменения!${NC}"
    echo ""
    read -p "Создать backup commit? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add .
        git commit -m "backup: перед очисткой неиспользуемых ресурсов ($(date +%Y-%m-%d))"
        echo -e "${GREEN}✅ Backup commit создан${NC}"
    else
        echo -e "${RED}❌ Отменено - сначала сделайте commit${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${CYAN}🗑️  Начинаю удаление...${NC}"
echo ""

# Функция для безопасного удаления
safe_remove() {
    local file=$1
    if [ -f "$file" ]; then
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        rm "$file"
        TOTAL_FILES=$((TOTAL_FILES + 1))
        TOTAL_SIZE=$((TOTAL_SIZE + size))
        echo -e "${GREEN}✅ Удалено:${NC} $file ($(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo $size bytes))"
    else
        echo -e "${YELLOW}⚠️  Не найдено:${NC} $file"
    fi
}

# 1. Удалить стеки фишек
echo -e "${YELLOW}[1/3] Удаление stack_*.png...${NC}"
safe_remove "assets/chips/stack_100000.png"
safe_remove "assets/chips/stack_50000.png"
safe_remove "assets/chips/stack_25000.png"
safe_remove "assets/chips/stack_10000.png"
safe_remove "assets/chips/stack_5000.png"
safe_remove "assets/chips/stack_1000.png"
safe_remove "assets/chips/stack_500.png"
safe_remove "assets/chips/stack_100.png"
safe_remove "assets/chips/stack_25.png"
safe_remove "assets/chips/stack_5.png"
safe_remove "assets/chips/stack_1.png"
safe_remove "assets/chips/stack_0.5.png"
echo ""

# 2. Удалить устаревшие UI элементы
echo -e "${YELLOW}[2/3] Удаление устаревших UI элементов...${NC}"
safe_remove "assets/ui/Tie_win.png"
safe_remove "assets/ui/chip_bet.png"
safe_remove "assets/ui/chip_bet_1.png"
echo ""

# 3. Удалить лишний кадр анимации
echo -e "${YELLOW}[3/3] Удаление лишнего кадра анимации...${NC}"
safe_remove "assets/animation/animation_open_card/open_card_11.png"
echo ""

# Итоги
echo "════════════════════════════════════════════════════════════"
echo -e "${CYAN}📊 ИТОГИ:${NC}"
echo "  Удалено файлов: $TOTAL_FILES"
echo "  Освобождено места: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE 2>/dev/null || echo $TOTAL_SIZE bytes)"
echo "════════════════════════════════════════════════════════════"
echo ""

# Создать commit с изменениями
echo -e "${CYAN}💾 Создание commit...${NC}"
git add .
git commit -m "cleanup: удалены неиспользуемые ресурсы

- Удалены stack_*.png (12 файлов) - используется атлас
- Удалены устаревшие UI элементы (3 файла)
- Удален лишний кадр анимации (1 файл)
- Освобождено: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE 2>/dev/null || echo $TOTAL_SIZE bytes)

Анализ выполнен: tools/analyze_all.sh
Отчет: tools/ANALYSIS_SUMMARY.md"

echo ""
echo -e "${GREEN}✅ ОЧИСТКА ЗАВЕРШЕНА!${NC}"
echo ""
echo -e "${YELLOW}⚠️  ВАЖНО: Протестируйте игру (F5 в Godot)${NC}"
echo ""
echo -e "${CYAN}📝 Следующие шаги:${NC}"
echo "   1. Откройте проект в Godot"
echo "   2. Нажмите F5 для запуска"
echo "   3. Проверьте:"
echo "      - Раздачу карт"
echo "      - Выплаты с фишками"
echo "      - UI элементы"
echo "      - Анимации"
echo ""
echo "   Если что-то сломалось:"
echo "   git revert HEAD  # Откатить последний commit"
echo ""
