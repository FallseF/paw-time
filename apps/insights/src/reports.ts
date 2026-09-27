// Reports page: the detailed product-use charts from the first dashboard (daily use, jobs,
// wellbeing, after-shift signals, chat tags, what a shop would see, pilot proposal).
import type { InsightsAggregate } from "@paw-time/api-contracts";
import { BarController, BarElement, CategoryScale, Chart, Legend, LinearScale, LineController, LineElement, PointElement, ScatterController, Tooltip, type ChartConfiguration, type Plugin, type TooltipItem } from "chart.js";
import { esc, fillTemplate, fmtN, fmtPct, fmtPp, labelOf } from "./format";
import type { Dict } from "./i18n";

Chart.register(BarController, BarElement, CategoryScale, LinearScale, LineController, LineElement, PointElement, ScatterController, Tooltip, Legend);

export interface ReportCtx {
  d: () => Dict;
  isSim: () => boolean;
  locale: () => string;
  charts: Chart[];
}
let ctx: ReportCtx;
export function initReports(c: ReportCtx) {
  ctx = c;
}
const d = () => ctx.d();
const isSim = () => ctx.isSim();
const n = (v: number | null | undefined) => fmtN(v, ctx.locale());
const pct = fmtPct;
export const css = (name: string) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
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
export const watermark: Plugin = {
  id: "watermark",
  afterDraw(chart) {
    if (!isSim()) return;
    const { ctx, chartArea } = chart;
    ctx.save();
    ctx.font = "500 11px 'IBM Plex Sans', 'Noto Sans JP', sans-serif";
    ctx.fillStyle = css("--synth-fg");
    ctx.globalAlpha = 0.8;
    ctx.textAlign = "right";
    ctx.textBaseline = "top";
    ctx.fillText(d().synthWatermark.toUpperCase(), chartArea.right, Math.max(0, chartArea.top - 16));
    ctx.restore();
  },
};

export const axisX = () => ({ grid: { display: false }, ticks: { color: css("--text-2"), maxRotation: 0, autoSkipPadding: 12 }, border: { color: css("--line") } });
export const axisY = () => ({ grid: { color: css("--line") }, ticks: { color: css("--text-2") }, border: { display: false }, beginAtZero: true });
export const pctAxis = () => ({ ...axisY(), min: 0, max: 1, ticks: { color: css("--text-2"), callback: (v: string | number) => `${Math.round(Number(v) * 100)}%` } });
export const legend = () => ({ display: true, position: "bottom" as const, labels: { color: css("--text-2"), boxWidth: 12, boxHeight: 12 } });
export const pctTooltip = { callbacks: { label: (c: TooltipItem<"bar" | "line">) => `${c.dataset.label ? `${c.dataset.label}: ` : ""}${pct(c.raw as number | null, 1)}` } };
export const bar = (label: string, data: (number | null)[], color: string | string[]) => ({
  label, data, backgroundColor: color, borderRadius: 4, borderSkipped: false as const, maxBarThickness: 28, categoryPercentage: 0.8, barPercentage: 0.9,
});

export function makeChart(id: string, config: ChartConfiguration) {
  const el = document.getElementById(id) as HTMLCanvasElement | null;
  if (!el) return;
  config.plugins = [...(config.plugins ?? []), watermark];
  config.options = { responsive: true, maintainAspectRatio: false, animation: { duration: 300 }, layout: { padding: { top: 20 } }, ...config.options };
  ctx.charts.push(new Chart(el, config));
}

