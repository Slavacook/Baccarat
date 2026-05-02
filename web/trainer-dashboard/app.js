/**
 * Веб-дашборд тренера (MVP): вход, комнаты, live-сессия, опрос результатов.
 * Работает с тем же origin, что и API (например https://baccarat-trainer.ru).
 */

const STORAGE_ACCESS_KEY = "bt_trainer_access_token";
const STORAGE_REFRESH_KEY = "bt_trainer_refresh_token";
const STORAGE_ROOM_PINS_KEY = "bt_room_pins_cache_v1";
const STORAGE_ROOM_PERSONAL_INVITE_CODES_PREFIX = "bt_room_personal_invite_codes_v1:";
const STORAGE_ROOM_INVITE_CODES_PREFIX = "bt_room_invite_codes_v1:";

const el = (id) => document.getElementById(id);

let pollTimer = null;
let roomPollTimer = null;
let roomPollInFlight = false;
let roomPollGeneration = 0;
let sessionWs = null;
let sessionWsSessionId = "";
let sessionWsGeneration = 0;
let resultsFetchInFlight = false;
let currentSessionId = null;
let currentSessionInfoBase = "";
let onlineDealers = null;
let readyDealerIds = new Set();
let connectedDealerIds = new Set();
let refreshInFlight = null;
let latestDealersSnapshot = [];
let dealerRoundsCache = [];
let liveFeedEntries = [];
let roomPinsSnapshot = [];
let roomAccessesSnapshot = [];
let roomParticipantsSnapshot = [];
let roomPersonalInvitesSnapshot = [];
let roomInviteSnapshot = null;
let selectedDealerId = null;
let roomInviteTransientMessage = "";
let roomInviteTransientManualCode = "";
let roomInviteTransientManualNote = "";
let roomInviteLimitSaveInFlight = null;
let roomInviteLimitInputDirty = false;
let roomParticipantsTransientMessage = "";
let roomParticipantsTransientManualCode = "";
let roomParticipantsTransientManualNote = "";
let generatedRoomAccesses = [];
let tournamentsSnapshot = [];
let tournamentsLoaded = false;
let createTournamentInFlight = false;
let currentRoomCode = "";
const liveTableStore = {
  byDealerId: new Map(),
};
const liveErrorsByDealerId = new Map();
const liveTimeByDealerId = new Map();
let liveTimerInterval = null;
const LIVE_FEED_MAX = 100;
const LIVE_MONITOR_TYPES = new Set([
  "round_started",
  "error_occurred",
  "action_performed",
  "round_completed",
]);
const ROOM_MODEL_POLL_MS = 4000;
const WINNER_LABELS = {
  Player: "Игрок",
  Banker: "Банкир",
  Tie: "Эгалите",
};
const PHASE_LABELS = {
  waiting: "Ожидание",
  dealing_initial: "Карты открываются",
  third_card_player: "Карта игроку",
  third_card_banker: "Карта банкиру",
  winner_selection: "Выбор победителя",
  payout: "Оплата сыгравших ставок",
  round_completed: "Конец раздачи",
};
const EVENT_ERROR_LABELS = {
  player_wrong: "Карта игроку",
  banker_wrong: "Карта банкиру",
  both_wrong: "Карта каждому",
  winner_wrong: "Неверный победитель",
  tie_wrong: "Неверный маркер Эгалите",
  natural_draw: "Натуральная комбинация",
  winner_early: "Победитель выбран слишком рано",
  collection_error: "Ошибка сбора ставки",
  payment_error: "Ошибка оплаты ставки",
  payout_wrong: "Ошибка оплаты ставки",
};

function resetLiveCounters() {
  onlineDealers = null;
  readyDealerIds = new Set();
  connectedDealerIds = new Set();
  liveTableStore.byDealerId.clear();
  clearLiveErrorCounters();
  clearLiveTimeCounters();
}

function resetLiveSessionView(options = {}) {
  const {
    clearFeed = false,
    refreshDealersTable = true,
  } = options;

  resetLiveCounters();
  if (clearFeed) {
    clearLiveFeed();
  }
  if (refreshDealersTable) {
    renderDealers(Array.isArray(latestDealersSnapshot) ? latestDealersSnapshot : []);
  }
  renderSessionInfo();
  renderLiveTableView();
}

function deleteRoomPinsCache(roomCode) {
  const code = String(roomCode || "").trim();
  if (!code) return;
  const cache = _loadPinsCache();
  if (!(code in cache)) return;
  delete cache[code];
  _savePinsCache(cache);
}

function setRoomScopedVisibility() {
  const hasRoom = Boolean(selectedRoomCode());
  el("rooms-empty-state")?.classList.toggle("hidden", hasRoom);
  el("room-details-section")?.classList.toggle("hidden", !hasRoom);
  el("btn-toggle-training")?.classList.toggle("hidden", !hasRoom);
  el("btn-delete-current-room")?.classList.toggle("hidden", !hasRoom);
}

function clearRoomAccessState() {
  roomAccessesSnapshot = [];
  generatedRoomAccesses = [];
  clearRoomAccessMessages();
  renderRoomAccesses([]);
  renderGeneratedRoomAccesses([]);
}

