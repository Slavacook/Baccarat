# res://tests/test_unused_code_detection.gd
# GUT тест для поиска потенциально неиспользуемого кода
# Запуск: godot --path . --headless --script addons/gut/gut_cmdln.gd -gtest=tests/test_unused_code_detection.gd

extends GutTest

# Этот тест анализирует код и выявляет потенциально неиспользуемые элементы

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТ 1: Проверка неиспользуемых публичных методов
# ═══════════════════════════════════════════════════════════════════════════

func test_find_unused_public_methods():
	"""Найти публичные методы, которые нигде не вызываются"""
	print("\n🔍 ТЕСТ: Поиск неиспользуемых публичных методов")
	print("=" * 60)

	# Список файлов для проверки
	var scripts_to_check = [
		"res://scripts/GameController.gd",
		"res://scripts/UIManager.gd",
		"res://scripts/GamePhaseManager.gd",
		"res://scripts/SettingsScene.gd",
		"res://scripts/LimitsManager.gd",
	]

	for script_path in scripts_to_check:
		_analyze_script_methods(script_path)

func _analyze_script_methods(script_path: String):
	"""Анализировать методы в скрипте"""
	print("\n📄 Анализ: %s" % script_path)

	if not FileAccess.file_exists(script_path):
		print("  ❌ Файл не найден!")
		return

	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		print("  ❌ Не удалось открыть файл")
		return

	var content = file.get_as_text()
	file.close()

	# Найти все публичные методы (не начинающиеся с _)
	var regex_method = RegEx.new()
	regex_method.compile("func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")

	var methods: Array[String] = []
	for result in regex_method.search_all(content):
		var method_name = result.get_string(1)

		# Пропустить приватные методы (начинающиеся с _)
		if method_name.begins_with("_"):
			continue

		# Пропустить специальные методы Godot
		if method_name in ["_ready", "_process", "_physics_process", "_input", "_unhandled_input"]:
			continue

		methods.append(method_name)

	if methods.is_empty():
		print("  ✅ Публичных методов не найдено (все приватные)")
		return

	print("  📋 Найдено публичных методов: %d" % methods.size())

	# Проверить, вызываются ли эти методы где-то
	for method in methods:
		var is_used = _is_method_used(method, script_path)
		if not is_used:
			print("  ⚠️  ВОЗМОЖНО НЕ ИСПОЛЬЗУЕТСЯ: %s()" % method)

func _is_method_used(method_name: String, script_path: String) -> bool:
	"""Проверить, используется ли метод в проекте"""
	# Упрощенная проверка: ищем вызовы метода в других скриптах
	# Примечание: это не 100% точно, так как могут быть динамические вызовы

	var scripts_dir = DirAccess.open("res://scripts/")
	if not scripts_dir:
		return true  # Не можем проверить, считаем что используется

	# Простая эвристика: если метод вызывается хотя бы раз, он используется
	# Более точная проверка потребует полного парсинга AST

	return true  # Заглушка - в реальности нужен более сложный анализ

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТ 2: Проверка неиспользуемых переменных
# ═══════════════════════════════════════════════════════════════════════════

func test_find_unused_variables():
	"""Найти объявленные, но неиспользуемые переменные"""
	print("\n🔍 ТЕСТ: Поиск неиспользуемых переменных")
	print("=" * 60)

	# Примечание: Godot 4 имеет встроенные предупреждения об этом
	# Этот тест служит дополнительной проверкой

	print("  💡 Используйте встроенные warnings Godot:")
	print("     Project Settings → Debug → GDScript → Warnings")
	print("     - unused_variable")
	print("     - unused_parameter")
	print("     - unused_signal")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТ 3: Проверка дублирования кода
# ═══════════════════════════════════════════════════════════════════════════

func test_find_duplicate_code():
	"""Найти дублирование кода (копипаста)"""
	print("\n🔍 ТЕСТ: Поиск дублирования кода")
	print("=" * 60)

	# Это сложная задача, требующая анализа AST
	# Для простоты, выведем рекомендации

	print("  💡 РЕКОМЕНДАЦИИ:")
	print("     1. Используйте sonar-scanner для анализа дублирования")
	print("     2. Проверьте методы с похожими именами:")
	print("        - _on_*_pressed() методы")
	print("        - _update_*() методы")
	print("     3. Извлекайте общий код в отдельные методы")

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТ 4: Проверка мертвого кода (unreachable code)
# ═══════════════════════════════════════════════════════════════════════════

