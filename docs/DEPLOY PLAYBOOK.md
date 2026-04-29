# DEPLOY PLAYBOOK — Baccarat Trainer

## 1. Цель

Безопасно деплоить backend и trainer dashboard Baccarat Trainer на production-сервер, не путая dev/prod окружения, не ломая базу данных и не выкатывая случайные локальные изменения.

Главная задача playbook:

- понимать, какой commit деплоится;
- понимать, какой compose реально управляет backend;
- понимать, какой nginx реально обслуживает сайт;
- не затирать production-local настройки;
- безопасно применять миграции;
- не перезапускать API, пока код, image, миграции и startup-check не готовы;
- быстро понимать, где ошибка: git, Docker, Alembic, backend import/runtime, nginx/dashboard или Godot.

---

## 2. Главные правила

### 2.1. Не деплоить из грязной рабочей ветки

Нельзя делать production deploy из ветки, где перемешаны:

- backend;
- dashboard;
- Godot;
- `.godot`;
- `.DS_Store`;
- `.import`;
- временные файлы;
- незакоммиченные правки.

Для server deploy нужна отдельная понятная ветка/commit, куда входят только нужные файлы:

```text
baccarat-server/...
web/trainer-dashboard/...
```

Godot-клиент не деплоится на backend-сервер.

---

### 2.2. Не делать `git add .`

Для deploy commit нельзя использовать:

```bash
git add .
git add -A
```

Только точечный staging нужных файлов:

```bash
git add baccarat-server/app/...
git add baccarat-server/alembic/...
git add web/trainer-dashboard/app.js
git add web/trainer-dashboard/index.html
git add web/trainer-dashboard/styles.css
```

Если меняется только dashboard static, не надо добавлять backend.  
Если меняется только backend, не надо добавлять Godot/dashboard.

---

### 2.3. Production server-local файлы нельзя затирать вслепую

На production-сервере есть важные локальные отличия:

```text
baccarat-server/alembic.ini
baccarat-server/deploy/docker-compose.prod.yml
```

Пример production-local отличий:

```text
alembic.ini:
localhost → db

docker-compose.prod.yml:
ports:
  - "8000:8000"
```

Это не мусор. Это production-настройки.

Нельзя делать:

```bash
git reset --hard
git checkout -- .
git clean -fd
```

пока не понятно, что именно будет затёрто.

---

### 2.4. Нельзя делать опасные действия с production БД

Без отдельного явного решения нельзя:

```bash
alembic downgrade ...
drop table ...
truncate ...
reset database ...
docker volume rm ...
docker compose down -v
```

Также нельзя “чинить миграции” через ручное изменение `alembic_version`, если не понятно, почему именно это безопасно.

---

## 3. Где production

Production checkout:

```bash
/root/baccarat_new
```

Backend:

```bash
/root/baccarat_new/baccarat-server
```

Deploy-директория backend:

```bash
/root/baccarat_new/baccarat-server/deploy
```

Production compose backend:

```bash
/root/baccarat_new/baccarat-server/deploy/docker-compose.prod.yml
```

Trainer dashboard source в repo:

```bash
/root/baccarat_new/web/trainer-dashboard
```

Trainer dashboard static на сервере:

```bash
/var/www/dashboard
```

---

## 4. Какой nginx реально работает

Важно: production traffic сейчас обслуживает **host nginx**, а не compose nginx.

Фактическая схема:

```text
80/443 → host nginx
/api/  → proxy на 127.0.0.1:8000
/ws/   → proxy на 127.0.0.1:8000
/      → static dashboard из /var/www/dashboard
```

Проверить:

```bash
ss -ltnp | grep -E ':80|:443|:8000'
nginx -v
```

Ожидаемо:

```text
:80 / :443 → nginx host process
:8000      → docker-proxy / deploy-api-1
```

Compose nginx может быть в файле, но это не значит, что он реально обслуживает production.

Не поднимать compose nginx на 80/443 без отдельного плана: можно конфликтовать с host nginx и certbot.

---

## 5. Где НЕ деплоить

Не использовать для production deploy:

```bash
/root/baccarat_new/baccarat-server/docker-compose.yml
```

Это dev/local compose.

Не запускать production-команды из случайной директории без `-f docker-compose.prod.yml`.

Правильно:

```bash
cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml ...
```

---

## 6. Проверить текущий production backend

```bash
cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml ps
docker ps
```

Ожидаемые backend-контейнеры:

