/**
 * Веб-дашборд тренера (MVP): вход, комнаты, live-сессия, опрос результатов.
 * Работает с тем же origin, что и API (например https://baccarat-trainer.ru).
 */

const STORAGE_ACCESS_KEY = "bt_trainer_access_token";
const STORAGE_REFRESH_KEY = "bt_trainer_refresh_token";
const STORAGE_ROOM_PINS_KEY = "bt_room_pins_cache_v1";

const el = (id) => document.getElementById(id);

let pollTimer = null;
let sessionWs = null;
let currentSessionId = null;
let currentSessionInfoBase = "";
let onlineDealers = null;
let readyDealerIds = new Set();
let connectedDealerIds = new Set();
let refreshInFlight = null;
let latestDealersSnapshot = [];
let dealerRoundsCache = [];
let roomPinsSnapshot = [];
let currentRoomCode = "";
const liveTableStore = {
  byDealerId: new Map(),
};
const LIVE_FEED_MAX = 100;
const LIVE_MONITOR_TYPES = new Set([
  "round_started",
  "error_occurred",
  "action_performed",
  "round_completed",
]);

function resetLiveCounters() {
  onlineDealers = null;
  readyDealerIds = new Set();
  connectedDealerIds = new Set();
  liveTableStore.byDealerId.clear();
}

function applyTableState(snapshot) {
  if (!snapshot || typeof snapshot !== "object") return false;
  const dealerId = String(snapshot.dealer_id || "").trim();
  if (!dealerId) return false;

  const seqRaw = snapshot.event_seq;
  if (typeof seqRaw !== "number" || !Number.isInteger(seqRaw)) return false;

  const roundId = String(snapshot.round_id || "").trim();
  const prev = liveTableStore.byDealerId.get(dealerId);
  const lastSeq = prev && Number.isInteger(prev.lastSeq) ? prev.lastSeq : -1;
  if (seqRaw <= lastSeq) return false;

  liveTableStore.byDealerId.set(dealerId, {
    lastSeq: seqRaw,
    currentRoundId: roundId || (prev ? prev.currentRoundId : ""),
    currentState: snapshot,
  });

  renderLiveTableView();
  if (typeof console !== "undefined" && typeof console.debug === "function") {
    console.debug("[live-table] state applied", {
      dealerId,
      eventSeq: seqRaw,
      roundId: roundId || null,
    });
  }
  return true;
}

function applyTableStateSync(states) {
  if (!Array.isArray(states)) return 0;
  let applied = 0;
  for (const item of states) {
    if (applyTableState(item)) applied += 1;
  }
  if (applied > 0) renderLiveTableView();
  return applied;
}

function _renderCardCodesFromSlots(slots) {
  if (!Array.isArray(slots)) return "<span class=\"live-card is-hidden\">??</span>";
  const out = [];
  for (const slot of slots) {
    if (!slot || typeof slot !== "object") {
      out.push("<span class=\"live-card is-empty\">--</span>");
      continue;
    }
    const isVisible = slot.visible === true;
    const code = slot.code != null ? String(slot.code) : "";
    if (!isVisible) out.push("<span class=\"live-card is-hidden\">??</span>");
    else if (!code) out.push("<span class=\"live-card is-empty\">--</span>");
    else out.push(`<span class=\"live-card\">${code}</span>`);
  }
  return out.join("");
}

function _phaseClass(phase) {
  const p = String(phase || "waiting").trim().toLowerCase();
  return "phase-" + (p || "waiting");
}

function _safeScore(value) {
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  if (typeof value === "string" && value.trim() !== "") return value.trim();
  return "—";
}

function _safePhase(value) {
  if (typeof value === "string" && value.trim() !== "") return value.trim();
  return "waiting";
}

function _safeAction(state) {
  const lastAction = state && state.last_action && typeof state.last_action === "object" ? state.last_action : {};
  const actionType = lastAction.type != null && String(lastAction.type).trim() !== "" ? String(lastAction.type) : "—";
  const actionValue = lastAction.value != null ? String(lastAction.value) : "";
  const result = lastAction.result || "";
  const expected = lastAction.expected != null ? String(lastAction.expected) : "";
  const actual = lastAction.actual != null ? String(lastAction.actual) : "";
  return { actionType, actionValue, result, expected, actual };
}

function _safeError(state) {
  const error = state && state.error && typeof state.error === "object" ? state.error : {};
  const hasError = error.active === true;
  const errorType = error.error_type != null ? String(error.error_type) : "";
  const errorMsg = error.message != null ? String(error.message) : "";
  return { hasError, errorType, errorMsg };
}

