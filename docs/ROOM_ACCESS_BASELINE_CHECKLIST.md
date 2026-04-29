# Room Access Baseline Checklist

Snapshot date: 2026-04-28

## 1. Purpose

Этот документ фиксирует текущий рабочий baseline перед внедрением новой системы room access.

Цель Iteration 0:

- описать, как сейчас работает legacy PIN-flow;
- зафиксировать текущие endpoints и связанные файлы;
- подготовить ручной curl-checklist;
- заранее отметить, что нельзя сломать при Iteration 1 и следующих шагах.

В этом этапе нельзя менять backend-логику, модели, миграции, dashboard и Godot client.

## 2. Current Baseline Summary

Текущая система работает так:

- тренер регистрируется и входит через email/password;
- тренер создаёт комнату через `POST /api/rooms/`;
- при создании комнаты сервер генерирует `room_code` и набор 6-значных PIN-кодов;
- PIN-коды хранятся как bcrypt-хэши в `room_pins.pin_hash`;
- полный PIN возвращается тренеру в ответе создания комнаты;
- дилер входит через `POST /api/rooms/dealer/join` с `room_code`, `pin`, `display_name`;
- при первом успешном PIN join создаётся запись `Dealer`;
- найденный `RoomPin` привязывается к `Dealer` через `room_pins.dealer_id`;
- `Room.total_dealers` увеличивается на 1;
- повторный join с тем же PIN и тем же `display_name` работает;
- повторный join с тем же PIN, но другим `display_name`, возвращает `409` и `detail.code = NAME_MISMATCH`;
- `/api/auth/dealer/join` сейчас не является рабочим dealer join, он возвращает `501`;
- live/session endpoints сейчас в основном проверяют связь через `Dealer.room_id`.

Важно: старый PIN-flow должен остаться рабочим до отдельного этапа legacy cleanup.

## 3. Relevant Files

Backend files:

- `baccarat-server/app/main.py`
  - подключает роутеры;
  - `/api/auth`, `/api/rooms`, `/api/sessions`;
  - WebSocket подключается без `/api` prefix: `/ws/sessions/{session_id}`.
- `baccarat-server/app/api/auth.py`
  - trainer register/login/refresh/logout/whoami;
  - содержит `POST /api/auth/dealer/join`, но сейчас это `501 Not Implemented`.
- `baccarat-server/app/api/rooms.py`
  - создание комнат;
  - генерация `room_code`;
  - генерация и проверка PIN;
  - список комнат;
  - список PIN slots;
  - reset/delete PIN slots;
  - реальный legacy dealer join: `POST /api/rooms/dealer/join`;
  - текущий invite-token flow: `POST /api/rooms/dealer/join-invite`.
- `baccarat-server/app/api/sessions.py`
  - live session endpoints;
  - dealer access to active live session;
  - round results;
  - trainer results;
  - WebSocket `/ws/sessions/{session_id}`.
- `baccarat-server/app/dependencies.py`
  - `get_current_trainer`;
  - `get_current_dealer`;
  - проверка JWT role;
  - проверка `Dealer.is_active`.
- `baccarat-server/app/utils/auth.py`
  - создание и чтение JWT;
  - dealer access JWT содержит `sub = dealer.id`, `role = dealer`, `room_id`.

Models:

- `baccarat-server/app/models/trainer.py`
  - постоянный аккаунт тренера.
- `baccarat-server/app/models/room.py`
  - комната;
  - `room_code`;
  - `status`;
  - `max_dealers`;
  - `total_dealers`;
  - связи с `Dealer`, `RoomPin`, `Session`.
- `baccarat-server/app/models/dealer.py`
  - текущий дилер как участник комнаты;
  - `room_id` обязательный;
  - `display_name`;
  - `is_active`;
  - `device_id` и `device_claimed_at` для текущего invite-token flow.
