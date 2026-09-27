import assert from "node:assert/strict";
import test from "node:test";
import { app } from "../src/app.js";
import { resetConsoleStores } from "../src/modules/shop-console/routes.js";

const headers = (org = "org-sunnyside") => ({
  "content-type": "application/json",
  "x-organization-id": org,
  "x-actor-id": "staff-2",
});

async function get<T = unknown>(path: string, org?: string): Promise<{ status: number; body: T }> {
  const res = await app.request(`/v1/business/console${path}`, { headers: headers(org) });
  return { status: res.status, body: (await res.json()) as T };
}

async function post<T = unknown>(path: string, payload: unknown, org?: string): Promise<{ status: number; body: T }> {
  const res = await app.request(`/v1/business/console${path}`, { method: "POST", headers: headers(org), body: JSON.stringify(payload) });
  return { status: res.status, body: (await res.json()) as T };
}

/** Every key anywhere in a JSON value. */
function keysOf(value: unknown, out = new Set<string>()): Set<string> {
  if (Array.isArray(value)) value.forEach((v) => keysOf(v, out));
  else if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value)) {
      out.add(k);
      keysOf(v, out);
    }
  }
  return out;
}

const FORBIDDEN_KEY = /(score|rank|rating|reliab|percentile|stars|phone|email|contact$)/i;

test("console: requires business context and a known organization", async () => {
  const noAuth = await app.request("/v1/business/console/today");
  assert.equal(noAuth.status, 401);
  const unknown = await get("/today", "org-unknown");
  assert.equal(unknown.status, 404);
});

test("console: no individual score, ranking or contact detail in any shop response", async () => {
  resetConsoleStores();
  const paths = ["/today", "/jobs", "/applicants", "/shifts?from=2020-01-01&to=2030-12-31", "/attendance-log", "/threads", "/reviews", "/invites"];
  for (const org of ["org-sunnyside", "org-komorebi"]) {
    for (const path of paths) {
      const { status, body } = await get<{ data: unknown }>(path, org);
      assert.equal(status, 200, `${org} ${path}`);
      const bad = [...keysOf(body.data)].filter((k) => FORBIDDEN_KEY.test(k));
      assert.deepEqual(bad, [], `${org} ${path} exposes ${bad.join(", ")}`);
      const text = JSON.stringify(body.data);
      assert.ok(!/555-01\d\d|090-0000/.test(text), `${org} ${path} leaks a phone number`);
      assert.ok(!/worker\d+@example\.com/.test(text), `${org} ${path} leaks a worker email`);
    }
  }
});

test("console: applicants carry only what the worker shared", async () => {
  resetConsoleStores();
  const { body } = await get<{ data: Array<Record<string, unknown> & { shared: { badges: unknown; onTime: unknown }; displayName: string }> }>("/applicants");
  const allowed = ["applicationId", "jobId", "slotId", "workerId", "displayName", "cat", "status", "appliedAt", "decidedAt", "note", "firstTimeHere", "shared", "canMessage", "threadId"].sort();
  for (const a of body.data) assert.deepEqual(Object.keys(a).sort(), allowed);
  const theo = body.data.find((a) => a.displayName === "Theo");
  assert.equal(theo?.shared.badges, null, "Theo hid his badges");
  assert.deepEqual(theo?.shared.onTime, { onTime: 6, total: 7 });
  const jun = body.data.find((a) => a.displayName === "Jun");
  assert.equal(jun?.shared.onTime, null, "Jun hid his on-time record");
  // Applicants come back newest first, never ordered by any quality measure.
  const times = body.data.map((a) => String(a.appliedAt));
  assert.deepEqual(times, [...times].sort().reverse());
});