```text
deploy-api-1
deploy-db-1
deploy-redis-1
```

Проверить, какой compose реально создал API-контейнер:

```bash
docker inspect deploy-api-1 --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}'
```

Ожидаемо:

```text
/root/baccarat_new/baccarat-server/deploy
```

Проверить volume mounts:

```bash
docker inspect deploy-api-1 --format '{{json .Mounts}}'
```

Если ответ:

```json
[]
```

значит код не примонтирован, а baked внутри Docker image.

---

## 7. Health check

Backend напрямую:

```bash
curl -sS http://127.0.0.1:8000/api/health
```

Через host nginx HTTPS:

```bash
curl -k -i https://127.0.0.1/api/health
```

Ожидаемый ответ:

```json
{"status":"ok","version":"0.1.0"}
```

Если health не отвечает:

```bash
cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs --tail=100 api
```

---

## 8. Перед deploy: проверить git на сервере

```bash
cd /root/baccarat_new
git status --short
git branch --show-current
git rev-parse HEAD
git log --oneline -5
git remote -v
```

Если есть dirty files — остановиться и разобраться.

Пример ожидаемых server-local файлов:

```text
 M baccarat-server/alembic.ini
 M baccarat-server/deploy/docker-compose.prod.yml
```

Если для этих файлов включён `skip-worktree`, `git status` может быть чистым, хотя файлы локально отличаются. Это нормально, если так сделано осознанно.

---

## 9. Production server-local config и `skip-worktree`

На production-сервере два файла intentionally отличаются от репозитория:

```text
baccarat-server/alembic.ini
baccarat-server/deploy/docker-compose.prod.yml
```

Причина:

- в `alembic.ini` для Docker production нужен host `db`, а не `localhost`;
- в `docker-compose.prod.yml` на production добавлен port mapping `8000:8000`.

Чтобы эти production-local изменения не висели постоянно в `git status`, на сервере применён:

```bash
git update-index --skip-worktree baccarat-server/alembic.ini
git update-index --skip-worktree baccarat-server/deploy/docker-compose.prod.yml
```

Проверить, что файлы помечены как skip-worktree:

```bash
git ls-files -v baccarat-server/alembic.ini baccarat-server/deploy/docker-compose.prod.yml
```

Если строка начинается с `S`, значит skip-worktree включён.

Снять skip-worktree:

```bash
git update-index --no-skip-worktree baccarat-server/alembic.ini
git update-index --no-skip-worktree baccarat-server/deploy/docker-compose.prod.yml
```

После снятия проверить diff:

```bash
git status --short
git --no-pager diff -- baccarat-server/alembic.ini baccarat-server/deploy/docker-compose.prod.yml
```

Вернуть skip-worktree после ручной проверки:

```bash
git update-index --skip-worktree baccarat-server/alembic.ini
git update-index --skip-worktree baccarat-server/deploy/docker-compose.prod.yml
```

Правило:

```text
skip-worktree — это не фикс кода.
Это локальная защита production-настроек от случайного затирания.
```

Если upstream когда-нибудь изменит эти файлы, перед обновлением нужно временно снять skip-worktree и сравнить изменения вручную.

---

## 10. Backup и мусор на сервере

Backup перед изменением production-local файлов:

```bash
cp baccarat-server/alembic.ini baccarat-server/alembic.ini.pre-deploy-$(date +%Y%m%d-%H%M%S).bak
cp baccarat-server/deploy/docker-compose.prod.yml baccarat-server/deploy/docker-compose.prod.yml.pre-deploy-$(date +%Y%m%d-%H%M%S).bak
```

Но не нужно бесконечно хранить много backup-файлов в repo checkout.

Найти мусор:

```bash
cd /root/baccarat_new
find . -maxdepth 4 \( -name "*.bak" -o -name "._*" -o -name ".DS_Store" \)
```

Обычно можно удалить:

```text
*.pre-deploy-*.bak
*.server-local.*.bak
._*
.DS_Store
```

Но только если понятно, что это не единственная важная копия production-local настроек.

macOS AppleDouble мусор:

```bash
file ._baccarat-server
```

Если это:

```text
AppleDouble encoded Macintosh file
```

можно удалить:

```bash
rm ._baccarat-server
```

---

## 11. Подготовка deploy-ветки

Если локальная рабочая ветка грязная или содержит Godot/client изменения, делать отдельную deploy-ветку.

Пример:

