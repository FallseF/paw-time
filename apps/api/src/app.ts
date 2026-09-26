import { Hono } from "hono";
import { insightsRoutes } from "./modules/insights/routes.js";
import { telemetryRoutes } from "./modules/telemetry/routes.js";
import { businessRoutes } from "./routes/business.js";
import { workerRoutes } from "./routes/worker.js";
import type { AppEnv } from "./types.js";

export const app = new Hono<AppEnv>();

app.get("/health", (context) => {
  return context.json({ status: "ok", service: "paw-time-api" });
});

app.route("/v1/worker", workerRoutes);
app.route("/v1/business", businessRoutes);
app.route("/v1/telemetry", telemetryRoutes);
app.route("/v1/insights", insightsRoutes);

app.notFound((context) => context.json({ error: "not_found" }, 404));
