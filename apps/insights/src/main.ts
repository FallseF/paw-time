// Paw Time Insights — an explorer over aggregated work-cycle signals for Recruit teams.
// Saved views and tables of shops, listings, supply slots and shop-weeks (never workers),
// a detail panel with the signals behind each row, a pilot calculator, a data map, the data
// policy, the detailed report charts and a live activity drawer for the demo.
import type { InsightsAggregate, InsightsFeedResponse, InsightsMetricsResponse } from "@paw-time/api-contracts";
import type { Chart } from "chart.js";
import { CALC_DEFAULTS_BY_CURRENCY, pilotValue, type CalcInput } from "./calc";
import { currencyOf, currencySymbol, esc, feedText, fillTemplate, fmtMoney, type Currency } from "./format";
import { I18N, type Dict, type Lang } from "./i18n";
import { UI, type UiDict } from "./i18n-ui";
import { launchParams } from "./launch";
import { skinDict, skinUi } from "./skin";
import {
  applyQuery, COLUMNS, DEFAULT_VISIBLE, listingRows, shopRows, signalRows, supplyRows, toCsv, VIEWS,
  type Column, type Filter, type Query, type Row, type SavedView, type TableId, type Value, type ViewId,
} from "./model";
import { axisX, axisY, bar, css, drawReportCharts, initReports, legend, makeChart, pctAxis, pctTooltip, reportsHtml } from "./reports";

type Mode = "simulated" | "live";
type Loaded = InsightsMetricsResponse | { error: true };
type Route = { kind: "view"; id: ViewId } | { kind: "table"; id: TableId } | { kind: "page"; id: "pilot" | "map" | "policy" | "reports" };
interface TableUi {
  query: Query;
  columns: string[];
}

const API = (document.querySelector('meta[name="paw-time-api"]') as HTMLMetaElement | null)?.content ?? "";
const FEEDS_BY_TABLE: Record<TableId, string[]> = {
  shops: ["air_work", "indeed"],
  listings: ["townwork", "air_shift"],
  supply: ["air_shift", "townwork"],
  signals: ["air_work", "indeed"],
};

const state = {
  mode: "simulated" as Mode,
  lang: "en" as Lang,
  demoOnly: false,
  route: { kind: "view", id: "at-risk" } as Route,
  density: "comfortable" as "comfortable" | "compact",
  metrics: new Map<string, Loaded>(),
  charts: [] as Chart[],
  tables: new Map<string, TableUi>(),
  selected: null as string | null,
  liveOpen: false,
  navOpen: false,
  feed: null as InsightsFeedResponse | null,
  feedTimer: 0 as number | undefined,
  seenFeed: new Set<string>(),
  heatArea: "all",
  // One set of calculator inputs per currency, so switching language keeps each set's edits.
  calc: { USD: { ...CALC_DEFAULTS_BY_CURRENCY.USD }, JPY: { ...CALC_DEFAULTS_BY_CURRENCY.JPY } } as Record<Currency, CalcInput>,
  popover: null as null | "filter" | "columns",
};

try {
  const saved = JSON.parse(localStorage.getItem("pawtime-insights") ?? "{}") as Record<string, unknown>;
  if (saved.mode === "live" || saved.mode === "simulated") state.mode = saved.mode;
  if (saved.lang === "en" || saved.lang === "ja") state.lang = saved.lang;
  if (typeof saved.demoOnly === "boolean") state.demoOnly = saved.demoOnly;
  if (saved.density === "compact" || saved.density === "comfortable") state.density = saved.density;
} catch {
  // storage may be blocked; defaults are fine
}
const launch = launchParams(location.search);
if (launch.mode) state.mode = launch.mode;
if (launch.lang) state.lang = launch.lang;
if (launch.demoOnly !== undefined) state.demoOnly = launch.demoOnly;
if (launch.liveOpen) state.liveOpen = true;

function persist() {
  try {
    localStorage.setItem("pawtime-insights", JSON.stringify({ mode: state.mode, lang: state.lang, demoOnly: state.demoOnly, density: state.density }));
  } catch {
    // ignore
  }
}

// The simulated pilot wears a locale skin (en: San Francisco, ja: Japan); live keeps the game's names.
const SKIN_D = { en: skinDict(I18N.en, "en"), ja: skinDict(I18N.ja, "ja") } as Record<Lang, Dict>;
const SKIN_U = { en: skinUi(UI.en, "en"), ja: skinUi(UI.ja, "ja") } as Record<Lang, UiDict>;
const isSim = () => state.mode === "simulated";
const d = (): Dict => (isSim() ? SKIN_D : I18N)[state.lang];
const u = (): UiDict => (isSim() ? SKIN_U : UI)[state.lang];
const locale = () => (state.lang === "ja" ? "ja-JP" : "en-US");
const n = (v: number | null | undefined, digits = 0) => (v == null ? "—" : new Intl.NumberFormat(locale(), { maximumFractionDigits: digits, minimumFractionDigits: digits }).format(v));
const pct = (v: number | null | undefined) => (v == null ? "—" : `${(v * 100).toFixed(Math.abs(v) < 0.1 && v !== 0 ? 1 : 0)}%`);
/** Money follows the language (en: USD, ja: JPY) in both modes. */
const currency = (): Currency => currencyOf(state.lang);
const money = (v: number, cents = false) => fmtMoney(v, currency(), { cents });
/** Wages carry the currency of the payload they came from. */
const wage = (v: number) => fmtMoney(v, payload()?.data.recruit?.pay?.currency ?? currency(), { cents: true, perHour: u().perHour });
const lbl = (group: string | undefined, key: string): string => {
  if (!group) return key;
  const t = u() as unknown as Record<string, Record<string, string>>;
  const dd = d() as unknown as Record<string, Record<string, string>>;
  return t[group]?.[key] ?? dd[group]?.[key] ?? key;
};

initReports({ d, isSim, locale, charts: state.charts });

// ---- Routing -----------------------------------------------------------------------

function parseRoute(): Route {
  const [, kind, id] = location.hash.replace(/^#\/?/, "#/").split("/");
  if (kind === "views" && VIEWS.some((v) => v.id === id)) return { kind: "view", id: id as ViewId };
  if (kind === "tables" && id && id in COLUMNS) return { kind: "table", id: id as TableId };
  if (kind === "pages" && (id === "pilot" || id === "map" || id === "policy" || id === "reports")) return { kind: "page", id };
  return { kind: "view", id: "at-risk" };
}
const hrefOf = (r: Route) => `#/${r.kind === "view" ? "views" : r.kind === "table" ? "tables" : "pages"}/${r.id}`;
const sameRoute = (a: Route, b: Route) => a.kind === b.kind && a.id === b.id;

function tableUi(key: string, view?: SavedView): TableUi {
  let t = state.tables.get(key);
  if (!t) {
    t = view
      ? { query: structuredClone(view.query), columns: [...view.columns] }
      : { query: { search: "", filters: [], sort: null }, columns: [...DEFAULT_VISIBLE[key as TableId]] };
    state.tables.set(key, t);
  }
  return t;
}

// ---- Data ----------------------------------------------------------------------------

const metricsKey = () => (isSim() ? `simulated:${state.lang}` : `live:${state.demoOnly}`);
function payload(): InsightsMetricsResponse | null {
  const m = state.metrics.get(metricsKey());
  return m && !("error" in m) ? m : null;
}
function rowsFor(table: TableId, a: InsightsAggregate): Row[] {
  if (table === "shops") return shopRows(a);
  if (table === "listings") return listingRows(a);
  if (table === "supply") return supplyRows(a);
  return signalRows(a);
}

async function refresh() {
  const key = metricsKey();
  const url = isSim() ? `${API}/v1/insights/metrics?mode=simulated&lang=${state.lang}` : `${API}/v1/insights/metrics?mode=live${state.demoOnly ? "&demo=1" : ""}`;
  try {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) throw new Error(String(r.status));
    state.metrics.set(key, (await r.json()) as InsightsMetricsResponse);
  } catch {
    state.metrics.set(key, { error: true });
  }
  if (key === metricsKey()) render();
}

async function pollFeed() {
  try {
    const r = await fetch(`${API}/v1/insights/feed${state.demoOnly ? "?demo=1" : ""}`, { cache: "no-store" });
    if (r.ok) state.feed = (await r.json()) as InsightsFeedResponse;
  } catch {
    // keep the last feed on a transient error
  }
  renderLive();
  renderLiveButton();
}

// ---- Formatting cells -------------------------------------------------------------------

const NA = () => `<span class="na" title="${esc(d().suppressed)}">—</span>`;

function delta(v: number | null, better: "up" | "down" | undefined, text: string): string {
  if (v == null) return NA();
  const good = better === "down" ? v < 0 : v > 0;
  const cls = Math.abs(v) < 1e-9 ? "flat" : good ? "good" : "bad";
  const arrow = v > 0 ? "▲" : v < 0 ? "▼" : "";
  return `<span class="delta ${cls}">${arrow ? `<span class="arr" aria-hidden="true">${arrow}</span>` : ""}${esc(text)}</span>`;
}
const signed = (x: number, digits: number) => `${x > 0 ? "+" : x < 0 ? "−" : "±"}${Math.abs(x).toFixed(digits)}`;

