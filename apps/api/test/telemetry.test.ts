import {
  InsightsFeedResponseSchema,
  InsightsMetricsResponseSchema,
  TELEMETRY_MAX_EVENTS_PER_BATCH,
} from "@paw-time/api-contracts";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { beforeEach, test } from "node:test";
import { app } from "../src/app.js";
import { clearInsightsCache } from "../src/modules/insights/service.js";
import { telemetryLimiter } from "../src/modules/telemetry/rate-limit.js";
import { MemoryTelemetryStore, setTelemetryStore } from "../src/modules/telemetry/store.js";

const GAME_ORIGIN = "https://obake-breakroom-b-sleep.vercel.app";
let store: MemoryTelemetryStore;

beforeEach(() => {
  store = new MemoryTelemetryStore();
  setTelemetryStore(store);
  telemetryLimiter.reset();
  clearInsightsCache();
});

const now = () => Math.floor(Date.now() / 1000);

function post(body: unknown, headers: Record<string, string> = {}) {
  return app.request("/v1/telemetry/events", {
    method: "POST",
    headers: { "content-type": "application/json", origin: GAME_ORIGIN, ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function metrics(query = "mode=live") {
  const res = await app.request(`/v1/insights/metrics?${query}`);
  assert.equal(res.status, 200);
  return InsightsMetricsResponseSchema.parse(await res.json());
}

test("valid batch is stored and shows in the anonymous feed", async () => {
  const id = randomUUID();
  const res = await post({
    install_id: id,
    events: [
      { t: now(), type: "app_open", props: { day_type: "off", hours_since_last_shift_end: "lt24" } },
      { t: now(), type: "job_accept", props: { role: "register", pay_style: "daily", invited: true, shop_id: "cafe_komorebi", demo_session: true } },
      { t: now(), type: "cat_tired_stop", props: { hours_bucket: "7_5to8" } },
    ],
  });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("access-control-allow-origin"), GAME_ORIGIN);
  assert.deepEqual(await res.json(), { accepted: 3, rejected: [] });

  const feedRes = await app.request("/v1/insights/feed");
  const text = await feedRes.text();
  assert.ok(!text.includes(id), "feed must never expose install_id");
  const feed = InsightsFeedResponseSchema.parse(JSON.parse(text));
  assert.equal(feed.players, 1);
  assert.equal(feed.counts.job_accept, 1);
  assert.equal(feed.items.length, 3);

  const demoFeed = InsightsFeedResponseSchema.parse(await (await app.request("/v1/insights/feed?demo=1")).json());
  assert.deepEqual(demoFeed.items.map((i) => i.type), ["job_accept"]);
});

test("unknown types, unknown props and free text are rejected per event", async () => {
  const res = await post({
    install_id: randomUUID(),
    events: [
      { type: "app_open", props: { day_type: "work" } },
      { type: "sleep_logged", props: {} },
      { type: "job_pass", props: { role: "register", note: "hello" } },
      { type: "shift_start", props: { role: "barista" } },
      { type: "review_submitted", props: { tags: ["friendly", "I hated it"] } },
      { type: "app_open", props: {}, name: "Mika" },
    ],
  });
  assert.equal(res.status, 200);
  const body = (await res.json()) as { accepted: number; rejected: { i: number }[] };
  assert.equal(body.accepted, 1);
  assert.deepEqual(body.rejected.map((r) => r.i), [1, 2, 3, 4, 5]);
  assert.equal((await store.readAll())[0]?.events.length, 1);
});

test("envelope errors: bad install_id, oversized batch, bad json", async () => {
  assert.equal((await post({ install_id: "user@example.com", events: [{ type: "app_open" }] })).status, 400);
  const many = Array.from({ length: TELEMETRY_MAX_EVENTS_PER_BATCH + 1 }, () => ({ type: "outfit_change" }));
  assert.equal((await post({ install_id: randomUUID(), events: many })).status, 413);
  assert.equal((await post("{not json")).status, 400);
  assert.equal((await post({ install_id: randomUUID(), events: [{ type: "app_open" }], extra: 1 })).status, 400);
});

test("sendBeacon-style text/plain bodies are accepted", async () => {
  const res = await post({ install_id: randomUUID(), events: [{ type: "island_share" }] }, { "content-type": "text/plain;charset=UTF-8" });
  assert.equal(res.status, 200);
});

test("per-install rate limit returns 429", async () => {
  const id = randomUUID();
  const statuses: number[] = [];
  for (let i = 0; i < 13; i++) statuses.push((await post({ install_id: id, events: [{ type: "outfit_change" }] })).status);
  assert.deepEqual(statuses.slice(0, 12), Array(12).fill(200));
  assert.equal(statuses[12], 429);
});

test("CORS: unknown origins get no allow-origin header", async () => {
  const res = await app.request("/v1/telemetry/events", {
    method: "OPTIONS",
    headers: { origin: "https://evil.example", "access-control-request-method": "POST" },
  });
  assert.equal(res.headers.get("access-control-allow-origin"), null);
  const ok = await app.request("/v1/telemetry/events", {
    method: "OPTIONS",
    headers: { origin: "http://localhost:8060", "access-control-request-method": "POST" },
  });
  assert.equal(ok.headers.get("access-control-allow-origin"), "http://localhost:8060");
});

test("delete on request removes an install's events", async () => {
  const id = randomUUID();
  await post({ install_id: id, events: [{ type: "app_open" }] });
  await post({ install_id: randomUUID(), events: [{ type: "app_open" }] });
  const res = await app.request("/v1/telemetry/events", {
    method: "DELETE",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ install_id: id }),
  });
  assert.deepEqual(await res.json(), { deleted: 1 });
  assert.equal((await store.readAll()).length, 1);
});

test("live aggregates suppress cells under 5 installs", async () => {
  for (let i = 0; i < 4; i++) await post({ install_id: randomUUID(), events: [{ type: "app_open", props: { day_type: "off" } }] });
  let m = await metrics();
  assert.equal(m.synthetic, false);
  assert.equal(m.storage, "local_memory");
  assert.equal(m.data.headline.wau, null);
  assert.equal(m.data.headline.no_job_search_share, null);

  await post({ install_id: randomUUID(), events: [{ type: "app_open", props: { day_type: "work" } }] });
  clearInsightsCache();
  m = await metrics();
  assert.equal(m.data.headline.wau, 5);
  assert.equal(m.data.headline.no_job_search_share, 0.8);
});

test("simulated pilot is labelled synthetic, deterministic and shows shop culture", async () => {
  const a = await metrics("mode=simulated");
  const b = await metrics("mode=simulated");
  assert.equal(a.synthetic, true);
  assert.match(a.label, /synthetic/i);
  assert.deepEqual(a.data.headline, b.data.headline);
  const rows = a.data.after_shift.rows;
  assert.ok(rows.length >= 3 && rows.every((r) => r.workers >= 5));
  const delta = (shop: string) => rows.find((r) => r.shop === shop)?.delta ?? NaN;
  assert.ok(delta("cafe_komorebi") > delta("izk_torimaru"), "friendlier shop should pull workers back more");
  const f = a.data.funnel;
  assert.ok((f.shown ?? 0) > (f.opened ?? 0) && (f.opened ?? 0) > (f.accepted ?? 0) && (f.accepted ?? 0) > (f.shift_done ?? 0));
});