```text
codex/deploy-room-access-backend-dashboard
```

В неё включать только server/dashboard файлы.

### 11.1. Что можно включать

Backend:

```text
baccarat-server/app/...
baccarat-server/alembic/...
baccarat-server/requirements...
baccarat-server/Dockerfile
baccarat-server/deploy/... если это реально нужно и согласовано
```

Dashboard:

```text
web/trainer-dashboard/app.js
web/trainer-dashboard/index.html
web/trainer-dashboard/styles.css
web/trainer-dashboard/assets/... если это реальные нужные static assets
```

Docs:

```text
docs/... только если документ действительно нужен в repo
```

### 11.2. Что не включать

```text
Godot:
project.godot
export_presets.cfg
scenes/...
scripts/...
*.uid

Editor/runtime:
.godot/...
.DS_Store
.kilo/
.playwright-mcp/

Godot/dashboard import metadata:
*.import
```

Исключение: если конкретный Godot commit нужен отдельно, делать его отдельным Godot/client commit, не смешивать с server deploy.

---

## 12. Перед deploy commit: проверить полноту backend

Перед push deploy-ветки обязательно проверить, что backend не собран “кусочно”.

Проверить:

```bash
find baccarat-server/app -type f | sort
find baccarat-server/alembic/versions -type f | sort
```

Проверить, что в deploy-ветку вошли все файлы, на которые ссылается backend:

- API modules;
- schemas;
- models;
- websocket managers;
- utils;
- migrations.

Типичные ошибки из опыта:

```text
ImportError: cannot import name 'DealerInviteJoinRequest'
ModuleNotFoundError: No module named 'app.schemas.session'
ModuleNotFoundError: No module named 'app.websocket.manager'
TypeError: 'invite_token' is an invalid keyword argument for RoomPin
```

Что это значит:

```text
deploy-ветка неполная или model/schema не соответствуют миграциям/API-коду
```

---

## 13. Перед deploy: проверить миграции

### 13.1. Миграции должны быть полной цепочкой

Нельзя включать только новые миграции `004/005/006`, если production БД уже стоит на `002`, а файлов `002/003` в ветке нет.

Проверить список:

```bash
ls -la baccarat-server/alembic/versions
```

Пример полной цепочки:

```text
001_initial.py
002_live_sessions_and_round_details.py
003_add_invite_device_fields.py
004_room_accesses_and_participant_tokens.py
005_add_session_participant_status.py
006_add_round_results_submitted_at_default.py
```

---

### 13.2. Alembic смотрит не только на имя файла

Alembic смотрит на внутренние поля:

```python
revision = "..."
down_revision = "..."
```

Файл может называться правильно, но Alembic всё равно не увидит нужную migration, если `revision` внутри не совпадает с тем, что записано в production БД.

Пример проблемы:

```text
В БД:
002_live_sessions_and_round_details

В файле:
revision = "002_live_sessions"
```

Проверять:

```bash
grep -R "revision =" baccarat-server/alembic/versions
grep -R "down_revision =" baccarat-server/alembic/versions
```

---

### 13.3. Миграции должны быть безопасны для production

Production БД может отличаться от ожиданий. Например колонка уже есть.

Если миграция добавляет колонку:

```python
op.add_column("session_participants", sa.Column("status", ...))
```

а в production колонка уже существует, миграция упадёт:

```text
DuplicateColumnError: column "status" already exists
```

Для таких случаев миграция должна быть безопасной:

```text
если колонка есть — не добавлять повторно
если колонки нет — добавить
```

Downgrade тоже желательно делать безопасным:

```text
если колонка есть — удалить
если колонки нет — не падать
```

---

## 14. Важное правило Docker: код внутри контейнера может быть старым

На production compose код не примонтирован volume.

Проверка:

```bash
docker inspect deploy-api-1 --format '{{json .Mounts}}'
```

Если ответ:

```json
[]
```

значит код baked внутри Docker image.

Следствие:

```text
git pull на сервере НЕ обновляет код внутри уже запущенного контейнера
```

Нужно собрать новый image.

---

## 15. Как правильно запускать Alembic при baked image

Нельзя запускать миграции внутри старого running контейнера, если он собран из старого image.

Неправильно:

```bash
docker compose -f docker-compose.prod.yml exec api alembic upgrade head
```

если `api` ещё старый.

Правильнее:

1. подтянуть код;
2. собрать новый image;
3. запустить Alembic в одноразовом контейнере из нового image;
4. только после успешных миграций заменить running API.

