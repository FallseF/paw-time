// Paw Time — Recruit view. Renders /v1/insights/metrics (live or simulated) and the
// /v1/insights/feed "Live now" panel. Simulated mode is synthetic and labelled so on every card and chart.
import type {
  InsightsAggregate,
  InsightsFeedResponse,
  InsightsMetricsResponse,
} from "@paw-time/api-contracts";
import { BarController, BarElement, CategoryScale, Chart, Legend, LinearScale, LineController, LineElement, PointElement, Tooltip, type ChartConfiguration, type Plugin, type TooltipItem } from "chart.js";
import { I18N, type Dict, type Lang } from "./i18n";
import { esc, feedText, fillTemplate, fmtN, fmtPct, fmtPp, labelOf } from "./format";

Chart.register(BarController, BarElement, CategoryScale, LinearScale, LineController, LineElement, PointElement, Tooltip, Legend);

type Mode = "simulated" | "live";
type Loaded = InsightsMetricsResponse | { error: true };

const API = (document.querySelector('meta[name="paw-time-api"]') as HTMLMetaElement | null)?.content ?? "";

const ICONS: Record<string, string> = {
  app_open: "📱", job_cards_shown: "🐾", job_card_open: "🗂️", job_accept: "✅", job_pass: "↩️", shift_start: "▶️",
  shift_end: "⏹️", cat_tired_stop: "😿", review_submitted: "⭐", practice_done: "🎯", skill_badge_share_toggled: "🏅",
  shop_island_visit: "🏝️", scoop_night: "🌙", hatch: "🥚", island_expand: "🌱", island_share: "🔗", outfit_change: "👕",
  calendar_add: "📅", suggestions_toggled: "💡",
};

const state = {
  mode: "simulated" as Mode,
  lang: "en" as Lang,
  demoOnly: false,
  metrics: new Map<string, Loaded>(),
  charts: [] as Chart[],
  feedTimer: 0 as number | undefined,
  feed: null as InsightsFeedResponse | null,
  seenFeed: new Set<string>(),
};

try {
  const saved = JSON.parse(localStorage.getItem("pawtime-insights") ?? "{}") as Partial<typeof state>;
  if (saved.mode === "live" || saved.mode === "simulated") state.mode = saved.mode;
  if (saved.lang === "en" || saved.lang === "ja") state.lang = saved.lang;
  if (typeof saved.demoOnly === "boolean") state.demoOnly = saved.demoOnly;
} catch {
  // storage may be blocked; defaults are fine
}
const params = new URLSearchParams(location.search);
const qMode = params.get("mode");
if (qMode === "live" || qMode === "simulated") state.mode = qMode;
const qLang = params.get("lang");
if (qLang === "ja" || qLang === "en") state.lang = qLang;

function persist() {
  try {
    localStorage.setItem("pawtime-insights", JSON.stringify({ mode: state.mode, lang: state.lang, demoOnly: state.demoOnly }));
  } catch {
    // ignore
  }
}

const d = (): Dict => I18N[state.lang];
const isSim = () => state.mode === "simulated";
const locale = () => (state.lang === "ja" ? "ja-JP" : "en-US");
const n = (v: number | null | undefined) => fmtN(v, locale());
const pct = fmtPct;
const css = (name: string) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
const suppressedAttr = (v: unknown) => (v == null ? ` title="${esc(d().suppressed)}"` : "");

function chip(): string {
  return isSim() ? `<span class="chip synth">${esc(d().synthChip)}</span>` : `<span class="chip live">${esc(d().liveChip)}</span>`;
}
function card(id: string, title: string, sub: string, body: string, cls = "", extraChip = ""): string {
  return `<section class="card ${cls}" id="${id}"><div class="card-head"><div><h2>${esc(title)}</h2>${sub ? `<p class="sub">${esc(sub)}</p>` : ""}</div><div class="chips">${extraChip}${chip()}</div></div>${body}</section>`;
}
const canvas = (id: string, cls = "") => `<div class="chart ${cls}"><canvas id="${id}" role="img"></canvas></div>`;
const tile = (k: string, v: string, note = "", cls = "", raw: unknown = 0) =>
  `<div class="tile ${cls}"><div class="k">${esc(k)}</div><div class="v"${suppressedAttr(raw)}>${esc(v)}</div>${note ? `<div class="n">${esc(note)}</div>` : ""}</div>`;

