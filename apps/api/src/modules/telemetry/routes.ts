import {
  TELEMETRY_MAX_BODY_BYTES,
  TelemetryDeleteInputSchema,
  type TelemetryBatchResponse,
} from "@paw-time/api-contracts";
import { Hono, type Context } from "hono";
import { cors } from "hono/cors";
import { allowedOrigin } from "./cors.js";
import { telemetryLimiter } from "./rate-limit.js";
import { telemetryStore } from "./store.js";
import { validateBatch } from "./validate.js";

const MINUTE = 60_000;

export const telemetryRoutes = new Hono();

telemetryRoutes.use(
  "*",
  cors({ origin: (origin) => allowedOrigin(origin), allowMethods: ["POST", "DELETE", "OPTIONS"], allowHeaders: ["Content-Type"], maxAge: 86400 }),
);

const clientIp = (c: Context) => (c.req.header("x-forwarded-for") ?? "").split(",")[0]?.trim() || "unknown";

// Accepts application/json and text/plain (navigator.sendBeacon on page hide).
async function readJson(c: Context): Promise<{ ok: true; body: unknown } | { ok: false; error: string; status: 400 | 413 }> {
  if (Number(c.req.header("content-length") ?? "0") > TELEMETRY_MAX_BODY_BYTES) return { ok: false, error: "body_too_large", status: 413 };
  const text = await c.req.text();
  if (new TextEncoder().encode(text).length > TELEMETRY_MAX_BODY_BYTES) return { ok: false, error: "body_too_large", status: 413 };
  try {
    return { ok: true, body: JSON.parse(text) };
  } catch {
    return { ok: false, error: "bad_json", status: 400 };
  }
}

telemetryRoutes.post("/events", async (c) => {
  const now = Date.now();
  if (!telemetryLimiter.allow(`ip:${clientIp(c)}`, 120, MINUTE, now)) {
    c.header("Retry-After", "60");
    return c.json({ error: "rate_limited" }, 429);
  }
  const body = await readJson(c);
  if (!body.ok) return c.json({ error: body.error }, body.status);
  const result = validateBatch(body.body, Math.floor(now / 1000));
  if (!result.ok) return c.json({ error: result.error }, result.status);
  // 12 batches/min per install is ~4x the game's 20 s flush cadence.
  if (!telemetryLimiter.allow(`id:${result.installId}`, 12, MINUTE, now)) {
    c.header("Retry-After", "60");
    return c.json({ error: "rate_limited" }, 429);
  }
  if (result.events.length) {
    await telemetryStore().append({ install_id: result.installId, received: now, events: result.events });
  }
  const response: TelemetryBatchResponse = { accepted: result.events.length, rejected: result.rejected };
  return c.json(response);
});

// Delete on request: removes every stored event of one install_id.
telemetryRoutes.delete("/events", async (c) => {
  if (!telemetryLimiter.allow(`del:${clientIp(c)}`, 10, MINUTE)) return c.json({ error: "rate_limited" }, 429);
  const body = await readJson(c);
  if (!body.ok) return c.json({ error: body.error }, body.status);
  const parsed = TelemetryDeleteInputSchema.safeParse(body.body);
  if (!parsed.success) return c.json({ error: "bad_install_id" }, 400);
  const deleted = await telemetryStore().deleteInstall(parsed.data.install_id);
  return c.json({ deleted });
});
