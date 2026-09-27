/**
 * In-memory shop console. The API keeps one per organization; the web console keeps one in
 * the browser. Every public method returns views built for a shop: only what workers shared,
 * counts under 5 hidden, no scores or rankings of individual workers.
 */
import {
  REGIONS,
  aggregate,
  buildImprovementReport,
  buildIsland,
  checkMinimumWage,
  shopMessageDelivery,
  urgentReach,
  validateJob,
} from "./rules";
import { monthPayroll as buildMonthPayroll } from "./payroll";
import type { MonthPayroll } from "./payroll";
import { createSample } from "./sample";
import type { ApplicationRecord, SampleData, ThreadRecord, WorkerRecord } from "./sample";
import { addDays, minutesOf, weekStart, zonedParts, zonedToUtc } from "./time";
import type {
  Alert,
  ApplicantView,
  AttendanceEvent,
  Faq,
  FieldError,
  ImprovementReport,
  InvitesView,
  IslandView,
  Job,
  JobInput,
  JobStatus,
  JobView,
  Message,
  NotificationSettings,
  Region,
  SettingsView,
  ShiftStatus,
  ShiftView,
  ShopProfile,
  SlotView,
  StaffMember,
  TemplateKind,
  ThreadView,
  TodayView,
  UrgentReach,
} from "./types";

export type Result<T> = { ok: true; data: T } | { ok: false; error: string; errors?: FieldError[] };

const LATE_GRACE_MINUTES = 5;
const MESSAGE_WINDOW_DAYS = 7;

let idCounter = 0;
const newId = (prefix: string) => `${prefix}-${Date.now().toString(36)}${(++idCounter).toString(36)}`;

export class ShopConsoleStore {
  readonly region: Region;
  readonly timeZone: string;
  private readonly data: SampleData;
  private readonly clock: () => Date;
  private urgentPosts: Array<{ jobId: string; slotId: string; sentAt: string; reach: UrgentReach }> = [];

  /**
   * `clock` defaults to the sample shop clock: today at 14:20 local time, moving forward in
   * real time from when the store was created.
   */
  constructor(region: Region, options: { realNow?: Date; clock?: () => Date } = {}) {
    const realNow = options.realNow ?? new Date();
    this.region = region;
    this.timeZone = REGIONS[region].timeZone;
    this.data = createSample(region, realNow);
    const start = Date.parse(this.data.now);
    const bootReal = Date.now();
    this.clock = options.clock ?? (() => new Date(start + (Date.now() - bootReal)));
  }

  now(): Date {
    return this.clock();
  }

  today(): string {
    return zonedParts(this.now(), this.timeZone).date;
  }

  // ------------------------------------------------------------ helpers

  private worker(id: string): WorkerRecord | undefined {
    return this.data.workers.find((w) => w.id === id);
  }

  private at(date: string, time: string): string {
    return zonedToUtc(date, time, this.timeZone).toISOString();
  }

  private localTime(iso: string): string {
    const p = zonedParts(new Date(iso), this.timeZone);
    return `${String(p.hour).padStart(2, "0")}:${String(p.minute).padStart(2, "0")}`;
  }

  private slotView(job: Job, slot: Job["slots"][number]): SlotView {
    const apps = this.data.applications.filter((a) => a.slotId === slot.id);
    const accepted = apps.filter((a) => a.status === "accepted").length;
    return { ...slot, accepted, applied: apps.filter((a) => a.status === "applied").length, open: Math.max(0, slot.capacity - accepted) };
  }

  private jobView(job: Job): JobView {
    const slots = job.slots.map((s) => this.slotView(job, s));
    const dates = slots.map((s) => s.date).sort();
    return {
      ...job,
      slots,
      capacity: slots.reduce((n, s) => n + s.capacity, 0),
      accepted: slots.reduce((n, s) => n + s.accepted, 0),
      applied: slots.reduce((n, s) => n + s.applied, 0),
      firstDate: dates[0] ?? null,
      lastDate: dates.at(-1) ?? null,
    };
  }

