// Seeded generator for the "Simulated 12-week pilot" mode. SYNTHETIC DATA.
// It emits the same event stream the game would, so the dashboard aggregates it
// with exactly the same code as live data. Internal consistency by construction:
// shifts only exist after a job_accept, reviews only after a shift_end, etc.
import {
  TELEMETRY_BACKSTAGE_ROLES as BACKSTAGE_ROLES,
  TELEMETRY_FAQ_TOPICS as FAQ_TOPICS,
  TELEMETRY_REVIEW_TAGS as REVIEW_TAGS,
  TELEMETRY_ROLES as ROLES,
  TELEMETRY_SHOP_IDS as SHOP_IDS,
  type TelemetryEventType,
  type TelemetryPropValue as PropValue,
} from "@paw-time/api-contracts";
import type { FlatEvent } from "./aggregate.js";

const DAY = 86400;
export const SIM_WEEKS = 12;
export const SIM_DAYS = SIM_WEEKS * 7;
// Day 1 of the simulated pilot (Mon 2026-07-06 00:00 JST). Shown only as D1..D84 / W1..W12.
export const SIM_START = Date.UTC(2026, 6, 5, 15, 0, 0) / 1000;
export const SIM_NOW = SIM_START + SIM_DAYS * DAY - 1;
export const SIM_SEED = 20260706;

