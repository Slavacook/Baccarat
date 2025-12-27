# res://tests/manual_test_GuestMenuScene.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ GuestMenuScene (рефакторинг)
# Тестирует работу GuestMenuState и GuestMenuKeyboardNavigator
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ GuestMenuScene")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	# ═══════════════════════════════════════════════════════════════════
	# ТЕСТЫ: GuestMenuState
	# ═══════════════════════════════════════════════════════════════════
	
	print("═══════════════════════════════════════════════════════════")
	print("📋 ТЕСТЫ: GuestMenuState")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var menu_state = GuestMenuState.new()
	
	# Тест 1: Инициализация
	print("📋 Тест 1: Инициализация состояния")
	var selected1 = menu_state.get_selected_guest()
	var hovered1 = menu_state.get_hovered_guest()
	if selected1 == 0 and hovered1 == 0:
		print("  ✅ PASS: Начальное состояние корректно (selected=0, hovered=0)")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось selected=0, hovered=0, получено selected=%d, hovered=%d" % [selected1, hovered1])
		tests_failed += 1
	
	# Тест 2: Установка выбранного гостя
	print("")
	print("📋 Тест 2: Установка выбранного гостя")
	menu_state.set_selected_guest(3)
	var selected2 = menu_state.get_selected_guest()
	if selected2 == 3:
		print("  ✅ PASS: Выбранный гость = 3")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 3, получено %d" % selected2)
		tests_failed += 1
	
	# Тест 3: Проверка has_selected_guest
	print("")
	print("📋 Тест 3: Проверка has_selected_guest")
	var has_selected = menu_state.has_selected_guest()
	if has_selected:
		print("  ✅ PASS: has_selected_guest = true")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось true, получено false")
		tests_failed += 1
	
	# Тест 4: Установка hovered гостя
	print("")
	print("📋 Тест 4: Установка hovered гостя")
	menu_state.set_hovered_guest(5)
	var hovered4 = menu_state.get_hovered_guest()
	if hovered4 == 5:
		print("  ✅ PASS: Hovered гость = 5")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 5, получено %d" % hovered4)
		tests_failed += 1
	
	# Тест 5: Очистка hover
	print("")
	print("📋 Тест 5: Очистка hover")
	menu_state.clear_hover()
	var hovered5 = menu_state.get_hovered_guest()
	if hovered5 == 0:
		print("  ✅ PASS: Hover очищен (hovered=0)")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 0, получено %d" % hovered5)
		tests_failed += 1
	
	# Тест 6: Валидация границ (отрицательное значение)
	print("")
	print("📋 Тест 6: Валидация границ (отрицательное значение)")
	print("  ⚠️  Ожидаемое предупреждение в консоли - это нормально")
	menu_state.set_selected_guest(-1)
	var selected6 = menu_state.get_selected_guest()
	if selected6 == 3:  # Должно остаться предыдущее значение
		print("  ✅ PASS: Отрицательное значение проигнорировано")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Состояние изменилось, ожидалось 3, получено %d" % selected6)
		tests_failed += 1
	
	# Тест 7: Валидация границ (слишком большое значение)
	print("")
	print("📋 Тест 7: Валидация границ (слишком большое значение)")
	print("  ⚠️  Ожидаемое предупреждение в консоли - это нормально")
	menu_state.set_selected_guest(10)
	var selected7 = menu_state.get_selected_guest()
	if selected7 == 3:  # Должно остаться предыдущее значение
		print("  ✅ PASS: Значение > 6 проигнорировано")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Состояние изменилось, ожидалось 3, получено %d" % selected7)
		tests_failed += 1
	
	# Тест 8: Reset
	print("")
	print("📋 Тест 8: Reset состояния")
	menu_state.reset()
	var selected8 = menu_state.get_selected_guest()
	var hovered8 = menu_state.get_hovered_guest()
	if selected8 == 0 and hovered8 == 0:
		print("  ✅ PASS: Состояние сброшено (selected=0, hovered=0)")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось selected=0, hovered=0, получено selected=%d, hovered=%d" % [selected8, hovered8])
		tests_failed += 1
	
	# ═══════════════════════════════════════════════════════════════════
	# ТЕСТЫ: GuestMenuKeyboardNavigator
	# ═══════════════════════════════════════════════════════════════════
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("📋 ТЕСТЫ: GuestMenuKeyboardNavigator")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var navigator = GuestMenuKeyboardNavigator.new()
	
	# Тест 9: Инициализация
	print("📋 Тест 9: Инициализация навигатора")
	var level9 = navigator.current_level
	var focused9 = navigator.focused_guest_id
	var active9 = navigator.is_active
	if level9 == GuestMenuKeyboardNavigator.NavigationLevel.GUESTS and focused9 == 0 and not active9:
		print("  ✅ PASS: Начальное состояние корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Неправильное начальное состояние")
		tests_failed += 1
	
	# Тест 10: Reset
	print("")
	print("📋 Тест 10: Reset навигатора")
	navigator.current_level = GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON
	navigator.focused_guest_id = 5
	navigator.is_active = true
	navigator.reset()
	if navigator.current_level == GuestMenuKeyboardNavigator.NavigationLevel.GUESTS and \
	   navigator.focused_guest_id == 0 and not navigator.is_active:
		print("  ✅ PASS: Навигатор сброшен корректно")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Навигатор не сброшен корректно")
		tests_failed += 1
	
	# Тест 11: Активация
	print("")
	print("📋 Тест 11: Активация навигатора")
	# Устанавливаем простые callbacks для теста
	navigator.update_visibility_callback = func(): pass
	navigator.activate(4)  # Активируем с выбранным гостем 4
	if navigator.is_active and navigator.current_level == GuestMenuKeyboardNavigator.NavigationLevel.GUESTS and \
	   navigator.focused_guest_id == 4:
		print("  ✅ PASS: Навигатор активирован с гостем 4")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Активация не сработала корректно")
		tests_failed += 1
	
	# Тест 12: Деактивация
	print("")
	print("📋 Тест 12: Деактивация навигатора")
	navigator.deactivate()
	if not navigator.is_active and navigator.focused_guest_id == 0:
		print("  ✅ PASS: Навигатор деактивирован")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Деактивация не сработала корректно")
		tests_failed += 1
	
	# Тест 13: Enum уровней навигации
	print("")
	print("📋 Тест 13: Enum уровней навигации")
	var levels = [
		GuestMenuKeyboardNavigator.NavigationLevel.OK_BUTTON,
		GuestMenuKeyboardNavigator.NavigationLevel.WEALTH_OPTION,
		GuestMenuKeyboardNavigator.NavigationLevel.CHARACTER_OPTION,
		GuestMenuKeyboardNavigator.NavigationLevel.GUESTS
	]
	if levels[0] == 1 and levels[1] == 2 and levels[2] == 3 and levels[3] == 4:
		print("  ✅ PASS: Уровни навигации корректны (1,2,3,4)")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Неправильные значения enum")
		tests_failed += 1
	
	# ═══════════════════════════════════════════════════════════════════
	# ИТОГИ
	# ═══════════════════════════════════════════════════════════════════
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("📊 ИТОГИ ТЕСТИРОВАНИЯ")
	print("═══════════════════════════════════════════════════════════")
	print("")
	print("✅ Пройдено тестов: %d" % tests_passed)
	print("❌ Провалено тестов: %d" % tests_failed)
	print("📈 Всего тестов: %d" % (tests_passed + tests_failed))
	print("")
	
	if tests_failed == 0:
		print("🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!")
	else:
		print("⚠️ ЕСТЬ ПРОВАЛЕННЫЕ ТЕСТЫ - НУЖНА ПРОВЕРКА")
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("📝 ИНСТРУКЦИИ ДЛЯ РУЧНОГО ТЕСТИРОВАНИЯ UI")
	print("═══════════════════════════════════════════════════════════")
	print("")
	print("Для полной проверки рефакторинга выполните следующие действия:")
	print("")
	print("1. 🔘 ОТКРЫТИЕ МЕНЮ:")
	print("   - Откройте игру и перейдите в настройки")
	print("   - Нажмите кнопку для открытия меню гостей")
	print("   - ✅ Проверьте: меню открывается без ошибок")
	print("")
	print("2. 🖱️ ТЕСТИРОВАНИЕ МЫШЬЮ:")
	print("   - Наведите курсор на призрака гостя 1")
	print("   - ✅ Проверьте: появляется hover эффект")
	print("   - Кликните по призраку")
	print("   - ✅ Проверьте: гость включается, появляется досье")
	print("   - Кликните по другому гостю")
	print("   - ✅ Проверьте: выбор переключается, досье обновляется")
	print("   - Кликните по выбранному гостю ещё раз")
	print("   - ✅ Проверьте: гость выключается, досье исчезает")
	print("")
	print("3. ⌨️ ТЕСТИРОВАНИЕ КЛАВИАТУРОЙ:")
	print("   - Нажмите любую стрелку или WASD")
	print("   - ✅ Проверьте: активируется режим клавиатуры, появляется hover на госте")
	print("   - Используйте ←/→ или A/D для навигации между гостями")
	print("   - ✅ Проверьте: hover перемещается между гостями")
	print("   - Нажмите SPACE на неактивном госте")
	print("   - ✅ Проверьте: гость активируется")
	print("   - Используйте ↓/S для перехода к кнопкам досье")
	print("   - ✅ Проверьте: фокус переходит на CharacterOption")
	print("   - Используйте ↓/S для перехода к WealthOption")
	print("   - ✅ Проверьте: фокус переходит на WealthOption")
	print("   - Используйте ↓/S для перехода к OKButton")
	print("   - ✅ Проверьте: фокус переходит на OKButton")
	print("   - Используйте ↑/W для возврата вверх")
	print("   - ✅ Проверьте: навигация работает в обратном направлении")
	print("   - Нажмите SPACE на OKButton")
	print("   - ✅ Проверьте: меню закрывается")
	print("")
	print("4. 🎛️ ТЕСТИРОВАНИЕ ОПЦИЙ:")
	print("   - Выберите гостя")
	print("   - Измените характер через CharacterOption")
	print("   - ✅ Проверьте: изменение сохраняется")
	print("   - Измените обеспеченность через WealthOption")
	print("   - ✅ Проверьте: изменение сохраняется")
	print("")
	print("5. 🔄 ТЕСТИРОВАНИЕ ПЕРЕКЛЮЧЕНИЯ:")
	print("   - Включите несколько гостей (например, 1, 3, 5)")
	print("   - Выберите гостя 1")
	print("   - В режиме клавиатуры на кнопках досье используйте ←/→")
	print("   - ✅ Проверьте: переключение между включёнными гостями работает")
	print("")
	print("6. 🖱️⌨️ ПЕРЕКЛЮЧЕНИЕ МЕЖДУ МЫШЬЮ И КЛАВИАТУРОЙ:")
	print("   - Активируйте клавиатурный режим")
	print("   - Переместите мышь и кликните по гостю")
	print("   - ✅ Проверьте: клавиатурный режим деактивируется")
	print("   - Снова нажмите стрелку")
	print("   - ✅ Проверьте: клавиатурный режим активируется заново")
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("")