  /** A shop may message a worker only about an accepted shift (recent or upcoming) or an invite. */
  canMessage(workerId: string): boolean {
    if (this.data.threads.some((t) => t.workerId === workerId && t.blocked)) return false;
    const since = addDays(this.today(), -MESSAGE_WINDOW_DAYS);
    const shift = this.data.shifts.some((s) => s.workerId === workerId && s.date >= since);
    const invite = this.data.invites.some((i) => i.workerId === workerId);
    return shift || invite;
  }

  private applicantView(a: ApplicationRecord): ApplicantView | null {
    const w = this.worker(a.workerId);
    if (!w) return null;
    const thread = this.data.threads.find((t) => t.workerId === w.id);
    // Build the object field by field: nothing from the worker record is spread in.
    return {
      applicationId: a.id,
      jobId: a.jobId,
      slotId: a.slotId,
      workerId: w.id,
      displayName: w.displayName,
      cat: { name: w.cat.name, color: w.cat.color },
      status: a.status,
      appliedAt: a.appliedAt,
      decidedAt: a.decidedAt,
      note: a.note,
      firstTimeHere: w.past === null,
      shared: {
        badges: w.shareBadges ? w.badges.map((b) => ({ role: b.role, level: b.level, shifts: b.shifts })) : null,
        onTime: w.shareOnTime ? { onTime: w.onTime.onTime, total: w.onTime.total } : null,
      },
      canMessage: a.status === "accepted" && this.canMessage(w.id),
      threadId: thread?.id ?? null,
    };
  }

  private shiftView(s: SampleData["shifts"][number]): ShiftView | null {
    const w = this.worker(s.workerId);
    const job = this.data.jobs.find((j) => j.id === s.jobId);
    if (!w || !job) return null;
    const events = this.data.events.filter((e) => e.shiftId === s.id).sort((a, b) => a.recordedAt.localeCompare(b.recordedAt));
    const latest = (field: "check_in" | "check_out") => {
      let value: string | null = null;
      for (const e of events) {
        if (e.kind === field) value = e.at;
        if (e.kind === "correction" && e.field === field) value = e.at;
      }
      return value;
    };
    const checkInAt = latest("check_in");
    const checkOutAt = latest("check_out");
    const lastNoShow = [...events].reverse().find((e) => e.kind === "no_show");
    const inAfterNoShow = lastNoShow ? events.some((e) => e.recordedAt > lastNoShow.recordedAt && (e.kind === "check_in" || (e.kind === "correction" && e.field === "check_in"))) : false;
    const startAt = this.at(s.date, s.start);
    let status: ShiftStatus = "scheduled";
    if (lastNoShow && !inAfterNoShow) status = "no_show";
    else if (checkOutAt) status = "checked_out";
    else if (checkInAt) status = "checked_in";
    else if (events.some((e) => e.kind === "running_late")) status = "running_late";
    else if (events.some((e) => e.kind === "on_the_way")) status = "on_the_way";
    const late = checkInAt ? Math.max(0, Math.round((Date.parse(checkInAt) - Date.parse(startAt)) / 60_000)) : null;
    const thread = this.data.threads.find((t) => t.workerId === w.id);
    return {
      id: s.id,
      jobId: job.id,
      jobTitle: job.title,
      role: job.role,
      slotId: s.slotId,
      workerId: w.id,
      displayName: w.displayName,
      cat: { name: w.cat.name, color: w.cat.color },
      date: s.date,
      start: s.start,
      end: s.end,
      startAt,
      endAt: this.at(s.date, s.end),
      status,
      checkInAt: status === "no_show" ? null : checkInAt,
      checkOutAt: status === "no_show" ? null : checkOutAt,
      minutesLate: late === null ? null : late > LATE_GRACE_MINUTES ? late : 0,
      corrected: events.some((e) => e.kind === "correction"),
      threadId: thread?.id ?? null,
    };
  }

