## Спецификация JSON-протокола WebSocket (Live Monitoring)

Документ фиксирует контракт между Godot-клиентом, сервером и trainer-dashboard.

## 1) Общий формат WS-сообщений

Любое сообщение передается в формате:

```json
{
  "type": "event_type",
  "data": {}
}
```

Общие поля метаданных в `data` (рекомендуемые для live-сообщений):

- `dealer_id: string`
- `display_name: string` (опционально)
- `round_number: integer`
- `timestamp: integer` (unix time в миллисекундах; если отправитель использует секунды, это должно быть явно задокументировано)

## 2) Legacy live-события (сохраняются для обратной совместимости)

### `round_started`

```json
{
  "type": "round_started",
  "data": {
    "dealer_id": "uuid",
    "display_name": "Dealer One",
    "round_number": 12,
    "timestamp": 1777027200000
  }
}
```

### `action_performed`

```json
{
  "type": "action_performed",
  "data": {
    "dealer_id": "uuid",
    "round_number": 12,
    "action_type": "winner_selection",
    "value": "Banker",
    "is_correct": true
  }
}
```

### `error_occurred`

```json
{
  "type": "error_occurred",
  "data": {
    "dealer_id": "uuid",
    "round_number": 12,
    "error_type": "player_wrong",
    "message": "Игрок не должен брать карту",
    "lives_remaining": 5
  }
}
```

### `round_completed`

```json
{
  "type": "round_completed",
  "data": {
    "dealer_id": "uuid",
    "round_number": 12,
    "accuracy": 0.95,
    "time_spent": 45,
    "is_game_over": false
  }
}
```

## 3) Новый canonical snapshot: `table_state` (v1)

`table_state` является источником правды для визуального live-view стола.
Dashboard должен строить визуальное состояние именно по `table_state`, а не по legacy-событиям.

### Пример

```json
{
  "type": "table_state",
  "data": {
    "schema_version": 1,
    "dealer_id": "uuid",
    "display_name": "Dealer One",
    "session_id": "session-uuid",
    "round_number": 12,
    "round_id": "session-uuid:uuid:12",
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

## 4) Enum `phase` (v1)

Допустимые значения:

- `waiting`
- `dealing_initial`
- `third_card_player`
- `third_card_banker`
- `winner_selection`
- `payout`
- `round_completed`

## 5) Формат карты (v1)

Элемент массива `player.cards[]` / `banker.cards[]`:

- `slot: integer` — индекс позиции (0..2)
- `code: string | null` — код карты в формате `RANK + SUIT`
- `visible: boolean` — карта видна на столе

Формат `code`:

- `RANK`: `A`, `2`..`10`, `J`, `Q`, `K`
- `SUIT`: `C`, `H`, `S`, `D`
- Примеры: `8H`, `10S`, `KD`, `AC`

## 6) Правила `event_seq`

- `event_seq` монотонно увеличивается в рамках `dealer_id` + `session_id`.
- Dashboard применяет только события с `event_seq > last_seq`.
- Повторные события с тем же `event_seq` должны игнорироваться (идемпотентность).

## 7) Правила `timestamp`

- Рекомендуемый формат: unix time в миллисекундах (UTC).
- `timestamp` должен отражать время формирования snapshot на клиенте.
- Если в legacy-событии timestamp отсутствует, dashboard может использовать локальное время приема для лога, но не как источник правды для table-state таймлайна.

## 8) Правила `round_id`

- `round_id` должен быть стабилен в рамках одного раунда.
- Рекомендуемый шаблон: `{session_id}:{dealer_id}:{round_number}`.
- При смене `round_id` dashboard начинает новый state трек раунда для данного дилера.

## 9) Совместимость

- Legacy-события (`round_started`, `action_performed`, `error_occurred`, `round_completed`) сохраняются.
- `table_state` добавляется как новый тип и не ломает существующие интеграции.
- До полной миграции UI:
  - лог событий может продолжать использовать legacy-события;
  - визуальный live-view стола должен использовать `table_state`.

Подробный контракт v1 вынесен также в `docs/TABLE_STATE_CONTRACT_V1.md`.
