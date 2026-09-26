// Batch validation: the batch envelope must be exact; each event is validated on its
// own so one bad event doesn't drop the rest. Unknown types/props are rejected.
import {
  TelemetryBatchInputSchema,
  TelemetryEventInputSchema,
  TelemetryPropSchemas,
  type TelemetryEvent,
} from "@paw-time/api-contracts";
import type { z } from "zod";

// Client timestamps outside this window around server time are replaced by server time.
const MAX_PAST_S = 3 * 86_400;
const MAX_FUTURE_S = 10 * 60;

const reasonOf = (error: z.ZodError): string => {
  const issue = error.issues[0];
  if (!issue) return "invalid";
  if (issue.code === "unrecognized_keys") return `unknown_field:${issue.keys.join(",")}`;
  return `${issue.code}:${issue.path.join(".") || "event"}`;
};

export type EventResult = { ok: true; event: TelemetryEvent } | { ok: false; reason: string };

export function validateEvent(raw: unknown, nowS: number): EventResult {
  const envelope = TelemetryEventInputSchema.safeParse(raw);
  if (!envelope.success) return { ok: false, reason: reasonOf(envelope.error) };
  const { type, t, props } = envelope.data;
  const parsed = TelemetryPropSchemas[type].safeParse(props ?? {});
  if (!parsed.success) return { ok: false, reason: reasonOf(parsed.error) };
  let when = t === undefined ? nowS : Math.floor(t);
  if (when < nowS - MAX_PAST_S || when > nowS + MAX_FUTURE_S) when = nowS;
  const clean: TelemetryEvent["props"] = {};
  for (const [k, v] of Object.entries(parsed.data)) {
    if (v === undefined) continue;
    clean[k] = Array.isArray(v) ? [...new Set(v as string[])] : (v as string | number | boolean);
  }
  return { ok: true, event: { t: when, type, props: clean } };
}

export type BatchResult =
  | { ok: true; installId: string; events: TelemetryEvent[]; rejected: { i: number; reason: string }[] }
  | { ok: false; status: 400 | 413; error: string };

export function validateBatch(body: unknown, nowS: number): BatchResult {
  const parsed = TelemetryBatchInputSchema.safeParse(body);
  if (!parsed.success) {
    const tooBig = parsed.error.issues.some((i) => i.code === "too_big" && i.path[0] === "events");
    return { ok: false, status: tooBig ? 413 : 400, error: reasonOf(parsed.error) };
  }
  const events: TelemetryEvent[] = [];
  const rejected: { i: number; reason: string }[] = [];
  parsed.data.events.forEach((raw, i) => {
    const r = validateEvent(raw, nowS);
    if (r.ok) events.push(r.event);
    else rejected.push({ i, reason: r.reason });
  });
  return { ok: true, installId: parsed.data.install_id, events, rejected };
}