  private threadView(t: ThreadRecord): ThreadView | null {
    const w = this.worker(t.workerId);
    if (!w) return null;
    const now = this.now().toISOString();
    const visible = t.messages.map((m) => (m.status === "queued" && m.deliverAt <= now ? { ...m, status: "delivered" as const } : m));
    const incoming = visible.filter((m) => m.from === "worker");
    const last = visible.at(-1);
    const shift = t.shiftId ? this.data.shifts.find((s) => s.id === t.shiftId) : undefined;
    const job = shift ? this.data.jobs.find((j) => j.id === shift.jobId) : undefined;
    const invite = t.inviteId ? this.data.invites.find((i) => i.id === t.inviteId) : undefined;
    const inviteJob = invite ? this.data.jobs.find((j) => j.id === invite.jobId) : undefined;
    const inviteSlot = inviteJob?.slots.find((s) => s.id === invite?.slotId);
    const context = shift && job
      ? { jobTitle: job.title, date: shift.date, start: shift.start, end: shift.end }
      : inviteJob && inviteSlot
        ? { jobTitle: inviteJob.title, date: inviteSlot.date, start: inviteSlot.start, end: inviteSlot.end }
        : null;
    return {
      id: t.id,
      workerId: w.id,
      displayName: w.displayName,
      cat: { name: w.cat.name, color: w.cat.color },
      kind: t.kind,
      shiftId: t.shiftId,
      context,
      messages: visible,
      unread: incoming.filter((m) => m.sentAt > t.readAt).length,
      lastAt: last?.sentAt ?? t.readAt,
      needsStaff: last?.from === "worker" && last.template !== "thanks",
      reported: t.reported,
      blocked: t.blocked,
      canMessage: !t.blocked && this.canMessage(w.id),
    };
  }

  // ------------------------------------------------------------ jobs

  jobs(): JobView[] {
    const order: Record<JobStatus, number> = { published: 0, draft: 1, closed: 2 };
    return this.data.jobs
      .map((j) => this.jobView(j))
      .sort((a, b) => order[a.status] - order[b.status] || (a.firstDate ?? "").localeCompare(b.firstDate ?? ""));
  }

  job(id: string): JobView | null {
    const j = this.data.jobs.find((x) => x.id === id);
    return j ? this.jobView(j) : null;
  }

  checkWage(wage: number, dates: string[]) {
    return checkMinimumWage(wage, this.region, dates);
  }

  saveJob(input: JobInput, options: { urgent?: boolean } = {}): Result<JobView> {
    const errors = validateJob(input, this.region);
    if (errors.length) return { ok: false, error: "invalid_job", errors };
    const now = this.now().toISOString();
    const existing = input.id ? this.data.jobs.find((j) => j.id === input.id) : undefined;
    if (input.id && !existing) return { ok: false, error: "job_not_found" };
    const id = existing?.id ?? newId("job");
    const slots = input.slots.map((s, i) => ({
      id: s.id && existing?.slots.some((x) => x.id === s.id) ? s.id : `${id}-n${i + 1}-${(++idCounter).toString(36)}`,
      date: s.date,
      start: s.start,
      end: s.end,
      capacity: s.capacity,
    }));
    if (existing) {
      for (const slot of existing.slots) {
        const keeps = slots.find((s) => s.id === slot.id);
        const accepted = this.data.applications.filter((a) => a.slotId === slot.id && a.status === "accepted").length;
        if (accepted > 0 && (!keeps || keeps.capacity < accepted)) {
          return { ok: false, error: "slot_has_accepted_workers", errors: [{ field: "slots", code: "has_accepted" }] };
        }
      }
    }
    const job: Job = {
      id,
      title: input.title.trim(),
      role: input.role,
      status: input.status,
      wage: input.wage,
      payStyle: input.payStyle,
      dressCode: input.dressCode.trim(),
      notes: input.notes.trim(),
      slots,
      urgent: options.urgent ?? existing?.urgent ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };
    if (existing) Object.assign(existing, job);
    else this.data.jobs.push(job);
    return { ok: true, data: this.jobView(job) };
  }