export function sparkline(values: (number | null)[], opts: { w?: number; h?: number; second?: (number | null)[] | undefined; zero?: boolean; cls?: string } = {}): string {
  const w = opts.w ?? 96;
  const h = opts.h ?? 24;
  const all = [...values, ...(opts.second ?? [])].filter((x): x is number => x != null);
  if (all.length < 2) return `<span class="spark-empty">${NA()}</span>`;
  let lo = Math.min(...all, opts.zero ? 0 : Infinity);
  let hi = Math.max(...all, opts.zero ? 0 : -Infinity);
  if (hi - lo < 1e-9) { hi += 0.5; lo -= 0.5; }
  const x = (i: number) => (values.length <= 1 ? 0 : (i / (values.length - 1)) * (w - 4) + 2);
  const y = (v: number) => h - 3 - ((v - lo) / (hi - lo)) * (h - 6);
  const path = (vs: (number | null)[]) => {
    let dd = "";
    let pen = false;
    vs.forEach((v, i) => {
      if (v == null) { pen = false; return; }
      dd += `${pen ? "L" : "M"}${x(i).toFixed(1)},${y(v).toFixed(1)}`;
      pen = true;
    });
    return dd;
  };
  const lastI = values.map((v, i) => (v == null ? -1 : i)).filter((i) => i >= 0).pop() ?? 0;
  const zero = opts.zero && lo < 0 && hi > 0 ? `<line x1="0" x2="${w}" y1="${y(0).toFixed(1)}" y2="${y(0).toFixed(1)}" class="sp-zero"/>` : "";
  const second = opts.second ? `<path d="${path(opts.second)}" class="sp-2"/>` : "";
  return `<svg class="spark ${opts.cls ?? ""}" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" aria-hidden="true">${zero}${second}<path d="${path(values)}" class="sp-1"/><circle cx="${x(lastI).toFixed(1)}" cy="${y(values[lastI]!).toFixed(1)}" r="2.5" class="sp-dot"/></svg>`;
}

function cellHtml(c: Column, v: Value | undefined): string {
  if (c.fmt === "spark") {
    const arr = (v ?? []) as (number | null)[];
    return sparkline(arr, { zero: c.key === "trend" });
  }
  if (c.fmt === "tags") {
    const arr = (v ?? []) as string[];
    return arr.length ? arr.map((x) => `<span class="tag">${esc(lbl(c.group, x))}</span>`).join("") : `<span class="muted">—</span>`;
  }
  if (v == null) return NA();
  switch (c.fmt) {
    case "enum":
      return esc(lbl(c.group, String(v)));
    case "text":
      return esc(String(v));
    case "int":
      return n(v as number);
    case "num1":
      return n(v as number, 1);
    case "pct":
      return pct(v as number);
    case "pp":
      return delta(v as number, c.better, `${signed((v as number) * 100, 1)} ${u().pts}`);
    case "stars":
      return `${(v as number).toFixed(2)}`;
    case "wage":
      return esc(wage(v as number));
    case "dstars":
      return delta(v as number, c.better, `${signed(v as number, 2)}★`);
    case "risk":
      return `<span class="status risk-${esc(String(v))}"><span class="dot"></span>${esc(lbl("risk", String(v)))}</span>`;
    case "status":
      return `<span class="status st-${esc(String(v))}"><span class="dot"></span>${esc(lbl(c.group, String(v)))}</span>`;
    default:
      return esc(String(v));
  }
}
function cellText(c: Column, v: Value | undefined): string {
  if (v == null) return "";
  if (Array.isArray(v)) return c.fmt === "tags" ? v.map((x) => lbl(c.group, String(x))).join(" ") : "";
  if (c.group || c.fmt === "risk") return lbl(c.fmt === "risk" ? "risk" : c.group, String(v));
  return String(v);
}
const isNumeric = (c: Column) => ["int", "num1", "pct", "pp", "stars", "dstars", "wage"].includes(c.fmt);
const colLabel = (c: Column) => u().cols[c.key] ?? c.key;

// ---- Shell -------------------------------------------------------------------------------

const ICON: Record<string, string> = {
  view: `<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M2 4h12M2 8h8M2 12h5" /></svg>`,
  table: `<svg viewBox="0 0 16 16" aria-hidden="true"><rect x="2" y="3" width="12" height="10" rx="1.5"/><path d="M2 7h12M6.5 7v6"/></svg>`,
  pilot: `<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M3 13V8M8 13V4M13 13V6"/></svg>`,
  map: `<svg viewBox="0 0 16 16" aria-hidden="true"><circle cx="4" cy="4" r="1.6"/><circle cx="4" cy="12" r="1.6"/><circle cx="12" cy="8" r="1.6"/><path d="M5.5 4.6 10.5 7.4M5.5 11.4l5-2.8"/></svg>`,
  policy: `<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 2 13 4v4c0 3-2.2 5-5 6-2.8-1-5-3-5-6V4z"/></svg>`,
  reports: `<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M2 13h12M4 10l3-3 2 2 4-4"/></svg>`,
};

function navHtml(): string {
  const t = u();
  const item = (r: Route, label: string, icon: string) =>
    `<a class="nav-item${sameRoute(r, state.route) ? " active" : ""}" href="${hrefOf(r)}"${sameRoute(r, state.route) ? ' aria-current="page"' : ""}>${icon}<span>${esc(label)}</span></a>`;
  return `<div class="brand"><span class="logo" aria-hidden="true"></span><span class="brand-name">Paw Time</span><span class="brand-product">${esc(t.product)}</span></div>
    <nav aria-label="${esc(t.navViews)}">
      <div class="nav-h">${esc(t.navViews)}</div>
      ${VIEWS.map((v) => item({ kind: "view", id: v.id }, t.views[v.id] ?? v.id, ICON.view!)).join("")}
      <div class="nav-h">${esc(t.navTables)}</div>
      ${(Object.keys(COLUMNS) as TableId[]).map((id) => item({ kind: "table", id }, t.tables[id] ?? id, ICON.table!)).join("")}
      <div class="nav-h">${esc(t.navPages)}</div>
      ${(["pilot", "map", "policy", "reports"] as const).map((id) => item({ kind: "page", id }, t.pages[id] ?? id, ICON[id]!)).join("")}
    </nav>`;
}

function titleOf(r: Route): string {
  const t = u();
  return r.kind === "view" ? t.views[r.id]! : r.kind === "table" ? t.tables[r.id]! : t.pages[r.id]!;
}

function renderShell() {
  const t = u();
  document.documentElement.lang = state.lang;
  document.title = `${titleOf(state.route)} · Paw Time ${t.product}`;
  document.getElementById("nav")!.innerHTML = navHtml();
  document.getElementById("nav")!.classList.toggle("open", state.navOpen);
  for (const b of document.querySelectorAll<HTMLElement>("[data-mode]")) b.setAttribute("aria-pressed", String(b.dataset.mode === state.mode));
  for (const b of document.querySelectorAll<HTMLElement>("[data-lang]")) b.setAttribute("aria-pressed", String(b.dataset.lang === state.lang));
  for (const el of document.querySelectorAll<HTMLElement>("[data-ui]")) {
    const v = (t as unknown as Record<string, unknown>)[el.dataset.ui!];
    if (typeof v === "string") el.textContent = v;
  }
  for (const el of document.querySelectorAll<HTMLElement>("[data-i18n]")) {
    const v = (d() as unknown as Record<string, unknown>)[el.dataset.i18n!];
    if (typeof v === "string") el.textContent = v;
  }
  document.getElementById("banner")!.innerHTML = isSim()
    ? `<div class="banner synth" role="note"><span class="badge synth">${esc(t.synthetic)}</span><span>${esc(t.bannerSim)}</span></div>`
    : `<div class="banner live" role="note"><span class="badge live"><span class="pulse"></span>${esc(t.liveBadge)}</span><span>${esc(t.bannerLive)}</span>${storageNote()}</div>`;
  document.body.classList.toggle("nav-open", state.navOpen);
  renderLiveButton();
}
function storageNote(): string {
  const s = payload()?.storage ?? state.feed?.storage;
  if (s === "not_connected") return `<strong class="warn-text">${esc(d().storageOff)}</strong>`;
  return "";
}

function modeBadge(): string {
  const t = u();
  return isSim() ? `<span class="badge synth">${esc(t.synthetic)}</span>` : `<span class="badge live"><span class="pulse"></span>${esc(t.liveBadge)}</span>`;
}

// ---- KPI bar -------------------------------------------------------------------------------

function kpisHtml(a: InsightsAggregate | null): string {
  const t = u();
  const k = a?.recruit?.kpis;
  const keys = ["dau_mau", "off_day_share", "fill_rate", "next_day_return", "active_shops"] as const;
  return keys
    .map((key) => {
      const v = k?.[key];
      const isCount = key === "active_shops";
      const val = !a ? `<span class="skel w60"></span>` : v?.now == null ? NA() : isCount ? n(v.now) : key === "dau_mau" ? v.now.toFixed(2) : pct(v.now);
      let dl = "";
      if (v?.now != null && v.prev != null) {
        const diff = v.now - v.prev;
        dl = isCount ? delta(diff, "up", signed(diff, 0)) : key === "dau_mau" ? delta(diff, "up", signed(diff, 2)) : delta(diff, "up", `${signed(diff * 100, 1)} ${t.pts}`);
      }
      return `<div class="kpi"><div class="kpi-k">${esc(t.kpis[key]!)}</div><div class="kpi-v">${val}</div><div class="kpi-n">${dl ? `${dl} <span class="muted">${esc(t.kpiVs)}</span>` : `<span class="muted">${esc(t.kpiNotes[key]!)}</span>`}</div></div>`;
    })
    .join("");
}

