# res://scripts/CardDealer.test.gd
# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТЫ ДЛЯ CardDealer
# ═══════════════════════════════════════════════════════════════════════════
#
# TODO: Написать полноценные тесты с использованием GUT (Godot Unit Test)
#
# Тесты которые нужно написать:
#
# 1. test_deal_first_four():
#    - Проверка что раздаются ровно 4 карты (2 игроку, 2 банкиру)
#    - Проверка что карты берутся из колоды
#    - Проверка что руки обновляются в HandManager
#
# 2. test_draw_player_third():
#    - Проверка что карта берётся из колоды
#    - Проверка что карта добавляется в руку игрока
#    - Проверка что возвращается правильная карта
#    - Проверка обработки пустой колоды (должен вернуть null)
#
# 3. test_draw_banker_third():
#    - Аналогично test_draw_player_third, но для банкира
#
# 4. test_integration_with_hand_manager():
#    - Проверка что CardDealer правильно работает с HandManager
#    - Проверка что состояние рук корректно обновляется
#
# Пример структуры теста (GUT):
# ```
# extends GutTest
#
# var dealer: CardDealer
# var deck: Deck
# var hand_manager: HandManager
#
# func before_each():
#     dealer = CardDealer.new()
#     deck = Deck.new()
#     hand_manager = HandManager.new()
#
# func test_deal_first_four():
#     dealer.deal_first_four(deck, hand_manager)
#     assert_eq(hand_manager.get_player_size(), 2, "Игрок должен получить 2 карты")
#     assert_eq(hand_manager.get_banker_size(), 2, "Банкир должен получить 2 карты")
# ```

