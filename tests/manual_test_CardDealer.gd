# res://tests/manual_test_CardDealer.gd
# ═══════════════════════════════════════════════════════════════════════════
# РУЧНОЙ ТЕСТ ДЛЯ CardDealer (без GUT)
# Запустите этот скрипт в Godot редакторе для проверки CardDealer
# ═══════════════════════════════════════════════════════════════════════════

extends Node

func _ready():
	# Явная задержка чтобы autoload скрипты успели инициализироваться
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("🧪 НАЧАЛО РУЧНОГО ТЕСТИРОВАНИЯ CardDealer")
	print("═══════════════════════════════════════════════════════════")
	print("")
	
	var tests_passed = 0
	var tests_failed = 0
	
	# Тест 1: deal_first_four
	print("📋 Тест 1: deal_first_four раздаёт 4 карты")
	var dealer = CardDealer.new()
	var deck = Deck.new()
	var hand_manager = HandManager.new()
	
	var initial_deck_size = deck.cards.size()
	dealer.deal_first_four(deck, hand_manager)
	
	if hand_manager.get_player_size() == 2 and hand_manager.get_banker_size() == 2:
		print("  ✅ PASS: Разданы 2 карты игроку и 2 банкиру")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 2+2 карты, получено %d+%d" % [hand_manager.get_player_size(), hand_manager.get_banker_size()])
		tests_failed += 1
	
	if deck.cards.size() == initial_deck_size - 4:
		print("  ✅ PASS: Из колоды взято 4 карты")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось %d карт в колоде, получено %d" % [initial_deck_size - 4, deck.cards.size()])
		tests_failed += 1
	
	# Тест 2: draw_player_third
	print("")
	print("📋 Тест 2: draw_player_third добавляет карту игроку")
	var player_third = dealer.draw_player_third(deck, hand_manager)
	
	if player_third != null and hand_manager.get_player_size() == 3:
		print("  ✅ PASS: Третья карта игрока раздана")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Третья карта не раздана или размер руки неверный")
		tests_failed += 1
	
	if hand_manager.get_player_third_card() == player_third:
		print("  ✅ PASS: Третья карта совпадает с возвращённой")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Третья карта не совпадает")
		tests_failed += 1
	
	# Тест 3: draw_banker_third
	print("")
	print("📋 Тест 3: draw_banker_third добавляет карту банкиру")
	var banker_third = dealer.draw_banker_third(deck, hand_manager)
	
	if banker_third != null and hand_manager.get_banker_size() == 3:
		print("  ✅ PASS: Третья карта банкира раздана")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Третья карта не раздана или размер руки неверный")
		tests_failed += 1
	
	if hand_manager.get_banker_third_card() == banker_third:
		print("  ✅ PASS: Третья карта совпадает с возвращённой")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Третья карта не совпадает")
		tests_failed += 1
	
	# Тест 4: Полная последовательность
	print("")
	print("📋 Тест 4: Полная последовательность раздачи")
	hand_manager.reset()
	deck = Deck.new()
	var full_deck_size = deck.cards.size()
	
	dealer.deal_first_four(deck, hand_manager)
	var p3 = dealer.draw_player_third(deck, hand_manager)
	var b3 = dealer.draw_banker_third(deck, hand_manager)
	
	if hand_manager.get_player_size() == 3 and hand_manager.get_banker_size() == 3:
		print("  ✅ PASS: Полная раздача выполнена (3+3 карты)")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось 3+3 карты, получено %d+%d" % [hand_manager.get_player_size(), hand_manager.get_banker_size()])
		tests_failed += 1
	
	if deck.cards.size() == full_deck_size - 6:
		print("  ✅ PASS: Из колоды взято 6 карт")
		tests_passed += 1
	else:
		print("  ❌ FAIL: Ожидалось %d карт в колоде, получено %d" % [full_deck_size - 6, deck.cards.size()])
		tests_failed += 1
	
	# Итоги
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("📊 ИТОГИ ТЕСТИРОВАНИЯ:")
	print("  ✅ Пройдено: %d" % tests_passed)
	print("  ❌ Провалено: %d" % tests_failed)
	print("  📈 Успешность: %.1f%%" % (100.0 * tests_passed / (tests_passed + tests_failed) if (tests_passed + tests_failed) > 0 else 0))
	print("═══════════════════════════════════════════════════════════")
	
	if tests_failed == 0:
		print("🎉 Все тесты пройдены успешно!")
	else:
		print("⚠️  Некоторые тесты провалены. Проверьте код.")
	
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("✅ Тестирование завершено")
	print("═══════════════════════════════════════════════════════════")

