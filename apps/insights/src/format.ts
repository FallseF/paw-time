import type { Dict } from "./i18n";

const ESC: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
/** Every string that reaches innerHTML goes through this. */
export const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ESC[c] ?? c);

export const fillTemplate = (tpl: string, vars: Record<string, string>) => tpl.replace(/\{(\w+)\}/g, (_, k: string) => vars[k] ?? "");

/** null = suppressed cell (< 5 installs) and renders as an em dash. */
export const fmtN = (v: number | null | undefined, locale = "en-US") => (v == null ? "—" : new Intl.NumberFormat(locale).format(v));
export const fmtPct = (v: number | null | undefined, digits = 0) => (v == null ? "—" : `${(v * 100).toFixed(digits)}%`);
/** Difference of two rates as signed percentage points. */
export const fmtPp = (v: number | null | undefined) => (v == null ? "—" : `${v > 0 ? "+" : v < 0 ? "−" : "±"}${Math.abs(v * 100).toFixed(1)} pt`);

export type Currency = "USD" | "JPY";
/** The currency each dashboard language is set in: en = San Francisco (USD), ja = Japan (JPY). */
export const currencyOf = (lang: "en" | "ja"): Currency => (lang === "ja" ? "JPY" : "USD");
export const currencySymbol = (c: Currency) => (c === "USD" ? "$" : "¥");

/**
 * Money in the given currency: "$24.50", "$1,240", "¥1,500". USD shows cents when asked
 * (hourly pay, per-worker values) or when the amount has them; yen never has decimals.
 * Always "¥" (Intl's ja-JP JPY would print the full-width "￥").
 */
export function fmtMoney(v: number | null | undefined, currency: Currency, opts: { cents?: boolean; perHour?: string } = {}): string {
  if (v == null || !Number.isFinite(v)) return "—";
  const neg = v < 0 ? "−" : "";
  const abs = Math.abs(v);
  let body: string;
  if (currency === "JPY") body = new Intl.NumberFormat("ja-JP", { maximumFractionDigits: 0 }).format(Math.round(abs));
  else {
    const cents = opts.cents ?? Math.round(abs * 100) % 100 !== 0;
    body = new Intl.NumberFormat("en-US", { minimumFractionDigits: cents ? 2 : 0, maximumFractionDigits: cents ? 2 : 0 }).format(cents ? abs : Math.round(abs));
  }
  return `${neg}${currencySymbol(currency)}${body}${opts.perHour ?? ""}`;
}

export const labelOf = (group: Record<string, string>, key: string) => group[key] ?? key;

/** One anonymous feed line, e.g. "Job accepted · Register". */
export function feedText(t: Dict, type: string, props: Record<string, unknown>): string {
  return labelOf(t.events, type).replace(/\{(\w+)\}/g, (_, k: string) => {
    const v = props[k];
    if (v == null) return "—";
    if (k === "role") return labelOf(t.roles, String(v));
    if (k === "hours_bucket") return labelOf(t.hours, String(v));
    if (k === "shop_id") return labelOf(t.shops, String(v));
    if (k === "day_type") return labelOf(t.dayType, String(v));
    if (k === "tag") return labelOf(t.tags, String(v));
    if (k === "reaction") return labelOf(t.reactions, String(v));
    if (k === "on") return t.onOff[v ? 1 : 0] ?? "";
    if (k === "kind" && type === "hatch") return labelOf(t.hatchKind, String(v));
    if (k === "kind") return v === "google" ? "Google" : ".ics";
    return String(v);
  });
}