---

## 16. Backend deploy с миграциями

### 16.1. Подтянуть код

```bash
cd /root/baccarat_new
git status --short
git branch --show-current
git rev-parse HEAD
git pull --ff-only
git rev-parse HEAD
```

Если `git pull --ff-only` блокируется — остановиться.

---

### 16.2. Собрать новый API image

```bash
cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml build api
```

Если Docker Hub rate limit:

```text
429 Too Many Requests
```

варианты:

```bash
docker login
```

или подождать.

Не менять Dockerfile хаотично.

---

### 16.3. Проверить Alembic в одноразовом контейнере нового image

Важно использовать `PYTHONPATH=/code`.

```bash
cd /root/baccarat_new/baccarat-server/deploy

docker compose -f docker-compose.prod.yml run --rm api sh -lc \
'cd /code && PYTHONPATH=/code alembic current && PYTHONPATH=/code alembic heads'
```

Если ошибка:

```text
ModuleNotFoundError: No module named 'app'
```

значит не выставлен `PYTHONPATH=/code`.

Если ошибка:

```text
Can't locate revision identified by ...
```

значит сломана цепочка миграций: нет файла, не совпадает `revision`, или неправильный `down_revision`.

---

### 16.4. Выполнить миграции

Только если `current` и `heads` работают:

```bash
docker compose -f docker-compose.prod.yml run --rm api sh -lc \
'cd /code && PYTHONPATH=/code alembic upgrade head'
```

После этого:

```bash
docker compose -f docker-compose.prod.yml run --rm api sh -lc \
'cd /code && PYTHONPATH=/code alembic current'
```

---

### 16.5. Поднять новый API

Только после успешных миграций:

```bash
docker compose -f docker-compose.prod.yml up -d api
```

Если нужно пересобрать при up:

```bash
docker compose -f docker-compose.prod.yml up -d --build api
```

Но если image уже собран, обычно достаточно:

```bash
docker compose -f docker-compose.prod.yml up -d api
```

---

## 17. Backend deploy без миграций

Если менялся только Python-код без изменения БД:

```bash
cd /root/baccarat_new
git pull --ff-only

cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml build api
docker compose -f docker-compose.prod.yml up -d api

docker compose -f docker-compose.prod.yml ps
curl -sS http://127.0.0.1:8000/api/health
docker compose -f docker-compose.prod.yml logs --tail=100 api
```

Миграции повторно запускать не нужно, если БД уже на head и новая правка только import/runtime/frontend/backend logic без schema changes.

---

## 18. Dashboard static deploy

Если менялись только:

```text
web/trainer-dashboard/app.js
web/trainer-dashboard/index.html
web/trainer-dashboard/styles.css
```

то API rebuild не нужен.

Порядок:

```bash
cd /root/baccarat_new

git status --short
git branch --show-current
git rev-parse HEAD

git pull --ff-only

git rev-parse HEAD

ts=$(date +%Y%m%d-%H%M%S)

cp /var/www/dashboard/index.html /var/www/dashboard/index.html.$ts.bak
cp /var/www/dashboard/app.js /var/www/dashboard/app.js.$ts.bak
cp /var/www/dashboard/styles.css /var/www/dashboard/styles.css.$ts.bak

cp /root/baccarat_new/web/trainer-dashboard/index.html /var/www/dashboard/index.html
cp /root/baccarat_new/web/trainer-dashboard/app.js /var/www/dashboard/app.js
cp /root/baccarat_new/web/trainer-dashboard/styles.css /var/www/dashboard/styles.css

chmod 644 /var/www/dashboard/index.html /var/www/dashboard/app.js /var/www/dashboard/styles.css

nginx -t
systemctl reload nginx

curl -k -i https://127.0.0.1/ | head -40
curl -k -i https://127.0.0.1/api/health
```

Если менялся только `app.js`, можно копировать только его:

```bash
cd /root/baccarat_new

git pull --ff-only

ts=$(date +%Y%m%d-%H%M%S)
cp /var/www/dashboard/app.js /var/www/dashboard/app.js.$ts.bak
cp /root/baccarat_new/web/trainer-dashboard/app.js /var/www/dashboard/app.js
chmod 644 /var/www/dashboard/app.js

nginx -t
systemctl reload nginx
```

Проверить наличие нужного текста:

```bash
grep -n "Live View стола\|Лог событий дилера\|Персональные access-коды" /var/www/dashboard/index.html
```