  setJobStatus(id: string, status: JobStatus): Result<JobView> {
    const job = this.data.jobs.find((j) => j.id === id);
    if (!job) return { ok: false, error: "job_not_found" };
    if (status === "published") {
      const errors = validateJob({ ...job, slots: job.slots }, this.region);
      if (errors.length) return { ok: false, error: "invalid_job", errors };
    }
    job.status = status;
    job.updatedAt = this.now().toISOString();
    return { ok: true, data: this.jobView(job) };
  }

  /** Counts only. A slot reaches workers who are free, have the skill and are under their cap. */
  urgentReach(role: Job["role"], slot: { date: string; start: string; end: string }): UrgentReach {
    const raw = urgentReach(this.data.pool, role, slot);
    return { available: aggregate(raw.available), skilled: aggregate(raw.skilled), underCap: aggregate(raw.underCap) };
  }

  sendUrgent(jobId: string, slotId: string): Result<{ job: JobView; reach: UrgentReach }> {
    const job = this.data.jobs.find((j) => j.id === jobId);
    const slot = job?.slots.find((s) => s.id === slotId);
    if (!job || !slot) return { ok: false, error: "slot_not_found" };
    if (job.status !== "published") return { ok: false, error: "job_not_published" };
    const reach = this.urgentReach(job.role, slot);
    job.urgent = true;
    this.urgentPosts.push({ jobId, slotId, sentAt: this.now().toISOString(), reach });
    return { ok: true, data: { job: this.jobView(job), reach } };
  }

  postUrgentShift(input: JobInput): Result<{ job: JobView; reach: UrgentReach }> {
    const saved = this.saveJob({ ...input, status: "published" }, { urgent: true });
    if (!saved.ok) return saved;
    const slot = saved.data.slots[0];
    if (!slot) return { ok: false, error: "slot_not_found" };
    return this.sendUrgent(saved.data.id, slot.id);
  }

  urgentHistory() {
    return this.urgentPosts.map((p) => ({ ...p }));
  }

  // ------------------------------------------------------------ applicants

  applicants(jobId?: string): ApplicantView[] {
    return this.data.applications
      .filter((a) => !jobId || a.jobId === jobId)
      .map((a) => this.applicantView(a))
      .filter((a): a is ApplicantView => a !== null)
      .sort((a, b) => b.appliedAt.localeCompare(a.appliedAt));
  }

  decide(applicationId: string, decision: "accepted" | "declined"): Result<ApplicantView> {
    const a = this.data.applications.find((x) => x.id === applicationId);
    if (!a) return { ok: false, error: "application_not_found" };
    if (a.status !== "applied") return { ok: false, error: "already_decided" };
    const job = this.data.jobs.find((j) => j.id === a.jobId);
    const slot = job?.slots.find((s) => s.id === a.slotId);
    if (!job || !slot) return { ok: false, error: "slot_not_found" };
    if (decision === "accepted" && this.slotView(job, slot).open <= 0) return { ok: false, error: "slot_full" };
    a.status = decision;
    a.decidedAt = this.now().toISOString();
    if (decision === "accepted") {
      this.data.shifts.push({ id: newId("shift"), jobId: job.id, slotId: slot.id, workerId: a.workerId, date: slot.date, start: slot.start, end: slot.end });
    }
    const view = this.applicantView(a);
    return view ? { ok: true, data: view } : { ok: false, error: "worker_not_found" };
  }

  // ------------------------------------------------------------ shifts & attendance

  shifts(from: string, to: string): ShiftView[] {
    return this.data.shifts
      .filter((s) => s.date >= from && s.date <= to)
      .map((s) => this.shiftView(s))
      .filter((s): s is ShiftView => s !== null)
      .sort((a, b) => a.startAt.localeCompare(b.startAt) || a.displayName.localeCompare(b.displayName));
  }