// Stamps "Synthetic data" inside every chart in simulated mode.
const watermark: Plugin = {
  id: "watermark",
  afterDraw(chart) {
    if (!isSim()) return;
    const { ctx, chartArea } = chart;
    ctx.save();
    ctx.font = "600 11px Roboto, 'Noto Sans JP', sans-serif";
    ctx.fillStyle = css("--synth-fg");
    ctx.globalAlpha = 0.8;
    ctx.textAlign = "right";
    ctx.textBaseline = "top";
    ctx.fillText(`⚠ ${d().synthWatermark}`, chartArea.right, Math.max(0, chartArea.top - 16));
    ctx.restore();
  },
};

const axisX = () => ({ grid: { display: false }, ticks: { color: css("--text-2"), maxRotation: 0, autoSkipPadding: 12 }, border: { color: css("--line") } });
const axisY = () => ({ grid: { color: css("--line") }, ticks: { color: css("--text-2") }, border: { display: false }, beginAtZero: true });
const pctAxis = () => ({ ...axisY(), min: 0, max: 1, ticks: { color: css("--text-2"), callback: (v: string | number) => `${Math.round(Number(v) * 100)}%` } });
const legend = () => ({ display: true, position: "bottom" as const, labels: { color: css("--text-2"), boxWidth: 12, boxHeight: 12 } });
const pctTooltip = { callbacks: { label: (c: TooltipItem<"bar" | "line">) => `${c.dataset.label ? `${c.dataset.label}: ` : ""}${pct(c.raw as number | null, 1)}` } };
const bar = (label: string, data: (number | null)[], color: string | string[]) => ({
  label, data, backgroundColor: color, borderRadius: 4, borderSkipped: false as const, maxBarThickness: 28, categoryPercentage: 0.8, barPercentage: 0.9,
});

function makeChart(id: string, config: ChartConfiguration) {
  const el = document.getElementById(id) as HTMLCanvasElement | null;
  if (!el) return;
  config.plugins = [...(config.plugins ?? []), watermark];
  config.options = { responsive: true, maintainAspectRatio: false, animation: { duration: 300 }, layout: { padding: { top: 20 } }, ...config.options };
  state.charts.push(new Chart(el, config));
}

function hbar(id: string, labels: string[], data: (number | null)[], color: string, label?: (v: number, i: number) => string) {
  makeChart(id, {
    type: "bar",
    data: { labels, datasets: [bar("", data, color)] },
    options: {
      indexAxis: "y",
      interaction: { mode: "nearest", intersect: true, axis: "y" },
      plugins: { legend: { display: false }, tooltip: { callbacks: { label: (c) => (label ? label(c.raw as number, c.dataIndex) : n(c.raw as number)) } } },
      scales: { x: axisY(), y: { grid: { display: false }, ticks: { color: css("--text-2") }, border: { color: css("--line") } } },
    },
  });
}

function render() {
  const t = d();
  document.documentElement.lang = state.lang;
  for (const el of document.querySelectorAll<HTMLElement>("[data-i18n]")) {
    const key = el.dataset.i18n as keyof Dict;
    const v = t[key];
    if (typeof v === "string") el.textContent = v;
  }
  for (const b of document.querySelectorAll<HTMLElement>("[data-mode]")) b.setAttribute("aria-pressed", String(b.dataset.mode === state.mode));
  for (const b of document.querySelectorAll<HTMLElement>("[data-lang]")) b.setAttribute("aria-pressed", String(b.dataset.lang === state.lang));
  for (const c of state.charts) c.destroy();
  state.charts = [];

  const banner = document.getElementById("banner")!;
  const grid = document.getElementById("grid")!;
  const loaded = state.metrics.get(metricsKey());
  const payload = loaded && !("error" in loaded) ? loaded : null;

  if (isSim()) {
    banner.innerHTML = `<div class="banner synth" role="note"><div aria-hidden="true">⚠</div><div><strong>${esc(t.bannerSimTitle)}</strong>${esc(t.bannerSimBody)}</div></div>`;
  } else {
    const storage = payload?.storage ?? state.feed?.storage;
    const extra = storage === "not_connected" ? `<div class="banner warn" role="alert">${esc(t.storageOff)}</div>` : storage === "local_memory" ? `<p class="note">${esc(t.storageLocal)}</p>` : "";
    banner.innerHTML = `<div class="banner live"><div><span class="pulse"></span></div><div><strong>${esc(t.bannerLiveTitle)}</strong>${esc(t.bannerLiveBody)}</div></div>${extra}`;
  }

  if (!payload) {
    grid.innerHTML = (isSim() ? "" : livePanelHtml()) + (loaded ? `<section class="card wide"><p class="empty">${esc(t.loadError)}</p></section>` : "");
    if (!isSim()) renderFeed();
    return;
  }

  const a = payload.data;
  grid.innerHTML = (isSim() ? "" : livePanelHtml()) + sectionsHtml(a) + pilotHtml();
  if (!isSim()) renderFeed();
  drawCharts(a);
}

