import { z } from "zod";

// ---------------------------------------------------------------------------
// Telemetry: pseudonymous product events from the worker game.
// No free text, no names, no location finer than a sample-shop id, no sleep times.
// Every prop is optional but, when present, must match its enum/range exactly.
// ---------------------------------------------------------------------------

export const TELEMETRY_ROLES = ["register", "dish", "hall", "kitchen", "stock"] as const;
export const TELEMETRY_PAY_STYLES = ["daily", "weekly", "monthly"] as const;
/** Reviews.TAGS in the game. All are positive tags. */
export const TELEMETRY_REVIEW_TAGS = ["breaks", "instructions", "on_time", "paid", "friendly", "fair", "again"] as const;
export const TELEMETRY_HOURS_BUCKETS = ["lt4", "4to6", "6to7_5", "7_5to8", "8to10", "gt10"] as const;
export const TELEMETRY_SINCE_SHIFT = ["none", "lt24", "24to72", "gt72"] as const;
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

/**
 * Chat with the cat-obake. Raw text never leaves the device: the game maps a chat
 * to at most a few of these fixed tags locally. Sensitive categories (health,
 * religion, beliefs, family, etc.) are deliberately not tags.
 */
export const TELEMETRY_CHAT_ISSUE_TOPICS = ["break_hard", "yelled_at", "pay_late", "unclear_instructions", "too_busy"] as const;
export const TELEMETRY_CHAT_POSITIVE_TOPICS = ["liked_team", "liked_customers"] as const;
export const TELEMETRY_CHAT_PREFERENCE_TOPICS = ["want_more_hours", "want_fewer_hours", "prefer_backstage", "prefer_customer_facing"] as const;
export const TELEMETRY_CHAT_TOPICS = [
  ...TELEMETRY_CHAT_ISSUE_TOPICS,
  "nervous_new_role",
  ...TELEMETRY_CHAT_POSITIVE_TOPICS,
  ...TELEMETRY_CHAT_PREFERENCE_TOPICS,
] as const;
export const TELEMETRY_FAQ_TOPICS = ["dress", "entrance", "break"] as const;
export const TELEMETRY_SHOP_MESSAGE_KINDS = ["late", "swap", "thanks", "question"] as const;
/** Roles counted as "backstage" for prefer_backstage; the rest are customer-facing. */
export const TELEMETRY_BACKSTAGE_ROLES: readonly string[] = ["dish", "kitchen", "stock"];

/** Buckets counted as "shift ended at 7.5 h or less" and as overtime (> 8 h). */
export const TELEMETRY_HOURS_LE_7_5: readonly string[] = ["lt4", "4to6", "6to7_5"];
export const TELEMETRY_HOURS_OVERTIME: readonly string[] = ["8to10", "gt10"];

export const TELEMETRY_MAX_EVENTS_PER_BATCH = 50;
export const TELEMETRY_MAX_BODY_BYTES = 16 * 1024;

const role = z.enum(TELEMETRY_ROLES);
const shop = z.enum(TELEMETRY_SHOP_IDS);
const hours = z.enum(TELEMETRY_HOURS_BUCKETS);
const bool = z.boolean();

/** props shared by every event. demo_session marks the short judge-demo route. */
const common = { demo_session: bool.optional() };
const props = <T extends z.ZodRawShape>(shape: T) => z.strictObject({ ...common, ...shape }).partial();

