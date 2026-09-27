import { INSIGHTS_SKINS, InsightsMetricsResponseSchema } from "@paw-time/api-contracts";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { beforeEach, test } from "node:test";
import { app } from "../src/app.js";
import { aggregate, dayOf, type FlatEvent } from "../src/modules/insights/aggregate.js";
import { FILL_PRIOR, forecastFill, reactionNoShow, riskScore, supplyGrid } from "../src/modules/insights/recruit.js";
import { clearInsightsCache } from "../src/modules/insights/service.js";
import { telemetryLimiter } from "../src/modules/telemetry/rate-limit.js";
import { MemoryTelemetryStore, setTelemetryStore } from "../src/modules/telemetry/store.js";

beforeEach(() => {
  setTelemetryStore(new MemoryTelemetryStore());
  telemetryLimiter.reset();
  clearInsightsCache();
});

const post = (body: unknown) =>
  app.request("/v1/telemetry/events", {
    method: "POST",
    headers: { "content-type": "application/json", origin: "https://paw-time-play.vercel.app" },
    body: JSON.stringify(body),
  });

// ---- Risk score ---------------------------------------------------------------------

test("risk score: healthy shop scores 0, every signal at full strength scores 100", () => {
  const healthy = riskScore({ workers: 20, return_delta: 0.05, repeat_pass: 0.02, issue_workers: 0, stars_change: 0.2 });
  assert.equal(healthy.score, 0);
  assert.deepEqual(healthy.reasons, []);
  const worst = riskScore({ workers: 20, return_delta: -0.2, repeat_pass: 0.6, issue_workers: 10, stars_change: -1 });
  assert.equal(worst.score, 100);
  assert.deepEqual(worst.reasons, ["return_drop", "repeat_pass", "issue_tags", "review_trend"], "strongest weighted signal first");
});

test("risk score: partial signals are weighted, missing ones count as zero", () => {
  // next-day return 7.5 pt below baseline = half of 35 points; nothing else known.
  const r = riskScore({ workers: 10, return_delta: -0.075, repeat_pass: null, issue_workers: 0, stars_change: null });
  assert.equal(r.score, 18); // 17.5 rounded
  assert.equal(r.components.return_drop, 0.5);
  assert.deepEqual(r.reasons, ["return_drop"]);
  // 5 of 20 workers behind issue tags = 25% = full 25 points.
  assert.equal(riskScore({ workers: 20, return_delta: null, repeat_pass: null, issue_workers: 5, stars_change: null }).score, 25);
  // A weak signal (below 30% of its range) is not listed as a reason.
  assert.deepEqual(riskScore({ workers: 20, return_delta: -0.03, repeat_pass: null, issue_workers: 0, stars_change: null }).reasons, []);
});

// ---- Fill forecast and no-show --------------------------------------------------------

test("fill forecast: history smoothed towards the band's market fill, supply trend capped", () => {
  // 10 openings, 5 filled, market 0.8, flat supply: (5 + 8*0.8) / (10 + 8) = 0.6333
  assert.ok(Math.abs(forecastFill({ openings: 10, filled: 5 }, 0.8, 50, 50) - 11.4 / 18) < 1e-9);
  assert.equal(FILL_PRIOR, 8);
  // A listing with no history falls back to the market.
  assert.equal(forecastFill({ openings: 0, filled: 0 }, 0.7, 10, 10), 0.7);
  // Supply up 4x: sqrt would be 2x, capped at +30%.
  assert.ok(Math.abs(forecastFill({ openings: 100, filled: 50 }, 0.5, 10, 40) - 0.65) < 1e-9);
  // Never above 1.
  assert.equal(forecastFill({ openings: 100, filled: 100 }, 1, 10, 40), 1);
});

test("no-show from reminder reactions is the reaction mix weighted by each reaction's rate", () => {
  assert.equal(reactionNoShow({ ok: 3, dismissed: 1 }, { ok: 0.04, dismissed: 0.2 }), (3 * 0.04 + 0.2) / 4);
  assert.equal(reactionNoShow({ swap: 2 }, { swap: null }), null, "unknown rate (suppressed) is skipped");
});

// ---- Supply grid ------------------------------------------------------------------------

test("supply grid: < 5 willing workers is suppressed, tired / capped workers are excluded", () => {
  const w = (slots: string[], excluded = false) => ({ slots: new Set(slots), area: "harbor", excluded });
  const four = Array.from({ length: 4 }, () => w(["sat_evening"]));
  let cell = supplyGrid(four, null).find((c) => c.slot === "sat_evening")!;
  assert.equal(cell.available, null);
  assert.equal(cell.open_shifts, null, "no postings connected");
  cell = supplyGrid([...four, w(["sat_evening"], true)], new Map([["sat_evening", 2.25]])).find((c) => c.slot === "sat_evening")!;
  assert.equal(cell.available, null, "an excluded worker does not count towards the 5");
  assert.equal(cell.open_shifts, 2.3);
  cell = supplyGrid([...four, w(["sat_evening", "sun_day"])], null).find((c) => c.slot === "sat_evening")!;
  assert.equal(cell.available, 5);
  assert.equal(supplyGrid(four, null).length, 28);
});