function renderLiveTableView() {
  const root = el("live-table-view");
  if (!root) return;
  root.innerHTML = "";
  const rows = Array.from(liveTableStore.byDealerId.entries());
  if (rows.length === 0) {
    root.textContent = "Нет live-данных стола.";
    return;
  }

  for (const [dealerId, entry] of rows) {
    const state = entry && entry.currentState && typeof entry.currentState === "object" ? entry.currentState : {};
    const dealerName = state.display_name ? String(state.display_name) : dealerDisplayName(dealerId);
    const roundNumber = state.round_number != null ? String(state.round_number) : "—";
    const phase = _safePhase(state.phase);
    const player = state.player && typeof state.player === "object" ? state.player : {};
    const banker = state.banker && typeof state.banker === "object" ? state.banker : {};
    const playerScore = _safeScore(player.score);
    const bankerScore = _safeScore(banker.score);
    const { actionType, actionValue, result, expected, actual } = _safeAction(state);
    const { hasError, errorType, errorMsg } = _safeError(state);
    const lives = state.lives != null ? String(state.lives) : "";
    const gameOver = state.game_over === true;
    const eventSeq = state.event_seq != null ? String(state.event_seq) : entry.lastSeq != null ? String(entry.lastSeq) : "—";

    const card = document.createElement("article");
    card.className = "live-dealer-card";
    card.innerHTML = `
      <div class="live-dealer-header">
        <div class="live-title">
          <strong>${dealerName}</strong>
          <span class="muted small mono">${dealerId}</span>
        </div>
        <span class="live-phase ${_phaseClass(phase)}">${phase}</span>
      </div>
      
      <div class="live-meta muted small">
        <span>Раунд: ${roundNumber}</span>
        <span>seq: ${eventSeq}</span>
        ${lives ? `<span>Lives: ${lives}</span>` : ""}
        ${gameOver ? `<span class="live-game-over">Game Over</span>` : ""}
      </div>
      
      <div class="live-table-area">
        <div class="live-zone live-zone-banker">
          <div class="live-zone-header">Banker</div>
          <div class="live-cards">${_renderCardCodesFromSlots(banker.cards)}</div>
          <div class="live-score">${bankerScore}</div>
        </div>
        
        <div class="live-zone live-zone-player">
          <div class="live-zone-header">Player</div>
          <div class="live-cards">${_renderCardCodesFromSlots(player.cards)}</div>
          <div class="live-score">${playerScore}</div>
        </div>
      </div>
      
      <div class="live-action-section">
        <div class="live-action-title">Last Action:</div>
        <div class="live-action-content">
          ${actionType !== "—" ? `<span class="mono">${actionType}${actionValue ? ` (${actionValue})` : ""}</span>` : "No action recorded"}
          ${result ? ` | <span class="mono">${result}${expected ? `, exp: ${expected}` : ""}${actual ? `, act: ${actual}` : ""}</span>` : ""}
        </div>
      </div>
      
      <div class="live-error-section">
        <div class="live-error-title">Error:</div>
        <div class="live-error-content">
          ${
            hasError
              ? `<span class="live-error-badge">Ошибка: ${errorType || "unknown"}${errorMsg ? ` — ${errorMsg}` : ""}</span>`
              : `<span class="live-ok-badge">OK</span>`
          }
        </div>
      </div>
    `;
    root.appendChild(card);
  }
}

function clearLiveFeed() {
  const ul = el("live-feed-list");
  if (ul) ul.innerHTML = "";
  const empty = el("live-feed-empty");
  if (empty) empty.hidden = false;
}

function dealerDisplayName(dealerId) {
  const id = String(dealerId || "");
  if (!id) return "—";
  const row = latestDealersSnapshot.find((d) => String(d.dealer_id || "") === id);
  return row && row.display_name ? String(row.display_name) : id.slice(0, 8) + "…";
}

function formatLiveEventLine(t, data) {
  const name = dealerDisplayName(data.dealer_id);
  const r = data.round_number != null ? `#${data.round_number}` : "";
  if (t === "error_occurred") {
    const et = data.error_type || "ошибка";
    const msg = data.message ? String(data.message) : "";
    return `${name} ${r} — ${et}${msg ? `: ${msg}` : ""}`;
  }
  if (t === "action_performed") {
    const at = data.action_type || "действие";
    const val = data.value != null && String(data.value) !== "" ? ` → ${data.value}` : "";
    return `${name} ${r} — ${at}${val}`;
  }
  if (t === "round_started") {
    return `${name} ${r} — раздача`;
  }
  if (t === "round_completed") {
    const acc = typeof data.accuracy === "number" ? `${(data.accuracy <= 1 ? data.accuracy * 100 : data.accuracy).toFixed(0)}%` : "—";
    const go = data.is_game_over ? " (game over)" : "";
    return `${name} ${r} — раунд завершён, точность ${acc}${go}`;
  }
  return `${name} — ${t}`;
}

function pushLiveFeedEntry(msgType, data) {
  const ul = el("live-feed-list");
  const empty = el("live-feed-empty");
  if (!ul) return;
  const errOnly = el("live-feed-errors-only")?.checked;
  if (errOnly && msgType !== "error_occurred") return;

  const li = document.createElement("li");
  li.dataset.msgType = msgType;
  const ts = document.createElement("span");
  ts.className = "ts";
  const d = new Date();
  ts.textContent = d.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit", second: "2-digit" });

  const tag = document.createElement("span");
  tag.className = "tag " + (msgType === "error_occurred" ? "tag-err" : msgType === "action_performed" ? "tag-ok" : "tag-info");
  tag.textContent =
    msgType === "error_occurred" ? "Ошибка" : msgType === "action_performed" ? "Действие" : msgType === "round_started" ? "Старт" : "Конец";

  const text = document.createElement("span");
  text.textContent = formatLiveEventLine(msgType, data && typeof data === "object" ? data : {});

  li.appendChild(ts);
  li.appendChild(tag);
  li.appendChild(text);
  ul.insertBefore(li, ul.firstChild);
  while (ul.children.length > LIVE_FEED_MAX) {
    ul.removeChild(ul.lastChild);
  }
  if (empty) empty.hidden = ul.children.length > 0;
}

function pulseDealerRow(dealerId) {
  const id = String(dealerId || "");
  if (!id) return;
  const tbody = el("dealers-table")?.querySelector("tbody");
  if (!tbody) return;
  const tr = Array.from(tbody.querySelectorAll("tr[data-dealer-id]")).find((row) => row.dataset.dealerId === id);
  if (!tr) return;
  tr.classList.remove("row-live-error");
  void tr.offsetWidth;
  tr.classList.add("row-live-error");
  window.setTimeout(() => tr.classList.remove("row-live-error"), 2600);
}

