import {
  ApplicationDecisionInputSchema,
  CreateEvaluationInputSchema,
  CreateJobPostingInputSchema,
  RecordAttendanceInputSchema,
} from "@paw-time/api-contracts";
import { Hono } from "hono";
import { store } from "../infrastructure/memory-store.js";
import { shopConsoleRoutes } from "../modules/shop-console/routes.js";
import { requireBusinessContext } from "../middleware/business-context.js";
import type { AppEnv } from "../types.js";

export const businessRoutes = new Hono<AppEnv>();

businessRoutes.use("*", requireBusinessContext);

businessRoutes.route("/console", shopConsoleRoutes);

businessRoutes.get("/jobs", (context) => {
  return context.json({ data: store.listOrganizationJobs(context.get("organizationId")) });
});

businessRoutes.post("/jobs", async (context) => {
  const parsed = CreateJobPostingInputSchema.safeParse(await context.req.json());
  if (!parsed.success) {
    return context.json({ error: "invalid_request", issues: parsed.error.issues }, 400);
  }
  return context.json(
    { data: store.createJob(context.get("organizationId"), parsed.data) },
    201,
  );
});

businessRoutes.get("/applications", (context) => {
  return context.json({ data: store.listApplications(context.get("organizationId")) });
});

businessRoutes.get("/shifts", (context) => {
  return context.json({ data: store.listOrganizationShifts(context.get("organizationId")) });
});

businessRoutes.post("/applications/:applicationId/decision", async (context) => {
  const parsed = ApplicationDecisionInputSchema.safeParse(await context.req.json());
  if (!parsed.success) {
    return context.json({ error: "invalid_request", issues: parsed.error.issues }, 400);
  }
  const application = store.decideApplication(
    context.get("organizationId"),
    context.req.param("applicationId"),
    parsed.data,
  );
  if (!application) {
    return context.json({ error: "application_not_found_or_already_decided" }, 404);
  }
  return context.json({ data: application });
});

businessRoutes.post("/shifts/:shiftId/attendance", async (context) => {
  const parsed = RecordAttendanceInputSchema.safeParse(await context.req.json());
  if (!parsed.success) {
    return context.json({ error: "invalid_request", issues: parsed.error.issues }, 400);
  }
  const event = store.recordAttendance(
    context.get("organizationId"),
    context.req.param("shiftId"),
    context.get("actorId"),
    "employer",
    parsed.data,
  );
  if (!event) return context.json({ error: "shift_not_found" }, 404);
  return context.json({ data: event }, 201);
});

businessRoutes.get("/shifts/:shiftId/attendance-summary", (context) => {
  const summary = store.getAttendanceSummary(
    context.get("organizationId"),
    context.req.param("shiftId"),
  );
  if (!summary) return context.json({ error: "shift_not_found" }, 404);
  return context.json({ data: summary });
});

businessRoutes.post("/evaluations", async (context) => {
  const parsed = CreateEvaluationInputSchema.safeParse(await context.req.json());
  if (!parsed.success) {
    return context.json({ error: "invalid_request", issues: parsed.error.issues }, 400);
  }
  const evaluation = store.createEvaluation(
    context.get("organizationId"),
    context.get("actorId"),
    parsed.data,
  );
  if (!evaluation) return context.json({ error: "invalid_evaluation_target" }, 404);
  return context.json({ data: evaluation }, 201);
});

businessRoutes.get("/world", (context) => {
  return context.json({
    data: store.getWorld("organization", context.get("organizationId")),
  });
});
