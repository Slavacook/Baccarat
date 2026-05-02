const el = (id) => document.getElementById(id);

let refreshTimer = null;
let currentTournamentCode = "";

function showPageError(message) {
  const node = el("tournament-page-error");
  if (!node) return;
  const text = String(message || "").trim();
  node.textContent = text;
  node.classList.toggle("hidden", !text);
}

function formatTournamentStatus(status) {
  const normalized = String(status || "").trim().toLowerCase();
  if (normalized === "active") return "Активен";
  if (normalized === "closed") return "Закрыт";
  return "—";
}

function formatTournamentRules(tournament) {
  const maxRounds = Number(tournament && tournament.max_rounds);
  const attemptDurationSeconds = Number(tournament && tournament.attempt_duration_seconds);
  const roundsLabel = Number.isFinite(maxRounds) && maxRounds > 0 ? `${maxRounds} раздач` : "—";
  const minutes = Number.isFinite(attemptDurationSeconds) && attemptDurationSeconds > 0
    ? Math.floor(attemptDurationSeconds / 60)
    : 0;
  const durationLabel = minutes > 0 ? `${minutes} мин` : "—";
  return `${roundsLabel} / ${durationLabel}`;
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

function renderTournamentInfo(tournament) {
  const card = el("tournament-public-info-card");
  const title = el("tournament-public-title");
  const code = el("tournament-public-code");
  const status = el("tournament-public-status");
  const rules = el("tournament-public-rules");
  if (!card || !title || !code || !status || !rules) return;

  if (!tournament) {
    card.classList.add("hidden");
    title.textContent = "Турнир";
    code.textContent = "Код: —";
    status.textContent = "Статус: —";
    rules.textContent = "Правила: —";
    return;
  }

  card.classList.remove("hidden");
  title.textContent = tournament.title || "Турнир";
  code.textContent = `Код: ${tournament.code || "—"}`;
  status.textContent = `Статус: ${formatTournamentStatus(tournament.status)}`;
  rules.textContent = `Правила: ${formatTournamentRules(tournament)}`;
}

function renderLeaderboard(entries) {
  const card = el("tournament-public-leaderboard-card");
  const table = el("tournament-public-leaderboard-table");
  const tbody = table ? table.querySelector("tbody") : null;
  const empty = el("tournament-public-leaderboard-empty");
  if (!card || !tbody || !empty) return;

  tbody.innerHTML = "";
  card.classList.remove("hidden");

  if (!Array.isArray(entries) || entries.length === 0) {
    empty.classList.remove("hidden");
    return;
  }

  empty.classList.add("hidden");
  for (const entry of entries) {
    const tr = document.createElement("tr");

    const cRank = document.createElement("td");
    cRank.textContent = String(entry && entry.rank != null ? entry.rank : "—");

    const cName = document.createElement("td");
    cName.textContent = entry && entry.display_name ? String(entry.display_name) : "—";

    const cErrors = document.createElement("td");
    cErrors.textContent = String(entry && entry.errors_total != null ? entry.errors_total : "—");

    const cTime = document.createElement("td");
    cTime.textContent = formatDuration(entry && entry.time_spent_seconds != null ? entry.time_spent_seconds : 0);

    const cAttempt = document.createElement("td");
    cAttempt.textContent = String(entry && entry.attempt_number != null ? entry.attempt_number : "—");

    tr.appendChild(cRank);
    tr.appendChild(cName);
    tr.appendChild(cErrors);
    tr.appendChild(cTime);
    tr.appendChild(cAttempt);
    tbody.appendChild(tr);
  }
}

async function loadTournamentPage() {
  if (!currentTournamentCode) {
    showPageError("Код турнира не указан");
    renderTournamentInfo(null);
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
    if (response.status === 404) {
      showPageError("Турнир не найден");
    } else {
      showPageError("Не удалось загрузить турнир");
    }
    renderTournamentInfo(null);
    renderLeaderboard([]);
    return;
  }

  showPageError("");
  renderTournamentInfo(data && data.tournament ? data.tournament : null);
  renderLeaderboard(data && data.leaderboard && Array.isArray(data.leaderboard.entries) ? data.leaderboard.entries : []);
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
  el("btn-refresh-tournament")?.addEventListener("click", () => {
    void loadTournamentPage();
  });
  void loadTournamentPage();
  startAutoRefresh();
}

init();
