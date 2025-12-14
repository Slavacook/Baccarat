#!/usr/bin/env python3
"""
Скрипт для замены всех print() на DebugLogger вызовы
"""
import re
import sys

def replace_prints_in_file(filepath):
    """Заменяет print() на соответствующие DebugLogger вызовы"""

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Паттерны замены (порядок важен - от специфичных к общим!)
    replacements = [
        # Инициализация (✅)
        (r'print\("✅ ([^"]+)"\)', r'DebugLogger.log_init("\1")'),
        (r"print\('✅ ([^']+)'\)", r"DebugLogger.log_init('\1')"),

        # Ошибки (❌, 🚫)
        (r'print\("❌ ([^"]+)"\)', r'DebugLogger.log_error("\1")'),
        (r'print\("🚫 ([^"]+)"\)', r'DebugLogger.log_error("\1")'),
        (r"print\('❌ ([^']+)'\)", r"DebugLogger.log_error('\1')"),

        # Восстановление состояния (♻️)
        (r'print\("♻️ ([^"]+)"\)', r'DebugLogger.log_restore("\1")'),
        (r"print\('♻️ ([^']+)'\)", r"DebugLogger.log_restore('\1')"),

        # Игровой процесс (🎮)
        (r'print\("🎮 ([^"]+)"\)', r'DebugLogger.log_game_flow("\1")'),
        (r"print\('🎮 ([^']+)'\)", r"DebugLogger.log_game_flow('\1')"),

        # Выплаты (💰, 🏦)
        (r'print\("💰 ([^"]+)"\)', r'DebugLogger.log_payout("\1")'),
        (r'print\("🏦 ([^"]+)"\)', r'DebugLogger.log_payout("\1")'),
        (r"print\('💰 ([^']+)'\)", r"DebugLogger.log_payout('\1')"),

        # Ставки (🎲)
        (r'print\("🎲 ([^"]+)"\)', r'DebugLogger.log_bet("\1")'),
        (r"print\('🎲 ([^']+)'\)", r"DebugLogger.log_bet('\1')"),

        # Предупреждения (⚠️)
        (r'print\("⚠️ ([^"]+)"\)', r'DebugLogger.log_warning("\1")'),
        (r"print\('⚠️ ([^']+)'\)", r"DebugLogger.log_warning('\1')"),

        # Разделители (===)
        (r'print\("=+"\)', r'DebugLogger.log_separator()'),
        (r"print\('=+'\)", r"DebugLogger.log_separator()"),

        # Обычные print() (должно быть последним!)
        (r'print\(', r'DebugLogger.log('),
    ]

    # Применяем замены
    for pattern, replacement in replacements:
        content = re.sub(pattern, replacement, content)

    # Проверяем, были ли изменения
    if content != original_content:
        # Создаем backup
        backup_path = filepath + '.backup'
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(original_content)
        print(f"✅ Создан backup: {backup_path}")

        # Сохраняем изменения
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

        # Подсчитываем количество замен
        original_count = original_content.count('print(')
        new_count = content.count('print(')
        replaced = original_count - new_count

        print(f"✅ Заменено {replaced} вызовов print() в {filepath}")
        print(f"   Осталось print(): {new_count}")
        return True
    else:
        print(f"ℹ️  Нет изменений в {filepath}")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Использование: python3 replace_prints.py <filepath>")
        sys.exit(1)

    filepath = sys.argv[1]
    replace_prints_in_file(filepath)
