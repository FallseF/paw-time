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