function refilterLiveFeed() {
  const ul = el("live-feed-list");
  if (!ul) return;
  const errOnly = el("live-feed-errors-only")?.checked;
  for (const li of ul.querySelectorAll("li")) {
    const t = li.dataset.msgType || "";
    li.hidden = errOnly && t !== "error_occurred";
  }
}

function setTrainingButtons(active) {
  const toggle = el("btn-toggle-training");
  if (toggle) toggle.textContent = active ? "Завершить тренировку" : "Начать тренировку";
}

function renderSessionInfo() {
  const parts = [];
  if (onlineDealers != null) parts.push(`онлайн дилеров: ${onlineDealers}`);
  if (readyDealerIds.size > 0) parts.push(`готовы: ${readyDealerIds.size}`);
  el("session-info").textContent = parts.join(" | ");
}

function openDealerDetailsModal() {
  el("dealer-details-modal").classList.remove("hidden");
}

function closeDealerDetailsModal() {
  el("dealer-details-modal").classList.add("hidden");
}

function openCreateRoomModal() {
  el("create-room-modal").classList.remove("hidden");
}

function closeCreateRoomModal() {
  el("create-room-modal").classList.add("hidden");
}

function renderDealerRounds(items) {
  const mode = el("dealer-rounds-filter")?.value || "all";
  const visibleItems =
    mode === "errors"
      ? (items || []).filter((r) => Array.isArray(r.errors) && r.errors.length > 0)
      : items || [];
  const tbody = el("dealer-rounds-table").querySelector("tbody");
  tbody.innerHTML = "";
  const empty = el("dealer-rounds-empty");
  if (!Array.isArray(visibleItems) || visibleItems.length === 0) {
    empty.hidden = false;
    return;
  }
  empty.hidden = true;
  for (const r of visibleItems) {
    const tr = document.createElement("tr");
    const round = document.createElement("td");
    round.textContent = `#${r.round_number ?? "—"}`;
    const status = document.createElement("td");
    const winnerOk = r.winner_correct === true;
    const hasErrors = Array.isArray(r.errors) && r.errors.length > 0;
    status.textContent = winnerOk && !hasErrors ? "✅" : "❌";
    const acc = document.createElement("td");
    const av = r.accuracy;
    acc.textContent = typeof av === "number" ? `${av.toFixed(1)}%` : String(av ?? "—");
    const details = document.createElement("td");
    details.textContent = formatRoundLine(r);
    tr.appendChild(round);
    tr.appendChild(status);
    tr.appendChild(acc);
    tr.appendChild(details);
    tbody.appendChild(tr);
  }
}

function formatRoundLine(r) {
  const cards = r.round_context || {};
  const pCards = Array.isArray(cards.player_cards) ? cards.player_cards : [];
  const bCards = Array.isArray(cards.banker_cards) ? cards.banker_cards : [];
  const bThird = toPrettyCard(bCards.length >= 3 ? bCards[2] : "🚫");
  const pThird = toPrettyCard(pCards.length >= 3 ? pCards[2] : "🚫");
  const b1 = toPrettyCard(bCards[0] || "🚫");
  const b2 = toPrettyCard(bCards[1] || "🚫");
  const p1 = toPrettyCard(pCards[0] || "🚫");
  const p2 = toPrettyCard(pCards[1] || "🚫");
  const wc = String((r.winner_chosen || "")).toLowerCase();
  let winnerIcon = "👑🔵";
  if (wc === "banker") winnerIcon = "👑🔴";
  if (wc === "tie") winnerIcon = "🟢";
  const isOk = r.winner_correct === true && (!Array.isArray(r.errors) || r.errors.length === 0);
  const mark = isOk ? "✅" : "❌";
  return `[${bThird}] [${b1}] [${b2}] - [${p1}] [${p2}] [${pThird}] - ${winnerIcon} - ${mark}`;
}

function toPrettyCard(raw) {
  const t = String(raw || "").trim();
  if (!t || t === "🚫") return "🚫";
  const m = t.match(/^(.+?)([CHSD])$/i);
  if (!m) return t;
  const rank = m[1].toUpperCase();
  const suit = m[2].toUpperCase();
  const suitMap = { C: "♣", H: "♥", S: "♠", D: "♦" };
  return `${rank}${suitMap[suit] || suit}`;
}

async function openDealerDetails(dealerId) {
  if (!currentSessionId || !dealerId) return;
  const dealer = latestDealersSnapshot.find((d) => String(d.dealer_id || "") === String(dealerId));
  el("dealer-details-title").textContent = dealer ? `Дилер: ${dealer.display_name}` : "Дилер";
  el("dealer-details-subtitle").textContent = `Сессия: ${currentSessionId}`;
  openDealerDetailsModal();
  renderDealerRounds([]);
  const { ok, data } = await api(
    "GET",
    `/api/sessions/${encodeURIComponent(currentSessionId)}/dealers/${encodeURIComponent(dealerId)}/rounds?limit=150&offset=0`
  );
  if (!ok || !data || !Array.isArray(data.rounds)) {
    dealerRoundsCache = [];
    el("dealer-rounds-empty").hidden = false;
    return;
  }
  dealerRoundsCache = data.rounds;
  renderDealerRounds(dealerRoundsCache);
}

function getToken() {
  return sessionStorage.getItem(STORAGE_ACCESS_KEY) || "";
}

function getRefreshToken() {
  return sessionStorage.getItem(STORAGE_REFRESH_KEY) || "";
}

function setTokens(accessToken, refreshToken) {
  if (accessToken) sessionStorage.setItem(STORAGE_ACCESS_KEY, accessToken);
  else sessionStorage.removeItem(STORAGE_ACCESS_KEY);
  if (refreshToken) sessionStorage.setItem(STORAGE_REFRESH_KEY, refreshToken);
}

