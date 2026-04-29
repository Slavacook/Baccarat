# Room Access Implementation Plan

## 1. Product Goal

Новая система нужна для онлайн-тренировок без аккаунтов дилеров.

Целевой сценарий:

- тренер входит в dashboard через свой постоянный аккаунт;
- тренер создаёт тренировочную комнату и задаёт количество мест;
- сервер создаёт персональные доступы для каждого места;
- тренер видит access-code для каждого слота и отправляет конкретный код конкретному дилеру вручную;
- дилер открывает игру, выбирает онлайн-режим, вставляет access-code и вводит публичное имя;
- сервер по access-code понимает комнату и слот;
- после первой активации сервер создаёт/привязывает участника комнаты и выдаёт participant token;
- игра сохраняет participant token локально;
- дальше дилер видит комнату в списке без повторного ввода кода;
- тренер видит участников, их внутренние имена, публичные имена, статусы и может управлять доступами.

Главная идея: дилер не является постоянным пользователем сервиса. Дилер является участником конкретной комнаты.

## 2. Accepted Architecture

Принятые решения:

- не делать dealer email/password;
- не делать dealer register/login;
- не делать постоянный `dealer_code` для человека;
- access-code привязан к конкретной комнате и конкретному слоту;
- дилер вводит один access-code, без отдельного `room_code + PIN`;
- access-code нужен только для первой активации;
- после активации используется participant token;
- `room_accesses` создаётся отдельно от `room_pins`;
- `participant_tokens` создаётся отдельно;
- `Dealer` остаётся участником комнаты, а не аккаунтом;
- `Dealer.display_name` используется как публичное имя дилера;
- старый PIN-flow остаётся временно как legacy/reserve;
- старую `RoomPin` не расширяем под новую систему, чтобы не смешивать legacy PIN-flow и новый access-code flow.

Важно: access-code может быть технически случайной строкой, а связь с комнатой и слотом хранится в базе. Для пользователя это всё равно один код, который сразу ведёт в нужную комнату.

## 3. Key UX Flows

### Trainer UX

Тренер:

- создаёт комнату;
- указывает количество мест/участников;
- видит список access slots;
- может подписать каждый слот внутренним именем, например `Иван Петров` или `Алексей утренняя группа`;
- копирует access-code конкретного слота;
- отправляет этот код дилеру личным сообщением;
- видит статус доступа: не активирован, активирован, онлайн, оффлайн, отозван;
- видит оба имени:
  - внутреннее имя тренера;
  - публичное имя дилера;
- может revoke доступ;
- может reset/regenerate доступ, если код отправили не тому человеку или дилер потерял доступ.

### Dealer UX

Дилер:

- открывает онлайн-режим в игре;
- видит поле `Введите код доступа`;
- может вставить access-code из буфера обмена;
- вводит или меняет public display name;
- активирует доступ;
- после активации видит комнату в списке своих комнат;
- больше не вводит access-code каждый раз;
- заходит в комнату, если она online/active;
- видит понятный статус, если комната offline, завершена, закрыта или доступ отозван.

## 4. Data Model Draft

Это черновая модель данных. Она фиксирует направление, но не является готовой миграцией.

### `room_accesses`

Одна запись = один персональный доступ/слот в конкретной комнате.

Примерные поля:

- `id`;
- `room_id`;
- `slot_number`;
- `access_code_hash`;
- `access_code_suffix`;
- `trainer_internal_name`;
- `dealer_id nullable`;
- `status`;
- `activated_at`;
- `revoked_at`;
- `last_used_at`;
- `created_at`;
- `updated_at`.

Рекомендуемые статусы:

- `created` — доступ создан, но ещё не активирован;
- `activated` — дилер активировал доступ;
- `revoked` — тренер отозвал доступ;
- `closed` — доступ закрыт из-за закрытия комнаты.

Важные правила:

- полный access-code не хранить в открытом виде;
- хранить хэш access-code;
- `access_code_suffix` нужен только для безопасного отображения тренеру последних символов;
- полный access-code показывать только при создании или reset/regenerate;
- `(room_id, slot_number)` должен быть уникальным;
- `access_code_hash` должен быть уникальным.