- `baccarat-server/app/models/room_pin.py`
  - legacy PIN slot;
  - `pin_hash`;
  - `dealer_slot`;
  - `dealer_id nullable`;
  - `is_active`;
  - invite fields: `invite_token`, `invite_status`, `claimed_at`, `revoked_at`, `device_reset_at`.
- `baccarat-server/app/models/session.py`
  - `Session`;
  - `SessionParticipant`;
  - `SessionParticipant` связан с `dealer_id`.
- `baccarat-server/app/models/round_result.py`
  - результаты раундов по `session_id + dealer_id`.

Schemas:

- `baccarat-server/app/schemas/auth.py`
  - `TrainerRegisterRequest`;
  - `TrainerLoginRequest`;
  - `DealerJoinRequest`;
  - `DealerJoinResponse`;
  - `DealerInviteJoinRequest`;
  - `TokenResponse`.
- `baccarat-server/app/schemas/room.py`
  - `RoomCreateRequest`;
  - `PinResponse`;
  - `RoomResponse`;
  - `RoomCreateResponse`.
- `baccarat-server/app/schemas/session.py`
  - live session request/response schemas;
  - round result schema.

Existing tests that describe current behavior:

- `baccarat-server/tests/unit/test_auth.py`
  - trainer register/login/refresh/whoami;
  - dealer token cannot call trainer whoami.
- `baccarat-server/tests/unit/test_rooms.py`
  - create room;
  - list rooms;
  - dealer join;
  - wrong room;
  - wrong PIN;
  - invalid PIN format;
  - repeat same PIN/name;
  - name mismatch.
- `baccarat-server/tests/unit/test_sessions_live.py`
  - live session lifecycle;
  - active live session lookup for dealer;
  - round result submission;
  - trainer results.
- `baccarat-server/tests/conftest.py`
  - important risk: fixtures delete data and drop tables in `TEST_DATABASE_URL`.

## 4. Current Endpoints

Base API prefix: `/api`.

### Auth

- `POST /api/auth/trainer/register`
  - creates Trainer;
  - returns trainer access/refresh tokens.
- `POST /api/auth/trainer/login`
  - logs Trainer in;
  - returns trainer access/refresh tokens.
- `POST /api/auth/trainer/refresh`
  - refreshes trainer tokens.
- `POST /api/auth/trainer/logout`
  - stateless logout;
  - client deletes tokens.
- `GET /api/auth/trainer/whoami`
  - returns current trainer.
- `POST /api/auth/dealer/join`
  - currently returns `501 Not Implemented`;
  - this is not the real working dealer PIN join.

### Rooms and Legacy PIN Flow

- `POST /api/rooms/`
  - trainer-only;
  - creates room;
  - generates `room_code`;
  - creates `RoomPin` rows;
  - returns room plus plaintext PIN list once.
- `GET /api/rooms/`
  - trainer-only;
  - lists trainer rooms.
- `GET /api/rooms/{room_code}`
  - gets room details;
  - currently does not require trainer auth.
- `GET /api/rooms/{room_code}/dealers`
  - trainer-only room owner;
  - lists active dealers in room.
- `GET /api/rooms/{room_code}/pins`
  - trainer-only room owner;
  - lists active PIN slots;
  - returns `pin_id`, `dealer_slot`, `dealer_id`, `display_name`;
  - does not return plaintext PIN.
- `POST /api/rooms/{room_code}/pins`
  - trainer-only room owner;
  - adds one new PIN slot;
  - returns plaintext PIN for that new slot.
- `POST /api/rooms/{room_code}/pins/{dealer_slot}/reset`
  - trainer-only room owner;
  - deactivates existing dealer for slot if present;
  - generates new PIN;
  - clears `RoomPin.dealer_id`;
  - returns plaintext new PIN.
- `DELETE /api/rooms/{room_code}/pins/{dealer_slot}`
  - trainer-only room owner;
  - marks PIN slot inactive;
  - deactivates linked dealer if present.
