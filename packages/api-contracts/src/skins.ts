// Locale "skins" for the simulated pilot. Both languages render the same seeded model:
// every count, rate and risk score is identical, only the setting changes (place names,
// currency, wage scale, time zone). Zod-free so the static dashboard can bundle it.

export const INSIGHTS_LOCALES = ["en", "ja"] as const;
export type InsightsLocale = (typeof INSIGHTS_LOCALES)[number];
export const isInsightsLocale = (v: unknown): v is InsightsLocale => v === "en" || v === "ja";

export type InsightsCurrency = "USD" | "JPY";

export interface InsightsSkin {
  locale: InsightsLocale;
  /** Where the simulated pilot is set. */
  place: string;
  currency: InsightsCurrency;
  /** IANA zone for any date/time shown in this skin. */
  time_zone: string;
  /** Local minimum hourly wage the synthetic wages must stay above. */
  min_wage: number;
  /** Hourly wage for a shop's wage level (0..1, from the model) and time band. */
  wage: (level: number, band: string) => number;
}

const roundTo = (x: number, step: number) => Math.round(x / step) * step;

export const INSIGHTS_SKINS: Record<InsightsLocale, InsightsSkin> = {
  // San Francisco, entry-level hourly work. SF minimum wage is $19.61/h from 2026-07-01
  // (sf.gov, Minimum Wage Ordinance, checked 2026-09-27); the wage scale spans $20.00-$28.00 (simulated shops: $21.00-$25.75).
  // Night shifts get a $1.50 differential (common practice, not required by CA law).
  en: {
    locale: "en",
    place: "San Francisco",
    currency: "USD",
    time_zone: "America/Los_Angeles",
    min_wage: 19.61,
    wage: (level, band) => roundTo(20 + level * 6.5, 0.25) + (band === "night" ? 1.5 : 0),
  },
  // A Japanese town. Tokyo minimum wage is ¥1,226/h from 2025-10-03 (Tokyo Labour Bureau);
  // synthetic wages start at ¥1,300. Late-night work (22:00-5:00) is paid +25% (Labour
  // Standards Act art. 37).
  ja: {
    locale: "ja",
    place: "日本の架空の街",
    currency: "JPY",
    time_zone: "Asia/Tokyo",
    min_wage: 1226,
    wage: (level, band) => roundTo((1300 + level * 250) * (band === "night" ? 1.25 : 1), 10),
  },
};
