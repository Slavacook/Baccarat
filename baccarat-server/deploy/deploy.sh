#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# DEPLOY SCRIPT — Baccarat Trainer Server
#
# Использование:
#   ssh root@147.45.103.38
#   cd /root/baccarat-server/deploy
#   bash deploy.sh
#
# Скрипт делает:
#   1. Устанавливает Docker + Docker Compose
#   2. Настраивает .env (если нет)
#   3. Запускает все сервисы
#   4. Применяет миграции БД
#   5. Проверяет работоспособность
# ═══════════════════════════════════════════════════════════════

set -e

echo "🚀 Baccarat Trainer Server — Деплой"
echo "====================================="

# ─── Цвета ───
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Шаг 1: Проверка Docker ───
log_info "Проверка Docker..."
if ! command -v docker &> /dev/null; then
    log_warn "Docker не установлен. Устанавливаю..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

if ! command -v docker compose &> /dev/null; then
    log_warn "Docker Compose не установлен. Устанавливаю..."
    apt-get update && apt-get install -y docker-compose-plugin
fi

log_info "Docker: $(docker --version)"
log_info "Docker Compose: $(docker compose version)"

# ─── Шаг 2: Проверка .env ───
if [ ! -f .env ]; then
    log_warn ".env не найден! Копирую из примера..."
    cp .env.prod.example .env
    log_warn "⚠️  ОТРЕДАКТИРУЙ .env ПЕРЕД ЗАПУСКОМ!"
    log_warn "   Особенно: DB_PASSWORD, REDIS_PASSWORD, JWT_SECRET_KEY"
    log_warn "   Для генерации ключей:"
    log_warn '   python3 -c "import secrets; print(secrets.token_urlsafe(48))"'
    exit 1
fi

# Загружаем переменные
set -a
source .env
set +a

# ─── Шаг 3: Остановка старых контейнеров ───
log_info "Остановка старых контейнеров..."
docker compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true

# ─── Шаг 4: Запуск сервисов ───
log_info "Запуск сервисов..."
docker compose -f docker-compose.prod.yml up -d --build

# ─── Шаг 5: Ожидание БД ───
log_info "Ожидание PostgreSQL..."
sleep 5

# ─── Шаг 6: Применение миграций ───
log_info "Применение миграций БД..."
docker compose -f docker-compose.prod.yml exec -T api \
    python -m alembic upgrade head || {
    log_error "Миграции не применены!"
    exit 1
}

# ─── Шаг 7: Проверка ───
log_info "Проверка работоспособности..."
sleep 3
HEALTH=$(curl -sf http://localhost:8000/api/health 2>/dev/null || echo "FAILED")

if echo "$HEALTH" | grep -q "ok"; then
    log_info "✅ Сервер работает!"
    log_info "   API: http://$(hostname -I | awk '{print $1}'):8000"
    log_info "   Health: $HEALTH"
else
    log_warn "⚠️  Сервер ещё запускается. Подожди 30 сек и проверь:"
    log_warn "   curl http://localhost:8000/api/health"
fi

# ─── Шаг 8: Статус ───
log_info "Запущенные контейнеры:"
docker compose -f docker-compose.prod.yml ps

echo ""
echo "====================================="
log_info "✅ Деплой завершён!"
echo ""
log_warn "Следующие шаги:"
echo "  1. Обновить base_url в APIClient.gd (Godot)"
echo "  2. Настроить SSL (см. docs/SSL_SETUP.md)"
echo "  3. Протестировать API:"
echo "     curl https://<IP>/api/health"
echo ""
