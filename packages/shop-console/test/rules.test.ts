import assert from "node:assert/strict";
import test from "node:test";
import {
  buildImprovementReport,
  buildIsland,
  checkMinimumWage,
  createSample,
  createStore,
  landmarkLevel,
  matchFaq,
  shopMessageDelivery,
  urgentReach,
  validateJob,
  zonedToUtc,
} from "../src/index";
import type { IssueId, JobInput } from "../src/index";

const job = (wage: number, date = "2026-10-03"): JobInput => ({
  title: "Boba bar",
  role: "register",
  status: "published",
  wage,
  payStyle: "weekly",
  dressCode: "",
  notes: "",
  slots: [{ date, start: "17:00", end: "21:00", capacity: 2 }],
});

test("minimum wage: San Francisco is $19.61 from 2026-07-01 and $19.18 before", () => {
  assert.equal(checkMinimumWage(19.61, "sf", ["2026-07-01"]).ok, true);
  const short = checkMinimumWage(19.6, "sf", ["2026-07-01"]);
  assert.equal(short.ok, false);
  assert.equal(short.minimum, 19.61);
  assert.equal(short.shortBy, 0.01);
  assert.equal(checkMinimumWage(19.2, "sf", ["2026-06-30"]).ok, true);
  // The latest slot date decides when a job spans the change.
  assert.equal(checkMinimumWage(19.2, "sf", ["2026-06-30", "2026-07-02"]).ok, false);
});

test("minimum wage: Tokyo is ¥1,280 from 2026-10-01 and ¥1,226 the day before", () => {
  const before = checkMinimumWage(1226, "jp", ["2026-09-30"]);
  assert.deepEqual([before.ok, before.minimum, before.from], [true, 1226, "2025-10-03"]);
  const after = checkMinimumWage(1226, "jp", ["2026-10-01"]);
  assert.deepEqual([after.ok, after.minimum, after.from, after.shortBy], [false, 1280, "2026-10-01", 54]);
  assert.equal(checkMinimumWage(1280, "jp", ["2026-10-01"]).ok, true);
  // A job that spans the change must pay the new rate.
  assert.equal(checkMinimumWage(1250, "jp", ["2026-09-30", "2026-10-01"]).ok, false);
});

test("minimum wage: the job form refuses a wage below the local minimum", () => {
  assert.deepEqual(validateJob(job(21), "sf"), []);
  const errors = validateJob(job(19.5), "sf");
  assert.deepEqual(errors, [{ field: "wage", code: "below_minimum", minimum: 19.61 }]);
  assert.equal(validateJob(job(1200), "jp")[0]?.code, "below_minimum");
  assert.deepEqual(validateJob(job(1280), "jp"), []);
  assert.deepEqual(validateJob(job(1250, "2026-09-30"), "jp"), []);
});

test("minimum wage: every seeded job clears the minimum on its slot dates, after the 2026 raise too", () => {
  for (const region of ["sf", "jp"] as const) {
    for (const realNow of [new Date("2026-09-27T03:00:00Z"), new Date("2026-10-15T03:00:00Z")]) {
      for (const j of createSample(region, realNow).jobs) {
        const check = checkMinimumWage(j.wage, region, j.slots.map((s) => s.date));
        assert.equal(check.ok, true, `${region} ${j.id} pays ${j.wage} < ${check.minimum} on ${check.date}`);
      }
    }
  }
});

test("minimum wage: the store will not save or publish an underpaid job", () => {
  const store = createStore("sf", { realNow: new Date("2026-09-27T20:00:00Z") });
  const saved = store.saveJob(job(18));
  assert.equal(saved.ok, false);
  const before = store.jobs().length;
  const urgent = store.postUrgentShift(job(19));
  assert.equal(urgent.ok, false);
  assert.equal(store.jobs().length, before);
});