### `participant_tokens`

Одна запись = один сохранённый локальный доступ дилера к комнате после активации.

Примерные поля:

- `id`;
- `room_access_id`;
- `dealer_id`;
- `token_hash`;
- `status`;
- `created_at`;
- `last_used_at`;
- `revoked_at`.

Рекомендуемые статусы:

- `active`;
- `revoked`;
- `expired`.

Важные правила:

- сам participant token не хранить в базе в открытом виде;
- хранить только `token_hash`;
- при revoke access все связанные participant tokens должны перестать работать;
- participant token нужен для восстановления списка комнат в игре без повторного ввода access-code.

### `dealers`

`Dealer` остаётся room-scoped participant.

На первом этапе:

- `Dealer` не становится аккаунтом;
- `Dealer` не получает email/password;
- `Dealer.room_id` остаётся полезным для совместимости с текущими live/session endpoints;
- `Dealer.display_name` = public display name дилера;
- `Dealer.is_active` можно использовать для совместимости с текущими проверками;
- один реальный человек в разных комнатах может иметь разные `Dealer` записи.

## 5. API Draft

Это черновой список endpoints. Названия можно уточнить перед реализацией.

### Trainer

Предполагаемые endpoints:

- `GET /api/rooms/{room_code}/accesses`
  - список access slots комнаты;
  - возвращает slot, internal name, public display name, status, activation info.
- `POST /api/rooms/{room_code}/accesses`
  - создать один или несколько access slots;
  - возвращает новые access-code только в этом ответе.
- `PATCH /api/rooms/{room_code}/accesses/{access_id}`
  - изменить `trainer_internal_name`.
- `POST /api/rooms/{room_code}/accesses/{access_id}/revoke`
  - отозвать доступ;
  - связанные participant tokens больше не работают.
- `POST /api/rooms/{room_code}/accesses/{access_id}/reset`
  - отозвать старый код/token;
  - создать новый access-code для этого слота.
- `GET /api/rooms/{room_code}/participants`
  - список участников и статусов;
  - можно объединить с `GET /accesses`, если ответ получится удобным.

### Dealer / Game

Предполагаемые endpoints:

- `POST /api/dealer/accesses/activate`
  - без dealer login;
  - body: `access_code`, `display_name`;
  - создаёт или привязывает `Dealer`;
  - возвращает participant token и данные комнаты.
- `POST /api/dealer/my-rooms`
  - body: список сохранённых participant tokens;
  - возвращает список комнат и статусы: online, offline, completed, closed, revoked.
- `POST /api/dealer/tokens/exchange`
  - participant token -> короткоживущий access JWT для текущих live/session/WebSocket endpoints.
- `PATCH /api/dealer/rooms/{room_access_id}/display-name`
  - изменить публичное имя дилера в конкретной комнате.
- `GET /api/dealer/rooms/{room_access_id}/active-live-session`
  - получить active live session при активном доступе.

Важно: новый dealer flow не должен использовать `/api/auth/dealer/join` как dealer login. Это не логин аккаунта, а активация доступа к комнате.

## 6. Implementation Roadmap

### Iteration 0 — Baseline / Safety

Цель:

- зафиксировать текущее поведение старого PIN-flow;
- понять, какие endpoints и клиенты завязаны на `room_code + PIN`;
- подготовить проверочные curl-сценарии.

Что можно менять:

- только документацию или отдельный checklist;
- при необходимости можно добавить план тестирования без запуска опасных тестов.

Что нельзя менять:

- backend-логику;
- модели;
- миграции;
- dashboard;
- Godot client;
- production PIN-flow.

Ожидаемый результат:

- есть понятный baseline текущего поведения;
- известно, что нельзя ломать на следующих этапах.

Как проверить:

- ручной просмотр текущих endpoints;
- подготовленные curl-команды для старого flow:
  - trainer register/login;
  - create room;
  - dealer join by `room_code + PIN`;
  - repeat join with same display name;
  - name mismatch.

Отчёт после итерации:

