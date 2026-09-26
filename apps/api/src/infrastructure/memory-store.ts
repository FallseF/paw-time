import type {
  Application,
  ApplicationDecisionInput,
  AttendanceEvent,
  AttendanceSummary,
  CreateApplicationInput,
  CreateEvaluationInput,
  CreateJobPostingInput,
  Evaluation,
  GameWorld,
  JobPosting,
  RecordAttendanceInput,
  Shift,
} from "@paw-time/api-contracts";

const DEMO_ORGANIZATION_ID = "org-komorebi";
const PUNCTUAL_GRACE_MINUTES = 5;

export class MemoryStore {
  private readonly jobs: JobPosting[] = [
    {
      id: "job-komorebi-20261003",
      organizationId: DEMO_ORGANIZATION_ID,
      storeId: "store-komorebi",
      title: "カフェのホールスタッフ",
      description: "注文のお伺い、配膳、片付けをお願いします。",
      role: "hall",
      hourlyWage: 1300,
      startsAt: "2026-10-03T10:00:00+09:00",
      endsAt: "2026-10-03T15:00:00+09:00",
      capacity: 3,
      status: "published",
      createdAt: "2026-09-26T09:00:00+09:00",
    },
  ];

  private readonly applications: Application[] = [
    {
      id: "application-demo-1",
      organizationId: DEMO_ORGANIZATION_ID,
      jobPostingId: "job-komorebi-20261003",
      workerId: "worker-demo-mika",
      workerDisplayName: "みか",
      status: "applied",
      appliedAt: "2026-09-26T10:30:00+09:00",
      decidedAt: null,
    },
  ];

  private readonly attendanceEvents: AttendanceEvent[] = [];
  private readonly evaluations: Evaluation[] = [];
  private readonly shifts: Shift[] = [];
  private readonly worlds: GameWorld[] = [
    {
      id: "world-komorebi",
      ownerType: "organization",
      ownerId: DEMO_ORGANIZATION_ID,
      kind: "employer_house",
      level: 1,
      experience: 40,
      inventory: { house_empty_room: 1 },
      updatedAt: "2026-09-26T09:00:00+09:00",
    },
  ];

  listPublishedJobs(): JobPosting[] {
    return this.jobs.filter((job) => job.status === "published");
  }

  listOrganizationJobs(organizationId: string): JobPosting[] {
    return this.jobs.filter((job) => job.organizationId === organizationId);
  }

  createJob(organizationId: string, input: CreateJobPostingInput): JobPosting {
    const job: JobPosting = {
      ...input,
      id: crypto.randomUUID(),
      organizationId,
      createdAt: new Date().toISOString(),
    };
    this.jobs.push(job);
    if (job.status === "published") this.grantExperience("organization", organizationId, 5);
    return job;
  }

  listApplications(organizationId: string): Application[] {
    return this.applications.filter(
      (application) => application.organizationId === organizationId,
    );
  }

  applyForJob(workerId: string, input: CreateApplicationInput): Application | undefined {
    const job = this.jobs.find(
      (candidate) => candidate.id === input.jobPostingId && candidate.status === "published",
    );
    if (!job) return undefined;
    const existing = this.applications.find(
      (application) =>
        application.jobPostingId === input.jobPostingId && application.workerId === workerId,
    );
    if (existing) return existing;
    const application: Application = {
      id: crypto.randomUUID(),
      organizationId: job.organizationId,
      jobPostingId: job.id,
      workerId,
      workerDisplayName: input.workerDisplayName,
      status: "applied",
      appliedAt: new Date().toISOString(),
      decidedAt: null,
    };
    this.applications.push(application);
    return application;
  }

  decideApplication(
    organizationId: string,
    applicationId: string,
    input: ApplicationDecisionInput,
  ): Application | undefined {
    const application = this.applications.find(
      (candidate) =>
        candidate.id === applicationId && candidate.organizationId === organizationId,
    );
    if (!application || application.status !== "applied") return undefined;
    application.status = input.decision;
    application.decidedAt = new Date().toISOString();
    if (input.decision === "selected") {
      this.grantExperience("worker", application.workerId, 10);
      const job = this.jobs.find((candidate) => candidate.id === application.jobPostingId);
      if (job && !this.shifts.some((shift) => shift.applicationId === application.id)) {
        this.shifts.push({
          id: crypto.randomUUID(),
          organizationId,
          storeId: job.storeId,
          jobPostingId: job.id,
          applicationId: application.id,
          workerId: application.workerId,
          scheduledStartAt: job.startsAt,
          scheduledEndAt: job.endsAt,
          status: "scheduled",
        });
      }
    }
    return application;
  }