test("improvement report: an issue needs 5 distinct workers, and weeks under 5 are hidden", () => {
  const weeks = ["2026-09-14", "2026-09-21"];
  const responses: Array<{ workerId: string; issue: IssueId; week: string }> = [];
  // 4 workers say "unclear" (twice each): still under the threshold.
  for (let i = 0; i < 4; i++) {
    responses.push({ workerId: `u${i}`, issue: "unclear", week: "2026-09-14" });
    responses.push({ workerId: `u${i}`, issue: "unclear", week: "2026-09-21" });
  }
  let report = buildImprovementReport(responses, weeks);
  assert.equal(report.status, "not_enough");
  assert.deepEqual(report.issues, []);
  assert.ok(!JSON.stringify(report).includes("unclear"), "an issue below 5 must not be named at all");

  // 5 distinct workers → shown, with the week that has only 1 of them suppressed.
  responses.push({ workerId: "u4", issue: "unclear", week: "2026-09-21" });
  report = buildImprovementReport(responses, weeks);
  assert.equal(report.status, "ready");
  assert.equal(report.issues[0]?.issue, "unclear");
  assert.equal(report.issues[0]?.workers, 5);
  assert.deepEqual(report.issues[0]?.trend, [
    { week: "2026-09-14", workers: null },
    { week: "2026-09-21", workers: 5 },
  ]);
  assert.equal(report.issues[0]?.action, "first_day_checklist");
});

test("improvement report: the seeded shop hides its small issues", () => {
  const store = createStore("sf", { realNow: new Date("2026-09-27T20:00:00Z") });
  const report = store.improvementReport();
  const shown = report.issues.map((i) => i.issue);
  assert.deepEqual(shown, ["too_busy", "no_break"]);
  for (const row of report.issues) {
    assert.ok(row.workers >= 5);
    for (const w of row.trend) assert.ok(w.workers === null || w.workers >= 5);
  }
});

test("quiet hours: shop messages deliver 8:00–21:00 local, otherwise at the next 8:00", () => {
  const tz = "America/Los_Angeles";
  const at = (date: string, time: string) => zonedToUtc(date, time, tz);
  assert.deepEqual(shopMessageDelivery(at("2026-09-27", "14:20"), tz), { status: "delivered", deliverAt: at("2026-09-27", "14:20").toISOString() });
  assert.deepEqual(shopMessageDelivery(at("2026-09-27", "08:00"), tz).status, "delivered");
  assert.deepEqual(shopMessageDelivery(at("2026-09-27", "20:59"), tz).status, "delivered");
  assert.deepEqual(shopMessageDelivery(at("2026-09-27", "21:00"), tz), { status: "queued", deliverAt: at("2026-09-28", "08:00").toISOString() });
  assert.deepEqual(shopMessageDelivery(at("2026-09-27", "23:45"), tz), { status: "queued", deliverAt: at("2026-09-28", "08:00").toISOString() });
  assert.deepEqual(shopMessageDelivery(at("2026-09-28", "06:30"), tz), { status: "queued", deliverAt: at("2026-09-28", "08:00").toISOString() });
  // Across the DST change (Nov 1, 2026) the message still lands at 8:00 local.
  assert.equal(shopMessageDelivery(at("2026-10-31", "22:00"), tz).deliverAt, "2026-11-01T16:00:00.000Z");
  const jst = "Asia/Tokyo";
  assert.equal(shopMessageDelivery(new Date("2026-09-27T13:30:00Z"), jst).deliverAt, "2026-09-27T23:00:00.000Z");
});

test("quiet hours: the store queues a staff message sent at night", () => {
  const tz = "America/Los_Angeles";
  let now = zonedToUtc("2026-09-27", "22:10", tz);
  const store = createStore("sf", { realNow: now, clock: () => now });
  const thread = store.threads().find((t) => t.canMessage);
  assert.ok(thread);
  const sent = store.sendMessage(thread.id, "See you tomorrow", "Jordan Lee");
  assert.ok(sent.ok);
  assert.equal(sent.data.status, "queued");
  assert.equal(sent.data.deliverAt, zonedToUtc("2026-09-28", "08:00", tz).toISOString());
  now = zonedToUtc("2026-09-28", "08:01", tz);
  const later = store.thread(thread.id)?.messages.find((m) => m.id === sent.data.id);
  assert.equal(later?.status, "delivered");
});