- какие файлы изменены;
- какие текущие endpoints подтверждены;
- какие проверки подготовлены;
- какие риски найдены;
- что делать следующим шагом.

### Iteration 1 — Database Models / Migration Only

Цель:

- добавить основу данных для нового access-code flow.

Что можно менять:

- SQLAlchemy models;
- Alembic migration;
- imports моделей для Alembic metadata.

Что нельзя менять:

- старый PIN-flow;
- существующие `/api/rooms/dealer/join`;
- dashboard;
- Godot client;
- live/session/WebSocket логику.

Ожидаемый результат:

- появились таблицы `room_accesses` и `participant_tokens`;
- старые таблицы и старый flow не изменены;
- новые таблицы пока не используются production-кодом.

Как проверить:

- проверить миграцию на отдельной dev/test базе;
- проверить, что старые таблицы не удаляются и не меняют смысл;
- проверить constraints и индексы:
  - unique `access_code_hash`;
  - unique `(room_id, slot_number)`;
  - unique `token_hash`;
  - indexes по `room_id`, `dealer_id`, `room_access_id`, `status`.

Отчёт после итерации:

- какие файлы изменены;
- какие таблицы добавлены;
- какие constraints добавлены;
- что не трогалось;
- как откатить миграцию;
- риски;
- следующий шаг.

### Iteration 2 — Trainer Access Management API

Цель:

- дать тренеру API для управления access slots без dealer activation.

Что можно менять:

- backend endpoints для trainer access management;
- Pydantic schemas для новых ответов/запросов;
- helper генерации access-code;
- unit/integration tests только для новых trainer endpoints.

Что нельзя менять:

- старый PIN-flow;
- dealer activation;
- dashboard;
- Godot client;
- live/session/WebSocket.

Ожидаемый результат:

- тренер может получить список access slots;
- тренер может создать/generate access slots;
- тренер может изменить `trainer_internal_name`;
- полный access-code возвращается только при создании/reset.

Как проверить:

- trainer login;
- create room;
- create/list accesses;
- update internal name;
- убедиться, что старый `/api/rooms/{room_code}/pins` всё ещё работает.

Отчёт после итерации:

- какие endpoints добавлены;
- какие файлы изменены;
- примеры curl;
- что не трогалось;
- риски;
- следующий шаг.

### Iteration 3 — Dealer Access Activation API

Цель:

- реализовать первую активацию access-code дилером.

Что можно менять:

- новый dealer activation endpoint;
- создание/привязку `Dealer`;
- создание participant token;
- tests для activation flow.

Что нельзя менять:

- dealer email/password;
- `/api/auth/dealer/join` как полноценный login;
- старый PIN-flow;
- dashboard UI;
- Godot UI;
- live/session/WebSocket.

Ожидаемый результат:

- дилер отправляет `access_code + display_name`;
- сервер создаёт `Dealer` в нужной комнате;
- `room_access.dealer_id` заполняется;
- `room_access.status` становится `activated`;
- сервер возвращает participant token;
- повторная активация уже занятого access-code запрещена.

Как проверить:

- активировать новый access-code;
- проверить, что создан `Dealer`;
- повторить activation тем же кодом и получить ожидаемый отказ;
- активировать несуществующий/отозванный код и получить ошибку;
- проверить, что старый PIN-flow всё ещё работает.

Отчёт после итерации:

- какие endpoints добавлены;
- какие статусы ошибок используются;
- какие файлы изменены;
- как проверить curl;
- что не трогалось;
- риски;
- следующий шаг.

### Iteration 4 — Dealer My Rooms API

Цель:

- дать игре список комнат по сохранённым participant tokens.

Что можно менять:

- endpoint `my rooms`;
- token lookup по `participant_tokens.token_hash`;
- вычисление статусов комнат.

Что нельзя менять:

- dashboard;
- Godot client;
- live/session/WebSocket;
- старый PIN-flow.

Ожидаемый результат:

- игра может отправить список локальных participant tokens;
- сервер возвращает комнаты дилера;
- для каждой комнаты есть статус:
  - `online`;
  - `offline`;
  - `completed`;
  - `closed`;
  - `revoked`.