function sectionsHtml(a: InsightsAggregate): string {
  const t = d();
  const h = a.headline;
  let html = `<h2 class="section-title">${esc(t.secActivity)}</h2>`;
  const extraNote = h.off_days_without_card_open == null ? "" : fillTemplate(t.noSearchExtra, { x: pct(h.off_days_without_card_open) });
  html += card("c-headline", isSim() ? t.bannerSimTitle : t.bannerLiveTitle, `${a.window.start} – ${a.window.end}`,
    `<div class="tiles">
      ${tile(t.noSearch, pct(h.no_job_search_share), t.noSearchNote, "hero", h.no_job_search_share)}
      ${tile(t.dau, n(h.dau), t.dauNote, "", h.dau)}
      ${tile(t.wau, n(h.wau), t.wauNote, "", h.wau)}
      ${tile(t.mau, n(h.mau), t.mauNote, "", h.mau)}
      ${tile(t.stick, pct(h.stickiness), t.stickNote, "", h.stickiness)}
    </div>${!isSim() && a.installs == null ? `<p class="banner warn">${esc(t.fewPlayers)}</p>` : ""}<p class="note">${esc(extraNote)} ${esc(t.noBenchmark)}</p>`, "wide");
  html += card("c-dau", t.dauTitle, t.dauSub, canvas("ch-dau"));
  html += card("c-mix", t.mixTitle, t.mixSub, canvas("ch-mix"));
  html += card("c-acts", t.actsTitle, t.actsSub, canvas("ch-acts"));
  html += card("c-ret", t.retTitle, t.retSub, retentionTable(a.retention));

  html += `<h2 class="section-title">${esc(t.secJobs)}</h2>`;
  const f = a.funnel;
  html += card("c-funnel", t.funnelTitle, t.funnelSub, canvas("ch-funnel"));
  html += card("c-inv", t.invTitle, t.invSub, canvas("ch-inv", "short") +
    `<div class="mini">${tile(t.invited, pct(f.invited.accept_rate), `${n(f.invited.accepted)} / ${n(f.invited.opened)}`, "", f.invited.accept_rate)}${tile(t.normal, pct(f.normal.accept_rate), `${n(f.normal.accepted)} / ${n(f.normal.opened)}`, "", f.normal.accept_rate)}</div>`);

  html += `<h2 class="section-title">${esc(t.secCare)}</h2>`;
  const w = a.wellbeing;
  html += card("c-well", t.wellTitle, t.wellSub, canvas("ch-well") +
    `<div class="mini">${tile(t.le75Total, pct(w.le75_share), "", "", w.le75_share)}${tile(t.otTotal, pct(w.overtime_rate, 1), "", "", w.overtime_rate)}</div>`);
  html += card("c-cat", t.catTitle, t.catSub, canvas("ch-cat") + `<div class="mini">${tile(t.catTotal, n(w.cat_stops), "", "", w.cat_stops)}</div>`);
  const r = a.reviews;
  html += card("c-rev", t.revTitle, t.revSub,
    `<div class="mini top">${tile(t.respRate, pct(r.response_rate), t.respNote, "", r.response_rate)}${tile(t.stars, r.stars_avg == null ? "—" : `★ ${r.stars_avg.toFixed(2)}`, "", "", r.stars_avg)}</div>` + canvas("ch-tags"), "wide");
  html += afterShiftHtml(a);

  html += `<h2 class="section-title">${esc(t.secSkills)}</h2>`;
  html += card("c-skill", t.skillTitle, t.skillSub, canvas("ch-skill", "short") + `<div class="mini">${tile(t.badge, pct(a.skills.badge_opt_in_rate), t.badgeNote, "", a.skills.badge_opt_in_rate)}</div>`);
  html += card("c-shop", t.shopTitle, t.shopSub, canvas("ch-shop", "short") +
    `<div class="mini">${tile(t.invFlow, `${n(a.shops.invites.opened)} → ${n(a.shops.invites.accepted)}`, "", "", a.shops.invites.accepted)}</div>`);
  return html;
}