test("console: the API refuses a job below the minimum wage", async () => {
  resetConsoleStores();
  const input = {
    title: "Evening register",
    role: "register",
    status: "published",
    wage: 19,
    payStyle: "weekly",
    dressCode: "",
    notes: "",
    slots: [{ date: "2026-10-10", start: "17:00", end: "21:00", capacity: 1 }],
  };
  const low = await post<{ error: string; issues: Array<{ field: string; code: string; minimum: number }> }>("/jobs", input);
  assert.equal(low.status, 422);
  assert.deepEqual(low.body.issues, [{ field: "wage", code: "below_minimum", minimum: 19.61 }]);
  const ok = await post<{ data: { wage: number; status: string } }>("/jobs", { ...input, wage: 22.5 });
  assert.equal(ok.status, 201);
  assert.equal(ok.body.data.wage, 22.5);
  const yen = await post("/jobs", { ...input, wage: 1100 }, "org-komorebi");
  assert.equal(yen.status, 422);
});

test("console: the improvement report never shows an issue from fewer than 5 workers", async () => {
  resetConsoleStores();
  const { body } = await get<{ data: { report: { threshold: number; issues: Array<{ issue: string; workers: number; trend: Array<{ workers: number | null }> }> } } }>("/reviews");
  assert.equal(body.data.report.threshold, 5);
  const names = body.data.report.issues.map((i) => i.issue);
  assert.ok(!names.includes("unclear") && !names.includes("late_pay"), "issues under 5 workers are left out");
  for (const i of body.data.report.issues) {
    assert.ok(i.workers >= 5);
    for (const w of i.trend) assert.ok(w.workers === null || w.workers >= 5);
  }
});

test("console: accepting an applicant opens chat; declining does not", async () => {
  resetConsoleStores();
  const { body } = await get<{ data: Array<{ applicationId: string; status: string; workerId: string; displayName: string }> }>("/applicants");
  const ana = body.data.find((a) => a.displayName === "Ana" && a.status === "applied");
  const theo = body.data.find((a) => a.displayName === "Theo" && a.status === "applied");
  assert.ok(ana && theo);
  const before = await post(`/workers/${ana.workerId}/thread`, {});
  assert.equal(before.status, 409);
  const accepted = await post<{ data: { status: string; canMessage: boolean } }>(`/applicants/${ana.applicationId}/decision`, { decision: "accepted" });
  assert.equal(accepted.body.data.status, "accepted");
  assert.equal(accepted.body.data.canMessage, true);
  const thread = await post<{ data: { id: string } }>(`/workers/${ana.workerId}/thread`, {});
  assert.equal(thread.status, 200);
  await post(`/applicants/${theo.applicationId}/decision`, { decision: "declined" });
  const theoThread = await post(`/workers/${theo.workerId}/thread`, {});
  assert.equal(theoThread.status, 409);
});

test("console: attendance corrections are appended with reason, who and when", async () => {
  resetConsoleStores();
  const shifts = await get<{ data: Array<{ id: string; status: string; checkOutAt: string | null }> }>("/shifts?from=2020-01-01&to=2030-12-31");
  const done = shifts.body.data.find((s) => s.status === "checked_out");
  assert.ok(done);
  const logBefore = await get<{ data: unknown[] }>(`/attendance-log?shiftId=${done.id}`);
  const noReason = await post(`/shifts/${done.id}/corrections`, { field: "check_out", time: "21:15", reason: " " });
  assert.equal(noReason.status, 422);
  const fixed = await post<{ data: { corrected: boolean } }>(`/shifts/${done.id}/corrections`, { field: "check_out", time: "21:15", reason: "Closed the register" });
  assert.equal(fixed.status, 201);
  assert.equal(fixed.body.data.corrected, true);
  const logAfter = await get<{ data: Array<{ kind: string; reason?: string; by: string; recordedAt: string; previous?: string | null }> }>(`/attendance-log?shiftId=${done.id}`);
  assert.equal(logAfter.body.data.length, logBefore.body.data.length + 1);
  const entry = logAfter.body.data[0];
  assert.equal(entry?.kind, "correction");
  assert.equal(entry?.reason, "Closed the register");
  assert.equal(entry?.by, "Jordan Lee");
  assert.ok(entry?.previous);
});
