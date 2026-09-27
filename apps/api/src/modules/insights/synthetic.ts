// Seeded generator for the "Simulated 12-week pilot" mode. SYNTHETIC DATA.
// It emits the same event stream the game would, so the dashboard aggregates it
// with exactly the same code as live data. Internal consistency by construction:
// shifts only exist after a job_accept, reviews only after a shift_end, etc.
// Shop-side shift postings (what Air Shift / Townwork would hold) are generated
// alongside, from the same shifts, so fill and no-show numbers line up with the events.
import {
  TELEMETRY_BACKSTAGE_ROLES as BACKSTAGE_ROLES,
  TELEMETRY_FAQ_TOPICS as FAQ_TOPICS,
  TELEMETRY_REVIEW_TAGS as REVIEW_TAGS,
  TELEMETRY_ROLES as ROLES,
  TELEMETRY_SHOP_IDS as SHOP_IDS,
  TELEMETRY_TIME_BANDS as BANDS,
  TELEMETRY_WEEKDAYS as WEEKDAYS,
  type InsightsPosting,
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
/** JST day index of D1, the same index aggregate.ts uses. */
export const SIM_START_DAY = Math.floor((SIM_START + 9 * 3600) / DAY);
export const SIM_SHOPS = 10;

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

type Band = (typeof BANDS)[number];
// 10 pilot shops in 3 areas. "culture" (0..1) is the hidden variable the after-shift
// signals should surface: how people feel after working there. drift moves it over the
// 12 weeks (cvs_hoshi gets a new manager and slides; izk_kemuri improves). "wage" (0..1) is the
// shop's pay level; a locale skin turns it into dollars or yen. It feeds no other number, so
// every locale shows the same metrics.
const SHOPS = {
  cafe_komorebi: { culture: 0.85, drift: 0, overtime: 0.6, wage: 0.5, bands: ["morning", "day"] },
  izk_torimaru: { culture: 0.35, drift: 0, overtime: 1.8, wage: 0.35, bands: ["evening", "night"] },
  cvs_machikado: { culture: 0.6, drift: 0, overtime: 1.0, wage: 0.25, bands: ["morning", "day", "evening", "night"] },
  bk_komugi: { culture: 0.75, drift: 0, overtime: 0.8, wage: 0.45, bands: ["morning", "day"] },
  cafe_sunnyside: { culture: 0.7, drift: 0, overtime: 0.7, wage: 0.15, bands: ["morning", "day", "evening"] },
  izk_chochin: { culture: 0.5, drift: 0, overtime: 1.4, wage: 0.6, bands: ["evening", "night"] },
  cvs_hoshi: { culture: 0.72, drift: -0.42, overtime: 1.2, wage: 0.2, bands: ["morning", "day", "evening", "night"] },
  rs_nikoniko: { culture: 0.8, drift: 0, overtime: 0.9, wage: 0.55, bands: ["day", "evening"] },
  sm_maruya: { culture: 0.62, drift: 0, overtime: 0.8, wage: 0.7, bands: ["day", "evening"] },
  izk_kemuri: { culture: 0.42, drift: 0.3, overtime: 1.5, wage: 0.65, bands: ["evening", "night"] },
} as const satisfies Record<string, { culture: number; drift: number; overtime: number; wage: number; bands: readonly Band[] }>;
type Shop = keyof typeof SHOPS & (typeof SHOP_IDS)[number];
const shops = Object.keys(SHOPS) as Shop[];
/** Pay level (0..1) and posted time bands per simulated shop, for the locale skin's wages. */
export const SIM_SHOP_PAY: { shop: string; level: number; bands: readonly string[] }[] = shops.map((shop) => ({ shop, level: SHOPS[shop].wage, bands: SHOPS[shop].bands }));
const cultureAt = (shop: Shop, d: number) => Math.min(0.95, Math.max(0.05, SHOPS[shop].culture + SHOPS[shop].drift * (d / SIM_DAYS)));

// What tends to go wrong at each shop: the same hidden culture, plus its own flavour.
const ISSUES_DEFAULT: [string, number][] = [["too_busy", 3], ["unclear_instructions", 2], ["break_hard", 2], ["pay_late", 0.6], ["yelled_at", 0.6]];
const issueMix: Partial<Record<Shop, [string, number][]>> = {
  cafe_komorebi: [["too_busy", 3], ["unclear_instructions", 2], ["break_hard", 1], ["pay_late", 0.3], ["yelled_at", 0.3]],
  izk_torimaru: [["too_busy", 4], ["break_hard", 4], ["yelled_at", 3], ["unclear_instructions", 2], ["pay_late", 1]],
  cvs_machikado: [["unclear_instructions", 4], ["too_busy", 2], ["pay_late", 2], ["break_hard", 1.5], ["yelled_at", 1]],
  bk_komugi: [["too_busy", 3], ["break_hard", 2], ["unclear_instructions", 1.5], ["pay_late", 0.5], ["yelled_at", 0.5]],
  cvs_hoshi: [["unclear_instructions", 3], ["break_hard", 3], ["too_busy", 2], ["yelled_at", 1.5], ["pay_late", 0.5]],
};
// Which landmark people tap on a shop's island: the good ones stand out at good shops.
const landmarkWeights = (c: number): [string, number][] => [
  ["on_time", 1 + 4 * c], ["breaks", 1 + 3 * c], ["friendly", 1 + 3 * c], ["again", 0.5 + 3 * c],
  ["instructions", 1 + c], ["paid", 1.5], ["fair", 2 - c],
];

export interface SimulatedPilot {
  events: FlatEvent[];
  postings: InsightsPosting[];
}

export function generateSimulated(opts: { seed?: number; installs?: number } = {}): FlatEvent[] {
  return generateSimulatedPilot(opts).events;
}

export function generateSimulatedPilot(opts: { seed?: number; installs?: number } = {}): SimulatedPilot {
  const seed = opts.seed ?? SIM_SEED;
  const rnd = mulberry32(seed);
  const total = opts.installs ?? 820;
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
  const tags = REVIEW_TAGS;
  const events: FlatEvent[] = [];
  // Chat is drawn from its own stream so adding it leaves every other synthetic number unchanged.
  const crnd = mulberry32(seed ^ 0x5eed_c4a7);
  const cchance = (p: number) => crnd() < p;
  const cpick = <T>(xs: readonly T[]): T => xs[Math.floor(crnd() * xs.length)]!;
  const cweighted = <T>(pairs: [T, number][]) => {
    let r = crnd() * pairs.reduce((s, [, w]) => s + w, 0);
    for (const [v, w] of pairs) if ((r -= w) <= 0) return v;
    return pairs[pairs.length - 1]![0];
  };
  // Scheduling signals (availability, time slots, reminders, landmarks, person-shop fit): own stream too.
  const srnd = mulberry32(seed ^ 0x51_07_5eed);
  const schance = (p: number) => srnd() < p;
  const spick = <T>(xs: readonly T[]): T => xs[Math.floor(srnd() * xs.length)]!;
  const sweighted = <T>(pairs: [T, number][]) => {
    let r = srnd() * pairs.reduce((s, [, w]) => s + w, 0);
    for (const [v, w] of pairs) if ((r -= w) <= 0) return v;
    return pairs[pairs.length - 1]![0];
  };
  const sinceBucket = (h: number) => (h < 24 ? "lt24" : h <= 72 ? "24to72" : "gt72");
  const slotOf = (day: number, band: string) => `${WEEKDAYS[day % 7]}_${band}`;
  // Shop side: filled / no-show per shop|day|band, from the shifts workers actually booked.
  const booked = new Map<string, { filled: number; noShows: number }>();
  const bookedAt = (shop: Shop, day: number, band: string) => {
    const k = `${shop}|${day}|${band}`;
    let b = booked.get(k);
    if (!b) booked.set(k, (b = { filled: 0, noShows: 0 }));
    return b;
  };

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
      const ot = overtimeTendency * SHOPS[shop].overtime;
      return weighted<number>([[4, 2], [5.5, 3], [7, 3], [7.75, 2], [9, 2 * (1 + ot * 4)], [10.5, ot * 3]]);
    };

    // Person x shop fit: the shop's culture plus this person's own match with it.
    const fitNoise = new Map<Shop, number>();
    const fitOf = (shop: Shop, d: number) => {
      if (!fitNoise.has(shop)) fitNoise.set(shop, (srnd() - 0.5) * 0.55);
      return Math.min(0.97, Math.max(0.03, cultureAt(shop, d) + fitNoise.get(shop)!));
    };
    // When they can work: students lean to evenings and weekends, others to weekday daytime.
    const profile = sweighted<"student" | "daytime" | "mixed">([["student", 4], ["daytime", 3], ["mixed", 3]]);
    const bandW: Record<Band, number> = profile === "student" ? { morning: 0.5, day: 1, evening: 4, night: 1.5 } : profile === "daytime" ? { morning: 3, day: 4, evening: 0.6, night: 0.2 } : { morning: 1.5, day: 2, evening: 2, night: 0.6 };
    const dayW = (wd: number) => (wd >= 5 ? (profile === "daytime" ? 0.8 : 2.2) : profile === "student" ? 0.8 : 1.3);
    const pickAvailability = () => {
      const want = 4 + Math.floor(srnd() * 7);
      const pool = WEEKDAYS.flatMap((_, wd) => BANDS.map((b) => ({ slot: `${WEEKDAYS[wd]}_${b}`, w: bandW[b] * dayW(wd) })));
      const out = new Set<string>();
      while (out.size < want) out.add(sweighted(pool.map((p) => [p.slot, p.w] as [string, number])));
      return out;
    };
    let availability = pickAvailability();
    const maxPerWeek = Math.min(7, appetite + (schance(0.3) ? 1 : 0));
    let availabilitySent = false;

    const scheduled = new Map<number, { role: string; shop: Shop; band: string; noShow: boolean }>();
    const workedAt = new Set<Shop>();
    let practiceLevel = 0;
    let badgeSet = false;
    let churned = false;
    let lastShift: { day: number; t: number; shop: Shop; overtime: boolean } | null = null;
    let islandPull: { shop: Shop; until: number } | null = null;
    let curious: { shop: Shop; until: number } | null = null; // visited an island before working there
    // Chat habits (own stream). "Just between us" users keep most chats fully private.
    const chatty = crnd();
    const privateShare = cchance(0.2) ? 0.85 : 0.1;
    const consentAnon = 0.35 + 0.4 * crnd();
    const backstage = myRoles.filter((r) => BACKSTAGE_ROLES.includes(r)).length;
    // What people say they prefer only loosely matches the roles they end up applying for.
    const leanBack = backstage === 2 ? 0.8 : backstage === 0 ? 0.2 : 0.5;
    const rolePref = cchance(0.6) ? (cchance(leanBack) ? "prefer_backstage" : "prefer_customer_facing") : null;
    const hoursPref = appetite >= 3 ? "want_more_hours" : appetite === 1 ? "want_fewer_hours" : null;
    const workedRoles = new Set<string>();

    for (let d = join; d < SIM_DAYS && !churned; d++) {
      const age = d - join;
      const badShift = lastShift && lastShift.day === d - 1 ? 1 - fitOf(lastShift.shop, d) : 0;
      if (age > 0 && chance((age < 7 ? earlyChurn : churnHazard) + badShift * 0.04)) {
        churned = true;
        // Shifts they had booked are simply not shown up for: the shop records no-shows.
        for (const [day, s] of scheduled) if (day >= d) bookedAt(s.shop, day, s.band).noShows++;
        break;
      }
      const dayStart = SIM_START + d * DAY;
      let clock = dayStart + int(7, 11) * 3600 + int(0, 3599);
      const emit = (type: TelemetryEventType, props: Record<string, PropValue> = {}) => {
        clock += int(20, 900);
        events.push({ install_id: id, t: Math.min(clock, dayStart + DAY - 1), type, props });
      };
      const semit = (type: TelemetryEventType, props: Record<string, PropValue> = {}) => {
        clock += 20 + Math.floor(srnd() * 300);
        events.push({ install_id: id, t: Math.min(clock, dayStart + DAY - 1), type, props });
      };

      const shift = scheduled.get(d);
      let upcoming = false;
      for (let k = 1; k <= 7; k++) if (scheduled.has(d + k)) upcoming = true;
      const dayType = shift ? "work" : upcoming ? "off" : "no_shift";
      // On a work day the game is opened to work alongside the cat, so almost always.
      let openP = dayType === "work" ? 0.985 : dayType === "off" ? engagement : Math.min(0.95, engagement + 0.12);
      // The day after a shift: a good fit pulls you back in, a draining one pushes you away.
      if (lastShift && lastShift.day === d - 1 && dayType !== "work") openP = Math.min(0.97, openP * (0.45 + 0.9 * fitOf(lastShift.shop, d)));
      if (!chance(openP)) continue;

      emit("app_open", {
        day_type: dayType,
        hours_since_last_shift_end: lastShift ? sinceBucket((clock - lastShift.t) / 3600) : "none",
      });
      // Weekly availability for the cat: set on the first open, revisited now and then on Mondays.
      if (!availabilitySent || (d % 7 === 0 && schance(0.25))) {
        if (availabilitySent && schance(0.5)) availability = pickAvailability();
        semit("availability_set", { slots: [...availability], max_per_week: maxPerWeek });
        availabilitySent = true;
      }

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
          let shop = invited ? pick([...workedAt]) : chance(0.5) ? homeShop : pick(shops);
          // An island visit before applying makes that shop's card more likely to be opened.
          if (!invited && curious && d <= curious.until && schance(0.35)) shop = curious.shop;
          emit("job_card_open", { invited, shop_id: shop });
          const role = invited ? myRoles[0] : pick(myRoles);
          // Going back to a shop you already know depends on how it felt there.
          const base = invited ? 0.2 + 0.7 * fitOf(shop, d) : workedAt.has(shop) ? 0.1 + 0.4 * fitOf(shop, d) : 0.3;
          const acceptP = base * (bookedThisWeek < appetite ? 1 : 0.15);
          if (chance(acceptP)) {
            let day = d + int(1, 4);
            while (scheduled.has(day)) day++;
            const wd = WEEKDAYS[day % 7]!;
            const fitting = SHOPS[shop].bands.filter((b) => availability.has(`${wd}_${b}`));
            const band = fitting.length ? spick(fitting) : spick(SHOPS[shop].bands);
            const slot = slotOf(day, band);
            emit("job_accept", { role, pay_style: weighted<string>([["daily", 3], ["weekly", 3], ["monthly", 4]]), invited, shop_id: shop, slot });
            // Decided now so the night-before reminder can reflect it; drawn from the scheduling stream.
            const tired = !!lastShift && lastShift.overtime && lastShift.day >= d - 2;
            const noShow = schance(0.015 + 0.06 * (1 - fitOf(shop, day)) + (tired ? 0.04 : 0) + (fitting.length ? 0 : 0.04));
            scheduled.set(day, { role, shop, band, noShow });
            bookedAt(shop, day, band).filled++;
            bookedThisWeek++;
            if (chance(0.3)) emit("calendar_add", { kind: chance(0.7) ? "google" : "ics" });
          } else if (chance(0.7)) {
            emit("job_pass", { role, invited, shop_id: shop });
          }
        }
      }

      if (shift) {
        const slot = slotOf(d, shift.band);
        rnd(); // keeps the main stream aligned with the no-show draw it used to make here
        if (shift.noShow) {
          bookedAt(shift.shop, d, shift.band).noShows++;
        } else {
          const c = cultureAt(shift.shop, d);
          const fit = fitOf(shift.shop, d);
          emit("shift_start", { role: shift.role, shop_id: shift.shop, slot });
          clock += 3 * 3600;
          let hours = hoursPlan(shift.shop);
          // The cat learns your limits: overtime attempts fade over the first weeks.
          if (hours > 8 && chance(0.55 + Math.min(0.3, (age / 7) * 0.05))) {
            emit("cat_tired_stop", { hours_bucket: "7_5to8" });
            hours = 7.75;
          }
          const bucket = hours < 4 ? "lt4" : hours < 6 ? "4to6" : hours <= 7.5 ? "6to7_5" : hours <= 8 ? "7_5to8" : hours <= 10 ? "8to10" : "gt10";
          emit("shift_end", { role: shift.role, hours_bucket: bucket, shop_id: shift.shop, slot });
          lastShift = { day: d, t: clock, shop: shift.shop, overtime: hours > 8 };
          workedAt.add(shift.shop);
          if (chance(0.55 + 0.3 * fit)) {
            const tagN = weighted<number>([[0, 1.5 - c], [1, 3], [2, 2 + 3 * c], [3, 3 * c]]);
            const chosen = [...new Set(Array.from({ length: tagN }, () => pick(tags)))];
            // Stars follow the shop's reputation more than this person's own fit.
            const sc = 0.7 * c + 0.3 * fit;
            const stars = weighted<number>([[5, 1 + 6 * sc], [4, 4], [3, 2.2 - 1.5 * sc], [2, 0.6 - 0.5 * sc], [1, 0.15]]);
            emit("review_submitted", { tag_count: chosen.length, tags: chosen, stars, shop_id: shift.shop });
          }
          if (chance(0.1 + 0.6 * fit)) islandPull = { shop: shift.shop, until: d + 3 };
        }
      }
      // The cat's reminder the night before a booked shift. In-game only; no penalty for skipping.
      const tomorrow = scheduled.get(d + 1);
      if (tomorrow) {
        const reaction = tomorrow.noShow
          ? sweighted<string>([["ok", 3], ["swap", 2.5], ["dismissed", 4.5]])
          : sweighted<string>([["ok", 7.5], ["swap", 0.3], ["dismissed", 2.2]]);
        semit("reminder_reaction", { when: "night_before", reaction, shop_id: tomorrow.shop, slot: slotOf(d + 1, tomorrow.band) });
      }

      // Everyday loop: the reasons to open on a day without work.
      const offDay = dayType !== "work";
      if (chance(offDay ? 0.62 : 0.45)) emit("scoop_night", { orbs: int(4, 36) });
      if (chance(0.2)) emit("hatch", { kind: weighted<string>([["material", 5], ["clothes", 3], ["cat", 1]]) });
      let visited: Shop | null = null;
      if (islandPull && d > (lastShift?.day ?? -1) && d <= islandPull.until && chance(0.55)) {
        emit("shop_island_visit", { shop_id: islandPull.shop });
        visited = islandPull.shop;
        islandPull = null;
      } else if (chance(offDay ? 0.18 : 0.08)) {
        const shop = chance(0.6) ? homeShop : pick(shops);
        emit("shop_island_visit", { shop_id: shop });
        visited = shop;
        if (!workedAt.has(shop)) curious = { shop, until: d + 14 };
      }
      if (visited && schance(0.65)) {
        const c = cultureAt(visited, d);
        const taps = schance(0.4) ? 2 : 1;
        for (let k = 0; k < taps; k++) semit("landmark_tap", { shop_id: visited, tag: sweighted(landmarkWeights(c)) });
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
          const c = cultureAt(justWorked, d);
          if (cchance(0.7 * (1 - c) + 0.05)) {
            const tag = cweighted(issueMix[justWorked] ?? ISSUES_DEFAULT);
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
        if (cchance(0.25 * cultureAt(shift.shop, d))) cemit("shop_message_sent", { kind: "thanks" });
      } else if (upcoming && cchance(0.02)) {
        cemit("shop_message_sent", { kind: "swap" });
      }
    }
  }
  events.sort((a, b) => a.t - b.t);
  return { events, postings: postingsFrom(booked, seed) };
}

