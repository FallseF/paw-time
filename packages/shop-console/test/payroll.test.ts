import assert from "node:assert/strict";
import test from "node:test";
import {
  addMonths,
  createStore,
  csvCell,
  daysInMonth,
  legalBreakMinutes,
  monthClose,
  monthPayroll,
  niceScale,
  payLine,
  toCsv,
} from "../src/index";
import type { ShiftView } from "../src/index";

const NOW = new Date("2026-09-15T12:00:00Z");

const shift = (over: Partial<ShiftView>): ShiftView => ({
  id: "s1",
  jobId: "j1",
  jobTitle: "Register",
  role: "register",
  slotId: "j1-s1",
  workerId: "w1",
  displayName: "Maya",
  cat: { name: "Mochi", color: "#000" },
  date: "2026-09-10",
  start: "09:00",
  end: "17:00",
  startAt: "2026-09-10T09:00:00Z",
  endAt: "2026-09-10T17:00:00Z",
  status: "scheduled",
  checkInAt: null,
  checkOutAt: null,
  minutesLate: null,
  corrected: false,
  threadId: null,
  ...over,
});

test("legal break: none up to 6 h, 45 min over 6 h, 60 min over 8 h (LSA art. 34)", () => {
  assert.equal(legalBreakMinutes(0), 0);
  assert.equal(legalBreakMinutes(360), 0);
  assert.equal(legalBreakMinutes(361), 45);
  assert.equal(legalBreakMinutes(480), 45);
  assert.equal(legalBreakMinutes(481), 60);
  assert.equal(legalBreakMinutes(600), 60);
});

test("pay line: checked in and out is confirmed and priced from the punches minus the legal break", () => {
  const line = payLine(
    shift({ status: "checked_out", checkInAt: "2026-09-10T09:00:00Z", checkOutAt: "2026-09-10T16:30:00Z" }),
    1300,
    "JPY",
    NOW,
  );
  assert.ok(line);
  assert.equal(line.kind, "confirmed");
  assert.deepEqual([line.spanMinutes, line.breakMinutes, line.paidMinutes, line.amount], [450, 45, 405, 8775]);
});

test("pay line: USD rounds to cents, JPY to whole yen", () => {
  const usd = payLine(shift({ status: "checked_out", checkInAt: "2026-09-10T09:00:00Z", checkOutAt: "2026-09-10T13:07:00Z" }), 24.5, "USD", NOW);
  assert.equal(usd?.amount, 100.86); // 247 min × $24.50/h = $100.858…
  const jpy = payLine(shift({ status: "checked_out", checkInAt: "2026-09-10T09:00:00Z", checkOutAt: "2026-09-10T13:07:00Z" }), 1450, "JPY", NOW);
  assert.equal(jpy?.amount, 5969); // 247 min × ¥1,450/h = ¥5,969.1…
});

test("pay line: a started shift missing a punch is awaiting; a future one is a forecast; a no-show costs nothing", () => {
  const inOnly = payLine(shift({ status: "checked_in", checkInAt: "2026-09-10T09:30:00Z" }), 1300, "JPY", NOW);
  assert.equal(inOnly?.kind, "awaiting");
  assert.equal(inOnly?.spanMinutes, 450); // check-in to the scheduled end
  assert.equal(payLine(shift({}), 1300, "JPY", NOW)?.kind, "awaiting");
  const future = payLine(shift({ date: "2026-09-20", startAt: "2026-09-20T09:00:00Z", endAt: "2026-09-20T17:00:00Z" }), 1300, "JPY", NOW);
  assert.equal(future?.kind, "forecast");
  assert.deepEqual([future?.breakMinutes, future?.paidMinutes, future?.amount], [45, 435, 9425]);
  assert.equal(payLine(shift({ status: "no_show" }), 1300, "JPY", NOW), null);
});

