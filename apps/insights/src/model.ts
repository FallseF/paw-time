// Table model for the explorer: turns the aggregate payload into rows of entities
// (shops, listings, supply slots, shop-weeks). Never individual workers. Pure: no DOM.
import type { InsightsAggregate } from "@paw-time/api-contracts";
import { insightsAreaOf } from "@paw-time/api-contracts/areas";

export type TableId = "shops" | "listings" | "supply" | "signals";
export type Fmt = "text" | "enum" | "int" | "num1" | "pct" | "pp" | "stars" | "dstars" | "risk" | "status" | "spark" | "tags";
export interface Column {
  key: string;
  fmt: Fmt;
  /** i18n group for enum values (shops, areas, bands, days, status, tags). */
  group?: string;
  /** Higher is better (for ▲▼ colouring of deltas). */
  better?: "up" | "down";
}
export type Value = string | number | null | string[] | (number | null)[];
export interface Row {
  id: string;
  table: TableId;
  [key: string]: Value;
}

export type RiskLevel = "high" | "medium" | "low";
export const riskLevel = (score: number): RiskLevel => (score >= 50 ? "high" : score >= 30 ? "medium" : "low");

export const COLUMNS: Record<TableId, Column[]> = {
  shops: [
    { key: "shop", fmt: "enum", group: "shops" },
    { key: "area", fmt: "enum", group: "areas" },
    { key: "risk", fmt: "risk" },
    { key: "risk_score", fmt: "int", better: "down" },
    { key: "workers", fmt: "int" },
    { key: "return_delta", fmt: "pp", better: "up" },
    { key: "trend", fmt: "spark" },
    { key: "repeat_pass", fmt: "pct", better: "down" },
    { key: "issue_workers", fmt: "int", better: "down" },
    { key: "issue_tags", fmt: "tags", group: "topics" },
    { key: "stars_change", fmt: "dstars", better: "up" },
    { key: "island_visitors", fmt: "int" },
    { key: "apply_rate", fmt: "pct", better: "up" },
    { key: "top_landmark", fmt: "enum", group: "tags" },
    { key: "fill_rate", fmt: "pct", better: "up" },
    { key: "no_show_rate", fmt: "pct", better: "down" },
    { key: "repeat_rate", fmt: "pct", better: "up" },
    { key: "strong_signal_share", fmt: "pct", better: "up" },
  ],
  listings: [
    { key: "shop", fmt: "enum", group: "shops" },
    { key: "band", fmt: "enum", group: "bands" },
    { key: "area", fmt: "enum", group: "areas" },
    { key: "status", fmt: "status", group: "listingStatus" },
    { key: "openings_per_week", fmt: "num1" },
    { key: "predicted_fill", fmt: "pct", better: "up" },
    { key: "history", fmt: "spark" },
    { key: "no_show_risk", fmt: "pct", better: "down" },
    { key: "backtest_predicted", fmt: "pct" },
    { key: "backtest_actual", fmt: "pct" },
    { key: "fill_rate", fmt: "pct", better: "up" },
    { key: "no_show_rate", fmt: "pct", better: "down" },
  ],
  supply: [
    { key: "area", fmt: "enum", group: "areas" },
    { key: "day", fmt: "enum", group: "days" },
    { key: "band", fmt: "enum", group: "bands" },
    { key: "status", fmt: "status", group: "supplyStatus" },
    { key: "available", fmt: "int", better: "up" },
    { key: "open_shifts", fmt: "num1", better: "down" },
    { key: "cover", fmt: "num1", better: "up" },
  ],
  signals: [
    { key: "shop", fmt: "enum", group: "shops" },
    { key: "week", fmt: "text" },
    { key: "area", fmt: "enum", group: "areas" },
    { key: "workers", fmt: "int" },
    { key: "next_day_return", fmt: "pct", better: "up" },
    { key: "baseline", fmt: "pct" },
    { key: "return_delta", fmt: "pp", better: "up" },
    { key: "invite_pass_share", fmt: "pct", better: "down" },
    { key: "issue_workers", fmt: "int", better: "down" },
    { key: "stars_avg", fmt: "stars", better: "up" },
    { key: "island_visitors", fmt: "int" },
    { key: "openings", fmt: "int" },
    { key: "filled", fmt: "int" },
    { key: "fill_rate", fmt: "pct", better: "up" },
    { key: "no_shows", fmt: "int", better: "down" },
  ],
};