// ---- Render ----------------------------------------------------------------------------------

function destroyCharts() {
  for (const c of state.charts) c.destroy();
  state.charts.length = 0;
}

function render() {
  destroyCharts();
  renderShell();
  const p = payload();
  const loaded = state.metrics.get(metricsKey());
  document.getElementById("kpis")!.innerHTML = kpisHtml(p?.data ?? null);
  const content = document.getElementById("content")!;
  const r = state.route;
  if (!p) {
    content.innerHTML = headerHtml(r) + (loaded ? `<div class="empty-state">${esc(u().loadError)}</div>` : skeletonHtml());
    renderDetail();
    return;
  }
  const a = p.data;
  if (r.kind === "page") {
    content.innerHTML = headerHtml(r) + pageHtml(r.id, a);
    if (r.id === "reports") drawReportCharts(a);
    if (r.id === "pilot") bindCalc();
  } else {
    const view = r.kind === "view" ? VIEWS.find((v) => v.id === r.id)! : undefined;
    const table = view ? view.table : (r.id as TableId);
    content.innerHTML = headerHtml(r) + (view ? viewChartHtml(view, a) : "") + tableShellHtml(table);
    if (view) drawViewCharts(view, a);
    renderTable();
  }
  renderDetail();
  renderLive();
}

function headerHtml(r: Route): string {
  const t = u();
  const desc = r.kind === "view" ? t.viewDesc[r.id] : r.kind === "table" ? t.tableDesc[r.id] : r.id === "pilot" ? t.pilotSub : r.id === "map" ? t.mapSub : r.id === "policy" ? t.policySub : t.reportsSub;
  const crumb = r.kind === "view" ? t.navViews : r.kind === "table" ? t.navTables : t.navPages;
  const hyp = r.kind === "view" && r.id === "fit" ? `<span class="badge hyp">${esc(t.hypothesis)}</span>` : "";
  const reset = r.kind === "view" ? `<button type="button" class="btn ghost sm" data-act="reset-view">${esc(t.reset)}</button>` : "";
  const badge = r.kind === "page" && (r.id === "policy" || r.id === "map" || r.id === "pilot") ? "" : modeBadge();
  return `<div class="page-head"><div class="crumb">${esc(crumb)}</div><div class="title-row"><h1>${esc(titleOf(r))}</h1>${badge}${hyp}<span class="spacer"></span>${reset}</div><p class="desc">${esc(desc ?? "")}</p></div>`;
}

function skeletonHtml(): string {
  return `<div class="panel"><div class="skel-table">${Array.from({ length: 8 }, () => `<div class="skel-row"><span class="skel w20"></span><span class="skel w10"></span><span class="skel w15"></span><span class="skel w30"></span></div>`).join("")}</div><p class="sr-only">${esc(u().loading)}</p></div>`;
}

// ---- Tables ------------------------------------------------------------------------------------

function currentTable(): { key: string; table: TableId; view?: SavedView } | null {
  const r = state.route;
  if (r.kind === "view") {
    const view = VIEWS.find((v) => v.id === r.id)!;
    return { key: `view:${view.id}`, table: view.table, view };
  }
  if (r.kind === "table") return { key: r.id, table: r.id };
  return null;
}

function tableShellHtml(table: TableId): string {
  const t = u();
  const ct = currentTable()!;
  const ui = tableUi(ct.key, ct.view);
  return `<section class="panel table-panel" aria-label="${esc(t.tables[table] ?? table)}">
    <div class="toolbar">
      <label class="search"><svg viewBox="0 0 16 16" aria-hidden="true"><circle cx="7" cy="7" r="4.5"/><path d="m10.5 10.5 3 3"/></svg><input type="search" id="tbl-search" placeholder="${esc(t.search)}" value="${esc(ui.query.search)}" aria-label="${esc(t.search)}"/></label>
      <div class="tb-group">
        <div class="pop-wrap"><button type="button" class="btn" data-act="pop-filter" aria-haspopup="dialog" aria-expanded="${state.popover === "filter"}">${esc(t.filter)}${ui.query.filters.length ? ` <span class="count">${ui.query.filters.length}</span>` : ""}</button><div class="popover" id="pop-filter" ${state.popover === "filter" ? "" : "hidden"}></div></div>
        <div class="pop-wrap"><button type="button" class="btn" data-act="pop-columns" aria-haspopup="dialog" aria-expanded="${state.popover === "columns"}">${esc(t.columns)}</button><div class="popover" id="pop-columns" ${state.popover === "columns" ? "" : "hidden"}></div></div>
        <div class="seg sm" role="group" aria-label="${esc(t.density)}"><button type="button" data-density="comfortable" aria-pressed="${state.density === "comfortable"}">${esc(t.comfortable)}</button><button type="button" data-density="compact" aria-pressed="${state.density === "compact"}">${esc(t.compact)}</button></div>
        <button type="button" class="btn" data-act="csv"><svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 2v8m-3-3 3 3 3-3M3 13h10"/></svg>${esc(t.exportCsv)}</button>
      </div>
    </div>
    <div class="filter-chips" id="filter-chips"></div>
    <div id="tbl"></div>
  </section>`;
}

function filterLabel(c: Column, f: Filter): string {
  const t = u();
  const val = (x: string | number) => (typeof x === "number" ? (c.fmt === "pct" || c.fmt === "pp" ? pct(x) : c.fmt === "wage" ? wage(x) : n(x, c.fmt === "num1" ? 1 : 0)) : lbl(c.group ?? (c.fmt === "risk" ? "risk" : undefined), x));
  const v = Array.isArray(f.value) ? f.value.map(val).join(", ") : val(f.value);
  return `${colLabel(c)} ${t.ops[f.op]} ${v}`;
}

function renderTable() {
  const ct = currentTable();
  const p = payload();
  const box = document.getElementById("tbl");
  if (!ct || !p || !box) return;
  const t = u();
  const ui = tableUi(ct.key, ct.view);
  const all = COLUMNS[ct.table];
  const cols = ui.columns.map((k) => all.find((c) => c.key === k)).filter((c): c is Column => !!c);
  const rows = rowsFor(ct.table, p.data);
  const shown = applyQuery(rows, ui.query, (row) => cols.map((c) => cellText(c, row[c.key])).join(" "));
  const chips = document.getElementById("filter-chips")!;
  chips.innerHTML = ui.query.filters
    .map((f, i) => {
      const c = all.find((x) => x.key === f.key)!;
      return `<span class="fchip">${esc(filterLabel(c, f))}<button type="button" data-rm-filter="${i}" aria-label="${esc(t.clear)}">×</button></span>`;
    })
    .join("") + (ui.query.filters.length ? `<button type="button" class="link" data-act="clear-filters">${esc(t.clear)}</button>` : "") +
    `<span class="row-count">${esc(shown.length === rows.length ? fillTemplate(t.rows, { n: n(rows.length) }) : fillTemplate(t.rowsOf, { n: n(shown.length), total: n(rows.length) }))}</span>`;

  if (!rows.length) {
    const extra = (ct.table === "listings" && !p.data.recruit?.fill.has_postings) || (ct.table === "supply" && !p.data.recruit?.supply.has_availability) ? t.needsPostings : "";
    box.innerHTML = `<div class="empty-state"><strong>${esc(t.noData)}</strong><p>${esc(isSim() ? "" : t.noDataLive)}</p>${extra ? `<p>${esc(extra)}</p>` : ""}</div>`;
    return;
  }
  if (!shown.length) {
    box.innerHTML = `<div class="empty-state"><strong>${esc(t.noRows)}</strong><button type="button" class="btn sm" data-act="clear-filters">${esc(t.clear)}</button></div>`;
    return;
  }
  const sort = ui.query.sort;
  const head = cols
    .map((c) => {
      const active = sort?.key === c.key;
      const aria = active ? (sort!.dir === 1 ? "ascending" : "descending") : "none";
      const help = t.colHelp[c.key];
      return `<th scope="col" class="${isNumeric(c) ? "num" : ""} f-${c.fmt}" aria-sort="${aria}"><button type="button" data-sort="${c.key}"${help ? ` title="${esc(help)}"` : ""}>${esc(colLabel(c))}<span class="sort-ind" aria-hidden="true">${active ? (sort!.dir === 1 ? "↑" : "↓") : ""}</span></button></th>`;
    })
    .join("");
  const body = shown
    .map((row) => `<tr tabindex="0" data-row="${esc(row.id)}"${state.selected === row.id ? ' class="selected" aria-selected="true"' : ""}>${cols.map((c) => `<td class="${isNumeric(c) ? "num" : ""} f-${c.fmt}">${cellHtml(c, row[c.key])}</td>`).join("")}</tr>`)
    .join("");
  const cards = shown
    .map((row) => {
      const [first, ...rest] = cols;
      return `<button type="button" class="rcard${state.selected === row.id ? " selected" : ""}" data-row="${esc(row.id)}"><span class="rcard-title">${cellHtml(first!, row[first!.key])}</span><dl>${rest
        .slice(0, 6)
        .map((c) => `<div><dt>${esc(colLabel(c))}</dt><dd>${cellHtml(c, row[c.key])}</dd></div>`)
        .join("")}</dl></button>`;
    })
    .join("");
  box.innerHTML = `<div class="table-scroll density-${state.density}"><table class="dt"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div><div class="cards">${cards}</div>`;
}

