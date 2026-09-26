import { z } from "zod";

export * from "./telemetry";

export const IdSchema = z.string().min(1).max(128);
export const TimestampSchema = z.string().datetime({ offset: true });

export const JobPostingStatusSchema = z.enum(["draft", "published", "closed"]);
export const ApplicationStatusSchema = z.enum([
  "applied",
  "selected",
  "rejected",
  "withdrawn",
]);
export const ShiftStatusSchema = z.enum([
  "scheduled",
  "checked_in",
  "checked_out",
  "completed",
  "no_show",
  "disputed",
]);

export const JobPostingSchema = z.object({
  id: IdSchema,
  organizationId: IdSchema,
  storeId: IdSchema,
  title: z.string().min(1).max(120),
  description: z.string().max(5000),
  role: z.enum(["register", "dish", "hall", "kitchen", "stock", "other"]),
  hourlyWage: z.number().int().nonnegative(),
  startsAt: TimestampSchema,
  endsAt: TimestampSchema,
  capacity: z.number().int().positive().max(1000),
  status: JobPostingStatusSchema,
  createdAt: TimestampSchema,
});

export const CreateJobPostingInputSchema = JobPostingSchema.omit({
  id: true,
  organizationId: true,
  createdAt: true,
});

export const ApplicationSchema = z.object({
  id: IdSchema,
  organizationId: IdSchema,
  jobPostingId: IdSchema,
  workerId: IdSchema,
  workerDisplayName: z.string().min(1).max(80),
  status: ApplicationStatusSchema,
  appliedAt: TimestampSchema,
  decidedAt: TimestampSchema.nullable(),
});

export const CreateApplicationInputSchema = z.object({
  jobPostingId: IdSchema,
  workerDisplayName: z.string().min(1).max(80),
});

export const ApplicationDecisionInputSchema = z.object({
  decision: z.enum(["selected", "rejected"]),
  note: z.string().max(1000).optional(),
});

export const ShiftSchema = z.object({
  id: IdSchema,
  organizationId: IdSchema,
  storeId: IdSchema,
  jobPostingId: IdSchema,
  applicationId: IdSchema,
  workerId: IdSchema,
  scheduledStartAt: TimestampSchema,
  scheduledEndAt: TimestampSchema,
  status: ShiftStatusSchema,
});

export const AttendanceEventSchema = z.object({
  id: IdSchema,
  organizationId: IdSchema,
  shiftId: IdSchema,
  kind: z.enum(["check_in", "check_out"]),
  recordedAt: TimestampSchema,
  source: z.enum(["worker", "employer", "system"]),
  actorId: IdSchema,
  clientRequestId: IdSchema,
});

export const RecordAttendanceInputSchema = AttendanceEventSchema.pick({
  kind: true,
  recordedAt: true,
  clientRequestId: true,
});

export const AttendanceSummarySchema = z.object({
  shiftId: IdSchema,
  scheduledStartAt: TimestampSchema,
  scheduledEndAt: TimestampSchema,
  actualCheckInAt: TimestampSchema.nullable(),
  actualCheckOutAt: TimestampSchema.nullable(),
  punctuality: z.enum(["pending", "on_time", "late"]),
  minutesLate: z.number().int().nonnegative(),
});

export const EvaluationSchema = z.object({
  id: IdSchema,
  organizationId: IdSchema,
  shiftId: IdSchema,
  authorId: IdSchema,
  subjectType: z.enum(["worker", "store"]),
  subjectId: IdSchema,
  rating: z.number().int().min(1).max(5),
  tags: z.array(z.string().min(1).max(64)).max(10),
  comment: z.string().max(2000).optional(),
  submittedAt: TimestampSchema,
});

export const CreateEvaluationInputSchema = EvaluationSchema.pick({
  shiftId: true,
  subjectType: true,
  subjectId: true,
  rating: true,
  tags: true,
  comment: true,
});

export const GameWorldSchema = z.object({
  id: IdSchema,
  ownerType: z.enum(["worker", "organization"]),
  ownerId: IdSchema,
  kind: z.enum(["worker_island", "employer_house"]),
  level: z.number().int().positive(),
  experience: z.number().int().nonnegative(),
  inventory: z.record(z.string(), z.number().int().nonnegative()),
  updatedAt: TimestampSchema,
});

export type JobPosting = z.infer<typeof JobPostingSchema>;
export type CreateJobPostingInput = z.infer<typeof CreateJobPostingInputSchema>;
export type Application = z.infer<typeof ApplicationSchema>;
export type CreateApplicationInput = z.infer<typeof CreateApplicationInputSchema>;
export type ApplicationDecisionInput = z.infer<typeof ApplicationDecisionInputSchema>;
export type Shift = z.infer<typeof ShiftSchema>;
export type AttendanceEvent = z.infer<typeof AttendanceEventSchema>;
export type RecordAttendanceInput = z.infer<typeof RecordAttendanceInputSchema>;
export type AttendanceSummary = z.infer<typeof AttendanceSummarySchema>;
export type Evaluation = z.infer<typeof EvaluationSchema>;
export type CreateEvaluationInput = z.infer<typeof CreateEvaluationInputSchema>;
export type GameWorld = z.infer<typeof GameWorldSchema>;