function mulberry32(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function generateSimulated(opts: { seed?: number; installs?: number } = {}): FlatEvent[] {
  const rnd = mulberry32(opts.seed ?? SIM_SEED);
  const total = opts.installs ?? 360;
  const chance = (p: number) => rnd() < p;
  const pick = <T>(xs: readonly T[]): T => xs[Math.floor(rnd() * xs.length)]!;
  const int = (lo: number, hi: number) => lo + Math.floor(rnd() * (hi - lo + 1));
  const weighted = <T>(pairs: [T, number][]) => {
    let r = rnd() * pairs.reduce((s, [, w]) => s + w, 0);
    for (const [v, w] of pairs) if ((r -= w) <= 0) return v;
    return pairs[pairs.length - 1]![0];
  };
  const hex = (n: number) => Array.from({ length: n }, () => Math.floor(rnd() * 16).toString(16)).join("");

  const roles = ROLES;
  // 4 pilot shops. "culture" (0..1) is the hidden variable the after-shift signals
  // should surface: how people feel after working there.
  const shops = ["cafe_komorebi", "izk_torimaru", "cvs_machikado", "bk_komugi"] as const satisfies readonly (typeof SHOP_IDS)[number][];
  type Shop = (typeof shops)[number];
  const culture: Record<Shop, number> = { cafe_komorebi: 0.85, izk_torimaru: 0.35, cvs_machikado: 0.6, bk_komugi: 0.75 };
  const overtimeAt: Record<Shop, number> = { cafe_komorebi: 0.6, izk_torimaru: 1.8, cvs_machikado: 1.0, bk_komugi: 0.8 };
  const tags = REVIEW_TAGS;
  const events: FlatEvent[] = [];
  // Chat is drawn from its own stream so adding it leaves every other synthetic number unchanged.
  const crnd = mulberry32((opts.seed ?? SIM_SEED) ^ 0x5eed_c4a7);
  const cchance = (p: number) => crnd() < p;
  const cpick = <T>(xs: readonly T[]): T => xs[Math.floor(crnd() * xs.length)]!;
  const cweighted = <T>(pairs: [T, number][]) => {
    let r = crnd() * pairs.reduce((s, [, w]) => s + w, 0);
    for (const [v, w] of pairs) if ((r -= w) <= 0) return v;
    return pairs[pairs.length - 1]![0];
  };
  // What tends to go wrong at each shop: the same hidden culture, plus its own flavour.
  const issueMix: Record<Shop, [string, number][]> = {
    cafe_komorebi: [["too_busy", 3], ["unclear_instructions", 2], ["break_hard", 1], ["pay_late", 0.3], ["yelled_at", 0.3]],
    izk_torimaru: [["too_busy", 4], ["break_hard", 4], ["yelled_at", 3], ["unclear_instructions", 2], ["pay_late", 1]],
    cvs_machikado: [["unclear_instructions", 4], ["too_busy", 2], ["pay_late", 2], ["break_hard", 1.5], ["yelled_at", 1]],
    bk_komugi: [["too_busy", 3], ["break_hard", 2], ["unclear_instructions", 1.5], ["pay_late", 0.5], ["yelled_at", 0.5]],
  };
  const sinceBucket = (h: number) => (h < 24 ? "lt24" : h <= 72 ? "24to72" : "gt72");

  for (let i = 0; i < total; i++) {
    const id = `${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}`;
    // Onboarding: shops recruit their existing pool in weeks 1-2, then word of mouth.
    const join = chance(0.45) ? int(0, 13) : int(14, SIM_DAYS - 10);
    const engagement = 0.12 + rnd() * rnd() * 0.75 + rnd() * 0.1; // chance of opening on a non-work day
    const earlyChurn = engagement < 0.35 ? 0.1 : 0.03; // daily hazard, first week
    const churnHazard = 0.006 + (0.9 - engagement) * 0.022;
    const appetite = weighted<number>([[1, 3], [2, 4], [3, 2], [4, 1]]); // shifts / week wanted
    const myRoles = [pick(roles), pick(roles)] as const;
    const homeShop = pick(shops);
    const overtimeTendency = rnd() * 0.35;
    const sharesBadge = chance(0.42);
    const hoursPlan = (shop: Shop) => {
      const ot = overtimeTendency * overtimeAt[shop];
      return weighted<number>([[4, 2], [5.5, 3], [7, 3], [7.75, 2], [9, 2 * (1 + ot * 4)], [10.5, ot * 3]]);
    };

    const scheduled = new Map<number, { role: string; shop: Shop }>();
    const workedAt = new Set<Shop>();
    let practiceLevel = 0;
    let badgeSet = false;
    let churned = false;
    let lastShift: { day: number; t: number; shop: Shop } | null = null;
    let islandPull: { shop: Shop; until: number } | null = null;
    // Chat habits (own stream). "Just between us" users keep most chats fully private.
    const chatty = crnd();
    const privateShare = cchance(0.2) ? 0.85 : 0.1;
    const consentAnon = 0.2 + 0.35 * crnd();
    const backstage = myRoles.filter((r) => BACKSTAGE_ROLES.includes(r)).length;
    // What people say they prefer only loosely matches the roles they end up applying for.
    const leanBack = backstage === 2 ? 0.8 : backstage === 0 ? 0.2 : 0.5;
    const rolePref = cchance(0.6) ? (cchance(leanBack) ? "prefer_backstage" : "prefer_customer_facing") : null;
    const hoursPref = appetite >= 3 ? "want_more_hours" : appetite === 1 ? "want_fewer_hours" : null;
    const workedRoles = new Set<string>();

    for (let d = join; d < SIM_DAYS && !churned; d++) {
      const age = d - join;
      const badShift = lastShift && lastShift.day === d - 1 ? 1 - culture[lastShift.shop] : 0;
      if (age > 0 && chance((age < 7 ? earlyChurn : churnHazard) + badShift * 0.02)) { churned = true; break; }
      const dayStart = SIM_START + d * DAY;
      let clock = dayStart + int(7, 11) * 3600 + int(0, 3599);
      const emit = (type: TelemetryEventType, props: Record<string, PropValue> = {}) => {
        clock += int(20, 900);
        events.push({ install_id: id, t: Math.min(clock, dayStart + DAY - 1), type, props });
      };

      const shift = scheduled.get(d);
      let upcoming = false;
      for (let k = 1; k <= 7; k++) if (scheduled.has(d + k)) upcoming = true;
      const dayType = shift ? "work" : upcoming ? "off" : "no_shift";
      let openP = dayType === "work" ? 0.94 : dayType === "off" ? engagement : Math.min(0.95, engagement + 0.12);
      // The day after a shift: a good shop pulls you back in, a draining one pushes you away.
      if (lastShift && lastShift.day === d - 1 && dayType !== "work") openP = Math.min(0.97, openP * (0.5 + 0.8 * culture[lastShift.shop]));
      if (!chance(openP)) continue;

      emit("app_open", {
        day_type: dayType,
        hours_since_last_shift_end: lastShift ? sinceBucket((clock - lastShift.t) / 3600) : "none",
      });

      // Browsing jobs: mostly on days with nothing booked.
      const browseP = dayType === "no_shift" ? 0.8 : dayType === "off" ? 0.28 : 0.1;
      if (chance(browseP)) {
        const n = int(3, 6);
        emit("job_cards_shown", { n });
        const opens = Math.min(n, weighted<number>([[0, 1], [1, 4], [2, 3], [3, 1]]));
        let bookedThisWeek = 0;
        for (let k = 0; k < 7; k++) if (scheduled.has(d + k)) bookedThisWeek++;
        for (let o = 0; o < opens; o++) {
          // Shops re-invite people who already worked for them.
          const invited = workedAt.size > 0 && chance(0.35);
          const shop = invited ? pick([...workedAt]) : chance(0.5) ? homeShop : pick(shops);
          emit("job_card_open", { invited, shop_id: shop });
          const role = invited ? myRoles[0] : pick(myRoles);
          const base = invited ? 0.25 + 0.6 * culture[shop] : 0.3;
          const acceptP = base * (bookedThisWeek < appetite ? 1 : 0.15);
          if (chance(acceptP)) {
            emit("job_accept", { role, pay_style: weighted<string>([["daily", 3], ["weekly", 3], ["monthly", 4]]), invited, shop_id: shop });
            let day = d + int(1, 4);
            while (scheduled.has(day)) day++;
            scheduled.set(day, { role, shop });
            bookedThisWeek++;
            if (chance(0.3)) emit("calendar_add", { kind: chance(0.7) ? "google" : "ics" });
          } else if (chance(0.7)) {
            emit("job_pass", { role, invited, shop_id: shop });
          }
        }
      }

      if (shift) {
        if (chance(0.02 + 0.04 * (1 - culture[shift.shop]))) {
          // no-show: accepted but never started
        } else {
          const c = culture[shift.shop];
          emit("shift_start", { role: shift.role, shop_id: shift.shop });
          clock += 3 * 3600;
          let hours = hoursPlan(shift.shop);
          // The cat learns your limits: overtime attempts fade over the first weeks.
          if (hours > 8 && chance(0.55 + Math.min(0.3, (age / 7) * 0.05))) {
            emit("cat_tired_stop", { hours_bucket: "7_5to8" });
            hours = 7.75;
          }
          const bucket = hours < 4 ? "lt4" : hours < 6 ? "4to6" : hours <= 7.5 ? "6to7_5" : hours <= 8 ? "7_5to8" : hours <= 10 ? "8to10" : "gt10";
          emit("shift_end", { role: shift.role, hours_bucket: bucket, shop_id: shift.shop });
          lastShift = { day: d, t: clock, shop: shift.shop };
          workedAt.add(shift.shop);
          if (chance(0.55 + 0.3 * c)) {
            const tagN = weighted<number>([[0, 1.5 - c], [1, 3], [2, 2 + 3 * c], [3, 3 * c]]);
            const chosen = [...new Set(Array.from({ length: tagN }, () => pick(tags)))];
            const stars = weighted<number>([[5, 1 + 6 * c], [4, 4], [3, 2.2 - 1.5 * c], [2, 0.6 - 0.5 * c], [1, 0.15]]);
            emit("review_submitted", { tag_count: chosen.length, tags: chosen, stars, shop_id: shift.shop });
          }
          if (chance(0.15 + 0.5 * c)) islandPull = { shop: shift.shop, until: d + 3 };
        }
      }

      // Everyday loop: the reasons to open on a day without work.
      const offDay = dayType !== "work";
      if (chance(offDay ? 0.62 : 0.45)) emit("scoop_night", { orbs: int(4, 36) });
      if (chance(0.2)) emit("hatch", { kind: weighted<string>([["material", 5], ["clothes", 3], ["cat", 1]]) });
      if (islandPull && d > (lastShift?.day ?? -1) && d <= islandPull.until && chance(0.55)) {
        emit("shop_island_visit", { shop_id: islandPull.shop });
        islandPull = null;
      } else if (chance(offDay ? 0.18 : 0.08)) {
        emit("shop_island_visit", { shop_id: chance(0.6) ? homeShop : pick(shops) });
      }
      if (chance(offDay ? 0.2 : 0.06)) {
        practiceLevel = Math.min(20, practiceLevel + 1);
        emit("practice_done", { role: myRoles[0], level: practiceLevel });
        if (!badgeSet) { emit("skill_badge_share_toggled", { on: sharesBadge }); badgeSet = true; }
      }
      if (chance(0.07)) emit("outfit_change");
      if (chance(0.035)) emit("island_expand");
      if (chance(0.02)) emit("island_share");
      if (age === 0 && chance(0.15)) emit("suggestions_toggled", { on: chance(0.5) });

      // Chat with the cat. Only fixed tags are ever emitted; a private chat emits nothing.
      const cemit = (type: TelemetryEventType, props: Record<string, PropValue> = {}) => {
        clock += 30 + Math.floor(crnd() * 600);
        events.push({ install_id: id, t: Math.min(clock, dayStart + DAY - 1), type, props });
      };
      const justWorked = lastShift && lastShift.day >= d - 1 ? lastShift.shop : null;
      if (cchance(0.12 + 0.3 * chatty + (justWorked ? 0.25 : 0)) && !cchance(privateShare)) {
        cemit("chat_open", { kind: "me" });
        const signal = (topic: string, shop?: Shop) => cemit("chat_signal", { topic, private_mode: false, ...(shop ? { shop_id: shop } : {}) });
        if (justWorked) {
          const c = culture[justWorked];
          if (cchance(0.7 * (1 - c) + 0.05)) {
            const tag = cweighted(issueMix[justWorked]);
            signal(tag, justWorked);
            if (cchance(consentAnon)) cemit("anon_issue_sent", { tag, shop_id: justWorked });
          }
          if (cchance(0.6 * c)) signal(cchance(0.55) ? "liked_team" : "liked_customers", justWorked);
        }
        const next = scheduled.get(d + 1);
        if (next && !workedRoles.has(next.role) && cchance(0.35)) signal("nervous_new_role");
        if (rolePref && cchance(0.12)) signal(rolePref);
        if (hoursPref && cchance(0.1)) signal(hoursPref);
      }
      if (shift && lastShift?.day === d) workedRoles.add(shift.role);
      // The shop's cat: auto-answers before a shift, short fixed messages to the shop.
      if (scheduled.has(d + 1) && cchance(0.4)) {
        cemit("chat_open", { kind: "shop" });
        cemit("faq_auto_answered", { topic: cpick(FAQ_TOPICS) });
        if (cchance(0.12)) cemit("shop_message_sent", { kind: "question" });
      }
      if (shift && lastShift?.day === d) {
        if (cchance(0.03)) cemit("shop_message_sent", { kind: "late" });
        if (cchance(0.25 * culture[shift.shop])) cemit("shop_message_sent", { kind: "thanks" });
      } else if (upcoming && cchance(0.02)) {
        cemit("shop_message_sent", { kind: "swap" });
      }
    }
  }
  events.sort((a, b) => a.t - b.t);
  return events;
}