function renderPopover() {
  const ct = currentTable();
  if (!ct) return;
  const t = u();
  const ui = tableUi(ct.key, ct.view);
  const all = COLUMNS[ct.table];
  const pf = document.getElementById("pop-filter");
  const pc = document.getElementById("pop-columns");
  if (pf) {
    pf.hidden = state.popover !== "filter";
    if (state.popover === "filter") {
      const filterable = all.filter((c) => c.fmt !== "spark" && c.fmt !== "tags" && c.fmt !== "text");
      pf.innerHTML = `<form id="filter-form" class="pop-form"><div class="pop-title">${esc(t.addFilter)}</div>
        <label>${esc(u().columns)}<select name="key" id="f-key">${filterable.map((c) => `<option value="${c.key}">${esc(colLabel(c))}</option>`).join("")}</select></label>
        <div id="f-value"></div>
        <div class="pop-actions"><button type="submit" class="btn primary sm">${esc(t.apply)}</button></div></form>`;
      renderFilterValue();
    }
  }
  if (pc) {
    pc.hidden = state.popover !== "columns";
    if (state.popover === "columns") {
      pc.innerHTML = `<div class="pop-form"><div class="pop-title">${esc(t.columns)}</div><div class="col-list">${all
        .map((c) => `<label class="check"><input type="checkbox" data-col="${c.key}" ${ui.columns.includes(c.key) ? "checked" : ""} ${c.key === all[0]!.key ? "disabled" : ""}/> ${esc(colLabel(c))}</label>`)
        .join("")}</div></div>`;
    }
  }
  for (const b of document.querySelectorAll<HTMLElement>("[data-act=pop-filter],[data-act=pop-columns]")) {
    b.setAttribute("aria-expanded", String(b.dataset.act === `pop-${state.popover}`));
  }
}

function renderFilterValue() {
  const ct = currentTable();
  const p = payload();
  const sel = document.getElementById("f-key") as HTMLSelectElement | null;
  const box = document.getElementById("f-value");
  if (!ct || !p || !sel || !box) return;
  const c = COLUMNS[ct.table].find((x) => x.key === sel.value)!;
  if (isNumeric(c)) {
    const unit = c.fmt === "pct" || c.fmt === "pp" ? "%" : c.fmt === "wage" ? currencySymbol(p.data.recruit?.pay?.currency ?? currency()) : "";
    box.innerHTML = `<div class="op-row"><select name="op"><option value="gte">≥</option><option value="lte">≤</option></select><input name="num" type="number" step="any" required inputmode="decimal"/>${unit ? `<span class="unit">${unit}</span>` : ""}</div>`;
  } else {
    const values = [...new Set(rowsFor(ct.table, p.data).map((r) => r[c.key]).filter((v): v is string => typeof v === "string"))];
    box.innerHTML = `<div class="col-list">${values.map((v) => `<label class="check"><input type="checkbox" name="v" value="${esc(v)}"/> ${esc(lbl(c.group ?? (c.fmt === "risk" ? "risk" : undefined), v))}</label>`).join("")}</div>`;
  }
}

