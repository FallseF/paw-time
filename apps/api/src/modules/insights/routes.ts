import { Hono } from "hono";
import { cors } from "hono/cors";
import { isInsightsLocale } from "@paw-time/api-contracts";
import { allowedOrigin } from "../telemetry/cors.js";
import { telemetryStore } from "../telemetry/store.js";
import { liveFeed, liveMetrics, simulatedMetrics } from "./service.js";

// Aggregate-only read endpoints for the Recruit view dashboard (apps/insights).
export const insightsRoutes = new Hono();

insightsRoutes.use("*", cors({ origin: (origin) => allowedOrigin(origin), allowMethods: ["GET", "OPTIONS"] }));

// GET /v1/insights/metrics?mode=live|simulated[&demo=1][&lang=en|ja]
// lang picks the simulated pilot's setting (en: San Francisco / USD, the default; ja: Japan / JPY).
insightsRoutes.get("/metrics", async (c) => {
  if (c.req.query("mode") === "simulated") {
    const lang = c.req.query("lang");
    c.header("Cache-Control", "public, s-maxage=3600");
    return c.json(simulatedMetrics(isInsightsLocale(lang) ? lang : "en"));
  }
  c.header("Cache-Control", "public, s-maxage=10, stale-while-revalidate=20");
  return c.json(await liveMetrics(telemetryStore(), c.req.query("demo") === "1"));
});

// GET /v1/insights/feed[?demo=1] — anonymous activity in the last 30 minutes.
insightsRoutes.get("/feed", async (c) => {
  c.header("Cache-Control", "public, s-maxage=2");
  return c.json(await liveFeed(telemetryStore(), c.req.query("demo") === "1"));
});