// ---- End to end: live data keeps the 5-worker rule --------------------------------------

test("live recruit answers: new events accepted, cells stay hidden until 5 distinct workers", async () => {
  const now = Math.floor(Date.now() / 1000);
  const worker = () => ({
    install_id: randomUUID(),
    events: [
      { t: now - 60, type: "app_open", props: { day_type: "no_shift" } },
      { t: now - 50, type: "availability_set", props: { slots: ["sat_evening", "sun_day"], max_per_week: 2 } },
      { t: now - 40, type: "shop_island_visit", props: { shop_id: "cafe_komorebi" } },
      { t: now - 30, type: "landmark_tap", props: { shop_id: "cafe_komorebi", tag: "on_time" } },
      { t: now - 20, type: "reminder_reaction", props: { when: "night_before", reaction: "ok", shop_id: "cafe_komorebi", slot: "sat_evening" } },
    ],
  });
  for (let i = 0; i < 4; i++) {
    const res = await post(worker());
    assert.deepEqual(await res.json(), { accepted: 5, rejected: [] });
  }
  const bad = await post({ install_id: randomUUID(), events: [{ type: "availability_set", props: { slots: ["saturday night"] } }, { type: "landmark_tap", props: { tag: "hated_it" } }] });
  assert.equal(((await bad.json()) as { accepted: number }).accepted, 0, "slots and landmark tags are enums");

  const get = async () => InsightsMetricsResponseSchema.parse(await (await app.request("/v1/insights/metrics?mode=live")).json()).data.recruit!;
  let r = await get();
  assert.equal(r.supply.cells.find((c) => c.slot === "sat_evening")?.available, null);
  assert.equal(r.interest.landmarks.length, 0);
  assert.equal(r.stages.before.island_visitors, null);
  assert.equal(r.fill.has_postings, false, "live mode has no shop-side postings");

  await post(worker());
  clearInsightsCache();
  r = await get();
  assert.equal(r.supply.cells.find((c) => c.slot === "sat_evening")?.available, 5);
  assert.equal(r.supply.cells.find((c) => c.slot === "mon_morning")?.available, null);
  assert.deepEqual(r.interest.landmarks, [{ key: "on_time", taps: 5, workers: 5 }]);
  assert.equal(r.stages.before.island_visitors, 5);
});

test("at-risk shops: hidden under 5 workers, anonymous issue tags follow the 5-worker rule", () => {
  const day0 = dayOf(Date.UTC(2026, 6, 6) / 1000);
  const t = (day: number, h: number) => day * 86400 - 9 * 3600 + h * 3600;
  const events: FlatEvent[] = [];
  const shift = (id: string, day: number, shop: string) => {
    events.push({ install_id: id, t: t(day, 8), type: "app_open", props: { day_type: "work" } });
    events.push({ install_id: id, t: t(day, 9), type: "shift_start", props: { shop_id: shop } });
    events.push({ install_id: id, t: t(day, 17), type: "shift_end", props: { shop_id: shop, hours_bucket: "6to7_5" } });
  };
  for (let i = 0; i < 6; i++) {
    const id = randomUUID();
    shift(id, day0 + i, "izk_torimaru");
    // Only 4 of 6 send the same anonymous issue: it must not reach the score.
    if (i < 4) events.push({ install_id: id, t: t(day0 + i, 18), type: "anon_issue_sent", props: { tag: "yelled_at", shop_id: "izk_torimaru" } });
  }
  for (let i = 0; i < 3; i++) shift(randomUUID(), day0 + i, "cafe_komorebi");
  const r = aggregate(events, { now: t(day0 + 10, 12), weekLabel: "date" }).recruit!;
  assert.deepEqual(r.at_risk.rows.map((x) => x.shop), ["izk_torimaru"]);
  assert.equal(r.at_risk.hidden_shops, 1);
  assert.deepEqual(r.at_risk.rows[0]!.issue_tags, []);
  assert.equal(r.at_risk.rows[0]!.raw.issue_workers, 0);
  assert.ok(!JSON.stringify(r).match(/[0-9a-f]{8}-[0-9a-f]{4}-4/), "no install ids in the answers");
});

// ---- Simulated pilot ----------------------------------------------------------------------