function afterShiftHtml(a: InsightsAggregate): string {
  const t = d();
  const rows = a.after_shift.rows;
  const hyp = `<span class="chip hyp">${esc(t.hypothesisChip)}</span>`;
  const hidden = a.after_shift.hidden_shops ? `<p class="note">${esc(fillTemplate(t.afterHidden, { n: String(a.after_shift.hidden_shops) }))}</p>` : "";
  const hypotheses = `<ol class="hyps">${t.hypotheses.map(([hy, va]) => `<li><strong>${esc(t.hypothesisLabel)}:</strong> ${esc(hy ?? "")}<br><span class="muted">${esc(t.validateLabel)}: ${esc(va ?? "")}</span></li>`).join("")}</ol>`;
  if (!rows.length) return card("c-after", t.afterTitle, t.afterSub, `<p class="empty">${esc(t.afterEmpty)}</p>${hidden}${hypotheses}`, "wide", hyp);
  const table = `<div class="table-wrap"><table><thead><tr><th>${esc(t.afterShop)}</th><th>${esc(t.afterWorkers)}</th><th>${esc(t.afterNext)}<br><span class="muted">${esc(t.afterBase)}</span></th><th>${esc(t.afterDelta)}</th><th>${esc(t.afterVisit)}</th><th>${esc(t.afterPass)}</th><th>${esc(t.afterReview)}</th></tr></thead><tbody>${rows
    .map((row) => `<tr><td>${esc(labelOf(t.shops, row.shop))}</td><td>${n(row.workers)}</td><td>${pct(row.next_day_open)}<br><span class="muted">${pct(row.baseline)}</span></td><td class="${(row.delta ?? 0) < 0 ? "neg" : "pos"}">${fmtPp(row.delta)}</td><td>${pct(row.visit_3d)}</td><td${suppressedAttr(row.repeat_pass)}>${pct(row.repeat_pass)}</td><td>${pct(row.review_rate)}</td></tr>`)
    .join("")}</tbody></table></div>`;
  return card("c-after", t.afterTitle, t.afterSub, `<div class="after-grid"><div>${table}${hidden}</div><div><p class="sub">${esc(t.afterChart)}</p>${canvas("ch-after", "short")}</div></div>${hypotheses}`, "wide", hyp);
}

function retentionTable(rows: InsightsAggregate["retention"]): string {
  const t = d();
  if (!rows.length) return `<p class="empty">—</p>`;
  const cell = (v: number | null) =>
    `<td${v == null ? "" : ` class="heat" style="background: color-mix(in oklab, var(--s1) ${Math.round(v * 70)}%, transparent)"`}${suppressedAttr(v)}>${pct(v)}</td>`;
  return `<div class="table-wrap"><table><thead><tr><th>${esc(t.cohort)}</th><th>${esc(t.size)}</th><th>D1</th><th>D7</th><th>D30</th></tr></thead><tbody>${rows
    .map((r) => `<tr><td>${esc(r.cohort)}</td><td${suppressedAttr(r.size)}>${n(r.size)}</td>${cell(r.d1)}${cell(r.d7)}${cell(r.d30)}</tr>`)
    .join("")}</tbody></table></div>`;
}

function pilotHtml(): string {
  const t = d();
  const list = (arr: readonly string[]) => `<ol>${arr.map((x) => `<li>${esc(x)}</li>`).join("")}</ol>`;
  return `<section class="card wide pilot"><div class="card-head"><div><h2>${esc(t.pilotTitle)}</h2><p class="sub">${esc(t.pilotSub)}</p></div></div>
    <div class="cols"><div><h3>${esc(t.pilotScope)}</h3>${list(t.pilotScopeBody)}</div><div><h3>${esc(t.pilotMeasure)}</h3>${list(t.pilotMeasureBody)}</div><div><h3>${esc(t.pilotThresh)}</h3>${list(t.pilotThreshBody)}</div></div></section>`;
}