function clearTokens() {
  sessionStorage.removeItem(STORAGE_ACCESS_KEY);
  sessionStorage.removeItem(STORAGE_REFRESH_KEY);
}

function handleAuthExpired(message = "Сессия истекла. Войдите снова.") {
  clearTokens();
  stopLiveWatch();
  clearLiveFeed();
  currentSessionId = null;
  currentSessionInfoBase = "";
  resetLiveCounters();
  renderSessionInfo();
  setDashboardVisible(false);
  setAuthTab("login");
  showError("login-error", message);
  showError("action-error", "");
}

async function tryRefreshToken() {
  if (refreshInFlight) return await refreshInFlight;
  refreshInFlight = (async () => {
    const rt = getRefreshToken();
    if (!rt) return false;
    try {
      const res = await fetch("/api/auth/trainer/refresh", {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: rt }),
      });
      const text = await res.text();
      let data = null;
      if (text) {
        try {
          data = JSON.parse(text);
        } catch {
          data = null;
        }
      }
      if (!res.ok || !data || !data.access_token) {
        clearTokens();
        return false;
      }
      setTokens(data.access_token, data.refresh_token || rt);
      return true;
    } catch {
      return false;
    }
  })();
  try {
    return await refreshInFlight;
  } finally {
    refreshInFlight = null;
  }
}

async function api(method, path, body, canRetry = true) {
  const headers = { Accept: "application/json" };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const res = await fetch(path, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { detail: text };
    }
  }
  if (
    res.status === 401 &&
    canRetry &&
    path !== "/api/auth/trainer/login" &&
    path !== "/api/auth/trainer/register" &&
    path !== "/api/auth/trainer/refresh"
  ) {
    const refreshed = await tryRefreshToken();
    if (refreshed) {
      return await api(method, path, body, false);
    }
    handleAuthExpired("Сессия истекла или токен недействителен. Войдите снова.");
    return { ok: false, status: 401, data: { detail: "AUTH_EXPIRED" } };
  }
  return { ok: res.ok, status: res.status, data };
}

function showError(targetId, message) {
  const node = el(targetId);
  if (!node) return;
  if (!message) {
    node.hidden = true;
    node.textContent = "";
    return;
  }
  node.hidden = false;
  node.textContent = message;
}

function stopPoll() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

function closeSessionWs() {
  if (!sessionWs) return;
  try {
    sessionWs.onopen = null;
    sessionWs.onmessage = null;
    sessionWs.onerror = null;
    sessionWs.onclose = null;
    sessionWs.close();
  } catch (_) {
    /* ignore */
  }
  sessionWs = null;
}

function stopLiveWatch() {
  stopPoll();
  closeSessionWs();
}

function sessionWsUrl(sessionId) {
  const token = getToken();
  if (!token || !sessionId) return "";
  const { protocol, host } = window.location;
  const wsProto = protocol === "https:" ? "wss:" : "ws:";
  return `${wsProto}//${host}/ws/sessions/${encodeURIComponent(sessionId)}?token=${encodeURIComponent(token)}`;
}

function startPollResults() {
  stopLiveWatch();
  fetchResultsOnce();
  pollTimer = setInterval(fetchResultsOnce, 5000);
}

function startTrainerSessionWebSocket() {
  stopLiveWatch();
  const url = sessionWsUrl(currentSessionId);
  if (!url || typeof WebSocket === "undefined") {
    startPollResults();
    return;
  }
  try {
    sessionWs = new WebSocket(url);
  } catch (_) {
    startPollResults();
    return;
  }
  sessionWs.onopen = () => {
    fetchResultsOnce();
  };
  sessionWs.onmessage = (ev) => {
    let msg = null;
    try {
      msg = JSON.parse(ev.data);
    } catch {
      return;
    }
    const t = msg.type || "";
    const data = msg.data && typeof msg.data === "object" ? msg.data : {};
    if (t === "dealer_joined" || t === "dealer_left") {
      if (typeof data.online_count === "number") {
        onlineDealers = data.online_count;
      }
      if (data.dealer_id) {
        const did = String(data.dealer_id);
        if (t === "dealer_joined") connectedDealerIds.add(did);
        else connectedDealerIds.delete(did);
      }
      if (t === "dealer_left" && data.dealer_id) {
        readyDealerIds.delete(String(data.dealer_id));
      }
      renderSessionInfo();
    }
    if (t === "dealer_ready" && data.dealer_id) {
      readyDealerIds.add(String(data.dealer_id));
      connectedDealerIds.add(String(data.dealer_id));
      renderSessionInfo();
    }
    if (t === "dealer_update" && data.dealer_id) {
      connectedDealerIds.add(String(data.dealer_id));
    }
    if (
      t === "dealer_update" ||
      t === "round_sync" ||
      t === "dealer_joined" ||
      t === "dealer_left" ||
      t === "dealer_ready" ||
      t === "session_started" ||
      t === "session_ended"
    ) {
      fetchResultsOnce();
    }
    if (LIVE_MONITOR_TYPES.has(t)) {
      pushLiveFeedEntry(t, data);
      if (t === "error_occurred") {
        pulseDealerRow(data.dealer_id);
      }
      fetchResultsOnce();
    }
    if (t === "table_state") {
      applyTableState(data);
    }
    if (t === "table_state_sync") {
      const states = data && Array.isArray(data.states) ? data.states : [];
      applyTableStateSync(states);
    }
  };
  sessionWs.onerror = () => {
    try {
      sessionWs.close();
    } catch (_) {
      /* ignore */
    }
  };
  sessionWs.onclose = () => {
    sessionWs = null;
    if (!currentSessionId) return;
    if (pollTimer) return;
    startPollResults();
  };
}

