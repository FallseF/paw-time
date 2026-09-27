// Builds the Insights payloads: aggregate metrics (live or simulated) and the
// anonymous "Live now" feed. Cached briefly per warm instance.
import type {
  InsightsFeedResponse,
  InsightsMetricsResponse,
  InsightsStorageStatus,
  TelemetryPropValue,
} from "@paw-time/api-contracts";
import type { StoredBatch, TelemetryStore } from "../telemetry/store.js";
import { aggregate, dayOf, type FlatEvent } from "./aggregate.js";
import { SIM_NOW, SIM_START, generateSimulatedPilot } from "./synthetic.js";

export function storageStatus(store: TelemetryStore, env: NodeJS.ProcessEnv = process.env): InsightsStorageStatus {
  if (store.kind !== "memory") return "connected";
  // An in-memory store on Vercel would lose events between instances: say so.
  return env.VERCEL ? "not_connected" : "local_memory";
}

const flatten = (batches: StoredBatch[]): FlatEvent[] =>
  batches.flatMap((b) => b.events.map((e) => ({ ...e, install_id: b.install_id })));

let simCache: InsightsMetricsResponse | null = null;

export function simulatedMetrics(): InsightsMetricsResponse {
  if (!simCache) {
    const sim = generateSimulatedPilot();
    simCache = {
      mode: "simulated",
      synthetic: true,
      label: "Simulated 12-week pilot — synthetic data",
      storage: "connected",
      data: aggregate(sim.events, { now: SIM_NOW, weekLabel: "index", startDay: dayOf(SIM_START), postings: sim.postings }),
    };
  }
  return simCache;
}

type Cached<T> = { at: number; value: T };
const metricsCache = new Map<string, Cached<InsightsMetricsResponse>>();
const feedCache = new Map<string, Cached<InsightsFeedResponse>>();

export function clearInsightsCache() {
  metricsCache.clear();
  feedCache.clear();
}

export async function liveMetrics(store: TelemetryStore, demoOnly: boolean, now = Date.now()): Promise<InsightsMetricsResponse> {
  const key = String(demoOnly);
  const hit = metricsCache.get(key);
  if (hit && now - hit.at < 15_000) return hit.value;
  const storage = storageStatus(store);
  let events = storage === "not_connected" ? [] : flatten(await store.readAll());
  if (demoOnly) events = events.filter((e) => e.props.demo_session === true);
  const value: InsightsMetricsResponse = {
    mode: "live",
    synthetic: false,
    label: "Live — demo players",
    storage,
    data: aggregate(events, { now: Math.floor(now / 1000), weekLabel: "date" }),
  };
  metricsCache.set(key, { at: now, value });
  return value;
}

// Props safe and useful to show in the anonymous feed (all are enums/small numbers).
const FEED_PROPS = ["day_type", "n", "role", "pay_style", "invited", "hours_bucket", "stars", "tag_count", "level", "on", "shop_id", "orbs", "kind", "topic", "tag", "reaction", "when", "max_per_week", "slot"];
// Chat topics and anonymous issues are internal-only and never shown per event, not even
// anonymously: the feed shows that one happened, without topic, tag or shop.
const FEED_REDACTED_TYPES = new Set(["chat_signal", "anon_issue_sent"]);
export const FEED_WINDOW_MS = 30 * 60_000;

export async function liveFeed(store: TelemetryStore, demoOnly: boolean, now = Date.now()): Promise<InsightsFeedResponse> {
  const key = String(demoOnly);
  const hit = feedCache.get(key);
  if (hit && now - hit.at < 2_000) return hit.value;
  const storage = storageStatus(store);
  const since = now - FEED_WINDOW_MS;
  const nowS = Math.floor(now / 1000);
  const events = (storage === "not_connected" ? [] : flatten(await store.readSince(since)))
    .filter((e) => e.t * 1000 >= since - 60_000 && (!demoOnly || e.props.demo_session === true))
    .sort((a, b) => b.t - a.t);
  const counts: Record<string, number> = {};
  for (const e of events) counts[e.type] = (counts[e.type] ?? 0) + 1;
  const value: InsightsFeedResponse = {
    storage,
    window_min: FEED_WINDOW_MS / 60_000,
    players: new Set(events.map((e) => e.install_id)).size,
    counts,
    // No install_id leaves the server: only type, whitelisted props and relative time.
    items: events.slice(0, 40).map((e) => {
      const props: Record<string, TelemetryPropValue> = {};
      if (!FEED_REDACTED_TYPES.has(e.type)) for (const k of FEED_PROPS) {
        const v = e.props[k];
        if (v !== undefined) props[k] = v;
      }
      return { type: e.type, props, ago_s: Math.max(0, nowS - e.t), demo: e.props.demo_session === true };
    }),
  };
  feedCache.set(key, { at: now, value });
  return value;
}