  shift(id: string): ShiftView | null {
    const s = this.data.shifts.find((x) => x.id === id);
    return s ? this.shiftView(s) : null;
  }

  /** The append-only log, newest first. Nothing is ever edited or removed. */
  attendanceLog(shiftId?: string): Array<AttendanceEvent & { displayName: string; date: string }> {
    return this.data.events
      .filter((e) => !shiftId || e.shiftId === shiftId)
      .map((e) => {
        const s = this.data.shifts.find((x) => x.id === e.shiftId);
        return { ...e, displayName: (s && this.worker(s.workerId)?.displayName) ?? "", date: s?.date ?? "" };
      })
      .sort((a, b) => b.recordedAt.localeCompare(a.recordedAt));
  }

  recordAttendance(shiftId: string, kind: "check_in" | "check_out", by: string): Result<ShiftView> {
    const view = this.shift(shiftId);
    if (!view) return { ok: false, error: "shift_not_found" };
    if (kind === "check_in" && (view.checkInAt || view.status === "no_show")) return { ok: false, error: "already_checked_in" };
    if (kind === "check_out" && (!view.checkInAt || view.checkOutAt)) return { ok: false, error: "not_checked_in" };
    const now = this.now().toISOString();
    this.data.events.push({ id: newId("ev"), shiftId, kind, at: now, recordedAt: now, by, source: "staff" });
    return { ok: true, data: this.shift(shiftId) as ShiftView };
  }

  markNoShow(shiftId: string, reason: string, by: string): Result<ShiftView> {
    const view = this.shift(shiftId);
    if (!view) return { ok: false, error: "shift_not_found" };
    if (!reason.trim()) return { ok: false, error: "reason_required" };
    if (view.checkInAt) return { ok: false, error: "already_checked_in" };
    if (view.status === "no_show") return { ok: false, error: "already_no_show" };
    if (this.now().toISOString() < view.startAt) return { ok: false, error: "not_started" };
    const now = this.now().toISOString();
    this.data.events.push({ id: newId("ev"), shiftId, kind: "no_show", at: now, recordedAt: now, by, source: "staff", reason: reason.trim() });
    return { ok: true, data: this.shift(shiftId) as ShiftView };
  }

