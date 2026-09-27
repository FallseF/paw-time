// Pay on shop-side postings for the simulated pilot, in the locale skin's currency.
// Wages come from each shop's pay level in the model; the pay-style mix comes from the
// job_accept events, so it is the same in every locale (only the labels differ).
import { TELEMETRY_PAY_STYLES as PAY_STYLES, type InsightsPay, type InsightsSkin } from "@paw-time/api-contracts";
import { K_MIN, type FlatEvent } from "./aggregate.js";

export interface ShopPay {
  shop: string;
  level: number; // 0..1
  bands: readonly string[];
}

export function payAnswers(events: FlatEvent[], shops: ShopPay[], skin: InsightsSkin): InsightsPay {
  const accepts = new Map<string, { total: number; byStyle: Map<string, { n: number; who: Set<string> }> }>();
  for (const e of events) {
    if (e.type !== "job_accept" || typeof e.props.shop_id !== "string" || typeof e.props.pay_style !== "string") continue;
    let a = accepts.get(e.props.shop_id);
    if (!a) accepts.set(e.props.shop_id, (a = { total: 0, byStyle: new Map() }));
    a.total++;
    let s = a.byStyle.get(e.props.pay_style);
    if (!s) a.byStyle.set(e.props.pay_style, (s = { n: 0, who: new Set() }));
    s.n++;
    s.who.add(e.install_id);
  }
  const round = (x: number) => Math.round(x * 1000) / 1000;
  return {
    currency: skin.currency,
    shops: shops.map(({ shop, level }) => {
      const a = accepts.get(shop);
      return {
        shop,
        hourly_wage: skin.wage(level, "day"),
        pay_styles: PAY_STYLES.map((key) => {
          const s = a?.byStyle.get(key);
          return { key, share: a && s && s.who.size >= K_MIN ? round(s.n / a.total) : null };
        }),
      };
    }),
    listings: shops.flatMap(({ shop, level, bands }) => bands.map((band) => ({ shop, band, hourly_wage: skin.wage(level, band) }))),
  };
}
