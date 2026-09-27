import { createStore } from "@paw-time/shop-console";
import type { Region, Result, ShopConsoleStore } from "@paw-time/shop-console";
import { Hono } from "hono";
import type { Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../../types.js";

/**
 * Shop console (apps/employer) endpoints under /v1/business/console. Sample data per demo
 * organization, kept in memory. Every response is a shop view: only what workers shared,
 * counts under 5 withheld, no individual scores or rankings.
 */
export const shopConsoleRoutes = new Hono<AppEnv>();

const ORGANIZATIONS: Record<string, Region> = {
  "org-sunnyside": "sf",
  "org-komorebi": "jp",
};

const stores = new Map<string, ShopConsoleStore>();

export function consoleStore(organizationId: string): ShopConsoleStore | null {
  const region = ORGANIZATIONS[organizationId];
  if (!region) return null;
  let store = stores.get(organizationId);
  if (!store) {
    store = createStore(region);
    stores.set(organizationId, store);
  }
  return store;
}

/** Test hook: start an organization's console over from the seed. */
export function resetConsoleStores(): void {
  stores.clear();
}

const Role = z.enum(["register", "barista", "hall", "kitchen", "dish", "stock"]);
const Time = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);
const DateStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const JobInput = z.object({
  title: z.string().max(200),
  role: Role,
  status: z.enum(["draft", "published", "closed"]),
  wage: z.number(),
  payStyle: z.enum(["same_day", "weekly", "monthly"]),
  dressCode: z.string().max(1000).default(""),
  notes: z.string().max(5000).default(""),
  slots: z.array(z.object({ id: z.string().optional(), date: z.string(), start: z.string(), end: z.string(), capacity: z.number().int() })).max(60),
});

/** Only called after the middleware below has checked the organization has a console. */
function store(c: Context<AppEnv>): ShopConsoleStore {
  return consoleStore(c.get("organizationId")) as ShopConsoleStore;
}

function staffName(c: Context<AppEnv>, s: ShopConsoleStore): string {
  const staff = s.settings().staff;
  return staff.find((m) => m.id === c.get("actorId"))?.name ?? staff.find((m) => m.role === "manager")?.name ?? staff[0]?.name ?? "Staff";
}

function reply<T>(c: Context<AppEnv>, result: Result<T>, created = false) {
  if (result.ok) return c.json({ data: result.data }, created ? 201 : 200);
  const status = result.error.endsWith("_not_found") ? 404 : result.errors ? 422 : 409;
  return c.json({ error: result.error, ...(result.errors ? { issues: result.errors } : {}) }, status);
}

async function body<T extends z.ZodTypeAny>(c: Context<AppEnv>, schema: T): Promise<z.infer<T> | null> {
  const parsed = schema.safeParse(await c.req.json().catch(() => null));
  return parsed.success ? parsed.data : null;
}

const invalid = (c: Context<AppEnv>) => c.json({ error: "invalid_request" }, 400);

shopConsoleRoutes.use("*", async (c, next) => {
  if (!consoleStore(c.get("organizationId"))) return c.json({ error: "console_not_found" }, 404);
  await next();
});

shopConsoleRoutes.get("/today", (c) => c.json({ data: store(c).todayView() }));

shopConsoleRoutes.get("/jobs", (c) => c.json({ data: store(c).jobs() }));
shopConsoleRoutes.get("/jobs/:id", (c) => {
  const job = store(c).job(c.req.param("id"));
  return job ? c.json({ data: job }) : c.json({ error: "job_not_found" }, 404);
});
shopConsoleRoutes.post("/jobs", async (c) => {
  const input = await body(c, JobInput);
  if (!input) return invalid(c);
  return reply(c, store(c).saveJob(input), true);
});
shopConsoleRoutes.put("/jobs/:id", async (c) => {
  const input = await body(c, JobInput);
  if (!input) return invalid(c);
  return reply(c, store(c).saveJob({ ...input, id: c.req.param("id") }));
});
shopConsoleRoutes.post("/jobs/:id/status", async (c) => {
  const input = await body(c, z.object({ status: z.enum(["draft", "published", "closed"]) }));
  if (!input) return invalid(c);
  return reply(c, store(c).setJobStatus(c.req.param("id"), input.status));
});
shopConsoleRoutes.post("/wage-check", async (c) => {
  const input = await body(c, z.object({ wage: z.number(), dates: z.array(DateStr).max(60) }));
  if (!input) return invalid(c);
  return c.json({ data: store(c).checkWage(input.wage, input.dates) });
});
shopConsoleRoutes.get("/urgent-reach", (c) => {
  const role = Role.safeParse(c.req.query("role"));
  const date = DateStr.safeParse(c.req.query("date"));
  const start = Time.safeParse(c.req.query("start"));
  const end = Time.safeParse(c.req.query("end"));
  if (!role.success || !date.success || !start.success || !end.success) return invalid(c);
  return c.json({ data: store(c).urgentReach(role.data, { date: date.data, start: start.data, end: end.data }) });
});
shopConsoleRoutes.post("/jobs/:id/slots/:slotId/urgent", (c) => reply(c, store(c).sendUrgent(c.req.param("id"), c.req.param("slotId"))));
shopConsoleRoutes.post("/urgent-shifts", async (c) => {
  const input = await body(c, JobInput);
  if (!input) return invalid(c);
  return reply(c, store(c).postUrgentShift(input), true);
});

shopConsoleRoutes.get("/applicants", (c) => c.json({ data: store(c).applicants(c.req.query("jobId") || undefined) }));
shopConsoleRoutes.post("/applicants/:id/decision", async (c) => {
  const input = await body(c, z.object({ decision: z.enum(["accepted", "declined"]) }));
  if (!input) return invalid(c);
  return reply(c, store(c).decide(c.req.param("id"), input.decision));
});