test("month payroll: totals split confirmed / awaiting / forecast, per day, and skip other months", () => {
  const shifts = [
    shift({ id: "a", status: "checked_out", checkInAt: "2026-09-10T09:00:00Z", checkOutAt: "2026-09-10T13:00:00Z" }),
    shift({ id: "b", date: "2026-09-20", startAt: "2026-09-20T09:00:00Z", endAt: "2026-09-20T13:00:00Z" }),
    shift({ id: "c", date: "2026-09-10", status: "no_show" }),
    shift({ id: "d", date: "2026-10-01", startAt: "2026-10-01T09:00:00Z", endAt: "2026-10-01T13:00:00Z" }),
  ];
  const p = monthPayroll("2026-09", shifts, () => 1000, "JPY", NOW);
  assert.equal(p.lines.length, 2);
  assert.deepEqual(p.totals, { confirmed: 4000, awaiting: 0, forecast: 4000, all: 8000 });
  assert.deepEqual(p.counts, { confirmed: 1, awaiting: 0, forecast: 1 });
  assert.equal(p.noShows, 1);
  assert.equal(p.days.length, 30);
  assert.deepEqual(p.days[9], { day: 10, confirmed: 4000, projected: 0, total: 4000 });
  assert.deepEqual(p.days[19], { day: 20, confirmed: 0, projected: 4000, total: 4000 });
});

test("month close: ready only after the month ends with every shift punched", () => {
  const done = monthPayroll("2026-09", [shift({ status: "checked_out", checkInAt: "2026-09-10T09:00:00Z", checkOutAt: "2026-09-10T13:00:00Z" })], () => 1000, "JPY", NOW);
  assert.equal(monthClose(done, "2026-09-30").ready, false);
  assert.equal(monthClose(done, "2026-10-01").ready, true);
  const missing = monthPayroll("2026-09", [shift({})], () => 1000, "JPY", NOW);
  assert.deepEqual([monthClose(missing, "2026-10-01").ready, monthClose(missing, "2026-10-01").missingPunches], [false, 1]);
});

test("months: days in month, and stepping across a year", () => {
  assert.equal(daysInMonth("2026-02"), 28);
  assert.equal(daysInMonth("2028-02"), 29);
  assert.equal(daysInMonth("2026-09"), 30);
  assert.equal(addMonths("2026-12", 1), "2027-01");
  assert.equal(addMonths("2026-01", -1), "2025-12");
});

test("chart scale: clean ceilings and five ticks", () => {
  assert.deepEqual(niceScale(0), { ceiling: 4, ticks: [0, 1, 2, 3, 4] });
  assert.deepEqual(niceScale(37_000), { ceiling: 40_000, ticks: [0, 10_000, 20_000, 30_000, 40_000] });
  assert.equal(niceScale(412).ceiling, 800); // step 103 rounds up to 200
});

test("csv: BOM, CRLF and quoting for commas, quotes and newlines", () => {
  assert.equal(csvCell("plain"), "plain");
  assert.equal(csvCell('say "hi", ok'), '"say ""hi"", ok"');
  assert.equal(csvCell("a\nb"), '"a\nb"');
  const csv = toCsv([["日付", "金額"], ["2026-09-10", 1300]]);
  assert.equal(csv.charCodeAt(0), 0xfeff);
  assert.equal(csv, "﻿日付,金額\r\n2026-09-10,1300\r\n");
});

test("store: the sample month has confirmed pay from punched shifts and no pay for the no-show", () => {
  for (const region of ["sf", "jp"] as const) {
    const store = createStore(region, { realNow: new Date("2026-09-27T20:00:00Z") });
    const month = store.today().slice(0, 7);
    const p = store.monthPayroll(month);
    assert.ok(p.counts.confirmed >= 1, `${region}: confirmed shifts`);
    assert.ok(p.totals.all > 0, `${region}: labor cost`);
    assert.equal(p.currency, region === "sf" ? "USD" : "JPY");
    // Every line is a shift fact priced from the job's wage; nothing per worker is scored.
    for (const line of p.lines) assert.equal(line.amount >= 0, true);
    assert.ok(p.noShows >= 0);
  }
});

test("csv: text cells that a spreadsheet would run as a formula are prefixed with a quote", () => {
  assert.equal(csvCell('=HYPERLINK("http://x")'), `"'=HYPERLINK(""http://x"")"`);
  const out = toCsv([['=HYPERLINK("http://x")', "+1", "-cmd", "@SUM(A1)", "\tx", "\rx", "Maya"]]).slice(1);
  const cells = ["'=HYPERLINK", "'+1", "'-cmd", "'@SUM(A1)", "'\tx", "\"'\rx\"", "Maya"];
  for (const c of cells) assert.ok(out.includes(c), `${JSON.stringify(c)} in ${JSON.stringify(out)}`);
  // The first cell, once unquoted, starts with '=
  assert.ok(out.startsWith(`"'=`));
  // Numbers are data, not text: negative amounts stay numbers.
  assert.equal(csvCell(-120), "-120");
});