function drawCharts(a: InsightsAggregate) {
  const t = d();
  const s1 = css("--s1"), s2 = css("--s2"), s3 = css("--s3"), neg = css("--neg");
  makeChart("ch-dau", {
    type: "line",
    data: { labels: a.daily.map((x) => x.day), datasets: [{ label: t.dau, data: a.daily.map((x) => x.dau), borderColor: s1, backgroundColor: s1, borderWidth: 2, pointRadius: a.daily.length <= 14 ? 3 : 0, pointHoverRadius: 4, tension: 0.25 }] },
    options: { interaction: { mode: "index", intersect: false }, plugins: { legend: { display: false } }, scales: { x: axisX(), y: axisY() } },
  });
  const mix = a.weekly_day_type;
  const stackBar = (label: string, data: (number | null)[], color: string) => ({ ...bar(label, data, color), stack: "a", borderColor: css("--surface"), borderWidth: { top: 2 } });
  makeChart("ch-mix", {
    type: "bar",
    data: { labels: mix.map((x) => x.week), datasets: [stackBar(t.work, mix.map((x) => x.work), s1), stackBar(t.off, mix.map((x) => x.off), s2), stackBar(t.no_shift, mix.map((x) => x.no_shift), s3)] },
    options: { interaction: { mode: "index", intersect: false }, plugins: { legend: legend(), tooltip: pctTooltip }, scales: { x: { ...axisX(), stacked: true }, y: { ...pctAxis(), stacked: true } } },
  });
  hbar("ch-acts", a.off_day_activities.map((x) => labelOf(t.offDayEvents, x.key)), a.off_day_activities.map((x) => x.value), s1);
  const f = a.funnel;
  const steps = ["shown", "opened", "accepted", "shift_done", "reviewed"] as const;
  const values = steps.map((k) => f[k]);
  hbar("ch-funnel", steps.map((k) => t[k]), values, s1, (v, i) => {
    const prev = i > 0 ? values[i - 1] : null;
    return `${n(v)}${prev && v != null ? `  (${pct(v / prev)})` : ""}`;
  });
  makeChart("ch-inv", {
    type: "bar",
    data: { labels: [t.invited, t.normal], datasets: [bar("", [f.invited.accept_rate, f.normal.accept_rate], [s2, s1])] },
    options: { plugins: { legend: { display: false }, tooltip: pctTooltip }, scales: { x: axisX(), y: pctAxis() } },
  });
  const ww = a.wellbeing.weekly;
  const line = (label: string, data: (number | null)[], color: string) => ({ label, data, borderColor: color, backgroundColor: color, borderWidth: 2, pointRadius: 3, tension: 0.25 });
  makeChart("ch-well", {
    type: "line",
    data: { labels: ww.map((x) => x.week), datasets: [line(t.le75, ww.map((x) => x.le75_share), s1), line(t.overtime, ww.map((x) => x.overtime_rate), s2)] },
    options: { interaction: { mode: "index", intersect: false }, plugins: { legend: legend(), tooltip: pctTooltip }, scales: { x: axisX(), y: pctAxis() } },
  });
  makeChart("ch-cat", {
    type: "bar",
    data: { labels: ww.map((x) => x.week), datasets: [bar(t.catTotal, ww.map((x) => x.cat_stops), s3)] },
    options: { plugins: { legend: { display: false } }, scales: { x: axisX(), y: axisY() } },
  });
  hbar("ch-tags", a.reviews.tags.map((x) => labelOf(t.tags, x.key)), a.reviews.tags.map((x) => x.value), s3);
  const rows = a.after_shift.rows;
  if (rows.length) {
    const deltas = rows.map((r) => (r.delta == null ? null : r.delta * 100));
    makeChart("ch-after", {
      type: "bar",
      data: { labels: rows.map((r) => labelOf(t.shops, r.shop)), datasets: [bar(t.afterDelta, deltas, deltas.map((v) => ((v ?? 0) < 0 ? neg : s1)))] },
      options: {
        indexAxis: "y",
        plugins: { legend: { display: false }, tooltip: { callbacks: { label: (c) => fmtPp((c.raw as number) / 100) } } },
        scales: { x: { ...axisY(), beginAtZero: false, suggestedMin: -10, suggestedMax: 10, ticks: { color: css("--text-2"), callback: (v) => `${Number(v) > 0 ? "+" : ""}${v} pt` } }, y: { grid: { display: false }, ticks: { color: css("--text-2") } } },
      },
    });
  }
  hbar("ch-skill", a.skills.practice_by_role.map((x) => labelOf(t.roles, x.key)), a.skills.practice_by_role.map((x) => x.value), s1);
  hbar("ch-shop", a.shops.visits.map((x) => labelOf(t.shops, x.key)), a.shops.visits.map((x) => x.value), s2);
}