export const TelemetryPropSchemas = {
  app_open: props({ day_type: z.enum(["work", "off", "no_shift"]), hours_since_last_shift_end: z.enum(TELEMETRY_SINCE_SHIFT) }),
  job_cards_shown: props({ n: z.number().int().min(0).max(50) }),
  job_card_open: props({ invited: bool, shop_id: shop }),
  job_accept: props({ role, pay_style: z.enum(TELEMETRY_PAY_STYLES), invited: bool, shop_id: shop }),
  job_pass: props({ role, invited: bool, shop_id: shop }),
  shift_start: props({ role, shop_id: shop }),
  shift_end: props({ role, hours_bucket: hours, shop_id: shop }),
  cat_tired_stop: props({ hours_bucket: hours }),
  review_submitted: props({
    tag_count: z.number().int().min(0).max(10),
    tags: z.array(z.enum(TELEMETRY_REVIEW_TAGS)).max(10),
    stars: z.number().int().min(1).max(5),
    shop_id: shop,
  }),
  practice_done: props({ role, level: z.number().int().min(0).max(20) }),
  skill_badge_share_toggled: props({ on: bool }),
  shop_island_visit: props({ shop_id: shop }),
  scoop_night: props({ orbs: z.number().int().min(0).max(500) }),
  hatch: props({ kind: z.enum(["cat", "material", "clothes"]) }),
  island_expand: props({}),
  island_share: props({}),
  outfit_change: props({}),
  calendar_add: props({ kind: z.enum(["google", "ics"]) }),
  suggestions_toggled: props({ on: bool }),
  chat_open: props({ kind: z.enum(["me", "shop"]) }),
  // Internal use only (matching, product). Sent only when the worker is not in private
  // mode ("Just between us"); the flag must be stated and false.
  chat_signal: z.strictObject({
    ...common,
    topic: z.enum(TELEMETRY_CHAT_TOPICS),
    private_mode: z.literal(false),
    shop_id: shop.optional(),
  }),
  // The worker explicitly agreed to tell this shop, anonymously. Issues only.
  anon_issue_sent: z.strictObject({ ...common, tag: z.enum(TELEMETRY_CHAT_ISSUE_TOPICS), shop_id: shop }),
  faq_auto_answered: props({ topic: z.enum(TELEMETRY_FAQ_TOPICS) }),
  shop_message_sent: props({ kind: z.enum(TELEMETRY_SHOP_MESSAGE_KINDS) }),
} as const;

export type TelemetryEventType = keyof typeof TelemetryPropSchemas;
export const TELEMETRY_EVENT_TYPES = Object.keys(TelemetryPropSchemas) as TelemetryEventType[];

export const TelemetryEventTypeSchema = z.enum(TELEMETRY_EVENT_TYPES as [TelemetryEventType, ...TelemetryEventType[]]);

/** Loose wire shape of one event; props are checked per type with TelemetryPropSchemas. */
export const TelemetryEventInputSchema = z.strictObject({
  t: z.number().finite().optional(),
  type: TelemetryEventTypeSchema,
  props: z.record(z.string(), z.unknown()).optional(),
});

export const TelemetryInstallIdSchema = z.uuid().regex(/^[0-9a-f-]+$/, "lowercase uuid");

export const TelemetryBatchInputSchema = z.strictObject({
  install_id: TelemetryInstallIdSchema,
  events: z.array(z.unknown()).min(1).max(TELEMETRY_MAX_EVENTS_PER_BATCH),
});

export const TelemetryPropValueSchema = z.union([z.string(), z.number(), z.boolean(), z.array(z.string())]);

/** A validated event as stored. t is unix seconds (clamped to server time when implausible). */
export const TelemetryEventSchema = z.object({
  t: z.number().int(),
  type: TelemetryEventTypeSchema,
  props: z.record(z.string(), TelemetryPropValueSchema),
});

export const TelemetryBatchResponseSchema = z.object({
  accepted: z.number().int().nonnegative(),
  rejected: z.array(z.object({ i: z.number().int(), reason: z.string() })),
});

export const TelemetryDeleteInputSchema = z.strictObject({ install_id: TelemetryInstallIdSchema });

export type TelemetryEvent = z.infer<typeof TelemetryEventSchema>;
export type TelemetryPropValue = z.infer<typeof TelemetryPropValueSchema>;
export type TelemetryBatchResponse = z.infer<typeof TelemetryBatchResponseSchema>;

// ---------------------------------------------------------------------------
// Insights: aggregate-only responses for the "Recruit view" dashboard.
// A null cell means "suppressed" (backed by fewer than INSIGHTS_K_MIN installs).
// ---------------------------------------------------------------------------

export const INSIGHTS_K_MIN = 5;

const cell = z.number().nullable();
const keyedRow = z.object({ key: z.string(), value: cell, installs: z.number().int().nullable() });

export const InsightsStorageStatusSchema = z.enum(["connected", "not_connected", "local_memory"]);

export const InsightsAfterShiftRowSchema = z.object({
  shop: z.string(),
  workers: z.number().int(),
  shifts: z.number().int(),
  next_day_open: cell,
  baseline: cell,
  delta: cell,
  visit_3d: cell,
  repeat_pass: cell,
  review_rate: cell,
});

