const el = (id) => document.getElementById(id);

const TELEGRAM_CHANNEL_URL = "https://t.me/baccarat_tr";

let refreshTimer = null;
let currentTournamentCode = "";
let currentTournamentSnapshot = null;

function showPageError(message) {
  const node = el("tournament-page-error");
  if (!node) return;
  const text = String(message || "").trim();
  node.textContent = text;
  node.classList.toggle("hidden", !text);
}

function showJoinTournamentStatus(message) {
  const node = el("join-tournament-modal-status");
  if (!node) return;
  node.textContent = String(message || "").trim();
}

function formatTournamentStatus(status) {
  const normalized = String(status || "").trim().toLowerCase();
  if (normalized === "active" || normalized === "open" || normalized === "started") {
    return "Активный турнир";
  }
  if (normalized === "closed" || normalized === "finished" || normalized === "completed") {
    return "Завершённый турнир";
  }
  if (!normalized) {
    return "Турнир";
  }
  return "Турнир";
}

function formatTournamentMeta(tournament) {
  if (!tournament) {
    return "Турнир · — · лимит —";
  }

  const statusLabel = formatTournamentStatus(tournament.status);
  const maxRounds = Number(tournament && tournament.max_rounds);
  const attemptDurationSeconds = Number(tournament && tournament.attempt_duration_seconds);
  const roundsLabel = Number.isFinite(maxRounds) && maxRounds > 0 ? `${maxRounds} раздач` : "—";
  const minutes = Number.isFinite(attemptDurationSeconds) && attemptDurationSeconds > 0
    ? `лимит ${Math.floor(attemptDurationSeconds / 60)} мин`
    : "—";
  return `${statusLabel} · ${roundsLabel} · ${minutes}`;
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

function getPodiumMedal(rank) {
  if (rank === 1) return "🥇";
  if (rank === 2) return "🥈";
  return "🥉";
}

function getLeaderboardRankClass(rank) {
  if (rank === 1) return "leaderboard-rank-first";
  if (rank === 2) return "leaderboard-rank-second";
  if (rank === 3) return "leaderboard-rank-third";
  return "";
}

function renderTournamentHero(tournament) {
  const title = el("tournament-public-title");
  const meta = el("tournament-public-meta");
  const joinButton = el("btn-open-join-tournament-modal");
  if (!title || !meta) return;

  if (!tournament) {
    title.textContent = "Турнир";
    meta.textContent = "Статус: —";
    if (joinButton) {
      joinButton.disabled = true;
    }
    return;
  }

  title.textContent = tournament.title || "Турнир";
  meta.textContent = formatTournamentMeta(tournament);
  if (joinButton) {
    joinButton.disabled = false;
  }
}

function openJoinTournamentModal() {
  const modal = el("join-tournament-modal");
  if (!modal) return;
  showJoinTournamentStatus("");
  modal.classList.remove("hidden");
}

function closeJoinTournamentModal() {
  const modal = el("join-tournament-modal");
  if (!modal) return;
  modal.classList.add("hidden");
  showJoinTournamentStatus("");
}

function openTelegramChannel() {
  window.open(TELEGRAM_CHANNEL_URL, "_blank", "noopener");
}

async function copyTextToClipboard(text) {
  const value = String(text || "").trim();
  if (!value) {
    throw new Error("empty_text");
  }

  if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
    try {
      await navigator.clipboard.writeText(value);
      return;
    } catch {
      // Continue to textarea fallback below.
    }
  }

  const textarea = document.createElement("textarea");
  textarea.value = value;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.left = "-9999px";
  document.body.appendChild(textarea);
  textarea.select();
  textarea.setSelectionRange(0, textarea.value.length);
  const copied = document.execCommand("copy");
  document.body.removeChild(textarea);

  if (!copied) {
    throw new Error("copy_failed");
  }
}

async function copyTournamentCode() {
  const tournamentCode = currentTournamentSnapshot && currentTournamentSnapshot.code
    ? String(currentTournamentSnapshot.code).trim()
    : "";
  if (!tournamentCode) {
    showJoinTournamentStatus("Код турнира недоступен");
    return;
  }

  try {
    await copyTextToClipboard(tournamentCode);
    showJoinTournamentStatus("Код скопирован");
  } catch {
    showJoinTournamentStatus("Не удалось скопировать код");
  }
}

