/**
 * Product rules of the shop console. Pure functions; the store and the UI both call these,
 * so a rule is enforced in one place and tested once.
 */
import { addDays, zonedParts, zonedToUtc } from "./time";
import type {
  AggregateCount,
  Currency,
  Faq,
  FaqKey,
  FieldError,
  ImprovementReport,
  IslandView,
  IssueId,
  JobInput,
  LandmarkId,
  LandmarkView,
  PositiveTag,
  Region,
  Role,
} from "./types";

// ---------------------------------------------------------------- regions

export type RegionInfo = {
  currency: Currency;
  timeZone: string;
  minimumWageArea: string;
  /** Oldest first. Each entry applies from its date (inclusive) until the next one. */
  minimumWage: Array<{ from: string; amount: number }>;
};

export const REGIONS: Record<Region, RegionInfo> = {
  sf: {
    currency: "USD",
    timeZone: "America/Los_Angeles",
    minimumWageArea: "San Francisco",
    minimumWage: [
      { from: "2025-07-01", amount: 19.18 },
      { from: "2026-07-01", amount: 19.61 },
    ],
  },
  jp: {
    currency: "JPY",
    timeZone: "Asia/Tokyo",
    minimumWageArea: "東京都",
    minimumWage: [
      { from: "2024-10-01", amount: 1163 },
      { from: "2025-10-03", amount: 1226 },
      { from: "2026-10-01", amount: 1280 },
    ],
  },
};

export function minimumWageOn(region: Region, date: string): { amount: number; from: string } {
  const table = REGIONS[region].minimumWage;
  let current = table[0] ?? { from: "1970-01-01", amount: 0 };
  for (const row of table) if (row.from <= date) current = row;
  return current;
}

export type MinimumWageCheck = { ok: boolean; minimum: number; from: string; shortBy: number; date: string };

/**
 * Checks an hourly wage against the local minimum wage in force on every slot date.
 * The latest date decides when several apply (minimum wage only goes up).
 */
export function checkMinimumWage(wage: number, region: Region, dates: string[]): MinimumWageCheck {
  const latest = [...dates].sort().at(-1) ?? "1970-01-01";
  const { amount, from } = minimumWageOn(region, latest);
  const cents = (n: number) => Math.round(n * 100);
  const ok = Number.isFinite(wage) && cents(wage) >= cents(amount);
  return { ok, minimum: amount, from, shortBy: ok ? 0 : Math.max(0, cents(amount) - cents(wage)) / 100, date: latest };
}

// ---------------------------------------------------------------- job form

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

export function validateJob(input: JobInput, region: Region): FieldError[] {
  const errors: FieldError[] = [];
  if (!input.title.trim()) errors.push({ field: "title", code: "required" });
  if (input.title.length > 80) errors.push({ field: "title", code: "too_long" });
  if (input.slots.length === 0) errors.push({ field: "slots", code: "required" });
  input.slots.forEach((slot, i) => {
    if (!DATE.test(slot.date)) errors.push({ field: `slots.${i}.date`, code: "invalid" });
    if (!TIME.test(slot.start)) errors.push({ field: `slots.${i}.start`, code: "invalid" });
    if (!TIME.test(slot.end)) errors.push({ field: `slots.${i}.end`, code: "invalid" });
    else if (TIME.test(slot.start) && slot.end <= slot.start) errors.push({ field: `slots.${i}.end`, code: "before_start" });
    if (!Number.isInteger(slot.capacity) || slot.capacity < 1 || slot.capacity > 50) {
      errors.push({ field: `slots.${i}.capacity`, code: "invalid" });
    }
  });
  if (!Number.isFinite(input.wage) || input.wage <= 0) {
    errors.push({ field: "wage", code: "required" });
  } else {
    const check = checkMinimumWage(input.wage, region, input.slots.map((s) => s.date).filter((d) => DATE.test(d)));
    if (!check.ok) errors.push({ field: "wage", code: "below_minimum", minimum: check.minimum });
  }
  if (input.dressCode.length > 200) errors.push({ field: "dressCode", code: "too_long" });
  if (input.notes.length > 1000) errors.push({ field: "notes", code: "too_long" });
  return errors;
}

// ---------------------------------------------------------------- aggregates (5+ rule)

/** Smallest group a shop can see a number for. Below this, counts and issues are not shown. */
export const MIN_AGGREGATE = 5;

export function aggregate(n: number): AggregateCount {
  return n >= MIN_AGGREGATE ? n : null;
}

// ---------------------------------------------------------------- shop island

export const LANDMARKS: ReadonlyArray<readonly [PositiveTag, LandmarkId]> = [
  ["on_time", "clock_tower"],
  ["breaks", "rest_grove"],
  ["instructions", "guide_post"],
  ["paid", "payday_bell"],
  ["friendly", "lantern_path"],
  ["fair", "fair_fountain"],
  ["again", "welcome_arch"],
];
/** Votes for level 1, 2 and 3. Levels only count votes, so they never go down. */
export const LANDMARK_LEVELS = [3, 8, 16] as const;

export function landmarkLevel(votes: number): 0 | 1 | 2 | 3 {
  let level: 0 | 1 | 2 | 3 = 0;
  LANDMARK_LEVELS.forEach((need, i) => {
    if (votes >= need) level = (i + 1) as 1 | 2 | 3;
  });
  return level;
}

/**
 * The island is built only from positive tags in worker reviews. There is no input for money,
 * plan or shop settings here on purpose: landmarks cannot be bought.
 */
