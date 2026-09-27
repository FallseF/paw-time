// Zod-free constants the dashboard bundles at runtime (kept out of telemetry.ts so the
// static site does not pull in zod).

/** JobListings.LIST ids (sample shops in the game). */
export const TELEMETRY_SHOP_IDS = [
  "cafe_komorebi", "cafe_sunnyside", "cafe_mori", "cafe_tsuki", "cafe_nekomimi", "cafe_harbor", "cafe_hoshizora", "cafe_matcha",
  "cafe_beanbag", "cafe_fuwari", "izk_torimaru", "izk_chochin", "izk_kemuri", "izk_hanabi", "izk_daruma", "izk_minato",
  "izk_hinoki", "izk_tanuki", "cvs_hoshi", "cvs_machikado", "cvs_kurumi", "cvs_tsuki24", "cvs_asahi", "cvs_pocket", "cvs_sakura",
  "wh_kita", "wh_minato", "wh_shiori", "wh_hayate", "wh_tsubame", "wh_nuno", "wh_omocha", "bk_komugi", "bk_mori", "bk_melon",
  "bk_tsukiakari", "bk_koguma", "bk_tomato", "sm_maruya", "sm_midori", "sm_kaede", "sm_tane", "sm_hakka", "rs_nikoniko",
  "rs_yuge", "rs_tsurutsuru", "rs_umi", "rs_hoshi", "rs_hanamaru", "rs_teppan", "rs_kiri", "rs_tamago", "ot_shioridou",
  "ot_tsukikage", "ot_utaya", "ot_hotel", "ot_ohisama", "ot_yuki", "ot_hanahana", "ot_mimi", "ot_pon", "ot_wa", "ot_enpitsu",
  "ot_awa",
] as const;

/** Fictional areas of the demo town. A shop's area is fixed by its sample id; workers' locations are never collected. */
export const INSIGHTS_AREAS = ["station_north", "shotengai", "harbor"] as const;
export type InsightsArea = (typeof INSIGHTS_AREAS)[number];
export const insightsAreaOf = (shop: string): InsightsArea =>
  INSIGHTS_AREAS[Math.max(0, (TELEMETRY_SHOP_IDS as readonly string[]).indexOf(shop)) % INSIGHTS_AREAS.length]!;