test("simulated pilot: answers are consistent with the hidden model", async () => {
  const m = InsightsMetricsResponseSchema.parse(await (await app.request("/v1/insights/metrics?mode=simulated")).json());
  const r = m.data.recruit!;
  assert.equal(r.weeks.length, 12);
  // The shop whose culture slides over the pilot, and the draining izakaya, rank as most at risk.
  const top3 = r.at_risk.rows.slice(0, 3).map((x) => x.shop);
  assert.ok(top3.includes("cvs_hoshi") && top3.includes("izk_torimaru"), top3.join(","));
  assert.ok(r.at_risk.rows.every((x) => x.workers >= 5 && x.score >= 0 && x.score <= 100));
  assert.ok(r.at_risk.rows.every((x) => x.issue_tags.every((tag) => tag.workers >= 5)));
  // Fill model beats a naive 50% guess by a wide margin on held-out weeks.
  assert.equal(r.fill.backtest.holdout_weeks, 4);
  assert.ok((r.fill.backtest.mae ?? 1) < 0.1, String(r.fill.backtest.mae));
  const rem = Object.fromEntries(r.fill.reminders.map((x) => [x.reaction, x.no_show_rate ?? NaN]));
  assert.ok(rem.dismissed! > rem.ok! && rem.swap! > rem.ok!, "a dismissed or swap reminder precedes more no-shows");
  assert.ok(r.fill.rows.every((x) => x.history.length === 12));
  // Supply: every cell is either suppressed or backed by 5+ workers.
  assert.ok(r.supply.cells.every((c) => c.available == null || c.available >= 5));
  assert.ok(r.supply.grid.every((c) => c.available == null || c.available >= 5));
  assert.equal(r.supply.grid.length, 3 * 28);
  // Island visitors apply more than people who only opened the card.
  assert.ok((r.interest.visitor_apply_rate ?? 0) > (r.interest.non_visitor_apply_rate ?? 1));
  // Fit: more after-shift signals, more repeat; behaviour beats self-report.
  const bins = r.fit.bins.map((b) => b.repeat_rate ?? NaN);
  assert.ok(bins[3]! > bins[0]!, bins.join(","));
  assert.ok((r.fit.behavior.repeat_rate ?? 0) > (r.fit.self_report.repeat_rate ?? 1));
  assert.equal(r.kpis.active_shops.now, 10);
});

// ---- Locale skins -------------------------------------------------------------------

test("simulated pilot skins: en = San Francisco / USD (default), ja = Japan / JPY, same model underneath", async () => {
  const get = async (q: string) => InsightsMetricsResponseSchema.parse(await (await app.request(`/v1/insights/metrics?mode=simulated${q}`)).json());
  const [def, en, ja, bad] = [await get(""), await get("&lang=en"), await get("&lang=ja"), await get("&lang=fr")];
  assert.deepEqual(def, en, "no lang = en (backward compatible)");
  assert.deepEqual(bad.skin, en.skin, "unknown lang falls back to en");
  assert.deepEqual(en.skin, { locale: "en", place: "San Francisco", currency: "USD", time_zone: "America/Los_Angeles" });
  assert.equal(ja.skin?.currency, "JPY");
  assert.equal(ja.skin?.time_zone, "Asia/Tokyo");

  // Every metric and risk score is identical; only the pay section's currency and amounts differ.
  const strip = (m: typeof en) => ({ ...m.data, recruit: { ...m.data.recruit!, pay: undefined } });
  assert.deepEqual(strip(en), strip(ja));
  assert.deepEqual(en.data.recruit!.at_risk.rows.map((x) => x.shop), ja.data.recruit!.at_risk.rows.map((x) => x.shop), "same risk ordering");
  const enPay = en.data.recruit!.pay!;
  const jaPay = ja.data.recruit!.pay!;
  assert.equal(enPay.currency, "USD");
  assert.equal(jaPay.currency, "JPY");
  assert.equal(enPay.shops.length, 10);
  assert.deepEqual(enPay.shops.map((s) => s.pay_styles), jaPay.shops.map((s) => s.pay_styles), "pay-style mix comes from the same events");
  assert.ok(enPay.shops.every((s) => s.pay_styles.every((p) => p.share == null || (p.share > 0 && p.share < 1))));

  // Wages: realistic SF entry-level range above the local minimum; yen above Tokyo's minimum.
  const usd = enPay.listings.map((x) => x.hourly_wage);
  assert.ok(usd.every((w) => w >= INSIGHTS_SKINS.en.min_wage && w >= 20 && w <= 28 && Math.abs(w * 4 - Math.round(w * 4)) < 1e-9), usd.join(","));
  const jpy = jaPay.listings.map((x) => x.hourly_wage);
  assert.ok(jpy.every((w) => w >= INSIGHTS_SKINS.ja.min_wage && Number.isInteger(w) && w % 10 === 0), jpy.join(","));
  // The shop that pays more pays more in both currencies; night pays at least the day rate.
  const order = (p: typeof enPay) => [...p.shops].sort((a, b) => a.hourly_wage - b.hourly_wage || a.shop.localeCompare(b.shop)).map((s) => s.shop);
  assert.deepEqual(order(enPay), order(jaPay));
  for (const p of [enPay, jaPay]) {
    for (const l of p.listings) assert.ok(l.hourly_wage >= p.shops.find((s) => s.shop === l.shop)!.hourly_wage);
  }
  // Every listing in the fill table has a wage.
  for (const f of en.data.recruit!.fill.rows) assert.ok(enPay.listings.some((l) => l.shop === f.shop && l.band === f.band), `${f.shop}:${f.band}`);
});

test("live metrics carry no skin or synthetic pay", async () => {
  const m = InsightsMetricsResponseSchema.parse(await (await app.request("/v1/insights/metrics?mode=live&lang=ja")).json());
  assert.equal(m.skin, undefined);
  assert.equal(m.data.recruit?.pay, undefined);
});