  listOrganizationShifts(organizationId: string): Shift[] {
    return this.shifts.filter((shift) => shift.organizationId === organizationId);
  }

  listWorkerShifts(workerId: string): Shift[] {
    return this.shifts.filter((shift) => shift.workerId === workerId);
  }

  recordAttendance(
    organizationId: string,
    shiftId: string,
    actorId: string,
    source: AttendanceEvent["source"],
    input: RecordAttendanceInput,
  ): AttendanceEvent | undefined {
    const shift = this.shifts.find(
      (candidate) => candidate.id === shiftId && candidate.organizationId === organizationId,
    );
    if (!shift) return undefined;
    const existing = this.attendanceEvents.find(
      (event) =>
        event.organizationId === organizationId &&
        event.clientRequestId === input.clientRequestId,
    );
    if (existing) return existing;
    if (input.kind === "check_in" && shift.status !== "scheduled") return undefined;
    if (input.kind === "check_out" && shift.status !== "checked_in") return undefined;

    const event: AttendanceEvent = {
      ...input,
      id: crypto.randomUUID(),
      organizationId,
      shiftId,
      actorId,
      source,
    };
    this.attendanceEvents.push(event);
    shift.status = event.kind === "check_in" ? "checked_in" : "checked_out";
    if (event.kind === "check_out") {
      this.grantExperience("organization", organizationId, 20);
    }
    return event;
  }

  getAttendanceSummary(
    organizationId: string,
    shiftId: string,
  ): AttendanceSummary | undefined {
    const shift = this.shifts.find(
      (candidate) => candidate.id === shiftId && candidate.organizationId === organizationId,
    );
    if (!shift) return undefined;
    const events = this.attendanceEvents.filter((event) => event.shiftId === shift.id);
    const checkIn = events.find((event) => event.kind === "check_in");
    const checkOut = [...events].reverse().find((event) => event.kind === "check_out");
    const lateMilliseconds = checkIn
      ? Math.max(0, Date.parse(checkIn.recordedAt) - Date.parse(shift.scheduledStartAt))
      : 0;
    const minutesLate = Math.ceil(lateMilliseconds / 60_000);
    return {
      shiftId: shift.id,
      scheduledStartAt: shift.scheduledStartAt,
      scheduledEndAt: shift.scheduledEndAt,
      actualCheckInAt: checkIn?.recordedAt ?? null,
      actualCheckOutAt: checkOut?.recordedAt ?? null,
      punctuality: !checkIn
        ? "pending"
        : minutesLate <= PUNCTUAL_GRACE_MINUTES
          ? "on_time"
          : "late",
      minutesLate,
    };
  }

  createEvaluation(
    organizationId: string,
    actorId: string,
    input: CreateEvaluationInput,
  ): Evaluation | undefined {
    const shift = this.shifts.find(
      (candidate) =>
        candidate.id === input.shiftId && candidate.organizationId === organizationId,
    );
    if (!shift) return undefined;
    if (input.subjectType === "worker" && input.subjectId !== shift.workerId) return undefined;
    if (input.subjectType === "store" && input.subjectId !== shift.storeId) return undefined;
    const existing = this.evaluations.find(
      (candidate) =>
        candidate.shiftId === input.shiftId &&
        candidate.authorId === actorId &&
        candidate.subjectType === input.subjectType &&
        candidate.subjectId === input.subjectId,
    );
    if (existing) return existing;
    const evaluation: Evaluation = {
      ...input,
      id: crypto.randomUUID(),
      organizationId,
      authorId: actorId,
      submittedAt: new Date().toISOString(),
    };
    this.evaluations.push(evaluation);
    this.grantExperience("organization", organizationId, 5);
    return evaluation;
  }

  getWorld(ownerType: GameWorld["ownerType"], ownerId: string): GameWorld {
    const existing = this.worlds.find(
      (world) => world.ownerType === ownerType && world.ownerId === ownerId,
    );
    if (existing) return existing;

    const created: GameWorld = {
      id: crypto.randomUUID(),
      ownerType,
      ownerId,
      kind: ownerType === "worker" ? "worker_island" : "employer_house",
      level: 1,
      experience: 0,
      inventory: {},
      updatedAt: new Date().toISOString(),
    };
    this.worlds.push(created);
    return created;
  }

  private grantExperience(
    ownerType: GameWorld["ownerType"],
    ownerId: string,
    amount: number,
  ): void {
    const world = this.getWorld(ownerType, ownerId);
    world.experience += amount;
    world.level = world.experience >= 250 ? 3 : world.experience >= 100 ? 2 : 1;
    world.updatedAt = new Date().toISOString();
  }
}

export const store = new MemoryStore();