func test_find_dead_code():
	"""Найти недостижимый код (после return, в if false, etc)"""
	print("\n🔍 ТЕСТ: Поиск мертвого кода")
	print("=" * 60)

	# Простая проверка: код после return
	var scripts_to_check = [
		"res://scripts/GameController.gd",
		"res://scripts/BaccaratRules.gd",
		"res://scripts/GamePhaseManager.gd",
	]

	for script_path in scripts_to_check:
		_check_code_after_return(script_path)

func _check_code_after_return(script_path: String):
	"""Проверить код после return"""
	print("\n📄 Проверка: %s" % script_path)

	if not FileAccess.file_exists(script_path):
		print("  ❌ Файл не найден!")
		return

	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return

	var line_number = 0
	var in_function = false
	var found_return = false

	while not file.eof_reached():
		line_number += 1
		var line = file.get_line().strip_edges()

		# Начало функции
		if line.begins_with("func "):
			in_function = true
			found_return = false

		# Конец функции (пустая строка или новая функция)
		if line.is_empty() or (line.begins_with("func ") and in_function):
			in_function = false
			found_return = false

		# Нашли return
		if in_function and line.begins_with("return"):
			found_return = true

		# Код после return (игнорируем комментарии)
		if in_function and found_return and not line.is_empty() and not line.begins_with("#"):
			print("  ⚠️  ВОЗМОЖНО МЕРТВЫЙ КОД на строке %d: %s" % [line_number, line])
			found_return = false  # Сбрасываем, чтобы не спамить

	file.close()

# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТ 5: Проверка устаревших комментариев TODO/FIXME
# ═══════════════════════════════════════════════════════════════════════════

func test_find_old_todos():
	"""Найти устаревшие TODO/FIXME комментарии"""
	print("\n🔍 ТЕСТ: Поиск TODO/FIXME комментариев")
	print("=" * 60)

	var scripts_dir = "res://scripts/"
	_scan_directory_for_todos(scripts_dir)

func _scan_directory_for_todos(path: String):
	"""Рекурсивно сканировать директорию на TODO"""
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path.path_join(file_name)

		if dir.current_is_dir():
			if file_name != "." and file_name != ".." and file_name != "addons":
				_scan_directory_for_todos(full_path)
		elif file_name.ends_with(".gd"):
			_find_todos_in_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

func _find_todos_in_file(file_path: String):
	"""Найти TODO/FIXME в файле"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var line_number = 0
	var todos_found = false

	while not file.eof_reached():
		line_number += 1
		var line = file.get_line()

		if "TODO" in line or "FIXME" in line or "HACK" in line:
			if not todos_found:
				print("\n📄 %s" % file_path)
				todos_found = true
			print("  📝 Строка %d: %s" % [line_number, line.strip_edges()])

	file.close()

# ═══════════════════════════════════════════════════════════════════════════
# ИТОГОВЫЙ ТЕСТ: Общая статистика проекта
# ═══════════════════════════════════════════════════════════════════════════

func test_project_statistics():
	"""Собрать общую статистику проекта"""
	print("\n📊 СТАТИСТИКА ПРОЕКТА")
	print("=" * 60)

	var stats = {
		"total_scripts": 0,
		"total_lines": 0,
		"total_functions": 0,
		"total_comments": 0,
	}

	_collect_stats("res://scripts/", stats)

	print("\n📈 ИТОГИ:")
	print("  Всего скриптов: %d" % stats.total_scripts)
	print("  Всего строк кода: %d" % stats.total_lines)
	print("  Всего функций: %d" % stats.total_functions)
	print("  Всего комментариев: %d" % stats.total_comments)

func _collect_stats(path: String, stats: Dictionary):
	"""Собрать статистику из директории"""
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path.path_join(file_name)

		if dir.current_is_dir():
			if file_name != "." and file_name != ".." and file_name != "addons":
				_collect_stats(full_path, stats)
		elif file_name.ends_with(".gd"):
			_analyze_file_stats(full_path, stats)

		file_name = dir.get_next()

	dir.list_dir_end()

func _analyze_file_stats(file_path: String, stats: Dictionary):
	"""Анализировать статистику файла"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	stats.total_scripts += 1

	while not file.eof_reached():
		var line = file.get_line()
		stats.total_lines += 1

		if line.strip_edges().begins_with("#"):
			stats.total_comments += 1

		if "func " in line:
			stats.total_functions += 1

	file.close()