function formatInviteExpiresAt(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleString("ru-RU", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function showRoomInviteMessage(message) {
  roomInviteTransientMessage = message ? String(message) : "";
  const node = el("room-invite-message");
  if (!node) return;
  if (!roomInviteTransientMessage) {
    node.hidden = true;
    node.textContent = "";
    return;
  }
  node.hidden = false;
  node.textContent = roomInviteTransientMessage;
}

function formatInviteParticipantLimit(limit) {
  return limit == null ? "∞" : String(limit);
}

function getCurrentSavedRoomInviteLimit() {
  if (!roomInviteSnapshot || roomInviteSnapshot.participant_limit == null) return null;
  const participantLimit = Number(roomInviteSnapshot.participant_limit);
  return Number.isInteger(participantLimit) && participantLimit > 0 ? participantLimit : null;
}

function restoreRoomInviteLimitInput() {
  const input = el("room-invite-limit-input");
  if (!input) return;
  const savedLimit = getCurrentSavedRoomInviteLimit();
  input.value = savedLimit == null ? "" : String(savedLimit);
}

function isAddParticipantModalOpen() {
  const modal = el("add-participant-modal");
  return Boolean(modal && !modal.classList.contains("hidden"));
}

function syncRoomInviteLimitInputFromSnapshot(force = false) {
  const input = el("room-invite-limit-input");
  if (!input) return;
  const isFocused = document.activeElement === input;
  if (!force && isAddParticipantModalOpen() && (roomInviteLimitInputDirty || isFocused)) {
    return;
  }
  restoreRoomInviteLimitInput();
}

function normalizeRoomInviteLimitInput(rawValue) {
  const text = String(rawValue || "").trim();
  if (!text) return { ok: true, value: null };
  if (!/^-?\d+(?:\.\d+)?$/.test(text)) {
    return { ok: false, message: "Лимит участников должен быть целым числом или 0" };
  }
  const numericValue = Number(text);
  if (!Number.isFinite(numericValue)) {
    return { ok: false, message: "Лимит участников должен быть числом" };
  }
  if (!Number.isInteger(numericValue)) {
    return { ok: false, message: "Лимит участников должен быть целым числом" };
  }
  if (numericValue < 0) {
    return { ok: false, message: "Лимит участников не может быть отрицательным" };
  }
  if (numericValue === 0) {
    return { ok: true, value: null };
  }
  return { ok: true, value: numericValue };
}

function getRoomInviteCodesStorageKey(roomCode = selectedRoomCode()) {
  const code = String(roomCode || "").trim();
  return code ? `${STORAGE_ROOM_INVITE_CODES_PREFIX}${code}` : "";
}

function loadRoomInviteCodes(roomCode = selectedRoomCode()) {
  const key = getRoomInviteCodesStorageKey(roomCode);
  if (!key) return {};
  try {
    const raw = sessionStorage.getItem(key);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

function saveRoomInviteCodes(roomCode, codesMap) {
  const key = getRoomInviteCodesStorageKey(roomCode);
  if (!key) return;
  try {
    sessionStorage.setItem(key, JSON.stringify(codesMap || {}));
  } catch {
    // ignore storage write failures
  }
}

function storeRoomInviteCode(inviteId, inviteCode, roomCode = selectedRoomCode()) {
  const id = String(inviteId || "").trim();
  const code = String(inviteCode || "").trim();
  if (!id || !code) return;
  const codesMap = loadRoomInviteCodes(roomCode);
  codesMap[id] = code;
  saveRoomInviteCodes(roomCode, codesMap);
}

function getRoomInviteCode(inviteId, roomCode = selectedRoomCode()) {
  const id = String(inviteId || "").trim();
  if (!id) return "";
  const codesMap = loadRoomInviteCodes(roomCode);
  return String(codesMap[id] || "").trim();
}

function renderRoomInvite(invite, options = {}) {
  if (Object.prototype.hasOwnProperty.call(options, "manualCode")) {
    roomInviteTransientManualCode = String(options.manualCode || "");
    roomInviteTransientManualNote = String(options.manualNote || "");
  }
  const statusNode = el("room-invite-status");
  if (statusNode) {
    if (invite && String(invite.status || "").toLowerCase() === "active") {
      statusNode.textContent = `Активен до: ${formatInviteExpiresAt(invite.expires_at)}`;
    } else {
      statusNode.textContent = "Активен до: —";
    }
  }

  const participantsNode = el("room-invite-participants");
  if (participantsNode) {
    const activeCount = Number(invite && invite.active_participants_count != null ? invite.active_participants_count : 0);
    const participantLimit = invite && invite.participant_limit != null ? Number(invite.participant_limit) : null;
    participantsNode.textContent = `Участники: ${activeCount} / ${formatInviteParticipantLimit(participantLimit)}`;
  }

  const limitInput = el("room-invite-limit-input");
  if (limitInput) {
    syncRoomInviteLimitInputFromSnapshot();
  }

  const manualNode = el("room-invite-manual");
  if (!manualNode) return;
  manualNode.innerHTML = "";
  const isActiveInvite = invite && String(invite.status || "").toLowerCase() === "active";
  const activeInviteId = isActiveInvite ? String(invite.id || "").trim() : "";
  const cachedInviteCode = activeInviteId ? getRoomInviteCode(activeInviteId) : "";
  const visibleInviteCode = cachedInviteCode || roomInviteTransientManualCode;
  const labelNode = document.createElement("span");
  labelNode.className = "muted";
  labelNode.textContent = "Код:";
  const codeNode = document.createElement("div");
  codeNode.className = "invite-manual-code";
  codeNode.textContent = visibleInviteCode || (isActiveInvite ? "недоступен" : "—");
  manualNode.appendChild(labelNode);
  manualNode.appendChild(codeNode);

  if (visibleInviteCode) {
    const copyBtn = document.createElement("button");
    copyBtn.type = "button";
    copyBtn.className = "ghost table-action-button";
    copyBtn.textContent = "Скопировать";
    copyBtn.addEventListener("click", async () => {
      try {
        const copied = await copyRoomInviteCode(visibleInviteCode, copyBtn);
        if (!copied) throw new Error("copy_failed");
      } catch {
        showError("room-invite-error", "Не удалось скопировать код. Скопируйте его вручную.");
      }
    });
    manualNode.appendChild(copyBtn);
  }
}

function clearRoomInviteState() {
  roomInviteSnapshot = null;
  roomInviteTransientMessage = "";
  roomInviteTransientManualCode = "";
  roomInviteTransientManualNote = "";
  showError("room-invite-error", "");
  showRoomInviteMessage("");
  renderRoomInvite(null, { manualCode: "", manualNote: "" });
}

function showRoomParticipantsMessage(message) {
  roomParticipantsTransientMessage = message ? String(message) : "";
  const node = el("room-participants-message");
  if (!node) return;
  if (!roomParticipantsTransientMessage) {
    node.hidden = true;
    node.textContent = "";
    return;
  }
  node.hidden = false;
  node.textContent = roomParticipantsTransientMessage;
}

function renderRoomParticipantsManual(code = "", note = "") {
  roomParticipantsTransientManualCode = String(code || "");
  roomParticipantsTransientManualNote = String(note || "");
  const manualNode = el("room-participants-manual");
  if (!manualNode) return;
  manualNode.innerHTML = "";
  if (!roomParticipantsTransientManualCode) {
    manualNode.classList.add("hidden");
    return;
  }

  manualNode.classList.remove("hidden");
  const noteNode = document.createElement("p");
  noteNode.className = "muted small";
  noteNode.textContent = roomParticipantsTransientManualNote || "Скопируйте код вручную.";
  const codeNode = document.createElement("div");
  codeNode.className = "invite-manual-code";
  codeNode.textContent = roomParticipantsTransientManualCode;
  manualNode.appendChild(noteNode);
  manualNode.appendChild(codeNode);
}

function clearRoomParticipantsState() {
  roomParticipantsSnapshot = [];
  roomPersonalInvitesSnapshot = [];
  selectedDealerId = null;
  roomParticipantsTransientMessage = "";
  roomParticipantsTransientManualCode = "";
  roomParticipantsTransientManualNote = "";
  showError("room-participants-error", "");
  showRoomParticipantsMessage("");
  renderRoomParticipantsManual("", "");
  renderRoomParticipants([], []);
  renderSelectedDealerDetail();
  renderLiveTableView();
  renderLiveFeed();
}

function getRoomPersonalInviteCodesStorageKey(roomCode = selectedRoomCode()) {
  const code = String(roomCode || "").trim();
  return code ? `${STORAGE_ROOM_PERSONAL_INVITE_CODES_PREFIX}${code}` : "";
}

function loadRoomPersonalInviteCodes(roomCode = selectedRoomCode()) {
  const key = getRoomPersonalInviteCodesStorageKey(roomCode);
  if (!key) return {};
  try {
    const raw = sessionStorage.getItem(key);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

function saveRoomPersonalInviteCodes(roomCode, codesMap) {
  const key = getRoomPersonalInviteCodesStorageKey(roomCode);
  if (!key) return;
  try {
    sessionStorage.setItem(key, JSON.stringify(codesMap || {}));
  } catch {
    // ignore storage write failures
  }
}

function storeRoomPersonalInviteCode(accessId, accessCode, roomCode = selectedRoomCode()) {
  const id = String(accessId || "").trim();
  const code = String(accessCode || "").trim();
  if (!id || !code) return;
  const codesMap = loadRoomPersonalInviteCodes(roomCode);
  codesMap[id] = code;
  saveRoomPersonalInviteCodes(roomCode, codesMap);
}

function getRoomPersonalInviteCode(accessId, roomCode = selectedRoomCode()) {
  const id = String(accessId || "").trim();
  if (!id) return "";
  const codesMap = loadRoomPersonalInviteCodes(roomCode);
  return String(codesMap[id] || "").trim();
}

function deleteRoomPersonalInviteCode(accessId, roomCode = selectedRoomCode()) {
  const id = String(accessId || "").trim();
  if (!id) return;
  const codesMap = loadRoomPersonalInviteCodes(roomCode);
  if (!(id in codesMap)) return;
  delete codesMap[id];
  saveRoomPersonalInviteCodes(roomCode, codesMap);
}

function clearLiveDashboardState() {
  stopLiveWatch();
  currentSessionId = null;
  currentSessionInfoBase = "";
  clearLiveErrorCounters();
  clearLiveTimeCounters();
  latestDealersSnapshot = [];
  dealerRoundsCache = [];
  resetLiveSessionView({ clearFeed: true, refreshDealersTable: false });
  renderDealerRounds([]);
  setTrainingButtons(false);
  renderResultsEmpty("Тренировка ещё не запущена");
}

function getSelectedDealerId() {
  return String(selectedDealerId || "").trim();
}

function getSelectedParticipantSnapshot() {
  const dealerId = getSelectedDealerId();
  if (!dealerId) return null;
  return roomParticipantsSnapshot.find(
    (participant) => String(participant && participant.dealer_id ? participant.dealer_id : "").trim() === dealerId
  ) || null;
}

function renderSelectedDealerDetail() {
  const panel = el("selected-participant-detail");
  const liveWorkspaceCard = el("live-workspace-card");
  const title = el("selected-participant-title");
  const statusRoot = el("selected-participant-status");
  const hasSelectedDealer = Boolean(getSelectedDealerId());
  const selectedParticipant = getSelectedParticipantSnapshot();

  panel?.classList.toggle("hidden", !hasSelectedDealer);
  liveWorkspaceCard?.classList.toggle("hidden", !hasSelectedDealer);

  if (!panel || !title || !statusRoot) return;

  title.textContent = selectedParticipant && selectedParticipant.display_name
    ? String(selectedParticipant.display_name)
    : "Участник";

  statusRoot.textContent = "";
  if (!selectedParticipant) {
    return;
  }
  statusRoot.textContent = [
    participantStatusLabel(selectedParticipant.online_status, "participant"),
    formatParticipantErrorsSummary(getSelectedDealerId()),
    formatParticipantPhaseSummary(getSelectedDealerId()),
  ].join(" · ");
}

function selectLiveDealer(dealerId) {
  const nextDealerId = String(dealerId || "").trim();
  selectedDealerId = nextDealerId || null;
  renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
  renderSelectedDealerDetail();
  renderLiveTableView();
  renderLiveFeed();
}

async function openSelectedDealerView(dealerId) {
  const nextDealerId = String(dealerId || "").trim();
  if (!nextDealerId) return;
  selectLiveDealer(nextDealerId);
  setDashboardStage("live");
  await loadTrainerLiveSession();
  await fetchResultsOnce();
}

function closeSelectedDealerView() {
  selectedDealerId = null;
  renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
  renderSelectedDealerDetail();
  renderLiveTableView();
  renderLiveFeed();
  setDashboardStage("rooms");
}

function syncSelectedDealerWithParticipants(participants) {
  const currentSelected = getSelectedDealerId();
  if (!currentSelected) return;
  const items = Array.isArray(participants) ? participants : [];
  const exists = items.some((participant) => String(participant && participant.dealer_id ? participant.dealer_id : "").trim() === currentSelected);
  if (!exists) {
    selectedDealerId = null;
  }
}

function clearRoomScopedState(options = {}) {
  const {
    keepCurrentRoom = false,
    preservePinsCacheForCurrentRoom = false,
    preserveActionError = false,
  } = options;

  const previousRoomCode = currentRoomCode;
  if (!keepCurrentRoom && previousRoomCode && !preservePinsCacheForCurrentRoom) {
    deleteRoomPinsCache(previousRoomCode);
  }

  stopRoomModelPolling();
  hideAddParticipantModal();
  roomPinsSnapshot = [];
  clearRoomInviteState();
  clearRoomParticipantsState();
  clearRoomAccessState();
  clearLiveDashboardState();

  if (!keepCurrentRoom) {
    setCurrentRoom("", "");
  }

  renderRoomPins([]);
  setDashboardStage("rooms");
  if (!preserveActionError) {
    showError("action-error", "");
  }
  setRoomScopedVisibility();
}

function applyTableState(snapshot) {
  if (!snapshot || typeof snapshot !== "object") return false;
  const snapshotSessionId = String(snapshot.session_id || "").trim();
  const activeSessionId = String(currentSessionId || "").trim();
  if (snapshotSessionId && activeSessionId && snapshotSessionId !== activeSessionId) {
    return false;
  }

  const dealerId = String(snapshot.dealer_id || "").trim();
  if (!dealerId) return false;

  const seqRaw = snapshot.event_seq;
  if (typeof seqRaw !== "number" || !Number.isInteger(seqRaw)) return false;

  const roundId = String(snapshot.round_id || "").trim();
  const prev = liveTableStore.byDealerId.get(dealerId);
  const prevState = prev && prev.currentState && typeof prev.currentState === "object" ? prev.currentState : {};
  const incomingRoundNumber = Number.isInteger(snapshot.round_number) ? snapshot.round_number : null;
  const prevRoundNumber = Number.isInteger(prevState.round_number) ? prevState.round_number : null;
  if (incomingRoundNumber != null && prevRoundNumber != null && incomingRoundNumber < prevRoundNumber) {
    return false;
  }
  const isNewerRound = incomingRoundNumber != null && prevRoundNumber != null && incomingRoundNumber > prevRoundNumber;
  const lastSeq = isNewerRound ? -1 : prev && Number.isInteger(prev.lastSeq) ? prev.lastSeq : -1;
  if (seqRaw <= lastSeq) return false;

  liveTableStore.byDealerId.set(dealerId, {
    lastSeq: seqRaw,
    sessionId: snapshotSessionId || activeSessionId || (prev ? prev.sessionId : ""),
    currentRoundId: roundId || (prev ? prev.currentRoundId : ""),
    currentState: snapshot,
  });

  renderLiveTableView();
  if (roomParticipantsSnapshot.length > 0) {
    renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
  }
  if (typeof console !== "undefined" && typeof console.debug === "function") {
    console.debug("[live-table] state applied", {
      dealerId,
      eventSeq: seqRaw,
      roundId: roundId || null,
    });
  }
  return true;
}

function resetDealerLiveState(dealerId, options = {}) {
  const id = String(dealerId || "").trim();
  if (!id) return;
  const { clearReady = false } = options;
  liveTableStore.byDealerId.delete(id);
  resetDealerLiveErrorCounter(id);
  resetDealerLiveTimeCounter(id);
  connectedDealerIds.delete(id);
  if (clearReady) {
    readyDealerIds.delete(id);
  }
  renderSessionInfo();
  renderLiveTableView();
  renderDealers(Array.isArray(latestDealersSnapshot) ? latestDealersSnapshot : []);
  if (roomParticipantsSnapshot.length > 0) {
    renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
  }
}

function markDealerRoundStarted(dealerId, data = {}) {
  const id = String(dealerId || "").trim();
  if (!id) return;
  const prev = liveTableStore.byDealerId.get(id);
  const prevState = prev && prev.currentState && typeof prev.currentState === "object" ? prev.currentState : {};
  const nextRoundNumber = Number.isInteger(data.round_number)
    ? data.round_number
    : Number.isInteger(prevState.round_number)
      ? prevState.round_number + 1
      : prevState.round_number;

  liveTableStore.byDealerId.set(id, {
    lastSeq: -1,
    sessionId: String(currentSessionId || "").trim() || String(prev?.sessionId || "").trim(),
    currentRoundId: "",
    currentState: {
      dealer_id: id,
      display_name: String(data.display_name || prevState.display_name || dealerDisplayName(id)),
      session_id: String(currentSessionId || "").trim() || String(prevState.session_id || "").trim(),
      round_number: nextRoundNumber,
      round_id: "",
      phase: "dealing_initial",
      player: { cards: [], score: null },
      banker: { cards: [], score: null },
      last_action: { type: "round_started", value: null, result: "" },
      error: { active: false, error_type: null, message: null },
      lives_remaining: prevState.lives_remaining ?? null,
      is_game_over: false,
    },
  });
  renderLiveTableView();
  if (roomParticipantsSnapshot.length > 0) {
    renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
  }
}

function applyTableStateSync(states) {
  if (!Array.isArray(states)) return 0;
  let applied = 0;
  for (const item of states) {
    if (applyTableState(item)) applied += 1;
  }
  if (applied > 0) {
    renderLiveTableView();
    if (roomParticipantsSnapshot.length > 0) {
      renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
    }
  }
  return applied;
}

const CARD_RANK_NAMES = {
  A: "ace",
  J: "jack",
  Q: "queen",
  K: "king"
};

const CARD_SUIT_NAMES = {
  C: "clubs",
  D: "diamonds",
  H: "hearts",
  S: "spades"
};

function _cardImagePath(code) {
  const normalized = String(code || "").trim().toUpperCase();
  if (normalized.length < 2) return "";

  const suitCode = normalized.slice(-1);
  const rankCode = normalized.slice(0, -1);
  const suitName = CARD_SUIT_NAMES[suitCode];
  const rankName = CARD_RANK_NAMES[rankCode] || rankCode.toLowerCase();

  if (!suitName || !rankName) return "";

  return `assets/cards/${rankName}_${suitName}.png`;
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

    if (!code) {
      out.push("<span class=\"live-card is-empty\">--</span>");
      continue;
    }

    if (!isVisible) {
      out.push(`<img src="assets/cards/card_back.png" class="live-card-img" alt="back" />`);
      continue;
    }

    const imagePath = _cardImagePath(code);
    if (imagePath) {
      out.push(`<img src="${imagePath}" class="live-card-img" alt="${code}" />`);
    } else {
      out.push(`<span class=\"live-card\">${code}</span>`);
    }
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
  const details = lastAction.details && typeof lastAction.details === "object" ? lastAction.details : {};
  return { actionType, actionValue, result, expected, actual, details };
}

function _safeError(state) {
  const error = state && state.error && typeof state.error === "object" ? state.error : {};
  const hasError = error.active === true;
  const errorType = error.error_type != null ? String(error.error_type) : "";
  const errorMsg = error.message != null ? String(error.message) : "";
  const errorDetails = error.details && typeof error.details === "object" ? error.details : {};
  return { hasError, errorType, errorMsg, errorDetails };
}

function _winnerLabel(value) {
  const key = String(value || "").trim();
  return WINNER_LABELS[key] || "";
}

function _phaseLabel(phase) {
  const key = String(phase || "").trim();
  return PHASE_LABELS[key] || "Ожидание";
}

function _errorLabel(errorType, fallbackMessage = "") {
  const key = String(errorType || "").trim();
  if (EVENT_ERROR_LABELS[key]) return EVENT_ERROR_LABELS[key];
  const text = String(fallbackMessage || "").trim();
  return text || "Ошибка";
}

function _formatAmount(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return "0";
  return num.toFixed(2).replace(/\.?0+$/, "").replace(".", ",");
}

function _betTypeLabel(betType) {
  const key = String(betType || "").trim();
  switch (key) {
    case "Player":
      return "Игрока";
    case "Banker":
      return "Банкира";
    case "Tie":
      return "Эгалите";
    case "PairPlayer":
    case "PlayerPair":
      return "пару Игрока";
    case "PairBanker":
    case "BankerPair":
      return "пару Банкира";
    default:
      return "";
  }
}

function _betActionLabel(eventCode, details = {}) {
  const code = String(eventCode || "").trim();
  const amount = details.actual_amount ?? details.expected_amount;

  switch (code) {
    case "take_player_bet":
      return "Забрал ставку на Игрока";
    case "take_banker_bet":
      return "Забрал ставку на Банкира";
    case "take_tie_bet":
      return "Забрал ставку на Эгалите";
    case "take_player_pair_bet":
      return "Забрал ставку на пару Игрока";
    case "take_banker_pair_bet":
      return "Забрал ставку на пару Банкира";
    case "pay_player_bet_correct":
      return `Оплатил ставку на Игрока правильно: ${_formatAmount(amount)}`;
    case "pay_banker_bet_correct":
      return `Оплатил ставку на Банкира правильно: ${_formatAmount(amount)}`;
    case "pay_tie_bet_correct":
      return `Оплатил ставку на Эгалите правильно: ${_formatAmount(amount)}`;
    case "pay_player_pair_bet_correct":
      return `Оплатил ставку на пару Игрока правильно: ${_formatAmount(amount)}`;
    case "pay_banker_pair_bet_correct":
      return `Оплатил ставку на пару Банкира правильно: ${_formatAmount(amount)}`;
    default:
      return "";
  }
}

function _betActionFallback(details = {}) {
  const category = String(details.category || "").trim();
  const reason = String(details.reason || "").trim();
  const betLabel = _betTypeLabel(details.bet_type);
  const actualAmount = details.actual_amount;
  const expectedAmount = details.expected_amount;

  if (category === "collection" && !reason && betLabel) {
    return `Забрал ставку на ${betLabel}`;
  }
  if (category === "payment" && !reason && betLabel) {
    return `Оплатил ставку на ${betLabel} правильно: ${_formatAmount(actualAmount ?? expectedAmount)}`;
  }
  if (category === "collection" && reason === "collect_winning" && betLabel) {
    return { primary: `Ошибка: забрал выигрышную ставку на ${betLabel}`, detail: "" };
  }
  if (category === "collection" && reason === "wrong_order" && betLabel) {
    return { primary: `Ошибка: забрал ставку на ${betLabel} не по порядку`, detail: "" };
  }
  if (category === "collection" && reason === "pay_before_collect") {
    return { primary: "Ошибка: сначала забери все проигрышные ставки", detail: "" };
  }
  if (category === "collection" && reason === "complete_before_collect") {
    return { primary: "Ошибка: не все проигрышные ставки забраны", detail: "" };
  }
  if (category === "payment" && reason === "complete_before_pay") {
    return { primary: "Ошибка: не все выигрышные ставки оплачены", detail: "" };
  }
  if (category === "payment" && reason === "pay_losing" && betLabel) {
    return { primary: `Ошибка: оплатил проигрышную ставку на ${betLabel}`, detail: "" };
  }
  if (category === "payment" && reason === "wrong_order" && betLabel) {
    return { primary: `Ошибка: оплатил ставку на ${betLabel} не по порядку`, detail: "" };
  }
  if (category === "payment" && reason === "wrong_amount" && betLabel) {
    return {
      primary: `Ошибка: оплатил ставку на ${betLabel}: ${_formatAmount(actualAmount)}`,
      detail: `Ожидалось: ${_formatAmount(expectedAmount)}`,
    };
  }
  return null;
}

function _formatBetError(data) {
  const fallback = _betActionFallback(data && typeof data === "object" ? data : {});
  if (fallback && typeof fallback === "object") return fallback;
  const code = String(data && data.event_code ? data.event_code : "").trim();
  if (!code) return null;

  switch (code) {
    case "error_took_winning_player_bet":
      return { primary: "Ошибка: забрал выигрышную ставку на Игрока", detail: "" };
    case "error_took_winning_banker_bet":
      return { primary: "Ошибка: забрал выигрышную ставку на Банкира", detail: "" };
    case "error_took_winning_tie_bet":
      return { primary: "Ошибка: забрал выигрышную ставку на Эгалите", detail: "" };
    case "error_took_winning_player_pair_bet":
      return { primary: "Ошибка: забрал выигрышную ставку на пару Игрока", detail: "" };
    case "error_took_winning_banker_pair_bet":
      return { primary: "Ошибка: забрал выигрышную ставку на пару Банкира", detail: "" };
    case "error_paid_losing_player_bet":
      return { primary: "Ошибка: оплатил проигрышную ставку на Игрока", detail: "" };
    case "error_paid_losing_banker_bet":
      return { primary: "Ошибка: оплатил проигрышную ставку на Банкира", detail: "" };
    case "error_paid_losing_tie_bet":
      return { primary: "Ошибка: оплатил проигрышную ставку на Эгалите", detail: "" };
    case "error_paid_losing_player_pair_bet":
      return { primary: "Ошибка: оплатил проигрышную ставку на пару Игрока", detail: "" };
    case "error_paid_losing_banker_pair_bet":
      return { primary: "Ошибка: оплатил проигрышную ставку на пару Банкира", detail: "" };
    case "error_pay_player_bet_amount":
      return { primary: `Ошибка: оплатил ставку на Игрока: ${_formatAmount(data.actual_amount)}`, detail: `Ожидалось: ${_formatAmount(data.expected_amount)}` };
    case "error_pay_banker_bet_amount":
      return { primary: `Ошибка: оплатил ставку на Банкира: ${_formatAmount(data.actual_amount)}`, detail: `Ожидалось: ${_formatAmount(data.expected_amount)}` };
    case "error_pay_tie_bet_amount":
      return { primary: `Ошибка: оплатил ставку на Эгалите: ${_formatAmount(data.actual_amount)}`, detail: `Ожидалось: ${_formatAmount(data.expected_amount)}` };
    case "error_pay_player_pair_bet_amount":
      return { primary: `Ошибка: оплатил ставку на пару Игрока: ${_formatAmount(data.actual_amount)}`, detail: `Ожидалось: ${_formatAmount(data.expected_amount)}` };
    case "error_pay_banker_pair_bet_amount":
      return { primary: `Ошибка: оплатил ставку на пару Банкира: ${_formatAmount(data.actual_amount)}`, detail: `Ожидалось: ${_formatAmount(data.expected_amount)}` };
    default:
      return null;
  }
}

function _lowercaseFirst(text) {
  const raw = String(text || "").trim();
  if (!raw) return "";
  return raw.charAt(0).toLowerCase() + raw.slice(1);
}

function _errorActionLine(actionType) {
  const label = _actionPerformedLabel(actionType, actionType);
  if (!label) return "Ошибка";
  return `Ошибка: ${_lowercaseFirst(label)}`;
}

function _expectedActionLine(actionType) {
  const label = _actionPerformedLabel(actionType, actionType);
  return label ? `Ожидалось: ${label}` : "";
}

function _formatLiveError(data) {
  const betError = _formatBetError(data && typeof data === "object" ? data : {});
  if (betError) return betError;
  const actualAction = String(data && data.actual_action ? data.actual_action : "").trim();
  const expectedAction = String(data && data.expected_action ? data.expected_action : "").trim();
  if (actualAction || expectedAction) {
    return {
      primary: actualAction ? _errorActionLine(actualAction) : "Ошибка",
      detail: expectedAction ? _expectedActionLine(expectedAction) : "",
    };
  }
  const label = _errorLabel(data && data.error_type, data && data.message ? data.message : "");
  if (!label) return "Ошибка";
  if (label.startsWith("Ошибка")) return label;
  return `Ошибка: ${_lowercaseFirst(label)}`;
}

function _errorStatusLabel(errorType, fallbackMessage = "", expectedAction = "", details = {}) {
  const expected = String(expectedAction || "").trim();
  if (expected) {
    return _expectedActionLine(expected);
  }
  const fullDetails = details && typeof details === "object" ? { ...details } : {};
  if (!fullDetails.error_type) fullDetails.error_type = errorType;
  if (!fullDetails.message) fullDetails.message = fallbackMessage;
  const betError = _formatBetError(fullDetails);
  if (betError) return betError.primary || "Ошибка";
  return _errorLabel(errorType, fallbackMessage);
}

function _actionPerformedLabel(actionType, actionValue, details = {}) {
  const type = String(actionType || "").trim();
  const value = String(actionValue || "").trim();
  const betLabel = _betActionLabel(type, details && typeof details === "object" ? details : {});
  if (betLabel) return betLabel;
  const betFallback = _betActionFallback(details && typeof details === "object" ? details : {});
  if (typeof betFallback === "string" && betFallback) return betFallback;

  if (type === "winner_selection") {
    const winner = _winnerLabel(value);
    return winner ? `Победитель: ${winner}` : "Выбор победителя";
  }
  if (type === "third_card_player_checked") return "Отметил третью карту игроку";
  if (type === "third_card_player_unchecked") return "Снял отметку третьей карты игроку";
  if (type === "third_card_banker_checked") return "Отметил третью карту банкиру";
  if (type === "third_card_banker_unchecked") return "Снял отметку третьей карты банкиру";
  if (type === "third_card_decision_player") return "Карта игроку";
  if (type === "third_card_decision_banker") return "Карта банкиру";
  if (type === "third_card_decision_each") return "Карта каждому";
  if (type === "winner_marker_player_selected") return "Выбрал маркер Игрока";
  if (type === "winner_marker_player_unselected") return "Отменил маркер Игрока";
  if (type === "winner_marker_banker_selected") return "Выбрал маркер Банкира";
  if (type === "winner_marker_banker_unselected") return "Отменил маркер Банкира";
  if (type === "winner_marker_tie_selected") return "Выбрал маркер Эгалите";
  if (type === "winner_marker_tie_unselected") return "Отменил маркер Эгалите";
  if (type === "player_third") return "Карта игроку";
  if (type === "banker_third" || type === "banker_third_after_player") return "Карта банкиру";
  if (type === "both_third") return "Карта каждому";
  if (type === "no_third") return "";
  return "Действие дилера";
}

function _lastActionLabel(lastAction) {
  const actionType = String(lastAction.type || "").trim();
  const actionValue = lastAction.value;
  const expected = String(lastAction.expected || "").trim();
  const actual = String(lastAction.actual || "").trim();
  const details = lastAction.details && typeof lastAction.details === "object" ? lastAction.details : {};

  switch (actionType) {
    case "round_started":
      return "Новая раздача";
    case "cards_dealt":
      return "Карты открыты";
    case "action_correct": {
      const winner = _winnerLabel(actionValue);
      if (winner) return `Победитель: ${winner}`;
      return _actionPerformedLabel(String(actionValue || ""), String(actionValue || ""), details);
    }
    case "action_performed":
      return _actionPerformedLabel(String(actionValue || ""), String(actionValue || ""), details);
    case "error_occurred": {
      const line = _formatLiveError(details);
      if (typeof line === "object") return line.primary || "Ошибка";
      return line || "Ошибка";
    }
    case "action_error":
      if (actual) return _actionPerformedLabel(actual, actual) || "Ошибка";
      if (expected) return _expectedActionLine(expected);
      return _errorLabel(actionValue, "");
    case "payment_correct":
    case "payout_correct":
      return _actionPerformedLabel(String(details.event_code || ""), String(details.event_code || ""), details) || "Оплата сыгравшей ставки";
    case "payment_error":
    case "payout_wrong":
      return (_formatBetError(details) || {}).primary || "Ошибка оплаты ставки";
    case "collection_correct":
      return _actionPerformedLabel(String(details.event_code || ""), String(details.event_code || ""), details) || "Сбор проигрышной ставки";
    case "collection_error":
      return (_formatBetError(details) || {}).primary || "Ошибка сбора ставки";
    case "round_completed":
      return "Конец раздачи";
    default:
      return "Событие";
  }
}

function _getLastActionText(lastAction) {
  return _lastActionLabel(lastAction || {});
}

function _getLastActionStatus(lastAction, hasError) {
  const result = lastAction.result != null ? String(lastAction.result) : "";
  let isError = false;
  
  // Приоритет: используем result если доступен
  if (result === "wrong" || result === "error") {
    isError = true;
  } else if (result === "correct") {
    isError = false;
  } else {
    // fallback на error.active
    isError = hasError;
  }
  
  return isError 
    ? '<span class="live-last-action-badge live-last-action-error">Ошибка</span>'
    : '<span class="live-last-action-badge live-last-action-success">OK</span>';
}

function renderLiveTableView() {
  const root = el("live-table-view");
  if (!root) return;
  root.innerHTML = "";
  const selectedId = getSelectedDealerId();
  if (!selectedId) {
    return;
  }

  const entry = liveTableStore.byDealerId.get(selectedId);
  if (!entry || !entry.currentState || typeof entry.currentState !== "object") {
    root.textContent = "Участник выбран. Live View появится, когда он начнёт online-тренировку.";
    return;
  }

  const rows = [[selectedId, entry]];

  for (const [dealerId, entry] of rows) {
    const state = entry && entry.currentState && typeof entry.currentState === "object" ? entry.currentState : {};
    const dealerName = state.display_name ? String(state.display_name) : dealerDisplayName(dealerId);
    const roundNumber = state.round_number != null ? String(state.round_number) : "—";
    const phase = _safePhase(state.phase);
    const phaseLabel = _phaseLabel(phase);
    const player = state.player && typeof state.player === "object" ? state.player : {};
    const banker = state.banker && typeof state.banker === "object" ? state.banker : {};
    const playerScore = _safeScore(player.score);
    const bankerScore = _safeScore(banker.score);
    const { actionType, actionValue, result, expected, actual, details } = _safeAction(state);
    const { hasError, errorType, errorMsg, errorDetails } = _safeError(state);
    const lives = state.lives_remaining != null ? String(state.lives_remaining) : "";
    const gameOver = state.is_game_over === true;
    const actionLabel = _getLastActionText({ type: actionType, value: actionValue, result, expected, actual, details });
    const errorLabel = hasError
      ? ((_formatBetError(errorDetails) || {}).primary || _errorStatusLabel(errorType, errorMsg, expected, errorDetails))
      : "Без ошибок";

    const card = document.createElement("article");
    card.className = "live-dealer-card" + (hasError ? " live-dealer-card-error" : "");
    card.innerHTML = `
      <div class="live-dealer-header">
        <div class="live-title">
          <strong>${dealerName}</strong>
        </div>
        <span class="live-phase ${_phaseClass(phase)}">${phaseLabel}</span>
      </div>
      
      <div class="live-meta muted small">
        <span>Раунд: ${roundNumber}</span>
        ${lives ? `<span>Жизни: ${lives}</span>` : ""}
        ${gameOver ? `<span class="live-game-over">Раунд завершён</span>` : ""}
      </div>
      
      <div class="live-table-area">
        <div class="live-zone live-zone-banker">
          <div class="live-zone-header">Банкир</div>
          <div class="live-cards">${_renderCardCodesFromSlots(banker.cards.length >= 3 ? [banker.cards[2], banker.cards[0], banker.cards[1]] : banker.cards)}</div>
          <div class="live-score">${bankerScore}</div>
        </div>
        
        <div class="live-zone live-zone-player">
          <div class="live-zone-header">Игрок</div>
          <div class="live-cards">${_renderCardCodesFromSlots(player.cards.length >= 3 ? [player.cards[0], player.cards[1], player.cards[2]] : player.cards)}</div>
          <div class="live-score">${playerScore}</div>
        </div>
      </div>
        
      <div class="live-last-action-section">
        <div class="live-last-action-title">Последнее событие</div>
        <div class="live-last-action-content">
          ${actionLabel}
        </div>
        <div class="live-last-action-status">
          ${_getLastActionStatus({type: actionType, value: actionValue, result: result}, hasError)}
        </div>
      </div>
        
      <div class="live-error-section">
        <div class="live-error-title">Статус</div>
        <div class="live-error-content">
          ${
            hasError
              ? `<span class="live-error-badge">${errorLabel}</span>`
              : `<span class="live-ok-badge">Без ошибок</span>`
          }
        </div>
      </div>
    `;
    root.appendChild(card);
  }
}

function clearLiveFeed() {
  liveFeedEntries = [];
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
  if (t === "error_occurred") {
    return _formatLiveError(data);
  }
  if (t === "action_performed") {
    return _actionPerformedLabel(data.action_type, data.value, data);
  }
  if (t === "round_started") {
    return "Новая раздача";
  }
  if (t === "round_completed") {
    return "Конец раздачи";
  }
  return "Событие";
}

function _formatLiveFeedTimestamp(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  return date.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

function renderLiveFeed() {
  const ul = el("live-feed-list");
  const empty = el("live-feed-empty");
  if (!ul) return;
  ul.innerHTML = "";

  const selectedId = getSelectedDealerId();
  if (!selectedId) {
    if (empty) empty.hidden = true;
    return;
  }

  const errOnly = el("live-feed-errors-only")?.checked;
  const visibleEntries = liveFeedEntries.filter((entry) => {
    if (!entry || entry.dealerId !== selectedId) return false;
    if (errOnly && entry.msgType !== "error_occurred") return false;
    return true;
  });

  if (visibleEntries.length === 0) {
    if (empty) {
      empty.textContent = "Пока нет событий — дождитесь действий участника в игре.";
      empty.hidden = false;
    }
    return;
  }

  for (const entry of visibleEntries) {
    const li = document.createElement("li");
    li.dataset.msgType = entry.msgType;
    li.dataset.dealerId = entry.dealerId;
    const ts = document.createElement("span");
    ts.className = "ts";
    ts.textContent = _formatLiveFeedTimestamp(entry.timestamp);

    const tag = document.createElement("span");
    tag.className = "tag " + (entry.msgType === "error_occurred" ? "tag-err" : entry.msgType === "action_performed" ? "tag-ok" : "tag-info");
    tag.textContent =
      entry.msgType === "error_occurred" ? "Ошибка" : entry.msgType === "action_performed" ? "Действие" : entry.msgType === "round_started" ? "Старт" : "Конец";

    const text = document.createElement("span");
    const line = formatLiveEventLine(entry.msgType, entry.data && typeof entry.data === "object" ? entry.data : {});
    if (!line) {
      continue;
    }
    if (typeof line === "object") {
      const primary = document.createElement("span");
      primary.textContent = line.primary || "";
      text.appendChild(primary);
      if (line.detail) {
        primary.style.display = "block";
        const detail = document.createElement("span");
        detail.textContent = line.detail;
        detail.className = "muted small";
        detail.style.display = "block";
        text.appendChild(detail);
      }
    } else {
      text.textContent = line;
    }

    li.appendChild(ts);
    li.appendChild(tag);
    li.appendChild(text);
    ul.appendChild(li);
  }

  if (empty) empty.hidden = true;
}

function pushLiveFeedEntry(msgType, data) {
  const safeData = data && typeof data === "object" ? data : {};
  const dealerId = String(safeData.dealer_id || "").trim();
  if (!dealerId) return;

  liveFeedEntries.unshift({
    msgType,
    dealerId,
    timestamp: Date.now(),
    data: safeData,
  });
  if (liveFeedEntries.length > LIVE_FEED_MAX) {
    liveFeedEntries.length = LIVE_FEED_MAX;
  }
  renderLiveFeed();
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
  renderLiveFeed();
}

function setTrainingButtons(active) {
  const toggle = el("btn-toggle-training");
  if (toggle) toggle.textContent = active ? "Завершить тренировку" : "Начать тренировку";
}

function renderSessionInfo() {
  const parts = [];
  if (currentSessionId) {
    parts.push(`дилеров в сети: ${connectedDealerIds.size}`);
  }
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

function openAddParticipantModal() {
  roomInviteLimitInputDirty = false;
  syncRoomInviteLimitInputFromSnapshot(true);
  showError("room-invite-error", "");
  el("add-participant-modal")?.classList.remove("hidden");
}

function hideAddParticipantModal() {
  el("add-participant-modal")?.classList.add("hidden");
}

async function closeAddParticipantModal() {
  roomInviteLimitInputDirty = false;
  syncRoomInviteLimitInputFromSnapshot(true);
  hideAddParticipantModal();
  return true;
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
  clearRoomScopedState({ preserveActionError: true });
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

function stopRoomModelPolling() {
  if (roomPollTimer) {
    clearInterval(roomPollTimer);
    roomPollTimer = null;
  }
  roomPollInFlight = false;
  roomPollGeneration += 1;
}

function isRoomPollStale(roomCode, generation) {
  return (
    generation !== roomPollGeneration
    || String(selectedRoomCode() || "") !== String(roomCode || "")
    || !getToken()
  );
}

async function pollRoomModelOnce() {
  if (roomPollInFlight) return;
  const roomCode = String(selectedRoomCode() || "");
  if (!roomCode || !getToken()) return;

  const generation = roomPollGeneration;
  roomPollInFlight = true;
  try {
    await loadRoomInvite(roomCode, { background: true, generation });
    if (isRoomPollStale(roomCode, generation)) return;
    await loadRoomParticipants(roomCode, { background: true, generation });
  } finally {
    if (generation === roomPollGeneration) {
      roomPollInFlight = false;
    }
  }
}

function startRoomModelPolling() {
  stopRoomModelPolling();
  if (!getToken() || !selectedRoomCode()) return;
  void pollRoomModelOnce();
  roomPollTimer = setInterval(() => {
    void pollRoomModelOnce();
  }, ROOM_MODEL_POLL_MS);
}

function closeSessionWs(targetWs = sessionWs) {
  if (!targetWs) return;
  const isCurrentWs = targetWs === sessionWs;
  try {
    targetWs.onopen = null;
    targetWs.onmessage = null;
    targetWs.onerror = null;
    targetWs.onclose = null;
    targetWs.close();
  } catch (_) {
    /* ignore */
  }
  if (isCurrentWs) {
    sessionWs = null;
    sessionWsSessionId = "";
    sessionWsGeneration += 1;
  }
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
  const targetSessionId = String(currentSessionId || "").trim();
  if (
    sessionWs &&
    sessionWsSessionId === targetSessionId &&
    typeof WebSocket !== "undefined" &&
    (sessionWs.readyState === WebSocket.CONNECTING || sessionWs.readyState === WebSocket.OPEN)
  ) {
    return;
  }

  stopPoll();
  if (sessionWs) {
    closeSessionWs(sessionWs);
  }

  const url = sessionWsUrl(targetSessionId);
  if (!url || typeof WebSocket === "undefined") {
    startPollResults();
    return;
  }

  const generation = sessionWsGeneration + 1;
  sessionWsGeneration = generation;
  let nextWs = null;
  try {
    nextWs = new WebSocket(url);
  } catch (_) {
    sessionWs = null;
    sessionWsSessionId = "";
    startPollResults();
    return;
  }

  sessionWs = nextWs;
  sessionWsSessionId = targetSessionId;

  nextWs.onopen = () => {
    if (sessionWs !== nextWs || sessionWsGeneration !== generation) return;
    fetchResultsOnce();
  };
  nextWs.onmessage = (ev) => {
    if (sessionWs !== nextWs || sessionWsGeneration !== generation) return;
    let msg = null;
    try {
      msg = JSON.parse(ev.data);
    } catch {
      return;
    }
    const t = msg.type || "";
    const data = msg.data && typeof msg.data === "object" ? msg.data : {};
    console.debug("[WS]", t, data);
    if (t === "dealer_joined" || t === "dealer_left") {
      if (typeof data.online_count === "number") {
        onlineDealers = data.online_count;
      }
      if (data.dealer_id) {
        const did = String(data.dealer_id);
        if (t === "dealer_joined") {
          resetDealerLiveState(did, { clearReady: true });
          connectedDealerIds.add(did);
          startDealerLiveTimeCounter(did, getBackendParticipantLiveSeconds(did) || 0);
        } else {
          resetDealerLiveState(did, { clearReady: true });
        }
      }
      renderSessionInfo();
    }
    if (t === "dealer_ready" && data.dealer_id) {
      const did = String(data.dealer_id);
      readyDealerIds.add(did);
      connectedDealerIds.add(did);
      ensureDealerLiveTimeCounter(did);
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
      if (t === "round_started" && data.dealer_id) {
        markDealerRoundStarted(data.dealer_id, data);
      }
      if (data.dealer_id) {
        ensureDealerLiveTimeCounter(data.dealer_id);
      }
      pushLiveFeedEntry(t, data);
      if (t === "error_occurred") {
        incrementDealerLiveErrorCounter(data.dealer_id);
        pulseDealerRow(data.dealer_id);
        if (roomParticipantsSnapshot.length > 0) {
          renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
        }
        renderSelectedDealerDetail();
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
  nextWs.onerror = () => {
    if (sessionWs !== nextWs || sessionWsGeneration !== generation) return;
    try {
      nextWs.close();
    } catch (_) {
      /* ignore */
    }
  };
  nextWs.onclose = () => {
    const isCurrentWs = sessionWs === nextWs && sessionWsGeneration === generation;
    if (isCurrentWs) {
      sessionWs = null;
      sessionWsSessionId = "";
    }
    if (!isCurrentWs) return;
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
  const isTournaments = stage === "tournaments";
  el("room-stage").classList.toggle("hidden", isLive || isTournaments);
  el("live-stage").classList.toggle("hidden", !isLive);
  el("tournaments-stage")?.classList.toggle("hidden", !isTournaments);
  const roomsTab = el("btn-open-rooms-section");
  const tournamentsTab = el("btn-open-tournaments-section");
  const roomsSelected = !isTournaments;
  if (roomsTab) {
    roomsTab.classList.toggle("active", roomsSelected);
    roomsTab.setAttribute("aria-selected", roomsSelected ? "true" : "false");
  }
  if (tournamentsTab) {
    tournamentsTab.classList.toggle("active", isTournaments);
    tournamentsTab.setAttribute("aria-selected", isTournaments ? "true" : "false");
  }
  renderSelectedDealerDetail();
}

function setDashboardUserLabel(text) {
  const label = String(text || "");
  const roomUser = el("user-label");
  if (roomUser) roomUser.textContent = label;
  const tournamentsUser = el("tournaments-user-label");
  if (tournamentsUser) tournamentsUser.textContent = label;
}

function clearTournamentState() {
  tournamentsSnapshot = [];
  tournamentsLoaded = false;
  showError("tournaments-error", "");
  renderTournaments([]);
}

function formatTournamentStatus(status) {
  const normalized = String(status || "").trim().toLowerCase();
  if (normalized === "active") return "Активен";
  if (normalized === "closed") return "Закрыт";
  return "—";
}

function formatTournamentRules(item) {
  const maxRounds = Number(item && item.max_rounds);
  const attemptDurationSeconds = Number(item && item.attempt_duration_seconds);
  const roundsLabel = Number.isFinite(maxRounds) && maxRounds > 0 ? `${maxRounds} раздач` : "—";
  const minutes = Number.isFinite(attemptDurationSeconds) && attemptDurationSeconds > 0
    ? Math.floor(attemptDurationSeconds / 60)
    : 0;
  const durationLabel = minutes > 0 ? `${minutes} мин` : "—";
  return `${roundsLabel} / ${durationLabel}`;
}

async function copyTournamentCode(code, button) {
  const value = String(code || "").trim();
  if (!value) return false;
  showError("tournaments-error", "");
  try {
    if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
      await navigator.clipboard.writeText(value);
    } else {
      const textarea = document.createElement("textarea");
      textarea.value = value;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.left = "-9999px";
      document.body.appendChild(textarea);
      textarea.select();
      const copied = document.execCommand("copy");
      document.body.removeChild(textarea);
      if (!copied) throw new Error("copy_failed");
    }
    if (button) {
      const prev = button.textContent;
      button.textContent = "Скопировано";
      setTimeout(() => {
        button.textContent = prev || "Скопировать код";
      }, 1400);
    }
    return true;
  } catch {
    showError("tournaments-error", "Не удалось скопировать код турнира.");
    return false;
  }
}

async function closeTournament(tournamentId) {
  const id = String(tournamentId || "").trim();
  if (!id) return;
  const confirmed = window.confirm("Закрыть турнир? Новые попытки больше не будут приниматься.");
  if (!confirmed) return;

  showError("tournaments-error", "");
  const { ok, status, data } = await api("POST", `/api/tournaments/${encodeURIComponent(id)}/close`, {});
  if (!ok) {
    showError(
      "tournaments-error",
      (data && formatApiError(data)) || `Не удалось закрыть турнир (${status})`,
    );
    return;
  }
  await refreshTournaments();
  setDashboardStage("tournaments");
}

function renderTournaments(items) {
  const listCard = el("tournaments-list-card");
  const emptyState = el("tournaments-empty-state");
  const table = el("tournaments-table");
  const tbody = table ? table.querySelector("tbody") : null;
  if (!tbody || !listCard || !emptyState) return;
  tbody.innerHTML = "";

  if (!Array.isArray(items) || items.length === 0) {
    listCard.classList.add("hidden");
    emptyState.classList.remove("hidden");
    return;
  }

  emptyState.classList.add("hidden");
  listCard.classList.remove("hidden");

  for (const item of items) {
    const tr = document.createElement("tr");

    const cTitle = document.createElement("td");
    cTitle.textContent = item && item.title ? String(item.title) : "—";

    const cCode = document.createElement("td");
    cCode.className = "mono";
    cCode.textContent = item && item.code ? String(item.code) : "—";

    const cStatus = document.createElement("td");
    cStatus.textContent = formatTournamentStatus(item && item.status);

    const cRules = document.createElement("td");
    cRules.textContent = formatTournamentRules(item);

    const cActions = document.createElement("td");
    const copyBtn = document.createElement("button");
    copyBtn.type = "button";
    copyBtn.className = "ghost table-action-button";
    copyBtn.textContent = "Скопировать код";
    copyBtn.addEventListener("click", () => {
      void copyTournamentCode(item && item.code, copyBtn);
    });
    cActions.appendChild(copyBtn);

    if (String(item && item.status ? item.status : "").trim().toLowerCase() === "active") {
      const closeBtn = document.createElement("button");
      closeBtn.type = "button";
      closeBtn.className = "danger table-action-button";
      closeBtn.textContent = "Закрыть";
      closeBtn.addEventListener("click", () => {
        void closeTournament(item && item.id);
      });
      cActions.appendChild(closeBtn);
    }

    tr.appendChild(cTitle);
    tr.appendChild(cCode);
    tr.appendChild(cStatus);
    tr.appendChild(cRules);
    tr.appendChild(cActions);
    tbody.appendChild(tr);
  }
}

async function refreshTournaments() {
  const { ok, status, data } = await api("GET", "/api/tournaments");
  if (!ok) {
    tournamentsLoaded = false;
    tournamentsSnapshot = [];
    renderTournaments([]);
    showError("tournaments-error", (data && formatApiError(data)) || `Не удалось загрузить турниры (${status})`);
    return;
  }
  tournamentsLoaded = true;
  tournamentsSnapshot = Array.isArray(data) ? data : [];
  showError("tournaments-error", "");
  renderTournaments(tournamentsSnapshot);
}

function openCreateTournamentModal() {
  showError("create-tournament-error", "");
  el("create-tournament-modal")?.classList.remove("hidden");
  el("new-tournament-title")?.focus();
}

function closeCreateTournamentModal(force = false) {
  if (createTournamentInFlight && !force) return;
  el("create-tournament-modal")?.classList.add("hidden");
  showError("create-tournament-error", "");
}

async function createTournament() {
  if (createTournamentInFlight) return;
  showError("create-tournament-error", "");
  const titleInput = el("new-tournament-title");
  const rawTitle = titleInput ? String(titleInput.value || "") : "";
  const title = rawTitle.trim();
  const body = title ? { title } : {};

  createTournamentInFlight = true;
  const button = el("btn-create-tournament");
  const prevText = button ? button.textContent : "";
  if (button) {
    button.disabled = true;
    button.textContent = "Создание...";
  }

  try {
    const { ok, status, data } = await api("POST", "/api/tournaments", body);
    if (!ok) {
      showError(
        "create-tournament-error",
        formatApiError(data) || `Не удалось создать турнир (${status})`,
      );
      return;
    }

    if (titleInput) titleInput.value = "";
    closeCreateTournamentModal(true);
    tournamentsLoaded = false;
    await refreshTournaments();
    setDashboardStage("tournaments");
  } finally {
    createTournamentInFlight = false;
    if (button) {
      button.disabled = false;
      button.textContent = prevText || "Создать";
    }
  }
}

async function openDashboardSection(section) {
  if (section === "tournaments") {
    setDashboardStage("tournaments");
    if (!tournamentsLoaded) {
      await refreshTournaments();
    }
    return;
  }
  setDashboardStage("rooms");
}

function formatDuration(seconds) {
  const s = Number(seconds || 0);
  if (!Number.isFinite(s) || s < 0) return "0:00";
  const totalSeconds = Math.floor(s);
  const hh = Math.floor(totalSeconds / 3600);
  const mm = Math.floor((totalSeconds % 3600) / 60);
  const ss = totalSeconds % 60;
  if (hh > 0) {
    return `${hh}:${String(mm).padStart(2, "0")}:${String(ss).padStart(2, "0")}`;
  }
  return `${mm}:${String(ss).padStart(2, "0")}`;
}

function setCurrentRoom(code, roomName = "") {
  const nextRoomCode = String(code || "");
  if (nextRoomCode !== currentRoomCode) {
    generatedRoomAccesses = [];
    renderGeneratedRoomAccesses();
    clearRoomInviteState();
    clearRoomParticipantsState();
  }
  currentRoomCode = nextRoomCode;
  const label = el("current-room-label");
  if (label) {
    label.textContent = currentRoomCode ? `Комната: ${roomName || currentRoomCode}` : "Комната: —";
  }
  setRoomScopedVisibility();
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
  if (d && typeof d === "object") {
    if ("message" in d) return String(d.message);
    if ("code" in d) return String(d.code);
    try {
      return JSON.stringify(d);
    } catch {
      return "Ошибка сервера";
    }
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
    clearRoomScopedState({ preserveActionError: true });
    renderRoomsList([]);
    showError("action-error", (data && data.detail) || `Ошибка списка комнат (${status})`);
    return;
  }
  showError("action-error", "");
  const rooms = Array.isArray(data) ? data.filter((r) => String(r.status || "").toLowerCase() !== "closed") : [];
  if (rooms.length === 0) {
    clearRoomScopedState({ preserveActionError: true });
    renderRoomsList([]);
    return;
  }
  const previousRoomCode = currentRoomCode;
  const nextRoomCode =
    !currentRoomCode || !rooms.some((r) => r.room_code === currentRoomCode)
      ? String(rooms[0].room_code || "")
      : currentRoomCode;
  if (nextRoomCode !== previousRoomCode) {
    clearLiveDashboardState();
  }
  const selected = rooms.find((r) => r.room_code === nextRoomCode) || rooms[0];
  stopRoomModelPolling();
  setCurrentRoom(selected.room_code, `${selected.name} (${selected.room_code})`);
  renderRoomsList(rooms);
  await loadRoomInvite();
  await loadRoomParticipants();
  await fetchRoomPinsOnce();
  await loadRoomAccesses();
  await fetchRoomDealersOnce();
  startRoomModelPolling();
}

function selectedRoomCode() {
  return currentRoomCode || "";
}

async function copyRoomInviteCode(code, button) {
  if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
    await navigator.clipboard.writeText(code);
    if (button) {
      const prev = button.textContent;
      button.textContent = "Скопировано";
      setTimeout(() => {
        button.textContent = prev || "Скопировать";
      }, 1400);
    }
    return true;
  }
  return false;
}

async function loadRoomInvite(roomCode = selectedRoomCode(), options = {}) {
  const code = String(roomCode || "");
  const background = Boolean(options.background);
  const generation = options.generation;
  if (!code) {
    if (!background) {
      clearRoomInviteState();
    }
    return;
  }

  if (!background) {
    showError("room-invite-error", "");
  }
  const { ok, status, data } = await api("GET", `/api/rooms/${encodeURIComponent(code)}/invite`);
  if (background && isRoomPollStale(code, generation)) {
    return;
  }
  if (!ok) {
    if (!background) {
      roomInviteSnapshot = null;
      renderRoomInvite(null);
      showError("room-invite-error", (data && formatApiError(data)) || `Не удалось загрузить приглашение (${status})`);
    }
    return;
  }

  roomInviteSnapshot = data || null;
  renderRoomInvite(roomInviteSnapshot);
}

async function saveRoomInviteLimit(limitValue) {
  const code = selectedRoomCode();
  if (!code) return false;

  showError("room-invite-error", "");
  showRoomInviteMessage("");
  renderRoomInvite(roomInviteSnapshot, { manualCode: "", manualNote: "" });

  const { ok, status, data } = await api(
    "PATCH",
    `/api/rooms/${encodeURIComponent(code)}/invite-limit`,
    { participant_limit: limitValue },
  );
  if (!ok) {
    showError("room-invite-error", (data && formatApiError(data)) || `Не удалось сохранить лимит (${status})`);
    return false;
  }

  roomInviteSnapshot = data || null;
  roomInviteLimitInputDirty = false;
  renderRoomInvite(roomInviteSnapshot);
  showRoomInviteMessage("Лимит сохранён");
  return true;
}

async function saveRoomInviteLimitFromInput() {
  const input = el("room-invite-limit-input");
  if (!input) return false;
  const normalized = normalizeRoomInviteLimitInput(input.value);
  if (!normalized.ok) {
    showError("room-invite-error", normalized.message || "Некорректный лимит участников");
    return false;
  }
  const normalizedValue = normalized.value;
  const savedValue = getCurrentSavedRoomInviteLimit();
  const nextKey = normalizedValue == null ? "null" : String(normalizedValue);
  const savedKey = savedValue == null ? "null" : String(savedValue);
  if (nextKey === savedKey) {
    showError("room-invite-error", "");
    showRoomInviteMessage("");
    roomInviteLimitInputDirty = false;
    syncRoomInviteLimitInputFromSnapshot(true);
    return false;
  }
  if (roomInviteLimitSaveInFlight) {
    return await roomInviteLimitSaveInFlight;
  }
  roomInviteLimitSaveInFlight = saveRoomInviteLimit(normalizedValue);
  try {
    return await roomInviteLimitSaveInFlight;
  } finally {
    roomInviteLimitSaveInFlight = null;
  }
}

async function createRoomInvite() {
  const code = selectedRoomCode();
  if (!code) return;

  showError("room-invite-error", "");
  showRoomInviteMessage("");
  renderRoomInvite(roomInviteSnapshot, { manualCode: "", manualNote: "" });

  const button = el("btn-create-room-invite");
  if (button) button.disabled = true;
  try {
    const { ok, status, data } = await api("POST", `/api/rooms/${encodeURIComponent(code)}/invite`, {});
    if (!ok || !data || !data.invite_code) {
      showError("room-invite-error", (data && formatApiError(data)) || `Не удалось создать приглашение (${status})`);
      return;
    }

    const inviteId = String(data.id || "").trim();
    const inviteCode = String(data.invite_code || "");
    if (inviteId && inviteCode) {
      storeRoomInviteCode(inviteId, inviteCode, code);
    }
    roomInviteSnapshot = data;
    let copied = false;
    try {
      copied = await copyRoomInviteCode(inviteCode, button);
    } catch {
      copied = false;
    }

    if (copied) {
      renderRoomInvite(roomInviteSnapshot);
      showRoomInviteMessage("Приглашение создано и скопировано");
    } else {
      renderRoomInvite(roomInviteSnapshot, {
        manualCode: String(data.invite_code || ""),
        manualNote: "Буфер обмена недоступен. Скопируйте код вручную сейчас.",
      });
      showRoomInviteMessage("Приглашение создано");
    }
  } finally {
    if (button) button.disabled = false;
  }
}

function participantStatusLabel(status, kind = "participant") {
  const value = String(status || "").toLowerCase();
  if (kind === "pending-invite") return "Ожидает";
  if (value === "online") return "Онлайн";
  if (value === "offline") return "Оффлайн";
  if (value === "unknown") return "Неизвестно";
  return status || "—";
}

function participantStatusClass(status, kind = "participant") {
  const value = String(status || "").toLowerCase();
  if (kind === "pending-invite") return "status-created";
  if (value === "online") return "status-activated";
  if (value === "offline") return "status-revoked";
  return "status-unknown";
}

function getParticipantResultsSummary(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return null;
  return latestDealersSnapshot.find((dealer) => String(dealer && dealer.dealer_id ? dealer.dealer_id : "").trim() === id) || null;
}

function clearLiveErrorCounters() {
  liveErrorsByDealerId.clear();
}

function resetDealerLiveErrorCounter(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return;
  liveErrorsByDealerId.delete(id);
}

function incrementDealerLiveErrorCounter(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return 0;
  const nextCount = Number(liveErrorsByDealerId.get(id) || 0) + 1;
  liveErrorsByDealerId.set(id, nextCount);
  return nextCount;
}

function stopLiveTimerInterval() {
  if (!liveTimerInterval) return;
  clearInterval(liveTimerInterval);
  liveTimerInterval = null;
}

function clearLiveTimeCounters() {
  liveTimeByDealerId.clear();
  stopLiveTimerInterval();
}

function resetDealerLiveTimeCounter(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return;
  liveTimeByDealerId.delete(id);
  if (liveTimeByDealerId.size === 0) {
    stopLiveTimerInterval();
  }
}

function ensureLiveTimerInterval() {
  if (liveTimerInterval || liveTimeByDealerId.size === 0) return;
  liveTimerInterval = setInterval(() => {
    if (liveTimeByDealerId.size === 0) {
      stopLiveTimerInterval();
      return;
    }
    if (roomParticipantsSnapshot.length > 0) {
      renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
    }
    renderSelectedDealerDetail();
    if (Array.isArray(latestDealersSnapshot) && latestDealersSnapshot.length > 0) {
      renderDealers(latestDealersSnapshot);
    }
  }, 1000);
}

function startDealerLiveTimeCounter(dealerId, backendSeconds = 0) {
  const id = String(dealerId || "").trim();
  if (!id) return null;
  const safeBaseSeconds = Math.max(0, Math.floor(Number(backendSeconds || 0)));
  const currentRuntimeSeconds = getRuntimeParticipantLiveSeconds(id);
  if (currentRuntimeSeconds != null && currentRuntimeSeconds >= safeBaseSeconds) {
    ensureLiveTimerInterval();
    return liveTimeByDealerId.get(id) || null;
  }
  const nextState = {
    startedAtMs: Date.now(),
    baseSeconds: safeBaseSeconds,
  };
  liveTimeByDealerId.set(id, nextState);
  ensureLiveTimerInterval();
  return nextState;
}

function ensureDealerLiveTimeCounter(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return null;
  if (liveTimeByDealerId.has(id)) {
    ensureLiveTimerInterval();
    return liveTimeByDealerId.get(id) || null;
  }
  return startDealerLiveTimeCounter(id, getBackendParticipantLiveSeconds(id) || 0);
}

function getBackendParticipantErrorsCount(dealerId) {
  const summary = getParticipantResultsSummary(dealerId);
  if (!summary || typeof summary.errors_total !== "number") return 0;
  return Number(summary.errors_total || 0);
}

function isDealerLiveTimerEligible(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return false;
  if (connectedDealerIds.has(id) || readyDealerIds.has(id)) {
    return true;
  }
  const participant = roomParticipantsSnapshot.find(
    (item) => String(item && item.dealer_id ? item.dealer_id : "").trim() === id
  );
  return String(participant && participant.online_status ? participant.online_status : "").trim() === "online";
}

function getBackendParticipantLiveSeconds(dealerId) {
  const summary = getParticipantResultsSummary(dealerId);
  if (!summary || typeof summary.live_seconds !== "number") return null;
  return Number(summary.live_seconds || 0);
}

function getRuntimeParticipantLiveSeconds(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return null;
  const state = liveTimeByDealerId.get(id);
  if (!state || typeof state !== "object") return null;
  const startedAtMs = Number(state.startedAtMs || 0);
  const baseSeconds = Math.max(0, Math.floor(Number(state.baseSeconds || 0)));
  if (!Number.isFinite(startedAtMs) || startedAtMs <= 0) return baseSeconds;
  const elapsedSeconds = Math.max(0, Math.floor((Date.now() - startedAtMs) / 1000));
  return baseSeconds + elapsedSeconds;
}

function getParticipantDisplayLiveSeconds(dealerId) {
  const backendSeconds = getBackendParticipantLiveSeconds(dealerId);
  const runtimeSeconds = getRuntimeParticipantLiveSeconds(dealerId);
  if (runtimeSeconds != null && backendSeconds != null) {
    return Math.max(runtimeSeconds, backendSeconds);
  }
  if (runtimeSeconds != null) return runtimeSeconds;
  if (backendSeconds != null) return backendSeconds;
  return null;
}

function syncDealerLiveTimeFromBackend(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return;
  if (!isDealerLiveTimerEligible(id)) return;
  const backendSeconds = getBackendParticipantLiveSeconds(id);
  if (backendSeconds == null) return;
  const runtimeSeconds = getRuntimeParticipantLiveSeconds(id);
  if (runtimeSeconds == null || backendSeconds > runtimeSeconds) {
    startDealerLiveTimeCounter(id, backendSeconds);
  }
}

function getLiveParticipantErrorsCount(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return 0;
  return Number(liveErrorsByDealerId.get(id) || 0);
}

function getParticipantDisplayErrorsCount(dealerId) {
  const backendCount = getBackendParticipantErrorsCount(dealerId);
  const liveCount = getLiveParticipantErrorsCount(dealerId);
  return Math.max(liveCount, backendCount);
}

function getParticipantPhaseLabel(dealerId) {
  const id = String(dealerId || "").trim();
  if (!id) return "—";
  const state = liveTableStore.byDealerId.get(id)?.currentState;
  const phase = state && typeof state === "object" ? state.phase : "";
  if (typeof phase === "string" && phase.trim() !== "") {
    return _phaseLabel(phase);
  }
  return "—";
}

function formatParticipantErrorsSummary(dealerId) {
  return `Ошибки: ${getParticipantDisplayErrorsCount(dealerId)}`;
}

function formatParticipantPhaseSummary(dealerId) {
  return `Фаза: ${getParticipantPhaseLabel(dealerId)}`;
}

function getParticipantErrorsCount(dealerId) {
  return getParticipantDisplayErrorsCount(dealerId);
}

function getParticipantLiveSeconds(dealerId) {
  return getParticipantDisplayLiveSeconds(dealerId);
}

async function copyPendingPersonalInviteCode(code, button) {
  const value = String(code || "").trim();
  if (!value) return false;
  showError("room-participants-error", "");
  try {
    if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
      await navigator.clipboard.writeText(value);
    } else {
      const textarea = document.createElement("textarea");
      textarea.value = value;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.left = "-9999px";
      document.body.appendChild(textarea);
      textarea.select();
      const copied = document.execCommand("copy");
      document.body.removeChild(textarea);
      if (!copied) throw new Error("copy_failed");
    }
    if (button) {
      const prev = button.textContent;
      button.textContent = "Скопировано";
      setTimeout(() => {
        button.textContent = prev || "Скопировать";
      }, 1400);
    }
    return true;
  } catch {
    showError("room-participants-error", "Не удалось скопировать код. Скопируйте его вручную.");
    return false;
  }
}

function renderRoomParticipants(participants, invites) {
  const table = el("room-participants-table");
  if (!table) return;
  const tbody = table.querySelector("tbody");
  tbody.innerHTML = "";

  const participantItems = Array.isArray(participants) ? participants : [];
  const inviteItems = Array.isArray(invites) ? invites : [];

  if (participantItems.length === 0 && inviteItems.length === 0) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 5;
    td.className = "muted";
    td.textContent = "Участников пока нет.";
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  for (const participant of participantItems) {
    const tr = document.createElement("tr");
    const participantDealerId = String(participant.dealer_id || "").trim();
    const isSelected = participantDealerId && participantDealerId === getSelectedDealerId();
    tr.dataset.dealerId = participantDealerId;
    tr.classList.toggle("participant-row-selectable", Boolean(participantDealerId));
    tr.classList.toggle("participant-row-selected", Boolean(isSelected));
    if (participantDealerId) {
      tr.tabIndex = 0;
      tr.setAttribute("role", "button");
      tr.setAttribute("aria-pressed", isSelected ? "true" : "false");
      tr.addEventListener("click", () => {
        void openSelectedDealerView(participantDealerId);
      });
      tr.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
        void openSelectedDealerView(participantDealerId);
      });
    }

    const cName = document.createElement("td");
    cName.textContent = participant.display_name || "—";

    const cStatus = document.createElement("td");
    const badge = document.createElement("span");
    badge.className = `status-badge ${participantStatusClass(participant.online_status, "participant")}`;
    badge.textContent = participantStatusLabel(participant.online_status, "participant");
    cStatus.appendChild(badge);

    const cErrors = document.createElement("td");
    cErrors.textContent = String(getParticipantErrorsCount(participantDealerId));

    const cTime = document.createElement("td");
    const participantLiveSeconds = getParticipantLiveSeconds(participantDealerId);
    cTime.textContent = participantLiveSeconds == null ? "—" : formatDuration(participantLiveSeconds);

    const cActions = document.createElement("td");
    const deleteBtn = document.createElement("button");
    deleteBtn.type = "button";
    deleteBtn.className = "danger table-action-button";
    deleteBtn.textContent = "Удалить";
    deleteBtn.addEventListener("click", (event) => {
      event.stopPropagation();
      deleteRoomParticipant(participant.dealer_id);
    });
    cActions.appendChild(deleteBtn);

    tr.appendChild(cName);
    tr.appendChild(cStatus);
    tr.appendChild(cErrors);
    tr.appendChild(cTime);
    tr.appendChild(cActions);
    tbody.appendChild(tr);
  }

  for (const invite of inviteItems) {
    const tr = document.createElement("tr");
    const accessId = String(invite.access_id || "").trim();
    const inviteCode = getRoomPersonalInviteCode(accessId);

    const cName = document.createElement("td");
    const nameWrap = document.createElement("div");
    nameWrap.className = "participant-name-cell";
    const title = document.createElement("span");
    title.textContent = "Ожидает входа";
    nameWrap.appendChild(title);
    if (invite.trainer_internal_name) {
      const subtitle = document.createElement("span");
      subtitle.className = "participant-subtitle";
      subtitle.textContent = invite.trainer_internal_name;
      nameWrap.appendChild(subtitle);
    }
    const codeSubtitle = document.createElement("span");
    codeSubtitle.className = inviteCode ? "participant-subtitle mono" : "participant-subtitle muted";
    codeSubtitle.textContent = inviteCode
      ? `Код: ${inviteCode}`
      : "Код недоступен после обновления страницы";
    nameWrap.appendChild(codeSubtitle);
    cName.appendChild(nameWrap);

    const cStatus = document.createElement("td");
    const badge = document.createElement("span");
    badge.className = `status-badge ${participantStatusClass(invite.status, "pending-invite")}`;
    badge.textContent = participantStatusLabel(invite.status, "pending-invite");
    cStatus.appendChild(badge);

    const cErrors = document.createElement("td");
    cErrors.textContent = "—";

    const cTime = document.createElement("td");
    cTime.textContent = "—";

    const cActions = document.createElement("td");
    if (inviteCode) {
      const copyBtn = document.createElement("button");
      copyBtn.type = "button";
      copyBtn.className = "ghost table-action-button";
      copyBtn.textContent = "Скопировать";
      copyBtn.addEventListener("click", (event) => {
        event.stopPropagation();
        void copyPendingPersonalInviteCode(inviteCode, copyBtn);
      });
      cActions.appendChild(copyBtn);
    }
    const deleteBtn = document.createElement("button");
    deleteBtn.type = "button";
    deleteBtn.className = "danger table-action-button";
    deleteBtn.textContent = "Удалить";
    deleteBtn.addEventListener("click", (event) => {
      event.stopPropagation();
      revokePendingPersonalInvite(accessId);
    });
    cActions.appendChild(deleteBtn);

    tr.appendChild(cName);
    tr.appendChild(cStatus);
    tr.appendChild(cErrors);
    tr.appendChild(cTime);
    tr.appendChild(cActions);
    tbody.appendChild(tr);
  }
}

async function loadRoomParticipants(roomCode = selectedRoomCode(), options = {}) {
  const code = String(roomCode || "");
  const background = Boolean(options.background);
  const generation = options.generation;
  if (!code) {
    if (!background) {
      clearRoomParticipantsState();
    }
    return;
  }

  if (!background) {
    showError("room-participants-error", "");
  }
  const [participantsRes, invitesRes] = await Promise.all([
    api("GET", `/api/rooms/${encodeURIComponent(code)}/participants`),
    api("GET", `/api/rooms/${encodeURIComponent(code)}/personal-invites`),
  ]);
  if (background && isRoomPollStale(code, generation)) {
    return;
  }

  const participantsOk = participantsRes.ok && Array.isArray(participantsRes.data);
  const invitesOk = invitesRes.ok && Array.isArray(invitesRes.data);

  if (participantsOk && invitesOk) {
    const previousSelectedDealerId = getSelectedDealerId();
    roomParticipantsSnapshot = participantsRes.data;
    roomPersonalInvitesSnapshot = invitesRes.data;
    syncSelectedDealerWithParticipants(roomParticipantsSnapshot);
    if (previousSelectedDealerId && !getSelectedDealerId()) {
      setDashboardStage("rooms");
    }
    renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
    renderSelectedDealerDetail();
    renderLiveTableView();
    renderLiveFeed();
    return;
  }

  if (background) {
    return;
  }

  const previousSelectedDealerId = getSelectedDealerId();
  roomParticipantsSnapshot = participantsOk ? participantsRes.data : [];
  roomPersonalInvitesSnapshot = invitesOk ? invitesRes.data : [];
  syncSelectedDealerWithParticipants(roomParticipantsSnapshot);
  if (previousSelectedDealerId && !getSelectedDealerId()) {
    setDashboardStage("rooms");
  }
  renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
  renderSelectedDealerDetail();
  renderLiveTableView();
  renderLiveFeed();

  const participantsError = !participantsOk
    ? (participantsRes.data && formatApiError(participantsRes.data)) || `Не удалось загрузить участников (${participantsRes.status})`
    : "";
  const invitesError = !invitesOk
    ? (invitesRes.data && formatApiError(invitesRes.data)) || `Не удалось загрузить персональные приглашения (${invitesRes.status})`
    : "";

  showError("room-participants-error", [participantsError, invitesError].filter(Boolean).join(". "));
}

async function createPersonalInviteFromParticipants() {
  const code = selectedRoomCode();
  if (!code) return;

  showError("room-participants-error", "");
  showRoomParticipantsMessage("");
  renderRoomParticipantsManual("", "");

  const button = el("btn-create-personal-invite");
  if (button) button.disabled = true;
  try {
    const { ok, status, data } = await api("POST", `/api/rooms/${encodeURIComponent(code)}/accesses`, {});
    const created = data && Array.isArray(data.accesses) ? data.accesses : [];
    const createdItem = created.find((item) => item && item.access_code);
    if (!ok || !createdItem || !createdItem.access_code) {
      showError(
        "room-participants-error",
        (data && formatApiError(data)) || `Не удалось создать персональное приглашение (${status})`,
      );
      return;
    }

    const createdAccessId = String(createdItem.access_id || createdItem.id || "").trim();
    const accessCode = String(createdItem.access_code || "");
    if (createdAccessId && accessCode) {
      storeRoomPersonalInviteCode(createdAccessId, accessCode, code);
    }
    let copied = false;
    try {
      if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
        await navigator.clipboard.writeText(accessCode);
        copied = true;
      }
    } catch {
      copied = false;
    }

    if (copied) {
      showRoomParticipantsMessage("Приглашение создано и скопировано");
    } else {
      renderRoomParticipantsManual(
        accessCode,
        "Буфер обмена недоступен. Скопируйте код вручную сейчас.",
      );
      showRoomParticipantsMessage("Приглашение создано");
    }

    await loadRoomParticipants(code);
  } finally {
    if (button) button.disabled = false;
  }
}

async function revokePendingPersonalInvite(accessId) {
  const code = selectedRoomCode();
  if (!code || !accessId) return;

  const confirmed = window.confirm("Удалить персональное приглашение? Этот код больше не будет работать.");
  if (!confirmed) return;

  showError("room-participants-error", "");
  showRoomParticipantsMessage("");
  renderRoomParticipantsManual("", "");
  const { ok, status, data } = await api(
    "POST",
    `/api/rooms/${encodeURIComponent(code)}/accesses/${encodeURIComponent(accessId)}/revoke`,
    {},
  );
  if (!ok) {
    showError(
      "room-participants-error",
      (data && formatApiError(data)) || `Не удалось удалить приглашение (${status})`,
    );
    return;
  }

  deleteRoomPersonalInviteCode(accessId, code);
  await loadRoomParticipants(code);
}

async function deleteRoomParticipant(dealerId) {
  const code = selectedRoomCode();
  if (!code || !dealerId) return;

  const confirmed = window.confirm("Удалить участника? Он потеряет доступ к комнате.");
  if (!confirmed) return;

  showError("room-participants-error", "");
  showRoomParticipantsMessage("");
  renderRoomParticipantsManual("", "");
  const { ok, status, data } = await api(
    "DELETE",
    `/api/rooms/${encodeURIComponent(code)}/participants/${encodeURIComponent(dealerId)}`,
  );
  if (!ok) {
    showError(
      "room-participants-error",
      (data && formatApiError(data)) || `Не удалось удалить участника (${status})`,
    );
    return;
  }

  if (String(dealerId || "").trim() === getSelectedDealerId()) {
    closeSelectedDealerView();
  }
  await loadRoomParticipants(code);
}

function roomAccessStatusLabel(status) {
  const value = String(status || "").toLowerCase();
  const labels = {
    created: "Не активирован",
    activated: "Активирован",
    revoked: "Отозван",
    closed: "Закрыт",
  };
  return labels[value] || status || "Неизвестно";
}

function roomAccessStatusClass(status) {
  const value = String(status || "").toLowerCase();
  if (value === "created") return "status-created";
  if (value === "activated") return "status-activated";
  if (value === "revoked") return "status-revoked";
  if (value === "closed") return "status-closed";
  return "status-unknown";
}

function showRoomAccessMessage(message) {
  const node = el("room-accesses-message");
  if (!node) return;
  if (!message) {
    node.hidden = true;
    node.textContent = "";
    return;
  }
  node.hidden = false;
  node.textContent = message;
}

function clearRoomAccessMessages() {
  showError("room-accesses-error", "");
  showRoomAccessMessage("");
}

function renderGeneratedRoomAccesses(items = generatedRoomAccesses) {
  const panel = el("new-room-access-codes");
  if (!panel) return;
  panel.innerHTML = "";
  if (!Array.isArray(items) || items.length === 0) {
    panel.classList.add("hidden");
    return;
  }

  panel.classList.remove("hidden");
  const title = document.createElement("h3");
  title.textContent = "Новые access-коды";
  const note = document.createElement("p");
  note.className = "muted small";
  note.textContent = "Код показывается только сейчас. Скопируйте его перед обновлением страницы.";
  const list = document.createElement("div");
  list.className = "generated-access-list";

  for (const item of items) {
    const code = String(item.access_code || "");
    if (!code) continue;

    const row = document.createElement("div");
    row.className = "generated-access-row";

    const codeNode = document.createElement("span");
    codeNode.className = "generated-access-code";
    codeNode.textContent = code;

    const copyBtn = document.createElement("button");
    copyBtn.type = "button";
    copyBtn.className = "ghost table-action-button";
    copyBtn.textContent = "Скопировать";
    copyBtn.addEventListener("click", () => copyAccessCode(code, copyBtn));

    row.appendChild(codeNode);
    row.appendChild(copyBtn);
    list.appendChild(row);
  }

  panel.appendChild(title);
  panel.appendChild(note);
  panel.appendChild(list);
}

async function copyAccessCode(code, button) {
  clearRoomAccessMessages();
  try {
    if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
      await navigator.clipboard.writeText(code);
    } else {
      const textarea = document.createElement("textarea");
      textarea.value = code;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.left = "-9999px";
      document.body.appendChild(textarea);
      textarea.select();
      const copied = document.execCommand("copy");
      document.body.removeChild(textarea);
      if (!copied) throw new Error("copy_failed");
    }
    if (button) {
      const prev = button.textContent;
      button.textContent = "Скопировано";
      setTimeout(() => {
        button.textContent = prev || "Скопировать";
      }, 1400);
    }
  } catch {
    showError("room-accesses-error", "Не удалось скопировать код. Скопируйте его вручную.");
  }
}

function renderRoomAccesses(items) {
  const table = el("room-accesses-table");
  if (!table) return;
  const tbody = table.querySelector("tbody");
  tbody.innerHTML = "";

  if (!Array.isArray(items) || items.length === 0) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 6;
    td.className = "muted";
    td.textContent = "Access-коды ещё не созданы.";
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  for (const access of items) {
    const tr = document.createElement("tr");

    const cSlot = document.createElement("td");
    cSlot.textContent = String(access.slot_number ?? "—");

    const cInternal = document.createElement("td");
    const nameInput = document.createElement("input");
    nameInput.type = "text";
    nameInput.maxLength = 255;
    nameInput.className = "access-name-input";
    nameInput.value = access.trainer_internal_name || "";
    nameInput.placeholder = "Имя для тренера";
    cInternal.appendChild(nameInput);

    const cPublic = document.createElement("td");
    cPublic.textContent = access.dealer_display_name || "—";

    const cStatus = document.createElement("td");
    const badge = document.createElement("span");
    badge.className = `status-badge ${roomAccessStatusClass(access.status)}`;
    badge.textContent = roomAccessStatusLabel(access.status);
    cStatus.appendChild(badge);

    const cSuffix = document.createElement("td");
    cSuffix.className = "mono";
    cSuffix.textContent = access.access_code_suffix ? `...${access.access_code_suffix}` : "—";

    const cActions = document.createElement("td");
    const actions = document.createElement("div");
    actions.className = "access-actions";

    const saveBtn = document.createElement("button");
    saveBtn.type = "button";
    saveBtn.className = "ghost table-action-button";
    saveBtn.textContent = "Сохранить имя";
    saveBtn.addEventListener("click", () => updateRoomAccessInternalName(access.id, nameInput.value));
    actions.appendChild(saveBtn);

    const statusValue = String(access.status || "").toLowerCase();
    const isClosed = statusValue === "closed";
    const isRevoked = statusValue === "revoked";

    const revokeBtn = document.createElement("button");
    revokeBtn.type = "button";
    revokeBtn.className = "danger table-action-button";
    revokeBtn.textContent = "Отозвать";
    revokeBtn.disabled = isRevoked || isClosed;
    revokeBtn.title = isRevoked ? "Доступ уже отозван" : isClosed ? "Комната закрыта" : "";
    revokeBtn.addEventListener("click", () => revokeRoomAccess(access.id));
    actions.appendChild(revokeBtn);

    const resetBtn = document.createElement("button");
    resetBtn.type = "button";
    resetBtn.className = "secondary table-action-button";
    resetBtn.textContent = "Сбросить";
    resetBtn.disabled = isClosed;
    resetBtn.title = isClosed ? "Комната закрыта" : "";
    resetBtn.addEventListener("click", () => resetRoomAccess(access.id));
    actions.appendChild(resetBtn);

    cActions.appendChild(actions);

    tr.appendChild(cSlot);
    tr.appendChild(cInternal);
    tr.appendChild(cPublic);
    tr.appendChild(cStatus);
    tr.appendChild(cSuffix);
    tr.appendChild(cActions);
    tbody.appendChild(tr);
  }
}

async function loadRoomAccesses(roomCode = selectedRoomCode()) {
  const code = String(roomCode || "");
  if (!code) {
    clearRoomAccessState();
    return;
  }
  clearRoomAccessMessages();
  const { ok, status, data } = await api("GET", `/api/rooms/${encodeURIComponent(code)}/accesses`);
  if (!ok || !Array.isArray(data)) {
    roomAccessesSnapshot = [];
    renderRoomAccesses([]);
    showError("room-accesses-error", (data && formatApiError(data)) || `Не удалось загрузить access-коды (${status})`);
    return;
  }
  roomAccessesSnapshot = data;
  renderRoomAccesses(data);
}

async function createRoomAccess() {
  const code = selectedRoomCode();
  if (!code) return;

  clearRoomAccessMessages();
  const btn = el("btn-create-room-access");
  if (btn) btn.disabled = true;
  try {
    const { ok, status, data } = await api("POST", `/api/rooms/${encodeURIComponent(code)}/accesses`, {});
    const created = data && Array.isArray(data.accesses) ? data.accesses : [];
    if (!ok || created.length === 0) {
      showError("room-accesses-error", (data && formatApiError(data)) || `Не удалось создать access-код (${status})`);
      return;
    }
    generatedRoomAccesses = created.filter((item) => item && item.access_code);
    renderGeneratedRoomAccesses();
    showRoomAccessMessage("Access-код создан. Скопируйте полный код сейчас.");
    await loadRoomParticipants(code);
    await loadRoomAccesses(code);
  } finally {
    if (btn) btn.disabled = false;
  }
}

async function updateRoomAccessInternalName(accessId, value) {
  const code = selectedRoomCode();
  if (!code || !accessId) return;

  clearRoomAccessMessages();
  const body = {
    trainer_internal_name: String(value || "").trim() || null,
  };
  const { ok, status, data } = await api(
    "PATCH",
    `/api/rooms/${encodeURIComponent(code)}/accesses/${encodeURIComponent(accessId)}`,
    body,
  );
  if (!ok) {
    showError("room-accesses-error", (data && formatApiError(data)) || `Не удалось сохранить имя (${status})`);
    return;
  }
  showRoomAccessMessage("Внутреннее имя сохранено.");
  await loadRoomParticipants(code);
  await loadRoomAccesses(code);
}

async function revokeRoomAccess(accessId) {
  const code = selectedRoomCode();
  if (!code || !accessId) return;

  const confirmed = window.confirm("Отозвать доступ? Участник больше не сможет использовать эту комнату.");
  if (!confirmed) return;

  clearRoomAccessMessages();
  generatedRoomAccesses = [];
  renderGeneratedRoomAccesses();

  const { ok, status, data } = await api(
    "POST",
    `/api/rooms/${encodeURIComponent(code)}/accesses/${encodeURIComponent(accessId)}/revoke`,
    {},
  );
  if (!ok) {
    showError("room-accesses-error", (data && formatApiError(data)) || `Не удалось отозвать доступ (${status})`);
    return;
  }

  showRoomAccessMessage("Доступ отозван.");
  await loadRoomParticipants(code);
  await loadRoomAccesses(code);
}

async function resetRoomAccess(accessId) {
  const code = selectedRoomCode();
  if (!code || !accessId) return;

  const confirmed = window.confirm(
    "Сбросить доступ? Старый код и токены перестанут работать. Будет создан новый код для этого слота.",
  );
  if (!confirmed) return;

  clearRoomAccessMessages();
  const { ok, status, data } = await api(
    "POST",
    `/api/rooms/${encodeURIComponent(code)}/accesses/${encodeURIComponent(accessId)}/reset`,
    {},
  );
  if (!ok || !data || !data.access_code) {
    showError("room-accesses-error", (data && formatApiError(data)) || `Не удалось сбросить доступ (${status})`);
    return;
  }

  generatedRoomAccesses = [data];
  renderGeneratedRoomAccesses();
  showRoomAccessMessage("Доступ сброшен. Новый код показан ниже, скопируйте его сейчас.");
  await loadRoomParticipants(code);
  await loadRoomAccesses(code);
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

async function deleteCurrentRoom() {
  const code = selectedRoomCode();
  if (!code) return;
  const okDel = window.confirm(`Удалить комнату ${code}?`);
  if (!okDel) return;
  const { ok, status, data } = await api("DELETE", `/api/rooms/${encodeURIComponent(code)}`);
  if (!ok) {
    showError("action-error", (data && formatApiError(data)) || `Не удалось удалить комнату (${status})`);
    return;
  }
  clearRoomScopedState({ preserveActionError: true });
  await refreshRooms();
}

function renderRoomsList(rooms) {
  const tbody = el("rooms-list-table").querySelector("tbody");
  tbody.innerHTML = "";
  if (!Array.isArray(rooms) || rooms.length === 0) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 4;
    td.className = "muted";
    td.textContent = "Комнат пока нет.";
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }
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
      clearLiveDashboardState();
      stopRoomModelPolling();
      setCurrentRoom(room.room_code, `${room.name} (${room.room_code})`);
      await loadRoomInvite();
      await loadRoomParticipants();
      await fetchRoomPinsOnce();
      await loadRoomAccesses();
      await fetchRoomDealersOnce();
      await loadTrainerLiveSession();
      startRoomModelPolling();
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
      const { ok, status, data } = await api("DELETE", `/api/rooms/${encodeURIComponent(room.room_code)}`);
      if (!ok) {
        showError("action-error", (data && formatApiError(data)) || `Не удалось удалить комнату (${status})`);
        return;
      }
      if (String(room.room_code || "") === selectedRoomCode()) {
        clearRoomScopedState({ preserveActionError: true });
      } else {
        deleteRoomPinsCache(room.room_code);
      }
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
  if (titleNode) titleNode.textContent = roomLabel ? `Доступ в комнату: ${roomLabel}` : "Доступ в комнату";
  const tbody = el("room-access-table").querySelector("tbody");
  tbody.innerHTML = "";
  if (!code) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 4;
    td.className = "muted";
    td.textContent = "Сначала выберите комнату.";
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }
  const cacheItem = _loadPinsCache()[selectedRoomCode()] || {};
  const pinMap = new Map((cacheItem.pins || []).map((p) => [Number(p.dealer_slot), String(p.pin)]));
  if (!Array.isArray(items) || items.length === 0) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 4;
    td.className = "muted";
    td.textContent = "PIN-слоты ещё не созданы.";
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }
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
  const { ok, status, data } = await api("GET", `/api/rooms/${encodeURIComponent(code)}/pins`);
  if (!ok || !Array.isArray(data)) {
    roomPinsSnapshot = [];
    renderRoomPins([]);
    if (status !== 404) {
      showError("action-error", (data && formatApiError(data)) || `Не удалось загрузить PIN-доступы (${status})`);
    }
    return;
  }
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
  clearRoomScopedState({ preserveActionError: true });
  await refreshRooms();
  if (room && room.room_code) {
    stopRoomModelPolling();
    setCurrentRoom(room.room_code, `${room.name || room.room_code} (${room.room_code})`);
    await loadRoomInvite();
    await loadRoomParticipants();
    await fetchRoomPinsOnce();
    await loadRoomAccesses();
    await fetchRoomDealersOnce();
    await loadTrainerLiveSession();
    startRoomModelPolling();
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
    clearLiveDashboardState();
    return;
  }
  const { ok, status, data } = await api("GET", `/api/rooms/${encodeURIComponent(code)}/trainer-live-session`);
  if (!ok) {
    clearLiveDashboardState();
    if (status === 404) {
      renderResultsEmpty("Тренировка ещё не запущена");
      return;
    }
    showError("action-error", (data && formatApiError(data)) || `Ошибка ${status}`);
    return;
  }
  const prevSessionId = String(currentSessionId || "");
  currentSessionId = String(data.session_id || "");
  const sessionChanged = prevSessionId !== String(currentSessionId || "");
  if (sessionChanged) {
    resetLiveSessionView({ clearFeed: true });
  } else {
    renderSessionInfo();
  }
  setTrainingButtons(data.status === "active");
  if (data.status === "active") {
    startTrainerSessionWebSocket();
  } else {
    stopLiveWatch();
    resetLiveSessionView({ clearFeed: true });
    renderResultsEmpty("Тренировка ещё не запущена");
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
  clearLiveDashboardState();
}

async function fetchResultsOnce() {
  const activeSessionId = String(currentSessionId || "").trim();
  if (!activeSessionId || !getToken() || resultsFetchInFlight) return;

  resultsFetchInFlight = true;
  try {
    const { ok, data } = await api("GET", `/api/sessions/${encodeURIComponent(activeSessionId)}/results`);
    if (!ok || !data || !Array.isArray(data.dealers)) {
      return;
    }
    if (String(currentSessionId || "").trim() !== activeSessionId) {
      return;
    }
    if (data.status === "completed" || data.status === "aborted") {
      clearLiveDashboardState();
      renderResultsEmpty("Тренировка завершена");
      return;
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
    if (String(currentSessionId || "").trim() !== activeSessionId) {
      return;
    }
    renderDealers(Array.from(byId.values()));
    if (roomParticipantsSnapshot.length > 0) {
      renderRoomParticipants(roomParticipantsSnapshot, roomPersonalInvitesSnapshot);
    }
  } finally {
    resultsFetchInFlight = false;
  }
}

async function fetchRoomDealersOnce() {
  const code = selectedRoomCode();
  if (!code) {
    latestDealersSnapshot = [];
    renderResultsEmpty("Тренировка ещё не запущена");
    return;
  }
  const { ok, data } = await api("GET", `/api/rooms/${encodeURIComponent(code)}/dealers`);
  if (!ok || !Array.isArray(data)) {
    latestDealersSnapshot = [];
    renderResultsEmpty("Тренировка ещё не запущена");
    return;
  }
  const mapped = data.map((d) => ({
    ...(latestDealersSnapshot.find((item) => String(item.dealer_id || "") === String(d.dealer_id || "")) || {
      rounds_completed: 0,
      errors_total: 0,
      cards_errors: 0,
      payout_errors: 0,
      chips_errors: 0,
      live_seconds: 0,
      avg_accuracy: 0,
    }),
    dealer_id: String(d.dealer_id || ""),
    display_name: d.display_name || "—",
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
  for (const dealer of latestDealersSnapshot) {
    syncDealerLiveTimeFromBackend(dealer && dealer.dealer_id);
  }
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
    const dealerLiveSeconds = getParticipantDisplayLiveSeconds(did);
    liveTime.textContent = dealerLiveSeconds == null ? "—" : formatDuration(dealerLiveSeconds);
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

function renderResultsEmpty(message = "Тренировка ещё не запущена") {
  const tbody = el("dealers-table").querySelector("tbody");
  tbody.innerHTML = "";
  const empty = el("results-empty");
  empty.textContent = message;
  empty.hidden = false;
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
  setDashboardUserLabel(`${user.full_name || user.email || "тренер"}`);
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
  setDashboardUserLabel(`${user.full_name || user.email || "тренер"}`);
  setDashboardVisible(true);
  setDashboardStage("rooms");
  await refreshRooms();
  await maybeLoadSessionAfterRooms();
}

function onLogout() {
  clearTokens();
  clearRoomScopedState({ preserveActionError: true });
  clearTournamentState();
  closeCreateTournamentModal();
  setDashboardUserLabel("");
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
  el("btn-logout-tournaments")?.addEventListener("click", () => onLogout());
  el("btn-open-rooms-section")?.addEventListener("click", () => {
    void openDashboardSection("rooms");
  });
  el("btn-open-tournaments-section")?.addEventListener("click", () => {
    void openDashboardSection("tournaments");
  });
  el("btn-open-create-tournament-modal")?.addEventListener("click", () => openCreateTournamentModal());
  el("btn-close-create-tournament-modal")?.addEventListener("click", () => closeCreateTournamentModal());
  el("create-tournament-modal")?.addEventListener("click", (ev) => {
    if (ev.target === el("create-tournament-modal")) closeCreateTournamentModal();
  });
  el("btn-create-tournament")?.addEventListener("click", () => {
    void createTournament();
  });
  el("btn-open-create-room-modal").addEventListener("click", () => openCreateRoomModal());
  el("btn-close-create-room-modal").addEventListener("click", () => closeCreateRoomModal());
  el("create-room-modal").addEventListener("click", (ev) => {
    if (ev.target === el("create-room-modal")) closeCreateRoomModal();
  });
  el("btn-close-add-participant-modal").addEventListener("click", () => {
    void closeAddParticipantModal();
  });
  el("add-participant-modal").addEventListener("click", (ev) => {
    if (ev.target === el("add-participant-modal")) {
      void closeAddParticipantModal();
    }
  });
  el("btn-create-room").addEventListener("click", () => createRoom());
  el("btn-delete-current-room").addEventListener("click", () => deleteCurrentRoom());
  const openRoomDashboardBtn = el("btn-open-room-dashboard");
  if (openRoomDashboardBtn) {
    openRoomDashboardBtn.addEventListener("click", async () => {
      setDashboardStage("live");
      await loadTrainerLiveSession();
      await fetchResultsOnce();
    });
  }
  el("btn-back-to-participants").addEventListener("click", () => closeSelectedDealerView());
  el("btn-add-pin-slot").addEventListener("click", async () => {
    const code = selectedRoomCode();
    if (!code) return;
    const { ok, data } = await api("POST", `/api/rooms/${encodeURIComponent(code)}/pins`, {});
    if (!ok || !data) return;
    cachePinUpdate(code, data.dealer_slot, data.pin);
    await fetchRoomPinsOnce();
  });
  el("btn-create-room-access").addEventListener("click", () => createRoomAccess());
  el("btn-create-room-invite").addEventListener("click", () => createRoomInvite());
  el("btn-create-personal-invite").addEventListener("click", () => createPersonalInviteFromParticipants());
  el("btn-open-room-settings")?.addEventListener("click", () => openAddParticipantModal());
  el("btn-save-room-invite-limit")?.addEventListener("click", () => {
    void saveRoomInviteLimitFromInput();
  });
  const roomInviteLimitInput = el("room-invite-limit-input");
  roomInviteLimitInput?.addEventListener("input", () => {
    roomInviteLimitInputDirty = true;
  });
  roomInviteLimitInput?.addEventListener("change", () => {
    roomInviteLimitInputDirty = true;
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
  setRoomScopedVisibility();
  renderRoomInvite(null);
  renderRoomParticipants([], []);
  renderRoomPins([]);
  renderRoomAccesses([]);
  renderTournaments([]);
  renderResultsEmpty("Тренировка ещё не запущена");
  if (getToken()) {
    setDashboardVisible(true);
    setDashboardStage("rooms");
    refreshRooms().then(() => {
      maybeLoadSessionAfterRooms();
    });
  }
}

boot();