Как проверить:

- активировать access-code;
- вызвать `my rooms`;
- создать live session и увидеть `online/active`;
- закрыть комнату и увидеть `closed`;
- проверить revoked token после Iteration 5.

Отчёт после итерации:

- какие endpoints добавлены;
- какие статусы возвращаются;
- какие файлы изменены;
- что не трогалось;
- риски;
- следующий шаг.

### Iteration 5 — Revoke / Reset

Цель:

- дать тренеру управление доступом после создания.

Что можно менять:

- trainer endpoints для revoke/reset;
- смену статусов `room_accesses`;
- отключение связанных participant tokens;
- tests для revoke/reset.

Что нельзя менять:

- старый PIN-flow;
- live/session/WebSocket интеграцию, если она ещё не начата;
- dashboard UI;
- Godot UI.

Ожидаемый результат:

- trainer revoke делает доступ недействительным;
- revoked participant token больше не работает в `my rooms`;
- reset создаёт новый access-code для слота;
- старый access-code и старые participant tokens не работают.

Как проверить:

- активировать access-code;
- вызвать `my rooms`;
- revoke;
- снова вызвать `my rooms` и увидеть revoked/closed access;
- reset;
- активировать новый code;
- проверить, что старый code не активируется.

Отчёт после итерации:

- какие endpoints добавлены;
- какие статусы используются;
- какие файлы изменены;
- как проверить;
- что не трогалось;
- риски;
- следующий шаг.

### Iteration 6 — Live Session Access Integration

Цель:

- подключить новый access-code flow к live/session/WebSocket.

Что можно менять:

- зависимости авторизации для participant token или exchanged JWT;
- проверки доступа в live/session endpoints;
- WebSocket access check;
- tests для live access.

Что нельзя менять:

- legacy PIN-flow поведение;
- dashboard UI;
- Godot UI, если это не оговорено отдельно;
- формат старых ответов без необходимости.

Ожидаемый результат:

- новый participant может входить в live session;
- revoked participant не может войти;
- closed room не пускает;
- старые dealer JWT из PIN-flow продолжают работать на переходный период;
- WebSocket проверяет не только `dealer.room_id`, но и активность доступа.

Как проверить:

- legacy PIN dealer всё ещё входит в live session;
- новый access-code dealer входит в live session;
- revoked dealer получает отказ;
- WebSocket с revoked token закрывается;
- round-results не принимаются от revoked access.

Отчёт после итерации:

- какие проверки доступа добавлены;
- какие endpoints затронуты;
- какие файлы изменены;
- как проверить;
- что не трогалось;
- риски;
- следующий шаг.

### Iteration 7 — Dashboard UI

Цель:

- показать тренеру новую таблицу access slots.

Что можно менять:

- dashboard HTML/CSS/JS;
- только UI нового access management;
- вызовы новых trainer endpoints.

Что нельзя менять:

- backend-логику;
- миграции;
- Godot client;
- legacy PIN-flow, если он ещё нужен.

Ожидаемый результат:

- тренер видит новую таблицу access slots;
- может копировать access-code после create/reset;
- может менять internal name;
- видит public display name;
- видит статус;
- может revoke/reset.

Как проверить:

- открыть dashboard;
- создать комнату;
- создать/list access slots;
- изменить internal name;
- активировать доступ через curl;
- увидеть public display name;
- revoke/reset из dashboard.

Отчёт после итерации:

- какие UI-файлы изменены;
- что добавлено;
- что не трогалось;
- скриншоты/ручные проверки;
- риски;
- следующий шаг.

### Iteration 8 — Godot Client UX

Цель:

- добавить дилеру новый UX без аккаунта и без повторного ввода кода.

Что можно менять:

- Godot online screen;
- API client methods;
- local storage participant tokens;
- room list UI;
- clipboard paste для access-code.

Что нельзя менять:

- backend-логику;
- миграции;
- dashboard;
- старый PIN-flow, если он ещё нужен как reserve.

Ожидаемый результат:

