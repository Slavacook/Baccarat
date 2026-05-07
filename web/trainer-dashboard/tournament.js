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
  if (!title || !meta) return;

  if (!tournament) {
    title.textContent = "Турнир";
    meta.textContent = "Статус: —";
    return;
  }

  title.textContent = tournament.title || "Турнир";
  meta.textContent = formatTournamentMeta(tournament);
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

    const meta = document.createElement("p");
    meta.className = "leaderboard-row-meta";
    const errorsLabel = `${entry && entry.errors_total != null ? entry.errors_total : "—"} ошибок`;
    const timeLabel = formatDuration(entry && entry.time_spent_seconds != null ? entry.time_spent_seconds : 0);
    const attemptLabel = `попытка ${entry && entry.attempt_number != null ? entry.attempt_number : "—"}`;
    meta.textContent = `${errorsLabel} · ${timeLabel} · ${attemptLabel}`;

    content.appendChild(name);
    content.appendChild(meta);
    row.appendChild(rankBadge);
    row.appendChild(content);
    list.appendChild(row);
  }
}

async function loadTournamentPage() {
  if (!currentTournamentCode) {
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
  renderTournamentHero(data && data.tournament ? data.tournament : null);
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
  void loadTournamentPage();
  startAutoRefresh();
}

init();