shopConsoleRoutes.get("/shifts", (c) => {
  const s = store(c);
  const today = s.today();
  const from = DateStr.safeParse(c.req.query("from"));
  const to = DateStr.safeParse(c.req.query("to"));
  return c.json({ data: s.shifts(from.success ? from.data : today, to.success ? to.data : today) });
});
shopConsoleRoutes.get("/attendance-log", (c) => c.json({ data: store(c).attendanceLog(c.req.query("shiftId") || undefined) }));
shopConsoleRoutes.post("/shifts/:id/attendance", async (c) => {
  const input = await body(c, z.object({ kind: z.enum(["check_in", "check_out"]) }));
  if (!input) return invalid(c);
  const s = store(c);
  return reply(c, s.recordAttendance(c.req.param("id"), input.kind, staffName(c, s)), true);
});
shopConsoleRoutes.post("/shifts/:id/no-show", async (c) => {
  const input = await body(c, z.object({ reason: z.string().max(500) }));
  if (!input) return invalid(c);
  const s = store(c);
  return reply(c, s.markNoShow(c.req.param("id"), input.reason, staffName(c, s)), true);
});
shopConsoleRoutes.post("/shifts/:id/corrections", async (c) => {
  const input = await body(c, z.object({ field: z.enum(["check_in", "check_out"]), time: z.string(), reason: z.string().max(500) }));
  if (!input) return invalid(c);
  const s = store(c);
  return reply(c, s.correct(c.req.param("id"), input.field, input.time, input.reason, staffName(c, s)), true);
});

shopConsoleRoutes.get("/threads", (c) => c.json({ data: store(c).threads() }));
shopConsoleRoutes.get("/threads/:id", (c) => {
  const t = store(c).thread(c.req.param("id"));
  return t ? c.json({ data: t }) : c.json({ error: "thread_not_found" }, 404);
});
shopConsoleRoutes.post("/workers/:workerId/thread", (c) => reply(c, store(c).openThread(c.req.param("workerId"))));
shopConsoleRoutes.post("/threads/:id/messages", async (c) => {
  const input = await body(c, z.object({ text: z.string(), template: z.enum(["late", "swap", "thanks"]).optional() }));
  if (!input) return invalid(c);
  const s = store(c);
  return reply(c, s.sendMessage(c.req.param("id"), input.text, staffName(c, s), input.template), true);
});
shopConsoleRoutes.post("/threads/:id/read", (c) => {
  store(c).markRead(c.req.param("id"));
  return c.body(null, 204);
});
shopConsoleRoutes.post("/threads/:id/report", (c) => reply(c, store(c).report(c.req.param("id"))));
shopConsoleRoutes.post("/threads/:id/block", async (c) => {
  const input = await body(c, z.object({ blocked: z.boolean() }));
  if (!input) return invalid(c);
  return reply(c, store(c).setBlocked(c.req.param("id"), input.blocked));
});
shopConsoleRoutes.get("/faq", (c) => c.json({ data: store(c).faq() }));
shopConsoleRoutes.put("/faq", async (c) => {
  const input = await body(c, z.object({ dressCode: z.string(), entrance: z.string(), breaks: z.string(), contactName: z.string() }).partial());
  if (!input) return invalid(c);
  const clean = Object.fromEntries(Object.entries(input).filter(([, v]) => typeof v === "string"));
  return c.json({ data: store(c).updateFaq(clean) });
});

shopConsoleRoutes.get("/reviews", (c) => {
  const s = store(c);
  return c.json({ data: { island: s.island(), report: s.improvementReport() } });
});

shopConsoleRoutes.get("/invites", (c) => c.json({ data: store(c).invites() }));
shopConsoleRoutes.post("/invites", async (c) => {
  const input = await body(c, z.object({ workerId: z.string(), jobId: z.string(), slotId: z.string(), text: z.string().max(1000).default("") }));
  if (!input) return invalid(c);
  const s = store(c);
  return reply(c, s.sendInvite(input.workerId, input.jobId, input.slotId, staffName(c, s), input.text), true);
});

shopConsoleRoutes.get("/settings", (c) => c.json({ data: store(c).settings() }));
shopConsoleRoutes.patch("/settings/profile", async (c) => {
  const input = await body(c, z.object({ name: z.string(), area: z.string(), signColor: z.string(), values: z.string() }).partial());
  if (!input) return invalid(c);
  const clean = Object.fromEntries(Object.entries(input).filter(([, v]) => typeof v === "string"));
  return reply(c, store(c).updateProfile(clean));
});
shopConsoleRoutes.patch("/settings/notifications", async (c) => {
  const input = await body(c, z.object({ from: Time, to: Time, newApplicants: z.boolean(), chats: z.boolean(), attendance: z.boolean(), weeklyReport: z.boolean() }).partial());
  if (!input) return invalid(c);
  const clean = Object.fromEntries(Object.entries(input).filter(([, v]) => v !== undefined));
  return reply(c, store(c).updateNotifications(clean));
});
shopConsoleRoutes.post("/settings/staff", async (c) => {
  const input = await body(c, z.object({ name: z.string().max(80), role: z.enum(["manager", "staff"]), email: z.string().max(200) }));
  if (!input) return invalid(c);
  return reply(c, store(c).addStaff(input.name, input.role, input.email), true);
});
shopConsoleRoutes.delete("/settings/staff/:id", (c) => reply(c, store(c).removeStaff(c.req.param("id"))));
