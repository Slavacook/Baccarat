# TABLE_STATE Contract v1

Документ фиксирует минимальный snapshot-контракт для live-view стола в trainer-dashboard.

## 1. Назначение

`table_state` — canonical snapshot состояния стола дилера в live-сессии.

Цели:

- восстановление состояния стола в реальном времени;
- устойчивость к пропущенным/дублированным WS-событиям;
- отсутствие необходимости запускать Godot в dashboard.

## 2. Событие

```json
{
  "type": "table_state",
  "data": {}
}
```

## 3. Поля `data`

### 3.1 Идентификация и версионирование

- `schema_version: integer` — версия схемы (`1` для данного контракта).
- `dealer_id: string` — идентификатор дилера.
- `display_name: string` — отображаемое имя дилера (опционально).
- `session_id: string` — live-сессия (опционально, но рекомендуется).
- `round_number: integer` — номер раунда.
- `round_id: string` — стабильный id раунда.
- `event_seq: integer` — монотонный счетчик событий в рамках дилера+сессии.
- `timestamp: integer` — unix time в миллисекундах (UTC).

### 3.2 Игровая фаза

- `phase: string`

Допустимые значения v1:

- `waiting`
- `dealing_initial`
- `third_card_player`
- `third_card_banker`
- `winner_selection`
- `payout`
- `round_completed`

### 3.3 Карты и очки

- `player.cards: CardSlot[]`
- `player.score: integer | null`
- `banker.cards: CardSlot[]`
- `banker.score: integer | null`

`CardSlot`:

- `slot: integer` (0..2)
- `code: string | null` (`8H`, `KD`, `10S`, `AC`, либо `null` если карты нет)
- `visible: boolean`

### 3.4 Контекст действия и ошибки

- `last_action.type: string`
- `last_action.value: string | number | boolean | null`
- `error.active: boolean`
- `error.error_type: string | null`
- `error.message: string | null`
- `lives_remaining: integer | null`
- `is_game_over: boolean`

## 4. Нормы построения `round_id`

Рекомендуемый шаблон:

`{session_id}:{dealer_id}:{round_number}`

Требования:

- `round_id` не меняется в пределах одного раунда;
- при начале нового раунда `round_id` должен измениться.

## 5. Правила `event_seq`

- `event_seq` увеличивается на 1 при каждом новом snapshot.
- Последовательность ведется в контексте `dealer_id` + `session_id`.
- Dashboard применяет только события с `event_seq > last_seq`.
- События с `event_seq <= last_seq` игнорируются как дубликаты/устаревшие.

## 6. Правила `timestamp`

- Всегда UTC unix milliseconds.
- Значение отражает момент формирования snapshot на клиенте.
- Допускается отличие с серверным временем; для сортировки внутри одного дилера приоритет у `event_seq`.

## 7. Совместимость

- Legacy-события (`round_started`, `action_performed`, `error_occurred`, `round_completed`) не удаляются.
- Визуальный стол строится только по `table_state`.
- Лента событий может использовать legacy и/или `table_state`.

## 8. Пример payload

```json
{
  "type": "table_state",
  "data": {
    "schema_version": 1,
    "dealer_id": "9d8f7e2f-1f2b-4f52-bda7-e73eecdb6a33",
    "display_name": "Dealer One",
    "session_id": "6a2d8a59-8e6e-42be-bc90-f7a22f4ac6da",
    "round_number": 12,
    "round_id": "6a2d8a59-8e6e-42be-bc90-f7a22f4ac6da:9d8f7e2f-1f2b-4f52-bda7-e73eecdb6a33:12",
    "event_seq": 44,
    "timestamp": 1777027200456,
    "phase": "winner_selection",
    "player": {
      "cards": [
        { "slot": 0, "code": "8H", "visible": true },
        { "slot": 1, "code": "AC", "visible": true },
        { "slot": 2, "code": null, "visible": false }
      ],
      "score": 9
    },
    "banker": {
      "cards": [
        { "slot": 0, "code": "7D", "visible": true },
        { "slot": 1, "code": "2S", "visible": true },
        { "slot": 2, "code": null, "visible": false }
      ],
      "score": 9
    },
    "last_action": {
      "type": "choose_winner",
      "value": "Banker"
    },
    "error": {
      "active": false,
      "error_type": null,
      "message": null
    },
    "lives_remaining": 5,
    "is_game_over": false
  }
}
```