export function buildIsland(votes: Array<{ workerId: string; tag: PositiveTag }>, reviewers: number): IslandView {
  const byTag = new Map<PositiveTag, Set<string>>();
  for (const v of votes) {
    const set = byTag.get(v.tag) ?? new Set<string>();
    set.add(v.workerId);
    byTag.set(v.tag, set);
  }
  const landmarks: LandmarkView[] = LANDMARKS.map(([tag, id]) => {
    const n = byTag.get(tag)?.size ?? 0;
    const level = landmarkLevel(n);
    return {
      tag,
      id,
      votes: n,
      level,
      sprout: level === 0 && n > 0,
      nextAt: level < 3 ? ((LANDMARK_LEVELS as readonly number[])[level] ?? null) : null,
    };
  });
  return { landmarks, basedOn: reviewers, totalLevel: landmarks.reduce((s, l) => s + l.level, 0) };
}

// ---------------------------------------------------------------- improvement report

export const ISSUES: IssueId[] = ["no_break", "left_late", "unclear", "too_busy", "late_pay", "rude"];
export const ISSUE_ACTIONS: Record<IssueId, string> = {
  no_break: "break_schedule",
  left_late: "closing_plan",
  unclear: "first_day_checklist",
  too_busy: "add_peak_slot",
  late_pay: "confirm_payday",
  rude: "team_guide",
};

/**
 * Anonymous issues, only when at least 5 distinct workers said the same thing. Issues below
 * the threshold are left out entirely (not listed as "few"), and weekly buckets under 5 are null.
 */
export function buildImprovementReport(
  responses: Array<{ workerId: string; issue: IssueId; week: string }>,
  weeks: string[],
): ImprovementReport {
  const issues = ISSUES.flatMap((issue) => {
    const mine = responses.filter((r) => r.issue === issue);
    const workers = new Set(mine.map((r) => r.workerId)).size;
    if (workers < MIN_AGGREGATE) return [];
    const trend = weeks.map((week) => ({
      week,
      workers: aggregate(new Set(mine.filter((r) => r.week === week).map((r) => r.workerId)).size),
    }));
    return [{ issue, workers, trend, action: ISSUE_ACTIONS[issue] }];
  }).sort((a, b) => b.workers - a.workers);
  return { threshold: MIN_AGGREGATE, weeks, status: issues.length ? "ready" : "not_enough", issues };
}

// ---------------------------------------------------------------- chat

/** Shops can reach workers only 8:00–21:00 local time. Outside that, messages wait until 8:00. */
export const DELIVERY_WINDOW = { from: 8, to: 21 } as const;

export function shopMessageDelivery(sentAt: Date, timeZone: string): { status: "delivered" | "queued"; deliverAt: string } {
  const p = zonedParts(sentAt, timeZone);
  if (p.hour >= DELIVERY_WINDOW.from && p.hour < DELIVERY_WINDOW.to) {
    return { status: "delivered", deliverAt: sentAt.toISOString() };
  }
  const date = p.hour >= DELIVERY_WINDOW.to ? addDays(p.date, 1) : p.date;
  const at = zonedToUtc(date, `${String(DELIVERY_WINDOW.from).padStart(2, "0")}:00`, timeZone);
  return { status: "queued", deliverAt: at.toISOString() };
}

const FAQ_WORDS: Record<FaqKey, RegExp> = {
  dressCode: /(dress|wear|uniform|shoes|apron|clothes|服装|服|制服|靴|エプロン|髪)/i,
  entrance: /(entrance|enter|door|where do i|back door|park|bike|入口|どこから|裏口|駐輪|自転車|場所)/i,
  breaks: /(break|lunch|rest|meal|休憩|まかない|昼休み)/i,
  contactName: /(who (should|do) i|ask for|contact|manager|誰に|だれに|担当|店長)/i,
};

/** Which FAQ answers a worker question, if any. Order matters: most specific first. */
export function matchFaq(question: string, faq: Faq): FaqKey | null {
  for (const key of ["dressCode", "entrance", "breaks", "contactName"] as const) {
    if (FAQ_WORDS[key].test(question) && faq[key].trim()) return key;
  }
  return null;
}

// ---------------------------------------------------------------- urgent shifts

export type PoolWorker = {
  id: string;
  roles: Role[];
  /** Local dates and windows the worker marked as free. */
  free: Array<{ date: string; start: string; end: string }>;
  /** Minutes already booked per date. */
  booked: Record<string, number>;
  /** The worker's own daily cap, in minutes. */
  dailyCapMinutes: number;
};

/**
 * Who an urgent shift would reach: free for the whole slot → has the role → still under their
 * own daily cap with this slot added. Shops only get the counts, never the people.
 */
export function urgentReach(pool: PoolWorker[], role: Role, slot: { date: string; start: string; end: string }) {
  const len = (a: string, b: string) => {
    const [ah, am] = a.split(":").map(Number);
    const [bh, bm] = b.split(":").map(Number);
    return (bh ?? 0) * 60 + (bm ?? 0) - ((ah ?? 0) * 60 + (am ?? 0));
  };
  const minutes = len(slot.start, slot.end);
  const available = pool.filter((w) => w.free.some((f) => f.date === slot.date && f.start <= slot.start && f.end >= slot.end));
  const skilled = available.filter((w) => w.roles.includes(role));
  const underCap = skilled.filter((w) => (w.booked[slot.date] ?? 0) + minutes <= w.dailyCapMinutes);
  return { available: available.length, skilled: skilled.length, underCap: underCap.length };
}
