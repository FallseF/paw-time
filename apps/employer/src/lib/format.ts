import { zonedParts } from "@paw-time/shop-console";
import type { AggregateCount, Currency, Locale } from "@paw-time/shop-console";
import type { Dict } from "./i18n";

/**
 * The one money formatter: "$22.00", "$1,240", "¥1,300". Hourly wages always show cents in USD;
 * yen never has decimals and always uses the half-width "¥".
 */
export function fmtMoney(v: number, currency: Currency, opts: { cents?: boolean; perHour?: string } = {}): string {
  if (!Number.isFinite(v)) return "—";
  const neg = v < 0 ? "−" : "";
  const abs = Math.abs(v);
  let body: string;
  if (currency === "JPY") body = new Intl.NumberFormat("ja-JP", { maximumFractionDigits: 0 }).format(Math.round(abs));
  else {
    const cents = opts.cents ?? Math.round(abs * 100) % 100 !== 0;
    body = new Intl.NumberFormat("en-US", { minimumFractionDigits: cents ? 2 : 0, maximumFractionDigits: 2 }).format(abs);
  }
  return `${neg}${currency === "USD" ? "$" : "¥"}${body}${opts.perHour ?? ""}`;
}

const intlLocale = (l: Locale) => (l === "ja" ? "ja-JP" : "en-US");

/** "Sat, Oct 3" / "10月3日(土)" for a calendar date. */
export function fmtDate(date: string, locale: Locale, opts: { weekday?: boolean; long?: boolean } = {}): string {
  const d = new Date(`${date}T12:00:00Z`);
  const f = new Intl.DateTimeFormat(intlLocale(locale), {
    timeZone: "UTC",
    month: opts.long ? "long" : "short",
    day: "numeric",
    ...(opts.weekday === false ? {} : { weekday: opts.long ? "long" : "short" }),
  });
  return f.format(d);
}

export function fmtWeekday(date: string, locale: Locale, style: "short" | "long" = "short"): string {
  return new Intl.DateTimeFormat(intlLocale(locale), { timeZone: "UTC", weekday: style }).format(new Date(`${date}T12:00:00Z`));
}

/** "5:00 PM" / "17:00" for a wall-clock "HH:MM". */
export function fmtTime(time: string, locale: Locale): string {
  if (locale === "ja") return time;
  const [h = 0, m = 0] = time.split(":").map(Number);
  const hour12 = h % 12 === 0 ? 12 : h % 12;
  return `${hour12}:${String(m).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}

export function fmtRange(start: string, end: string, locale: Locale): string {
  if (locale === "ja") return `${start}〜${end}`;
  const s = fmtTime(start, locale);
  const e = fmtTime(end, locale);
  // "5:00–9:00 PM" when both are in the same half of the day.
  if (s.slice(-2) === e.slice(-2)) return `${s.slice(0, -3)}–${e}`;
  return `${s} – ${e}`;
}

/** Local wall time of an instant in the shop's time zone. */
export function instantTime(iso: string, timeZone: string, locale: Locale): string {
  const p = zonedParts(new Date(iso), timeZone);
  return fmtTime(`${String(p.hour).padStart(2, "0")}:${String(p.minute).padStart(2, "0")}`, locale);
}

export function instantDate(iso: string, timeZone: string): string {
  return zonedParts(new Date(iso), timeZone).date;
}

/** "Today 2:05 PM", "Yesterday 9:40 PM", "Sep 24, 4:31 PM". */
export function fmtInstant(iso: string, timeZone: string, locale: Locale, today: string, t: Dict): string {
  const date = instantDate(iso, timeZone);
  const time = instantTime(iso, timeZone, locale);
  const y = new Date(`${today}T12:00:00Z`);
  y.setUTCDate(y.getUTCDate() - 1);
  const yesterday = y.toISOString().slice(0, 10);
  const dayLabel = date === today ? t.time.today : date === yesterday ? t.time.yesterday : fmtDate(date, locale, { weekday: false });
  return locale === "ja" ? `${dayLabel} ${time}` : `${dayLabel}, ${time}`;
}

export function fmtAgo(iso: string, now: Date, t: Dict): string {
  const mins = Math.max(0, Math.round((now.getTime() - Date.parse(iso)) / 60_000));
  if (mins < 1) return t.time.justNow;
  if (mins < 60) return t.time.ago(mins, "m");
  const hours = Math.round(mins / 60);
  if (hours < 24) return t.time.ago(hours, "h");
  return t.time.ago(Math.round(hours / 24), "d");
}

/** "Saturday evening" / "土曜の夕方" for alerts. */
export function fmtWhen(date: string, start: string, today: string, locale: Locale, t: Dict): string {
  const h = Number(start.slice(0, 2));
  const part = h >= 17 ? t.time.evening : h >= 12 ? t.time.afternoon : t.time.morning;
  const tomorrow = new Date(`${today}T12:00:00Z`);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  const day = date === today ? t.time.today : date === tomorrow.toISOString().slice(0, 10) ? t.time.tomorrow : fmtWeekday(date, locale, "long");
  if (locale === "ja") return `${day}の${part}`;
  return `${day} ${part}`;
}

export function fmtCount(n: AggregateCount, t: Dict): string {
  return n === null ? t.common.fewerThan5 : new Intl.NumberFormat("en-US").format(n);
}

/** "September 2026" / "2026年9月" for a "YYYY-MM" month. */
export function fmtMonth(month: string, locale: Locale): string {
  return new Intl.DateTimeFormat(intlLocale(locale), { timeZone: "UTC", year: "numeric", month: "long" }).format(new Date(`${month}-15T12:00:00Z`));
}
