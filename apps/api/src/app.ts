import { Hono } from "hono";
import { businessRoutes } from "./routes/business.js";
import { workerRoutes } from "./routes/worker.js";
import type { AppEnv } from "./types.js";

export const app = new Hono<AppEnv>();

app.get("/health", (context) => {
  return context.json({ status: "ok", service: "paw-time-api" });
});

app.route("/v1/worker", workerRoutes);
app.route("/v1/business", businessRoutes);

app.notFound((context) => context.json({ error: "not_found" }, 404));