function csvExport() {
  const ct = currentTable();
  const p = payload();
  if (!ct || !p) return;
  const ui = tableUi(ct.key, ct.view);
  const all = COLUMNS[ct.table];
  const cols = ui.columns.map((k) => all.find((c) => c.key === k)).filter((c): c is Column => !!c);
  const rows = applyQuery(rowsFor(ct.table, p.data), ui.query, (row) => cols.map((c) => cellText(c, row[c.key])).join(" "));
  const payCur = p.data.recruit?.pay?.currency;
  const header = (c: Column) => (c.fmt === "wage" && payCur ? `${colLabel(c)} (${payCur}/h)` : colLabel(c));
  const csv = toCsv(rows, cols, header, (c, v) => lbl(c.group ?? (c.fmt === "risk" ? "risk" : undefined), v));
  const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `pawtime-${ct.key.replace(":", "-")}-${state.mode}${isSim() ? "-synthetic" : ""}.csv`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

// ---- View charts -------------------------------------------------------------------------------

const SERIES = () => [css("--s1"), css("--s2"), css("--s3"), css("--s4")];

function viewChartHtml(view: SavedView, a: InsightsAggregate): string {
  const t = u();
  const r = a.recruit;
  if (!r) return "";
  const box = (title: string, body: string, cls = "") => `<div class="vc ${cls}"><div class="vc-title">${esc(title)}</div>${body}</div>`;
  const cv = (id: string, cls = "") => `<div class="vchart ${cls}"><canvas id="${id}" role="img" aria-label=""></canvas></div>`;
  let inner = "";
  if (view.id === "at-risk") {
    inner = r.at_risk.rows.length ? box(t.chartRisk, cv("vc-risk", "tall")) : "";
  } else if (view.id === "unfilled") {
    if (!r.fill.has_postings) return `<div class="note-strip">${esc(t.needsPostings)}</div>` + remindersBox();
    const mae = r.fill.backtest.mae == null ? "" : `<div class="vc-foot">${esc(fillTemplate(t.backtestMae, { x: pct(r.fill.backtest.mae), n: String(r.fill.backtest.listings) }))}</div>`;
    inner = box(t.chartBacktest, cv("vc-backtest") + mae) + remindersBox(true);
  } else if (view.id === "supply") {
    inner = box(t.chartHeat, heatmapHtml(a), "wide");
  } else if (view.id === "interest") {
    inner = box(t.chartInterest, cv("vc-interest", "short")) + box(t.chartLandmarks, cv("vc-landmarks", "short"));
  } else if (view.id === "fit") {
    inner = box(t.chartFit, cv("vc-fit")) + box(t.chartFitCompare, cv("vc-fitcmp"));
  }
  const feeds = `<div class="feeds"><span class="feeds-k">${esc(t.detailFeeds)}</span>${view.feeds.map((f) => `<span class="feed-tag">${esc(t.feeds[f]!)}</span>`).join("")}</div>`;
  return inner ? `<section class="panel view-charts"><div class="vc-grid">${inner}</div>${feeds}</section>` : "";

  function remindersBox(inGrid = false) {
    const ex = r!.fill.willing_excluded_share == null ? "" : `<div class="vc-foot">${esc(fillTemplate(t.excluded, { x: pct(r!.fill.willing_excluded_share) }))}</div>`;
    const b = box(t.chartReminders, cv("vc-reminders", "short") + ex);
    return inGrid ? b : `<section class="panel view-charts"><div class="vc-grid">${b}</div></section>`;
  }
}

function heatmapHtml(a: InsightsAggregate): string {
  const t = u();
  const r = a.recruit!;
  if (!r.supply.has_availability) return `<p class="muted">${esc(t.noDataLive)}</p>`;
  const days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
  const bands = ["morning", "day", "evening", "night"];
  const cell = (slot: string) => {
    if (state.heatArea === "all") {
      const c = r.supply.cells.find((x) => x.slot === slot);
      return { available: c?.available ?? null, open: c?.open_shifts ?? null };
    }
    const c = r.supply.grid.find((x) => x.slot === slot && x.area === state.heatArea);
    return { available: c?.available ?? null, open: c?.open_shifts ?? null };
  };
  const vals = days.flatMap((dd) => bands.map((b) => cell(`${dd}_${b}`).available ?? 0));
  // Highlight the 5 slots with the most open shifts that still have 5+ willing workers.
  const top = new Set(days.flatMap((dd) => bands.map((b) => ({ slot: `${dd}_${b}`, ...cell(`${dd}_${b}`) }))).filter((c) => c.available != null && (c.open ?? 0) > 0).sort((x, y) => (y.open ?? 0) - (x.open ?? 0)).slice(0, 5).map((c) => c.slot));
  const max = Math.max(1, ...vals);
  const areaSel = `<div class="seg sm heat-areas" role="group">${["all", ...Object.keys(t.areas)].map((ar) => `<button type="button" data-heat-area="${ar}" aria-pressed="${state.heatArea === ar}">${esc(ar === "all" ? t.allAreas : t.areas[ar]!)}</button>`).join("")}</div>`;
  const grid = `<div class="heat" role="table"><div class="heat-row head" role="row"><span role="columnheader"></span>${days.map((dd) => `<span role="columnheader" class="${dd === "sat" || dd === "sun" ? "we" : ""}">${esc(t.days[dd] ?? dd)}</span>`).join("")}</div>${bands
    .map((b) => `<div class="heat-row" role="row"><span role="rowheader" class="hb">${esc(t.bands[b]!)}<small>${esc(t.bandHours[b]!)}</small></span>${days
      .map((dd) => {
        const c = cell(`${dd}_${b}`);
        const lvl = c.available == null ? 0 : Math.max(1, Math.ceil((c.available / max) * 6));
        const gap = top.has(`${dd}_${b}`);
        const title = `${t.days[dd]} ${t.bands[b]} · ${t.cols.available}: ${c.available ?? "—"} · ${t.cols.open_shifts}: ${c.open ?? "—"}`;
        return `<span role="cell" class="hc l${lvl}${gap ? " gap" : ""}" title="${esc(title)}"><b>${c.available == null ? "—" : n(c.available)}</b>${c.open != null ? `<small>(${n(c.open, 1)})</small>` : ""}</span>`;
      })
      .join("")}</div>`)
    .join("")}</div>`;
  const legendHtml = `<div class="heat-legend"><span class="lg-scale"><i class="l1"></i><i class="l3"></i><i class="l5"></i><i class="l6"></i></span><span>${esc(t.cols.available!)}</span><span class="lg-gap"></span><span>${esc(t.topGaps)}</span></div>`;
  return areaSel + grid + legendHtml;
}

function drawViewCharts(view: SavedView, a: InsightsAggregate) {
  const t = u();
  const r = a.recruit;
  if (!r) return;
  const [s1, s2, s3, s4] = SERIES() as [string, string, string, string];
  const shopName = (s: string) => lbl("shops", s);
  if (view.id === "at-risk" && r.at_risk.rows.length) {
    const rows = r.at_risk.rows.slice(0, 10);
    const W = { return_drop: 35, repeat_pass: 25, issue_tags: 25, review_trend: 15 } as const;
    const keys = Object.keys(W) as (keyof typeof W)[];
    const colors = [s1, s2, s3, s4];
    makeChart("vc-risk", {
      type: "bar",
      data: {
        labels: rows.map((x) => shopName(x.shop)),
        datasets: keys.map((k, i) => ({ ...bar(t.reasons[k]!, rows.map((x) => Math.round(x.components[k] * W[k] * 10) / 10), colors[i]!), stack: "s", borderColor: css("--surface"), borderWidth: 1 })),
      },
      options: {
        indexAxis: "y",
        interaction: { mode: "index", intersect: false, axis: "y" },
        plugins: { legend: legend() },
        scales: { x: { ...axisY(), stacked: true, max: 100 }, y: { stacked: true, grid: { display: false }, ticks: { color: css("--text-2") }, border: { color: css("--line") } } },
      },
    });
  }
  if (view.id === "unfilled") {
    if (r.fill.has_postings) {
      const pts = r.fill.rows.filter((x) => x.backtest_predicted != null && x.backtest_actual != null).map((x) => ({ x: x.backtest_predicted!, y: x.backtest_actual!, label: `${shopName(x.shop)} · ${lbl("bands", x.band)}` }));
      makeChart("vc-backtest", {
        type: "scatter",
        data: {
          datasets: [
            { label: `${t.forecast} = ${t.actual}`, data: [{ x: 0.3, y: 0.3 }, { x: 1, y: 1 }], showLine: true, borderColor: css("--text-3"), borderDash: [4, 4], borderWidth: 1, pointRadius: 0, type: "line" } as never,
            { label: t.cols.backtest_actual ?? "", data: pts, backgroundColor: s1, borderColor: css("--surface"), borderWidth: 1.5, pointRadius: 5, pointHoverRadius: 7 },
          ],
        },
        options: {
          plugins: { legend: { display: false }, tooltip: { callbacks: { label: (c) => { const p = c.raw as { x: number; y: number; label?: string }; return `${p.label ?? ""} ${t.forecast} ${pct(p.x)} · ${t.actual} ${pct(p.y)}`; } } } },
          scales: {
            x: { ...pctAxis(), min: 0.3, max: 1, title: { display: true, text: t.forecast, color: css("--text-2") } },
            y: { ...pctAxis(), min: 0.3, max: 1, title: { display: true, text: t.actual, color: css("--text-2") } },
          },
        },
      });
    }
    const rem = r.fill.reminders;
    makeChart("vc-reminders", {
      type: "bar",
      data: { labels: rem.map((x) => t.reminderReplies[x.reaction] ?? x.reaction), datasets: [bar(t.cols.no_show_rate ?? "", rem.map((x) => x.no_show_rate), [s1, s4, s2])] },
      options: { plugins: { legend: { display: false }, tooltip: pctTooltip }, scales: { x: axisX(), y: { ...pctAxis(), max: undefined, suggestedMax: 0.5 } } },
    });
  }
  if (view.id === "interest") {
    makeChart("vc-interest", {
      type: "bar",
      data: { labels: [t.visitors, t.nonVisitors], datasets: [bar("", [r.interest.visitor_apply_rate, r.interest.non_visitor_apply_rate], [s1, css("--neutral-bar")])] },
      options: { indexAxis: "y", plugins: { legend: { display: false }, tooltip: pctTooltip }, scales: { x: { ...pctAxis(), max: undefined, suggestedMax: 0.5 }, y: { grid: { display: false }, ticks: { color: css("--text-2") } } } },
    });
    const lm = r.interest.landmarks.slice(0, 6);
    makeChart("vc-landmarks", {
      type: "bar",
      data: { labels: lm.map((x) => lbl("tags", x.key)), datasets: [bar("", lm.map((x) => x.taps), s1)] },
      options: { indexAxis: "y", plugins: { legend: { display: false } }, scales: { x: axisY(), y: { grid: { display: false }, ticks: { color: css("--text-2") } } } },
    });
  }
  if (view.id === "fit") {
    const bins = r.fit.bins;
    makeChart("vc-fit", {
      type: "bar",
      data: {
        labels: bins.map((b) => fillTemplate(t.signalsN, { n: String(b.signals) })),
        datasets: [
          bar(t.cols.repeat_rate ?? "", bins.map((b) => b.repeat_rate), s1),
          { type: "line", label: t.fitBase, data: bins.map(() => r.fit.base_repeat_rate), borderColor: css("--text-3"), borderDash: [4, 4], borderWidth: 1.5, pointRadius: 0 } as never,
        ],
      },
      options: { plugins: { legend: legend(), tooltip: pctTooltip }, scales: { x: axisX(), y: pctAxis() } },
    });
    makeChart("vc-fitcmp", {
      type: "bar",
      data: { labels: [t.fitBase, t.selfReport, t.behavior], datasets: [bar(t.cols.repeat_rate ?? "", [r.fit.base_repeat_rate, r.fit.self_report.repeat_rate, r.fit.behavior.repeat_rate], [css("--neutral-bar"), s2, s1])] },
      options: { indexAxis: "y", plugins: { legend: { display: false }, tooltip: pctTooltip }, scales: { x: pctAxis(), y: { grid: { display: false }, ticks: { color: css("--text-2") } } } },
    });
  }
}

// ---- Detail panel --------------------------------------------------------------------------------

function renderDetail() {
  const el = document.getElementById("detail")!;
  const p = payload();
  const ct = currentTable();
  if (!state.selected || !p || !ct) {
    el.hidden = true;
    el.innerHTML = "";
    document.body.classList.remove("detail-open");
    return;
  }
  let row = rowsFor(ct.table, p.data).find((r) => r.id === state.selected);
  // A shop-week opens its shop.
  if (row?.table === "signals") row = shopRows(p.data).find((r) => r.shop === row!.shop);
  if (!row) {
    state.selected = null;
    el.hidden = true;
    return;
  }
  el.hidden = false;
  document.body.classList.add("detail-open");
  el.innerHTML = detailHtml(row, p.data);
}

function detailHtml(row: Row, a: InsightsAggregate): string {
  const t = u();
  const r = a.recruit!;
  const head = (title: string, sub: string, chip: string) =>
    `<div class="dp-head"><div><div class="dp-kicker">${esc(sub)}</div><h2>${esc(title)}</h2></div><button type="button" class="icon-btn" data-act="close-detail" aria-label="${esc(t.close)}">×</button></div><div class="dp-chips">${chip}${modeBadge()}</div>`;
  const kv = (items: [string, string][]) => `<dl class="dp-kv">${items.map(([k, v]) => `<div><dt>${esc(k)}</dt><dd>${v}</dd></div>`).join("")}</dl>`;
  const feeds = (keys: string[]) => `<section class="dp-sec"><h3>${esc(t.detailFeeds)}</h3><div class="feeds">${keys.map((f) => `<span class="feed-tag">${esc(t.feeds[f]!)}</span>`).join("")}</div></section>`;
  const actions = `<section class="dp-sec"><h3>${esc(t.detailActions)}</h3><div class="dp-actions"><button type="button" class="btn" data-act="mock">${esc(t.actionShare)}</button><button type="button" class="btn" data-act="mock">${esc(t.actionAlert)}</button></div><p class="muted small">${esc(t.mockNote)}</p></section>`;
  const cols = (table: TableId, key: string) => COLUMNS[table].find((c) => c.key === key)!;
  const weeks = r.weeks;
  const spark = (label: string, values: (number | null)[], fmt: (v: number) => string, second?: (number | null)[]) => {
    const last = [...values].reverse().find((v) => v != null);
    return `<div class="sp-row"><div class="sp-k">${esc(label)}</div>${sparkline(values, { w: 140, h: 32, second })}<div class="sp-v">${last == null ? "—" : esc(fmt(last))}</div></div>`;
  };

  if (row.table === "shops") {
    const shop = String(row.shop);
    const risk = r.at_risk.rows.find((x) => x.shop === shop);
    const sig = weeks.map((w) => r.signals.find((s) => s.shop === shop && s.week === w));
    const W = { return_drop: 35, repeat_pass: 25, issue_tags: 25, review_trend: 15 } as const;
    const breakdown = risk
      ? `<section class="dp-sec"><h3>${esc(t.detailScore)} <span class="muted">${risk.score}/100</span></h3>${(Object.keys(W) as (keyof typeof W)[])
          .map((k) => `<div class="bd-row"><span class="bd-k">${esc(t.reasons[k]!)}</span><span class="bd-bar"><i style="width:${(risk.components[k] * 100).toFixed(0)}%"></i></span><span class="bd-v">${(risk.components[k] * W[k]).toFixed(1)} / ${W[k]}</span></div>`)
          .join("")}${risk.reasons.length ? `<div class="reasons">${risk.reasons.map((x) => `<span class="reason">${esc(t.reasons[x]!)}</span>`).join("")}</div>` : ""}</section>`
      : "";
    const signals = `<section class="dp-sec"><h3>${esc(t.detailSignals)} <span class="muted">${esc(weeks[0] ?? "")}–${esc(weeks[weeks.length - 1] ?? "")}</span></h3>
      ${spark(t.sparkReturn, sig.map((s) => s?.next_day_return ?? null), (v) => pct(v), sig.map((s) => s?.baseline ?? null))}
      ${spark(t.sparkPass, sig.map((s) => s?.invite_pass_share ?? null), (v) => pct(v))}
      ${spark(t.sparkStars, sig.map((s) => s?.stars_avg ?? null), (v) => v.toFixed(2))}
      ${spark(t.sparkVisits, sig.map((s) => s?.island_visitors ?? null), (v) => n(v))}
      ${spark(t.sparkFill, sig.map((s) => (s?.openings ? (s.filled ?? 0) / s.openings : null)), (v) => pct(v))}
      <div class="sp-legend"><span class="k1"></span>${esc(t.cols.next_day_return!)} <span class="k2"></span>${esc(t.cols.baseline!)}</div></section>`;
    const issues = `<section class="dp-sec"><h3>${esc(t.detailIssues)}</h3>${risk?.issue_tags.length ? `<div class="reasons">${risk.issue_tags.map((x) => `<span class="tag">${esc(lbl("topics", x.key))} · ${esc(fillTemplate(d().workersN, { n: n(x.workers) }))}</span>`).join("")}</div>` : `<p class="muted small">${esc(t.detailNoIssues)}</p>`}</section>`;
    const listings = r.fill.rows.filter((x) => x.shop === shop);
    const lst = listings.length
      ? `<section class="dp-sec"><h3>${esc(t.detailListings)}</h3><table class="mini-t"><thead><tr><th>${esc(t.cols.band!)}</th><th class="num">${esc(t.cols.predicted_fill!)}</th><th class="num">${esc(t.cols.no_show_risk!)}</th>${r.pay ? `<th class="num">${esc(t.cols.hourly_wage!)}</th>` : ""}<th>${esc(t.cols.history!)}</th></tr></thead><tbody>${listings
          .map((x) => {
            const w = r.pay?.listings.find((p) => p.shop === x.shop && p.band === x.band)?.hourly_wage;
            return `<tr><td>${esc(lbl("bands", x.band))}</td><td class="num">${pct(x.predicted_fill)}</td><td class="num">${pct(x.no_show_risk)}</td>${r.pay ? `<td class="num">${w == null ? NA() : esc(wage(w))}</td>` : ""}<td>${sparkline(x.history, { w: 80, h: 20 })}</td></tr>`;
          })
          .join("")}</tbody></table></section>`
      : "";
    return head(lbl("shops", shop), lbl("areas", String(row.area)), row.risk ? cellHtml(cols("shops", "risk"), row.risk) : "") +
      kv([
        [colLabel(cols("shops", "workers")), cellHtml(cols("shops", "workers"), row.workers)],
        [colLabel(cols("shops", "return_delta")), cellHtml(cols("shops", "return_delta"), row.return_delta)],
        [colLabel(cols("shops", "repeat_rate")), cellHtml(cols("shops", "repeat_rate"), row.repeat_rate)],
        [colLabel(cols("shops", "fill_rate")), cellHtml(cols("shops", "fill_rate"), row.fill_rate)],
        [colLabel(cols("shops", "island_visitors")), cellHtml(cols("shops", "island_visitors"), row.island_visitors)],
        [colLabel(cols("shops", "top_landmark")), cellHtml(cols("shops", "top_landmark"), row.top_landmark)],
        ...(row.hourly_wage != null
          ? ([
              [colLabel(cols("shops", "hourly_wage")), cellHtml(cols("shops", "hourly_wage"), row.hourly_wage)],
              [colLabel(cols("shops", "pay_style")), cellHtml(cols("shops", "pay_style"), row.pay_style)],
            ] as [string, string][])
          : []),
      ]) + breakdown + signals + issues + lst + feeds(["air_work", "indeed", "townwork"]) + actions;
  }
  if (row.table === "listings") {
    const c = (k: string) => cols("listings", k);
    const hist = (row.history ?? []) as (number | null)[];
    return head(`${lbl("shops", String(row.shop))} · ${lbl("bands", String(row.band))}`, `${lbl("areas", String(row.area))} · ${t.bandHours[String(row.band)] ?? ""}`, cellHtml(c("status"), row.status)) +
      kv([
        [colLabel(c("predicted_fill")), cellHtml(c("predicted_fill"), row.predicted_fill)],
        [colLabel(c("no_show_risk")), cellHtml(c("no_show_risk"), row.no_show_risk)],
        [colLabel(c("openings_per_week")), cellHtml(c("openings_per_week"), row.openings_per_week)],
        ...(row.hourly_wage != null ? ([[colLabel(c("hourly_wage")), cellHtml(c("hourly_wage"), row.hourly_wage)], [colLabel(c("no_show_rate")), cellHtml(c("no_show_rate"), row.no_show_rate)]] as [string, string][]) : []),
        [colLabel(c("fill_rate")), cellHtml(c("fill_rate"), row.fill_rate)],
        [colLabel(c("backtest_predicted")), cellHtml(c("backtest_predicted"), row.backtest_predicted)],
        [colLabel(c("backtest_actual")), cellHtml(c("backtest_actual"), row.backtest_actual)],
      ]) +
      `<section class="dp-sec"><h3>${esc(t.detailSignals)}</h3>${spark(t.sparkFill, hist, (v) => pct(v))}<p class="muted small">${esc(t.colHelp.predicted_fill!)}</p><p class="muted small">${esc(t.colHelp.no_show_risk!)}</p></section>` +
      feeds(["townwork", "air_shift"]) + actions;
  }
  // supply slot
  const slot = String(row.slot);
  const c = (k: string) => cols("supply", k);
  const byArea = r.supply.grid.filter((x) => x.slot === slot);
  const sameAreaDays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"].map((dd) => r.supply.grid.find((x) => x.area === row.area && x.slot === `${dd}_${row.band}`)?.available ?? null);
  return head(fillTemplate(t.slotAt, { day: lbl("days", String(row.day)), band: lbl("bands", String(row.band)), hours: t.bandHours[String(row.band)] ?? "" }), lbl("areas", String(row.area)), cellHtml(c("status"), row.status)) +
    kv([
      [colLabel(c("available")), cellHtml(c("available"), row.available)],
      [colLabel(c("open_shifts")), cellHtml(c("open_shifts"), row.open_shifts)],
      [colLabel(c("cover")), cellHtml(c("cover"), row.cover)],
    ]) +
    `<section class="dp-sec"><h3>${esc(t.byArea)}</h3><table class="mini-t"><thead><tr><th>${esc(t.cols.area!)}</th><th class="num">${esc(t.cols.available!)}</th><th class="num">${esc(t.cols.open_shifts!)}</th></tr></thead><tbody>${byArea
      .map((x) => `<tr${x.area === row.area ? ' class="hl"' : ""}><td>${esc(lbl("areas", x.area))}</td><td class="num">${x.available == null ? NA() : n(x.available)}</td><td class="num">${x.open_shifts == null ? NA() : n(x.open_shifts, 1)}</td></tr>`)
      .join("")}</tbody></table></section>` +
    `<section class="dp-sec"><h3>${esc(lbl("bands", String(row.band)))} · ${esc(lbl("areas", String(row.area)))}</h3>${spark(t.cols.available!, sameAreaDays, (v) => n(v))}<p class="muted small">${esc(t.colHelp.available!)}</p></section>` +
    feeds(["air_shift", "townwork"]) + actions;
}

// ---- Pages -------------------------------------------------------------------------------------

function pageHtml(id: "pilot" | "map" | "policy" | "reports", a: InsightsAggregate): string {
  if (id === "reports") return reportsHtml(a);
  if (id === "pilot") return pilotHtml();
  if (id === "map") return mapHtml();
  return policyHtml();
}

const CALC_FIELDS: { key: keyof CalcInput; kind: "int" | "pct" | "money"; step: number }[] = [
  { key: "shops", kind: "int", step: 1 },
  { key: "workers", kind: "int", step: 5 },
  { key: "shiftsPerWeek", kind: "int", step: 1 },
  { key: "currentFill", kind: "pct", step: 1 },
  { key: "noShowRate", kind: "pct", step: 0.5 },
  { key: "fillFee", kind: "money", step: 100 },
  { key: "noShowCost", kind: "money", step: 500 },
  { key: "fillUplift", kind: "pct", step: 0.5 },
  { key: "noShowReduction", kind: "pct", step: 5 },
];

function pilotHtml(): string {
  const t = u();
  const cur = currency();
  const fields = CALC_FIELDS.map((f) => {
    const v = state.calc[cur][f.key];
    const shown = f.kind === "pct" ? Math.round(v * 1000) / 10 : v;
    const unit = f.kind === "pct" ? (f.key === "fillUplift" ? t.pts : "%") : "";
    // Dollar inputs move in whole dollars ($1 / $5), yen in ¥100 / ¥500.
    const step = f.kind === "money" && cur === "USD" ? f.step / 100 : f.step;
    return `<div class="field"><label for="calc-${f.key}">${esc(t.calc[f.key]!)}</label><div class="input-wrap">${f.kind === "money" ? `<span class="pre">${currencySymbol(cur)}</span>` : ""}<input id="calc-${f.key}" type="number" min="0" step="${step}" value="${shown}" data-calc="${f.key}" data-kind="${f.kind}" inputmode="decimal"/>${unit ? `<span class="post">${esc(unit)}</span>` : ""}</div><p class="help">${esc(t.calcNote[f.key]!)}</p></div>`;
  }).join("");
  return `<div class="calc"><section class="panel calc-in"><div class="panel-h"><h2>${esc(t.assumptions)}</h2><span class="badge hyp">${esc(t.hypothesis)}</span><span class="spacer"></span><button type="button" class="btn ghost sm" data-act="calc-reset">${esc(t.resetDefaults)}</button></div><div class="fields">${fields}</div></section>
    <section class="panel calc-out" aria-live="polite"><div class="panel-h"><h2>${esc(t.results)}</h2><span class="badge hyp">${esc(t.hypothesis)}</span></div><div id="calc-out">${calcOutHtml()}</div><p class="help">${esc(t.calcFormula)}</p></section></div>`;
}

function calcOutHtml(): string {
  const t = u();
  const o = pilotValue(state.calc[currency()]);
  const line = (k: string, v: string, cls = "") => `<div class="out-row ${cls}"><span>${esc(t.out[k]!)}</span><span class="num">${v}</span></div>`;
  return `<div class="out-hero"><div class="kpi-k">${esc(t.out.total!)}</div><div class="out-total">${money(o.total)}</div><div class="muted">${esc(t.out.annual!)} ${money(o.annual)}</div></div>` +
    line("postedPerMonth", n(o.postedPerMonth, 0)) +
    line("fillsGained", n(o.fillsGained, 1)) +
    line("noShowsAvoided", n(o.noShowsAvoided, 1)) +
    line("valueFills", money(o.valueFills)) +
    line("valueNoShows", money(o.valueNoShows)) +
    line("perWorker", o.perWorker == null ? "—" : money(o.perWorker, currency() === "USD"), "sub");
}

function bindCalc() {
  for (const el of document.querySelectorAll<HTMLInputElement>("[data-calc]")) {
    el.addEventListener("input", () => {
      const raw = Number(el.value);
      const key = el.dataset.calc as keyof CalcInput;
      state.calc[currency()][key] = el.dataset.kind === "pct" ? raw / 100 : raw;
      document.getElementById("calc-out")!.innerHTML = calcOutHtml();
    });
  }
}

const MAP_LINKS: [string, string][] = [
  ["off_day_opens", "townwork"], ["island", "townwork"], ["island", "air_work"], ["availability", "air_shift"], ["reminders", "air_shift"],
  ["tiredness", "air_shift"], ["next_day", "indeed"], ["next_day", "air_work"], ["invites", "indeed"], ["invites", "air_work"],
  ["issues", "air_work"], ["reviews", "indeed"], ["reviews", "air_work"],
];
function mapHtml(): string {
  const t = u();
  const biz = ["indeed", "townwork", "air_shift", "air_work"];
  const sigs = Object.keys(t.mapSignals);
  const head = `<tr><th scope="col">${esc(t.mapSignal)}</th>${biz.map((b) => `<th scope="col"><span class="feed-tag">${esc(t.feeds[b]!)}</span></th>`).join("")}</tr>`;
  const body = sigs
    .map((s) => `<tr><th scope="row">${esc(t.mapSignals[s]!)}</th>${biz
      .map((b) => (MAP_LINKS.some(([x, y]) => x === s && y === b) ? `<td class="link-cell"><span class="lk-dot" aria-hidden="true"></span>${esc(t.mapValue[`${s}|${b}`] ?? "")}</td>` : `<td class="empty-cell" aria-label="—"></td>`))
      .join("")}</tr>`)
    .join("");
  const list = biz
    .map((b) => `<div class="map-card"><div class="feed-tag">${esc(t.feeds[b]!)}</div><ul>${MAP_LINKS.filter(([, y]) => y === b).map(([s]) => `<li><strong>${esc(t.mapSignals[s]!)}</strong><span>${esc(t.mapValue[`${s}|${b}`] ?? "")}</span></li>`).join("")}</ul></div>`)
    .join("");
  return `<section class="panel"><div class="table-scroll map-table"><table class="dt map">${`<thead>${head}</thead><tbody>${body}</tbody>`}</table></div><div class="map-cards">${list}</div></section>`;
}

function policyHtml(): string {
  const t = u();
  return `<section class="panel policy">${t.policy.map(([h, b], i) => `<div class="pol"><span class="pol-n">${i + 1}</span><div><h3>${esc(h)}</h3><p>${esc(b)}</p></div></div>`).join("")}<p class="muted small"><a href="/privacy">${esc(t.privacy)}</a></p></section>`;
}

// ---- Live drawer ------------------------------------------------------------------------------------

const ICONS: Record<string, string> = {
  app_open: "📱", job_cards_shown: "🐾", job_card_open: "🗂️", job_accept: "✅", job_pass: "↩️", shift_start: "▶️",
  shift_end: "⏹️", cat_tired_stop: "😿", review_submitted: "⭐", practice_done: "🎯", skill_badge_share_toggled: "🏅",
  shop_island_visit: "🏝️", scoop_night: "🌙", hatch: "🥚", island_expand: "🌱", island_share: "🔗", outfit_change: "👕",
  calendar_add: "📅", suggestions_toggled: "💡", chat_open: "💬", chat_signal: "🏷️", anon_issue_sent: "✉️",
  faq_auto_answered: "❓", shop_message_sent: "📨", landmark_tap: "📍", availability_set: "🗓️", reminder_reaction: "🔔",
};

function renderLiveButton() {
  const b = document.getElementById("live-btn");
  if (!b) return;
  const players = state.feed?.players ?? 0;
  b.setAttribute("aria-expanded", String(state.liveOpen));
  b.innerHTML = `<span class="pulse${players ? "" : " idle"}"></span>${esc(u().live)}${state.feed ? `<span class="count">${n(players)}</span>` : ""}`;
}

function renderLive() {
  const el = document.getElementById("live")!;
  el.hidden = !state.liveOpen;
  document.body.classList.toggle("live-open", state.liveOpen);
  if (!state.liveOpen) return;
  // Real events from the game: keep the game's own shop and role names, even over the simulation.
  const t = I18N[state.lang];
  const fd = state.feed;
  const c = fd?.counts ?? {};
  const count = (k: string) => (fd ? n(c[k] ?? 0) : "—");
  const stat = (k: string, v: string) => `<div class="ls"><div class="ls-v">${v}</div><div class="ls-k">${esc(k)}</div></div>`;
  let items = `<li class="empty">${esc(fd?.storage === "not_connected" ? t.storageOff : t.feedEmpty)}</li>`;
  if (fd?.items.length) {
    const firstPaint = state.seenFeed.size === 0;
    const nowS = Math.round(Date.now() / 1000);
    items = fd.items
      .map((it) => {
        const key = `${it.type}|${JSON.stringify(it.props)}|${Math.round((nowS - it.ago_s) / 5)}`;
        const fresh = !firstPaint && !state.seenFeed.has(key);
        state.seenFeed.add(key);
        const demo = it.demo ? `<span class="demo-tag">demo</span>` : "";
        const inv = it.props.invited === true ? `<span class="demo-tag">${esc(t.invitedTag)}</span>` : "";
        const ago = it.ago_s < 60 ? `${it.ago_s} ${t.agoS}` : `${Math.floor(it.ago_s / 60)} ${t.agoM}`;
        return `<li class="${fresh ? "new" : ""}"><span class="ic" aria-hidden="true">${ICONS[it.type] ?? "•"}</span><span class="txt">${esc(feedText(t, it.type, it.props))}${inv}${demo}</span><span class="ago">${esc(ago)}</span></li>`;
      })
      .join("");
  }
  el.innerHTML = `<div class="dp-head"><div><div class="dp-kicker">${esc(t.liveNowSub)}</div><h2><span class="pulse"></span>${esc(u().liveDrawer)}</h2></div><button type="button" class="icon-btn" data-act="close-live" aria-label="${esc(u().close)}">×</button></div>
    <label class="switch"><input type="checkbox" id="demo-only" ${state.demoOnly ? "checked" : ""}/><span class="track"><span class="thumb"></span></span>${esc(t.demoOnly)}</label>
    <div class="ls-grid">${stat(t.players, fd ? n(fd.players) : "—")}${stat(t.accepts, count("job_accept"))}${stat(t.catStops, count("cat_tired_stop"))}${stat(t.shopVisits, count("shop_island_visit"))}</div>
    <ul class="feed" aria-live="polite">${items}</ul>`;
}

// ---- Events --------------------------------------------------------------------------------------------

let toastTimer = 0;
function toast(msg: string) {
  const el = document.getElementById("toast")!;
  el.textContent = msg;
  el.classList.add("show");
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => el.classList.remove("show"), 2600);
}

