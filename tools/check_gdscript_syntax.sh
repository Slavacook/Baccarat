#!/bin/bash
# Скрипт для проверки синтаксиса GDScript файлов
# Проверяет отступы и базовые синтаксические ошибки
# Использование: ./tools/check_gdscript_syntax.sh [путь_к_файлу_или_директории]

set -e

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
CHECKED_FILES=0

# Функция для проверки одного файла
check_file() {
	local file="$1"
	
	if [[ ! -f "$file" ]]; then
		echo -e "${RED}❌ Файл не найден: $file${NC}"
		ERRORS=$((ERRORS + 1))
		return 1
	fi
	
	CHECKED_FILES=$((CHECKED_FILES + 1))
	local has_errors=0
	
	# Проверка 1: Отступы после if/for/while/else/elif
	# Ищем строки с if/for/while/else/elif, которые заканчиваются на ":"
	# Следующая строка должна начинаться с табуляции
	local indent_errors=$(awk '
		/^\s*(if|for|while|else|elif)\s+.*:\s*$/ {
			# Нашли строку с условием/циклом
			getline next_line
			if (next_line != "" && next_line !~ /^\t/ && next_line !~ /^\s*$/) {
				print NR ": Строка после '"'"'if/for/while/else/elif'"'"' должна начинаться с табуляции: " next_line
			}
		}
	' "$file" 2>/dev/null || true)
	
	if [[ -n "$indent_errors" ]]; then
		echo -e "${RED}❌ Ошибки отступов в $file:${NC}"
		echo "$indent_errors" | while read -r line; do
			echo -e "  ${RED}→${NC} $line"
		done
		has_errors=1
		ERRORS=$((ERRORS + 1))
	fi
	
	# Проверка 2: Отступы после match
	local match_errors=$(awk '
		/^\s*match\s+.*:\s*$/ {
			# Нашли строку с match
			getline next_line
			if (next_line != "" && next_line !~ /^\t/ && next_line !~ /^\s*$/) {
				print NR ": Строка после '"'"'match'"'"' должна начинаться с табуляции: " next_line
			}
		}
	' "$file" 2>/dev/null || true)
	
	if [[ -n "$match_errors" ]]; then
		echo -e "${RED}❌ Ошибки отступов после match в $file:${NC}"
		echo "$match_errors" | while read -r line; do
			echo -e "  ${RED}→${NC} $line"
		done
		has_errors=1
		ERRORS=$((ERRORS + 1))
	fi
	
	# Проверка 3: Проверка на смешанные пробелы и табы (должны быть только табы для отступов)
	local mixed_indent=$(grep -n "^[ \t]*\t.*[ ].*\|^[ ]+\t" "$file" 2>/dev/null || true)
	if [[ -n "$mixed_indent" ]]; then
		echo -e "${YELLOW}⚠️  Смешанные отступы (пробелы и табы) в $file:${NC}"
		echo "$mixed_indent" | head -5 | while read -r line; do
			echo -e "  ${YELLOW}→${NC} $line"
		done
		WARNINGS=$((WARNINGS + 1))
	fi
	
	# Проверка 4: Открывающие скобки на той же строке (плохая практика, но не ошибка)
	# Пропускаем эту проверку, т.к. в GDScript это нормально
	
	# Проверка 5: Пустые блоки if/for без тела (потенциальная ошибка)
	local empty_blocks=$(grep -n "^\s*\(if\|for\|while\).*:\s*$" "$file" | while read -r line_info; do
		local line_num=$(echo "$line_info" | cut -d: -f1)
		local next_line=$(sed -n "$((line_num + 1))p" "$file")
		if [[ "$next_line" =~ ^[[:space:]]*(else|elif|#|$) ]]; then
			echo "$line_info: Возможно пустой блок"
		fi
	done)
	
	if [[ -n "$empty_blocks" ]]; then
		echo -e "${YELLOW}⚠️  Возможно пустые блоки в $file:${NC}"
		echo "$empty_blocks" | head -3 | while read -r line; do
			echo -e "  ${YELLOW}→${NC} $line"
		done
		WARNINGS=$((WARNINGS + 1))
	fi
	
	if [[ $has_errors -eq 0 ]]; then
		echo -e "${GREEN}✅ $file${NC}"
	fi
	
	return $has_errors
}

# Проверяем указанный файл/директорию или все .gd файлы в scripts/
if [[ $# -eq 0 ]]; then
	echo -e "${BLUE}🔍 Проверка синтаксиса всех GDScript файлов в scripts/...${NC}"
	echo ""
	
	# Проверяем все .gd файлы в scripts/
	while IFS= read -r -d '' file; do
		check_file "$file"
	done < <(find scripts -name "*.gd" -type f -print0 2>/dev/null)
else
	# Проверяем указанный путь
	if [[ -d "$1" ]]; then
		echo -e "${BLUE}🔍 Проверка синтаксиса GDScript файлов в $1...${NC}"
		echo ""
		while IFS= read -r -d '' file; do
			check_file "$file"
		done < <(find "$1" -name "*.gd" -type f -print0 2>/dev/null)
	elif [[ -f "$1" ]]; then
		echo -e "${BLUE}🔍 Проверка синтаксиса файла $1...${NC}"
		echo ""
		check_file "$1"
	else
		echo -e "${RED}❌ Неверный путь: $1${NC}"
		exit 1
	fi
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}ИТОГИ ПРОВЕРКИ:${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "Проверено файлов: ${CHECKED_FILES}"
echo -e "Ошибок: ${RED}${ERRORS}${NC}"
echo -e "Предупреждений: ${YELLOW}${WARNINGS}${NC}"

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
	echo -e "${GREEN}✅ Все проверки пройдены успешно!${NC}"
	exit 0
elif [[ $ERRORS -eq 0 ]]; then
	echo -e "${YELLOW}⚠️  Есть предупреждения, но критических ошибок нет${NC}"
	exit 0
else
	echo -e "${RED}❌ Найдены критические ошибки!${NC}"
	exit 1
fi