- `DELETE /api/rooms/{room_code}`
  - trainer-only room owner;
  - sets room `CLOSED`;
  - marks room pins inactive;
  - marks room dealers inactive.
- `POST /api/rooms/dealer/join`
  - real legacy dealer PIN join;
  - body: `room_code`, `pin`, `display_name`;
  - creates or reuses Dealer;
  - returns dealer access/refresh tokens.
- `POST /api/rooms/dealer/join-invite`
  - current invite-token flow built on `RoomPin.invite_token`;
  - uses `device_id`;
  - not the accepted future access-code architecture.

### Live / Session Endpoints Depending on Dealer or Room

- `POST /api/rooms/{room_code}/sessions`
  - trainer-only room owner;
  - creates live session.
- `GET /api/rooms/{room_code}/active-live-session`
  - dealer-only;
  - uses `get_current_dealer`;
  - checks `dealer.room_id == room.id`.
- `GET /api/rooms/{room_code}/trainer-live-session`
  - trainer-only room owner.
- `POST /api/sessions/{session_id}/start`
  - trainer-only session owner.
- `POST /api/sessions/{session_id}/end`
  - trainer-only session owner.
- `POST /api/sessions/{session_id}/round-results`
  - dealer-only;
  - checks `dealer.room_id == session.room_id`;
  - creates `SessionParticipant` if missing;
  - writes `RoundResult`.
- `GET /api/sessions/{session_id}/results`
  - trainer-only session owner;
  - reads active dealers by `Dealer.room_id`.
- `GET /api/sessions/{session_id}/dealers/{dealer_id}/rounds`
  - trainer-only session owner;
  - checks dealer belongs to session room.
- `WebSocket /ws/sessions/{session_id}?token=...`
  - accepts trainer or dealer access JWT;
  - trainer must own session;
  - dealer must have `dealer.room_id == session.room_id`.

## 5. Manual Curl Checklist

Do not run this against production unless you intentionally want to create test data there.

These commands are for manual local/dev verification. They create a trainer, room, dealer and optionally live session data.

Prerequisites:

- backend server is running;
- `curl` is installed;
- `jq` is installed;
- use a disposable local/dev database.

```bash
set -euo pipefail

export BASE_URL="${BASE_URL:-http://localhost:8000}"
export WORKDIR="$(mktemp -d /tmp/baccarat-room-access-baseline.XXXXXX)"

export EMAIL="baseline-$(date +%s)@example.com"
export PASSWORD="BaselinePass123"
export FULL_NAME="Baseline Trainer"
export ROOM_NAME="Baseline PIN Room"
export MAX_DEALERS=5
export DEALER_NAME="Baseline Dealer"
export OTHER_DEALER_NAME="Other Baseline Dealer"

echo "Using BASE_URL=$BASE_URL"
echo "Writing response bodies to $WORKDIR"
```

### 5.1 Health check

```bash
curl -sS \
  -o "$WORKDIR/health.json" \
  -w "health status: %{http_code}\n" \
  "$BASE_URL/api/health"

jq . "$WORKDIR/health.json"
```

### 5.2 Register trainer

```bash
curl -sS \
  -o "$WORKDIR/register.json" \
  -w "register status: %{http_code}\n" \
  -X POST "$BASE_URL/api/auth/trainer/register" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg email "$EMAIL" \
    --arg password "$PASSWORD" \
    --arg full_name "$FULL_NAME" \
    '{email:$email,password:$password,full_name:$full_name}')"

jq . "$WORKDIR/register.json"
export REGISTER_TOKEN="$(jq -r '.access_token' "$WORKDIR/register.json")"
```

### 5.3 Login trainer

```bash
curl -sS \
  -o "$WORKDIR/login.json" \
  -w "login status: %{http_code}\n" \
  -X POST "$BASE_URL/api/auth/trainer/login" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg email "$EMAIL" \
    --arg password "$PASSWORD" \
    '{email:$email,password:$password}')"

jq . "$WORKDIR/login.json"
export TRAINER_TOKEN="$(jq -r '.access_token' "$WORKDIR/login.json")"
```

