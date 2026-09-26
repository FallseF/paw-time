import { CreateApplicationInputSchema } from "@paw-time/api-contracts";
import { Hono } from "hono";
import { store } from "../infrastructure/memory-store.js";

export const workerRoutes = new Hono();

workerRoutes.get("/jobs", (context) => {
  return context.json({ data: store.listPublishedJobs() });
});

workerRoutes.post("/applications", async (context) => {
  const workerId = context.req.header("x-user-id");
  if (!workerId) return context.json({ error: "unauthorized" }, 401);
  const parsed = CreateApplicationInputSchema.safeParse(await context.req.json());
  if (!parsed.success) {
    return context.json({ error: "invalid_request", issues: parsed.error.issues }, 400);
  }
  const application = store.applyForJob(workerId, parsed.data);
  if (!application) return context.json({ error: "job_not_found" }, 404);
  return context.json({ data: application }, 201);
});

workerRoutes.get("/shifts", (context) => {
  const workerId = context.req.header("x-user-id");
  if (!workerId) return context.json({ error: "unauthorized" }, 401);
  return context.json({ data: store.listWorkerShifts(workerId) });
});
