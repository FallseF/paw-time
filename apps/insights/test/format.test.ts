import { TELEMETRY_EVENT_TYPES } from "@paw-time/api-contracts";
import assert from "node:assert/strict";
import test from "node:test";
import { esc, feedText, fmtPct, fmtPp } from "../src/format";
import { I18N } from "../src/i18n";

test("every telemetry event type has feed copy in both languages", () => {
  for (const lang of ["en", "ja"] as const) {
    for (const type of TELEMETRY_EVENT_TYPES) assert.ok(I18N[lang].events[type as keyof typeof I18N.en.events], `${lang}:${type}`);
  }
});

test("feed lines read naturally", () => {
  assert.equal(feedText(I18N.en, "job_accept", { role: "register" }), "Job accepted · Register");
  assert.equal(feedText(I18N.en, "cat_tired_stop", {}), "Cat got tired and stopped the shift");
  assert.equal(feedText(I18N.ja, "shop_island_visit", { shop_id: "cafe_komorebi" }), "お店の島を訪問 · カフェ こもれび");
});

test("suppressed cells and escaping", () => {
  assert.equal(fmtPct(null), "—");
  assert.equal(fmtPp(-0.083), "−8.3 pt");
  assert.equal(esc(`<img src=x onerror="a">`), "&lt;img src=x onerror=&quot;a&quot;&gt;");
});