- дилер открывает онлайн-режим;
- вводит access-code;
- вводит public display name;
- игра сохраняет participant token;
- дилер видит список своих комнат;
- дилер входит в online room;
- revoked/closed status отображается понятно.

Как проверить:

- активировать code в игре;
- перезапустить игру;
- убедиться, что комната осталась в списке;
- проверить offline/online;
- проверить revoked;
- проверить смену public display name.

Отчёт после итерации:

- какие Godot-файлы изменены;
- что добавлено;
- что не трогалось;
- как проверить вручную;
- риски;
- следующий шаг.

### Iteration 9 — Legacy PIN Cleanup

Цель:

- после стабилизации новой системы убрать старый PIN-flow из основного потока.

Что можно менять:

- dashboard UI;
- Godot UI;
- backend legacy endpoints только после отдельного подтверждения;
- docs.

Что нельзя менять:

- рабочую новую access-code систему;
- production-сценарии без отдельного плана миграции.

Ожидаемый результат:

- PIN-flow скрыт из основного UI;
- legacy endpoints либо оставлены временно, либо удалены отдельной миграцией;
- документация обновлена.

Как проверить:

- новый access-code flow полностью работает;
- старые PIN элементы не показываются в основном UI;
- если endpoints удаляются, проверить, что клиенты больше их не вызывают.

Отчёт после итерации:

- что именно удалено или скрыто;
- какие файлы изменены;
- как проверить;
- какие legacy данные остаются в базе;
- риски;
- следующий шаг.

## 7. Rules for Every Iteration

Правила работы:

- одна итерация = маленький scope;
- не делать следующий этап без подтверждения;
- после каждой итерации давать отчёт;
- не смешивать backend, dashboard и Godot в одной итерации, если это явно не согласовано;
- не ломать production PIN-flow;
- перед опасными изменениями явно предупреждать;
- не делать dealer accounts случайно через новые endpoints;
- не хранить access-code и participant token в открытом виде в базе;
- не менять старые API-ответы без причины;
- если причина проблемы не ясна, фиксировать это честно в отчёте.

Отчёт после каждой итерации должен содержать:

- какие файлы изменены;
- что добавлено;
- что не трогалось;
- как проверить;
- какие проверки уже выполнены;
- риски;
- что делать следующим шагом.

## 8. Testing Strategy

Тестирование должно идти постепенно.

Обязательные проверки старого flow:

- trainer register/login работает;
- trainer create room работает;
- `POST /api/rooms/dealer/join` по `room_code + PIN` работает;
- повторный PIN-вход с тем же именем работает;
- другое имя для того же PIN даёт `NAME_MISMATCH`;
- dashboard PIN table не ломается до cleanup-этапа.

Обязательные проверки нового access-code flow:

- trainer создаёт room accesses;
- trainer видит список accesses;
- trainer меняет internal name;
- dealer активирует access-code;
- повторная активация занятого code запрещена;
- participant token возвращается только после успешной активации;
- dealer видит комнату через `my rooms`;
- room offline/online определяется корректно;
- public display name можно изменить;
- trainer видит internal name + public display name;
- revoke отключает participant token;
- reset выдаёт новый code и инвалидирует старый;
- закрытая комната не пускает дилера;
- WebSocket/live access check подключается позже и отдельно проверяется.

Рекомендуемые типы проверок:

- curl-сценарии для API;
- backend tests для моделей и endpoints;
- ручная проверка dashboard;
- ручная проверка Godot-клиента;
- отдельная проверка WebSocket после Iteration 6.

## 9. Open Questions

Вопросы, которые можно решить позже:

- нужен ли device binding;
- если device binding нужен, делать ли его обязательным или мягким;
- как восстанавливать доступ после переустановки игры;
- сколько живёт access-code до активации;
- показывать ли закрытые комнаты в списке дилера;
- показывать ли revoked комнаты в списке дилера или скрывать их после сообщения;
- как именно хранить participant token в Godot;
- нужен ли refresh-механизм для participant token или достаточно reset через тренера;
- должен ли trainer видеть историю reset/revoke;
- когда скрывать legacy PIN-flow из UI;
- когда физически удалять legacy `RoomPin` систему.