После dashboard static deploy в браузере делать hard refresh:

```text
Cmd + Shift + R
```

---

## 19. Проверки после запуска API

### 19.1. Статус контейнеров

```bash
cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml ps
```

Если `api` в restart loop — сразу смотреть logs.

---

### 19.2. Health

```bash
curl -sS http://127.0.0.1:8000/api/health
curl -k -i https://127.0.0.1/api/health
```

Ожидаемо:

```json
{"status":"ok","version":"0.1.0"}
```

---

### 19.3. Логи API

```bash
docker compose -f docker-compose.prod.yml logs --tail=100 api
```

Нормальные строки:

```text
Application startup complete
Uvicorn running on http://0.0.0.0:8000
GET /api/health 200 OK
```

Плохие признаки:

```text
Traceback
ImportError
ModuleNotFoundError
sqlalchemy.exc
asyncpg.exceptions
```

---

## 20. Если API не стартует после deploy

Не откатывать вслепую. Сначала понять точную ошибку.

### 20.1. ImportError / ModuleNotFoundError

Примеры:

```text
ImportError: cannot import name 'DealerInviteJoinRequest'
ModuleNotFoundError: No module named 'app.schemas.session'
ModuleNotFoundError: No module named 'app.websocket.manager'
```

Что это значит:

```text
deploy-ветка неполная
```

Что делать:

1. найти, кто импортирует;
2. проверить, есть ли файл в основной рабочей копии;
3. добавить недостающий файл/класс в deploy-ветку;
4. сделать маленький fix commit;
5. pull на сервере;
6. build api;
7. up -d api;
8. снова logs/health.

Не запускать миграции повторно, если БД уже на head и новая правка только import/runtime.

---

### 20.2. SQLAlchemy model/schema mismatch

Пример:

```text
TypeError: 'invite_token' is an invalid keyword argument for RoomPin
```

Это значит:

```text
API-код уже использует поле,
миграция уже могла добавить колонку,
но SQLAlchemy model в deploy-ветке отстаёт.
```

Что делать:

1. проверить migration;
2. проверить model;
3. синхронизировать model с migration;
4. не удалять поле из API-кода наугад;
5. сделать маленький fix commit;
6. rebuild API.

---

### 20.3. Ошибки подключения к БД

Если:

```text
password authentication failed
Connect call failed ('127.0.0.1', 5432)
```

проверить:

```bash
grep -R "localhost\|DATABASE_URL\|sqlalchemy.url" \
/root/baccarat_new/baccarat-server/alembic.ini \
/root/baccarat_new/baccarat-server/alembic/env.py \
/root/baccarat_new/baccarat-server/app/config.py
```

В Docker production обычно нужно:

```text
db:5432
```

а не:

```text
localhost:5432
```

---

## 21. Dashboard / nginx troubleshooting

Backend API и dashboard — разные части.

API может быть успешно поднят, а dashboard при этом отдавать:

```text
404
```

Это отдельная проблема nginx/static.

Проверить dashboard:

```bash
curl -k -i https://127.0.0.1/ | head -40
ls -la /var/www/dashboard
```

Проверить host nginx site:

```bash
nginx -t
systemctl status nginx --no-pager
```

Если dashboard не обновился, проверить, что новые файлы реально скопированы в:

```bash
/var/www/dashboard
```

а не только лежат в:

```bash
/root/baccarat_new/web/trainer-dashboard
```

---

## 22. Smoke-check новых endpoints

Если backend поднялся, можно безопасно проверить routes без создания production-данных.

Для новых dealer endpoints пустые body могут вернуть `422`. Это нормально и означает, что route существует и валидирует request.

Примеры:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
-X POST http://127.0.0.1:8000/api/dealer/accesses/activate \
-H "Content-Type: application/json" \
-d '{}'

curl -sS -o /dev/null -w "%{http_code}\n" \
-X POST http://127.0.0.1:8000/api/dealer/my-rooms \
-H "Content-Type: application/json" \
-d '{}'