// Shop-side postings: every shop posts openings in the bands it runs. Openings a worker
// booked count as filled; the rest stayed open. Weekend evenings and struggling shops post more.
function postingsFrom(booked: Map<string, { filled: number; noShows: number }>, seed: number): InsightsPosting[] {
  const prnd = mulberry32(seed ^ 0x9051_1265);
  const poisson = (lambda: number) => {
    let k = 0;
    let p = Math.exp(-lambda);
    let s = p;
    const u = prnd();
    while (u > s && k < 20) { k++; p *= lambda / k; s += p; }
    return k;
  };
  const out: InsightsPosting[] = [];
  for (const shop of shops) {
    for (let day = 0; day < SIM_DAYS; day++) {
      const wd = day % 7;
      for (const band of SHOPS[shop].bands as readonly Band[]) {
        const b = booked.get(`${shop}|${day}|${band}`) ?? { filled: 0, noShows: 0 };
        const peak = (wd >= 4 && (band === "evening" || band === "night")) || (wd >= 5 && band === "day") ? 0.45 : 0;
        const lambda = 0.2 + 0.55 * (1 - cultureAt(shop, day)) + peak;
        const openings = b.filled + poisson(lambda);
        if (openings === 0) continue;
        out.push({ shop, day: SIM_START_DAY + day, slot: `${WEEKDAYS[wd]}_${band}`, openings, filled: b.filled, no_shows: b.noShows });
      }
    }
  }
  return out;
}
