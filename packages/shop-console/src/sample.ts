/**
 * Seeded sample data for the shop console. EN = a boba shop in San Francisco (USD),
 * JA = a cafe in Kichijoji, Tokyo (JPY). Dates are relative to "today" in the shop's time
 * zone, and the shop clock starts at 14:20 so the day always looks the same.
 * Every person and shop here is fictional.
 */
import { REGIONS } from "./rules";
import type { PoolWorker } from "./rules";
import { addDays, weekStart, weekdayOf, zonedParts, zonedToUtc } from "./time";
import type {
  AttendanceEvent,
  CatLook,
  Faq,
  IssueId,
  Job,
  Message,
  NotificationSettings,
  OnTimeRecord,
  PositiveTag,
  Region,
  Role,
  ShopProfile,
  SkillBadge,
  StaffMember,
  TemplateKind,
} from "./types";

export const SAMPLE_CLOCK = "14:20";

/** Internal worker record. The store turns it into views; most of it never reaches a shop. */
export type WorkerRecord = {
  id: string;
  displayName: string;
  cat: CatLook;
  badges: SkillBadge[];
  shareBadges: boolean;
  onTime: OnTimeRecord;
  shareOnTime: boolean;
  /** Private. Must never appear in anything a shop can read. */
  contact: { phone: string; email: string };
  past: { shifts: number; lastWorked: string; stars: number; allowContact: boolean; roles: Role[] } | null;
};

export type ApplicationRecord = {
  id: string;
  jobId: string;
  slotId: string;
  workerId: string;
  status: "applied" | "accepted" | "declined" | "withdrawn";
  appliedAt: string;
  decidedAt: string | null;
  note: string | null;
};

export type ShiftRecord = { id: string; jobId: string; slotId: string; workerId: string; date: string; start: string; end: string };

export type ThreadRecord = {
  id: string;
  workerId: string;
  kind: "shift" | "invite";
  shiftId: string | null;
  inviteId: string | null;
  messages: Message[];
  readAt: string;
  reported: boolean;
  blocked: boolean;
};

export type ReviewRecord = { workerId: string; week: string; stars: number; tags: PositiveTag[]; issues: IssueId[] };

export type InviteRecord = { id: string; workerId: string; jobId: string; slotId: string; sentAt: string; deliverAt: string; status: "delivered" | "queued" };

export type SampleData = {
  region: Region;
  timeZone: string;
  today: string;
  now: string;
  profile: ShopProfile;
  staff: StaffMember[];
  notifications: NotificationSettings;
  faq: Faq;
  jobs: Job[];
  workers: WorkerRecord[];
  applications: ApplicationRecord[];
  shifts: ShiftRecord[];
  events: AttendanceEvent[];
  threads: ThreadRecord[];
  reviews: ReviewRecord[];
  invites: InviteRecord[];
  pool: PoolWorker[];
};

type Text = {
  profile: ShopProfile;
  staff: Array<[string, StaffMember["role"]]>;
  faq: Faq;
  jobs: Record<"boba" | "prep" | "tea" | "stock" | "popup", { title: string; notes: string; dress: string; wage: number }>;
  workers: Array<[string, string, string]>;
  msg: Record<string, string>;
  reason: Record<"closeLate" | "forgotPunch" | "noShow", string>;
};