### 5.4 Create room and capture first PIN

```bash
curl -sS \
  -o "$WORKDIR/create-room.json" \
  -w "create room status: %{http_code}\n" \
  -X POST "$BASE_URL/api/rooms/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TRAINER_TOKEN" \
  --data "$(jq -n \
    --arg name "$ROOM_NAME" \
    --argjson max_dealers "$MAX_DEALERS" \
    '{name:$name,max_dealers:$max_dealers}')"

jq . "$WORKDIR/create-room.json"
export ROOM_CODE="$(jq -r '.room.room_code' "$WORKDIR/create-room.json")"
export PIN="$(jq -r '.pins[0].pin' "$WORKDIR/create-room.json")"

echo "ROOM_CODE=$ROOM_CODE"
echo "PIN=$PIN"
```

### 5.5 List rooms

```bash
curl -sS \
  -o "$WORKDIR/list-rooms.json" \
  -w "list rooms status: %{http_code}\n" \
  -H "Authorization: Bearer $TRAINER_TOKEN" \
  "$BASE_URL/api/rooms/"

jq . "$WORKDIR/list-rooms.json"
```

### 5.6 Get room by code

```bash
curl -sS \
  -o "$WORKDIR/get-room.json" \
  -w "get room status: %{http_code}\n" \
  "$BASE_URL/api/rooms/$ROOM_CODE"

jq . "$WORKDIR/get-room.json"
```

### 5.7 List PIN slots before dealer join

```bash
curl -sS \
  -o "$WORKDIR/pins-before-join.json" \
  -w "pins before join status: %{http_code}\n" \
  -H "Authorization: Bearer $TRAINER_TOKEN" \
  "$BASE_URL/api/rooms/$ROOM_CODE/pins"

jq . "$WORKDIR/pins-before-join.json"
```

### 5.8 First dealer PIN join

```bash
curl -sS \
  -o "$WORKDIR/dealer-first-join.json" \
  -w "dealer first join status: %{http_code}\n" \
  -X POST "$BASE_URL/api/rooms/dealer/join" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg room_code "$ROOM_CODE" \
    --arg pin "$PIN" \
    --arg display_name "$DEALER_NAME" \
    '{room_code:$room_code,pin:$pin,display_name:$display_name}')"

jq . "$WORKDIR/dealer-first-join.json"
export DEALER_TOKEN="$(jq -r '.access_token' "$WORKDIR/dealer-first-join.json")"
export DEALER_ID="$(jq -r '.user.id' "$WORKDIR/dealer-first-join.json")"
```

### 5.9 List PIN slots after dealer join

```bash
curl -sS \
  -o "$WORKDIR/pins-after-join.json" \
  -w "pins after join status: %{http_code}\n" \
  -H "Authorization: Bearer $TRAINER_TOKEN" \
  "$BASE_URL/api/rooms/$ROOM_CODE/pins"

jq . "$WORKDIR/pins-after-join.json"
```

### 5.10 Repeat dealer PIN join with same display_name

```bash
curl -sS \
  -o "$WORKDIR/dealer-repeat-same-name.json" \
  -w "dealer repeat same name status: %{http_code}\n" \
  -X POST "$BASE_URL/api/rooms/dealer/join" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg room_code "$ROOM_CODE" \
    --arg pin "$PIN" \
    --arg display_name "$DEALER_NAME" \
    '{room_code:$room_code,pin:$pin,display_name:$display_name}')"

jq . "$WORKDIR/dealer-repeat-same-name.json"
```

### 5.11 Repeat dealer PIN join with different display_name

```bash
curl -sS \
  -o "$WORKDIR/dealer-repeat-different-name.json" \
  -w "dealer repeat different name status: %{http_code}\n" \
  -X POST "$BASE_URL/api/rooms/dealer/join" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg room_code "$ROOM_CODE" \
    --arg pin "$PIN" \
    --arg display_name "$OTHER_DEALER_NAME" \
    '{room_code:$room_code,pin:$pin,display_name:$display_name}')"

jq . "$WORKDIR/dealer-repeat-different-name.json"
```