/** Columns shown by default (the rest are one click away in "Columns"). */
export const DEFAULT_VISIBLE: Record<TableId, string[]> = {
  shops: ["shop", "area", "risk", "risk_score", "workers", "return_delta", "trend", "repeat_pass", "issue_workers", "stars_change", "fill_rate", "repeat_rate"],
  listings: ["shop", "band", "area", "status", "openings_per_week", "predicted_fill", "history", "no_show_risk", "backtest_actual"],
  supply: ["area", "day", "band", "status", "available", "open_shifts", "cover"],
  signals: ["shop", "week", "workers", "next_day_return", "baseline", "return_delta", "invite_pass_share", "issue_workers", "stars_avg", "island_visitors", "fill_rate", "no_shows"],
};

const fillOf = (o: number | null, f: number | null) => (o && f != null ? f / o : null);

export function shopRows(a: InsightsAggregate): Row[] {
  const r = a.recruit;
  if (!r) return [];
  const shops = new Set<string>([...r.at_risk.rows.map((x) => x.shop), ...r.fit.shops.map((x) => x.shop), ...r.interest.rows.map((x) => x.shop), ...r.fill.rows.map((x) => x.shop)]);
  return [...shops].map((shop) => {
    const risk = r.at_risk.rows.find((x) => x.shop === shop);
    const interest = r.interest.rows.find((x) => x.shop === shop);
    const fit = r.fit.shops.find((x) => x.shop === shop);
    const weeks = r.signals.filter((x) => x.shop === shop);
    const opened = weeks.reduce((s, x) => s + (x.openings ?? 0), 0);
    const filled = weeks.reduce((s, x) => s + (x.filled ?? 0), 0);
    const noShows = weeks.reduce((s, x) => s + (x.no_shows ?? 0), 0);
    return {
      id: `shop:${shop}`,
      table: "shops",
      shop,
      area: insightsAreaOf(shop),
      risk: risk ? riskLevel(risk.score) : null,
      risk_score: risk?.score ?? null,
      workers: risk?.workers ?? null,
      return_delta: risk?.raw.return_delta ?? null,
      trend: weeks.map((x) => (x.next_day_return != null && x.baseline != null ? x.next_day_return - x.baseline : null)),
      repeat_pass: risk?.raw.repeat_pass ?? null,
      issue_workers: risk ? risk.raw.issue_workers : null,
      issue_tags: risk ? risk.issue_tags.map((t) => t.key) : [],
      stars_change: risk?.raw.stars_change ?? null,
      island_visitors: interest?.visitors ?? null,
      apply_rate: interest?.apply_rate ?? null,
      top_landmark: interest?.top_landmark ?? null,
      fill_rate: r.fill.has_postings && opened ? filled / opened : null,
      no_show_rate: r.fill.has_postings && filled ? noShows / filled : null,
      repeat_rate: fit?.repeat_rate ?? null,
      strong_signal_share: fit?.strong_signal_share ?? null,
    };
  });
}

export type ListingStatus = "likely_unfilled" | "no_show_risk" | "on_track";
export const LISTING_UNFILLED = 0.6;
export const LISTING_NO_SHOW = 0.1;
export const listingStatus = (predicted: number, noShow: number | null): ListingStatus =>
  predicted < LISTING_UNFILLED ? "likely_unfilled" : (noShow ?? 0) >= LISTING_NO_SHOW ? "no_show_risk" : "on_track";