const TEXT: Record<Region, Text> = {
  sf: {
    profile: {
      name: "Sunnyside Boba",
      area: "Mission District, San Francisco",
      signColor: "#3f9e8f",
      values: "A calm pace and a warm cup on every shift.",
      kind: "cafe",
    },
    staff: [
      ["Alex Chen", "owner"],
      ["Jordan Lee", "manager"],
      ["Riley Park", "staff"],
    ],
    faq: {
      dressCode: "Black top and comfortable closed-toe shoes. We lend you an apron.",
      entrance: "Use the side door on 24th Street and ring the bell. Bike rack is next to it.",
      breaks: "A 30-minute paid break on shifts of 5 hours or more. Staff drinks are free.",
      contactName: "Jordan",
    },
    jobs: {
      boba: { title: "Boba bar — drinks & register", notes: "Take orders, run the register and help shake drinks at rush.", dress: "Black top, closed-toe shoes. Apron provided.", wage: 22 },
      prep: { title: "Opening prep & dishes", notes: "Cook tapioca, set up the bar and keep the dish station moving.", dress: "Comfortable clothes you can get wet. Non-slip shoes.", wage: 21 },
      tea: { title: "Tea bar barista", notes: "Brew teas and build drinks from recipe cards. Training on the first hour.", dress: "Black top, closed-toe shoes. Apron provided.", wage: 24.5 },
      stock: { title: "Stock & delivery check-in", notes: "Check the weekly delivery against the list and restock the back room.", dress: "Closed-toe shoes. Gloves provided.", wage: 21.5 },
      popup: { title: "Night market pop-up — register", notes: "Register at our stall at the summer night market.", dress: "Sunnyside T-shirt provided.", wage: 23 },
    },
    workers: [
      ["Maya", "Mochi", "#f2b8a0"],
      ["Diego", "Pepper", "#8f9bb3"],
      ["Priya", "Biscuit", "#e6c07b"],
      ["Sam", "Nori", "#5b6b73"],
      ["Kenji", "Tofu", "#f4efe6"],
      ["Lena", "Plum", "#b99ad6"],
      ["Ana", "Churro", "#d9a066"],
      ["Theo", "Pebble", "#a7b0a0"],
      ["Jun", "Yuzu", "#f0d36b"],
      ["Rosa", "Clove", "#c98f7a"],
      ["Omar", "Sesame", "#cdb89a"],
      ["Sofia", "Latte", "#d8b99b"],
      ["Grace", "Mint", "#9fd3c0"],
      ["Leo", "Ash", "#9aa1ab"],
      ["Hana", "Peach", "#f5b3b8"],
    ],
    msg: {
      late: "Running about 10 min late, sorry! Bus is stuck on Mission.",
      lateReply: "Thanks for the heads-up. See you soon!",
      entranceQ: "Which entrance should I use?",
      bottleQ: "Can I bring my own water bottle behind the bar?",
      swap: "Could I swap Saturday for Sunday this week?",
      closeThanks: "Thanks for closing tonight! Could you also open on Saturday?",
      closeYes: "Yes, happy to!",
      seeYou: "Great, see you Saturday!",
      thanks: "Thanks for today!",
      invite: "We'd love you back — we have a Saturday evening shift open.",
      dressQ: "What should I wear on my first day?",
    },
    reason: {
      closeLate: "Stayed to close the register",
      forgotPunch: "Forgot to check out; confirmed with Jordan",
      noShow: "No check-in and no message by 30 min after start",
    },
  },
  jp: {
    profile: {
      name: "カフェ こもれび",
      area: "吉祥寺・東京都武蔵野市",
      signColor: "#3f9e8f",
      values: "あわてないペースと、あたたかい一杯を。",
      kind: "cafe",
    },
    staff: [
      ["森 あかり", "owner"],
      ["田中 洋平", "manager"],
      ["佐藤 ゆき", "staff"],
    ],
    faq: {
      dressCode: "黒のトップスと、歩きやすい靴でお越しください。エプロンは貸し出します。",
      entrance: "井の頭通り側の通用口からお入りください。駐輪場は通用口の横です。",
      breaks: "5時間以上のシフトは30分の休憩があります（有給）。ドリンクは無料です。",
      contactName: "田中",
    },
    jobs: {
      boba: { title: "ホール・レジ（ドリンク）", notes: "注文受け、レジ、混雑時はドリンクづくりの手伝いをお願いします。", dress: "黒のトップス、歩きやすい靴。エプロン貸出。", wage: 1300 },
      prep: { title: "開店準備・洗い場", notes: "仕込み、開店準備と洗い場をお願いします。", dress: "濡れてもよい服、滑りにくい靴。", wage: 1300 },
      tea: { title: "バリスタ（紅茶・ドリンク）", notes: "レシピカードに沿ってドリンクをつくります。最初の1時間は研修です。", dress: "黒のトップス、歩きやすい靴。エプロン貸出。", wage: 1450 },
      stock: { title: "品出し・納品チェック", notes: "週1回の納品を一覧と照合し、バックヤードに補充します。", dress: "つま先の出ない靴。軍手貸出。", wage: 1280 },
      popup: { title: "夏祭り出店・レジ", notes: "商店街の夏祭りの出店でレジをお願いします。", dress: "Tシャツ貸出。", wage: 1350 },
    },
    workers: [
      ["みか", "もち", "#f2b8a0"],
      ["そうた", "こしょう", "#8f9bb3"],
      ["ゆい", "ビスケ", "#e6c07b"],
      ["はると", "のり", "#5b6b73"],
      ["けんじ", "とうふ", "#f4efe6"],
      ["あおい", "すもも", "#b99ad6"],
      ["りく", "きなこ", "#d9a066"],
      ["れん", "こいし", "#a7b0a0"],
      ["じゅん", "ゆず", "#f0d36b"],
      ["さき", "あずき", "#c98f7a"],
      ["たくみ", "ごま", "#cdb89a"],
      ["ほのか", "ラテ", "#d8b99b"],
      ["めい", "ミント", "#9fd3c0"],
      ["しょう", "はい", "#9aa1ab"],
      ["はな", "もも", "#f5b3b8"],
    ],
    msg: {
      late: "10分ほど遅れそうです、すみません！電車が止まっています。",
      lateReply: "連絡ありがとうございます。気をつけて来てください。",
      entranceQ: "どこから入ればいいですか？",
      bottleQ: "カウンターの中に自分の水筒を持ち込んでもいいですか？",
      swap: "今週の土曜を日曜に交代してもらえますか？",
      closeThanks: "今日は締めまでありがとうございました！土曜の開店もお願いできますか？",
      closeYes: "はい、大丈夫です！",
      seeYou: "助かります、土曜よろしくお願いします！",
      thanks: "今日はありがとうございました！",
      invite: "また来てほしいです。土曜の夕方のシフトが空いています。",
      dressQ: "初日は何を着ていけばいいですか？",
    },
    reason: {
      closeLate: "レジ締めのため残った",
      forgotPunch: "退勤の打刻忘れ。田中が確認",
      noShow: "開始30分後まで出勤も連絡もなし",
    },
  },
};