function renderLeaderboard(entries) {
  const card = el("tournament-public-leaderboard-card");
  const list = el("tournament-public-leaderboard-list");
  const empty = el("tournament-public-leaderboard-empty");
  if (!card || !list || !empty) return;

  list.replaceChildren();
  card.classList.remove("hidden");

  if (!Array.isArray(entries) || entries.length === 0) {
    empty.classList.remove("hidden");
    list.classList.add("hidden");
    return;
  }

  empty.classList.add("hidden");
  list.classList.remove("hidden");
  for (const entry of entries) {
    const rank = Number(entry && entry.rank);
    const row = document.createElement("article");
    row.className = "leaderboard-row";

    const rankBadge = document.createElement("div");
    rankBadge.className = "leaderboard-rank-badge";
    const rankClass = getLeaderboardRankClass(rank);
    if (rankClass) {
      rankBadge.classList.add(rankClass);
      row.classList.add(rankClass);
    }
    rankBadge.textContent = rank >= 1 && rank <= 3 ? getPodiumMedal(rank) : String(entry && entry.rank != null ? entry.rank : "—");

    const content = document.createElement("div");
    content.className = "leaderboard-row-content";

    const name = document.createElement("h3");
    name.className = "leaderboard-row-name";
    name.textContent = entry && entry.display_name ? String(entry.display_name) : "—";

    const metrics = document.createElement("div");
    metrics.className = "leaderboard-row-metrics";

    const attemptMetric = document.createElement("div");
    attemptMetric.className = "leaderboard-metric leaderboard-metric-attempt";
    const attemptLabel = document.createElement("span");
    attemptLabel.className = "leaderboard-metric-label";
    attemptLabel.textContent = "Попытка";
    const attemptValue = document.createElement("span");
    attemptValue.className = "leaderboard-metric-value";
    attemptValue.textContent = String(entry && entry.attempt_number != null ? entry.attempt_number : "—");
    attemptMetric.appendChild(attemptLabel);
    attemptMetric.appendChild(attemptValue);

    const timeMetric = document.createElement("div");
    timeMetric.className = "leaderboard-metric leaderboard-metric-time";
    const timeLabel = document.createElement("span");
    timeLabel.className = "leaderboard-metric-label";
    timeLabel.textContent = "Время";
    const timeValue = document.createElement("span");
    timeValue.className = "leaderboard-metric-value";
    timeValue.textContent = formatDuration(entry && entry.time_spent_seconds != null ? entry.time_spent_seconds : 0);
    timeMetric.appendChild(timeLabel);
    timeMetric.appendChild(timeValue);

    const errorsMetric = document.createElement("div");
    errorsMetric.className = "leaderboard-metric leaderboard-metric-errors";
    const errorsLabel = document.createElement("span");
    errorsLabel.className = "leaderboard-metric-label";
    errorsLabel.textContent = "Ошибки";
    const errorsValue = document.createElement("span");
    errorsValue.className = "leaderboard-metric-value";
    errorsValue.textContent = String(entry && entry.errors_total != null ? entry.errors_total : "—");
    errorsMetric.appendChild(errorsLabel);
    errorsMetric.appendChild(errorsValue);

    metrics.appendChild(attemptMetric);
    metrics.appendChild(timeMetric);
    metrics.appendChild(errorsMetric);

    content.appendChild(name);
    row.appendChild(rankBadge);
    row.appendChild(content);
    row.appendChild(metrics);
    list.appendChild(row);
  }
}

async function loadTournamentPage() {
  if (!currentTournamentCode) {
    currentTournamentSnapshot = null;
    showPageError("Код турнира не указан");
    renderTournamentHero(null);
    renderLeaderboard([]);
    return;
  }

  const response = await fetch(`/api/tournaments/public/${encodeURIComponent(currentTournamentCode)}`, {
    method: "GET",
    headers: { Accept: "application/json" },
  });

  let data = null;
  try {
    data = await response.json();
  } catch {
    data = null;
  }

  if (!response.ok) {
    currentTournamentSnapshot = null;
    if (response.status === 404) {
      showPageError("Турнир не найден");
    } else {
      showPageError("Не удалось загрузить турнир");
    }
    renderTournamentHero(null);
    renderLeaderboard([]);
    return;
  }

  showPageError("");
  currentTournamentSnapshot = data && data.tournament ? data.tournament : null;
  renderTournamentHero(currentTournamentSnapshot);
  const entries = data && data.leaderboard && Array.isArray(data.leaderboard.entries) ? data.leaderboard.entries : [];
  renderLeaderboard(entries);
}

function startAutoRefresh() {
  if (refreshTimer) clearInterval(refreshTimer);
  refreshTimer = setInterval(() => {
    void loadTournamentPage();
  }, 10000);
}

function init() {
  const params = new URLSearchParams(window.location.search);
  currentTournamentCode = String(params.get("code") || "").trim();
  el("btn-open-join-tournament-modal")?.addEventListener("click", () => {
    openJoinTournamentModal();
  });
  el("btn-close-join-tournament-modal")?.addEventListener("click", () => {
    closeJoinTournamentModal();
  });
  el("btn-open-telegram-channel")?.addEventListener("click", () => {
    openTelegramChannel();
  });
  el("btn-copy-tournament-code")?.addEventListener("click", () => {
    void copyTournamentCode();
  });
  el("join-tournament-modal")?.addEventListener("click", (event) => {
    if (event.target === el("join-tournament-modal")) {
      closeJoinTournamentModal();
    }
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeJoinTournamentModal();
    }
  });
  void loadTournamentPage();
  startAutoRefresh();
}

init();
