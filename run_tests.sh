#!/bin/bash
# Скрипт для запуска GUT тестов

echo "🧪 Запуск GUT тестов..."
echo ""

godot --path . --headless --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests/ \
  -ginclude_subdirs \
  -gprefix=test_ \
  -gsuffix=.gd \
  -gexit

echo ""
echo "✅ Тесты завершены!"