// ---- Live now ------------------------------------------------------------------
function livePanelHtml(): string {
  const t = d();
  return `<section class="card wide live-panel" id="c-live"><div class="card-head"><div><h2><span class="pulse"></span>${esc(t.liveNow)}</h2><p class="sub">${esc(t.liveNowSub)}</p></div>
    <label class="toggle"><input type="checkbox" id="demo-only" ${state.demoOnly ? "checked" : ""}/> ${esc(t.demoOnly)}</label></div>
    <div class="counters" id="live-counters"></div><ul class="feed" id="live-feed" aria-live="polite"></ul></section>`;
}

function renderFeed() {
  const t = d();
  const box = document.getElementById("live-feed");
  const counters = document.getElementById("live-counters");
  const toggle = document.getElementById("demo-only") as HTMLInputElement | null;
  if (toggle) {
    toggle.onchange = () => {
      state.demoOnly = toggle.checked;
      persist();
      state.seenFeed.clear();
      state.feed = null;
      renderFeed();
      void refresh();
      void pollFeed();
    };
  }
  if (!box || !counters) return;
  const fd = state.feed;
  const c = fd?.counts ?? {};
  const count = (k: string) => (fd ? n(c[k] ?? 0) : "—");
  counters.innerHTML = [
    tile(t.players, fd ? n(fd.players) : "—"),
    tile(t.accepts, count("job_accept")),
    tile(t.catStops, count("cat_tired_stop")),
    tile(t.shopVisits, count("shop_island_visit")),
  ].join("");
  if (!fd || !fd.items.length) {
    box.innerHTML = `<li class="empty">${esc(fd?.storage === "not_connected" ? t.storageOff : t.feedEmpty)}</li>`;
    return;
  }
  const firstPaint = state.seenFeed.size === 0;
  const nowS = Math.round(Date.now() / 1000);
  box.innerHTML = fd.items
    .map((it) => {
      const key = `${it.type}|${JSON.stringify(it.props)}|${Math.round((nowS - it.ago_s) / 5)}`;
      const fresh = !firstPaint && !state.seenFeed.has(key);
      state.seenFeed.add(key);
      const inv = it.props.invited === true ? `<span class="demo-tag">${esc(t.invitedTag)}</span>` : "";
      const demo = it.demo ? `<span class="demo-tag">demo</span>` : "";
      const ago = it.ago_s < 60 ? `${it.ago_s} ${t.agoS}` : `${Math.floor(it.ago_s / 60)} ${t.agoM}`;
      return `<li class="${fresh ? "new" : ""}"><span class="ic" aria-hidden="true">${ICONS[it.type] ?? "•"}</span><span class="txt">${esc(feedText(t, it.type, it.props))}${inv}${demo}</span><span class="ago">${esc(ago)}</span></li>`;
    })
    .join("");
}

async function pollFeed() {
  if (isSim()) return;
  try {
    const r = await fetch(`${API}/v1/insights/feed${state.demoOnly ? "?demo=1" : ""}`, { cache: "no-store" });
    if (r.ok) state.feed = (await r.json()) as InsightsFeedResponse;
  } catch {
    // keep the last feed on a transient error
  }
  renderFeed();
}

const metricsKey = () => (isSim() ? "simulated" : `live:${state.demoOnly}`);

async function refresh() {
  const key = metricsKey();
  const url = isSim() ? `${API}/v1/insights/metrics?mode=simulated` : `${API}/v1/insights/metrics?mode=live${state.demoOnly ? "&demo=1" : ""}`;
  try {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) throw new Error(String(r.status));
    state.metrics.set(key, (await r.json()) as InsightsMetricsResponse);
  } catch {
    state.metrics.set(key, { error: true });
  }
  if (key === metricsKey()) render();
}

function setMode(mode: Mode) {
  state.mode = mode;
  persist();
  window.clearInterval(state.feedTimer);
  render();
  void refresh();
  if (mode === "live") {
    void pollFeed();
    state.feedTimer = window.setInterval(() => {
      if (!document.hidden) void pollFeed();
    }, 4000);
  }
}

document.addEventListener("click", (e) => {
  const target = e.target as HTMLElement;
  const m = target.closest<HTMLElement>("[data-mode]");
  if (m?.dataset.mode === "live" || m?.dataset.mode === "simulated") setMode(m.dataset.mode);
  const l = target.closest<HTMLElement>("[data-lang]");
  if (l?.dataset.lang === "en" || l?.dataset.lang === "ja") {
    state.lang = l.dataset.lang;
    persist();
    render();
  }
});
// Re-pull live aggregates every 30 s so new demo players also reach the charts.
window.setInterval(() => {
  if (!isSim() && !document.hidden) void refresh();
}, 30_000);
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", render);
setMode(state.mode);