### 5.12 Optional: verify `/api/auth/dealer/join` is still not the real flow

```bash
curl -sS \
  -o "$WORKDIR/auth-dealer-join.json" \
  -w "auth dealer join status: %{http_code}\n" \
  -X POST "$BASE_URL/api/auth/dealer/join" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg room_code "$ROOM_CODE" \
    --arg pin "$PIN" \
    --arg display_name "$DEALER_NAME" \
    '{room_code:$room_code,pin:$pin,display_name:$display_name}')"

jq . "$WORKDIR/auth-dealer-join.json"
```

### 5.13 Optional live/session smoke check

This creates live session data in the selected dev database.

```bash
curl -sS \
  -o "$WORKDIR/create-live-session.json" \
  -w "create live session status: %{http_code}\n" \
  -X POST "$BASE_URL/api/rooms/$ROOM_CODE/sessions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TRAINER_TOKEN" \
  --data '{"duration_minutes":5,"max_rounds":10}'

jq . "$WORKDIR/create-live-session.json"
export SESSION_ID="$(jq -r '.session_id' "$WORKDIR/create-live-session.json")"

curl -sS \
  -o "$WORKDIR/dealer-active-live-created.json" \
  -w "dealer active live before start status: %{http_code}\n" \
  -H "Authorization: Bearer $DEALER_TOKEN" \
  "$BASE_URL/api/rooms/$ROOM_CODE/active-live-session"

jq . "$WORKDIR/dealer-active-live-created.json"

curl -sS \
  -o "$WORKDIR/start-live-session.json" \
  -w "start live session status: %{http_code}\n" \
  -X POST "$BASE_URL/api/sessions/$SESSION_ID/start" \
  -H "Authorization: Bearer $TRAINER_TOKEN"

jq . "$WORKDIR/start-live-session.json"

curl -sS \
  -o "$WORKDIR/dealer-active-live-active.json" \
  -w "dealer active live after start status: %{http_code}\n" \
  -H "Authorization: Bearer $DEALER_TOKEN" \
  "$BASE_URL/api/rooms/$ROOM_CODE/active-live-session"

jq . "$WORKDIR/dealer-active-live-active.json"
```

## 6. Expected Results

Expected results for the manual checklist:

- Health check:
  - status `200`;
  - body contains `{"status":"ok"}`.
- Register trainer:
  - status `201`;
  - response contains `access_token`, `refresh_token`;
  - `user.role = trainer`;
  - `user.email` equals `$EMAIL`.
- Login trainer:
  - status `200`;
  - response contains `access_token`, `refresh_token`;
  - `user.role = trainer`.
- Create room:
  - status `201`;
  - `room.room_code` starts with `TRAIN-`;
  - `room.room_code` length is currently 10, for example `TRAIN-ABCD`;
  - `pins` array length equals `$MAX_DEALERS`;
  - each `pin` is 6 digits.
- List rooms:
  - status `200`;
  - created room appears in the response.
- Get room:
  - status `200`;
  - returned `room_code` equals `$ROOM_CODE`.
- List PIN slots before join:
  - status `200`;
  - first slot has `dealer_id = null`;
  - first slot has `display_name = null`;
  - plaintext PIN is not returned.
- First dealer join:
  - status `200`;
  - response contains `access_token`, `refresh_token`;
  - `user.role = dealer`;
  - `user.room_code = $ROOM_CODE`;
  - `user.display_name = $DEALER_NAME`;
  - `user.is_first_login = true`.
- List PIN slots after join:
  - status `200`;
  - first slot has non-null `dealer_id`;
  - first slot has `display_name = $DEALER_NAME`.
