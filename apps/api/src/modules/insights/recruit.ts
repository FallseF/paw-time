// Recruit-facing answers built on the same event stream (live or synthetic) plus optional
// shop-side postings. Aggregate-only: every number is backed by K_MIN+ distinct installs
// or it is null / omitted. Nothing here scores an individual for a shop.
import {
  TELEMETRY_CHAT_ISSUE_TOPICS as ISSUE_TOPICS,
  TELEMETRY_HOURS_OVERTIME as HOURS_OVERTIME,
  TELEMETRY_SLOTS as SLOTS,
  TELEMETRY_TIME_BANDS as BANDS,
  INSIGHTS_AREAS,
  insightsAreaOf,
  type InsightsFillRow,
  type InsightsPosting,
  type InsightsRecruit,
  type InsightsRiskRow,
} from "@paw-time/api-contracts";
import { K_MIN, dayOf, type FlatEvent } from "./aggregate.js";

type Cell = number | null;
const gate = (value: number, n: number): Cell => (n >= K_MIN ? value : null);
const rate = (num: number, den: number, n: number): Cell => (den > 0 && n >= K_MIN ? num / den : null);
const clamp01 = (x: number) => Math.min(1, Math.max(0, x));
const round = (x: number, d = 3) => Math.round(x * 10 ** d) / 10 ** d;
const bandOf = (slot: string) => slot.slice(slot.indexOf("_") + 1);

export const FOCUS_SLOT = "sat_evening";
/** Weeks held out at the end of the window to check the fill model. */
export const HOLDOUT_WEEKS = 4;

// ---- At-risk score ----------------------------------------------------------------

/** Weight (points out of 100) and the value at which each signal counts in full. */
export const RISK_WEIGHTS = {
  return_drop: { points: 35, full: 0.15 }, // next-day return 15 pt below the same workers' own habit
  repeat_pass: { points: 25, floor: 0.05, full: 0.4 }, // share of invite openers passing it 2+ times
  issue_tags: { points: 25, full: 0.25 }, // workers behind issue tags that reached 5+, per worker
  review_trend: { points: 15, full: 0.4 }, // average stars down 0.4 in the last 4 weeks
} as const;

export interface RiskInput {
  workers: number;
  return_delta: Cell;
  repeat_pass: Cell;
  issue_workers: number;
  stars_change: Cell;
}

export function riskScore(x: RiskInput): { score: number; components: InsightsRiskRow["components"]; reasons: string[] } {
  const W = RISK_WEIGHTS;
  const components = {
    return_drop: x.return_delta == null ? 0 : clamp01(-x.return_delta / W.return_drop.full),
    repeat_pass: x.repeat_pass == null ? 0 : clamp01((x.repeat_pass - W.repeat_pass.floor) / (W.repeat_pass.full - W.repeat_pass.floor)),
    issue_tags: x.workers > 0 ? clamp01(x.issue_workers / x.workers / W.issue_tags.full) : 0,
    review_trend: x.stars_change == null ? 0 : clamp01(-x.stars_change / W.review_trend.full),
  };
  const points = (Object.keys(components) as (keyof typeof components)[]).map((k) => ({ k, p: components[k] * W[k].points }));
  const score = Math.round(points.reduce((s, x) => s + x.p, 0));
  const reasons = points.filter((x) => components[x.k] >= 0.3).sort((a, b) => b.p - a.p).map((x) => x.k);
  return { score, components: { return_drop: round(components.return_drop), repeat_pass: round(components.repeat_pass), issue_tags: round(components.issue_tags), review_trend: round(components.review_trend) }, reasons };
}

// ---- Fill forecast ----------------------------------------------------------------

/** Prior strength (in openings) that pulls a thin listing towards its band's market fill. */
export const FILL_PRIOR = 8;

/**
 * Next-period fill for one listing: its own history, smoothed towards the market fill of the
 * same time band, scaled by how willing supply in that band moved (square root, capped ±30%).
 */
export function forecastFill(history: { openings: number; filled: number }, marketFill: number, supplyBefore: number, supplyNow: number): number {
  const smoothed = (history.filled + FILL_PRIOR * marketFill) / (history.openings + FILL_PRIOR);
  const trend = supplyBefore > 0 ? Math.min(1.3, Math.max(0.7, Math.sqrt(supplyNow / supplyBefore))) : 1;
  return clamp01(smoothed * trend);
}

/** Expected no-show from the mix of night-before reactions and the rate behind each reaction. */
export function reactionNoShow(mix: Record<string, number>, rates: Record<string, number | null>): number | null {
  let total = 0;
  let exp = 0;
  for (const [r, n] of Object.entries(mix)) {
    const p = rates[r];
    if (p == null) continue;
    total += n;
    exp += n * p;
  }
  return total > 0 ? exp / total : null;
}

// ---- Supply ------------------------------------------------------------------------