test("chat: no messages without an accepted shift or invite, and no phone numbers", () => {
  const store = createStore("sf", { realNow: new Date("2026-09-27T20:00:00Z") });
  const applicant = store.applicants().find((a) => a.status === "applied");
  assert.ok(applicant);
  assert.equal(applicant.canMessage, false);
  assert.equal(store.openThread(applicant.workerId).ok, false);
  const thread = store.threads().find((t) => t.canMessage);
  assert.ok(thread);
  const phone = store.sendMessage(thread.id, "Call me at 415 555 0199", "Jordan");
  assert.deepEqual(phone, { ok: false, error: "no_phone_numbers" });
});

test("chat: FAQ questions are matched to the shop's own answers", () => {
  const faq = { dressCode: "Black top", entrance: "Side door", breaks: "30 min", contactName: "Jordan" };
  assert.equal(matchFaq("What should I wear?", faq), "dressCode");
  assert.equal(matchFaq("Which entrance should I use?", faq), "entrance");
  assert.equal(matchFaq("休憩はありますか？", faq), "breaks");
  assert.equal(matchFaq("Can I bring my dog?", faq), null);
  assert.equal(matchFaq("What should I wear?", { ...faq, dressCode: " " }), null);
});

test("island: levels at 3, 8 and 16 votes, counted once per worker", () => {
  assert.deepEqual([0, 2, 3, 7, 8, 15, 16, 40].map(landmarkLevel), [0, 0, 1, 1, 2, 2, 3, 3]);
  const votes = [
    ...Array.from({ length: 8 }, (_, i) => ({ workerId: `w${i}`, tag: "on_time" as const })),
    { workerId: "w0", tag: "on_time" as const },
    { workerId: "w1", tag: "fair" as const },
  ];
  const island = buildIsland(votes, 8);
  const clock = island.landmarks.find((l) => l.id === "clock_tower");
  assert.equal(clock?.votes, 8);
  assert.equal(clock?.level, 2);
  assert.equal(clock?.nextAt, 16);
  assert.equal(island.landmarks.find((l) => l.id === "fair_fountain")?.sprout, true);
});

test("urgent shifts: reach = free for the slot, has the skill, and under the daily cap", () => {
  const slot = { date: "2026-10-03", start: "17:00", end: "21:00" };
  const pool = [
    { id: "a", roles: ["register" as const], free: [{ date: "2026-10-03", start: "11:00", end: "22:00" }], booked: {}, dailyCapMinutes: 480 },
    { id: "b", roles: ["dish" as const], free: [{ date: "2026-10-03", start: "11:00", end: "22:00" }], booked: {}, dailyCapMinutes: 480 },
    { id: "c", roles: ["register" as const], free: [{ date: "2026-10-03", start: "11:00", end: "22:00" }], booked: { "2026-10-03": 360 }, dailyCapMinutes: 480 },
    { id: "d", roles: ["register" as const], free: [{ date: "2026-10-03", start: "18:00", end: "22:00" }], booked: {}, dailyCapMinutes: 480 },
  ];
  assert.deepEqual(urgentReach(pool, "register", slot), { available: 3, skilled: 2, underCap: 1 });
  // The store only reports counts of 5 or more.
  const store = createStore("sf", { realNow: new Date("2026-09-27T20:00:00Z") });
  const reach = store.urgentReach("stock", { date: "2026-09-28", start: "03:00", end: "04:00" });
  assert.deepEqual(reach, { available: null, skilled: null, underCap: null });
});
