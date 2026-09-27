import assert from "node:assert/strict";
import test from "node:test";
import { CALC_DEFAULTS, WEEKS_PER_MONTH, pilotValue } from "../src/calc";
import { applyQuery, COLUMNS, listingStatus, riskLevel, supplyStatus, toCsv, VIEWS, type Row } from "../src/model";

test("pilot calculator: monthly fills, no-shows avoided and yen value", () => {
  const out = pilotValue(CALC_DEFAULTS);
  const posted = 5 * 20 * WEEKS_PER_MONTH; // 433.3 posted shifts a month
  assert.ok(Math.abs(out.postedPerMonth - posted) < 1e-9);
  assert.ok(Math.abs(out.fillsGained - posted * 0.03) < 1e-9); // 13.0
  assert.ok(Math.abs(out.noShowsAvoided - posted * 0.75 * 0.05 * 0.2) < 1e-9); // 3.25
  assert.ok(Math.abs(out.total - (posted * 0.03 * 1500 + posted * 0.75 * 0.05 * 0.2 * 5000)) < 1e-6);
  assert.ok(Math.abs(out.annual - out.total * 12) < 1e-6);
  assert.ok(Math.abs((out.perWorker ?? 0) - out.total / 60) < 1e-9);
});

test("pilot calculator: fill can't pass 100% and bad inputs count as zero", () => {
  const out = pilotValue({ ...CALC_DEFAULTS, currentFill: 0.99, fillUplift: 0.1 });
  assert.ok(Math.abs(out.fillsGained - out.postedPerMonth * 0.01) < 1e-9);
  const zero = pilotValue({ ...CALC_DEFAULTS, shops: -3, workers: 0, fillFee: Number.NaN });
  assert.equal(zero.total, 0);
  assert.equal(zero.perWorker, null);
});

test("status rules for risk, listings and supply slots", () => {
  assert.equal(riskLevel(62), "high");
  assert.equal(riskLevel(30), "medium");
  assert.equal(riskLevel(29), "low");
  assert.equal(listingStatus(0.5, 0.01), "likely_unfilled");
  assert.equal(listingStatus(0.8, 0.12), "no_show_risk");
  assert.equal(listingStatus(0.8, null), "on_track");
  assert.equal(supplyStatus(null, 3), "hidden", "fewer than 5 workers never shows a number");
  assert.equal(supplyStatus(12, null), "no_postings");
  assert.equal(supplyStatus(12, 2.5), "untapped");
  assert.equal(supplyStatus(12, 1.5), "covered");
});

const rows: Row[] = [
  { id: "a", table: "shops", shop: "cafe_komorebi", area: "station_north", risk_score: 10, risk: "low" },
  { id: "b", table: "shops", shop: "izk_torimaru", area: "shotengai", risk_score: 58, risk: "high" },
  { id: "c", table: "shops", shop: "cvs_hoshi", area: "station_north", risk_score: null, risk: null },
  { id: "d", table: "shops", shop: "izk_chochin", area: "harbor", risk_score: 40, risk: "medium" },
];
const text = (r: Row) => `${r.shop} ${r.area}`;

test("query: filters, search and sort with nulls last", () => {
  const byScore = applyQuery(rows, { search: "", filters: [], sort: { key: "risk_score", dir: -1 } }, text);
  assert.deepEqual(byScore.map((r) => r.id), ["b", "d", "a", "c"]);
  const asc = applyQuery(rows, { search: "", filters: [], sort: { key: "risk_score", dir: 1 } }, text);
  assert.deepEqual(asc.map((r) => r.id), ["a", "d", "b", "c"], "null still last when ascending");
  const risky = applyQuery(rows, { search: "", filters: [{ key: "risk_score", op: "gte", value: 30 }], sort: null }, text);
  assert.deepEqual(risky.map((r) => r.id), ["b", "d"]);
  const north = applyQuery(rows, { search: "NORTH", filters: [], sort: null }, text);
  assert.deepEqual(north.map((r) => r.id), ["a", "c"]);
  const inArea = applyQuery(rows, { search: "", filters: [{ key: "area", op: "in", value: ["harbor", "shotengai"] }], sort: { key: "risk", dir: -1 } }, text);
  assert.deepEqual(inArea.map((r) => r.id), ["b", "d"], "risk sorts high > medium > low");
});

test("csv: header, raw numbers, labels, quoting and formula neutralising", () => {
  const cols = COLUMNS.shops.filter((c) => ["shop", "risk_score", "issue_tags"].includes(c.key));
  const csv = toCsv(
    [
      { id: "x", table: "shops", shop: "izk_torimaru", risk_score: 57.123456, issue_tags: ["yelled_at", "too_busy"] },
      { id: "y", table: "shops", shop: "=cmd", risk_score: null, issue_tags: [] },
    ],
    cols,
    (c) => (c.key === "shop" ? "Shop, name" : c.key),
    (c, v) => (v === "izk_torimaru" ? 'Izakaya "Tori"' : v),
  );
  assert.equal(csv, `"Shop, name",risk_score,issue_tags\r\n"Izakaya ""Tori""",57.1235,yelled_at; too_busy\r\n'=cmd,,\r\n`);
});

test("every saved view points at real columns", () => {
  assert.equal(VIEWS.length, 5);
  for (const v of VIEWS) {
    const keys = new Set(COLUMNS[v.table].map((c) => c.key));
    for (const c of v.columns) assert.ok(keys.has(c), `${v.id}:${c}`);
    for (const f of v.query.filters) assert.ok(keys.has(f.key), `${v.id}:filter ${f.key}`);
    if (v.query.sort) assert.ok(keys.has(v.query.sort.key), `${v.id}:sort`);
  }
});