export function listingRows(a: InsightsAggregate): Row[] {
  const r = a.recruit;
  if (!r) return [];
  return r.fill.rows.map((x) => ({
    id: `listing:${x.shop}:${x.band}`,
    table: "listings",
    shop: x.shop,
    band: x.band,
    area: insightsAreaOf(x.shop),
    status: listingStatus(x.predicted_fill, x.no_show_risk),
    openings_per_week: x.openings_per_week,
    predicted_fill: x.predicted_fill,
    history: x.history,
    no_show_risk: x.no_show_risk,
    backtest_predicted: x.backtest_predicted,
    backtest_actual: x.backtest_actual,
    fill_rate: x.fill_rate,
    no_show_rate: x.no_show_rate,
  }));
}

/** A slot counts as untapped when 2+ shifts a week stay open while 5+ willing workers are available. */
export const UNTAPPED_MIN_OPEN = 2;
export type SupplyStatus = "untapped" | "covered" | "hidden" | "no_postings";
export function supplyStatus(available: number | null, open: number | null): SupplyStatus {
  if (available == null) return "hidden";
  if (open == null) return "no_postings";
  return open >= UNTAPPED_MIN_OPEN ? "untapped" : "covered";
}

export function supplyRows(a: InsightsAggregate): Row[] {
  const r = a.recruit;
  if (!r) return [];
  return r.supply.grid.map((c) => {
    const [day, band] = c.slot.split("_") as [string, string];
    return {
      id: `supply:${c.area}:${c.slot}`,
      table: "supply",
      area: c.area,
      day,
      band,
      slot: c.slot,
      status: supplyStatus(c.available, c.open_shifts),
      available: c.available,
      open_shifts: c.open_shifts,
      // Willing workers per open shift: how easy the gap is to fill from Paw Time's pool.
      cover: c.available != null && c.open_shifts ? Math.round((c.available / c.open_shifts) * 10) / 10 : null,
    };
  });
}

export function signalRows(a: InsightsAggregate): Row[] {
  const r = a.recruit;
  if (!r) return [];
  return r.signals.map((x, i) => ({
    id: `signal:${x.shop}:${x.week}`,
    table: "signals",
    order: i,
    shop: x.shop,
    week: x.week,
    area: insightsAreaOf(x.shop),
    workers: x.workers,
    next_day_return: x.next_day_return,
    baseline: x.baseline,
    return_delta: x.next_day_return != null && x.baseline != null ? Math.round((x.next_day_return - x.baseline) * 1000) / 1000 : null,
    invite_pass_share: x.invite_pass_share,
    issue_workers: x.issue_workers,
    stars_avg: x.stars_avg,
    island_visitors: x.island_visitors,
    openings: x.openings,
    filled: x.filled,
    fill_rate: fillOf(x.openings, x.filled),
    no_shows: x.no_shows,
  }));
}

// ---- Query --------------------------------------------------------------------------

export type FilterOp = "eq" | "in" | "gte" | "lte";
export interface Filter {
  key: string;
  op: FilterOp;
  value: string | number | string[];
}
export interface Query {
  search: string;
  filters: Filter[];
  sort: { key: string; dir: 1 | -1 } | null;
}

function matches(row: Row, f: Filter): boolean {
  const v = row[f.key];
  switch (f.op) {
    case "eq":
      return v === f.value;
    case "in":
      return Array.isArray(f.value) && typeof v === "string" && f.value.includes(v);
    case "gte":
      return typeof v === "number" && v >= Number(f.value);
    case "lte":
      return typeof v === "number" && v <= Number(f.value);
  }
}

