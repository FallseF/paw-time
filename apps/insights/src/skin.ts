// Display side of the locale skins for the simulated pilot (the data side is
// @paw-time/api-contracts/skins). English is set in San Francisco, Japanese in a Japanese
// town. Only names change; every number comes from the same seeded model.
// Live mode keeps the game's own shop names, so the skin applies to the simulation only.
import type { Dict, Lang } from "./i18n";
import type { UiDict } from "./i18n-ui";

/** Fictional San Francisco small businesses standing in for the 10 simulated shops. */
export const SF_SHOPS: Record<string, string> = {
  // SoMa (station_north)
  cafe_komorebi: "Sunlit Pages Bookstore Café",
  izk_kemuri: "Ember Izakaya",
  cvs_hoshi: "Starlight Corner Market",
  // Mission (shotengai)
  cafe_sunnyside: "Sunnyside Boba",
  izk_torimaru: "La Brasita Taqueria",
  cvs_machikado: "24th Street Market",
  rs_nikoniko: "Smiley's Diner",
  // North Beach (harbor)
  izk_chochin: "Paper Lantern Izakaya Bar",
  bk_komugi: "Wheatfield Bakery",
  sm_maruya: "Columbus Avenue Grocery",
};
export const SF_AREAS: Record<string, string> = { station_north: "SoMa", shotengai: "Mission", harbor: "North Beach" };
export const US_ROLES = { register: "Cashier", dish: "Dishwasher", hall: "Server / barista", kitchen: "Line cook", stock: "Stocker" };
/** The model's three pay styles, in US terms (same-day payout apps, weekly, biweekly payroll). */
export const US_PAY_STYLES: Record<string, string> = { daily: "Instant pay", weekly: "Weekly", monthly: "Biweekly" };

const DICT_OVERRIDES: Record<Lang, Partial<Dict>> = {
  en: { shops: SF_SHOPS, roles: US_ROLES },
  ja: {},
};
const UI_OVERRIDES: Record<Lang, Partial<UiDict>> = {
  en: { areas: SF_AREAS, payStyles: US_PAY_STYLES },
  ja: {},
};

export const skinDict = (base: Dict, lang: Lang): Dict => ({ ...base, ...DICT_OVERRIDES[lang] });
export const skinUi = (base: UiDict, lang: Lang): UiDict => ({ ...base, ...UI_OVERRIDES[lang] });
