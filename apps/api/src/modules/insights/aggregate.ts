// Turns raw events into the aggregate-only numbers the dashboard shows.
// The same code runs for live data and for the synthetic pilot, so both modes
// are computed identically. Every cell backed by fewer than K_MIN distinct
// installs is replaced by null ("suppressed").
import {
  INSIGHTS_K_MIN,
  TELEMETRY_HOURS_LE_7_5 as HOURS_LE_7_5,
  TELEMETRY_HOURS_OVERTIME as HOURS_OVERTIME,
  type InsightsAggregate,
  type TelemetryEvent,
} from "@paw-time/api-contracts";

export type FlatEvent = TelemetryEvent & { install_id: string };

export const K_MIN = INSIGHTS_K_MIN;
const DAY = 86400;
const JST = 9 * 3600;

export const dayOf = (t: number) => Math.floor((t + JST) / DAY);
const dayToIso = (d: number) => new Date(d * DAY * 1000).toISOString().slice(0, 10);

type Cell = number | null;

function gate(value: number, installs: number): Cell {
  return installs >= K_MIN ? value : null;
}
function rate(num: number, den: number, installs: number): Cell {
  return den > 0 && installs >= K_MIN ? num / den : null;
}

class Counter {
  n = 0;
  who = new Set<string>();
  add(id: string, by = 1) {
    this.n += by;
    this.who.add(id);
  }
  cell(): Cell {
    return gate(this.n, this.who.size);
  }
}

class Keyed {
  map = new Map<string, Counter>();
  add(key: string, id: string, by = 1) {
    let c = this.map.get(key);
    if (!c) this.map.set(key, (c = new Counter()));
    c.add(id, by);
  }
  rows() {
    return [...this.map.entries()]
      .map(([key, c]) => ({ key, value: c.cell(), installs: c.who.size >= K_MIN ? c.who.size : null }))
      .sort((a, b) => (b.value ?? -1) - (a.value ?? -1));
  }
}

export interface AggregateOptions {
  now: number; // unix seconds; "today" for the window
  weekLabel: "date" | "index"; // live uses ISO dates, simulated uses W1..W12
  startDay?: number; // first day of week 1 (defaults to first event day)
}