function setDashboardVisible(visible) {
  el("auth-panel").classList.toggle("hidden", visible);
  el("dashboard").classList.toggle("hidden", !visible);
}

function setDashboardStage(stage) {
  const isLive = stage === "live";
  el("room-stage").classList.toggle("hidden", isLive);
  el("live-stage").classList.toggle("hidden", !isLive);
}

function formatDuration(seconds) {
  const s = Number(seconds || 0);
  const mm = Math.floor(s / 60);
  const ss = s % 60;
  return `${mm}:${String(ss).padStart(2, "0")}`;
}

function setCurrentRoom(code, roomName = "") {
  currentRoomCode = String(code || "");
  const label = el("current-room-label");
  if (label) {
    label.textContent = currentRoomCode ? `Комната: ${roomName || currentRoomCode}` : "Комната: —";
  }
}

function formatApiError(data) {
  if (!data) return "Ошибка сервера";
  const d = data.detail;
  if (typeof d === "string") {
    if (d === "Email already registered") return "Этот email уже зарегистрирован — войдите или укажите другой.";
    return d;
  }
  if (Array.isArray(d)) {
    return d
      .map((item) => {
        if (item && typeof item === "object" && "msg" in item) return String(item.msg);
        return JSON.stringify(item);
      })
      .join(" ");
  }
  return String(d);
}

function setAuthTab(which) {
  const isLogin = which === "login";
  el("pane-login").classList.toggle("hidden", !isLogin);
  el("pane-register").classList.toggle("hidden", isLogin);
  el("tab-login").classList.toggle("active", isLogin);
  el("tab-register").classList.toggle("active", !isLogin);
  el("tab-login").setAttribute("aria-selected", isLogin ? "true" : "false");
  el("tab-register").setAttribute("aria-selected", !isLogin ? "true" : "false");
  showError("login-error", "");
  showError("register-error", "");
}

async function refreshRooms() {
  const { ok, status, data } = await api("GET", "/api/rooms/");
  if (!ok) {
    showError("action-error", (data && data.detail) || `Ошибка списка комнат (${status})`);
    return;
  }
  const rooms = Array.isArray(data) ? data.filter((r) => String(r.status || "").toLowerCase() !== "closed") : [];
  if (rooms.length === 0) {
    setCurrentRoom("", "");
    renderRoomsList([]);
    return;
  }
  if (!currentRoomCode || !rooms.some((r) => r.room_code === currentRoomCode)) {
    currentRoomCode = String(rooms[0].room_code || "");
  }
  const selected = rooms.find((r) => r.room_code === currentRoomCode) || rooms[0];
  setCurrentRoom(selected.room_code, `${selected.name} (${selected.room_code})`);
  renderRoomsList(rooms);
  await fetchRoomPinsOnce();
  fetchRoomDealersOnce();
}

function selectedRoomCode() {
  return currentRoomCode || "";
}