  /** Adds a correction. The original punch stays in the log with the reason, who and when. */
  correct(shiftId: string, field: "check_in" | "check_out", time: string, reason: string, by: string): Result<ShiftView> {
    const view = this.shift(shiftId);
    if (!view) return { ok: false, error: "shift_not_found" };
    if (!reason.trim()) return { ok: false, error: "reason_required", errors: [{ field: "reason", code: "required" }] };
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) return { ok: false, error: "invalid_time", errors: [{ field: "time", code: "invalid" }] };
    const at = this.at(view.date, time);
    const inAt = field === "check_in" ? at : view.checkInAt;
    const outAt = field === "check_out" ? at : view.checkOutAt;
    if (inAt && outAt && outAt <= inAt) return { ok: false, error: "out_before_in", errors: [{ field: "time", code: "out_before_in" }] };
    const now = this.now().toISOString();
    this.data.events.push({
      id: newId("ev"),
      shiftId,
      kind: "correction",
      field,
      at,
      previous: field === "check_in" ? view.checkInAt : view.checkOutAt,
      recordedAt: now,
      by,
      source: "staff",
      reason: reason.trim(),
    });
    return { ok: true, data: this.shift(shiftId) as ShiftView };
  }

  /** Labor cost for a month ("YYYY-MM"), priced from each job's hourly wage. */
  monthPayroll(month: string): MonthPayroll {
    const wages = new Map(this.data.jobs.map((j) => [j.id, j.wage]));
    return buildMonthPayroll(month, this.shifts(`${month}-01`, `${month}-31`), (id) => wages.get(id) ?? 0, REGIONS[this.region].currency, this.now());
  }

  // ------------------------------------------------------------ chat

  threads(): ThreadView[] {
    return this.data.threads
      .map((t) => this.threadView(t))
      .filter((t): t is ThreadView => t !== null)
      .sort((a, b) => b.lastAt.localeCompare(a.lastAt));
  }

  thread(id: string): ThreadView | null {
    const t = this.data.threads.find((x) => x.id === id);
    return t ? this.threadView(t) : null;
  }

  markRead(id: string): void {
    const t = this.data.threads.find((x) => x.id === id);
    if (t) t.readAt = this.now().toISOString();
  }

  /** Opens (or finds) the thread with a worker. Refused without an accepted shift or invite. */
  openThread(workerId: string): Result<ThreadView> {
    const existing = this.data.threads.find((t) => t.workerId === workerId);
    if (existing) return { ok: true, data: this.threadView(existing) as ThreadView };
    if (!this.canMessage(workerId)) return { ok: false, error: "no_accepted_shift_or_invite" };
    const today = this.today();
    const shift = this.data.shifts
      .filter((s) => s.workerId === workerId && s.date >= today)
      .sort((a, b) => a.date.localeCompare(b.date))[0];
    const t: ThreadRecord = { id: newId("th"), workerId, kind: "shift", shiftId: shift?.id ?? null, inviteId: null, messages: [], readAt: this.now().toISOString(), reported: false, blocked: false };
    this.data.threads.push(t);
    return { ok: true, data: this.threadView(t) as ThreadView };
  }

  /** A staff message. Outside 8:00–21:00 shop time it is queued and delivered at 8:00. */
  sendMessage(threadId: string, text: string, staffName: string, template?: TemplateKind): Result<Message> {
    const t = this.data.threads.find((x) => x.id === threadId);
    if (!t) return { ok: false, error: "thread_not_found" };
    if (t.blocked) return { ok: false, error: "blocked" };
    if (!this.canMessage(t.workerId)) return { ok: false, error: "no_accepted_shift_or_invite" };
    const body = text.trim();
    if (!body) return { ok: false, error: "empty" };
    if (body.length > 1000) return { ok: false, error: "too_long" };
    if (/(\+?\d[\d\s().-]{8,}\d)/.test(body)) return { ok: false, error: "no_phone_numbers" };
    const sent = this.now();
    const delivery = shopMessageDelivery(sent, this.timeZone);
    const m: Message = { id: newId("m"), from: "staff", text: body, sentAt: sent.toISOString(), deliverAt: delivery.deliverAt, status: delivery.status, staffName };
    if (template) m.template = template;
    t.messages.push(m);
    t.readAt = sent.toISOString();
    return { ok: true, data: m };
  }

  report(threadId: string): Result<ThreadView> {
    const t = this.data.threads.find((x) => x.id === threadId);
    if (!t) return { ok: false, error: "thread_not_found" };
    t.reported = true;
    return { ok: true, data: this.threadView(t) as ThreadView };
  }

  setBlocked(threadId: string, blocked: boolean): Result<ThreadView> {
    const t = this.data.threads.find((x) => x.id === threadId);
    if (!t) return { ok: false, error: "thread_not_found" };
    t.blocked = blocked;
    return { ok: true, data: this.threadView(t) as ThreadView };
  }

  faq(): Faq {
    return { ...this.data.faq };
  }

  updateFaq(faq: Partial<Faq>): Faq {
    for (const [k, v] of Object.entries(faq)) {
      if (typeof v === "string" && k in this.data.faq) this.data.faq[k as keyof Faq] = v.slice(0, 400);
    }
    return this.faq();
  }

  // ------------------------------------------------------------ reviews

  island(): IslandView {
    const votes = this.data.reviews.flatMap((r) => r.tags.map((tag) => ({ workerId: r.workerId, tag })));
    return buildIsland(votes, new Set(this.data.reviews.map((r) => r.workerId)).size);
  }

  improvementReport(): ImprovementReport {
    const thisWeek = weekStart(this.today());
    const weeks = Array.from({ length: 6 }, (_, i) => addDays(thisWeek, -7 * (5 - i)));
    const responses = this.data.reviews.flatMap((r) => r.issues.map((issue) => ({ workerId: r.workerId, issue, week: r.week })));
    return buildImprovementReport(responses, weeks);
  }

  // ------------------------------------------------------------ invites

  invites(): InvitesView {
    const eligibleIds = new Set(this.data.reviews.filter((r) => r.stars >= 4).map((r) => r.workerId));
    const contactable = this.data.workers
      .filter((w) => w.past && w.past.stars >= 4 && w.past.allowContact)
      .map((w) => {
        const last = this.data.invites.filter((i) => i.workerId === w.id).map((i) => i.sentAt).sort().at(-1) ?? null;
        return {
          workerId: w.id,
          displayName: w.displayName,
          cat: { name: w.cat.name, color: w.cat.color },
          lastWorked: w.past?.lastWorked ?? "",
          shiftsHere: w.past?.shifts ?? 0,
          roles: [...(w.past?.roles ?? [])],
          invitedAt: last,
        };
      })
      .sort((a, b) => b.lastWorked.localeCompare(a.lastWorked));
    const sent = this.data.invites
      .map((i) => ({ ...i, displayName: this.worker(i.workerId)?.displayName ?? "" }))
      .map(({ id, workerId, displayName, jobId, slotId, sentAt, deliverAt, status }) => ({
        id, workerId, displayName, jobId, slotId, sentAt, deliverAt,
        status: status === "queued" && deliverAt <= this.now().toISOString() ? ("delivered" as const) : status,
      }))
      .sort((a, b) => b.sentAt.localeCompare(a.sentAt));
    return { eligible: aggregate(eligibleIds.size), contactable, sent };
  }

  sendInvite(workerId: string, jobId: string, slotId: string, staffName: string, text: string): Result<InvitesView> {
    const w = this.worker(workerId);
    if (!w?.past || w.past.stars < 4 || !w.past.allowContact) return { ok: false, error: "not_invitable" };
    const job = this.data.jobs.find((j) => j.id === jobId);
    const slot = job?.slots.find((s) => s.id === slotId);
    if (!job || !slot || job.status !== "published") return { ok: false, error: "slot_not_found" };
    if (this.data.threads.some((t) => t.workerId === workerId && t.blocked)) return { ok: false, error: "blocked" };
    const sent = this.now();
    const delivery = shopMessageDelivery(sent, this.timeZone);
    const id = newId("inv");
    this.data.invites.push({ id, workerId, jobId, slotId, sentAt: sent.toISOString(), deliverAt: delivery.deliverAt, status: delivery.status });
    const m: Message = { id: newId("m"), from: "staff", text: text.trim() || job.title, sentAt: sent.toISOString(), deliverAt: delivery.deliverAt, status: delivery.status, staffName };
    const existing = this.data.threads.find((t) => t.workerId === workerId);
    if (existing) existing.messages.push(m);
    else this.data.threads.push({ id: newId("th"), workerId, kind: "invite", shiftId: null, inviteId: id, messages: [m], readAt: sent.toISOString(), reported: false, blocked: false });
    return { ok: true, data: this.invites() };
  }

  // ------------------------------------------------------------ settings

  settings(): SettingsView {
    const r = REGIONS[this.region];
    return {
      profile: { ...this.data.profile },
      staff: this.data.staff.map((s) => ({ ...s })),
      notifications: { ...this.data.notifications },
      faq: this.faq(),
      region: this.region,
      timeZone: r.timeZone,
      currency: r.currency,
    };
  }

  updateProfile(patch: Partial<ShopProfile>): Result<ShopProfile> {
    const next = { ...this.data.profile, ...patch };
    if (!next.name.trim()) return { ok: false, error: "invalid", errors: [{ field: "name", code: "required" }] };
    if (!/^#[0-9a-f]{6}$/i.test(next.signColor)) return { ok: false, error: "invalid", errors: [{ field: "signColor", code: "invalid" }] };
    if (next.values.length > 80) return { ok: false, error: "invalid", errors: [{ field: "values", code: "too_long" }] };
    this.data.profile = { ...next, name: next.name.trim(), values: next.values.trim(), area: next.area.trim() };
    return { ok: true, data: { ...this.data.profile } };
  }

  updateNotifications(patch: Partial<NotificationSettings>): Result<NotificationSettings> {
    const next = { ...this.data.notifications, ...patch };
    if (minutesOf(next.to) <= minutesOf(next.from)) return { ok: false, error: "invalid", errors: [{ field: "to", code: "before_start" }] };
    this.data.notifications = next;
    return { ok: true, data: { ...next } };
  }

  addStaff(name: string, role: StaffMember["role"], email: string): Result<StaffMember[]> {
    if (!name.trim()) return { ok: false, error: "invalid", errors: [{ field: "name", code: "required" }] };
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { ok: false, error: "invalid", errors: [{ field: "email", code: "invalid" }] };
    if (this.data.staff.some((s) => s.email.toLowerCase() === email.toLowerCase())) return { ok: false, error: "invalid", errors: [{ field: "email", code: "taken" }] };
    this.data.staff.push({ id: newId("staff"), name: name.trim(), role, email: email.trim() });
    return { ok: true, data: this.data.staff.map((s) => ({ ...s })) };
  }

  removeStaff(id: string): Result<StaffMember[]> {
    const s = this.data.staff.find((x) => x.id === id);
    if (!s) return { ok: false, error: "staff_not_found" };
    if (s.role === "owner") return { ok: false, error: "cannot_remove_owner" };
    this.data.staff = this.data.staff.filter((x) => x.id !== id);
    return { ok: true, data: this.data.staff.map((x) => ({ ...x })) };
  }

  // ------------------------------------------------------------ today

  todayView(): TodayView {
    const now = this.now();
    const today = this.today();
    const nowTime = this.localTime(now.toISOString());
    const shifts = this.shifts(today, today);
    const horizon = addDays(today, 7);
    const openSlots = this.data.jobs
      .filter((j) => j.status === "published")
      .flatMap((j) => {
        const job = this.jobView(j);
        return job.slots
          .filter((s) => s.open > 0 && s.date <= horizon && (s.date > today || (s.date === today && s.start > nowTime)))
          .map((slot) => ({ job, slot }));
      })
      .sort((a, b) => `${a.slot.date}${a.slot.start}`.localeCompare(`${b.slot.date}${b.slot.start}`));
    const alerts: Alert[] = [];
    for (const { job, slot } of openSlots) {
      if (slot.open >= 2) alerts.push({ id: `short-${slot.id}`, kind: "short_staffed", jobId: job.id, slotId: slot.id, date: slot.date, start: slot.start, end: slot.end, short: slot.open });
    }
    for (const s of shifts) {
      if (s.status === "running_late") alerts.push({ id: `late-${s.id}`, kind: "running_late", shiftId: s.id, displayName: s.displayName });
    }
    const threads = this.threads();
    const waiting = threads.filter((t) => t.needsStaff);
    if (waiting.length) alerts.push({ id: "unanswered", kind: "unanswered", count: waiting.length });
    const newApplicants = this.applicants().filter((a) => a.status === "applied");
    return {
      date: today,
      now: now.toISOString(),
      shifts,
      openSlots,
      unreadChats: threads.filter((t) => t.unread > 0 || t.needsStaff),
      newApplicants,
      alerts,
      island: this.island(),
    };
  }
}

export function createStore(region: Region, options: { realNow?: Date; clock?: () => Date } = {}): ShopConsoleStore {
  return new ShopConsoleStore(region, options);
}

export type { ApplicationRecord, ThreadRecord, WorkerRecord } from "./sample";
export type { Message } from "./types";
export type AttendanceLogEntry = ReturnType<ShopConsoleStore["attendanceLog"]>[number];
export type { AttendanceEvent };