/** Filter, search (over the displayed text of every visible column) and sort. Nulls sort last. */
export function applyQuery(rows: Row[], q: Query, text: (row: Row) => string): Row[] {
  const needle = q.search.trim().toLowerCase();
  const out = rows.filter((row) => q.filters.every((f) => matches(row, f)) && (!needle || text(row).toLowerCase().includes(needle)));
  if (q.sort) {
    const { key, dir } = q.sort;
    out.sort((a, b) => {
      const x = sortable(a[key]);
      const y = sortable(b[key]);
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      if (typeof x === "number" && typeof y === "number") return (x - y) * dir;
      return String(x).localeCompare(String(y)) * dir;
    });
  }
  return out;
}
const RISK_ORDER: Record<string, number> = { low: 0, medium: 1, high: 2 };
function sortable(v: Value | undefined): string | number | null {
  if (v == null) return null;
  if (Array.isArray(v)) {
    const nums = v.filter((x): x is number => typeof x === "number");
    return nums.length ? nums[nums.length - 1]! : v.length ? v.length : null;
  }
  if (typeof v === "string" && v in RISK_ORDER) return RISK_ORDER[v]!;
  return v;
}

// ---- CSV ----------------------------------------------------------------------------

const csvCell = (s: string) => {
  // Neutralise spreadsheet formulas and quote when needed.
  const safe = /^[=+\-@\t\r]/.test(s) && !/^-?\d/.test(s) ? `'${s}` : s;
  return /[",\n\r]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
};

/** CSV of the aggregated rows. Numbers are raw (rates as 0..1); enums use their display label. */
export function toCsv(rows: Row[], cols: Column[], header: (c: Column) => string, label: (c: Column, v: string) => string): string {
  const lines = [cols.map((c) => csvCell(header(c))).join(",")];
  for (const row of rows) {
    lines.push(
      cols
        .map((c) => {
          const v = row[c.key];
          if (v == null) return "";
          if (Array.isArray(v)) return csvCell(c.fmt === "spark" ? v.map((x) => (x == null ? "" : String(x))).join(" ") : v.map((x) => label(c, String(x))).join("; "));
          if (typeof v === "number") return String(Math.round(v * 10000) / 10000);
          return csvCell(c.group ? label(c, v) : v);
        })
        .join(","),
    );
  }
  return lines.join("\r\n") + "\r\n";
}

// ---- Saved views --------------------------------------------------------------------

export type ViewId = "at-risk" | "unfilled" | "supply" | "interest" | "fit";
export interface SavedView {
  id: ViewId;
  table: TableId;
  query: Query;
  columns: string[];
  feeds: string[];
}

export const VIEWS: SavedView[] = [
  {
    id: "at-risk",
    table: "shops",
    query: { search: "", filters: [{ key: "risk_score", op: "gte", value: 30 }], sort: { key: "risk_score", dir: -1 } },
    columns: ["shop", "area", "risk", "risk_score", "workers", "return_delta", "trend", "repeat_pass", "issue_tags", "stars_change"],
    feeds: ["air_work", "indeed"],
  },
  {
    id: "unfilled",
    table: "listings",
    query: { search: "", filters: [{ key: "status", op: "in", value: ["likely_unfilled", "no_show_risk"] }], sort: { key: "predicted_fill", dir: 1 } },
    columns: ["shop", "band", "area", "status", "openings_per_week", "predicted_fill", "history", "no_show_risk", "backtest_predicted", "backtest_actual"],
    feeds: ["townwork", "air_shift"],
  },
  {
    id: "supply",
    table: "supply",
    query: { search: "", filters: [{ key: "day", op: "in", value: ["sat", "sun"] }, { key: "status", op: "eq", value: "untapped" }], sort: { key: "cover", dir: -1 } },
    columns: ["area", "day", "band", "status", "available", "open_shifts", "cover"],
    feeds: ["air_shift", "townwork"],
  },
  {
    id: "interest",
    table: "shops",
    query: { search: "", filters: [], sort: { key: "island_visitors", dir: -1 } },
    columns: ["shop", "area", "island_visitors", "apply_rate", "top_landmark", "fill_rate", "risk"],
    feeds: ["townwork", "air_work"],
  },
  {
    id: "fit",
    table: "shops",
    query: { search: "", filters: [], sort: { key: "repeat_rate", dir: -1 } },
    columns: ["shop", "area", "repeat_rate", "strong_signal_share", "return_delta", "trend", "stars_change", "risk"],
    feeds: ["indeed"],
  },
];