function setMode(mode: Mode) {
  state.mode = mode;
  state.selected = null;
  persist();
  render();
  void refresh();
}

function startFeed() {
  window.clearInterval(state.feedTimer);
  void pollFeed();
  state.feedTimer = window.setInterval(() => {
    if (!document.hidden) void pollFeed();
  }, state.liveOpen ? 4000 : 15000);
}

function openRow(id: string) {
  state.selected = state.selected === id ? null : id;
  renderTable();
  renderDetail();
  if (state.selected) (document.querySelector("#detail .icon-btn") as HTMLElement | null)?.focus({ preventScroll: true });
}

document.addEventListener("click", (e) => {
  const target = e.target as HTMLElement;
  const m = target.closest<HTMLElement>("[data-mode]");
  if (m?.dataset.mode === "live" || m?.dataset.mode === "simulated") return setMode(m.dataset.mode);
  const l = target.closest<HTMLElement>("[data-lang]");
  if (l?.dataset.lang === "en" || l?.dataset.lang === "ja") {
    state.lang = l.dataset.lang;
    persist();
    render();
    // The simulated pilot is fetched per language (its setting and currency change).
    if (isSim() && !state.metrics.has(metricsKey())) void refresh();
    return;
  }
  if (target.closest(".nav-item")) {
    state.navOpen = false;
    document.body.classList.remove("nav-open");
  }
  const sortBtn = target.closest<HTMLElement>("[data-sort]");
  const ct = currentTable();
  if (sortBtn && ct) {
    const ui = tableUi(ct.key, ct.view);
    const key = sortBtn.dataset.sort!;
    const col = COLUMNS[ct.table].find((c) => c.key === key)!;
    const first: 1 | -1 = isNumeric(col) || col.fmt === "risk" ? -1 : 1;
    ui.query.sort = ui.query.sort?.key === key ? (ui.query.sort.dir === first ? { key, dir: (first * -1) as 1 | -1 } : null) : { key, dir: first };
    return renderTable();
  }
  const rowEl = target.closest<HTMLElement>("[data-row]");
  if (rowEl) return openRow(rowEl.dataset.row!);
  const rm = target.closest<HTMLElement>("[data-rm-filter]");
  if (rm && ct) {
    tableUi(ct.key, ct.view).query.filters.splice(Number(rm.dataset.rmFilter), 1);
    return render();
  }
  const dens = target.closest<HTMLElement>("[data-density]");
  if (dens) {
    state.density = dens.dataset.density === "compact" ? "compact" : "comfortable";
    persist();
    for (const b of document.querySelectorAll<HTMLElement>("[data-density]")) b.setAttribute("aria-pressed", String(b.dataset.density === state.density));
    return renderTable();
  }
  const ha = target.closest<HTMLElement>("[data-heat-area]");
  if (ha) {
    state.heatArea = ha.dataset.heatArea!;
    return render();
  }
  const act = target.closest<HTMLElement>("[data-act]")?.dataset.act;
  if (!act) {
    if (state.popover && !target.closest(".popover")) {
      state.popover = null;
      renderPopover();
    }
    return;
  }
  if (act === "pop-filter" || act === "pop-columns") {
    const want = act === "pop-filter" ? "filter" : "columns";
    state.popover = state.popover === want ? null : want;
    return renderPopover();
  }
  if (act === "clear-filters" && ct) {
    tableUi(ct.key, ct.view).query.filters = [];
    return render();
  }
  if (act === "reset-view" && ct) {
    state.tables.delete(ct.key);
    state.selected = null;
    return render();
  }
  if (act === "csv") return csvExport();
  if (act === "close-detail") {
    state.selected = null;
    renderTable();
    return renderDetail();
  }
  if (act === "close-live" || act === "toggle-live") {
    state.liveOpen = act === "toggle-live" ? !state.liveOpen : false;
    renderLive();
    renderLiveButton();
    return startFeed();
  }
  if (act === "mock") return toast(u().mockToast);
  if (act === "nav") {
    state.navOpen = !state.navOpen;
    document.body.classList.toggle("nav-open", state.navOpen);
    return;
  }
  if (act === "calc-reset") {
    state.calc[currency()] = { ...CALC_DEFAULTS_BY_CURRENCY[currency()] };
    return render();
  }
});