curl -sS -o /dev/null -w "%{http_code}\n" \
-X POST http://127.0.0.1:8000/api/dealer/tokens/exchange \
-H "Content-Type: application/json" \
-d '{}'
```

Ожидаемо:

```text
422
```

Это значит:

```text
route существует
сервер новый
валидация работает
```

---

## 23. Полный smoke-test room access flow

Когда API и dashboard доступны:

1. Зайти trainer в dashboard.
2. Создать room.
3. В dashboard создать personal access-code.
4. Проверить list accesses.
5. Скопировать access-code.
6. В Godot:
   - Онлайн-тренировка;
   - Мои тренировки;
   - Добавить тренировку;
   - ввести access-code + имя;
   - participant_token должен сохраниться.
7. Вернуться в “Мои тренировки”.
8. Проверить `/api/dealer/my-rooms`.
9. Когда room online — нажать “Войти”.
10. Проверить exchange participant token → dealer JWT.
11. Проверить переход в DealerWaitingScreen.
12. Проверить старый live/session stack.

---

## 24. Live View smoke-test после dashboard fixes

После изменений live dashboard проверять так:

1. Открыть trainer dashboard.
2. Открыть live dashboard комнаты.
3. Начать тренировку.
4. Зайти дилером из Godot.
5. Проверить:
   - live-log обновляется;
   - Live View обновляется;
   - карты видны корректно;
   - нет raw technical names в основном UI.
6. Не завершать тренировку.
7. Выйти из Godot / закрыть игру.
8. Снова зайти тем же дилером в ту же live session.
9. Проверить:
   - live-log сразу работает;
   - Live View не остаётся на старых картах;
   - при “Новая раздача” старые карты сразу исчезают;
   - новая раздача заполняется свежими картами;
   - не нужно ждать 2–3 раздачи.
10. Открыть browser console:
   - не должно быть постоянного спама `401`;
   - не должно быть `WebSocket is closed before the connection is established`;
   - единичные ошибки отдельно разбирать по факту.

---

## 25. Если порт 8000 занят

Проверить:

```bash
ss -ltnp | grep :8000
docker ps
```

Не убивать процессы вслепую, пока не понятно, это production или dev.

---

## 26. Быстрый backend deploy-порядок

Использовать только когда deploy-ветка уже подготовлена и проверена.

```bash
# 1. Проверить серверный git
cd /root/baccarat_new
git status --short
git branch --show-current
git rev-parse HEAD

# 2. Подтянуть deploy-ветку
git pull --ff-only

# 3. Собрать новый API image
cd /root/baccarat_new/baccarat-server/deploy
docker compose -f docker-compose.prod.yml build api

# 4. Проверить Alembic
docker compose -f docker-compose.prod.yml run --rm api sh -lc \
'cd /code && PYTHONPATH=/code alembic current && PYTHONPATH=/code alembic heads'

# 5. Применить миграции, если они нужны
docker compose -f docker-compose.prod.yml run --rm api sh -lc \
'cd /code && PYTHONPATH=/code alembic upgrade head'

# 6. Проверить current
docker compose -f docker-compose.prod.yml run --rm api sh -lc \
'cd /code && PYTHONPATH=/code alembic current'

# 7. Поднять API
docker compose -f docker-compose.prod.yml up -d api

# 8. Проверить API
docker compose -f docker-compose.prod.yml ps
curl -sS http://127.0.0.1:8000/api/health
docker compose -f docker-compose.prod.yml logs --tail=100 api
```

Если миграций нет, шаги Alembic можно заменить на проверку, что current уже на head.

---

## 27. Чего нельзя делать

Нельзя без отдельного осознанного решения:

```bash
git reset --hard
git clean -fd
git add .
git add -A
docker volume rm ...
alembic downgrade ...
drop database
drop table
truncate
docker compose down -v
```

---

## 28. Что документировать после каждого deploy

После каждого deploy записывать:

```text
Дата:
Ветка:
Commit:
Что менялось:
- backend
- dashboard
- миграции
- nginx/static
Миграции до:
Миграции после:
Какие контейнеры пересобраны:
Какие static-файлы скопированы:
Health:
Ошибки в logs:
Dashboard status:
Smoke-check endpoints:
Что проверено в Godot:
Какие проблемы нашли:
Какие fix commits добавлены:
```

---

## 29. Главный принцип

> Production deploy — это не “залить всё, что есть”.
> Production deploy — это поставить на сервер конкретную понятную ревизию, безопасно применить миграции, поднять API/dashboard и проверить, что сервис жив.

Второй главный принцип:

> Если ошибка непонятна — остановиться, показать точную ошибку и не делать разрушительных действий.

Третий главный принцип:

> Backend deploy, dashboard static deploy и Godot client deploy — это разные процессы. Их нельзя смешивать в одну грязную выкатку.