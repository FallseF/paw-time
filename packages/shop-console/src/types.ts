/**
 * Shapes the shop (employer) console works with. Everything a shop can read is a *View*;
 * internal records (worker profiles, raw review responses) never leave the store.
 */

export type Region = "sf" | "jp";
export type Locale = "en" | "ja";
export type Currency = "USD" | "JPY";

export type Role = "register" | "barista" | "hall" | "kitchen" | "dish" | "stock";
export type PayStyle = "same_day" | "weekly" | "monthly";
export type JobStatus = "draft" | "published" | "closed";

export type PositiveTag = "on_time" | "breaks" | "instructions" | "paid" | "friendly" | "fair" | "again";
export type LandmarkId =
  | "clock_tower"
  | "rest_grove"
  | "guide_post"
  | "payday_bell"
  | "lantern_path"
  | "fair_fountain"
  | "welcome_arch";
export type IssueId = "no_break" | "left_late" | "unclear" | "too_busy" | "late_pay" | "rude";

export type JobSlot = {
  id: string;
  date: string;
  start: string;
  end: string;
  capacity: number;
};

export type Job = {
  id: string;
  title: string;
  role: Role;
  status: JobStatus;
  wage: number;
  payStyle: PayStyle;
  dressCode: string;
  notes: string;
  slots: JobSlot[];
  urgent: boolean;
  createdAt: string;
  updatedAt: string;
};

export type JobInput = {
  id?: string | undefined;
  title: string;
  role: Role;
  status: JobStatus;
  wage: number;
  payStyle: PayStyle;
  dressCode: string;
  notes: string;
  slots: Array<Omit<JobSlot, "id"> & { id?: string | undefined }>;
};

export type SlotView = JobSlot & { accepted: number; applied: number; open: number };
export type JobView = Omit<Job, "slots"> & {
  slots: SlotView[];
  capacity: number;
  accepted: number;
  applied: number;
  firstDate: string | null;
  lastDate: string | null;
};

export type FieldError = { field: string; code: string; minimum?: number };

/** A skill badge the worker chose to show: "Register ★2 · 3 shifts". */
export type SkillBadge = { role: Role; level: 1 | 2 | 3; shifts: number };
/** On-time record the worker chose to show: arrived on time for `onTime` of `total` shifts. */
export type OnTimeRecord = { onTime: number; total: number };

export type CatLook = { name: string; color: string };

export type ApplicationStatus = "applied" | "accepted" | "declined" | "withdrawn";

/** Everything a shop can see about one applicant. Only what the worker shared; no score, no rank. */
export type ApplicantView = {
  applicationId: string;
  jobId: string;
  slotId: string;
  workerId: string;
  displayName: string;
  cat: CatLook;
  status: ApplicationStatus;
  appliedAt: string;
  decidedAt: string | null;
  note: string | null;
  firstTimeHere: boolean;
  shared: { badges: SkillBadge[] | null; onTime: OnTimeRecord | null };
  canMessage: boolean;
  threadId: string | null;
};

export type ShiftStatus = "scheduled" | "on_the_way" | "running_late" | "checked_in" | "checked_out" | "no_show";

export type AttendanceKind = "on_the_way" | "running_late" | "check_in" | "check_out" | "no_show" | "correction";
export type AttendanceEvent = {
  id: string;
  shiftId: string;
  kind: AttendanceKind;
  /** When it happened (for corrections: the corrected time). */
  at: string;
  /** When it was written down. Never changes. */
  recordedAt: string;
  by: string;
  source: "worker" | "staff" | "system";
  field?: "check_in" | "check_out";
  previous?: string | null;
  reason?: string;
  minutesLate?: number;
};

export type ShiftView = {
  id: string;
  jobId: string;
  jobTitle: string;
  role: Role;
  slotId: string;
  workerId: string;
  displayName: string;
  cat: CatLook;
  date: string;
  start: string;
  end: string;
  startAt: string;
  endAt: string;
  status: ShiftStatus;
  checkInAt: string | null;
  checkOutAt: string | null;
  minutesLate: number | null;
  corrected: boolean;
  threadId: string | null;
};

export type MessageFrom = "worker" | "auto" | "staff" | "system";
export type TemplateKind = "late" | "swap" | "thanks";
export type Message = {
  id: string;
  from: MessageFrom;
  text: string;
  sentAt: string;
  deliverAt: string;
  status: "delivered" | "queued";
  staffName?: string;
  template?: TemplateKind;
  faqKey?: FaqKey;
};

export type ThreadView = {
  id: string;
  workerId: string;
  displayName: string;
  cat: CatLook;
  kind: "shift" | "invite";
  shiftId: string | null;
  /** What the chat is about: the accepted shift or the invited slot. */
  context: { jobTitle: string; date: string; start: string; end: string } | null;
  messages: Message[];
  unread: number;
  lastAt: string;
  needsStaff: boolean;
  reported: boolean;
  blocked: boolean;
  canMessage: boolean;
};

export type FaqKey = "dressCode" | "entrance" | "breaks" | "contactName";
export type Faq = Record<FaqKey, string>;

export type LandmarkView = {
  tag: PositiveTag;
  id: LandmarkId;
  votes: number;
  level: 0 | 1 | 2 | 3;
  sprout: boolean;
  nextAt: number | null;
};

export type IslandView = { landmarks: LandmarkView[]; basedOn: number; totalLevel: number };

export type IssueRow = {
  issue: IssueId;
  workers: number;
  trend: Array<{ week: string; workers: number | null }>;
  action: string;
};
export type ImprovementReport = {
  threshold: number;
  weeks: string[];
  status: "ready" | "not_enough";
  issues: IssueRow[];
};

/** A count shown to a shop. `null` means fewer than 5 people and is shown as "Fewer than 5". */
export type AggregateCount = number | null;

export type UrgentReach = {
  available: AggregateCount;
  skilled: AggregateCount;
  underCap: AggregateCount;
};

export type InviteCandidate = {
  workerId: string;
  displayName: string;
  cat: CatLook;
  lastWorked: string;
  shiftsHere: number;
  roles: Role[];
  invitedAt: string | null;
};

export type InvitesView = {
  eligible: AggregateCount;
  contactable: InviteCandidate[];
  sent: Array<{ id: string; workerId: string; displayName: string; jobId: string; slotId: string; sentAt: string; deliverAt: string; status: "delivered" | "queued" }>;
};

export type StaffMember = { id: string; name: string; role: "owner" | "manager" | "staff"; email: string };

export type ShopProfile = {
  name: string;
  area: string;
  signColor: string;
  values: string;
  kind: string;
};

export type NotificationSettings = {
  from: string;
  to: string;
  newApplicants: boolean;
  chats: boolean;
  attendance: boolean;
  weeklyReport: boolean;
};

export type SettingsView = {
  profile: ShopProfile;
  staff: StaffMember[];
  notifications: NotificationSettings;
  faq: Faq;
  region: Region;
  timeZone: string;
  currency: Currency;
};

export type Alert = {
  id: string;
  kind: "short_staffed" | "running_late" | "unanswered";
  jobId?: string;
  slotId?: string;
  date?: string;
  start?: string;
  end?: string;
  short?: number;
  threadId?: string;
  shiftId?: string;
  displayName?: string;
  count?: number;
};

export type TodayView = {
  date: string;
  now: string;
  shifts: ShiftView[];
  openSlots: Array<{ job: JobView; slot: SlotView }>;
  unreadChats: ThreadView[];
  newApplicants: ApplicantView[];
  alerts: Alert[];
  island: IslandView;
};
