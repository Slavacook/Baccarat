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

function formatTournamentMeta(tournament) {
  if (!tournament) {
    return "Статус: —";
  }

  const statusLabel = formatTournamentStatus(tournament.status);
  const maxRounds = Number(tournament && tournament.max_rounds);
  const attemptDurationSeconds = Number(tournament && tournament.attempt_duration_seconds);
  const roundsLabel = Number.isFinite(maxRounds) && maxRounds > 0 ? `${maxRounds} раздач` : "—";
  const minutes = Number.isFinite(attemptDurationSeconds) && attemptDurationSeconds > 0
    ? `${Math.floor(attemptDurationSeconds / 60)} мин`
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

function getPodiumClass(rank) {
  if (rank === 1) return "podium-first";
  if (rank === 2) return "podium-second";
  return "podium-third";
}

function getPodiumMedal(rank) {
  if (rank === 1) return "🥇";
  if (rank === 2) return "🥈";
  return "🥉";
}

function renderTournamentHero(tournament) {
  const title = el("tournament-public-title");
  const meta = el("tournament-public-meta");
  if (!title || !meta) return;

  if (!tournament) {
    title.textContent = "Турнир";
    meta.textContent = "Статус: —";
    return;
  }

  title.textContent = tournament.title || "Турнир";
  meta.textContent = formatTournamentMeta(tournament);
}

function renderTournamentPodium(entries) {
  const card = el("tournament-public-podium-card");
  const container = el("tournament-public-podium");
  if (!card || !container) return;

  container.innerHTML = "";

  if (!Array.isArray(entries) || entries.length === 0) {
    card.classList.add("hidden");
    return;
  }

  const podiumEntries = entries.filter((entry) => {
    const rank = Number(entry && entry.rank);
    return rank >= 1 && rank <= 3;
  }).slice(0, 3);

  if (podiumEntries.length === 0) {
    card.classList.add("hidden");
    return;
  }

  const displayOrder = [];
  const second = podiumEntries.find((entry) => Number(entry && entry.rank) === 2);
  const first = podiumEntries.find((entry) => Number(entry && entry.rank) === 1);
  const third = podiumEntries.find((entry) => Number(entry && entry.rank) === 3);
  if (second) displayOrder.push(second);
  if (first) displayOrder.push(first);
  if (third) displayOrder.push(third);

  for (const entry of displayOrder) {
    const rank = Number(entry && entry.rank);
    const cardNode = document.createElement("article");
    cardNode.className = `podium-slot ${getPodiumClass(rank)}`;

    const badge = document.createElement("div");
    badge.className = "podium-badge";
    badge.textContent = getPodiumMedal(rank);

    const place = document.createElement("p");
    place.className = "podium-place";
    place.textContent = `${rank} место`;

    const name = document.createElement("h3");
    name.className = "podium-name";
    name.textContent = entry && entry.display_name ? String(entry.display_name) : "—";

    const stats = document.createElement("dl");
    stats.className = "podium-stats";

    const errorsTerm = document.createElement("dt");
    errorsTerm.textContent = "Ошибки";
    const errorsValue = document.createElement("dd");
    errorsValue.textContent = String(entry && entry.errors_total != null ? entry.errors_total : "—");

    const timeTerm = document.createElement("dt");
    timeTerm.textContent = "Время";
    const timeValue = document.createElement("dd");
    timeValue.textContent = formatDuration(entry && entry.time_spent_seconds != null ? entry.time_spent_seconds : 0);

    const attemptTerm = document.createElement("dt");
    attemptTerm.textContent = "Попытка";
    const attemptValue = document.createElement("dd");
    attemptValue.textContent = String(entry && entry.attempt_number != null ? entry.attempt_number : "—");

    stats.appendChild(errorsTerm);
    stats.appendChild(errorsValue);
    stats.appendChild(timeTerm);
    stats.appendChild(timeValue);
    stats.appendChild(attemptTerm);
    stats.appendChild(attemptValue);

    cardNode.appendChild(badge);
    cardNode.appendChild(place);
    cardNode.appendChild(name);
    cardNode.appendChild(stats);
    container.appendChild(cardNode);
  }

  card.classList.remove("hidden");
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
    renderTournamentHero(null);
    renderTournamentPodium([]);
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
    renderTournamentHero(null);
    renderTournamentPodium([]);
    renderLeaderboard([]);
    return;
  }

  showPageError("");
  renderTournamentHero(data && data.tournament ? data.tournament : null);
  const entries = data && data.leaderboard && Array.isArray(data.leaderboard.entries) ? data.leaderboard.entries : [];
  renderTournamentPodium(entries);
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
  void loadTournamentPage();
  startAutoRefresh();
}

init();