function _loadPinsCache() {
  try {
    const raw = localStorage.getItem(STORAGE_ROOM_PINS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function _savePinsCache(cache) {
  try {
    localStorage.setItem(STORAGE_ROOM_PINS_KEY, JSON.stringify(cache || {}));
  } catch {
    /* ignore */
  }
}

function cacheRoomPins(roomCode, roomName, pins) {
  if (!roomCode || !Array.isArray(pins) || pins.length === 0) return;
  const cache = _loadPinsCache();
  cache[roomCode] = {
    room_name: roomName || "",
    pins,
    saved_at: new Date().toISOString(),
  };
  _savePinsCache(cache);
}

function showPinsForSelectedRoom() {}

function renderRoomsList(rooms) {
  const tbody = el("rooms-list-table").querySelector("tbody");
  tbody.innerHTML = "";
  for (const room of rooms) {
    const tr = document.createElement("tr");
    const n = document.createElement("td");
    n.textContent = room.name || "—";
    const c = document.createElement("td");
    c.textContent = room.room_code || "—";
    const pickTd = document.createElement("td");
    const pick = document.createElement("button");
    pick.type = "button";
    pick.className = "ghost";
    pick.textContent = room.room_code === currentRoomCode ? "Выбрана" : "Выбрать";
    pick.disabled = room.room_code === currentRoomCode;
    pick.addEventListener("click", async () => {
      setCurrentRoom(room.room_code, `${room.name} (${room.room_code})`);
      await fetchRoomPinsOnce();
      await fetchRoomDealersOnce();
      await loadTrainerLiveSession();
      renderRoomsList(rooms);
    });
    pickTd.appendChild(pick);
    const a = document.createElement("td");
    const del = document.createElement("button");
    del.type = "button";
    del.className = "danger";
    del.textContent = "🗑";
    del.addEventListener("click", async () => {
      const okDel = window.confirm(`Удалить комнату ${room.room_code}?`);
      if (!okDel) return;
      const { ok } = await api("DELETE", `/api/rooms/${encodeURIComponent(room.room_code)}`);
      if (!ok) return;
      await refreshRooms();
    });
    a.appendChild(del);
    tr.appendChild(n);
    tr.appendChild(c);
    tr.appendChild(pickTd);
    tr.appendChild(a);
    tbody.appendChild(tr);
  }
}

function cachePinUpdate(roomCode, slot, pin) {
  const cache = _loadPinsCache();
  const item = cache[roomCode] || { room_name: "", pins: [] };
  const pins = Array.isArray(item.pins) ? item.pins.slice() : [];
  const idx = pins.findIndex((p) => Number(p.dealer_slot) === Number(slot));
  if (idx >= 0) pins[idx] = { dealer_slot: Number(slot), pin: String(pin) };
  else pins.push({ dealer_slot: Number(slot), pin: String(pin) });
  pins.sort((a, b) => Number(a.dealer_slot) - Number(b.dealer_slot));
  item.pins = pins;
  item.saved_at = new Date().toISOString();
  cache[roomCode] = item;
  _savePinsCache(cache);
}

function cachePinDelete(roomCode, slot) {
  const cache = _loadPinsCache();
  const item = cache[roomCode];
  if (!item || !Array.isArray(item.pins)) return;
  item.pins = item.pins.filter((p) => Number(p.dealer_slot) !== Number(slot));
  item.saved_at = new Date().toISOString();
  cache[roomCode] = item;
  _savePinsCache(cache);
}

function renderRoomPins(items) {
  const code = selectedRoomCode();
  const roomLabel = el("current-room-label") ? el("current-room-label").textContent.replace("Комната: ", "") : code;
  const titleNode = el("room-access-title");
  if (titleNode) titleNode.textContent = `Доступ в комнату: ${roomLabel || "—"}`;
  const tbody = el("room-access-table").querySelector("tbody");
  tbody.innerHTML = "";
  const cacheItem = _loadPinsCache()[selectedRoomCode()] || {};
  const pinMap = new Map((cacheItem.pins || []).map((p) => [Number(p.dealer_slot), String(p.pin)]));
  for (const row of items) {
    const tr = document.createElement("tr");
    const cSlot = document.createElement("td");
    cSlot.textContent = String(row.dealer_slot ?? "—");
    const cName = document.createElement("td");
    cName.textContent = row.display_name || "—";
    const cPin = document.createElement("td");
    cPin.textContent = pinMap.get(Number(row.dealer_slot)) || "••••••";
    const cActions = document.createElement("td");
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "ghost";
    btn.textContent = "Сбросить PIN";
    btn.addEventListener("click", async () => {
      const code = selectedRoomCode();
      if (!code) return;
      const { ok, data } = await api("POST", `/api/rooms/${encodeURIComponent(code)}/pins/${encodeURIComponent(row.dealer_slot)}/reset`, {});
      if (!ok || !data) return;
      cachePinUpdate(code, row.dealer_slot, data.pin);
      await fetchRoomPinsOnce();
    });
    cActions.appendChild(btn);
    const del = document.createElement("button");
    del.type = "button";
    del.className = "danger";
    del.textContent = "🗑";
    del.style.marginLeft = "6px";
    del.addEventListener("click", async () => {
      const code = selectedRoomCode();
      if (!code) return;
      const { ok } = await api("DELETE", `/api/rooms/${encodeURIComponent(code)}/pins/${encodeURIComponent(row.dealer_slot)}`);
      if (!ok) return;
      cachePinDelete(code, row.dealer_slot);
      await fetchRoomPinsOnce();
    });
    cActions.appendChild(del);
    tr.appendChild(cSlot);
    tr.appendChild(cName);
    tr.appendChild(cPin);
    tr.appendChild(cActions);
    tbody.appendChild(tr);
  }
}

async function fetchRoomPinsOnce() {
  const code = selectedRoomCode();
  if (!code) {
    roomPinsSnapshot = [];
    renderRoomPins([]);
    return;
  }
  const { ok, data } = await api("GET", `/api/rooms/${encodeURIComponent(code)}/pins`);
  if (!ok || !Array.isArray(data)) return;
  roomPinsSnapshot = data;
  renderRoomPins(data);
}

async function createRoom() {
  showError("action-error", "");
  const name = el("new-room-name").value.trim();
  if (name.length < 3) {
    showError("action-error", "Название комнаты — не короче 3 символов.");
    return;
  }
  const { ok, status, data } = await api("POST", "/api/rooms/", { name, max_dealers: 5 });
  if (!ok) {
    showError("action-error", formatApiError(data) || `Не удалось создать комнату (${status})`);
    return;
  }
  const room = data.room;
  const pins = Array.isArray(data.pins) ? data.pins : [];
  cacheRoomPins(room && room.room_code, room && room.name, pins);
  el("new-room-name").value = "";
  closeCreateRoomModal();
  await refreshRooms();
  if (room && room.room_code) {
    setCurrentRoom(room.room_code, `${room.name || room.room_code} (${room.room_code})`);
    await fetchRoomPinsOnce();
    await fetchRoomDealersOnce();
  }
  showError("action-error", "");
}

async function maybeLoadSessionAfterRooms() {
  if (selectedRoomCode()) {
    await loadTrainerLiveSession();
  }
}

async function loadTrainerLiveSession() {
  showError("action-error", "");
  const code = selectedRoomCode();
  if (!code) {
    showError("action-error", "Выберите комнату");
    return;
  }
  const { ok, status, data } = await api("GET", `/api/rooms/${encodeURIComponent(code)}/trainer-live-session`);
  if (!ok) {
    stopLiveWatch();
    clearLiveFeed();
    currentSessionId = null;
    resetLiveCounters();
    setTrainingButtons(false);
    renderSessionInfo();
    if (status === 404) {
      renderResultsEmpty();
      return;
    }
    showError("action-error", (data && data.detail) || `Ошибка ${status}`);
    return;
  }
  const prevSessionId = currentSessionId;
  currentSessionId = data.session_id;
  resetLiveCounters();
  if (String(prevSessionId || "") !== String(currentSessionId || "")) {
    clearLiveFeed();
  }
  renderSessionInfo();
  setTrainingButtons(data.status === "active");
  if (data.status === "active") {
    startTrainerSessionWebSocket();
  } else {
    stopLiveWatch();
    clearLiveFeed();
    renderResultsEmpty();
  }
}

async function createLiveSession() {
  showError("action-error", "");
  const code = selectedRoomCode();
  if (!code) {
    showError("action-error", "Выберите комнату");
    return;
  }
  const { ok, status, data } = await api("POST", `/api/rooms/${encodeURIComponent(code)}/sessions`, {
    duration_minutes: 30,
  });
  if (!ok) {
    showError("action-error", (data && data.detail) || `Не удалось подготовить тренировку (${status})`);
    return;
  }
  await loadTrainerLiveSession();
}

async function startLiveSession() {
  showError("action-error", "");
  if (!currentSessionId) {
    showError("action-error", "Сначала загрузите сессию");
    return;
  }
  const { ok, status, data } = await api("POST", `/api/sessions/${encodeURIComponent(currentSessionId)}/start`, {});
  if (!ok) {
    showError("action-error", (data && data.detail) || `Старт не удался (${status})`);
    return;
  }
  await loadTrainerLiveSession();
}

async function endLiveSession() {
  showError("action-error", "");
  if (!currentSessionId) return;
  const { ok, status, data } = await api("POST", `/api/sessions/${encodeURIComponent(currentSessionId)}/end`, {});
  if (!ok) {
    showError("action-error", (data && data.detail) || `Завершение не удалось (${status})`);
    return;
  }
  stopLiveWatch();
  clearLiveFeed();
  currentSessionId = null;
  resetLiveCounters();
  setTrainingButtons(false);
  renderSessionInfo();
  renderResultsEmpty();
}

async function fetchResultsOnce() {
  if (!currentSessionId) return;
  const { ok, data } = await api("GET", `/api/sessions/${encodeURIComponent(currentSessionId)}/results`);
  if (!ok || !data || !Array.isArray(data.dealers)) {
    return;
  }
  if (data.status === "completed" || data.status === "aborted") {
    stopLiveWatch();
    setTrainingButtons(false);
    renderSessionInfo();
  }
  const roomCode = selectedRoomCode();
  const roomResp = await api("GET", `/api/rooms/${encodeURIComponent(roomCode)}/dealers`);
  const roomDealers = roomResp.ok && Array.isArray(roomResp.data) ? roomResp.data : [];
  const byId = new Map();
  for (const d of roomDealers) {
    byId.set(String(d.dealer_id), {
      dealer_id: String(d.dealer_id),
      display_name: d.display_name || "—",
      rounds_completed: 0,
      errors_total: 0,
      cards_errors: 0,
      payout_errors: 0,
      chips_errors: 0,
      live_seconds: 0,
      avg_accuracy: 0,
    });
  }
  for (const d of data.dealers) {
    const id = String(d.dealer_id || "");
    if (!id) continue;
    const prev = byId.get(id) || { dealer_id: id, display_name: d.display_name || "—" };
    byId.set(id, {
      ...prev,
      display_name: d.display_name || prev.display_name || "—",
      rounds_completed: Number(d.rounds_completed || 0),
      errors_total: Number(d.errors_total || 0),
      cards_errors: Number(d.cards_errors || 0),
      payout_errors: Number(d.payout_errors || 0),
      chips_errors: Number(d.chips_errors || 0),
      live_seconds: Number(d.live_seconds || 0),
      avg_accuracy: Number(d.avg_accuracy || 0),
    });
  }
  renderDealers(Array.from(byId.values()));
}

async function fetchRoomDealersOnce() {
  const code = selectedRoomCode();
  if (!code) {
    renderResultsEmpty();
    return;
  }
  const { ok, data } = await api("GET", `/api/rooms/${encodeURIComponent(code)}/dealers`);
  if (!ok || !Array.isArray(data)) {
    return;
  }
  const mapped = data.map((d) => ({
    dealer_id: String(d.dealer_id || ""),
    display_name: d.display_name || "—",
    rounds_completed: 0,
    errors_total: 0,
    cards_errors: 0,
    payout_errors: 0,
    chips_errors: 0,
    live_seconds: 0,
    avg_accuracy: 0,
  }));
  renderDealers(mapped);
}

async function startTrainingSimple() {
  showError("action-error", "");
  const code = selectedRoomCode();
  if (!code) {
    showError("action-error", "Выберите комнату");
    return;
  }
  await loadTrainerLiveSession();

  // toggle: если активна, то завершаем
  if (currentSessionId && el("btn-toggle-training").textContent.includes("Завершить")) {
    await endLiveSession();
    return;
  }

  if (!currentSessionId) {
    const { ok, status, data } = await api("POST", `/api/rooms/${encodeURIComponent(code)}/sessions`, {
      duration_minutes: 30,
    });
    if (!ok) {
      showError("action-error", formatApiError(data) || `Не удалось подготовить тренировку (${status})`);
      return;
    }
    currentSessionId = String((data && data.session_id) || "");
    if (!currentSessionId) {
      showError("action-error", "Сервер не вернул ID тренировки");
      return;
    }
  }
  const { ok, status, data } = await api("POST", `/api/sessions/${encodeURIComponent(currentSessionId)}/start`, {});
  if (!ok) {
    // Если уже запущено кем-то параллельно — просто обновим статус
    await loadTrainerLiveSession();
    if (status === 409) return;
    showError("action-error", formatApiError(data) || `Не удалось запустить тренировку (${status})`);
    return;
  }
  await loadTrainerLiveSession();
}

function renderDealers(dealers) {
  latestDealersSnapshot = Array.isArray(dealers) ? dealers : [];
  const tbody = el("dealers-table").querySelector("tbody");
  tbody.innerHTML = "";
  el("results-empty").hidden = dealers.length > 0;
  for (const d of dealers) {
    const tr = document.createElement("tr");
    const did = String(d.dealer_id || "");
    if (did) tr.dataset.dealerId = did;
    const name = document.createElement("td");
    if (did && currentSessionId) {
      const a = document.createElement("a");
      a.className = "dealer-link";
      a.textContent = d.display_name || "—";
      a.href = "#";
      a.addEventListener("click", (ev) => {
        ev.preventDefault();
        openDealerDetails(did);
      });
      name.appendChild(a);
    } else {
      name.textContent = d.display_name || "—";
    }
    const online = document.createElement("td");
    online.textContent = did && connectedDealerIds.has(did) ? "в сети" : "офлайн";
    const errs = document.createElement("td");
    errs.textContent = `🃏${Number(d.cards_errors || 0)}  💰${Number(d.payout_errors || 0)}  🔢${Number(d.chips_errors || 0)}`;
    const liveTime = document.createElement("td");
    liveTime.textContent = formatDuration(Number(d.live_seconds || 0));
    const rounds = document.createElement("td");
    rounds.textContent = String(d.rounds_completed ?? 0);
    const acc = document.createElement("td");
    const v = d.avg_accuracy;
    acc.textContent = typeof v === "number" ? `${v.toFixed(1)}%` : String(v ?? "—");
    tr.appendChild(name);
    tr.appendChild(online);
    tr.appendChild(errs);
    tr.appendChild(liveTime);
    tr.appendChild(rounds);
    tr.appendChild(acc);
    tbody.appendChild(tr);
  }
}

function renderResultsEmpty() {
  const tbody = el("dealers-table").querySelector("tbody");
  tbody.innerHTML = "";
  el("results-empty").hidden = false;
}

async function onLogin() {
  showError("login-error", "");
  const email = el("email").value.trim();
  const password = el("password").value;
  if (!email || !password) {
    showError("login-error", "Введите email и пароль");
    return;
  }
  const { ok, status, data } = await api("POST", "/api/auth/trainer/login", { email, password });
  if (!ok || !data || !data.access_token) {
    showError("login-error", formatApiError(data) || `Вход не удался (${status})`);
    return;
  }
  setTokens(data.access_token, data.refresh_token || "");
  const user = data.user || {};
  el("user-label").textContent = `${user.full_name || user.email || "тренер"}`;
  setDashboardVisible(true);
  setDashboardStage("rooms");
  await refreshRooms();
  await maybeLoadSessionAfterRooms();
}

async function onRegister() {
  showError("register-error", "");
  const email = el("reg-email").value.trim();
  const password = el("reg-password").value;
  const fullName = el("reg-full-name").value.trim();
  if (!email || !password) {
    showError("register-error", "Введите email и пароль");
    return;
  }
  const body = { email, password };
  if (fullName) body.full_name = fullName;
  const { ok, status, data } = await api("POST", "/api/auth/trainer/register", body);
  if (!ok || !data || !data.access_token) {
    showError("register-error", formatApiError(data) || `Регистрация не удалась (${status})`);
    return;
  }
  setTokens(data.access_token, data.refresh_token || "");
  const user = data.user || {};
  el("user-label").textContent = `${user.full_name || user.email || "тренер"}`;
  setDashboardVisible(true);
  setDashboardStage("rooms");
  await refreshRooms();
  await maybeLoadSessionAfterRooms();
}

function onLogout() {
  clearTokens();
  stopLiveWatch();
  clearLiveFeed();
  currentSessionId = null;
  setDashboardVisible(false);
  setDashboardStage("rooms");
  el("password").value = "";
  el("reg-password").value = "";
  setAuthTab("login");
}

function wire() {
  el("tab-login").addEventListener("click", () => setAuthTab("login"));
  el("tab-register").addEventListener("click", () => setAuthTab("register"));
  el("btn-login").addEventListener("click", () => onLogin());
  el("btn-register").addEventListener("click", () => onRegister());
  el("btn-logout").addEventListener("click", () => onLogout());
  el("btn-open-create-room-modal").addEventListener("click", () => openCreateRoomModal());
  el("btn-close-create-room-modal").addEventListener("click", () => closeCreateRoomModal());
  el("create-room-modal").addEventListener("click", (ev) => {
    if (ev.target === el("create-room-modal")) closeCreateRoomModal();
  });
  el("btn-create-room").addEventListener("click", () => createRoom());
  el("btn-open-room-dashboard").addEventListener("click", async () => {
    setDashboardStage("live");
    await loadTrainerLiveSession();
    await fetchResultsOnce();
  });
  el("btn-back").addEventListener("click", () => setDashboardStage("rooms"));
  el("btn-add-pin-slot").addEventListener("click", async () => {
    const code = selectedRoomCode();
    if (!code) return;
    const { ok, data } = await api("POST", `/api/rooms/${encodeURIComponent(code)}/pins`, {});
    if (!ok || !data) return;
    cachePinUpdate(code, data.dealer_slot, data.pin);
    await fetchRoomPinsOnce();
  });
  el("btn-toggle-training").addEventListener("click", () => startTrainingSimple());
  el("btn-close-dealer-details").addEventListener("click", () => closeDealerDetailsModal());
  el("dealer-rounds-filter").addEventListener("change", () => renderDealerRounds(dealerRoundsCache));
  const feedErr = el("live-feed-errors-only");
  if (feedErr) feedErr.addEventListener("change", () => refilterLiveFeed());
  el("dealer-details-modal").addEventListener("click", (ev) => {
    if (ev.target === el("dealer-details-modal")) closeDealerDetailsModal();
  });
}

function boot() {
  wire();
  if (getToken()) {
    setDashboardVisible(true);
    setDashboardStage("rooms");
    refreshRooms().then(() => {
      maybeLoadSessionAfterRooms();
    });
  }
}

boot();