export function hbar(id: string, labels: string[], data: (number | null)[], color: string, label?: (v: number, i: number) => string) {
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


export function reportsHtml(a: InsightsAggregate): string {
  return `<div class="grid">${sectionsHtml(a)}${chatHtml(a)}${shopViewHtml(a)}${pilotHtml()}</div>`;
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

// Internal only: chat tags. Never shown to shops as-is.
function chatHtml(a: InsightsAggregate): string {
  const t = d();
  const c = a.chat;
  const internal = `<span class="chip internal">${esc(t.internalChip)}</span>`;
  const hyp = `<span class="chip hyp">${esc(t.hypothesisChip)}</span>`;
  let html = `<h2 class="section-title">${esc(t.secChat)}</h2>`;
  html += card("c-chat", t.chatTitle, t.chatSub,
    `<div class="tiles">
      ${tile(t.chatOpens, n(c.opens), t.chatOpensNote, "", c.opens)}
      ${tile(t.chatters, n(c.chatters), "", "", c.chatters)}
      ${tile(t.chatSignals, n(c.signals), t.chatSignalsNote, "", c.signals)}
      ${tile(t.anonIssues, n(c.anon_issues), t.anonIssuesNote, "", c.anon_issues)}
    </div><p class="sub">${esc(t.topicsTitle)} · ${esc(t.topicsSub)}</p>${c.topics.length ? canvas("ch-topics", "tall") : `<p class="empty">—</p>`}`, "wide", internal);
  const fitCell = (r: InsightsAggregate["chat"]["preferences"][number]) =>
    r.key.startsWith("prefer_")
      ? `<td${suppressedAttr(r.fit_share)}>${pct(r.fit_share)}<br><span class="muted">${esc(t.prefBase)} ${pct(r.baseline_fit_share)}</span></td>`
      : `<td class="muted">${esc(t.prefFitNA)}</td>`;
  const prefRows = c.preferences
    .map((r) => `<tr><td>${esc(labelOf(t.topics, r.key))}</td><td${suppressedAttr(r.workers)}>${n(r.workers)}</td><td${suppressedAttr(r.accept_rate)}>${pct(r.accept_rate)}<br><span class="muted">${esc(t.prefBase)} ${pct(r.baseline_accept_rate)}</span></td>${fitCell(r)}</tr>`)
    .join("");
  html += card("c-pref", t.prefTitle, t.prefSub,
    `<div class="table-wrap"><table><thead><tr><th>${esc(t.prefTag)}</th><th>${esc(t.prefWorkers)}</th><th>${esc(t.prefAccept)}</th><th>${esc(t.prefFit)}</th></tr></thead><tbody>${prefRows}</tbody></table></div>
    <ol class="hyps"><li><strong>${esc(t.hypothesisLabel)}:</strong> ${esc(t.prefHyp)}</li></ol>`, "", hyp + internal);
  html += card("c-faq", t.faqTitle, t.faqSub, canvas("ch-faq", "short") + `<p class="sub">${esc(t.msgTitle)} · ${esc(t.msgSub)}</p>` + canvas("ch-msg", "short"), "", internal);
  return html;
}

// What we would provide to an employer: consented anonymous issues + positive topics, 5+ workers each.
function shopViewHtml(a: InsightsAggregate): string {
  const t = d();
  const sv = a.shop_view;
  const period = fillTemplate(t.shopViewPeriod, { start: sv.period.start, end: sv.period.end });
  const list = (items: { key: string; workers: number }[], cls: string) =>
    items.length
      ? `<ul class="sv-list ${cls}">${items.map((x) => `<li><span>${esc(labelOf(t.topics, x.key))}</span><span class="sv-n">${esc(fillTemplate(t.workersN, { n: n(x.workers) }))}</span></li>`).join("")}</ul>`
      : `<p class="muted">${esc(t.shopViewNone)}</p>`;
  const body = sv.shops.length
    ? `<div class="sv-grid">${sv.shops
        .map((s) => `<div class="sv-shop"><h3>${esc(labelOf(t.shops, s.shop))}</h3><p class="muted">${esc(period)}</p><h4>${esc(t.shopViewPositives)}</h4>${list(s.positives, "pos")}<h4>${esc(t.shopViewIssues)}</h4>${list(s.issues, "neg")}</div>`)
        .join("")}</div>`
    : `<p class="empty">${esc(t.shopViewEmpty)}</p>`;
  return `<h2 class="section-title">${esc(t.secShop)}</h2>` +
    card("c-shopview", t.shopViewTitle, t.shopViewSub, `${body}<p class="note">${esc(t.shopViewNever)}</p>`, "wide shop-view");
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

export function drawReportCharts(a: InsightsAggregate) {
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
  const topicColor = (k: string) => (["liked_team", "liked_customers"].includes(k) ? s3 : k.startsWith("want_") || k.startsWith("prefer_") ? s1 : s2);
  const topicKeys = a.chat.topics.map((x) => x.key);
  if (topicKeys.length) {
    makeChart("ch-topics", {
      type: "bar",
      data: { labels: topicKeys.map((k) => labelOf(t.topics, k)), datasets: [bar("", a.chat.topics.map((x) => x.value), topicKeys.map(topicColor))] },
      options: {
        indexAxis: "y",
        plugins: { legend: { display: false }, tooltip: { callbacks: { label: (c) => n(c.raw as number) } } },
        scales: { x: axisY(), y: { grid: { display: false }, ticks: { color: css("--text-2") }, border: { color: css("--line") } } },
      },
    });
  }
  hbar("ch-faq", a.chat.faq.map((x) => labelOf(t.faqTopics, x.key)), a.chat.faq.map((x) => x.value), s1);
  hbar("ch-msg", a.chat.shop_messages.map((x) => labelOf(t.msgKinds, x.key)), a.chat.shop_messages.map((x) => x.value), s3);
  hbar("ch-skill", a.skills.practice_by_role.map((x) => labelOf(t.roles, x.key)), a.skills.practice_by_role.map((x) => x.value), s1);
  hbar("ch-shop", a.shops.visits.map((x) => labelOf(t.shops, x.key)), a.shops.visits.map((x) => x.value), s2);
}