- Repeat dealer join with same display name:
  - status `200`;
  - `user.is_first_login = false`;
  - `user.id` should match the first dealer join user id.
- Repeat dealer join with different display name:
  - status `409`;
  - response detail contains `code = NAME_MISMATCH`;
  - message says the PIN is already bound to the original name.
- Optional `/api/auth/dealer/join` check:
  - status `501`;
  - confirms this route is not the current real dealer join.
- Optional live/session smoke check:
  - create live session status `201`;
  - dealer active-live-session before start status `200`, with `status = created`;
  - start live session status `200`, with `status = active`;
  - dealer active-live-session after start status `200`, with `status = active` and non-null `round_seed`.

## 7. Must Not Break

Before Iteration 1 and every later change, this behavior must stay intact:

- trainer registration returns tokens;
- trainer login returns tokens;
- trainer can create room;
- room creation returns plaintext PIN list once;
- room creation creates `RoomPin` rows;
- `GET /api/rooms/` lists trainer rooms;
- `GET /api/rooms/{room_code}` returns room details;
- `GET /api/rooms/{room_code}/pins` returns PIN slots without plaintext PIN;
- `POST /api/rooms/dealer/join` remains the working legacy PIN join;
- first PIN join creates `Dealer`;
- first PIN join links `RoomPin.dealer_id`;
- first PIN join returns dealer JWT tokens;
- repeat PIN join with same `display_name` works;
- repeat PIN join with different `display_name` returns `NAME_MISMATCH`;
- wrong room code returns `ROOM_NOT_FOUND`;
- wrong PIN returns `INVALID_PIN`;
- invalid PIN format still returns validation error;
- closed room blocks dealer join;
- `Dealer.room_id` remains usable by current live/session endpoints;
- existing live/session endpoints continue to accept legacy dealer JWTs;
- WebSocket still accepts valid legacy dealer JWT when `dealer.room_id == session.room_id`;
- dashboard and Godot client flows that use `room_code + PIN` are not broken.

## 8. Post-Change Regression Checklist

After each future iteration, repeat at least this smoke check on a disposable dev/test database:

1. Register trainer.
2. Login trainer.
3. Create room with 5 PIN slots.
4. Save first PIN from create-room response.
5. Call `GET /api/rooms/{room_code}/pins`.
6. Join dealer with first PIN and display name.
7. Join again with the same PIN and same display name.
8. Join again with same PIN and different display name.
9. Confirm `NAME_MISMATCH`.
10. If live/session code was touched:
    - create live session;
    - get active live session as dealer;
    - start live session;
    - get active live session as dealer again;
    - confirm `Dealer.room_id` access checks still pass.

Fast command set:

- run the full script in section 5 on local/dev;
- compare actual status codes with section 6;
- do not proceed if any baseline result changes unexpectedly.

## 9. Notes / Risks

- Do not run the current pytest suite against a shared or production-like database.
- `baccarat-server/tests/conftest.py` uses `TEST_DATABASE_URL`, defaults to `postgresql+asyncpg://baccarat:baccarat@localhost:5432/baccarat_trainer`, deletes table data before tests and drops all metadata tables after the test session.
- Manual curl checks also create data, so they should use only disposable local/dev environments.
- Current `RoomPin` already has `invite_token` fields and `/api/rooms/dealer/join-invite`, but this is not the accepted future architecture.
- The accepted future architecture should use new `room_accesses` and `participant_tokens`, not more fields in `RoomPin`.
- Current WebSocket dealer check reads `Dealer` and checks `dealer.room_id`, but does not visibly check a future participant token yet. That should be handled later in the live/session integration iteration.
- Current `GET /api/rooms/{room_code}` is public. If this changes later, update clients and tests deliberately.
- Current dashboard caches plaintext PINs from create/reset responses because `GET /pins` does not return plaintext PIN.
- Any future migration must leave legacy `RoomPin` and `POST /api/rooms/dealer/join` working until the explicit legacy cleanup iteration.

