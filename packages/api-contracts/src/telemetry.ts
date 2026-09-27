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
export { TELEMETRY_SHOP_IDS } from "./areas";
import { TELEMETRY_SHOP_IDS } from "./areas";

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
/**
 * When a shift or a listing happens: weekday x time band (e.g. "sat_evening").
 * Bands: morning 6-11, day 11-17, evening 17-22, night 22-6 (JST).
 */
export const TELEMETRY_WEEKDAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"] as const;
export const TELEMETRY_TIME_BANDS = ["morning", "day", "evening", "night"] as const;
export const TELEMETRY_SLOTS = TELEMETRY_WEEKDAYS.flatMap((d) => TELEMETRY_TIME_BANDS.map((b) => `${d}_${b}` as const));
/** Reaction to the cat's reminder the night before / the morning of a shift. */
export const TELEMETRY_REMINDER_REACTIONS = ["ok", "swap", "dismissed"] as const;
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
const slot = z.enum(TELEMETRY_SLOTS as unknown as [string, ...string[]]);

/** props shared by every event. demo_session marks the short judge-demo route. */
const common = { demo_session: bool.optional() };
const props = <T extends z.ZodRawShape>(shape: T) => z.strictObject({ ...common, ...shape }).partial();

export const TelemetryPropSchemas = {
  app_open: props({ day_type: z.enum(["work", "off", "no_shift"]), hours_since_last_shift_end: z.enum(TELEMETRY_SINCE_SHIFT) }),
  job_cards_shown: props({ n: z.number().int().min(0).max(50) }),
  job_card_open: props({ invited: bool, shop_id: shop, slot }),
  job_accept: props({ role, pay_style: z.enum(TELEMETRY_PAY_STYLES), invited: bool, shop_id: shop, slot }),
  job_pass: props({ role, invited: bool, shop_id: shop, slot }),
  shift_start: props({ role, shop_id: shop, slot }),
  shift_end: props({ role, hours_bucket: hours, shop_id: shop, slot }),
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
  // Tapped a landmark on a shop's island ("Left on time" clock tower = review tag on_time).
  landmark_tap: props({ shop_id: shop, tag: z.enum(TELEMETRY_REVIEW_TAGS) }),
  // Weekly availability the worker set for the cat ("when can you work?"), plus a weekly cap.
  availability_set: props({ slots: z.array(slot).max(28), max_per_week: z.number().int().min(0).max(7) }),
  // How the worker reacted to the cat's reminder before a booked shift. In-game only.
  reminder_reaction: props({
    when: z.enum(["night_before", "morning"]),
    reaction: z.enum(TELEMETRY_REMINDER_REACTIONS),
    shop_id: shop,
    slot,
  }),
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

export { INSIGHTS_AREAS, insightsAreaOf, type InsightsArea } from "./areas";

const count = z.number().int().nonnegative();

/** Shop-side shift postings (Air Shift / Townwork style). Not telemetry: supplied by shops in a pilot. */
export const InsightsPostingSchema = z.object({
  shop: z.string(),
  day: z.number().int(), // day index (JST) of the shift
  slot: z.string(),
  openings: count,
  filled: count,
  no_shows: count,
});
export type InsightsPosting = z.infer<typeof InsightsPostingSchema>;

/** At-risk score components, each 0..1 before weighting. */
export const InsightsRiskRowSchema = z.object({
  shop: z.string(),
  area: z.string(),
  workers: count,
  score: z.number(), // 0..100
  components: z.object({
    return_drop: z.number(),
    repeat_pass: z.number(),
    issue_tags: z.number(),
    review_trend: z.number(),
  }),
  /** Raw values behind the components (null = not enough data). */
  raw: z.object({
    return_delta: cell, // next-day return minus the same workers' own baseline
    repeat_pass: cell, // share of invite openers who passed 2+ times
    issue_workers: count, // distinct workers across issue tags that reached 5+ workers
    stars_change: cell, // avg stars, last 4 weeks minus the 4 weeks before
  }),
  /** Signal keys that drive the score, strongest first. */
  reasons: z.array(z.string()),
  issue_tags: z.array(z.object({ key: z.string(), workers: count })),
});

export const InsightsFillRowSchema = z.object({
  shop: z.string(),
  band: z.string(),
  openings_per_week: z.number(),
  predicted_fill: z.number(), // 0..1 for the next week
  backtest_predicted: cell, // model trained on weeks before the holdout
  backtest_actual: cell, // actual fill in the holdout weeks
  no_show_risk: cell,
  /** Weekly fill rate of this listing (null = nothing posted that week). */
  history: z.array(cell),
  fill_rate: cell, // whole window
  no_show_rate: cell, // whole window, per filled opening
});

const kpi = z.object({ now: cell, prev: cell });

/** One shop x one week of aggregated signals. Cells under K_MIN distinct workers are null. */
export const InsightsSignalWeekSchema = z.object({
  shop: z.string(),
  week: z.string(),
  workers: cell, // distinct workers who finished a shift there that week
  next_day_return: cell,
  baseline: cell,
  invite_pass_share: cell,
  issue_workers: cell,
  stars_avg: cell,
  island_visitors: cell,
  openings: z.number().int().nullable(),
  filled: z.number().int().nullable(),
  no_shows: z.number().int().nullable(),
});

export const InsightsRecruitSchema = z.object({
  weeks: z.array(z.string()),
  /** Last 4 weeks vs the 4 before. */
  kpis: z.object({
    dau_mau: kpi,
    off_day_share: kpi,
    fill_rate: kpi,
    next_day_return: kpi,
    active_shops: kpi,
  }),
  signals: z.array(InsightsSignalWeekSchema),
  stages: z.object({
    before: z.object({ off_day_open_share: cell, island_visitors: cell, practice_workers: cell }),
    during: z.object({ shifts: cell, cat_stops_per_100: cell, shift_day_chat_share: cell }),
    after: z.object({ next_day_return: cell, island_revisit_3d: cell, invite_accept_rate: cell, anon_issue_workers: cell }),
  }),
  at_risk: z.object({ rows: z.array(InsightsRiskRowSchema), hidden_shops: count }),
  fill: z.object({
    has_postings: z.boolean(),
    rows: z.array(InsightsFillRowSchema),
    backtest: z.object({ mae: cell, listings: count, holdout_weeks: count }),
    reminders: z.array(z.object({ reaction: z.string(), shifts: cell, no_show_rate: cell })),
    willing_excluded_share: cell, // share of available workers excluded as tired / at their weekly cap
  }),
  supply: z.object({
    has_availability: z.boolean(),
    has_postings: z.boolean(),
    focus_slot: z.string(),
    cells: z.array(z.object({ slot: z.string(), available: cell, open_shifts: cell })),
    areas: z.array(z.object({ area: z.string(), available: cell, open_shifts: cell })),
    /** Area x weekday x time band. */
    grid: z.array(z.object({ area: z.string(), slot: z.string(), available: cell, open_shifts: cell })),
  }),
  interest: z.object({
    visitors: cell,
    visitor_apply_rate: cell,
    non_visitor_apply_rate: cell,
    rows: z.array(z.object({ shop: z.string(), visitors: count, applied: count, apply_rate: cell, top_landmark: z.string().nullable() })),
    landmarks: z.array(z.object({ key: z.string(), taps: count, workers: count })),
  }),
  fit: z.object({
    bins: z.array(z.object({ signals: count, pairs: cell, repeat_rate: cell })),
    base_repeat_rate: cell,
    self_report: z.object({ pairs: cell, repeat_rate: cell }),
    behavior: z.object({ pairs: cell, repeat_rate: cell }),
    shops: z.array(z.object({ shop: z.string(), pairs: count, repeat_rate: cell, strong_signal_share: cell, strong_repeat_rate: cell })),
  }),
});
export type InsightsRecruit = z.infer<typeof InsightsRecruitSchema>;
export type InsightsRiskRow = z.infer<typeof InsightsRiskRowSchema>;
export type InsightsFillRow = z.infer<typeof InsightsFillRowSchema>;
export type InsightsSignalWeek = z.infer<typeof InsightsSignalWeekSchema>;

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
  /** Recruit-facing answers (added in v2; optional so older payloads still parse). */
  recruit: InsightsRecruitSchema.optional(),
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
