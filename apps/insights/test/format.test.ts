import { TELEMETRY_EVENT_TYPES, TELEMETRY_PAY_STYLES } from "@paw-time/api-contracts";
import { INSIGHTS_AREAS, insightsAreaOf } from "@paw-time/api-contracts/areas";
import assert from "node:assert/strict";
import test from "node:test";
import { currencyOf, esc, feedText, fmtMoney, fmtPct, fmtPp } from "../src/format";
import { I18N } from "../src/i18n";
import { UI } from "../src/i18n-ui";
import { SF_AREAS, SF_SHOPS, skinDict, skinUi } from "../src/skin";

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

test("money follows the language: $ with cents where relevant, ¥ without decimals", () => {
  assert.equal(fmtMoney(24.5, "USD", { cents: true, perHour: "/h" }), "$24.50/h");
  assert.equal(fmtMoney(1240, "USD"), "$1,240");
  assert.equal(fmtMoney(1240.4, "USD", { cents: false }), "$1,240");
  assert.equal(fmtMoney(5.2, "USD"), "$5.20", "cents shown when the amount has them");
  assert.equal(fmtMoney(1500, "JPY"), "¥1,500");
  assert.equal(fmtMoney(1430, "JPY", { cents: true, perHour: "/時" }), "¥1,430/時", "yen never shows decimals");
  assert.equal(fmtMoney(-12, "USD"), "−$12");
  assert.equal(fmtMoney(null, "USD"), "—");
  assert.equal(currencyOf("en"), "USD");
  assert.equal(currencyOf("ja"), "JPY");
});

test("San Francisco skin names every simulated shop and area; Japanese keeps its own", () => {
  const en = skinDict(I18N.en, "en");
  assert.deepEqual(Object.keys(SF_SHOPS).sort(), Object.keys(I18N.en.shops).sort());
  assert.deepEqual(Object.keys(SF_AREAS).sort(), [...INSIGHTS_AREAS].sort());
  assert.equal(en.shops.izk_torimaru, "La Brasita Taqueria");
  assert.equal(en.roles.hall, "Server / barista");
  assert.equal(skinUi(UI.en, "en").areas.shotengai, "Mission");
  assert.equal(skinUi(UI.en, "en").payStyles.monthly, "Biweekly");
  // Each SF shop sits in the neighbourhood its comment in skin.ts claims (area is fixed by shop id).
  const expected: Record<string, string> = { cafe_komorebi: "SoMa", izk_kemuri: "SoMa", cvs_hoshi: "SoMa", cafe_sunnyside: "Mission", izk_torimaru: "Mission", cvs_machikado: "Mission", rs_nikoniko: "Mission", izk_chochin: "North Beach", bk_komugi: "North Beach", sm_maruya: "North Beach" };
  for (const [shop, area] of Object.entries(expected)) assert.equal(SF_AREAS[insightsAreaOf(shop)], area, shop);
  // Japanese: unchanged names, yen-era copy.
  assert.equal(skinDict(I18N.ja, "ja").shops.izk_torimaru, "居酒屋 とりまる");
  assert.equal(skinUi(UI.ja, "ja").areas.shotengai, "商店街");
  // Every UI key exists in both languages for the new pay labels.
  for (const lang of ["en", "ja"] as const) {
    assert.ok(UI[lang].cols.hourly_wage && UI[lang].cols.pay_style && UI[lang].perHour, lang);
    for (const k of TELEMETRY_PAY_STYLES) assert.ok(UI[lang].payStyles[k], `${lang}:${k}`);
  }
});