document.addEventListener("change", (e) => {
  const target = e.target as HTMLElement;
  if (target.id === "demo-only") {
    state.demoOnly = (target as HTMLInputElement).checked;
    persist();
    state.seenFeed.clear();
    state.feed = null;
    renderLive();
    void pollFeed();
    if (!isSim()) void refresh();
    return;
  }
  if (target.id === "f-key") return renderFilterValue();
  const col = (target as HTMLInputElement).dataset?.col;
  const ct = currentTable();
  if (col && ct) {
    const ui = tableUi(ct.key, ct.view);
    const order = COLUMNS[ct.table].map((c) => c.key);
    ui.columns = (target as HTMLInputElement).checked ? order.filter((k) => ui.columns.includes(k) || k === col) : ui.columns.filter((k) => k !== col);
    return renderTable();
  }
});

document.addEventListener("submit", (e) => {
  const form = e.target as HTMLFormElement;
  if (form.id !== "filter-form") return;
  e.preventDefault();
  const ct = currentTable();
  if (!ct) return;
  const fd = new FormData(form);
  const key = String(fd.get("key"));
  const col = COLUMNS[ct.table].find((c) => c.key === key)!;
  let f: Filter | null = null;
  if (isNumeric(col)) {
    const raw = Number(fd.get("num"));
    if (Number.isFinite(raw)) f = { key, op: fd.get("op") === "lte" ? "lte" : "gte", value: col.fmt === "pct" || col.fmt === "pp" ? raw / 100 : raw };
  } else {
    const vals = fd.getAll("v").map(String);
    if (vals.length) f = { key, op: "in", value: vals };
  }
  if (f) tableUi(ct.key, ct.view).query.filters.push(f);
  state.popover = null;
  render();
});