/** Acceptance of workers who told their cat a work preference vs all workers (hypothesis). */
export const InsightsChatPreferenceRowSchema = z.object({
  key: z.string(),
  workers: cell,
  accept_rate: cell,
  baseline_accept_rate: cell,
  /** prefer_backstage / prefer_customer_facing only: share of their accepted jobs that match. */
  fit_share: cell,
  baseline_fit_share: cell,
});

const shopViewItem = z.object({ key: z.string(), workers: z.number().int() });
export const InsightsShopViewRowSchema = z.object({
  shop: z.string(),
  issues: z.array(shopViewItem),
  positives: z.array(shopViewItem),
});

export const InsightsAggregateSchema = z.object({
  installs: cell,
  window: z.object({ start: z.string(), end: z.string(), weeks: z.number().int() }),
  headline: z.object({
    dau: cell,
    wau: cell,
    mau: cell,
    stickiness: cell,
    no_job_search_share: cell,
    off_days_without_card_open: cell,
    active_install_days: cell,
  }),
  daily: z.array(z.object({ day: z.string(), dau: cell })),
  weekly_day_type: z.array(z.object({ week: z.string(), work: cell, off: cell, no_shift: cell })),
  off_day_activities: z.array(keyedRow),
  retention: z.array(z.object({ cohort: z.string(), size: cell, d1: cell, d7: cell, d30: cell })),
  funnel: z.object({
    shown: cell,
    opened: cell,
    accepted: cell,
    shift_done: cell,
    reviewed: cell,
    invited: z.object({ opened: cell, accepted: cell, accept_rate: cell }),
    normal: z.object({ opened: cell, accepted: cell, accept_rate: cell }),
    accept_by_role: z.array(keyedRow),
  }),
  wellbeing: z.object({
    cat_stops: cell,
    shifts: cell,
    le75_share: cell,
    overtime_rate: cell,
    weekly: z.array(
      z.object({ week: z.string(), shifts: cell, cat_stops: cell, le75_share: cell, overtime_rate: cell, review_rate: cell }),
    ),
  }),
  reviews: z.object({ response_rate: cell, stars_avg: cell, tags: z.array(keyedRow) }),
  skills: z.object({ practice_by_role: z.array(keyedRow), badge_opt_in_rate: cell }),
  after_shift: z.object({ rows: z.array(InsightsAfterShiftRowSchema), hidden_shops: z.number().int() }),
  shops: z.object({ visits: z.array(keyedRow), invites: z.object({ opened: cell, accepted: cell }) }),
  /** Internal only: what workers tell their cat, as fixed tags. */
  chat: z.object({
    opens: cell,
    chatters: cell,
    signals: cell,
    topics: z.array(keyedRow),
    preferences: z.array(InsightsChatPreferenceRowSchema),
    faq: z.array(keyedRow),
    shop_messages: z.array(keyedRow),
    anon_issues: cell,
  }),
  /** What a shop would see: >= K_MIN distinct workers per tag, whole window, week granularity. */
  shop_view: z.object({
    period: z.object({ start: z.string(), end: z.string() }),
    shops: z.array(InsightsShopViewRowSchema),
  }),
});

export const InsightsMetricsResponseSchema = z.object({
  mode: z.enum(["live", "simulated"]),
  synthetic: z.boolean(),
  label: z.string(),
  storage: InsightsStorageStatusSchema,
  data: InsightsAggregateSchema,
});

export const InsightsFeedItemSchema = z.object({
  type: TelemetryEventTypeSchema,
  props: z.record(z.string(), TelemetryPropValueSchema),
  ago_s: z.number().int().nonnegative(),
  demo: z.boolean(),
});

export const InsightsFeedResponseSchema = z.object({
  storage: InsightsStorageStatusSchema,
  window_min: z.number().int(),
  players: z.number().int().nonnegative(),
  counts: z.record(z.string(), z.number().int()),
  items: z.array(InsightsFeedItemSchema),
});

export type InsightsAggregate = z.infer<typeof InsightsAggregateSchema>;
export type InsightsAfterShiftRow = z.infer<typeof InsightsAfterShiftRowSchema>;
export type InsightsChatPreferenceRow = z.infer<typeof InsightsChatPreferenceRowSchema>;
export type InsightsShopViewRow = z.infer<typeof InsightsShopViewRowSchema>;
export type InsightsMetricsResponse = z.infer<typeof InsightsMetricsResponseSchema>;
export type InsightsFeedResponse = z.infer<typeof InsightsFeedResponseSchema>;
export type InsightsStorageStatus = z.infer<typeof InsightsStorageStatusSchema>;