export function aggregate(events: FlatEvent[], opts: AggregateOptions): InsightsAggregate {
  const nowDay = dayOf(opts.now);
  const firstDay = new Map<string, number>();
  const activeDays = new Map<string, Set<number>>(); // install -> days
  // install|day -> day_type reported by app_open (last one wins)
  const dayType = new Map<string, string>();
  const openedJobsOn = new Set<string>(); // install|day with job_card_open
  let minDay = Infinity;

  for (const e of events) {
    const d = dayOf(e.t);
    if (d > nowDay) continue;
    minDay = Math.min(minDay, d);
    if (!firstDay.has(e.install_id) || firstDay.get(e.install_id)! > d) firstDay.set(e.install_id, d);
    if (e.type === "app_open") {
      let s = activeDays.get(e.install_id);
      if (!s) activeDays.set(e.install_id, (s = new Set()));
      s.add(d);
      if (typeof e.props.day_type === "string") dayType.set(`${e.install_id}|${d}`, e.props.day_type);
    }
    if (e.type === "job_card_open") openedJobsOn.add(`${e.install_id}|${d}`);
  }
  const startDay = opts.startDay ?? (Number.isFinite(minDay) ? minDay : nowDay);
  const weekOf = (d: number) => Math.floor((d - startDay) / 7);
  const nWeeks = Math.max(1, weekOf(nowDay) + 1);
  const weekName = (w: number) => (opts.weekLabel === "index" ? `W${w + 1}` : dayToIso(startDay + w * 7));

  // ---- Activity -------------------------------------------------------------
  const activeOn = (lo: number, hi: number) => {
    const who = new Set<string>();
    for (const [id, days] of activeDays) for (const d of days) if (d >= lo && d <= hi) { who.add(id); break; }
    return who.size;
  };
  const dailySeries: { day: string; dau: Cell }[] = [];
  const dauByDay = new Map<number, number>();
  for (const days of activeDays.values()) for (const d of days) dauByDay.set(d, (dauByDay.get(d) ?? 0) + 1);
  for (let d = Math.max(startDay, nowDay - 83); d <= nowDay; d++) {
    const v = dauByDay.get(d) ?? 0;
    dailySeries.push({ day: opts.weekLabel === "index" ? `D${d - startDay + 1}` : dayToIso(d), dau: gate(v, v) });
  }
  let dauSum = 0;
  for (let d = nowDay - 6; d <= nowDay; d++) dauSum += dauByDay.get(d) ?? 0;
  const dau = dauSum / 7;
  const wau = activeOn(nowDay - 6, nowDay);
  const mau = activeOn(nowDay - 29, nowDay);

  // Active install-days and the key "no job search" share.
  let installDays = 0;
  let offDays = 0;
  let offDaysNoCardOpen = 0;
  const offWho = new Set<string>();
  const weeklyMix = Array.from({ length: nWeeks }, () => ({ work: 0, off: 0, no_shift: 0, unknown: 0, who: new Set<string>() }));
  for (const [id, days] of activeDays) {
    for (const d of days) {
      installDays++;
      const dt = dayType.get(`${id}|${d}`) ?? "unknown";
      const w = weekOf(d);
      if (w >= 0 && w < nWeeks) {
        const mix = weeklyMix[w]!;
        mix[dt as "work" | "off" | "no_shift" | "unknown"]++;
        mix.who.add(id);
      }
      if (dt === "off" || dt === "no_shift") {
        offDays++;
        offWho.add(id);
        if (!openedJobsOn.has(`${id}|${d}`)) offDaysNoCardOpen++;
      }
    }
  }
  const allInstalls = activeDays.size;

  // ---- Retention (cohort = week of first app_open) --------------------------
  const cohorts = new Map<number, { ids: string[] }>();
  for (const [id, days] of activeDays) {
    const f = Math.min(...days);
    const w = weekOf(f);
    if (!cohorts.has(w)) cohorts.set(w, { ids: [] });
    cohorts.get(w)!.ids.push(id);
  }
  const retention = [...cohorts.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([w, c]) => {
      const col = (n: number): Cell => {
        let eligible = 0;
        let back = 0;
        for (const id of c.ids) {
          const days = activeDays.get(id)!;
          const f = Math.min(...days);
          if (f + n > nowDay) continue;
          eligible++;
          if (days.has(f + n)) back++;
        }
        return rate(back, eligible, eligible);
      };
      return { cohort: weekName(w), size: gate(c.ids.length, c.ids.length), d1: col(1), d7: col(7), d30: col(30) };
    });

  // ---- Per-event counters ----------------------------------------------------
  const shown = new Counter();
  const opened = new Counter();
  const accepted = new Counter();
  const passed = new Counter();
  const started = new Counter();
  const ended = new Counter();
  const reviewed = new Counter();
  const invOpened = new Counter();
  const invAccepted = new Counter();
  const invPassed = new Counter();
  const norOpened = new Counter();
  const norAccepted = new Counter();
  const norPassed = new Counter();
  const catStops = new Counter();
  const shiftsLe75 = new Counter();
  const shiftsOver = new Counter();
  const stars = new Counter();
  const tags = new Keyed();
  const practice = new Keyed();
  const acceptByRole = new Keyed();
  const shopVisits = new Keyed();
  const offDayActs = new Keyed();
  const badgeLatest = new Map<string, { t: number; on: boolean }>();
  // After-the-shift signals (per shop).
  const shiftEnds: { id: string; day: number; t: number; shop: string }[] = [];
  const workDays = new Set<string>(); // install|day with shift_start
  const islandVisits = new Map<string, { t: number; shop: string }[]>(); // install -> visits
  const invOpenBy = new Map<string, Set<string>>(); // shop -> installs that opened its invite
  const invPassBy = new Map<string, Map<string, number>>(); // shop -> install -> passes
  const reviewsAt = new Map<string, number>(); // shop -> reviews
  const practiced = new Set<string>();
  const weekly = Array.from({ length: nWeeks }, () => ({
    ended: new Counter(),
    le75: new Counter(),
    over: new Counter(),
    cat: new Counter(),
    reviewed: new Counter(),
  }));

  for (const e of events) {
    const id = e.install_id;
    const d = dayOf(e.t);
    if (d > nowDay) continue;
    const w = weekOf(d);
    const wk = w >= 0 && w < nWeeks ? weekly[w]! : null;
    const p = e.props;
    const dt = dayType.get(`${id}|${d}`);
    const offDay = dt === "off" || dt === "no_shift";
    switch (e.type) {
      case "job_cards_shown":
        shown.add(id, typeof p.n === "number" ? p.n : 1);
        break;
      case "job_card_open":
        opened.add(id);
        (p.invited === true ? invOpened : norOpened).add(id);
        if (p.invited === true && typeof p.shop_id === "string") {
          if (!invOpenBy.has(p.shop_id)) invOpenBy.set(p.shop_id, new Set());
          invOpenBy.get(p.shop_id)!.add(id);
        }
        break;
      case "job_accept":
        accepted.add(id);
        (p.invited === true ? invAccepted : norAccepted).add(id);
        if (typeof p.role === "string") acceptByRole.add(p.role, id);
        break;
      case "job_pass":
        passed.add(id);
        (p.invited === true ? invPassed : norPassed).add(id);
        if (p.invited === true && typeof p.shop_id === "string") {
          if (!invPassBy.has(p.shop_id)) invPassBy.set(p.shop_id, new Map());
          const m = invPassBy.get(p.shop_id)!;
          m.set(id, (m.get(id) ?? 0) + 1);
        }
        break;
      case "shift_start":
        started.add(id);
        workDays.add(`${id}|${d}`);
        break;
      case "shift_end": {
        ended.add(id);
        wk?.ended.add(id);
        const hb = String(p.hours_bucket ?? "");
        if (HOURS_LE_7_5.includes(hb)) { shiftsLe75.add(id); wk?.le75.add(id); }
        if (HOURS_OVERTIME.includes(hb)) { shiftsOver.add(id); wk?.over.add(id); }
        if (typeof p.shop_id === "string") shiftEnds.push({ id, day: d, t: e.t, shop: p.shop_id });
        break;
      }
      case "cat_tired_stop":
        catStops.add(id);
        wk?.cat.add(id);
        break;
      case "review_submitted":
        reviewed.add(id);
        wk?.reviewed.add(id);
        if (typeof p.stars === "number") stars.add(id, p.stars);
        if (Array.isArray(p.tags)) for (const tag of p.tags) tags.add(String(tag), id);
        if (typeof p.shop_id === "string") reviewsAt.set(p.shop_id, (reviewsAt.get(p.shop_id) ?? 0) + 1);
        break;
      case "practice_done":
        practiced.add(id);
        if (typeof p.role === "string") practice.add(p.role, id);
        break;
      case "skill_badge_share_toggled": {
        const prev = badgeLatest.get(id);
        if (!prev || prev.t <= e.t) badgeLatest.set(id, { t: e.t, on: p.on === true });
        break;
      }
      case "shop_island_visit":
        if (typeof p.shop_id === "string") {
          shopVisits.add(p.shop_id, id);
          if (!islandVisits.has(id)) islandVisits.set(id, []);
          islandVisits.get(id)!.push({ t: e.t, shop: p.shop_id });
        }
        break;
    }
    if (offDay && e.type !== "app_open") offDayActs.add(e.type, id);
  }

  const ended_n = ended.n;
  const afterShift = afterShiftSignals();

  // Per shop, for the workers who finished a shift there:
  //  - next-day open rate after that shop's shifts (next day not itself a work day)
  //    vs those same workers' own open rate on any non-work day in their tenure
  //  - island re-visit of that shop within 3 days
  //  - share of invite-receivers who passed that shop's invites 2+ times
  //  - review response per finished shift
  function afterShiftSignals() {
    const baselineCache = new Map<string, number | null>();
    const baselineOf = (id: string): number | null => {
      if (baselineCache.has(id)) return baselineCache.get(id)!;
      const days = activeDays.get(id);
      let v: number | null = null;
      if (days && days.size) {
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
    const byShop = new Map<string, typeof shiftEnds>();
    for (const s of shiftEnds) {
      if (!byShop.has(s.shop)) byShop.set(s.shop, []);
      byShop.get(s.shop)!.push(s);
    }
    const rows = [];
    let hidden = 0;
    for (const [shop, list] of byShop) {
      const workers = new Set(list.map((s) => s.id));
      if (workers.size < K_MIN) { hidden++; continue; }
      let nextN = 0, nextHit = 0, baseSum = 0, baseN = 0, visitHit = 0, visitN = 0;
      for (const s of list) {
        if (s.day + 1 <= nowDay && !workDays.has(`${s.id}|${s.day + 1}`)) {
          nextN++;
          if (activeDays.get(s.id)?.has(s.day + 1)) nextHit++;
          const b = baselineOf(s.id);
          if (b != null) { baseSum += b; baseN++; }
        }
        if (s.day + 3 <= nowDay) {
          visitN++;
          const v = islandVisits.get(s.id) ?? [];
          if (v.some((x) => x.shop === shop && x.t > s.t && dayOf(x.t) <= s.day + 3)) visitHit++;
        }
      }
      const openers = invOpenBy.get(shop) ?? new Set<string>();
      const passes = invPassBy.get(shop) ?? new Map<string, number>();
      const repeatPass = [...openers].filter((id) => (passes.get(id) ?? 0) >= 2).length;
      const nextDay = nextN ? nextHit / nextN : null;
      const baseline = baseN ? baseSum / baseN : null;
      rows.push({
        shop,
        workers: workers.size,
        shifts: list.length,
        next_day_open: nextDay,
        baseline,
        delta: nextDay != null && baseline != null ? nextDay - baseline : null,
        visit_3d: visitN ? visitHit / visitN : null,
        repeat_pass: rate(repeatPass, openers.size, openers.size),
        review_rate: list.length ? (reviewsAt.get(shop) ?? 0) / list.length : null,
      });
    }
    rows.sort((a, b) => b.shifts - a.shifts);
    return { rows, hidden_shops: hidden };
  }
  const badgeOn = [...badgeLatest.entries()].filter(([id, v]) => v.on && practiced.has(id)).length;

  return {
    installs: gate(allInstalls, allInstalls),
    window: { start: opts.weekLabel === "index" ? "D1" : dayToIso(startDay), end: opts.weekLabel === "index" ? `D${nowDay - startDay + 1}` : dayToIso(nowDay), weeks: nWeeks },
    headline: {
      dau: gate(Math.round(dau * 10) / 10, wau),
      wau: gate(wau, wau),
      mau: gate(mau, mau),
      stickiness: rate(dau, mau, mau),
      no_job_search_share: rate(offDays, installDays, allInstalls),
      off_days_without_card_open: rate(offDaysNoCardOpen, offDays, offWho.size),
      active_install_days: gate(installDays, allInstalls),
    },
    daily: dailySeries,
    weekly_day_type: weeklyMix.map((m, w) => {
      const tot = m.work + m.off + m.no_shift + m.unknown;
      const ok = m.who.size >= K_MIN && tot > 0;
      return {
        week: weekName(w),
        work: ok ? m.work / tot : null,
        off: ok ? m.off / tot : null,
        no_shift: ok ? m.no_shift / tot : null,
      };
    }),
    off_day_activities: offDayActs.rows().slice(0, 8),
    retention,
    funnel: {
      shown: shown.cell(),
      opened: opened.cell(),
      accepted: accepted.cell(),
      shift_done: ended.cell(),
      reviewed: reviewed.cell(),
      invited: {
        opened: invOpened.cell(),
        accepted: invAccepted.cell(),
        accept_rate: rate(invAccepted.n, invAccepted.n + invPassed.n, new Set([...invAccepted.who, ...invPassed.who]).size),
      },
      normal: {
        opened: norOpened.cell(),
        accepted: norAccepted.cell(),
        accept_rate: rate(norAccepted.n, norAccepted.n + norPassed.n, new Set([...norAccepted.who, ...norPassed.who]).size),
      },
      accept_by_role: acceptByRole.rows(),
    },
    wellbeing: {
      cat_stops: catStops.cell(),
      shifts: ended.cell(),
      le75_share: rate(shiftsLe75.n, ended_n, ended.who.size),
      overtime_rate: rate(shiftsOver.n, ended_n, ended.who.size),
      weekly: weekly.map((x, w) => ({
        week: weekName(w),
        shifts: x.ended.cell(),
        cat_stops: x.cat.cell(),
        le75_share: rate(x.le75.n, x.ended.n, x.ended.who.size),
        overtime_rate: rate(x.over.n, x.ended.n, x.ended.who.size),
        review_rate: rate(x.reviewed.n, x.ended.n, x.ended.who.size),
      })),
    },
    reviews: {
      response_rate: rate(reviewed.n, ended_n, ended.who.size),
      stars_avg: rate(stars.n, reviewed.n, reviewed.who.size),
      tags: tags.rows(),
    },
    skills: {
      practice_by_role: practice.rows(),
      badge_opt_in_rate: rate(badgeOn, practiced.size, practiced.size),
    },
    after_shift: afterShift,
    shops: {
      visits: shopVisits.rows(),
      invites: { opened: invOpened.cell(), accepted: invAccepted.cell() },
    },
  };
}