/** Deterministic PRNG so the sample looks the same on every load. */
function rng(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

export function createSample(region: Region, realNow: Date = new Date()): SampleData {
  const { timeZone } = REGIONS[region];
  const t = TEXT[region];
  const today = zonedParts(realNow, timeZone).date;
  const day = (n: number) => addDays(today, n);
  const at = (n: number, time: string) => zonedToUtc(day(n), time, timeZone).toISOString();
  const now = at(0, SAMPLE_CLOCK);
  // Next Saturday strictly after today (the "short on Saturday evening" alert).
  const sat = ((6 - weekdayOf(today) + 7) % 7) || 7;

  const workers: WorkerRecord[] = t.workers.map(([name, catName, color], i) => ({
    id: `w-${(0x3a1 + i * 97).toString(16)}`,
    displayName: name,
    cat: { name: catName, color },
    badges: [],
    shareBadges: true,
    onTime: { onTime: 0, total: 0 },
    shareOnTime: true,
    contact: { phone: `+1-415-555-01${String(i).padStart(2, "0")}`, email: `worker${i}@example.com` },
    past: null,
  }));
  const w = (i: number): WorkerRecord => workers[i] as WorkerRecord;
  const set = (i: number, patch: Partial<WorkerRecord>) => Object.assign(w(i), patch);
  // Maya, Diego, Priya, Sam, Kenji, Lena, Ana, Theo, Jun, Rosa, Omar, Sofia, Grace, Leo, Hana
  set(0, { badges: [{ role: "register", level: 3, shifts: 14 }, { role: "barista", level: 2, shifts: 6 }], onTime: { onTime: 19, total: 20 }, past: { shifts: 12, lastWorked: day(-1), stars: 5, allowContact: true, roles: ["register", "barista"] } });
  set(1, { badges: [{ role: "register", level: 2, shifts: 5 }], onTime: { onTime: 6, total: 7 }, past: { shifts: 3, lastWorked: day(-8), stars: 4, allowContact: false, roles: ["register"] } });
  set(2, { badges: [{ role: "register", level: 1, shifts: 3 }, { role: "hall", level: 2, shifts: 9 }], onTime: { onTime: 12, total: 12 } });
  set(3, { badges: [{ role: "register", level: 2, shifts: 8 }], onTime: { onTime: 8, total: 9 }, past: { shifts: 5, lastWorked: day(-6), stars: 4, allowContact: true, roles: ["register"] } });
  set(4, { badges: [{ role: "dish", level: 3, shifts: 22 }, { role: "kitchen", level: 2, shifts: 7 }], onTime: { onTime: 28, total: 29 }, past: { shifts: 9, lastWorked: day(-2), stars: 5, allowContact: true, roles: ["dish"] } });
  set(5, { badges: [{ role: "barista", level: 3, shifts: 17 }], onTime: { onTime: 16, total: 17 }, past: { shifts: 7, lastWorked: day(-7), stars: 5, allowContact: false, roles: ["barista"] } });
  set(6, { badges: [{ role: "register", level: 1, shifts: 2 }], onTime: { onTime: 2, total: 2 } });
  set(7, { shareBadges: false, badges: [{ role: "register", level: 2, shifts: 6 }], onTime: { onTime: 6, total: 7 } });
  set(8, { badges: [{ role: "barista", level: 2, shifts: 8 }], shareOnTime: false, onTime: { onTime: 5, total: 8 } });
  set(9, { badges: [{ role: "register", level: 1, shifts: 4 }], onTime: { onTime: 3, total: 4 }, past: { shifts: 2, lastWorked: day(-3), stars: 2, allowContact: false, roles: ["register"] } });
  set(10, { badges: [{ role: "register", level: 2, shifts: 11 }], onTime: { onTime: 10, total: 11 }, past: { shifts: 6, lastWorked: day(-24), stars: 5, allowContact: true, roles: ["register", "stock"] } });
  set(11, { badges: [{ role: "barista", level: 2, shifts: 9 }], onTime: { onTime: 9, total: 9 }, past: { shifts: 4, lastWorked: day(-31), stars: 4, allowContact: true, roles: ["barista"] } });
  set(12, { badges: [{ role: "dish", level: 2, shifts: 6 }], onTime: { onTime: 6, total: 6 }, past: { shifts: 3, lastWorked: day(-45), stars: 5, allowContact: true, roles: ["dish", "stock"] } });
  set(13, { badges: [{ role: "register", level: 1, shifts: 1 }], onTime: { onTime: 1, total: 1 } });
  set(14, { shareBadges: false, shareOnTime: false, badges: [{ role: "hall", level: 1, shifts: 1 }], onTime: { onTime: 1, total: 1 } });
  if (region === "jp") workers.forEach((x, i) => (x.contact.phone = `090-0000-00${String(i).padStart(2, "0")}`));

  const created = at(-9, "10:00");
  const job = (id: string, key: keyof Text["jobs"], role: Role, status: Job["status"], payStyle: Job["payStyle"], slots: Array<[number, string, string, number]>): Job => ({
    id,
    title: t.jobs[key].title,
    role,
    status,
    wage: t.jobs[key].wage,
    payStyle,
    dressCode: t.jobs[key].dress,
    notes: t.jobs[key].notes,
    slots: slots.map(([d, start, end, capacity], i) => ({ id: `${id}-s${i + 1}`, date: day(d), start, end, capacity })),
    urgent: false,
    createdAt: created,
    updatedAt: created,
  });
  const jobs: Job[] = [
    job("job-boba", "boba", "register", "published", "weekly", [
      [-2, "16:00", "21:00", 2],
      [-1, "16:00", "21:00", 2],
      [0, "11:00", "16:00", 2],
      [0, "16:00", "21:00", 2],
      [2, "16:00", "21:00", 3],
      [sat, "17:00", "21:00", 3],
    ]),
    job("job-prep", "prep", "dish", "published", "same_day", [
      [-3, "07:30", "11:30", 1],
      [0, "07:30", "11:30", 1],
      [1, "07:30", "11:30", 1],
      [3, "07:30", "11:30", 1],
    ]),
    job("job-tea", "tea", "barista", "published", "weekly", [
      [-4, "12:00", "17:00", 1],
      [0, "12:00", "17:00", 2],
      [sat, "12:00", "17:00", 2],
    ]),
    job("job-stock", "stock", "stock", "draft", "weekly", [[5, "09:00", "13:00", 1]]),
    job("job-popup", "popup", "register", "closed", "same_day", [
      [-20, "18:00", "22:00", 3],
      [-19, "18:00", "22:00", 3],
    ]),
  ];
  jobs[4]!.createdAt = at(-40, "10:00");
  jobs[3]!.createdAt = at(-1, "16:00");

  const applications: ApplicationRecord[] = [];
  const shifts: ShiftRecord[] = [];
  let n = 0;
  const book = (slotId: string, wi: number, appliedDaysAgo = 5) => {
    const jobId = slotId.replace(/-s\d+$/, "");
    const slot = jobs.find((j) => j.id === jobId)?.slots.find((s) => s.id === slotId);
    if (!slot) throw new Error(`unknown slot ${slotId}`);
    const appId = `app-${++n}`;
    applications.push({ id: appId, jobId, slotId, workerId: w(wi).id, status: "accepted", appliedAt: at(-appliedDaysAgo, "09:12"), decidedAt: at(-appliedDaysAgo, "11:30"), note: null });
    const id = `shift-${n}`;
    shifts.push({ id, jobId, slotId, workerId: w(wi).id, date: slot.date, start: slot.start, end: slot.end });
    return id;
  };
  const apply = (slotId: string, wi: number, when: string, status: ApplicationRecord["status"] = "applied", note: string | null = null) => {
    const jobId = slotId.replace(/-s\d+$/, "");
    applications.push({ id: `app-${++n}`, jobId, slotId, workerId: w(wi).id, status, appliedAt: when, decidedAt: status === "applied" ? null : when, note });
  };

  const past2 = book("job-boba-s1", 0, 7);
  const past2b = book("job-boba-s1", 9, 7);
  const past1 = book("job-boba-s2", 0, 6);
  const noShow = book("job-boba-s2", 9, 6);
  const prep3 = book("job-prep-s1", 4, 8);
  const tea4 = book("job-tea-s1", 5, 9);
  const prepToday = book("job-prep-s2", 4, 4);
  const maya = book("job-boba-s3", 0, 4);
  const diego = book("job-boba-s3", 1, 4);
  const lena = book("job-tea-s2", 5, 5);
  const priya = book("job-boba-s4", 2, 3);
  const sam = book("job-boba-s4", 3, 3);
  book("job-prep-s3", 4, 2);
  book("job-boba-s5", 3, 2);
  book("job-boba-s5", 0, 2);
  book("job-boba-s6", 0, 1);
  book("job-tea-s3", 5, 2);
  book("job-popup-s1", 10, 26);
  book("job-popup-s1", 0, 26);
  book("job-popup-s2", 11, 26);

  apply("job-boba-s6", 6, at(0, "09:41"), "applied", region === "sf" ? "First time at a boba shop, but I've done register at a bakery." : "ドリンクのお店は初めてですが、パン屋でレジの経験があります。");
  apply("job-boba-s6", 7, at(0, "12:03"));
  apply("job-tea-s3", 8, at(-1, "19:25"));
  apply("job-prep-s4", 12, at(-1, "08:10"));
  apply("job-boba-s5", 14, at(0, "13:47"));
  apply("job-boba-s6", 13, at(-2, "10:00"), "declined");

  const events: AttendanceEvent[] = [];
  let e = 0;
  const ev = (shiftId: string, kind: AttendanceEvent["kind"], d: number, time: string, extra: Partial<AttendanceEvent> = {}, by = "worker", source: AttendanceEvent["source"] = "worker") => {
    const when = at(d, time);
    events.push({ id: `ev-${++e}`, shiftId, kind, at: when, recordedAt: extra.recordedAt ?? when, by, source, ...extra });
  };
  const manager = t.staff[1]?.[0] ?? "";
  ev(prep3, "check_in", -3, "07:27"); ev(prep3, "check_out", -3, "11:31");
  ev(tea4, "check_in", -4, "11:56"); ev(tea4, "check_out", -4, "17:02");
  ev(past2, "check_in", -2, "15:55"); ev(past2, "check_out", -2, "21:04");
  ev(past2b, "check_in", -2, "16:02"); ev(past2b, "check_out", -2, "21:00");
  ev(past1, "check_in", -1, "15:57"); ev(past1, "check_out", -1, "21:05");
  ev(past1, "correction", -1, "21:30", { field: "check_out", previous: at(-1, "21:05"), reason: t.reason.closeLate, recordedAt: at(-1, "21:42") }, manager, "staff");
  ev(noShow, "no_show", -1, "16:30", { reason: t.reason.noShow, recordedAt: at(-1, "16:31") }, manager, "staff");
  ev(prepToday, "check_in", 0, "07:28"); ev(prepToday, "check_out", 0, "11:34");
  ev(prepToday, "correction", 0, "11:30", { field: "check_out", previous: at(0, "11:34"), reason: t.reason.forgotPunch, recordedAt: at(0, "12:05") }, manager, "staff");
  ev(maya, "check_in", 0, "10:56");
  ev(diego, "running_late", 0, "10:50", { minutesLate: 10 });
  ev(diego, "check_in", 0, "11:12");
  ev(lena, "check_in", 0, "11:58");
  ev(priya, "on_the_way", 0, "14:02");

  const threads: ThreadRecord[] = [];
  const msg = (from: Message["from"], d: number, time: string, text: string, extra: Partial<Message> = {}): Message => {
    const sent = at(d, time);
    return { id: `m-${threads.length}-${d}-${time}-${from}`, from, text, sentAt: sent, deliverAt: extra.deliverAt ?? sent, status: "delivered", ...extra };
  };
  const thread = (wi: number, shiftId: string | null, messages: Message[], readAt: string, kind: "shift" | "invite" = "shift", inviteId: string | null = null) => {
    threads.push({ id: `th-${threads.length + 1}`, workerId: w(wi).id, kind, shiftId, inviteId, messages, readAt, reported: false, blocked: false });
  };
  const staffName = t.staff[1]?.[0] ?? "";
  const owner = t.staff[0]?.[0] ?? "";
  thread(2, priya, [
    msg("worker", 0, "13:58", t.msg.entranceQ ?? ""),
    msg("auto", 0, "13:58", t.faq.entrance, { faqKey: "entrance" }),
    msg("worker", 0, "14:05", t.msg.bottleQ ?? ""),
  ], at(0, "13:59"));
  thread(3, sam, [msg("worker", 0, "12:40", t.msg.swap ?? "", { template: "swap" as TemplateKind })], at(0, "09:00"));
  thread(1, diego, [
    msg("worker", 0, "10:50", t.msg.late ?? "", { template: "late" }),
    msg("staff", 0, "10:52", t.msg.lateReply ?? "", { staffName }),
  ], at(0, "10:52"));
  thread(0, maya, [
    msg("staff", -1, "21:40", t.msg.closeThanks ?? "", { staffName: owner, status: "queued", deliverAt: at(0, "08:00") }),
    msg("worker", 0, "08:12", t.msg.closeYes ?? ""),
    msg("staff", 0, "08:20", t.msg.seeYou ?? "", { staffName: owner }),
  ], at(0, "08:30"));
  thread(4, prepToday, [msg("worker", 0, "11:40", t.msg.thanks ?? "", { template: "thanks" })], at(0, "11:45"));

  const invites: InviteRecord[] = [
    { id: "inv-1", workerId: w(10).id, jobId: "job-boba", slotId: "job-boba-s6", sentAt: at(-1, "10:15"), deliverAt: at(-1, "10:15"), status: "delivered" },
  ];
  thread(10, null, [msg("staff", -1, "10:15", t.msg.invite ?? "", { staffName: owner })], at(-1, "10:15"), "invite", "inv-1");

  // Reviews: 14 workers a week over the last 6 weeks. Positive tags build the island; issues
  // only show up in the report when 5+ different workers picked the same one.
  const reviews: ReviewRecord[] = [];
  const r = rng(region === "sf" ? 7 : 11);
  const thisWeek = weekStart(today);
  const weeks = Array.from({ length: 6 }, (_, i) => addDays(thisWeek, -7 * (5 - i)));
  const perWeek = 14;
  weeks.forEach((week, wi) => {
    for (let k = 0; k < perWeek; k++) reviews.push({ workerId: `rv-${wi}-${k}`, week, stars: 0, tags: [], issues: [] });
  });
  // Issues per week: "too busy" and "couldn't take a break" rise; the rest stay under 5 in total.
  const issueByWeek: Array<[IssueId, number[]]> = [
    ["too_busy", [2, 3, 4, 6, 7, 9]],
    ["no_break", [1, 2, 1, 3, 5, 6]],
    ["unclear", [1, 0, 1, 0, 1, 1]],
    ["late_pay", [0, 0, 1, 0, 0, 0]],
  ];
  for (const [issue, counts] of issueByWeek) {
    counts.forEach((count, wi) => {
      const pool = reviews.map((rv, i) => (rv.week === weeks[wi] ? i : -1)).filter((i) => i >= 0);
      for (let k = 0; k < count; k++) {
        const idx = pool.splice(Math.floor(r() * pool.length), 1)[0];
        if (idx !== undefined) reviews[idx]!.issues.push(issue);
      }
    });
  }
  const tagQuota: Array<[PositiveTag, number]> = [["on_time", 38], ["friendly", 21], ["instructions", 11], ["again", 9], ["paid", 6], ["breaks", 4], ["fair", 2]];
  for (const [tag, count] of tagQuota) {
    const pool = reviews.map((_, i) => i);
    for (let k = 0; k < count; k++) {
      const idx = pool.splice(Math.floor(r() * pool.length), 1)[0];
      if (idx !== undefined) reviews[idx]!.tags.push(tag);
    }
  }
  reviews.forEach((rv) => {
    rv.stars = rv.issues.length >= 2 ? 3 : rv.issues.length === 1 ? (r() < 0.5 ? 3 : 4) : r() < 0.7 ? 5 : 4;
  });
  // Past workers with a name on file review like everyone else.
  for (const x of workers) {
    if (x.past) reviews.push({ workerId: x.id, week: weekStart(x.past.lastWorked), stars: x.past.stars, tags: x.past.stars >= 4 ? ["on_time"] : [], issues: x.past.stars <= 2 ? ["too_busy"] : [] });
  }

  // Anonymous pool of workers nearby (only ever reported as counts).
  const pr = rng(region === "sf" ? 101 : 202);
  const roles: Role[] = ["register", "barista", "hall", "kitchen", "dish", "stock"];
  const pool: PoolWorker[] = Array.from({ length: 64 }, (_, i) => {
    const mine = roles.filter(() => pr() < 0.35);
    if (mine.length === 0) mine.push(roles[i % roles.length] ?? "register");
    const free: PoolWorker["free"] = [];
    for (let d = 0; d <= 7; d++) {
      if (pr() < 0.45) free.push({ date: day(d), start: pr() < 0.5 ? "07:00" : "11:00", end: pr() < 0.6 ? "22:00" : "17:00" });
    }
    const booked: Record<string, number> = {};
    for (const f of free) if (pr() < 0.3) booked[f.date] = pr() < 0.5 ? 240 : 360;
    return { id: `p-${i}`, roles: mine, free, booked, dailyCapMinutes: pr() < 0.4 ? 360 : 480 };
  });

  return {
    region,
    timeZone,
    today,
    now,
    profile: { ...t.profile },
    staff: t.staff.map(([name, role], i) => ({ id: `staff-${i + 1}`, name, role, email: region === "sf" ? `${["alex", "jordan", "riley"][i]}@sunnyside.example.com` : `${["mori", "tanaka", "sato"][i]}@komorebi.example.com` })),
    notifications: { from: "08:00", to: "21:00", newApplicants: true, chats: true, attendance: true, weeklyReport: true },
    faq: { ...t.faq },
    jobs,
    workers,
    applications,
    shifts,
    events,
    threads,
    reviews,
    invites,
    pool,
  };
}