document.addEventListener("input", (e) => {
  const target = e.target as HTMLInputElement;
  if (target.id !== "tbl-search") return;
  const ct = currentTable();
  if (!ct) return;
  tableUi(ct.key, ct.view).query.search = target.value;
  renderTable();
});

document.addEventListener("keydown", (e) => {
  const target = e.target as HTMLElement;
  if (e.key === "Enter" && target.matches("tr[data-row]")) {
    e.preventDefault();
    return openRow(target.dataset.row!);
  }
  if ((e.key === "ArrowDown" || e.key === "ArrowUp") && target.matches("tr[data-row]")) {
    e.preventDefault();
    const next = (e.key === "ArrowDown" ? target.nextElementSibling : target.previousElementSibling) as HTMLElement | null;
    next?.focus();
    return;
  }
  if (e.key === "/" && !(target instanceof HTMLInputElement) && !(target instanceof HTMLTextAreaElement)) {
    const s = document.getElementById("tbl-search");
    if (s) {
      e.preventDefault();
      s.focus();
    }
    return;
  }
  if (e.key === "Escape") {
    if (state.popover) {
      state.popover = null;
      return renderPopover();
    }
    if (state.selected) {
      const id = state.selected;
      state.selected = null;
      renderTable();
      renderDetail();
      (document.querySelector(`tr[data-row="${CSS.escape(id)}"]`) as HTMLElement | null)?.focus();
      return;
    }
    if (state.liveOpen) {
      state.liveOpen = false;
      renderLive();
      renderLiveButton();
      return;
    }
    if (state.navOpen) {
      state.navOpen = false;
      document.body.classList.remove("nav-open");
    }
  }
});

window.addEventListener("hashchange", () => {
  state.route = parseRoute();
  state.selected = null;
  state.popover = null;
  render();
  document.getElementById("content")?.focus({ preventScroll: true });
  window.scrollTo({ top: 0 });
});
// Re-pull live aggregates every 30 s so new demo players also reach the tables.
window.setInterval(() => {
  if (!isSim() && !document.hidden) void refresh();
}, 30_000);
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", render);

state.route = parseRoute();
if (!location.hash && launch.view) {
  state.route = { kind: "view", id: launch.view };
  history.replaceState(null, "", hrefOf(state.route));
}
render();
void refresh();
startFeed();