export interface SupplyWorker {
  slots: ReadonlySet<string>;
  area: string | null;
  excluded: boolean; // tired or at their weekly cap right now
}

/** Available & willing workers per slot (suppressed under K_MIN) vs open shifts per week. */
export function supplyGrid(workers: SupplyWorker[], openPerWeek: Map<string, number> | null) {
  const willing = workers.filter((w) => !w.excluded);
  return SLOTS.map((slot) => {
    const n = willing.filter((w) => w.slots.has(slot)).length;
    return { slot, available: gate(n, n), open_shifts: openPerWeek ? round(openPerWeek.get(slot) ?? 0, 1) : null };
  });
}

// ---- Builder -------------------------------------------------------------------------

export interface RecruitInput {
  events: FlatEvent[];
  postings: InsightsPosting[];
  nowDay: number;
  startDay: number;
  offDayOpenShare: Cell;
  inviteAcceptRate: Cell;
  weekLabels: string[];
}

export function recruitAnswers({ events, postings, nowDay, startDay, offDayOpenShare, inviteAcceptRate, weekLabels }: RecruitInput): InsightsRecruit {
  const nWeeks = weekLabels.length;
  const activeDays = new Map<string, Set<number>>();
  const workDays = new Set<string>(); // id|day
  const startsAt = new Set<string>(); // id|day|shop
  const shiftEnds: { id: string; day: number; t: number; shop: string; overtime: boolean }[] = [];
  const visits = new Map<string, { t: number; day: number; shop: string }[]>();
  const reviews: { id: string; day: number; shop: string; stars: number | null }[] = [];
  const invOpen: { id: string; day: number; shop: string }[] = [];
  const invPass: { id: string; day: number; shop: string }[] = [];
  const anon: { id: string; day: number; shop: string; tag: string }[] = [];
  const availability = new Map<string, { t: number; slots: Set<string>; max: number | null }[]>();
  const accepts: { id: string; day: number; t: number; shop: string }[] = [];
  const cardOpens: { id: string; t: number; shop: string }[] = [];
  const reminders: { id: string; day: number; shop: string; slot: string | null; reaction: string }[] = [];
  const tiredDays = new Map<string, number[]>();
  const landmarks = new Map<string, { n: number; who: Set<string> }>();
  const shopLandmarks = new Map<string, Map<string, Set<string>>>(); // shop -> tag -> workers
  const dayType = new Map<string, string>(); // id|day -> day_type
  const chatDays = new Set<string>(); // id|day
  const practiced = new Set<string>();
  const catStops = { n: 0, who: new Set<string>() };
  const shopTouches = new Map<string, Map<string, number>>(); // id -> shop -> n (for the worker's area)
  const touch = (id: string, shop: string) => {
    if (!shopTouches.has(id)) shopTouches.set(id, new Map());
    const m = shopTouches.get(id)!;
    m.set(shop, (m.get(shop) ?? 0) + 1);
  };

  for (const e of events) {
    const id = e.install_id;
    const d = dayOf(e.t);
    if (d > nowDay) continue;
    const p = e.props;
    const shop = typeof p.shop_id === "string" ? p.shop_id : null;
    switch (e.type) {
      case "app_open": {
        let s = activeDays.get(id);
        if (!s) activeDays.set(id, (s = new Set()));
        s.add(d);
        if (typeof p.day_type === "string") dayType.set(`${id}|${d}`, p.day_type);
        break;
      }
      case "shift_start":
        workDays.add(`${id}|${d}`);
        if (shop) startsAt.add(`${id}|${d}|${shop}`);
        break;
      case "shift_end":
        if (shop) {
          shiftEnds.push({ id, day: d, t: e.t, shop, overtime: HOURS_OVERTIME.includes(String(p.hours_bucket ?? "")) });
          touch(id, shop);
        }
        if (HOURS_OVERTIME.includes(String(p.hours_bucket ?? ""))) (tiredDays.get(id) ?? tiredDays.set(id, []).get(id)!).push(d);
        break;
      case "cat_tired_stop":
        catStops.n++;
        catStops.who.add(id);
        (tiredDays.get(id) ?? tiredDays.set(id, []).get(id)!).push(d);
        break;
      case "shop_island_visit":
        if (shop) {
          (visits.get(id) ?? visits.set(id, []).get(id)!).push({ t: e.t, day: d, shop });
          touch(id, shop);
        }
        break;
      case "review_submitted":
        if (shop) reviews.push({ id, day: d, shop, stars: typeof p.stars === "number" ? p.stars : null });
        break;
      case "job_card_open":
        if (shop && p.invited === true) invOpen.push({ id, day: d, shop });
        if (shop && p.invited !== true) cardOpens.push({ id, t: e.t, shop });
        break;
      case "job_pass":
        if (shop && p.invited === true) invPass.push({ id, day: d, shop });
        break;
      case "job_accept":
        if (shop) {
          accepts.push({ id, day: d, t: e.t, shop });
          touch(id, shop);
        }
        break;
      case "anon_issue_sent":
        if (shop && typeof p.tag === "string") anon.push({ id, day: d, shop, tag: p.tag });
        break;
      case "availability_set":
        if (Array.isArray(p.slots)) {
          (availability.get(id) ?? availability.set(id, []).get(id)!).push({ t: e.t, slots: new Set(p.slots), max: typeof p.max_per_week === "number" ? p.max_per_week : null });
        }
        break;
      case "reminder_reaction":
        if (shop && p.when === "night_before" && typeof p.reaction === "string") reminders.push({ id, day: d, shop, slot: typeof p.slot === "string" ? p.slot : null, reaction: p.reaction });
        break;
      case "landmark_tap":
        if (typeof p.tag === "string") {
          let l = landmarks.get(p.tag);
          if (!l) landmarks.set(p.tag, (l = { n: 0, who: new Set() }));
          l.n++;
          l.who.add(id);
          if (shop) {
            const m = shopLandmarks.get(shop) ?? shopLandmarks.set(shop, new Map()).get(shop)!;
            (m.get(p.tag) ?? m.set(p.tag, new Set()).get(p.tag)!).add(id);
          }
        }
        break;
      case "chat_open":
        chatDays.add(`${id}|${d}`);
        break;
      case "practice_done":
        practiced.add(id);
        break;
    }
  }
  for (const list of availability.values()) list.sort((a, b) => a.t - b.t);
  const availabilityAt = (id: string, day: number) => {
    const list = availability.get(id);
    if (!list) return null;
    let found: (typeof list)[number] | null = null;
    for (const a of list) if (dayOf(a.t) <= day) found = a;
    return found;
  };
  const opened = (id: string, day: number) => activeDays.get(id)?.has(day) ?? false;

  // Each worker's own habit: share of their non-work days (after the first) with an open.
  const baselineCache = new Map<string, number | null>();
  const baselineOf = (id: string): number | null => {
    if (baselineCache.has(id)) return baselineCache.get(id)!;
    const days = activeDays.get(id);
    let v: number | null = null;
    if (days?.size) {
      const lo = Math.min(...days) + 1;
      const hi = Math.min(nowDay, Math.max(...days));
      let n = 0;
      let hit = 0;
      for (let x = lo; x <= hi; x++) {
        if (workDays.has(`${id}|${x}`)) continue;
        n++;
        if (days.has(x)) hit++;
      }
      v = n ? hit / n : null;
    }
    baselineCache.set(id, v);
    return v;
  };
  const revisited = (id: string, shop: string, t: number, day: number) =>
    (visits.get(id) ?? []).some((v) => v.shop === shop && v.t > t && v.day <= day + 3);

  // ---- Stages -------------------------------------------------------------------------
  const visitors = new Set(visits.keys()).size;
  let nextN = 0, nextHit = 0, revN = 0, revHit = 0;
  const nextWho = new Set<string>();
  for (const s of shiftEnds) {
    if (s.day + 1 <= nowDay && !workDays.has(`${s.id}|${s.day + 1}`)) {
      nextN++;
      nextWho.add(s.id);
      if (opened(s.id, s.day + 1)) nextHit++;
    }
    if (s.day + 3 <= nowDay) {
      revN++;
      if (revisited(s.id, s.shop, s.t, s.day)) revHit++;
    }
  }
  const shiftWorkers = new Set(shiftEnds.map((s) => s.id)).size;
  let workDayN = 0, workDayChat = 0;
  const workDayWho = new Set<string>();
  for (const k of workDays) {
    workDayN++;
    workDayWho.add(k.slice(0, k.indexOf("|")));
    if (chatDays.has(k)) workDayChat++;
  }
  const anonWho = new Set(anon.map((a) => a.id)).size;
  const stages: InsightsRecruit["stages"] = {
    before: { off_day_open_share: offDayOpenShare, island_visitors: gate(visitors, visitors), practice_workers: gate(practiced.size, practiced.size) },
    during: {
      shifts: gate(shiftEnds.length, shiftWorkers),
      cat_stops_per_100: rate(catStops.n * 100, shiftEnds.length, shiftWorkers),
      shift_day_chat_share: rate(workDayChat, workDayN, workDayWho.size),
    },
    after: {
      next_day_return: rate(nextHit, nextN, nextWho.size),
      island_revisit_3d: rate(revHit, revN, shiftWorkers),
      invite_accept_rate: inviteAcceptRate,
      anon_issue_workers: gate(anonWho, anonWho),
    },
  };

  // ---- a. At-risk shops (last 6 weeks of signals) ---------------------------------------
  const since = Math.max(startDay, nowDay - 41);
  const recentEnds = shiftEnds.filter((s) => s.day >= since);
  const shopsSeen = new Set(recentEnds.map((s) => s.shop));
  const riskRows: InsightsRiskRow[] = [];
  let hiddenRisk = 0;
  for (const shop of shopsSeen) {
    const list = recentEnds.filter((s) => s.shop === shop);
    const workers = new Set(list.map((s) => s.id));
    if (workers.size < K_MIN) { hiddenRisk++; continue; }
    let n = 0, hit = 0, baseSum = 0, baseN = 0;
    for (const s of list) {
      if (s.day + 1 > nowDay || workDays.has(`${s.id}|${s.day + 1}`)) continue;
      n++;
      if (opened(s.id, s.day + 1)) hit++;
      const b = baselineOf(s.id);
      if (b != null) { baseSum += b; baseN++; }
    }
    const returnDelta = n && baseN ? hit / n - baseSum / baseN : null;
    const openers = new Set(invOpen.filter((x) => x.shop === shop && x.day >= since).map((x) => x.id));
    const passes = new Map<string, number>();
    for (const x of invPass) if (x.shop === shop && x.day >= since) passes.set(x.id, (passes.get(x.id) ?? 0) + 1);
    const repeatPass = rate([...openers].filter((id) => (passes.get(id) ?? 0) >= 2).length, openers.size, openers.size);
    // Issue tags follow the shop-view rule: whole window, a tag counts only with 5+ distinct workers.
    const byTag = new Map<string, Set<string>>();
    for (const a of anon) if (a.shop === shop) (byTag.get(a.tag) ?? byTag.set(a.tag, new Set()).get(a.tag)!).add(a.id);
    const tagRows = [...byTag.entries()].filter(([, who]) => who.size >= K_MIN).map(([key, who]) => ({ key, workers: who.size })).sort((a, b) => b.workers - a.workers);
    const issueWho = new Set([...byTag.entries()].filter(([, who]) => who.size >= K_MIN).flatMap(([, who]) => [...who]));
    const starsIn = (lo: number, hi: number) => {
      const rs = reviews.filter((r) => r.shop === shop && r.day >= lo && r.day <= hi && r.stars != null);
      const who = new Set(rs.map((r) => r.id)).size;
      return who >= K_MIN ? rs.reduce((s, r) => s + r.stars!, 0) / rs.length : null;
    };
    const recent = starsIn(nowDay - 27, nowDay);
    const before = starsIn(nowDay - 55, nowDay - 28);
    const starsChange = recent != null && before != null ? recent - before : null;
    const r = riskScore({ workers: workers.size, return_delta: returnDelta, repeat_pass: repeatPass, issue_workers: issueWho.size, stars_change: starsChange });
    riskRows.push({
      shop,
      area: insightsAreaOf(shop),
      workers: workers.size,
      score: r.score,
      components: r.components,
      raw: {
        return_delta: returnDelta == null ? null : round(returnDelta),
        repeat_pass: repeatPass == null ? null : round(repeatPass),
        issue_workers: issueWho.size,
        stars_change: starsChange == null ? null : round(starsChange, 2),
      },
      reasons: r.reasons,
      issue_tags: tagRows,
    });
  }
  riskRows.sort((a, b) => b.score - a.score || a.shop.localeCompare(b.shop));

  // ---- Supply (who is available & willing right now) ------------------------------------
  const areaOfWorker = (id: string) => {
    const m = shopTouches.get(id);
    if (!m?.size) return null;
    return insightsAreaOf([...m.entries()].sort((a, b) => b[1] - a[1])[0]![0]);
  };
  const acceptsBy = new Map<string, number[]>();
  for (const a of accepts) (acceptsBy.get(a.id) ?? acceptsBy.set(a.id, []).get(a.id)!).push(a.day);
  const supplyWorkers: SupplyWorker[] = [];
  for (const [id, days] of activeDays) {
    if (![...days].some((x) => x >= nowDay - 13)) continue;
    const av = availabilityAt(id, nowDay);
    if (!av) continue;
    const tired = (tiredDays.get(id) ?? []).some((x) => x >= nowDay - 2);
    const booked = (acceptsBy.get(id) ?? []).filter((x) => x >= nowDay - 6).length;
    const atCap = av.max != null && av.max > 0 && booked >= av.max;
    supplyWorkers.push({ slots: av.slots, area: areaOfWorker(id), excluded: tired || atCap });
  }
  const hasPostings = postings.length > 0;
  const recentPostWeeks = Math.min(4, nWeeks);
  const openPerWeek = hasPostings ? new Map<string, number>() : null;
  const openByArea = new Map<string, number>();
  const openBySlotArea = new Map<string, number>(); // area|slot
  if (openPerWeek) {
    for (const p of postings) {
      if (p.day < nowDay - recentPostWeeks * 7 + 1 || p.day > nowDay) continue;
      const open = Math.max(0, p.openings - p.filled);
      openPerWeek.set(p.slot, (openPerWeek.get(p.slot) ?? 0) + open / recentPostWeeks);
      const ak = `${insightsAreaOf(p.shop)}|${p.slot}`;
      openBySlotArea.set(ak, (openBySlotArea.get(ak) ?? 0) + open / recentPostWeeks);
      if (p.slot === FOCUS_SLOT) openByArea.set(insightsAreaOf(p.shop), (openByArea.get(insightsAreaOf(p.shop)) ?? 0) + open / recentPostWeeks);
    }
  }
  const excluded = supplyWorkers.filter((w) => w.excluded).length;
  const supply: InsightsRecruit["supply"] = {
    has_availability: supplyWorkers.length > 0,
    has_postings: hasPostings,
    focus_slot: FOCUS_SLOT,
    cells: supplyGrid(supplyWorkers, openPerWeek),
    grid: INSIGHTS_AREAS.flatMap((area) => {
      const inArea = supplyWorkers.filter((w) => !w.excluded && w.area === area);
      return SLOTS.map((slot) => {
        const n = inArea.filter((w) => w.slots.has(slot)).length;
        return { area, slot, available: gate(n, n), open_shifts: hasPostings ? round(openBySlotArea.get(`${area}|${slot}`) ?? 0, 1) : null };
      });
    }),
    areas: INSIGHTS_AREAS.map((area) => {
      const n = supplyWorkers.filter((w) => !w.excluded && w.area === area && w.slots.has(FOCUS_SLOT)).length;
      return { area, available: gate(n, n), open_shifts: hasPostings ? round(openByArea.get(area) ?? 0, 1) : null };
    }),
  };

  // ---- b. Fill and no-show --------------------------------------------------------------
  // Night-before reaction -> did the shift start the next day at that shop?
  const reactionStats = new Map<string, { n: number; miss: number; who: Set<string> }>();
  for (const r of reminders) {
    if (r.day + 1 > nowDay) continue;
    let s = reactionStats.get(r.reaction);
    if (!s) reactionStats.set(r.reaction, (s = { n: 0, miss: 0, who: new Set() }));
    s.n++;
    s.who.add(r.id);
    if (!startsAt.has(`${r.id}|${r.day + 1}|${r.shop}`)) s.miss++;
  }
  const reactionRates: Record<string, number | null> = {};
  const reminderRows = ["ok", "swap", "dismissed"].map((reaction) => {
    const s = reactionStats.get(reaction);
    const v = s ? rate(s.miss, s.n, s.who.size) : null;
    reactionRates[reaction] = v;
    return { reaction, shifts: s ? gate(s.n, s.who.size) : null, no_show_rate: v };
  });

  const weekOf = (day: number) => Math.floor((day - startDay) / 7);
  const weeklySupply = new Map<string, number[]>(); // band -> per week count
  for (const band of BANDS) weeklySupply.set(band, Array.from({ length: nWeeks }, () => 0));
  for (const [id, days] of activeDays) {
    for (let w = 0; w < nWeeks; w++) {
      const lo = startDay + w * 7;
      if (![...days].some((x) => x >= lo && x < lo + 7)) continue;
      const av = availabilityAt(id, Math.min(nowDay, lo + 6));
      if (!av) continue;
      const bands = new Set([...av.slots].map(bandOf));
      for (const b of bands) {
        const arr = weeklySupply.get(b);
        if (arr) arr[w]!++;
      }
    }
  }
  const meanWeeks = (band: string, lo: number, hi: number) => {
    const arr = (weeklySupply.get(band) ?? []).slice(Math.max(0, lo), Math.max(0, hi + 1));
    return arr.length ? arr.reduce((s, x) => s + x, 0) / arr.length : 0;
  };
  const listings = new Map<string, InsightsPosting[]>();
  for (const p of postings) {
    if (p.day > nowDay) continue;
    const k = `${p.shop}|${bandOf(p.slot)}`;
    (listings.get(k) ?? listings.set(k, []).get(k)!).push(p);
  }
  const sum = (ps: InsightsPosting[], k: "openings" | "filled" | "no_shows") => ps.reduce((s, p) => s + p[k], 0);
  const holdout = nWeeks >= HOLDOUT_WEEKS * 2 ? HOLDOUT_WEEKS : 0;
  const trainEnd = nWeeks - holdout - 1; // last training week index
  const marketFill = (band: string, maxWeek: number) => {
    const ps = postings.filter((p) => bandOf(p.slot) === band && weekOf(p.day) <= maxWeek);
    const o = sum(ps, "openings");
    return o ? sum(ps, "filled") / o : 0.7;
  };
  const allFilled = sum(postings, "filled");
  const marketNoShow = allFilled ? sum(postings, "no_shows") / allFilled : 0;
  const fillRows: InsightsFillRow[] = [];
  const errors: number[] = [];
  for (const [k, ps] of listings) {
    const [shop, band] = k.split("|") as [string, string];
    const all = { openings: sum(ps, "openings"), filled: sum(ps, "filled") };
    const recentWeeks = Math.min(2, nWeeks);
    const predicted = forecastFill(all, marketFill(band, nWeeks - 1), meanWeeks(band, 0, nWeeks - 1), meanWeeks(band, nWeeks - recentWeeks, nWeeks - 1));
    let btPred: number | null = null;
    let btActual: number | null = null;
    if (holdout) {
      const train = ps.filter((p) => weekOf(p.day) <= trainEnd);
      const test = ps.filter((p) => weekOf(p.day) > trainEnd);
      const testO = sum(test, "openings");
      if (testO >= 5) {
        btPred = forecastFill({ openings: sum(train, "openings"), filled: sum(train, "filled") }, marketFill(band, trainEnd), meanWeeks(band, 0, trainEnd), meanWeeks(band, trainEnd + 1, nWeeks - 1));
        btActual = sum(test, "filled") / testO;
        errors.push(Math.abs(btPred - btActual));
      }
    }
    // No-show risk: the listing's own history (smoothed), blended with what recent reminder reactions imply.
    const hist = (sum(ps, "no_shows") + FILL_PRIOR * marketNoShow) / (all.filled + FILL_PRIOR);
    const recentRem = reminders.filter((r) => r.shop === shop && r.slot != null && bandOf(r.slot) === band && r.day >= nowDay - 27);
    const mix: Record<string, number> = {};
    for (const r of recentRem) mix[r.reaction] = (mix[r.reaction] ?? 0) + 1;
    const fromReactions = new Set(recentRem.map((r) => r.id)).size >= K_MIN ? reactionNoShow(mix, reactionRates) : null;
    fillRows.push({
      shop,
      band,
      openings_per_week: round(all.openings / nWeeks, 1),
      predicted_fill: round(predicted),
      backtest_predicted: btPred == null ? null : round(btPred),
      backtest_actual: btActual == null ? null : round(btActual),
      no_show_risk: round(fromReactions == null ? hist : 0.5 * hist + 0.5 * fromReactions),
      history: Array.from({ length: nWeeks }, (_, w) => {
        const wk = ps.filter((p) => weekOf(p.day) === w);
        const o = sum(wk, "openings");
        return o ? round(sum(wk, "filled") / o) : null;
      }),
      fill_rate: all.openings ? round(all.filled / all.openings) : null,
      no_show_rate: all.filled ? round(sum(ps, "no_shows") / all.filled) : null,
    });
  }
  fillRows.sort((a, b) => a.predicted_fill - b.predicted_fill || a.shop.localeCompare(b.shop));
  const fill: InsightsRecruit["fill"] = {
    has_postings: hasPostings,
    rows: fillRows,
    backtest: { mae: errors.length ? round(errors.reduce((s, x) => s + x, 0) / errors.length) : null, listings: errors.length, holdout_weeks: holdout },
    reminders: reminderRows,
    willing_excluded_share: rate(excluded, supplyWorkers.length, supplyWorkers.length),
  };

  // ---- d. Interest before applying ------------------------------------------------------
  const WINDOW = 14 * 86400;
  const workedBefore = (id: string, shop: string, t: number) => shiftEnds.some((s) => s.id === id && s.shop === shop && s.t < t);
  const appliedWithin = (id: string, shop: string, t: number) => accepts.some((a) => a.id === id && a.shop === shop && a.t > t && a.t <= t + WINDOW);
  const perShop = new Map<string, { visitors: Set<string>; applied: Set<string> }>();
  const visitedShop = new Set<string>(); // id|shop
  for (const [id, list] of visits) {
    const firstByShop = new Map<string, number>();
    for (const v of list) if (!firstByShop.has(v.shop)) firstByShop.set(v.shop, v.t);
    for (const [shop, t] of firstByShop) {
      visitedShop.add(`${id}|${shop}`);
      if (workedBefore(id, shop, t)) continue;
      let s = perShop.get(shop);
      if (!s) perShop.set(shop, (s = { visitors: new Set(), applied: new Set() }));
      s.visitors.add(id);
      if (appliedWithin(id, shop, t)) s.applied.add(id);
    }
  }
  // Baseline: people who opened the shop's card without ever visiting its island.
  const nvPairs = new Map<string, boolean>(); // id|shop -> applied within 14 days of the first open
  for (const c of cardOpens) {
    const k = `${c.id}|${c.shop}`;
    if (visitedShop.has(k) || nvPairs.has(k) || workedBefore(c.id, c.shop, c.t)) continue;
    nvPairs.set(k, appliedWithin(c.id, c.shop, c.t - 1));
  }
  const vPairs = [...perShop.values()].reduce((s, x) => s + x.visitors.size, 0);
  const vApplied = [...perShop.values()].reduce((s, x) => s + x.applied.size, 0);
  const vWho = new Set([...perShop.values()].flatMap((x) => [...x.visitors])).size;
  const nvWho = new Set([...nvPairs.keys()].map((k) => k.slice(0, k.indexOf("|")))).size;
  const interest: InsightsRecruit["interest"] = {
    visitors: gate(vWho, vWho),
    visitor_apply_rate: rate(vApplied, vPairs, vWho),
    non_visitor_apply_rate: rate([...nvPairs.values()].filter(Boolean).length, nvPairs.size, nvWho),
    rows: [...perShop.entries()]
      .filter(([, s]) => s.visitors.size >= K_MIN)
      .map(([shop, s]) => {
        const top = [...(shopLandmarks.get(shop) ?? new Map<string, Set<string>>()).entries()].filter(([, who]) => who.size >= K_MIN).sort((a, b) => b[1].size - a[1].size)[0];
        return { shop, visitors: s.visitors.size, applied: s.applied.size, apply_rate: round(s.applied.size / s.visitors.size), top_landmark: top ? top[0] : null };
      })
      .sort((a, b) => b.visitors - a.visitors),
    landmarks: [...landmarks.entries()]
      .filter(([, l]) => l.who.size >= K_MIN)
      .map(([key, l]) => ({ key, taps: l.n, workers: l.who.size }))
      .sort((a, b) => b.taps - a.taps),
  };

  // ---- e. Fit: after-shift behaviour vs coming back to the same shop ----------------------
  const firstShift = new Map<string, (typeof shiftEnds)[number]>();
  for (const s of shiftEnds) {
    const k = `${s.id}|${s.shop}`;
    if (!firstShift.has(k)) firstShift.set(k, s);
  }
  type Pair = { id: string; shop: string; signals: number; nextDay: boolean; revisit: boolean; stars: number | null; repeat: boolean };
  const pairs: Pair[] = [];
  for (const s of firstShift.values()) {
    if (s.day > nowDay - 14 || workDays.has(`${s.id}|${s.day + 1}`)) continue;
    const nextDay = opened(s.id, s.day + 1);
    const revisit = revisited(s.id, s.shop, s.t, s.day);
    const review = reviews.find((r) => r.id === s.id && r.shop === s.shop && r.day === s.day) ?? null;
    const repeat = shiftEnds.some((x) => x.id === s.id && x.shop === s.shop && x.t > s.t);
    pairs.push({ id: s.id, shop: s.shop, signals: Number(nextDay) + Number(revisit) + Number(!!review), nextDay, revisit, stars: review?.stars ?? null, repeat });
  }
  const repeatOf = (ps: Pair[]) => ({ pairs: gate(ps.length, new Set(ps.map((p) => p.id)).size), repeat_rate: rate(ps.filter((p) => p.repeat).length, ps.length, new Set(ps.map((p) => p.id)).size) });
  const fit: InsightsRecruit["fit"] = {
    bins: [0, 1, 2, 3].map((k) => ({ signals: k, ...repeatOf(pairs.filter((p) => p.signals === k)) })),
    base_repeat_rate: repeatOf(pairs).repeat_rate,
    self_report: repeatOf(pairs.filter((p) => (p.stars ?? 0) >= 4)),
    behavior: repeatOf(pairs.filter((p) => p.nextDay && p.revisit)),
    shops: [...new Set(pairs.map((p) => p.shop))]
      .map((shop) => {
        const ps = pairs.filter((p) => p.shop === shop);
        const strong = ps.filter((p) => p.signals >= 2);
        const n = new Set(ps.map((p) => p.id)).size;
        return {
          shop,
          pairs: n >= K_MIN ? ps.length : 0,
          repeat_rate: rate(ps.filter((p) => p.repeat).length, ps.length, n),
          strong_signal_share: rate(strong.length, ps.length, n),
          strong_repeat_rate: rate(strong.filter((p) => p.repeat).length, strong.length, new Set(strong.map((p) => p.id)).size),
        };
      })
      .filter((x) => x.pairs > 0)
      .sort((a, b) => a.shop.localeCompare(b.shop)),
  };

  // ---- Weekly signals per shop (the Signals table) and KPI deltas ------------------------
  const weekIdx = (day: number) => Math.floor((day - startDay) / 7);
  const signals: InsightsRecruit["signals"] = [];
  const allShops = new Set([...shiftEnds.map((s) => s.shop), ...postings.map((p) => p.shop)]);
  for (const shop of [...allShops].sort()) {
    for (let w = 0; w < nWeeks; w++) {
      const ends = shiftEnds.filter((s) => s.shop === shop && weekIdx(s.day) === w);
      const who = new Set(ends.map((s) => s.id));
      let n = 0, hit = 0, bSum = 0, bN = 0;
      for (const s of ends) {
        if (s.day + 1 > nowDay || workDays.has(`${s.id}|${s.day + 1}`)) continue;
        n++;
        if (opened(s.id, s.day + 1)) hit++;
        const b = baselineOf(s.id);
        if (b != null) { bSum += b; bN++; }
      }
      const openers = new Set(invOpen.filter((x) => x.shop === shop && weekIdx(x.day) === w).map((x) => x.id));
      const passers = new Set(invPass.filter((x) => x.shop === shop && weekIdx(x.day) === w).map((x) => x.id));
      const passShare = [...openers].filter((id) => passers.has(id)).length;
      const issueWho = new Set(anon.filter((a) => a.shop === shop && weekIdx(a.day) === w).map((a) => a.id));
      const revs = reviews.filter((r) => r.shop === shop && weekIdx(r.day) === w && r.stars != null);
      const revWho = new Set(revs.map((r) => r.id)).size;
      const visWho = new Set<string>();
      for (const [id, list] of visits) if (list.some((v) => v.shop === shop && weekIdx(v.day) === w)) visWho.add(id);
      const ps = postings.filter((p) => p.shop === shop && weekIdx(p.day) === w && p.day <= nowDay);
      signals.push({
        shop,
        week: weekLabels[w] ?? `W${w + 1}`,
        workers: gate(who.size, who.size),
        next_day_return: n && who.size >= K_MIN ? round(hit / n) : null,
        baseline: bN && who.size >= K_MIN ? round(bSum / bN) : null,
        invite_pass_share: openers.size >= K_MIN ? round(passShare / openers.size) : null,
        issue_workers: gate(issueWho.size, issueWho.size),
        stars_avg: revWho >= K_MIN ? round(revs.reduce((s, r) => s + r.stars!, 0) / revs.length, 2) : null,
        island_visitors: gate(visWho.size, visWho.size),
        openings: hasPostings ? sum(ps, "openings") : null,
        filled: hasPostings ? sum(ps, "filled") : null,
        no_shows: hasPostings ? sum(ps, "no_shows") : null,
      });
    }
  }
  const period = (back: number) => ({ lo: nowDay - 28 * (back + 1) + 1, hi: nowDay - 28 * back });
  const kpiFor = (back: number) => {
    const { lo, hi } = period(back);
    if (hi < startDay) return { dau_mau: null, off_day_share: null, fill_rate: null, next_day_return: null, active_shops: null };
    const from = Math.max(lo, startDay);
    const actives = new Set<string>();
    let installDays = 0, offDays = 0;
    for (const [id, days] of activeDays) {
      for (const d of days) {
        if (d < from || d > hi) continue;
        actives.add(id);
        installDays++;
        const dt = dayType.get(`${id}|${d}`);
        if (dt === "off" || dt === "no_shift") offDays++;
      }
    }
    const span = hi - from + 1;
    const ps = postings.filter((p) => p.day >= from && p.day <= hi);
    const o = sum(ps, "openings");
    let nn = 0, nh = 0;
    const nWho = new Set<string>();
    for (const s of shiftEnds) {
      if (s.day < from || s.day > hi || s.day + 1 > nowDay || workDays.has(`${s.id}|${s.day + 1}`)) continue;
      nn++;
      nWho.add(s.id);
      if (opened(s.id, s.day + 1)) nh++;
    }
    const perShop = new Map<string, Set<string>>();
    for (const s of shiftEnds) if (s.day >= from && s.day <= hi) (perShop.get(s.shop) ?? perShop.set(s.shop, new Set()).get(s.shop)!).add(s.id);
    return {
      dau_mau: rate(installDays / span, actives.size, actives.size),
      off_day_share: rate(offDays, installDays, actives.size),
      fill_rate: o ? round(sum(ps, "filled") / o) : null,
      next_day_return: rate(nh, nn, nWho.size),
      active_shops: [...perShop.values()].filter((x) => x.size >= K_MIN).length,
    };
  };
  const nowK = kpiFor(0);
  const prevK = kpiFor(1);
  const k = (key: keyof typeof nowK) => ({ now: nowK[key] == null ? null : round(nowK[key]!), prev: prevK[key] == null ? null : round(prevK[key]!) });
  const kpis: InsightsRecruit["kpis"] = { dau_mau: k("dau_mau"), off_day_share: k("off_day_share"), fill_rate: k("fill_rate"), next_day_return: k("next_day_return"), active_shops: k("active_shops") };

  return { weeks: weekLabels, kpis, signals, stages, at_risk: { rows: riskRows, hidden_shops: hiddenRisk }, fill, supply, interest, fit };
}

/** Issue tags a shop could ever see. Exported for tests. */
export const RISK_ISSUE_TAGS: readonly string[] = ISSUE_TOPICS;
