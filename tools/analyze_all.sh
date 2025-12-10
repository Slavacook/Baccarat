#!/bin/bash
# Главный скрипт для запуска всех анализов проекта
# Использование: ./tools/analyze_all.sh

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🔍 ПОЛНЫЙ АНАЛИЗ ПРОЕКТА BACCARAT                        ║"
echo "║  Поиск неиспользуемого кода и ресурсов                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_DIR="/Users/vaaceslav/Личное Вячеслав/GitHub/Baccarat"
TOOLS_DIR="$PROJECT_DIR/tools"
REPORT_FILE="$PROJECT_DIR/tools/unused_analysis_report.txt"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Проверка, что мы в правильной директории
cd "$PROJECT_DIR" || exit 1

# Создать директорию tools если не существует
mkdir -p "$TOOLS_DIR"

# Сделать скрипты исполняемыми
chmod +x "$TOOLS_DIR"/*.sh 2>/dev/null

# Начать отчет
echo "ОТЧЕТ АНАЛИЗА ПРОЕКТА BACCARAT" > "$REPORT_FILE"
echo "Дата: $(date)" >> "$REPORT_FILE"
echo "======================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 1. Анализ скриптов
echo -e "${CYAN}[1/4]${NC} 🔍 Анализ неиспользуемых скриптов (.gd)..."
echo ""
if [ -f "$TOOLS_DIR/analyze_unused_scripts.sh" ]; then
    "$TOOLS_DIR/analyze_unused_scripts.sh" | tee -a "$REPORT_FILE"
else
    echo -e "${RED}❌ Скрипт analyze_unused_scripts.sh не найден${NC}"
fi
echo ""
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 2. Анализ сцен
echo -e "${CYAN}[2/4]${NC} 🎬 Анализ неиспользуемых сцен (.tscn)..."
echo ""
if [ -f "$TOOLS_DIR/analyze_unused_scenes.sh" ]; then
    "$TOOLS_DIR/analyze_unused_scenes.sh" | tee -a "$REPORT_FILE"
else
    echo -e "${RED}❌ Скрипт analyze_unused_scenes.sh не найден${NC}"
fi
echo ""
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 3. Анализ autoload
echo -e "${CYAN}[3/4]${NC} 🔧 Анализ autoload синглтонов..."
echo ""
if [ -f "$TOOLS_DIR/analyze_autoloads.sh" ]; then
    "$TOOLS_DIR/analyze_autoloads.sh" | tee -a "$REPORT_FILE"
else
    echo -e "${RED}❌ Скрипт analyze_autoloads.sh не найден${NC}"
fi
echo ""
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 4. Анализ ресурсов
echo -e "${CYAN}[4/4]${NC} 🖼️  Анализ неиспользуемых ресурсов..."
echo ""
if [ -f "$TOOLS_DIR/analyze_unused_assets.sh" ]; then
    "$TOOLS_DIR/analyze_unused_assets.sh" | tee -a "$REPORT_FILE"
else
    echo -e "${RED}❌ Скрипт analyze_unused_assets.sh не найден${NC}"
fi
echo ""
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Итоговая статистика
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ АНАЛИЗ ЗАВЕРШЕН                                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}📄 Полный отчет сохранен в:${NC}"
echo "   $REPORT_FILE"
echo ""
echo -e "${YELLOW}💡 РЕКОМЕНДАЦИИ:${NC}"
echo "   1. Проверьте отчет перед удалением файлов"
echo "   2. Некоторые файлы могут загружаться динамически"
echo "   3. Сделайте backup перед удалением"
echo "   4. Используйте git для отслеживания изменений"
echo ""
echo -e "${CYAN}📊 Просмотреть отчет:${NC}"
echo "   cat $REPORT_FILE"
echo ""
